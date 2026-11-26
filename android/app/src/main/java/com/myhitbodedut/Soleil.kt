package com.myhitbodedut

import kotlin.math.PI
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan

/**
 * La hauteur du soleil, pour le ciel continu du Jour (24/11 ; CielContinu). Les formules de la
 * NOAA (celles de NOAACalculator de KosherJava, que SoleilTest prend pour témoin) : déclinaison
 * et équation du temps d'après le jour julien, angle horaire d'après la longitude.
 *
 * Pur, en degrés, sans réfraction ; la même chose côté web (ciel.js, soleil).
 */
object Soleil {

    /**
     * Le soleil à un instant : sa hauteur au-dessus de l'horizon, son angle horaire (négatif le
     * matin, positif l'après-midi, de −180 à 180) et l'angle horaire de son lever (0 : nuit
     * polaire, 180 : jour polaire).
     */
    data class Position(val hauteur: Double, val angleHoraire: Double, val angleLever: Double) {
        /** Le soleil est levé (angle horaire dans l'arc du jour). */
        val jour: Boolean get() = kotlin.math.abs(angleHoraire) <= angleLever

        /** Le matin : avant le passage au méridien. */
        val matin: Boolean get() = angleHoraire < 0

        /** La part du jour écoulée, de 0 au lever à 1 au coucher ; hors du jour, la plus proche borne. */
        val progresJour: Double get() =
            if (angleLever <= 0.0) 0.5 else ((angleHoraire + angleLever) / (2 * angleLever)).coerceIn(0.0, 1.0)

        /**
         * La part de la nuit écoulée, de 0 au coucher à 1 au lever ; de jour, la plus proche borne
         * (1 le matin, 0 l'après-midi : la nuit tout juste finie, ou sur le point de commencer).
         */
        val progresNuit: Double get() {
            val nuit = 360.0 - 2 * angleLever
            if (nuit <= 0.0) return 0.5
            if (jour) return if (matin) 1.0 else 0.0
            val depuis = ((angleHoraire - angleLever) % 360.0 + 360.0) % 360.0
            return (depuis / nuit).coerceIn(0.0, 1.0)
        }
    }

    private fun rad(d: Double) = d * PI / 180.0
    private fun deg(r: Double) = r * 180.0 / PI

    /** Le soleil à l'instant [millis] (UTC), pour [latitude] et [longitude] (est positive), en degrés. */
    fun position(millis: Long, latitude: Double, longitude: Double): Position {
        val jd = millis / 86_400_000.0 + 2440587.5
        val t = (jd - 2451545.0) / 36525.0
        val l0 = ((280.46646 + t * (36000.76983 + 0.0003032 * t)) % 360.0 + 360.0) % 360.0
        val m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        val e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        val c = sin(rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
            sin(rad(2 * m)) * (0.019993 - 0.000101 * t) + sin(rad(3 * m)) * 0.000289
        val omega = 125.04 - 1934.136 * t
        val lambda = l0 + c - 0.00569 - 0.00478 * sin(rad(omega))
        val eps0 = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        val eps = eps0 + 0.00256 * cos(rad(omega))
        val declinaison = deg(asin(sin(rad(eps)) * sin(rad(lambda))))
        val y = tan(rad(eps / 2)).let { it * it }
        val equation = 4 * deg(y * sin(2 * rad(l0)) - 2 * e * sin(rad(m)) + 4 * e * y * sin(rad(m)) * cos(2 * rad(l0)) -
            0.5 * y * y * sin(4 * rad(l0)) - 1.25 * e * e * sin(2 * rad(m)))
        val minutes = ((millis % 86_400_000L + 86_400_000L) % 86_400_000L) / 60_000.0
        val solaire = minutes + equation + 4 * longitude
        var h = solaire / 4.0 - 180.0
        h = ((h + 180.0) % 360.0 + 360.0) % 360.0 - 180.0
        val phi = rad(latitude)
        val delta = rad(declinaison)
        val cosZenith = (sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(rad(h))).coerceIn(-1.0, 1.0)
        val hauteur = 90.0 - deg(acos(cosZenith))
        // Le lever : le centre du soleil à 0,833° sous l'horizon (réfraction et demi-diamètre).
        val cosLever = (sin(rad(-0.833)) - sin(phi) * sin(delta)) / (cos(phi) * cos(delta))
        val lever = when {
            cosLever >= 1.0 -> 0.0
            cosLever <= -1.0 -> 180.0
            else -> deg(acos(cosLever))
        }
        return Position(hauteur, h, lever)
    }

    /**
     * Sans lieu : un soleil moyen d'après la seule heure du téléphone ([heure] décimale, 0 à 24).
     * Levé à 6 h 30, couché à 18 h 30, 50° à son plus haut (12 h 30) et −50° à son plus bas : il
     * passe −19° à 5 h et à 20 h, +19° à 8 h et à 17 h, les heures de l'aube et du coucher
     * d'avant (CielDuJour.parHeure).
     */
    fun parHeure(heure: Double): Position {
        val h = ((heure - 12.5) * 15.0).let { ((it + 180.0) % 360.0 + 360.0) % 360.0 - 180.0 }
        return Position(50.0 * sin(PI * (heure - 6.5) / 12.0), h, 90.0)
    }
}
