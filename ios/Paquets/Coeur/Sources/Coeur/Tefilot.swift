import Foundation

// Tefilot.kt : les dix sujets de l'écran Tfilot et ce qu'il affiche, calculé sans écran. Jugé par TefilotTests
// (TefilotTest d'Android) et par les sections « tefilot » et « tefilotEssai » de `Tests/Vecteurs/textes.json`.

/// `SujetTefila` : les dix sujets de l'écran Tfilot, dans l'ordre où ils ont été demandés.
///
/// L'ordre n'est pas alphabétique et ne doit pas le devenir : il commence par l'hitbodedout, qui est le sujet de
/// l'application, et finit par les deux demandes qu'on vient chercher un mauvais jour : le conjoint et la guérison.
public enum SujetTefila: String, Sendable, CaseIterable {
    case hitbodedut, simcha, uman, kdusha, zera, parnassa, brit, geula, zivug, refua

    /// La clé portée par les prières de la bibliothèque (« sujet »).
    public var cle: String { rawValue }

    /// La clé du titre dans le catalogue de chaînes.
    public var titre: String { "tefila_" + rawValue }
}

/// `TefilotRules` : l'écran ne connaît pas les prières, il lit la sous-section de la bibliothèque. Ajouter une
/// prière au fichier suffit à la faire paraître, pourvu qu'elle porte son sujet.
public enum TefilotRules {

    public static let sousSection = "tefilot-lt"

    /// `Ligne` : une ligne de l'écran, un sujet, ou une prière sous ce sujet.
    public enum Ligne: Sendable, Equatable {
        case titre(SujetTefila, nombre: Int)
        case priere(SujetTefila, SourceBibliotheque)
    }

    /// Les prières de la sous-section, articles exclus.
    public static func prieres(_ bibliotheque: Bibliotheque) -> [SourceBibliotheque] {
        (bibliotheque.sousSection(sousSection)?.entrees ?? []).compactMap { entree -> SourceBibliotheque? in
            if case .source(let s) = entree { return s }
            return nil
        }
    }

    public static func parSujet(_ bibliotheque: Bibliotheque, _ sujet: SujetTefila) -> [SourceBibliotheque] {
        prieres(bibliotheque).filter { $0.sujet?.egalUnites(sujet.cle) ?? false }
    }

    /// Les lignes, sujet par sujet, dans l'ordre de l'énumération.
    ///
    /// Un sujet sans prière ne produit aucune ligne : mieux vaut un écran plus court qu'un titre qui promet un
    /// texte absent.
    public static func lignes(_ bibliotheque: Bibliotheque) -> [Ligne] {
        var resultat: [Ligne] = []
        for sujet in SujetTefila.allCases {
            let siennes = parSujet(bibliotheque, sujet)
            if siennes.isEmpty { continue }
            resultat.append(.titre(sujet, nombre: siennes.count))
            for priere in siennes { resultat.append(.priere(sujet, priere)) }
        }
        return resultat
    }

    /// La leçon annoncée par cette prière porte-t-elle sur le sujet sous lequel on la range ?
    ///
    /// Rabbi Natan tire de chaque leçon une prière très large : la demande de guérison est dans une prière sur
    /// les danses, celle du conjoint dans une prière sur 'Hanoucca. Le fichier le dit ; l'écran le dira aussi,
    /// plutôt que de laisser croire que chaque leçon traite du sujet.
    public static func prevenir(_ entree: SourceBibliotheque) -> Bool {
        entree.leconSurLeSujet?.egalUnites("non") ?? false
    }
}
