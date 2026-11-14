// Les trois anneaux de l'accueil devant la JVM : ce que répond Anneaux.kt pour les paliers de la série,
// les valeurs d'un anneau (fraction, tours et reste, en simple précision), l'état bâti des chiffres du
// jour, l'objectif effectif et les marques de fête. D'abord les cas d'AnneauxTest, puis un balayage :
// bornes des entiers, zéro, négatifs, voisins des paliers, chaque jour de la semaine, fins de mois,
// d'année et de siècle.

import com.myhitbodedut.Anneaux
import com.myhitbodedut.JaugeSemaine
import java.time.LocalDate

object VecteursAnneaux : Generateur {
    override val fichier = "anneaux.json"

    private val JOUR = Anneaux.Quel.JOUR
    private val SEMAINE = Anneaux.Quel.SEMAINE
    private val SERIE = Anneaux.Quel.SERIE
    private const val MAX = Int.MAX_VALUE
    private const val MIN = Int.MIN_VALUE

    /** La semaine et le mercredi d'AnneauxTest. */
    private val semaine = JaugeSemaine.Progression(faits = 4, dus = 6)
    private val mercredi = LocalDate.of(2026, 10, 7)

    /** Les trois anneaux fermés : chacun a sa marque. */
    private val tousFermes = Anneaux.etat(15, 15, JaugeSemaine.Progression(6, 6), 7)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursAnneaux.kt"),
        "table" to Anneaux.PALIERS.toList(),
        "paliers" to paliers(),
        "anneaux" to anneaux(),
        "etats" to etats(),
        "parQuel" to parQuel(),
        "objectifs" to objectifs(),
        "marques" to marques(),
        "marquesLointaines" to marquesLointaines(),
    )

    /** Les bits d'un flottant : ils disent aussi le signe d'un zéro, que sa valeur écrite peut perdre. */
    private fun bits(f: Float): Int = java.lang.Float.floatToRawIntBits(f)

    private fun anneau(a: Anneaux.Anneau) = linkedMapOf("quel" to a.quel.name, "fait" to a.fait, "objectif" to a.objectif)

    // --- Le palier que vise la série ---------------------------------------------------------------
    // Au-delà de 2 147 483 283 jours, « serie + 364 » déborde les 32 bits d'un Int : Kotlin rend alors un
    // palier négatif, sans lever. Les dernières lignes le montrent.

    private fun paliers() = (listOf(0, 1, 7, 8, 14, 15, 30, 31, 100, 101, 365, 366, 730, 731) + (-3..370) +
        listOf(729, 1094, 1095, 1096, 1459, 1460, 1461, 3649, 3650, 3651, 36_499, 36_500, 36_501, 100_000,
            MAX - 365, MAX - 364, MAX - 363, MAX - 1, MAX, MIN, MIN + 1, -100))
        .distinct().map { serie -> linkedMapOf("serie" to serie, "palier" to Anneaux.palier(serie)) }

    // --- Un anneau : fraction, tours, reste, atteint -----------------------------------------------

    private fun anneaux(): List<Map<String, Any?>> {
        val duTest = listOf(8 to 15, 23 to 15, 30 to 15, 4 to 6, 0 to 7, 7 to 7, 8 to 14, 10 to 0, 0 to 0, 0 to 15)
        // 16 777 217 : le premier entier qu'un flottant ne sait pas écrire.
        val faits = listOf(MIN, -5, -1, 0, 1, 4, 7, 8, 14, 15, 16, 23, 30, 31, 45, 100, 1000, 16_777_217, MAX)
        val objectifs = listOf(-1, 0, 1, 3, 6, 7, 14, 15, 365, 16_777_217, MAX)
        return (duTest + faits.flatMap { f -> objectifs.map { o -> f to o } }).distinct().map { (fait, objectif) ->
            val a = Anneaux.Anneau(JOUR, fait, objectif)
            linkedMapOf(
                "fait" to fait, "objectif" to objectif,
                "fraction" to a.fraction, "bitsFraction" to bits(a.fraction),
                "tours" to a.tours, "reste" to a.reste, "bitsReste" to bits(a.reste), "atteint" to a.atteint,
            )
        }
    }

    // --- L'état : les trois anneaux bâtis des chiffres du jour -------------------------------------

    private fun etats(): List<Map<String, Any?>> {
        // minutesJour, objectifJour, jours faits et dus de la semaine, série.
        val duTest = listOf(
            listOf(8, 15, 4, 6, 4), listOf(23, 15, 4, 6, 4), listOf(30, 15, 4, 6, 4), listOf(0, 15, 4, 6, 0),
            listOf(0, 15, 4, 6, 7), listOf(0, 15, 4, 6, 8), listOf(10, 0, 0, 0, 0), listOf(-5, 15, 4, 6, -2),
            listOf(15, 15, 4, 6, 4), listOf(0, 15, 6, 6, 7), listOf(0, 15, 0, 0, 14),
        )
        val minutes = listOf(MIN, -5, 0, 1, 8, 15, 23, 30, 600, MAX)
        val objectifs = listOf(MIN, -3, 0, 1, 15, 20, 60, MAX)
        val faits = listOf(-1, 0, 2, 4, 6, 7, MAX)
        val dus = listOf(-1, 0, 5, 6, 7)
        val series = listOf(MIN, -2, 0, 4, 7, 8, 14, 15, 99, 100, 101, 180, 181, 365, 366, 730, 731, 5000, MAX)
        // Chaque liste tourne à son pas : toutes les valeurs passent, dans des compagnies variées.
        val balayage = (0 until 3 * series.size).map { i ->
            listOf(minutes[i % minutes.size], objectifs[(i * 3) % objectifs.size], faits[(i * 2) % faits.size],
                dus[(i * 3) % dus.size], series[i % series.size])
        }
        return (duTest + balayage).distinct().map { (m, o, f, d, s) ->
            val e = Anneaux.etat(minutesJour = m, objectifJour = o, semaine = JaugeSemaine.Progression(f, d), serie = s)
            linkedMapOf(
                "entree" to linkedMapOf("minutesJour" to m, "objectifJour" to o, "faits" to f, "dus" to d, "serie" to s),
                "jour" to anneau(e.jour), "semaine" to anneau(e.semaine), "serie" to anneau(e.serie),
                "duCentre" to e.duCentre.map { it.quel.name },
                // Du centre vers l'extérieur : les bits de la fraction de chaque anneau, et s'il est fermé.
                "bitsFractions" to e.duCentre.map { bits(it.fraction) },
                "atteints" to e.duCentre.map { it.atteint },
            )
        }
    }

    // --- Etat.anneau(quel) : le premier du centre qui porte ce nom ---------------------------------
    // Un état bâti à la main peut n'avoir aucun anneau de ce nom : Kotlin lève alors
    // NoSuchElementException, écrit null ici.

    private fun parQuel() = listOf(
        Anneaux.etat(8, 15, semaine, 4),
        Anneaux.Etat(Anneaux.Anneau(SERIE, 1, 2), Anneaux.Anneau(SERIE, 3, 4), Anneaux.Anneau(JOUR, 5, 6)),
        Anneaux.Etat(Anneaux.Anneau(SEMAINE, 1, 2), Anneaux.Anneau(SEMAINE, 3, 4), Anneaux.Anneau(SEMAINE, 5, 6)),
        Anneaux.Etat(Anneaux.Anneau(SERIE, 1, 2), Anneaux.Anneau(JOUR, 3, 4), Anneaux.Anneau(SEMAINE, 5, 6)),
    ).map { e ->
        linkedMapOf(
            "duCentre" to e.duCentre.map(::anneau),
            "trouves" to Anneaux.Quel.entries.map { q -> runCatching { e.anneau(q) }.getOrNull()?.let(::anneau) },
        )
    }

    // --- L'objectif quotidien effectif -------------------------------------------------------------

    private fun objectifs(): List<Map<String, Any?>> {
        val regles = listOf(MIN, -5, -1, 0, 1, 15, 20, MAX)
        val durees = listOf(MIN, -3, 0, 1, 15, 60, MAX)
        return (listOf(0 to 15, 20 to 15, 0 to 0) + regles.flatMap { r -> durees.map { d -> r to d } }).distinct()
            .map { (regle, duree) ->
                linkedMapOf("regle" to regle, "dureeHabituelle" to duree, "objectif" to Anneaux.objectifEffectif(regle, duree))
            }
    }

    // --- Les marques de fête -----------------------------------------------------------------------

    /**
     * Un état, un jour : la marque de chaque anneau, les marques gardées, et ce qui reste à fêter
     * selon ce qui l'a déjà été (rien, les marques du jour, de la veille, de la semaine d'avant,
     * des marques voisines des vraies qui n'en sont pas, et [autres]).
     */
    private fun fete(etat: Anneaux.Etat, jour: LocalDate, vararg autres: Set<String>): Map<String, Any?> {
        val iso = jour.toString()
        val palier = etat.serie.objectif
        val deja = (listOf(
            emptySet(),
            Anneaux.marques(etat, jour),
            Anneaux.marques(etat, jour.minusDays(1)),
            Anneaux.marques(etat, jour.minusDays(7)),
            setOf("serie:$palier"),
            setOf("", "jour:", "JOUR:$iso", "jour:$iso ", " jour:$iso", "jour: $iso", "semaine:$iso", "serie:0$palier", "série:$palier"),
        ) + autres).distinct()
        return linkedMapOf(
            "jour" to iso,
            "duCentre" to etat.duCentre.map(::anneau),
            "parAnneau" to etat.duCentre.map { Anneaux.marque(it, jour) },
            "marques" to Anneaux.marques(etat, jour).toList(),
            "fetes" to deja.map { d ->
                linkedMapOf("deja" to d.toList(), "aFeter" to Anneaux.aFeter(etat, jour, d).map { it.name })
            },
        )
    }

    private fun marques(): List<Map<String, Any?>> {
        // Les cas d'AnneauxTest.
        val plein = Anneaux.etat(15, 15, semaine, 4)
        val ouvert = Anneaux.etat(8, 15, semaine, 4)
        val semainePleine = Anneaux.etat(0, 15, JaugeSemaine.Progression(6, 6), 7)
        val quatorze = Anneaux.etat(0, 15, JaugeSemaine.Progression(0, 0), 14)
        val dejaPlein = Anneaux.marques(plein, mercredi)
        val dejaSemaine = Anneaux.marques(semainePleine, mercredi)
        val duTest = listOf(
            fete(plein, mercredi),
            fete(plein, mercredi.plusDays(1), dejaPlein),
            fete(ouvert, mercredi),
            fete(semainePleine, mercredi),
            fete(semainePleine, mercredi.plusDays(1), dejaSemaine),
            fete(semainePleine, LocalDate.of(2026, 10, 11), dejaSemaine),
            fete(quatorze, mercredi, dejaSemaine),
        )
        // Les trois anneaux fermés : chaque jour de deux semaines, du dimanche au dimanche, puis des
        // fins de mois, d'année et de siècle, où le dimanche de la semaine tombe de l'autre côté.
        val dimanche = LocalDate.of(2026, 9, 27)
        val jours = (0..14).map { dimanche.plusDays(it.toLong()) } + listOf(
            "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03", "2028-02-29", "2028-03-01", "2028-03-04", "2024-03-02",
            "2000-01-01", "1970-01-01", "2100-03-01", "1900-03-03", "0001-01-01", "9999-12-31",
        ).map { LocalDate.parse(it) }
        // D'autres états, un même mercredi : second tour, objectif nul, anneaux ouverts, bornes des
        // entiers, puis des états bâtis à la main où un même nom revient.
        val autres = listOf(
            Anneaux.etat(30, 15, JaugeSemaine.Progression(7, 6), 365),
            Anneaux.etat(10, 0, JaugeSemaine.Progression(0, 0), 0),
            Anneaux.etat(15, 15, JaugeSemaine.Progression(5, 6), 6),
            Anneaux.etat(14, 15, JaugeSemaine.Progression(7, 7), 8),
            Anneaux.etat(0, 15, JaugeSemaine.Progression(0, 6), 730),
            Anneaux.etat(MAX, 1, JaugeSemaine.Progression(MAX, MAX), MAX),
            Anneaux.Etat(Anneaux.Anneau(SERIE, 7, 7), Anneaux.Anneau(SERIE, 7, 7), Anneaux.Anneau(SERIE, 14, 14)),
            Anneaux.Etat(Anneaux.Anneau(JOUR, 1, 1), Anneaux.Anneau(JOUR, 2, 1), Anneaux.Anneau(SEMAINE, 3, 3)),
        )
        return duTest + jours.map { fete(tousFermes, it) } + autres.map { fete(it, mercredi) }
    }

    /**
     * Hors des années 0000 à 9999, java.time écrit l'année avec son signe (« +10000-01-01 »,
     * « -0044-03-15 ») : les marques du jour et de la semaine le portent. La date est donnée par ses
     * trois nombres.
     */
    private fun marquesLointaines() = listOf(
        LocalDate.of(10000, 1, 1), LocalDate.of(10000, 1, 2), LocalDate.of(123456, 7, 8), LocalDate.of(0, 1, 1),
        LocalDate.of(0, 1, 2), LocalDate.of(-1, 12, 31), LocalDate.of(-44, 3, 15), LocalDate.of(-12345, 6, 7),
        LocalDate.of(999_999, 12, 31), LocalDate.of(-999_999, 1, 8),
    ).map { d ->
        linkedMapOf(
            "annee" to d.year, "mois" to d.monthValue, "jour" to d.dayOfMonth,
            "duCentre" to tousFermes.duCentre.map(::anneau),
            "parAnneau" to tousFermes.duCentre.map { Anneaux.marque(it, d) },
        )
    }
}
