import Foundation
import Observation
import Coeur

// Les rappels de hitbodedout (RemindersActivity.kt, activity_reminders.xml, item_reminder.xml) : l'interrupteur,
// l'avertissement quand les notifications manquent, le trophée tout proche dit dans le rappel, puis les heures
// réglées, chacune touchable pour la changer, avec de quoi la retirer, et « Ajouter une heure ».
//
// L'écran existe parce qu'une ligne dans la carte des réglages ne se trouve pas. Plusieurs heures peuvent être
// réglées ; la règle ne change pas pour autant : rien ne sonne un jour de repos, ni la veille après midi (ou
// l'allumage), ni une fois la séance faite (ReminderRule, appliquée par PlanNotifications).
//
// La demande des notifications est celle de DemandeNotifications.kt (13/11) : posée tant qu'iOS ne l'a pas posée ;
// une fois la réponse donnée, le toucher mène aux Réglages d'iOS (`RappelsRoute.reglagesNotifications`) au lieu de
// rester sans effet. Chaque changement fait replanifier les notifications (`PresentationRappels`,
// Reminder.reschedule d'Android).

/// Ce que l'écran des rappels demande d'ouvrir.
public enum RappelsRoute: Sendable, Hashable {
    /// Les notifications de l'app dans les Réglages d'iOS (`openNotificationSettingsURLString`).
    case reglagesNotifications
}

/// Une heure de la liste (item_reminder.xml) : touchée, elle se change ; « Retirer » l'ôte.
public struct RappelsHeure: Sendable, Hashable, Identifiable {
    /// Son rang dans la liste.
    public let rang: Int
    /// Minutes depuis minuit.
    public let minutes: Int

    public var id: Int { rang }
    public var heure: Int { (minutes / 60) % 24 }
    public var minute: Int { minutes % 60 }
}

/// Le choix d'une heure ouvert (TimePickerDialog) : une heure à ajouter, ou celle d'un rang à changer.
public enum RappelsDialogue: Sendable, Hashable, Identifiable {
    case ajout
    case changement(rang: Int)

    public var id: String {
        switch self {
        case .ajout: "ajout"
        case .changement(let rang): "changement-\(rang)"
        }
    }
}

@MainActor
@Observable
public final class RappelsModele {
    private let magasin: Magasin
    private let notificateur: any Notificateur
    private let rappels: any PresentationRappels
    private let plan: (@MainActor () -> [DemandeNotification])?

    /// Les notifications s'affichent-elles ? Relu à chaque apparition (onResume → render).
    public private(set) var notificationsAccordees = true
    /// La question d'iOS est à l'écran : il n'y a pas encore de refus à signaler (DemandeNotifications.enCours).
    public private(set) var demandeEnCours = false
    /// Le choix d'une heure ouvert ; nil sinon.
    public var dialogue: RappelsDialogue? = nil
    /// Les écrans demandés, que la vue ouvre puis retire (`routeOuverte()`) : un interrupteur ne rend rien.
    public private(set) var routes: [RappelsRoute] = []

    /// `plan` : ce que le planificateur a posé à son dernier passage, pour le diagnostic.
    public init(magasin: Magasin, notificateur: any Notificateur, rappels: any PresentationRappels,
                plan: (@MainActor () -> [DemandeNotification])? = nil) {
        self.magasin = magasin
        self.notificateur = notificateur
        self.rappels = rappels
        self.plan = plan
    }

    // MARK: Le diagnostic (ROADMAP, tâche 19)

    /// « Notifications en attente » : la liste que montre la construction de développement.
    public var diagnosticTitre: Libelle { Libelle("rappels_diagnostic") }

    /// Les notifications que le planificateur tient en attente, dans l'ordre du temps ; vide sans planificateur.
    public var diagnostic: [DemandeNotification] {
        plan?() ?? []
    }

    // MARK: Le bandeau

    /// « Rappels ».
    public var titre: Libelle { Libelle("reminders_title") }

    /// L'illustration du bandeau, sur sa scène.
    public var image: String {
        Personnage.pour(Adresse.parse(magasin.reglages.adresse), "char_pointing")
    }

    /// Sous le titre (render) : « Désactivés. », « Aucune heure réglée. », ou le nombre d'heures.
    public var resume: Libelle {
        let reglages = magasin.reglages
        let heures = reglages.reminderTimes
        if !reglages.reminderEnabled { return Libelle("reminders_off") }
        if heures.isEmpty { return Libelle("reminders_none") }
        return Libelle.pluriel("reminders_count", quantite: heures.count, .entier(heures.count))
    }

    // MARK: La carte

    public var activerTitre: Libelle { Libelle("reminders_enable") }
    public var activerAide: Libelle { Libelle("reminders_enable_hint") }

    /// L'interrupteur (Store.reminderEnabled).
    public var actif: Bool { magasin.reglages.reminderEnabled }

    /// Sans la permission, le rappel se programme et ne s'affiche jamais : il faut le dire, pas laisser croire
    /// qu'il est actif (PermissionRules.rappelMuet). Touché, l'avertissement relance la demande.
    public var permissionManquante: Bool {
        PermissionRules.rappelMuet(actif: actif, notifications: notificationsAccordees, demandeEnCours: demandeEnCours)
    }

