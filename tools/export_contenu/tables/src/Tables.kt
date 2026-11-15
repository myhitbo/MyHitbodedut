// Les tables écrites dans le Kotlin d'Android (ios/PORTAGE.md § 4.1 C), lues dans le code compilé
// et écrites en JSON pour iOS (§ 4.2, étape 3). Aucune valeur n'est tapée ici : chaque table vient
// de l'objet de l'app qui la porte, par son API ou, pour une table privée, par réflexion. Les
// identifiants de ressources (R.string.*, R.drawable.*) redeviennent les noms de clés.
//
// Usage : Tables <tables.json> <vecteurs_recherche.json> <cas_normalisation.json> <res/raw>
// (lancé par tools/export_contenu/tables.py, à travers Gradle ; Recherche.kt écrit les vecteurs).
package com.myhitbodedut

import com.kosherjava.zmanim.hebrewcalendar.JewishDate
import java.io.File
import java.lang.reflect.Modifier

fun main(args: Array<String>) {
    require(args.size == 4) { "usage : Tables <tables.json> <vecteurs_recherche.json> <cas_normalisation.json> <res/raw>" }
    val sortie = File(args[0])
    val tables = linkedMapOf<String, Any?>(
        "paliers" to paliers(),
        "trophees" to trophees(),
        "tehilim" to tehilim(),
        "tikkun" to mapOf("ordre" to Tikkun.ORDRE),
        "hitbodedut" to hitbodedut(),
        "sujets_tefila" to mapOf(
            "sous_section" to TefilotRules.SOUS_SECTION,
            "sujets" to SujetTefila.entries.map { mapOf("cle" to it.cle, "titre" to nom(it.titre)) },
        ),
        "sujets_seance" to Theme.entries.map { mapOf("cle" to it.cle, "titre" to nom(it.titre)) },
        "questions" to QuestionsBlocage.QUESTIONS.map(::nom),
        "presentation" to presentation(),
        "conseils" to Tips.ALL.map {
            mapOf("numero" to it.number, "titre" to nom(it.titleRes), "corps" to nom(it.bodyRes), "illustration" to nom(it.art))
        },
        "yalkut_yosef" to yalkutYosef(),
        "ben_ish_hai" to mapOf("jointes" to Halakha.JOINTES),
        "calendrier" to calendrier(),
        "zmanim" to zmanim(),
        "references" to references(),
        "saisie_vol" to saisieVol(),
        "territoire_israel" to mapOf("contour" to prive<Array<DoubleArray>>(TerritoireIsrael, "CONTOUR").map { it.toList() }),
        "direction_jerusalem" to mapOf(
            "latitude" to DirectionJerusalem.LATITUDE, "longitude" to DirectionJerusalem.LONGITUDE,
            "tolerance" to DirectionJerusalem.TOLERANCE.toDouble(),
        ),
        "personnage" to personnage(),
    )
    sortie.writeText(enJson(tables) + "\n", Charsets.UTF_8)
    vecteursRecherche(raw = File(args[3]), cas = File(args[2]), sortie = File(args[1]), nomRaw = ::nom)
}

// --- Paliers et trophées ------------------------------------------------------------------

/** Les six échelles : la base (echelle(piste, 0)) et le pas au-delà du dernier palier. */
private fun paliers() = Paliers.Piste.entries.associate { p ->
    val base = Paliers.echelle(p, 0)
    val pas = Paliers.echelle(p, base.last()).last() - base.last()
    p.cle to mapOf("echelle" to base, "pas" to pas)
}

private fun trophees() = mapOf(
    "metaux" to Trophees.Metal.entries.map { it.name.lowercase() },
    "formes" to Trophees.Forme.entries.map { it.cle },
    "familles" to Trophees.Famille.entries.map { f ->
        mapOf("cle" to f.cle, "icone" to f.icone, "forme" to f.forme.cle, "seuils" to f.seuils.toList())
    },
    // Le chemin, du plus facile au plus dur : chaque niveau avec son coût. Le métal n'est plus
    // celui du niveau mais celui du grade, d'après le nombre de trophées gagnés (seuils_grades).
    "chemin" to Trophees.chemin.map { n ->
        mapOf("famille" to n.famille.cle, "rang" to n.rang, "seuil" to n.seuil, "cout" to Trophees.cout(n.famille, n.seuil))
    },
    "seuils_grades" to Trophees.SEUILS_GRADES.toList(),
)

