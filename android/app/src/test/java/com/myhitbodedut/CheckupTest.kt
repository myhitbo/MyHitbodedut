package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les corrections du check-up du 11/11. Comme Fiabilite2Test : chaque garde
 * doit exister à l'endroit où elle protège, et les règles pures sont
 * vérifiées directement.
 */
class CheckupTest {

    private fun lire(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()
    private fun res(f: String) = File("src/main/res/$f").readText()

    @Test
    fun `une seance sans duree oubliee s arrete au plafond`() {
        val debut = 1_000_000L
        val plafond = SessionRule.PLAFOND_OUVERTE * 60_000L
        assertTrue(SessionRule.estEchue(debut, 0L, SessionRule.OUVERTE, debut + plafond))
        val refresh = lire("SessionService.kt").substringAfter("private fun refresh()").substringBefore("startForegroundNow()")
        assertTrue("le tour du service doit clore une séance échue", refresh.contains("SessionRule.estEchue("))
        assertTrue(refresh.contains("!Store.isSessionRunning(this) || plafond"))
    }

    @Test
    fun `ne pas deranger revient quand la seance est reprise echue`() {
        val reprise = lire("SessionService.kt").substringAfter("fun reconcilier(").substringBefore("} else {")
        assertTrue(reprise.contains("NePasDeranger.retablir(context)"))
        val reset = lire("SettingsActivity.kt").substringAfter("reset_confirm_yes").substringBefore("Store.reinitialiser")
        assertTrue("rétablir avant d'effacer les préférences", reset.indexOf("NePasDeranger.retablir") in 0 until reset.indexOf("stopService"))
    }

    @Test
    fun `les services ne plantent pas s ils ne peuvent passer au premier plan`() {
        // Les gardes de main (fusion du 15/11) : le passage au premier plan rend vrai ou faux.
        assertTrue(lire("SessionService.kt").contains("private fun startForegroundNow(): Boolean = runCatching {"))
        assertTrue(lire("GateService.kt").contains("if (!startInForeground())"))
    }

    @Test
    fun `la sauvegarde garde le journal enrichi et le tikoun`() {
        val store = lire("Store.kt")
        val export = store.substringAfter("fun exportJson").substringBefore("fun importJson")
        assertTrue(export.contains("root.put(\"journal_plus\""))
        assertTrue(export.contains("root.put(\"tikkun_journal\""))
        // Le journal enrichi et le Tikoun passent par importerAjouts, appelé par importJson (fusion du 15/11).
        val import = store.substringAfter("private fun importerAjouts").substringBefore("// --- Format")
        assertTrue(store.substringAfter("fun importJson").contains("importerAjouts(context, root,"))
        assertTrue(import.contains("optJSONObject(\"journal_plus\")"))
        assertTrue(import.contains("optJSONArray(\"tikkun_journal\")"))
        assertTrue(import.contains("jour.isBefore(PREMIER_JOUR_IMPORTABLE)"))
    }

    @Test
    fun `le journal n est plus relu a chaque appel`() {
        val days = lire("Store.kt").substringAfter("fun days(context: Context)").substringBefore("private fun lireJours")
        assertTrue(days.contains("raw == joursBrut && anciens == joursAnciens"))
    }

    @Test
    fun `les recents ne relancent pas une seance`() {
        assertTrue(lire("SessionActivity.kt").contains("Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY"))
    }

    @Test
    fun `l ecran de garde ne couvre jamais le telephone`() {
        // La règle de main (FBARRIERE-05, fusion du 15/11) : GateRule et AppsProtegees.
        assertTrue(lire("GateService.kt").contains("GateRule.retenue(readForegroundPackage(), packageName, Store.blockedApps(this), ::protegees)"))
        assertTrue(lire("AppsProtegees.kt").contains("defaultDialerPackage"))
    }

    @Test
    fun `une fenetre vide est refusee`() {
        assertTrue(lire("SettingsActivity.kt").contains("if (it == Store.windowEnd(this)) fenetreVide() else"))
        for (l in listOf("values", "values-en", "values-iw")) {
            assertTrue(l, res("$l/strings.xml").contains("name=\"settings_window_same\""))
        }
    }

    @Test
    fun `les textes longs se replient`() {
        val journal = res("layout/item_journal.xml")
        assertTrue(journal.contains("android:id=\"@+id/entry_more\""))
        assertTrue(journal.contains("android:maxLines=\"6\""))
        assertTrue(lire("HilloulotActivity.kt").contains("notice.maxLines = 8"))
        for (f in listOf("widget_zmanim_petit", "widget_zmanim", "widget_zmanim_grand")) {
            val w = res("layout/$f.xml")
            assertTrue(f, w.contains("android:autoSizeTextType=\"uniform\""))
            assertEquals(f, 3, Regex("android:ellipsize=\"end\"").findAll(w).count().coerceAtMost(3))
        }
    }
}
