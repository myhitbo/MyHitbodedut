package com.myhitbodedut

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.Writer

/**
 * L'index de recherche des livres (décision du 24/11).
 *
 * La recherche « dans tous les livres » relisait et réanalysait les douze livres — 28 Mo de
 * JSON — à chaque requête, puis passait chaque paragraphe par [RechercheGlobale.nu] : quelques
 * secondes par recherche, davantage sur un téléphone modeste. Garder les livres en mémoire
 * coûterait 40 Mo. On écrit donc une fois, dans les fichiers de l'application, chaque paragraphe
 * déjà normalisé (sans voyelles, sans accents, en minuscules), une ligne par paragraphe ; une
 * recherche ne fait plus que lire ce fichier de haut en bas. Il se refait à chaque nouvelle
 * version de l'application, puisque les livres peuvent avoir changé.
 *
 * Les résultats sont ceux de [RechercheGlobale.dansRecueil] : même ordre, mêmes extraits, même
 * place dans le livre (IndexLivresTest le vérifie).
 *
 * Lignes, séparées par des tabulations :
 * - `T  id  titre hébreu  titre français  titre anglais` : un livre commence ;
 * - `S  rang  titre` : un chapitre ;
 * - `P  rang du chapitre  rang du paragraphe  texte normalisé`.
 */
object IndexLivres {

    private const val FORMAT = 1

    private fun propre(t: String) = t.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ')

    /** Écrit l'index d'un recueil de livres. */
    fun ecrire(recueil: Siddur, sortie: Writer) {
        recueil.textes.forEach { t -> ecrireTexte(t, sortie) }
    }

    private fun ecrireTexte(t: SiddurTexte, sortie: Writer) {
        sortie.write("T\t${propre(t.id)}\t${propre(t.titre.he)}\t${propre(t.titre.fr)}\t${propre(t.titre.en)}\n")
        t.sections.forEachIndexed { si, sec ->
            if (sec.titre.isNotBlank()) sortie.write("S\t$si\t${propre(sec.titre)}\n")
            sec.blocs.forEachIndexed { bi, b ->
                if (!b.consigne) sortie.write("P\t$si\t$bi\t${RechercheGlobale.nu(b.texte)}\n")
            }
        }
    }

    /**
     * Cherche [q] (déjà passé par [RechercheGlobale.nu]) dans les lignes d'un index, comme
     * [RechercheGlobale.dansRecueil] le fait dans les livres.
     */
    fun chercher(lignes: Sequence<String>, q: String, langue: String, annule: () -> Boolean = { false }): List<RechercheGlobale.Resultat> {
        val sortie = ArrayList<RechercheGlobale.Resultat>()
        var id = ""
        var titre = ""
        var trouves = 0
        var plein = false
        val chapitres = HashMap<Int, String>()
        for (ligne in lignes) {
            if (sortie.size >= RechercheGlobale.PAR_RECUEIL || annule()) break
            when (ligne.firstOrNull()) {
                'T' -> {
                    val c = ligne.split('\t')
                    id = c.getOrElse(1) { "" }
                    val nom = LocalizedText(c.getOrElse(2) { "" }, c.getOrElse(3) { "" }, c.getOrElse(4) { "" })
                    titre = nom.he
                    trouves = 0
                    plein = false
                    chapitres.clear()
                    val traduit = nom.forLanguage(langue)
                    if (RechercheGlobale.nu(titre).contains(q) || RechercheGlobale.nu(traduit).contains(q)) {
                        sortie += RechercheGlobale.Resultat(RechercheGlobale.Sorte.LIVRE, id, titre, traduit.takeIf { it != titre }.orEmpty())
                        trouves++
                    }
                }
                'S' -> {
                    val c = ligne.split('\t', limit = 3)
                    c.getOrNull(1)?.toIntOrNull()?.let { chapitres[it] = c.getOrElse(2) { "" } }
                }
                'P' -> {
                    if (plein) continue
                    // Le texte est le quatrième champ : on ne découpe la ligne que s'il contient la recherche.
                    val t3 = ligne.indexOf('\t', ligne.indexOf('\t', 2) + 1)
                    if (t3 < 0 || !ligne.regionContains(t3 + 1, q)) continue
                    val c = ligne.substring(0, t3).split('\t')
                    val si = c.getOrNull(1)?.toIntOrNull() ?: continue
                    val bi = c.getOrNull(2)?.toIntOrNull() ?: continue
                    val chapitre = chapitres[si]?.takeIf { it.isNotBlank() }?.let { "$it · " }.orEmpty()
                    sortie += RechercheGlobale.Resultat(RechercheGlobale.Sorte.LIVRE, id, titre,
                        chapitre + RechercheGlobale.extraitNu(ligne.substring(t3 + 1), q), si, bi)
                    trouves++
                    // Le titre compte dans les cinq, comme dans dansRecueil.
                    if (trouves >= RechercheGlobale.PAR_TEXTE) plein = true
                }
            }
        }
        return sortie.take(RechercheGlobale.PAR_RECUEIL)
    }

    private fun String.regionContains(depuis: Int, q: String): Boolean = indexOf(q, depuis) >= 0

    // --- Sur le téléphone ------------------------------------------------------------------

    private fun fichier(context: Context) =
        File(context.filesDir, "recherche-livres-$FORMAT-${BuildConfig.VERSION_CODE}.idx")

    /**
     * L'index, écrit s'il manque : un livre lu à la fois, comme la recherche le faisait, puis
     * oublié. Hors du fil principal. Null si l'écriture échoue (place manquante) : la
     * recherche relit alors les livres, comme avant.
     */
    @Synchronized
    fun pret(context: Context): File? {
        val f = fichier(context)
        if (f.isFile && f.length() > 0L) return f
        return runCatching {
            context.filesDir.listFiles { x -> x.name.startsWith("recherche-livres-") && x != f }?.forEach { it.delete() }
            val provisoire = File(f.path + ".tmp")
            provisoire.bufferedWriter(Charsets.UTF_8).use { w ->
                val index = Data.livresIndex(context)
                index.textes.forEach { e -> Data.livreSeul(context, e.id)?.let { ecrireTexte(it, w) } }
            }
            if (!provisoire.renameTo(f)) error("renommage")
            f
        }.getOrNull()
    }

    /** Cherche dans l'index des livres, écrit au besoin ; null si l'index n'est pas disponible. */
    fun chercher(context: Context, q: String, langue: String, annule: () -> Boolean): List<RechercheGlobale.Resultat>? {
        val f = pret(context) ?: return null
        return runCatching {
            f.bufferedReader(Charsets.UTF_8).use { r: BufferedReader -> chercher(r.lineSequence(), q, langue, annule) }
        }.getOrNull()
    }
}
