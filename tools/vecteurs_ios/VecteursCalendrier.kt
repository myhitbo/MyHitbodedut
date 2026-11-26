// Le calendrier des prières devant la JVM (audit halakhique du 16/11) : ce que répondent CalendrierJuif et
// SiddurJour.conditionsPour d'Android jour après jour, que rejoue CalendrierVecteursTests de Coeur.
//
// web/test/vecteurs_kosherjava.json juge déjà les conditions de C.TOUTES ; ici, les conditions déduites
// (C.DERIVEES), le Chabbat spécial, les repères du jour (Seli'hot, chofar, בה״ב…), la période sans musique, puis
// ce que conditionsPour ajoute ou retire selon le noussa'h, l'Israël, la coutume de la fin de Tichri et
// l'hémisphère. Une condition s'écrit par son rang dans « derivees » (C.DERIVEES) ou « toutes » (C.TOUTES).
//
// Puis JourAffiche : les ajouts du jour (noussa'h, Israël, « pas de Ta'hanoun aujourd'hui »), la note du Yom
// tov chéni, l'allumage à Jérusalem, le Tikoun 'hatsot et Ra'hel, la prière ouvrable ; les horaires du jour
// (entrée, sortie, jeûne, 'hamets) et la suggestion du siddour en quelques lieux, aux instants écrits ; et
// SiddurMoment (heures fixes, Ilanot selon le noussa'h).
//
// Les jours : du 1er septembre 2025 au 30 septembre 2027 (5786 et 5787 entiers), en diaspora, en Israël et à
// Jérusalem (ville murée) ; plus les Pourim triples de 5781 et 5785 et les jours de jeûne repoussés.

import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.JourAffiche
import com.myhitbodedut.SiddurJour
import com.myhitbodedut.SiddurMoment
import com.myhitbodedut.Zmanim
import java.time.Instant
import java.time.ZoneId
import java.time.LocalDate
import java.time.LocalTime

object VecteursCalendrier : Generateur {
    override val fichier = "calendrier.json"

    private val C = CalendrierJuif.C
    private val derivees = C.DERIVEES
    private val toutes = C.TOUTES
    private val nusahs = listOf("edot", "sefard", "ashkenaz")

    private data class Lieu(val nom: String, val israel: Boolean, val muree: Boolean)

    private val lieux = listOf(Lieu("diaspora", false, false), Lieu("israel", true, false), Lieu("jerusalem", true, true))

    private val jours: List<LocalDate> = run {
        val tous = generateSequence(LocalDate.of(2025, 9, 1)) { it.plusDays(1) }.takeWhile { !it.isAfter(LocalDate.of(2027, 9, 30)) }.toList()
        // Pourim triple : 5781 (15 Adar le samedi 27/02/2021) et 5785 (15 Adar le samedi 15/03/2025).
        val pourimTriples = (-2L..2L).flatMap { listOf(LocalDate.of(2021, 2, 27).plusDays(it), LocalDate.of(2025, 3, 15).plusDays(it)) }
        (pourimTriples + tous).distinct()
    }

    private fun rangs(c: Set<String>, liste: List<String>): List<Int> = liste.indices.filter { liste[it] in c }

    private fun jour(d: LocalDate, l: Lieu): Map<String, Any?> {
        val j = CalendrierJuif.jour(d, l.israel, l.muree)
        val inconnues = j.conditions - derivees.toSet() - toutes.toSet()
        check(inconnues.isEmpty()) { "$d : conditions hors des listes $inconnues" }
        return linkedMapOf(
            "d" to rangs(j.conditions, derivees),
            "t" to rangs(j.conditions, toutes),
            "s" to j.parachaSpeciale,
            // Les repères, noussa'h par noussa'h (la ville murée n'y change rien : ils ne sont pas relevés pour elle).
            "r" to if (l.muree) null else nusahs.map { CalendrierJuif.reperes(d, l.israel, it) },
            // conditionsPour, noussa'h par noussa'h : ce qu'il ajoute (rangs dans derivees puis toutes, « +d3 »…)
            // et retire, la coutume de la fin de Tichri du noussa'h, l'hémisphère nord ; puis l'autre coutume et
            // le sud pour les Edot, et le réglage « pas de Ta'hanoun aujourd'hui ».
            "p" to nusahs.map { n -> ecart(j.conditions, SiddurJour.conditionsPour(n, l.israel, j.conditions)) },
            // JourAffiche.ajouts : Edot, Sfard, Ashkenaz, puis Ashkenaz avec « pas de Ta'hanoun aujourd'hui ».
            "a" to nusahs.map { JourAffiche.ajouts(j.conditions, it, l.israel) } +
                listOf(JourAffiche.ajouts(SiddurJour.avecSansTahanoun(j.conditions, true), "ashkenaz", l.israel)),
            "pa" to listOf(
                ecart(j.conditions, SiddurJour.conditionsPour("edot", l.israel, j.conditions, sansTahanounFinTichri = false)),
                ecart(j.conditions, SiddurJour.conditionsPour("sefard", l.israel, j.conditions, sansTahanounFinTichri = true)),
                ecart(j.conditions, SiddurJour.conditionsPour("edot", l.israel, j.conditions, sud = true)),
                ecart(j.conditions, SiddurJour.conditionsPour("ashkenaz", l.israel, SiddurJour.avecSansTahanoun(j.conditions, true))),
            ),
        )
    }

