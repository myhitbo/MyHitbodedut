package com.myhitbodedut

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import androidx.core.graphics.ColorUtils

/**
 * Le ciel du moment en fond de tout le Jour (24/11). Le propriétaire : « Fais en sorte que le
 * mode jour nuit au coucher du soleil ou lever du soleil s'affiche dans l'arrière-plan de la
 * première page sur toute la page, pas dans le logo dans les anneaux ». La plaque du hassid
 * reprend donc son disque clair, et le ciel (CielDuJour : aube, jour, coucher, nuit) passe
 * derrière toute la page.
 *
 * Posé en fond de la ScrollView du Jour, il en couvre toute la largeur (marges des tablettes
 * comprises) et monte avec la page : le dégradé (TeintesCiel) va du haut du contenu jusqu'au
 * bas de l'écran (le premier écran entier), sa couleur du bas continue au-delà et sous la
 * barre de départ, qui la reprend (MainActivity). Par-dessus :
 *  - l'astre, à côté des anneaux (PlanCiel.astre) : le soleil haut à droite le jour, la lune
 *    en croissant haut à droite la nuit, le soleil bas à gauche à l'aube et bas à droite au
 *    coucher ; avec sa couronne (2,2 rayons) et sa lueur large (4,2 rayons) ;
 *  - la nuit, des étoiles sur les quatre cinquièmes du haut, plus rares et plus pâles vers
 *    l'horizon ; à l'aube et au coucher, en thème sombre, douze étoiles pâles tout en haut ;
 *  - le jour, deux nuages pâles ; à l'aube et au coucher, un long voile de lumière.
 * Les étoiles et l'astre ne tombent jamais sous un texte (PlanCiel) ; la lueur et les nuages ont
 * une opacité bornée pour que tout texte reste lisible (TeintesCiel).
 *
 * Les mouvements sont ceux de CielVivant, au rythme de HorlogeCiel ; à l'arrêt, le ciel prend
 * sa pose de repos. Rien n'est créé par image : le dégradé et chaque motif (halo, astre,
 * étoile, nuage) sont peints une fois dans une image, qui est ensuite posée, déplacée ou
 * pâlie. Aucun dégradé n'est donc peint à l'écran (recette du 22/11, PaysageCiel : les
 * émulateurs Android 15 et 16 tombaient sur des dégradés peints à chaque trame).
 */
class CielPage(private val d: Float) : Drawable() {

    val horloge = HorlogeCiel(this)

    /** Le ciel bouge-t-il (GardeCiel) ? */
    var anime: Boolean
        get() = horloge.permis
        set(v) { horloge.permis = v }

    /** Le défilement de la page, en px : le ciel monte avec elle. */
    var defilement = 0
        set(v) { if (field != v) { field = v; invalidateSelf() } }

    var phase: CielDuJour.Phase = CielDuJour.Phase.JOUR
        private set
    var teintes: TeintesCiel.Page? = null
        private set

    private var jauge: PlanCiel.Zone? = null
    private var zones: List<PlanCiel.Zone> = emptyList()

    /** Le thème est sombre : le ciel y garde des étoiles pâles à l'aube et au coucher. */
    private var sombre = false

    /** La phase et ses teintes ; tout ce qui en dépend sera repeint au prochain dessin. */
    fun regler(phase: CielDuJour.Phase, teintes: TeintesCiel.Page, sombre: Boolean) {
        if (phase == this.phase && teintes == this.teintes && sombre == this.sombre) return
        this.phase = phase
        this.teintes = teintes
        this.sombre = sombre
        oublier()
        invalidateSelf()
    }

    /**
     * Où sont les anneaux et ce qui porte du texte, en px dans le contenu du Jour (haut du
     * contenu = 0) : l'astre se pose à côté des anneaux, les étoiles hors des textes.
     */
    fun placer(jauge: PlanCiel.Zone?, zones: List<PlanCiel.Zone>) {
        if (jauge == this.jauge && zones == this.zones) return
        this.jauge = jauge
        this.zones = zones
        plan = null
        invalidateSelf()
    }

    // --- Ce qui est peint une fois -------------------------------------------------------

    private var fond: Bitmap? = null
    private var halo: Bitmap? = null
    private var disque: Bitmap? = null
    private var etoile: Bitmap? = null
    private var nuage: Bitmap? = null
    private var largeur = 0
    private var hauteurVue = 0

