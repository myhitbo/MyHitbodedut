import Foundation
import Observation
import Coeur

// La bibliothèque (LibraryActivity.kt, LibrarySubSectionActivity.kt, LibraryEntryActivity.kt) : trois écrans
// empilés, chacun son modèle.
//
//  - `BibliothequeModele` : la liste. Sans livres (l'accueil, « Sources de la hitbodedout »), les sections de
//    bibliotheque.json et leurs sous-sections ; avec (`EXTRA_LIVRES`, « Livres »), les groupes de
//    livres_titres.json et leurs livres, qui s'ouvrent dans le lecteur, et la ligne des marque-pages.
//  - `BibliothequeSousSectionModele` : les entrées d'une sous-section, les sources d'abord (LibraryRules.ordered).
//  - `BibliothequeEntreeModele` : une entrée en entier. Une source montre ses paragraphes ; un article ne
//    montre qu'une fiche (résumé, lien), son texte intégral seulement s'il est autorisé (LibraryRules.fullText).
//
// La langue est celle de l'app (`Traducteur.langue`, « fr », « en » ou « he ») : `ChizukCard.language(context)`
// d'Android. Les réglages (adresse, police et langues de lecture, marque-pages) sont lus dans le `Magasin` à
// chaque fois : un changement fait ailleurs se voit ici.

/// Où en est un écran de la bibliothèque.
public enum BibliothequeEtat: Sendable, Equatable {
    /// Les contenus se lisent.
    case chargement
    case pret
    /// L'identifiant reçu ne désigne rien : Android ferme l'écran (`finish()`), la vue revient en arrière.
    case introuvable
    /// Le contenu n'a pu être lu (fichier absent ou illisible).
    case erreur
}

/// Les écrans qu'ouvre la bibliothèque, pour `NavigationLink(value:)` et `navigationDestination(for:)`.
public enum BibliothequeRoute: Sendable, Hashable {
    /// LibrarySubSectionActivity, `EXTRA_ID` : l'identifiant de la sous-section.
    case sousSection(String)
    /// LibraryEntryActivity, `EXTRA_ID` : l'identifiant de l'entrée.
    case entree(String)
    /// `SiddurLectureActivity.ouvrirLivre(id)` : le lecteur, sur un livre entier (`LIVRE` vrai).
    case livre(String)
    /// La feuille des marque-pages des livres (`RepriseFavoris.listeSignets`, recueil « l »).
    case marquesPagesLivres
}

/// Une ligne de la liste (LibraryActivity.Row).
public struct BibliothequeLigne: Sendable, Equatable, Identifiable {

    public enum Sorte: Sendable, Equatable {
        /// Le titre d'une section, ou d'un groupe de livres (item_library_section) : on ne le touche pas.
        case titre
        /// Une sous-section ou un livre (item_library_subsection) : une carte qu'on touche.
        case carte
    }

    /// « section:<id> », « sous:<id> », « groupe:<clé> » ou « livre:<id> » : unique dans la liste.
    public let id: String
    public let sorte: Sorte
    /// Le titre hébreu, de droite à gauche quelle que soit la langue.
    public let hebreu: String
    /// Sa traduction dans la langue de l'app ; nil quand elle répéterait l'hébreu ou serait vide (en hébreu).
    public let traduction: String?
    /// « 32 entrées », « 411 chapitres » ; nil pour un titre.
    public let compte: Libelle?
    /// L'illustration de la carte (char_tehilim, au féminin s'il le faut) ; nil pour un titre.
    public let image: String?
    /// Ce qu'ouvre la carte ; nil pour un titre.
    public let route: BibliothequeRoute?
}

/// La ligne « סימניות · n » au-dessus de la liste des livres (RepriseFavoris.ligneSignets(c, "l")).
public struct BibliothequeSignets: Sendable, Equatable {
    /// « Marque-pages », suivi dans la vue de « · » et du nombre.
    public let titre: Libelle
    public let nombre: Int
    /// L'icône des livres (`SiddurLectureActivity.icone(true)`), teinte de la couleur de marque.
    public let icone: String
    public let route: BibliothequeRoute
}

