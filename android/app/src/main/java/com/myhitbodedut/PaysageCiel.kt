package com.myhitbodedut

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable

/**
 * Le paysage de la carte : le ciel du moment en dégradé, le soleil (ou la lune) dans son
 * halo, les étoiles la nuit, deux collines et une brume. Dessiné, pas une image livrée : il
 * suit la taille de la carte et la phase du ciel.
 *
 * Immobile, il est peint une seule fois, dans une image à la taille de la carte, et c'est
 * cette image qui est posée à l'écran à chaque trame. Ses dégradés ne passent donc jamais par
 * le processeur graphique. Recette du 22/11 : peints directement sur la carte de l'accueil
 * Instant, ils arrêtaient net les émulateurs Android 15 et 16 (rendu logiciel d'OpenGL, sans
 * carte graphique) dès la première trame.
 *
 * Animé (24/11, CielVivant ; [anime], tenu par l'écran et GardeCiel), il est peint en deux
 * images : le ciel seul (arrière), les collines et la brume (avant). Entre les deux, à chaque
 * trame, seulement des motifs déjà peints : les étoiles qui scintillent et dérivent d'un rien,
 * le halo qui respire, l'astre, et sur la carte de Sérénité ([nuages]) un nuage pâle le jour,
 * un voile de lumière à l'aube et au coucher, qui passent dans le haut du ciel, loin du texte.
 * Étoiles et halo ne dépassent jamais l'éclat du paysage immobile : le texte posé dessus
 * (Instant) n'y perd rien. Immobile, l'image est celle d'avant, au pixel près.
 */
