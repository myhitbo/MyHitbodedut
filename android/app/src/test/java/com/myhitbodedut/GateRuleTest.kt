package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * La règle de la barrière, sans appareil (13/11, FPRODUIT-01, FBARRIERE-01, FBARRIERE-05,
 * FBARRIERE-08, FACCUEIL-06, TFRUX-02, TFRUX-05) : elle n'a jamais tourné sur un téléphone
 * dans cette construction, sa décision au moins est tenue ici.
 */
class GateRuleTest {

    /** Tout est en place, dans la fenêtre : l'état armé. */
    private val arme = GateFaits(
        active = true, accesAccordes = true, applications = 3, serviceVivant = true,
        seanceEnCours = false, faite = false, exempte = false, reportee = false, dansLaFenetre = true,
    )

    @Test
    fun `tout en place dans la fenetre arme la barriere`() {
        assertEquals(GateState.ARMED, GateRule.etat(arme))
        assertEquals(BlockerMode.PROMPT, GateRule.ecran(GateState.ARMED))
    }

    @Test
    fun `le mode eteint passe avant les acces manquants`() {
        val eteint = arme.copy(active = false, accesAccordes = false, applications = 0)
        assertEquals(GateState.DISABLED, GateRule.etat(eteint))
        assertEquals(GateState.MISSING_PERMISSIONS, GateRule.etat(arme.copy(accesAccordes = false)))
        assertEquals(GateState.NO_APPS_SELECTED, GateRule.etat(arme.copy(applications = 0)))
    }

    @Test
    fun `un service arrete n est jamais dit en veille`() {
        assertEquals(GateState.SERVICE_STOPPED, GateRule.etat(arme.copy(serviceVivant = false)))
        // Hors fenêtre aussi : il ne surveillera rien demain matin non plus.
        assertEquals(GateState.SERVICE_STOPPED, GateRule.etat(arme.copy(serviceVivant = false, dansLaFenetre = false)))
        assertNull(GateRule.ecran(GateState.SERVICE_STOPPED))
    }

    @Test
    fun `une hitbodedout en cours bloque a toute heure et la carte le dit`() {
        val seance = arme.copy(seanceEnCours = true)
        for (variante in listOf(seance, seance.copy(faite = true), seance.copy(exempte = true),
            seance.copy(reportee = true), seance.copy(dansLaFenetre = false))) {
            assertEquals(GateState.SESSION_RUNNING, GateRule.etat(variante))
        }
        assertEquals(BlockerMode.SESSION_RUNNING, GateRule.ecran(GateState.SESSION_RUNNING))
    }

    @Test
    fun `les autres etats ne posent aucun ecran`() {
        val sansEcran = GateState.values().filter { it != GateState.ARMED && it != GateState.SESSION_RUNNING }
        sansEcran.forEach { assertNull("$it", GateRule.ecran(it)) }
        assertEquals(GateState.ALREADY_DONE, GateRule.etat(arme.copy(faite = true)))
        assertEquals(GateState.EXEMPT_DAY, GateRule.etat(arme.copy(exempte = true)))
        assertEquals(GateState.SNOOZED, GateRule.etat(arme.copy(reportee = true)))
        assertEquals(GateState.OUTSIDE_WINDOW, GateRule.etat(arme.copy(dansLaFenetre = false)))
    }

    @Test
    fun `la fenetre est semi ouverte et passe minuit`() {
        assertTrue(GateRule.dansLaFenetre(6 * 60, 6 * 60, 10 * 60))
        assertFalse(GateRule.dansLaFenetre(10 * 60, 6 * 60, 10 * 60))
        assertFalse(GateRule.dansLaFenetre(5 * 60 + 59, 6 * 60, 10 * 60))
        assertTrue(GateRule.dansLaFenetre(23 * 60, 21 * 60, 2 * 60))
        assertTrue(GateRule.dansLaFenetre(60, 21 * 60, 2 * 60))
        assertFalse(GateRule.dansLaFenetre(12 * 60, 21 * 60, 2 * 60))
    }

    @Test
    fun `le service doit tourner des que les reglages sont bons`() {
        assertTrue(GateRule.doitTourner(avecBarriere = true, active = true, accesAccordes = true))
        assertFalse(GateRule.doitTourner(avecBarriere = false, active = true, accesAccordes = true))
        assertFalse(GateRule.doitTourner(avecBarriere = true, active = false, accesAccordes = true))
        assertFalse(GateRule.doitTourner(avecBarriere = true, active = true, accesAccordes = false))
    }