/// La liste de la bibliothèque : les sources de la hitbodedout, ou les livres entiers.
@MainActor
@Observable
public final class BibliothequeModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    /// « fr », « en » ou « he ».
    public let langue: String
    /// Vrai : les livres entiers (`EXTRA_LIVRES`, l'onglet Textes, « Livres ») ; faux : les sources.
    public let livresSeuls: Bool

    public private(set) var etat: BibliothequeEtat = .chargement
    private var bibliotheque: Bibliotheque?
    private var indexLivres: Siddur?

    public init(magasin: Magasin, contenus: ContenusApp, langue: String, livresSeuls: Bool) {
        self.magasin = magasin
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
        self.livresSeuls = livresSeuls
    }

    /// Lit la bibliothèque, ou l'index des livres (sans leur texte). À appeler à l'apparition de l'écran ; une
    /// seconde lecture ne coûte rien (les contenus sont gardés).
    public func charger() async {
        do {
            if livresSeuls {
                indexLivres = try await contenus.livres()
            } else {
                bibliotheque = try await contenus.bibliotheque()
            }
            etat = .pret
        } catch {
            etat = .erreur
        }
    }

    // MARK: Le bandeau

    /// « Livres » ou « Sources de la hitbodedout ».
    public var titre: Libelle {
        Libelle(livresSeuls ? "livres_title" : "library_title")
    }

    public var sousTitre: Libelle {
        Libelle(livresSeuls ? "livres_hint" : "library_hint")
    }

    /// Le personnage qui étudie (Character.STUDY), au féminin pour qui a choisi צדקת.
    public var image: String {
        Personnage.pour(adresse, Poses.study)
    }

    // MARK: La liste

    /// Les lignes dans l'ordre : chaque titre de section suivi de ses sous-sections, ou chaque titre de groupe
    /// suivi de ses livres. Vide tant que rien n'est lu.
    public var lignes: [BibliothequeLigne] {
        let imageCarte = Personnage.pour(adresse, Poses.reading)
        var resultat: [BibliothequeLigne] = []
        if livresSeuls {
            guard let index = indexLivres else { return [] }
            for groupe in index.groupes {
                resultat.append(BibliothequeLigne(
                    id: "groupe:" + groupe.cle, sorte: .titre, hebreu: groupe.titre.he,
                    traduction: BibliothequeLecture.traduction(groupe.titre, langue), compte: nil, image: nil, route: nil))
                for livre in index.du(groupe.cle) {
                    resultat.append(BibliothequeLigne(
                        id: "livre:" + livre.id, sorte: .carte, hebreu: livre.titre.he,
                        traduction: BibliothequeLecture.traduction(livre.titre, langue),
                        compte: Libelle.pluriel("livre_chapitres", quantite: livre.chapitres, .entier(livre.chapitres)),
                        image: imageCarte, route: .livre(livre.id)))
                }
            }
        } else {
            guard let bibliotheque else { return [] }
            for section in bibliotheque.sections {
                resultat.append(BibliothequeLigne(
                    id: "section:" + section.id, sorte: .titre, hebreu: section.titre.he,
                    traduction: BibliothequeLecture.traduction(section.titre, langue), compte: nil, image: nil, route: nil))
                for sous in section.sousSections {
                    resultat.append(BibliothequeLigne(
                        id: "sous:" + sous.id, sorte: .carte, hebreu: sous.titre.he,
                        traduction: BibliothequeLecture.traduction(sous.titre, langue),
                        compte: Libelle("library_entries_count", .entier(sous.entrees.count)),
                        image: imageCarte, route: .sousSection(sous.id)))
                }
            }
        }
        return resultat
    }

    // MARK: Les marque-pages des livres

    /// Les marque-pages posés dans un livre qui existe encore, dans l'ordre où ils sont gardés ; vide hors des
    /// livres. Relus à chaque fois : un marque-page posé dans le lecteur se compte au retour (onResume).
    public var signets: [MarquesPages.Marque] {
        guard livresSeuls, let index = indexLivres else { return [] }
        return BibliothequeLecture.marques(magasin.reglages).filter { marque in
            marque.cle.commenceParUnites("l:") && index.texte(marque.cle.apresUnites(":")) != nil
        }
    }

    /// La ligne des marque-pages ; nil sans marque-page (Android ne la pose pas).
    public var ligneSignets: BibliothequeSignets? {
        let nombre = signets.count
        guard nombre > 0 else { return nil }
        return BibliothequeSignets(titre: Libelle("marques_titre"), nombre: nombre, icone: "ic_marque_etude",
                                   route: .marquesPagesLivres)
    }

    private var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }
}

// MARK: - La sous-section

