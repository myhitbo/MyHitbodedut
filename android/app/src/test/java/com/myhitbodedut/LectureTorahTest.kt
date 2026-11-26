package com.myhitbodedut

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * La lecture de la Torah des offices de semaine (26/11). Le calcul est celui du web (web/src/js/lecture-torah.js),
 * que web/test/lecture-torah.test.mjs compare jour par jour à @hebcal/leyning, la référence, et dont il garde la
 * réponse dans web/test/vecteurs_lecture_torah.json : ici, chaque jour de ces vecteurs (septembre 2025 à décembre
 * 2031, six années hébraïques entières), en diaspora, en Israël et à Jérusalem, aux deux offices et dans les trois
 * noussa'h, doit donner exactement la même chose.
 */
class LectureTorahTest {

    private val d = LectureTorah.parse(File("src/main/res/raw/lecture_torah.json").readText())
    private val texte by lazy { LectureTorah.Texte(File("src/main/res/raw/lecture_torah_texte.json").readText()) }

    /** La même ligne que resume() de web/tools/lecture-torah.mjs. */
    private fun resume(l: LectureTorah.Lecture) =
        l.cle + "|" + l.montees.joinToString(",") { "${it.cle}:${it.livre} ${it.debut}-${it.fin}" }

    private val lieux = mapOf("dia" to (false to false), "il" to (true to false), "jer" to (true to true))

    private fun une(iso: String, il: Boolean = false, nusah: String = "ashkenaz", office: String = LectureTorah.CHAHARIT, muk: Boolean = false) =
        LectureTorah.lectures(d, LocalDate.parse(iso), office, il, muk, nusah).single()

    @Test
    fun `chaque jour des vecteurs du web, la meme reponse`() {
        val v = JSONObject(File("../../web/test/vecteurs_lecture_torah.json").readText())
        val jours = v.getJSONObject("jours")
        var date = LocalDate.parse(v.getString("debut"))
        val fin = LocalDate.parse(v.getString("fin"))
        var lectures = 0
        while (!date.isAfter(fin)) {
            for ((lieu, p) in lieux) {
                // Jérusalem n'est écrite que là où elle diffère d'Israël.
                val entree = jours.optJSONObject("$date/$lieu") ?: if (lieu == "jer") jours.optJSONObject("$date/il") else null
                for (office in LectureTorah.OFFICES) {
                    val attendu = entree?.optJSONObject(office)
                    for (nusah in LectureTorah.NUSAH) {
                        val ici = LectureTorah.lectures(d, date, office, p.first, p.second, nusah).map { resume(it) }
                        val liste = attendu?.let { it.optJSONArray(nusah) ?: it.getJSONArray("*") }
                        val att = liste?.let { a -> (0 until a.length()).map { a.getString(it) } }.orEmpty()
                        assertEquals("$date $lieu $office $nusah", att, ici)
                        lectures += ici.size
                    }
                }
            }
            date = date.plusDays(1)
        }
        // 2 313 jours, trois lieux, deux offices, trois noussa'h : 7 428 lectures, des seuls jours de semaine.
        assertEquals(7_428, lectures)
    }

    @Test
    fun `quelques jours, comme le web`() {
        // Jeudi 26/11/2026 : Vayichla'h, trois montées, le troisième « Israël ».
        val l = une("2026-11-26")
        assertEquals("semaine:VAYISHLACH", l.cle)
        assertEquals("Vayichla’h", l.titre.fr)
        assertEquals(listOf("Cohen", "Lévi", "Israël"), l.montees.map { it.libelle.fr })
        // Chabbat et Yom tov : rien, à aucun office.
        for (iso in listOf("2026-11-28", "2026-04-02", "2026-10-03", "2026-09-21")) {
            for (office in LectureTorah.OFFICES) assertTrue("$iso $office", LectureTorah.lectures(d, LocalDate.parse(iso), office, false).isEmpty())
        }
        // 'Hanouka, premier jour en semaine : Edot depuis la bénédiction des cohanim (Kitsour Yalkout Yossef 684:1).
        assertEquals(listOf("6:22-7:3", "7:4-7:11", "7:12-7:17"), une("2025-12-15", nusah = "edot").montees.map { "${it.debut}-${it.fin}" })
        assertEquals(listOf("7:1-7:11", "7:12-7:14", "7:15-7:17"), une("2025-12-15").montees.map { "${it.debut}-${it.fin}" })
        // Min'ha d'un jeûne : le troisième maftir chez Ashkenaz ; chez les Edot « Israël », sauf le 9 Av.
        assertEquals("Maftir", une("2026-12-20", office = LectureTorah.MINHA).montees[2].libelle.fr)
        assertEquals("Israël", une("2026-12-20", nusah = "edot", office = LectureTorah.MINHA).montees[2].libelle.fr)
        assertEquals("Maftir", une("2026-07-23", nusah = "edot", office = LectureTorah.MINHA).montees[2].libelle.fr)
        // 9 Av au matin : maftir dans les trois rites (Choul'han Aroukh O.H. 559:4).
        for (nusah in LectureTorah.NUSAH) assertEquals(nusah, "Maftir", une("2026-07-23", nusah = nusah).montees[2].libelle.fr)
        // Pourim à Jérusalem le 15, ailleurs le 14.
        assertEquals("Shushan Purim", une("2027-03-24", il = true, muk = true).cle)
        assertTrue(LectureTorah.lectures(d, LocalDate.parse("2027-03-23"), LectureTorah.CHAHARIT, true, true, "edot").isEmpty())
        // 'Hol hamoèd Souccot en Israël : les quatre lisent le sacrifice du jour (Kitsour Yalkout Yossef 662:1).
        assertEquals(setOf("29:20-29:22"), une("2026-09-28", il = true).montees.map { "${it.debut}-${it.fin}" }.toSet())
    }

    @Test
    fun `le texte des lectures, les seuls chapitres lus, la Torah seule`() {
        // Le qere (ketiv גיים), la numérotation d'hebcal (Bamidbar 25:19).
        assertTrue(texte.versets("Genesis", "25:23", "25:23").single().texte.contains("שְׁנֵ֤י גוֹיִם֙"))
        assertEquals("וַיְהִ֖י אַחֲרֵ֣י הַמַּגֵּפָ֑ה", texte.versets("Numbers", "25:19", "25:19").single().texte)
        // La lecture de ce jeudi : trois montées, des versets vocalisés avec leurs teamim.
        val l = une("2026-11-26")
        val versets = l.montees.flatMap { texte.versets(it) }
        assertEquals(32, versets.first().chapitre)
        assertTrue(versets.all { v -> v.texte.any { it.code in 0x0591..0x05AF } && v.texte.any { it.code in 0x05B0..0x05BC } })
        // Les cinq livres, et rien d'autre ; les seules lectures des jours de semaine.
        val o = JSONObject(File("src/main/res/raw/lecture_torah_texte.json").readText()).getJSONObject("livres")
        assertEquals(setOf("Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"), o.keys().asSequence().toSet())
        assertEquals(setOf("1", "2", "3", "3_israel", "4", "M"), d.montees.keys)
        assertEquals(d.livres.keys, o.keys().asSequence().toSet())
    }
}
