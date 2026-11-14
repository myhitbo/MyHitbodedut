// Tikkun.kt devant la JVM : le Tikoun HaKlali livré, lu par TikkunLoader (une empreinte par texte
// long, le reste en clair), Tikkun.byNumero, bloc, avant et apres, la coupe d'un verset à son arrêt
// (Verse.coupe) sur des versets écrits à la main, et ce que TikkunLoader accepte, refuse et convertit
// d'un document écrit à la main (org.json d'Android : getString, getInt, optString, Json.nullable).

import com.myhitbodedut.LiturgyBlock
import com.myhitbodedut.LocalizedText
import com.myhitbodedut.Pause
import com.myhitbodedut.Psalm
import com.myhitbodedut.Tikkun
import com.myhitbodedut.TikkunLoader
import com.myhitbodedut.Verse
import java.io.File

object VecteursTikkun : Generateur {
    override val fichier = "tikkun.json"

    private val livre: Tikkun = TikkunLoader.parse(File(RES, "raw/tikkun_haklali.json").readText())

    private val cles = listOf(Tikkun.OUVERTURE, Tikkun.CLOTURE, Tikkun.KAVANA, Tikkun.PRIERE)

    private fun localise(t: LocalizedText?): Map<String, Any?>? = t?.let { linkedMapOf("he" to it.he, "fr" to it.fr, "en" to it.en) }

    private fun arret(p: Pause?): Map<String, Any?>? = p?.let { linkedMapOf("avant" to it.avant, "note" to it.note) }

    /** La coupe d'un verset en clair : ce qui précède le mot d'arrêt, puis ce qui commence par lui. */
    private fun coupe(v: Verse): List<String>? = v.coupe()?.let { listOf(it.first, it.second) }

    private fun empreintes(textes: List<String>): List<Int> = textes.map { it.hashCode() }

    // --- Le fichier livré : empreintes des textes, le reste en clair ------------------------------

    private fun versetLivre(v: Verse): Map<String, Any?> = linkedMapOf(
        "n" to v.numero, "he" to v.he.hashCode(), "arret" to arret(v.arret),
        "fr" to v.fr?.hashCode(), "en" to v.en?.hashCode(),
        "coupe" to v.coupe()?.let { listOf(it.first.hashCode(), it.second.hashCode()) },
    )

    private fun psaumeLivre(p: Psalm): Map<String, Any?> = linkedMapOf(
        "id" to p.id, "numero" to p.numero, "ref" to p.ref, "refSefaria" to p.refSefaria, "url" to p.url,
        "versets" to p.versets.map(::versetLivre),
    )

    private fun blocLivre(b: LiturgyBlock): Map<String, Any?> = linkedMapOf(
        "cle" to b.cle, "titre" to localise(b.titre), "note" to localise(b.note), "formule" to b.formule,
        "paragraphes" to empreintes(b.paragraphes), "paragraphesFr" to empreintes(b.paragraphesFr),
        "paragraphesEn" to empreintes(b.paragraphesEn),
    )

    // --- Un document écrit à la main : tout en clair ----------------------------------------------

    private fun verset(v: Verse): Map<String, Any?> = linkedMapOf(
        "n" to v.numero, "he" to v.he, "arret" to arret(v.arret), "fr" to v.fr, "en" to v.en, "coupe" to coupe(v),
    )

    private fun psaume(p: Psalm): Map<String, Any?> = linkedMapOf(
        "id" to p.id, "numero" to p.numero, "ref" to p.ref, "refSefaria" to p.refSefaria, "url" to p.url,
        "versets" to p.versets.map(::verset),
    )

    private fun bloc(b: LiturgyBlock): Map<String, Any?> = linkedMapOf(
        "cle" to b.cle, "titre" to localise(b.titre), "note" to localise(b.note), "formule" to b.formule,
        "paragraphes" to b.paragraphes, "paragraphesFr" to b.paragraphesFr, "paragraphesEn" to b.paragraphesEn,
    )

    private fun lu(t: Tikkun): Map<String, Any?> = linkedMapOf(
        "version" to t.version, "titre" to localise(t.titre),
        "edition" to linkedMapOf("cle" to t.edition.key, "titre" to t.edition.titre, "licence" to t.edition.licence,
            "nikkoudOk" to t.edition.nikkoudOk),
        "continuite" to localise(t.continuite), "versets" to t.versets,
        "psaumes" to t.psaumes.map(::psaume),
        // Les blocs dans l'ordre de la Map de Kotlin : celui des quatre clés, les absents sautés.
        "blocs" to t.blocs.values.map(::bloc),
        "avant" to t.avant.map { it.cle }, "apres" to t.apres.map { it.cle },
        "byNumero" to listOf(16, 1, 0, 10, 4, -1).map { n -> linkedMapOf("numero" to n, "id" to t.byNumero(n)?.id) },
    )

    private val vide = """"_meta":{"edition":{}}"""

