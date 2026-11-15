// Les règles de la pratique (tâche 8) devant la JVM : l'arithmétique d'une séance (SessionRule), la durée
// saisie (DureeSeance), les trois anneaux et leurs fêtes (Anneaux, JaugeSemaine), les faces de la plaque,
// la salutation, les sujets, l'adresse, puis ce que Store.kt décide sans contexte : la fenêtre de nuit, la
// reprise d'une prière, le jour du Tikoun ; enfin l'heure du prochain rappel (ReminderRule) et le prochain
// changement d'une vignette (ZmanimVignette), que les tests de la tâche 8 appellent.

import com.myhitbodedut.Adresse
import com.myhitbodedut.Anneaux
import com.myhitbodedut.DureeSeance
import com.myhitbodedut.JaugeSemaine
import com.myhitbodedut.Plaque
import com.myhitbodedut.ReminderRule
import com.myhitbodedut.Salutation
import com.myhitbodedut.SessionRule
import com.myhitbodedut.Store
import com.myhitbodedut.Theme
import com.myhitbodedut.ThemeRules
import com.myhitbodedut.WeekDay
import com.myhitbodedut.ZmanimVignette
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.random.Random

object VecteursPratique : Generateur {
    override val fichier = "pratique.json"

    private const val MINUTE = 60_000L
    private const val DEBUT = 1_800_000_000_000L

