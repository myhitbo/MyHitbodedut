// Tehilim.kt devant la JVM : le livre lu par TehilimLoader (une empreinte par verset, pas le texte),
// les versets d'une portion, les deux cycles de CycleTehilim, et le jour du mois hébreu que rend
// KosherJava, jour après jour sur l'année 5787 et à chaque borne de mois de 2025 à 2030.

import com.myhitbodedut.CycleTehilim
import com.myhitbodedut.Portion
import com.myhitbodedut.Tehilim
import com.myhitbodedut.TehilimLoader
import java.io.File
import java.time.DayOfWeek
import java.time.LocalDate

object VecteursTehilim : Generateur {
    override val fichier = "tehilim.json"

    private val livre: Tehilim = TehilimLoader.parse(File(RES, "raw/tehilim.json").readText())

    /** Une portion : début, fin, premier verset, dernier verset (null : jusqu'au bout). */
    private fun portion(p: Portion): List<Int?> = listOf(p.debut, p.fin, p.debutVerset, p.finVerset)

    /** Un IntRange de Kotlin : premier, dernier, nombre d'éléments (0 pour un intervalle vide). */
    private fun intervalle(r: IntRange): List<Int> = listOf(r.first, r.last, r.count())

    private fun jours(debut: LocalDate, fin: LocalDate): List<LocalDate> =
        generateSequence(debut) { it.plusDays(1) }.takeWhile { !it.isAfter(fin) }.toList()

    /** Le jour de la semaine comme `JourCivil.jourDeSemaine` : 1 = dimanche … 7 = samedi. */
    private fun jourDeSemaine(jour: DayOfWeek): Int = jour.value % 7 + 1

    // --- Les portions ----------------------------------------------------------------------------

    private val tables: List<Portion> = (CycleTehilim.MOIS + CycleTehilim.SEMAINE).distinct()

    /** Les cas de TehilimTest, puis les bornes : un seul psaume, une portion vide ou à l'envers, des versets hors du psaume, un psaume hors du livre. */
    private val essais: List<Portion> = listOf(
        Portion(140, 150), Portion(5, 5), Portion(119, 119), Portion(119, 119, 97, 176), Portion(119, 119, 1, 96),
        Portion(1, 1, 1, 1), Portion(1, 1, 2), Portion(3, 3, 1, null), Portion(3, 3, 1, 0), Portion(7, 3), Portion(5, 5, 10, 3),
        Portion(0, 0), Portion(151, 151), Portion(-1, 2), Portion(10, 12, 3, 4), Portion(10, 12, 0, 0), Portion(10, 10, -2, 500),
        Portion(117, 117, 3), Portion(150, 150, 6, 6), Portion(149, 150, 9, 2),
    )

    /** Les versets à lire, psaume par psaume : [psaume, total, premier, dernier, nombre]. */
    private fun casDePortion(p: Portion, large: Boolean): Map<String, Any?> {
        val psaumes = listOf(p.debut - 1, p.debut, p.debut + 1, p.fin - 1, p.fin, p.fin + 1).distinct()
        val versets = psaumes.flatMap { n ->
            // Le nombre de versets du livre ; pour les portions d'essai, des totaux de part et d'autre de leurs bornes.
            val totaux = listOf(livre.versets(n).size, 0, 1) +
                if (large) listOf(96, 176) + listOfNotNull(p.finVerset, p.finVerset?.minus(1), p.debutVerset - 1) else emptyList()
            totaux.distinct().map { total -> listOf(n, total) + intervalle(p.versets(n, total)) }
        }
        return linkedMapOf("portion" to portion(p), "partielle" to p.partielle, "psaumes" to intervalle(p.psaumes), "versets" to versets)
    }

    // --- Le livre --------------------------------------------------------------------------------

    /** Une empreinte pour toute une liste : les textes joints par un saut de ligne, « ∅ » là où il n'y en a pas. */
    private fun empreinte(textes: List<String?>): Int = textes.joinToString("\n") { it ?: "∅" }.hashCode()