// --- Textes -------------------------------------------------------------------------------

private fun portion(p: Portion) = mapOf("debut" to p.debut, "fin" to p.fin, "debut_verset" to p.debutVerset, "fin_verset" to p.finVerset)

private fun tehilim() = mapOf(
    "psaumes" to Tehilim.PSAUMES,
    "mois" to CycleTehilim.MOIS.map(::portion),
    "semaine" to CycleTehilim.SEMAINE.map(::portion),
    // Un mois de 29 jours dit le 29 les deux dernières portions (CycleTehilim.duMois).
    "fin_mois_court" to portion(CycleTehilim.duMois(29, 29)),
)

private fun hitbodedut() = mapOf(
    "mouvements" to Hitbodedut.MOUVEMENTS.map { m ->
        mapOf("cle" to m.cle, "he" to m.he, "titre" to nom(m.titre), "invite" to nom(m.invite),
            "illustration" to nom(m.illustration), "source" to m.source)
    },
)

private fun presentation() = mapOf(
    "version" to Onboarding.VERSION,
    "durees" to Onboarding.DUREES.toList(),
    "ecrans" to Onboarding.ECRANS.map { e ->
        mapOf("cle" to e.cle, "titre" to nom(e.titre), "corps" to nom(e.corps), "illustration" to nom(e.illustration),
            "choix_adresse" to e.choixAdresse, "choix_duree" to e.choixDuree, "choix_rappel" to e.choixRappel)
    },
)

// --- Halakha ------------------------------------------------------------------------------

/**
 * Les fenêtres de fête du Yalkout Yossef, par plages : [mois, premier jour, dernier jour, fenêtre],
 * mois de KosherJava, pour une année simple et une année embolismique (YalkutYosef.fenetre).
 */
private fun yalkutYosef(): Map<String, Any?> {
    fun plages(embolismique: Boolean): List<List<Any>> {
        val liste = mutableListOf<List<Any>>()
        for (mois in JewishDate.NISSAN..JewishDate.ADAR_II) {
            if (mois == JewishDate.ADAR_II && !embolismique) continue
            var debut = 0
            var courante: String? = null
            for (jour in 1..31) {
                val f = if (jour <= 30) YalkutYosef.fenetre(mois, jour, embolismique) else null
                if (f != courante) {
                    if (courante != null) liste += listOf(mois, debut, jour - 1, courante)
                    courante = f
                    debut = jour
                }
            }
        }
        return liste
    }
    return mapOf("par_jour" to YalkutYosef.PAR_JOUR, "fenetres" to mapOf("simple" to plages(false), "embolismique" to plages(true)))
}

// --- Calendrier et zmanim -----------------------------------------------------------------

private fun calendrier() = mapOf(
    "fetes" to CalendrierJuif.FETES.entries.map { (index, cle) -> mapOf("index" to index, "cle" to cle) },
    // Dans une ville murée (Jérusalem), Pourim et Chouchan Pourim prennent ces clés (CalendrierJuif.jour).
    "muree" to prive<Map<String, String>>(CalendrierJuif, "MUREE"),
    "conditions" to CalendrierJuif.C.TOUTES,
    "derivees" to CalendrierJuif.C.DERIVEES,
)

private fun zmanim() = mapOf(
    "moteur" to Zmanim.MOTEUR,
    "profil" to Zmanim.PROFIL.map { (cle, m) -> mapOf("cle" to cle, "methode" to m.cle, "parametres" to m.parametres) },
    "allumage" to Zmanim.methodeAllumage(Zmanim.ALLUMAGE_DEFAUT).cle,
    "allumages" to Zmanim.ALLUMAGES,
    "allumage_defaut" to Zmanim.ALLUMAGE_DEFAUT,
)

// --- Références, vol, personnage ----------------------------------------------------------

private fun references(): Map<String, Any?> {
    val livres = prive<List<Any>>(Reference, "LIVRES").map { l ->
        mapOf("fr" to champ<String>(l, "fr"), "en" to champ<String>(l, "en"), "he" to champ<String>(l, "he"))
    }
    // Les nombres en lettres de 1 à 999 (Reference.lettres), pour juger le portage d'un coup.
    return mapOf("livres" to livres, "lettres" to (1..999).map(Reference::lettres))
}

