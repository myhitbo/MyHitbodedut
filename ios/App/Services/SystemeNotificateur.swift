import Coeur
import Ecrans
import Foundation
import UserNotifications

/// Les notifications locales de l'app : `UNUserNotificationCenter` (Notifications.kt, Reminder.kt, VolAlerte.kt
/// d'Android). Un seul objet pour toute l'app : le `Notificateur` des écrans, le retrait des notifications du vol
/// (`VolRetraitNotifications`), et la pose du plan entier des notifications (`poser(plan:)`, que
/// `SystemeRappels` lui confie après `PlanNotifications.planifier`).
///
/// Les textes sont des `Libelle` : ils sont écrits ici, dans la langue de l'app au moment de la pose, par le
/// `Traducteur`. Un instant à plus d'une minute devient un `UNCalendarNotificationTrigger` à la date et à l'heure
/// du fuseau du téléphone, fuseau compris (l'instant reste le même si l'on voyage) ; un instant plus proche, ou
/// déjà passé (« Mazal tov ! », posé à l'instant de la fin), un `UNTimeIntervalNotificationTrigger` d'une seconde
/// au moins, iOS refusant un délai nul.
///
/// Les appels à UserNotifications passent par leurs variantes à fermeture, dont seules des valeurs partageables
/// (un booléen, des identifiants, une erreur) ressortent : rien de ce que le centre rend ne traverse les acteurs.
@MainActor
final class SystemeNotificateur: Notificateur, VolRetraitNotifications {

    /// Les clés de `userInfo`, que le délégué des notifications touchées lit pour savoir où mener.
    enum Cle {
        /// Le texte du siddour qu'ouvre la notification (`NotificationPlanifiee.texteSiddur`) : Birkat haLevana,
        /// Tefilat haDerekh…
        static let texteSiddur = "texte_siddur"
        /// Le trophée tout proche annoncé (« famille:rang »), à noter parmi les trophées signalés.
        static let trophee = "trophee"
        /// La catégorie du plan (« rappel », « chabbat », « levana », « vol », « seance »).
        static let categorie = "categorie"
    }

    /// La catégorie d'iOS qui porte les deux boutons du rappel, « Commencer » et « Plus tard » (ReminderReceiver).
    /// L'identifiant de chaque bouton est `NotificationPlanifiee.Action.rawValue`.
    static let categorieRappel = "rappel"

    private let traducteur: Traducteur
    private let horloge: any Horloge
    /// La dernière pose du plan lancée : la suivante l'attend, pour que deux replanifications ne se mêlent pas.
    private var pose: Task<Void, Never>?

    init(traducteur: Traducteur, horloge: any Horloge = HorlogeSysteme()) {
        self.traducteur = traducteur
        self.horloge = horloge
        let commencer = UNNotificationAction(identifier: NotificationPlanifiee.Action.commencer.rawValue,
                                             title: traducteur.texte(cle: NotificationPlanifiee.Action.commencer.libelle),
                                             options: [.foreground])
        let plusTard = UNNotificationAction(identifier: NotificationPlanifiee.Action.plusTard.rawValue,
                                            title: traducteur.texte(cle: NotificationPlanifiee.Action.plusTard.libelle),
                                            options: [])
        let categorie = UNNotificationCategory(identifier: SystemeNotificateur.categorieRappel,
                                               actions: [commencer, plusTard], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([categorie])
    }

    // MARK: Notificateur

    func autorisation() async -> Bool {
        let statut = await statut()
        return statut == .authorized || statut == .provisional || statut == .ephemeral
    }

    func demanderAutorisation() async -> Bool {
        await withCheckedContinuation { (suite: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { accordee, _ in
                suite.resume(returning: accordee)
            }
        }
    }

    func programmer(_ notifications: [NotificationPrevue]) async throws {
        let maintenant = horloge.maintenant
        var premiere: (any Error)?
        for notification in notifications {
            let contenu = UNMutableNotificationContent()
            contenu.title = traducteur.texte(notification.titre)
            contenu.body = traducteur.texte(notification.corps)
            contenu.sound = .default
            let requete = UNNotificationRequest(identifier: notification.identifiant, content: contenu,
                                                trigger: SystemeNotificateur.declencheur(notification.instant,
                                                                                         maintenant: maintenant))
            if let erreur = await ajouter(requete), premiere == nil {
                premiere = erreur
            }
        }
        if let premiere { throw premiere }
    }

    func annulerTout() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: VolRetraitNotifications

    func retirer(prefixe: String) async {
        let prevues = await identifiantsPrevus()
        let retirees = prevues.filter { $0.hasPrefix(prefixe) }
        if !retirees.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: retirees)
        }
    }

    // MARK: Ce que l'app fait de plus

