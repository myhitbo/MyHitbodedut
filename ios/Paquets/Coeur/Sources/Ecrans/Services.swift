import Foundation
import Coeur

// Ce qui parle au système (ECRANS.md) : notifications, lieu, son, Temps d'écran, Live Activity. Ici, les
// protocoles, sans aucune API d'Apple, que les modèles d'écran reçoivent ; leurs adaptateurs viendront dans
// ios/App/Services/ ; leurs faux, ci-dessous, servent aux tests et aux aperçus. Chacun est partageable entre
// fils (`Sendable`) et s'appelle en `await` : le système répond quand il veut.
//
// Une API minimale, celle que les écrans demandent aujourd'hui : chaque tâche de la feuille de route qui
// branche un service l'étend avec son adaptateur.

// MARK: Notifications

/// Une notification à faire paraître à un instant donné (Notifications.kt, Reminder.kt). Ses textes sont des
/// `Libelle` : l'adaptateur les résout dans la langue de l'app au moment de la programmer.
public struct NotificationPrevue: Sendable, Hashable, Identifiable {
    /// Fixe par genre de notification : en programmer une autre sous le même identifiant la remplace.
    public let identifiant: String
    /// L'instant où elle paraît, en millisecondes Unix.
    public let instant: Int64
    public let titre: Libelle
    public let corps: Libelle

    public var id: String { identifiant }

    public init(identifiant: String, instant: Int64, titre: Libelle, corps: Libelle) {
        self.identifiant = identifiant
        self.instant = instant
        self.titre = titre
        self.corps = corps
    }
}

/// Les notifications locales (`UNUserNotificationCenter` dans l'app).
public protocol Notificateur: Sendable {
    /// L'autorisation de notifier est-elle accordée ? Sans rien demander.
    func autorisation() async -> Bool
    /// Demande l'autorisation (iOS ne pose la question qu'une fois) ; vrai si elle est accordée.
    func demanderAutorisation() async -> Bool
    /// Programme ces notifications ; une notification déjà prévue sous le même identifiant est remplacée, les
    /// autres restent.
    func programmer(_ notifications: [NotificationPrevue]) async throws
    /// Retire toutes les notifications prévues (réinitialiser l'app, replanifier de zéro).
    func annulerTout() async
}

/// Un notificateur qui garde ce qu'on lui confie.
public actor FauxNotificateur: Notificateur {
    /// Les notifications prévues, dans l'ordre où elles ont été programmées.
    public private(set) var prevues: [NotificationPrevue] = []
    public private(set) var demandes = 0
    public private(set) var annulations = 0
    private let accordee: Bool

    public init(accordee: Bool = true) {
        self.accordee = accordee
    }

    public func autorisation() -> Bool {
        accordee
    }

    public func demanderAutorisation() -> Bool {
        demandes += 1
        return accordee
    }

    public func programmer(_ notifications: [NotificationPrevue]) {
        for notification in notifications {
            prevues.removeAll { $0.identifiant == notification.identifiant }
            prevues.append(notification)
        }
    }

    public func annulerTout() {
        prevues = []
        annulations += 1
    }
}

// MARK: Lieu

/// Une position approximative (de l'ordre du kilomètre, ChoixLieu.kt depuis le 31/10) : assez pour les
/// zmanim et la ville la plus proche, pas assez pour suivre quelqu'un.
public struct PositionApprochee: Sendable, Hashable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Ce qu'une demande de position rend.
public enum ReponseLocalisation: Sendable, Hashable {
    case position(PositionApprochee)
    /// L'autorisation est refusée : l'écran propose de choisir une ville.
    case refusee
    /// Aucune position en un temps raisonnable (hors ligne, à l'intérieur).
    case indisponible
}

/// La position du téléphone (`CLLocationManager` dans l'app).
public protocol Localisation: Sendable {
    /// Demande la position approximative, une fois ; l'autorisation d'abord si iOS ne l'a pas encore demandée.
    func positionApprochee() async -> ReponseLocalisation
}

/// Une localisation qui rend toujours la même réponse.
public actor FausseLocalisation: Localisation {
    public private(set) var demandes = 0
    private let reponse: ReponseLocalisation

    public init(_ reponse: ReponseLocalisation) {
        self.reponse = reponse
    }

    public func positionApprochee() -> ReponseLocalisation {
        demandes += 1
        return reponse
    }
}

// MARK: Son

/// La musique et les ambiances de la séance (`AVAudioPlayer` dans l'app).
public protocol LecteurSon: Sendable {
    /// Joue un fichier des ressources (`Musique/<id>.m4a`, `Morceau.fichier`) au volume donné, de 0 à 100,
    /// à la place de ce qui jouait.
    func jouer(fichier: String, volume: Int) async throws
    /// Arrête ce qui joue.
    func arreter() async
}

/// Un lecteur muet, qui retient ce qu'on lui a fait jouer.
public actor FauxLecteurSon: LecteurSon {
    /// Ce qui joue ; nil à l'arrêt.
    public private(set) var enCours: String?
    public private(set) var volume = 0
    /// Tout ce qui a été joué, dans l'ordre.
    public private(set) var joues: [String] = []

    public init() {}

    public func jouer(fichier: String, volume: Int) {
        enCours = fichier
        self.volume = volume
        joues.append(fichier)
    }

    public func arreter() {
        enCours = nil
    }
}

// MARK: Temps d'écran

/// La barrière « Je suis avec Hachem » côté app (Family Controls et Managed Settings, PORTAGE.md § 2.1).
public protocol TempsEcran: Sendable {
    /// Demande l'autorisation de Temps d'écran ; vrai si elle est accordée.
    func demanderAutorisation() async -> Bool
    /// Lève les boucliers posés sur les applications choisies : la hitbodedout du jour est faite.
    func leverBoucliers() async
}

public actor FauxTempsEcran: TempsEcran {
    public private(set) var demandes = 0
    public private(set) var levees = 0
    private let accordee: Bool

    public init(accordee: Bool = true) {
        self.accordee = accordee
    }

    public func demanderAutorisation() -> Bool {
        demandes += 1
        return accordee
    }

    public func leverBoucliers() {
        levees += 1
    }
}

// MARK: Live Activity

/// La séance en cours sur l'écran verrouillé et dans l'île dynamique (ActivityKit dans l'app,
/// PORTAGE.md § 2.2.1).
public protocol ActiviteEnDirect: Sendable {
    /// Montre la séance : son début et sa fin prévue, en millisecondes Unix.
    func commencer(debut: Int64, fin: Int64) async throws
    /// La retire : la séance est finie ou abandonnée.
    func terminer() async
}

public actor FausseActiviteEnDirect: ActiviteEnDirect {
    /// La séance montrée (début, fin) ; nil sans séance.
    public private(set) var seance: (debut: Int64, fin: Int64)?

    public init() {}

    public func commencer(debut: Int64, fin: Int64) {
        seance = (debut, fin)
    }

    public func terminer() {
        seance = nil
    }
}
