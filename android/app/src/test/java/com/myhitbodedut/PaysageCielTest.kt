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
    fun `tous les degrades sont peints dans des images, jamais a l ecran`() {
        // Les dégradés ne vivent que dans les fonctions qui peignent une image (peindre…).
        val fonctions = Regex("""private fun (\w+)\(""").findAll(code).map { it.groupValues[1] }.toList()
        val avecDegrade = fonctions.filter { Regex("(Linear|Radial)Gradient\\(").containsMatchIn(corps("private fun $it(")) }
        assertTrue("aucun dégradé trouvé", avecDegrade.isNotEmpty())
        avecDegrade.forEach { assertTrue("dégradé hors d'une peinture d'image : $it", it.startsWith("peindre")) }
        assertEquals("un dégradé hors des fonctions de peinture",
            Regex("(Linear|Radial)Gradient\\(").findAll(code).count(),
            avecDegrade.sumOf { Regex("(Linear|Radial)Gradient\\(").findAll(corps("private fun $it(")).count() })
        // Animé (24/11), chaque trame ne fait que poser des images déjà peintes.
        val anime = corps("private fun dessinerAnime(")
        assertTrue(anime.contains("canvas.drawBitmap("))
        traces.forEach { trace -> assertFalse("l'animation peint directement à l'écran ($trace)", anime.contains(trace)) }
    }

    /** Immobile (animations coupées, économie de batterie, écran quitté), une seule image, même ordre de peinture. */
    @Test
    fun `immobile, le paysage est peint en une image, dans l ordre du ciel anime`() {
        val draw = corps("override fun draw(canvas: Canvas)")
        assertTrue(draw.contains("if (horloge.enMarche && dessinerAnime(canvas, largeur, hauteur))"))
        val peindre = corps("private fun peindre(")
        val ordre = listOf("peindreCiel(canvas, w, h)", "etoiles.forEach", "peindreHalo(canvas, cx, cy, rayon)",
            "peindreAstre(canvas, cx, cy, rayon)", "peindreCollines(canvas, w, h)").map { peindre.indexOf(it) }
        assertTrue("la peinture immobile a changé : $ordre", ordre.all { it >= 0 } && ordre == ordre.sorted())
    }

    /** Le ciel continu (24/11) : les quatre ciels peints d'avant, mêlés selon la hauteur du soleil. */
    @Test
    fun `les quatre ciels d avant se melent sans a-coup`() {
        listOf(true, false).forEach { matin ->
            var avant = PaysageCiel.poidsDesCiels(-30.0, matin)
            var e = -30.0
            while (e <= 60.0) {
                val p = PaysageCiel.poidsDesCiels(e, matin)
                assertEquals(1.0, p.sum(), 1e-9)
                assertTrue("saut à $e° : ${avant.toList()} → ${p.toList()}", p.indices.all { kotlin.math.abs(p[it] - avant[it]) <= 0.03 })
                avant = p
                e += 0.25
            }
        }
        // Le matin passe par l'aube, le soir par le coucher.
        assertEquals(1.0, PaysageCiel.poidsDesCiels(0.0, true)[1], 1e-9)
        assertEquals(1.0, PaysageCiel.poidsDesCiels(0.0, false)[3], 1e-9)
        assertEquals(1.0, PaysageCiel.poidsDesCiels(-20.0, true)[0], 1e-9)
        assertEquals(1.0, PaysageCiel.poidsDesCiels(30.0, false)[2], 1e-9)
    }

    /** Les deux accueils qui montrent le ciel passent par ce paysage, pas par un dégradé à eux. */
    @Test
    fun `Instant et Serenite posent ce paysage en fond de carte`() {
        // AccueilVersion.paysage crée le PaysageCiel et lui donne l'état de ses animations (GardeCiel).
        assertTrue(File("src/main/java/com/myhitbodedut/AccueilVersion.kt").readText()
            .contains("PaysageCiel(CielDuJour.etat(this), resources.displayMetrics.density, nuages, arc)"))
        listOf("InstantActivity" to "background = paysage()", "SereniteActivity" to "background = paysage(nuages = true, arc = true)").forEach { (ecran, pose) ->
            val source = File("src/main/java/com/myhitbodedut/$ecran.kt").readText()
            assertTrue("$ecran ne pose plus PaysageCiel", source.contains(pose))
        }
    }
}
