// « Mon parcours » devant la JVM (ParcoursActivity.kt, l'objet Parcours) : le bilan des journées (jours
// faits, minutes sur les 32 bits d'un Int, moyenne arrondie, sujets les plus fréquents) et l'humeur
// moyenne avant et après. ParcoursActivity.kt est un écran, que l'oracle ne compile pas : l'objet
// Parcours est recopié ici, et la recopie est comparée, ligne de code par ligne de code, à celle du
// fichier d'Android avant de produire quoi que ce soit (le générateur s'arrête si Android a bougé). Ce
// qu'elle appelle est le vrai code de l'app : DayRecord.faite, ThemeRules.frequents, JournalPlus.Plus.
// ParcoursTests de Coeur rejoue ces cas sur Parcours.swift.
//
// D'abord les cas de ParcoursTest et du site (web/test), puis les bornes (demis négatifs, sommes qui
// débordent, clés de sujets inconnues ou presque justes, sujets des notes seules, plafond de cinq), puis
// un balayage tiré d'une graine fixe.

import com.myhitbodedut.DayRecord
import com.myhitbodedut.JournalPlus
import com.myhitbodedut.Theme
import com.myhitbodedut.ThemeRules
import java.io.File
import kotlin.random.Random

object VecteursParcours : Generateur {
    override val fichier = "parcours.json"

    /** La recopie de l'objet Parcours de ParcoursActivity.kt, sans ses commentaires. */
    private object Recopie {
        data class Bilan(val jours: Int, val minutes: Int, val sujets: List<Pair<Theme, Int>>) {
            val moyenne: Int get() = if (jours == 0) 0 else Math.round(minutes.toDouble() / jours).toInt()
        }

        fun bilan(jours: Collection<DayRecord>): Bilan {
            val faits = jours.filter { it.faite }
            return Bilan(faits.size, faits.sumOf { it.minutes }, ThemeRules.frequents(jours.flatMap { it.themes }, max = 5))
        }

        fun humeur(plus: Collection<JournalPlus.Plus>): Triple<Int, Int, Int>? {
            val notes = plus.filter { it.avant > 0 && it.apres > 0 }
            if (notes.isEmpty()) return null
            return Triple(
                Math.round(notes.map { it.avant }.average()).toInt(),
                Math.round(notes.map { it.apres }.average()).toInt(),
                notes.size,
            )
        }
    }

    /** Les lignes de code de la recopie, dans l'ordre : elles doivent être celles de l'objet d'Android. */
    private val lignesRecopiees = listOf(
        "object Parcours {",
        "data class Bilan(val jours: Int, val minutes: Int, val sujets: List<Pair<Theme, Int>>) {",
        "val moyenne: Int get() = if (jours == 0) 0 else Math.round(minutes.toDouble() / jours).toInt()",
        "}",
        "fun bilan(jours: Collection<DayRecord>): Bilan {",
        "val faits = jours.filter { it.faite }",
        "return Bilan(faits.size, faits.sumOf { it.minutes }, ThemeRules.frequents(jours.flatMap { it.themes }, max = 5))",
        "}",
        "fun humeur(plus: Collection<JournalPlus.Plus>): Triple<Int, Int, Int>? {",
        "val notes = plus.filter { it.avant > 0 && it.apres > 0 }",
        "if (notes.isEmpty()) return null",
        "return Triple(",
        "Math.round(notes.map { it.avant }.average()).toInt(),",
        "Math.round(notes.map { it.apres }.average()).toInt(),",
        "notes.size,",
        ")",
        "}",
        "}",
    )

