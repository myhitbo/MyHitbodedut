import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les trois écrans de la bibliothèque (LibraryActivity, LibrarySubSectionActivity, LibraryEntryActivity) : ce
/// que chaque liste montre et dans quel ordre, et ce qu'une entrée a le droit d'afficher. Sur les contenus
/// exportés du dépôt, et sur une petite bibliothèque écrite ici pour les cas que les données n'ont pas (un
/// article autorisé, une traduction manquante, un signe que la police n'a pas).
///
/// Restent au test d'interface : l'ouverture d'une adresse (`openURL`) et son échec réel, la barre de lecture,
/// le défilement, les marges et les polices à l'écran.
@Suite("Modèle de la bibliothèque")
@MainActor
struct BibliothequeModeleTests {

    /// Un seul acteur pour la suite : chaque contenu n'est lu qu'une fois.
    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    /// Une bibliothèque minuscule : deux sources (une édition vocalisée, une non), deux articles (l'un avec un
    /// texte intégral sans autorisation, l'autre autorisé), dans le désordre.
    private static let petite = """
    {"_meta": {"version": "t", "editions": {
        "pd": {"titre": "PD", "licence": "Public Domain", "nikkoud_ok": true},
        "sans": {"titre": "S", "licence": "non déclarée", "nikkoud_ok": false}}},
     "sections": [{"id": "s", "titre": {"he": "שיחה", "fr": "Conversation", "en": ""}, "sous_sections": [
       {"id": "ss", "titre": {"he": "תת", "fr": "Sous", "en": "Sub"}, "entrees": [
         {"type": "article", "id": "a1", "titre": "מאמר", "site": "אתר", "date": "2024",
          "url": "https://exemple.org/a1", "resume_fr": "Résumé", "resume_en": "Summary",
          "texte_integral": "Le texte entier"},
         {"type": "source", "id": "s1", "titre_he": "מקור", "ref": "Tehilim 51:19", "edition": "pd",
          "url": "https://www.sefaria.org/Psalms.51.19", "paragraphes": ["\u{05D0}\u{05B8}\u{05BD}", "\u{05D1}\u{05BC}"],
          "paragraphes_sans_nikkoud": ["א", "ב"], "paragraphes_fr": ["A", ""], "paragraphes_en": ["A-en"]},
         {"type": "article", "id": "a2", "titre": "שני", "auteur": "Auteur",
          "autorisation": "accord écrit du 1er janvier", "texte_integral": "Texte autorisé", "resume_he": "תקציר"},
         {"type": "source", "id": "s2", "titre_he": "שני", "ref": "", "edition": "sans",
          "paragraphes": ["\u{05D2}\u{05BC}\u{05B8}"], "paragraphes_sans_nikkoud": ["ג"]}
       ]}]}]}
    """

    /// Le premier paragraphe de s1 : alef, qamats et meteg (U+05BD), que la police à empattements n'a pas.
    private static let alefMeteg = "\u{05D0}\u{05B8}\u{05BD}"

    private static func contenusEcrits(_ json: String) -> ContenusApp {
        let donnees = Data(json.utf8)
        return ContenusApp(lecteur: { chemin in chemin == "bibliotheque.json" ? donnees : nil })
    }

    private static func magasin(_ reglages: Reglages = Reglages()) -> Magasin {
        Magasin.enMemoire(Enregistrement(reglages: reglages))
    }

    private static func entree(_ id: String, langue: String = "fr", reglages: Reglages = Reglages())
        async -> BibliothequeEntreeModele {
        let modele = BibliothequeEntreeModele(magasin: magasin(reglages), contenus: contenusEcrits(petite),
                                              langue: langue, id: id)
        await modele.charger()
        return modele
    }

    // MARK: La liste des sources

    @Test func lesSourcesMontrentChaqueSectionPuisSesSousSections() async throws {
        let modele = BibliothequeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "fr", livresSeuls: false)
        #expect(modele.etat == .chargement)
        await modele.charger()
        #expect(modele.etat == .pret)
        let bibliotheque = try await Self.contenus.bibliotheque()
        let lignes = modele.lignes
        let ids = lignes.map { $0.id }
        #expect(ids == ["section:sichat-chaverim", "sous:hitbodedut-ma-velama", "section:tefilot", "sous:tefilot-lt"])
        let sortes = lignes.map { $0.sorte }
        #expect(sortes == [.titre, .carte, .titre, .carte])

