import Ecrans
import Foundation

/// Ce que l'accueil fait faire au système à chaque passage et à chaque changement (MainActivity.applyServiceState,
/// StreakWidget.refresh, ZmanimWidget.refresh).
///
/// `appliquerEtat` replanifie les notifications (les rappels, Chabbat, Levana, le vol, la fin de séance) d'après le
/// magasin. La barrière de Temps d'écran, qu'Android pose ou lève ici selon « enabled », n'est pas encore branchée :
/// elle demande FamilyControls, accordé par Apple à la signature (`SystemeTempsEcran`) ; rien n'est fait pour
/// elle, et rien ne prétend l'avoir fait.
@MainActor
final class SystemeAccueil: AccueilSysteme {

    /// Les débuts d'identifiant des rappels de hitbodedout du plan : « rappel-… » et « rappel-reporte-… ».
    static let prefixesRappel = ["rappel-"]

    private let rappels: SystemeRappels
    private let widgets: SystemeWidgets
    private let notificateur: SystemeNotificateur

    init(rappels: SystemeRappels, widgets: SystemeWidgets, notificateur: SystemeNotificateur) {
        self.rappels = rappels
        self.widgets = widgets
        self.notificateur = notificateur
    }

    func appliquerEtat() async {
        await rappels.replanifier()
    }

    func rafraichirVignettes() async {
        await widgets.rafraichir()
    }

    func retirerRappelDuJour() async {
        await notificateur.retirerParues(prefixes: SystemeAccueil.prefixesRappel)
    }
}