    private val documents: List<Pair<String, String>> = listOf(
        "minimal" to """{$vide,"psaumes":[]}""",
        "complet" to """{"_meta":{"version":"2.0","titre":{"he":"תיקון","fr":"Tikoun","en":"Tikkun"},"continuite":{"he":"ברצף","fr":"d'un trait","en":"in one go"},"edition":{"cle":"tanakh","titre":"T","licence":"Public Domain","nikkoud_ok":true}},"psaumes":[{"id":"tehilim-16","numero":16,"ref":"Tehilim 16","ref_sefaria":"Psalms 16","url":"https://x","versets":[{"n":1,"he":"מִכְתָּם לְדָוִד","fr":"Mikhtam","en":"Michtam"},{"n":2,"he":"אַתָּה סֵתֶר לִי מִצַּר תִּצְּרֵנִי","arret":{"avant":"מִצַּר","note":"(ליקוטי מוהר\"ן)"}}]},{"id":"tehilim-32","numero":32,"versets":[]}],"ouverture":{"titre":{"he":"לפני"},"note":{"fr":"Bon à dire"},"paragraphes":["א","ב"],"paragraphes_fr":["a"]},"cloture":{"titre":{"he":"אחרי"},"formule":"x = y","paragraphes":["ג"]},"kavana":{"titre":{"he":"כוונה"},"paragraphes":[]},"priere_rabbi_nathan":{"paragraphes":["ד"],"paragraphes_en":["d"]}}""",
        "sansMeta" to """{"psaumes":[]}""",
        "metaPasUnObjet" to """{"_meta":"x","psaumes":[]}""",
        "metaNul" to """{"_meta":null,"psaumes":[]}""",
        "sansEdition" to """{"_meta":{},"psaumes":[]}""",
        "editionPasUnObjet" to """{"_meta":{"edition":[]},"psaumes":[]}""",
        "sansPsaumes" to """{$vide}""",
        "psaumesPasUnTableau" to """{$vide,"psaumes":{}}""",
        "psaumesNuls" to """{$vide,"psaumes":null}""",
        "psaumePasUnObjet" to """{$vide,"psaumes":[1]}""",
        "psaumeNul" to """{$vide,"psaumes":[null]}""",
        "sansId" to """{$vide,"psaumes":[{"numero":1}]}""",
        "sansNumero" to """{$vide,"psaumes":[{"id":"a"}]}""",
        "numeroIllisible" to """{$vide,"psaumes":[{"id":"a","numero":"seize"}]}""",
        "numeroBooleen" to """{$vide,"psaumes":[{"id":"a","numero":true}]}""",
        "numeroNul" to """{$vide,"psaumes":[{"id":"a","numero":null}]}""",
        "numeroTableau" to """{$vide,"psaumes":[{"id":"a","numero":[1]}]}""",
        "versetPasUnObjet" to """{$vide,"psaumes":[{"id":"a","numero":1,"versets":["x"]}]}""",
        "versetSansNumero" to """{$vide,"psaumes":[{"id":"a","numero":1,"versets":[{"he":"x"}]}]}""",
        "versetNumeroTexte" to """{$vide,"psaumes":[{"id":"a","numero":1,"versets":[{"n":"un","he":"x"}]}]}""",
        "conversions" to """{"_meta":{"version":1.50,"titre":{"he":null,"fr":7,"en":true},"continuite":"non","edition":{"cle":12,"titre":null,"licence":["x"],"nikkoud_ok":"TRUE"}},"psaumes":[{"id":5,"numero":"16","ref":null,"ref_sefaria":"  ","url":null,"versets":[{"n":"3","he":null,"fr":null,"en":" "},{"n":4.9,"he":12,"arret":{},"fr":"\t","en":"x"},{"n":-0,"arret":"non","he":"א ב"},{"n":2,"he":"un deux","arret":{"avant":null,"note":5}}]},{"id":null,"numero":1e1,"versets":"non"},{"id":"","numero":3000000000,"ref_sefaria":null,"url":" "},{"id":"b","numero":-7.9,"url":" https://y "}]}""",
        "nikkoudTexte" to """{"_meta":{"edition":{"nikkoud_ok":"false"}},"psaumes":[]}""",
        "nikkoudUn" to """{"_meta":{"edition":{"nikkoud_ok":1}},"psaumes":[]}""",
        "nikkoudNul" to """{"_meta":{"edition":{"nikkoud_ok":null}},"psaumes":[]}""",
        "nikkoudVrai" to """{"_meta":{"edition":{"nikkoud_ok":"True"}},"psaumes":[]}""",
        "blocsConvertis" to """{$vide,"psaumes":[],"ouverture":[],"cloture":"x","kavana":null,"priere_rabbi_nathan":{"titre":"x","note":null,"formule":null,"paragraphes":[1,null,true,{"a":"b"},"  ",2.50,[1,"y"]],"paragraphes_fr":"non","paragraphes_en":[[1]]}}""",
        "noteVide" to """{$vide,"psaumes":[],"kavana":{"note":{},"formule":" x ","paragraphes":["א"]}}""",
        "formuleNulle" to """{$vide,"psaumes":[],"cloture":{"formule":null,"titre":{"he":"","fr":"Après"}},"ouverture":{"formule":"\t"}}""",
        "seulementApres" to """{$vide,"psaumes":[],"priere_rabbi_nathan":{},"kavana":{}}""",
        "doublons" to """{$vide,"psaumes":[{"id":"a","numero":16,"versets":[]},{"id":"b","numero":16,"versets":[{"n":1,"he":"x"}]},{"id":"c","numero":0}]}""",
        "clesRepetees" to """{$vide,"psaumes":[{"id":"a","numero":1}],"psaumes":[{"id":"b","numero":2}]}""",
        "autresCles" to """{$vide,"psaumes":[],"OUVERTURE":{"paragraphes":["x"]},"priere":{"paragraphes":["y"]}}""",
        "suite" to """{$vide,"psaumes":[]} suite""",
        "marqueDOrdre" to "﻿" + """{$vide,"psaumes":[]}""",
        "tableau" to """[]""",
        "texteVide" to "",
        "objetVide" to """{}""",
    )