    private fun nom(id: Int): String = Identifiants.nom(id)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursPratique.kt"),
        // « début|fin|durée|maintenant » → estOuverte, enCours, minutesEcoulees, minutesAInscrire, estEchue,
        // minutesRestantes(fin, maintenant) : sans séance, minutée de 20 minutes, ouverte, avec une horloge qui recule.
        "seances" to seances(),
        "compteurs" to listOf(false, true).flatMap { o -> listOf(false, true).map { m -> listOf(o, m, SessionRule.compteur(o, m).name) } },
        // Le texte saisi, rogné à la manière de Kotlin, lu par toIntOrNull (chiffres d'autres écritures compris), borné.
        "durees_saisies" to listOf(
            "", " ", "25", " 25 ", "\t25\n", "0", "-5", "-0", "+7", "07", "1", "240", "241", "600", "vingt", "1e2", "2.5",
            "2147483647", "2147483648", "-2147483648", "-2147483649", "99999999999", "٣", "٢٥", "３０", "१५", "+", "-",
            "１", " 25 ", "​25", "25 min", "𝟐𝟓", "٣٠٠",
        ).map { listOf(it, DureeSeance.lire(it)) },
        "durees_proposees" to DureeSeance.PROPOSEES.toList(),
        "durees_courtes" to ((-5..200) + listOf(239, 240, 599, 600, 601, 1439, 1440, 6000)).map { listOf(it, JaugeSemaine.dureeCourte(it)) },
        "paliers" to (-3..1500).map { Anneaux.palier(it) },
        // « fait, objectif » → fraction, tours, reste (simple précision), atteint.
        "anneaux" to (-2..47).flatMap { f ->
            listOf(0, 1, 7, 14, 15, 20, 30, 365).map { o ->
                val a = Anneaux.Anneau(Anneaux.Quel.JOUR, f, o)
                listOf(f, o, a.fraction, a.tours, a.reste, a.atteint)
            }
        },
        // « minutes, objectif, faits, dus, série » → ce que l'état garde de chaque anneau, ses marques, et ce qui est
        // à fêter le mercredi 7 octobre 2026, le jeudi et le dimanche suivants : sans rien de fêté, puis après le mercredi.
        "etats" to etats(),
        "objectifs" to listOf(-5, 0, 1, 15, 20).flatMap { r -> listOf(-3, 0, 1, 15, 60).map { d -> listOf(r, d, Anneaux.objectifEffectif(r, d)) } },
        // Une semaine de sept cases, « f » faite, « x » exemptée → faits, dus, fraction.
        "jauges" to jauges(),
        "faces" to Plaque.Face.entries.map { listOf(it.name, it.anneau?.name, Plaque.suivante(it).name) },
        "faces_anneaux" to Anneaux.Quel.entries.map { listOf(it.name, Plaque.pour(it).name) },
        "moyennes" to listOf(0, 1, 5, 7, 49, 50, 51, 99, 100, 101, 200, 1234, 999_999, 16_777_217).flatMap { t ->
            listOf(-1, 0, 1, 2, 3, 4, 6, 7, 10, 13, 400).map { j -> listOf(t, j, Plaque.moyenne(t, j)) }
        },
        "meilleures_series" to meilleuresSeries(),
        "salutations" to (-1..24).map { h -> listOf(h, Salutation.partie(h).name, nom(Salutation.mot(h)), nom(Salutation.chaine(h))) },
        "themes" to Theme.entries.map { listOf(it.name, it.cle, nom(it.titre)) },
        "themes_lus" to listOf("", " ", "autre", "AUTRE", "parnassa", " parnassa", "teshouva_2031", "aucun", null).map { listOf(it, ThemeRules.parse(it)?.name) },
        "themes_frequents" to themesFrequents(),
        "adresses" to listOf("m", "f", "", "x", "M", " m", null).map { listOf(it, Adresse.parse(it)?.name) },
        "adresses_mots" to (Adresse.entries + listOf(null)).map { listOf(it?.name, nom(Adresse.bravo(it)), nom(Adresse.hazak(it)), it?.let { a -> nom(a.nom) }) },
        // « début|fin|maintenant|faitA|r » : r dit, pour chaque jeu de jours faits (aucun, le 2, le 3, le 1er novembre),
        // si la fenêtre est honorée (1) ou non (0).
        "fenetres" to fenetres(),
        "reprises" to reprises(),
        "tikkun" to tikkun(),
        // « fuseau|maintenant|heures » → le prochain rappel, en millisecondes et en heure civile, ou null.
        "rappels" to rappels(),
        // « fuseau, maintenant, horaires, minuit du téléphone » → le prochain changement (millisecondes).
        "vignettes" to vignettes(false),
        // « fuseau, maintenant, tsét » → le jour civil dont la vignette montre le jour hébreu.
        "vignettes_jours" to vignettes(true),
    )

    private fun seances(): List<String> {
        val lignes = mutableListOf<String>()
        val decalages = listOf(-MINUTE, -1L, 0L, 1L, 30_000L, 59_999L, MINUTE, 12 * MINUTE + 30_000L, 20 * MINUTE - 1, 20 * MINUTE,
            20 * MINUTE + 1, 35 * MINUTE, 60 * MINUTE, 240 * MINUTE - 1, 240 * MINUTE, 241 * MINUTE, 20 * 60 * MINUTE)
        for (debut in listOf(0L, DEBUT)) {
            for ((fin, duree) in listOf(0L to SessionRule.OUVERTE, DEBUT + 20 * MINUTE to 20, DEBUT + 1 to 0, 0L to 20)) {
                for (d in decalages) {
                    val maintenant = DEBUT + d
                    lignes += listOf(
                        debut, fin, duree, maintenant,
                        SessionRule.estOuverte(debut, duree), SessionRule.enCours(debut, fin, duree, maintenant),
                        SessionRule.minutesEcoulees(debut, maintenant), SessionRule.minutesAInscrire(debut, fin, maintenant),
                        SessionRule.estEchue(debut, fin, duree, maintenant), SessionRule.minutesRestantes(fin, maintenant),
                    ).joinToString("|")
                }
            }
        }
        return lignes
    }

    private val mercredi = LocalDate.of(2026, 10, 7)

    private fun etats(): List<Any?> {
        val lignes = mutableListOf<Any?>()
        val semaines = listOf(4 to 6, 0 to 0, 6 to 6, 7 to 6)
        for (m in listOf(-5, 8, 15, 30)) for (o in listOf(0, 15)) for ((f, d) in semaines) for (s in listOf(-2, 4, 7, 8, 14, 366)) {
            val e = Anneaux.etat(m, o, JaugeSemaine.Progression(f, d), s)
            val deja = Anneaux.marques(e, mercredi)
            lignes.add(listOf<Any?>(m, o, f, d, s) +
                e.duCentre.flatMap { listOf(it.quel.name, it.fait, it.objectif, it.fraction) } +
                listOf(Anneaux.marques(e, mercredi).sorted()) +
                listOf(0, 1, 4).map { k ->
                    val jour = mercredi.plusDays(k.toLong())
                    listOf(Anneaux.aFeter(e, jour, emptySet()).map { it.name }, Anneaux.aFeter(e, jour, deja).map { it.name })
                })
        }
        return lignes
    }

    private fun jauges(): List<Any?> {
        val r = Random(8)
        val dimanche = LocalDate.of(2026, 9, 27)
        return (0 until 200).map {
            val cases = (0..6).map { listOf("", "f", "x", "fx")[r.nextInt(4)] }
            val jours = cases.mapIndexed { i, c ->
                WeekDay(dimanche.plusDays(i.toLong()), done = 'f' in c, exempt = 'x' in c, shabbat = i == 6, future = false)
            }
            val p = JaugeSemaine.progression(jours)
            listOf(cases, p.faits, p.dus, p.fraction)
        }
    }

    private fun meilleuresSeries(): List<Any?> {
        val r = Random(11)
        val origine = LocalDate.of(2026, 1, 1)
        return (0 until 150).map { k ->
            val longueur = 1 + r.nextInt(60)
            val faits = (0 until longueur).filter { r.nextInt(3) != 0 }.map { origine.plusDays(it.toLong()) }.toSet()
            val exemptes = (0 until longueur).filter { r.nextInt(5) == 0 }.map { origine.plusDays(it.toLong()) }.toSet()
            // Une fois sur trois, le samedi exempté aussi, comme un Chabbat chômé.
            val samedi = k % 3 == 0
            val exempt = { d: LocalDate -> d in exemptes || (samedi && d.dayOfWeek == java.time.DayOfWeek.SATURDAY) }
            listOf(faits.map { it.toEpochDay() - origine.toEpochDay() }.sorted(),
                exemptes.map { it.toEpochDay() - origine.toEpochDay() }.sorted(), samedi, Plaque.meilleureSerie(faits, exempt))
        }
    }

    private fun themesFrequents(): List<Any?> {
        val r = Random(5)
        val cles = Theme.entries.map { it.cle } + listOf("inconnu", "", " ", "AUTRE")
        return (0 until 80).map { k ->
            val liste = (0 until r.nextInt(25)).map { cles[r.nextInt(cles.size)] }
            val max = listOf(0, 1, 2, 4, 4, 10)[k % 6]
            listOf(liste, max, ThemeRules.frequents(liste, max).map { listOf(it.first.name, it.second) })
        }
    }

    private fun fenetres(): List<String> {
        val lignes = mutableListOf<String>()
        val d = LocalDate.of(2026, 11, 2)
        val fenetres = listOf(21 * 60 to 2 * 60, 6 * 60 to 12 * 60, 22 * 60 to 0, 0 to 0, 23 * 60 + 30 to 23 * 60 + 29, 21 * 60 to 21 * 60)
        val instants = listOf(d.atTime(0, 0), d.atTime(1, 59), d.atTime(2, 0), d.atTime(7, 0), d.atTime(21, 30),
            d.atTime(23, 59, 59), d.plusDays(1).atTime(0, 30), d.plusDays(1).atTime(1, 0), d.plusDays(1).atTime(21, 30))
        val faits = listOf(null, d.minusDays(1).atTime(21, 30), d.atTime(1, 59, 59), d.atTime(2, 0), d.atTime(10, 0),
            d.atTime(21, 30), d.plusDays(1).atTime(0, 30))
        val jours = listOf(emptySet(), setOf(d), setOf(d.plusDays(1)), setOf(d.minusDays(1)))
        for ((debut, fin) in fenetres) for (m in instants) for (f in faits) {
            val r = jours.joinToString("") { j -> if (Store.fenetreFaite(debut, fin, m, f) { it in j }) "1" else "0" }
            lignes += listOf(debut, fin, m, f ?: "-", r).joinToString("|")
        }
        return lignes
    }

    private fun reprises(): List<Any?> {
        val t0 = 1_793_000_000_000L
        val lignes = mutableListOf<Any?>()
        for (cle in listOf("s:chaharit", "s:", "l:likoutei_etsot", "", "S:chaharit", "x")) {
            for (quand in listOf(0L, -1L, t0)) {
                for (ecart in listOf(-1L, 0L, 1L, 20 * MINUTE, Store.PRIERE_REPRISE_MS - 1, Store.PRIERE_REPRISE_MS, 24 * 60 * MINUTE)) {
                    lignes.add(listOf(cle, quand, t0 + ecart, Store.repriseValable(cle, quand, t0 + ecart)))
                }
            }
        }
        return lignes
    }

    private fun tikkun(): List<Any?> = listOf(
        LocalDateTime.of(2026, 11, 1, 23, 45), LocalDateTime.of(2026, 11, 2, 0, 5), LocalDateTime.of(2026, 11, 2, 3, 59, 59),
        LocalDateTime.of(2026, 11, 2, 4, 0), LocalDateTime.of(2026, 11, 2, 9, 0), LocalDateTime.of(2027, 1, 1, 3, 0),
        LocalDateTime.of(2024, 3, 1, 2, 0), LocalDateTime.of(2028, 2, 29, 4, 0), LocalDateTime.of(2026, 3, 29, 2, 30),
    ).map { listOf(it.toString(), Store.jourTikkun(it)) }

    private fun rappels(): List<String> {
        val lignes = mutableListOf<String>()
        val listes = listOf(listOf(7 * 60), listOf(7 * 60, 20 * 60), listOf(2 * 60 + 30), listOf(0), listOf(1439),
            listOf(-1, 1440, 600, 600, 30), emptyList(), listOf(20 * 60, 7 * 60, 12 * 60 + 15))
        val cas = listOf(
            "Europe/Paris" to listOf(LocalDateTime.of(2026, 9, 29, 6, 30), LocalDateTime.of(2026, 9, 29, 21, 0),
                LocalDateTime.of(2026, 3, 28, 22, 0), LocalDateTime.of(2026, 3, 29, 2, 15), LocalDateTime.of(2026, 10, 24, 22, 0),
                LocalDateTime.of(2026, 10, 25, 2, 30), LocalDateTime.of(2026, 12, 31, 23, 59), LocalDateTime.of(2028, 2, 28, 20, 0)),
            "America/New_York" to listOf(LocalDateTime.of(2026, 3, 7, 23, 0), LocalDateTime.of(2026, 11, 1, 0, 30)),
            "Asia/Jerusalem" to listOf(LocalDateTime.of(2026, 3, 26, 23, 0), LocalDateTime.of(2026, 10, 24, 23, 30)),
            "Australia/Melbourne" to listOf(LocalDateTime.of(2026, 4, 4, 22, 0), LocalDateTime.of(2026, 10, 3, 23, 0)),
            "America/Santiago" to listOf(LocalDateTime.of(2026, 9, 5, 22, 0)),
        )
        for ((zone, instants) in cas) for (m in instants) for (h in listes) {
            val maintenant = ZonedDateTime.of(m, ZoneId.of(zone))
            val p = ReminderRule.prochainDeclenchement(maintenant, h)
            lignes += listOf(zone, maintenant.toInstant().toEpochMilli(), h.joinToString(","),
                p?.toInstant()?.toEpochMilli() ?: "-", p?.let { "%s %02d:%02d".format(it.toLocalDate(), it.hour, it.minute) } ?: "-").joinToString("|")
        }
        return lignes
    }

    private fun vignettes(jours: Boolean): List<Any?> {
        val lignes = mutableListOf<Any?>()
        val cas = listOf(
            "Europe/Paris" to LocalDateTime.of(2026, 11, 2, 9, 5), "Europe/Paris" to LocalDateTime.of(2026, 11, 2, 13, 0),
            "Europe/Paris" to LocalDateTime.of(2026, 11, 2, 23, 55), "Europe/Paris" to LocalDateTime.of(2026, 3, 28, 23, 55),
            "America/Santiago" to LocalDateTime.of(2026, 9, 5, 23, 55), "Asia/Jerusalem" to LocalDateTime.of(2026, 11, 2, 17, 51),
        )
        for ((zone, m) in cas) {
            val z = ZoneId.of(zone)
            val maintenant = ZonedDateTime.of(m, z)
            val horaires = listOf(
                emptyList(), listOf(maintenant.plusMinutes(7), null, maintenant.plusHours(5)), listOf(maintenant.plusHours(3), maintenant.minusHours(1)),
                listOf(maintenant), listOf(maintenant.plusSeconds(1)), listOf(null, null),
            )
            if (!jours) for (h in horaires) for (tel in listOf(null, maintenant.plusMinutes(2), maintenant.minusMinutes(2))) {
                lignes.add(listOf(zone, maintenant.toInstant().toEpochMilli(), h.map { it?.toInstant()?.toEpochMilli() },
                    tel?.toInstant()?.toEpochMilli(), ZmanimVignette.prochainChangement(h, maintenant, tel).toInstant().toEpochMilli()))
            }
            if (jours) for (tset in listOf(null, maintenant.minusMinutes(1), maintenant, maintenant.plusMinutes(1))) {
                lignes.add(listOf(zone, maintenant.toInstant().toEpochMilli(), tset?.toInstant()?.toEpochMilli(),
                    ZmanimVignette.jourHebreuAffiche(maintenant, tset).toString()))
            }
        }
        return lignes
    }
}
