import Ecrans
import Foundation

/// Les liens profonds de l'app (`myhitbodedut://…`), déclarés dans l'Info.plist (CFBundleURLTypes). Les widgets
/// ouvrent l'app par les leurs, comme les PendingIntent d'Android ouvraient une activité : la boussole
/// (BoussoleWidget.kt), l'accueil, la séance et la séance qui part seule (StreakWidget.kt), les zmanim
/// (ZmanimVignette.kt), l'écran de séance depuis la Live Activity. Widgets/WidgetsCommun.swift (`WidgetsLiens`) écrit
/// les mêmes.
enum LienApp: Equatable {
    /// BoussoleActivity, depuis le widget de la boussole.
    case boussole
    /// MainActivity, depuis le widget de la série.
    case aujourdhui
    /// SessionActivity, pendant une séance (le widget de la série, la Live Activity).
    case seance
    /// SessionActivity avec EXTRA_START_NOW : le bouton « Commencer » du widget de la série.
    case commencer
    /// ZmanimActivity, depuis le widget des zmanim.
    case zmanim

    static let schema = "myhitbodedut"

    /// Le lien du widget de la boussole.
    static let boussoleURL = URL(string: "myhitbodedut://boussole")!

    /// Le lien que dit une URL, ou nil si elle n'est pas de l'app ou nomme un écran inconnu.
    init?(_ url: URL) {
        guard url.scheme?.lowercased() == LienApp.schema else { return nil }
        switch url.host()?.lowercased() {
        case "boussole": self = .boussole
        case "aujourdhui": self = .aujourdhui
        case "seance": self = .seance
        case "commencer": self = .commencer
        case "zmanim": self = .zmanim
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
        case .aujourdhui:
            navigation.onglet = .aujourdhui
            navigation.vider(.aujourdhui)
        case .seance, .commencer:
            navigation.onglet = .aujourdhui
            navigation.vider(.aujourdhui)
            navigation.pousser(.seance(commencer: lien == .commencer), dans: .aujourdhui)
        case .zmanim:
            navigation.onglet = .zmanim
            navigation.vider(.zmanim)
        }
    }
}
