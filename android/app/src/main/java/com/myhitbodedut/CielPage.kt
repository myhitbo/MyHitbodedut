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
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import androidx.core.graphics.ColorUtils

/**
 * Le ciel du moment en fond de tout le Jour (24/11). Le propriétaire : « Fais en sorte que le
 * mode jour nuit au coucher du soleil ou lever du soleil s'affiche dans l'arrière-plan de la
 * première page sur toute la page, pas dans le logo dans les anneaux » ; puis un ciel continu,
 * qui suit le vrai soleil du lieu, illustré à plat (CielContinu). La plaque du hassid garde son
 * disque clair.
 *
 * Posé en fond de la ScrollView du Jour, il en couvre toute la largeur et monte avec la page :
 * le dégradé (TeintesCiel) va du haut du contenu jusqu'au bas du premier écran, où deux
 * collines lointaines ferment l'horizon ; leur couleur (le sol) continue au-delà et sous la
 * barre de départ, qui la reprend (MainActivity). Par-dessus :
 *  - le soleil suit un arc de la gauche (lever) à la droite (coucher), à côté des anneaux et
 *    derrière eux vers midi, sa hauteur selon celle du vrai soleil (PlanCiel.arc) ; sous
 *    l'horizon, rien ; la nuit, la lune fait de même, sa phase selon le jour du mois hébreu ;
 *    autour, une couronne vive et une lueur large ; à l'heure dorée, des rayons doux ;
 *  - les étoiles s'allument avec la profondeur du crépuscule ;
 *  - trois nuages prennent la lumière du moment (bord éclairé dessous, corps par-dessus).
 * Les étoiles, le disque, la couronne et les rayons ne tombent jamais sous un texte (PlanCiel) ;
 * la lueur, les nuages et les collines gardent tout texte lisible (TeintesCiel).
 *
 * Les mouvements sont ceux de CielVivant, au rythme de HorlogeCiel ; à l'arrêt, le ciel prend
 * sa pose de repos. Rien n'est créé par image : le dégradé, les collines et chaque motif sont
 * peints dans une image quand le ciel change (au plus chaque minute), puis seulement posés,
 * déplacés ou pâlis. Aucun dégradé n'est peint à l'écran (recette du 22/11, PaysageCiel).
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

    var etat: EtatCiel = EtatCiel(30.0, -45.0, 0.3, 0.5, 15)
        private set
    var teintes: TeintesCiel.Page? = null
        private set
    private var sombre = false

    private var jauge: PlanCiel.Zone? = null
    private var zones: List<PlanCiel.Zone> = emptyList()

    /** L'état du ciel et ses teintes ; ce qui en dépend sera repeint au prochain dessin. */
    fun regler(etat: EtatCiel, teintes: TeintesCiel.Page, sombre: Boolean) {
        if (etat == this.etat && teintes == this.teintes && sombre == this.sombre) return
        if (teintes != this.teintes || sombre != this.sombre ||
            CielContinu.rayonSoleil(etat.hauteur) != CielContinu.rayonSoleil(this.etat.hauteur) ||
            etat.jourHebreu != this.etat.jourHebreu ||
            CielContinu.soleilPlutotQueLune(etat.hauteur) != CielContinu.soleilPlutotQueLune(this.etat.hauteur)) oublierImages()
        this.etat = etat
        this.teintes = teintes
        this.sombre = sombre
        plan = null
        invalidateSelf()
    }

    /**
     * Où sont les anneaux et ce qui porte du texte, en px dans le contenu du Jour (haut du
     * contenu = 0) : l'astre passe à côté des anneaux et derrière eux, les étoiles hors des textes.
     */
    fun placer(jauge: PlanCiel.Zone?, zones: List<PlanCiel.Zone>) {
        if (jauge == this.jauge && zones == this.zones) return
        this.jauge = jauge
        this.zones = zones
        plan = null
        invalidateSelf()
    }

    // --- Ce qui est peint une fois ---------------------------------------------------------

    private var fond: Bitmap? = null
    private var collines: Bitmap? = null
    private var halo: Bitmap? = null
    private var rayons: Bitmap? = null
    private var soleil: Bitmap? = null
    private var lune: Bitmap? = null
    private var etoile: Bitmap? = null
    /** Les nuages, par forme : en couleurs bornées (sous un texte) et vives (dans la bande des anneaux). */
    private val corps = arrayOfNulls<Bitmap>(2)
    private val bords = arrayOfNulls<Bitmap>(2)
    private val corpsVifs = arrayOfNulls<Bitmap>(2)
    private val bordsVifs = arrayOfNulls<Bitmap>(2)
    private var largeur = 0
    private var hauteurVue = 0

    /** Le plan pour cette taille et ce moment : l'astre, les étoiles retenues, les anneaux. */
    private var plan: Plan? = null

    private class Plan(
        val astreX: Float, val astreY: Float, val avecAstre: Boolean, val estSoleil: Boolean, val astreAlpha: Float, val lueurAlpha: Float,
        val etoiles: FloatArray, val libres: BooleanArray, val limite: Float,
        val anneaux: Path?,
        /** Pour chaque nuage : sa hauteur (px) et s'il reste loin de tout texte (couleurs vives). */
        val nuagesY: FloatArray, val nuagesVifs: BooleanArray,
    )

    private fun oublierImages() {
        fond = null; collines = null; halo = null; rayons = null; soleil = null; lune = null; etoile = null
        corps.fill(null); bords.fill(null); corpsVifs.fill(null); bordsVifs.fill(null)
    }

    override fun onBoundsChange(bounds: android.graphics.Rect) {
        if (bounds.width() != largeur || bounds.height() != hauteurVue) { oublierImages(); plan = null }
    }

    private val image = Paint(Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG)
    private val motif = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val uni = Paint()
    private val cadre = RectF()

    private fun rayonAstre(soleil: Boolean) = (if (soleil) CielContinu.rayonSoleil(etat.hauteur) else CielContinu.RAYON_LUNE) * d

    private fun preparer(w: Int, hv: Int, t: TeintesCiel.Page) {
        largeur = w
        hauteurVue = hv
        if (fond == null) fond = peindreFond(w, hv, t)
        if (collines == null) collines = peindreCollines(w, t)
        val jour = CielContinu.soleilPlutotQueLune(etat.hauteur)
        if (halo == null) halo = peindreHalo(rayonAstre(jour), t, jour)
        if (rayons == null && jour) rayons = peindreRayons(rayonAstre(true), t)
        if (soleil == null) soleil = peindreDisque(rayonAstre(true), t.astre)
        if (lune == null) lune = peindreLune(rayonAstre(false), t.lune, CielContinu.lune(etat.jourHebreu))
        if (etoile == null) etoile = peindreEtoile(t)
        for (forme in 0..1) {
            if (corps[forme] == null) corps[forme] = peindreNuage(forme, t.corps)
            if (bords[forme] == null) bords[forme] = peindreNuage(forme, t.bord)
            if (corpsVifs[forme] == null) corpsVifs[forme] = peindreNuage(forme, t.corpsVif)
            if (bordsVifs[forme] == null) bordsVifs[forme] = peindreNuage(forme, t.bordVif)
        }
        if (plan == null) plan = tracer(w.toFloat(), hv.toFloat())
    }

    private fun tracer(w: Float, hv: Float): Plan {
        val j = jauge
        val e = etat.hauteur
        // Le soleil jusqu'à 3° sous l'horizon ; ensuite la lune, à la hauteur inversée du soleil.
        val estSoleil = etat.estSoleil
        val r = rayonAstre(estSoleil)
        val progres = if (estSoleil) etat.progresJour else etat.progresNuit
        val haut = CielContinu.elevationDessinee(if (estSoleil) e else -e)
        val place = if (j != null) PlanCiel.arc(progres, haut, j, w, r, r * PlanCiel.COURONNE, zones, d) else null
        val (nombre, limite) = PlanCiel.etoiles(w / d, hv / d)
        val etoiles = CielVivant.etoiles(nombre, GRAINE, if (sombre) 0.7f else 1.0f, if (sombre) 1.7f else 2.0f)
        val libres = PlanCiel.libres(etoiles, w, hv * limite, zones + listOfNotNull(j), d)
        // Derrière les anneaux : le cercle qu'ils occupent ne laisse rien passer de l'astre.
        val anneaux = j?.let { Path().apply { addCircle((it.gauche + it.droite) / 2, (it.haut + it.bas) / 2, minOf(it.droite - it.gauche, it.bas - it.haut) / 2, Path.Direction.CW) } }
        val n = PlanCiel.NUAGES.size / 4
        val nuagesY = FloatArray(n)
        val nuagesVifs = BooleanArray(n)
        for (i in 0 until n) {
            val forme = PlanCiel.NUAGES[i * 4 + 3].toInt()
            val haut = PlanCiel.NUAGE_TAILLES[forme * 2 + 1] * PlanCiel.NUAGES[i * 4 + 2] * d
            val y = PlanCiel.nuageY(i, j, hv, haut)
            nuagesY[i] = y
            nuagesVifs[i] = j != null && PlanCiel.bandeLibre(y, y + haut + PlanCiel.BORD_DP * d, zones)
        }
        return Plan(place?.get(0) ?: 0f, place?.get(1) ?: 0f, place != null, estSoleil, etat.astreVisible.toFloat(), etat.lueurVisible.toFloat(),
            etoiles, libres, limite, anneaux, nuagesY, nuagesVifs)
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

    /** Les deux collines lointaines du bas du premier écran, en aplats : la plus lointaine plus claire. */
    private fun peindreCollines(w: Int, t: TeintesCiel.Page): Bitmap? = runCatching {
        val h = (PlanCiel.COLLINES_DP * d).toInt().coerceAtLeast(2)
        Bitmap.createBitmap(w.coerceAtLeast(1), h, Bitmap.Config.ARGB_8888).also { b ->
            val c = Canvas(b)
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val wf = w.toFloat()
            val hf = h.toFloat()
            p.color = t.collineLoin
            c.drawPath(Path().apply {
                moveTo(0f, hf * 0.55f)
                cubicTo(wf * 0.22f, hf * 0.18f, wf * 0.42f, hf * 0.42f, wf * 0.6f, hf * 0.3f)
                cubicTo(wf * 0.78f, hf * 0.16f, wf * 0.9f, hf * 0.34f, wf, hf * 0.3f)
                lineTo(wf, hf); lineTo(0f, hf); close()
            }, p)
            p.color = t.collinePres
            c.drawPath(Path().apply {
                moveTo(0f, hf * 0.78f)
                cubicTo(wf * 0.3f, hf * 0.5f, wf * 0.55f, hf * 0.72f, wf * 0.76f, hf * 0.6f)
                cubicTo(wf * 0.88f, hf * 0.54f, wf * 0.95f, hf * 0.62f, wf, hf * 0.6f)
                lineTo(wf, hf); lineTo(0f, hf); close()
            }, p)
        }
    }.getOrNull()

    /** La lueur large (opacité bornée, TeintesCiel) et la couronne vive, dans une même image. */
    private fun peindreHalo(r: Float, t: TeintesCiel.Page, jour: Boolean): Bitmap? = runCatching {
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
            val teinte = if (jour) t.couronne else t.lune
            val fort = if (jour) 140 else 80
            p.shader = RadialGradient(m, m, couronne,
                intArrayOf(ColorUtils.setAlphaComponent(teinte, fort), ColorUtils.setAlphaComponent(teinte, fort),
                    ColorUtils.setAlphaComponent(teinte, fort / 3), ColorUtils.setAlphaComponent(teinte, 0)),
                floatArrayOf(0f, bord, bord + (1f - bord) * 0.45f, 1f), Shader.TileMode.CLAMP)
            c.drawCircle(m, m, couronne, p)
        }
    }.getOrNull()

    /** Les rayons doux de l'heure dorée : douze pointes floues, dans la couronne. */
    private fun peindreRayons(r: Float, t: TeintesCiel.Page): Bitmap? = runCatching {
        val couronne = r * PlanCiel.COURONNE
        val cote = (2 * couronne).toInt().coerceAtLeast(2)
        Bitmap.createBitmap(cote, cote, Bitmap.Config.ARGB_8888).also { b ->
            val c = Canvas(b)
            val m = cote / 2f
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = ColorUtils.setAlphaComponent(t.couronne, 120)
                maskFilter = BlurMaskFilter(1.5f * d, BlurMaskFilter.Blur.NORMAL)
            }
            val pointe = Path()
            for (i in 0 until PlanCiel.RAYONS) {
                val a = (2 * Math.PI * i / PlanCiel.RAYONS).toFloat()
                val l = if (i % 2 == 0) couronne * 0.96f else couronne * 0.78f
                val large = 0.09f
                pointe.reset()
                pointe.moveTo(m + r * 1.05f * kotlin.math.cos(a - large), m + r * 1.05f * kotlin.math.sin(a - large))
                pointe.lineTo(m + l * kotlin.math.cos(a), m + l * kotlin.math.sin(a))
                pointe.lineTo(m + r * 1.05f * kotlin.math.cos(a + large), m + r * 1.05f * kotlin.math.sin(a + large))
                pointe.close()
                c.drawPath(pointe, p)
            }
        }
    }.getOrNull()

    private fun peindreDisque(r: Float, couleur: Int): Bitmap? = runCatching {
        val cote = (2 * r + 4).toInt()
        Bitmap.createBitmap(cote, cote, Bitmap.Config.ARGB_8888).also { b ->
            Canvas(b).drawCircle(cote / 2f, cote / 2f, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = couleur })
        }
    }.getOrNull()

    /** La lune de ce jour du mois : sa part éclairée, et le reste du disque à peine. */
    private fun peindreLune(r: Float, couleur: Int, l: CielContinu.Lune): Bitmap? = runCatching {
        val cote = (2 * r + 4).toInt()
        Bitmap.createBitmap(cote, cote, Bitmap.Config.ARGB_8888).also { b ->
            PlanCiel.peindreLune(Canvas(b), cote / 2f, cote / 2f, r, couleur, l)
        }
    }.getOrNull()

    /** Une étoile : un point net au cœur, adouci au bord. */
    private fun peindreEtoile(t: TeintesCiel.Page): Bitmap? = runCatching {
        Bitmap.createBitmap(24, 24, Bitmap.Config.ARGB_8888).also { b ->
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            p.shader = RadialGradient(12f, 12f, 12f, intArrayOf(t.etoile, t.etoile, ColorUtils.setAlphaComponent(t.etoile, 0)),
                floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP)
            Canvas(b).drawCircle(12f, 12f, 12f, p)
        }
    }.getOrNull()

    /** Un nuage ([forme] 0 : bombé ; 1 : long) dans la couleur donnée, flou, à moitié taille. */
    private fun peindreNuage(forme: Int, couleur: Int): Bitmap? = runCatching {
        val e = d / 2f
        val lw = PlanCiel.NUAGE_TAILLES[forme * 2] * e
        val lh = PlanCiel.NUAGE_TAILLES[forme * 2 + 1] * e
        Bitmap.createBitmap(lw.toInt().coerceAtLeast(2), lh.toInt().coerceAtLeast(2), Bitmap.Config.ARGB_8888).also { b ->
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = couleur
                maskFilter = BlurMaskFilter(5f * e, BlurMaskFilter.Blur.NORMAL)
            }
            val c = Canvas(b)
            val formes = if (forme == 0) PlanCiel.FORME_NUAGE else PlanCiel.FORME_VOILE
            var i = 0
            while (i < formes.size) {
                val cx = formes[i] * lw; val cy = formes[i + 1] * lh
                val rx = formes[i + 2] * lw; val ry = formes[i + 3] * lh
                c.drawOval(cx - rx, cy - ry, cx + rx, cy + ry, p)
                i += 4
            }
        }
    }.getOrNull()

    // --- Chaque image -----------------------------------------------------------------------

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
        val e = etat.hauteur

        val retour = canvas.save()
        canvas.clipRect(bounds)
        canvas.translate(bounds.left.toFloat(), bounds.top - haut)

        // Le dégradé sur le premier écran, les collines à son pied, puis le sol.
        val f = fond
        if (f != null) {
            cadre.set(0f, 0f, wf, hf)
            canvas.drawBitmap(f, null, cadre, image)
        } else {
            uni.color = t.milieu
            canvas.drawRect(0f, 0f, wf, hf, uni)
        }
        uni.color = t.collinePres
        if (haut > 0f) canvas.drawRect(0f, hf, wf, hf + haut, uni)

        // Les étoiles s'allument avec le crépuscule, chacune à son rythme ; le champ dérive d'un rien.
        val lueurEtoiles = CielContinu.etoiles(e).toFloat()
        val et = etoile
        if (et != null && lueurEtoiles > 0f) {
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
                motif.alpha = (255 * t.etoileAlpha * lueurEtoiles * pale * vif).toInt().coerceIn(0, 255)
                cadre.set(x - r, y - r, x + r, y + r)
                canvas.drawBitmap(et, null, cadre, motif)
            }
        }

        // Derrière les anneaux (le cercle qu'ils occupent ne laisse rien passer) : l'astre, sa
        // lueur et sa couronne qui respirent, les rayons de l'heure dorée qui tournent lentement,
        // le disque ; puis les nuages, qui passent devant lui.
        val dedans = canvas.save()
        plan.anneaux?.let { canvas.clipOutPath(it) }
        if (plan.avecAstre && plan.lueurAlpha > 0f) {
            val x = plan.astreX
            val y = plan.astreY
            val h = halo
            if (h != null) {
                val k = if (marche) CielVivant.tailleHalo(s) else 1f
                val demi = h.width / 2f * k
                cadre.set(x - demi, y - demi, x + demi, y + demi)
                motif.alpha = ((if (marche) CielVivant.eclatHalo(s) else 1f) * plan.lueurAlpha * 255).toInt()
                canvas.drawBitmap(h, null, cadre, motif)
            }
            val rr = rayons
            val doux = if (plan.estSoleil) CielContinu.rayons(e).toFloat() else 0f
            if (rr != null && doux > 0f) {
                val tour = canvas.save()
                canvas.rotate(if (marche) (s * CielVivant.RAYONS_DEG_S % 360.0).toFloat() else 0f, x, y)
                motif.alpha = (255 * doux * plan.astreAlpha).toInt()
                canvas.drawBitmap(rr, x - rr.width / 2f, y - rr.height / 2f, motif)
                canvas.restoreToCount(tour)
            }
            val disque = if (plan.estSoleil) soleil else lune
            if (disque != null) {
                motif.alpha = (255 * plan.astreAlpha).toInt()
                canvas.drawBitmap(disque, x - disque.width / 2f, y - disque.height / 2f, motif)
            }
        }

        // Les nuages prennent la lumière du moment et passent de gauche à droite : le bord éclairé
        // dessous, le corps dessus. Vifs dans la bande des anneaux, loin de tout texte ; bornés sinon.
        val presence = CielContinu.nuages(e).toFloat()
        if (presence > 0f) {
            val vitesse = CielVivant.NUAGE_DP_S * d
            for (i in plan.nuagesY.indices) {
                val forme = PlanCiel.NUAGES[i * 4 + 3].toInt()
                val vif = plan.nuagesVifs[i]
                val c = (if (vif) corpsVifs else corps)[forme]
                val b = (if (vif) bordsVifs else bords)[forme]
                if (c == null || b == null) continue
                val echelle = PlanCiel.NUAGES[i * 4 + 2]
                val lw = c.width * 2f * echelle
                val lh = c.height * 2f * echelle
                val x0 = PlanCiel.NUAGES[i * 4] * wf
                val x = if (marche) CielVivant.nuageX(x0, vitesse * (if (forme == 1) 0.7f else 1f), s, wf, lw) else x0
                val y = plan.nuagesY[i]
                motif.alpha = (255 * (if (vif) PlanCiel.NUAGE_VIF else t.bordAlpha) * presence).toInt()
                cadre.set(x, y + PlanCiel.BORD_DP * d, x + lw, y + lh + PlanCiel.BORD_DP * d)
                canvas.drawBitmap(b, null, cadre, motif)
                motif.alpha = (255 * (if (vif) PlanCiel.NUAGE_VIF else t.corpsAlpha) * presence).toInt()
                cadre.set(x, y, x + lw, y + lh)
                canvas.drawBitmap(c, null, cadre, motif)
            }
        }
        canvas.restoreToCount(dedans)

        // Les collines devant tout le ciel.
        collines?.let { canvas.drawBitmap(it, 0f, hf - it.height, image) }
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
 * Le plan du ciel du Jour : où passent l'astre, les étoiles et les nuages. Pur (pas
 * d'android.graphics, sauf la peinture de la lune) : TeintesCielTest et CielContinuTest le
 * vérifient.
 */
