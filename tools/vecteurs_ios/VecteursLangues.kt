// RegleLangue, LanguesTexte, LibraryRules et Reference devant la JVM : la règle des langues sur des
// étiquettes de toutes formes (« iw », « en-US », « fr_CA », vides, en capitales), les langues d'un
// texte à lire pour chaque mode, ce que la bibliothèque livrée montre de chaque entrée (une empreinte
// String.hashCode par texte), puis une bibliothèque écrite à la main, lue par LibraryLoader comme
// Swift la décodera ; enfin Reference.lettres de -1 à 1100 et Reference.localise sur chaque référence
// de chizuk.json et de bibliotheque.json, et sur des références écrites à la main.

import com.myhitbodedut.ArticleEntry
import com.myhitbodedut.LanguesTexte
import com.myhitbodedut.Library
import com.myhitbodedut.LibraryEntry
import com.myhitbodedut.LibraryLoader
import com.myhitbodedut.LibraryRules
import com.myhitbodedut.Reference
import com.myhitbodedut.RegleLangue
import com.myhitbodedut.SourceEntry
import java.io.File

object VecteursLangues : Generateur {
    override val fichier = "langues.json"

    // --- Les étiquettes de langue ----------------------------------------------------------------

    /** Ce qu'un téléphone, un réglage ou une donnée peut nommer comme langue. */
    private val etiquettes: List<String> = listOf(
        "", "he", "iw", "fr", "en", "HE", "IW", "Iw", "Fr", "EN", "he-IL", "iw-IL", "iw_IL", "he_IL", "fr-FR", "fr_CA",
        "en-US", "en_GB", "en-Latn-US", "EN-gb", "FR-be", "IW-il", "es", "es-ES", "de", "ar", "ru", "yi", "-fr", "_en",
        "-", "_", "x", " he", "he ", "fr-", "en_", "i", "w", "iwi", "hebrew", "français", "ÉN", "zh-Hant-TW",
    )

    /** Les langues d'un texte, pour `permet`. */
    private val languesDuTexte = listOf("he", "iw", "fr", "en", "es", "", "HE", "IW", "fr-FR", "en_US", "he-IL", "iw_IL")

    /** Des textes indexés par langue, pour `choisit` : des absents, des vides, des blancs de Kotlin. */
    private val recueils: List<Map<String, String?>> = listOf(
        emptyMap(),
        mapOf("fr" to "une note"),
        mapOf("fr" to "x", "he" to ""),
        mapOf("he" to "אחד", "fr" to "un", "en" to "one"),
        mapOf("he" to "  ", "fr" to "\t", "en" to "\n"),
        mapOf("he" to null, "fr" to null, "en" to null),
        mapOf("en" to " ", "fr" to " ", "he" to " "),
        mapOf("en" to "​", "fr" to "　", "he" to " "),
        mapOf("en" to " one ", "fr" to " un ", "he" to " שָׁלוֹם "),
        mapOf("iw" to "ivrit", "EN" to "capitales", "fr-FR" to "région"),
        mapOf("" to "sans langue"),
        mapOf("es" to "uno", "de" to "eins"),
    )

    private fun regle(): Map<String, Any?> = linkedMapOf(
        "etiquettes" to etiquettes.map { e ->
            linkedMapOf(
                "etiquette" to e,
                "normalise" to RegleLangue.normalise(e),
                // L'ordre de setOf : l'hébreu, puis la langue de l'interface.
                "permises" to RegleLangue.permises(e).toList(),
                "traduit" to RegleLangue.traduit(e),
                "permet" to languesDuTexte.map { RegleLangue.permet(e, it) },
                "choisit" to recueils.map { RegleLangue.choisit(e, it) },
            )
        },
        "normaliseNul" to RegleLangue.normalise(null),
        "languesDuTexte" to languesDuTexte,
        "recueils" to recueils,
    )

    // --- Les langues d'un texte à lire -----------------------------------------------------------

    private val hebreux = listOf("אחד", "", "שָׁלוֹם")
    private val francais = listOf(null, "", " ", "un")
    private val anglais = listOf(null, " ", "​", "one")