    private fun code(c: String): String {
        val i = derivees.indexOf(c)
        if (i >= 0) return "d$i"
        val k = toutes.indexOf(c)
        check(k >= 0) { "condition inconnue : $c" }
        return "t$k"
    }

    private fun ecart(avant: Set<String>, apres: Set<String>): String =
        ((apres - avant).map { "+" + code(it) }.sorted() + (avant - apres).map { "-" + code(it) }.sorted()).joinToString(" ")

    private val lieuxZmanim = listOf(
        Zmanim.Lieu("Jérusalem", 31.76904, 35.21633, 0.0, "Asia/Jerusalem"),
        Zmanim.Lieu("Paris", 48.85341, 2.3488, 0.0, "Europe/Paris"),
        Zmanim.Lieu("Londres", 51.50853, -0.12574, 0.0, "Europe/London"),
        Zmanim.Lieu("New York", 40.71427, -74.00597, 0.0, "America/New_York"),
    )

    /** Les jours où les horaires changent : fêtes, Chabbat, jeûnes, veilles de Pessa'h (dont un Chabbat), 9 Av. */
    private val joursHoraires = listOf("2026-04-01", "2026-04-02", "2026-04-03", "2026-04-04", "2026-04-08", "2026-04-09",
        "2026-04-10", "2026-04-11", "2026-07-02", "2026-07-22", "2026-07-23", "2026-09-11", "2026-09-12", "2026-09-13",
        "2026-09-20", "2026-09-21", "2026-10-02", "2026-10-03", "2026-10-04", "2026-11-20", "2026-11-21", "2026-12-20",
        "2027-03-22", "2027-04-20", "2027-04-21", "2027-04-22", "2027-04-23", "2027-04-24", "2027-06-10", "2027-06-11",
        "2027-06-12", "2027-08-11", "2027-08-12", "2027-08-13", "2025-04-11", "2025-04-12", "2025-08-02", "2025-08-03")
        .map { LocalDate.parse(it) }

    /** JourAffiche.horaires : [clé, méthode, paramètres, statut, instant] par ligne, profil commun et Edot. */
    private fun horaires(): List<Map<String, Any?>> = lieuxZmanim.flatMap { lieu ->
        joursHoraires.flatMap { d ->
            listOf(false, true).filter { !it || lieu.fuseau == "Asia/Jerusalem" }.flatMap { israel ->
                listOf(Zmanim.NUSAH_COMMUN, "edot").map { n ->
                    linkedMapOf("lieu" to lieu.nom, "date" to d.toString(), "israel" to israel, "nusah" to n,
                        "lignes" to JourAffiche.horaires(lieu, d, israel, 18, n).map { z ->
                            listOf(z.cle, z.methode.cle, z.methode.parametres, z.statut.name, z.instant?.toEpochMilli())
                        })
                }
            }
        }
    }