    /** Un psaume : l'empreinte de chaque verset, et celle de ses traductions prises une à une par `traduction`. */
    private fun psaume(n: Int): Map<String, Any?> {
        val versets = livre.versets(n)
        return linkedMapOf(
            "numero" to n, "versets" to versets.size, "he" to versets.map { it.hashCode() },
            "fr" to empreinte(versets.indices.map { livre.traduction("fr", n, it + 1) }),
            "en" to empreinte(versets.indices.map { livre.traduction("en", n, it + 1) }),
        )
    }

    private val requetes: List<Triple<String, Int, Int>> = listOf(
        Triple("fr", 1, 1), Triple("en", 1, 1), Triple("he", 1, 1), Triple("", 1, 1), Triple("FR", 1, 1), Triple("fr ", 1, 1),
        Triple("fr", 0, 1), Triple("fr", 151, 1), Triple("fr", 150, 1), Triple("fr", 1, 0), Triple("fr", 1, 6), Triple("fr", 1, 7),
        Triple("fr", 117, 2), Triple("en", 117, 2), Triple("en", 117, 3), Triple("en", 150, 6), Triple("en", 150, 7),
        Triple("fr", 119, 176), Triple("fr", 119, 177), Triple("fr", -1, -1), Triple("en", Int.MIN_VALUE, 1),
        Triple("en", 1, Int.MIN_VALUE), Triple("fr", Int.MAX_VALUE, Int.MAX_VALUE), Triple("en", 23, 1), Triple("fr", 23, 1),
    )

    // --- La lecture du fichier : ce que TehilimLoader accepte, refuse et convertit ------------------

    private val documents: List<Pair<String, String>> = listOf(
        "minimal" to """{"psaumes":[["a","b"],[]]}""",
        "traductions" to """{"psaumes":[["א","ב","ג"],["ד"]],"traductions":{"fr":{"edition":{"titre":"x"},"psaumes":[["un"," ",""],["quatre","cinq"]]},"en":{"psaumes":[["one"]]}}}""",
        "blancs" to """{"psaumes":[["a","b","c","d","e","f","g","h"]],"traductions":{"fr":{"psaumes":[["\t"," ","  　","\u001c","​","\u0085","﻿"," x "]]}}}""",
        "hebreuVocalise" to """{"psaumes":[["בְּרֵאשִׁית בָּרָא","מָה־אָשִׁיב לַיהוָה׃"]],"traductions":{"fr":{"psaumes":[["Au commencement","Que rendrai-je ?"]]}}}""",
        "conversions" to """{"psaumes":[[20,1.5,true,false,null,{"a":1},[1,"x"],1e3,-0,3000000000,"20",""]]}""",
        "traductionsIgnorees" to """{"psaumes":[["a"]],"traductions":{"fr":"texte","en":{"psaumes":"non"},"he":{"autre":[["x"]]},"es":{"psaumes":[["hola"]]},"nul":null,"liste":[["x"]],"vide":{"psaumes":[]}}}""",
        "traductionsPasUnObjet" to """{"psaumes":[["a"]],"traductions":[["x"]]}""",
        "traductionsNulles" to """{"psaumes":[["a"]],"traductions":null}""",
        "meta" to """{"_meta":{"version":"1.0"},"psaumes":[["א"]],"autre":1}""",
        "clesRepetees" to """{"psaumes":[["a"]],"psaumes":[["b"],["c"]]}""",
        "suite" to """{"psaumes":[["a"]]} suite""",
        "sansPsaumes" to """{"traductions":{}}""",
        "psaumesPasUnTableau" to """{"psaumes":{"0":["a"]}}""",
        "psaumesEnChaine" to """{"psaumes":"[]"}""",
        "psaumesNuls" to """{"psaumes":null}""",
        "psaumePasUnTableau" to """{"psaumes":[["a"],"b"]}""",
        "psaumeNul" to """{"psaumes":[null]}""",
        "traductionFautive" to """{"psaumes":[["a"]],"traductions":{"fr":{"psaumes":[["x"],"y"]}}}""",
        "objetVide" to """{}""",
        "tableau" to """[["a"]]""",
        "texteVide" to "",
    )

