import Foundation
import Observation
import Coeur

// Le planificateur des notifications branché sur le centre de notifications d'iOS (PORTAGE.md § 2.2.2, ROADMAP
// tâche 19). `PlanNotifications` (Coeur) dit, d'après le journal, les réglages et l'heure, tout ce qu'Android
// aurait affiché d'ici dix jours (rappels, « Chabbat dans 3 h », Birkat haLevana, le vol, la fin de séance) ;
// ici, ce plan devient les demandes en attente d'iOS : celles qui n'y sont plus sont retirées, les autres posées
// (un identifiant déjà posé est remplacé). Les notifications qui ne viennent pas du plan (« Mazal tov ! », posée
// par la séance) ne sont pas touchées.
//
// Il remplace Reminder.reschedule, ChabbatAlerte.programmer, LevanaAlerte.programmer, VolAlerte.programmer et
// BootReceiver : l'app le fait repasser au lancement, au retour au premier plan, en partant en arrière-plan, après
// chaque réglage qui les touche, au début et à la fin d'une séance. Les notifications locales survivent au
// redémarrage du téléphone.
//
// Ce que fait ReminderReceiver à l'affichage se fait ici au passage suivant : un trophée tout proche annoncé par
// une notification parue est noté parmi les trophées signalés (`trophees_proches_signales`), pour n'être dit qu'une
// fois. « Plus tard » reporte le rappel de 30 minutes (Reminder.snooze), « Commencer » ouvre la séance lancée.

// MARK: Ce que reçoit le centre de notifications

/// Une notification telle que l'app la pose dans le centre de notifications (`UNNotificationRequest`).
public struct DemandeNotification: Sendable, Hashable, Identifiable {
    public let identifiant: String
    /// L'instant où elle paraît, en millisecondes Unix ; passé, elle paraît aussitôt.
    public let instant: Int64
    public let titre: Libelle
    /// Le texte, puis la seconde ligne s'il y en a une (jointes par un retour à la ligne, comme sur Android).
    public let lignes: [Libelle]
    /// La catégorie qui porte les boutons « Commencer » et « Plus tard » ; nil sans bouton.
    public let categorie: String?
    /// Ce qu'ouvre un toucher sur la notification.
    public let lien: LienApp
    /// La clé du trophée tout proche qu'elle annonce (« famille:rang »).
    public let trophee: String?

    public var id: String { identifiant }

    /// La catégorie des rappels de hitbodedout : « Commencer », « Plus tard » (ReminderReceiver.build).
    public static let categorieRappel = "rappel"

    public init(identifiant: String, instant: Int64, titre: Libelle, lignes: [Libelle], categorie: String?,
                lien: LienApp, trophee: String?) {
        self.identifiant = identifiant
        self.instant = instant
        self.titre = titre
        self.lignes = lignes
        self.categorie = categorie
        self.lien = lien
        self.trophee = trophee
    }

    /// La demande d'une notification du plan : le texte du siddour qu'elle ouvre (LevanaAlerteReceiver,
    /// VolAlerte.texteSiddur), sinon le Jour.
    public init(_ planifiee: NotificationPlanifiee) {
        self.init(identifiant: planifiee.identifiant, instant: planifiee.instant, titre: planifiee.titre,
                  lignes: [planifiee.texte] + (planifiee.suite.map { [$0] } ?? []),
                  categorie: planifiee.actions.isEmpty ? nil : DemandeNotification.categorieRappel,
                  lien: planifiee.texteSiddur.map { LienApp.siddour($0) } ?? .accueil,
                  trophee: planifiee.trophee)
    }
}

/// Ce que l'app fait d'une réponse à une notification (`UNNotificationResponse`).
public enum ReponseNotification: Sendable, Hashable {
    /// Ouvrir cet écran.
    case ouvrir(LienApp)
    /// « Plus tard » : le rappel revient dans 30 minutes.
    case reporter
    /// La notification a été écartée : rien.
    case rien
}

