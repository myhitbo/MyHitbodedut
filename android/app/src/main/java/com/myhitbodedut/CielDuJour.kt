package com.myhitbodedut

import java.time.ZonedDateTime
import kotlin.math.roundToInt

/**
 * Le ciel de l'accueil (refonte « Ciel », aimée sur la maquette, 15/11) : la
 * couleur du ciel du lieu choisi à cette heure, le soleil sur son arc entre le
 * lever et le coucher, la nuit qui allume les étoiles.
 *
 * Les teintes sont celles de la maquette. Leurs heures ne sont plus celles
 * d'une démonstration à Jérusalem : chaque teinte se pose par rapport aux
 * zmanim du jour (lever, 'hatsot, coucher, tsét).
 *
 * Le bandeau ne porte aucun texte : ce qu'il dit (le prochain zman) s'écrit
 * dessous, sur le fond de l'écran, où les contrastes sont déjà vérifiés.
 *
 * Sans Android, pour se tester : les couleurs sont des entiers ARGB, les heures
 * des minutes depuis minuit, à l'heure du lieu.
 */
object CielDuJour {

    /** Les heures qui règlent le ciel, en minutes depuis minuit. */
    data class Reperes(val netz: Int, val chatsot: Int, val minhaKetana: Int, val chkia: Int, val tset: Int)

    /** Sans lieu, ou un jour sans lever ni coucher (cercle polaire) : des heures moyennes. */
    val MOYENS = Reperes(netz = 6 * 60, chatsot = 12 * 60, minhaKetana = 15 * 60 + 30, chkia = 18 * 60, tset = 18 * 60 + 25)

    /** Le ciel à dessiner. */
    data class Ciel(
        val haut: Int,
        val bas: Int,
        /** 0 en plein jour, 1 en pleine nuit : les étoiles, la lune, les collines sombres. */
        val nuit: Float,
        /** La place du soleil sur son arc, de 0 (lever) à 1 (coucher) ; null quand il est couché. */
        val soleil: Float?,
        /** Les deux points posés sur l'arc entre ses bouts : 'hatsot et min'ha ketana. */
        val chatsot: Float,
        val minhaKetana: Float,
    )

    const val MINUIT = 24 * 60

    // Ce que le bandeau pose sur le ciel, aux couleurs de la maquette.
    const val BLANC = 0xFFFFFFFF.toInt()
    const val LUNE = 0xFFF3EBD2.toInt()
    const val HALO = 0x8CFFD66E.toInt()
    const val SOLEIL = 0xFFFFD86E.toInt()
    const val SOLEIL_BAS = 0xFFFFB45C.toInt()
    const val COLLINE_JOUR = 0xFF86A86F.toInt()
    const val COLLINE_NUIT = 0xFF1F2B3A.toInt()
    const val COLLINE_PRES_JOUR = 0xFF5E844B.toInt()
    const val COLLINE_PRES_NUIT = 0xFF141D2A.toInt()

    // Les teintes de la maquette, (haut, bas) du dégradé.
    private val NUIT_PROFONDE = 0xFF0B1029.toInt() to 0xFF1E2650.toInt()
    private val NUIT = 0xFF141B36.toInt() to 0xFF2E3563.toInt()
    private val AUBE = 0xFFE79A87.toInt() to 0xFFFBE0C2.toInt()
    private val MATIN = 0xFF7DB6E6.toInt() to 0xFFDCEFFB.toInt()
    private val JOUR = 0xFF4A93DB.toInt() to 0xFFCBE5F9.toInt()
    private val DOREE = 0xFFE8945A.toInt() to 0xFFFAD6A2.toInt()
    private val CREPUSCULE = 0xFF4F427F.toInt() to 0xFFDF8F7D.toInt()
    private val SOIR = 0xFF0E1430.toInt() to 0xFF262F5A.toInt()

    /**
     * Chaque teinte et sa minute, strictement croissantes : un jour très court
     * (hiver loin au nord) rapproche les repères sans qu'ils se croisent.
     */
    fun cles(r: Reperes): List<Pair<Int, Pair<Int, Int>>> {
        val brutes = listOf(
            0 to NUIT_PROFONDE,
            r.netz - 90 to NUIT,
            r.netz - 15 to AUBE,
            r.netz + 150 to MATIN,
            r.chatsot + 40 to JOUR,
            r.chkia - 60 to DOREE,
            r.chkia + 5 to CREPUSCULE,
            r.tset + 45 to SOIR,
            MINUIT to NUIT_PROFONDE,
        )
        var avant = -1
        return brutes.mapIndexed { i, (minute, teinte) ->
            val plafond = MINUIT - (brutes.lastIndex - i)
            val m = minute.coerceIn(avant + 1, plafond)
            avant = m
            m to teinte
        }
    }