    /** Le plan pour cette taille : l'astre, les étoiles retenues, les nuages. */
    private var plan: Plan? = null

    private class Plan(
        val astreX: Float, val astreY: Float, val avecAstre: Boolean,
        val etoiles: FloatArray, val libres: BooleanArray, val limite: Float, val eclat: Float,
    )

    private fun oublier() {
        fond = null; halo = null; disque = null; etoile = null; nuage = null; plan = null
    }

    override fun onBoundsChange(bounds: android.graphics.Rect) {
        if (bounds.width() != largeur || bounds.height() != hauteurVue) oublier()
    }

    private val image = Paint(Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG)
    private val motif = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val uni = Paint()
    private val cadre = RectF()

    private fun preparer(w: Int, hv: Int, t: TeintesCiel.Page) {
        largeur = w
        hauteurVue = hv
        if (fond == null) fond = peindreFond(w, hv, t)
        val r = PlanCiel.rayon(phase) * d
        if (halo == null) halo = peindreHalo(r, t)
        if (disque == null) disque = peindreDisque(r, t)
        if (etoile == null) etoile = peindreEtoile(t)
        if (nuage == null && t.nuageAlpha > 0f && phase != CielDuJour.Phase.NUIT) nuage = peindreNuage(t)
        if (plan == null) plan = tracer(w.toFloat(), hv.toFloat())
    }

    private fun tracer(w: Float, hv: Float): Plan {
        val j = jauge
        val astre = if (j != null) PlanCiel.astre(phase, j, w, zones, d) else null
        val (nombre, limite, eclat) = PlanCiel.etoiles(phase, sombre, w / d, hv / d)
        val etoiles = CielVivant.etoiles(nombre, GRAINE, if (sombre) 0.7f else 1.0f, if (sombre) 1.7f else 2.0f)
        val libres = PlanCiel.libres(etoiles, w, hv * limite, zones + listOfNotNull(j), d)
        return Plan(astre?.get(0) ?: 0f, astre?.get(1) ?: 0f, astre != null, etoiles, libres, limite, eclat)
    }