object PlanCiel {

    /** Un rectangle, en px, dans le contenu du Jour. */
    data class Zone(val gauche: Float, val haut: Float, val droite: Float, val bas: Float) {
        /** Le carré qui entoure le cercle ([cx], [cy], [r]) mord sur la zone. */
        fun touche(cx: Float, cy: Float, r: Float): Boolean =
            cx + r > gauche && cx - r < droite && cy + r > haut && cy - r < bas
    }

    /** La couronne vive et la lueur large, en rayons du disque ; les rayons de l'heure dorée. */
    const val COURONNE = 2.2f
    const val LUEUR = 4.2f
    const val RAYONS = 12

    /** L'écart entre une étoile et le texte le plus proche, en dp. */
    const val MARGE_DP = 6f

    /** La hauteur des collines du bas du premier écran, en dp. */
    const val COLLINES_DP = 72f

    /** Le bord éclairé d'un nuage dépasse de son corps vers le bas de 3 dp. */
    const val BORD_DP = 3f

    /**
     * Le centre de l'astre sur son arc, en px : de la place libre à gauche des anneaux ([progres]
     * 0, le lever) à celle de droite ([progres] 1, le coucher), en passant derrière les anneaux
     * vers le milieu du jour ; la hauteur ([hauteur] 0 : l'horizon, au bas des anneaux ; 1 : le
     * haut des anneaux) suit celle du soleil. La couronne ([couronne]) reste dans la hauteur des
     * anneaux. Null si elle toucherait un texte. Sur un écran étroit, où la marge des anneaux est
     * plus mince que le disque, il s'arrête au bord de l'écran (il y disparaissait, puis surgissait
     * d'un coup une heure après le lever).
     *
     * L'abscisse s'attarde dans les marges : x = centre ∓ écart × |cos(π·progres)|^0,4. Et il longe
     * le disque des anneaux sans s'y cacher, tout entier dehors (son centre au moins à un rayon
     * du cercle), jusqu'à trois quarts d'heure environ de midi (|cos(π·progres)| < [LONGE]), où il
     * glisse derrière, puis ressort de l'autre côté. Il passait derrière les anneaux de 10 h à
     * 15 h, un jour de douze heures.
     */
    fun arc(progres: Double, hauteur: Double, jauge: Zone, largeur: Float, r: Float, couronne: Float, zones: List<Zone>, d: Float): FloatArray? {
        if (largeur < 2 * r) return null
        val cx = (jauge.gauche + jauge.droite) / 2f
        val cy = (jauge.haut + jauge.bas) / 2f
        val rayonAnneaux = minOf(jauge.droite - jauge.gauche, jauge.bas - jauge.haut) / 2f
        val gauche = jauge.gauche / 2f
        val droite = (jauge.droite + largeur) / 2f
        val u = kotlin.math.cos(Math.PI * progres.coerceIn(0.0, 1.0))
        val pousse = Math.pow(kotlin.math.abs(u), 0.4).toFloat()
        val bas = jauge.bas - couronne
        val hautArc = jauge.haut + couronne
        val y = bas - (bas - hautArc).coerceAtLeast(0f) * hauteur.coerceIn(0.0, 1.0).toFloat()
        val loin = rayonAnneaux + r
        val longe = kotlin.math.sqrt((loin * loin - (y - cy) * (y - cy)).coerceAtLeast(0f)) * (kotlin.math.abs(u) / LONGE).coerceAtMost(1.0).toFloat()
        val ecart = maxOf((if (u >= 0) cx - gauche else droite - cx) * pousse, longe)
        val x = (if (u >= 0) cx - ecart else cx + ecart).coerceIn(r, largeur - r)
        if (zones.any { it.touche(x, y, couronne) }) return null
        return floatArrayOf(x, y)
    }

