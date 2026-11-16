// Les tables écrites dans le Kotlin d'Android (ios/PORTAGE.md § 4.1, tableau C ; ios/ROADMAP.md, tâche 6),
// prises dans le vrai code et non recopiées : chaque table sous sa clé, avec ses comptes. Les identifiants de
// ressources (R.string.x, R.drawable.x) redeviennent leur nom (« x »), clé des chaînes et nom des images d'iOS.
//
// ROADMAP prévoyait tables.json comme ressource lue par l'app ; il est ici le juge des tables que les autres
// grappes ont écrites en Swift (TablesTests.swift les compare entrée par entrée). Une table changée dans le
// Kotlin change ce fichier, et la garde (ios-oracle.yml) échoue tant qu'iOS n'a pas suivi.
//
// Les tables privées du Kotlin sont lues par réflexion (un champ privé d'un « object » est un champ statique
// de sa classe) ; quand la table Swift est privée elle aussi, des sondes font répondre la règle qui s'en sert
// (Reference.localise, SaisieVol.lire, Character.call…), et le Swift doit répondre de même.

import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.CycleTehilim
import com.myhitbodedut.DirectionJerusalem
import com.myhitbodedut.Halakha
import com.myhitbodedut.Hitbodedut
import com.myhitbodedut.Moment
import com.myhitbodedut.MusiquePlay
import com.myhitbodedut.Onboarding
import com.myhitbodedut.Paliers
import com.myhitbodedut.Personnage
import com.myhitbodedut.PoliceHebraique
import com.myhitbodedut.Portion
import com.myhitbodedut.QuestionsBlocage
import com.myhitbodedut.Reference
import com.myhitbodedut.SaisieVol
import com.myhitbodedut.SujetTefila
import com.myhitbodedut.TefilotRules
import com.myhitbodedut.TerritoireIsrael
import com.myhitbodedut.Theme
import com.myhitbodedut.Tikkun
import com.myhitbodedut.Tips
import com.myhitbodedut.Trophees
import com.myhitbodedut.Vol
import com.myhitbodedut.YalkutYosef
import com.myhitbodedut.Zmanim
import com.myhitbodedut.Character as PosesAndroid
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

object VecteursTables : Generateur {
    override val fichier = "tables.json"

    /** Un champ privé d'un objet Kotlin (statique pour un « object », d'instance sinon). */
    private fun prive(objet: Any, nom: String): Any? =
        objet.javaClass.getDeclaredField(nom).apply { isAccessible = true }.get(objet)

    private fun nom(id: Int): String = Identifiants.entree(id)

    /** Les unités UTF-16 d'une chaîne en hexadécimal, « 05BD » : sans ambiguïté pour des signes combinants. */
    private fun unites(s: String): List<String> = s.map { "%04X".format(it.code) }

    private val jour0: LocalDate = LocalDate.of(2026, 1, 1)

