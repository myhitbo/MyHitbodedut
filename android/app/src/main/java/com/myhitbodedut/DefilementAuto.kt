package com.myhitbodedut

import android.app.Activity
import android.os.SystemClock
import android.view.Choreographer
import android.view.View
import kotlin.math.pow

/**
 * Le défilement automatique des textes (16/11) : le texte monte tout seul, à la vitesse choisie,
 * pour lire un psaume ou une prière sans toucher l'écran.
 *
 * Dix vitesses, la troisième par défaut, gardées pour tous les écrans de lecture (Store). La
 * vitesse est en lignes plutôt qu'en pixels : elle suit la taille des lettres, pour qu'agrandir
 * le texte ne fasse pas lire plus vite. Les mêmes règles valent sur le site, le Nokia et l'iPhone.
 *
 * Il s'arrête de lui-même au bout du texte, quand on touche le texte, et quand l'écran s'en va.
 *
 * L'écran reste allumé tant qu'il défile (vérification du 24/11) : par la vue qui défile elle-même
 * (keepScreenOn), sur tous les écrans de lecture. VeilleLecture ne suffisait pas : la halakha et les
 * hilloulot n'en ont pas, et elle ne fait rien quand « Garder l'écran allumé » est coupé ; le
 * téléphone s'éteignait alors au bout de trente secondes, en plein défilement. keepScreenOn s'ajoute
 * au drapeau de la fenêtre que pose VeilleLecture sans y toucher, et ne compte que pour une vue à
 * l'écran.
 */
class DefilementAuto(
    private val activite: Activity,
    private val defilement: View,
    /** Appelé quand il démarre ou s'arrête, quelle qu'en soit la raison. */
    private val surEtat: (actif: Boolean) -> Unit,
) {
    var actif = false
        private set

    private val densite = activite.resources.displayMetrics.density
    private val choreographe = Choreographer.getInstance()
    private var dernier = 0L
    private var reste = 0f
    private var dernierReveil = 0L

    private val image = Choreographer.FrameCallback { avancer() }
    private val attente = Runnable { avancer() }

    fun basculer() = if (actif) arreter() else demarrer()

    fun demarrer() {
        if (actif) return
        // Déjà au bout : rien à faire défiler.
        if (!defilement.canScrollVertically(1)) return
        actif = true
        dernier = 0L
        reste = 0f
        dernierReveil = SystemClock.uptimeMillis()
        defilement.keepScreenOn = true
        surEtat(true)
        choreographe.postFrameCallback(image)
    }

    fun arreter() {
        if (!actif) return
        actif = false
        choreographe.removeFrameCallback(image)
        defilement.removeCallbacks(attente)
        defilement.keepScreenOn = false
        surEtat(false)
    }

    private fun avancer() {
        if (!actif) return
        if (activite.isFinishing || activite.isDestroyed || !defilement.isAttachedToWindow) return arreter()
        val maintenant = SystemClock.uptimeMillis()
        // Écran parti, menu ouvert, autre fenêtre devant : en attente, sans avancer ni rattraper le temps.
        if (!activite.hasWindowFocus() || !defilement.isShown) {
            dernier = 0L
            defilement.postDelayed(attente, ATTENTE_MS)
            return
        }
        if (dernier != 0L) {
            val ecoule = (maintenant - dernier).coerceAtMost(MAX_PAS_MS)
            val (pixels, nouveauReste) = pas(
                vitesse(Store.lectureDefilementVitesse(activite), Store.lectureEchelle(activite), densite), ecoule, reste,
            )
            reste = nouveauReste
            if (pixels > 0) defilement.scrollBy(0, pixels)
            if (!defilement.canScrollVertically(1)) return arreter()
        }
        dernier = maintenant
        // Défiler, c'est lire, même sans toucher l'écran : VeilleLecture repart pour dix minutes à chaque
        // minute de défilement, pour que l'écran reste allumé après l'arrêt, le temps de finir la page.
        if (maintenant - dernierReveil >= REVEIL_MS) {
            dernierReveil = maintenant
            activite.onUserInteraction()
        }
        choreographe.postFrameCallback(image)
    }

    companion object {
        const val MIN = 1
        const val MAX = 10
        const val DEFAUT = 3

        /** La première vitesse, en dp par seconde à la taille de base ; chaque vitesse va 1,4 fois plus vite. */
        const val BASE_DP = 6f
        const val RAISON = 1.4f

        private const val ATTENTE_MS = 250L
        private const val MAX_PAS_MS = 100L
        private const val REVEIL_MS = 60_000L

        /** La vitesse [niveau] (1 à 10) en pixels par seconde, pour cette taille de lettres et cet écran. */
        fun vitesse(niveau: Int, echelle: Float, densite: Float): Float =
            BASE_DP * RAISON.pow(niveau.coerceIn(MIN, MAX) - 1) * echelle * densite

        /**
         * Les pixels entiers à défiler pour [ecouleMs] millisecondes, et la fraction gardée pour la fois
         * suivante : sans elle, les vitesses lentes (quelques pixels par seconde, 60 images par seconde)
         * ne bougeraient jamais.
         */
        fun pas(pixelsParSeconde: Float, ecouleMs: Long, reste: Float): Pair<Int, Float> {
            val total = reste + pixelsParSeconde * ecouleMs / 1000f
            val entiers = total.toInt()
            return entiers to (total - entiers)
        }
    }
}
