package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** Les rappels de tefila (16/10) : les dates des changements, en Israël et en diaspora. */
class RappelsTefilaTest {

    private fun rappels(d: LocalDate, israel: Boolean, avance: Int = 3) =
        RappelsTefila.prochains(d, avance) { CalendrierJuif.jour(it, israel) }

    @Test
    fun `la benediction d hiver en Israel le 7 Hechvan 5787, dimanche 18 octobre 2026`() {
        // CalJ (Jérusalem) l'annonce pour Motsaé Chabbat, à Arvit : le soir qui ouvre le 7 'Hechvan.
        val r = rappels(LocalDate.of(2026, 10, 16), israel = true)
        assertEquals(listOf(RappelsTefila.Rappel(RappelsTefila.Type.PLUIE_DEBUT, LocalDate.of(2026, 10, 18))), r)
        assertEquals(7, CalendrierJuif.jour(LocalDate.of(2026, 10, 18), true).jourHebreu)
    }

    @Test
    fun `en diaspora, rien en octobre, et le debut en decembre`() {
        assertTrue(rappels(LocalDate.of(2026, 10, 16), israel = false).none { it.type == RappelsTefila.Type.PLUIE_DEBUT })
        val dec = rappels(LocalDate.of(2026, 12, 2), israel = false, avance = 6).filter { it.type == RappelsTefila.Type.PLUIE_DEBUT }
        // Premier jour le samedi 5 décembre : pas d'Arvit de vendredi soir, on commence à motsaé Chabbat
        // (rappel daté du dimanche 6, FCALENDRIER-04) ; il reste affiché le samedi.
        assertEquals(listOf(LocalDate.of(2026, 12, 6)), dec.map { it.date })
        for (jour in listOf(2, 4, 5)) {
            val r = rappels(LocalDate.of(2026, 12, jour), israel = false).filter { it.type == RappelsTefila.Type.PLUIE_DEBUT }
            assertEquals("5/12/2026 vu le $jour", listOf(LocalDate.of(2026, 12, 6)), r.map { it.date })
        }
        assertTrue(rappels(LocalDate.of(2026, 12, 6), israel = false).none { it.type == RappelsTefila.Type.PLUIE_DEBUT })
        // 2031 : le premier jour est le samedi 6 décembre, rappel au 7.
        val r2031 = rappels(LocalDate.of(2031, 12, 5), israel = false).filter { it.type == RappelsTefila.Type.PLUIE_DEBUT }
        assertEquals(listOf(LocalDate.of(2031, 12, 7)), r2031.map { it.date })
    }

    @Test
    fun `Pessah 5787 en Israel - fin de la pluie et de machiv harouah, debut de l omer`() {
        // 15 Nissan 5787 : jeudi 22 avril 2027.
        val r = rappels(LocalDate.of(2027, 4, 20), israel = true).map { it.type to it.date }.toSet()
        val p = LocalDate.of(2027, 4, 22)
        assertTrue(r.contains(RappelsTefila.Type.PLUIE_FIN to p))
        assertTrue(r.contains(RappelsTefila.Type.GUECHEM_FIN to p))
        assertTrue(r.contains(RappelsTefila.Type.OMER to p.plusDays(1)))
    }

    @Test
    fun `Roch Hachana et Chemini Atseret 5788`() {
        // 1 Tichri 5788 : samedi 2 octobre 2027 ; 22 Tichri : samedi 23 octobre 2027.
        assertTrue(rappels(LocalDate.of(2027, 9, 30), israel = false).any { it.type == RappelsTefila.Type.DIX_JOURS && it.date == LocalDate.of(2027, 10, 2) })
        assertTrue(rappels(LocalDate.of(2027, 10, 21), israel = true).any { it.type == RappelsTefila.Type.GUECHEM_DEBUT && it.date == LocalDate.of(2027, 10, 23) })
    }

    @Test
    fun `nord et sud, Israel et diaspora`() {
        val chemini = LocalDate.of(2027, 10, 21) // deux jours avant le 22 Tichri 5788
        val types = { israel: Boolean, sud: Boolean ->
            RappelsTefila.prochains(chemini, 3, sansGuechem = sud) { CalendrierJuif.jour(it, israel) }.map { it.type }.toSet() }
        // Nord : Israël et diaspora annoncent מַשִּׁיב הָרוּחַ ; sud (Edot) : rien à annoncer.
        assertTrue(RappelsTefila.Type.GUECHEM_DEBUT in types(true, false))
        assertTrue(RappelsTefila.Type.GUECHEM_DEBUT in types(false, false))
        assertTrue(RappelsTefila.Type.GUECHEM_DEBUT !in types(false, true))
        // La demande de pluie suit la diaspora au sud : début en décembre, pas le 7 'Hechvan.
        val hechvan = RappelsTefila.prochains(LocalDate.of(2026, 10, 16), 3, sansGuechem = true) { CalendrierJuif.jour(it, false) }
        assertTrue(hechvan.none { it.type == RappelsTefila.Type.PLUIE_DEBUT })
    }

    @Test
    fun `rappel de fin de machiv harouah - l ashkenaz de diaspora cesse a Minha`() {
        // Audit du 16/11 : Rema 114:3 ; Michna Beroura 114:3.
        assertEquals("rappel_guechem_fin_ashkenaz", RappelsTefila.cleGuechemFin(Nusah.ASHKENAZ, false))
        assertEquals("rappel_guechem_fin", RappelsTefila.cleGuechemFin(Nusah.ASHKENAZ, true))
        assertEquals("rappel_guechem_fin", RappelsTefila.cleGuechemFin(Nusah.SEFARD, false))
        assertEquals("rappel_guechem_fin", RappelsTefila.cleGuechemFin(Nusah.EDOT, false))
        val xml = listOf("values", "values-en", "values-iw").map { File("src/main/res/$it/strings.xml").readText() }
        xml.forEach { assertTrue(it.contains("name=\"rappel_guechem_fin_ashkenaz\"")) }
        assertFalse(xml[0].contains("name=\"rappel_guechem_fin_ashkenaz\">%1\$s, à Moussaf du premier jour de Pessa’h, on cesse"))
    }
}
