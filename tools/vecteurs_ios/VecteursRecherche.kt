// La recherche dans toute l'application devant la JVM (RechercheGlobale.kt) : nu sur plus de deux cents
// chaînes (titres du siddour et des livres, blocs vocalisés, noms de hilloulot, français accentué, blancs,
// balises), puis sur tout le corpus (une empreinte par texte) ; extrait ; resultatHilloula ; chercher sur une
// quarantaine de requêtes et toutes les portées, avec le vrai siddour (siddur_edot.json), les vrais livres,
// yalkut_yosef, ben_ish_hai et hilloulot. Les résultats ne gardent que (sorte, id, titre, extrait), écrits
// par empreinte : une par sorte et par portée, et les premiers en entier.

import com.myhitbodedut.Data
import com.myhitbodedut.Halakha
import com.myhitbodedut.Hilloulot
import com.myhitbodedut.RechercheGlobale
import com.myhitbodedut.Siddur
import com.myhitbodedut.SiddurLoader
import com.myhitbodedut.YalkutYosef
import java.io.File

object VecteursRecherche : Generateur {
    override val fichier = "recherche.json"

    private val siddur: Siddur = SiddurLoader.parse(File(RES, "raw/siddur_edot.json").readText())
    private val livres: Siddur = Data.livres(Theatre().contexte)
    private val yalkut: YalkutYosef.Livre = YalkutYosef.parse(File(RES, "raw/yalkut_yosef.json").readText())
    private val benIshHai: Halakha.Livre = Halakha.parse(File(RES, "raw/ben_ish_hai.json").readText())
    private val hilloulot: Map<String, List<Hilloulot.Hilloula>> = Hilloulot.parse(File(RES, "raw/hilloulot.json").readText())

    /** L'empreinte d'une liste de lignes : jointes par un saut de ligne, puis String.hashCode(). */
    private fun empreinte(lignes: List<String>): Int = lignes.joinToString("\n").hashCode()

    private fun ligne(r: RechercheGlobale.Resultat): String = listOf(r.sorte.name, r.id, r.titre, r.extrait).joinToString("\u001F")

    private fun ecrit(r: RechercheGlobale.Resultat): List<String> = listOf(r.sorte.name, r.id, r.titre, r.extrait)

    // --- nu ----------------------------------------------------------------------------------------

    /** Ce que la recherche doit traverser : accents, apostrophes, balises, blancs de toute sorte, signes hébreux. */
    private val bornes = listOf(
        "<b>בָּרוּךְ</b> אַתָּה", "Birkot hacha’har Prières", "Alénou", "alénou", "Alenou", "L’Éternel", "Chéma‘ Israël",
        "Ḥanoukka", "Pâque", "Œuvre", "ÇA", "naïve", "Noël", "Hébreu « guillemets »", "‘Amida’", "l'Alliance", "\"quoted\"",
        "Méguilat Esther", "Kitsour Choul'han Aroukh", "HÔPITAL Éé Èè Êê Ëë", "Ångström", "İstanbul", "ẞtraße", "ﬁ",
        "", " ", "\t\n", "a\u000Bb", "a\u000Cb", "a\rb", "a b", " a ", "a b", " a ", "a  \t  b",
        "  x  ", "a\u0085b", "\u001Fa\u001C", "<b>x</b>", "<>", "a<b", "a > b", "<<b>>", "<́b>", "<́>", "x<br/>y",
        "<p\nclass='a'>t</p>", "a<b>c", "<b>", "<", ">", "<<>>", "<a><>b>", "1 < 2 > 0", "שָׁלוֹם־עֲלֵיכֶם", "פסוק׀ב",
        "ר׳ נחמן", "רש״י", "\"רבי\"", "'רבי'", "ﬠ", "שׁשׂשּׁ", "וֹ", "ﭏ", "יִ", "ײַ",
        "בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים", "ה׳", "יְהֹוָה", "וַיֹּ֥אמֶר אֱלֹהִ֖ים יְהִ֣י א֑וֹר", "ׇ", "ׇ׈", "֐֑",
        "ׯװױײ", "ABC def", "MOCHÉ", "Moché", "moche", "Rabbénou", "Yossef", "Haïm", "Ḥayyim",
        "שלמה־זלמן", "  רבי  ", "‫רבי‬", "⁨רבי⁩", "a​b", "x﻿y", "1–2—3", "« Ô »",
    )