    @Test
    fun `le telephone l accueil et les reglages ne sont jamais retenus`() {
        val protegees = setOf("com.android.dialer", "com.android.launcher", "com.android.settings")
        val choisies = protegees + "com.exemple.reseau"
        protegees.forEach {
            assertFalse(it, GateRule.proposable(it, "com.myhitbodedut", protegees))
            assertFalse(it, GateRule.retenue(it, "com.myhitbodedut", choisies) { protegees })
        }
        assertTrue(GateRule.retenue("com.exemple.reseau", "com.myhitbodedut", choisies) { protegees })
        assertFalse(GateRule.proposable("com.myhitbodedut", "com.myhitbodedut", protegees))
    }

    @Test
    fun `les applications protegees ne sont lues que pour une application choisie`() {
        var lectures = 0
        val lire = { lectures++; emptySet<String>() }
        assertFalse(GateRule.retenue(null, "moi", setOf("a"), lire))
        assertFalse(GateRule.retenue("b", "moi", setOf("a"), lire))
        assertEquals(0, lectures)
        assertTrue(GateRule.retenue("a", "moi", setOf("a"), lire))
        assertEquals(1, lectures)
    }

    @Test
    fun `la pastille d accueil ne bascule que si le mode peut agir`() {
        assertEquals(GesteBarriere.REGLER, GateRule.geste(arme.copy(accesAccordes = false)))
        assertEquals(GesteBarriere.REGLER, GateRule.geste(arme.copy(applications = 0, active = false)))
        assertEquals(GesteBarriere.RELANCER, GateRule.geste(arme.copy(serviceVivant = false)))
        assertEquals(GesteBarriere.BASCULER, GateRule.geste(arme))
        // Éteint mais réglé : la touche l'allume, le service n'étant pas encore lancé.
        assertEquals(GesteBarriere.BASCULER, GateRule.geste(arme.copy(active = false, serviceVivant = false)))
    }

    @Test
    fun `chaque etat a un mot court pour la pastille`() {
        GateState.values().forEach { GateStatus.pastilleDe(it) }
        assertEquals(GateStatus.pastilleDe(GateState.MISSING_PERMISSIONS), GateStatus.pastilleDe(GateState.NO_APPS_SELECTED))
    }

    @Test
    fun `les reglages ne reclament pas ce qui n est pas allume`() {
        val rienAccorde = { _: Autorisation -> false }
        // Mode éteint : seules les notifications sont signalées ; la batterie jamais.
        assertEquals(listOf(Autorisation.NOTIFICATIONS), PermissionRules.aSignaler(true, false, rienAccorde))
        // Mode allumé : les deux accès de la barrière comptent aussi, la batterie toujours pas.
        assertEquals(
            listOf(Autorisation.NOTIFICATIONS, Autorisation.OVERLAY, Autorisation.USAGE),
            PermissionRules.aSignaler(true, true, rienAccorde)
        )
        // Édition légère : pas de barrière.
        assertEquals(listOf(Autorisation.NOTIFICATIONS), PermissionRules.aSignaler(false, true, rienAccorde))
        assertEquals(emptyList<Autorisation>(), PermissionRules.aSignaler(true, true) { true })
    }

    @Test
    fun `le service rattrape le refus d Android de le lancer au premier plan`() {
        val code = File("src/main/java/com/myhitbodedut/GateService.kt").readLines()
            .filterNot { it.trim().startsWith("//") || it.trim().startsWith("*") }.joinToString("\n")
        // startForegroundService et startForeground : jamais sans runCatching (Android 12 et plus).
        assertTrue(code.contains("runCatching {\n                context.startForegroundService"))
        assertTrue(code.contains("val reussi = runCatching {"))
        assertTrue(code.contains("START_NOT_STICKY"))
    }

    @Test
    fun `les libelles de la barriere existent dans les trois langues`() {
        val cles = listOf(
            "gate_stopped_title", "gate_stopped_detail", "gate_stopped_action", "gate_session_detail",
            "start_focus_setup", "start_focus_stopped", "permission_optional_off",
        )
        listOf("values", "values-en", "values-iw").forEach { dossier ->
            val xml = File("src/main/res/$dossier/strings.xml").readText()
            cles.forEach { assertTrue("$dossier : « $it » manquant", xml.contains("""name="$it"""")) }
        }
    }
}