/// Une entrée dans la liste d'une sous-section (item_library_entry).
public struct BibliothequeEntreeLigne: Sendable, Equatable, Identifiable {
    public let id: String
    public let estSource: Bool
    /// « Source » ou « Article », dans la pastille menthe.
    public let nature: Libelle
    /// Le nom hébreu d'une source, le titre d'un article.
    public let titre: String
    /// Vrai pour une source : son titre se lit de droite à gauche, aligné au début, quelle que soit la langue.
    /// Faux pour un article : le sens de la langue de l'app.
    public let titreDroiteAGauche: Bool
    /// La référence d'une source dans la langue de l'app, le site et la date d'un article ; nil si vide.
    public let detail: String?
    /// char_torah pour une source, char_writing pour un article (au féminin s'il le faut).
    public let image: String
    public var route: BibliothequeRoute { .entree(id) }
}

/// Les entrées d'une sous-section : les sources d'abord, puis les articles (LibrarySubSectionActivity).
@MainActor
@Observable
public final class BibliothequeSousSectionModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    public let langue: String
    /// L'identifiant de la sous-section (`EXTRA_ID`).
    public let id: String

    public private(set) var etat: BibliothequeEtat = .chargement
    private var sousSection: SousSection?

    public init(magasin: Magasin, contenus: ContenusApp, langue: String, id: String) {
        self.magasin = magasin
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
        self.id = id
    }

    public func charger() async {
        do {
            let bibliotheque = try await contenus.bibliotheque()
            guard let trouvee = bibliotheque.sousSection(id) else {
                etat = .introuvable
                return
            }
            sousSection = trouvee
            etat = .pret
        } catch {
            etat = .erreur
        }
    }

    /// Le titre hébreu de la sous-section, en tête du bandeau ; vide tant que rien n'est lu.
    public var titre: String {
        sousSection?.titre.he ?? ""
    }

    /// Sa traduction ; nil quand elle répète l'hébreu (en hébreu, ou sans traduction).
    public var sousTitre: String? {
        guard let titre = sousSection?.titre else { return nil }
        let traduction = titre.pour(langue)
        return traduction.egalUnites(titre.he) ? nil : traduction
    }

    /// Le personnage qui lit (Character.READING).
    public var image: String {
        Personnage.pour(adresse, Poses.reading)
    }

    /// Les entrées, les sources d'abord ; l'ordre de chaque nature est celui du fichier.
    public var entrees: [BibliothequeEntreeLigne] {
        guard let sousSection else { return [] }
        let adresse = self.adresse
        let langue = self.langue
        return LibraryRules.ordered(sousSection.entrees).map { (entree: EntreeBibliotheque) -> BibliothequeEntreeLigne in
            switch entree {
            case .source(let source):
                return BibliothequeEntreeLigne(
                    id: source.id, estSource: true, nature: Libelle("library_kind_source"), titre: source.titreHe,
                    titreDroiteAGauche: true, detail: BibliothequeLecture.nonBlanc(Reference.localise(source.ref, langue)),
                    image: Personnage.pour(adresse, Poses.ofLibraryEntry(entree)))
            case .article(let article):
                return BibliothequeEntreeLigne(
                    id: article.id, estSource: false, nature: Libelle("library_kind_article"), titre: article.titre,
                    titreDroiteAGauche: false,
                    detail: BibliothequeLecture.nonBlanc(BibliothequeLecture.points([article.site, article.date])),
                    image: Personnage.pour(adresse, Poses.ofLibraryEntry(entree)))
            }
        }
    }

    private var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }
}

// MARK: - L'entrée

/// Un morceau du texte d'une source, dans l'ordre : l'hébreu d'un paragraphe, puis ses traductions.
public struct BibliothequeBloc: Sendable, Equatable, Identifiable {

    public enum Sorte: Sendable, Equatable {
        /// Un paragraphe hébreu : de droite à gauche, 17 pt, interligne 12, encre, police de lecture.
        case hebreu
        /// Une traduction, de gauche à droite, à empattements du système. Seule (le mode n'a pas l'hébreu) :
        /// 16 pt, couleur du texte ; sous l'hébreu : 14 pt, couleur discrète. Interligne 4.
        case traduction(langue: String, seule: Bool)
    }

    /// Le rang du bloc dans la page.
    public let id: Int
    /// Le rang du paragraphe d'où il vient.
    public let paragraphe: Int
    public let sorte: Sorte
    public let texte: String
    /// L'espace au-dessus, en points (les dp d'Android) : 0 en tête, 12 entre deux paragraphes, 6 sous l'hébreu.
    public let margeHaut: Int
}

/// Un couple « intitulé / contenu » de la carte des informations d'un article.
public struct BibliothequeFait: Sendable, Equatable, Identifiable {
    /// « Résumé » ou « Texte intégral » : 12 pt, couleur de marque.
    public let intitule: Libelle
    /// 15 pt, interligne 9, encre.
    public let texte: String
    public var id: String { intitule.cle }
}