/// Le centre de notifications d'iOS (`UNUserNotificationCenter` dans l'app), tel que le planificateur s'en sert.
public protocol CentreNotifications: Sendable {
    /// Les identifiants des notifications en attente.
    func enAttente() async -> [String]
    /// Les trophées annoncés par les notifications déjà parues et encore dans le centre.
    func tropheesParus() async -> [String]
    /// Pose ces notifications ; un identifiant déjà en attente est remplacé.
    func poser(_ demandes: [DemandeNotification]) async
    /// Retire ces notifications en attente.
    func retirer(_ identifiants: [String]) async
    /// Retire du centre les notifications déjà parues dont l'identifiant commence ainsi.
    func retirerParues(prefixe: String) async
}

/// Un centre en mémoire, pour les tests et les aperçus.
public actor FauxCentreNotifications: CentreNotifications {
    /// Les notifications en attente, par identifiant.
    public private(set) var attente: [String: DemandeNotification] = [:]
    /// Les notifications parues (identifiant, trophée annoncé).
    public private(set) var parues: [(identifiant: String, trophee: String?)] = []
    public private(set) var poses = 0

    public init() {}

    public func enAttente() -> [String] {
        Array(attente.keys)
    }

    public func tropheesParus() -> [String] {
        parues.compactMap(\.trophee)
    }

    public func poser(_ demandes: [DemandeNotification]) {
        poses += 1
        for demande in demandes { attente[demande.identifiant] = demande }
    }

    public func retirer(_ identifiants: [String]) {
        for identifiant in identifiants { attente[identifiant] = nil }
    }

    public func retirerParues(prefixe: String) {
        parues.removeAll { $0.identifiant.hasPrefix(prefixe) }
    }

    /// Une notification paraît : elle quitte l'attente et entre dans le centre.
    public func paraitre(_ identifiant: String) {
        guard let demande = attente.removeValue(forKey: identifiant) else { return }
        parues.append((identifiant: identifiant, trophee: demande.trophee))
    }

    /// Une notification posée par un autre que le planificateur (« Mazal tov ! »).
    public func poserAutre(_ identifiant: String) {
        attente[identifiant] = DemandeNotification(identifiant: identifiant, instant: 0, titre: Libelle(identifiant),
                                                   lignes: [], categorie: nil, lien: .accueil, trophee: nil)
    }
}

// MARK: Le planificateur

@MainActor
@Observable
public final class PlanificateurNotifications: PresentationRappels, VolRetraitNotifications {

    /// Les débuts d'identifiants des notifications du plan (PlanNotifications) : seules celles-là sont retirées.
    public nonisolated static let prefixes = ["rappel-", "fin-seance-", "chabbat-", "levana-", "vol-"]

    private let magasin: Magasin
    private let horloge: any Horloge
    private let centre: any CentreNotifications
    private let chargerAeroports: (@Sendable () async throws -> [Vol.Aeroport])?
    private let formats: VolFormats
    @ObservationIgnored private var aeroports: [Vol.Aeroport]?

    /// Ce que le dernier passage a posé, dans l'ordre du temps (le diagnostic des rappels).
    public private(set) var plan: [DemandeNotification] = []
    /// Les passages faits.
    public private(set) var passages = 0

    /// `aeroports` : la liste des aéroports, lue seulement quand un vol a des rappels, pour écrire leurs heures
    /// comme l'écran du vol (VolAlerte.deuxHeures) ; sans elle, l'heure universelle.
    public init(magasin: Magasin, horloge: any Horloge, centre: any CentreNotifications,
                aeroports: (@Sendable () async throws -> [Vol.Aeroport])? = nil, formats: VolFormats = .neutre) {
        self.magasin = magasin
        self.horloge = horloge
        self.centre = centre
        chargerAeroports = aeroports
        self.formats = formats
    }

    /// Une notification de ce planificateur ?
    public nonisolated static func possede(_ identifiant: String) -> Bool {
        prefixes.contains { identifiant.hasPrefix($0) }
    }

