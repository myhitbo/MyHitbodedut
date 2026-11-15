package com.myhitbodedut

import android.content.Context
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.LightingColorFilter
import android.graphics.LinearGradient
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.View
import android.view.ViewOutlineProvider
import androidx.core.content.ContextCompat
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Le bandeau « Ciel » de l'accueil (15/11) : le ciel du lieu à cette heure
 * (CielDuJour), le soleil sur l'arc des zmanim, les étoiles la nuit, et le
 * hassid sur sa colline. Une image fixe, redessinée chaque minute tant qu'elle
 * est à l'écran : aucune animation continue, rien qui tourne écran éteint.
 *
 * Il ne porte aucun texte : le prochain zman s'écrit dessous, sur le fond de
 * l'écran.
 */
class CielView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {

    /** Appelé chaque minute tant que le bandeau est visible : l'écran recalcule le ciel. */
    var aChaqueMinute: (() -> Unit)? = null

    private var ciel: CielDuJour.Ciel? = null
    private val densite = resources.displayMetrics.density
    private fun dp(v: Float) = v * densite

    private val fond = Paint(Paint.ANTI_ALIAS_FLAG)
    private val trait = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(1.5f)
        strokeCap = Paint.Cap.ROUND
        pathEffect = DashPathEffect(floatArrayOf(dp(0.5f), dp(6f)), 0f)
    }
    private val plein = Paint(Paint.ANTI_ALIAS_FLAG)
    private val halo = Paint(Paint.ANTI_ALIAS_FLAG)
    private val colline1 = Path()
    private val colline2 = Path()
    private val lune = Path()
    private val arc = RectF()
    private val personnage: Drawable? =
        runCatching { ContextCompat.getDrawable(context, Personnage.pour(context, R.drawable.char_praise)) }.getOrNull()

    private val minute = object : Runnable {
        override fun run() {
            aChaqueMinute?.invoke()
            postDelayed(this, delaiJusquALaMinute())
        }
    }

    init {
        outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, dp(20f))
            }
        }
        clipToOutline = true
    }

    fun montrer(c: CielDuJour.Ciel) {
        if (c == ciel) return
        ciel = c
        fond.shader = LinearGradient(0f, 0f, 0f, height.toFloat().coerceAtLeast(1f), c.haut, c.bas, Shader.TileMode.CLAMP)
        invalidate()
    }

    private fun delaiJusquALaMinute(): Long = 60_000L - System.currentTimeMillis() % 60_000L + 200L

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        removeCallbacks(minute)
        if (visibility == VISIBLE) postDelayed(minute, delaiJusquALaMinute())
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(minute)
        super.onDetachedFromWindow()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val l = w.toFloat()
        val t = h.toFloat()
        colline1.reset()
        colline1.moveTo(0f, t * 0.78f)
        colline1.cubicTo(l * 0.18f, t * 0.70f, l * 0.38f, t * 0.72f, l * 0.54f, t * 0.77f)
        colline1.cubicTo(l * 0.70f, t * 0.82f, l * 0.85f, t * 0.74f, l, t * 0.71f)
        colline1.lineTo(l, t); colline1.lineTo(0f, t); colline1.close()
        colline2.reset()
        colline2.moveTo(0f, t * 0.90f)
        colline2.cubicTo(l * 0.23f, t * 0.83f, l * 0.46f, t * 0.85f, l * 0.64f, t * 0.88f)
        colline2.cubicTo(l * 0.80f, t * 0.91f, l * 0.90f, t * 0.87f, l, t * 0.85f)
        colline2.lineTo(l, t); colline2.lineTo(0f, t); colline2.close()
        // L'arc du soleil, du lever (à gauche) au coucher (à droite), sous les collines à ses bouts.
        arc.set(l * 0.08f, t * 0.20f, l * 0.92f, t * 1.40f)
        // Le croissant : un disque moins un disque décalé.
        val cx = l * 0.82f
        val cy = t * 0.24f
        val r = dp(9f)
        lune.reset()
        lune.addCircle(cx, cy, r, Path.Direction.CW)
        lune.op(Path().apply { addCircle(cx + r * 0.55f, cy - r * 0.35f, r * 0.9f, Path.Direction.CW) }, Path.Op.DIFFERENCE)
        ciel?.let { c -> fond.shader = LinearGradient(0f, 0f, 0f, t, c.haut, c.bas, Shader.TileMode.CLAMP) }
    }

    /** Le point de l'arc à la part [p] du jour (0 au lever, 1 au coucher). */
    private fun surArc(p: Float): Pair<Float, Float> {
        val a = PI * p
        val rx = arc.width() / 2f
        val ry = arc.height() / 2f
        return (arc.centerX() - rx * cos(a)).toFloat() to (arc.centerY() - ry * sin(a)).toFloat()
    }

    override fun onDraw(canvas: Canvas) {
        val c = ciel ?: return
        val l = width.toFloat()
        val t = height.toFloat()
        canvas.drawRect(0f, 0f, l, t, fond)

        // Les étoiles, puis la lune : seulement quand la nuit tombe.
        if (c.nuit > 0.02f) {
            plein.color = CielDuJour.BLANC
            for (i in 0 until 18) {
                plein.alpha = (c.nuit * (140 + (i % 4) * 38)).roundToInt().coerceIn(0, 255)
                canvas.drawCircle(((i * 97) % 100) / 100f * l, (0.06f + ((i * 53) % 58) / 100f) * t, dp(1f + (i % 3) * 0.4f), plein)
            }
            plein.color = CielDuJour.LUNE
            plein.alpha = (c.nuit * 255).roundToInt().coerceIn(0, 255)
            canvas.drawPath(lune, plein)
        }

        // L'arc des zmanim et ses quatre points : lever, 'hatsot, min'ha ketana, coucher.
        val clair = CielDuJour.luminance(c.haut) > 0.28
        trait.color = if (clair) 0x5918203A else 0x73F5F2EA
        canvas.drawArc(arc, 180f, 180f, false, trait)
        plein.color = trait.color
        listOf(0f, c.chatsot, c.minhaKetana, 1f).forEach { p ->
            val (x, y) = surArc(p)
            canvas.drawCircle(x, y, dp(3f), plein)
        }

        // Le soleil et son halo, qui se couche derrière les collines.
        c.soleil?.let { p ->
            val (x, y) = surArc(p)
            halo.shader = RadialGradient(x, y, dp(26f), CielDuJour.HALO, 0x00FFD66E, Shader.TileMode.CLAMP)
            canvas.drawCircle(x, y, dp(26f), halo)
            plein.color = if (p < 0.12f || p > 0.85f) CielDuJour.SOLEIL_BAS else CielDuJour.SOLEIL
            canvas.drawCircle(x, y, dp(10f), plein)
        }

        plein.color = CielDuJour.melange(CielDuJour.COLLINE_JOUR, CielDuJour.COLLINE_NUIT, c.nuit)
        canvas.drawPath(colline1, plein)
        plein.color = CielDuJour.melange(CielDuJour.COLLINE_PRES_JOUR, CielDuJour.COLLINE_PRES_NUIT, c.nuit)
        canvas.drawPath(colline2, plein)

        // Le hassid sur la colline, un peu dans l'ombre la nuit.
        personnage?.let { d ->
            val hauteur = t * 0.46f
            val largeur = if (d.intrinsicHeight > 0) hauteur * d.intrinsicWidth / d.intrinsicHeight else hauteur * 0.6f
            val bas = t * 0.90f
            val gauche = l * 0.80f - largeur / 2f
            d.setBounds(gauche.roundToInt(), (bas - hauteur).roundToInt(), (gauche + largeur).roundToInt(), bas.roundToInt())
            val lumiere = (255 * (1f - c.nuit * 0.45f)).roundToInt().coerceIn(0, 255)
            d.colorFilter = if (lumiere < 255) LightingColorFilter((lumiere shl 16) or (lumiere shl 8) or lumiere, 0) else null
            d.draw(canvas)
        }
    }
}
