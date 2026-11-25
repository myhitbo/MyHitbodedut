package com.myhitbodedut

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Décision du 24/11 : le bilan de la semaine s'ouvre sur tous les accueils, plus seulement le Classique. */
class BilanPartoutTest {

    private fun source(nom: String) = File("src/main/java/com/myhitbodedut/$nom.kt").readText()

    @Test
    fun `le Classique et les quatre autres accueils ouvrent le meme bilan`() {
        assertTrue(source("MainActivity").contains("BilanSemaineVue.montrerSiDu(this)"))
        assertFalse("le Classique garde sa copie", source("MainActivity").contains("fun bilanDeLaSemaine("))
        val accueil = source("AccueilVersion")
        assertTrue(accueil.contains("BilanSemaineVue.montrerSiDu(this)"))
        // Sérénité, Bento, Instant et Pile héritent d'AccueilVersion.
        listOf("SereniteActivity", "BentoActivity", "InstantActivity", "PileActivity").forEach {
            assertTrue(it, Regex("class $it\\s*:\\s*AccueilVersion\\(").containsMatchIn(source(it)))
        }
    }

    @Test
    fun `un bravo ou une note en cours passent d abord`() {
        val ligne = source("AccueilVersion").lines().first { it.contains("BilanSemaineVue.montrerSiDu(this)") }
        assertTrue(ligne, ligne.contains("!NoteDialog.ouverte(this)") && ligne.contains("!Store.hasPendingCelebration(this)"))
    }

    @Test
    fun `une fois par semaine, comme avant`() {
        val s = source("BilanSemaineVue")
        assertTrue(s.contains("if (Store.bilanVu(activite) == debut.toString()) return"))
        assertTrue(s.contains("Store.setBilanVu(activite, b.debut.toString())"))
    }
}