    private fun languesTexte(): Map<String, Any?> = linkedMapOf(
        "modes" to LanguesTexte.Mode.entries.map { m ->
            linkedMapOf("nom" to m.name, "cle" to m.cle, "langues" to m.langues, "libelle" to Identifiants.entree(m.libelle))
        },
        "defaut" to etiquettes.map { linkedMapOf("langue" to it, "mode" to LanguesTexte.defaut(it).cle) },
        "hebreux" to hebreux,
        "francais" to francais,
        "anglais" to anglais,
        // Pour chaque mode, chaque hébreu, chaque français et chaque anglais (dans cet ordre, l'anglais
        // variant le plus vite) : les paires (langue, texte) que rend `textes`.
        "textes" to LanguesTexte.Mode.entries.map { m ->
            linkedMapOf(
                "mode" to m.cle,
                "resultats" to hebreux.flatMap { he ->
                    francais.flatMap { fr ->
                        anglais.map { en -> LanguesTexte.textes(m, he, fr, en).map { (l, t) -> listOf(l, t) } }
                    }
                },
            )
        },
        "manque" to LanguesTexte.Mode.entries.map { m ->
            linkedMapOf("mode" to m.cle, "sansTraduction" to LanguesTexte.manque(m, false), "avecTraduction" to LanguesTexte.manque(m, true))
        },
    )

    // --- La bibliothèque -------------------------------------------------------------------------

    private val livre: Library = LibraryLoader.parse(File(RES, "raw/bibliotheque.json").readText())

    private val languesArticle = listOf("fr", "en", "he", "iw", "FR", "en-US", "he_IL", "es", "")

    private fun empreintes(textes: List<String>): List<Int> = textes.map { it.hashCode() }

    private fun article(a: ArticleEntry): Map<String, Any?> = linkedMapOf(
        "id" to a.id,
        "texteIntegral" to LibraryRules.fullText(a)?.hashCode(),
        "resumes" to languesArticle.map { LibraryRules.summary(a, it)?.hashCode() },
        "droits" to languesArticle.map { LibraryRules.rights(a, it)?.hashCode() },
        "erreurs" to languesArticle.map { empreintes(LibraryRules.errors(a, it)) },
    )

    private fun source(l: Library, s: SourceEntry): Map<String, Any?> = linkedMapOf(
        "id" to s.id,
        "edition" to s.edition,
        "nikkoudOk" to l.editions[s.edition]?.nikkoudOk,
        "affiches" to empreintes(LibraryRules.paragraphs(l, s)),
        "sontLesParagraphes" to (LibraryRules.paragraphs(l, s) == s.paragraphes),
    )

    private fun nature(e: LibraryEntry): String = if (e is SourceEntry) "source" else "article"

    /** Ce que la règle rend pour une bibliothèque : chaque entrée, et l'ordre de chaque sous-section. */
    private fun bibliotheque(l: Library): Map<String, Any?> = linkedMapOf(
        "articles" to l.entrees.filterIsInstance<ArticleEntry>().map { article(it) },
        "sources" to l.entrees.filterIsInstance<SourceEntry>().map { source(l, it) },
        "ordres" to l.sections.flatMap { it.sousSections }.map { ss ->
            linkedMapOf(
                "sousSection" to ss.id,
                "ids" to LibraryRules.ordered(ss.entrees).map { it.id },
                "natures" to LibraryRules.ordered(ss.entrees).map { nature(it) },
            )
        },
    )

