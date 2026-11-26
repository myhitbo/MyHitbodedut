package com.myhitbodedut

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * « Chnayim mikra : les halakhot » (demande du 26/11, tools/chnayim_mikra/construction.py) : un
 * petit livre du groupe « halakha ». Chaque halakha a son français, son anglais, sa citation
 * hébraïque avec sa référence, son rite (tous, séfarade = Edot, ashkénaze = Ashkenaz et Sfard,
 * marqué dans le texte) ; la table tools/chnayim_mikra/sources.json garde, pour le relecteur,
 * chaque citation exacte et l'adresse où elle a été lue. Le site lit le même livres.json
 * (web/test/chnayim-mikra.test.mjs vérifie le même livre de son côté).
 */
class ChnayimMikraTest {

    private val brut = JSONObject(File("src/main/res/raw/livre_chnayim_mikra.json").readText())
    private val livre = SiddurLoader.parse(brut.toString()).texte("chnayim_mikra")!!
    private val texte = brut.getJSONArray("textes").getJSONObject(0)
    private val table = JSONObject(File("../../tools/chnayim_mikra/sources.json").readText())

    /** Les paragraphes-halakhot, avec leurs champs que SiddurLoader ne lit pas (id, rite, refs). */
    private val halakhot: List<JSONObject> = buildList {
        val sections = texte.getJSONArray("sections")
        for (i in 0 until sections.length()) {
            val blocs = sections.getJSONObject(i).getJSONArray("blocs")
            for (j in 0 until blocs.length()) blocs.getJSONObject(j).takeIf { it.has("id") }?.let { add(it) }
        }
    }

    @Test
    fun `le livre se lit, dans le groupe halakha, avec ses trois titres`() {
        assertEquals("halakha", livre.groupe)
        assertEquals("הלכות שנים מקרא ואחד תרגום", livre.titre.he)
        assertEquals("Chnayim mikra : les halakhot", livre.titre.fr)
        assertEquals("Shnayim mikra: the laws", livre.titre.en)
        // Une introduction, puis sept chapitres, chacun titré dans les trois langues.
        assertEquals(8, livre.sections.size)
        livre.sections.forEach { s -> assertTrue(s.titre, s.titre.isNotBlank() && !s.titreFr.isNullOrBlank() && !s.titreEn.isNullOrBlank()) }
        // Toutes les traductions sont là : pas d'avis de traduction partielle, mais celui de la traduction automatique.
        assertEquals(livre.sections.size, livre.chapitresTraduits())
        assertTrue(livre.traductionAuto)
    }

    @Test
    fun `chaque halakha a son francais, son anglais, son hebreu, sa reference et son rite`() {
        assertTrue("${halakhot.size} halakhot", halakhot.size in 15..35)
        assertEquals((1..halakhot.size).map { "chm-%02d".format(it) }, halakhot.map { it.getString("id") })
        val rites = setOf("tous", "sefarade", "ashkenaze")
        halakhot.forEachIndexed { i, h ->
            val id = h.getString("id")
            for (champ in listOf("t", "fr", "en")) assertTrue("$id $champ", h.optString(champ).isNotBlank())
            assertTrue(id, h.getString("rite") in rites)
            assertTrue(id, h.getJSONArray("refs").length() > 0)
            // Le numéro en tête : la lettre en hébreu, le chiffre en français et en anglais.
            assertTrue(id, h.getString("t").startsWith("<b>${Reference.lettres(i + 1).replace("׳", "").replace("״", "")}</b>"))
            assertTrue(id, h.getString("fr").startsWith("<b>${i + 1}</b>") && h.getString("en").startsWith("<b>${i + 1}</b>"))
            // Les références en fin de traduction, et l'hébreu cite ses sources entre parenthèses.
            assertTrue(id, Regex("""<small>\[[^\]]+]</small>$""").containsMatchIn(h.getString("fr")))
            assertTrue(id, Regex("""<small>\[[^\]]+]</small>$""").containsMatchIn(h.getString("en")))
            assertTrue(id, h.getString("t").contains("<small>(") && h.getString("t").endsWith(")</small>"))
        }
        // Les deux camps sont représentés, et des halakhot valent pour tous.
        assertEquals(rites, halakhot.map { it.getString("rite") }.toSet())
    }

