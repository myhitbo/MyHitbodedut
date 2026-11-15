// MelangeMusique.kt devant la JVM : la suite des morceaux que rend la lecture aléatoire pour une graine
// donnée de kotlin.random.Random, sur les scénarios de MelangeMusiqueTest (douze niggounim, une
// bibliothèque qui rétrécit ou se vide) et d'autres : doublons, un ou deux morceaux, une bibliothèque
// qui grandit en cours de tour, des identifiants hébreux. Chaque appel dit ce qu'il rend et `dernier`.

import com.myhitbodedut.MelangeMusique
import kotlin.random.Random

object VecteursMelangeMusique : Generateur {
    override val fichier = "melange_musique.json"

    private val niggounim = (1..12).map { "niggoun_%02d".format(it) }

    /** Un appel : la bibliothèque passée à `suivant`, autant de fois que dit. */
    private class Appel(val ids: List<String>, val fois: Int)

    private val scenarios: List<Pair<String, List<Appel>>> = listOf(
        "douze" to listOf(Appel(niggounim, 72)),
        "retire" to listOf(Appel(niggounim, 1), Appel(niggounim.drop(6), 20), Appel(emptyList(), 2), Appel(niggounim, 14)),
        "retireEnCours" to listOf(Appel(niggounim, 5), Appel(niggounim.filterIndexed { i, _ -> i % 2 == 0 }, 9),
            Appel(niggounim.take(1), 3), Appel(niggounim, 13)),
        "grandit" to listOf(Appel(niggounim.take(3), 4), Appel(niggounim.take(6), 8), Appel(niggounim, 20)),
        "doublons" to listOf(Appel(listOf("a", "b", "a", "c", "b", "c", "c"), 15)),
        "seul" to listOf(Appel(listOf("seul"), 4), Appel(emptyList(), 1), Appel(listOf("seul"), 2)),
        "deux" to listOf(Appel(listOf("x", "y"), 20)),
        "deuxIdentiques" to listOf(Appel(listOf("x", "x"), 5), Appel(listOf("x", "y", "x"), 8)),
        "trois" to listOf(Appel(listOf("p", "q", "r"), 30)),
        "hebreu" to listOf(Appel(listOf("נִגּוּן", "ניגון", "שִׁיר", "é", "é", "😀"), 24)),
        "remplace" to listOf(Appel(listOf("a", "b", "c", "d"), 2), Appel(listOf("e", "f", "g"), 7), Appel(listOf("a", "b", "c", "d"), 9)),
        "vide" to listOf(Appel(emptyList(), 3)),
    )

    private val graines: List<Int> = listOf(0, 1, 2, 3, 7, 42, -1, 2026, 123_456_789, Int.MAX_VALUE, Int.MIN_VALUE)
    private val grainesLongues: List<Long> = listOf(0L, 1L, -1L, 4_294_967_296L, Long.MAX_VALUE, Long.MIN_VALUE, 1_731_600_000_000L)

    private fun rejoue(melange: MelangeMusique, appels: List<Appel>): List<Map<String, Any?>> = appels.map { appel ->
        val rendus = List(appel.fois) { melange.suivant(appel.ids) }
        linkedMapOf("ids" to appel.ids, "rendus" to rendus, "dernier" to melange.dernier)
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursMelangeMusique.kt"),
        // Random(graine) d'un Int, puis Random(graine) d'un Long : chaque scénario repart d'un mélange neuf.
        "graines" to graines.map { graine ->
            linkedMapOf("graine" to graine, "scenarios" to scenarios.map { (nom, appels) ->
                linkedMapOf("nom" to nom, "appels" to rejoue(MelangeMusique(Random(graine)), appels))
            })
        },
        "grainesLongues" to grainesLongues.map { graine ->
            linkedMapOf("graine" to graine.toString(), "scenarios" to scenarios.filter { it.first in setOf("douze", "retire", "doublons", "deux") }
                .map { (nom, appels) -> linkedMapOf("nom" to nom, "appels" to rejoue(MelangeMusique(Random(graine)), appels)) })
        },
        // MelangeMusiqueTest : « jamais deux fois de suite » sur cinquante graines, six tours de douze.
        "cinquante" to (1..50).map { graine ->
            val melange = MelangeMusique(Random(graine))
            linkedMapOf("graine" to graine, "suite" to List(niggounim.size * 6) { niggounim.indexOf(melange.suivant(niggounim)!!) })
        },
    )
}
