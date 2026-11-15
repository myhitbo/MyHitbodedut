package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Le travail des receveurs hors du fil principal (15/11) : au changement d'heure ou de fuseau,
 * BootReceiver reprogrammait cinq alarmes et redessinait les vignettes sur le fil principal —
 * trois « l'application ne répond pas » de MainActivity sur l'émulateur, juste après un
 * changement de date. goAsync() garde la diffusion ouverte, finish() la referme toujours.
 */
class ReceveursEnFondTest {

    private fun lire(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()

    @Test
    fun `BootReceiver passe le travail lourd hors du fil principal et referme toujours la diffusion`() {
        val code = lire("BootReceiver.kt")
        assertTrue("goAsync() manque", code.contains("recepteur.goAsync()"))
        val tache = code.substringAfter("val tache = Runnable {").substringBefore("fil.execute(tache)")
        assertTrue("finish() doit être dans un finally", tache.contains("} finally {") &&
            tache.substringAfter("} finally {").contains("fin()"))
        assertTrue(code.contains("lancer(travail) { attente?.finish() }"))

        val recoit = code.substringAfter("override fun onReceive(").substringBefore("private fun etape(")
        val fond = recoit.indexOf("EnFond.recevoir(this) {")
        assertTrue("onReceive doit passer par EnFond", fond > 0)
        listOf("ChoixLieu.reprendreEnFond(context)", "Reminder.reschedule(context)", "ChabbatAlerte.programmer(context)",
            "LevanaAlerte.programmer(context)", "VolAlerte.programmer(context)", "StreakWidget.refresh(context)",
            "ZmanimWidget.refresh(context)").forEach {
            assertTrue("$it doit tourner hors du fil principal", recoit.indexOf(it) > fond)
        }
        // La position reprise avant les alertes, qui lisent le lieu.
        assertTrue(recoit.indexOf("ChoixLieu.reprendreEnFond") < recoit.indexOf("ChabbatAlerte.programmer"))
        // Les drapeaux des services sont tenus sur le fil principal : leurs démarrages y restent.
        listOf("GateService.start(context)", "SessionService.reconcilier(context)").forEach {
            assertTrue("$it reste sur le fil principal", recoit.indexOf(it) in 0 until fond)
        }
    }

    /** La reprise de la position ne demande aucun Looper : elle peut passer hors du fil principal. */
    @Test
    fun `la position reprise en fond ne demande pas de Looper`() {
        val reprise = lire("ChoixLieu.kt").substringAfter("fun reprendreEnFond(").substringBefore("private const val")
        assertTrue(reprise.contains("getLastKnownLocation"))
        listOf("Looper", "Handler", "requestSingleUpdate", "requestLocationUpdates").forEach {
            assertTrue("« $it » dans reprendreEnFond", !reprise.contains(it))
        }
    }

    @Test
    fun `les autres receveurs lourds passent aussi par EnFond`() {
        val vol = lire("VolAlerte.kt").substringAfter("class VolAlerteReceiver")
        assertTrue("les aéroports s'analysent hors du fil principal",
            vol.indexOf("EnFond.recevoir(this)") in 0 until vol.indexOf("Data.aeroports(context)"))
        val tic = lire("ZmanimVignette.kt").substringAfter("class ZmanimTic")
        assertTrue(tic.substringBefore("\n}").contains("EnFond.recevoir(this) { ZmanimWidget.refresh(context) }"))
        val serie = lire("StreakWidget.kt").substringAfter("override fun onUpdate(").substringBefore("companion object")
        assertTrue(serie.indexOf("EnFond.recevoir(this)") in 0 until serie.indexOf("draw(traduit, manager, it)"))
    }

    @Test
    fun `le travail tourne sur un autre fil et la fin vient toujours, meme apres une erreur`() {
        val principal = Thread.currentThread()
        val fils = mutableListOf<Thread>()
        val fini = CountDownLatch(2)
        // L'erreur voulue remonte au fil des receveurs, comme sur le fil principal avant : on la recueille.
        val erreur = CountDownLatch(1)
        val avant = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { _, _ -> erreur.countDown() }
        try {
            EnFond.lancer({ synchronized(fils) { fils += Thread.currentThread() } }) { fini.countDown() }
            EnFond.lancer({ throw IllegalStateException("échec voulu") }) { fini.countDown() }
            assertTrue("finish() n'a pas été appelé", fini.await(5, TimeUnit.SECONDS))
            assertTrue(erreur.await(5, TimeUnit.SECONDS))
        } finally {
            Thread.setDefaultUncaughtExceptionHandler(avant)
        }
        assertEquals(1, fils.size)
        assertNotEquals("le travail est resté sur le fil appelant", principal, fils[0])
    }
}
