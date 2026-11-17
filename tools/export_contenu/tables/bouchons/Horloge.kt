// L'heure qu'il est, pour le code d'Android exécuté par l'oracle : figée, et réglée par chaque générateur.
// build.gradle.kts réécrit les classes de l'app compilées (com/myhitbodedut) pour que leurs appels à
// LocalDate.now(), LocalDateTime.now(), LocalTime.now(), ZonedDateTime.now(), Instant.now(), YearMonth.now(),
// System.currentTimeMillis(), ZoneId.systemDefault() et TimeZone.getDefault() arrivent ici. Sans cela,
// Store.streak, currentWeek, inWindow ou importJson répondraient selon le jour où l'on lance l'oracle.
// VecteursIos.kt remet l'horloge au défaut avant chaque générateur.

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.YearMonth
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.util.TimeZone

object Horloge {
    /** Le présent par défaut : le 1er janvier 2026 à midi, en UTC. */
    val INSTANT_DEFAUT: Instant = Instant.parse("2026-01-01T12:00:00Z")

    @JvmStatic var instantFige: Instant = INSTANT_DEFAUT
    /** Le fuseau « du téléphone ». */
    @JvmStatic var zoneFigee: ZoneId = ZoneOffset.UTC

    /**
     * Le format d'heure « du téléphone » (android.text.format.DateFormat.getTimeFormat, que build.gradle.kts
     * détourne ici comme l'horloge) : 24 h, « HH:mm », celui d'iOS en France et en Israël.
     */
    @JvmStatic fun formatHeureTelephone(@Suppress("UNUSED_PARAMETER") c: android.content.Context?): java.text.DateFormat =
        java.text.SimpleDateFormat("HH:mm", java.util.Locale.US)

    @JvmStatic fun defaut() {
        instantFige = INSTANT_DEFAUT
        zoneFigee = ZoneOffset.UTC
    }

    /** Le présent : une heure civile dans le fuseau du téléphone. */
    @JvmStatic fun regler(civile: LocalDateTime, zone: ZoneId) {
        instantFige = civile.atZone(zone).toInstant()
        zoneFigee = zone
    }

    /** Le présent : un instant, vu du fuseau du téléphone. */
    @JvmStatic fun regler(millis: Long, zone: ZoneId) {
        instantFige = Instant.ofEpochMilli(millis)
        zoneFigee = zone
    }

    // Les remplaçantes, de même signature que les fonctions du JDK qu'elles remplacent.
    @JvmStatic fun millis(): Long = instantFige.toEpochMilli()
    @JvmStatic fun instant(): Instant = instantFige
    @JvmStatic fun zone(): ZoneId = zoneFigee
    @JvmStatic fun fuseau(): TimeZone = TimeZone.getTimeZone(zoneFigee)
    @JvmStatic fun aujourdhui(): LocalDate = LocalDate.ofInstant(instantFige, zoneFigee)
    @JvmStatic fun aujourdhui(zone: ZoneId): LocalDate = LocalDate.ofInstant(instantFige, zone)
    @JvmStatic fun maintenantCivil(): LocalDateTime = LocalDateTime.ofInstant(instantFige, zoneFigee)
    @JvmStatic fun maintenantCivil(zone: ZoneId): LocalDateTime = LocalDateTime.ofInstant(instantFige, zone)
    @JvmStatic fun heure(): LocalTime = LocalTime.ofInstant(instantFige, zoneFigee)
    @JvmStatic fun heure(zone: ZoneId): LocalTime = LocalTime.ofInstant(instantFige, zone)
    @JvmStatic fun maintenantZone(): ZonedDateTime = instantFige.atZone(zoneFigee)
    @JvmStatic fun maintenantZone(zone: ZoneId): ZonedDateTime = instantFige.atZone(zone)
    @JvmStatic fun moisCourant(): YearMonth = YearMonth.from(aujourdhui())
    @JvmStatic fun moisCourant(zone: ZoneId): YearMonth = YearMonth.from(aujourdhui(zone))
}
