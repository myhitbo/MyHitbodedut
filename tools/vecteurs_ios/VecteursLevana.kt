// Birkat haLevana devant la JVM : ce que répondent Levana et LevanaAlerte d'Android (le molad et les
// bornes viennent de KosherJava 2.5.0), que rejouent LevanaTests et LevanaAlerteTests de Coeur.
//
// Les instants sont des millisecondes Unix, les jours des dates ISO. Un état de Levana.etat s'écrit en
// nombre : Dans(n) → n (≥ 0), CeSoir → -1, DernierSoir → -2. Un rappel de LevanaAlerte s'écrit
// [date, nom du soir]. Dans « fenetres », une fenêtre tient en sept chaînes, pour rester sous 300 Ko :
// [début, fin, restriction ou "", premier soir, dernier soir, motsaé Chabbat ou "", noms des soirs du
// rappel séparés d'une espace] ; la date d'un soir du rappel est celle du premier soir, du motsaé
// Chabbat ou du dernier soir. Les vues d'un mois suivent l'ordre de « fuseaux », leurs fenêtres celui
// de « usages ».

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import com.myhitbodedut.Levana
import com.myhitbodedut.LevanaAlerte
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

object VecteursLevana : Generateur {
    override val fichier = "levana.json"

    private val fuseaux = listOf("Asia/Jerusalem", "Europe/Paris", "America/New_York", "Australia/Melbourne")
    private val usages = Levana.Usage.entries

    private const val JOUR = 86_400_000L

    private fun etat(e: Levana.Etat): Int = when (e) {
        is Levana.Etat.Dans -> e.jours
        Levana.Etat.CeSoir -> -1
        Levana.Etat.DernierSoir -> -2
    }

