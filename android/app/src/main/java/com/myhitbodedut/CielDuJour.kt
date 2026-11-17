package com.myhitbodedut

import android.content.Context
import java.time.Duration
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Le ciel du Jour (étape 3 de la refonte, 14/11) : l'aube, le plein jour, le coucher ou la
 * nuit. D'après les zmanim du lieu quand on le connaît, sinon d'après l'heure du téléphone.
 *
 * L'aube va d'alot hacha'har à une heure après le lever ; le coucher, d'une heure avant la
 * chkia à tsét hakokhavim ; la nuit, de tsét à alot. Un zman qui manque (nuit ou jour polaire,
 * calcul impossible) renvoie aux heures fixes. La même règle côté web (ciel.js).
 *
 * Le nom évite « Ciel », déjà pris par la frise de VolActivity.
 */
object CielDuJour {

    enum class Phase(val cle: String) { AUBE("aube"), JOUR("jour"), COUCHER("coucher"), NUIT("nuit") }

    /** Ce que l'aube garde après le lever, et ce que le coucher prend avant la chkia. */
    val MARGE: Duration = Duration.ofHours(1)

    /** Sans lieu : un matin et un soir moyens. */
    fun parHeure(h: LocalTime): Phase = when {
        h < LocalTime.of(5, 0) -> Phase.NUIT
        h < LocalTime.of(8, 0) -> Phase.AUBE
        h < LocalTime.of(17, 0) -> Phase.JOUR
        h < LocalTime.of(20, 0) -> Phase.COUCHER
        else -> Phase.NUIT
    }

    /**
     * Avec les zmanim du jour : alot hacha'har, le lever (netz), la chkia et tsét. Un jour trop
     * court pour un plein jour (l'aube finit après le début du coucher) passe de l'aube au coucher.
     */
    fun phase(maintenant: ZonedDateTime, alot: ZonedDateTime?, lever: ZonedDateTime?, chkia: ZonedDateTime?, tset: ZonedDateTime?): Phase {
        if (alot == null || lever == null || chkia == null || tset == null) return parHeure(maintenant.toLocalTime())
        return when {
            maintenant.isBefore(alot) -> Phase.NUIT
            maintenant.isBefore(lever.plus(MARGE)) -> Phase.AUBE
            maintenant.isBefore(chkia.minus(MARGE)) -> Phase.JOUR
            maintenant.isBefore(tset) -> Phase.COUCHER
            else -> Phase.NUIT
        }
    }

    /** Le ciel de maintenant, à l'heure du lieu des zmanim s'il est réglé, comme la vignette des zmanim. */
    fun maintenant(context: Context): Phase = runCatching {
        val lieu = Store.lieuZmanim(context) ?: return@runCatching parHeure(LocalTime.now())
        val ici = ZonedDateTime.now(runCatching { ZoneId.of(lieu.fuseau) }.getOrNull() ?: ZoneId.systemDefault())
        val z = Zmanim.jour(lieu, ici.toLocalDate()).associate { it.cle to it.local }
        phase(ici, z["alot"], z["netz"], z["chkia"], z["tset"])
    }.getOrElse { parHeure(LocalTime.now()) }

    /**
     * Les couleurs d'un ciel : le dégradé (haut, milieu, horizon), la colline, l'astre et sa
     * lueur, et le voile que prend le haut de l'écran. Ce sont celles du ciel, pas du thème :
     * les mêmes de jour comme de nuit, et les mêmes côté web (ciel.js).
     */
    data class Palette(
        val haut: Int, val milieu: Int, val horizon: Int, val colline: Int,
        val astre: Int, val lueur: Int, val voile: Int,
    )

    val PALETTES: Map<Phase, Palette> = mapOf(
        Phase.AUBE to Palette(0xFF7B88C9.toInt(), 0xFFE3A3BE.toInt(), 0xFFFFD6AE.toInt(), 0xFF7E9F86.toInt(),
            0xFFFFE7B8.toInt(), 0xFFFFE0A8.toInt(), 0xFFE8A0B4.toInt()),
        Phase.JOUR to Palette(0xFF5FB1EA.toInt(), 0xFFA8DAF6.toInt(), 0xFFE6F6FC.toInt(), 0xFF7CC293.toInt(),
            0xFFFFE97A.toInt(), 0xFFFFF6C8.toInt(), 0xFF6FB8EA.toInt()),
        Phase.COUCHER to Palette(0xFF8A64B0.toInt(), 0xFFE58397.toInt(), 0xFFFDBA6E.toInt(), 0xFF6C5A80.toInt(),
            0xFFFFC46A.toInt(), 0xFFFFAA5A.toInt(), 0xFFF08A5D.toInt()),
        Phase.NUIT to Palette(0xFF101B3D.toInt(), 0xFF1F2F63.toInt(), 0xFF33477F.toInt(), 0xFF1D2A4C.toInt(),
            0xFFF6F0D6.toInt(), 0xFFF6F0D6.toInt(), 0xFF2C3E7A.toInt()),
    )

    /** L'icône devant la date hébraïque, en tête du Jour. */
    fun icone(phase: Phase): Int = when (phase) {
        Phase.AUBE -> R.drawable.ic_ciel_aube
        Phase.JOUR -> R.drawable.ic_ciel_jour
        Phase.COUCHER -> R.drawable.ic_ciel_coucher
        Phase.NUIT -> R.drawable.ic_ciel
    }
}