    /**
     * Une bibliothèque écrite à la main, que Swift décode telle quelle : des éditions vocalisables ou
     * non, une édition absente, des sources sans paragraphes sans nikkoud, des articles aux langues
     * incomplètes, une autorisation blanche, des erreurs relevées vides ou qui ne sont pas une liste.
     */
    private val document = """
        {"_meta": {"version": "essai", "editions": {
            "voc": {"titre": "vocalisée", "licence": "Public Domain", "nikkoud_ok": true},
            "nue": {"titre": "non déclarée", "licence": "?", "nikkoud_ok": false},
            "muette": {"titre": "sans drapeau"}}},
         "sections": [
          {"id": "s1", "titre": {"he": "א", "fr": "A", "en": "A"}, "sous_sections": [
            {"id": "melee", "entrees": [
              {"id": "a1", "type": "article", "titre": "un", "resume_fr": "résumé", "droits_fr": "droits",
               "autorisation": "accord écrit", "texte_integral": "le texte",
               "erreurs_relevees_fr": ["e1", "e2"], "erreurs_relevees_en": ["f1", "f2"], "erreurs_relevees_he": []},
              {"id": "s-voc", "type": "source", "edition": "voc", "paragraphes": ["בְּרֵאשִׁית", "בָּרָא"],
               "paragraphes_sans_nikkoud": ["בראשית", "ברא"]},
              {"id": "a2", "type": "article", "resume_en": "summary", "resume_he": "תקציר", "resume_": "sans langue",
               "resume_FR": "capitales", "droits_en": "rights", "droits_he": "   ", "autorisation": "   ",
               "texte_integral": "caché", "erreurs_relevees_he": "pas une liste", "erreurs_relevees_": ["vide"]},
              {"id": "s-nue", "type": "source", "edition": "nue", "paragraphes": ["שָׁלוֹם"],
               "paragraphes_sans_nikkoud": ["שלום"]},
              {"id": "s-nue-seule", "type": "source", "edition": "nue", "paragraphes": ["עוֹלָם", "וָעֶד"]},
              {"id": "a3", "type": "Source", "titre": "pas une source", "autorisation": "oui", "texte_integral": ""},
              {"id": "s-muette", "type": "source", "edition": "muette", "paragraphes": ["אָמֵן"],
               "paragraphes_sans_nikkoud": ["אמן"]},
              {"id": "s-inconnue", "type": "source", "edition": "inconnue", "paragraphes": ["הַלְלוּיָהּ"],
               "paragraphes_sans_nikkoud": ["הללויה"]},
              {"id": "s-sans-edition", "type": "source", "paragraphes": ["א", "ב"], "paragraphes_sans_nikkoud": []},
              {"id": "a4", "type": "article", "resume_fr": " ", "resume_en": "", "droits_fr": null,
               "autorisation": null, "texte_integral": "texte", "erreurs_relevees_fr": ["seule"]}
            ]},
            {"id": "articles-seuls", "entrees": [
              {"id": "a5", "type": "article"}, {"id": "a6", "type": "article", "resume_he": "רק עברית"}]},
            {"id": "sources-seules", "entrees": [
              {"id": "s-a", "type": "source", "edition": "voc", "paragraphes": []},
              {"id": "s-b", "type": "source", "edition": "nue", "paragraphes": [], "paragraphes_sans_nikkoud": []}]},
            {"id": "vide", "entrees": []}
          ]},
          {"id": "s2", "sous_sections": [
            {"id": "inverse", "entrees": [
              {"id": "a7", "type": "article", "resume_fr": "sept"},
              {"id": "a8", "type": "article", "resume_fr": "huit"},
              {"id": "s-c", "type": "source", "edition": "voc", "paragraphes": ["ג"]},
              {"id": "a9", "type": "article", "resume_fr": "neuf"},
              {"id": "s-d", "type": "source", "edition": "nue", "paragraphes": ["ד"], "paragraphes_sans_nikkoud": ["ד׳"]}]}
          ]}
         ]}
    """.trimIndent()

    private val manuelle: Library = LibraryLoader.parse(document)

    /** `fullText` sur un article construit directement : la règle seule, sans le tri de Json.nullable. */
    private val autorisations = listOf(null, "", "   ", " ", "\t", "​", "accord", "accord écrit de l'auteur, 20/09/2026")
    private val integraux = listOf(null, "", " ", " ", "texte", "le texte complet de l'article")

    private fun gabarit(autorisation: String?, texte: String?) = ArticleEntry(
        id = "t", titre = "titre", auteur = null, site = null, date = null, url = null,
        resumes = mapOf("fr" to "résumé"), droits = emptyMap(), autorisation = autorisation,
        texteIntegral = texte, sourcesCitees = emptyList(), erreursRelevees = emptyMap(),
    )