    /**
     * Près de midi (|cos(π·progres)| sous ce seuil : 45 minutes d'un jour de douze heures),
     * l'astre cesse de longer les anneaux et glisse derrière ; plus court, il y glissait trop vite
     * les jours brefs du nord (CielContinuTest).
     */
    const val LONGE = 0.2

    /** Combien d'étoiles (une pour 4 600 dp², 24 à 72) et jusqu'où (les quatre cinquièmes du haut). */
    fun etoiles(largeurDp: Float, hauteurDp: Float): Pair<Int, Float> =
        Pair((largeurDp * hauteurDp / 4600f).toInt().coerceIn(24, 72), 0.78f)

    /**
     * Les étoiles qui se montrent : aucune à moins de [MARGE_DP] (plus son rayon et sa dérive)
     * d'une zone de texte, d'icône ou des anneaux. Leurs places sont des fractions de [largeur]
     * et de [hauteur] (CielVivant.etoiles) ; [d], la densité de l'écran.
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

    /**
     * Les trois nuages : départ (part de la largeur), place dans la hauteur des anneaux (0 en
     * haut, 1 en bas), échelle, forme (0 bombé, 1 long). Ils passent dans la bande des anneaux,
     * à côté d'eux et derrière eux : il n'y a pas de texte, ils peuvent y être vifs.
     */
    val NUAGES = floatArrayOf(0.08f, 0.06f, 0.9f, 0f, 0.30f, 0.52f, 0.8f, 1f, 0.62f, 0.86f, 0.75f, 0f)

