import Ecrans
import Foundation
import UserNotifications

/// Les notifications en attente, pour l'écran de diagnostic des rappels (ROADMAP, tâche 19) :
/// `UNUserNotificationCenter.getPendingNotificationRequests`, par sa variante à fermeture comme
/// `SystemeNotificateur` : seules des valeurs partageables (`RappelsNotificationEnAttente`) sortent de la fermeture,
/// rien de ce que le centre rend ne traverse les acteurs.
///
/// Le prochain déclenchement est `nextTriggerDate()` du déclencheur : une date fixe pour un déclencheur de
/// calendrier (celui que pose `SystemeNotificateur` au-delà d'une minute) ; pour un délai, iOS le compte depuis
/// la lecture, et la ligne ne se compare pas au plan (`instantFixe` faux).
struct SystemeRappelsCentre: RappelsCentreNotifications {

    func enAttente() async -> [RappelsNotificationEnAttente] {
        await withCheckedContinuation { (suite: CheckedContinuation<[RappelsNotificationEnAttente], Never>) in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requetes in
                suite.resume(returning: requetes.map { SystemeRappelsCentre.lire($0) })
            }
        }
    }

    private static func lire(_ requete: UNNotificationRequest) -> RappelsNotificationEnAttente {
        var prochaine: Date?
        var fixe = false
        if let calendrier = requete.trigger as? UNCalendarNotificationTrigger {
            prochaine = calendrier.nextTriggerDate()
            fixe = !calendrier.repeats
        } else if let delai = requete.trigger as? UNTimeIntervalNotificationTrigger {
            prochaine = delai.nextTriggerDate()
        }
        let instant = prochaine.map { Int64(($0.timeIntervalSince1970 * 1000).rounded(.down)) }
        let categorie = requete.content.userInfo[SystemeNotificateur.Cle.categorie] as? String
        return RappelsNotificationEnAttente(identifiant: requete.identifier, titre: requete.content.title,
                                            corps: requete.content.body, instant: instant, instantFixe: fixe,
                                            categorie: categorie)
    }
}