    /** L'objet Parcours du fichier d'Android, ses lignes de code seules (ni blancs ni commentaires). */
    private fun lignesDAndroid(): List<String> {
        val texte = File(DEPOT, "android/app/src/main/java/com/myhitbodedut/ParcoursActivity.kt").readText()
        val debut = texte.indexOf("object Parcours {")
        check(debut >= 0) { "ParcoursActivity.kt ne déclare plus « object Parcours » : revoir VecteursParcours.kt" }
        val fin = texte.indexOf("\n}\n", debut)
        check(fin > debut) { "fin de l'objet Parcours introuvable" }
        return texte.substring(debut, fin + 2).lines().map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("//") && !it.startsWith("/**") && !it.startsWith("*") }
    }

    private fun jour(i: Int, minutes: Int, themes: List<String>, noteSeule: Boolean = false) =
        DayRecord("2026-10-%02d".format(1 + i % 28), minutes, if (noteSeule) "une note" else "", themes, noteSeule)

    private fun bilan(nom: String, jours: List<DayRecord>): Map<String, Any?> {
        val b = Recopie.bilan(jours)
        return linkedMapOf(
            "nom" to nom,
            // [minutes, note seule, sujets] : la date ne compte pas.
            "jours" to jours.map { listOf(it.minutes, it.noteSeule, it.themes) },
            "faits" to b.jours, "minutes" to b.minutes, "moyenne" to b.moyenne,
            "sujets" to b.sujets.map { (t, n) -> listOf(t.cle, n) },
        )
    }

    private fun humeur(nom: String, plus: List<JournalPlus.Plus>): Map<String, Any?> {
        val h = Recopie.humeur(plus)
        return linkedMapOf(
            "nom" to nom,
            "plus" to plus.map { listOf(it.avant, it.apres) },
            "humeur" to h?.let { listOf(it.first, it.second, it.third) },
        )
    }

    private fun bilans(): List<Map<String, Any?>> {
        val tous = Theme.values().map { it.cle }
        val fixes = listOf(
            "ParcoursTest" to listOf(
                DayRecord("2026-10-01", 20, "", listOf("famille", "parnassa")),
                DayRecord("2026-10-02", 10, "", listOf("famille")),
                DayRecord("2026-10-03", 0, "une note", emptyList(), noteSeule = true),
            ),
            "vide" to emptyList(),
            "notes seules" to listOf(jour(0, 0, listOf("gratitude"), true), jour(1, 15, listOf("gratitude", "avoda"), true)),
            "un jour à zéro minute" to listOf(jour(0, 0, emptyList())),
            "demi qui monte" to listOf(jour(0, 2, emptyList()), jour(1, 3, emptyList())),
            "demi négatif" to listOf(jour(0, -2, emptyList()), jour(1, -1, emptyList())),
            "demi négatif, deux et demi" to listOf(jour(0, -3, emptyList()), jour(1, -2, emptyList())),
            "un tiers" to listOf(jour(0, 1, emptyList()), jour(1, 0, emptyList()), jour(2, 0, emptyList())),
            "deux tiers" to listOf(jour(0, 1, emptyList()), jour(1, 1, emptyList()), jour(2, 0, emptyList())),
            "débordement" to listOf(jour(0, Int.MAX_VALUE, emptyList()), jour(1, 1, emptyList())),
            "débordement, trois jours" to listOf(jour(0, Int.MAX_VALUE, emptyList()), jour(1, Int.MAX_VALUE, emptyList()), jour(2, 5, emptyList())),
            "minimum" to listOf(jour(0, Int.MIN_VALUE, emptyList())),
            "minimum et un" to listOf(jour(0, Int.MIN_VALUE, emptyList()), jour(1, -1, emptyList())),
            "clés presque justes" to listOf(jour(0, 10, listOf("famille", " famille", "famille ", "FAMILLE", "Famille", "", "  ", "x", "famille\u0000"))),
            "tous les sujets, plafond de cinq" to listOf(jour(0, 10, tous), jour(1, 10, tous.drop(3)), jour(2, 10, tous.drop(6))),
            "égalités dans l'ordre des sujets" to listOf(jour(0, 10, tous.reversed())),
            "sujets des notes seules" to listOf(jour(0, 5, listOf("avoda")), jour(1, 0, listOf("croissance", "croissance"), true)),
            "un sujet répété" to listOf(jour(0, 30, List(7) { "zivoug" } + "autre")),
            "sujet hébreu" to listOf(jour(0, 30, listOf("פַּרְנָסָה", "parnassa"))),
        ).map { (nom, jours) -> bilan(nom, jours) }
        val r = Random(20261019)
        val cles = tous + listOf("", " ", "x", "famille ", "Gratitude")
        val minutes = listOf(0, 1, 5, 10, 15, 20, 25, 30, 45, 59, 60, 61, 90, 120, 180, -1, -3)
        val tires = (1..60).map { k ->
            val n = r.nextInt(0, 9)
            val jours = (0 until n).map { i ->
                val seule = r.nextInt(4) == 0
                jour(i, if (seule && r.nextBoolean()) 0 else minutes[r.nextInt(minutes.size)],
                    List(r.nextInt(0, 5)) { cles[r.nextInt(cles.size)] }, seule)
            }
            bilan("tirage $k", jours)
        }
        return fixes + tires
    }

    private fun humeurs(): List<Map<String, Any?>> {
        val p = { avant: Int, apres: Int -> JournalPlus.Plus(avant, apres) }
        val fixes = listOf(
            "ParcoursTest, avant seul" to listOf(JournalPlus.Plus(avant = 2)),
            "ParcoursTest, deux jours notés" to listOf(JournalPlus.Plus(2, 4), JournalPlus.Plus(2, 4), JournalPlus.Plus(apres = 5)),
            "site, demis" to listOf(p(1, 4), p(2, 5)),
            "vide" to emptyList(),
            "rien de noté" to listOf(p(0, 0), p(0, 0)),
            "après seul" to listOf(p(0, 3)),
            "un jour" to listOf(p(3, 5)),
            "un tiers et deux tiers" to listOf(p(1, 1), p(2, 2), p(2, 2)),
            "demis des deux côtés" to listOf(p(4, 1), p(5, 2)),
            "négatifs écartés" to listOf(p(-1, 3), p(3, -2), p(2, 2)),
            "au-delà de cinq" to listOf(p(6, 9), p(7, 1)),
            "grands" to listOf(p(Int.MAX_VALUE, 1), p(Int.MAX_VALUE, 1)),
            "quatre jours" to listOf(p(1, 5), p(2, 5), p(2, 4), p(1, 4)),
        ).map { (nom, plus) -> humeur(nom, plus) }
        val r = Random(20261102)
        val tires = (1..40).map { k ->
            humeur("tirage $k", List(r.nextInt(0, 7)) { p(r.nextInt(-1, 7), r.nextInt(-1, 7)) })
        }
        return fixes + tires
    }

    override fun produire(): Map<String, Any?> {
        val android = lignesDAndroid()
        check(android == lignesRecopiees) {
            "l'objet Parcours de ParcoursActivity.kt n'est plus celui que recopie VecteursParcours.kt :\n" + android.joinToString("\n")
        }
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursParcours.kt"),
            "bilans" to bilans(),
            "humeurs" to humeurs(),
        )
    }
}
