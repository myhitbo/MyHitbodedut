import Coeur
import Ecrans
import Foundation
import UIKit
import UserNotifications

// Les adaptateurs des services d'Ecrans (ECRANS.md, « Ce qui parle au système ») : les notifications locales et
// l'icône de l'app, branchées sur iOS ; Temps d'écran, la Live Activity et les répercussions des réglages, encore
// absents (tâches 17, 19, 27 et 28) : ils ne font rien et le disent.

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

/// Temps d'écran tant que la barrière n'est pas écrite (tâches 27 et 28) : aucune autorisation demandée, aucun
/// bouclier posé.
struct TempsEcranAbsent: TempsEcran {
    func demanderAutorisation() async -> Bool { false }
    func leverBoucliers() async {}
}

/// Ce que l'app constate de Temps d'écran tant que la barrière n'est pas écrite : rien d'autorisé, aucune application.
struct BarriereAbsente: ReglagesBarriereSysteme {
    func constat() async -> Constat { Constat(autorise: false) }
    func nombreDeJetons() async -> Int { 0 }
}

/// La Live Activity de la séance (tâche 17) : pas encore.
struct ActiviteAbsente: ActiviteEnDirect {
    func commencer(debut: Int64, fin: Int64) async throws {}
    func terminer() async {}
}

/// Ce que les réglages changés touchent (etat.json, le planificateur, les widgets) : le planificateur des rappels et
/// les widgets viendront avec leurs tâches (19, 25) ; d'ici là, rien à réécrire.
struct EffetsAbsents: ReglagesEffets {
    func repercuter(_ quoi: ReglagesRepercussions, journal: Journal, reglages: Reglages) async {}
}

/// Les rappels que la présentation replanifie (tâche 19) : pas encore de planificateur branché.
struct RappelsAbsents: PresentationRappels {
    func replanifier(_ reglages: Reglages) async {}
}