    /** Le ciel à la minute [m] (0 à 1439), pour ces repères. */
    fun ciel(m: Int, r: Reperes): Ciel {
        val minute = m.coerceIn(0, MINUIT - 1)
        val cles = cles(r)
        val i = cles.indexOfLast { it.first <= minute }.coerceIn(0, cles.lastIndex - 1)
        val (m0, t0) = cles[i]
        val (m1, t1) = cles[i + 1]
        val k = ((minute - m0).toFloat() / (m1 - m0)).coerceIn(0f, 1f)
        val duree = (r.chkia - r.netz).coerceAtLeast(1)
        fun surArc(x: Int) = ((x - r.netz).toFloat() / duree).coerceIn(0f, 1f)
        return Ciel(
            haut = melange(t0.first, t1.first, k),
            bas = melange(t0.second, t1.second, k),
            nuit = nuit(minute, r),
            soleil = if (minute in r.netz..r.chkia && r.chkia > r.netz) surArc(minute) else null,
            chatsot = surArc(r.chatsot),
            minhaKetana = surArc(r.minhaKetana),
        )
    }

    /** La nuit tombe en une heure et quart après le coucher, et se lève dans l'heure avant le soleil. */
    fun nuit(m: Int, r: Reperes): Float = when {
        m < r.netz - 60 -> 1f
        m < r.netz + 10 -> (r.netz + 10 - m) / 70f
        m < r.chkia -> 0f
        m < r.chkia + 75 -> (m - r.chkia) / 75f
        else -> 1f
    }.coerceIn(0f, 1f)

    /** Les repères d'un jour de zmanim ; null sans lever ni coucher, où le ciel prend [MOYENS]. */
    fun reperes(zmanim: List<Zmanim.Zman>): Reperes? {
        fun minute(cle: String): Int? = zmanim.firstOrNull { it.cle == cle && it.statut == Zmanim.Statut.OK }
            ?.local?.let { it.hour * 60 + it.minute }
        val netz = minute("netz") ?: return null
        val chkia = minute("chkia") ?: return null
        if (chkia <= netz) return null
        return Reperes(
            netz = netz,
            chatsot = minute("chatsot") ?: (netz + chkia) / 2,
            // Min'ha ketana : neuf heures et demie « saisonnières » après le lever (Gra).
            minhaKetana = minute("minha_ketana") ?: (netz + (chkia - netz) * 19 / 24),
            chkia = chkia,
            tset = minute("tset") ?: (chkia + 25),
        )
    }

    /** Les zmanim que le bandeau annonce, dans l'ordre du jour. */
    val SUIVIS = listOf("netz", "szks_gra", "chatsot", "minha_gedola", "minha_ketana", "plag", "chkia", "tset")

    /** Le nom de chaque zman annoncé. */
    val NOMS: Map<String, Int> = mapOf(
        "netz" to R.string.zman_netz, "szks_gra" to R.string.zman_szks_gra, "chatsot" to R.string.zman_chatsot,
        "minha_gedola" to R.string.zman_minha_gedola, "minha_ketana" to R.string.zman_minha_ketana,
        "plag" to R.string.zman_plag, "chkia" to R.string.zman_chkia, "tset" to R.string.zman_tset,
    )

    /** Le prochain zman annoncé après [maintenant] ; null une fois la nuit tombée. */
    fun prochain(zmanim: List<Zmanim.Zman>, maintenant: ZonedDateTime): Zmanim.Zman? =
        zmanim.filter { it.cle in SUIVIS && it.statut == Zmanim.Statut.OK && it.local?.isAfter(maintenant) == true }
            .minByOrNull { it.local!! }

    /** Le mélange de deux couleurs, canal par canal ; [t] est la part de [b]. */
    fun melange(a: Int, b: Int, t: Float): Int {
        val u = t.coerceIn(0f, 1f)
        fun canal(decalage: Int): Int {
            val x = (a ushr decalage) and 0xFF
            val y = (b ushr decalage) and 0xFF
            return (x + (y - x) * u).roundToInt().coerceIn(0, 255)
        }
        return (canal(24) shl 24) or (canal(16) shl 16) or (canal(8) shl 8) or canal(0)
    }

    /** La luminance relative (WCAG) : un ciel clair prend des traits sombres, et l'inverse. */
    fun luminance(couleur: Int): Double {
        fun lin(c: Int): Double {
            val v = c / 255.0
            return if (v <= 0.03928) v / 12.92 else Math.pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin((couleur shr 16) and 0xFF) + 0.7152 * lin((couleur shr 8) and 0xFF) + 0.0722 * lin(couleur and 0xFF)
    }
}
