package com.myhitbodedut

import android.animation.ValueAnimator
import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import androidx.core.graphics.ColorUtils
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * L'écran pendant la pratique (16/10, point 2) : six secondes sans toucher,
 * et tout s'efface sauf le minuteur, sa lueur et « Terminer » ; les barres du
 * téléphone se cachent, le fond s'assombrit. Un toucher n'importe où ramène
 * tout pour six secondes, sans déclencher ce qu'il y avait dessous, quand le toucher
 * tombe sur ce qui s'était effacé : on ne touche pas un bouton qu'on ne voyait pas.
 *
 * Ce qui s'efface ne change que d'opacité : render(), qui repasse chaque
 * seconde, garde la main sur ce qui est visible ou non.
 */
class PratiqueCalme(
    private val activite: Activity,
    private val fond: View,
    private val couleurFond: Int,
    /** Ce qui reste visible par-dessus ce qui s'efface (le mini-lecteur) : son toucher passe. */
    private val restes: () -> List<View> = { emptyList() },
    private val effaces: () -> List<View>,
) {
    private val handler = Handler(Looper.getMainLooper())
    private val sombre = ColorUtils.blendARGB(couleurFond, 0xFF000000.toInt(), 0.55f)
    private var enCours = false
    var calme = false
        private set
    /** Le geste qui a réveillé l'écran : avalé jusqu'au bout. */
    private var avale = false

    private val endormir = Runnable { entrer() }

    /** À chaque passage de render() : en pratique ou non. */
    fun suivre(pratique: Boolean) {
        if (pratique == enCours) return
        enCours = pratique
        if (pratique) attendre() else { handler.removeCallbacks(endormir); sortir(anime = false) }
    }

    /** À appeler depuis dispatchTouchEvent : true si le geste est avalé. */
    fun toucher(e: MotionEvent): Boolean {
        if (e.actionMasked == MotionEvent.ACTION_DOWN) {
            // Seul un geste tombé sur une vue effacée est avalé : « Terminer », le guide ou le
            // mini-lecteur, restés visibles, reçoivent leur toucher (FSEANCE-08).
            avale = calme && surUneVueEffacee(e)
            if (calme) sortir(anime = true)
            if (enCours) attendre()
        }
        val garde = avale
        if (e.actionMasked == MotionEvent.ACTION_UP || e.actionMasked == MotionEvent.ACTION_CANCEL) avale = false
        return garde
    }

    private fun surUneVueEffacee(e: MotionEvent): Boolean {
        // Les coordonnées de la fenêtre, celles de getGlobalVisibleRect : rawX et rawY sont
        // celles de l'écran, décalées en écran partagé ou en fenêtre libre.
        val x = e.x.toInt()
        val y = e.y.toInt()
        val zone = android.graphics.Rect()
        // isShown, pas la seule visibilité de la vue : getGlobalVisibleRect ne regarde pas
        // si un parent est masqué. Le mini-lecteur flotte au-dessus du bas de l'écran, où
        // tombent souvent le 'hizouk ou « Je n'arrive pas à parler » : il passe en premier.
        fun dedans(v: View) = v.isShown && v.getGlobalVisibleRect(zone) && zone.contains(x, y)
        if (restes().any(::dedans)) return false
        return effaces().any(::dedans)
    }

    fun liberer() {
        handler.removeCallbacks(endormir)
        teinte?.cancel()
        barres(true)
    }

    /** Une touche (clavier, contacteur) réveille aussi l'écran, sans être avalée. */
    fun touche() {
        if (calme) sortir(anime = true)
        if (enCours) attendre()
    }

    /** Avec TalkBack, rien ne s'efface : un bouton invisible resterait atteignable (revue du 16/10). */
    private val lectureEcran: Boolean
        get() = (activite.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE) as? android.view.accessibility.AccessibilityManager)
            ?.isTouchExplorationEnabled == true

    private fun attendre() {
        handler.removeCallbacks(endormir)
        handler.postDelayed(endormir, DELAI_MS)
    }

    private fun entrer() {
        if (!enCours || calme || lectureEcran) return
        calme = true
        val d = duree(900L)
        effaces().forEach { it.animate().alpha(0f).setDuration(d).start() }
        teinter(couleurFond, sombre, d)
        barres(false)
    }

    private fun sortir(anime: Boolean) {
        val etait = calme
        calme = false
        val d = if (anime) duree(250L) else 0L
        effaces().forEach { it.animate().cancel(); if (d == 0L) it.alpha = 1f else it.animate().alpha(1f).setDuration(d).start() }
        if (etait) teinter(sombre, couleurFond, d) else fond.setBackgroundColor(couleurFond)
        barres(true)
    }

    /** La teinte en cours : annulée avant toute autre, sinon la plus lente finissait en dernier. */
    private var teinte: ValueAnimator? = null

    private fun teinter(de: Int, a: Int, d: Long) {
        teinte?.cancel()
        teinte = null
        if (d == 0L) { fond.setBackgroundColor(a); return }
        teinte = ValueAnimator.ofArgb(de, a).apply {
            duration = d
            addUpdateListener { fond.setBackgroundColor(it.animatedValue as Int) }
            start()
        }
    }

    private fun barres(visibles: Boolean) {
        val c = WindowCompat.getInsetsController(activite.window, activite.window.decorView)
        if (visibles) c.show(WindowInsetsCompat.Type.systemBars())
        else {
            c.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            c.hide(WindowInsetsCompat.Type.systemBars())
        }
    }

    /** Animations coupées sur le téléphone : tout se fait d'un coup. */
    private fun duree(ms: Long) = if (ValueAnimator.areAnimatorsEnabled()) ms else 0L

    companion object {
        const val DELAI_MS = 6_000L
    }
}
