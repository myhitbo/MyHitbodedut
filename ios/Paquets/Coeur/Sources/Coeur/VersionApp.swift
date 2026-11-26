import Foundation

/// Les versions de l'application (VersionApp.kt d'Android, 17/11) : cinq manières d'habiter la même pratique.
/// Classique est l'accueil d'origine ; Sérénité, Bento, Instant et Pile sont des accueils à part, tirés des maquettes
/// du propriétaire, qui ouvrent les mêmes écrans. Le journal, la série, les réglages et la barrière sont les mêmes
/// d'une version à l'autre : changer de version ne perd rien. Les cinq accueils sont portés sur iOS (Classique dans
/// AccueilVue, les autres dans SereniteVue, BentoVue, InstantVue et PileVue) ; le réglage « version_app » passe par la
/// sauvegarde, d'un téléphone à l'autre.
public enum VersionApp: String, Sendable, CaseIterable {
    case classique, serenite, bento, instant, pile

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
        case .instant: [0xFF141414, 0xFF232323, 0xFFC2D67A]
        case .pile: [0xFF1D1B2E, 0xFF0E4D52, 0xFF7FE7D9]
        }
    }

    /// `VersionApp.parse` : la version de cette clé ; nil pour une clé absente ou inconnue.
    public static func parse(_ cle: String?) -> VersionApp? {
        guard let cle else { return nil }
        return allCases.first { $0.cle.egalUnites(cle) }
    }

    /// `VersionApp.courante` : Classique tant qu'aucune n'est choisie.
    public static func courante(_ reglages: Reglages) -> VersionApp {
        reglages.versionApp ?? .classique
    }

    /// L'accueil que l'app montre (VersionApp.rediriger) : celui de la version choisie, Classique par défaut.
    public static func accueil(_ reglages: Reglages) -> VersionApp {
        courante(reglages)
    }
}
