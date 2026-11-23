package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le paysage des accueils Instant et Sérénité (recette du 22/11). Ses dégradés, peints à
 * chaque trame sur la carte de l'accueil Instant, arrêtaient net les émulateurs Android 15 et
 * 16 : l'appareil virtuel ne répondait plus une seconde après l'ouverture de l'écran. Le
 * paysage est peint une fois dans une image ; l'écran ne reçoit plus que cette image.
 */
class PaysageCielTest {

    private val code = File("src/main/java/com/myhitbodedut/PaysageCiel.kt").readText()

    /** Le corps de la fonction dont la déclaration commence par [debut], accolades comprises. */
    private fun corps(debut: String): String {
        val depart = code.indexOf(debut)
        assertTrue("« $debut » introuvable dans PaysageCiel.kt", depart >= 0)
        val ouvre = code.indexOf('{', depart)
        var niveau = 0
        for (i in ouvre until code.length) {
            when (code[i]) {
                '{' -> niveau++
                '}' -> if (--niveau == 0) return code.substring(ouvre, i + 1)
            }
        }
        throw AssertionError("« $debut » n'est pas refermée")
    }

    private val traces = listOf("Gradient", "shader", "drawRect", "drawCircle", "drawPath", "drawOval")

    @Test
    fun `a l ecran, l image du paysage, et aucun degrade`() {
        val draw = corps("override fun draw(canvas: Canvas)")
        assertTrue("draw ne pose pas l'image", draw.contains("canvas.drawBitmap("))
        traces.forEach { trace ->
            assertFalse("draw peint encore directement à l'écran ($trace)", draw.contains(trace))
        }
    }

    @Test
    fun `le paysage est peint dans l image, une fois par taille de carte`() {
        val image = corps("private fun imagePeinte(")
        assertTrue("l'image n'est pas créée à la taille de la carte", image.contains("Bitmap.createBitmap(largeur, hauteur, Bitmap.Config.ARGB_8888)"))
        assertTrue("le paysage n'est pas peint dans l'image", image.contains("peindre(Canvas(neuve)"))
        assertTrue("l'image n'est pas gardée", image.contains("image = neuve"))
        val draw = corps("override fun draw(canvas: Canvas)")
        assertTrue("l'image gardée n'est pas reprise", draw.contains("image?.takeIf { it.width == largeur && it.height == hauteur }"))
        assertTrue("une carte qui change de taille garde l'ancienne image", corps("override fun onBoundsChange(").contains("image = null"))
    }

    @Test
    fun `tous les degrades sont dans la peinture de l image`() {
        val peindre = corps("private fun peindre(")
        assertTrue(peindre.contains("LinearGradient("))
        assertEquals("un dégradé hors de peindre()", Regex("(Linear|Radial)Gradient\\(").findAll(code).count(),
            Regex("(Linear|Radial)Gradient\\(").findAll(peindre).count())
    }

    /** Les deux accueils qui montrent le ciel passent par ce paysage, pas par un dégradé à eux. */
    @Test
    fun `Instant et Serenite posent ce paysage en fond de carte`() {
        listOf("InstantActivity", "SereniteActivity").forEach { ecran ->
            val source = File("src/main/java/com/myhitbodedut/$ecran.kt").readText()
            assertTrue("$ecran ne pose plus PaysageCiel", source.contains("background = PaysageCiel(phase, resources.displayMetrics.density)"))
        }
    }
}
