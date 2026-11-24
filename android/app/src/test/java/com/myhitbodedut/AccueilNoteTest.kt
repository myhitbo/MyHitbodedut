package com.myhitbodedut

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Décision du 24/11 : les accueils Sérénité, Bento, Instant et Pile ne montrent plus le texte
 * de la dernière note. Un accueil se voit dans les captures d'écran et l'aperçu des
 * applications récentes, que l'écran du journal interdit (FLAG_SECURE).
 */
class AccueilNoteTest {

    private fun source(nom: String) = File("src/main/java/com/myhitbodedut/$nom.kt").readText()

    @Test
    fun `les donnees de l accueil ne portent pas le texte de la note`() {
        val champs = Regex("data class NoteAffichee\\(([^)]*)\\)").find(source("AccueilVersion"))!!.groupValues[1]
        assertFalse("NoteAffichee porte encore un texte : $champs", champs.contains("String"))
        assertTrue(champs.contains("val ecrite: Boolean"))
    }

    @Test
    fun `aucun des quatre accueils n affiche le texte d une note`() {
        listOf("BentoActivity", "InstantActivity", "PileActivity", "SereniteActivity").forEach { ecran ->
            val s = source(ecran)
            assertFalse("$ecran lit n.texte", Regex("\\bn\\??\\.texte\\b").containsMatchIn(s))
            assertFalse("$ecran affiche r.note", Regex("texte\\(context, r\\.note\\b").containsMatchIn(s))
            assertTrue("$ecran ne dit pas qu'une note existe", s.contains("R.string.version_note_ecrite"))
        }
    }

    @Test
    fun `le libelle existe dans les cinq langues`() {
        listOf("values", "values-en", "values-iw", "values-es", "values-ar-rTN").forEach { v ->
            assertTrue(v, File("src/main/res/$v/strings.xml").readText().contains("name=\"version_note_ecrite\""))
        }
    }
}
