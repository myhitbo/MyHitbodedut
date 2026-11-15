// Les paliers d'objectifs devant la JVM : ce que répond Paliers.kt pour l'échelle de chaque piste (avec
// l'objectif quotidien), l'état vers le prochain palier (atteint, prochain, rang, reste, avancée en simple
// précision), le bilan d'une pratique (périodes, marques, nouveautés), le palier à la une et les records.
// D'abord les cas de PaliersTest, puis un balayage : valeurs voisines de chaque palier et des pas au-delà
// de l'échelle, zéro, négatifs, objectifs hors échelle, semaines et mois à cheval, sommes qui débordent les
// 32 bits d'un Int, bilans et records tirés d'une graine fixe.

import com.myhitbodedut.Paliers
import com.myhitbodedut.Paliers.Piste
import java.time.LocalDate
import kotlin.random.Random

object VecteursPaliers : Generateur {
    override val fichier = "paliers.json"

    private const val MAX = Int.MAX_VALUE
    private const val MIN = Int.MIN_VALUE

    /** Les bits d'un flottant : ils disent aussi le signe d'un zéro, que sa valeur écrite peut perdre. */
    private fun bits(f: Float): Int = java.lang.Float.floatToRawIntBits(f)

    /** Des objectifs quotidiens : absents, négatifs, dans l'échelle du jour, entre deux paliers, au-delà. */
    private val objectifs = listOf(0, -10, 1, 5, 10, 25, 59, 60, 61, 120, 121, 200, 1000)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursPaliers.kt"),
        // L'échelle de base de chaque piste (rien à couvrir) et son pas au-delà du dernier palier.
        "pistes" to Piste.entries.map { p ->
            linkedMapOf("nom" to p.name, "cle" to p.cle, "base" to base(p), "pas" to pas(p))
        },
        "echelles" to echelles(),
        "etats" to etats(),
        "avancees" to avancees(),
        "bilans" to bilans(),
        "aLaUne" to aLaUne(),
        "aLaUneMain" to aLaUneMain(),
        "records" to records(),
    )

    private fun base(p: Piste): List<Int> = Paliers.echelle(p, -1)

    private fun pas(p: Piste): Int = base(p).last().let { dernier -> Paliers.echelle(p, dernier).last() - dernier }

    // --- L'échelle : [piste, jusqua, objectif du jour, échelle] ------------------------------------------

    private fun echelles(): List<List<Any?>> {
        val duTest = listOf(Triple(Piste.JOUR, 0, 25))
        val balayage = Piste.entries.flatMap { p ->
            val b = base(p)
            val pas = pas(p)
            val jusqua = listOf(-5, -1, 0, 1, b.first() - 1, b.first(), b[b.size / 2], b.last() - 1, b.last(), b.last() + 1,
                b.last() + pas - 1, b.last() + pas, b.last() + pas + 1, b.last() + 3 * pas, 3000).distinct()
            val objs = if (p == Piste.JOUR) objectifs else listOf(0, 25)
            jusqua.flatMap { j -> objs.map { o -> Triple(p, j, o) } }
        }
        return (duTest + balayage).distinct().map { (p, j, o) -> listOf(p.name, j, o, Paliers.echelle(p, j, o)) }
    }

    // --- L'état : [piste, valeur donnée, objectif, valeur, atteint, prochain, rang, reste, bits de l'avancée] ---

    private fun etats(): List<List<Any?>> {
        val duTest = listOf(Triple(Piste.SERIE, 7, 0), Triple(Piste.SERIE, 0, 0), Triple(Piste.SERIE, 400, 0),
            Triple(Piste.CUMUL, 61000, 0), Triple(Piste.JOUR, 21, 25), Triple(Piste.SERIE, 6, 0), Triple(Piste.JOUR, 5, 0))
        val balayage = Piste.entries.flatMap { p ->
            val b = base(p)
            val pas = pas(p)
            val valeurs = (listOf(MIN, -100, -1) + (0..5) + b.flatMap { listOf(it - 1, it, it + 1) } +
                (1..4).flatMap { k -> listOf(b.last() + k * pas - 1, b.last() + k * pas, b.last() + k * pas + 1) } +
                listOf(b.last() + 10 * pas + pas / 2, 100_000)).distinct()
            val objs = if (p == Piste.JOUR) objectifs else listOf(0, 25)
            valeurs.flatMap { v -> objs.map { o -> Triple(p, v, o) } }
        }
        // Le jour, autour de chaque objectif : juste sous, dessus, juste au-dessus.
        val autourDesObjectifs = objectifs.flatMap { o -> (-1..1).map { d -> Triple(Piste.JOUR, o + d, o) } }
        return (duTest + balayage + autourDesObjectifs).distinct().map { (p, v, o) ->
            val e = Paliers.etat(p, v, o)
            listOf(p.name, v, o, e.valeur, e.atteint, e.prochain, e.rang, e.reste, bits(e.avancee))
        }
    }

    // --- Un état bâti à la main : [valeur, prochain, reste, bits de l'avancée] ---------------------------
    // Hors de etat() : prochain nul ou négatif (l'infini, NaN, le zéro négatif), et un reste qui déborde.

    private fun avancees(): List<List<Int>> {
        val valeurs = listOf(MIN, -7, -1, 0, 1, 2, 3, 7, 10, 16_777_217, MAX)
        val prochains = listOf(MIN, -5, -1, 0, 1, 3, 7, 14, 16_777_216, MAX)
        return valeurs.flatMap { v ->
            prochains.map { p ->
                val e = Paliers.Etat(Piste.SERIE, v, 0, p, 0)
                listOf(v, p, e.reste, bits(e.avancee))
            }
        }
    }

    // --- Les bilans --------------------------------------------------------------------------------------
    // Un cas : le bilan donné, puis son début de semaine, des sommes entre deux dates, les six états, le
    // palier à la une, les marques, et les nouveautés pour des « vus » bâtis ainsi : (toutes les marques si
    // « base », rien sinon) moins « retires » plus « ajoutes ».

    private data class Vus(val base: Boolean, val retires: List<String> = emptyList(), val ajoutes: List<String> = emptyList())

    private fun bilan(nom: String, aujourdhui: LocalDate, minutes: Map<LocalDate, Int>, serie: Int, debutMois: LocalDate,
                      objectif: Int, autresVus: List<Vus> = emptyList()): Map<String, Any?> {
        val b = Paliers.Bilan(aujourdhui, minutes, serie, debutMois, objectif)
        val etats = Paliers.etats(b)
        val marques = Paliers.marques(etats, b)
        val variantes = mutableListOf(Vus(false), Vus(true))
        // Tout vu sauf le plus haut palier d'une piste, piste après piste.
        for (e in etats) {
            val plusHaut = marques.filter { it.substringBefore(':') == e.piste.cle }.maxByOrNull { it.substringAfterLast(':').toInt() }
            if (plusHaut != null) variantes += Vus(true, retires = listOf(plusHaut))
        }
        variantes += autresVus
        val avant = minutes.keys.minOrNull() ?: aujourdhui
        val apres = minutes.keys.maxOrNull() ?: aujourdhui
        val bornes = listOf(b.debutSemaine to null, debutMois to null, aujourdhui to null, aujourdhui.plusDays(1) to null,
            avant to null, aujourdhui.minusDays(10) to aujourdhui.minusDays(3), aujourdhui to aujourdhui.minusDays(1),
            avant to apres, apres to apres, b.debutSemaine to b.debutSemaine.plusDays(6))
        return linkedMapOf(
            "nom" to nom,
            "aujourdhui" to aujourdhui.toString(),
            "minutes" to minutes.entries.sortedBy { it.key }.map { listOf(it.key.toString(), it.value) },
            "serie" to serie,
            "debutMoisHebreu" to debutMois.toString(),
            "objectifJour" to objectif,
            "debutSemaine" to b.debutSemaine.toString(),
            // [début, fin (null : aujourd'hui), somme]
            "entre" to bornes.map { (a, z) -> listOf(a.toString(), z?.toString(), if (z == null) b.entre(a) else b.entre(a, z)) },
            // [piste, valeur, atteint, prochain, rang, bits de l'avancée]
            "etats" to etats.map { listOf(it.piste.name, it.valeur, it.atteint, it.prochain, it.rang, bits(it.avancee)) },
            "aLaUne" to Paliers.aLaUne(etats).piste.name,
            "marques" to marques.sorted(),
            "nouveaux" to variantes.map { v ->
                val vus = (if (v.base) marques else emptySet()) - v.retires.toSet() + v.ajoutes
                linkedMapOf("base" to v.base, "retires" to v.retires, "ajoutes" to v.ajoutes,
                    "pistes" to Paliers.nouveaux(etats, b, vus).map { it.piste.name })
            },
        )
    }

    private fun d(texte: String): LocalDate = LocalDate.parse(texte)

    private fun bilans(): List<Map<String, Any?>> {
        // PaliersTest : mercredi 14/10/2026, 3 'Hechvan 5787 ; le mois hébreu a commencé le lundi 12.
        val mercredi = d("2026-10-14")
        val duTest = bilan("test : les périodes repartent", mercredi,
            mapOf(d("2026-10-10") to 20, d("2026-10-12") to 30, d("2026-10-14") to 15), 2, d("2026-10-12"), 20,
            listOf(Vus(false, ajoutes = listOf("jour:2026-10-13:15", "serie:3", "cumul:60")),
                Vus(true, ajoutes = listOf("jour", "chai", "")), Vus(true, retires = listOf("jour:2026-10-14:10", "jour:2026-10-14:15"))))
        val choisis = listOf(
            bilan("rien", mercredi, emptyMap(), 0, d("2026-10-12"), 0),
            bilan("rien, une série", mercredi, emptyMap(), 18, d("2026-10-12"), 30),
            bilan("série négative", mercredi, mapOf(mercredi to 10), -4, d("2026-10-12"), 10),
            bilan("un dimanche", d("2026-10-11"), mapOf(d("2026-10-10") to 40, d("2026-10-11") to 25), 2, d("2026-09-23"), 25),
            bilan("un samedi", d("2026-10-17"), (11..17).associate { d("2026-10-%02d".format(it)) to 30 }, 7, d("2026-10-12"), 30),
            bilan("le mois commence demain", mercredi, mapOf(mercredi to 60, d("2026-10-13") to 45), 2, d("2026-10-15"), 45),
            bilan("des jours à venir", mercredi, mapOf(d("2026-10-15") to 90, d("2026-10-20") to 30, mercredi to 5), 1, d("2026-10-12"), 0),
            bilan("des minutes négatives", mercredi, mapOf(mercredi to -30, d("2026-10-13") to 20, d("2026-10-01") to -5), 1, d("2026-10-12"), 15),
            bilan("des jours à 0 min", mercredi, mapOf(mercredi to 0, d("2026-10-13") to 0, d("2026-10-12") to 0), 3, d("2026-10-12"), 10),
            bilan("l'objectif est un palier", mercredi, mapOf(mercredi to 30), 1, d("2026-10-12"), 30),
            bilan("l'objectif au-delà de l'échelle", mercredi, mapOf(mercredi to 200), 1, d("2026-10-12"), 150),
            bilan("à cheval sur l'année", d("2027-01-01"), (0..20).associate { d("2026-12-12").plusDays(it.toLong()) to 15 + it }, 21,
                d("2026-12-10"), 20),
            bilan("le cumul déborde et revient à 14", mercredi,
                mapOf(d("2026-09-01") to MAX, d("2026-09-02") to MAX, d("2026-09-03") to 4, mercredi to 12), 1, d("2026-10-12"), 10),
            bilan("le cumul déborde en négatif", mercredi,
                mapOf(d("2026-09-01") to 1_500_000_000, d("2026-09-02") to 1_500_000_000, mercredi to 12), 1, d("2026-10-12"), 10),
            bilan("la semaine déborde", mercredi,
                mapOf(d("2026-10-12") to 1_500_000_000, d("2026-10-13") to 1_500_000_000), 2, d("2026-10-12"), 10),
            bilan("beaucoup de pratique", mercredi, (0..199).associate { mercredi.minusDays(it.toLong()) to 30 + it % 50 }, 200,
                d("2026-10-12"), 60),
        )
        val hasard = Random(1110)
        val tires = (1..26).map { rang ->
            val aujourdhui = LocalDate.of(2026, 1, 1).plusDays(hasard.nextInt(-1500, 1500).toLong())
            val minutes = mutableMapOf<LocalDate, Int>()
            for (i in -45..6) {
                if (hasard.nextInt(100) < 55) {
                    val tirage = hasard.nextInt(100)
                    minutes[aujourdhui.plusDays(i.toLong())] = when {
                        tirage < 5 -> -hasard.nextInt(1, 50)
                        tirage < 12 -> 0
                        else -> hasard.nextInt(1, 130)
                    }
                }
            }
            val serie = if (hasard.nextInt(10) == 0) -hasard.nextInt(1, 10) else hasard.nextInt(0, 400)
            val debutMois = aujourdhui.minusDays(hasard.nextInt(-3, 30).toLong())
            bilan("tiré $rang", aujourdhui, minutes, serie, debutMois, objectifs[hasard.nextInt(objectifs.size)])
        }
        return listOf(duTest) + choisis + tires
    }

    // --- Le palier à la une : {états [piste, valeur, objectif], rang de celui qui est rendu, null si Kotlin lève} ---

    private fun aLaUne(): List<Map<String, Any?>> {
        val cas = mutableListOf(
            listOf(Triple(Piste.SERIE, 6, 0), Triple(Piste.JOUR, 5, 0)),
            listOf(Triple(Piste.JOUR, 5, 0), Triple(Piste.SEMAINE, 15, 0)),
            listOf(Triple(Piste.SEMAINE, 15, 0), Triple(Piste.JOUR, 5, 0)),
            listOf(Triple(Piste.CUMUL, 59, 0), Triple(Piste.JOUR, 1, 0)),
            listOf(Triple(Piste.CUMUL, 59, 0), Triple(Piste.JOURS, 0, 0)),
            listOf(Triple(Piste.JOUR, 0, 0), Triple(Piste.SERIE, 0, 0), Triple(Piste.MOIS, 0, 0)),
            listOf(Triple(Piste.MOIS, 0, 0), Triple(Piste.JOUR, 0, 0)),
            listOf(Triple(Piste.JOUR, 7, 0), Triple(Piste.JOUR, 8, 0), Triple(Piste.JOUR, 7, 0)),
            listOf(Triple(Piste.JOUR, 21, 25), Triple(Piste.SERIE, 2, 0)),
            emptyList(),
        )
        val hasard = Random(1111)
        repeat(30) {
            cas += (1..hasard.nextInt(1, 9)).map {
                val p = Piste.entries[hasard.nextInt(Piste.entries.size)]
                Triple(p, hasard.nextInt(-5, 700), objectifs[hasard.nextInt(objectifs.size)])
            }
        }
        return cas.map { liste ->
            val etats = liste.map { (p, v, o) -> Paliers.etat(p, v, o) }
            val une = try { Paliers.aLaUne(etats) } catch (e: NullPointerException) { null }
            linkedMapOf("etats" to liste.map { (p, v, o) -> listOf(p.name, v, o) },
                "indice" to une?.let { u -> etats.indexOfFirst { it === u } })
        }
    }

    // --- Le palier à la une parmi des états bâtis à la main : {états [piste, valeur, prochain], rang rendu} ---
    // L'avancée y peut être NaN (0 sur 0) ou un zéro négatif (0 sur -5) : maxByOrNull compare les Float
    // par compareTo, où NaN dépasse tout et -0,0 passe sous 0,0.

    private fun aLaUneMain(): List<Map<String, Any?>> {
        val cas = listOf(
            listOf(Triple(Piste.JOUR, 0, 0), Triple(Piste.SERIE, 1, 2)),
            listOf(Triple(Piste.SERIE, 1, 2), Triple(Piste.JOUR, 0, 0)),
            listOf(Triple(Piste.SERIE, 5, 0), Triple(Piste.JOUR, 0, 0)),
            listOf(Triple(Piste.JOUR, 0, -5), Triple(Piste.SERIE, 0, 5)),
            listOf(Triple(Piste.SERIE, 0, 5), Triple(Piste.JOUR, 0, -5)),
            listOf(Triple(Piste.JOUR, 0, -5), Triple(Piste.SEMAINE, 0, -3)),
            listOf(Triple(Piste.MOIS, -3, 5), Triple(Piste.JOUR, 0, -5)),
            listOf(Triple(Piste.MOIS, 9, 5), Triple(Piste.JOUR, 0, 0), Triple(Piste.SERIE, 7, 0)),
            listOf(Triple(Piste.CUMUL, 0, 0), Triple(Piste.SERIE, -1, 5)),
            listOf(Triple(Piste.SEMAINE, 3, 6), Triple(Piste.JOUR, 6, 12), Triple(Piste.SERIE, 2, 4)),
        )
        return cas.map { liste ->
            val etats = liste.map { (p, v, prochain) -> Paliers.Etat(p, v, 0, prochain, 0) }
            val une = try { Paliers.aLaUne(etats) } catch (e: NullPointerException) { null }
            linkedMapOf("etats" to liste.map { (p, v, prochain) -> listOf(p.name, v, prochain) },
                "indice" to une?.let { u -> etats.indexOfFirst { it === u } })
        }
    }

    // --- Les records : {minutes, coupures, [jour, semaine, mois]} --------------------------------------------
    // Le mois d'un jour : combien de « coupures » (débuts de mois) sont à ce jour ou avant.

    private fun records(): List<Map<String, Any?>> {
        val cas = mutableListOf(
            mapOf(d("2026-10-04") to 30, d("2026-10-05") to 40, d("2026-10-12") to 20) to listOf(d("2026-10-12")),
            emptyMap<LocalDate, Int>() to emptyList(),
            mapOf(d("2026-10-04") to -30, d("2026-10-05") to -40) to emptyList(),
            mapOf(d("2026-10-03") to 30, d("2026-10-04") to 40) to listOf(d("2026-10-04")),
            mapOf(d("2026-10-05") to MAX, d("2026-10-06") to MAX, d("2026-10-12") to 5) to emptyList(),
            mapOf(d("2026-10-05") to 1_500_000_000, d("2026-10-06") to 1_500_000_000) to listOf(d("2026-10-06")),
            mapOf(d("2026-12-27") to 10, d("2027-01-02") to 20, d("2027-01-03") to 25) to listOf(d("2027-01-01")),
        )
        val hasard = Random(1112)
        repeat(25) {
            val debut = LocalDate.of(2026, 1, 1).plusDays(hasard.nextInt(-1000, 1000).toLong())
            val minutes = (1..hasard.nextInt(1, 60)).associate { debut.plusDays(hasard.nextInt(0, 120).toLong()) to hasard.nextInt(-10, 150) }
            val coupures = (0 until hasard.nextInt(0, 5)).map { debut.plusDays(hasard.nextInt(0, 120).toLong()) }.sorted()
            cas += minutes to coupures
        }
        return cas.map { (minutes, coupures) ->
            val r = Paliers.records(minutes) { jour -> "m" + coupures.count { !jour.isBefore(it) } }
            linkedMapOf("minutes" to minutes.entries.sortedBy { it.key }.map { listOf(it.key.toString(), it.value) },
                "coupures" to coupures.map { it.toString() }, "records" to listOf(r.jour, r.semaine, r.mois))
        }
    }
}
