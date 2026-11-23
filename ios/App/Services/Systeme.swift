import Coeur
import Ecrans
import Foundation
import UIKit
import UserNotifications

// Les adaptateurs des services d'Ecrans (ECRANS.md, « Ce qui parle au système ») : les notifications locales et
// l'icône de l'app. Les autres sont à côté : Temps d'écran (TempsEcran.swift), le lieu et la boussole (Lieu.swift,
// Boussole.swift), le planificateur des notifications et les répercussions des réglages (Notifications.swift), la Live
// Activity (Activite.swift), la musique, le code du téléphone pour le verrou du journal (CodeDuTelephone.swift), les
// alarmes de la minuterie système (Minuterie.swift).

/// Les notifications locales (`UNUserNotificationCenter`) ; les textes, des `Libelle`, se résolvent dans la langue de
/// l'app au moment de programmer.
struct NotificateurSysteme: Notificateur {
    let traducteur: Traducteur

    func autorisation() async -> Bool {
        let reglages = await UNUserNotificationCenter.current().notificationSettings()
        switch reglages.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    func demanderAutorisation() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func programmer(_ notifications: [NotificationPrevue]) async throws {
        let centre = UNUserNotificationCenter.current()
        let maintenant = Date().timeIntervalSince1970
        for prevue in notifications {
            let contenu = UNMutableNotificationContent()
            contenu.title = traducteur.texte(prevue.titre)
            contenu.body = traducteur.texte(prevue.corps)
            contenu.sound = .default
            // Un instant passé paraît aussitôt (une seconde : le minimum d'un déclencheur à intervalle).
            let delai = max(Double(prevue.instant) / 1000 - maintenant, 1)
            let declencheur = UNTimeIntervalNotificationTrigger(timeInterval: delai, repeats: false)
            try await centre.add(UNNotificationRequest(identifier: prevue.identifiant, content: contenu,
                                                       trigger: declencheur))
        }
    }

    func annulerTout() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

/// L'icône de l'app (`UIApplication.setAlternateIconName`) : nil, l'icône principale.
struct IconeSysteme: ReglagesIcone {
    func nomActuel() async -> String? {
        await MainActor.run { UIApplication.shared.alternateIconName }
    }

    func changer(_ nom: String?) async throws {
        try await IconeSysteme.poser(nom)
    }

    @MainActor
    private static func poser(_ nom: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(nom)
    }
}
