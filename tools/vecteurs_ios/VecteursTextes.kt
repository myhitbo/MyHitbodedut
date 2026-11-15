// Les textes de prière devant la JVM (tâche 9) : le jour hébreu et la longueur du mois que
// CycleTehilim.jourHebreu lit dans KosherJava, jour par jour de 1950 à 2099 (le calendrier hébreu d'ICU, celui de
// Foundation, s'en écarte en 5806, d'octobre 2045 à novembre 2046) ; la portion du mois et
// celle de la semaine ; les versets d'une portion ; les psaumes et les traductions du livre ; la coupe
// d'un verset à son arrêt ; les lignes de l'écran Tfilot, sur la bibliothèque et sur une bibliothèque
// d'essai ; les bornes de la hitbodedout guidée et des questions « je ne sais pas quoi dire ».

import com.myhitbodedut.CycleTehilim
import com.myhitbodedut.Hitbodedut
import com.myhitbodedut.LibraryLoader
import com.myhitbodedut.Pause
import com.myhitbodedut.Portion
import com.myhitbodedut.QuestionsBlocage
import com.myhitbodedut.TefilotRules
import com.myhitbodedut.TehilimLoader
import com.myhitbodedut.TikkunLoader
import com.myhitbodedut.Verse
import java.io.File
import java.time.LocalDate

object VecteursTextes : Generateur {
    override val fichier = "textes.json"

    private val debut = LocalDate.of(1950, 1, 1)
    private val fin = LocalDate.of(2100, 1, 1)

    private fun portion(p: Portion): List<Any?> = listOf(p.debut, p.fin, p.debutVerset, p.finVerset)

    /** Les coupes d'essai : texte, mot d'arrêt (null : sans arrêt). */
    private val coupes: List<Pair<String, String?>> = listOf(
        "א ב" to null,
        "א ב" to "ב",
        "א ב" to "א",
        "א ב" to "",
        "א ב" to "ג",
        "אַתָּה סֵתֶר לִי מִצַּר תִּצְּרֵנִי" to "מִצַּר",
        "מָה מ" to "מ",
        "אב מָה" to "מ",
        "a \t b" to "b",
        "a\u0085b" to "b",
        "a 　b c b" to "b",
        "   b" to "b",
        "x  יְהוָה יְהוָה" to "יְהוָה",
        "é é" to "é",
        "é é" to "é",
    )

    /** Une bibliothèque d'essai : un article, des sujets absents, inconnus, et un sujet sans « oui ». */
    private val bibliothequeEssai = """
        {"_meta": {"version": "essai", "editions": {"lt": {"titre": "LT", "licence": "", "nikkoud_ok": false}}},
         "sections": [{"id": "s", "sous_sections": [
           {"id": "autre", "entrees": [{"type": "source", "id": "hors", "sujet": "zivug", "paragraphes": ["x"]}]},
           {"id": "tefilot-lt", "entrees": [
             {"type": "article", "id": "art", "titre": "Article", "sujet": "zivug"},
             {"type": "source", "id": "z1", "sujet": "zivug", "lecon_sur_le_sujet": "non", "paragraphes": ["a"]},
             {"type": "source", "id": "inconnu", "sujet": "xyz", "lecon_sur_le_sujet": "non", "paragraphes": ["b"]},
             {"type": "source", "id": "sans", "paragraphes": ["c"]},
             {"type": "source", "id": "blanc", "sujet": "  ", "paragraphes": ["d"]},
             {"type": "source", "id": "h1", "sujet": "hitbodedut", "lecon_sur_le_sujet": "oui", "paragraphes": ["e"]},
             {"type": "source", "id": "z2", "sujet": "zivug", "lecon_sur_le_sujet": "partiel", "paragraphes": ["f"]},
             {"type": "source", "id": "r1", "sujet": "refua", "lecon_sur_le_sujet": "Non", "paragraphes": ["g"]},
             {"type": "source", "id": "majuscule", "sujet": "ZIVUG", "paragraphes": ["h"]}
           ]}
         ]}]}
    """.trimIndent()

    private fun lignes(json: String): List<String> = TefilotRules.lignes(LibraryLoader.parse(json)).map {
        when (it) {
            is TefilotRules.Ligne.Titre -> "titre ${it.sujet.cle} ${it.nombre}"
            is TefilotRules.Ligne.Priere -> "priere ${it.sujet.cle} ${it.entree.id}" +
                (if (TefilotRules.prevenir(it.entree)) " prevenir" else "")
        }
    }