    /** Le dégradé, au quart de la taille : il n'a que des transitions douces, l'agrandissement filtré ne se voit pas. */
    private fun peindreFond(w: Int, hv: Int, t: TeintesCiel.Page): Bitmap? = runCatching {
        val bw = (w / 4).coerceAtLeast(1)
        val bh = (hv / 4).coerceAtLeast(2)
        Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888).also { b ->
            val p = Paint(Paint.DITHER_FLAG)
            p.shader = LinearGradient(0f, 0f, 0f, bh.toFloat(), intArrayOf(t.haut, t.milieu, t.bas),
                floatArrayOf(0f, TeintesCiel.MILIEU, 1f), Shader.TileMode.CLAMP)
            Canvas(b).drawRect(0f, 0f, bw.toFloat(), bh.toFloat(), p)
        }
    }.getOrNull()

    /** La lueur large (opacité bornée, TeintesCiel) et la couronne vive, dans une même image. */
    private fun peindreHalo(r: Float, t: TeintesCiel.Page): Bitmap? = runCatching {
        val grand = r * PlanCiel.LUEUR
        val cote = (2 * grand).toInt().coerceAtLeast(2)
        Bitmap.createBitmap(cote, cote, Bitmap.Config.ARGB_8888).also { b ->
            val c = Canvas(b)
            val m = cote / 2f
            val p = Paint(Paint.ANTI_ALIAS_FLAG or Paint.DITHER_FLAG)
            val a = (t.lueurAlpha * 255).toInt()
            p.shader = RadialGradient(m, m, grand,
                intArrayOf(ColorUtils.setAlphaComponent(t.lueur, a), ColorUtils.setAlphaComponent(t.lueur, a * 55 / 100),
                    ColorUtils.setAlphaComponent(t.lueur, a * 18 / 100), ColorUtils.setAlphaComponent(t.lueur, 0)),
                floatArrayOf(0f, 0.35f, 0.7f, 1f), Shader.TileMode.CLAMP)
            c.drawCircle(m, m, grand, p)
            val couronne = r * PlanCiel.COURONNE
            val bord = 1f / PlanCiel.COURONNE
            p.shader = RadialGradient(m, m, couronne,
                intArrayOf(ColorUtils.setAlphaComponent(t.couronne, 140), ColorUtils.setAlphaComponent(t.couronne, 140),
                    ColorUtils.setAlphaComponent(t.couronne, 46), ColorUtils.setAlphaComponent(t.couronne, 0)),
                floatArrayOf(0f, bord, bord + (1f - bord) * 0.45f, 1f), Shader.TileMode.CLAMP)
            c.drawCircle(m, m, couronne, p)
        }
    }.getOrNull()

    /** Le soleil, ou la lune en croissant : le disque, moins le même disque décalé (0,55 rayon à droite, 0,25 vers le haut). */
    private fun peindreDisque(r: Float, t: TeintesCiel.Page): Bitmap? = runCatching {
        val cote = (2 * r + 4).toInt()
        Bitmap.createBitmap(cote, cote, Bitmap.Config.ARGB_8888).also { b ->
            val c = Canvas(b)
            val m = cote / 2f
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = t.astre }
            c.drawCircle(m, m, r, p)
            if (phase == CielDuJour.Phase.NUIT) {
                p.xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
                c.drawCircle(m + r * 0.55f, m - r * 0.25f, r, p)
            }
        }
    }.getOrNull()

    /** Une étoile : un point net au cœur, adouci au bord. */
    private fun peindreEtoile(t: TeintesCiel.Page): Bitmap? = runCatching {
        val cote = 24
        Bitmap.createBitmap(cote, cote, Bitmap.Config.ARGB_8888).also { b ->
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            p.shader = RadialGradient(12f, 12f, 12f,
                intArrayOf(t.etoile, t.etoile, ColorUtils.setAlphaComponent(t.etoile, 0)),
                floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP)
            Canvas(b).drawCircle(12f, 12f, 12f, p)
        }
    }.getOrNull()

    /** Un nuage (le jour) ou un long voile (aube, coucher), flous, à moitié taille. */
    private fun peindreNuage(t: TeintesCiel.Page): Bitmap? = runCatching {
        val e = d / 2f
        val jour = phase == CielDuJour.Phase.JOUR
        val lw = (if (jour) PlanCiel.NUAGE_L else PlanCiel.VOILE_L) * e
        val lh = (if (jour) PlanCiel.NUAGE_H else PlanCiel.VOILE_H) * e
        Bitmap.createBitmap(lw.toInt().coerceAtLeast(2), lh.toInt().coerceAtLeast(2), Bitmap.Config.ARGB_8888).also { b ->
            val flou = 6f * e
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = t.nuage
                maskFilter = BlurMaskFilter(flou, BlurMaskFilter.Blur.NORMAL)
            }
            val c = Canvas(b)
            // Des bosses posées sur une base : des fractions de la largeur et de la hauteur.
            val formes = if (jour) PlanCiel.FORME_NUAGE else PlanCiel.FORME_VOILE
            var i = 0
            while (i < formes.size) {
                val cx = formes[i] * lw; val cy = formes[i + 1] * lh
                val rx = formes[i + 2] * lw; val ry = formes[i + 3] * lh
                c.drawOval(cx - rx, cy - ry, cx + rx, cy + ry, p)
                i += 4
            }
        }
    }.getOrNull()

    // --- Chaque image --------------------------------------------------------------------

    override fun draw(canvas: Canvas) {
        val t = teintes ?: return
        val w = bounds.width()
        val hv = bounds.height()
        if (w <= 0 || hv <= 0) return
        preparer(w, hv, t)
        val plan = plan ?: return
        horloge.relancerSiBesoin()
        val marche = horloge.enMarche
        val s = if (marche) horloge.secondes() else 0.0
        val wf = w.toFloat()
        val hf = hv.toFloat()
        val haut = defilement.toFloat()

        val retour = canvas.save()
        canvas.clipRect(bounds)
        canvas.translate(bounds.left.toFloat(), bounds.top - haut)

        // Le dégradé sur le premier écran, puis sa couleur du bas.
        val f = fond
        if (f != null) {
            cadre.set(0f, 0f, wf, hf)
            canvas.drawBitmap(f, null, cadre, image)
        }
        uni.color = if (f != null) t.bas else t.milieu
        if (f == null) canvas.drawRect(0f, 0f, wf, hf, uni)
        if (haut > 0f) canvas.drawRect(0f, hf, wf, hf + haut, uni)

        // La lueur et la couronne, qui respirent.
        val h = halo
        if (plan.avecAstre && h != null) {
            val k = if (marche) CielVivant.tailleHalo(s) else 1f
            val demi = h.width / 2f * k
            cadre.set(plan.astreX - demi, plan.astreY - demi, plan.astreX + demi, plan.astreY + demi)
            motif.alpha = ((if (marche) CielVivant.eclatHalo(s) else 1f) * 255).toInt()
            canvas.drawBitmap(h, null, cadre, motif)
        }

        // Les étoiles, chacune à son rythme ; le champ dérive d'un rien.
        val e = etoile
        if (e != null && plan.eclat > 0f) {
            val dx = if (marche) CielVivant.deriveX(s) * d else 0f
            val dy = if (marche) CielVivant.deriveY(s) * d else 0f
            val zone = hf * plan.limite
            val tab = plan.etoiles
            for (i in plan.libres.indices) {
                if (!plan.libres[i]) continue
                val o = i * CielVivant.CHAMPS
                val y = tab[o + 1] * zone + dy
                if (y < haut - 8 * d || y > haut + hf + 8 * d) continue
                val x = tab[o] * wf + dx
                val r = tab[o + 2] * d * 1.6f
                val vif = if (marche) CielVivant.scintillement(s, tab[o + 3].toDouble(), tab[o + 4].toDouble()) else 1f
                val pale = 1f - 0.6f * (y / zone).coerceIn(0f, 1f)
                motif.alpha = (255 * t.etoileAlpha * plan.eclat * pale * vif).toInt().coerceIn(0, 255)
                cadre.set(x - r, y - r, x + r, y + r)
                canvas.drawBitmap(e, null, cadre, motif)
            }
        }

        // L'astre.
        val a = disque
        if (plan.avecAstre && a != null) {
            motif.alpha = 255
            canvas.drawBitmap(a, plan.astreX - a.width / 2f, plan.astreY - a.height / 2f, motif)
        }

        // Les nuages, ou le voile, qui passent de gauche à droite.
        val n = nuage
        if (n != null) {
            motif.alpha = (255 * t.nuageAlpha).toInt()
            val jour = phase == CielDuJour.Phase.JOUR
            val departs = if (jour) PlanCiel.NUAGES else PlanCiel.VOILES
            val vitesse = (if (jour) CielVivant.NUAGE_DP_S else CielVivant.VOILE_DP_S) * d
            var i = 0
            while (i < departs.size) {
                val echelle = departs[i + 2]
                val lw = n.width * 2f * echelle
                val lh = n.height * 2f * echelle
                val x = if (marche) CielVivant.nuageX(departs[i] * wf, vitesse, s, wf, lw) else departs[i] * wf
                val y = departs[i + 1] * hf
                cadre.set(x, y, x + lw, y + lh)
                canvas.drawBitmap(n, null, cadre, motif)
                i += 3
            }
        }
        canvas.restoreToCount(retour)
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
        /** La même graine d'une ouverture à l'autre : le ciel ne change pas d'étoiles. */
        const val GRAINE = 29L
    }
}