        let section = try #require(bibliotheque.sections.first)
        #expect(lignes[0].hebreu == section.titre.he)
        #expect(lignes[0].traduction == "Conversation entre amis")
        #expect(lignes[0].compte == nil)
        #expect(lignes[0].route == nil)

        let sous = try #require(bibliotheque.sousSection("hitbodedut-ma-velama"))
        #expect(lignes[1].hebreu == sous.titre.he)
        #expect(lignes[1].traduction == sous.titre.fr)
        #expect(lignes[1].compte == Libelle("library_entries_count", .entier(32)))
        #expect(lignes[1].route == .sousSection("hitbodedut-ma-velama"))
        #expect(lignes[1].image == "char_tehilim")

        #expect(modele.titre == Libelle("library_title"))
        #expect(modele.sousTitre == Libelle("library_hint"))
        #expect(modele.image == "char_torah")
        // Hors des livres, pas de ligne des marque-pages.
        #expect(modele.ligneSignets == nil)
    }

    @Test func enHebreuAucuneTraductionNeRepeteLeTitre() async {
        let modele = BibliothequeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "he", livresSeuls: false)
        await modele.charger()
        let traductions = modele.lignes.compactMap { $0.traduction }
        #expect(traductions.isEmpty)
        // « iw », l'ancien code de l'hébreu, se lit « he ».
        let ancien = BibliothequeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "iw", livresSeuls: false)
        #expect(ancien.langue == "he")
    }

    @Test func uneTraductionBlancheEstCachee() async {
        let modele = BibliothequeModele(magasin: Self.magasin(), contenus: Self.contenusEcrits(Self.petite),
                                        langue: "en", livresSeuls: false)
        await modele.charger()
        let lignes = modele.lignes
        #expect(lignes.count == 2)
        // La section n'a pas d'anglais : la traduction répéterait l'hébreu.
        #expect(lignes[0].traduction == nil)
        #expect(lignes[1].traduction == "Sub")
        #expect(lignes[1].compte == Libelle("library_entries_count", .entier(4)))
    }

    @Test func leComptedesEntreesSeLitDansLaLangue() async throws {
        let modele = BibliothequeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "fr", livresSeuls: false)
        await modele.charger()
        let compte = try #require(modele.lignes[1].compte)
        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: "fr")
        #expect(traducteur.texte(compte) == "32 entrées")
    }

    @Test func unContenuIlisibleSeDitEnErreur() async {
        let vide = ContenusApp(lecteur: { _ in nil })
        let sources = BibliothequeModele(magasin: Self.magasin(), contenus: vide, langue: "fr", livresSeuls: false)
        await sources.charger()
        #expect(sources.etat == .erreur)
        #expect(sources.lignes.isEmpty)
        let livres = BibliothequeModele(magasin: Self.magasin(), contenus: vide, langue: "fr", livresSeuls: true)
        await livres.charger()
        #expect(livres.etat == .erreur)
        let sous = BibliothequeSousSectionModele(magasin: Self.magasin(), contenus: vide, langue: "fr", id: "ss")
        await sous.charger()
        #expect(sous.etat == .erreur)
        let entree = BibliothequeEntreeModele(magasin: Self.magasin(), contenus: vide, langue: "fr", id: "s1")
        await entree.charger()
        #expect(entree.etat == .erreur)
    }

    @Test func lePersonnageAuFeminin() async {
        var reglages = Reglages()
        reglages.setAdresse("f")
        let modele = BibliothequeModele(magasin: Self.magasin(reglages), contenus: Self.contenus, langue: "fr",
                                        livresSeuls: false)
        await modele.charger()
        #expect(modele.image == Personnage.feminin("char_torah"))
        #expect(modele.lignes[1].image == Personnage.feminin("char_tehilim"))
        #expect(modele.image != "char_torah")
    }

    // MARK: La liste des livres

    @Test func lesLivresParGroupeEtLeurNombreDeChapitres() async throws {
        let modele = BibliothequeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "fr", livresSeuls: true)
        await modele.charger()
        #expect(modele.etat == .pret)
        #expect(modele.titre == Libelle("livres_title"))
        #expect(modele.sousTitre == Libelle("livres_hint"))
        let index = try await Self.contenus.livres()
        var attendus: [String] = []
        for groupe in index.groupes {
            attendus.append("groupe:" + groupe.cle)
            attendus += index.du(groupe.cle).map { "livre:" + $0.id }
        }
        let ids = modele.lignes.map { $0.id }
        #expect(ids == attendus)
        #expect(ids.count == 15)
        #expect(ids.first == "groupe:livres")
        #expect(ids.last == "livre:yalkut_yosef_kitsour")

        let trouve = modele.lignes.first { $0.id == "livre:likoutei_moharan" }
        let moharan = try #require(trouve)
        let texte = try #require(index.texte("likoutei_moharan"))
        #expect(moharan.sorte == .carte)
        #expect(moharan.hebreu == texte.titre.he)
        #expect(moharan.traduction == "Likoutei Moharan")
        #expect(moharan.compte == Libelle.pluriel("livre_chapitres", quantite: 411, .entier(411)))
        #expect(moharan.route == .livre("likoutei_moharan"))
        let groupe = try #require(modele.lignes.first)
        #expect(groupe.sorte == .titre)
        #expect(groupe.traduction == "Livres")
    }

    @Test func unLivreDUnSeulChapitreAuSingulier() async throws {
        let modele = BibliothequeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "he", livresSeuls: true)
        await modele.charger()
        let trouve = modele.lignes.first { $0.id == "livre:nichmat" }
        let nichmat = try #require(trouve)
        let compte = try #require(nichmat.compte)
        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: "he")
        let attendu = try #require(CatalogueBrut.lire().forme("livre_chapitres", "one", langue: "he"))
        #expect(traducteur.texte(compte) == attendu)
    }

    @Test func lesMarquePagesDesLivresSeComptentEnTete() async throws {
        let marques = [
            MarquesPages.Marque(cle: "l:likoutei_moharan", nusah: "edot", section: 3, bloc: 0, apercu: "אשרי"),
            MarquesPages.Marque(cle: "s:birkot_hachahar", nusah: "edot", section: 0, bloc: 2, apercu: "ברוך"),
            MarquesPages.Marque(cle: "l:livre_disparu", nusah: "edot", section: 1, bloc: 1, apercu: "x"),
            MarquesPages.Marque(cle: "l:nichmat", nusah: "edot", section: 0, bloc: 4, apercu: "נשמת"),
        ]
        let reglages = Reglages(brut: ObjetJSON([("marques_pages", JSON.chaine(MarquesPages.encoder(marques)))]))
        let modele = BibliothequeModele(magasin: Self.magasin(reglages), contenus: Self.contenus, langue: "fr",
                                        livresSeuls: true)
        // Avant la lecture de l'index, rien ne se compte.
        #expect(modele.ligneSignets == nil)
        await modele.charger()
        let cles = modele.signets.map { $0.cle }
        #expect(cles == ["l:likoutei_moharan", "l:nichmat"])
        let ligne = try #require(modele.ligneSignets)
        #expect(ligne.nombre == 2)
        #expect(ligne.titre == Libelle("marques_titre"))
        #expect(ligne.icone == "ic_marque_etude")
        #expect(ligne.route == .marquesPagesLivres)
    }

    @Test func unMarquePagePoseAilleursSeCompteAuRetour() async throws {
        let magasin = Self.magasin()
        let modele = BibliothequeModele(magasin: magasin, contenus: Self.contenus, langue: "fr", livresSeuls: true)
        await modele.charger()
        #expect(modele.ligneSignets == nil)
        let marque = MarquesPages.Marque(cle: "l:kokhvei_or", nusah: "edot", section: 2, bloc: 0, apercu: "x")
        let texte = MarquesPages.encoder([marque])
        try await magasin.modifierReglages { reglages in
            var brut = reglages.brut
            brut["marques_pages"] = .chaine(texte)
            reglages = Reglages(brut: brut)
        }
        #expect(modele.ligneSignets?.nombre == 1)
    }

    // MARK: La sous-section

    @Test func lesSourcesDAbordPuisLesArticles() async throws {
        let modele = BibliothequeSousSectionModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "fr",
                                                   id: "hitbodedut-ma-velama")
        await modele.charger()
        #expect(modele.etat == .pret)
        let bibliotheque = try await Self.contenus.bibliotheque()
        let sous = try #require(bibliotheque.sousSection("hitbodedut-ma-velama"))
        let attendus = LibraryRules.ordered(sous.entrees).map { $0.id }
        let entrees = modele.entrees
        let ids = entrees.map { $0.id }
        #expect(ids == attendus)
        #expect(entrees.count == 32)
        let natures = entrees.map { $0.estSource }
        #expect(natures == Array(repeating: true, count: 8) + Array(repeating: false, count: 24))
        #expect(modele.titre == sous.titre.he)
        #expect(modele.sousTitre == sous.titre.fr)
        #expect(modele.image == "char_tehilim")

        let premiere = try #require(entrees.first)
        #expect(premiere.id == "src-lm2-25")
        #expect(premiere.nature == Libelle("library_kind_source"))
        #expect(premiere.titreDroiteAGauche)
        #expect(premiere.detail == Reference.localise("Likoutei Moharan II, 25", "fr"))
        #expect(premiere.image == "char_torah")
        #expect(premiere.route == .entree("src-lm2-25"))

        let trouve = entrees.first { $0.id == "art-pgisha-01" }
        let pgisha = try #require(trouve)
        guard case .article(let article)? = bibliotheque.entree("art-pgisha-01") else {
            Issue.record("art-pgisha-01 n'est pas un article")
            return
        }
        let site = try #require(article.site)
        let date = try #require(article.date)
        #expect(pgisha.nature == Libelle("library_kind_article"))
        #expect(!pgisha.titreDroiteAGauche)
        #expect(pgisha.titre == article.titre)
        #expect(pgisha.detail == site + " · " + date)
        #expect(pgisha.image == "char_writing")
        // Ni site ni date : pas de détail.
        let sansDetail = entrees.first { $0.id == "art-abn-1-68" }
        let abn = try #require(sansDetail)
        #expect(abn.detail == nil)
    }

    @Test func enHebreuLaReferenceEtLeTitreSansTraduction() async throws {
        let modele = BibliothequeSousSectionModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "he",
                                                   id: "hitbodedut-ma-velama")
        await modele.charger()
        #expect(modele.sousTitre == nil)
        let premiere = try #require(modele.entrees.first)
        #expect(premiere.detail == Reference.localise("Likoutei Moharan II, 25", "he"))
        #expect(premiere.detail != "Likoutei Moharan II, 25")
    }

    @Test func lOrdreDesNaturesGardeCeluiDuFichier() async {
        let modele = BibliothequeSousSectionModele(magasin: Self.magasin(), contenus: Self.contenusEcrits(Self.petite),
                                                   langue: "fr", id: "ss")
        await modele.charger()
        let ids = modele.entrees.map { $0.id }
        #expect(ids == ["s1", "s2", "a1", "a2"])
        let details = modele.entrees.map { $0.detail }
        #expect(details == ["Tehilim 51:19", nil, "אתר · 2024", nil])
        #expect(modele.titre == "תת")
        #expect(modele.sousTitre == "Sous")
    }

    @Test func uneSousSectionInconnueFermeLEcran() async {
        let modele = BibliothequeSousSectionModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "fr",
                                                   id: "n-existe-pas")
        await modele.charger()
        #expect(modele.etat == .introuvable)
        #expect(modele.entrees.isEmpty)
        #expect(modele.titre == "")
    }

    // MARK: Une source

    @Test func uneSourceMontreSesParagraphesSousLHebreu() async throws {
        let modele = await Self.entree("s1")
        #expect(modele.etat == .pret)
        #expect(modele.estSource)
        #expect(modele.paragraphesVisibles)
        #expect(modele.nature == Libelle("library_kind_source"))
        #expect(modele.titreDroiteAGauche)
        #expect(modele.reference == "Tehilim 51:19")
        #expect(modele.modeLangues == .heFr)
        let blocs = modele.blocs
        let sortes = blocs.map { $0.sorte }
        // Le second paragraphe n'a pas de français : son hébreu seul.
        #expect(sortes == [.hebreu, .traduction(langue: "fr", seule: false), .hebreu])
        let marges = blocs.map { $0.margeHaut }
        #expect(marges == [0, 6, 12])
        let paragraphes = blocs.map { $0.paragraphe }
        #expect(paragraphes == [0, 0, 1])
        #expect(blocs[1].texte == "A")
        // L'édition est vocalisée ; le meteg, que la police à empattements n'a pas, est masqué.
        #expect(blocs[0].texte == PoliceHebraique.masque(Self.alefMeteg, police: .serif))
        #expect(blocs[0].texte != Self.alefMeteg)
        #expect(blocs[2].texte == "\u{05D1}\u{05BC}")
        // Pas de fiche pour une source, et le lien vers Sefaria.
        #expect(modele.faits.isEmpty)
        let lien = try #require(modele.lien)
        #expect(lien.titre == Libelle("library_open_sefaria"))
        #expect(lien.adresse == "https://www.sefaria.org/Psalms.51.19")
        #expect(lien.url == URL(string: "https://www.sefaria.org/Psalms.51.19"))
    }

    @Test func lesLanguesDeLectureChoisies() async {
        var francais = Reglages()
        francais.setLectureLangues("fr")
        let seul = await Self.entree("s1", reglages: francais)
        let sortes = seul.blocs.map { $0.sorte }
        // Le second paragraphe n'a rien en français : l'hébreu seul, comme LanguesTexte.textes le veut.
        #expect(sortes == [.traduction(langue: "fr", seule: true), .hebreu])
        let marges = seul.blocs.map { $0.margeHaut }
        #expect(marges == [0, 12])

        var deux = Reglages()
        deux.setLectureLangues("fr+en")
        let traductions = await Self.entree("s1", reglages: deux)
        let sortesDeux = traductions.blocs.map { $0.sorte }
        #expect(sortesDeux == [.traduction(langue: "fr", seule: true), .traduction(langue: "en", seule: true), .hebreu])
        let margesDeux = traductions.blocs.map { $0.margeHaut }
        #expect(margesDeux == [0, 6, 12])

        // En hébreu, par défaut, rien que l'hébreu.
        let hebreu = await Self.entree("s1", langue: "he")
        #expect(hebreu.modeLangues == .he)
        let sortesHe = hebreu.blocs.map { $0.sorte }
        #expect(sortesHe == [.hebreu, .hebreu])

        // En anglais, l'hébreu et l'anglais ; le second paragraphe n'en a pas.
        let anglais = await Self.entree("s1", langue: "en")
        let sortesEn = anglais.blocs.map { $0.sorte }
        #expect(sortesEn == [.hebreu, .traduction(langue: "en", seule: false), .hebreu])
        #expect(anglais.blocs[1].texte == "A-en")
    }

    @Test func uneEditionSansLicenceDeVocalisationMontreLeTexteNu() async {
        let modele = await Self.entree("s2", langue: "he")
        let textes = modele.blocs.map { $0.texte }
        #expect(textes == ["ג"])
        // Sans référence, la ligne est cachée ; sans adresse, pas de bouton.
        #expect(modele.reference == nil)
        #expect(modele.lien == nil)
    }

    @Test func laPoliceDeLectureMasqueSesSignesAbsents() async {
        var reglages = Reglages()
        reglages.setLecturePolice("frank")
        let modele = await Self.entree("s1", langue: "he", reglages: reglages)
        #expect(modele.police == .frank)
        #expect(modele.titre == PoliceHebraique.masque("מקור", police: .frank))
        #expect(modele.blocs.first?.texte == PoliceHebraique.masque(Self.alefMeteg, police: .frank))
    }

    @Test func lesSourcesDuDepotSeLisentEnEntier() async throws {
        let bibliotheque = try await Self.contenus.bibliotheque()
        var sources = 0
        for entree in bibliotheque.entrees {
            guard case .source(let source) = entree else { continue }
            sources += 1
            let modele = BibliothequeEntreeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: "fr",
                                                  id: source.id)
            await modele.charger()
            let hebreux = modele.blocs.filter { $0.sorte == .hebreu }.map { $0.texte }
            let attendus = LibraryRules.paragraphs(bibliotheque, source).map { PoliceHebraique.masque($0, police: .serif) }
            #expect(hebreux == attendus, "\(source.id)")
            #expect(modele.lien?.titre == Libelle("library_open_sefaria"), "\(source.id)")
            #expect(modele.faits.isEmpty, "\(source.id)")
        }
        #expect(sources == 29)
    }

    // MARK: Un article : sa fiche seulement

    @Test func unArticleProtegeNeMontreQueSaFiche() async throws {
        let modele = await Self.entree("a1")
        #expect(modele.etat == .pret)
        #expect(!modele.estSource)
        #expect(!modele.paragraphesVisibles)
        #expect(modele.nature == Libelle("library_kind_article"))
        #expect(!modele.titreDroiteAGauche)
        #expect(modele.titre == PoliceHebraique.masque("מאמר", police: .serif))
        #expect(modele.reference == "אתר · 2024")
        #expect(modele.blocs.isEmpty)
        // Le texte intégral est dans les données, mais rien ne l'autorise : le résumé seul.
        let faits = modele.faits
        #expect(faits == [BibliothequeFait(intitule: Libelle("library_summary"), texte: "Résumé")])
        let lien = try #require(modele.lien)
        #expect(lien.titre == Libelle("library_read_on_site"))
        #expect(lien.url == URL(string: "https://exemple.org/a1"))
    }

    @Test func leResumeNeSeMontreQueDansLaLangueDeLApp() async {
        let anglais = await Self.entree("a1", langue: "en")
        #expect(anglais.faits == [BibliothequeFait(intitule: Libelle("library_summary"), texte: "Summary")])
        // Pas de résumé en hébreu, et aucun repli : la carte des informations est cachée.
        let hebreu = await Self.entree("a1", langue: "he")
        #expect(hebreu.faits.isEmpty)
    }

    @Test func unArticleAutoriseMontreSonTexteIntegral() async {
        let hebreu = await Self.entree("a2", langue: "he")
        #expect(hebreu.faits == [
            BibliothequeFait(intitule: Libelle("library_summary"), texte: "תקציר"),
            BibliothequeFait(intitule: Libelle("library_full_text"), texte: "Texte autorisé"),
        ])
        let francais = await Self.entree("a2")
        #expect(francais.faits == [BibliothequeFait(intitule: Libelle("library_full_text"), texte: "Texte autorisé")])
        #expect(francais.reference == "Auteur")
        #expect(francais.lien == nil)
    }

    @Test func aucunArticleDuDepotNeMontreSonTexte() async throws {
        let bibliotheque = try await Self.contenus.bibliotheque()
        var articles = 0
        for entree in bibliotheque.entrees {
            guard case .article(let article) = entree else { continue }
            articles += 1
            for langue in Traducteur.langues {
                let modele = BibliothequeEntreeModele(magasin: Self.magasin(), contenus: Self.contenus, langue: langue,
                                                      id: article.id)
                await modele.charger()
                #expect(modele.etat == .pret, "\(article.id)")
                #expect(modele.blocs.isEmpty, "\(article.id)")
                let intitules = modele.faits.map { $0.intitule.cle }
                #expect(intitules == ["library_summary"], "\(article.id) \(langue)")
                #expect(modele.lien?.titre != Libelle("library_open_sefaria"), "\(article.id)")
            }
        }
        #expect(articles == 24)
    }

    @Test func uneEntreeInconnueFermeLEcran() async {
        let modele = await Self.entree("n-existe-pas")
        #expect(modele.etat == .introuvable)
        #expect(modele.nature == nil)
        #expect(modele.titre == "")
        #expect(modele.blocs.isEmpty)
        #expect(modele.lien == nil)
    }

    @Test func uneAdresseQuiNeSOuvrePasLeDit() async {
        let modele = await Self.entree("s1")
        #expect(modele.alerte == nil)
        modele.ouvertureEchouee()
        #expect(modele.alerte == Libelle("settings_screen_missing"))
        modele.fermerAlerte()
        #expect(modele.alerte == nil)
    }

    // MARK: Les chaînes

    @Test func chaqueCleDesEcransEstDansLeCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        let simples = [
            "library_title", "library_hint", "livres_title", "livres_hint", "library_entries_count", "marques_titre",
            "library_kind_source", "library_kind_article", "library_open_sefaria", "library_read_on_site",
            "library_summary", "library_full_text", "settings_screen_missing",
        ]
        for cle in simples {
            for langue in Traducteur.langues {
                let valeur = catalogue.valeur(cle, langue: langue)
                #expect(valeur != nil, "\(cle) \(langue)")
            }
        }
        for langue in Traducteur.langues {
            let pluriel = catalogue.forme("livre_chapitres", "other", langue: langue)
            #expect(pluriel != nil, "livre_chapitres \(langue)")
        }
    }
}