    override fun produire(): Map<String, Any?> {
        fun lire(nom: String) = File(RES, "raw/$nom").readText()
        val livre = TehilimLoader.parse(lire("tehilim.json"))
        val tikkun = TikkunLoader.parse(lire("tikkun_haklali.json"))
        val bibliotheque = lire("bibliotheque.json")

        // Le jour hébreu, jour par jour, ramené aux premiers de mois : chaque jour d'un mois s'en déduit.
        val jours = generateSequence(debut) { it.plusDays(1) }.takeWhile { it.isBefore(fin) }.toList()
        val premiers = mutableListOf<String>()
        var ouvert: Pair<LocalDate, Int>? = null
        for (d in jours) {
            val (jour, longueur) = CycleTehilim.jourHebreu(d)
            if (jour == 1) {
                ouvert = d to longueur
                premiers += "$d $longueur"
            }
            ouvert?.let { (premier, l) ->
                check(jour.toLong() == d.toEpochDay() - premier.toEpochDay() + 1 && longueur == l) {
                    "$d : $jour/$longueur après $premier/$l"
                }
            }
        }

        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTextes.kt"),
            // « date longueur » de chaque premier du mois hébreu entre le début et la fin : du premier au
            // dernier, chaque jour civil a pour jour hébreu son rang depuis le premier, et cette longueur.
            "moisHebreux" to premiers,
            "jourHebreu" to listOf("2026-09-12", "2026-10-04", "2026-11-15", "2027-02-28", "2024-03-10", "2045-11-09",
                "2045-11-10", "2046-10-31", "1900-03-01", "1583-09-15", "2240-09-01", "3000-01-01").map {
                val (j, l) = CycleTehilim.jourHebreu(LocalDate.parse(it))
                listOf(it, j, l)
            },
            // jour, longueur, puis la portion : début, fin, premier verset, dernier verset (null : jusqu'au bout).
            "duMois" to (-1..32).flatMap { j -> listOf(29, 30).map { l -> listOf(j, l) + portion(CycleTehilim.duMois(j, l)) } },
            // Une semaine du dimanche au samedi.
            "deLaSemaine" to (0..6).map { i ->
                val d = LocalDate.of(2026, 10, 4).plusDays(i.toLong())
                listOf(d.toString()) + portion(CycleTehilim.deLaSemaine(d.dayOfWeek))
            },
            // Chaque portion : ses champs, partielle, puis pour chaque psaume de debut - 1 à fin + 1, « psaume
            // premier dernier » de versets(psaume, versets du livre) ; « dernier < premier » : rien à lire.
            "portions" to (CycleTehilim.MOIS + CycleTehilim.SEMAINE + listOf(Portion(5, 5), Portion(3, 2))).map { p ->
                linkedMapOf(
                    "portion" to portion(p),
                    "psaumes" to listOf(p.psaumes.first, p.psaumes.last),
                    "partielle" to p.partielle,
                    "versets" to (p.debut - 1..p.fin + 1).map { n ->
                        val r = p.versets(n, livre.versets(n).size)
                        "$n ${r.first} ${r.last}"
                    },
                )
            },
            "versetsTotal" to livre.versetsTotal,
            // Le nombre de versets des psaumes -1 à 152 (0 hors du livre).
            "versetsParPsaume" to (-1..152).map { livre.versets(it).size },
            // langue, psaume, verset, traduction (null : aucune).
            "traductions" to listOf(
                Triple("fr", 1, 1), Triple("en", 1, 1), Triple("fr", 150, 6), Triple("en", 117, 2),
                Triple("fr", 119, 176), Triple("en", 119, 177), Triple("fr", 0, 1), Triple("fr", 151, 1),
                Triple("fr", 1, 0), Triple("he", 1, 1), Triple("es", 1, 1), Triple("", 23, 1),
            ).map { (l, p, v) -> listOf(l, p, v, livre.traduction(l, p, v)) },
            "traductionsPresentes" to listOf("fr", "en").map { l ->
                listOf(l, (1..150).sumOf { p -> (1..livre.versets(p).size).count { v -> livre.traduction(l, p, v) != null } })
            },
            // texte, mot d'arrêt, puis les deux moitiés (null : pas de coupe).
            "coupes" to (coupes.map { (he, mot) -> Verse(1, he, mot?.let { Pause(it, "") }) } +
                tikkun.psaumes.flatMap { it.versets }.filter { it.arret != null }).map { v ->
                val c = v.coupe()
                listOf(v.he, v.arret?.avant, c?.first, c?.second)
            },
            "tefilot" to lignes(bibliotheque),
            "tefilotEssai" to linkedMapOf("json" to bibliothequeEssai, "lignes" to lignes(bibliothequeEssai)),
            // indice, clé du temps, suivant, précédent, premier, dernier.
            "hitbodedut" to (-3..8).map { i ->
                listOf(i, Hitbodedut.mouvement(i).cle, Hitbodedut.suivant(i), Hitbodedut.precedent(i),
                    Hitbodedut.estPremier(i), Hitbodedut.estDernier(i))
            },
            "questions" to (-3..21).map { listOf(it, QuestionsBlocage.suivante(it)) },
        )
    }
}
