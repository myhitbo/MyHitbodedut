// La lecture du siddour un jour donné (SiddurJour.lignes) devant la JVM : pour chaque jour du
// 1er septembre 2026 au 30 septembre 2027 qui apporte un jeu de conditions neuf (hors d'Israël ou en
// Israël ; le psaume du jour n'en fait pas un), chaque texte annoté des trois nusah, replié puis tout
// ouvert ; et, quand cela change les conditions, les Edot dans l'hémisphère sud et Sfard sans Ta'hanoun
// de la fin de Tichri. Les lectures d'un jour et d'un nusah tiennent en leur nombre de lignes et en une
// empreinte : le hashCode de Java de leurs lignes écrites en quelques signes, texte après texte dans
// l'ordre du fichier d'annotations (VecteursSiddourJour.code, refait par le test Swift).

import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.Nusah
import com.myhitbodedut.SiddurJour
import com.myhitbodedut.SiddurLoader
import java.io.File
import java.time.LocalDate

object VecteursSiddourJour : Generateur {
    override val fichier = "siddour_jour.json"

    /** Une ligne en quelques signes ; un texte par sa longueur en unités UTF-16. */
    fun code(l: SiddurJour.Ligne): String = when (l) {
        is SiddurJour.Ligne.Titre -> "T"
        is SiddurJour.Ligne.Bloc -> "B${l.style.ordinal}:${l.bloc.texte.length}"
        is SiddurJour.Ligne.Etiquette -> "E:${l.condition}:${l.libelle}"
        is SiddurJour.Ligne.Indice -> "I:${l.texte.length}"
        is SiddurJour.Ligne.Renvoi -> "R:${l.condition}:${l.cible}"
        is SiddurJour.Ligne.Seul -> "S:${l.texte.length}:${l.consigne?.length ?: -1}"
        is SiddurJour.Ligne.Replie -> "P:${l.cle}:${l.condition}:${if (l.ouvert) 1 else 0}:${l.libelle}"
    }

    private class Variante(val nom: String, val sansTahanoun: Boolean, val sud: Boolean)

    override fun produire(): Map<String, Any?> {
        val annotations = File(RES, "raw/siddur_annotations.json").readText()
        val recueils = Nusah.entries.map { n -> n to SiddurLoader.parse(File(RES, "raw/siddur_${n.cle}.json").readText()) }

        // Les jours retenus : le premier de chaque jeu de conditions, sans le psaume du jour.
        val jours = mutableListOf<Pair<LocalDate, Boolean>>()
        val vus = mutableSetOf<Pair<Boolean, Set<String>>>()
        var d = LocalDate.of(2026, 9, 1)
        while (!d.isAfter(LocalDate.of(2027, 9, 30))) {
            for (israel in listOf(false, true)) {
                val c = CalendrierJuif.jour(d, israel).conditions.filterNot { it.startsWith("jour_") }.toSet()
                if (vus.add(israel to c)) jours += d to israel
            }
            d = d.plusDays(1)
        }

        val cas = mutableListOf<String>()
        for ((jour, israel) in jours) {
            val conditions = CalendrierJuif.jour(jour, israel).conditions
            for ((n, siddur) in recueils) {
                val defaut = n.cle == "edot"
                val variantes = mutableListOf(Variante("-", defaut, false))
                fun ajoute(v: Variante) {
                    val ici = SiddurJour.conditionsPour(n.cle, israel, conditions, v.sansTahanoun, v.sud)
                    if (ici != SiddurJour.conditionsPour(n.cle, israel, conditions, defaut, false)) variantes += v
                }
                if (n == Nusah.EDOT) ajoute(Variante("sud", true, true))
                if (n == Nusah.SEFARD) ajoute(Variante("sans_tahanoun", true, false))
                for (v in variantes) {
                    val fermes = mutableListOf<String>()
                    val ouverts = mutableListOf<String>()
                    var n1 = 0
                    var n2 = 0
                    for ((id, liste) in SiddurJour.parse(annotations, n.cle)) {
                        val texte = siddur.texte(id)!!
                        fun lire(cles: Set<String>) =
                            SiddurJour.lignes(texte, liste, conditions, cles, n.cle, israel, v.sansTahanoun, v.sud)
                        val ferme = lire(emptySet())
                        val ouvert = lire(ferme.filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }.toSet())
                        fermes += id + "=" + ferme.joinToString(";") { code(it) }
                        ouverts += id + "=" + ouvert.joinToString(";") { code(it) }
                        n1 += ferme.size
                        n2 += ouvert.size
                    }
                    cas += listOf(jour, if (israel) 1 else 0, n.cle, v.nom,
                        n1, fermes.joinToString("#").hashCode(), n2, ouverts.joinToString("#").hashCode()).joinToString("|")
                }
            }
        }
        return linkedMapOf(
            "_meta" to mapOf(
                "source" to "tools/vecteurs_ios/VecteursSiddourJour.kt",
                "forme" to "jour|israël|nusah|variante|lignes|empreinte|lignes tout ouvert|empreinte tout ouvert",
            ),
            "cas" to cas,
        )
    }
}
