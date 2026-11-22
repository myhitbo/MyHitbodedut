package com.myhitbodedut

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.drawable.Drawable

/**
 * Le paysage de la carte : le ciel du moment en dégradé, le soleil (ou la lune) dans son
 * halo, les étoiles la nuit, deux collines et une brume. Dessiné, pas une image : il suit
 * la taille de la carte et la phase du ciel.
 */
class PaysageCiel(private val phase: CielDuJour.Phase, private val d: Float) : Drawable() {
    private val ciel = Paint()
    private val astre = Paint(Paint.ANTI_ALIAS_FLAG)
    private val halo = Paint(Paint.ANTI_ALIAS_FLAG)
    private val etoile = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFFFF6EC.toInt() }
    private val loin = Paint(Paint.ANTI_ALIAS_FLAG)
    private val pres = Paint(Paint.ANTI_ALIAS_FLAG)
    private val brume = Paint(Paint.ANTI_ALIAS_FLAG)
    private val etoiles = java.util.Random(29).let { r -> List(40) { floatArrayOf(r.nextFloat(), r.nextFloat() * 0.55f, 1f + r.nextFloat() * 1.6f) } }

    private val couleurs: IntArray = when (phase) {
        CielDuJour.Phase.NUIT -> intArrayOf(0xFF0B0A1F.toInt(), 0xFF1D1838.toInt(), 0xFF2E2366.toInt(), 0xFF4E3486.toInt())
        CielDuJour.Phase.COUCHER -> intArrayOf(0xFF0E0B1D.toInt(), 0xFF241C52.toInt(), 0xFF4E3486.toInt(), 0xFF9A5C97.toInt(), 0xFFE3957A.toInt(), 0xFFF7CDA8.toInt())
        CielDuJour.Phase.AUBE -> intArrayOf(0xFF2A2357.toInt(), 0xFF6A4C9C.toInt(), 0xFFC98AA0.toInt(), 0xFFF2C6A0.toInt(), 0xFFFBE3C8.toInt())
        CielDuJour.Phase.JOUR -> intArrayOf(0xFF4F86C6.toInt(), 0xFF7FAEDC.toInt(), 0xFFB3D2EA.toInt(), 0xFFDCE9EC.toInt(), 0xFFF4E6CB.toInt())
    }

    override fun draw(canvas: Canvas) {
        val w = bounds.width().toFloat()
        val h = bounds.height().toFloat()
        ciel.color = couleurs[1]
        canvas.drawRect(0f, 0f, w, h, ciel)
        if (phase == CielDuJour.Phase.NUIT || phase == CielDuJour.Phase.COUCHER) {
            val visibles = if (phase == CielDuJour.Phase.NUIT) etoiles else etoiles.take(18)
            visibles.forEach { (x, y, t) -> canvas.drawCircle(x * w, y * h, t * d * 0.8f, etoile) }
        }
        // L'astre : la lune haut dans la nuit, le soleil bas au couchant et à l'aube, haut le jour.
        val (cx, cy, rayon, couleur) = when (phase) {
            CielDuJour.Phase.NUIT -> listOf(w * 0.72f, h * 0.2f, 22 * d, 0xFFF3EBD2.toInt())
            CielDuJour.Phase.COUCHER -> listOf(w * 0.4f, h * 0.62f, 34 * d, 0xFFFFE6CC.toInt())
            CielDuJour.Phase.AUBE -> listOf(w * 0.6f, h * 0.6f, 30 * d, 0xFFFFF1DC.toInt())
            CielDuJour.Phase.JOUR -> listOf(w * 0.3f, h * 0.24f, 30 * d, 0xFFFFF8E6.toInt())
        }.let { Quad(it[0] as Float, it[1] as Float, it[2] as Float, it[3] as Int) }
        halo.shader = RadialGradient(cx, cy, rayon * 3.6f, intArrayOf(0xB0FFD6AA.toInt(), 0x47FFBE96, 0x00FFBE96), floatArrayOf(0f, 0.32f, 0.64f), Shader.TileMode.CLAMP)
        canvas.drawCircle(cx, cy, rayon * 3.6f, halo)
        astre.color = couleur
        canvas.drawCircle(cx, cy, rayon, astre)
        // Deux collines : la plus lointaine plus claire.
        val nuit = phase == CielDuJour.Phase.NUIT || phase == CielDuJour.Phase.COUCHER
        loin.color = if (nuit) 0xFF2A2350.toInt() else 0xFF8FA9C4.toInt()
        pres.color = if (nuit) 0xFF151026.toInt() else 0xFF4D6B5C.toInt()
        canvas.drawPath(Path().apply {
            moveTo(0f, h * 0.7f)
            cubicTo(w * 0.25f, h * 0.6f, w * 0.45f, h * 0.66f, w * 0.62f, h * 0.62f)
            cubicTo(w * 0.8f, h * 0.58f, w * 0.92f, h * 0.64f, w, h * 0.63f)
            lineTo(w, h); lineTo(0f, h); close()
        }, loin)
        brume.shader = RadialGradient(w / 2, h * 0.76f, w * 0.7f,
            intArrayOf(if (nuit) 0x80F7CDA8.toInt() else 0x99FFFFFF.toInt(), 0x00FFFFFF), null, Shader.TileMode.CLAMP)
        canvas.drawOval(-w * 0.2f, h * 0.7f, w * 1.2f, h * 0.84f, brume)
        canvas.drawPath(Path().apply {
            moveTo(0f, h * 0.8f)
            cubicTo(w * 0.3f, h * 0.72f, w * 0.55f, h * 0.78f, w * 0.75f, h * 0.74f)
            cubicTo(w * 0.88f, h * 0.72f, w * 0.95f, h * 0.75f, w, h * 0.74f)
            lineTo(w, h); lineTo(0f, h); close()
        }, pres)
    }

    private data class Quad(val a: Float, val b: Float, val c: Float, val d: Int)

    override fun setAlpha(alpha: Int) {}
    override fun setColorFilter(colorFilter: ColorFilter?) {}
    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.OPAQUE
}