    /// Retire du centre de notifications celles déjà parues dont l'identifiant commence par l'un de ces préfixes :
    /// le rappel « Il est temps… » d'une journée faite (`cancel(Notifications.ID_REMINDER)`, 02/11).
    func retirerParues(prefixes: [String]) async {
        let parues = await identifiantsParus()
        let retirees = parues.filter { identifiant in prefixes.contains { identifiant.hasPrefix($0) } }
        if !retirees.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: retirees)
        }
    }

    /// Pose le plan entier (PlanNotifications) : chaque notification prévue qui n'y est plus est retirée, sauf le
    /// « Mazal tov ! » qui va paraître (`SeanceEnCours.identifiantFete`, hors du plan), puis chaque notification du
    /// plan est posée, remplaçant celle du même identifiant. Les poses se suivent dans l'ordre des appels.
    func poser(plan: [NotificationPlanifiee]) async {
        let precedente = pose
        let gardes: Set<String> = [SeanceEnCours.identifiantFete]
        let tache = Task { @MainActor in
            if let precedente { await precedente.value }
            await self.poserMaintenant(plan, gardes: gardes)
        }
        pose = tache
        await tache.value
    }

    private func poserMaintenant(_ plan: [NotificationPlanifiee], gardes: Set<String>) async {
        let voulues = Set(plan.map(\.identifiant))
        let prevues = await identifiantsPrevus()
        let perimees = prevues.filter { !voulues.contains($0) && !gardes.contains($0) }
        if !perimees.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: perimees)
        }
        let maintenant = horloge.maintenant
        for notification in plan {
            let requete = UNNotificationRequest(identifier: notification.identifiant,
                                                content: contenu(notification),
                                                trigger: SystemeNotificateur.declencheur(notification.instant,
                                                                                         maintenant: maintenant))
            // Une notification refusée (autorisation retirée) n'empêche pas les autres.
            _ = await ajouter(requete)
        }
    }

    /// Le contenu d'une notification du plan : le texte, puis sa seconde ligne sous un retour à la ligne comme sur
    /// Android ; les boutons du rappel ; où mener quand on la touche.
    private func contenu(_ notification: NotificationPlanifiee) -> UNMutableNotificationContent {
        let contenu = UNMutableNotificationContent()
        contenu.title = traducteur.texte(notification.titre)
        var corps = traducteur.texte(notification.texte)
        if let suite = notification.suite {
            corps += "\n" + traducteur.texte(suite)
        }
        contenu.body = corps
        contenu.sound = .default
        contenu.threadIdentifier = notification.categorie.rawValue
        if !notification.actions.isEmpty {
            contenu.categoryIdentifier = SystemeNotificateur.categorieRappel
        }
        var infos: [AnyHashable: Any] = [Cle.categorie: notification.categorie.rawValue]
        if let texteSiddur = notification.texteSiddur {
            infos[Cle.texteSiddur] = texteSiddur
        }
        if let trophee = notification.trophee {
            infos[Cle.trophee] = trophee
        }
        contenu.userInfo = infos
        return contenu
    }

    // MARK: Le centre, par ses fermetures

    private func statut() async -> UNAuthorizationStatus {
        await withCheckedContinuation { (suite: CheckedContinuation<UNAuthorizationStatus, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { reglages in
                suite.resume(returning: reglages.authorizationStatus)
            }
        }
    }

    /// Ajoute la requête ; rend l'erreur du centre, nil si elle est posée.
    private func ajouter(_ requete: UNNotificationRequest) async -> (any Error)? {
        await withCheckedContinuation { (suite: CheckedContinuation<(any Error)?, Never>) in
            UNUserNotificationCenter.current().add(requete) { erreur in
                suite.resume(returning: erreur)
            }
        }
    }

    private func identifiantsPrevus() async -> [String] {
        await withCheckedContinuation { (suite: CheckedContinuation<[String], Never>) in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requetes in
                suite.resume(returning: requetes.map(\.identifier))
            }
        }
    }

    private func identifiantsParus() async -> [String] {
        await withCheckedContinuation { (suite: CheckedContinuation<[String], Never>) in
            UNUserNotificationCenter.current().getDeliveredNotifications { parues in
                suite.resume(returning: parues.map(\.request.identifier))
            }
        }
    }

    /// Le déclencheur d'un instant (millisecondes Unix) : une date du calendrier, fuseau compris, au-delà d'une
    /// minute ; un délai d'une seconde au moins en deçà.
    private static func declencheur(_ instant: Int64, maintenant: Int64) -> UNNotificationTrigger {
        let ecart = Double(instant - maintenant) / 1000
        if ecart < 60 {
            return UNTimeIntervalNotificationTrigger(timeInterval: max(ecart, 1), repeats: false)
        }
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone.current
        let date = Date(timeIntervalSince1970: Double(instant) / 1000)
        let composantes = calendrier.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                                                    from: date)
        return UNCalendarNotificationTrigger(dateMatching: composantes, repeats: false)
    }
}