    /** Le livre ne sait pas filtrer par rite : chaque halakha propre à un rite le dit en tête, dans les trois langues. */
    @Test
    fun `le rite se lit dans le texte`() {
        val etiquettes = mapOf(
            "sefarade" to listOf("[ספרדים – עדות המזרח]", "[Séfarades – rite Edot]", "[Sephardim – Edot rite]"),
            "ashkenaze" to listOf("[אשכנזים – נוסח אשכנז ונוסח ספרד]", "[Ashkénazes – rites Ashkenaz et Sfard]", "[Ashkenazim – Ashkenaz and Sfard rites]"),
        )
        halakhot.forEach { h ->
            val textes = listOf(h.getString("t"), h.getString("fr"), h.getString("en"))
            val attendues = etiquettes[h.getString("rite")]
            if (attendues == null) etiquettes.values.flatten().forEach { e -> assertFalse(h.getString("id"), textes.any { it.contains(e) }) }
            else textes.zip(attendues).forEach { (t, e) -> assertTrue("${h.getString("id")} : $e", t.substringAfter("</b>").startsWith(" <small>$e</small>")) }
        }
        // Les rites de l'application que chaque étiquette désigne.
        val r = texte.getJSONObject("rites")
        assertEquals(listOf("edot"), Json.strings(r.getJSONArray("sefarade")))
        assertEquals(listOf("ashkenaz", "sefard"), Json.strings(r.getJSONArray("ashkenaze")))
        assertEquals(Nusah.entries.map { it.cle }.toSet(), Json.strings(r.getJSONArray("tous")).toSet())
    }

    /** L'espagnol et l'arabe tunisien n'ont pas de traduction des textes : l'hébreu, comme pour les autres livres. */
    @Test
    fun `en espagnol et en arabe, l hebreu`() {
        halakhot.forEach { h -> assertFalse(h.has("es") || h.has("ar")) }
        val h = livre.sections[1].blocs.first()
        for (langue in listOf("es", "ar")) {
            assertEquals(LanguesTexte.Mode.HE, LanguesTexte.defaut(langue))
            assertEquals(listOf("he" to h.texte), LanguesTexte.textes(LanguesTexte.defaut(langue), h.texte, h.fr, h.en))
            assertEquals(livre.titre.he, livre.titre.forLanguage(langue))
        }
        assertEquals(listOf("he" to h.texte, "fr" to h.fr), LanguesTexte.textes(LanguesTexte.defaut("fr"), h.texte, h.fr, h.en))
    }

    /** Chaque citation affichée est celle de la table de vérification, et chaque référence y est. */
    @Test
    fun `la table de verification suit le livre`() {
        val lignes = table.getJSONArray("halakhot")
        assertEquals(halakhot.size, lignes.length())
        val sefaria = setOf("ber", "sa", "rema", "mb", "kh", "ksa", "bih", "rambam", "sahr")
        val modernes = setOf("hid", "kav", "malka")
        halakhot.forEachIndexed { i, h ->
            val l = lignes.getJSONObject(i)
            val id = h.getString("id")
            assertEquals(id, l.getString("id"))
            assertEquals(id, h.getString("rite"), l.getString("rite"))
            val refs = l.getJSONArray("references")
            assertTrue(id, refs.length() > 0)
            for (k in 0 until refs.length()) {
                val r = refs.getJSONObject(k)
                val src = r.getString("source")
                assertTrue("$id $src", r.getString("reference").isNotBlank() && r.getString("licence").isNotBlank())
                when (src) {
                    in sefaria -> assertTrue("$id $src", r.getString("lu_via").startsWith("https://www.sefaria.org/api/v3/texts/") && r.has("citation"))
                    "kyy" -> assertTrue("$id $src", r.getString("lu_via").contains("livre_yalkut_yosef_kitsour.json") && r.has("citation"))
                    in modernes -> {
                        assertTrue("$id $src", r.getString("url").startsWith("https://") && (r.has("citation") || r.has("passage_resume")))
                        assertEquals("paraphrase avec référence (œuvre protégée)", r.getString("nature"))
                        // Une œuvre protégée : une courte phrase citée au plus.
                        if (r.has("citation")) assertTrue("$id : citation trop longue", r.getString("citation").split(" ").size <= 16)
                    }
                    else -> throw AssertionError("$id : source inconnue $src")
                }
                if (r.has("citation")) assertTrue("$id : « ${r.getString("citation").take(40)} » absente de l'hébreu", h.getString("t").contains(r.getString("citation")))
                assertTrue("$id : ${r.getString("reference")}", Json.strings(h.getJSONArray("refs")).contains(r.getString("reference")))
            }
        }
    }