/**
 * Le plan du ciel du Jour : où se posent l'astre, les étoiles et les nuages. Pur (pas
 * d'android.graphics) : CielPageTest le vérifie.
 */
object PlanCiel {

    /** Un rectangle, en px, dans le contenu du Jour. */
    data class Zone(val gauche: Float, val haut: Float, val droite: Float, val bas: Float) {
        /** Le carré qui entoure le cercle ([cx], [cy], [r]) mord sur la zone. */
        fun touche(cx: Float, cy: Float, r: Float): Boolean =
            cx + r > gauche && cx - r < droite && cy + r > haut && cy - r < bas
    }

    /** Le rayon du disque, en dp : le soleil levant et couchant un peu plus grand, la lune plus petite. */
    fun rayon(phase: CielDuJour.Phase): Float = when (phase) {
        CielDuJour.Phase.JOUR -> 14f
        CielDuJour.Phase.NUIT -> 12f
        CielDuJour.Phase.AUBE -> 16f
        CielDuJour.Phase.COUCHER -> 17f
    }

    /** La couronne vive et la lueur large, en rayons du disque. */
    const val COURONNE = 2.2f
    const val LUEUR = 4.2f

    /** L'écart entre une étoile et le texte le plus proche, en dp. */
    const val MARGE_DP = 6f

