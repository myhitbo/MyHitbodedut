// Le centre des anneaux devant la JVM : ce que répond Plaque.kt pour l'ordre des faces, la face de chaque
// anneau, la moyenne d'un jour de pratique (arrondie en simple précision) et la meilleure série, où un jour
// exempté ne compte pas et ne casse pas. D'abord les cas de PlaqueTest, puis un balayage : demis, bornes
// des entiers, flottants qui perdent l'unité, séries à cheval sur un mois, une année bissextile ou un
// siècle, jours faits et exemptés à la fois, semaines aux samedis exemptés, bandes tirées d'une graine fixe.

import com.myhitbodedut.Anneaux
import com.myhitbodedut.Plaque
import java.time.DayOfWeek
import java.time.LocalDate
import kotlin.random.Random

object VecteursPlaque : Generateur {
    override val fichier = "plaque.json"

    private const val MAX = Int.MAX_VALUE
    private const val MIN = Int.MIN_VALUE

    /** Le lundi de PlaqueTest. */
    private val lundi = LocalDate.of(2026, 9, 28)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursPlaque.kt"),
        "retourMs" to Plaque.RETOUR_MS,
        "faces" to Plaque.Face.entries.map { f ->
            linkedMapOf("nom" to f.name, "rang" to f.ordinal, "anneau" to f.anneau?.name, "suivante" to Plaque.suivante(f).name)
        },
        "pour" to Anneaux.Quel.entries.map { q -> linkedMapOf("quel" to q.name, "face" to Plaque.pour(q).name) },
        // Deux tours de plaque depuis le hassid, un toucher après l'autre.
        "tour" to tour(),
        "moyennes" to moyennes(),
        "series" to series(),
    )

    private fun tour(): List<String> {
        var face = Plaque.Face.HASSID
        return (1..2 * Plaque.Face.entries.size).map {
            face = Plaque.suivante(face)
            face.name
        }
    }

    // --- La moyenne d'un jour de pratique --------------------------------------------------------------
    // [total des minutes, jours, moyenne] : Math.round d'un quotient en simple précision, demis vers +∞.

    private fun moyennes(): List<List<Int>> {
        val duTest = listOf(0 to 0, 50 to 3, 200 to 10)
        val totaux = listOf(MIN, MIN + 1, -1000, -101, -100, -51, -50, -7, -5, -3, -1, 0, 1, 2, 3, 5, 7, 10, 21, 49, 50,
            51, 99, 100, 101, 200, 999, 1000, 16_777_215, 16_777_216, 16_777_217, 16_777_218, 16_777_219, 33_554_435,
            100_000_007, MAX - 1, MAX)
        val jours = listOf(MIN, -2, -1, 0, 1, 2, 3, 4, 6, 7, 10, 14, 30, 365, 1000, 16_777_217, MAX)
        return (duTest + totaux.flatMap { t -> jours.map { j -> t to j } }).distinct()
            .map { (t, j) -> listOf(t, j, Plaque.moyenne(t, j)) }
    }

    // --- La meilleure série --------------------------------------------------------------------------
    // Un cas : les jours faits, les jours exemptés (et, si « samedis », chaque samedi), la meilleure série,
    // et combien de fois, sur quels jours, la règle a demandé si un jour était exempté : seulement pour un
    // jour non fait entre le premier et le dernier jour fait.

    private fun serie(nom: String, faits: Set<LocalDate>, exemptes: Set<LocalDate> = emptySet(), samedis: Boolean = false): Map<String, Any?> {
        val demandes = mutableListOf<LocalDate>()
        val meilleure = Plaque.meilleureSerie(faits) { jour ->
            demandes += jour
            jour in exemptes || (samedis && jour.dayOfWeek == DayOfWeek.SATURDAY)
        }
        return linkedMapOf(
            "nom" to nom,
            "faits" to faits.sorted().map { it.toString() },
            "exemptes" to exemptes.sorted().map { it.toString() },
            "samedis" to samedis,
            "meilleure" to meilleure,
            "demandes" to demandes.size,
            "premiereDemande" to demandes.firstOrNull()?.toString(),
            "derniereDemande" to demandes.lastOrNull()?.toString(),
        )
    }

    private fun jours(debut: LocalDate, vararg decalages: Int): Set<LocalDate> = decalages.map { debut.plusDays(it.toLong()) }.toSet()

    private fun suite(debut: String, fin: String): Set<LocalDate> = suite(LocalDate.parse(debut), LocalDate.parse(fin))

    private fun suite(debut: LocalDate, fin: LocalDate): Set<LocalDate> =
        generateSequence(debut) { it.plusDays(1) }.takeWhile { !it.isAfter(fin) }.toSet()

    private fun series(): List<Map<String, Any?>> {
        // PlaqueTest : lundi à mercredi faits, jeudi exempté, vendredi fait, samedi manqué, dimanche fait.
        val faitsDuTest = jours(lundi, 0, 1, 2, 4, 6)
        val jeudi = lundi.plusDays(3)
        val duTest = listOf(
            serie("test : jeudi exempté", faitsDuTest, setOf(jeudi)),
            serie("test : rien d'exempté", faitsDuTest),
            serie("test : aucun jour fait", emptySet()),
            serie("test : un seul jour", setOf(lundi)),
        )
        val choisies = listOf(
            serie("un jour exempté seul", setOf(lundi), setOf(lundi)),
            serie("tout exempté, rien de fait", emptySet(), suite("2026-01-01", "2026-01-31")),
            serie("deux jours loin l'un de l'autre", setOf(LocalDate.of(2026, 1, 1), LocalDate.of(2026, 12, 31))),
            serie("deux jours, tout exempté entre", setOf(LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 10)),
                suite("2026-01-02", "2026-01-09")),
            serie("faits et exemptés à la fois", suite("2026-03-01", "2026-03-10"), suite("2026-03-03", "2026-03-06")),
            serie("un trou au milieu", suite("2026-03-01", "2026-03-10") - LocalDate.of(2026, 3, 5)),
            serie("un trou exempté au milieu", suite("2026-03-01", "2026-03-10") - LocalDate.of(2026, 3, 5),
                setOf(LocalDate.of(2026, 3, 5))),
            serie("la plus longue en premier", suite("2026-03-01", "2026-03-08") + suite("2026-03-10", "2026-03-12")),
            serie("la plus longue en dernier", suite("2026-03-01", "2026-03-03") + suite("2026-03-05", "2026-03-12")),
            serie("deux suites égales", suite("2026-03-01", "2026-03-04") + suite("2026-03-06", "2026-03-09")),
            serie("le 29 février", suite("2024-02-26", "2024-03-03")),
            serie("février de 2100, sans 29", suite("2100-02-25", "2100-03-03")),
            serie("février de 2000, avec 29", suite("2000-02-26", "2000-03-02")),
            serie("au passage d'un siècle", suite("1899-12-28", "1900-01-03") - LocalDate.of(1900, 1, 1),
                setOf(LocalDate.of(1900, 1, 1))),
            serie("au passage de l'an 2000", suite("1999-12-25", "2000-01-05") - LocalDate.of(1999, 12, 31)),
            serie("autour de l'an zéro", suite(LocalDate.of(-1, 12, 29), LocalDate.of(0, 1, 3)) - LocalDate.of(0, 1, 1),
                setOf(LocalDate.of(0, 1, 1))),
            serie("trois semaines sans samedi", suite("2026-09-27", "2026-10-17").filter { it.dayOfWeek != DayOfWeek.SATURDAY }.toSet(),
                samedis = true),
            serie("trois semaines sans samedi, samedis comptés", suite("2026-09-27", "2026-10-17")
                .filter { it.dayOfWeek != DayOfWeek.SATURDAY }.toSet()),
            serie("du lundi au vendredi, samedis exemptés", suite("2026-09-28", "2026-10-23")
                .filter { it.dayOfWeek != DayOfWeek.SATURDAY && it.dayOfWeek != DayOfWeek.SUNDAY }.toSet(), samedis = true),
            serie("une année entière", suite("2026-01-01", "2026-12-31")),
            serie("une année, un jour sur deux exempté", suite("2025-01-01", "2025-12-31").filterIndexed { i, _ -> i % 2 == 0 }.toSet(),
                suite("2025-01-01", "2025-12-31").filterIndexed { i, _ -> i % 2 == 1 }.toSet()),
        )
        // Des bandes tirées d'une graine fixe : chaque jour d'une fenêtre est fait, exempté, les deux, ou rien.
        val hasard = Random(2610)
        val tirees = (1..40).map { rang ->
            val debut = LocalDate.of(2026, 1, 1).plusDays(hasard.nextInt(-800, 800).toLong())
            val longueur = hasard.nextInt(1, 70)
            val faits = mutableSetOf<LocalDate>()
            val exemptes = mutableSetOf<LocalDate>()
            for (i in 0 until longueur) {
                val jour = debut.plusDays(i.toLong())
                if (hasard.nextInt(100) < 62) faits += jour
                if (hasard.nextInt(100) < 18) exemptes += jour
            }
            serie("tirée $rang", faits, exemptes, samedis = hasard.nextBoolean())
        }
        return duTest + choisies + tirees
    }
}