    /** Le premier jour de chaque mois hébreu, de Tichri 5784 à Eloul 5790 (le 1 du mois, le jour civil). */
    private val premiersJours: List<LocalDate> = buildList {
        var d = LocalDate.of(2023, 9, 1)
        while (d.isBefore(LocalDate.of(2030, 10, 15))) {
            val c = JewishCalendar(d)
            if (c.jewishDayOfMonth == 1 && c.jewishYear in 5784..5790) add(d)
            d = d.plusDays(1)
        }
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursLevana.kt"),
        "usages" to usages.map { u ->
            linkedMapOf("nom" to u.name, "cle" to u.cle, "libelle" to Identifiants.entree(u.libelle),
                "troisJours" to u.troisJours, "quinzeJours" to u.quinzeJours)
        },
        // Usage.duNusah, pour les trois noussa'hs de l'app.
        "duNusah" to listOf("edot", "sefard", "ashkenaz").map { n -> listOf(n, Levana.Usage.duNusah(n).cle) },
        "restrictions" to Levana.Restriction.entries.map { it.name },
        "soirsAlerte" to LevanaAlerte.Soir.entries.map { s -> linkedMapOf("nom" to s.name, "titre" to Identifiants.entree(s.titre)) },
        // Le mois lunaire moyen (29 j 12 h 793 halakim), lu sur une fenêtre : prochainMolad - molad.
        "mois" to Levana.fenetre(LocalDate.of(2026, 10, 14), ZoneId.of("Asia/Jerusalem")).let {
            it.prochainMolad.toEpochMilli() - it.molad.toEpochMilli()
        },
        "fuseaux" to fuseaux,
        // Chaque mois hébreu de 5784 à 5790, vu de chaque fuseau, pour chacun des usages : la fenêtre du
        // 1 du mois, son motsaé Chabbat conseillé depuis le premier soir, et les soirs du rappel depuis ce 1.
        "fenetres" to premiersJours.map { date ->
            val c = JewishCalendar(date)
            val vues = fuseaux.map { id ->
                val zone = ZoneId.of(id)
                usages.map { Levana.fenetre(date, zone, it) to zone }
            }
            val molad = vues[0][0].first.molad
            check(vues.all { v -> v.all { it.first.molad == molad } }) { "$date : un même molad pour chaque fuseau et chaque usage" }
            linkedMapOf("date" to date.toString(), "annee" to c.jewishYear, "mois" to c.jewishMonth, "molad" to molad.toEpochMilli(),
                "vues" to vues.map { v ->
                    v.map { (f, zone) ->
                        val premier = f.premierSoir(zone)
                        val dernier = f.dernierSoir(zone)
                        val motsae = Levana.motsaeChabbat(f, premier, zone)
                        val rappels = LevanaAlerte.soirs(f, date, zone)
                        check(rappels.all { (d, s) ->
                            d == when (s) { LevanaAlerte.Soir.PREMIER -> premier; LevanaAlerte.Soir.MOTSAE -> motsae; LevanaAlerte.Soir.DERNIER -> dernier }
                        }) { "$date : la date d'un soir du rappel" }
                        listOf(f.debut.toEpochMilli().toString(), f.fin.toEpochMilli().toString(), f.restriction?.name ?: "",
                            premier.toString(), dernier.toString(), motsae?.toString() ?: "", rappels.joinToString(" ") { it.second.name })
                    }
                })
        },
        // Autour des bornes, à Jérusalem et à New York, de Tichri à Eloul 5787 : Levana.etat du
        // troisième jour avant le premier soir au deuxième après le dernier, et Levana.part à des instants voisins.
        "bornes" to premiersJours.filter { JewishCalendar(it).jewishYear == 5787 }.flatMap { date ->
            listOf("Asia/Jerusalem", "America/New_York").flatMap { id ->
                val zone = ZoneId.of(id)
                usages.map { u ->
                    val f = Levana.fenetre(date, zone, u)
                    val depart = f.premierSoir(zone).minusDays(3)
                    val jours = generateSequence(depart) { it.plusDays(1) }.takeWhile { !it.isAfter(f.dernierSoir(zone).plusDays(2)) }.toList()
                    val m = f.molad.toEpochMilli()
                    val p = f.prochainMolad.toEpochMilli()
                    val instants = listOf(m - JOUR, m - 1, m, m + 1, f.debut.toEpochMilli(), f.fin.toEpochMilli(),
                        Levana.soir(f.premierSoir(zone), zone).toEpochMilli(), Levana.soir(f.dernierSoir(zone), zone).toEpochMilli(),
                        p - 1, p, p + 1)
                    linkedMapOf("date" to date.toString(), "fuseau" to id, "usage" to u.cle, "depart" to depart.toString(),
                        "etats" to jours.map { etat(Levana.etat(f, it, zone)) },
                        "instants" to instants,
                        "parts" to instants.map { Levana.part(f, Instant.ofEpochMilli(it)) })
                }
            }
        },
        // Jour après jour, ce que montre la carte du jour : la fenêtre du soir (son molad), son état, le
        // motsaé Chabbat conseillé à partir de ce jour, la place du soir (20 h) sur la jauge.
        "jours" to listOf(
            "Asia/Jerusalem" to Levana.Usage.SEPT_MI_MOIS, "Europe/Paris" to Levana.Usage.TROIS_MI_MOIS,
            "America/New_York" to Levana.Usage.SEPT_QUINZE, "Australia/Melbourne" to Levana.Usage.SEPT_MI_MOIS,
        ).map { (id, u) ->
            val zone = ZoneId.of(id)
            val depart = LocalDate.of(2026, 7, 15)
            val jours = (0L until 170L).map { depart.plusDays(it) }
            val fs = jours.map { Levana.fenetre(it, zone, u) }
            linkedMapOf("fuseau" to id, "usage" to u.cle, "depart" to depart.toString(),
                "molads" to fs.map { it.molad.toEpochMilli() },
                "etats" to jours.indices.map { etat(Levana.etat(fs[it], jours[it], zone)) },
                "motsae" to jours.indices.map { Levana.motsaeChabbat(fs[it], jours[it], zone)?.toString() },
                "parts" to jours.indices.map { Levana.part(fs[it], Levana.soir(jours[it], zone)) })
        },
        // Le soir de 20 h, y compris les jours où l'heure change.
        "soirs20h" to listOf("2026-03-08", "2026-03-27", "2026-03-29", "2026-04-05", "2026-09-27", "2026-10-04", "2026-10-25",
            "2026-11-01", "2027-01-01").flatMap { jour ->
            fuseaux.map { id -> listOf(jour, id, Levana.soir(LocalDate.parse(jour), ZoneId.of(id)).toEpochMilli().toString()) }
        },
        // La lune par pas de 29 h sur vingt mois, plus les instants de LevanaTest et quelques extrêmes.
        "phase" to run {
            val debut = Instant.parse("2026-01-01T00:00:00Z").toEpochMilli()
            val instants = (0L until 500L).map { debut + it * 29 * 3_600_000L } + listOf(
                Instant.parse("2026-10-10T12:00:00Z").toEpochMilli(), Instant.parse("2026-10-18T12:00:00Z").toEpochMilli(),
                Instant.parse("2026-10-26T12:00:00Z").toEpochMilli(), 0L, -1L, 1L, -1_000_000_000_000L, 946_684_800_000L,
                1_700_000_000_000L, 4_102_444_800_000L, 4_000_000_000_000L)
            val lunes = instants.map { Levana.phase(Instant.ofEpochMilli(it)) }
            linkedMapOf("instants" to instants, "eclairages" to lunes.map { it.eclairage }, "croissantes" to lunes.map { it.croissante })
        },
        // La suite des rappels sur deux ans, l'heure du soir à 20 h : chaque rappel trouvé, puis le suivant
        // cherché une minute après.
        "suites" to fuseaux.flatMap { id ->
            val zone = ZoneId.of(id)
            usages.map { u ->
                val fin = ZonedDateTime.of(2028, 1, 1, 0, 0, 0, 0, zone)
                var maintenant = ZonedDateTime.of(2026, 1, 1, 0, 0, 0, 0, zone)
                val rappels = mutableListOf<List<String>>()
                while (true) {
                    val (quand, soir) = LevanaAlerte.prochain(maintenant, u) { d -> d.atTime(20, 0).atZone(zone) } ?: break
                    if (quand.isAfter(fin)) break
                    rappels.add(listOf(quand.toLocalDate().toString(), soir.name))
                    maintenant = quand.plusMinutes(1)
                }
                linkedMapOf("fuseau" to id, "usage" to u.cle, "rappels" to rappels)
            }
        },
        // Le prochain rappel vu de chaque jour, à midi et à 21 h, du 1er août au 30 novembre 2026.
        "prochains" to listOf("Asia/Jerusalem" to Levana.Usage.SEPT_MI_MOIS, "America/New_York" to Levana.Usage.TROIS_MI_MOIS).map { (id, u) ->
            val zone = ZoneId.of(id)
            val depart = LocalDate.of(2026, 8, 1)
            val reponses = (0L until 122L).flatMap { k ->
                val jour = depart.plusDays(k)
                listOf(12, 21).map { h ->
                    LevanaAlerte.prochain(jour.atTime(h, 0).atZone(zone), u) { d -> d.atTime(20, 0).atZone(zone) }
                        ?.let { (q, s) -> listOf(q.toLocalDate().toString(), s.name) }
                }
            }
            linkedMapOf("fuseau" to id, "usage" to u.cle, "depart" to depart.toString(), "heures" to listOf(12, 21), "reponses" to reponses)
        },
    )
}