    override fun produire(): Map<String, Any?> {
        val echelles = prive(Paliers, "ECHELLES") as Map<*, *>
        val feminin = prive(Personnage, "FEMININ") as Map<*, *>
        val contour = prive(TerritoireIsrael, "CONTOUR") as Array<*>
        val livres = prive(Reference, "LIVRES") as List<*>
        val absents = prive(PoliceHebraique, "ABSENTS") as Map<*, *>
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTables.kt"),
            // Les comptes du critère de la tâche 6, puis ceux des autres tables.
            "comptes" to linkedMapOf(
                "paliersEchelles" to echelles.size,
                "tropheesFamilles" to Trophees.Famille.entries.size,
                "tropheesNiveaux" to Trophees.chemin.size,
                "tehilimMois" to CycleTehilim.MOIS.size,
                "tehilimSemaine" to CycleTehilim.SEMAINE.size,
                "sujetsTefila" to SujetTefila.entries.size,
                "sujetsSeance" to Theme.entries.size,
                "mouvements" to Hitbodedut.MOUVEMENTS.size,
                "posesFeminines" to feminin.size,
                "zmanim" to Zmanim.PROFIL.size,
                "questions" to QuestionsBlocage.QUESTIONS.size,
                "ecransPresentation" to Onboarding.ECRANS.size,
                "conseils" to Tips.ALL.size,
                "fetes" to CalendrierJuif.FETES.size,
                "conditions" to CalendrierJuif.C.TOUTES.size,
                "conditionsDerivees" to CalendrierJuif.C.DERIVEES.size,
                "livresReference" to livres.size,
                "compagnies" to SaisieVol.COMPAGNIES.size,
                "villesPrincipales" to (prive(SaisieVol, "PRINCIPAL") as Map<*, *>).size,
                "nomsDeMois" to (prive(SaisieVol, "MOIS") as Map<*, *>).size,
                "contourIsrael" to contour.size,
                "polices" to PoliceHebraique.Police.entries.size,
                "morceaux" to MusiquePlay.MORCEAUX.size,
                "tikkun" to Tikkun.ORDRE.size,
            ),
            "hitbodedut" to hitbodedut(),
            "paliers" to Paliers.Piste.entries.map { p ->
                val base = Paliers.echelle(p, -1)
                val pas = Paliers.echelle(p, base.last())
                linkedMapOf("nom" to p.name, "cle" to p.cle, "base" to base, "pas" to pas.last() - base.last())
            },
            "trophees" to trophees(),
            "tehilim" to linkedMapOf(
                "psaumes" to com.myhitbodedut.Tehilim.PSAUMES,
                "mois" to CycleTehilim.MOIS.map(::portion),
                "semaine" to CycleTehilim.SEMAINE.map(::portion),
            ),
            "tikkun" to linkedMapOf(
                "ordre" to Tikkun.ORDRE,
                "blocs" to listOf(Tikkun.OUVERTURE, Tikkun.CLOTURE, Tikkun.KAVANA, Tikkun.PRIERE),
            ),
            "tefilot" to linkedMapOf(
                "sousSection" to TefilotRules.SOUS_SECTION,
                "sujets" to SujetTefila.entries.map { linkedMapOf("nom" to it.name, "cle" to it.cle, "titre" to nom(it.titre)) },
            ),
            "themes" to Theme.entries.map { linkedMapOf("nom" to it.name, "cle" to it.cle, "titre" to nom(it.titre)) },
            "questions" to QuestionsBlocage.QUESTIONS.map(::nom),
            "onboarding" to linkedMapOf(
                "version" to Onboarding.VERSION,
                "durees" to Onboarding.DUREES.toList(),
                "ecrans" to Onboarding.ECRANS.map {
                    linkedMapOf("cle" to it.cle, "titre" to nom(it.titre), "corps" to nom(it.corps),
                        "illustration" to nom(it.illustration), "choixAdresse" to it.choixAdresse,
                        "choixDuree" to it.choixDuree, "choixRappel" to it.choixRappel)
                },
            ),
            "tips" to Tips.ALL.map {
                linkedMapOf("number" to it.number, "titleRes" to nom(it.titleRes), "bodyRes" to nom(it.bodyRes), "art" to nom(it.art))
            },
            "yalkutYosef" to linkedMapOf(
                "parJour" to YalkutYosef.PAR_JOUR,
                // La fenêtre de fête de chaque jour hébreu, mois numérotés comme KosherJava (NISSAN = 1 … ADAR_II = 13).
                "fenetres" to listOf(false, true).flatMap { emb ->
                    (1..13).map { mois ->
                        linkedMapOf("embolismique" to emb, "mois" to mois,
                            "jours" to (1..30).map { jour -> YalkutYosef.fenetre(mois, jour, emb) })
                    }
                },
            ),
            "halakhaJointes" to Halakha.JOINTES.map { (jointe, parts) -> linkedMapOf("jointe" to jointe, "parts" to parts) },
            "calendrier" to linkedMapOf(
                "fetes" to CalendrierJuif.FETES.map { (index, cle) -> linkedMapOf("index" to index, "cle" to cle) },
                "conditions" to CalendrierJuif.C.TOUTES,
                "derivees" to CalendrierJuif.C.DERIVEES,
            ),
            "zmanim" to linkedMapOf(
                "profil" to Zmanim.PROFIL.map { (cle, m) -> linkedMapOf("cle" to cle, "methode" to m.cle, "parametres" to m.parametres) },
                "allumages" to Zmanim.ALLUMAGES,
                "allumageDefaut" to Zmanim.ALLUMAGE_DEFAUT,
                "methodesAllumage" to Zmanim.ALLUMAGES.map { m ->
                    Zmanim.methodeAllumage(m).let { linkedMapOf("minutes" to m, "methode" to it.cle, "parametres" to it.parametres) }
                },
            ),
            "reference" to reference(livres),
            "saisieVol" to saisieVol(),
            "territoireIsrael" to contour.map { (it as DoubleArray).toList() },
            "directionJerusalem" to linkedMapOf(
                "latitude" to DirectionJerusalem.LATITUDE,
                "longitude" to DirectionJerusalem.LONGITUDE,
                "tolerance" to DirectionJerusalem.TOLERANCE,
            ),
            "poses" to poses(),
            "personnage" to feminin.map { (hassid, f) -> linkedMapOf("hassid" to nom(hassid as Int), "feminine" to nom(f as Int)) },
            "polices" to PoliceHebraique.Police.entries.map { p ->
                val masque = absents[p]
                linkedMapOf("nom" to p.name, "cle" to p.cle, "libelle" to nom(p.libelle),
                    "absents" to masque?.let { m -> unites(String(prive(m, "de") as CharArray)) })
            },
            "musique" to MusiquePlay.MORCEAUX.map {
                linkedMapOf("id" to it.id, "rawRes" to nom(it.rawRes), "titleRes" to nom(it.titleRes))
            },
        )
    }

    private fun hitbodedut() = linkedMapOf(
        "sourceLikoutei" to Hitbodedut.SOURCE_LIKOUTEI,
        "sourceRambam" to Hitbodedut.SOURCE_RAMBAM,
        "mouvements" to Hitbodedut.MOUVEMENTS.map {
            linkedMapOf("cle" to it.cle, "he" to it.he, "titre" to nom(it.titre), "invite" to nom(it.invite),
                "illustration" to nom(it.illustration), "source" to it.source)
        },
    )

    private fun trophees() = linkedMapOf(
        "metaux" to Trophees.Metal.entries.map { it.name },
        "formes" to Trophees.Forme.entries.map { linkedMapOf("nom" to it.name, "cle" to it.cle) },
        "familles" to Trophees.Famille.entries.map { f ->
            linkedMapOf("nom" to f.name, "cle" to f.cle, "icone" to f.icone, "forme" to f.forme.name,
                "seuils" to f.seuils.toList(),
                "metaux" to (1..f.seuils.size).map { Trophees.metal(f, it).name },
                "couts" to f.seuils.map { Trophees.cout(f, it) })
        },
        // Les 128 niveaux, du plus facile au plus dur.
        "chemin" to Trophees.chemin.map { it.cle },
        "seuilsGrades" to Trophees.SEUILS_GRADES.toList(),
    )

    private fun portion(p: Portion) =
        linkedMapOf("debut" to p.debut, "fin" to p.fin, "debutVerset" to p.debutVerset, "finVerset" to p.finVerset)

    /** Les dix-huit livres, et ce que Reference.localise rend pour chacun suivi d'un numéro. */
    private fun reference(livres: List<*>) = linkedMapOf(
        "livres" to livres.map { l ->
            val fr = prive(l!!, "fr") as String
            linkedMapOf("fr" to fr, "en" to prive(l, "en"), "he" to prive(l, "he"),
                "connue" to Reference.connue(fr),
                "localiseEn" to Reference.localise(fr + "25", "en"),
                "localiseHe" to Reference.localise(fr + "25", "he"),
                "localiseFr" to Reference.localise(fr + "25", "fr"))
        },
        "inverses" to (prive(Reference, "INVERSES") as Map<*, *>).map { (n, s) -> linkedMapOf("nombre" to n, "lettres" to s) },
        // Les nombres en lettres, de -1 à 1000 : la table des unités, dizaines, centaines et des inversés.
        "lettres" to (-1..1000).map { Reference.lettres(it) },
    )

    /** Un aéroport d'essai : seul son code compte, sa ville ne ressemble à aucun mot sondé. */
    private fun aeroport(iata: String) =
        Vol.Aeroport(iata, "Essai $iata", "zz${iata.lowercase()}", "ZZ", 0.0, 0.0, "UTC")

    private fun saisieVol(): Map<String, Any?> {
        val principal = prive(SaisieVol, "PRINCIPAL") as Map<*, *>
        val mots = prive(SaisieVol, "MOTS") as Set<*>
        val mois = prive(SaisieVol, "MOIS") as Map<*, *>
        val jours = prive(SaisieVol, "JOURS") as Map<*, *>
        val vers = prive(SaisieVol, "VERS") as Set<*>
        val de = prive(SaisieVol, "DE") as Set<*>
        val aeroports = (principal.values.map { it as String } + listOf("LYS", "CDG")).distinct().map(::aeroport)
        fun lire(texte: String, liste: List<Vol.Aeroport> = emptyList()) = SaisieVol.lire(texte, liste, jour0)
        val hebreu = { s: String -> s.any { it in 'א'..'ת' } }
        return linkedMapOf(
            "aujourdhui" to jour0.toString(),
            "compagnies" to SaisieVol.COMPAGNIES.map { (n, c) -> linkedMapOf("nom" to n, "code" to c) },
            // Les tables privées, et une sonde par entrée : la phrase, puis ce que lire() en tire.
            "principal" to principal.map { (ville, iata) ->
                linkedMapOf("ville" to ville, "iata" to iata, "depart" to lire(ville as String, aeroports).depart?.iata)
            },
            "aeroportsEssai" to aeroports.map { it.iata },
            "mots" to mots.map { w ->
                val texte = w as String
                linkedMapOf("mot" to texte, "depart" to lire(texte, listOf(aeroport(texte.uppercase()))).depart?.iata)
            },
            "mois" to mois.map { (k, m) ->
                val texte = "12 $k 2027"
                linkedMapOf("nom" to k, "mois" to m, "texte" to texte, "date" to lire(texte).date?.toString())
            },
            "jours" to jours.map { (k, j) ->
                val cle = k as String
                val texte = if (hebreu(cle) && cle != "שבת") "יום $cle" else cle
                linkedMapOf("nom" to cle, "jour" to (j as DayOfWeek).name, "texte" to texte, "date" to lire(texte).date?.toString())
            },
            "vers" to vers.map { v ->
                val texte = "lyon $v paris"
                val p = lire(texte, aeroports)
                linkedMapOf("mot" to v, "texte" to texte, "depart" to p.depart?.iata, "arrivee" to p.arrivee?.iata)
            },
            "de" to de.map { d ->
                val texte = "lyon $d paris"
                val p = lire(texte, aeroports)
                linkedMapOf("mot" to d, "texte" to texte, "depart" to p.depart?.iata, "arrivee" to p.arrivee?.iata)
            },
        )
    }

    /** Character.kt (Poses en Swift) : les réserves, privées, et ce qu'elles donnent sept jours de suite. */
    private fun poses(): Map<String, Any?> {
        val reserve = { n: String -> (prive(PosesAndroid, n) as IntArray).map(::nom) }
        val jours = (0L..7L).map { jour0.plusDays(it) }
        return linkedMapOf(
            "appel" to reserve("CALL"),
            "pendant" to reserve("DURING"),
            "joie" to reserve("JOY"),
            "journal" to nom(PosesAndroid.JOURNAL),
            "study" to nom(PosesAndroid.STUDY),
            "reading" to nom(PosesAndroid.READING),
            "tehilim" to nom(PosesAndroid.TEHILIM),
            "moments" to Moment.entries.map { linkedMapOf("moment" to it.key, "pose" to nom(PosesAndroid.ofMoment(it))) },
            "jours" to jours.map { d ->
                Horloge.regler(LocalDateTime.of(d, java.time.LocalTime.NOON), ZoneId.of("UTC"))
                linkedMapOf("jour" to d.toString(), "call" to nom(PosesAndroid.call()), "during" to nom(PosesAndroid.during()),
                    "joy" to nom(PosesAndroid.joy()), "greetingFait" to nom(PosesAndroid.greeting(true)),
                    "greeting" to nom(PosesAndroid.greeting(false)))
            }.also { Horloge.defaut() },
        )
    }
}
