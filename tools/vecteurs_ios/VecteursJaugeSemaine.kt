// La jauge de la semaine devant la JVM : ce que répond JaugeSemaine.kt pour les jours faits sur les jours
// dus d'une bande (les WeekDay de Store.kt), la fraction de la jauge en simple précision (zéro négatif
// compris), et la durée courte d'un jour fait (DureeCourteTest). D'abord les cas des tests d'Android,
// puis un balayage : bande vide, plus courte ou plus longue que sept jours, chaque combinaison de trois
// cases, des semaines variées, bornes des entiers.

import com.myhitbodedut.JaugeSemaine
import com.myhitbodedut.WeekDay
import java.time.LocalDate

object VecteursJaugeSemaine : Generateur {
    override val fichier = "jauge_semaine.json"

    private const val MAX = Int.MAX_VALUE
    private const val MIN = Int.MIN_VALUE

    /** Le dimanche de JaugeSemaineTest. */
    private val dimanche = LocalDate.of(2026, 9, 27)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursJaugeSemaine.kt"),
        "semaines" to semaines(),
        "fractions" to fractions(),
        "dureesCourtes" to dureesCourtes(),
        "dureesSuivies" to dureesSuivies(),
    )

    /** Les bits d'un flottant : ils disent aussi le signe d'un zéro. */
    private fun bits(f: Float): Int = java.lang.Float.floatToRawIntBits(f)

    // --- La progression d'une bande ----------------------------------------------------------------
    // Une case s'écrit comme dans JaugeSemaineTest : « f » faite, « x » exemptée, « a » à venir, et « s »
    // pour le Chabbat ; la première case est au jour « debut », chacune un jour après la précédente.

    private fun bande(debut: LocalDate, cases: List<String>): Map<String, Any?> {
        val jours = cases.mapIndexed { i, e ->
            WeekDay(date = debut.plusDays(i.toLong()), done = 'f' in e, exempt = 'x' in e, shabbat = 's' in e, future = 'a' in e)
        }
        val p = JaugeSemaine.progression(jours)
        return linkedMapOf(
            "debut" to debut.toString(), "cases" to cases,
            "faits" to p.faits, "dus" to p.dus, "fraction" to p.fraction, "bitsFraction" to bits(p.fraction),
        )
    }

    private fun semaines(): List<Map<String, Any?>> {
        // Les trois semaines de JaugeSemaineTest : le septième jour y est le Chabbat.
        val duTest = listOf(
            listOf("f", "f", "", "a", "a", "a", "xs"),
            listOf("f", "f", "f", "f", "f", "f", "fxs"),
            listOf("x", "x", "x", "x", "x", "x", "xs"),
        ).map { bande(dimanche, it) }
        // Chaque bande de zéro à trois cases, chaque case faite ou non, exemptée ou non.
        val etats = listOf("", "f", "x", "fx")
        val courtes = (0..3).flatMap { n ->
            (0 until (1 shl (2 * n))).map { code -> (0 until n).map { i -> etats[(code shr (2 * i)) and 3] } }
        }.map { bande(dimanche, it) }
        // Des semaines de sept cases : le code en base 4 dit l'état de chaque jour, les derniers jours sont
        // à venir selon le rang, le septième est le Chabbat.
        val septJours = (0 until 4 * 4 * 4 * 4 * 4 * 4 * 4 step 97).mapIndexed { rang, code ->
            val aVenir = rang % 8
            (0 until 7).map { i ->
                etats[(code shr (2 * i)) and 3] + (if (i >= 7 - aVenir) "a" else "") + (if (i == 6) "s" else "")
            }
        }.mapIndexed { rang, cases -> bande(dimanche.plusDays(7L * (rang % 5) - 14), cases) }
        // Des bandes plus longues qu'une semaine, et des fins de mois et d'année.
        val longues = listOf(
            List(8) { "f" }, List(14) { i -> if (i % 7 == 6) "xs" else "f" }, List(31) { i -> if (i % 3 == 0) "x" else "" },
            List(31) { i -> if (i % 2 == 0) "fx" else "x" }, List(10) { "a" }, List(7) { "s" }, List(7) { "fa" },
        ).mapIndexed { rang, cases -> bande(listOf(dimanche, LocalDate.of(2026, 12, 27), LocalDate.of(2028, 2, 27))[rang % 3], cases) }
        return duTest + courtes + septJours + longues
    }

    // --- La fraction d'une progression ---------------------------------------------------------------
    // Calculée en simple précision puis ramenée entre 0 et 1 par coerceIn, qui garde le zéro négatif
    // (0 sur un nombre de jours dus négatif).

    private fun fractions(): List<Map<String, Any?>> {
        val faits = listOf(MIN, -7, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 100, 16_777_217, MAX)
        val dus = listOf(MIN, -7, -1, 0, 1, 2, 3, 6, 7, 8, 16_777_217, MAX)
        return faits.flatMap { f -> dus.map { d -> f to d } }.map { (f, d) ->
            val p = JaugeSemaine.Progression(faits = f, dus = d)
            linkedMapOf("faits" to f, "dus" to d, "fraction" to p.fraction, "bitsFraction" to bits(p.fraction))
        }
    }

    // --- La durée courte d'un jour fait ------------------------------------------------------------

    /** Les cas de DureeCourteTest, puis les voisins de chaque heure et les bornes des entiers. */
    private fun dureesCourtes() = (listOf(5, 59, 60, 65, 150) + listOf(
        MIN, MIN + 1, -3600, -61, -60, -59, -1, 0, 1, 9, 10, 59, 60, 61, 69, 70, 119, 120, 121, 599, 600, 601,
        1439, 1440, 1441, 5999, 6000, 6001, 59_999, 60_000, 60_001, 1_000_000, MAX - 8, MAX - 7, MAX - 6, MAX - 1, MAX,
    )).distinct().map { m -> linkedMapOf("minutes" to m, "texte" to JaugeSemaine.dureeCourte(m)) }

    /** `textes[i]` : la durée courte de `premier + i` minutes, de −70 à 1 500. */
    private fun dureesSuivies() = linkedMapOf("premier" to -70, "textes" to (-70..1500).map { JaugeSemaine.dureeCourte(it) })
}
