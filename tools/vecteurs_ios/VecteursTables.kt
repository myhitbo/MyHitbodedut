// Les tables écrites dans le Kotlin d'Android (PORTAGE.md § 4.1, tableau C ; § 4.2, étape 3), lues
// en exécutant ce Kotlin sur la JVM : échelles des paliers, familles et niveaux des trophées, portions
// des Tehilim, ordre du Tikoun, sujets, temps de la hitbodedout guidée, questions, écrans de
// présentation, conseils, profil des zmanim, poses du personnage féminin, signes absents des polices.
// Les identifiants de ressources redeviennent des noms (« string/tip_1_title »). Ce fichier est versionné
// et refait par ios-oracle.yml : un seuil changé dans Trophees.kt sans qu'iOS suive fait échouer la garde.
// tools/export_contenu/export.py le recopie dans ios/Ressources/Contenu/tables.json.

import com.myhitbodedut.CycleTehilim
import com.myhitbodedut.Hitbodedut
import com.myhitbodedut.Onboarding
import com.myhitbodedut.Paliers
import com.myhitbodedut.Personnage
import com.myhitbodedut.PoliceHebraique
import com.myhitbodedut.Portion
import com.myhitbodedut.QuestionsBlocage
import com.myhitbodedut.SujetTefila
import com.myhitbodedut.Theme
import com.myhitbodedut.Tikkun
import com.myhitbodedut.Tips
import com.myhitbodedut.Trophees
import com.myhitbodedut.Zmanim

object VecteursTables : Generateur {
    override val fichier = "tables.json"

    private fun nom(id: Int): String = Identifiants.nom(id)

    /** Un champ privé d'un objet Kotlin (champ statique de sa classe). */
    private fun prive(classe: Class<*>, champ: String): Any? =
        classe.getDeclaredField(champ).apply { isAccessible = true }.get(null)

    private fun portion(p: Portion): Map<String, Any?> = linkedMapOf(
        "debut" to p.debut, "fin" to p.fin, "debutVerset" to p.debutVerset, "finVerset" to p.finVerset,
    )

    /** Les échelles de base : la première échelle couvrant 0, sans objectif (Paliers.echelle). */
    private fun echelles(): Map<String, Any?> {
        @Suppress("UNCHECKED_CAST")
        val brutes = prive(Paliers::class.java, "ECHELLES") as Map<Paliers.Piste, Pair<IntArray, Int>>
        return Paliers.Piste.entries.associate { p ->
            val (base, pas) = brutes.getValue(p)
            p.cle to linkedMapOf("base" to base.toList(), "pas" to pas)
        }
    }

    private fun feminin(): Map<String, String> {
        @Suppress("UNCHECKED_CAST")
        val m = prive(Personnage::class.java, "FEMININ") as Map<Int, Int>
        return m.entries.associate { nom(it.key) to nom(it.value) }
    }

    private fun absents(): Map<String, String> {
        @Suppress("UNCHECKED_CAST")
        val m = prive(PoliceHebraique::class.java, "ABSENTS") as Map<PoliceHebraique.Police, Any>
        return PoliceHebraique.Police.entries.filter { it in m }.associate { p ->
            val masque = m.getValue(p)
            val de = masque.javaClass.getDeclaredField("de").apply { isAccessible = true }.get(masque) as CharArray
            p.cle to String(de)
        }
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTables.kt"),
        "paliers" to linkedMapOf("pistes" to Paliers.Piste.entries.map { it.cle }, "echelles" to echelles()),
        "trophees" to linkedMapOf(
            "familles" to Trophees.Famille.entries.map { f ->
                linkedMapOf("cle" to f.cle, "icone" to f.icone, "forme" to f.forme.cle, "seuils" to f.seuils.toList())
            },
            // Le chemin : chaque niveau dans l'ordre de l'écran, son coût estimé et son métal.
            "chemin" to Trophees.chemin.map { n ->
                linkedMapOf("cle" to n.cle, "seuil" to n.seuil, "cout" to Trophees.cout(n.famille, n.seuil), "metal" to n.metal.name)
            },
            "seuilsGrades" to Trophees.SEUILS_GRADES.toList(),
        ),
        "tehilim" to linkedMapOf(
            "mois" to CycleTehilim.MOIS.map(::portion),
            "semaine" to CycleTehilim.SEMAINE.map(::portion),
        ),
        "tikkun" to Tikkun.ORDRE,
        "sujets" to Theme.entries.map { linkedMapOf("cle" to it.cle, "titre" to nom(it.titre)) },
        "sujetsTefila" to SujetTefila.entries.map { linkedMapOf("cle" to it.cle, "titre" to nom(it.titre)) },
        "hitbodedut" to Hitbodedut.MOUVEMENTS.map {
            linkedMapOf("cle" to it.cle, "he" to it.he, "titre" to nom(it.titre), "invite" to nom(it.invite),
                "illustration" to nom(it.illustration), "source" to it.source)
        },
        "questions" to QuestionsBlocage.QUESTIONS.map(::nom),
        "presentation" to linkedMapOf(
            "version" to Onboarding.VERSION,
            "durees" to Onboarding.DUREES.toList(),
            "ecrans" to Onboarding.ECRANS.map {
                linkedMapOf("cle" to it.cle, "titre" to nom(it.titre), "corps" to nom(it.corps),
                    "illustration" to nom(it.illustration), "choixAdresse" to it.choixAdresse,
                    "choixDuree" to it.choixDuree, "choixRappel" to it.choixRappel)
            },
        ),
        "conseils" to Tips.ALL.map {
            linkedMapOf("numero" to it.number, "titre" to nom(it.titleRes), "corps" to nom(it.bodyRes), "illustration" to nom(it.art))
        },
        "zmanim" to linkedMapOf(
            "moteur" to Zmanim.MOTEUR,
            "profil" to Zmanim.PROFIL.map { (cle, m) -> linkedMapOf("cle" to cle, "methode" to m.cle, "parametres" to m.parametres) },
            "allumages" to Zmanim.ALLUMAGES,
            "allumageDefaut" to Zmanim.ALLUMAGE_DEFAUT,
        ),
        "personnageFeminin" to feminin(),
        "polices" to linkedMapOf(
            "cles" to PoliceHebraique.Police.entries.map { it.cle },
            "absents" to absents(),
        ),
    )
}
