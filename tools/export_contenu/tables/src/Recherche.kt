// Les vecteurs de la recherche (ios/PORTAGE.md § 2.2.10, § 4.2 étape 8) : ce que la recherche
// d'Android répond, pour juger l'index d'iOS sans recopier une seule valeur à la main.
//
//  - « normalisation » : RechercheGlobale.nu sur la liste de cas communs (cas_normalisation.json),
//    que la normalisation Python de l'export et celle de Swift doivent rendre à l'identique ;
//  - « recherches » : RechercheGlobale.chercher sur les contenus de res/raw, pour les requêtes des
//    tests d'Android (HalakhaTest, YalkutYosefTest, HilloulotTest, DixAmeliorationsTest) et
//    quelques autres, dans les trois langues et les trois rites.
//
// Les contenus sont lus par les chargeurs de l'app (SiddurLoader, YalkutYosef.parse…), avec
// l'org.json d'Android (build.gradle.kts) : l'ordre est celui du fichier, comme sur l'appareil ; et
// le \s+ de nu() a le sens d'ICU, celui de l'appareil (build.gradle.kts aussi). HalakhaActivity ne se compile pas hors d'Android : son bouchon rend les champs du
// titre du Ben Ich Haï (bouchons/App.kt), que le test Swift met en forme.
package com.myhitbodedut

import java.io.File

/** Les requêtes : celles des tests d'Android d'abord, puis de quoi couvrir chaque sorte et chaque règle. */
private val REQUETES = listOf(
    // HalakhaTest, YalkutYosefTest.
    "ציצית", "צ",
    // HilloulotTest.
    "צבי הירש חיות", "א", "Chelah", "Shelah", "Moché", "moche", "רבי",
    // DixAmeliorationsTest.
    "כורעים", "alénou", "Alenou", "שבת",
    // Titres, extraits, sortes, guillemets, balises, majuscules, espaces.
    "Birkot hacha’har", "priere", "שמע ישראל", "  נִשְׁמַת  ", "ה׳", "רמב\"ם", "התבודדות", "Tikoun", "Nahman",
    "BRESLOV", "תהילים", "Pessa'h", "<b>", "ab", "x",
    // Un bloc du Kitsour qui finit par U+0000 ; les espaces fines du siddour, les insécables du Ben Ich Haï.
    "שהיבם יתחרט", "יאר יהוה פניו", "ששה זוגות",
)

/** Les combinaisons (langue, rite) : le français dans les trois rites, puis l'anglais et l'hébreu. */
private val COMBINAISONS = listOf("fr" to Nusah.EDOT, "fr" to Nusah.SEFARD, "fr" to Nusah.ASHKENAZ,
    "en" to Nusah.EDOT, "he" to Nusah.EDOT)

fun vecteursRecherche(raw: File, cas: File, sortie: File, nomRaw: (Int) -> String) {
    fun lire(nom: String) = File(raw, "$nom.json").readText(Charsets.UTF_8)
    val siddurs = Nusah.entries.associateWith { SiddurLoader.parse(lire(nomRaw(it.brut))) }
    // Data.livres (ChizukCard.kt, lié à Android) : l'index, puis chaque livre entier, dans l'ordre de l'index.
    val index = SiddurLoader.parse(lire("livres_titres"))
    val livres = Siddur(index.groupes, index.textes.mapNotNull { e ->
        LivresBruts.parId[e.id]?.let { SiddurLoader.parse(lire(nomRaw(it))).texte(e.id) }
    }, index.nusah, index.sources)
    check(livres.textes.size == index.textes.size) { "recherche : un livre de l'index manque" }
    val yalkut = YalkutYosef.parse(lire("yalkut_yosef"))
    val benIshHai = Halakha.parse(lire("ben_ish_hai"))
    val hilloulot = Hilloulot.parse(lire("hilloulot"))

    val entrees = org.json.JSONObject(cas.readText(Charsets.UTF_8)).getJSONArray("cas").let { a -> (0 until a.length()).map(a::getString) }
    check(entrees.isNotEmpty()) { "recherche : aucun cas de normalisation" }

    val recherches = mutableListOf<Map<String, Any?>>()
    for (q in REQUETES) for ((langue, nusah) in COMBINAISONS) {
        val r = RechercheGlobale.chercher(q, langue, siddurs.getValue(nusah), livres, yalkut, benIshHai, hilloulot)
        recherches += cas(q, langue, nusah, RechercheGlobale.Portee.TOUT, r)
    }
    // Chaque portée, sur une requête qui trouve dans toutes les sortes.
    for (portee in RechercheGlobale.Portee.entries.filter { it != RechercheGlobale.Portee.TOUT }) {
        val r = RechercheGlobale.chercher("שבת", "fr", siddurs.getValue(Nusah.EDOT), livres, yalkut, benIshHai, hilloulot, portee)
        recherches += cas("שבת", "fr", Nusah.EDOT, portee, r)
    }
    val vecteurs = linkedMapOf(
        "normalisation" to entrees.map { listOf(it, RechercheGlobale.nu(it)) },
        "par_sorte" to RechercheGlobale.PAR_SORTE,
        "par_texte" to RechercheGlobale.PAR_TEXTE,
        "par_recueil" to RechercheGlobale.PAR_RECUEIL,
        "recherches" to recherches,
    )
    sortie.writeText(enJson(vecteurs) + "\n", Charsets.UTF_8)
}

private fun cas(q: String, langue: String, nusah: Nusah, portee: RechercheGlobale.Portee, r: List<RechercheGlobale.Resultat>) =
    linkedMapOf("q" to q, "langue" to langue, "rite" to nusah.cle, "portee" to portee.name.lowercase(),
        // La place d'un paragraphe (rang de section, rang de bloc) ; -1 pour un titre, la halakha, une hilloula.
        "resultats" to r.map { listOf(it.sorte.name.lowercase(), it.id, it.titre, it.extrait, it.section.toString(), it.bloc.toString()) })
