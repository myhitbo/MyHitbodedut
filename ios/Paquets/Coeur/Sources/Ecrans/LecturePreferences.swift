import Foundation
import Coeur

// Ce que le lecteur des textes (SiddurLectureActivity.kt) et le siddour (SiddurActivity.kt) partagent : la place
// d'un paragraphe, ce qu'on ouvre et avec quoi, et les préférences de lecture que Store.kt garde sous ses clés
// (favoris, marque-pages, reprise). Store.swift de Coeur n'est pas encore construit (`enChantierSources`) : ses
// règles de lecture sont reprises ici, à l'identique, sur `Reglages.brut` (mêmes clés, mêmes formes qu'Android).

/// Une place dans un texte : la section et le paragraphe (`places` de SiddurLectureActivity, « section:bloc » de
/// l'extra MARQUE).
public struct LecturePlace: Sendable, Hashable {
    public let section: Int
    public let bloc: Int

    public init(section: Int, bloc: Int) {
        self.section = section
        self.bloc = bloc
    }
}

/// Ce qu'on ouvre dans le lecteur : les extras de SiddurLectureActivity.
public struct LectureCible: Sendable, Hashable {
    /// ID : l'identifiant du texte (« chaharit », « likoutei_moharan »).
    public let id: String
    /// LIVRE : un livre de la bibliothèque, sans nusah ni ajouts du jour.
    public let livre: Bool
    /// MARQUE : ouvert depuis un marque-page, à sa place ; nil : reprendre là où on s'était arrêté.
    public let marque: LecturePlace?

    public init(id: String, livre: Bool = false, marque: LecturePlace? = nil) {
        self.id = id
        self.livre = livre
        self.marque = marque
    }

    /// `SiddurLectureActivity.ouvrir(context, id)`.
    public static func siddour(_ id: String) -> LectureCible {
        LectureCible(id: id)
    }

    /// `SiddurLectureActivity.ouvrirLivre(context, id)`.
    public static func livre(_ id: String) -> LectureCible {
        LectureCible(id: id, livre: true)
    }

    /// « s:chaharit » pour le siddour, « l:likoutei_etsot » pour un livre : la clé des favoris et de la reprise.
    public var cle: String {
        (livre ? "l:" : "s:") + id
    }
}

/// Les écrans qu'ouvrent le siddour et le lecteur, pour `navigationDestination(for:)`.
public enum LectureRoute: Sendable, Hashable {
    /// SiddurLectureActivity : un texte du siddour ou un livre, à une place ou non.
    case lecture(LectureCible)
    /// TehilimActivity : le livre de Tehilim.
    case tehilim
    /// TikkunFlowActivity : le Tikoun HaKlali.
    case tikkun
    /// TehilimLectureActivity.ouvrirMarque : DEBUT = FIN = le psaume, MARQUE_VERSET = le verset.
    case tehilimMarque(psaume: Int, verset: Int)
    /// La feuille des marque-pages (RepriseFavoris.listeSignets) : tous (nil), ceux du siddour (« s ») ou des
    /// livres (« l »).
    case marquesPages(recueil: String?)

    /// `SiddurLectureActivity.ouvrirMarque` : le texte d'un marque-page, à sa place ; un psaume pour les Tehilim.
    public static func marque(_ m: MarquesPages.Marque) -> LectureRoute {
        if m.cle.egalUnites(LecturePreferences.cleTehilim) { return .tehilimMarque(psaume: m.section, verset: m.bloc) }
        let place = LecturePlace(section: m.section, bloc: m.bloc)
        return .lecture(LectureCible(id: m.cle.apresUnites(":"), livre: m.cle.commenceParUnites("l:"), marque: place))
    }
}

/// Un choix d'une liste (le nusah, la police, les langues) : son nom et s'il est coché.
public struct LectureOption<Valeur: Sendable & Hashable>: Sendable, Hashable, Identifiable {
    public let valeur: Valeur
    public let nom: Libelle
    public let choisi: Bool

    public var id: Valeur { valeur }
}

/// Un nom à montrer : de l'hébreu tel quel (le titre d'un texte), ou une chaîne de l'interface.
public enum LectureNom: Sendable, Hashable {
    /// Dans la police hébraïque choisie (déjà masquée pour elle).
    case hebreu(String)
    case libelle(Libelle)
}

/// Les préférences de lecture de Store.kt, sous les noms de clés d'Android.
public enum LecturePreferences {

    /// La clé des marque-pages des Tehilim (TehilimLectureActivity.CLE).
    public static let cleTehilim = "t:tehilim"

    /// Trois heures : un appel, une pause ; pas la prière du lendemain (PRIERE_REPRISE_MS).
    public static let priereRepriseMs: Int64 = 3 * 60 * 60 * 1000

    private static let cleFavoris = "favoris"
    private static let cleMarques = "marques_pages"
    private static let cleDerniereLecture = "derniere_lecture"

