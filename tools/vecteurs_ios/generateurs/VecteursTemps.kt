// Les heures civiles et les fuseaux comme java.time les compte : un instant vu d'un fuseau
// (LocalDateTime.ofInstant), et une heure civile ramenée à un instant (atZone), y compris dans
// l'heure qui n'existe pas au passage à l'heure d'été et dans celle qui existe deux fois à l'automne.

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

object VecteursTemps : Generateur {
    override val fichier = "temps.json"

    // Des fuseaux dont les règles n'ont pas bougé depuis longtemps : la base de fuseaux de la JVM et
    // celle de la machine qui rejouera ces vecteurs ne sont pas forcément de la même année.
    private val fuseaux = listOf("UTC", "Europe/Paris", "Asia/Jerusalem", "America/New_York", "Australia/Melbourne",
        "Asia/Kolkata", "Pacific/Auckland", "Australia/Lord_Howe", "America/Los_Angeles", "Europe/London")

    // Les jours où l'heure change dans ces fuseaux en 2026, leurs voisins, et quelques jours ordinaires.
    private val jours = listOf("2024-02-29", "2025-10-26", "2026-03-08", "2026-03-27", "2026-03-29", "2026-04-05", "2026-09-27",
        "2026-10-04", "2026-10-25", "2026-11-01", "2026-11-13", "2026-12-31", "2027-01-01", "2028-02-29")

    private val heures = listOf(0 to 0, 0 to 30, 1 to 0, 1 to 30, 1 to 59, 2 to 0, 2 to 15, 2 to 30, 2 to 59, 3 to 0, 3 to 30,
        4 to 0, 12 to 0, 23 to 59)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTemps.kt"),
        // Une heure civile dans un fuseau : l'instant que java.time lui donne, puis l'heure civile et le
        // décalage qu'il relit de cet instant. Une ligne par fuseau et par jour ; les heures sont celles de « heures ».
        "heures" to heures.map { (h, m) -> listOf(h, m, 7) },
        "versInstant" to fuseaux.flatMap { id ->
            val zone = ZoneId.of(id)
            jours.map { jour ->
                val instants = heures.map { (h, m) -> LocalDate.parse(jour).atTime(h, m, 7).atZone(zone).toInstant() }
                linkedMapOf("fuseau" to id, "jour" to jour,
                    "millis" to instants.map { it.toEpochMilli() },
                    "relues" to instants.map { LocalDateTime.ofInstant(it, zone).toString() },
                    "decalages" to instants.map { zone.rules.getOffset(it).totalSeconds })
            }
        },
        // Un instant vu d'un fuseau.
        "versCivil" to fuseaux.flatMap { id ->
            val zone = ZoneId.of(id)
            listOf(0L, 1L, -1L, 86_399_999L, 951_782_400_000L, 1_700_000_000_123L, 1_743_296_399_999L, 1_743_296_400_000L,
                1_761_440_399_999L, 1_761_440_400_000L, 1_762_063_200_000L, 1_794_578_000_000L, 1_800_000_000_000L,
                1_900_000_000_000L, 2_000_000_000_000L, -86_400_000L, 946_684_799_999L).map { millis ->
                val vu = Instant.ofEpochMilli(millis).atZone(zone)
                linkedMapOf("fuseau" to id, "millis" to millis, "jour" to vu.toLocalDate().toString(),
                    "heure" to vu.hour, "minute" to vu.minute, "seconde" to vu.second, "milli" to vu.nano / 1_000_000,
                    "decalage" to vu.offset.totalSeconds,
                    // DayOfWeek de Java : lundi = 1 … dimanche = 7.
                    "jourDeSemaineJava" to vu.dayOfWeek.value, "samedi" to (vu.dayOfWeek == DayOfWeek.SATURDAY))
            }
        },
        // L'arithmétique d'une heure civile : plusMinutes, plusHours, plusDays passent minuit dans les deux sens.
        "arithmetique" to listOf("2026-11-13T00:00:00", "2026-11-13T23:59:59", "2026-12-31T23:30:00", "2024-02-28T12:00:00",
            "2026-03-01T03:59:59").flatMap { texte ->
            val depart = LocalDateTime.parse(texte)
            fun champs(d: LocalDateTime) = linkedMapOf("jour" to d.toLocalDate().toString(), "heure" to d.hour, "minute" to d.minute, "seconde" to d.second)
            listOf(0L, 1L, -1L, 59L, 60L, -60L, 239L, 240L, 1439L, 1440L, -1440L, 100_000L, -100_000L).map { minutes ->
                linkedMapOf("depart" to champs(depart), "minutes" to minutes, "arrivee" to champs(depart.plusMinutes(minutes)),
                    "moinsQuatreHeures" to depart.minusHours(4).toLocalDate().toString())
            }
        },
    )
}