/// Le bouton de sortie vers le web, sous la page.
public struct BibliothequeLien: Sendable, Equatable {
    /// « Ouvrir sur Sefaria » (une source) ou « Lire sur le site » (un article).
    public let titre: Libelle
    /// L'adresse telle que les données l'écrivent.
    public let adresse: String
    /// nil : l'adresse ne se lit pas comme une URL. Le bouton reste, comme sur Android ; le toucher signale
    /// l'échec (`ouvertureEchouee`).
    public let url: URL?
}

/// Une entrée en entier (LibraryEntryActivity) : une source et ses paragraphes, ou la fiche d'un article.
@MainActor
@Observable
public final class BibliothequeEntreeModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    public let langue: String
    /// L'identifiant de l'entrée (`EXTRA_ID`).
    public let id: String

    public private(set) var etat: BibliothequeEtat = .chargement
    /// Le message à montrer quand l'adresse n'a pu s'ouvrir (le Toast d'Android) ; nil sinon.
    public private(set) var alerte: Libelle?
    private var bibliotheque: Bibliotheque?
    private var entree: EntreeBibliotheque?

    public init(magasin: Magasin, contenus: ContenusApp, langue: String, id: String) {
        self.magasin = magasin
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
        self.id = id
    }

    public func charger() async {
        do {
            let lue = try await contenus.bibliotheque()
            guard let trouvee = lue.entree(id) else {
                etat = .introuvable
                return
            }
            bibliotheque = lue
            entree = trouvee
            etat = .pret
        } catch {
            etat = .erreur
        }
    }

    // MARK: Le bandeau (sans image : pas d'image pendant une lecture, demande du 13/10)

    /// Vrai pour une source, faux pour un article ou tant que rien n'est lu.
    public var estSource: Bool {
        if case .source? = entree { return true }
        return false
    }

    /// « Source » ou « Article », dans la pastille translucide du bandeau ; nil tant que rien n'est lu.
    public var nature: Libelle? {
        switch entree {
        case .source?: return Libelle("library_kind_source")
        case .article?: return Libelle("library_kind_article")
        case nil: return nil
        }
    }

    /// Le titre, en blanc, gras, 21 pt, dans la police hébraïque de lecture (ses signes absents masqués).
    public var titre: String {
        switch entree {
        case .source(let source)?: return PoliceHebraique.masque(source.titreHe, police: police)
        case .article(let article)?: return PoliceHebraique.masque(article.titre, police: police)
        case nil: return ""
        }
    }

    /// Vrai pour une source : son titre se lit de droite à gauche, aligné au début. Un article garde le sens
    /// de la langue de l'app.
    public var titreDroiteAGauche: Bool {
        estSource
    }

    /// La référence d'une source dans la langue de l'app ; l'auteur, le site et la date d'un article, séparés
    /// de « · ». nil si vide.
    public var reference: String? {
        switch entree {
        case .source(let source)?:
            return BibliothequeLecture.nonBlanc(Reference.localise(source.ref, langue))
        case .article(let article)?:
            return BibliothequeLecture.nonBlanc(BibliothequeLecture.points([article.auteur, article.site, article.date]))
        case nil:
            return nil
        }
    }

    // MARK: Le texte d'une source

    /// Vrai pour une source : la carte des paragraphes est montrée, et le bouton de lecture (taille, fond noir,
    /// police, langues) est posé sur la page.
    public var paragraphesVisibles: Bool {
        estSource
    }

    /// Les blocs d'une source, dans la forme que sa licence permet (LibraryRules.paragraphs) et dans les langues
    /// de lecture choisies (LanguesTexte) ; vide pour un article.
    public var blocs: [BibliothequeBloc] {
        guard case .source(let source)? = entree, let bibliotheque else { return [] }
        let mode = modeLangues
        let police = self.police
        var resultat: [BibliothequeBloc] = []
        for (index, paragraphe) in LibraryRules.paragraphs(bibliotheque, source).enumerated() {
            let fr: String? = index < source.paragraphesFr.count ? source.paragraphesFr[index] : nil
            let en: String? = index < source.paragraphesEn.count ? source.paragraphesEn[index] : nil
            let textes = LanguesTexte.textes(mode, paragraphe, fr, en)
            let avecHebreu = textes.contains { $0.langue.egalUnites("he") }
            if avecHebreu {
                resultat.append(BibliothequeBloc(
                    id: resultat.count, paragraphe: index, sorte: .hebreu,
                    texte: PoliceHebraique.masque(paragraphe, police: police), margeHaut: index == 0 ? 0 : 12))
            }
            var rang = 0
            for texte in textes where !texte.langue.egalUnites("he") {
                let marge = (avecHebreu || rang > 0) ? 6 : (index == 0 ? 0 : 12)
                resultat.append(BibliothequeBloc(
                    id: resultat.count, paragraphe: index, sorte: .traduction(langue: texte.langue, seule: !avecHebreu),
                    texte: texte.texte, margeHaut: marge))
                rang += 1
            }
        }
        return resultat
    }

    // MARK: La fiche d'un article

    /// Le résumé dans la langue de l'app seulement (RegleLangue), puis le texte intégral s'il est autorisé.
    /// Les droits et les erreurs relevées ne sont plus montrés (demande du 19/10). Vide pour une source :
    /// la carte des informations est alors cachée.
    public var faits: [BibliothequeFait] {
        guard case .article(let article)? = entree else { return [] }
        var resultat: [BibliothequeFait] = []
        if let resume = LibraryRules.summary(article, langue), !resume.estBlanc {
            resultat.append(BibliothequeFait(intitule: Libelle("library_summary"), texte: resume))
        }
        if let integral = LibraryRules.fullText(article), !integral.estBlanc {
            resultat.append(BibliothequeFait(intitule: Libelle("library_full_text"), texte: integral))
        }
        return resultat
    }

    /// Le bouton vers Sefaria (une source) ou vers le site (un article) ; nil sans adresse.
    public var lien: BibliothequeLien? {
        let titre: String
        let adresse: String?
        switch entree {
        case .source(let source)?:
            titre = "library_open_sefaria"
            adresse = source.url
        case .article(let article)?:
            titre = "library_read_on_site"
            adresse = article.url
        case nil:
            return nil
        }
        guard let adresse, !adresse.estBlanc else { return nil }
        return BibliothequeLien(titre: Libelle(titre), adresse: adresse, url: URL(string: adresse))
    }

    /// L'adresse n'a pu s'ouvrir (`openURL` a refusé, ou l'URL ne se lit pas) : « Cet écran n'existe pas sur ce
    /// téléphone », comme le Toast d'Android.
    public func ouvertureEchouee() {
        alerte = Libelle("settings_screen_missing")
    }

    public func fermerAlerte() {
        alerte = nil
    }

    // MARK: La lecture (ReglagesLecture, PoliceHebraique)

    /// La police hébraïque des réglages de lecture, pour le titre et les paragraphes hébreux.
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    /// La taille des lettres de lecture (0,8 à 2), qui multiplie celle des blocs.
    public var echelle: Float {
        magasin.reglages.lectureEchelle
    }

    /// La lecture sur fond noir (la lune de la barre de lecture).
    public var lectureSombre: Bool {
        magasin.reglages.lectureSombre
    }

    /// Les langues de lecture : le choix enregistré, sinon celles de la langue de l'app.
    public var modeLangues: LanguesTexte.Mode {
        BibliothequeLecture.mode(magasin.reglages, langue: langue)
    }
}

