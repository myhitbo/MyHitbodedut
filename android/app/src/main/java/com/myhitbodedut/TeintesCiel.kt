package com.myhitbodedut

import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Les teintes du ciel en fond du Jour (24/11). Demande du propriétaire : « Fais en sorte que le
 * mode jour nuit au coucher du soleil ou lever du soleil s'affiche dans l'arrière-plan de la
 * première page sur toute la page, pas dans le logo dans les anneaux ».
 *
 * Le ciel est celui de CielContinu (couleurs brutes selon la hauteur du soleil, le matin ou le
 * soir), adapté au thème pour que chaque texte de la page garde les seuils de PaletteTest, à
 * toute heure, pour chaque palette « Fond » et « Accent » :
 *  - thème sombre : chaque couleur est assombrie, teinte et saturation gardées, jusqu'à une
 *    luminance où les encres claires (encre 7:1, texte secondaire, accent, légendes des
 *    anneaux 4,5:1) tiennent encore ; l'aube et le coucher tirent vers le violet de leur haut,
 *    saturation bornée à 55 %, faute de quoi l'orangé sombre devient brun ;
 *  - thème clair : chaque couleur est éclaircie de la même façon, jusqu'à la luminance où les
 *    encres sombres tiennent : un ciel pastel.
 * La lueur large du halo et les nuages (bord éclairé et corps) ont une opacité bornée par le
 * même calcul, sur tout le dégradé ; en thème sombre, le corps des nuages est une silhouette
 * plus sombre que le ciel. Les étoiles, le disque de l'astre, sa couronne et ses rayons ne sont
 * jamais posés sous un texte (CielPage, PlanCiel).
 *
 * Le calcul est pur (des entiers ARGB, pas d'android.graphics) : TeintesCielTest le refait pour
 * chaque palette de l'application. Les mêmes règles côté web (ciel.js).
 */
object TeintesCiel {

    /** Une encre posée sur le ciel, et le contraste qu'elle doit y garder. */
    data class Encre(val couleur: Int, val seuil: Double)

    /**
     * Le ciel d'un moment, pour un thème : le dégradé du haut de la page (0) au bas de l'écran
     * (1), arrêt du milieu à [MILIEU] ; la lueur large du halo et son opacité au plus fort ; la
     * couronne (et les rayons de l'heure dorée) et le disque du soleil ; la lune ; le corps et le
     * bord éclairé des nuages et leurs opacités au plus fort ; les étoiles ; les deux collines du
     * bas de l'écran, sous la barre de départ.
     */
    data class Page(
        val haut: Int, val milieu: Int, val bas: Int,
        val lueur: Int, val lueurAlpha: Float,
        val couronne: Int, val astre: Int, val lune: Int,
        val corps: Int, val corpsAlpha: Float, val bord: Int, val bordAlpha: Float,
        val corpsVif: Int, val bordVif: Int,
        val etoile: Int, val etoileAlpha: Float,
        val collineLoin: Int, val collinePres: Int,
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

    /** Thème clair : la luminance de chaque arrêt, au-dessus de la plus basse permise. */
    private val ECART_CLAIR = floatArrayOf(0.012f, 0.03f, 0.05f)

    private const val ECHANTILLONS = 48
    private const val ASTRE_CLAIR = 0.55
    private const val ETOILE_SOMBRE = 0xFFFFF6EC.toInt()
    private const val ETOILE_CLAIRE = 0xFF7884C4.toInt()

    /**
     * Le ciel quand le soleil est à [hauteur] degrés, avec la part du [matin] (1 le matin, 0 le
     * soir, CielContinu.partMatin), sous des encres [encres] (claires si [sombre], sombres
     * sinon). Si aucune teinte ne les laisse lisibles (palette future trop exigeante), le ciel
     * reste le [papier].
     */
    fun pourCiel(hauteur: Double, matin: Double, sombre: Boolean, encres: List<Encre>, papier: Int): Page {
        val cle = Cle(CielContinu.arrondi(hauteur), (matin.coerceIn(0.0, 1.0) * 20).roundToInt() / 20.0, sombre, encres, papier)
        return memoire[cle] ?: calculer(cle.hauteur, cle.matin, sombre, encres, papier).also {
            if (memoire.size >= 16) memoire.clear()
            memoire[cle] = it
        }
    }

    /** Le [matin] ou le soir, sans passage. */
    fun pourCiel(hauteur: Double, matin: Boolean, sombre: Boolean, encres: List<Encre>, papier: Int): Page =
        pourCiel(hauteur, if (matin) 1.0 else 0.0, sombre, encres, papier)

    /** Les ciels déjà calculés : l'accueil revoit le sien chaque minute, au quart de degré et au vingtième du matin. */
    private data class Cle(val hauteur: Double, val matin: Double, val sombre: Boolean, val encres: List<Encre>, val papier: Int)
    private val memoire = HashMap<Cle, Page>()

    private fun calculer(e: Double, matin: Double, sombre: Boolean, encres: List<Encre>, papier: Int): Page {
        val borne = borne(encres, sombre)
        // Les arrêts, puis la vérification sur tout le dégradé : entre deux arrêts lisibles, le
        // mélange peut perdre un rien de luminance. On reprend alors avec plus de réserve.
        var reserve = 0
        var arrets = calculerArrets(e, matin, sombre, borne, 0)
        while (!degradeLisible(arrets, encres) && reserve < 12) arrets = calculerArrets(e, matin, sombre, borne, ++reserve)
        if (!degradeLisible(arrets, encres)) arrets = intArrayOf(papier, papier, papier)
        val nu = Page(arrets[0], arrets[1], arrets[2], 0, 0f, 0, 0, 0, 0, 0f, 0, 0f, 0, 0, 0, 0f, 0, 0)
        val echantillons = (0..ECHANTILLONS).map { nu.degrade(it / ECHANTILLONS.toFloat()) }
        fun tous(fonds: List<Int>, couche: Int, a: Double) = fonds.all { lisible(melange(it, couche, a), encres) }

        // Les nuages d'abord, ils passent partout : le bord éclairé (dessous), puis le corps
        // par-dessus. En thème sombre le corps est une silhouette plus sombre que le ciel, seul
        // son bord s'allume ; en thème clair, corps et bord sont pâles, assez pour se poser
        // pleinement sous les encres sombres (le bord doré plus sombre, de quelques centièmes
        // d'opacité seulement, passait d'un coup à 0,8 vers 8°, TeintesCielTest).
        var bord = CielContinu.NUAGE_BORD.a(e)
        var corps = CielContinu.NUAGE_CORPS.a(e)
        val plusSombre = echantillons.minOf { luminance(it) }
        if (sombre) corps = aLuminance(corps, plusSombre * 0.6)
        else {
            if (luminance(corps) < borne + 0.08) corps = aLuminance(corps, minOf(borne + 0.08, 1.0))
            if (luminance(bord) < borne + 0.03) bord = aLuminance(bord, minOf(borne + 0.03, 1.0))
        }
        val bordAlpha = opaciteMax(if (sombre) 0.5f else 0.8f) { a -> tous(echantillons, bord, a) }
        val sousBord = echantillons.map { melange(it, bord, bordAlpha.toDouble()) }
        val corpsAlpha = opaciteMax(if (sombre) 0.6f else 0.8f) { a -> tous(echantillons, corps, a) && tous(sousBord, corps, a) }

        // La lueur large prend ce qui reste, nuages par-dessus compris, dans l'ordre du dessin.
        var lueur = CielContinu.LUEUR.a(e)
        if (e < 0) lueur = melange(lueur, CielContinu.LUNE, CielContinu.rampe(e, 0.0, -12.0))
        if (!sombre && luminance(lueur) < borne + 0.06) lueur = aLuminance(lueur, minOf(borne + 0.06, 1.0))
        val lueurAlpha = opaciteMax(if (sombre) 0.9f else 0.85f) { a ->
            echantillons.all {
                val sous = melange(it, lueur, a)
                val bordDessus = melange(sous, bord, bordAlpha.toDouble())
                lisible(sous, encres) && lisible(bordDessus, encres) &&
                    lisible(melange(sous, corps, corpsAlpha.toDouble()), encres) && lisible(melange(bordDessus, corps, corpsAlpha.toDouble()), encres)
            }
        }

        // Le soleil tel quel sur un ciel sombre ; plus soutenu sur un ciel pâle, pour s'y détacher. De même la lune.
        fun detache(c: Int) = if (!sombre && luminance(c) > ASTRE_CLAIR) aLuminance(c, ASTRE_CLAIR) else c
        // Les collines du bas : la couleur du bas tirée vers le haut du ciel, la plus proche plus sombre.
        val loin = melange(arrets[2], arrets[0], 0.5)
        val pres0 = melange(arrets[2], arrets[0], 0.9)
        val pres = aLuminance(pres0, luminance(arrets[2]) * (if (sombre) 0.55 else 0.86))
        // Du texte peut passer sur les collines et le sol : ils restent lisibles eux aussi.
        fun lisibleAjuste(c0: Int): Int {
            var c = c0
            var n = 0
            while (!lisible(c, encres) && n++ < 40) {
                val l = luminance(c)
                c = aLuminance(c, if (sombre) l * 0.9 else minOf(l + 0.01, 1.0))
            }
            return c
        }
        return Page(
            haut = arrets[0], milieu = arrets[1], bas = arrets[2],
            lueur = lueur, lueurAlpha = lueurAlpha,
            couronne = CielContinu.LUEUR.a(e), astre = detache(CielContinu.ASTRE.a(e)), lune = detache(CielContinu.LUNE),
            corps = corps, corpsAlpha = corpsAlpha, bord = bord, bordAlpha = bordAlpha,
            corpsVif = nuageVif(CielContinu.NUAGE_CORPS.a(e), sombre, corps = true), bordVif = nuageVif(CielContinu.NUAGE_BORD.a(e), sombre, corps = false),
            etoile = if (sombre) ETOILE_SOMBRE else ETOILE_CLAIRE,
            etoileAlpha = if (sombre) 0.9f else 0.8f,
            collineLoin = lisibleAjuste(aLuminance(loin, luminance(arrets[2]) * (if (sombre) 0.8 else 0.94))), collinePres = lisibleAjuste(pres),
        )
    }

    /**
     * Les couleurs d'un nuage qui ne passe sous aucun texte (dans la bande des anneaux,
     * PlanCiel.nuages) : vives, sans borne de lisibilité. En thème sombre, le corps est atténué
     * (luminance 0,10 au plus) et le bord garde sa lumière (0,35 au plus) ; en thème clair, le
     * corps est pâle (0,8 au moins), le bord tel quel.
     */
    fun nuageVif(c: Int, sombre: Boolean, corps: Boolean): Int = when {
        sombre && corps -> if (luminance(c) > 0.10) aLuminance(c, 0.10) else c
        sombre -> if (luminance(c) > 0.35) aLuminance(c, 0.35) else c
        corps -> if (luminance(c) < 0.8) aLuminance(c, 0.8) else c
        else -> c
    }

    /** Les trois arrêts du dégradé ; chaque cran de [reserve] les éloigne un peu plus de la borne. */
    private fun calculerArrets(e: Double, matin: Double, sombre: Boolean, borne: Double, reserve: Int): IntArray {
        val departs = CielContinu.brutes(e, matin)
        val parts = CielContinu.partsSombre(e)
        val chaleur = CielContinu.chaleur(e)
        return IntArray(3) { i ->
            var c = departs[i]
            if (sombre) {
                val cible = borne * parts[i] * 0.9.pow(reserve)
                if (luminance(c) > cible) {
                    // L'orangé sombre devient brun, le vert-de-gris kaki : à l'aube, au coucher et
                    // jusqu'au bout de l'heure dorée, le milieu et l'horizon tirent vers le violet ou
                    // le bleu de leur haut, saturation bornée.
                    if (i > 0 && chaleur > 0) {
                        c = melange(c, departs[0], 0.45 * chaleur)
                        val h = hsl(c)
                        c = deHsl(h[0], minOf(h[1], 1.0 - 0.45 * chaleur), h[2])
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
        val page = Page(arrets[0], arrets[1], arrets[2], 0, 0f, 0, 0, 0, 0, 0f, 0, 0f, 0, 0, 0, 0f, 0, 0)
        return (0..ECHANTILLONS).all { lisible(page.degrade(it / ECHANTILLONS.toFloat()), encres) }
    }

    /** Chaque encre garde son seuil (plus la marge) sur [fond]. */
    fun lisible(fond: Int, encres: List<Encre>): Boolean = encres.all { contraste(it.couleur, fond) >= it.seuil + MARGE }

    /**
     * La plus forte opacité (au plus [plafond]) pour laquelle [tient] ; 0 si même un voile ténu
     * est de trop.
     */
    fun opaciteMax(plafond: Float, tient: (Double) -> Boolean): Float {
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