    // MARK: Les réglages de lecture

    /// `LanguesTexte.mode(context)` : le choix enregistré, sinon le mode de la langue de l'app.
    public static func mode(_ reglages: Reglages, langue: String) -> LanguesTexte.Mode {
        if let cle = reglages.lectureLangues, let mode = LanguesTexte.Mode(rawValue: cle) { return mode }
        return LanguesTexte.defaut(langue)
    }

    /// `Store.lecturePolice` : la police hébraïque choisie (« serif » par défaut).
    public static func police(_ reglages: Reglages) -> PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: reglages.lecturePolice) ?? .serif
    }

    // MARK: Favoris

    /// `Store.favoris` : les textes favoris (« s:id », « l:id »), le plus récent en tête.
    public static func favoris(_ reglages: Reglages) -> [String] {
        morceaux(chaine(reglages, cleFavoris) ?? "", 0x7C).filter { !$0.estBlanc }
    }

    /// `Store.basculerFavori` : retire la première occurrence, ou ajoute en tête.
    public static func basculerFavori(_ reglages: inout Reglages, _ cle: String) {
        var l = favoris(reglages)
        if let rang = l.firstIndex(where: { $0.egalUnites(cle) }) {
            l.remove(at: rang)
        } else {
            l.insert(cle, at: 0)
        }
        pose(&reglages, cleFavoris, .chaine(l.joined(separator: "|")))
    }

    // MARK: Marque-pages

    /// `Store.marques` : les marque-pages des lectures (MarquesPages, préférence « marques_pages »).
    public static func marques(_ reglages: Reglages) -> [MarquesPages.Marque] {
        MarquesPages.decoder(chaine(reglages, cleMarques))
    }

    /// `Store.basculerMarque` : pose ou retire ; vrai si la marque est maintenant posée.
    @discardableResult
    public static func basculerMarque(_ reglages: inout Reglages, _ m: MarquesPages.Marque) -> Bool {
        let l = MarquesPages.basculer(marques(reglages), m)
        pose(&reglages, cleMarques, .chaine(MarquesPages.encoder(l)))
        return l.contains { $0.memePlace(m) }
    }

    // MARK: La reprise

    /// `Store.positionLecture` : la ligne où reprendre un texte. Un livre reprend toujours ; une prière du
    /// siddour seulement juste après une interruption (bug du 02/11). nil sans place, ou à la ligne 0.
    public static func positionLecture(_ reglages: Reglages, cle: String, maintenant: Int64) -> Int? {
        guard let position = reglages.brut["position:" + cle]?.commeEntier, position > 0 else { return nil }
        let quand = reglages.brut["position_t:" + cle]?.commeLong ?? 0
        return repriseValable(cle, quand: quand, maintenant: maintenant) ? Int(position) : nil
    }

    /// `Store.setPositionLecture` : la ligne, l'instant, et le texte comme dernière lecture.
    public static func setPositionLecture(_ reglages: inout Reglages, cle: String, position: Int, maintenant: Int64) {
        pose(&reglages, "position:" + cle, .entier(Int64(Int32(truncatingIfNeeded: position))))
        pose(&reglages, "position_t:" + cle, .entier(maintenant))
        pose(&reglages, cleDerniereLecture, .chaine(cle))
    }

    /// `Store.derniereLecture` : la clé du dernier texte lu.
    public static func derniereLecture(_ reglages: Reglages) -> String? {
        chaine(reglages, cleDerniereLecture)
    }

    /// `Store.repriseValable` : l'écart se calcule comme une soustraction de `Long`, qui déborde sans lever.
    public static func repriseValable(_ cle: String, quand: Int64, maintenant: Int64) -> Bool {
        if !cle.commenceParUnites("s:") { return true }
        let ecart = maintenant &- quand
        return quand > 0 && ecart >= 0 && ecart < priereRepriseMs
    }

    // MARK: Les préférences brutes

    /// `getString(clé, null)` : seule une chaîne se lit.
    private static func chaine(_ reglages: Reglages, _ cle: String) -> String? {
        if case .chaine(let texte)? = reglages.brut[cle] { return texte }
        return nil
    }

    /// `putString`, `putInt`, `putLong`.
    private static func pose(_ reglages: inout Reglages, _ cle: String, _ valeur: JSON) {
        var brut = reglages.brut
        brut[cle] = valeur
        reglages = Reglages(brut: brut)
    }

    /// `split(c)` de Kotlin sur une unité UTF-16 : les morceaux entre deux séparateurs, vides compris.
    private static func morceaux(_ texte: String, _ separateur: UInt16) -> [String] {
        var resultat: [String] = []
        var courant: [UInt16] = []
        for unite in texte.utf16 {
            if unite == separateur {
                resultat.append(Unites.texte(courant))
                courant = []
            } else {
                courant.append(unite)
            }
        }
        resultat.append(Unites.texte(courant))
        return resultat
    }
}
