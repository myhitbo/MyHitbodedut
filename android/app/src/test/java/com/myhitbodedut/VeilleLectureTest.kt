package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * L'écran reste allumé pendant la lecture (audit du 12/11, FLECTURE-01) : il s'éteignait au
 * milieu de la Amida. Les quatre écrans de lecture préviennent VeilleLecture, qui relâche
 * l'écran après dix minutes sans toucher ; un réglage, allumé par défaut, le coupe.
 */
class VeilleLectureTest {

    private fun source(nom: String) = File("src/main/java/com/myhitbodedut/$nom.kt").readText()

    @Test
    fun `les quatre ecrans de lecture gardent l ecran allume`() {
        listOf("SiddurLectureActivity", "TehilimLectureActivity", "TikkunFlowActivity", "LibraryEntryActivity").forEach { nom ->
            val code = source(nom)
            assertTrue("$nom : pas de veille", code.contains("VeilleLecture(this)"))
            // Chaque toucher repousse l'extinction ; l'écran qui s'en va ne garde rien allumé.
            assertTrue("$nom : touchers non suivis", Regex("override fun onUserInteraction\\(\\) \\{\\s+super.onUserInteraction\\(\\)\\s+veille.toucher\\(\\)").containsMatchIn(code))
            assertTrue("$nom : retour non suivi", Regex("override fun onResume\\(\\) \\{\\s+super.onResume\\(\\)\\s+veille.toucher\\(\\)").containsMatchIn(code))
            assertTrue("$nom : départ non suivi", Regex("override fun onPause\\(\\) \\{\\s+super.onPause\\(\\)\\s+veille.arreter\\(\\)").containsMatchIn(code))
        }
    }

    @Test
    fun `dix minutes sans toucher et la veille du telephone reprend`() {
        assertEquals(10 * 60_000L, VeilleLecture.DELAI_MS)
        val code = source("VeilleLecture")
        assertTrue(code.contains("addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)"))
        assertTrue(code.contains("clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)"))
        assertTrue(code.contains("postDelayed(relacher, DELAI_MS)"))
        // Le réglage coupé : rien n'est gardé allumé.
        assertTrue(code.contains("if (!Store.lectureEcranAllume(activite)) return eteindre()"))
    }

    @Test
    fun `le reglage existe, allume par defaut, sauvegarde et restaure`() {
        val store = source("Store")
        assertTrue(store.contains("getBoolean(KEY_LECTURE_ECRAN_ALLUME, true)"))
        assertTrue(store.contains(".put(\"lecture_ecran_allume\", lectureEcranAllume(context))"))
        assertTrue(store.contains("if (settings.has(\"lecture_ecran_allume\")) setLectureEcranAllume("))
        assertTrue(source("SettingsActivity").contains("bindSwitch(R.id.ecran_allume_switch, Store.lectureEcranAllume(this))"))
        val ecran = File("src/main/res/layout/activity_settings.xml").readText()
        assertTrue(ecran.contains("android:id=\"@+id/ecran_allume_switch\"") && ecran.contains("@string/settings_ecran_allume"))
        listOf("values", "values-en", "values-iw").forEach { d ->
            assertTrue(d, File("src/main/res/$d/strings.xml").readText().contains("name=\"settings_ecran_allume\""))
        }
    }
}