// MARK: - Les aides communes

/// Ce que les écrans de la bibliothèque et du 'hizouk lisent de la même façon.
enum BibliothequeLecture {

    /// `bindTranslation` : la traduction d'un titre ; nil quand elle répète l'hébreu ou qu'elle est blanche.
    static func traduction(_ titre: TexteLocalise, _ langue: String) -> String? {
        let texte = titre.pour(langue)
        if texte.egalUnites(titre.he) || texte.estBlanc { return nil }
        return texte
    }

    /// `listOfNotNull(…).joinToString(" · ")`.
    static func points(_ morceaux: [String?]) -> String {
        morceaux.compactMap { $0 }.joined(separator: " · ")
    }

    /// nil pour un texte blanc (`isNullOrBlank` qui cache la vue).
    static func nonBlanc(_ texte: String) -> String? {
        texte.estBlanc ? nil : texte
    }

    /// `LanguesTexte.mode(context)` : le choix enregistré (`lecture_langues`), sinon le mode de la langue de l'app.
    static func mode(_ reglages: Reglages, langue: String) -> LanguesTexte.Mode {
        if let cle = reglages.lectureLangues, let mode = LanguesTexte.Mode(rawValue: cle) {
            return mode
        }
        return LanguesTexte.defaut(langue)
    }

    /// `Store.marques` : les marque-pages gardés sous « marques_pages » (MarquesPages.encoder).
    static func marques(_ reglages: Reglages) -> [MarquesPages.Marque] {
        if case .chaine(let texte)? = reglages.brut["marques_pages"] {
            return MarquesPages.decoder(texte)
        }
        return []
    }
}