    /// « Les notifications sont refusées : le rappel ne s'affichera pas. Touchez ici pour les autoriser. »
    public var permissionTexte: Libelle { Libelle("reminders_permission_missing") }

    /// Le trophée tout proche, dit dans le rappel (16/10).
    public var tropheeLibelle: Libelle { Libelle("rappel_trophee_reglage") }
    public var trophee: Bool { magasin.reglages.rappelTropheeProche }

    // MARK: Les heures

    public var heuresTitre: Libelle { Libelle("reminders_hours") }
    public var heuresAide: Libelle { Libelle("reminders_hours_hint") }
    public var retirerLibelle: Libelle { Libelle("reminders_remove") }
    public var ajouterLibelle: Libelle { Libelle("reminders_add") }

    /// Les heures réglées, triées et sans doublon (Store.reminderTimes).
    public var heures: [RappelsHeure] {
        magasin.reglages.reminderTimes.enumerated().map { RappelsHeure(rang: $0.offset, minutes: $0.element) }
    }

    /// L'heure où s'ouvre le choix : celle à changer ; pour un ajout, la dernière réglée, sinon 7 h
    /// (Store.DEFAULT_REMINDER).
    public func heureInitiale(_ dialogue: RappelsDialogue) -> (heure: Int, minute: Int) {
        let minutes: Int
        switch dialogue {
        case .ajout:
            minutes = magasin.reglages.reminderTimes.last ?? Reglages.defaultReminder
        case .changement(let rang):
            let liste = magasin.reglages.reminderTimes
            minutes = rang >= 0 && rang < liste.count ? liste[rang] : Reglages.defaultReminder
        }
        return ((minutes / 60) % 24, minutes % 60)
    }

    // MARK: Les actions

    /// À chaque apparition et au retour au premier plan (onResume) : l'autorisation relue.
    public func apparaitre() async {
        notificationsAccordees = await notificateur.autorisation()
    }

    /// L'interrupteur : allumé, les notifications sont demandées ; puis les rappels se replanifient. Rend l'écran
    /// des Réglages d'iOS à ouvrir quand la demande ne peut plus se poser.
    @discardableResult
    public func basculer(_ actif: Bool) async throws -> RappelsRoute? {
        try await magasin.modifierReglages { $0.setReminderEnabled(actif) }
        var route: RappelsRoute? = nil
        if actif { route = await demanderNotifications() }
        await rappels.replanifier(magasin.reglages)
        return route
    }

    /// « Dire dans le rappel qu'un trophée est tout proche » (Store.setRappelTropheeProche) : la phrase entre
    /// dans le prochain rappel posé.
    public func basculerTrophee(_ oui: Bool) async throws {
        try await magasin.modifierReglages { $0.setRappelTropheeProche(oui) }
        await rappels.replanifier(magasin.reglages)
    }

    /// DemandeNotifications.lancer : rien si elles s'affichent déjà ; la question d'iOS tant qu'il ne l'a pas posée ;
    /// sinon les Réglages d'iOS, où l'on peut encore les autoriser.
    @discardableResult
    public func demanderNotifications() async -> RappelsRoute? {
        switch await notificateur.etatAutorisation() {
        case .accordee:
            notificationsAccordees = true
            return nil
        case .refusee:
            notificationsAccordees = false
            routes.append(.reglagesNotifications)
            return .reglagesNotifications
        case .aDemander:
            demandeEnCours = true
            notificationsAccordees = await notificateur.demanderAutorisation()
            demandeEnCours = false
            return nil
        }
    }

    /// La première route demandée a été ouverte.
    public func routeOuverte() {
        if !routes.isEmpty { routes.removeFirst() }
    }

    /// « Ajouter une heure ».
    public func ouvrirAjout() {
        dialogue = .ajout
    }

    /// Une heure touchée : la changer.
    public func ouvrirChangement(_ heure: RappelsHeure) {
        dialogue = .changement(rang: heure.rang)
    }

    public func fermerDialogue() {
        dialogue = nil
    }

    /// L'heure choisie : ajoutée, ou à la place de celle qu'on changeait (la liste se trie et perd ses doublons).
    public func valider(heure: Int, minute: Int) async throws {
        guard let ouvert = dialogue else { return }
        dialogue = nil
        let minutes = heure * 60 + minute
        var liste = magasin.reglages.reminderTimes
        if case .changement(let rang) = ouvert, rang >= 0, rang < liste.count {
            liste.remove(at: rang)
        }
        liste.append(minutes)
        try await enregistrer(liste)
    }

    /// « Retirer ».
    public func retirer(_ heure: RappelsHeure) async throws {
        var liste = magasin.reglages.reminderTimes
        guard heure.rang >= 0, heure.rang < liste.count else { return }
        liste.remove(at: heure.rang)
        try await enregistrer(liste)
    }

    private func enregistrer(_ liste: [Int]) async throws {
        try await magasin.modifierReglages { $0.setReminderTimes(liste) }
        await rappels.replanifier(magasin.reglages)
    }
}
