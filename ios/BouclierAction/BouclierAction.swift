import Barriere
import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

/// L'extension ShieldActionDelegate : les boutons du bouclier (PORTAGE.md § 2.1.4, § 2.1.6 ; les rappels de
/// BlockerView.kt et leur effet dans GateService.kt). Le bouton touché est mené à son action par la règle
/// `VisageBouclier.action` du module Barriere, d'après le visage que le bouclier montrait (le même calcul que
/// l'extension du bouclier) :
///
/// - « Commencer maintenant » : la demande est écrite dans la boîte et l'extension répond
///   `.openParentalControlsApp` (iOS 26.5) ; l'app, en s'ouvrant, lit la demande, démarre la séance à la durée
///   habituelle et montre l'écran de séance (`SystemeBarriere.demandeDeCommencer`).
/// - « Revenir à la hitbodedout » : l'app s'ouvre ; une séance minutée déjà finie lève son magasin.
/// - « Je l'ai déjà faite » : écrit dans la boîte (l'app le versera au journal comme `Store.addSession(context, 0)`),
///   et le magasin `barriere` se désactive : le bouclier disparaît.
/// - « Plus tard » : écrit dans la boîte, `barriere` se désactive, et l'activité `report` est demandée au système
///   pour la fin du report : l'extension de surveillance réarmera.
/// - « Fermer l'aperçu » : l'essai est levé (le magasin `essai`, l'activité `essai`) et la boîte le dit.
///
/// Les extensions n'écrivent jamais le journal ni etat.json : elles ajoutent une ligne à la boîte (§ 3.2).
///
/// À éprouver sur l'iPhone (recette R2, questions 4 à 6) : `.openParentalControlsApp` porte le nom du contrôle
/// parental, et aucune source de première main ne confirme son effet avec une autorisation `.individual`. S'il ne
/// répond pas, passer `ouvrirParLeSysteme` à faux : l'extension pose alors la notification « Touchez pour commencer
/// votre hitbodedout » et ferme l'application retenue (deux gestes au lieu d'un).
///
/// Rien de ceci n'agit sans l'entitlement Family Controls accordé par Apple à l'app et à cette extension.
class BouclierAction: ShieldActionDelegate {

    /// `.openParentalControlsApp` ouvre MyHitbodedut ; faux : le repli par notification (§ 2.1.4).
    static let ouvrirParLeSysteme = true

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(BouclierReponse.repondre(action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(BouclierReponse.repondre(action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(BouclierReponse.repondre(action))
    }
}

/// Ce que fait un appui, et la réponse rendue au système.
enum BouclierReponse {

    static func repondre(_ action: ShieldAction) -> ShieldActionResponse {
        let bouton: BoutonBouclier
        switch action {
        case .primaryButtonPressed: bouton = .principal
        case .secondaryButtonPressed: bouton = .secondaire
        case .firstSecondarySubmenuItemPressed: bouton = .sousMenu(0)
        case .secondSecondarySubmenuItemPressed: bouton = .sousMenu(1)
        case .thirdSecondarySubmenuItemPressed: bouton = .sousMenu(2)
        @unknown default: bouton = .secondaire
        }
        let maintenant = Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
        let fuseau = TimeZone.current
        guard let conteneur = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ConteneurBarriere.groupe) else {
            // Sans le groupe d'apps, rien ne se transmet à l'app : l'appui ferme l'application retenue.
            return bouton == .secondaire ? .none : .close
        }
        let boite = ConteneurBarriere.fichier(Boite.nomFichier, dans: conteneur)
        let etat = lire(Etat.nomFichier, dans: conteneur).flatMap { Etat.lire($0) }
        let decor = lire(DecorBouclier.nomFichier, dans: conteneur).flatMap { DecorBouclier.lire($0) }
        let evenements = lire(Boite.nomFichier, dans: conteneur).map { Boite.lire($0) } ?? []
        let visage = VisageBouclier.actuel(etat: etat, decor: decor, evenements: evenements, millis: maintenant)
        let quand = Horodatage(millis: maintenant, fuseau: fuseau)

        func ajouter(_ genre: Evenement.Genre, _ detail: String = "") {
            try? FileManager.default.createDirectory(at: ConteneurBarriere.repertoire(dans: conteneur),
                                                     withIntermediateDirectories: true)
            try? Boite.ajouter(Evenement(quand: quand, genre: genre, detail: detail), a: boite)
        }

        var action = visage.action(bouton)
        // Un essai fini dont le magasin retient encore (ni l'app endormie ni la surveillance ne l'ont levé) : le
        // bouclier touché est celui de l'essai, montré « APERÇU » ou déjà sans badge. L'appui le lève, sans inscrire
        // de séance ni en démarrer une : « Fermer l'aperçu » ne doit pas devenir « Commencer ».
        if action != .aucune, visage != .apercu, decor?.essai != nil,
           ManagedSettingsStore(named: ManagedSettingsStore.Name(PilotageBarriere.magasinEssai)).isActive {
            action = .fermerApercu
        }
        switch action {
        case .commencer:
            ajouter(.commencer)
            return ouvrirLApp(etat: etat)
        case .revenir:
            if let seance = etat?.seance, seance.fin > 0, seance.fin <= maintenant {
                desactiver(PilotageBarriere.magasinSeance, quand: quand, boite: boite)
            }
            return ouvrirLApp(etat: etat)
        case .dejaFaite:
            ajouter(.dejaFaite)
            desactiver(PilotageBarriere.magasinBarriere, quand: quand, boite: boite)
            return .close
        case .plusTard:
            let minutes = etat?.snoozeMinutes ?? 15
            ajouter(.plusTard, String(minutes))
            desactiver(PilotageBarriere.magasinBarriere, quand: quand, boite: boite)
            planifierReport(fin: maintenant + Int64(minutes) * 60_000, fuseau: fuseau)
            return .close
        case .fermerApercu:
            ajouter(.essai, PilotageBarriere.finEssai)
            desactiver(PilotageBarriere.magasinEssai, quand: quand, boite: boite)
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(ActiviteBarriere.essai.rawValue)])
            return .close
        case .aucune:
            // Le bouton secondaire ouvre son sous-menu ; rien d'autre à faire.
            return .none
        }
    }

