package com.myhitbodedut

import com.kosherjava.zmanim.AstronomicalCalendar
import com.kosherjava.zmanim.util.GeoLocation
import com.kosherjava.zmanim.util.NOAACalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.GregorianCalendar
import java.util.TimeZone
import kotlin.math.abs

/**
 * Le soleil du ciel continu (Soleil, 24/11) contre son témoin, NOAACalculator de KosherJava 2.5.0
 * (le moteur des zmanim de l'application) : la hauteur à toute heure, le lever et le coucher, le
 * passage au méridien, à Jérusalem, Paris, New York, Montréal, Sydney et Buenos Aires ; près des
 * pôles (nuit et jour polaires, les pôles eux-mêmes, la ligne de changement de date), rien ne
 * casse ; sans lieu, le soleil moyen de l'heure du téléphone. Les mêmes cas côté web
 * (ciel.test.mjs, contre web/test/vecteurs_kosherjava.json).
 */
class SoleilTest {

    private class Lieu(val nom: String, val lat: Double, val lon: Double, val fuseau: String = "UTC")

    private val lieux = listOf(
        Lieu("Jérusalem", 31.778, 35.235, "Asia/Jerusalem"),
        Lieu("Paris", 48.857, 2.352, "Europe/Paris"),
        Lieu("New York", 40.713, -74.006, "America/New_York"),
        Lieu("Montréal", 45.502, -73.567, "America/Montreal"),
        Lieu("Sydney", -33.869, 151.209, "Australia/Sydney"),
        Lieu("Buenos Aires", -34.604, -58.382, "America/Argentina/Buenos_Aires"),
    )

    /** Les solstices, les équinoxes, et quelques jours ordinaires (dont aujourd'hui, le 24/11/2026). */
    private val dates = listOf(
        LocalDate.of(2026, 3, 20), LocalDate.of(2026, 6, 21), LocalDate.of(2026, 9, 23), LocalDate.of(2026, 12, 21),
        LocalDate.of(2026, 1, 15), LocalDate.of(2026, 11, 24), LocalDate.of(2027, 4, 22), LocalDate.of(2030, 8, 2),
    )

    private val utc = TimeZone.getTimeZone("UTC")

    private fun calendrier(millis: Long) = GregorianCalendar(utc).apply { timeInMillis = millis }

    private fun minuitUtc(date: LocalDate) = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()

    /**
     * L'écart permis avec NOAACalculator.getSolarElevation à l'instant [t]. Celui-ci prend la
     * déclinaison et l'équation du temps à 0 h UTC du jour (son getJulianDay ne lit que la date) ;
     * Soleil les prend à l'instant. L'écart permis croît donc avec l'heure UTC, de la marche de la
     * déclinaison : 0,4° par jour au plus, aux équinoxes.
     */
    private fun tolerance(t: Long) = 0.01 + 0.42 * (Math.floorMod(t, 86_400_000L) / 86_400_000.0)

    @Test
    fun `la hauteur du soleil est celle de NOAACalculator, a toute heure`() {
        var pire = 0.0
        lieux.forEach { l ->
            dates.forEach { date ->
                // Toutes les 20 minutes, sur tout le jour UTC.
                for (k in 0 until 72) {
                    val t = minuitUtc(date) + k * 20 * 60_000L + 37_000L
                    val attendu = NOAACalculator.getSolarElevation(calendrier(t), l.lat, l.lon)
                    val calcule = Soleil.position(t, l.lat, l.lon).hauteur
                    if (k == 0) pire = maxOf(pire, abs(calcule - attendu))
                    assertEquals("${l.nom} $date +${k * 20} min", attendu, calcule, tolerance(t))
                }
            }
        }
        // À 0 h UTC, là où NOAACalculator prend ses termes, les deux calculs se rejoignent.
        assertTrue("écart à 0 h UTC : $pire", pire < 0.01)
    }

