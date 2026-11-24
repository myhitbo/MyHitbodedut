package com.myhitbodedut

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Le filet de la fin de séance (relecture du 23/11).
 *
 * Le service de séance clôt lui-même la séance à son terme. Mais s'il est tué
 * avant sans être relancé (surcouche qui arrête les services écran éteint,
 * bouton « Arrêter » des applications actives d'Android 13), plus rien ne
 * tournait jusqu'à la prochaine ouverture de l'application : « Ne pas
 * déranger », posé au début, restait allumé — les appels coupés —, et la
 * séance n'était inscrite qu'alors.
 *
 * Une alarme est donc posée au terme prévu, par [Alarme] (sans permission
 * d'alarme exacte). Elle appelle [SessionService.reconcilier], qui ne fait
 * rien si le service vit ou si la séance est déjà close, et sinon inscrit la
 * séance échue et rétablit le mode. Une séance ouverte, sans terme, n'en a pas.
 */
class SessionFiletReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        // Dans la langue de l'application (LangueApp), comme BootReceiver : la séance inscrite ici
        // peut annoncer un trophée, et les noms des canaux de notification sont réécrits.
        runCatching { SessionService.reconcilier(LangueApp.envelopper(context)) }
    }

    companion object {
        private const val REQUETE = 170

        /** Après le terme : le service, s'il vit, a déjà clos la séance et retiré le filet. */
        private const val MARGE_MS = 60_000L

        /** Pose le filet au terme de la séance inscrite ; le retire s'il n'y a pas de terme. */
        fun poser(context: Context) {
            val fin = Store.sessionFinMurale(context)
            if (fin <= 0L || Store.isSessionOpen(context)) {
                annuler(context)
                return
            }
            Alarme.poser(context, REQUETE, SessionFiletReceiver::class.java, fin + MARGE_MS)
        }

        fun annuler(context: Context) = Alarme.annuler(context, REQUETE, SessionFiletReceiver::class.java)
    }
}
