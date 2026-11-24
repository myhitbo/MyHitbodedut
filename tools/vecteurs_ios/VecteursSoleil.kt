// Le témoin du soleil du ciel continu (Soleil.kt d'Android, Soleil.swift d'iOS, 24/11) : NOAACalculator de
// KosherJava 2.5.0, le moteur des zmanim de l'application, comme dans SoleilTest d'Android. La hauteur du soleil
// toutes les 20 minutes, sur tout le jour UTC (37 s après la minute ronde), aux solstices, aux équinoxes et à
// quelques jours ordinaires, à Jérusalem, Paris, New York, Montréal, Sydney et Buenos Aires ; près des pôles, toutes
// les demi-heures ; le lever et le coucher au niveau de la mer et le passage au méridien de chaque jour local.

import com.kosherjava.zmanim.AstronomicalCalendar
import com.kosherjava.zmanim.util.GeoLocation
import com.kosherjava.zmanim.util.NOAACalculator
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.GregorianCalendar
import java.util.TimeZone

object VecteursSoleil : Generateur {
    override val fichier = "soleil.json"

    private class Lieu(val nom: String, val lat: Double, val lon: Double, val fuseau: String = "UTC")

    private val lieux = listOf(
        Lieu("Jérusalem", 31.778, 35.235, "Asia/Jerusalem"),
        Lieu("Paris", 48.857, 2.352, "Europe/Paris"),
        Lieu("New York", 40.713, -74.006, "America/New_York"),
        Lieu("Montréal", 45.502, -73.567, "America/Montreal"),
        Lieu("Sydney", -33.869, 151.209, "Australia/Sydney"),
        Lieu("Buenos Aires", -34.604, -58.382, "America/Argentina/Buenos_Aires"),
    )

    /** Les solstices, les équinoxes, et quelques jours ordinaires (dont le 24/11/2026). */
    private val dates = listOf("2026-03-20", "2026-06-21", "2026-09-23", "2026-12-21", "2026-01-15", "2026-11-24",
        "2027-04-22", "2030-08-02")

    /** Près des pôles (sauf les pôles mêmes, où NOAACalculator n'est plus un témoin). */
    private val extremes = listOf(
        Lieu("Tromsø", 69.649, 18.955), Lieu("Longyearbyen", 78.223, 15.647), Lieu("Alert", 82.501, -62.348),
        Lieu("McMurdo", -77.846, 166.676), Lieu("Ushuaia", -54.802, -68.303),
        Lieu("ligne de changement de date", 0.0, 180.0), Lieu("et de l'autre côté", 0.0, -180.0),
    )
    private val joursExtremes = listOf("2026-06-21", "2026-12-21", "2026-03-20", "1970-01-01", "2099-12-31")

    private val utc = TimeZone.getTimeZone("UTC")

    private fun minuitUtc(date: String) = LocalDate.parse(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()

    private fun hauteur(t: Long, l: Lieu): Double =
        NOAACalculator.getSolarElevation(GregorianCalendar(utc).apply { timeInMillis = t }, l.lat, l.lon)

    /** Arrondi au cent-millième de degré : le fichier reste court, l'écart permis est d'un centième au moins. */
    private fun court(x: Double) = Math.round(x * 100_000) / 100_000.0

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursSoleil.kt", "moteur" to "KosherJava 2.5.0, NOAACalculator"),
        "journees" to lieux.flatMap { l ->
            val fuseau = TimeZone.getTimeZone(l.fuseau)
            dates.map { date ->
                val d = LocalDate.parse(date)
                val c = AstronomicalCalendar(GeoLocation(l.nom, l.lat, l.lon, fuseau)).apply {
                    calendar = GregorianCalendar(fuseau).apply { clear(); set(d.year, d.monthValue - 1, d.dayOfMonth) }
                }
                linkedMapOf(
                    "lieu" to l.nom, "lat" to l.lat, "lon" to l.lon, "date" to date,
                    // Toutes les 20 minutes du jour UTC, 37 s après la minute ronde.
                    "hauteurs" to (0 until 72).map { k -> court(hauteur(minuitUtc(date) + k * 20 * 60_000L + 37_000L, l)) },
                    // Le jour local : lever et coucher au niveau de la mer, passage au méridien.
                    "lever" to c.seaLevelSunrise?.time,
                    "coucher" to c.seaLevelSunset?.time,
                    "midi" to c.sunTransit?.time,
                )
            }
        },
        "extremes" to extremes.flatMap { l ->
            joursExtremes.map { date ->
                linkedMapOf("lieu" to l.nom, "lat" to l.lat, "lon" to l.lon, "date" to date,
                    "hauteurs" to (0 until 48).map { k -> court(hauteur(minuitUtc(date) + k * 30 * 60_000L, l)) })
            }
        },
    )
}
