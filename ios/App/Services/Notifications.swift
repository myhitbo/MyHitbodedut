import BackgroundTasks
import Coeur
import Ecrans
import Foundation
import Observation
import UIKit
import UserNotifications
import WidgetKit

// Les rappels, alertes et réponses aux notifications (tâche 19, PORTAGE.md § 2.2.2) : le centre de notifications
// d'iOS tel que le planificateur s'en sert (`CentreNotifications`), les boutons « Commencer » et « Plus tard » du
// rappel (ReminderReceiver.build), le délégué qui reçoit les touchers, et l'aiguillage qui les porte à la racine,
// avec les adresses « myhitbodedut:// » des widgets et de la Live Activity. Puis ce que les réglages, la
// présentation, l'ajout de temps et le vol font repasser : le planificateur et les widgets.

// « Continuer la hitbodedout ? » (24/11) : la question programmée dix secondes avant la fin d'une séance minutée porte
// ses réponses (+ 5 min, + la même durée, sans fin, non) ; elles agissent sans ouvrir l'app (`SuiteDeSeance`).

// MARK: Le centre de notifications

/// `UNUserNotificationCenter` pour le planificateur : les textes, des `Libelle`, se résolvent dans la langue de l'app
/// au moment de poser. Le `userInfo` garde l'adresse de l'écran qu'ouvre un toucher et le trophée annoncé.
struct CentreNotificationsSysteme: CentreNotifications {
    let traducteur: Traducteur

    /// Les clés du `userInfo`.
    static let cleLien = "lien"
    static let cleTrophee = "trophee"

    /// Les boutons du rappel de hitbodedout (ReminderReceiver.build) : « Commencer » ouvre la séance lancée,
    /// « Plus tard » reporte de 30 minutes sans ouvrir l'app. Puis ceux de « Continuer ? » pour ces suites de réponses
    /// (une catégorie par suite : le bouton de la même durée dit sa durée), qui agissent sans ouvrir l'app.
    static func enregistrerCategories(_ traducteur: Traducteur, suites: Set<[Int]> = []) {
        let commencer = UNNotificationAction(identifier: NotificationPlanifiee.Action.commencer.rawValue,
                                             title: traducteur.texte(Libelle(NotificationPlanifiee.Action.commencer.libelle)),
                                             options: [.foreground])
        let plusTard = UNNotificationAction(identifier: NotificationPlanifiee.Action.plusTard.rawValue,
                                            title: traducteur.texte(Libelle(NotificationPlanifiee.Action.plusTard.libelle)),
                                            options: [])
        let rappel = UNNotificationCategory(identifier: DemandeNotification.categorieRappel, actions: [commencer, plusTard],
                                            intentIdentifiers: [], options: [])
        var categories: Set<UNNotificationCategory> = [rappel]
        for reponses in suites {
            let boutons = reponses.map { minutes in
                UNNotificationAction(identifier: DemandeNotification.actionSuite(minutes),
                                     title: traducteur.texte(DemandeNotification.libelleSuite(minutes)), options: [])
            }
            categories.insert(UNNotificationCategory(identifier: DemandeNotification.categorieSuite(reponses),
                                                     actions: boutons, intentIdentifiers: [], options: []))
        }
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    func enAttente() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func tropheesParus() async -> [String] {
        await UNUserNotificationCenter.current().deliveredNotifications().compactMap {
            $0.request.content.userInfo[CentreNotificationsSysteme.cleTrophee] as? String
        }
    }

    func poser(_ demandes: [DemandeNotification]) async {
        let centre = UNUserNotificationCenter.current()
        let maintenant = Date().timeIntervalSince1970
        // Les boutons de « Continuer ? » de cette séance, enregistrés avant la question qui les porte.
        let suites = Set(demandes.map(\.continuer).filter { !$0.isEmpty })
        if !suites.isEmpty { CentreNotificationsSysteme.enregistrerCategories(traducteur, suites: suites) }
        for demande in demandes {
            let contenu = UNMutableNotificationContent()
            contenu.title = traducteur.texte(demande.titre)
            contenu.body = demande.lignes.map { traducteur.texte($0) }.joined(separator: "\n")
            contenu.sound = .default
            if let categorie = demande.categorie { contenu.categoryIdentifier = categorie }
            var infos: [String: String] = [CentreNotificationsSysteme.cleLien: demande.lien.url.absoluteString]
            if let trophee = demande.trophee { infos[CentreNotificationsSysteme.cleTrophee] = trophee }
            contenu.userInfo = infos
            // Un instant passé (un rappel du vol en retard de moins de vingt minutes) paraît aussitôt.
            let delai = max(Double(demande.instant) / 1000 - maintenant, 1)
            let declencheur = UNTimeIntervalNotificationTrigger(timeInterval: delai, repeats: false)
            do {
                try await centre.add(UNNotificationRequest(identifier: demande.identifiant, content: contenu,
                                                           trigger: declencheur))
            } catch {
                // Refusée par le système (trop de demandes, autorisation retirée) : le passage suivant la reposera.
            }
        }
    }

    func retirer(_ identifiants: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiants)
    }