    private fun lecture(nom: String, json: String): Map<String, Any?> {
        val base = linkedMapOf<String, Any?>("nom" to nom, "json" to json)
        val t = try {
            TikkunLoader.parse(json)
        } catch (e: Exception) {
            return base + ("lu" to false)
        }
        return base + linkedMapOf("lu" to true, "tikkun" to lu(t))
    }

    // --- La coupe d'un verset ---------------------------------------------------------------------

    /** [texte du verset, mot d'arrêt] ; null : un verset sans arrêt (Verse(1, "א ב") du test). */
    private val coupes: List<Pair<String, String?>> = listOf(
        "א ב" to null,
        "אַתָּה סֵתֶר לִי מִצַּר תִּצְּרֵנִי" to "מִצַּר",
        "אַתָּה סֵתֶר לִי מִצַּר" to "",
        "מִצַּר תִּצְּרֵנִי" to "מִצַּר",
        "אַתָּה סֵתֶר לִי" to "מִצַּר",
        "" to "מִצַּר",
        "" to "",
        "a b" to "a b c",
        "un deux deux" to "deux",
        "un  \t deux" to "deux",
        "un deux" to "deux",
        "un 　deux" to "deux",
        "un​deux" to "deux",
        "un\u0085deux" to "deux",
        "un\u001Cdeux" to "deux",
        "un     deux" to "deux",
        " deux" to "deux",
        " \t deux" to "deux",
        "שָׁמְרֵנִי אֵל כִּי" to "אֵל",
        "שָׁמְרֵנִי אֵל כִּי" to "אל",
        "שָׁמְרֵנִי אֵל כִּי" to "ל",
        "שָׁמְרֵנִי אֵל כִּי" to "ֵ",
        // Le même mot, dagesh et patah dans deux ordres : Kotlin compare les unités, sans équivalence canonique.
        "אַתָּה מִצַּר" to "מִצַּר",
        "אַתָּה מִצַּר" to "מִצַּר",
        "café café" to "café",
        "café x" to "café",
        "a😀 b" to "b",
        "a 😀b" to "😀",
        "x" to "x",
        "xy" to "y",
    )

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTikkun.kt"),
        "constantes" to linkedMapOf(
            "ouverture" to Tikkun.OUVERTURE, "cloture" to Tikkun.CLOTURE, "kavana" to Tikkun.KAVANA,
            "priere" to Tikkun.PRIERE, "ordre" to Tikkun.ORDRE,
        ),
        "livre" to linkedMapOf(
            "version" to livre.version, "titre" to localise(livre.titre),
            "edition" to linkedMapOf("cle" to livre.edition.key, "titre" to livre.edition.titre,
                "licence" to livre.edition.licence, "nikkoudOk" to livre.edition.nikkoudOk),
            "continuite" to localise(livre.continuite), "versets" to livre.versets,
            "avant" to livre.avant.map { it.cle }, "apres" to livre.apres.map { it.cle },
            "blocs" to livre.blocs.values.map(::blocLivre),
        ),
        "psaumes" to livre.psaumes.map(::psaumeLivre),
        "byNumero" to (listOf(-1, 0, 1, 15, 17, 119, 151, Int.MIN_VALUE, Int.MAX_VALUE) + Tikkun.ORDRE).map { n ->
            linkedMapOf("numero" to n, "id" to livre.byNumero(n)?.id)
        },
        "bloc" to (cles + listOf("", "OUVERTURE", "priere", "autre", "_meta", "psaumes", "kavana ")).map { cle ->
            linkedMapOf("cle" to cle, "trouve" to livre.bloc(cle)?.cle)
        },
        "coupes" to coupes.map { (he, avant) ->
            val v = Verse(1, he, avant?.let { Pause(it, "note") })
            linkedMapOf("he" to he, "avant" to avant, "coupe" to coupe(v))
        },
        "documents" to documents.map { (nom, json) -> lecture(nom, json) },
    )
}
