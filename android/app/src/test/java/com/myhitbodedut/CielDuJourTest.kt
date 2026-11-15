package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate
import kotlin.math.abs

/** Le bandeau « Ciel » de l'accueil (15/11) : un ciel qui suit les vrais zmanim du lieu. */
class CielDuJourTest {

    private val jerusalem = Zmanim.Lieu("Jérusalem", 31.778, 35.235, 754.0, "Asia/Jerusalem")

    private fun canaux(c: Int) = listOf((c shr 16) and 0xFF, (c shr 8) and 0xFF, c and 0xFF)

    @Test
    fun `le ciel change sans saut d une minute a l autre`() {
        listOf(LocalDate.of(2026, 6, 21), LocalDate.of(2026, 12, 21)).forEach { jour ->
            val r = CielDuJour.reperes(Zmanim.jour(jerusalem, jour))!!
            for (m in 0 until CielDuJour.MINUIT - 1) {
                val a = CielDuJour.ciel(m, r)
                val b = CielDuJour.ciel(m + 1, r)
                listOf(a.haut to b.haut, a.bas to b.bas).forEach { (x, y) ->
                    val saut = canaux(x).zip(canaux(y)).maxOf { (u, v) -> abs(u - v) }
                    assertTrue("$jour, minute $m : saut de $saut", saut <= 8)
                }
            }
        }
    }

    @Test
    fun `un jour tres court garde ses teintes dans l ordre`() {
        val court = CielDuJour.Reperes(netz = 630, chatsot = 720, minhaKetana = 780, chkia = 810, tset = 850)
        val cles = CielDuJour.cles(court).map { it.first }
        assertEquals(0, cles.first())
        assertEquals(CielDuJour.MINUIT, cles.last())
        assertTrue(cles.zipWithNext().all { (a, b) -> b > a })
        val tardif = CielDuJour.Reperes(netz = 60, chatsot = 720, minhaKetana = 1100, chkia = 1380, tset = 1430)
        assertTrue(CielDuJour.cles(tardif).map { it.first }.zipWithNext().all { (a, b) -> b > a })
    }

    @Test
    fun `le soleil suit son arc et la nuit allume les etoiles`() {
        val r = CielDuJour.MOYENS
        assertEquals(0f, CielDuJour.ciel(r.netz, r).soleil)
        assertEquals(1f, CielDuJour.ciel(r.chkia, r).soleil)
        assertEquals(0.5f, CielDuJour.ciel(r.chatsot, r).soleil!!, 0.01f)
        assertNull(CielDuJour.ciel(r.netz - 1, r).soleil)
        assertNull(CielDuJour.ciel(r.chkia + 1, r).soleil)
        assertEquals(0f, CielDuJour.ciel(r.chatsot, r).nuit)
        assertEquals(1f, CielDuJour.ciel(0, r).nuit)
        assertEquals(1f, CielDuJour.ciel(r.chkia + 75, r).nuit)
        assertTrue(CielDuJour.ciel(r.chkia + 30, r).nuit in 0.1f..0.9f)
        // Un ciel de midi est clair, celui de minuit sombre : les traits de l'arc en changent.
        assertTrue(CielDuJour.luminance(CielDuJour.ciel(r.chatsot + 60, r).haut) > CielDuJour.luminance(CielDuJour.ciel(0, r).haut))
    }

    @Test
    fun `les zmanim de jerusalem posent les reperes dans l ordre`() {
        val r = CielDuJour.reperes(Zmanim.jour(jerusalem, LocalDate.of(2026, 11, 15)))
        assertNotNull(r)
        r!!
        assertTrue(r.netz < r.chatsot && r.chatsot < r.minhaKetana && r.minhaKetana < r.chkia && r.chkia < r.tset)
        // Le 15 novembre à Jérusalem, le soleil se lève vers 6 h 10 et se couche vers 16 h 40.
        assertTrue("nets ${r.netz}", r.netz in 5 * 60 + 50..6 * 60 + 40)
        assertTrue("chki'a ${r.chkia}", r.chkia in 16 * 60 + 20..17 * 60 + 5)
    }

    @Test
    fun `sans lever ni coucher le ciel prend des heures moyennes`() {
        // Tromsø, nuit polaire : pas de lever le 21 décembre.
        val tromso = Zmanim.Lieu("Tromsø", 69.65, 18.96, 0.0, "Europe/Oslo")
        assertNull(CielDuJour.reperes(Zmanim.jour(tromso, LocalDate.of(2026, 12, 21))))
    }

    @Test
    fun `le prochain zman puis la nuit`() {
        val zmanim = Zmanim.jour(jerusalem, LocalDate.of(2026, 11, 15))
        val chatsot = zmanim.first { it.cle == "chatsot" }.local!!
        assertEquals("chatsot", CielDuJour.prochain(zmanim, chatsot.minusMinutes(1))?.cle)
        val tset = zmanim.first { it.cle == "tset" }.local!!
        assertNull(CielDuJour.prochain(zmanim, tset.plusMinutes(1)))
        CielDuJour.SUIVIS.forEach { assertTrue("$it sans nom", it in CielDuJour.NOMS) }
    }

    @Test
    fun `l accueil porte le bandeau debout et le reglage l eteint`() {
        fun lire(chemin: String) = File("src/main/$chemin").readText()
        val portrait = lire("res/layout/activity_main.xml")
        assertTrue(portrait.contains("<com.myhitbodedut.CielView") && portrait.contains("@+id/ciel_legende\""))
        // Couché, la hauteur manque déjà pour « Commencer » : le bandeau y est, caché.
        val couche = lire("res/layout-land/activity_main.xml")
        assertTrue(couche.substringAfter("<com.myhitbodedut.CielView").substringBefore("/>").contains("android:visibility=\"gone\""))
        assertTrue(lire("java/com/myhitbodedut/MainActivity.kt").contains("ORIENTATION_LANDSCAPE"))
        assertTrue(lire("res/layout/activity_settings.xml").contains("@+id/ciel_switch\""))
        val store = lire("java/com/myhitbodedut/Store.kt")
        assertTrue(store.contains(""".put("accueil_ciel", accueilCiel(context))"""))
        assertTrue(store.contains("""settings.has("accueil_ciel")"""))
        // Le bandeau ne porte pas de texte : rien à y rendre lisible.
        assertFalse(lire("java/com/myhitbodedut/CielView.kt").contains("drawText"))
    }
}
