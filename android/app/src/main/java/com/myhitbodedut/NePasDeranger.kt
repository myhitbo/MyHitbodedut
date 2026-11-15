package com.myhitbodedut

import android.app.NotificationManager
import android.content.Context

/**
 * « Ne pas déranger » pendant la hitbodedout (14/10) : au début de la séance, le
 * téléphone passe en mode « priorité » (les alarmes et les appels prioritaires
 * passent, comme l'utilisateur les a réglés) ; à la fin, il revient à « tout passe » (il n'est
 * posé que si rien n'était réglé avant). Seulement si l'option est cochée et qu'Android a donné l'accès
 * (Réglages → « Ne pas déranger », autorisation à accorder une fois).
 */
object NePasDeranger {

    private fun nm(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun accesAccorde(context: Context): Boolean = runCatching { nm(context).isNotificationPolicyAccessGranted }.getOrDefault(false)

    fun activer(context: Context) {
        if (!Store.nePasDeranger(context) || !accesAccorde(context)) return
        val nm = nm(context)
        // Déjà posé par l'application : une relance du service n'y revient pas.
        if (Store.filtreAvantSeance(context) != null) return
        val courant = nm.currentInterruptionFilter
        // Déjà en « Ne pas déranger » (mode coucher, réglage de l'utilisateur) : ce
        // n'est pas à nous d'y toucher, ni de le « rétablir » ensuite (audit FSEANCE-01).
        if (!doitActiver(courant)) return
        Store.setFiltreAvantSeance(context, courant)
        runCatching { nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY) }
    }

    /**
     * Le mode n'est posé que sur un téléphone sans « Ne pas déranger » : le mode d'avant est
     * alors toujours « tout passe ». Dès Android 15, setInterruptionFilter n'agit plus que sur
     * une règle propre à l'application, que seul « tout passe » désactive : rétablir un autre
     * mode la laissait active après la séance.
     */
    fun doitActiver(filtreCourant: Int): Boolean = filtreCourant == NotificationManager.INTERRUPTION_FILTER_ALL

    /**
     * Rétablit le mode, quel que soit le chemin qui clôt la séance (fin, arrêt, processus
     * mort puis séance reprise, « Tout effacer »). Sans effet si l'application n'a rien posé.
     */
    fun retablir(context: Context) {
        Store.filtreAvantSeance(context) ?: return
        Store.setFiltreAvantSeance(context, null)
        if (accesAccorde(context)) {
            runCatching { nm(context).setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL) }
        }
    }
}
