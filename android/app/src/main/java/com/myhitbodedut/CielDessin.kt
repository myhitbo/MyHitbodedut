package com.myhitbodedut

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import androidx.core.graphics.ColorUtils

/**
 * La fenêtre ronde au creux des anneaux (étape 3 de la refonte, 14/11) : le ciel du moment,
 * l'astre, la colline du champ où l'on sort, et la nuit le rond de lumière de la lanterne où
 * se tient le 'hassid. Posée en fond de la plaque à la place du disque clair.
 *
 * La nuit, la lueur couvre le personnage : le liseré clair de son détourage (README, « Les
 * illustrations ») ne se voit pas sur le sombre.
 *
 * Les mesures sont celles de la maquette, sur un carré de 188 ; le contour est un ovale, pour
 * que la plaque reste ronde (clipToOutline).
 */
class CielDessin(phase: CielDuJour.Phase) : Drawable() {

    var phase: CielDuJour.Phase = phase
        set(v) {
            if (field != v) { field = v; invalidateSelf() }
        }

    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val colline = Path().apply {
        moveTo(0f, 162f); quadTo(94f, 124f, 188f, 162f); lineTo(188f, 188f); lineTo(0f, 188f); close()
    }
    private val efface = PorterDuffXfermode(PorterDuff.Mode.CLEAR)

    override fun draw(canvas: Canvas) {
        val b = bounds
        if (b.width() <= 0 || b.height() <= 0) return
        val c = CielDuJour.PALETTES.getValue(phase)
        val s = maxOf(b.width(), b.height()) / COTE
        canvas.save()
        canvas.translate(b.exactCenterX() - COTE * s / 2f, b.exactCenterY() - COTE * s / 2f)
        canvas.scale(s, s)

        // Le ciel.
        p.shader = LinearGradient(0f, 0f, 0f, COTE, intArrayOf(c.haut, c.milieu, c.horizon), floatArrayOf(0f, .55f, 1f), Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, COTE, COTE, p)
        p.shader = null

        when (phase) {
            CielDuJour.Phase.NUIT -> {
                p.color = ETOILE
                ETOILES.forEach { (x, y, r) -> canvas.drawCircle(x, y, r, p) }
                // Le croissant : la lune, moins un disque décalé.
                val couche = canvas.saveLayer(110f, 10f, 170f, 70f, null)
                p.color = c.astre
                canvas.drawCircle(139f, 38f, 14f, p)
                p.xfermode = efface
                canvas.drawCircle(146.7f, 34.5f, 14f, p)
                p.xfermode = null
                canvas.restoreToCount(couche)
            }
            else -> {
                val (x, y, r, lueur) = ASTRES.getValue(phase)
                p.shader = RadialGradient(x, y, lueur, ColorUtils.setAlphaComponent(c.lueur, 217), ColorUtils.setAlphaComponent(c.lueur, 0), Shader.TileMode.CLAMP)
                canvas.drawCircle(x, y, lueur, p)
                p.shader = null
                p.color = c.astre
                canvas.drawCircle(x, y, r, p)
                if (phase == CielDuJour.Phase.JOUR) {
                    p.color = NUAGE
                    NUAGES.forEach { canvas.drawOval(it, p) }
                }
            }
        }

        // La colline : le champ où l'on sort.
        p.color = c.colline
        canvas.drawPath(colline, p)

        // La nuit, le rond de lumière de la lanterne.
        if (phase == CielDuJour.Phase.NUIT) {
            p.shader = RadialGradient(94f, 94f, 117f, intArrayOf(LANTERNE, ColorUtils.setAlphaComponent(LANTERNE, 204), ColorUtils.setAlphaComponent(LANTERNE, 0)),
                floatArrayOf(0f, .5f, 1f), Shader.TileMode.CLAMP)
            canvas.drawCircle(94f, 94f, 117f, p)
            p.shader = null
        }
        canvas.restore()
    }

    override fun getOutline(outline: Outline) = outline.setOval(bounds)

    override fun setAlpha(alpha: Int) {
        p.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        p.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

    /** Un astre : son centre, son rayon, et celui de sa lueur. */
    private data class Astre(val x: Float, val y: Float, val r: Float, val lueur: Float)

    companion object {
        /** Le côté du carré de la maquette. */
        const val COTE = 188f

        private val ASTRES = mapOf(
            CielDuJour.Phase.AUBE to Astre(53f, 150f, 21f, 85f),
            CielDuJour.Phase.JOUR to Astre(139f, 41f, 14f, 56f),
            CielDuJour.Phase.COUCHER to Astre(132f, 150f, 26f, 103f),
        )
        private val NUAGES = listOf(RectF(26f, 48.5f, 64f, 63.5f), RectF(48f, 43f, 72f, 57f), RectF(139f, 86f, 169f, 98f))
        private val ETOILES = listOf(
            Triple(22f, 40f, 1.2f), Triple(40f, 22f, 1f), Triple(58f, 52f, 1.6f), Triple(80f, 14f, 1f), Triple(98f, 34f, 1.2f),
            Triple(118f, 18f, 1.4f), Triple(160f, 64f, 1.1f), Triple(170f, 30f, 1f), Triple(30f, 78f, 1f), Triple(150f, 96f, 1.3f),
            Triple(176f, 104f, 1f), Triple(12f, 104f, 1.2f), Triple(70f, 30f, .9f), Triple(128f, 60f, .9f), Triple(48f, 110f, 1f),
        )
        private const val ETOILE = 0xFFFFFDF0.toInt()
        private const val NUAGE = 0xD9FFFFFF.toInt()
        private const val LANTERNE = 0xFFFFECBA.toInt()
    }
}