    /**
     * Le centre de l'astre, en px : à côté des anneaux ([jauge]), au milieu de la place libre
     * entre eux et le bord ; haut (un cinquième des anneaux) le jour et la nuit, bas (aux trois
     * quarts) à l'aube et au coucher ; à droite, sauf à l'aube (à gauche, comme dans la plaque
     * d'avant). Si ce côté manque de place ou si sa couronne touche une [zones] de texte, l'autre
     * côté ; sinon pas d'astre (accueil couché : les anneaux ont le texte à côté d'eux).
     */
    fun astre(phase: CielDuJour.Phase, jauge: Zone, largeur: Float, zones: List<Zone>, d: Float): FloatArray? {
        val r = rayon(phase) * d
        val couronne = r * COURONNE
        val bas = phase == CielDuJour.Phase.AUBE || phase == CielDuJour.Phase.COUCHER
        val cy = jauge.haut + (jauge.bas - jauge.haut) * (if (bas) 0.72f else 0.2f)
        val droite = phase != CielDuJour.Phase.AUBE
        for (aDroite in booleanArrayOf(droite, !droite)) {
            val libre = if (aDroite) largeur - jauge.droite else jauge.gauche
            if (libre < 2 * r + 8 * d) continue
            val cx = if (aDroite) (jauge.droite + largeur) / 2f else jauge.gauche / 2f
            if (zones.none { it.touche(cx, cy, couronne) }) return floatArrayOf(cx, cy)
        }
        return null
    }

    /**
     * Combien d'étoiles, jusqu'où (part de la hauteur de l'écran) et à quel éclat : la nuit, une
     * pour 4 600 dp² (24 à 72) sur les quatre cinquièmes du haut ; à l'aube et au coucher, en
     * thème sombre seulement, douze pâles dans le tiers du haut ; le jour, aucune.
     */
    fun etoiles(phase: CielDuJour.Phase, sombre: Boolean, largeurDp: Float, hauteurDp: Float): Triple<Int, Float, Float> = when {
        phase == CielDuJour.Phase.NUIT -> Triple((largeurDp * hauteurDp / 4600f).toInt().coerceIn(24, 72), 0.78f, 1f)
        sombre && (phase == CielDuJour.Phase.AUBE || phase == CielDuJour.Phase.COUCHER) -> Triple(12, 0.3f, 0.55f)
        else -> Triple(0, 0f, 0f)
    }

    /**
     * Les étoiles qui se montrent : aucune à moins de [marge] (plus son rayon et sa dérive) d'une
     * zone de texte, d'icône ou des anneaux. Leurs places sont des fractions de [largeur] et de
     * [hauteur] (CielVivant.etoiles) ; [d], la densité de l'écran.
     */
    fun libres(etoiles: FloatArray, largeur: Float, hauteur: Float, zones: List<Zone>, d: Float): BooleanArray {
        val n = etoiles.size / CielVivant.CHAMPS
        val ecart = (MARGE_DP + maxOf(CielVivant.DERIVE_X_DP, CielVivant.DERIVE_Y_DP)) * d
        return BooleanArray(n) { i ->
            val o = i * CielVivant.CHAMPS
            val x = etoiles[o] * largeur
            val y = etoiles[o + 1] * hauteur
            zones.none { it.touche(x, y, etoiles[o + 2] * 1.6f * d + ecart) }
        }
    }

    /** Les nuages du jour : départ (part de la largeur), hauteur (part de l'écran), échelle. */
    val NUAGES = floatArrayOf(0.08f, 0.10f, 1f, 0.58f, 0.42f, 0.8f)

    /** Le voile de l'aube et du coucher. */
    val VOILES = floatArrayOf(0.30f, 0.20f, 1f)

    /** La taille d'un nuage et du voile, en dp. */
    const val NUAGE_L = 128f
    const val NUAGE_H = 48f
    const val VOILE_L = 240f
    const val VOILE_H = 30f

    /** Leurs formes : centre et demi-axes de chaque ovale, en parts de leur cadre. */
    val FORME_NUAGE = floatArrayOf(
        0.30f, 0.62f, 0.22f, 0.22f,
        0.50f, 0.45f, 0.20f, 0.30f,
        0.68f, 0.60f, 0.20f, 0.22f,
        0.50f, 0.70f, 0.38f, 0.16f,
    )
    val FORME_VOILE = floatArrayOf(
        0.30f, 0.50f, 0.24f, 0.15f,
        0.55f, 0.48f, 0.30f, 0.18f,
        0.78f, 0.52f, 0.18f, 0.14f,
    )
}
