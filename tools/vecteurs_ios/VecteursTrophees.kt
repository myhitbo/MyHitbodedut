// Les trophées et le bilan de la semaine devant la JVM : ce que répondent Trophees.kt et BilanSemaine.kt.
// Les familles (seuils, formes, icônes), le métal de chaque rang, le coût et l'ordre du chemin, les grades,
// la progression ; les suites, semaines pleines et retours d'un ensemble de jours ; puis des pratiques :
// la valeur et le rang de chaque famille, la progression, le prochain, le proche, les plus proches et les
// nouveautés ; enfin des historiques jour par jour, avec la date de gain de chaque niveau (rejeu jour après
// jour, jours exemptés compris) et le bilan de la semaine écoulée vu de plusieurs jours. D'abord les cas des
// tests d'Android (TropheesTest, CheminTropheesTest, BilanTropheesTest, TropheesTikkunTest), puis chaque
// seuil de chaque famille (juste sous, dessus), des cas choisis (vides, 0 min, minutes négatives, sommes qui
// débordent les 32 bits, tous les niveaux gagnés) et des historiques tirés d'une graine fixe.
//
// Une pratique s'écrit depuis un jour « debut » : « parJour » (minutes du jour debut + i, null : rien),
// puis « plages » [décalage, nombre, pas, minutes] posées par-dessus (la dernière l'emporte), les notes, la
// meilleure série, le Tikoun en décalages et en plages [décalage, nombre, pas].

import com.myhitbodedut.BilanSemaine
import com.myhitbodedut.Plaque
import com.myhitbodedut.Trophees
import com.myhitbodedut.Trophees.Famille
import java.time.DayOfWeek
import java.time.LocalDate
import kotlin.random.Random

object VecteursTrophees : Generateur {
    override val fichier = "trophees.json"

    private const val MAX = Int.MAX_VALUE
    private const val MIN = Int.MIN_VALUE

    /** Les bits d'un flottant : ils disent aussi le signe d'un zéro, que sa valeur écrite peut perdre. */
    private fun bits(f: Float): Int = java.lang.Float.floatToRawIntBits(f)