    func retirerParues(prefixe: String) async {
        let centre = UNUserNotificationCenter.current()
        let parues = await centre.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(prefixe) }
        if !parues.isEmpty { centre.removeDeliveredNotifications(withIdentifiers: parues) }
    }
}

extension NotificateurSysteme {
    /// DemandeNotifications : la question tant qu'iOS ne l'a pas posée ; ensuite, les Réglages d'iOS.
    func etatAutorisation() async -> EtatNotifications {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .accordee
        case .notDetermined: .aDemander
        default: .refusee
        }
    }
}

/// Le notificateur de l'écran du vol : ses rappels font partie du plan (les quatorze places du vol) ; au lieu de
/// les poser lui-même, il fait repasser le planificateur, qui les pose avec le texte du siddour à ouvrir.
struct NotificateurDuPlan: Notificateur {
    let systeme: NotificateurSysteme
    let planificateur: PlanificateurNotifications

    func autorisation() async -> Bool { await systeme.autorisation() }
    func etatAutorisation() async -> EtatNotifications { await systeme.etatAutorisation() }
    func demanderAutorisation() async -> Bool { await systeme.demanderAutorisation() }

    func programmer(_ notifications: [NotificationPrevue]) async throws {
        await planificateur.replanifier()
    }

    func annulerTout() async { await systeme.annulerTout() }
}

// MARK: Les gestes venus d'hors de l'app

/// Les réponses aux notifications et les adresses ouvertes (widgets, Live Activity), dans l'ordre où elles
/// arrivent : la racine les prend une à une, dès qu'elle est là (une notification touchée peut lancer l'app).
@MainActor
@Observable
final class Aiguillage {
    static let commun = Aiguillage()

    private(set) var gestes: [ReponseNotification] = []

    func recevoir(_ geste: ReponseNotification) {
        guard geste != .rien else { return }
        gestes.append(geste)
    }

    func prendre() -> ReponseNotification? {
        gestes.isEmpty ? nil : gestes.removeFirst()
    }
}

/// Le délégué du centre de notifications : une notification paraît aussi app ouverte (comme sur Android) ; un
/// toucher ou un bouton passe par l'aiguillage.
final class DelegueNotifications: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let commun = DelegueNotifications()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let adresse = response.notification.request.content.userInfo[CentreNotificationsSysteme.cleLien] as? String
        let geste = PlanificateurNotifications.reponse(action: action, lien: adresse.flatMap { LienApp(texte: $0) })
        // « Plus tard » et les réponses de « Continuer ? » n'ouvrent pas l'app : iOS la réveille en arrière-plan, sans
        // écran pour vider l'aiguillage.
        switch geste {
        case .reporter:
            await ReportDuRappel.reporter()
        case .continuer(let minutes):
            await SuiteDeSeance.repondre(minutes)
        case .nePasContinuer:
            await SuiteDeSeance.repondre(nil)
        default:
            await Aiguillage.commun.recevoir(geste)
        }
    }
}

/// « Plus tard » (Reminder.snooze) depuis la notification : par le planificateur de l'app s'il est là, sinon sur les
/// fichiers, l'app réveillée pour l'occasion.
@MainActor
enum ReportDuRappel {
    /// Le planificateur de l'app, posé par `ModelesApp.charger`.
    static weak var planificateur: PlanificateurNotifications?

    static func reporter() async {
        if let planificateur {
            try? await planificateur.reporter()
            return
        }
        guard let magasin = try? await Magasin.charger(PersistanceFichiers(dossier: DossierApp.app)) else { return }
        let paquet = Bundle.main.bundleURL
        let traducteur = MyHitbodedutApp.traducteur(paquet: paquet)
        let lecteur = ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu"))
        let planificateur = PlanificateurNotifications(magasin: magasin, horloge: HorlogeSysteme(),
                                                       centre: CentreNotificationsSysteme(traducteur: traducteur),
                                                       aeroports: VolModele.lireAeroports(lecteur: lecteur),
                                                       formats: .langue(traducteur.langue))
        try? await planificateur.reporter()
    }
}

/// Une réponse à « Continuer la hitbodedout ? » (SessionService ACTION_SUITE, ACTION_SUITE_NON) : par la séance de
/// l'app si elle est là, sinon sur les fichiers, l'app réveillée pour l'occasion — la Live Activity et l'alarme suivent
/// la nouvelle fin. Puis le planificateur déplace la notification de fin et la question, et la question parue se
/// retire.
@MainActor
enum SuiteDeSeance {
    /// La séance et le planificateur de l'app, posés par `ModelesApp.charger`.
    static weak var seance: SeanceEnCours?
    static weak var planificateur: PlanificateurNotifications?

