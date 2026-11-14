// Les rappels devant la JVM : ce que répondent ReminderRule (dans combien de minutes, l'instant du
// prochain rappel, faut-il sonner) et ChabbatAlerte.prochaine d'Android, que rejouent
// ReminderRuleTests, ReminderTimesTests et ChabbatAlerteTests de Coeur.
//
// Les instants sont des millisecondes Unix. Un balayage s'écrit par son premier instant, son pas (en
// minutes, sur la ligne du temps) et son nombre d'instants ; ses réponses, en écarts à « maintenant »,
// en minutes pleines (null : rien n'est programmé). Les heures d'allumage sont écrites jour par jour,
// telles que la JVM les a résolues : Swift les relit sans rien recalculer.

import com.myhitbodedut.ChabbatAlerte
import com.myhitbodedut.Reminder
import com.myhitbodedut.ReminderRule
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

object VecteursRappels : Generateur {
    override val fichier = "rappels.json"

    private const val MINUTE = 60_000L
    private val CIVILE = DateTimeFormatter.ofPattern("uuuu-MM-dd'T'HH:mm:ss")
    private val DEBUT_BALAYAGE: Instant = Instant.parse("2026-01-01T00:00:00Z")
    private val FIN_BALAYAGE: Instant = Instant.parse("2028-01-01T00:00:00Z")

    // Des fuseaux dont les règles n'ont pas bougé depuis longtemps (voir VecteursTemps) : deux du nord
    // qui changent d'heure la nuit à 2 h ou 3 h, Jérusalem qui avance un vendredi, et le sud.
    private val fuseaux = listOf("Europe/Paris", "Asia/Jerusalem", "America/New_York", "Australia/Melbourne")

    private fun millis(z: ZonedDateTime): Long = z.toInstant().toEpochMilli()
    private fun vu(millis: Long, zone: ZoneId): ZonedDateTime = Instant.ofEpochMilli(millis).atZone(zone)

    /** L'écart de [depuis] à [jusqua], en minutes pleines ; un écart qui ne tombe pas sur la minute arrête tout. */
    private fun ecart(depuis: ZonedDateTime, jusqua: ZonedDateTime): Long {
        val ms = millis(jusqua) - millis(depuis)
        check(ms % MINUTE == 0L) { "écart qui ne tombe pas sur la minute : $depuis → $jusqua" }
        return ms / MINUTE
    }

    private fun a(fuseau: String, annee: Int, mois: Int, jour: Int, h: Int, m: Int, s: Int = 0, ms: Int = 0): ZonedDateTime =
        ZonedDateTime.of(LocalDateTime.of(annee, mois, jour, h, m, s, ms * 1_000_000), ZoneId.of(fuseau))

    private fun instant(fuseau: String, texte: String): ZonedDateTime = Instant.parse(texte).atZone(ZoneId.of(fuseau))

    /** Les instants où l'heure change dans ce fuseau, en 2026 et en 2027. */
    private fun changements(zone: ZoneId): List<Instant> {
        val res = mutableListOf<Instant>()
        var t = zone.rules.nextTransition(DEBUT_BALAYAGE)
        while (t != null && t.instant.isBefore(FIN_BALAYAGE)) {
            res += t.instant
            t = zone.rules.nextTransition(t.instant)
        }
        return res
    }

    // --- Dans combien de minutes -------------------------------------------------------------------

    // Vide, une, trois (ReminderTimesTest), désordonnées avec doublons et hors jour (ReminderTimesTest),
    // les bornes du jour, doublons seuls, désordonnées, rien que du hors jour, celles des autres tests.
    private val listesDuJour: List<List<Int>> = listOf(
        emptyList(),
        listOf(7 * 60),
        listOf(7 * 60, 13 * 60, 21 * 60),
        listOf(21 * 60, 7 * 60, 7 * 60, -30, ReminderRule.MINUTES_PAR_JOUR + 10, 13 * 60),
        listOf(0, 8 * 60, 23 * 60 + 59),
        listOf(1439, 0),
        listOf(720, 720, 720),
        listOf(1000, 5, 600, 1200, 300, 1439, 0, 59, 61),
        listOf(-1, 1440, 2000, -500, Int.MIN_VALUE, Int.MAX_VALUE),
        listOf(7 * 60, 21 * 60),
        listOf(7 * 60, 19 * 60),
    )

    // « Maintenant » hors du jour : négatif, au-delà de minuit, aux bornes d'un Int (le calcul déborde
    // alors en silence, comme tout Int de Kotlin).
    private val maintenantsHorsJour = listOf(-1, -30, -1439, -1440, -100_000, 1440, 1441, 2000, 2879, 2880, 100_000,
        Int.MIN_VALUE, Int.MIN_VALUE + 1, Int.MIN_VALUE + 1440, Int.MAX_VALUE, Int.MAX_VALUE - 1, Int.MAX_VALUE - 1440)

