package com.myhitbodedut

import com.kosherjava.zmanim.util.NOAACalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone
import kotlin.math.abs

/**
 * Le ciel continu (24/11) : le soleil (Soleil, contre NOAACalculator de KosherJava), les clés de
 * couleurs (CielContinu) sans saut d'une minute à l'autre, les étapes du jour (nuit noire, bleu du
 * crépuscule, rouges, jaunes, heure dorée, bleu du jour, orange, violet), la lune du mois hébreu,
 * et l'arc de l'astre (PlanCiel.arc). Les mêmes cas côté web (ciel.test.mjs).
 */
class CielContinuTest {

    private fun canal(c: Int, d: Int) = (c shr d) and 0xFF

    @Test
    fun `la hauteur du soleil est celle de KosherJava`() {
        val lieux = listOf(31.778 to 35.235, 48.857 to 2.352, 40.713 to -74.006, -33.869 to 151.209, 59.33 to 18.07)
        val utc = TimeZone.getTimeZone("UTC")
        lieux.forEach { (lat, lon) ->
            for (jour in listOf(15, 100, 172, 265, 355)) {
                for (heure in 0 until 24 step 3) {
                    val cal = Calendar.getInstance(utc).apply { clear(); set(2026, Calendar.JANUARY, 1, heure, 17, 0); add(Calendar.DAY_OF_YEAR, jour) }
                    val attendu = NOAACalculator.getSolarElevation(cal, lat, lon)
                    val calcule = Soleil.position(cal.timeInMillis, lat, lon).hauteur
                    assertTrue("$lat,$lon jour $jour $heure h : $calcule au lieu de $attendu", abs(calcule - attendu) < 0.6)
                }
            }
        }
    }

    @Test
    fun `le soleil se leve, passe au meridien et se couche`() {
        // Jérusalem, 24 novembre 2026 (UTC+2) : lever vers 6 h 20, midi vers 11 h 33 (37,6°), coucher vers 16 h 32.
        val jerusalem = { h: Int, m: Int -> Soleil.position(java.time.ZonedDateTime.of(2026, 11, 24, h, m, 0, 0, java.time.ZoneId.of("Asia/Jerusalem")).toInstant().toEpochMilli(), 31.778, 35.235) }
        val matin = jerusalem(6, 20)
        assertTrue(abs(matin.hauteur) < 1.5 && matin.matin && matin.progresJour < 0.03)
        val midi = jerusalem(11, 33)
        assertTrue(midi.hauteur in 36.0..39.0 && abs(midi.progresJour - 0.5) < 0.02)
        val soir = jerusalem(16, 32)
        assertTrue(abs(soir.hauteur) < 1.5 && !soir.matin && soir.progresJour > 0.97)
        val minuit = jerusalem(23, 33)
        assertTrue(minuit.hauteur < -60 && !minuit.jour && abs(minuit.progresNuit - 0.5) < 0.03)
    }

    @Test
    fun `sans lieu, un soleil moyen sur les heures d avant`() {
        assertEquals(0.0, Soleil.parHeure(6.5).hauteur, 1e-9)
        assertEquals(0.0, Soleil.parHeure(18.5).hauteur, 1e-9)
        assertEquals(50.0, Soleil.parHeure(12.5).hauteur, 1e-9)
        // L'aube commençait à 5 h et le coucher finissait à 20 h : le soleil y est vers −19°.
        assertEquals(-19.1, Soleil.parHeure(5.0).hauteur, 0.2)
        assertEquals(-19.1, Soleil.parHeure(20.0).hauteur, 0.2)
        assertTrue(Soleil.parHeure(9.0).matin && !Soleil.parHeure(15.0).matin)
        assertEquals(0.5, Soleil.parHeure(12.5).progresJour, 1e-9)
        assertEquals(0.5, Soleil.parHeure(0.5).progresNuit, 1e-9)
    }

    @Test
    fun `aucune minute ne saute`() {
        listOf(true, false).forEach { matin ->
            var avant = CielContinu.brutes(-30.0, matin)
            var e = -30.0
            while (e <= 70.0) {
                val c = CielContinu.brutes(e, matin)
                for (i in 0..2) for (d in intArrayOf(0, 8, 16)) {
                    assertTrue("$matin $e° : ${CielContinu.hexa(avant[i])} → ${CielContinu.hexa(c[i])}", abs(canal(c[i], d) - canal(avant[i], d)) <= 8)
                }
                avant = c
                e += 0.25
            }
        }
        // Un quart de degré, c'est une minute ou deux de soleil : les dosages aussi glissent.
        var e = -30.0
        while (e <= 70.0) {
            listOf(CielContinu::etoiles, CielContinu::nuages, CielContinu::rayons, CielContinu::soleilVisible, CielContinu::luneVisible, CielContinu::chaleur).forEach { f ->
                assertTrue("$e°", abs(f(e + 0.25) - f(e)) < 0.1)
            }
            e += 0.25
        }
    }

