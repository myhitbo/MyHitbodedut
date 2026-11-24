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
    /// `SiddurLectureActivity.ouvrirLivre(id)` : le lecteur, sur un livre entier (`ID` = id, `LIVRE` vrai).
    case livre(String)
    /// `SiddurLectureActivity.ouvrirMarque(m)` pour un marque-page de livre : le lecteur sur le livre `id`
    /// (`LIVRE` vrai), à sa place (`MARQUE` = « section:bloc »).
    case marque(livre: String, section: Int, bloc: Int)
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

/// La ligne « סימניות · n  › » au-dessus de la liste des livres (RepriseFavoris.ligneSignets(c, "l")) : la
/// toucher ouvre la feuille des marque-pages (`BibliothequeModele.ouvrirSignets`).
public struct BibliothequeSignets: Sendable, Equatable {
    /// « Marque-pages », suivi dans la vue de « · », du nombre, puis de deux espaces et « › ».
    public let titre: Libelle
    public let nombre: Int
    /// L'icône des livres (`SiddurLectureActivity.icone(true)`), teinte de la couleur de marque, 18 pt, en fin
    /// de ligne.
    public let icone: String
}

/// Une puce de la feuille des marque-pages (RepriseFavoris.listeSignets) : tous, les livres, ou un livre.
public struct BibliothequeFiltreSignets: Sendable, Equatable, Identifiable {
    /// « * » (tous), « l » (les livres) ou « l:<id> » (un livre).
    public let id: String
    /// Le nom d'une puce générale (« Tout », « Livres ») ; nil pour la puce d'un livre.
    public let libelle: Libelle?
    /// Le titre hébreu d'un livre, dans la police de lecture (ses signes absents masqués) ; nil pour une puce
    /// générale.
    public let titre: String?
}