    private fun minutesUntilNext() = listesDuJour.map { heures ->
        linkedMapOf(
            "heures" to heures,
            // La réponse à chaque minute du jour, de 0 h 00 à 23 h 59.
            "parMinute" to (0 until ReminderRule.MINUTES_PAR_JOUR).map { ReminderRule.minutesUntilNext(it, heures) },
            "horsJour" to maintenantsHorsJour.map { listOf(it, ReminderRule.minutesUntilNext(it, heures)) },
        )
    }

    // --- Faut-il sonner ------------------------------------------------------------------------------

    private val maintenantsSilence = listOf(-1, 0, 1, 599, 600, 601, 659, 660, 719, 720, 721, 1119, 1120, 1121, 1439, 1440)
    private val couchers: List<Int?> = listOf(null, 0, 600, 719, 720, 721, 1120, 1439, 1440, -1)

    private fun shouldNotify() = (0 until 8).flatMap { bits ->
        val fait = (bits and 4) != 0
        val repos = (bits and 2) != 0
        val veille = (bits and 1) != 0
        couchers.map { coucher ->
            linkedMapOf(
                "doneToday" to fait, "todayIsRestDay" to repos, "tomorrowIsRestDay" to veille, "sunsetMinutes" to coucher,
                "maintenants" to maintenantsSilence,
                "resultats" to maintenantsSilence.map { ReminderRule.shouldNotify(it, fait, repos, veille, coucher) },
            )
        }
    }

    // --- L'instant du prochain rappel -----------------------------------------------------------------

    // 7 h ; 7 h et 20 h ; 2 h 30 et 1 h 30 (dans l'heure qui manque ou qui double, selon le fuseau) ;
    // 3 h 20 et 2 h 30 (le jour du passage à l'heure d'été, 2 h 30 devient 3 h 30, après 3 h 20) ;
    // les bornes du jour ; la liste sale de ReminderTimesTest.
    private val listesHeures: List<List<Int>> = listOf(
        listOf(7 * 60),
        listOf(7 * 60, 20 * 60),
        listOf(0, 59, 2 * 60, 2 * 60 + 30, 3 * 60, 23 * 60 + 59),
        listOf(21 * 60, 7 * 60, 7 * 60, -30, ReminderRule.MINUTES_PAR_JOUR + 10, 13 * 60),
        listOf(2 * 60 + 30),
        listOf(60 + 30),
        listOf(3 * 60 + 20, 2 * 60 + 30),
    )

    /** Les quatre premières listes sur deux ans à grands pas ; toutes, chaque nuit où l'heure change, à pas de 10 min. */
    private fun prochainDeclenchement(): List<Map<String, Any?>> = fuseaux.flatMap { id ->
        val zone = ZoneId.of(id)
        val ordinaires = listesHeures.take(4).map { heures -> balayage(zone, heures, DEBUT_BALAYAGE.toEpochMilli(), 2003, 525) }
        val nuits = changements(zone).flatMap { t ->
            listesHeures.map { heures -> balayage(zone, heures, t.toEpochMilli() - 5 * 60 * MINUTE, 10, 61) }
        }
        ordinaires + nuits
    }

    private fun balayage(zone: ZoneId, heures: List<Int>, debut: Long, pas: Int, nombre: Int): Map<String, Any?> = linkedMapOf(
        "fuseau" to zone.id, "heures" to heures, "debut" to debut, "pas" to pas, "nombre" to nombre,
        "ecarts" to (0 until nombre).map { k ->
            val maintenant = vu(debut + k.toLong() * pas * MINUTE, zone)
            ReminderRule.prochainDeclenchement(maintenant, heures)?.let { r ->
                check(r.zone == zone) { "le rappel a changé de fuseau : $r" }
                ecart(maintenant, r)
            }
        },
    )

