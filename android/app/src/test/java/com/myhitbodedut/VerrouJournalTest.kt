package com.myhitbodedut

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le verrou du journal (audit du 12/11, revue du 15/11) : tout ce qui montre
 * ou emporte le texte du journal demande le code, et le verrou ne se coupe
 * pas sans lui.
 */
class VerrouJournalTest {

    private fun lire(nom: String) = File("src/main/java/com/myhitbodedut/$nom").readText()

    @Test
    fun `l export et la desactivation du verrou demandent le code`() {
        val reglages = lire("SettingsActivity.kt")
        assertTrue(reglages.contains("VerrouJournal.exiger(this, onOk = { demanderMotDePasseExport() })"))
        // Couper le verrou : l'interrupteur revient d'abord à « activé », puis le code.
        val couper = reglages.substringAfter("private fun renderVerrou()").substringBefore("/** Pose la valeur")
        assertTrue(couper.contains("VerrouJournal.exiger(this, onOk = {"))
        assertTrue(couper.contains("Store.setJournalVerrou(this, false)"))
        assertTrue(couper.indexOf("renderVerrou()\n                    VerrouJournal.exiger") >= 0)
    }

    @Test
    fun `la fenetre de note deja remplie demande le code hors du journal`() {
        val note = lire("NoteDialog.kt")
        assertTrue(note.contains("activity !is JournalActivity"))
        assertTrue(note.contains("VerrouJournal.exiger(composant"))
        assertTrue(note.contains("IME_FLAG_NO_PERSONALIZED_LEARNING"))
    }

    @Test
    fun `le journal se referme a l arriere-plan et apres la mort du processus`() {
        val journal = lire("JournalActivity.kt")
        assertTrue(journal.contains("override fun onStop()"))
        assertTrue(journal.contains("!isChangingConfigurations && VerrouJournal.actif(this)"))
        // « Ouvert » ne survit qu'à une rotation.
        assertTrue(journal.contains("outState.putBoolean(ETAT_OUVERT, ouvert && isChangingConfigurations)"))
        assertFalse(journal.contains("outState.putBoolean(ETAT_DEMANDE, !ouvert)"))
    }

    @Test
    fun `renoncer a l export n efface jamais un fichier existant`() {
        val reglages = lire("SettingsActivity.kt")
        // Le mot de passe est demandé avant le choix du fichier.
        val avant = reglages.substringAfter("private fun demanderMotDePasseExport()").substringBefore("private fun writeBackup")
        assertTrue(avant.indexOf("fenetreMotDePasseExport") < avant.indexOf("exportFile.launch"))
        // Le seul effacement restant ne touche qu'un document vide.
        val effacements = Regex("deleteDocument").findAll(reglages).count()
        assertTrue(effacements == 1)
        assertTrue(reglages.contains("if (tailleDocument(uri) == 0L) runCatching { android.provider.DocumentsContract.deleteDocument"))
    }
}
