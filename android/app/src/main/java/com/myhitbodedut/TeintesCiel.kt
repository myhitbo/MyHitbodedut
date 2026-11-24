package com.myhitbodedut

import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Les teintes du ciel en fond du Jour (24/11). Demande du propriétaire : « Fais en sorte que le
 * mode jour nuit au coucher du soleil ou lever du soleil s'affiche dans l'arrière-plan de la
 * première page sur toute la page, pas dans le logo dans les anneaux ».
 *
 * Le ciel est celui de CielDuJour (mêmes phases, mêmes couleurs de départ : haut, milieu,
 * horizon, astre, lueur), adapté au thème pour que chaque texte de la page garde les seuils de
 * PaletteTest, quelle que soit la phase, la palette « Fond » et la palette « Accent » :
 *  - thème sombre : chaque couleur est assombrie, teinte et saturation gardées, jusqu'à une
 *    luminance où les encres claires (encre 7:1, texte secondaire, accent, légendes des
 *    anneaux 4,5:1) tiennent encore ; l'aube et le coucher tirent vers le violet de leur haut,
 *    saturation bornée à 55 %, faute de quoi l'orangé sombre devient brun ;
 *  - thème clair : chaque couleur est éclaircie de la même façon, jusqu'à la luminance où les
 *    encres sombres tiennent : un ciel pastel.
 * La lueur large du halo et les nuages ont une opacité bornée par le même calcul, sur tout le
 * dégradé ; les étoiles, le disque de l'astre et sa couronne, eux, ne sont jamais posés sous un
 * texte (CielPage les écarte des zones de texte).
 *
 * Le calcul est pur (des entiers ARGB, pas d'android.graphics) : TeintesCielTest le refait pour
 * chaque palette de l'application. Les mêmes règles côté web (ciel.js).
 */
object TeintesCiel {

    /** Une encre posée sur le ciel, et le contraste qu'elle doit y garder. */
    data class Encre(val couleur: Int, val seuil: Double)

    /**
     * Le ciel d'une phase, pour un thème : le dégradé du haut de la page (0) au bas de l'écran
     * (1), arrêt du milieu à [MILIEU] ; la lueur large du halo et son opacité au plus fort ; la
     * couronne et le disque de l'astre ; les nuages (ou le voile) et leur opacité au plus fort ;
     * les étoiles et la leur.
     */
    data class Page(
        val haut: Int, val milieu: Int, val bas: Int,
        val lueur: Int, val lueurAlpha: Float,
        val couronne: Int, val astre: Int,
        val nuage: Int, val nuageAlpha: Float,
        val etoile: Int, val etoileAlpha: Float,
    ) {
        /** La couleur du dégradé à la hauteur [u] (0 en haut, 1 en bas de l'écran et au-delà). */
        fun degrade(u: Float): Int = when {
            u <= 0f -> haut
            u < MILIEU -> melange(haut, milieu, (u / MILIEU).toDouble())
            u < 1f -> melange(milieu, bas, ((u - MILIEU) / (1f - MILIEU)).toDouble())
            else -> bas
        }
    }

    /** L'arrêt du milieu du dégradé, comme dans l'ancienne plaque du ciel (14/11). */
    const val MILIEU = 0.55f

    /** Ce que le calcul garde en réserve au-dessus de chaque seuil : l'arrondi à 8 bits et le tramage du dégradé. */
    const val MARGE = 0.05

    /** Thème sombre : la luminance de chaque arrêt (haut, milieu, bas), en part de la plus haute permise. */
    private val PART_SOMBRE = mapOf(
        CielDuJour.Phase.AUBE to floatArrayOf(0.40f, 0.52f, 0.62f),
        CielDuJour.Phase.JOUR to floatArrayOf(0.45f, 0.52f, 0.60f),
        CielDuJour.Phase.COUCHER to floatArrayOf(0.38f, 0.52f, 0.62f),
        CielDuJour.Phase.NUIT to floatArrayOf(0.25f, 0.40f, 0.55f),
    )

    /** Thème clair : la luminance de chaque arrêt, au-dessus de la plus basse permise. */
    private val ECART_CLAIR = floatArrayOf(0.012f, 0.03f, 0.05f)

    /** Les nuages blancs du jour ; le voile, à peine chaud, de l'aube et du coucher. */
    private const val BLANC = 0xFFFFFFFF.toInt()
    private const val BLANC_CHAUD = 0xFFFFF8F0.toInt()

    /**
     * Le ciel de [phase] sous des encres [encres] (claires si [sombre], sombres sinon). Si aucune
     * teinte ne les laisse lisibles (palette future trop exigeante), le ciel reste le [papier].
     */
    fun pourPage(phase: CielDuJour.Phase, sombre: Boolean, encres: List<Encre>, papier: Int): Page {
        val cle = Cle(phase, sombre, encres, papier)
        return memoire[cle] ?: calculer(phase, sombre, encres, papier).also {
            if (memoire.size >= 8) memoire.clear()
            memoire[cle] = it
        }
    }

    /** Les ciels déjà calculés : l'accueil revoit le sien à chaque retour et chaque minute. */
    private data class Cle(val phase: CielDuJour.Phase, val sombre: Boolean, val encres: List<Encre>, val papier: Int)
    private val memoire = HashMap<Cle, Page>()

    private fun calculer(phase: CielDuJour.Phase, sombre: Boolean, encres: List<Encre>, papier: Int): Page {
        val p = CielDuJour.PALETTES.getValue(phase)
        val borne = borne(encres, sombre)
        // Les arrêts, puis la vérification sur tout le dégradé : entre deux arrêts lisibles, le
        // mélange peut perdre un rien de luminance. On reprend alors avec plus de réserve.
        var reserve = 0
        var arrets = calculerArrets(phase, sombre, borne, 0)
        while (!degradeLisible(arrets, encres) && reserve < 12) arrets = calculerArrets(phase, sombre, borne, ++reserve)
        if (!degradeLisible(arrets, encres)) arrets = intArrayOf(papier, papier, papier)
        val sansHalo = Page(arrets[0], arrets[1], arrets[2], 0, 0f, 0, 0, 0, 0f, 0, 0f)
        val echantillons = FloatArray(ECHANTILLONS + 1) { it / ECHANTILLONS.toFloat() }.map { sansHalo.degrade(it) }

        // La lueur large : la couleur du ciel le jour (claire, éclaircie encore en thème clair).
        var lueur = p.lueur
        if (!sombre && luminance(lueur) < borne + 0.06) lueur = aLuminance(lueur, borne + 0.06)
        val lueurAlpha = opaciteMax(echantillons, lueur, encres, if (sombre) 0.9f else 0.85f)

        // Les nuages passent aussi devant la lueur : vérifiés sur le dégradé seul et sous la lueur entière.
        val nuage = if (phase == CielDuJour.Phase.JOUR) BLANC else BLANC_CHAUD
        val sousLueur = echantillons + echantillons.map { melange(it, lueur, lueurAlpha.toDouble()) }
        val nuageAlpha = when (phase) {
            CielDuJour.Phase.NUIT -> 0f
            else -> opaciteMax(sousLueur, nuage, encres, if (sombre) 0.5f else 0.75f)
        }

        // L'astre : tel quel sur un ciel sombre ; plus soutenu sur un ciel pâle, pour s'y détacher.
        val astre = if (!sombre && luminance(p.astre) > ASTRE_CLAIR) aLuminance(p.astre, ASTRE_CLAIR) else p.astre
        return Page(
            haut = arrets[0], milieu = arrets[1], bas = arrets[2],
            lueur = lueur, lueurAlpha = lueurAlpha,
            couronne = p.lueur, astre = astre,
            nuage = nuage, nuageAlpha = nuageAlpha,
            etoile = if (sombre) ETOILE_SOMBRE else ETOILE_CLAIRE,
            etoileAlpha = if (sombre) 0.9f else 0.8f,
        )
    }

    private const val ECHANTILLONS = 48

    /** Les trois arrêts du dégradé ; chaque cran de [reserve] les éloigne un peu plus de la borne. */
    private fun calculerArrets(phase: CielDuJour.Phase, sombre: Boolean, borne: Double, reserve: Int): IntArray {
        val p = CielDuJour.PALETTES.getValue(phase)
        val departs = intArrayOf(p.haut, p.milieu, p.horizon)
        return IntArray(3) { i ->
            var c = departs[i]
            if (sombre) {
                val cible = borne * PART_SOMBRE.getValue(phase)[i] * 0.9.pow(reserve)
                if (luminance(c) > cible) {
                    if (i > 0 && (phase == CielDuJour.Phase.AUBE || phase == CielDuJour.Phase.COUCHER)) {
                        c = melange(c, p.haut, 0.45)
                        val h = hsl(c)
                        c = deHsl(h[0], minOf(h[1], 0.55), h[2])
                    }
                    c = aLuminance(c, cible)
                }
            } else {
                val cible = borne + ECART_CLAIR[i] + 0.01 * reserve
                if (luminance(c) < cible) c = aLuminance(c, minOf(cible, 1.0))
            }
            c
        }
    }

    private fun degradeLisible(arrets: IntArray, encres: List<Encre>): Boolean {
        val page = Page(arrets[0], arrets[1], arrets[2], 0, 0f, 0, 0, 0, 0f, 0, 0f)
        return (0..ECHANTILLONS).all { lisible(page.degrade(it / ECHANTILLONS.toFloat()), encres) }
    }
    private const val ASTRE_CLAIR = 0.55
    private const val ETOILE_SOMBRE = 0xFFFFF6EC.toInt()
    private const val ETOILE_CLAIRE = 0xFF7884C4.toInt()

    /** Chaque encre garde son seuil (plus la marge) sur [fond]. */
    fun lisible(fond: Int, encres: List<Encre>): Boolean = encres.all { contraste(it.couleur, fond) >= it.seuil + MARGE }

    /**
     * La plus forte opacité (au plus [plafond]) à laquelle [couleur] peut se poser sur chacun des
     * [fonds] sans qu'une encre perde son seuil ; 0 si même un voile ténu est de trop.
     */
    fun opaciteMax(fonds: List<Int>, couleur: Int, encres: List<Encre>, plafond: Float): Float {
        fun tient(a: Double) = fonds.all { lisible(melange(it, couleur, a), encres) }
        if (tient(plafond.toDouble())) return plafond
        if (!tient(0.0)) return 0f
        var bas = 0.0
        var haut = plafond.toDouble()
        repeat(24) {
            val m = (bas + haut) / 2
            if (tient(m)) bas = m else haut = m
        }
        return bas.toFloat()
    }

    /**
     * Thème sombre : la plus haute luminance qu'un fond peut avoir pour que chaque encre (claire)
     * y garde son seuil. Thème clair : la plus basse, pour des encres sombres.
     */
    fun borne(encres: List<Encre>, sombre: Boolean): Double =
        if (sombre) encres.minOf { (luminance(it.couleur) + 0.05) / it.seuil - 0.05 }
        else encres.maxOf { it.seuil * (luminance(it.couleur) + 0.05) - 0.05 }

    // --- Couleurs ------------------------------------------------------------------------

    private fun canal(c: Int, decalage: Int) = (c shr decalage) and 0xFF

    /** La valeur linéaire de chaque niveau d'un canal (sRGB), calculée une fois. */
    private val LINEAIRE = DoubleArray(256) { v ->
        val c = v / 255.0
        if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    private fun lineaire(v: Int): Double = LINEAIRE[v]

    /** La luminance relative (WCAG) d'une couleur opaque. */
    fun luminance(c: Int): Double =
        0.2126 * lineaire(canal(c, 16)) + 0.7152 * lineaire(canal(c, 8)) + 0.0722 * lineaire(canal(c, 0))

    fun contraste(a: Int, b: Int): Double {
        val x = luminance(a)
        val y = luminance(b)
        return (maxOf(x, y) + 0.05) / (minOf(x, y) + 0.05)
    }

    /** [a] recouvert de [b] à l'opacité [t] : un dégradé, ou une couche posée par-dessus. Opaque. */
    fun melange(a: Int, b: Int, t: Double): Int {
        fun m(d: Int) = (canal(a, d) + (canal(b, d) - canal(a, d)) * t).roundToInt().coerceIn(0, 255)
        return (0xFF shl 24) or (m(16) shl 16) or (m(8) shl 8) or m(0)
    }

    /** Teinte (0 à 1), saturation, clarté. */
    fun hsl(c: Int): DoubleArray {
        val r = canal(c, 16) / 255.0
        val g = canal(c, 8) / 255.0
        val b = canal(c, 0) / 255.0
        val max = maxOf(r, g, b)
        val min = minOf(r, g, b)
        val l = (max + min) / 2
        if (max == min) return doubleArrayOf(0.0, 0.0, l)
        val d = max - min
        val s = if (l > 0.5) d / (2 - max - min) else d / (max + min)
        val h = when (max) {
            r -> ((g - b) / d + (if (g < b) 6 else 0)) / 6
            g -> ((b - r) / d + 2) / 6
            else -> ((r - g) / d + 4) / 6
        }
        return doubleArrayOf(h, s, l)
    }

    fun deHsl(h: Double, s: Double, l: Double): Int {
        val c = (1 - abs(2 * l - 1)) * s
        val hp = (h * 6) % 6
        val x = c * (1 - abs(hp % 2 - 1))
        val (r, g, b) = when {
            hp < 1 -> Triple(c, x, 0.0)
            hp < 2 -> Triple(x, c, 0.0)
            hp < 3 -> Triple(0.0, c, x)
            hp < 4 -> Triple(0.0, x, c)
            hp < 5 -> Triple(x, 0.0, c)
            else -> Triple(c, 0.0, x)
        }
        val m = l - c / 2
        fun v(t: Double) = ((t + m) * 255).roundToInt().coerceIn(0, 255)
        return (0xFF shl 24) or (v(r) shl 16) or (v(g) shl 8) or v(b)
    }

    /**
     * [c] amenée à la luminance [cible] en ne changeant que sa clarté : la teinte et la
     * saturation restent, le ciel garde sa couleur en s'assombrissant ou en pâlissant. Arrondie
     * du bon côté : au plus [cible] en assombrissant, au moins en éclaircissant.
     */
    fun aLuminance(c: Int, cible: Double): Int {
        val (h, s, _) = hsl(c).let { Triple(it[0], it[1], it[2]) }
        val assombrir = luminance(c) > cible
        var bas = 0.0
        var haut = 1.0
        repeat(40) {
            val m = (bas + haut) / 2
            if (luminance(deHsl(h, s, m)) < cible) bas = m else haut = m
        }
        // La couleur à 8 bits, du côté qui tient la cible.
        var l = if (assombrir) bas else haut
        var r = deHsl(h, s, l)
        var garde = 0
        while (garde++ < 64 && (if (assombrir) luminance(r) > cible else luminance(r) < cible)) {
            l += if (assombrir) -0.002 else 0.002
            r = deHsl(h, s, l.coerceIn(0.0, 1.0))
        }
        return r
    }
}