/// Un marque-page dans la feuille : le livre en petit, les premiers mots du paragraphe dessous.
public struct BibliothequeSignetLigne: Sendable, Equatable, Identifiable {
    /// Son rang parmi les marque-pages des livres (`BibliothequeModele.signets`) : unique.
    public let id: Int
    /// Le titre hébreu du livre (13 pt, discret, de droite à gauche, police de lecture), signes absents masqués.
    public let titre: String
    /// Les premiers mots suivis de « … » (17 pt, encre, une ligne, de droite à gauche, police de lecture).
    public let apercu: String
    /// L'icône des livres, 14 pt, teinte de la couleur de marque, après le titre.
    public let icone: String
    /// Le lecteur, à la place du marque-page.
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
    /// La feuille des marque-pages est ouverte (le dialogue d'Android).
    public private(set) var feuilleSignetsOuverte = false
    /// La puce choisie dans la feuille : « * » à chaque ouverture.
    public private(set) var filtreSignets = "*"
    private var bibliotheque: Bibliotheque? = nil
    private var indexLivres: Siddur? = nil

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
        return BibliothequeSignets(titre: Libelle("marques_titre"), nombre: nombre,
                                   icone: BibliothequeModele.iconeLivres)
    }

    // MARK: La feuille des marque-pages (RepriseFavoris.listeSignets, recueil « l »)

    /// L'icône des marque-pages d'étude (`SiddurLectureActivity.icone(true)`).
    public static let iconeLivres = "ic_marque_etude"

    /// Le titre de la feuille, « Marque-pages » ; un bouton OK la ferme.
    public var titreFeuilleSignets: Libelle { Libelle("marques_titre") }

    /// Toucher la ligne des marque-pages : la feuille s'ouvre sur « Tout ». Rien sans marque-page.
    public func ouvrirSignets() {
        guard ligneSignets != nil else { return }
        filtreSignets = "*"
        feuilleSignetsOuverte = true
    }

    public func fermerSignets() {
        feuilleSignetsOuverte = false
    }

    /// Les puces, une seule cochée (`filtreSignets`) : « Tout », « Livres », puis un livre par puce dans
    /// l'ordre de l'index quand les marque-pages sont dans plus d'un livre. Vide sans marque-page.
    public var filtresSignets: [BibliothequeFiltreSignets] {
        let marques = signets
        guard !marques.isEmpty, let index = indexLivres else { return [] }
        var filtres = [
            BibliothequeFiltreSignets(id: "*", libelle: Libelle("recherche_tout"), titre: nil),
            BibliothequeFiltreSignets(id: "l", libelle: Libelle("livres_title"), titre: nil),
        ]
        // `distinct()` puis `sortedBy { ordre }` : chaque livre une fois, dans l'ordre de l'index.
        var cles: [String] = []
        for marque in marques where !cles.contains(where: { $0.egalUnites(marque.cle) }) {
            cles.append(marque.cle)
        }
        cles.sort { BibliothequeModele.position($0, index) < BibliothequeModele.position($1, index) }
        if cles.count > 1 {
            let police = self.police
            for cle in cles {
                let titre = index.texte(cle.apresUnites(":"))?.titre.he ?? cle
                filtres.append(BibliothequeFiltreSignets(id: cle, libelle: nil,
                                                         titre: PoliceHebraique.masque(titre, police: police)))
            }
        }
        return filtres
    }

    /// Choisit une puce ; une puce qui n'existe pas ne change rien.
    public func choisirFiltreSignets(_ id: String) {
        guard filtresSignets.contains(where: { $0.id == id }) else { return }
        filtreSignets = id
    }

    /// Les marque-pages de la puce choisie, dans l'ordre des livres de l'index, puis de la section et du
    /// paragraphe (à égalité, l'ordre où ils sont gardés).
    public var lignesSignets: [BibliothequeSignetLigne] {
        guard let index = indexLivres else { return [] }
        let filtre = filtreSignets
        let police = self.police
        var retenues: [(rang: Int, position: Int, marque: MarquesPages.Marque)] = []
        for (rang, marque) in signets.enumerated() {
            let garde: Bool
            if filtre == "*" {
                garde = true
            } else if filtre.contientUnites(":") {
                garde = marque.cle.egalUnites(filtre)
            } else {
                garde = marque.cle.commenceParUnites(filtre + ":")
            }
            if garde {
                retenues.append((rang: rang, position: BibliothequeModele.position(marque.cle, index), marque: marque))
            }
        }
        retenues.sort { a, b in
            if a.position != b.position { return a.position < b.position }
            if a.marque.section != b.marque.section { return a.marque.section < b.marque.section }
            if a.marque.bloc != b.marque.bloc { return a.marque.bloc < b.marque.bloc }
            return a.rang < b.rang
        }
        var lignes: [BibliothequeSignetLigne] = []
        for retenue in retenues {
            let id = retenue.marque.cle.apresUnites(":")
            let titre = index.texte(id)?.titre.he ?? ""
            lignes.append(BibliothequeSignetLigne(
                id: retenue.rang, titre: PoliceHebraique.masque(titre, police: police),
                apercu: PoliceHebraique.masque(retenue.marque.apercu + "…", police: police),
                icone: BibliothequeModele.iconeLivres,
                route: .marque(livre: id, section: retenue.marque.section, bloc: retenue.marque.bloc)))
        }
        return lignes
    }

    /// Toucher un marque-page : la feuille se ferme, et la vue ouvre ce que la ligne désigne.
    @discardableResult
    public func choisirSignet(_ ligne: BibliothequeSignetLigne) -> BibliothequeRoute {
        feuilleSignetsOuverte = false
        return ligne.route
    }

    /// `ordre(c, cle)` d'Android pour un livre : 10 000 plus son rang dans l'index (−1 s'il n'y est plus).
    private static func position(_ cle: String, _ index: Siddur) -> Int {
        let id = cle.apresUnites(":")
        return 10_000 + (index.textes.firstIndex { $0.id == id } ?? -1)
    }

    /// La police hébraïque des réglages de lecture : la vue en habille la ligne des marque-pages, les puces des
    /// livres, les titres et les aperçus de la feuille (PoliceHebraique.appliquer d'Android) ; les textes rendus
    /// ici en ont déjà les signes absents masqués.
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
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
    private var sousSection: SousSection? = nil

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

    /// Le bouton de lecture (taille, fond noir, police, langues, défilement automatique), posé sur la page d'une
    /// source seulement (`barreLectureVisible`).
    public let barre: BibliothequeBarreLecture
    /// L'écran allumé pendant qu'on lit (VeilleLecture.kt, FLECTURE-01), une source comme un article.
    public let veille: VeilleLecture

    public private(set) var etat: BibliothequeEtat = .chargement
    /// Le message à montrer quand l'adresse n'a pu s'ouvrir (le Toast d'Android) ; nil sinon.
    public private(set) var alerte: Libelle? = nil
    private var bibliotheque: Bibliotheque? = nil
    private var entree: EntreeBibliotheque? = nil

    public init(magasin: Magasin, contenus: ContenusApp, langue: String, id: String) {
        self.magasin = magasin
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
        self.id = id
        barre = BibliothequeBarreLecture(magasin: magasin, langue: langue)
        veille = VeilleLecture(magasin: magasin)
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

    /// Vrai pour une source : la carte des paragraphes est montrée.
    public var paragraphesVisibles: Bool {
        estSource
    }

    /// Vrai pour une source : le bouton de lecture (`barre`) est posé sur la page. Un article n'en a pas.
    public var barreLectureVisible: Bool {
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
        let brute: String?
        switch entree {
        case .source(let source)?:
            titre = "library_open_sefaria"
            brute = source.url
        case .article(let article)?:
            titre = "library_read_on_site"
            brute = article.url
        case nil:
            return nil
        }
        // Un autre nom que `adresse` : `guard let` dans la même portée qu'une constante du même nom ne compile pas.
        guard let adresse = brute, !adresse.estBlanc else { return nil }
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

// MARK: - Le bouton de lecture

/// Le bouton de lecture des textes saints (ReglagesLecture.kt), tel que l'entrée d'une source le pose : la taille
/// des lettres, la lecture sur fond noir, la police hébraïque, les langues du texte, le défilement automatique, et
/// le bouton qu'on masque.
///
/// Replié, une pastille « Aa » au milieu du bas de l'écran ; déplié, une barre : A−, la taille en pour cent (un
/// toucher la remet à 100 %), A+, la lune, « אב » (la police), « אA » (les langues), le défilement automatique
/// (DefilementAuto.swift : tant qu'il défile, la commande [−] [N] [+] [❚❚] au-dessus), masquer, replier. Masqué,
/// plus rien : deux touchers sur le texte le font revenir, déplié.
///
/// Les réglages valent pour tous les écrans de lecture : ils vivent dans le `Magasin`, sous les clés d'Android
/// (`lecture_echelle`, `lecture_sombre`, `lecture_police`, `lecture_langues`, `lecture_masquee`). Le pli de la
/// barre et l'effacement de la pastille au défilement sont l'état de la vue, non gardé.
@MainActor
@Observable
public final class BibliothequeBarreLecture {

    /// Un toucher sur A− ou A+ (ReglagesLecture.PAS).
    public static let pas: Float = 0.1

    private let magasin: Magasin
    /// « fr », « en » ou « he » : les langues de lecture par défaut en dépendent.
    public let langue: String

    /// Vrai : la barre est dépliée ; faux : la pastille « Aa ». Replié à l'ouverture de l'écran.
    public private(set) var deplie = false
    /// Le message du masquage (le Snackbar d'Android, « Bouton masqué… », avec « Annuler ») ; nil sinon.
    public private(set) var messageMasque: Libelle? = nil
    /// Le défilement automatique : le bouton de la barre, et la commande flottante tant qu'il défile.
    public let defilementAuto: DefilementAuto

    public init(magasin: Magasin, langue: String) {
        self.magasin = magasin
        self.langue = ChizukCard.language(langue)
        defilementAuto = DefilementAuto(magasin: magasin)
        deplie = LectureCaptures.barreDepliee
    }

    // MARK: Ce que la barre montre

    /// La taille des lettres, de 0,8 à 2 : les textes marqués la multiplient (ReglagesLecture.appliquer).
    public var echelle: Float {
        magasin.reglages.lectureEchelle
    }

    /// La taille en pour cent, arrondie comme Android (`roundToInt` d'un Float).
    public var pourcent: Int {
        Kotlin.arrondiFlottant(echelle * 100)
    }

    /// « 110 % », au milieu de la barre.
    public var libellePourcent: Libelle {
        Libelle("lecture_pourcent", .entier(pourcent))
    }

    /// « Taille du texte : 110 % », pour VoiceOver.
    public var descriptionTaille: Libelle {
        Libelle("lecture_taille", .entier(pourcent))
    }

    /// La lecture sur fond noir (la lune, cerclée quand elle est active).
    public var sombre: Bool {
        magasin.reglages.lectureSombre
    }

    /// L'état de la lune pour VoiceOver : « activée » ou « désactivée ».
    public var etatSombre: Libelle {
        Libelle(sombre ? "lecture_nuit_oui" : "lecture_nuit_non")
    }

    /// La police hébraïque choisie (le menu « אב »).
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    /// Les polices du menu, dans l'ordre d'Android ; chacune se nomme par `Police.libelle` (police_…).
    public var polices: [PoliceHebraique.Police] {
        PoliceHebraique.Police.allCases
    }

    /// Les langues du texte (le menu « אA ») : le choix enregistré, sinon celles de la langue de l'app.
    public var mode: LanguesTexte.Mode {
        BibliothequeLecture.mode(magasin.reglages, langue: langue)
    }

    /// Les six façons de lire, dans l'ordre d'Android ; chacune se nomme par `Mode.libelle` (langues_…).
    public var modes: [LanguesTexte.Mode] {
        LanguesTexte.Mode.allCases
    }

    /// Le bouton a été masqué : ni pastille ni barre.
    public var masquee: Bool {
        magasin.reglages.lectureMasquee
    }

    /// La pastille « Aa » se voit (repliée, non masquée).
    public var pastilleVisible: Bool {
        !masquee && !deplie
    }

    /// La barre se voit (dépliée, non masquée).
    public var barreVisible: Bool {
        !masquee && deplie
    }

    // MARK: Les actions

    /// Toucher la pastille déplie la barre ; « Replier » la replie.
    public func deplier(_ ouvert: Bool) {
        deplie = ouvert
    }

    /// A+ : dix pour cent de plus, au plus 200 %.
    public func agrandir() async throws {
        try await changerTaille(echelle + BibliothequeBarreLecture.pas)
    }

    /// A− : dix pour cent de moins, au moins 80 %.
    public func rapetisser() async throws {
        try await changerTaille(echelle - BibliothequeBarreLecture.pas)
    }

    /// Toucher le pour cent : 100 %.
    public func tailleNormale() async throws {
        try await changerTaille(1)
    }

    /// La lune.
    public func basculerSombre() async throws {
        let sombre = !self.sombre
        try await magasin.modifierReglages { $0.setLectureSombre(sombre) }
    }

    public func choisirPolice(_ police: PoliceHebraique.Police) async throws {
        try await magasin.modifierReglages { $0.setLecturePolice(police.cle) }
    }

    /// Le texte lui-même change : la vue se refait, en gardant sa place.
    public func choisirLangues(_ mode: LanguesTexte.Mode) async throws {
        try await magasin.modifierReglages { $0.setLectureLangues(mode.cle) }
    }

    /// « Masquer le bouton » : plus rien à l'écran, et le message dit comment le retrouver. Le défilement
    /// automatique s'arrête, comme sur Android (ReglagesLecture.masquer) : sa commande serait restée seule.
    public func masquer() async throws {
        defilementAuto.arreter()
        deplie = false
        messageMasque = Libelle("lecture_masque_info")
        try await magasin.modifierReglages { $0.setLectureMasquee(true) }
    }

    /// Le bouton du message, « Annuler ».
    public var libelleAnnulerMasque: Libelle {
        Libelle("lecture_annuler_masque")
    }

    /// Le message s'est effacé.
    public func fermerMessage() {
        messageMasque = nil
    }

    /// Deux touchers sur le texte, ou « Annuler » : le bouton revient, déplié. Rien s'il n'était pas masqué.
    public func retrouver() async throws {
        guard masquee else { return }
        deplie = true
        messageMasque = nil
        try await magasin.modifierReglages { $0.setLectureMasquee(false) }
    }

    /// `changerTaille` : au dixième près (dix touchers de +10 % ne donnent pas 199,99 %), entre 80 % et 200 % ;
    /// une taille qui ne change pas n'écrit rien.
    private func changerTaille(_ voulue: Float) async throws {
        let arrondie = Float(Kotlin.arrondiFlottant(voulue * 10)) / 10
        let nouvelle = min(max(arrondie, Reglages.echelleMin), Reglages.echelleMax)
        guard nouvelle != echelle else { return }
        try await magasin.modifierReglages { $0.setLectureEchelle(nouvelle) }
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
        Store.marques(reglages: reglages)
    }
}
