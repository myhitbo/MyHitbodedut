// La séance guidée devant la JVM : les cinq temps de la hitbodedout (Hitbodedut.kt), les questions du
// blocage (QuestionsBlocage.kt), l'invitation selon le sujet (GuideSujets.kt), les sujets (Theme.kt),
// l'adresse (Adresse.kt), la salutation (Salutation.kt) et les poses du personnage (Character.kt, qui
// devient Poses en Swift). Les ressources sont écrites par leur nom, comme iOS les nomme.

import com.myhitbodedut.Adresse
import com.myhitbodedut.ArticleEntry
import com.myhitbodedut.Character as PosesAndroid
import com.myhitbodedut.GuideSujets
import com.myhitbodedut.Hitbodedut
import com.myhitbodedut.Moment
import com.myhitbodedut.QuestionsBlocage
import com.myhitbodedut.Salutation
import com.myhitbodedut.SourceEntry
import com.myhitbodedut.Theme
import com.myhitbodedut.ThemeRules
import java.io.File
import java.time.LocalDate
import java.util.TimeZone
import kotlin.random.Random
import org.json.JSONObject

object VecteursGuidee : Generateur {
    override val fichier = "guidee.json"

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to linkedMapOf(
            "source" to "tools/vecteurs_ios/VecteursGuidee.kt",
            "debordements" to "ce que rend Kotlin là où son calcul sur 32 bits déborde ; Swift y rend le résultat exact",
            "posesJours" to "la règle de Character.ofDay appliquée à des jours fixes, après l'avoir vérifiée sur le vrai code pour les jours du lancement",
        ),

        // --- Hitbodedut.kt --------------------------------------------------------------------------
        "mouvements" to Hitbodedut.MOUVEMENTS.map { m ->
            linkedMapOf("cle" to m.cle, "he" to m.he, "titre" to Identifiants.entree(m.titre), "invite" to Identifiants.entree(m.invite),
                "illustration" to Identifiants.entree(m.illustration), "source" to m.source)
        },
        "sources" to linkedMapOf("likoutei" to Hitbodedut.SOURCE_LIKOUTEI, "rambam" to Hitbodedut.SOURCE_RAMBAM),
        "dernier" to Hitbodedut.DERNIER,
        // « suivant » et « precedent » manquent là où Kotlin déborde : voir « debordements ».
        "parcours" to listOf(Int.MIN_VALUE, Int.MIN_VALUE + 1, -1_000_000, -100, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 10, 99, 400,
            1_000_000, Int.MAX_VALUE - 1, Int.MAX_VALUE).map { i ->
            linkedMapOf("index" to i, "mouvement" to Hitbodedut.mouvement(i).cle,
                "suivant" to (if (i == Int.MAX_VALUE) null else Hitbodedut.suivant(i)),
                "precedent" to (if (i == Int.MIN_VALUE) null else Hitbodedut.precedent(i)),
                "estPremier" to Hitbodedut.estPremier(i), "estDernier" to Hitbodedut.estDernier(i))
        },
        "debordements" to listOf(
            linkedMapOf("fonction" to "Hitbodedut.suivant", "entree" to Int.MAX_VALUE, "kotlin" to Hitbodedut.suivant(Int.MAX_VALUE)),
            linkedMapOf("fonction" to "Hitbodedut.precedent", "entree" to Int.MIN_VALUE, "kotlin" to Hitbodedut.precedent(Int.MIN_VALUE)),
            linkedMapOf("fonction" to "QuestionsBlocage.suivante", "entree" to Int.MAX_VALUE, "kotlin" to QuestionsBlocage.suivante(Int.MAX_VALUE)),
        ),

        // --- QuestionsBlocage.kt --------------------------------------------------------------------
        "questions" to QuestionsBlocage.QUESTIONS.map { Identifiants.entree(it) },
        "suivantes" to (listOf(Int.MIN_VALUE, -1000, -2, -1) + (0..21) + listOf(99, 100, 1_000_000, Int.MAX_VALUE - 1)).map { i ->
            linkedMapOf("i" to i, "suivante" to QuestionsBlocage.suivante(i))
        },

        // --- Theme.kt -------------------------------------------------------------------------------
        "themes" to Theme.values().map { linkedMapOf("nom" to it.name, "cle" to it.cle, "titre" to Identifiants.entree(it.titre)) },
        "themesLus" to clesDeTheme.map { cle -> linkedMapOf("cle" to cle, "theme" to ThemeRules.parse(cle)?.cle) },
        // « max » absent : la valeur par défaut de Kotlin. « leve » : Kotlin lève une exception (max négatif).
        "frequents" to comptes().map { c ->
            val rendu = try {
                if (c.max == null) ThemeRules.frequents(c.cles) else ThemeRules.frequents(c.cles, c.max)
            } catch (e: IllegalArgumentException) {
                null
            }
            linkedMapOf("cles" to c.cles, "max" to c.max, "leve" to (rendu == null),
                "resultat" to rendu?.map { (theme, nombre) -> linkedMapOf("theme" to theme.cle, "nombre" to nombre) })
        },