    /** JourAffiche.momentDuSiddour toutes les heures (à la 17ᵉ minute), sur quelques jours, Edot et Ashkenaz. */
    private fun moments(): List<Map<String, Any?>> = lieuxZmanim.flatMap { lieu ->
        listOf("2026-06-21", "2026-07-15", "2026-07-25", "2026-10-03", "2026-12-21", "2027-04-24").map { LocalDate.parse(it) }.flatMap { d ->
            listOf("edot", "ashkenaz").map { n ->
                val zone = ZoneId.of(lieu.fuseau)
                val instants = (0 until 24).map { h -> d.atTime(h, 17).atZone(zone).toInstant() }
                linkedMapOf("lieu" to lieu.nom, "date" to d.toString(), "nusah" to n,
                    "instants" to instants.map(Instant::toEpochMilli),
                    "moments" to instants.map { JourAffiche.momentDuSiddour(lieu, it, lieu.fuseau == "Asia/Jerusalem", n) })
            }
        }
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursCalendrier.kt"),
        "derivees" to derivees,
        "toutes" to toutes,
        "lieux" to lieux.map { linkedMapOf("nom" to it.nom, "israel" to it.israel, "muree" to it.muree) },
        "jours" to jours.map { d ->
            linkedMapOf("date" to d.toString(), "lieux" to lieux.map { jour(d, it) },
                "musique" to CalendrierJuif.periodeSansMusique(d))
        },
        // JourAffiche, jour par jour (diaspora, Israël) : la note du Yom tov chéni (statut, lieu, noussa'h), le
        // Tikoun 'hatsot omis la nuit de ce jour, le Tikoun Ra'hel de midi (Edot, Sfard, Ashkenaz), la prière
        // ouvrable (Cha'harit à 8 h, Min'ha à 14 h, Arvit à 20 h), SiddurMoment.ilanot (nord, sud ; sans
        // noussa'h, Edot, Sfard, Ashkenaz).
        "affiche" to jours.map { d ->
            linkedMapOf(
                "date" to d.toString(),
                "ytc" to listOf(true to false, false to true).flatMap { (statut, lieu) -> nusahs.map { JourAffiche.noteYomTovCheni(d, statut, lieu, it) } },
                "sansTikoun" to listOf(JourAffiche.sansTikounHatsot(d, false), JourAffiche.sansTikounHatsot(d, true)),
                "rahel" to nusahs.map { JourAffiche.tikounRahelDeMidi(d, it) },
                "ouvrable" to listOf(false, true).flatMap { israel ->
                    listOf("chaharit" to 8, "minha" to 14, "arvit" to 20, "birkot_hachahar" to 6).map { (m, h) ->
                        JourAffiche.momentOuvrable(m, d, LocalTime.of(h, 0), israel)
                    }
                },
                "ilanot" to listOf(32.0, -33.0).flatMap { lat -> listOf(null, "edot", "sefard", "ashkenaz").map { SiddurMoment.ilanot(d, lat, it) } },
            )
        },
        "ligneDate" to listOf(-180.0, -150.1, -150.0, -149.9, 0.0, 35.2, 125.1, 125.2, 125.3, 180.0).map { listOf(it, JourAffiche.ligneDateDiscutee(it)) },
        "allumage" to nusahs.flatMap { n ->
            listOf(false, true).flatMap { muree ->
                listOf(18, 20, 22, 30, 40).map { m ->
                    listOf(n, muree, m, JourAffiche.propositionAllumage(n, muree, m), JourAffiche.coutumeJerusalem(n, muree, m))
                }
            }
        },
        "suggestion" to (0 until 24 * 4).flatMap { q ->
            listOf(false, true).map { sans -> listOf(q * 15, sans, SiddurMoment.suggestion(LocalTime.of(q / 4, (q % 4) * 15), sans)) }
        },
        "horaires" to horaires(),
        "moments" to moments(),
        // Le jour hébreu d'une prière : texte, heure (de 0 à 23), après la sortie des étoiles → décalage en jours.
        "jourDeLaPriere" to listOf("arvit", "chema_coucher", "minha", "chaharit", "tikoun_hatsot", "birkat", "", "sefirat_haomer").flatMap { t ->
            (0..23).flatMap { h ->
                listOf(false, true).map { apres ->
                    val d = LocalDate.of(2026, 11, 17)
                    listOf(t, h, apres, CalendrierJuif.jourDeLaPriere(t, d, LocalTime.of(h, 30), apres).toEpochDay() - d.toEpochDay())
                }
            }
        },
        // Le jour voisin du Birkat haMazon et de Méèn chaloch (26/11, Q6) : texte, heure (de 0 à 23), après le coucher
        // (null, faux, vrai), après la sortie (null, faux, vrai) → décalage en jours, ou null.
        "jourVoisin" to listOf("birkat_hamazon", "meen_chaloch", "chaharit", "arvit", "").flatMap { t ->
            (0..23).flatMap { h ->
                listOf(null, false, true).flatMap { coucher ->
                    listOf(null, false, true).map { sortie ->
                        val d = LocalDate.of(2026, 11, 20)
                        listOf(t, h, coucher, sortie,
                            CalendrierJuif.jourVoisin(t, d, LocalTime.of(h, 30), coucher, sortie)?.let { it.toEpochDay() - d.toEpochDay() })
                    }
                }
            }
        },
        // La nuit, pour la lecture : heure, après la sortie (null, faux, vrai), avant l'aube (null, faux, vrai).
        "nuit" to (0..23).flatMap { h ->
            listOf(null, false, true).flatMap { a ->
                listOf(null, false, true).map { b -> listOf(h, a, b, CalendrierJuif.nuit(LocalTime.of(h, 0), a, b)) }
            }
        },
    )
}