class PaysageCiel(
    private val phase: CielDuJour.Phase,
    private val d: Float,
    private val nuages: Boolean = false,
) : Drawable() {
    private val ciel = Paint()
    private val astre = Paint(Paint.ANTI_ALIAS_FLAG)
    private val halo = Paint(Paint.ANTI_ALIAS_FLAG)
    private val etoile = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFFFF6EC.toInt() }
    private val loin = Paint(Paint.ANTI_ALIAS_FLAG)
    private val pres = Paint(Paint.ANTI_ALIAS_FLAG)
    private val brume = Paint(Paint.ANTI_ALIAS_FLAG)
    private val etoiles = java.util.Random(29).let { r -> List(40) { floatArrayOf(r.nextFloat(), r.nextFloat() * 0.55f, 1f + r.nextFloat() * 1.6f) } }

    /** Le rythme de chaque étoile (cycle, décalage), au même rang que [etoiles]. */
    private val rythmes = CielVivant.etoiles(etoiles.size, 31L, 0f, 0f)

    private val couleurs: IntArray = when (phase) {
        CielDuJour.Phase.NUIT -> intArrayOf(0xFF0B0A1F.toInt(), 0xFF1D1838.toInt(), 0xFF2E2366.toInt(), 0xFF4E3486.toInt())
        CielDuJour.Phase.COUCHER -> intArrayOf(0xFF0E0B1D.toInt(), 0xFF241C52.toInt(), 0xFF4E3486.toInt(), 0xFF9A5C97.toInt(), 0xFFE3957A.toInt(), 0xFFF7CDA8.toInt())
        CielDuJour.Phase.AUBE -> intArrayOf(0xFF2A2357.toInt(), 0xFF6A4C9C.toInt(), 0xFFC98AA0.toInt(), 0xFFF2C6A0.toInt(), 0xFFFBE3C8.toInt())
        CielDuJour.Phase.JOUR -> intArrayOf(0xFF4F86C6.toInt(), 0xFF7FAEDC.toInt(), 0xFFB3D2EA.toInt(), 0xFFDCE9EC.toInt(), 0xFFF4E6CB.toInt())
    }

    val horloge = HorlogeCiel(this)

    /** Le paysage bouge-t-il (GardeCiel) ? */
    var anime: Boolean
        get() = horloge.permis
        set(v) { horloge.permis = v }

    /** Le paysage déjà peint, à la taille de la carte ; refait si la carte change de taille. */
    private var image: Bitmap? = null

    /** Animé : le ciel seul, puis les collines et la brume, et les motifs posés entre les deux. */
    private var arriere: Bitmap? = null
    private var avant: Bitmap? = null
    private var motifs: Motifs? = null

    private class Motifs(val etoile: Bitmap, val halo: Bitmap, val astre: Bitmap, val nuage: Bitmap?)

    override fun onBoundsChange(bounds: Rect) {
        image = null
        arriere = null
        avant = null
        motifs = null
    }

    override fun draw(canvas: Canvas) {
        val largeur = bounds.width()
        val hauteur = bounds.height()
        if (largeur <= 0 || hauteur <= 0) return
        horloge.relancerSiBesoin()
        if (horloge.enMarche && dessinerAnime(canvas, largeur, hauteur)) {
            image = null
            return
        }
        // Immobile : les couches de l'animation ne servent plus.
        arriere = null
        avant = null
        val peinte = image?.takeIf { it.width == largeur && it.height == hauteur } ?: imagePeinte(largeur, hauteur)
        if (peinte != null) {
            canvas.drawBitmap(peinte, null, bounds, null)
            return
        }
        // Plus de mémoire pour l'image : le paysage directement, plutôt qu'une carte vide.
        val retour = canvas.save()
        canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
        peindre(canvas, largeur.toFloat(), hauteur.toFloat())
        canvas.restoreToCount(retour)
    }

    private fun imagePeinte(largeur: Int, hauteur: Int): Bitmap? {
        val neuve = try {
            Bitmap.createBitmap(largeur, hauteur, Bitmap.Config.ARGB_8888)
        } catch (e: OutOfMemoryError) {
            return null
        }
        peindre(Canvas(neuve), largeur.toFloat(), hauteur.toFloat())
        image = neuve
        return neuve
    }

    // --- Animé -------------------------------------------------------------------------

    private val pose = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val cadre = RectF()

    /** Une image du paysage animé ; false s'il n'a pas pu être préparé (mémoire) : l'image immobile prend le relais. */
    private fun dessinerAnime(canvas: Canvas, largeur: Int, hauteur: Int): Boolean {
        val w = largeur.toFloat()
        val h = hauteur.toFloat()
        val ar = arriere ?: imageCouche(largeur, hauteur) { c -> peindreCiel(c, w, h) }?.also { arriere = it } ?: return false
        val av = avant ?: imageCouche(largeur, hauteur) { c -> peindreCollines(c, w, h) }?.also { avant = it } ?: return false
        val m = motifs ?: peindreMotifs()?.also { motifs = it } ?: return false
        val s = horloge.secondes()

        val retour = canvas.save()
        canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
        canvas.drawBitmap(ar, 0f, 0f, null)
        if (phase == CielDuJour.Phase.NUIT || phase == CielDuJour.Phase.COUCHER) {
            val visibles = if (phase == CielDuJour.Phase.NUIT) etoiles.size else 18
            val dx = CielVivant.deriveX(s) * d
            val dy = CielVivant.deriveY(s) * d
            for (i in 0 until visibles) {
                val e = etoiles[i]
                val r = e[2] * d * 0.8f
                val x = e[0] * w + dx
                val y = e[1] * h + dy
                pose.alpha = (255 * CielVivant.scintillement(s, rythmes[i * CielVivant.CHAMPS + 3].toDouble(),
                    rythmes[i * CielVivant.CHAMPS + 4].toDouble())).toInt()
                cadre.set(x - r, y - r, x + r, y + r)
                canvas.drawBitmap(m.etoile, null, cadre, pose)
            }
        }
        val (cx, cy, rayon) = astrePlace(w, h)
        val k = CielVivant.tailleHalo(s)
        val demi = rayon * HALO * k
        cadre.set(cx - demi, cy - demi, cx + demi, cy + demi)
        pose.alpha = (255 * CielVivant.eclatHalo(s)).toInt()
        canvas.drawBitmap(m.halo, null, cadre, pose)
        pose.alpha = 255
        canvas.drawBitmap(m.astre, cx - m.astre.width / 2f, cy - m.astre.height / 2f, pose)
        m.nuage?.let { n ->
            val jour = phase == CielDuJour.Phase.JOUR
            val lw = n.width * 2f
            val x = CielVivant.nuageX(0.18f * w, (if (jour) CielVivant.NUAGE_DP_S else CielVivant.VOILE_DP_S) * d, s, w, lw)
            pose.alpha = if (jour) 90 else 70
            cadre.set(x, h * 0.24f, x + lw, h * 0.24f + n.height * 2f)
            canvas.drawBitmap(n, null, cadre, pose)
        }
        canvas.drawBitmap(av, 0f, 0f, null)
        canvas.restoreToCount(retour)
        return true
    }

    private fun imageCouche(largeur: Int, hauteur: Int, peinture: (Canvas) -> Unit): Bitmap? = try {
        Bitmap.createBitmap(largeur, hauteur, Bitmap.Config.ARGB_8888).also { peinture(Canvas(it)) }
    } catch (e: OutOfMemoryError) {
        null
    }

    /** Les motifs posés à chaque trame : une étoile, le halo, l'astre, et le nuage de Sérénité. */
    private fun peindreMotifs(): Motifs? = try {
        val r0 = astrePlace(bounds.width().toFloat(), bounds.height().toFloat()).third
        val e = Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888).also { Canvas(it).drawCircle(16f, 16f, 16f, etoile) }
        val cote = (2 * r0 * HALO).toInt().coerceAtLeast(2)
        val hl = Bitmap.createBitmap(cote, cote, Bitmap.Config.ARGB_8888).also {
            val m = cote / 2f
            peindreHalo(Canvas(it), m, m, r0)
        }
        val ca = (2 * r0 + 4).toInt()
        val a = Bitmap.createBitmap(ca, ca, Bitmap.Config.ARGB_8888).also {
            astre.color = astreCouleur()
            Canvas(it).drawCircle(ca / 2f, ca / 2f, r0, astre)
        }
        Motifs(e, hl, a, if (nuages && phase != CielDuJour.Phase.NUIT) peindreNuage() else null)
    } catch (e: OutOfMemoryError) {
        null
    }

    /** Le nuage (le jour) ou le voile (aube, coucher), flou, à moitié taille. */
    private fun peindreNuage(): Bitmap {
        val e = d / 2f
        val jour = phase == CielDuJour.Phase.JOUR
        val lw = (if (jour) PlanCiel.NUAGE_L else PlanCiel.VOILE_L) * e
        val lh = (if (jour) PlanCiel.NUAGE_H else PlanCiel.VOILE_H) * e
        return Bitmap.createBitmap(lw.toInt().coerceAtLeast(2), lh.toInt().coerceAtLeast(2), Bitmap.Config.ARGB_8888).also { b ->
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (jour) 0xFFFFFFFF.toInt() else 0xFFFFF1E0.toInt()
                maskFilter = BlurMaskFilter(6f * e, BlurMaskFilter.Blur.NORMAL)
            }
            val c = Canvas(b)
            val formes = if (jour) PlanCiel.FORME_NUAGE else PlanCiel.FORME_VOILE
            var i = 0
            while (i < formes.size) {
                val cx = formes[i] * lw; val cy = formes[i + 1] * lh
                val rx = formes[i + 2] * lw; val ry = formes[i + 3] * lh
                c.drawOval(cx - rx, cy - ry, cx + rx, cy + ry, p)
                i += 4
            }
        }
    }

    // --- La peinture ---------------------------------------------------------------------

    /** Le paysage, de (0, 0) à ([w], [h]). */
    private fun peindre(canvas: Canvas, w: Float, h: Float) {
        peindreCiel(canvas, w, h)
        if (phase == CielDuJour.Phase.NUIT || phase == CielDuJour.Phase.COUCHER) {
            val visibles = if (phase == CielDuJour.Phase.NUIT) etoiles else etoiles.take(18)
            visibles.forEach { (x, y, t) -> canvas.drawCircle(x * w, y * h, t * d * 0.8f, etoile) }
        }
        val (cx, cy, rayon) = astrePlace(w, h)
        peindreHalo(canvas, cx, cy, rayon)
        astre.color = astreCouleur()
        canvas.drawCircle(cx, cy, rayon, astre)
        peindreCollines(canvas, w, h)
    }

    private fun peindreCiel(canvas: Canvas, w: Float, h: Float) {
        ciel.shader = LinearGradient(0f, 0f, 0f, h * 0.85f, couleurs, null, Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, w, h, ciel)
    }

    private fun peindreHalo(canvas: Canvas, cx: Float, cy: Float, rayon: Float) {
        halo.shader = RadialGradient(cx, cy, rayon * HALO, intArrayOf(0xB0FFD6AA.toInt(), 0x47FFBE96, 0x00FFBE96), floatArrayOf(0f, 0.32f, 0.64f), Shader.TileMode.CLAMP)
        canvas.drawCircle(cx, cy, rayon * HALO, halo)
    }

    /** Deux collines, la plus lointaine plus claire, et la brume entre elles. */
    private fun peindreCollines(canvas: Canvas, w: Float, h: Float) {
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

    /** L'astre : la lune haut dans la nuit, le soleil bas au couchant et à l'aube, haut le jour. */
    private fun astrePlace(w: Float, h: Float): Triple<Float, Float, Float> = when (phase) {
        CielDuJour.Phase.NUIT -> Triple(w * 0.72f, h * 0.2f, 22 * d)
        CielDuJour.Phase.COUCHER -> Triple(w * 0.4f, h * 0.62f, 34 * d)
        CielDuJour.Phase.AUBE -> Triple(w * 0.6f, h * 0.6f, 30 * d)
        CielDuJour.Phase.JOUR -> Triple(w * 0.3f, h * 0.24f, 30 * d)
    }

    private fun astreCouleur(): Int = when (phase) {
        CielDuJour.Phase.NUIT -> 0xFFF3EBD2.toInt()
        CielDuJour.Phase.COUCHER -> 0xFFFFE6CC.toInt()
        CielDuJour.Phase.AUBE -> 0xFFFFF1DC.toInt()
        CielDuJour.Phase.JOUR -> 0xFFFFF8E6.toInt()
    }

    override fun setVisible(visible: Boolean, restart: Boolean): Boolean {
        val change = super.setVisible(visible, restart)
        horloge.visible = visible
        return change
    }

    override fun setAlpha(alpha: Int) {}
    override fun setColorFilter(colorFilter: ColorFilter?) {}
    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.OPAQUE

    private companion object {
        /** Le rayon du halo, en rayons de l'astre. */
        const val HALO = 3.6f
    }
}
