import Foundation

/// Les versions de l'application (VersionApp.kt d'Android, 17/11) : quatre manières d'habiter la même pratique.
/// Classique est l'accueil d'origine ; Sérénité, Bento et Pile sont des accueils à part, tirés des maquettes du
/// propriétaire, qui ouvrent les mêmes écrans. Le journal, la série, les réglages et la barrière sont les mêmes
/// d'une version à l'autre : changer de version ne perd rien.
///
/// Sur iOS, seul l'accueil Classique est porté (`portee`) : la version choisie sur Android est gardée telle quelle
/// (réglage « version_app », sauvegarde comprise), et l'app montre Classique tant que l'accueil choisi n'existe pas.
public enum VersionApp: String, Sendable, CaseIterable {
    case classique, serenite, bento, pile

    /// La clé du réglage « version_app ».
    public var cle: String { rawValue }

    /// Le nom (version_<clé>) et la description (version_<clé>_desc) dans le catalogue.
    public var nom: Libelle { Libelle("version_\(rawValue)") }
    public var description: Libelle { Libelle("version_\(rawValue)_desc") }

    /// Trois couleurs pour l'aperçu de l'écran de choix, en ARGB : fond, carte, accent.
    public var apercu: [UInt32] {
        switch self {
        case .classique: [0xFF0F3D2E, 0xFF1E5A45, 0xFF8FD9B6]
        case .serenite: [0xFF14111F, 0xFF4E3486, 0xFFF2C6A0]
        case .bento: [0xFFF2F2EF, 0xFF123B30, 0xFFD9F56B]
        case .pile: [0xFF1D1B2E, 0xFF0E4D52, 0xFF7FE7D9]
        }
    }

    /// L'accueil de cette version existe sur iOS.
    public var portee: Bool { self == .classique }

    /// `VersionApp.parse` : la version de cette clé ; nil pour une clé absente ou inconnue.
    public static func parse(_ cle: String?) -> VersionApp? {
        guard let cle else { return nil }
        return allCases.first { $0.cle.egalUnites(cle) }
    }

    /// `VersionApp.courante` : Classique tant qu'aucune n'est choisie.
    public static func courante(_ reglages: Reglages) -> VersionApp {
        reglages.versionApp ?? .classique
    }

    /// L'accueil que l'app montre : la version choisie si elle est portée, sinon Classique.
    public static func accueil(_ reglages: Reglages) -> VersionApp {
        let v = courante(reglages)
        return v.portee ? v : .classique
    }
}
