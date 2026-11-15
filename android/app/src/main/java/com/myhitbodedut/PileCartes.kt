package com.myhitbodedut

import android.animation.ValueAnimator
import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import kotlin.math.abs

/**
 * La pile de cartes de l'accueil « Pile » (15/11) : les cartes sont l'une sur l'autre,
 * celle du dessus suit le doigt en tournant un peu ; lâchée assez loin, elle s'envole
 * et la suivante remonte. Les cartes de dessous, un peu plus petites, ne se touchent
 * pas et se taisent pour le lecteur d'écran. Sans animations dans le téléphone, la
 * carte change sur place.
 */
class PileCartes @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : FrameLayout(context, attrs) {

    /** Prévenu à chaque changement de carte, avec le rang de la nouvelle. */
    var surChangement: ((Int) -> Unit)? = null

    var position = 0
        private set

    /** Les cartes dans leur ordre de lecture ; bringToFront change l'ordre des enfants, pas celui-ci. */
    private val cartes = mutableListOf<View>()
    private val densite = resources.displayMetrics.density
    private val seuil = ViewConfiguration.get(context).scaledTouchSlop
    private var departX = 0f
    private var departY = 0f
    private var glisse = false
    private var vitesse: VelocityTracker? = null
    private var envol = false

    private val anime: Boolean get() = ValueAnimator.areAnimatorsEnabled()

    override fun onFinishInflate() {
        super.onFinishInflate()
        cartes.clear()
        for (i in 0 until childCount) cartes.add(getChildAt(i))
        // Une carte prend tout toucher qui la vise : il n'atteint pas les boutons de celle de dessous.
        cartes.forEach { it.isClickable = true }
        placer()
    }

    val dessus: View? get() = cartes.getOrNull(position)

    /** Va à la carte [i] (de 0 au nombre de cartes moins un). */
    fun montrer(i: Int) {
        if (cartes.isEmpty()) return
        position = Math.floorMod(i, cartes.size)
        placer()
        surChangement?.invoke(position)
    }

    /** La carte suivante ([sens] = 1) ou précédente (-1) ; la carte du dessus s'envole de ce côté. */
    fun aller(sens: Int) {
        val haut = dessus ?: return
        if (envol) return
        if (!anime) { montrer(position + sens); return }
        envol = true
        val cote = if (layoutDirection == LAYOUT_DIRECTION_RTL) -sens else sens
        haut.animate().cancel()
        haut.animate()
            .translationX(-cote * width * 1.1f)
            .rotation(-cote * 12f)
            .alpha(0f)
            .setDuration(300)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
                envol = false
                haut.translationX = 0f
                haut.rotation = 0f
                haut.alpha = 1f
                montrer(position + sens)
            }
            .start()
    }

    /** Chaque carte à son rang : la première de dessus, les deux suivantes visibles derrière. */
    private fun placer() {
        val n = cartes.size
        for (r in n - 1 downTo 0) cartes[(position + r) % n].bringToFront()
        cartes.forEachIndexed { i, c ->
            val rang = Math.floorMod(i - position, n)
            c.visibility = if (rang <= 2) View.VISIBLE else View.INVISIBLE
            c.importantForAccessibility = if (rang == 0) View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
            else View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            c.isEnabled = rang == 0
            val echelle = 1f - 0.05f * rang
            val bas = rang * 12f * densite
            if (anime && rang == 0) {
                c.animate().scaleX(1f).scaleY(1f).translationY(0f).setDuration(260).setInterpolator(DecelerateInterpolator()).start()
            } else {
                c.animate().cancel()
                c.scaleX = echelle
                c.scaleY = echelle
                c.translationY = bas
                c.translationX = 0f
                c.rotation = 0f
                c.alpha = 1f
            }
        }
        invalidate()
    }

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                departX = ev.x; departY = ev.y; glisse = false
                vitesse?.recycle(); vitesse = VelocityTracker.obtain().apply { addMovement(ev) }
            }
            MotionEvent.ACTION_MOVE -> {
                vitesse?.addMovement(ev)
                val dx = ev.x - departX
                val dy = ev.y - departY
                if (!envol && abs(dx) > seuil && abs(dx) > abs(dy) * 1.5f) {
                    glisse = true
                    parent?.requestDisallowInterceptTouchEvent(true)
                    return true
                }
            }
        }
        return false
    }

    override fun onTouchEvent(ev: MotionEvent): Boolean {
        val haut = dessus ?: return false
        vitesse?.addMovement(ev)
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> return true
            MotionEvent.ACTION_MOVE -> if (glisse) {
                val dx = ev.x - departX
                haut.translationX = dx
                haut.rotation = dx / width.coerceAtLeast(1) * 8f
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (!glisse) return false
                glisse = false
                val dx = ev.x - departX
                val v = vitesse?.run { computeCurrentVelocity(1000); xVelocity } ?: 0f
                vitesse?.recycle(); vitesse = null
                val loin = abs(dx) > width * 0.28f || (abs(v) > 1200 * densite && abs(dx) > seuil)
                if (ev.actionMasked == MotionEvent.ACTION_UP && loin) {
                    // Vers la gauche, la suivante ; vers la droite, la précédente (à l'inverse en hébreu).
                    val gauche = dx < 0
                    val rtl = layoutDirection == LAYOUT_DIRECTION_RTL
                    aller(if (gauche != rtl) 1 else -1)
                } else {
                    haut.animate().translationX(0f).rotation(0f).setDuration(if (anime) 220 else 0).start()
                }
            }
        }
        return true
    }
}