    /** L'opacité d'un nuage vif, à son plus fort (la nuit, CielContinu.nuages l'atténue). */
    const val NUAGE_VIF = 0.85f

    /** La hauteur (px) du nuage [i] de hauteur [haut] : dans la bande des anneaux, sinon dans le haut de l'écran. */
    fun nuageY(i: Int, jauge: Zone?, hauteurVue: Float, haut: Float): Float {
        val f = NUAGES[i * 4 + 1]
        return if (jauge != null) jauge.haut + f * (jauge.bas - jauge.haut - haut).coerceAtLeast(0f)
        else hauteurVue * (0.1f + 0.4f * f)
    }

    /** Aucune zone de texte ne coupe la bande horizontale [haut, bas] : un nuage peut y passer vif. */
    fun bandeLibre(haut: Float, bas: Float, zones: List<Zone>): Boolean = zones.none { it.bas > haut && it.haut < bas }

    /** La taille des deux formes, en dp : bombé, long. */
    val NUAGE_TAILLES = floatArrayOf(128f, 48f, 240f, 30f)

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

    // Anciens noms, gardés pour le paysage de Sérénité.
    const val NUAGE_L = 128f
    const val NUAGE_H = 48f
    const val VOILE_L = 240f
    const val VOILE_H = 30f

    /**
     * La lune d'un jour du mois, à plat : le disque entier à peine (14 %), puis sa part éclairée,
     * à droite quand elle croît, à gauche quand elle décroît. Le terminateur est une
     * demi-ellipse de demi-largeur r·|1 − 2k| (k, la part éclairée) : bombée vers la lumière en
     * croissant, vers l'ombre en lune gibbeuse.
     */
    fun peindreLune(c: Canvas, cx: Float, cy: Float, r: Float, couleur: Int, l: CielContinu.Lune) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ColorUtils.setAlphaComponent(couleur, 36) }
        c.drawCircle(cx, cy, r, p)
        p.color = couleur
        val k = l.eclairee.toFloat()
        if (k < 0.02f) return
        val retour = c.save()
        if (!l.croissante) c.scale(-1f, 1f, cx, cy)
        val rx = r * kotlin.math.abs(1 - 2 * k)
        val path = Path()
        path.arcTo(RectF(cx - r, cy - r, cx + r, cy + r), -90f, 180f)
        path.arcTo(RectF(cx - rx, cy - r, cx + rx, cy + r), 90f, if (k < 0.5f) -180f else 180f)
        path.close()
        c.drawPath(path, p)
        c.restoreToCount(retour)
    }
}