    /** Les cas de FiabiliteTest, puis des instants à la milliseconde près, dans l'heure qui manque et dans celle qui double. */
    private fun casDeclenchement(): List<Map<String, Any?>> = listOf(
        a("Europe/Paris", 2026, 9, 29, 6, 30) to listOf(7 * 60),
        a("Europe/Paris", 2026, 9, 29, 21, 0) to listOf(7 * 60, 20 * 60),
        a("Europe/Paris", 2026, 9, 29, 6, 30) to emptyList<Int>(),
        a("Europe/Paris", 2026, 3, 28, 22, 0) to listOf(7 * 60),
        a("Europe/Paris", 2026, 10, 24, 22, 0) to listOf(7 * 60),
        a("Europe/Paris", 2026, 3, 28, 22, 0) to listOf(2 * 60 + 30),
        a("Europe/Paris", 2026, 9, 29, 6, 59, 59, 999) to listOf(7 * 60),
        a("Europe/Paris", 2026, 9, 29, 7, 0) to listOf(7 * 60),
        a("Europe/Paris", 2026, 9, 29, 7, 0, 0, 1) to listOf(7 * 60),
        a("Europe/Paris", 2026, 9, 29, 10, 0) to listOf(-5, 1440),
        a("Europe/Paris", 2026, 12, 31, 23, 59, 59, 999) to listOf(0),
        instant("Europe/Paris", "2026-03-29T01:10:00Z") to listOf(3 * 60 + 20, 2 * 60 + 30),
        instant("Europe/Paris", "2026-03-29T00:59:59.999Z") to listOf(2 * 60 + 30),
        instant("Europe/Paris", "2026-10-25T00:15:00Z") to listOf(2 * 60 + 30),
        instant("Europe/Paris", "2026-10-25T00:45:00Z") to listOf(2 * 60 + 30),
        instant("Europe/Paris", "2026-10-25T01:15:00Z") to listOf(2 * 60 + 30),
        instant("America/New_York", "2026-11-01T05:15:00Z") to listOf(60 + 30),
        instant("America/New_York", "2026-11-01T06:15:00Z") to listOf(60 + 30),
        instant("America/New_York", "2026-03-08T06:59:59.999Z") to listOf(2 * 60 + 30),
        instant("Asia/Jerusalem", "2026-10-24T22:45:00Z") to listOf(60 + 30),
        instant("Asia/Jerusalem", "2026-03-26T23:50:00Z") to listOf(2 * 60 + 30),
        instant("Australia/Melbourne", "2026-04-04T15:45:00Z") to listOf(2 * 60 + 30),
        instant("Australia/Melbourne", "2026-10-03T15:45:00Z") to listOf(2 * 60 + 30),
    ).map { (maintenant, heures) ->
        val r = ReminderRule.prochainDeclenchement(maintenant, heures)
        linkedMapOf(
            "fuseau" to maintenant.zone.id, "maintenant" to millis(maintenant), "heures" to heures,
            "resultat" to r?.let(::millis), "civile" to r?.format(CIVILE), "decalage" to r?.offset?.totalSeconds,
        )
    }

    // --- « Chabbat dans 3 h » ----------------------------------------------------------------------------

    /**
     * Une heure d'allumage pour chaque date ([heure] peut rendre null), et des semaines de « maintenant »
     * à pas de 30 minutes à partir de minuit du premier jour, dans [fuseauMaintenant].
     */
    private class Scenario(
        val nom: String, val fuseauMaintenant: String, val fuseauAllumage: String,
        val premier: LocalDate, val jours: Int, val heure: (LocalDate) -> ZonedDateTime?,
    )

    private fun scenarios(): List<Scenario> {
        val jerusalem = ZoneId.of("Asia/Jerusalem")
        val paris = ZoneId.of("Europe/Paris")
        val melbourne = ZoneId.of("Australia/Melbourne")
        // De 16 h à 18 h 59, sans allumage un jour sur cinq.
        val variable = { d: LocalDate ->
            if (Math.floorMod(d.toEpochDay(), 5L) == 0L) null
            else d.atStartOfDay().plusMinutes(960 + Math.floorMod(d.toEpochDay() * 37, 180L)).atZone(paris)
        }
        val ailleurs = { d: LocalDate -> d.atTime(17, 45).plusMinutes(10 * Math.floorMod(d.toEpochDay(), 4L)).atZone(jerusalem) }
        return listOf(
            // ChabbatAlerteTest : 17 h 45 à Jérusalem, quatre semaines où l'heure d'hiver revient.
            Scenario("test", "Asia/Jerusalem", "Asia/Jerusalem", LocalDate.of(2026, 10, 10), 28) { d -> d.atTime(17, 45).atZone(jerusalem) },
            Scenario("variablePrintemps", "Europe/Paris", "Europe/Paris", LocalDate.of(2026, 3, 14), 28, variable),
            Scenario("variableAutomne", "Europe/Paris", "Europe/Paris", LocalDate.of(2026, 10, 17), 21, variable),
            // Le téléphone à New York, l'allumage à Jérusalem : l'alerte garde le fuseau de l'allumage.
            Scenario("ailleurs", "America/New_York", "Asia/Jerusalem", LocalDate.of(2026, 3, 7), 21, ailleurs),
            Scenario("jamais", "Asia/Jerusalem", "Asia/Jerusalem", LocalDate.of(2026, 10, 12), 7) { null },
            Scenario("melbourneAvril", "Australia/Melbourne", "Australia/Melbourne", LocalDate.of(2026, 3, 28), 14) { d -> d.atTime(18, 30).atZone(melbourne) },
            Scenario("melbourneOctobre", "Australia/Melbourne", "Australia/Melbourne", LocalDate.of(2026, 9, 26), 14) { d -> d.atTime(18, 30).atZone(melbourne) },
            // Un allumage à 2 h 30 : l'alerte tombe la veille au soir, et le 27 mars 2026 l'heure manque à Jérusalem.
            Scenario("nuit", "Asia/Jerusalem", "Asia/Jerusalem", LocalDate.of(2026, 3, 14), 21) { d -> d.atTime(2, 30).atZone(jerusalem) },
        )
    }