        // --- Adresse.kt -----------------------------------------------------------------------------
        "adresses" to Adresse.values().map { a ->
            linkedMapOf("membre" to a.name, "cle" to a.cle, "bravo" to Identifiants.entree(a.bravo), "nom" to Identifiants.entree(a.nom),
                "hazak" to Identifiants.entree(a.hazak), "bravoDe" to Identifiants.entree(Adresse.bravo(a)),
                "hazakDe" to Identifiants.entree(Adresse.hazak(a)))
        },
        "adresseNeutre" to linkedMapOf("bravo" to Identifiants.entree(Adresse.bravo(null)), "hazak" to Identifiants.entree(Adresse.hazak(null))),
        "adressesLues" to clesDAdresse.map { cle -> linkedMapOf("cle" to cle, "adresse" to Adresse.parse(cle)?.cle) },

        // --- Salutation.kt --------------------------------------------------------------------------
        "heures" to (listOf(Int.MIN_VALUE, -100, -25, -24, -13, -1) + (0..30) + listOf(47, 100, Int.MAX_VALUE)).map { h ->
            linkedMapOf("heure" to h, "partie" to Salutation.partie(h).name, "mot" to Identifiants.entree(Salutation.mot(h)),
                "chaine" to Identifiants.entree(Salutation.chaine(h)))
        },

        // --- GuideSujets.kt -------------------------------------------------------------------------
        // Sur le vrai fichier : une empreinte par invitation (longueur et hashCode), pas le texte.
        // Une langue absente de « rendus » : Android rend null.
        "guideLangues" to languesDuGuide,
        "guideReel" to guideReel(),
        // Sur des données forgées : ce que la lecture tolérante d'Android fait d'un fichier abîmé.
        "guideForgeTexte" to GUIDE_FORGE,
        "guideForgeLangues" to languesForgees,
        "guideForge" to guideForge(),