    @Test
    fun `les etapes du jour`() {
        fun lum(c: Int) = TeintesCiel.luminance(c)
        // La nuit noire, sous −18°.
        assertTrue(CielContinu.brutes(-25.0, true).all { lum(it) < 0.03 })
        // Le lever et le coucher : l'horizon rouge-orangé, le soir plus orangé que le matin.
        listOf(true, false).forEach { matin ->
            val h = CielContinu.brutes(0.0, matin)[2]
            assertTrue(canal(h, 16) > canal(h, 8) && canal(h, 8) > canal(h, 0))
        }
        assertTrue(canal(CielContinu.brutes(0.0, false)[2], 8) < canal(CielContinu.brutes(0.0, true)[2], 8))
        // Les jaunes du matin, l'heure dorée.
        val jaune = CielContinu.brutes(3.0, true)[2]
        assertTrue(canal(jaune, 16) > 240 && canal(jaune, 8) > 200 && canal(jaune, 0) < 180)
        // Le bleu du jour.
        CielContinu.brutes(40.0, true).forEach { assertTrue(canal(it, 0) > canal(it, 16)) }
        // Le violet du crépuscule le soir.
        val violet = CielContinu.brutes(-4.0, false)[1]
        assertTrue(canal(violet, 0) > canal(violet, 8) && canal(violet, 16) > canal(violet, 8))
        // Les étoiles : aucune à −4°, toutes à −14° ; les rayons seulement à l'heure dorée.
        assertEquals(0.0, CielContinu.etoiles(-4.0), 1e-9)
        assertEquals(1.0, CielContinu.etoiles(-14.0), 1e-9)
        assertEquals(0.0, CielContinu.rayons(-2.0), 1e-9)
        assertEquals(1.0, CielContinu.rayons(3.0), 1e-9)
        assertEquals(0.0, CielContinu.rayons(12.0), 1e-9)
        // Les nuages, presque rien la nuit ; blancs le jour, dorés bas.
        assertTrue(CielContinu.nuages(-20.0) < 0.2 && CielContinu.nuages(5.0) == 1.0)
        assertEquals(0xFFFFFFFF.toInt(), CielContinu.NUAGE_CORPS.a(30.0))
        val dore = CielContinu.NUAGE_BORD.a(3.0)
        assertTrue(canal(dore, 16) > canal(dore, 0) + 80)
    }

    @Test
    fun `la lune suit le mois hebreu`() {
        assertTrue(CielContinu.lune(1).eclairee < 0.02 && CielContinu.lune(2).eclairee < 0.06 && CielContinu.lune(2).croissante)
        assertEquals(0.5, CielContinu.lune(8).eclairee, 0.08)
        assertTrue(CielContinu.lune(15).eclairee > 0.98)
        assertTrue(!CielContinu.lune(22).croissante)
        assertEquals(0.5, CielContinu.lune(23).eclairee, 0.1)
        assertTrue(CielContinu.lune(29).eclairee < 0.04)
    }

    // --- L'arc ------------------------------------------------------------------------------

    private val d = 2.625f
    private val largeur = 411 * d
    private val jauge = PlanCiel.Zone(75.5f * d, 180 * d, 335.5f * d, 440 * d)
    private val textes = listOf(PlanCiel.Zone(24 * d, 64 * d, 387 * d, 160 * d), PlanCiel.Zone(24 * d, 444 * d, 387 * d, 520 * d))
    private val r = 14 * d
    private val couronne = r * PlanCiel.COURONNE

    private fun arc(p: Double, h: Double) = PlanCiel.arc(p, h, jauge, largeur, r, couronne, textes, d)

    @Test
    fun `le soleil se leve a gauche et se couche a droite, derriere les anneaux a midi`() {
        val lever = arc(0.0, 0.0)!!
        assertTrue(lever[0] < jauge.gauche && lever[1] <= jauge.bas - couronne + 0.1f)
        val coucher = arc(1.0, 0.0)!!
        assertTrue(coucher[0] > jauge.droite)
        val midi = arc(0.5, 0.6)!!
        assertEquals((jauge.gauche + jauge.droite) / 2, midi[0], 0.5f)
        // Il monte avec sa hauteur, sans jamais sortir de la hauteur des anneaux.
        var avant = Float.MAX_VALUE
        for (k in 0..20) {
            val y = arc(0.2, k / 20.0)!![1]
            assertTrue(y <= avant && y - couronne >= jauge.haut - 0.1f && y + couronne <= jauge.bas + 0.1f)
            avant = y
        }
        // Il s'attarde dans les marges : au premier quart du jour, encore à gauche des anneaux.
        assertTrue(arc(0.2, 0.3)!![0] < jauge.gauche + r)
        // De gauche à droite, toujours.
        var x = -1f
        for (k in 0..40) { val n = arc(k / 40.0, 0.3)!![0]; assertTrue(n >= x); x = n }
    }

    @Test
    fun `jamais sous un texte`() {
        // Un texte posé à côté des anneaux : l'astre ne s'y montre pas.
        val gene = textes + PlanCiel.Zone(0f, 300 * d, 70 * d, 340 * d)
        assertNull(PlanCiel.arc(0.0, 0.3, jauge, largeur, r, couronne, gene, d))
        assertNotNull(PlanCiel.arc(1.0, 0.3, jauge, largeur, r, couronne, gene, d))
    }
}