    /** La table des allumages d'un scénario : de la veille du premier jour à deux semaines après le dernier. */
    private fun table(s: Scenario): Pair<LocalDate, List<ZonedDateTime?>> {
        val zm = ZoneId.of(s.fuseauMaintenant)
        val debut = millis(s.premier.atStartOfDay(zm))
        val dernier = vu(debut + (s.jours * 48 - 1).toLong() * 30 * MINUTE, zm).toLocalDate()
        val premier = s.premier.minusDays(1)
        val n = ChronoUnit.DAYS.between(premier, dernier.plusDays(15)).toInt()
        return premier to (0 until n).map { s.heure(premier.plusDays(it.toLong())) }
    }

    private fun allumage(s: Scenario): (LocalDate) -> ZonedDateTime? {
        val (premier, valeurs) = table(s)
        val parJour = valeurs.indices.associate { premier.plusDays(it.toLong()) to valeurs[it] }
        return { d -> parJour[d] }
    }

    private fun chabbatAlerte(): List<Map<String, Any?>> = scenarios().map { s ->
        val zm = ZoneId.of(s.fuseauMaintenant)
        val debut = millis(s.premier.atStartOfDay(zm))
        val nombre = s.jours * 48
        val (premier, valeurs) = table(s)
        val f = allumage(s)
        linkedMapOf(
            "nom" to s.nom, "fuseauMaintenant" to s.fuseauMaintenant, "fuseauAllumage" to s.fuseauAllumage,
            "premierJour" to premier.toString(), "allumages" to valeurs.map { it?.let(::millis) },
            "debut" to debut, "pas" to 30, "nombre" to nombre,
            "ecarts" to (0 until nombre).map { k ->
                val maintenant = vu(debut + k.toLong() * 30 * MINUTE, zm)
                ChabbatAlerte.prochaine(maintenant, f)?.let { r ->
                    check(r.zone.id == s.fuseauAllumage) { "l'alerte a changé de fuseau : $r" }
                    ecart(maintenant, r)
                }
            },
        )
    }

    /** Les cas de ChabbatAlerteTest, puis l'alerte à la milliseconde près. */
    private fun casChabbat(): List<Map<String, Any?>> {
        val parNom = scenarios().associateBy { it.nom }
        fun le(j: Int, h: Int, m: Int, s: Int = 0, ms: Int = 0) = a("Asia/Jerusalem", 2026, 10, j, h, m, s, ms)
        return listOf(
            "test" to le(13, 9, 0), "test" to le(16, 10, 0), "test" to le(16, 15, 0), "jamais" to le(13, 9, 0),
            "test" to le(16, 14, 44, 59, 999), "test" to le(16, 14, 45), "test" to le(16, 14, 45, 0, 1),
            "test" to le(15, 23, 59, 59, 999), "test" to le(17, 0, 0),
        ).map { (nom, maintenant) ->
            val r = ChabbatAlerte.prochaine(maintenant, allumage(parNom.getValue(nom)))
            linkedMapOf(
                "scenario" to nom, "fuseauMaintenant" to maintenant.zone.id, "maintenant" to millis(maintenant),
                "resultat" to r?.let(::millis), "civile" to r?.format(CIVILE),
            )
        }
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursRappels.kt"),
        "constantes" to linkedMapOf(
            "noSunsetCutoffMinutes" to ReminderRule.NO_SUNSET_CUTOFF_MINUTES,
            "minutesParJour" to ReminderRule.MINUTES_PAR_JOUR,
            "snoozeMinutes" to Reminder.SNOOZE_MINUTES,
            "avanceHeures" to ChabbatAlerte.AVANCE_HEURES,
        ),
        "minutesUntilNext" to minutesUntilNext(),
        "shouldNotify" to shouldNotify(),
        "prochainDeclenchement" to prochainDeclenchement(),
        "prochainDeclenchementCas" to casDeclenchement(),
        "chabbatAlerte" to chabbatAlerte(),
        "chabbatAlerteCas" to casChabbat(),
    )
}