    private fun lecture(nom: String, json: String): Map<String, Any?> {
        val base = linkedMapOf<String, Any?>("nom" to nom, "json" to json)
        val lu = try { TehilimLoader.parse(json) } catch (e: Exception) { return base + ("lu" to false) }
        // Chaque traduction demandée de part et d'autre du livre : resultats[numero][verset], de 0 à un de trop.
        val langues = lu.traductions.keys.toList()
        val largeur = (lu.psaumes + lu.traductions.values.flatten()).maxOfOrNull { it.size } ?: 0
        val hauteur = maxOf(lu.psaumes.size, lu.traductions.values.maxOfOrNull { it.size } ?: 0)
        return base + linkedMapOf(
            "lu" to true, "psaumes" to lu.psaumes, "versetsTotal" to lu.versetsTotal, "langues" to langues,
            "nombres" to (0..lu.psaumes.size + 1).map { lu.versets(it).size },
            "traduit" to (langues + "xx").map { langue ->
                linkedMapOf("langue" to langue, "resultats" to (0..hauteur + 1).map { n -> (0..largeur + 1).map { v -> lu.traduction(langue, n, v) } })
            },
        )
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTehilim.kt"),
        "livre" to linkedMapOf(
            "PSAUMES" to Tehilim.PSAUMES, "psaumes" to livre.psaumes.size, "versetsTotal" to livre.versetsTotal,
            "langues" to livre.traductions.keys.toList(),
            // Le psaume 117 en clair : les deux versets et leurs traductions.
            "psaume117" to linkedMapOf("he" to livre.versets(117),
                "fr" to (1..2).map { livre.traduction("fr", 117, it) }, "en" to (1..2).map { livre.traduction("en", 117, it) }),
        ),
        "psaumes" to (1..livre.psaumes.size).map(::psaume),
        "nombres" to listOf(-1, 0, 1, 2, 117, 119, 150, 151, 200, Int.MIN_VALUE, Int.MAX_VALUE).map { n ->
            linkedMapOf("numero" to n, "versets" to livre.versets(n).size)
        },
        "traductions" to requetes.map { (langue, n, v) ->
            linkedMapOf("langue" to langue, "numero" to n, "verset" to v, "texte" to livre.traduction(langue, n, v))
        },
        "documents" to documents.map { (nom, json) -> lecture(nom, json) },
        "mois" to CycleTehilim.MOIS.map(::portion),
        "semaine" to CycleTehilim.SEMAINE.map(::portion),
        "portions" to tables.map { casDePortion(it, large = false) } + essais.filterNot { it in tables }.map { casDePortion(it, large = true) },
        "duMois" to listOf(29, 30, 28, 31, 0).flatMap { longueur ->
            ((-3..34) + listOf(100, -100, Int.MIN_VALUE, Int.MAX_VALUE)).map { jour ->
                linkedMapOf("jour" to jour, "longueur" to longueur, "portion" to portion(CycleTehilim.duMois(jour, longueur)))
            }
        },
        "deLaSemaine" to DayOfWeek.values().map { jour ->
            linkedMapOf("jour" to jour.name, "jourDeSemaine" to jourDeSemaine(jour), "portion" to portion(CycleTehilim.deLaSemaine(jour)))
        },
        // L'année 5787 entière (embolismique : Adar I et Adar II), avec les jours qui la bordent.
        // d : la date ; s : le jour de la semaine (1 = dimanche) ; j, l : le jour du mois hébreu et la
        // longueur de ce mois ; m, h : les portions du jour selon le mois et selon la semaine.
        "dates" to jours(LocalDate.of(2026, 9, 1), LocalDate.of(2027, 10, 31)).map { d ->
            val (jour, longueur) = CycleTehilim.jourHebreu(d)
            linkedMapOf("d" to d.toString(), "s" to jourDeSemaine(d.dayOfWeek), "j" to jour, "l" to longueur,
                "m" to portion(CycleTehilim.duMois(jour, longueur)), "h" to portion(CycleTehilim.deLaSemaine(d.dayOfWeek)))
        },
        // Les bornes de chaque mois hébreu de septembre 2025 à décembre 2030 (les années des vecteurs du
        // calendrier) : les 1er, 29 et 30, là où la longueur du mois décide de la portion.
        "bornesDeMois" to jours(LocalDate.of(2025, 9, 1), LocalDate.of(2030, 12, 31)).mapNotNull { d ->
            val (jour, longueur) = CycleTehilim.jourHebreu(d)
            if (jour == 1 || jour >= 29) linkedMapOf("d" to d.toString(), "j" to jour, "l" to longueur) else null
        },
    )
}
