package com.myhitbodedut

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Relance la surveillance et le rappel quand ce qui les portait a disparu.
 *
 * Au redémarrage, bien sûr ; mais aussi après une mise à jour de
 * l'application, qui arrêtait la barrière du matin jusqu'à la prochaine
 * ouverture, et quand l'heure ou le fuseau changent — en voyage, le rappel
 * sonnait encore à l'heure de l'endroit quitté (revue du 29/09).
 *
 * Le gros du travail passe hors du fil principal (15/11) : cinq alarmes
 * reprogrammées, les vignettes redessinées, la position reprise, le tout sur le
 * fil principal, retardait l'écran ouvert — trois « l'application ne répond
 * pas » de MainActivity juste après un changement de date sur l'émulateur.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(brut: Context, intent: Intent) {
        if (intent.action !in ACTIONS) return
        // Le rappel et la vignette dans la langue de l'application (LangueApp).
        val context = LangueApp.envelopper(brut)
        // Sur le fil principal : la barrière et la séance lisent et posent des drapeaux que leurs
        // services tiennent sur ce fil (enMarche, demarrage). Ce sont deux démarrages de service.
        if (BuildConfig.HAS_GATE && GateStatus.shouldRunService(context)) {
            runCatching { GateService.start(context) }
        }
        // Une séance en cours quand le téléphone s'est éteint : échue, elle
        // est inscrite pour sa durée ; sinon elle reprend si Android le permet.
        SessionService.reconcilier(context)
        val fuseau = intent.action == Intent.ACTION_TIMEZONE_CHANGED
        EnFond.recevoir(this) {
            // En voyage, la position du téléphone de l'endroit quitté (02/11) : reprise si Android
            // en connaît une récente, sinon les alertes attendent l'ouverture de l'application.
            // Avant les alertes, qui lisent le lieu. Dernière position connue : aucun Looper.
            if (fuseau) etape { ChoixLieu.reprendreEnFond(context) }
            // Chaque étape à part : l'échec de l'une n'empêche plus les suivantes.
            etape { Reminder.reschedule(context) }
            etape { ChabbatAlerte.programmer(context) }
            etape { LevanaAlerte.programmer(context) }
            etape { VolAlerte.programmer(context) }
            etape { StreakWidget.refresh(context) }
            etape { ZmanimWidget.refresh(context) }
        }
    }

    private fun etape(travail: () -> Unit) {
        runCatching(travail)
    }

    private companion object {
        val ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
        )
    }
}

/**
 * Le travail d'un receveur hors du fil principal (15/11). onReceive tourne sur le fil principal
 * de l'application : tant qu'il dure, l'écran ouvert ne répond plus. goAsync() garde la diffusion
 * ouverte le temps du travail (une dizaine de secondes au plus) ; finish() la referme toujours,
 * même quand le travail échoue. Rien de ce qui passe ici ne touche une vue ni ne demande de Looper.
 */
object EnFond {
    /** Un seul fil : deux receveurs ne reprogramment pas les mêmes alarmes ni les mêmes vignettes ensemble. */
    private val fil by lazy {
        Executors.newSingleThreadExecutor { r -> Thread(r, "receveurs").apply { isDaemon = true } }
    }

    /** À n'appeler que pendant onReceive (ou onUpdate d'une vignette, qui en part). */
    fun recevoir(recepteur: BroadcastReceiver, travail: () -> Unit) {
        val attente = recepteur.goAsync()
        lancer(travail) { attente?.finish() }
    }

    /** [travail] sur le fil des receveurs, puis [fin] quoi qu'il arrive. */
    internal fun lancer(travail: () -> Unit, fin: () -> Unit) {
        val tache = Runnable {
            try {
                travail()
            } finally {
                fin()
            }
        }
        try {
            fil.execute(tache)
        } catch (e: RejectedExecutionException) {
            tache.run()
        }
    }
}