        // --- Character.kt ---------------------------------------------------------------------------
        "poses" to linkedMapOf(
            "journal" to Identifiants.entree(PosesAndroid.JOURNAL), "study" to Identifiants.entree(PosesAndroid.STUDY),
            "reading" to Identifiants.entree(PosesAndroid.READING), "tehilim" to Identifiants.entree(PosesAndroid.TEHILIM),
            "accueil" to Identifiants.entree(PosesAndroid.greeting(false)),
            "source" to Identifiants.entree(PosesAndroid.ofLibraryEntry(source)),
            "article" to Identifiants.entree(PosesAndroid.ofLibraryEntry(article)),
        ),
        "posesMoments" to Moment.values().map { linkedMapOf("moment" to it.key, "pose" to Identifiants.entree(PosesAndroid.ofMoment(it))) },
        "posesJours" to posesJours(),
    )

    // --- Theme : les clés lues et les comptes ------------------------------------------------------

    private val clesDeTheme: List<String?> =
        listOf(null, "", " ", "   ", "\t", "\n", "\r\n", " ", " ", " ", "　", "\u001c", "\u0085", "​", "﻿") +
            Theme.values().map { it.cle } +
            listOf(" parnassa", "parnassa ", "parnassa\n", " parnassa", "PARNASSA", "Parnassa", "parnasa", "parnassaa", "aucun", "none",
                "vide", "teshouva_2031", "autres", "autre chose", "AUTRE", "EMOTIONS", "theme_emotions", "émotions", "emotionś",
                "ｅｍｏｔｉｏｎｓ", "0", "null", "נושא")

    private class Compte(val cles: List<String>, val max: Int?)

    private fun comptes(): List<Compte> {
        val journal = listOf("parnassa", "famille", "parnassa", "zivoug", "parnassa", "famille")
        val toutes = Theme.values().map { it.cle }
        val fixes = listOf(
            // Les cas de ThemeTest.
            Compte(listOf("parnassa", "inconnu", ""), null),
            Compte(journal, null), Compte(journal, 2), Compte(emptyList(), null),
            // Le plafond, de zéro à l'infini ; négatif, Kotlin lève une exception.
            Compte(journal, 0), Compte(journal, 1), Compte(journal, 3), Compte(journal, 4), Compte(journal, 100),
            Compte(journal, Int.MAX_VALUE), Compte(journal, -1), Compte(emptyList(), -1), Compte(journal, Int.MIN_VALUE),
            // À égalité, l'ordre de la liste des sujets tranche, pas celui du journal.
            Compte(toutes, null), Compte(toutes.reversed(), null), Compte(toutes.reversed(), 10), Compte(toutes + toutes.reversed(), 11),
            Compte(listOf("autre", "emotions", "autre", "emotions", "zivoug"), null),
            Compte(listOf("autre", "autre", "croissance", "croissance", "difficultes", "difficultes", "avoda", "avoda", "emotions"), null),
            // Rien que des clés que parse ne reconnaît pas.
            Compte(listOf(" parnassa", "PARNASSA", "parnassa ", "theme_parnassa", "aucun", "none", "vide", " "), null),
        )
        val hasard = Random(5787)
        val tirage = toutes + listOf("inconnu", "", " ", "PARNASSA", "teshouva_2031")
        val plafonds = listOf(null, 0, 1, 2, 3, 4, 5, 9, 10, 11)
        val tires = ArrayList<Compte>()
        for (n in 0 until 30) {
            val longueur = hasard.nextInt(0, 31)
            val cles = ArrayList<String>()
            for (k in 0 until longueur) cles.add(tirage[hasard.nextInt(tirage.size)])
            tires.add(Compte(cles, plafonds[n % plafonds.size]))
        }
        return fixes + tires
    }

    // --- Adresse ---------------------------------------------------------------------------------

    private val clesDAdresse: List<String?> = listOf(null, "", " ", "m", "f", "x", "M", "F", " m", "m ", "f\n", "mf", "fm", "mm", "homme",
        "femme", "HOMME", "FEMME", "ｍ", "м", "ḿ", "0", "null")

    // --- GuideSujets -----------------------------------------------------------------------------

    private val languesDuGuide = listOf("fr", "en", "he", "iw", "es", "", "FR", "He", "IW", "fr-FR", " he")

    private fun guideReel(): List<Map<String, Any?>> {
        // Comme GuideSujetsTest : le fichier lu en place ; et par le chemin de l'app, qui doit rendre la même chose.
        val sujets = JSONObject(File(RES, "raw/guide_sujets.json").readText()).getJSONObject("sujets")
        val contexte = Theatre().contexte
        val themes: List<Theme?> = Theme.values().toList() + listOf<Theme?>(null)
        val cles = Hitbodedut.MOUVEMENTS.map { it.cle } + listOf("", "inconnu", "SIHAH", "fr")
        return themes.flatMap { theme ->
            cles.map { cle ->
                val rendus = LinkedHashMap<String, Any?>()
                for (langue in languesDuGuide) {
                    val texte = GuideSujets.invitation(sujets, theme, cle, langue)
                    check(texte == GuideSujets.invitation(contexte, theme, cle, langue)) {
                        "GuideSujets : le fichier lu par l'app ne rend pas la même invitation (${theme?.cle}, $cle, $langue)"
                    }
                    if (texte != null) rendus[langue] = linkedMapOf("longueur" to texte.length, "empreinte" to texte.hashCode())
                }
                linkedMapOf("theme" to theme?.cle, "cle" to cle, "rendus" to rendus)
            }
        }
    }

    /** L'objet « sujets » d'un fichier abîmé : valeurs d'un autre type, textes blancs, clés inattendues. */
    private val GUIDE_FORGE = """
        {
         "emotions": {
          "sihah": {"fr": "Bonjour", "en": "", "he": "   ", "iw": "jamais lu", "es": "Hola", "": "langue vide", "FR": "majuscules"},
          "harata": {"fr": 20, "en": 1.5, "he": true, "es": null, "de": {"a": 1}, "it": [1, "x"], "nl": 1000.0, "pt": 1e3, "ru": false},
          "bakasha": "pas un objet",
          "torah": ["pas", "un", "objet"],
          "hodaa": null,
          "": {"fr": "temps sans nom"}
         },
         "gratitude": "pas un objet",
         "decisions": null,
         "famille": [],
         "zivoug": {},
         "parnassa": {
          "sihah": {"fr": "   \t\n", "en": "\u0085", "he": "לְפָרֵשׁ שִׂיחָתוֹ", "es": " x ", "de": "​", "it": "\u001c\u001f", "nl": "　", "pt": "﻿", "ru": "   "}
         },
         "avoda": {"sihah": {"fr": "a"}, "sihah ": {"fr": "b"}, "SIHAH": {"fr": "c"}},
         "autre": {"sihah": {"fr": "autre chose a ici son invitation"}, "hodaa": {"he": "תודה", "iw": "jamais lu"}}
        }
    """.trimIndent()

    private val languesForgees = listOf("fr", "en", "he", "iw", "es", "de", "it", "nl", "pt", "ru", "", "FR")

    private fun guideForge(): List<Map<String, Any?>> {
        val sujets = JSONObject(GUIDE_FORGE)
        val themes: List<Theme?> = Theme.values().toList() + listOf<Theme?>(null)
        val cles = Hitbodedut.MOUVEMENTS.map { it.cle } + listOf("", "inconnu", "sihah ", "SIHAH")
        return themes.flatMap { theme ->
            cles.map { cle ->
                val rendus = LinkedHashMap<String, Any?>()
                for (langue in languesForgees) {
                    val texte = GuideSujets.invitation(sujets, theme, cle, langue)
                    if (texte != null) rendus[langue] = texte
                }
                linkedMapOf("theme" to theme?.cle, "cle" to cle, "rendus" to rendus)
            }
        }
    }

    // --- Character : les poses -------------------------------------------------------------------

    private val source = SourceEntry(id = "source", titreHe = "", ref = "", refSefaria = null, url = null, edition = "",
        paragraphes = emptyList(), paragraphesSansNikkoud = emptyList(), liensChizuk = emptyList(), statutVerif = "",
        sujet = null, leconSurLeSujet = null)

    private val article = ArticleEntry(id = "article", titre = "", auteur = null, site = null, date = null, url = null,
        resumes = emptyMap(), droits = emptyMap(), autorisation = null, texteIntegral = null, sourcesCitees = emptyList(),
        erreursRelevees = emptyMap())

    /** Une des trois réserves de poses, privées dans Character : lue telle qu'elle est dans l'objet. */
    private fun reserve(nom: String): IntArray =
        PosesAndroid::class.java.getDeclaredField(nom).apply { isAccessible = true }.get(null) as IntArray

    /** La règle de Character.ofDay : le numéro du jour (LocalDate.toEpochDay), décalé de sept jours par sel. */
    private fun duJour(reserve: IntArray, sel: Int, numero: Long): Int =
        reserve[Math.floorMod(numero + sel * 7L, reserve.size.toLong()).toInt()]

    /**
     * Character lit le jour dans l'horloge (LocalDate.now()) : on ne peut pas lui en donner un autre.
     * La règle ci-dessus est donc comparée à ce que rend le vrai code pour les jours du lancement, vus
     * de trois fuseaux (deux ou trois jours civils distincts) ; les vecteurs, eux, portent des jours fixes.
     */
    private fun verifier(call: IntArray, during: IntArray, joy: IntArray) {
        val fuseau = TimeZone.getDefault()
        try {
            for (id in listOf("GMT-12:00", "UTC", "GMT+14:00")) {
                TimeZone.setDefault(TimeZone.getTimeZone(id))
                var verifie = false
                while (!verifie) {
                    val jour = LocalDate.now()
                    val rendus = listOf(PosesAndroid.call(), PosesAndroid.during(), PosesAndroid.joy(), PosesAndroid.greeting(true))
                    // Minuit a pu passer entre deux lectures de l'horloge : on recommence.
                    if (LocalDate.now() != jour) continue
                    val numero = jour.toEpochDay()
                    val attendus = listOf(duJour(call, 1, numero), duJour(during, 2, numero), duJour(joy, 3, numero), duJour(joy, 3, numero))
                    check(rendus == attendus) {
                        "Character.ofDay ne suit plus la règle portée ($jour, $id) : revoir Poses.swift et ce générateur"
                    }
                    verifie = true
                }
            }
        } finally {
            TimeZone.setDefault(fuseau)
        }
    }

    private fun posesJours(): List<Map<String, Any?>> {
        val call = reserve("CALL")
        val during = reserve("DURING")
        val joy = reserve("JOY")
        verifier(call, during, joy)
        // Autour du 1er janvier 1970 (numéros négatifs compris), un automne entier, et quelques jours repères.
        val jours = (-40L..40L).map { LocalDate.ofEpochDay(it) } +
            (0L until 42L).map { LocalDate.of(2026, 10, 25).plusDays(it) } +
            listOf("0000-01-01", "0000-02-29", "0001-01-01", "1582-10-15", "1899-12-31", "1900-02-28", "1900-03-01", "2000-02-29",
                "2024-02-29", "2038-01-19", "2100-02-28", "2100-03-01", "9999-12-31").map { LocalDate.parse(it) }
        return jours.map { jour ->
            val numero = jour.toEpochDay()
            linkedMapOf("jour" to jour.toString(), "numero" to numero,
                "call" to Identifiants.entree(duJour(call, 1, numero)),
                "during" to Identifiants.entree(duJour(during, 2, numero)),
                "joy" to Identifiants.entree(duJour(joy, 3, numero)))
        }
    }
}
