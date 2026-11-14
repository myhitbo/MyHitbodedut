package com.myhitbodedut

import com.kosherjava.zmanim.hebrewcalendar.JewishDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * La halakha courte du jour (13/10, tools/yalkut_yosef_construction.py) : une
 * sélection du Yalkut Yosef, jamais le livre entier, deux se'ifim par jour selon
 * la période. Les mêmes vecteurs que web/test/yalkut.test.mjs.
 */
class YalkutYosefTest {

    private val livre = YalkutYosef.parse(File("src/main/res/raw/yalkut_yosef.json").readText())

    @Test
    fun `une selection de halakhot courtes`() {
        assertEquals(
            setOf("ordinaire", "chabbat", "roch_hodech", "pessah", "omer", "chavouot", "bein_hametsarim", "eloul", "kippour",
                "soukkot", "hanouka", "tou_bichvat", "pourim"),
            livre.periodes.keys,
        )
        livre.periodes.forEach { (p, seifs) ->
            assertTrue(p, seifs.size >= 4)
            seifs.forEach { assertTrue("$p ${it.siman} ${it.lettre}", it.texte.isNotBlank() && it.texte.length <= 420 && it.siman.isNotBlank()) }
        }
    }

    @Test
    fun `chaque jour de trois annees a ses deux halakhot, et elles changent`() {
        var avant: String? = null
        var d = LocalDate.of(2025, 9, 1)
        while (d.isBefore(LocalDate.of(2028, 9, 1))) {
            listOf(false, true).forEach { assertEquals("$d $it", YalkutYosef.PAR_JOUR, YalkutYosef.pour(livre, d, it).size) }
            val ici = YalkutYosef.pour(livre, d, false).joinToString("|") { YalkutYosef.source(it) }
            assertNotEquals(d.toString(), avant, ici)
            avant = ici
            d = d.plusDays(1)
        }
    }

    @Test
    fun `les fenetres de fete`() {
        assertEquals("pourim", YalkutYosef.fenetre(JewishDate.ADAR, 14, false))
        assertEquals("pourim", YalkutYosef.fenetre(JewishDate.ADAR_II, 14, true))
        assertNull(YalkutYosef.fenetre(JewishDate.ADAR, 14, true))
        assertEquals("pessah", YalkutYosef.fenetre(JewishDate.NISSAN, 15, false))
        assertEquals("omer", YalkutYosef.fenetre(JewishDate.IYAR, 29, false))
        assertEquals("chavouot", YalkutYosef.fenetre(JewishDate.SIVAN, 6, false))
        assertEquals("bein_hametsarim", YalkutYosef.fenetre(JewishDate.AV, 9, false))
        assertEquals("eloul", YalkutYosef.fenetre(JewishDate.TISHREI, 1, false))
        assertEquals("kippour", YalkutYosef.fenetre(JewishDate.TISHREI, 10, false))
        assertEquals("soukkot", YalkutYosef.fenetre(JewishDate.TISHREI, 15, false))
        assertEquals("hanouka", YalkutYosef.fenetre(JewishDate.TEVES, 2, false))
        assertEquals("tou_bichvat", YalkutYosef.fenetre(JewishDate.SHEVAT, 15, false))
        assertNull(YalkutYosef.fenetre(JewishDate.CHESHVAN, 10, false))
        assertEquals("pessah" to 0, YalkutYosef.periode(LocalDate.of(2027, 3, 25), false)) // 16 Adar II 5787
        assertEquals("pourim", YalkutYosef.periode(LocalDate.of(2027, 3, 24), false).first)
        assertEquals("roch_hodech", YalkutYosef.periode(LocalDate.of(2026, 10, 12), false).first)
        assertEquals("chabbat", YalkutYosef.periode(LocalDate.of(2026, 10, 23), false).first)
        assertEquals("ordinaire", YalkutYosef.periode(LocalDate.of(2026, 10, 21), false).first)
        assertTrue(YalkutYosef.recherche(livre, "ציצית").isNotEmpty())
    }

    @Test
    fun `une fenetre est repartie sur toute sa liste, les lois de la fete a la fin`() {
        val siman = { d: LocalDate -> YalkutYosef.pour(livre, d, false).map { it.siman } }
        // Soukkot 5787 : 15 Tichri (26/09/2026), la soukka ; Hochaana Rabba (02/10), le loulav.
        assertEquals(13, YalkutYosef.longueur(LocalDate.of(2026, 10, 2), false))
        assertTrue(siman(LocalDate.of(2026, 9, 26)).all { it.contains("תרכט") })
        assertTrue(siman(LocalDate.of(2026, 10, 2)).all { it.contains("תרנא") })
        // 6 Sivan 5787 (11/06/2027) : Chavouot, plus la sefirat haomer.
        assertTrue(siman(LocalDate.of(2027, 6, 11)).all { it.contains("תצד") })
        // 22 Nissan 5787 (29/04/2027) : les quatre coupes, plus la bedikat 'hamets.
        assertTrue(siman(LocalDate.of(2027, 4, 29)).all { it.contains("תעב") })
        assertTrue(siman(LocalDate.of(2027, 3, 25)).all { it.contains("תלג") })
        // Chaque se'if de chaque fenetre sort au moins une fois en trois ans, sauf si la liste depasse deux fois la fenetre.
        val vus = HashSet<String>()
        var d = LocalDate.of(2025, 9, 1)
        while (d.isBefore(LocalDate.of(2028, 9, 1))) { YalkutYosef.pour(livre, d, false).forEach { vus.add("${it.siman}|${it.lettre}|${it.texte.take(20)}") }; d = d.plusDays(1) }
        listOf("soukkot", "chavouot").forEach { p -> assertTrue(p, livre.periodes.getValue(p).count { "${it.siman}|${it.lettre}|${it.texte.take(20)}" in vus } >= 8) }
    }
}