    private fun regles(): Map<String, Any?> = linkedMapOf(
        "languesArticle" to languesArticle,
        "livre" to bibliotheque(livre),
        "document" to document,
        "manuelle" to bibliotheque(manuelle),
        // Les textes en clair pour la bibliothèque écrite à la main, où rien n'est long.
        "manuelleEnClair" to manuelle.entrees.map { e ->
            when (e) {
                is SourceEntry -> linkedMapOf("id" to e.id, "affiches" to LibraryRules.paragraphs(manuelle, e))
                is ArticleEntry -> linkedMapOf(
                    "id" to e.id,
                    "texteIntegral" to LibraryRules.fullText(e),
                    "resumes" to languesArticle.map { LibraryRules.summary(e, it) },
                    "droits" to languesArticle.map { LibraryRules.rights(e, it) },
                    "erreurs" to languesArticle.map { LibraryRules.errors(e, it) },
                )
            }
        },
        "autorisations" to autorisations,
        "integraux" to integraux,
        // Pour chaque autorisation, le texte intégral rendu pour chacun des textes.
        "texteIntegral" to autorisations.map { a -> integraux.map { t -> LibraryRules.fullText(gabarit(a, t)) } },
        "resumeDuGabarit" to languesArticle.map { LibraryRules.summary(gabarit(null, null), it) },
    )

    // --- Les références --------------------------------------------------------------------------

    /** Les références des données, lues comme TraductionAffichageTest les lit : dans le texte brut. */
    private val refsDesDonnees: List<String> =
        listOf("raw/chizuk.json", "raw/bibliotheque.json").flatMap { f ->
            Regex(""""ref": "([^"]+)"""").findAll(File(RES, f).readText()).map { it.groupValues[1] }.toList()
        }

    private val languesRef = listOf("fr", "en", "he", "iw", "en-US", "he_IL", "EN", "es", "")

    /** Des références écrites à la main : les bornes du remplacement des livres et des numéros. */
    private val refsManuelles = listOf(
        "Michlé 24:16", "Likoutei Moharan II, 25", "Likoutei Moharan II, 78", "Likoutei Moharan I, 52:3",
        "Si'hot HaRan 275", "Si'hot HaRan 270, 272, 274, 298, 304, 344", "Si'hot HaRan 271 ; 345",
        "Tehilim 1:2:3", "Tehilim 0:0", "Tehilim 007", "Tehilim 1000:1001", "Tehilim 999:15", "Tehilim 145:18 ; Michlé 3:5",
        "Tehilim 23 ; 121", "Tehilim", "Tehilim ", "tehilim 1", "Tehilim 1234567890", "Tehilim 2147483647",
        "Tehilim ١٢:٣", "Tehilim １２", "Tehilim 12a", "Tehilim 1:", ":5", "12:34:56:78",
        "Rambam, Hilkhot Tefila 4:16", "Bisdei Yaar, chap. 3", "Likoutei Etsot, Téfila 5",
        "Likoutei Etsot, Téfila 5", "Likoutei Etsot, Hit'hazkout 1", "Likoutei Etsot, Hitbodedout 22",
        "Likoutei Tefilot I, 15", "Likoutei Tefilot II, 16", "Chmouel I 1:15", "Hochéa 14:2", "Yechayahou 40:31",
        "Eikha 3:23", "'Hayé Moharan 439", "Chiv'hei HaRan 10", "Inconnu 12", "", " ; ", " ;  ; ", "a ; b",
        "Likoutei Moharan II, Likoutei Moharan I, 3", "Michlé Michlé 1", "  Michlé 1", "Michlé 1",
    )

    private fun reference(ref: String): Map<String, Any?> = linkedMapOf(
        "ref" to ref,
        "connue" to Reference.connue(ref),
        "localisees" to languesRef.map { Reference.localise(ref, it) },
    )

    private val nombres: List<Int> = (-1..1100).toList() +
        listOf(-2, -15, -999, -1000, 1500, 9999, 10000, 123456, Int.MAX_VALUE, Int.MIN_VALUE)

    private fun references(): Map<String, Any?> = linkedMapOf(
        "nombres" to nombres,
        "lettres" to nombres.map { Reference.lettres(it) },
        "languesRef" to languesRef,
        "nombreDeRefsDesDonnees" to refsDesDonnees.size,
        // Chaque référence des données une seule fois, dans l'ordre de leur première apparition.
        "donnees" to refsDesDonnees.distinct().map { reference(it) },
        "manuelles" to refsManuelles.map { reference(it) },
    )

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursLangues.kt"),
        "regleLangue" to regle(),
        "languesTexte" to languesTexte(),
        "libraryRules" to regles(),
        "reference" to references(),
    )
}
