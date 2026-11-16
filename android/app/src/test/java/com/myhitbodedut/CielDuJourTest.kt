package com.myhitbodedut

import com.myhitbodedut.CielDuJour.Phase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Le ciel du Jour (étape 3 de la refonte, 14/11) : la phase d'après les zmanim, ou d'après
 * l'heure sans lieu ; et ce que l'accueil en fait. Les mêmes cas côté web (ciel.test.mjs).
 */
class CielDuJourTest {

    private val zone = ZoneId.of("Asia/Jerusalem")
    private fun a(h: Int, m: Int) = ZonedDateTime.of(2026, 11, 12, h, m, 0, 0, zone)

    // Un jour de novembre à Jérusalem, en chiffres ronds.
    private val alot = a(5, 0)
    private val lever = a(6, 20)
    private val chkia = a(16, 40)
    private val tset = a(17, 5)

    private fun phase(h: Int, m: Int) = CielDuJour.phase(a(h, m), alot, lever, chkia, tset)

    @Test
    fun `les zmanim bornent les quatre ciels`() {
        assertEquals(Phase.NUIT, phase(4, 59))
        assertEquals(Phase.AUBE, phase(5, 0))
        assertEquals(Phase.AUBE, phase(7, 19))
        assertEquals(Phase.JOUR, phase(7, 20))
        assertEquals(Phase.JOUR, phase(15, 39))
        assertEquals(Phase.COUCHER, phase(15, 40))
        assertEquals(Phase.COUCHER, phase(17, 4))
        assertEquals(Phase.NUIT, phase(17, 5))
        assertEquals(Phase.NUIT, phase(23, 59))
    }

    @Test
    fun `un jour trop court passe de l aube au coucher`() {
        val p = { h: Int, m: Int -> CielDuJour.phase(a(h, m), a(8, 0), a(9, 0), a(10, 30), a(11, 30)) }
        assertEquals(Phase.AUBE, p(9, 59))
        assertEquals(Phase.COUCHER, p(10, 0))
        assertEquals(Phase.NUIT, p(11, 30))
    }

    @Test
    fun `sans zman, l heure decide`() {
        assertEquals(Phase.JOUR, CielDuJour.phase(a(12, 0), null, lever, chkia, tset))
        assertEquals(Phase.NUIT, CielDuJour.phase(a(22, 0), alot, lever, chkia, null))
        listOf(
            LocalTime.of(4, 59) to Phase.NUIT, LocalTime.of(5, 0) to Phase.AUBE, LocalTime.of(7, 59) to Phase.AUBE,
            LocalTime.of(8, 0) to Phase.JOUR, LocalTime.of(16, 59) to Phase.JOUR, LocalTime.of(17, 0) to Phase.COUCHER,
            LocalTime.of(19, 59) to Phase.COUCHER, LocalTime.of(20, 0) to Phase.NUIT,
        ).forEach { (h, attendu) -> assertEquals("$h", attendu, CielDuJour.parHeure(h)) }
    }

    @Test
    fun `chaque ciel a sa palette et son icone`() {
        Phase.values().forEach {
            assertTrue("$it sans palette", it in CielDuJour.PALETTES)
            CielDuJour.icone(it)
        }
        listOf("ic_ciel", "ic_ciel_aube", "ic_ciel_jour", "ic_ciel_coucher").forEach {
            assertTrue("$it manque", File("src/main/res/drawable/$it.xml").exists())
        }
    }

    @Test
    fun `l accueil met le ciel dans la plaque et les lanternes dans la semaine`() {
        val accueil = File("src/main/java/com/myhitbodedut/MainActivity.kt").readText()
        // Le ciel derrière le hassid, le disque clair derrière les chiffres.
        assertTrue(accueil.contains("plaque.background = cielDessin"))
        assertTrue(accueil.contains("plaque.setBackgroundResource(R.drawable.bg_gauge_plate)"))
        // Revu chaque minute tant que l'accueil est devant, arrêté en le quittant.
        assertTrue(accueil.contains("postDelayed(veilleCiel, CIEL_MS)") && accueil.contains("removeCallbacks(veilleCiel)"))
        listOf("lanterne_allumee", "lanterne_eteinte", "lanterne_aujourdhui", "bougies_chabbat").forEach {
            assertTrue("$it n'est pas employée", accueil.contains("R.drawable.$it"))
        }
        val cellule = File("src/main/res/layout/item_day.xml").readText()
        assertTrue(cellule.contains("@+id/day_lanterne\"") && cellule.contains("android:importantForAccessibility=\"no\""))
        // La plaque reste ronde : le dessin du ciel donne un contour ovale.
        assertTrue(File("src/main/java/com/myhitbodedut/CielDessin.kt").readText().contains("outline.setOval(bounds)"))
    }
}
