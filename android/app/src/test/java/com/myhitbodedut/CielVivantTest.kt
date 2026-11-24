package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les petites animations des ciels (24/11, CielVivant) : lentes, de faible amplitude, jamais
 * plus vives que le ciel immobile, et coupées quand le téléphone le demande. Les mêmes chiffres
 * côté web (ciel.js, ciel.test.mjs).
 */
class CielVivantTest {

    private val secondes = (0..2400).map { it * 0.05 }  // deux minutes, image par image (20 par seconde)

    @Test
    fun `le ciel ne bouge que si le telephone le permet`() {
        assertTrue(CielVivant.permis(animationsDuSysteme = true, economieDeBatterie = false))
        assertFalse("animations coupées", CielVivant.permis(animationsDuSysteme = false, economieDeBatterie = false))
        assertFalse("économie de batterie", CielVivant.permis(animationsDuSysteme = true, economieDeBatterie = true))
        assertFalse(CielVivant.permis(animationsDuSysteme = false, economieDeBatterie = true))
    }

    @Test
    fun `des mouvements lents, entre 8 et 40 secondes`() {
        listOf(CielVivant.SCINTILLEMENT_MIN_S, CielVivant.SCINTILLEMENT_MAX_S, CielVivant.DERIVE_X_S, CielVivant.DERIVE_Y_S, CielVivant.SOUFFLE_S)
            .forEach { assertTrue("cycle de $it s", it in 8.0..40.0) }
        // Les nuages traversent un écran de 400 dp en plus de deux minutes.
        assertTrue(400f / CielVivant.NUAGE_DP_S > 120f && 400f / CielVivant.VOILE_DP_S > 120f)
        // Au plus 20 images par seconde : 0,15 dp par image au plus pour le plus rapide.
        assertTrue(CielVivant.IMAGE_MS >= 33L)
        assertTrue(CielVivant.NUAGE_DP_S * CielVivant.IMAGE_MS / 1000f <= 0.2f)
    }

    @Test
    fun `les etoiles scintillent sans jamais depasser leur eclat immobile`() {
        val e = CielVivant.etoiles(40, 29L, 0.7f, 1.7f)
        for (i in 0 until 40) {
            val periode = e[i * CielVivant.CHAMPS + 3].toDouble()
            val phase = e[i * CielVivant.CHAMPS + 4].toDouble()
            assertTrue(periode in CielVivant.SCINTILLEMENT_MIN_S..CielVivant.SCINTILLEMENT_MAX_S)
            val eclats = secondes.map { CielVivant.scintillement(it, periode, phase) }
            assertTrue(eclats.all { it <= 1f && it >= CielVivant.SCINTILLEMENT_BAS - 1e-4f })
            // Un vrai scintillement : il descend près du bas et remonte près du plein.
            assertTrue(eclats.min() < CielVivant.SCINTILLEMENT_BAS + 0.05f && eclats.max() > 0.95f)
            // Lent : d'une image à l'autre, moins de 3 % d'éclat.
            assertTrue(eclats.zipWithNext().all { (a, b) -> kotlin.math.abs(a - b) < 0.03f })
        }
        // Le même ciel d'une ouverture à l'autre.
        assertTrue(e.contentEquals(CielVivant.etoiles(40, 29L, 0.7f, 1.7f)))
    }

    @Test
    fun `le champ d etoiles derive de quelques dp au plus`() {
        secondes.forEach {
            assertTrue(kotlin.math.abs(CielVivant.deriveX(it)) <= CielVivant.DERIVE_X_DP + 1e-4f)
            assertTrue(kotlin.math.abs(CielVivant.deriveY(it)) <= CielVivant.DERIVE_Y_DP + 1e-4f)
        }
        assertEquals(0f, CielVivant.deriveX(0.0), 1e-6f)
    }

    @Test
    fun `le halo respire sans jamais grandir ni s eclaircir`() {
        val tailles = secondes.map(CielVivant::tailleHalo)
        val eclats = secondes.map(CielVivant::eclatHalo)
        assertTrue(tailles.all { it in (1f - CielVivant.SOUFFLE_TAILLE - 1e-4f)..1f })
        assertTrue(eclats.all { it in (1f - CielVivant.SOUFFLE_ECLAT - 1e-4f)..1f })
        // Au repos (t = 0), le halo du ciel immobile ; au creux, six secondes plus tard.
        assertEquals(1f, CielVivant.tailleHalo(0.0), 1e-6f)
        assertEquals(1f - CielVivant.SOUFFLE_TAILLE, CielVivant.tailleHalo(CielVivant.SOUFFLE_S / 2), 1e-4f)
        assertEquals(1f, CielVivant.eclatHalo(CielVivant.SOUFFLE_S), 1e-4f)
    }

    @Test
    fun `un nuage sorti a droite revient par la gauche`() {
        val l = 400f
        val n = 120f
        assertEquals(50f, CielVivant.nuageX(50f, 3f, 0.0, l, n), 1e-3f)
        assertEquals(80f, CielVivant.nuageX(50f, 3f, 10.0, l, n), 1e-3f)
        secondes.map { CielVivant.nuageX(50f, 3f, it * 3, l, n) }.forEach { assertTrue(it >= -n - 1e-3f && it < l) }
        // Juste sorti à droite (bord gauche au bord du ciel) : il réapparaît entièrement caché à gauche.
        assertEquals(-n, CielVivant.nuageX(-n, 4f, 130.0, l, n), 1e-2f)
        assertEquals(l - 4f, CielVivant.nuageX(-n, 4f, 129.0, l, n), 1e-2f)
    }

    /** Ce qui arrête le battement : le permis de l'écran, la visibilité du dessin, les animations du système. */
    @Test
    fun `l horloge s arrete hors de l ecran et sans animations`() {
        val code = File("src/main/java/com/myhitbodedut/CielVivant.kt").readText()
        assertTrue(code.contains("val enMarche: Boolean get() = permis && visible && ValueAnimator.areAnimatorsEnabled()"))
        assertTrue(code.contains("PowerManager.ACTION_POWER_SAVE_MODE_CHANGED") && code.contains("isPowerSaveMode"))
        // Les deux dessins animés suivent leur visibilité (onglet caché, écran quitté, vue détachée).
        listOf("CielPage", "PaysageCiel").forEach {
            val dessin = File("src/main/java/com/myhitbodedut/$it.kt").readText()
            assertTrue("$it ne suit pas sa visibilité", dessin.contains("horloge.visible = visible"))
        }
        // Les écrans le permettent en revenant devant, et l'arrêtent en partant.
        listOf("MainActivity", "AccueilVersion").forEach {
            val ecran = File("src/main/java/com/myhitbodedut/$it.kt").readText()
            assertTrue(it, ecran.contains("gardeCiel.reprendre()") && ecran.contains("gardeCiel.suspendre()"))
        }
    }

    /** Les écrans de lecture et la séance ne reçoivent aucun ciel animé. */
    @Test
    fun `rien ne bouge derriere un texte qu on lit`() {
        val ecrans = File("src/main/java/com/myhitbodedut").listFiles()!!.filter { it.name.endsWith(".kt") }
            .filter { f -> listOf("CielPage(", "PaysageCiel(", "paysage(", "GardeCiel(").any { f.readText().contains(it) } }
            .map { it.name.removeSuffix(".kt") }.toSet()
        assertEquals(setOf("CielPage", "PaysageCiel", "CielVivant", "AccueilVersion", "MainActivity", "InstantActivity", "SereniteActivity"), ecrans)
    }
}
