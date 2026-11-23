import Barriere
import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

/// L'extension d'action du bouclier (ShieldActionDelegate, PORTAGE.md § 2.1.4, § 2.1.6) : les boutons de l'écran de
/// garde d'Android (BlockerView, GateService.showOverlay), sur le visage que l'extension du bouclier a dessiné
/// (`PlanBouclier.face`, la même règle, le même instantané).
/// - « Commencer » (onStartSession) : la demande dans la boîte, et l'app ouverte (`.openParentalControlsApp`, iOS 26.5) ;
///   en repli, une notification qui l'ouvre d'un toucher, que l'app retire si elle s'est ouverte d'elle-même ;
/// - « Je l'ai faite sans le téléphone » (onAlreadyDone) : la boîte, le bouclier levé, l'application fermée ;
/// - « Plus tard » (onSnooze) : la boîte, le bouclier levé, le rendez-vous de la fin du report donné à la surveillance ;
/// - « Autre réponse » : le bouclier redessiné en deuxième page ;
/// - « Fermer l'aperçu » (onDismiss) : l'essai levé ; « Continuer » : tout levé.
class BouclierAction: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        repondre(action, Reponse(rendre: completionHandler))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        repondre(action, Reponse(rendre: completionHandler))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        repondre(action, Reponse(rendre: completionHandler))
    }

    private func repondre(_ action: ShieldAction, _ reponse: Reponse) {
        guard let fichiers = FichiersBarriere.duGroupe(), let etat = fichiers.lireEtat() else {
            reponse.rendre(.close)
            return
        }
        let maintenant = TempsEcranCommun.maintenant()
        let boite = fichiers.lireBoite().evenements
        let face = PlanBouclier.face(etat, evenements: boite, maintenant: maintenant)
        let appui: AppuiBouclier
        switch action {
        case .primaryButtonPressed: appui = .principal
        case .secondaryButtonPressed: appui = .secondaire
        case .firstSecondarySubmenuItemPressed: appui = .sousMenu(0)
        case .secondSecondarySubmenuItemPressed: appui = .sousMenu(1)
        case .thirdSecondarySubmenuItemPressed: appui = .sousMenu(2)
        @unknown default:
            reponse.rendre(.none)
            return
        }
        switch PlanBouclier.geste(face, appui) {
        case .commencer:
            TempsEcranCommun.noter(.commencer, fichiers: fichiers, quand: maintenant)
            notifier(etat.bouclier.notificationCommencer, reponse)
        case .revenir:
            TempsEcranCommun.noter(.commencer, "revenir", fichiers: fichiers, quand: maintenant)
            notifier(etat.bouclier.notificationRevenir, reponse)
        case .autreReponse:
            TempsEcranCommun.noter(.autreReponse, fichiers: fichiers, quand: maintenant)
            reponse.rendre(.defer)
        case .dejaFaite:
            TempsEcranCommun.noter(.dejaFaite, fichiers: fichiers, quand: maintenant)
            lever(.barriere, fichiers: fichiers, quand: maintenant)
            reponse.rendre(.close)
        case .plusTard:
            let plusTard = Evenement(quand: maintenant, genre: .plusTard, detail: String(etat.snoozeMinutes))
            try? fichiers.ajouter(plusTard)
            lever(.barriere, fichiers: fichiers, quand: maintenant)
            TempsEcranCommun.planifierReport(etat.avec(boite + [plusTard]), maintenant: maintenant)
            reponse.rendre(.close)
        case .fermerApercu:
            if TempsEcranCommun.estPose(.essai) { TempsEcranCommun.lever(.essai) }
            TempsEcranCommun.noter(.essai, Etat.essaiFini, fichiers: fichiers, quand: maintenant)
            TempsEcranCommun.arreter(.essai)
            reponse.rendre(.close)
        case .continuer:
            lever(.barriere, fichiers: fichiers, quand: maintenant)
            if TempsEcranCommun.estPose(.essai) { TempsEcranCommun.lever(.essai) }
            reponse.rendre(.close)
        case .rien:
            reponse.rendre(.none)
        }
    }

    private func lever(_ nom: NomMagasin, fichiers: FichiersBarriere, quand: Horodatage) {
        guard TempsEcranCommun.estPose(nom) else { return }
        TempsEcranCommun.lever(nom)
        TempsEcranCommun.noter(.levee, AgentBarriere.bouclier.rawValue, fichiers: fichiers, quand: quand)
    }

    /// Ouvre l'app ; en repli, trois secondes plus tard, la notification qui l'ouvre d'un toucher (l'app, ouverte, la
    /// retire avant qu'elle paraisse). La réponse part une fois la notification confiée au système.
    private func notifier(_ texte: String, _ reponse: Reponse) {
        let contenu = UNMutableNotificationContent()
        contenu.title = texte
        contenu.sound = .default
        let declencheur = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let demande = UNNotificationRequest(identifier: PlanBouclier.notification, content: contenu, trigger: declencheur)
        UNUserNotificationCenter.current().add(demande) { _ in
            reponse.rendre(.openParentalControlsApp)
        }
    }
}

/// La réponse au système, que la notification rend une fois posée : une fermeture que le système appelle une fois.
private struct Reponse: @unchecked Sendable {
    let rendre: (ShieldActionResponse) -> Void
}
