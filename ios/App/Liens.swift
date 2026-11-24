import Ecrans
import Foundation

/// Les liens profonds de l'app (`myhitbodedut://…`), déclarés dans l'Info.plist (CFBundleURLTypes). Le widget de
/// la boussole ouvre la boussole par le sien, comme le PendingIntent de BoussoleWidget.kt ouvrait BoussoleActivity.
enum LienApp: Equatable {
    /// BoussoleActivity, depuis le widget de la boussole.
    case boussole

    static let schema = "myhitbodedut"

    /// Le lien du widget de la boussole.
    static let boussoleURL = URL(string: "myhitbodedut://boussole")!

    /// Le lien que dit une URL, ou nil si elle n'est pas de l'app ou nomme un écran inconnu.
    init?(_ url: URL) {
        guard url.scheme?.lowercased() == LienApp.schema else { return nil }
        switch url.host()?.lowercased() {
        case "boussole": self = .boussole
        default: return nil
        }
    }
}

extension PartageApp {

    /// Ouvre l'écran d'un lien : ce qui était posé par-dessus se ferme, l'onglet du lien passe devant, et l'écran
    /// s'ouvre sur sa pile ramenée à la racine (Android ouvrait une activité neuve au-dessus de la tâche).
    func ouvrir(_ lien: LienApp) {
        navigation.feuille = nil
        navigation.couverture = nil
        navigation.ajout = nil
        switch lien {
        case .boussole:
            navigation.onglet = .zmanim
            navigation.vider(.zmanim)
            navigation.pousser(.boussole, dans: .zmanim)
        }
    }
}