private fun saisieVol() = mapOf(
    // Dans l'ordre : à longueur égale, la première compagnie nommée l'emporte (SaisieVol.lire).
    "compagnies" to SaisieVol.COMPAGNIES.map { listOf(it.key, it.value) },
    "villes" to prive<Map<String, String>>(SaisieVol, "PRINCIPAL"),
    "mots" to prive<Set<String>>(SaisieVol, "MOTS").toList(),
    "mois" to prive<Map<String, Int>>(SaisieVol, "MOIS"),
    "jours" to prive<Map<String, java.time.DayOfWeek>>(SaisieVol, "JOURS").mapValues { it.value.value },
    "vers" to prive<Set<String>>(SaisieVol, "VERS").toList(),
    "de" to prive<Set<String>>(SaisieVol, "DE").toList(),
)

private fun personnage(): Map<String, Any?> {
    val source = SourceEntry("s", "", "", null, null, "", emptyList(), emptyList(), emptyList(),
        statutVerif = "", sujet = null, leconSurLeSujet = null)
    val article = ArticleEntry("a", "", null, null, null, null, emptyMap(), emptyMap(), null, null, emptyList(), emptyMap())
    return mapOf(
        "appel" to prive<IntArray>(Character, "CALL").map(::nom),
        "seance" to prive<IntArray>(Character, "DURING").map(::nom),
        "joie" to prive<IntArray>(Character, "JOY").map(::nom),
        "accueil" to nom(Character.greeting(false)),
        "journal" to nom(Character.JOURNAL),
        "etude" to nom(Character.STUDY),
        "lecture" to nom(Character.READING),
        "tehilim" to nom(Character.TEHILIM),
        "moments" to Moment.entries.associate { it.key to nom(Character.ofMoment(it)) },
        "bibliotheque" to mapOf("source" to nom(Character.ofLibraryEntry(source)), "article" to nom(Character.ofLibraryEntry(article))),
    )
}

// --- Outils -------------------------------------------------------------------------------

/** Les ressources du bouchon R (généré par tables.py) : identifiant → nom. */
private val NOMS: Map<Int, String> by lazy {
    val paires = R::class.java.declaredClasses.flatMap { type ->
        type.declaredFields.filter { Modifier.isStatic(it.modifiers) && it.type == Int::class.javaPrimitiveType }
            .map { it.getInt(null) to it.name }
    }
    check(paires.map { it.first }.toSet().size == paires.size) { "R : deux ressources ont le même identifiant" }
    paires.toMap()
}

private fun nom(id: Int): String = NOMS[id] ?: error("identifiant de ressource inconnu : $id")

/** Une propriété privée d'un objet de l'app : la table, sans la recopier. */
@Suppress("UNCHECKED_CAST")
private fun <T> prive(objet: Any, nom: String): T {
    val f = objet.javaClass.getDeclaredField(nom)
    f.isAccessible = true
    return f.get(objet) as T
}

@Suppress("UNCHECKED_CAST")
private fun <T> champ(instance: Any, nom: String): T = prive(instance, nom)

/** Un JSON sans dépendance : l'ordre des tables est celui du Kotlin ; tables.py le remet en forme. */
internal fun enJson(v: Any?): String = when (v) {
    null -> "null"
    is String -> buildString {
        append('"')
        for (c in v) when {
            c == '"' -> append("\\\"")
            c == '\\' -> append("\\\\")
            c < ' ' -> append("\\u%04x".format(c.code))
            else -> append(c)
        }
        append('"')
    }
    is Boolean, is Int, is Long -> v.toString()
    is Double -> if (v == Math.floor(v) && !v.isInfinite() && Math.abs(v) < 1e15) v.toLong().toString() else v.toString()
    is Float -> enJson(v.toDouble())
    is Map<*, *> -> v.entries.joinToString(",", "{", "}") { (k, x) -> enJson(k.toString()) + ":" + enJson(x) }
    is Iterable<*> -> v.joinToString(",", "[", "]") { enJson(it) }
    is IntArray -> enJson(v.toList())
    else -> error("type inattendu dans les tables : ${v::class}")
}