    @Test
    fun `au lever et au coucher de NOAACalculator, le soleil est a l horizon`() {
        lieux.forEach { l ->
            val fuseau = TimeZone.getTimeZone(l.fuseau)
            dates.forEach { date ->
                val c = AstronomicalCalendar(GeoLocation(l.nom, l.lat, l.lon, fuseau)).apply {
                    calendar = GregorianCalendar(fuseau).apply { clear(); set(date.year, date.monthValue - 1, date.dayOfMonth) }
                }
                // Le lever et le coucher au niveau de la mer : le centre du soleil à 0,833° sous l'horizon.
                listOf(c.seaLevelSunrise to true, c.seaLevelSunset to false).forEach { (instant, lever) ->
                    val p = Soleil.position(instant!!.time, l.lat, l.lon)
                    val ici = "${l.nom} $date ${if (lever) "lever" else "coucher"}"
                    assertEquals(ici, -0.833, p.hauteur, 0.06)
                    assertEquals(ici, if (lever) -p.angleLever else p.angleLever, p.angleHoraire, 0.25)
                    assertEquals(ici, lever, p.matin)
                    assertEquals(ici, if (lever) 0.0 else 1.0, p.progresJour, 0.002)
                    assertEquals(ici, if (lever) 1.0 else 0.0, p.progresNuit, 0.002)
                }
                // Au midi vrai, l'angle horaire est nul et le soleil à son plus haut.
                val t = c.sunTransit!!.time
                val p = Soleil.position(t, l.lat, l.lon)
                assertEquals("${l.nom} $date midi", 0.0, p.angleHoraire, 0.1)
                assertTrue(p.hauteur >= Soleil.position(t - 1_800_000L, l.lat, l.lon).hauteur && p.hauteur >= Soleil.position(t + 1_800_000L, l.lat, l.lon).hauteur)
                assertEquals(0.5, p.progresJour, 0.001)
            }
        }
    }

    @Test
    fun `jerusalem le 24 novembre 2026`() {
        // UTC+2 : lever vers 6 h 20, midi vers 11 h 33 (37,6°), coucher vers 16 h 32.
        fun a(h: Int, m: Int) = Soleil.position(java.time.ZonedDateTime.of(2026, 11, 24, h, m, 0, 0, java.time.ZoneId.of("Asia/Jerusalem")).toInstant().toEpochMilli(), 31.778, 35.235)
        assertTrue(abs(a(6, 20).hauteur) < 1.5 && a(6, 20).matin && a(6, 20).progresJour < 0.03)
        assertTrue(a(11, 33).hauteur in 36.0..39.0 && abs(a(11, 33).progresJour - 0.5) < 0.02)
        assertTrue(abs(a(16, 32).hauteur) < 1.5 && !a(16, 32).matin && a(16, 32).progresJour > 0.97)
        assertTrue(a(23, 33).hauteur < -60 && !a(23, 33).jour && abs(a(23, 33).progresNuit - 0.5) < 0.03)
    }

    // --- Près des pôles ---------------------------------------------------------------------

    private fun valide(p: Soleil.Position, ici: String) {
        listOf(p.hauteur, p.angleHoraire, p.angleLever, p.progresJour, p.progresNuit).forEach { assertTrue("$ici : $p", it.isFinite()) }
        assertTrue("$ici : $p", p.hauteur in -90.0..90.0 && p.angleHoraire in -180.0..180.0 && p.angleLever in 0.0..180.0)
        assertTrue("$ici : $p", p.progresJour in 0.0..1.0 && p.progresNuit in 0.0..1.0)
    }