    private fun bits(d: Double): Long = java.lang.Double.doubleToRawLongBits(d)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTrophees.kt"),
        "metaux" to Trophees.Metal.entries.map { it.name },
        "formes" to Trophees.Forme.entries.map { linkedMapOf("nom" to it.name, "cle" to it.cle) },
        "familles" to Famille.entries.map { f ->
            linkedMapOf("nom" to f.name, "cle" to f.cle, "icone" to f.icone, "seuils" to f.seuils.toList(), "forme" to f.forme.name)
        },
        // [famille, rang, métal] : le rang de 1 au nombre de seuils, et au-delà (Kotlin calcule sur 32 bits).
        "metal" to metaux(),
        // [famille, seuil, bits du coût]
        "couts" to couts(),
        "chemin" to Trophees.chemin.map { it.cle },
        "seuilsGrades" to Trophees.SEUILS_GRADES.toList(),
        "grades" to ((0..70) + listOf(99, 100, 1000, MAX)).map { listOf(it, Trophees.grade(it).name) },
        // [valeur, cible, bits de la fraction]
        "progres" to progres(),
        "suites" to suites(),
        "seuils" to seuils(),
        "pratiques" to pratiques(),
        "historiques" to historiques(),
    )

    private fun metaux(): List<List<Any?>> = Famille.entries.flatMap { f ->
        ((-3..f.seuils.size + 3) + listOf(MIN, MIN + 1, -536_870_912, 536_870_912, 536_870_913, 1_000_000, MAX - 1, MAX))
            .distinct().map { r -> listOf(f.name, r, Trophees.metal(f, r).name) }
    }

    private fun couts(): List<List<Any?>> = Famille.entries.flatMap { f ->
        (listOf(MIN, -1, 0, 1) + f.seuils.toList() + listOf(1000, 16_777_217, MAX)).distinct()
            .map { s -> listOf(f.name, s, bits(Trophees.cout(f, s))) }
    }

    private fun progres(): List<List<Int>> {
        val valeurs = listOf(MIN, -5, -1, 0, 1, 2, 3, 5, 7, 10, 16_777_217, MAX)
        val cibles = listOf(MIN, -1, 0, 1, 3, 7, 10, 16_777_216, 16_777_217, MAX)
        return valeurs.flatMap { v -> cibles.map { c -> listOf(v, c, bits(Trophees.Progres(v, c).fraction)) } }
    }

    // --- Un ensemble de jours : la plus longue suite, les semaines pleines, les retours ---------------------

    private fun suites(): List<Map<String, Any?>> {
        val cas = mutableListOf<Pair<String, Set<LocalDate>>>()
        fun ajoute(nom: String, jours: Collection<LocalDate>) { cas += nom to jours.toSet() }
        val dim = LocalDate.of(2026, 10, 4)
        ajoute("aucun", emptyList())
        ajoute("un jour", listOf(dim))
        ajoute("dimanche à vendredi", (0L..5L).map { dim.plusDays(it) })
        ajoute("lundi à samedi", (1L..6L).map { dim.plusDays(it) })
        ajoute("dimanche à jeudi", (0L..4L).map { dim.plusDays(it) })
        ajoute("vendredi à vendredi", (5L..12L).map { dim.plusDays(it) })
        ajoute("deux semaines pleines sans samedi", (0L..13L).map { dim.plusDays(it) }.filter { it.dayOfWeek != DayOfWeek.SATURDAY })
        ajoute("sept jours d'écart", listOf(dim, dim.plusDays(7)))
        ajoute("huit jours d'écart", listOf(dim, dim.plusDays(8)))
        ajoute("des retours", listOf(0L, 8, 16, 23, 40, 41, 42, 50).map { dim.plusDays(it) })
        ajoute("à cheval sur l'année", (0L..9L).map { LocalDate.of(2026, 12, 27).plusDays(it) })
        ajoute("le 29 février", (0L..6L).map { LocalDate.of(2028, 2, 25).plusDays(it) })
        ajoute("TropheesTest : 41 jours", (0L until 41L).map { dim.plusDays(it) })
        ajoute("TropheesTikkunTest : 0, 1, 2, 5, 6, 9", listOf(0L, 1, 2, 5, 6, 9).map { LocalDate.of(2026, 11, 1).plusDays(it) })
        val hasard = Random(1113)
        repeat(30) { rang ->
            val debut = LocalDate.of(2026, 1, 1).plusDays(hasard.nextInt(-2000, 2000).toLong())
            val n = hasard.nextInt(1, 300)
            val densite = hasard.nextInt(5, 100)
            ajoute("tiré ${rang + 1}", (0 until n).filter { hasard.nextInt(100) < densite }.map { debut.plusDays(it.toLong()) })
        }
        return cas.map { (nom, jours) ->
            val debut = jours.minOrNull()
            linkedMapOf("nom" to nom, "debut" to debut?.toString(),
                "jours" to jours.sorted().map { (it.toEpochDay() - debut!!.toEpochDay()).toInt() },
                "plusLongueSuite" to Trophees.plusLongueSuite(jours), "semainesPleines" to Trophees.semainesPleines(jours),
                "retours" to Trophees.retours(jours))
        }
    }

    // --- Une pratique écrite, et lue comme Swift la relira ---------------------------------------------------

    private class Ecrite(
        val debut: LocalDate,
        val parJour: List<Int?> = emptyList(),
        val plages: List<List<Int>> = emptyList(),
        val notes: Int = 0,
        val meilleureSerie: Int = 0,
        val tikkun: List<Int> = emptyList(),
        val plagesTikkun: List<List<Int>> = emptyList(),
    ) {
        fun minutes(): Map<LocalDate, Int> {
            val m = linkedMapOf<LocalDate, Int>()
            parJour.forEachIndexed { i, v -> if (v != null) m[debut.plusDays(i.toLong())] = v }
            for ((decalage, nombre, pas, minutes) in plages) {
                for (k in 0 until nombre) m[debut.plusDays((decalage + k * pas).toLong())] = minutes
            }
            return m
        }

        fun joursTikkun(): Set<LocalDate> {
            val t = linkedSetOf<LocalDate>()
            tikkun.forEach { t += debut.plusDays(it.toLong()) }
            for ((decalage, nombre, pas) in plagesTikkun) for (k in 0 until nombre) t += debut.plusDays((decalage + k * pas).toLong())
            return t
        }

        fun pratique(serie: Int = meilleureSerie, nombreDeNotes: Int = notes) =
            Trophees.Pratique(minutes(), nombreDeNotes, serie, joursTikkun())

        /** Les champs vides ou nuls sont omis. */
        fun json(): Map<String, Any?> {
            val m = linkedMapOf<String, Any?>("debut" to debut.toString())
            if (parJour.isNotEmpty()) m["parJour"] = parJour
            if (plages.isNotEmpty()) m["plages"] = plages
            if (notes != 0) m["notes"] = notes
            if (meilleureSerie != 0) m["meilleureSerie"] = meilleureSerie
            if (tikkun.isNotEmpty()) m["tikkun"] = tikkun
            if (plagesTikkun.isNotEmpty()) m["plagesTikkun"] = plagesTikkun
            return m
        }
    }

    private val ks = listOf(0, 1, 2, 3, 10)

    /**
     * Les nouveautés pour des « vus » : « nul » (aucune visite), « ajoutes » (vus = la liste), « sauf » (vus =
     * tous les gagnés moins la liste).
     */
    private fun variantes(gagnes: Set<Trophees.Niveau>, completes: Boolean): List<Pair<String, List<String>>> {
        val parFamille = gagnes.groupBy { it.famille }
        val plusHauts = parFamille.values.map { n -> n.maxBy { it.rang }.cle }
        val deuxPlusHauts = parFamille.values.flatMap { n -> n.sortedByDescending { it.rang }.take(2).map { it.cle } }
        val unSurTrois = gagnes.map { it.cle }.filterIndexed { i, _ -> i % 3 == 0 }
        val toutes: List<Pair<String, List<String>>> = listOf(
            "nul" to emptyList(),
            "ajoutes" to emptyList(),
            "ajoutes" to listOf("chai", "premier_pas"),
            "ajoutes" to listOf("premier_pas:1"),
            "sauf" to emptyList(),
            "sauf" to plusHauts,
            "ajoutes" to listOf(""),
            "ajoutes" to listOf("x", ":"),
            "sauf" to unSurTrois,
            "sauf" to deuxPlusHauts,
        )
        return if (completes) toutes else listOf(toutes[1], toutes[5], toutes[8])
    }

    private fun analyse(p: Trophees.Pratique, completes: Boolean, fractions: Boolean = false): Map<String, Any?> {
        val gagnes = Trophees.gagnes(p)
        val cles = gagnes.map { it.cle }.toSet()
        val res = linkedMapOf<String, Any?>(
            "valeurs" to Famille.entries.map { Trophees.valeur(p, it) },
            "rangs" to Famille.entries.map { Trophees.rang(p, it) },
            "gagnes" to gagnes.size,
            // [valeur, cible, bits de la fraction], famille par famille.
            "progres" to Famille.entries.map { f -> Trophees.progres(p, f).let { listOf(it.valeur, it.cible, bits(it.fraction)) } },
            "prochain" to Trophees.prochain(p)?.cle,
            "proche" to Trophees.proche(p)?.cle,
            // Les plus proches pour k = 0, 1, 2, 3, 10, puis sans k (3 par défaut).
            "plusProches" to ks.map { k -> Trophees.plusProches(p, k).map { it.cle } },
            "plusProchesParDefaut" to Trophees.plusProches(p).map { it.cle },
            "nouveaux" to variantes(gagnes, completes).map { (type, liste) ->
                val vus: Set<String>? = when (type) {
                    "nul" -> null
                    "ajoutes" -> liste.toSet()
                    else -> cles - liste.toSet()
                }
                linkedMapOf("type" to type, "liste" to liste, "rendus" to Trophees.nouveaux(gagnes, vus).map { it.cle })
            },
        )
        // Pour les cas des tests : la fraction vers chaque étape du chemin, dans l'ordre du chemin.
        if (fractions) res["fractions"] = Trophees.chemin.map { bits(Trophees.fraction(p, it)) }
        return res
    }

    // --- Chaque seuil de chaque famille : juste sous, dessus ; et au-delà du dernier --------------------------
    // [famille, cible, valeur, rang, cible de la progression, bits de sa fraction], pour une pratique minimale
    // bâtie par pourValeur depuis le dimanche 4/10/2026 (le test Swift la rebâtit de même) : n = max(cible, 0)
    // jours d'une minute (premier pas, jours), un jour de « cible » minutes (séance longue) ou de 60 × cible
    // minutes (heures), la meilleure série, n semaines du dimanche au vendredi à 15 min, n vendredis, n + 1
    // jours à huit jours d'écart (retours), « cible » notes, n lectures du Tikoun un jour sur deux (tikkun) ou
    // d'affilée (tikkun_serie).

    private fun pourValeur(f: Famille, v: Int): Ecrite {
        val dim = LocalDate.of(2026, 10, 4)
        val n = maxOf(v, 0)
        return when (f) {
            Famille.PREMIER_PAS, Famille.JOURS -> Ecrite(dim, plages = listOf(listOf(0, n, 1, 1)))
            Famille.SEANCE_LONGUE -> Ecrite(dim, parJour = listOf(v))
            Famille.SERIE -> Ecrite(dim, meilleureSerie = v)
            Famille.HEURES -> Ecrite(dim, parJour = listOf(v * 60))
            Famille.SEMAINES -> Ecrite(dim, plages = (0 until n).map { listOf(7 * it, 6, 1, 15) })
            Famille.EREV_CHABBAT -> Ecrite(dim, plages = listOf(listOf(5, n, 7, 15)))
            Famille.RETOUR -> Ecrite(dim, plages = listOf(listOf(0, n + 1, 8, 15)))
            Famille.PLUME -> Ecrite(dim, notes = v)
            Famille.TIKKUN -> Ecrite(dim, plagesTikkun = listOf(listOf(0, n, 2)))
            Famille.TIKKUN_SERIE -> Ecrite(dim, plagesTikkun = listOf(listOf(0, n, 1)))
        }
    }

    private fun seuils(): List<List<Any?>> = Famille.entries.flatMap { f ->
        (f.seuils.flatMap { listOf(it - 1, it) } + (f.seuils.last() + 1)).distinct().map { cible ->
            val e = pourValeur(f, cible)
            val p = e.pratique()
            val pr = Trophees.progres(p, f)
            listOf(f.name, cible, Trophees.valeur(p, f), Trophees.rang(p, f), pr.cible, bits(pr.fraction))
        }
    }

    // --- Des pratiques (sans les jours des notes) -------------------------------------------------------------

    private fun pratique(nom: String, e: Ecrite, completes: Boolean = true): Map<String, Any?> =
        linkedMapOf("nom" to nom, "pratique" to e.json()) + analyse(e.pratique(), completes, fractions = completes)

    private fun pratiques(): List<Map<String, Any?>> {
        // TropheesTest : depuis le dimanche 4/10/2026.
        val dim = LocalDate.of(2026, 10, 4)
        // CheminTropheesTest : depuis le 1/09/2026, 15 min ; BilanTropheesTest : depuis le dimanche 6/09/2026.
        val sept = LocalDate.of(2026, 9, 1)
        val d0 = LocalDate.of(2026, 9, 6)
        val tikkun = LocalDate.of(2026, 11, 1)
        val duTest = listOf(
            pratique("TropheesTest : rien", Ecrite(dim)),
            pratique("TropheesTest : un jour", Ecrite(dim, plages = listOf(listOf(0, 1, 1, 20)), meilleureSerie = 1)),
            pratique("TropheesTest : 42 jours", Ecrite(dim, plages = listOf(listOf(0, 41, 1, 20), listOf(60, 1, 1, 130)),
                notes = 26, meilleureSerie = 41)),
            pratique("TropheesTest : 6 jours de 70 min", Ecrite(dim, plages = listOf(listOf(0, 6, 1, 70)), notes = 12, meilleureSerie = 6)),
            pratique("TropheesTest : 700 jours de 200 min", Ecrite(dim, plages = listOf(listOf(0, 700, 1, 200)), notes = 200,
                meilleureSerie = 700)),
            pratique("TropheesTest : 20 jours", Ecrite(dim, plages = listOf(listOf(0, 20, 1, 20)), meilleureSerie = 20)),
            pratique("CheminTropheesTest : 11 jours, 15 notes", Ecrite(sept, plages = listOf(listOf(0, 11, 1, 15)), notes = 15,
                meilleureSerie = 11)),
            pratique("CheminTropheesTest : 11 jours", Ecrite(sept, plages = listOf(listOf(0, 11, 1, 15)), meilleureSerie = 11)),
            pratique("BilanTropheesTest : 6 jours", Ecrite(d0, plages = listOf(listOf(0, 6, 1, 15)), meilleureSerie = 6)),
            pratique("BilanTropheesTest : 8 jours", Ecrite(d0, plages = listOf(listOf(0, 8, 1, 15)), meilleureSerie = 8)),
            pratique("BilanTropheesTest : un jour à 0 min", Ecrite(d0, parJour = listOf(0), meilleureSerie = 1)),
            pratique("TropheesTikkunTest : le Tikoun seul", Ecrite(tikkun, tikkun = listOf(0, 1, 2, 5, 6, 9))),
            pratique("TropheesTikkunTest : sans Tikoun", Ecrite(tikkun, parJour = listOf(20), meilleureSerie = 1)),
        )
        val choisies = listOf(
            pratique("des notes seules", Ecrite(dim, notes = 25)),
            pratique("une série sans jours", Ecrite(dim, meilleureSerie = 18)),
            pratique("une série négative", Ecrite(dim, parJour = listOf(10), meilleureSerie = -3)),
            pratique("des minutes négatives", Ecrite(dim, parJour = listOf(-30, null, -5, 0), meilleureSerie = 1)),
            pratique("les heures débordent", Ecrite(dim, parJour = listOf(2_000_000_000, 2_000_000_000, 30), meilleureSerie = 3)),
            pratique("les heures au bord", Ecrite(dim, parJour = listOf(MAX), meilleureSerie = 1), completes = false),
            pratique("tout ou presque", Ecrite(dim, plages = listOf(listOf(0, 300, 1, 45)), notes = 149, meilleureSerie = 99,
                tikkun = (0 until 199).toList()), completes = false),
        )
        val hasard = Random(1115)
        val tirees = (1..14).map { rang ->
            val n = hasard.nextInt(0, 120)
            val e = Ecrite(dim, parJour = (0 until n).map { if (hasard.nextInt(100) < 70) hasard.nextInt(0, 200) else null },
                notes = hasard.nextInt(0, 160), meilleureSerie = hasard.nextInt(0, 110),
                tikkun = (0 until hasard.nextInt(0, 60)).filter { hasard.nextInt(100) < 70 })
            pratique("tirée $rang", e, completes = false)
        }
        return duTest + choisies + tirees
    }

    // --- Des historiques : les jours des notes et les jours exemptés en plus, la date de chaque gain ----------

    private fun historique(nom: String, e: Ecrite, jourNotes: List<Int> = emptyList(), samedis: Boolean = false,
                           exemptes: List<Int> = emptyList(), completes: Boolean = false, datesDesBilans: Boolean = true,
                           bilans: List<Int>? = null): Map<String, Any?> {
        val minutes = e.minutes()
        val notes = jourNotes.map { e.debut.plusDays(it.toLong()) }.toSet()
        val tikkun = e.joursTikkun()
        val exemptSet = exemptes.map { e.debut.plusDays(it.toLong()) }.toSet()
        val exempt = { d: LocalDate -> d in exemptSet || (samedis && d.dayOfWeek == DayOfWeek.SATURDAY) }
        var demandes = 0
        val dates = Trophees.datesGain(minutes, notes, tikkun) { d -> demandes++; exempt(d) }
        val serie = Plaque.meilleureSerie(minutes.keys, exempt)
        val p = Trophees.Pratique(minutes, notes.size, serie, tikkun)
        fun decalage(d: LocalDate) = (d.toEpochDay() - e.debut.toEpochDay()).toInt()
        val dernier = (minutes.keys + notes + tikkun).maxOrNull()?.let { decalage(it) } ?: 0
        val vus = bilans ?: (listOf(0, 7, 8, 14) + listOf(3, 6, 9).map { it * dernier / 10 } +
            listOf(dernier + 1, dernier + 8, dernier + 30)).distinct()
        val datesBilan = if (datesDesBilans) dates else emptyMap()
        return linkedMapOf<String, Any?>(
            "nom" to nom,
            "pratique" to e.json(),
            "jourNotes" to jourNotes,
            "samedis" to samedis,
            "exemptes" to exemptes,
            "meilleureSerie" to serie,
        ) + analyse(p, completes) + linkedMapOf(
            // La date de gain de chaque étape du chemin, en décalage depuis « debut » ; null : pas gagnée.
            "dates" to Trophees.chemin.map { n -> dates[n.cle]?.let { decalage(it) } },
            "demandes" to demandes,
            "datesDesBilans" to datesDesBilans,
            // [aujourd'hui, null] ou [aujourd'hui, début, minutes, jours, précédente, écart, record, trophées], en décalages.
            "bilans" to vus.map { a ->
                val b = BilanSemaine.precedente(e.debut.plusDays(a.toLong()), minutes, datesBilan)
                if (b == null) listOf(a, null)
                else listOf(a, decalage(b.debut), b.minutes, b.jours, b.precedente, b.ecart, b.record, b.trophees.map { it.cle })
            },
        )
    }

    private fun historiques(): List<Map<String, Any?>> {
        val d0 = LocalDate.of(2026, 9, 6)
        val tikkun = LocalDate.of(2026, 11, 1)
        // BilanTropheesTest : 400 jours depuis le 1/03/2025, samedis exemptés, une pause du 121ᵉ au 131ᵉ jour.
        val mars = LocalDate.of(2025, 3, 1)
        val rejeu = (0 until 400).map { i ->
            val d = mars.plusDays(i.toLong())
            if (d.dayOfWeek != DayOfWeek.SATURDAY && (i * 37) % 11 != 3 && i !in 121..131) 5 + (i * 13) % 70 else null
        }
        val duTest = listOf(
            historique("BilanTropheesTest : 10 jours", Ecrite(d0, plages = listOf(listOf(0, 10, 1, 15))), completes = true),
            historique("BilanTropheesTest : les notes datent la plume", Ecrite(d0, plages = listOf(listOf(0, 2, 1, 15))),
                jourNotes = listOf(5), completes = true),
            historique("BilanTropheesTest : deux semaines", Ecrite(d0, plages = listOf(listOf(-7, 3, 1, 20), listOf(0, 4, 1, 30))),
                completes = true, bilans = listOf(8, 7, 0, 14, 15)),
            historique("BilanTropheesTest : une semaine vide", Ecrite(d0, plages = listOf(listOf(0, 3, 1, 15))),
                datesDesBilans = false, bilans = listOf(30, 7, 8, 0, 6)),
            historique("BilanTropheesTest : le rejeu incrémental", Ecrite(mars, parJour = rejeu),
                jourNotes = (0 until 400).filter { it % 9 == 0 }, samedis = true, completes = true),
            historique("BilanTropheesTest : un jour à 0 min", Ecrite(d0, parJour = listOf(0)), completes = true),
            historique("TropheesTikkunTest : le journal du Tikoun", Ecrite(tikkun, tikkun = listOf(0, 1, 2)), completes = true),
        )
        // Tous les niveaux : un bloc de 110 jours, puis dix de 55 après neuf jours sans ; 150 notes ; 200 jours de Tikoun.
        val tout = Ecrite(LocalDate.of(2024, 1, 7), plages = listOf(listOf(0, 110, 1, 200)) + (0 until 10).map { listOf(119 + 64 * it, 55, 1, 200) },
            plagesTikkun = listOf(listOf(3, 200, 1)))
        val choisis = listOf(
            historique("rien", Ecrite(d0), completes = true),
            historique("seulement des notes", Ecrite(d0), jourNotes = listOf(0, 3, 4, 30)),
            historique("seulement le Tikoun", Ecrite(d0, tikkun = listOf(0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 40))),
            historique("des minutes négatives", Ecrite(d0, parJour = listOf(-20, -5, null, -1, 0, -300))),
            historique("les heures débordent", Ecrite(d0, parJour = listOf(2_000_000_000, 2_000_000_000, 10, 20))),
            historique("des jours exemptés", Ecrite(d0, parJour = listOf(10, null, null, 10, null, 10, 10)), exemptes = listOf(1, 2, 4)),
            historique("un exempté de trop", Ecrite(d0, parJour = listOf(10, null, null, 10, null, 10, 10)), exemptes = listOf(1, 4)),
            historique("des notes avant la pratique", Ecrite(d0, plages = listOf(listOf(20, 5, 1, 30))), jourNotes = listOf(-3, 0, 2, 22)),
            historique("un an chaque jour", Ecrite(LocalDate.of(2025, 1, 1), plages = listOf(listOf(0, 365, 1, 15))),
                jourNotes = (0 until 365).filter { it % 7 == 3 }),
            historique("tous les niveaux", tout, jourNotes = (0 until 150).toList(), completes = true),
        )
        val hasard = Random(1114)
        val tires = (1..24).map { rang ->
            val debut = LocalDate.of(2026, 1, 1).plusDays(hasard.nextInt(-1500, 1500).toLong())
            val n = hasard.nextInt(1, 240)
            val densite = hasard.nextInt(20, 100)
            val pause = if (hasard.nextInt(3) == 0) hasard.nextInt(0, n) else -1
            val longueurPause = hasard.nextInt(8, 25)
            val parJour = (0 until n).map { i ->
                if (i in pause until pause + longueurPause || hasard.nextInt(100) >= densite) null
                else {
                    val t = hasard.nextInt(100)
                    when {
                        t < 2 -> -hasard.nextInt(1, 30)
                        t < 7 -> 0
                        t < 10 -> hasard.nextInt(90, 200)
                        else -> hasard.nextInt(1, 90)
                    }
                }
            }
            val densiteNotes = hasard.nextInt(0, 40)
            val jourNotes = (-5 until n + 5).filter { hasard.nextInt(100) < densiteNotes }
            val densiteTikkun = hasard.nextInt(0, 80)
            val tikkunJours = (0 until n).filter { hasard.nextInt(100) < densiteTikkun }
            val exemptes = (0 until n).filter { hasard.nextInt(100) < 10 }
            historique("tiré $rang", Ecrite(debut, parJour = parJour, tikkun = tikkunJours), jourNotes = jourNotes,
                samedis = hasard.nextBoolean(), exemptes = exemptes)
        }
        return duTest + choisis + tires
    }
}