    /// `minutes` : oui, de tant de minutes (`SessionRule.ouverte` : sans fin) ; nil : non.
    static func repondre(_ minutes: Int?) async {
        if let seance, let planificateur {
            await repondre(minutes, seance: seance, planificateur: planificateur)
            return
        }
        guard let magasin = try? await Magasin.charger(PersistanceFichiers(dossier: DossierApp.app)) else { return }
        let paquet = Bundle.main.bundleURL
        let traducteur = MyHitbodedutApp.traducteur(paquet: paquet)
        let horloge = HorlogeSysteme()
        let seance = SeanceEnCours(magasin: magasin, horloge: horloge, activite: ActiviteSysteme(traducteur: traducteur),
                                   minuterie: MinuterieAlarmes(traducteur: traducteur))
        let lecteur = ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu"))
        let planificateur = PlanificateurNotifications(magasin: magasin, horloge: horloge,
                                                       centre: CentreNotificationsSysteme(traducteur: traducteur),
                                                       aeroports: VolModele.lireAeroports(lecteur: lecteur),
                                                       formats: .langue(traducteur.langue))
        await repondre(minutes, seance: seance, planificateur: planificateur)
    }

    private static func repondre(_ minutes: Int?, seance: SeanceEnCours,
                                 planificateur: PlanificateurNotifications) async {
        if let minutes {
            try? await seance.continuer(minutes: minutes)
        } else {
            try? await seance.nePasContinuer()
        }
        await planificateur.retirerQuestionParue()
        await planificateur.replanifier()
    }
}

/// Le délégué de l'app : celui des notifications posé dès le lancement, pour qu'un toucher qui lance l'app ne se
/// perde pas.
@MainActor
final class DelegueApp: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = DelegueNotifications.commun
        return true
    }
}

// MARK: Ce que les changements font repasser

/// Les widgets se redessinent (StreakWidget.refresh, ZmanimWidget.refresh) : une journée inscrite, un lieu choisi,
/// une couleur changée doivent s'y voir tout de suite.
@MainActor
enum RafraichissementWidgets {
    static func redessiner() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func redessiner(_ genre: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: genre)
    }
}

/// Ce que les réglages changés touchent (ReglagesEffets) : les rappels (le planificateur) et les widgets. La
/// barrière (etat.json, la surveillance) est l'affaire des tâches 27 et 28.
struct EffetsSysteme: ReglagesEffets {
    let planificateur: PlanificateurNotifications

    func repercuter(_ quoi: ReglagesRepercussions, journal: Journal, reglages: Reglages) async {
        if quoi.contains(.rappels) { await planificateur.replanifier() }
        if quoi.contains(.widgets) { await MainActor.run { RafraichissementWidgets.redessiner() } }
    }
}

/// Après un ajout de temps (AjoutTemps.kt) : les widgets, et le rappel du jour retiré du centre.
struct AjoutTempsSystemeApp: AjoutTempsSysteme {
    let planificateur: PlanificateurNotifications

    func rafraichirWidgets() async {
        await MainActor.run { RafraichissementWidgets.redessiner() }
    }

    func retirerRappelDuJour() async {
        await planificateur.retirerRappelParu()
    }
}

/// Le rafraîchissement d'arrière-plan (`BGAppRefreshTask`, PORTAGE.md § 2.2.2) : sans lui, des rappels posés dix jours
/// d'avance s'arrêtent si l'app n'est pas ouverte d'ici là. iOS l'accorde quand il veut, sans garantie ; chaque passage
/// demande le suivant, au plus tôt dans six heures.
enum ReplanificationFond {
    /// `BGTaskSchedulerPermittedIdentifiers` (projet-commun.yml).
    static let identifiant = "com.myhitbodedut.replanifier"

    static func programmer() {
        let demande = BGAppRefreshTaskRequest(identifier: identifiant)
        demande.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        do {
            try BGTaskScheduler.shared.submit(demande)
        } catch {
            // Refusé (simulateur, rafraîchissement coupé dans les réglages) : l'ouverture de l'app replanifie.
        }
    }

    /// Les modèles de l'app s'ils sont là ; sinon (l'app lancée pour l'occasion) le magasin lu sur les fichiers.
    @MainActor
    static func executer(modeles: ModelesApp?, paquet: URL, traducteur: Traducteur) async {
        programmer()
        if let modeles {
            await modeles.planificateur.replanifier()
        } else if let magasin = try? await Magasin.charger(PersistanceFichiers(dossier: DossierApp.app)) {
            let lecteur = ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu"))
            let planificateur = PlanificateurNotifications(magasin: magasin, horloge: HorlogeSysteme(),
                                                           centre: CentreNotificationsSysteme(traducteur: traducteur),
                                                           aeroports: VolModele.lireAeroports(lecteur: lecteur),
                                                           formats: .langue(traducteur.langue))
            await planificateur.replanifier()
        }
        RafraichissementWidgets.redessiner()
    }
}
