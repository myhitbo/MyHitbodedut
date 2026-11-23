import Foundation
import Coeur

// Ce qu'ouvre un geste venu d'hors de l'app : une notification touchée (les `PendingIntent` de Reminder.kt,
// LevanaAlerte.kt, VolAlerte.kt), un widget (BoussoleWidget, ZmanimVignette, StreakWidget), la Live Activity
// (SessionService). Android y met une `Intent` vers l'activité ; iOS, une adresse « myhitbodedut:// » que l'app
// reçoit (`onOpenURL`, `userInfo` de la notification) et que la racine traduit en écran. Écrit ici, sans UIKit,
// pour que l'aller-retour adresse ↔ écran se teste sous Linux.

/// Un écran de l'app qu'on peut ouvrir de l'extérieur.
public enum LienApp: Sendable, Hashable {
    /// MainActivity : le Jour.
    case accueil
    /// ZmanimActivity (les vignettes des zmanim).
    case zmanim
    /// BoussoleActivity (le widget de la boussole).
    case boussole
    /// CalendrierActivity.
    case calendrier
    /// RemindersActivity.
    case rappels
    /// SessionActivity ; `demarrer` : EXTRA_START_NOW (« Commencer » du rappel et du widget).
    case seance(demarrer: Bool)
    /// SessionService.ACTION_FINISH : « Terminer maintenant » du widget et de la Live Activity.
    case terminerSeance
    /// SiddurLectureActivity.ouvrir(c, id) : Birkat haLevana, Tefilat haDerekh, la prière du vol.
    case siddour(String)
    /// VolActivity.
    case vol

    /// Le schéma déclaré par l'app (CFBundleURLTypes).
    public static let schema = "myhitbodedut"

    /// L'adresse : « myhitbodedut://seance?demarrer=1 », « myhitbodedut://siddour/birkat_halevana ».
    public var url: URL {
        var composants = URLComponents()
        composants.scheme = LienApp.schema
        switch self {
        case .accueil: composants.host = "accueil"
        case .zmanim: composants.host = "zmanim"
        case .boussole: composants.host = "boussole"
        case .calendrier: composants.host = "calendrier"
        case .rappels: composants.host = "rappels"
        case .seance(let demarrer):
            composants.host = "seance"
            if demarrer { composants.queryItems = [URLQueryItem(name: "demarrer", value: "1")] }
        case .terminerSeance: composants.host = "terminer"
        case .siddour(let id):
            composants.host = "siddour"
            composants.path = "/" + id
        case .vol: composants.host = "vol"
        }
        return composants.url ?? URL(fileURLWithPath: "/")
    }

    /// L'écran d'une adresse ; nil pour une adresse d'un autre schéma ou inconnue (rien ne s'ouvre).
    public init?(url: URL) {
        guard let composants = URLComponents(url: url, resolvingAgainstBaseURL: false),
              composants.scheme?.lowercased() == LienApp.schema, let hote = composants.host?.lowercased() else {
            return nil
        }
        switch hote {
        case "accueil": self = .accueil
        case "zmanim": self = .zmanim
        case "boussole": self = .boussole
        case "calendrier": self = .calendrier
        case "rappels": self = .rappels
        case "seance":
            let demarrer = composants.queryItems?.first { $0.name == "demarrer" }?.value == "1"
            self = .seance(demarrer: demarrer)
        case "terminer": self = .terminerSeance
        case "siddour":
            let id = composants.path.split(separator: "/").first.map(String.init) ?? ""
            guard !id.isEmpty else { return nil }
            self = .siddour(id)
        case "vol": self = .vol
        default: return nil
        }
    }

    /// L'adresse écrite, comme la garde le `userInfo` d'une notification.
    public init?(texte: String) {
        guard let url = URL(string: texte) else { return nil }
        self.init(url: url)
    }
}
