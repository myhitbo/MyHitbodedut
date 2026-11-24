package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Demande du 24/11 : dix secondes avant la fin d'une séance minutée, « Continuer ? » — 5 minutes
 * de plus, la même durée, ou sans fin ; sinon elle s'arrête et s'inscrit. Et décision du 24/11 :
 * la durée d'une séance ne suit plus l'heure du téléphone.
 */
class SeanceSuiteTest {

    private val minute = 60_000L

    // --- La question ---------------------------------------------------------------------

    @Test
    fun `la question tombe dans les dix dernieres secondes, pas avant`() {
        val fin = 1_000_000L
        assertFalse(SessionRule.questionDue(fin, fin - 10_001, activee = true, dejaPosee = false))
        assertTrue(SessionRule.questionDue(fin, fin - 10_000, activee = true, dejaPosee = false))
        assertTrue(SessionRule.questionDue(fin, fin - 1, activee = true, dejaPosee = false))
        assertFalse("après la fin", SessionRule.questionDue(fin, fin, activee = true, dejaPosee = false))
    }

    @Test
    fun `une seule fois, jamais si l option est eteinte, jamais sans fin`() {
        val fin = 1_000_000L
        assertFalse(SessionRule.questionDue(fin, fin - 5_000, activee = true, dejaPosee = true))
        assertFalse(SessionRule.questionDue(fin, fin - 5_000, activee = false, dejaPosee = false))
        assertFalse("séance ouverte", SessionRule.questionDue(0L, 5_000, activee = true, dejaPosee = false))
    }

    @Test
    fun `oui repart de la fin prevue, jamais d un instant passe`() {
        val fin = 100 * minute
        assertEquals(fin + 5 * minute, SessionRule.finProlongee(fin, fin - 8_000, 5))
        assertEquals(fin + 15 * minute, SessionRule.finProlongee(fin, fin - 8_000, 15))
        // Répondu en retard, après la fin : 5 minutes à partir de maintenant.
        assertEquals(fin + 30_000 + 5 * minute, SessionRule.finProlongee(fin, fin + 30_000, 5))
    }

    /** Prolongée, la séance s'inscrit pour toute sa durée, pas seulement la première étape. */
    @Test
    fun `une seance prolongee compte toutes ses minutes`() {
        val debut = 10 * minute
        val fin = SessionRule.finProlongee(debut + 15 * minute, debut + 15 * minute - 8_000, 15)
        assertEquals(30, SessionRule.minutesAInscrire(debut, fin, fin + 5_000))
    }

    // --- L'horloge -----------------------------------------------------------------------

    @Test
    fun `l heure du telephone change, la seance non`() {
        val debutMur = 1_700_000_000_000L
        val debutMono = 50_000L
        // Dix minutes réellement passées ; l'horloge murale a reculé d'une heure (heure d'hiver).
        val m = SessionRule.maintenant(debutMur, debutMono, 7, debutMur + 10 * minute - 60 * minute, debutMono + 10 * minute, 7)
        assertEquals(debutMur + 10 * minute, m)
        // Avancée d'une heure (voyage) : toujours dix minutes.
        val n = SessionRule.maintenant(debutMur, debutMono, 7, debutMur + 70 * minute, debutMono + 10 * minute, 7)
        assertEquals(debutMur + 10 * minute, n)
    }

    @Test
    fun `apres un redemarrage, l heure murale`() {
        val debutMur = 1_700_000_000_000L
        val mur = debutMur + 20 * minute
        assertEquals(mur, SessionRule.maintenant(debutMur, 50_000L, 7, mur, 3_000L, 8))
        // Démarrage illisible, ou séance d'avant la mise à jour : l'heure murale aussi.
        assertEquals(mur, SessionRule.maintenant(debutMur, 50_000L, -1, mur, 60_000L, -1))
        assertEquals(mur, SessionRule.maintenant(debutMur, -1L, 7, mur, 60_000L, 7))
    }

    // --- Le branchement ------------------------------------------------------------------

    private fun source(nom: String) = File("src/main/java/com/myhitbodedut/$nom.kt").readText()

    @Test
    fun `la seance ne lit plus l heure murale pour se mesurer`() {
        val service = source("SessionService")
        assertFalse(Regex("sessionEndsAt\\([^)]*\\)[^\\n]*System\\.currentTimeMillis").containsMatchIn(service))
        listOf("SessionService", "SessionActivity", "BlockerView").forEach { f ->
            val s = source(f)
            assertFalse("$f mesure encore la séance sur l'heure murale",
                Regex("(sessionEndsAt|sessionStartedAt)\\([^)]*\\)\\s*-\\s*System\\.currentTimeMillis|System\\.currentTimeMillis\\(\\)\\s*-\\s*Store\\.sessionStartedAt").containsMatchIn(s))
        }
        assertTrue(source("SessionFilet").contains("Store.sessionFinMurale(context)"))
    }

    @Test
    fun `la notification porte trois reponses et l ecran quatre`() {
        val service = source("SessionService")
        assertTrue(service.contains("Notifications.CHANNEL_SUITE"))
        assertTrue(service.contains("R.string.session_suite_sans_fin"))
        val ecran = source("SessionActivity")
        listOf("session_suite_oui_plus", "session_suite_oui_sans_fin", "session_suite_non").forEach { assertTrue(it, ecran.contains("R.string.$it")) }
        assertTrue("l'option avant de commencer", ecran.contains("R.id.session_suite"))
    }

    @Test
    fun `l option est sur les deux ecrans de seance, debout et couche, et dans les cinq langues`() {
        listOf("layout", "layout-land").forEach {
            assertTrue(it, File("src/main/res/$it/activity_session.xml").readText().contains("@+id/session_suite"))
        }
        val cles = listOf("session_suite_option", "session_suite_titre", "session_suite_texte", "session_suite_plus",
            "session_suite_sans_fin", "session_suite_non_court", "session_suite_oui_plus", "session_suite_oui_sans_fin",
            "session_suite_non", "channel_suite", "channel_suite_description")
        listOf("values", "values-en", "values-iw", "values-es", "values-ar-rTN").forEach { v ->
            val s = File("src/main/res/$v/strings.xml").readText()
            cles.forEach { assertTrue("$v : $it", s.contains("name=\"$it\"")) }
        }
    }
}
