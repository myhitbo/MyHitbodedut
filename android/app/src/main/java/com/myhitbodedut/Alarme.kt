package com.myhitbodedut

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Les rappels de l'application (pratique, Chabbat, Levana, vol) posés à
 * l'heure (check-up du 11/11).
 *
 * `setAndAllowWhileIdle` seul est une alarme inexacte : Android peut la
 * retarder des trois quarts du délai restant, jusqu'à une heure. Chaque
 * rappel est donc posé deux fois, sans permission d'alarme exacte :
 * - `setWindow` avec une fenêtre de 10 min (le minimum accepté depuis
 *   Android 12) : à l'heure tant que le téléphone ne dort pas profondément ;
 * - `setAndAllowWhileIdle` en filet : passe la veille profonde.
 * La première qui sonne affiche le rappel ; le récepteur reprogramme alors
 * le suivant, ce qui annule l'autre.
 */
object Alarme {

    const val FENETRE_MS = 10 * 60_000L

    /** Écart de code de requête entre l'alarme à l'heure et son filet de veille. */
    const val ECART_VEILLE = 5_000

    private fun pending(context: Context, requete: Int, recepteur: Class<out BroadcastReceiver>): PendingIntent =
        PendingIntent.getBroadcast(
            context, requete, Intent(context, recepteur),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun annuler(context: Context, requete: Int, recepteur: Class<out BroadcastReceiver>) {
        val alarmes = context.getSystemService(AlarmManager::class.java) ?: return
        alarmes.cancel(pending(context, requete, recepteur))
        alarmes.cancel(pending(context, requete + ECART_VEILLE, recepteur))
    }

    fun poser(context: Context, requete: Int, recepteur: Class<out BroadcastReceiver>, quand: Long) {
        val alarmes = context.getSystemService(AlarmManager::class.java) ?: return
        runCatching { alarmes.setWindow(AlarmManager.RTC_WAKEUP, quand, FENETRE_MS, pending(context, requete, recepteur)) }
        runCatching { alarmes.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quand, pending(context, requete + ECART_VEILLE, recepteur)) }
    }
}