    private fun echantillon(): List<String> {
        val s = mutableListOf<String>()
        s += bornes
        siddur.textes.forEach { t -> s += listOf(t.titre.he, t.titre.fr, t.titre.en) }
        siddur.textes.flatMap { it.sections }.map { it.titre }.filter { it.isNotEmpty() }.distinct().take(40).forEach { s += it }
        livres.textes.forEach { t -> s += listOf(t.titre.he, t.titre.fr, t.titre.en) }
        // Le premier bloc de chaque texte, voyelles et te'amim compris, et la première consigne : 160 unités au plus.
        siddur.textes.forEach { t ->
            t.sections.flatMap { it.blocs }.firstOrNull { !it.consigne }?.let { s += it.texte.take(160) }
            t.sections.flatMap { it.blocs }.firstOrNull { it.consigne }?.let { s += it.texte.take(160) }
        }
        livres.textes.forEach { t -> t.sections.firstOrNull()?.blocs?.firstOrNull()?.let { s += it.texte.take(160) } }
        val toutes = hilloulot.values.flatten()
        toutes.take(40).forEach { s += it.he }
        toutes.mapNotNull { it.fr }.take(30).forEach { s += it }
        toutes.mapNotNull { it.en }.take(30).forEach { s += it }
        return s.distinct()
    }

    private fun nus(): List<Any?> = echantillon().map { listOf(it, RechercheGlobale.nu(it)) }

    /** nu sur tout le corpus : [id, nombre de blocs, empreinte des blocs mis à nu] par texte du siddour et par livre. */
    private fun corpus(): Map<String, Any?> {
        fun recueil(r: Siddur): List<Any?> = r.textes.map { t ->
            val blocs = t.sections.flatMap { it.blocs }
            listOf(t.id, blocs.size, empreinte(blocs.map { RechercheGlobale.nu(it.texte) }))
        }
        val toutes = hilloulot.values.flatten()
        return linkedMapOf(
            "siddour" to recueil(siddur),
            "livres" to recueil(livres),
            "hilloulot" to listOf(
                listOf(toutes.size, empreinte(toutes.map { RechercheGlobale.nu(it.he) })),
                listOf(toutes.count { it.fr != null }, empreinte(toutes.mapNotNull { it.fr }.map(RechercheGlobale::nu))),
                listOf(toutes.count { it.en != null }, empreinte(toutes.mapNotNull { it.en }.map(RechercheGlobale::nu))),
            ),
        )
    }

    // --- extrait -----------------------------------------------------------------------------------

    private fun textesExtrait(): List<String> {
        val blocs = siddur.textes.flatMap { t -> t.sections.flatMap { it.blocs } }.filter { !it.consigne }
        val long = blocs.first { it.texte.length > 400 }.texte
        val moyen = blocs.first { it.texte.length in 120..250 }.texte
        return listOf(long, moyen, "<b>בָּרוּךְ</b> אַתָּה", "Birkot hacha’har — Prières du matin, l’Éternel est Un, et la suite qui dépasse cinquante unités.",
            "", "ab", "  début et fin blancs  ")
    }

    private fun extraits(): Map<String, Any?> {
        val textes = textesExtrait()
        val cas = mutableListOf<Any?>()
        textes.forEachIndexed { k, texte ->
            val t = RechercheGlobale.nu(texte)
            val requetes = mutableListOf("", "zzzz", t, t + "x")
            for (p in listOf(0, 1, 10, 29, 30, 31, 45, 60, 100, 200, t.length - 6, t.length - 2)) {
                for (n in listOf(2, 5, 12)) if (p >= 0 && p + n <= t.length) requetes += t.substring(p, p + n)
            }
            requetes.distinct().forEach { q -> cas.add(listOf(k, q, RechercheGlobale.extrait(texte, q))) }
        }
        return linkedMapOf("textes" to textes, "cas" to cas)
    }

    // --- resultatHilloula --------------------------------------------------------------------------

    private fun resultatsHilloula(): List<Any?> {
        val h = { he: String, fr: String?, en: String?, a: String -> Hilloulot.Hilloula(he, fr, en, a, "w", null) }
        val essais = listOf(h("רבי נחמן", "Rabbi Nahman", "Rabbi Nachman", "תקע\"א"), h("רבי נחמן", null, null, "תקע\"א"),
            h("רבי נחמן", "  ", "", ""), h("רבי נחמן", "Rabbi Nahman", null, "  "), h("", "", "", ""), h("א", "b", "c", "d"))
        val reels = hilloulot.values.flatten().filter { it.fr != null || it.en != null }.take(12)
        return (essais + reels).flatMap { x ->
            listOf("fr", "en", "he", "fr-FR", "en-GB", "es", "", "FR", "iw").map { langue ->
                linkedMapOf("hilloula" to listOf(x.he, x.fr, x.en, x.annee), "langue" to langue,
                    "resultat" to ecrit(RechercheGlobale.resultatHilloula("q", x, langue)))
            }
        }
    }

