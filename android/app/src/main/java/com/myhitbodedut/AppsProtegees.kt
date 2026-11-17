package com.myhitbodedut

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.telecom.TelecomManager

/**
 * Les applications que la barrière ne retient jamais (13/11, FBARRIERE-05) : le
 * Téléphone (le composeur par défaut), l'écran d'accueil par défaut et les Réglages
 * d'Android.
 *
 * « Tout sélectionner » les cochait avec le reste, et l'écran de garde se posait alors
 * sur le composeur, l'appel en cours compris, sur l'écran d'accueil où il renvoie
 * lui-même, et sur les Réglages où l'on retire un accès. Elles ne sont plus proposées
 * dans la liste, et le service ne pose jamais l'écran devant elles, même si une liste
 * importée ou choisie avant ce jour les contient (GateRule.proposable).
 *
 * L'écran d'accueil et les Réglages ne se résolvent que s'ils sont visibles de
 * l'application, c'est-à-dire s'ils exposent une icône de lancement (<queries> du
 * manifeste) : ce sont justement ceux que la liste pourrait proposer.
 */
object AppsProtegees {

    fun de(context: Context): Set<String> {
        val paquets = context.packageManager
        fun parDefaut(intent: Intent): String? = runCatching {
            paquets.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
        }.getOrNull()
        val telephone = runCatching {
            (context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)?.defaultDialerPackage
        }.getOrNull()
        return setOfNotNull(
            telephone,
            parDefaut(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)),
            parDefaut(Intent(Settings.ACTION_SETTINGS)),
        )
    }
}