    @Test
    fun `pres des poles, rien ne casse`() {
        val extremes = listOf(
            Lieu("Tromsø", 69.649, 18.955), Lieu("Longyearbyen", 78.223, 15.647), Lieu("Alert", 82.501, -62.348),
            Lieu("pôle Nord", 90.0, 0.0), Lieu("pôle Sud", -90.0, 0.0), Lieu("McMurdo", -77.846, 166.676),
            Lieu("Ushuaia", -54.802, -68.303), Lieu("ligne de changement de date", 0.0, 180.0), Lieu("et de l'autre côté", 0.0, -180.0),
        )
        val jours = listOf(LocalDate.of(2026, 6, 21), LocalDate.of(2026, 12, 21), LocalDate.of(2026, 3, 20), LocalDate.of(1970, 1, 1), LocalDate.of(2099, 12, 31))
        extremes.forEach { l ->
            jours.forEach { date ->
                for (k in 0 until 24 * 6) {
                    val t = minuitUtc(date) + k * 10 * 60_000L
                    val p = Soleil.position(t, l.lat, l.lon)
                    val ici = "${l.nom} $date +${k * 10} min"
                    valide(p, ici)
                    if (abs(l.lat) < 89.9) assertEquals(ici, NOAACalculator.getSolarElevation(calendrier(t), l.lat, l.lon), p.hauteur, tolerance(t))
                    // Et le ciel qui en sort se calcule, se dessine et se place.
                    val etat = EtatCiel.de(p, 15)
                    CielContinu.brutes(etat.hauteur, etat.matin)
                    PlanCiel.arc(if (CielContinu.soleilPlutotQueLune(etat.hauteur)) etat.progresJour else etat.progresNuit,
                        CielContinu.elevationDessinee(etat.hauteur), PlanCiel.Zone(75f, 180f, 335f, 440f), 411f, 14f, 30f, emptyList(), 1f)
                }
            }
        }
        // Tromsø : la nuit polaire au solstice d'hiver (l'arc du jour est vide), le jour polaire en été.
        val hiver = Soleil.position(minuitUtc(LocalDate.of(2026, 12, 21)) + 11 * 3_600_000L, 69.649, 18.955)
        assertEquals(0.0, hiver.angleLever, 1e-9)
        assertTrue(!hiver.jour && hiver.hauteur < 0 && hiver.progresJour == 0.5)
        val ete = Soleil.position(minuitUtc(LocalDate.of(2026, 6, 21)) + 23 * 3_600_000L, 69.649, 18.955)
        assertEquals(180.0, ete.angleLever, 1e-9)
        assertTrue(ete.jour && ete.hauteur > 0 && ete.progresNuit == 0.5)
    }

    // --- Sans lieu ----------------------------------------------------------------------------

    @Test
    fun `sans lieu, un soleil moyen sur les heures d avant`() {
        assertEquals(0.0, Soleil.parHeure(6.5).hauteur, 1e-9)
        assertEquals(0.0, Soleil.parHeure(18.5).hauteur, 1e-9)
        assertEquals(50.0, Soleil.parHeure(12.5).hauteur, 1e-9)
        assertEquals(-50.0, Soleil.parHeure(0.5).hauteur, 1e-9)
        // L'aube commençait à 5 h et le coucher finissait à 20 h (CielDuJour.parHeure) : le soleil y est vers −19°.
        assertEquals(-19.1, Soleil.parHeure(5.0).hauteur, 0.2)
        assertEquals(-19.1, Soleil.parHeure(20.0).hauteur, 0.2)
        // Le plein jour commençait à 8 h et finissait à 17 h : vers +19°.
        assertEquals(19.1, Soleil.parHeure(8.0).hauteur, 0.2)
        assertEquals(19.1, Soleil.parHeure(17.0).hauteur, 0.2)
        assertTrue(Soleil.parHeure(9.0).matin && !Soleil.parHeure(15.0).matin && Soleil.parHeure(3.0).matin && !Soleil.parHeure(22.0).matin)
        assertEquals(0.0, Soleil.parHeure(6.5).progresJour, 1e-9)
        assertEquals(0.5, Soleil.parHeure(12.5).progresJour, 1e-9)
        assertEquals(1.0, Soleil.parHeure(18.5).progresJour, 1e-9)
        assertEquals(0.5, Soleil.parHeure(0.5).progresNuit, 1e-9)
        // Minute par minute sur tout le jour, minuit compris : la hauteur glisse, d'un quart de degré au plus.
        var avant = Soleil.parHeure(23.0 + 59.0 / 60)
        for (m in 0 until 24 * 60) {
            val p = Soleil.parHeure(m / 60.0)
            valide(p, "$m min")
            assertTrue("$m min", abs(p.hauteur - avant.hauteur) <= 0.25)
            avant = p
        }
    }
}