    // --- chercher ----------------------------------------------------------------------------------

    /** [requête, langue, sources] : « complet » avec les livres, « sansLivres », « seulSiddur » (le reste à null). */
    private val requetes = listOf(
        listOf("ברוך", "fr", "complet"), listOf("בָּרוּךְ אַתָּה", "fr", "complet"), listOf("priere", "fr", "complet"),
        listOf("Likoutei", "fr", "complet"), listOf("התבודדות", "he", "complet"), listOf("נחמן", "en", "complet"),
        listOf("שבת", "fr", "complet"), listOf("Esther", "en", "complet"),
        listOf("שמע ישראל", "fr", "sansLivres"), listOf("אשרי", "fr", "sansLivres"), listOf("עלינו", "fr", "sansLivres"),
        listOf("קדיש", "fr", "sansLivres"), listOf("מודה אני", "fr", "sansLivres"), listOf("חנוכה", "fr", "sansLivres"),
        listOf("פורים", "en", "sansLivres"), listOf("תפילה", "he", "sansLivres"), listOf("צדיק", "fr", "sansLivres"),
        listOf("רבי", "fr", "sansLivres"), listOf("יוסף", "en", "sansLivres"), listOf("משה", "fr", "sansLivres"),
        listOf("<b>ברוך</b>", "fr", "sansLivres"), listOf("ה'", "fr", "sansLivres"), listOf("בורא פרי", "fr", "sansLivres"),
        listOf("ציצית", "fr", "sansLivres"), listOf("לשון הרע", "fr", "sansLivres"), listOf("Prières", "fr", "sansLivres"),
        listOf("hachahar", "fr", "sansLivres"), listOf("Birkot hacha’har", "fr", "sansLivres"), listOf("Alénou", "fr", "sansLivres"),
        listOf("kaddich", "fr", "sansLivres"), listOf("Chabbat", "fr", "sansLivres"), listOf("Hanouka", "fr", "sansLivres"),
        listOf("Moché", "fr", "sansLivres"), listOf("Nachman", "en", "sansLivres"), listOf("blessing", "en", "sansLivres"),
        listOf("Shabbat", "en", "sansLivres"), listOf("Aleinu", "en", "sansLivres"), listOf("Shema", "en", "sansLivres"),
        listOf("", "fr", "sansLivres"), listOf("א", "fr", "sansLivres"), listOf(" ", "fr", "sansLivres"),
        listOf("ab", "fr", "sansLivres"), listOf("zzzz", "fr", "sansLivres"), listOf("\"שבת\"", "he", "sansLivres"),
        listOf("ברוך", "he", "seulSiddur"), listOf("Chabbat", "en", "seulSiddur"), listOf("ראש חודש", "fr", "seulSiddur"),
    )

    private fun cherche(q: String, langue: String, sources: String, portee: RechercheGlobale.Portee): List<RechercheGlobale.Resultat> =
        when (sources) {
            "complet" -> RechercheGlobale.chercher(q, langue, siddur, livres, yalkut, benIshHai, hilloulot, portee)
            "sansLivres" -> RechercheGlobale.chercher(q, langue, siddur, null, yalkut, benIshHai, hilloulot, portee)
            else -> RechercheGlobale.chercher(q, langue, siddur, null, null, null, null, portee)
        }

    private fun recherches(): List<Any?> = requetes.map { (q, langue, sources) ->
        val portees = linkedMapOf<String, Any?>()
        RechercheGlobale.Portee.values().forEach { p ->
            val r = cherche(q, langue, sources, p)
            val parSorte = RechercheGlobale.Sorte.values().map { s -> r.filter { it.sorte == s } }
            // Les résultats viennent par sorte, dans l'ordre de Sorte : chaque sorte se juge à part.
            check(parSorte.flatten() == r) { "« $q » : les sortes mêlées" }
            val entree = linkedMapOf<String, Any?>("nombres" to parSorte.map { it.size }, "empreintes" to parSorte.map { l -> empreinte(l.map(::ligne)) })
            if (p == RechercheGlobale.Portee.TOUT) entree["premiers"] = parSorte.flatMap { l -> l.take(2).map(::ecrit) }
            portees[p.name] = entree
        }
        linkedMapOf("q" to q, "langue" to langue, "sources" to sources, "portees" to portees)
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursRecherche.kt"),
        "parSorte" to RechercheGlobale.PAR_SORTE,
        "nu" to nus(),
        "corpus" to corpus(),
        "extraits" to extraits(),
        "resultatsHilloula" to resultatsHilloula(),
        "recherches" to recherches(),
    )
}