    /// Ouvre MyHitbodedut (iOS 26.5), ou, en repli, pose la notification qui l'ouvre et ferme l'application retenue.
    private static func ouvrirLApp(etat: Etat?) -> ShieldActionResponse {
        if BouclierAction.ouvrirParLeSysteme { return .openParentalControlsApp }
        let contenu = UNMutableNotificationContent()
        contenu.title = etat?.bouclier.notificationCommencer ?? ""
        let demande = UNNotificationRequest(identifier: "bouclier-commencer", content: contenu, trigger: nil)
        UNUserNotificationCenter.current().add(demande) { _ in }
        return .close
    }

    /// Désactive un magasin nommé, et l'écrit dans la boîte s'il était actif.
    private static func desactiver(_ nom: String, quand: Horodatage, boite: URL) {
        let magasin = ManagedSettingsStore(named: ManagedSettingsStore.Name(nom))
        guard magasin.isActive else { return }
        magasin.isActive = false
        try? Boite.ajouter(Evenement(quand: quand, genre: .levee, detail: "bouclier:" + nom), a: boite)
    }

    /// L'activité `report`, qui commence à la fin du report et dure l'intervalle minimal (§ 2.1.6) : à son début,
    /// l'extension de surveillance réévalue et réactive `barriere`. Un refus du système n'est pas rattrapé ici :
    /// l'app replanifie le report à son retour au premier plan, et `fenetre` et `minuit` réévaluent.
    private static func planifierReport(fin: Int64, fuseau: TimeZone) {
        let intervalle = PilotageBarriere.intervallePonctuel(debut: fin)
        let horaire = DeviceActivitySchedule(
            intervalStart: PilotageBarriere.composantesDate(intervalle.debut, fuseau: fuseau),
            intervalEnd: PilotageBarriere.composantesDate(intervalle.fin, fuseau: fuseau),
            repeats: false)
        try? DeviceActivityCenter().startMonitoring(DeviceActivityName(ActiviteBarriere.report.rawValue),
                                                    during: horaire)
    }

    private static func lire(_ nom: String, dans conteneur: URL) -> Data? {
        try? Data(contentsOf: ConteneurBarriere.fichier(nom, dans: conteneur))
    }
}
