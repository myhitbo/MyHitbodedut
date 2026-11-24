import Coeur
import Foundation
import UserNotifications

/// Ce que l'utilisateur a fait d'une notification de l'app, en valeurs partageables : ce que la navigation lit pour
/// savoir où mener (ReminderReceiver, LevanaAlerteReceiver, VolAlerteReceiver d'Android).
struct NotificationTouchee: Sendable, Equatable {

    enum Geste: Sendable, Equatable {
        /// La notification elle-même a été touchée.
        case ouvrir
        /// « Commencer » sous le rappel : l'écran de séance, la séance lancée.
        case commencer
        /// « Plus tard » sous le rappel : le rappel reporté (`ServicesApp.reporterRappel`), sans ouvrir l'app.
        case plusTard
    }

    let geste: Geste
    /// L'identifiant de la notification : « rappel-… », « celebration », « vol-… »…
    let identifiant: String
    /// La catégorie du plan (`NotificationPlanifiee.Categorie.rawValue`), nil pour une notification d'un écran.
    let categorie: String?
    /// Le texte du siddour à ouvrir (Birkat haLevana, Tefilat haDerekh…), nil : l'accueil.
    let texteSiddur: String?
    /// Le trophée tout proche que le rappel annonçait (« famille:rang »).
    let trophee: String?
}

/// Le délégué du centre de notifications : les notifications paraissent aussi l'app ouverte (bannière, son), et ce
/// qu'on en fait est rendu à l'app comme une `NotificationTouchee`.
///
/// iOS peut rendre la réponse avant que l'interface soit prête (l'app lancée par le toucher) : le délégué se pose
/// dès le lancement (`init()` de l'App), et garde les réponses jusqu'à ce que l'app branche ce qui les traite
/// (`brancher`).
@MainActor
final class SystemeReponsesNotifications: NSObject, UNUserNotificationCenterDelegate {

    private var traiter: (@MainActor (NotificationTouchee) async -> Void)?
    private var enAttente: [NotificationTouchee] = []

    /// Se pose comme délégué de ce centre de notifications : celui de l'app.
    init(centre: UNUserNotificationCenter = .current()) {
        super.init()
        centre.delegate = self
    }

    /// Branche ce qui traite les réponses ; celles reçues avant lui sont traitées aussitôt, dans l'ordre.
    func brancher(_ traiter: @escaping @MainActor (NotificationTouchee) async -> Void) {
        self.traiter = traiter
        let attente = enAttente
        enAttente = []
        Task { @MainActor in
            for touchee in attente {
                await traiter(touchee)
            }
        }
    }

    private func recevoir(_ touchee: NotificationTouchee) async {
        guard let traiter else {
            enAttente.append(touchee)
            return
        }
        await traiter(touchee)
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let geste: NotificationTouchee.Geste
        switch response.actionIdentifier {
        case NotificationPlanifiee.Action.commencer.rawValue:
            geste = .commencer
        case NotificationPlanifiee.Action.plusTard.rawValue:
            geste = .plusTard
        case UNNotificationDismissActionIdentifier:
            completionHandler()
            return
        default:
            geste = .ouvrir
        }
        let requete = response.notification.request
        let infos = requete.content.userInfo
        let touchee = NotificationTouchee(geste: geste, identifiant: requete.identifier,
                                          categorie: infos[SystemeNotificateur.Cle.categorie] as? String,
                                          texteSiddur: infos[SystemeNotificateur.Cle.texteSiddur] as? String,
                                          trophee: infos[SystemeNotificateur.Cle.trophee] as? String)
        Task { @MainActor [weak self] in
            await self?.recevoir(touchee)
            completionHandler()
        }
    }
}
