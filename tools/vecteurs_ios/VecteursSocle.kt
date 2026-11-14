// Le socle de Coeur devant la JVM : ce que rendent Java et Kotlin pour les quelques opérations dont
// la sémantique ne va pas de soi en Swift (hashCode, hasard de Kotlin, modulo, arrondi, chaînes
// comptées en unités UTF-16, blancs de Kotlin).

import kotlin.math.roundToInt
import kotlin.math.roundToLong
import kotlin.random.Random

object VecteursSocle : Generateur {
    override val fichier = "socle.json"

    private val textes = listOf(
        "", "a", "abc", "Hitbodedout", "trophee_serie_7", "éàç", "שלום", "בְּרֵאשִׁית", "מָה־אָשִׁיב", "ה׳ בכסלו",
        "😀", "a😀b", " x ", " \t x \n", "  ", "İstanbul", "ǅ", "ß", "ΌΣΟΣ", "é", "é",
    )

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursSocle.kt", "moteur" to "JVM, Kotlin ${KotlinVersion.CURRENT}"),
        "chaines" to textes.map { s ->
            linkedMapOf(
                "s" to s, "hash" to s.hashCode(), "longueur" to s.length,
                "blanc" to s.isBlank(), "rogne" to s.trim(),
                "minuscules" to s.lowercase(), "majuscules" to s.uppercase(),
                "prend2" to s.take(2).map { it.code }, "retire2" to s.drop(2).map { it.code },
            )
        },
        "hasard" to listOf(0, 1, 7, 42, -1, 2026, "pluie".hashCode(), Int.MAX_VALUE, Int.MIN_VALUE).map { graine ->
            val r = Random(graine)
            linkedMapOf(
                "graine" to graine,
                "entiers" to List(6) { r.nextInt() },
                "bornes" to listOf(1, 2, 3, 4, 10, 100, 1000, 65536, 1_000_000).map { r.nextInt(it) },
                "intervalles" to listOf(0 to 10, -5 to 5, 100 to 101, 3 to 1000).map { (a, b) -> r.nextInt(a, b) },
                "longs" to List(3) { r.nextLong().toString() },
                "flottants" to List(4) { r.nextFloat().toDouble() },
                "doubles" to List(4) { r.nextDouble() },
                "booleens" to List(8) { r.nextBoolean() },
                "melange" to (0 until 12).toList().shuffled(Random(graine)),
                "melangeCourt" to listOf("a", "b", "c").shuffled(Random(graine)),
                "tirage" to List(5) { listOf("a", "b", "c", "d", "e").random(r) },
            )
        },
        "modulo" to listOf(7 to 3, -7 to 3, 7 to -3, -7 to -3, 0 to 5, -1 to 7, 14 to 7, -14 to 7, 1_000_000_007 to 13).map { (a, b) ->
            linkedMapOf("a" to a, "b" to b, "reste" to a % b, "quotient" to a / b,
                "floorMod" to Math.floorMod(a, b), "floorDiv" to Math.floorDiv(a, b), "mod" to a.mod(b))
        },
        "arrondis" to listOf(0.0, 0.5, 1.5, 2.5, -0.5, -1.5, -2.5, 0.49999999999999994, 2.4999, -2.5001, 1e9 + 0.5, -0.0, 3.14159, 1234.5).map { x ->
            linkedMapOf("x" to x, "roundToInt" to x.roundToInt(), "roundToLong" to x.roundToLong().toString(),
                "mathRound" to Math.round(x).toString(), "mathRoundFloat" to Math.round(x.toFloat()),
                "rint" to Math.rint(x), "versInt" to x.toInt(), "f1" to "%.1f".format(java.util.Locale.ROOT, x),
                "f2" to "%.2f".format(java.util.Locale.ROOT, x))
        },
        "formats" to listOf(0, 5, 9, 10, 59, 60, 61, 125, 600, 1439).map { m ->
            linkedMapOf("m" to m, "hhmm" to String.format(java.util.Locale.US, "%02d:%02d", (m / 60) % 24, m % 60),
                "hmm" to String.format(java.util.Locale.ROOT, "%d:%02d", m / 60, m % 60))
        },
    )
}
