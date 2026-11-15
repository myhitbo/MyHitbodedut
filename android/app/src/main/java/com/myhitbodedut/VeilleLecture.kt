package com.myhitbodedut

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.WindowManager

/**
 * L'écran reste allumé pendant qu'on lit (audit du 12/11, FLECTURE-01). Avec la mise en veille
 * courante de trente secondes, il s'éteignait au milieu de la Amida ou d'un psaume lu lentement,
 * et il fallait déverrouiller le téléphone en pleine prière.
 *
 * Avec discernement : dix minutes sans toucher l'écran et la veille du téléphone reprend, pour
 * qu'un téléphone posé, ouvert sur une page, ne vide pas sa batterie ; et un réglage le coupe
 * (« Garder l'écran allumé pendant la lecture », allumé par défaut).
 *
 * L'écran de lecture prévient de chaque toucher (onUserInteraction), de son retour au premier
 * plan (onResume) et de son départ (onPause).
 */
class VeilleLecture(private val activite: Activity) {

    private val principal = Handler(Looper.getMainLooper())
    private var allume = false
    private val relacher = Runnable { eteindre() }

    /** Un toucher, ou l'écran qui revient : dix minutes de plus, si le réglage le veut. */
    fun toucher() {
        principal.removeCallbacks(relacher)
        if (!Store.lectureEcranAllume(activite)) return eteindre()
        // Le drapeau n'est posé qu'une fois : le reposer à chaque toucher referait la mise en page de la fenêtre.
        if (!allume) {
            activite.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            allume = true
        }
        principal.postDelayed(relacher, DELAI_MS)
    }

    /** L'écran de lecture quitte le premier plan : plus rien à garder allumé. */
    fun arreter() {
        principal.removeCallbacks(relacher)
        eteindre()
    }

    private fun eteindre() {
        if (!allume) return
        activite.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        allume = false
    }

    companion object {
        /** Sans toucher pendant ce temps, la veille du téléphone reprend. */
        const val DELAI_MS = 10 * 60_000L
    }
}
