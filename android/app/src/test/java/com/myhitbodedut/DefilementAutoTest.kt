package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le défilement automatique des textes (16/11) : dix vitesses, la troisième par défaut, en
 * lignes plutôt qu'en pixels, et un défilement qui avance même aux vitesses les plus lentes.
 * Les mêmes nombres sont tenus par le site, le Nokia et l'iPhone.
 */
class DefilementAutoTest {

    @Test
    fun `dix vitesses de 6 a 124 dp par seconde, chacune 1,4 fois la precedente`() {
        val attendues = listOf(6.0, 8.4, 11.76, 16.46, 23.05, 32.27, 45.18, 63.25, 88.55, 123.97)
        attendues.forEachIndexed { i, v -> assertEquals(v, DefilementAuto.vitesse(i + 1, 1f, 1f).toDouble(), 0.01) }
        assertEquals(DefilementAuto.vitesse(1, 1f, 1f), DefilementAuto.vitesse(0, 1f, 1f))
        assertEquals(DefilementAuto.vitesse(10, 1f, 1f), DefilementAuto.vitesse(42, 1f, 1f))
        assertEquals(3, DefilementAuto.DEFAUT)
    }

    @Test
    fun `la vitesse suit la taille des lettres et la densite de l ecran`() {
        assertEquals(2 * DefilementAuto.vitesse(3, 1f, 1f), DefilementAuto.vitesse(3, 2f, 1f), 0.001f)
        assertEquals(3 * DefilementAuto.vitesse(3, 1f, 1f), DefilementAuto.vitesse(3, 1f, 3f), 0.001f)
    }

    @Test
    fun `la plus lente avance quand meme, image apres image`() {
        // 6 px/s à 60 images par seconde : un dixième de pixel par image.
        var reste = 0f
        var total = 0
        repeat(600) {
            val (px, r) = DefilementAuto.pas(6f, 16L, reste)
            total += px
            reste = r
        }
        // 600 images de 16 ms : 9,6 s, donc 57 ou 58 pixels.
        assertTrue("$total", total in 57..58)
        assertTrue(reste in 0f..1f)
    }

    @Test
    fun `cent petits pas valent un grand pas`() {
        var reste = 0f
        var total = 0
        repeat(100) {
            val (px, r) = DefilementAuto.pas(45f, 10L, reste)
            total += px
            reste = r
        }
        // Au pixel près : les flottants peuvent laisser 44,999 de côté.
        assertTrue("$total", total in 44..45)
        assertEquals(45f, total + reste, 0.01f)
    }

    @Test
    fun `chaque ecran de lecture a le defilement par la barre de lecture`() {
        val barre = File("src/main/java/com/myhitbodedut/ReglagesLecture.kt").readText()
        assertTrue(barre.contains("DefilementAuto(activite, defilement)"))
        assertTrue(barre.contains("R.drawable.ic_lecture_defiler, R.string.lecture_defiler"))
        // Toucher le texte arrête le défilement, dans une liste comme dans une vue qui défile : l'appui est
        // vu par l'indicateur, posé par-dessus le texte, avant qu'une vue du texte le prenne (24/11).
        assertTrue(barre.contains("surToucher = { reglages.arreterAuToucher(it) }"))
        val indicateur = File("src/main/java/com/myhitbodedut/IndicateurDefilement.kt").readText()
        val voit = indicateur.substringAfter("override fun dispatchTouchEvent(").substringBefore("\n    }")
        assertTrue(voit, voit.contains("surToucher?.invoke(event)") && voit.trimEnd().endsWith("return false"))
        listOf("values", "values-en", "values-iw", "values-es", "values-ar-rTN").forEach { d ->
            val textes = File("src/main/res/$d/strings.xml").readText()
            listOf("lecture_defiler", "lecture_defiler_pause", "lecture_vitesse", "lecture_plus_vite", "lecture_moins_vite")
                .forEach { assertTrue("$d : $it", textes.contains("name=\"$it\"")) }
        }
        // Les six écrans qui posent la barre, donc le défilement.
        listOf("SiddurLectureActivity", "TehilimLectureActivity", "TikkunFlowActivity", "LibraryEntryActivity",
            "HalakhaActivity", "HilloulotActivity").forEach {
            assertTrue(it, File("src/main/java/com/myhitbodedut/$it.kt").readText().contains("ReglagesLecture.installer("))
        }
    }

    @Test
    fun `l ecran reste allume tant qu il defile, sur chaque ecran de lecture`() {
        // La halakha et les hilloulot n'ont pas VeilleLecture, que les réglages peuvent aussi couper : le téléphone
        // s'éteignait en plein défilement. La vue qui défile garde l'écran allumé, du départ à l'arrêt (24/11).
        val source = File("src/main/java/com/myhitbodedut/DefilementAuto.kt").readText()
        val demarrer = source.substringAfter("fun demarrer()").substringBefore("\n    }")
        val arreter = source.substringAfter("fun arreter()").substringBefore("\n    }")
        assertTrue(demarrer, demarrer.contains("defilement.keepScreenOn = true"))
        assertTrue(arreter, arreter.contains("defilement.keepScreenOn = false"))
    }
}
