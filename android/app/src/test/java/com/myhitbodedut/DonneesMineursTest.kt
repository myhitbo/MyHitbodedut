package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Le lot « données », constats mineurs et cosmétiques du 15/11 (FDONNEES-10 à 29). */
class DonneesMineursTest {

    private fun lire(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()
    private fun chaines(dossier: String) = File("src/main/res/$dossier/strings.xml").readText()

    @Test
    fun `une date aberrante n entre pas au journal (FDONNEES-16)`() {
        assertNotNull(Store.dateValide("2026-11-15"))
        assertNull(Store.dateValide("0202-11-15"))
        assertNull(Store.dateValide("2101-01-01"))
        assertNull(Store.dateValide("pas une date"))
    }

    @Test
    fun `la gratitude s ecrit avec le deux-points de la langue (FDONNEES-27)`() {
        val plus = JournalPlus.Plus(gratitude = "merci")
        assertEquals("Gratitude : merci", JournalPlus.resume(plus, "Gratitude"))
        assertEquals("Gratitude: merci", JournalPlus.resume(plus, "Gratitude") { l, t -> "$l: $t" })
        listOf("values", "values-en", "values-iw").forEach {
            assertTrue(chaines(it).contains("name=\"journal_ligne\""))
            assertTrue(chaines(it).contains("name=\"journal_humeur_n\""))
        }
    }

    @Test
    fun `les trophees fetes ne sont jamais remplaces mais completes (FDONNEES-10)`() {
        val plume = Trophees.Niveau(Trophees.Famille.PLUME, 1)
        val pas = Trophees.Niveau(Trophees.Famille.PREMIER_PAS, 1)
        // La plume perdue (note effacée) reste fêtée : regagnée, elle n'est pas neuve.
        val vus = Trophees.vusAvec(setOf(plume.cle), setOf(pas))
        assertEquals(setOf(plume.cle, pas.cle), vus)
        assertTrue(Trophees.nouveaux(setOf(pas, plume), vus).isEmpty())
        // Les clés de l'ancien format tombent : elles ne bloquent plus nouveaux() et ne comptent pas.
        assertEquals(setOf(pas.cle), Trophees.vusAvec(setOf("chai", "premier_pas"), setOf(pas)))
        assertEquals(emptySet<String>(), Trophees.vusAvec(null, emptySet()))
        listOf("Confettis.kt", "PaliersActivity.kt").forEach { assertTrue(it, lire(it).contains("Trophees.vusAvec(")) }
        // Les étincelles suivent le compte des trophées gagnés, pas la taille de l'union retenue.
        assertTrue(lire("Confettis.kt").contains("Trophees.grade(r.compte)"))
        assertTrue(lire("SettingsActivity.kt").contains("Celebrations.apresImport(this)"))
    }

    @Test
    fun `la note est protegee des captures et suit les cinq champs (FDONNEES-12, 13)`() {
        assertTrue(lire("NoteDialog.kt").contains("window?.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)"))
        assertTrue(lire("NoteDialog.kt").contains("NoteBrouillon.modifie(enregistre, courant())"))
    }

    @Test
    fun `une humeur ou une gratitude garde la ligne du jour (FDONNEES-14)`() {
        val note = lire("Store.kt").substringAfter("fun setNote").substringBefore("writeDays")
        assertTrue(note.contains("JournalPlus.lire(context, date).vide"))
        val enregistrer = lire("NoteDialog.kt").substringAfter("private fun enregistrer")
        assertTrue(enregistrer.indexOf("JournalPlus.ecrire") < enregistrer.indexOf("Store.setNote"))
    }

    @Test
    fun `j ai deja fait depuis la barriere redessine la vignette et le rappel (FDONNEES-15)`() {
        val garde = lire("GateService.kt").substringAfter("onAlreadyDone = {").substringBefore("onSnooze")
        assertTrue(garde.contains("StreakWidget.refresh(this)") && garde.contains("Reminder.reschedule(this)"))
        assertFalse(lire("Store.kt").contains("if (minutes > 0) runCatching { androidx.core.app.NotificationManagerCompat"))
    }

    @Test
    fun `l import ne compte que le neuf et garde le prenom (FDONNEES-11)`() {
        val store = lire("Store.kt")
        assertTrue(store.contains("if (merged[date] != avant) imported++"))
        assertTrue(store.contains("settings.optString(\"first_name\").takeIf { it.isNotBlank() }"))
    }

    @Test
    fun `les noms du jour exempte sont unifies (FDONNEES-29)`() {
        assertTrue(chaines("values").contains(">Jour de pause<") && chaines("values").contains(">Pause aujourd’hui.<"))
        assertTrue(chaines("values-en").contains(">Rest day today.<"))
        assertFalse(chaines("values").contains("Pour un Yom Tov"))
        assertTrue(lire("StreakWidget.kt").contains("R.string.status_streak_first"))
    }

    @Test
    fun `les chaines mortes ne reviennent pas (FDONNEES-28)`() {
        listOf("values", "values-en", "values-iw").forEach { d ->
            listOf("paliers_title", "trophees_explication", "trophee_a_venir", "action_journal").forEach {
                assertFalse("$d $it", chaines(d).contains("name=\"$it\""))
            }
        }
    }

    @Test
    fun `les titres de la reprise portent leur traduction (FDONNEES-24)`() {
        assertTrue(lire("RepriseFavoris.kt").contains("traduction = traduction(c, cle)"))
    }
}
