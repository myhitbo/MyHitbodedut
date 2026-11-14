import Foundation

// Les prières de Likoutei Tefilot de l'écran Tfilot (Tefilot.kt), lues dans la sous-section
// « tefilot-lt » de la bibliothèque (`Bibliotheque`, Contenus.swift).
// Jugé par `Tests/Vecteurs/tefilot.json` (tools/vecteurs_ios/VecteursTefilot.kt).

/// Les dix sujets de l'écran Tfilot, dans l'ordre où ils ont été demandés.
///
/// L'ordre n'est pas alphabétique et ne doit pas le devenir : il commence par l'hitbodedout, qui
/// est le sujet de l'application, et finit par les deux demandes qu'on vient chercher un mauvais
/// jour — le conjoint et la guérison.
public enum SujetTefila: String, Sendable, CaseIterable {
    case hitbodedut, simcha, uman, kdusha, zera, parnassa, brit, geula, zivug, refua

    /// La clé du sujet, celle que porte le champ `sujet` d'une prière de la bibliothèque.
    public var cle: String { rawValue }

    /// Le nom de la chaîne du titre (R.string.tefila_…), clé de Localizable.xcstrings.
    public var titre: String {
        switch self {
        case .hitbodedut: "tefila_hitbodedut"
        case .simcha: "tefila_simcha"
        case .uman: "tefila_uman"
        case .kdusha: "tefila_kdusha"
        case .zera: "tefila_zera"
        case .parnassa: "tefila_parnassa"
        case .brit: "tefila_brit"
        case .geula: "tefila_geula"
        case .zivug: "tefila_zivug"
        case .refua: "tefila_refua"
        }
    }
}

/// Ce que l'écran Tfilot affiche, calculé sans écran pour être vérifiable.
///
/// L'écran ne connaît pas les prières : il lit la sous-section de la bibliothèque. Ajouter une
/// prière au fichier suffit à la faire paraître, pourvu qu'elle porte son sujet.
public enum TefilotRules {

    /// `SOUS_SECTION` de Kotlin.
    public static let sousSection = "tefilot-lt"

    /// Une ligne de l'écran : un sujet, ou une prière sous ce sujet.
    public enum Ligne: Sendable, Equatable {
        case titre(sujet: SujetTefila, nombre: Int)
        case priere(sujet: SujetTefila, entree: SourceBibliotheque)
    }

    /// Les prières de la sous-section, articles exclus, dans l'ordre du fichier.
    public static func prieres(_ library: Bibliotheque) -> [SourceBibliotheque] {
        var sources: [SourceBibliotheque] = []
        for entree in library.sousSection(TefilotRules.sousSection)?.entrees ?? [] {
            if case .source(let source) = entree {
                sources.append(source)
            }
        }
        return sources
    }

    public static func parSujet(_ library: Bibliotheque, _ sujet: SujetTefila) -> [SourceBibliotheque] {
        prieres(library).filter { egal($0.sujet, sujet.cle) }
    }

    /// Les lignes, sujet par sujet, dans l'ordre de l'énumération.
    ///
    /// Un sujet sans prière ne produit aucune ligne : mieux vaut un écran plus court qu'un titre
    /// qui promet un texte absent.
    public static func lignes(_ library: Bibliotheque) -> [Ligne] {
        var lignes: [Ligne] = []
        for sujet in SujetTefila.allCases {
            let siennes = parSujet(library, sujet)
            if siennes.isEmpty { continue }
            lignes.append(.titre(sujet: sujet, nombre: siennes.count))
            for entree in siennes {
                lignes.append(.priere(sujet: sujet, entree: entree))
            }
        }
        return lignes
    }

    /// La leçon annoncée par cette prière porte-t-elle sur le sujet sous lequel on la range ?
    ///
    /// Rabbi Natan tire de chaque leçon une prière très large : la demande de guérison est dans une
    /// prière sur les danses, celle du conjoint dans une prière sur 'Hanoucca. Le fichier le dit ;
    /// l'écran le dira aussi, plutôt que de laisser croire que chaque leçon traite du sujet.
    public static func prevenir(_ entree: SourceBibliotheque) -> Bool {
        egal(entree.leconSurLeSujet, "non")
    }

    /// `==` de Kotlin entre un texte peut-être absent et un texte : unité par unité.
    private static func egal(_ texte: String?, _ attendu: String) -> Bool {
        guard let texte else { return false }
        return texte.egalUnites(attendu)
    }
}