    /// Le plan d'après le magasin et l'heure, posé dans le centre ; ce qui n'en est plus est retiré.
    public func replanifier() async {
        await noterTropheesParus()
        let reglages = magasin.reglages
        let journal = magasin.journal
        let volRappels = VolStockage.rappels(reglages)
        let heureVol = await ecritureHeureVol(reglages, aRappels: reglages.volRappelsActifs && !volRappels.isEmpty)
        let liste = PlanNotifications.planifier(
            reglages: reglages, journal: journal, volRappels: volRappels, maintenant: horloge.maintenant,
            fuseau: horloge.fuseau,
            horaires: { lieu, jour in PlanNotifications.horairesCalcules(lieu, jour) },
            allumage: { lieu, jour, minutes in PlanNotifications.allumageCalcule(lieu, jour, minutes) },
            heureVol: heureVol)
        let demandes = liste.map(DemandeNotification.init)
        let gardes = Set(demandes.map(\.identifiant))
        let perimees = await centre.enAttente().filter { PlanificateurNotifications.possede($0) && !gardes.contains($0) }
        if !perimees.isEmpty { await centre.retirer(perimees.sorted()) }
        if !demandes.isEmpty { await centre.poser(demandes) }
        plan = demandes
        passages += 1
    }

    /// PresentationRappels : la présentation, l'écran des rappels et les réglages font repasser le planificateur.
    public func replanifier(_ reglages: Reglages) async {
        await replanifier()
    }

    /// VolRetraitNotifications : l'écran du vol retire ses rappels avant de poser les nouveaux ; le planificateur,
    /// qui tient les quatorze places du vol, repasse.
    public func retirer(prefixe: String) async {
        await replanifier()
    }

    /// « Plus tard » (Reminder.snooze) : le rappel revient dans 30 minutes, sans toucher aux heures réglées.
    public func reporter() async throws {
        let fin = Reminder.snooze(maintenant: horloge.maintenant)
        try await magasin.modifierReglages { $0.setReminderSnoozedUntil(fin) }
        await replanifier()
    }

    /// La journée est faite (Store.addSession) : le rappel déjà paru ne reste pas dans le centre de notifications
    /// (`cancel(Notifications.ID_REMINDER)`, 02/11).
    public func retirerRappelParu() async {
        await centre.retirerParues(prefixe: "rappel-")
    }

    /// Ce qu'une réponse à une notification demande : « Commencer » ouvre la séance lancée, « Plus tard » reporte,
    /// un toucher ouvre ce que la notification porte (le Jour sans rien) ; écartée, rien.
    public nonisolated static func reponse(action: String, lien: LienApp?) -> ReponseNotification {
        switch action {
        case NotificationPlanifiee.Action.commencer.rawValue: return .ouvrir(.seance(demarrer: true))
        case NotificationPlanifiee.Action.plusTard.rawValue: return .reporter
        case actionEcartee: return .rien
        default: return .ouvrir(lien ?? .accueil)
        }
    }

    /// `UNNotificationDismissActionIdentifier`.
    public nonisolated static let actionEcartee = "com.apple.UNNotificationDismissActionIdentifier"

    // MARK: Aides

    /// ReminderReceiver.tropheeProche : un trophée annoncé est noté, pour ne plus l'annoncer.
    private func noterTropheesParus() async {
        let parus = Set(await centre.tropheesParus())
        let signales = magasin.reglages.tropheesProchesSignales
        guard !parus.isSubset(of: signales) else { return }
        let tous = signales.union(parus)
        do {
            try await magasin.modifierReglages { $0.setTropheesProchesSignales(tous) }
        } catch {
            // Gardé en mémoire : le passage suivant l'écrira.
        }
    }

    /// L'heure d'un rappel du vol aux deux aéroports, comme l'écran du vol l'écrit ; l'heure universelle sans les
    /// aéroports ou sans vol gardé.
    private func ecritureHeureVol(_ reglages: Reglages, aRappels: Bool) async -> (Int64) -> String {
        guard aRappels, let chargerAeroports else { return { PlanNotifications.instantTexte($0) } }
        if aeroports == nil { aeroports = (try? await chargerAeroports()) ?? [] }
        guard let plan = VolStockage.plan(reglages, aeroports ?? []) else { return { PlanNotifications.instantTexte($0) } }
        let formats = self.formats
        return { t in VolMiseEnPage.texteDeuxHeures(plan, t, formats) }
    }
}
