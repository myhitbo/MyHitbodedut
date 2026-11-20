package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les corrections du check-up du 11/11 restées sur sa branche, reprises le 19/11
 * (celles que les audits du 12/11 et du 15/11 avaient déjà refaites autrement
 * sont vérifiées par leurs propres tests). Comme Fiabilite2Test : chaque garde
 * doit exister à l'endroit où elle protège, et les règles pures sont vérifiées
 * directement.
 */
class CheckupTest {

    private fun lire(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()
    private fun res(f: String) = File("src/main/res/$f").readText()

    @Test
    fun `le journal n est plus relu a chaque appel`() {
        val days = lire("Store.kt").substringAfter("fun days(context: Context)").substringBefore("private fun lireJours")
        assertTrue(days.contains("raw == joursBrut && anciens == joursAnciens"))
        // Un journal illisible n'est jamais gardé : sa copie de secours se fait à chaque lecture.
        assertTrue(days.contains("if (lisible)"))
    }

    @Test
    fun `les recents ne relancent pas une seance`() {
        val demande = lire("SessionActivity.kt").substringAfter("private fun lireDemande").substringBefore("EXTRA_DEPUIS_RAPPEL, false)")
        assertTrue(demande.contains("Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY"))
    }

    @Test
    fun `la notification de fin se lit en entier`() {
        assertTrue(lire("SessionService.kt").contains("Notification.BigTextStyle().bigText(getString(R.string.session_done_text"))
    }

    @Test
    fun `les textes longs se replient`() {
        val journal = res("layout/item_journal.xml")
        assertTrue(journal.contains("android:id=\"@+id/entry_more\""))
        assertTrue(journal.contains("android:maxLines=\"6\""))
        assertTrue(lire("JournalActivity.kt").contains("holder.note.maxLines = if (deplie) Int.MAX_VALUE else LIGNES_REPLIEES"))
        for (f in listOf("widget_zmanim_petit", "widget_zmanim", "widget_zmanim_grand")) {
            val w = res("layout/$f.xml")
            assertTrue(f, w.contains("android:autoSizeTextType=\"uniform\""))
            assertEquals(f, 3, Regex("android:ellipsize=\"end\"").findAll(w).count().coerceAtMost(3))
        }
    }

    @Test
    fun `la note du soir ne rogne ni les visages ni les reponses`() {
        val note = lire("NoteDialog.kt")
        assertTrue(note.contains("minHeight = (48 * density).toInt()"))
        assertFalse("gratitude et « à travailler » sur plusieurs lignes", note.contains("setSingleLine()"))
    }

    @Test
    fun `l ecran de garde ne guette de pres que barriere armee et ecran allume`() {
        assertEquals(GateRythme.ARMEE_MS, GateRythme.delai(armee = true, ecranAllume = true))
        assertEquals(GateRythme.REPOS_MS, GateRythme.delai(armee = false, ecranAllume = true))
        assertNull("écran éteint, l'allumage relance la boucle", GateRythme.delai(armee = true, ecranAllume = false))
        assertEquals(GateRythme.ETEINT_MS, GateRythme.delai(armee = true, ecranAllume = false, relanceAllumage = false))
        val gate = lire("GateService.kt")
        assertTrue(gate.contains("GateRythme.delai("))
        assertTrue(gate.contains("Intent.ACTION_SCREEN_ON"))
        assertTrue("le récepteur est rendu à la fin du service", gate.contains("unregisterReceiver(ecran)"))
    }

    @Test
    fun `les rappels sont poses a l heure avec un filet pour la veille`() {
        val alarme = lire("Alarme.kt")
        assertTrue(alarme.contains("setWindow(AlarmManager.RTC_WAKEUP"))
        assertTrue(alarme.contains("setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP"))
        for (f in listOf("Reminder.kt", "ChabbatAlerte.kt", "LevanaAlerte.kt", "VolAlerte.kt")) {
            val s = lire(f)
            assertTrue(f, s.contains("Alarme.poser(") && s.contains("Alarme.annuler("))
            assertFalse(f, s.contains("alarmes.setAndAllowWhileIdle") || s.contains("alarms.setAndAllowWhileIdle"))
        }
        // La seconde des deux alarmes ne remontre pas le rappel.
        for (f in listOf("Reminder.kt", "ChabbatAlerte.kt", "LevanaAlerte.kt")) assertTrue(f, lire(f).contains("Alarme.aTraiter("))
    }

    @Test
    fun `la seconde alarme du meme rappel est ecartee`() {
        val heure = 1_000_000_000L
        assertTrue("posée par une version d'avant", Alarme.estATraiter(0L, heure))
        assertTrue("la première, à l'heure", Alarme.estATraiter(heure, heure))
        assertTrue("la première, en retard", Alarme.estATraiter(heure, heure + Alarme.FENETRE_MS))
        assertFalse("la seconde : le rappel suivant est déjà posé, demain", Alarme.estATraiter(heure + 86_400_000L, heure + 5_000L))
    }
}
