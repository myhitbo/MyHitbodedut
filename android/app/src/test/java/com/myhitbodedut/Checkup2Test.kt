package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les points restés ouverts au check-up du 11/11, faits le 12/11 : rythme de l'écran de garde,
 * note qui survit à la rotation, rappels à l'heure, livres lus hors du fil de l'interface,
 * écran d'ouverture une fois par jour, recherche web dans un Worker.
 */
class Checkup2Test {

    private fun lire(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()

    @Test
    fun `l ecran de garde ne guette de pres que barriere armee et ecran allume`() {
        assertEquals(GateRythme.ARMEE_MS, GateRythme.delai(armee = true, ecranAllume = true))
        assertEquals(GateRythme.REPOS_MS, GateRythme.delai(armee = false, ecranAllume = true))
        assertNull("écran éteint : la boucle s'arrête", GateRythme.delai(armee = true, ecranAllume = false))
        assertEquals("sans écoute de l'allumage, un tour par minute", GateRythme.ETEINT_MS,
            GateRythme.delai(armee = true, ecranAllume = false, relanceAllumage = false))
        assertTrue(GateRythme.REPOS_MS >= 10 * GateRythme.ARMEE_MS)
        val service = lire("GateService.kt")
        assertFalse("plus de rythme fixe", service.contains("POLL_MS"))
        assertTrue(service.contains("Intent.ACTION_SCREEN_ON") && service.contains("unregisterReceiver(ecran)"))
    }

    @Test
    fun `la note du soir survit a la rotation`() {
        val note = lire("NoteDialog.kt")
        assertTrue("un fragment, recréé par le système", note.contains("class NoteDialog : AppCompatDialogFragment()"))
        assertTrue("le brouillon est gardé", note.contains("override fun onSaveInstanceState") && note.contains("putString(K_NOTE"))
        assertTrue("les humeurs aussi", note.contains("putInt(K_AVANT") && note.contains("putInt(K_APRES"))
        assertTrue("pas de lambdas perdues à la recréation", note.contains("interface Hote"))
        assertTrue("une note intime", note.contains("FLAG_SECURE"))
        assertTrue(lire("MainActivity.kt").contains("override fun noteEnregistree(date: String) = refresh()"))
        assertTrue(lire("JournalActivity.kt").contains("override fun noteEnregistree(date: String) = reload()"))
        assertTrue(lire("CelebrationActivity.kt").contains("override fun noteFermee(date: String) = finish()"))
    }

    @Test
    fun `les rappels sont poses a l heure avec un filet pour la veille`() {
        val alarme = lire("Alarme.kt")
        assertTrue(alarme.contains("setWindow(AlarmManager.RTC_WAKEUP, quand, FENETRE_MS"))
        assertTrue(alarme.contains("setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quand"))
        assertEquals(10 * 60_000L, Alarme.FENETRE_MS)
        listOf("Reminder.kt", "VolAlerte.kt", "ChabbatAlerte.kt", "LevanaAlerte.kt").forEach { f ->
            val code = lire(f)
            assertFalse("$f : plus d'alarme inexacte seule", code.contains("setAndAllowWhileIdle"))
            assertTrue(f, code.contains("Alarme.annuler(") && code.contains("Alarme.poser("))
        }
        // Les codes de requête des filets ne croisent aucun autre PendingIntent de l'application.
        val codes = File("src/main/java/com/myhitbodedut").listFiles()!!.flatMap { f ->
            Regex("""(?:REQUETE|REQUEST) = (\d+)""").findAll(f.readText()).map { it.groupValues[1].toInt() }.toList()
        }
        assertTrue(codes.isNotEmpty() && codes.all { it < Alarme.ECART_VEILLE })
    }

    @Test
    fun `un livre se lit hors du fil de l interface`() {
        val lecture = lire("SiddurLectureActivity.kt")
        assertTrue(lecture.contains("Data.livreEnMemoire(id) == null"))
        assertTrue(lecture.contains("Thread {") && lecture.contains("Data.livre(applicationContext, id)"))
        assertTrue("les signets dans une liste recyclée", lecture.contains("inner class Signets"))
        assertFalse(lecture.contains("HorizontalScrollView"))
        assertTrue("un marque-page ne redessine que son paragraphe", lecture.contains("notifyItemChanged(i)"))
        val mise = File("src/main/res/layout/activity_siddur_lecture.xml").readText()
        assertFalse(mise.contains("HorizontalScrollView"))
        listOf("values", "values-en", "values-iw").forEach {
            assertTrue(it, File("src/main/res/$it/strings.xml").readText().contains("name=\"lecture_chargement\""))
        }
    }

    @Test
    fun `l ecran d ouverture une fois par jour et un toucher l ecarte`() {
        assertTrue(MainActivity.ouvertureDuJour(null, "2026-11-12"))
        assertTrue(MainActivity.ouvertureDuJour("2026-11-11", "2026-11-12"))
        assertFalse(MainActivity.ouvertureDuJour("2026-11-12", "2026-11-12"))
        val accueil = lire("MainActivity.kt").substringAfter("private fun ouverture(").substringBefore("companion object")
        assertTrue(accueil.contains("voile.setOnClickListener { lever() }"))
        // Hors des préférences sauvegardées.
        listOf("backup_rules.xml", "data_extraction_rules.xml").forEach {
            assertFalse(it, File("src/main/res/xml/$it").readText().contains("ouverture.xml"))
        }
    }

    @Test
    fun `la recherche web travaille dans un worker`() {
        val web = File("../../web/src")
        val worker = File(web, "js/recherche-worker.js").readText()
        assertTrue(worker.contains("onmessage") && worker.contains("postMessage({ echec: true })"))
        val app = File(web, "js/app.js").readText()
        assertTrue(app.contains("new Worker('js/recherche-worker.js')"))
        assertTrue("repli sans Worker", app.contains("if (fond === false)"))
        assertTrue("arrêté en quittant la recherche", app.contains("arreterRechercheEnFond();"))
        val page = File(web, "index.html").readText()
        // Le voile se décide juste après son balisage, avant le premier dessin.
        assertTrue(page.indexOf("<script src=\"js/ouverture.js\">") > page.indexOf("<div id=\"ouverture\""))
        assertTrue(File(web, "js/ouverture.js").readText().contains("pointerdown"))
    }
}
