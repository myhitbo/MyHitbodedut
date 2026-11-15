// Paliers, trophées, 'hizouk et règles de texte (tâche 9) devant la JVM : les paliers de chaque piste, des
// historiques tirés au hasard (graine fixe) rendus en trophées gagnés, prochains, proches, nouveaux, dates de
// gain et bilans de la semaine ; les références des données dans les trois langues ; la langue, le
// marque-page, l'aération des paragraphes du siddour, le mélange de la musique et la danse du bravo.

import com.myhitbodedut.Aeration
import com.myhitbodedut.BilanSemaine
import com.myhitbodedut.Celebrations
import com.myhitbodedut.DanseMesure
import com.myhitbodedut.LangueApp
import com.myhitbodedut.LanguesTexte
import com.myhitbodedut.MarquesPages
import com.myhitbodedut.MelangeMusique
import com.myhitbodedut.Paliers
import com.myhitbodedut.Plaque
import com.myhitbodedut.Reference
import com.myhitbodedut.RegleLangue
import com.myhitbodedut.Trophees
import java.io.File
import java.time.LocalDate
import kotlin.random.Random

object VecteursRecompenses : Generateur {
    override val fichier = "recompenses.json"

    private val origine = LocalDate.of(2025, 3, 2) // un dimanche
    private fun j(d: LocalDate) = (d.toEpochDay() - origine.toEpochDay()).toInt()

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursRecompenses.kt", "origine" to origine.toString()),
        // « piste|valeur|objectif du jour » → atteint, prochain, rang, avancée (simple précision).
        "paliers" to Paliers.Piste.entries.flatMap { p ->
            ((-2..40) + (45..1300 step 61) + listOf(61000, 72000, 99999)).flatMap { v ->
                listOf(0, 25).map { o ->
                    val e = Paliers.etat(p, v, o)
                    listOf(p.cle, v, o, e.atteint, e.prochain, e.rang, e.avancee)
                }
            }
        },
        // Des historiques (jours depuis l'origine → minutes), des notes, des Tikoun : ce que les règles en tirent.
        "historiques" to historiques(),
        "references" to references(),
        "lettres" to (-1..1000).map { Reference.lettres(it) },
        "langues" to listOf("fr", "en", "he", "iw", "fr-FR", "en_US", "IW", "de", "", null, "He-IL", "zh-Hant-TW").map { l ->
            listOf(l, RegleLangue.normalise(l), RegleLangue.permises(l ?: "").sorted(), RegleLangue.traduit(l ?: ""),
                LanguesTexte.defaut(l ?: "").cle)
        },
        "replis" to listOf(listOf("es-ES"), listOf("es", "fr-FR"), emptyList(), listOf("iw-IL"), listOf("de", "it"), listOf("EN")).map {
            listOf(it, LangueApp.repli(it))
        },
        "textes" to LanguesTexte.Mode.entries.flatMap { m ->
            listOf(listOf("אחד", "un", "one"), listOf("אחד", null, "one"), listOf("אחד", " ", null), listOf("אחד", null, null)).map { (he, fr, en) ->
                listOf(m.cle, he, fr, en, LanguesTexte.textes(m, he!!, fr, en).map { listOf(it.first, it.second) },
                    LanguesTexte.manque(m, true), LanguesTexte.manque(m, false))
            }
        },
        "aeration" to aeration(),
        "melanges" to (0 until 40).map { graine ->
            val ids = (1..(1 + graine % 13)).map { "m%02d".format(it) }
            val m = MelangeMusique(Random(graine))
            listOf(graine, ids.size, (0 until ids.size * 3).map { m.suivant(ids) })
        },
        "danse" to (-8..408 step 2).map { k ->
            val t = k / 400f
            val p = DanseMesure.pas(t)
            listOf(t, p.hauteur, p.flexion, p.balance, p.poseB)
        },
    )

    private fun historiques(): List<Any?> {
        val r = Random(9)
        val samedi = { d: LocalDate -> d.dayOfWeek == java.time.DayOfWeek.SATURDAY }
        return (0 until 24).map { k ->
            val longueur = listOf(0, 3, 10, 40, 120, 400)[k % 6]
            val minutes = linkedMapOf<LocalDate, Int>()
            val notes = mutableSetOf<LocalDate>()
            val tikkun = mutableSetOf<LocalDate>()
            val trou = r.nextInt(5) + 1
            for (i in 0 until longueur) {
                val d = origine.plusDays(i.toLong())
                if (r.nextInt(trou + 1) != 0 && !(k % 2 == 0 && samedi(d)) && i % 37 !in 20..28) minutes[d] = r.nextInt(90)
                if (r.nextInt(7) == 0) notes += d
                if (r.nextInt(3) == 0) tikkun += d
            }
            val exempt: (LocalDate) -> Boolean = { k % 2 == 0 && samedi(it) }
            val serie = Plaque.meilleureSerie(minutes.keys, exempt)
            val p = Trophees.Pratique(minutes, notes.size, serie, tikkun)
            val gagnes = Trophees.gagnes(p)
            val dates = Trophees.datesGain(minutes, notes, tikkun, exempt)
            val aujourdhui = origine.plusDays((longueur + k % 4).toLong())
            val bilan = Paliers.Bilan(aujourdhui, minutes, serie % 50, aujourdhui.minusDays((k % 29).toLong()), listOf(0, 20, 25)[k % 3])
            val etats = Paliers.etats(bilan)
            val marques = Paliers.marques(etats, bilan)
            val vus = marques.filterIndexed { i, _ -> i % 2 == 0 }.toSet()
            val tropheesVus = gagnes.map { it.cle }.filterIndexed { i, _ -> i % 3 == 0 }.toSet()
            linkedMapOf(
                "minutes" to minutes.entries.map { listOf(j(it.key), it.value) },
                "notes" to notes.map(::j).sorted(),
                "tikkun" to tikkun.map(::j).sorted(),
                "samedi" to (k % 2 == 0),
                "serie" to serie,
                "valeurs" to Trophees.Famille.entries.map { Trophees.valeur(p, it) },
                "progres" to Trophees.Famille.entries.map { listOf(Trophees.progres(p, it).valeur, Trophees.progres(p, it).cible) },
                "gagnes" to gagnes.map { it.cle }.sorted(),
                "prochain" to Trophees.prochain(p)?.cle,
                "proches" to Trophees.plusProches(p).map { it.cle },
                "proche" to Trophees.proche(p)?.cle,
                "nouveaux" to listOf(null, emptySet(), setOf("chai"), tropheesVus).map { v -> Trophees.nouveaux(gagnes, v).map { it.cle } },
                "dates" to dates.entries.sortedBy { it.key }.map { listOf(it.key, j(it.value)) },
                "aujourdhui" to j(aujourdhui),
                "bilan" to listOf(bilan.serie, j(bilan.debutMoisHebreu), bilan.objectifJour),
                "etats" to etats.map { listOf(it.piste.cle, it.valeur, it.atteint, it.prochain, it.rang) },
                "marques" to marques.sorted(),
                "vus" to vus.sorted(),
                "nouveaux_paliers" to Paliers.nouveaux(etats, bilan, vus).map { it.piste.cle },
                "a_la_une" to Paliers.aLaUne(etats).piste.cle,
                "records" to Paliers.records(minutes) { "${it.year}-${it.monthValue}" }.let { listOf(it.jour, it.semaine, it.mois) },
                "semaine" to BilanSemaine.precedente(aujourdhui, minutes, dates)?.let { b ->
                    listOf(j(b.debut), b.minutes, b.jours, b.precedente, b.record, b.trophees.map { it.cle })
                },
            )
        }
    }

    private fun references(): List<Any?> {
        val refs = listOf("raw/chizuk.json", "raw/bibliotheque.json").flatMap { f ->
            Regex(""""ref": "([^"]+)"""").findAll(File(RES, f).readText()).map { it.groupValues[1] }.toList()
        }.distinct() + listOf("Michlé 24:16", "Si'hot HaRan 275", "Tehilim 119 ; Tehilim 150", "Inconnu 12", "")
        return refs.map { listOf(it, Reference.connue(it), Reference.localise(it, "en"), Reference.localise(it, "iw"), Reference.localise(it, "fr")) }
    }

    /**
     * Trente paragraphes du siddour edot (les « t » des blocs), longs ou un court sur dix : la question du
     * psaume, l'aération et l'aperçu d'un marque-page.
     */
    private fun aeration(): List<Any?> {
        val textes = org.json.JSONObject(File(RES, "raw/siddur_edot.json").readText()).getJSONArray("textes")
        val blocs = mutableListOf<String>()
        for (i in 0 until textes.length()) {
            val sections = textes.getJSONObject(i).optJSONArray("sections") ?: continue
            for (k in 0 until sections.length()) {
                val b = sections.getJSONObject(k).optJSONArray("blocs") ?: continue
                for (n in 0 until b.length()) b.optJSONObject(n)?.optString("t", "")?.takeIf { it.isNotEmpty() }?.let { blocs += it }
            }
        }
        val choisis = blocs.filterIndexed { i, t -> t.replace(Regex("<[^>]+>"), "").length > Aeration.LONG || i % 10 == 0 }
        return choisis.take(30).map { t -> listOf(t, Aeration.psaume(t), Aeration.aerer(t), MarquesPages.apercu(t)) }
    }
}
