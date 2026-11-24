import Ecrans
import Foundation

/// Ce que fait le système après un ajout de temps (AjoutTemps.kt) : les widgets se redessinent, et le rappel
/// « Il est temps… » déjà paru quitte le centre de notifications, la journée étant faite (Store.addSession,
/// `cancel(Notifications.ID_REMINDER)`, 02/11).
@MainActor
final class SystemeAjoutTemps: AjoutTempsSysteme {

    private let widgets: SystemeWidgets
    private let notificateur: SystemeNotificateur

    init(widgets: SystemeWidgets, notificateur: SystemeNotificateur) {
        self.widgets = widgets
        self.notificateur = notificateur
    }

    func rafraichirWidgets() async {
        await widgets.rafraichir()
    }

    func retirerRappelDuJour() async {
        await notificateur.retirerParues(prefixes: SystemeAccueil.prefixesRappel)
    }
}
