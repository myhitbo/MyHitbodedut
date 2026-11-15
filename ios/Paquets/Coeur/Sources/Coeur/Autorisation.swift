// Les autorisations que l'application demande, et la raison qu'elle en donne (Autorisation.kt), recopiées
// par programme du Kotlin, dans le même ordre : celui de l'utilité décroissante. Sans notifications rien
// ne s'affiche, sans batterie libre le rappel peut arriver en retard, et les deux dernières ne servent
// qu'à la barrière du matin : l'édition légère, qui n'en a pas, ne les demande pas. L'état d'une
// autorisation se lit sur l'appareil ; la règle le reçoit en argument.

/// Une autorisation demandée par l'application.
public enum Autorisation: String, Sendable, CaseIterable {
    case notifications = "notifications"
    case batterie = "batterie"
    case overlay = "overlay"
    case usage = "usage"

    public var cle: String { rawValue }

    /// La clé de son titre dans le catalogue.
    public var titre: String {
        switch self {
        case .notifications: return "permission_notifications"
        case .batterie: return "permission_battery"
        case .overlay: return "permission_overlay"
        case .usage: return "permission_usage"
        }
    }

    /// La clé de la raison donnée.
    public var pourquoi: String {
        switch self {
        case .notifications: return "permission_notifications_why"
        case .batterie: return "permission_battery_why"
        case .overlay: return "permission_overlay_why"
        case .usage: return "permission_usage_why"
        }
    }

    /// Elle ne sert qu'à la barrière, absente de l'édition légère.
    public var barriere: Bool {
        switch self {
        case .notifications: return false
        case .batterie: return false
        case .overlay: return true
        case .usage: return true
        }
    }
}

/// Ce qui est demandé, et ce qui manque (PermissionRules d'Autorisation.kt).
public enum PermissionRules {

    /// Les autorisations qu'il y a lieu de demander dans cette édition.
    public static func demandees(avecBarriere: Bool) -> [Autorisation] {
        Autorisation.allCases.filter { avecBarriere || !$0.barriere }
    }

    /// Celles qui manquent, dans l'ordre. L'état est passé plutôt que lu : il demande l'appareil, la
    /// règle non.
    public static func manquantes(avecBarriere: Bool, accordee: (Autorisation) -> Bool) -> [Autorisation] {
        demandees(avecBarriere: avecBarriere).filter { !accordee($0) }
    }
}