    /** Les sources et licences sont dans le _meta du fichier, et le livre crédite celles qui le demandent. */
    @Test
    fun `sources et licences dans le meta et dans le livre`() {
        val meta = brut.getJSONObject("_meta")
        val sources = Json.strings(meta.getJSONArray("sources"))
        for (mot in listOf("Choul'han Aroukh O.H. 285", "Michna Beroura 285", "Kaf ha'Haïm", "Kitsour Choul'han Aroukh 72", "Ben Ich 'Haï",
            "Rambam", "Kehot Publication Society (via API Sefaria), CC-BY-NC", "Kitsour Yalkout Yossef 285", "Hidabroot"))
            assertTrue(mot, sources.any { it.contains(mot) })
        assertEquals("tools/chnayim_mikra/sources.json", meta.getString("verification"))
        // Les autres livres ne reçoivent pas ces sources : le _meta propre au livre reste dans son fichier.
        val titres = JSONObject(File("src/main/res/raw/livres_titres.json").readText())
        assertFalse(Json.strings(titres.getJSONObject("_meta").getJSONArray("sources")).any { it.contains("Kehot") })
        assertFalse(JSONObject(File("src/main/res/raw/livre_yalkut_yosef_kitsour.json").readText()).getJSONObject("_meta").toString().contains("Kehot"))
        // L'introduction crédite le Choul'han Aroukh haRav (CC BY-NC) et le Yalkout Yossef, et dit qu'il ne tranche rien.
        val intro = livre.sections.first().blocs.single()
        for (t in listOf(intro.texte, intro.fr!!, intro.en!!)) {
            assertTrue(t.contains("CC BY-NC") && t.contains("CC BY-NC-SA 2.5") && t.contains("Kehot"))
        }
        assertTrue(intro.texte.contains("הרב יצחק יוסף שליט״א"))
        assertTrue(intro.fr!!.contains("ne tranche rien") && intro.en!!.contains("decides nothing"))
    }

    @Test
    fun `le livre est dans la bibliotheque, sur Android comme sur le site`() {
        assertEquals(R.raw.livre_chnayim_mikra, LivresBruts.parId["chnayim_mikra"])
        val index = SiddurLoader.parse(File("src/main/res/raw/livres_titres.json").readText())
        val entree = index.texte("chnayim_mikra")!!
        assertEquals("halakha", entree.groupe)
        assertEquals(8, entree.chapitres)
        assertTrue(index.du("halakha").map { it.id }.containsAll(listOf("yalkut_yosef_kitsour", "chnayim_mikra")))
        // La bibliothèque montre chaque livre de chaque groupe de l'index, sans liste à tenir.
        val bibliotheque = File("src/main/java/com/myhitbodedut/LibraryActivity.kt").readText()
        assertTrue(bibliotheque.contains("livres.groupes.flatMap { g -> listOf(Row.TitreLivres(g.titre)) + livres.du(g.cle).map { Row.Livre(it) } }"))
        // Le site construit sa table et ses fichiers de livres depuis la même source, livre par livre.
        val build = File("../../web/build.mjs").readText()
        assertTrue(build.contains("readFileSync(join(ANDROID, 'livres', 'livres.json')"))
        assertTrue(build.contains("for (const t of livres.textes) {"))
        assertTrue(build.contains("const { sections, _meta, ...entete } = t;"))
        // Ni l'un ni l'autre n'emporte le _meta d'un livre dans l'index.
        val source = JSONObject(File("src/main/livres/livres.json").readText()).getJSONArray("textes")
        val chnayim = (0 until source.length()).map { source.getJSONObject(it) }.single { it.getString("id") == "chnayim_mikra" }
        assertTrue(chnayim.has("_meta"))
        val enTete = JSONArray(File("src/main/res/raw/livres_titres.json").readText().let { JSONObject(it).getJSONArray("textes").toString() })
        assertFalse((0 until enTete.length()).map { enTete.getJSONObject(it) }.single { it.getString("id") == "chnayim_mikra" }.has("_meta"))
    }
}
