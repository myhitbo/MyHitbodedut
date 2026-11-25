import Foundation
import Observation
import Coeur

// L'écran de diagnostic des notifications en attente (ROADMAP, tâche 19 ; recette R3, geste 6). Propre à iOS :
// Android pose une alarme et décide au moment où elle sonne, iOS pose tout d'avance (PORTAGE.md § 2.2.2), sous une
// limite de 64. L'écran liste ce que le centre de notifications tient en attente, le compare au plan que le
// planificateur poserait maintenant (`PlanNotifications.planifier`, comme `SystemeRappels`), et signale un rappel
// qui tomberait un jour fait, un jour de repos ou une veille après midi (ReminderRule.shouldNotify).
//
// Le centre de notifications est derrière un protocole (`RappelsCentreNotifications`), réalisé dans l'app par
// `UNUserNotificationCenter.getPendingNotificationRequests` ; dans les tests et les aperçus,
// `RappelsFauxCentreNotifications`.

// MARK: Le centre de notifications

/// Une notification en attente dans le centre de notifications, telle qu'iOS la rend : ses textes déjà écrits dans
/// la langue de la pose.
public struct RappelsNotificationEnAttente: Sendable, Hashable, Identifiable {
    public let identifiant: String
    public let titre: String
    public let corps: String
    /// Le prochain déclenchement (millisecondes Unix) ; nil si iOS n'en donne pas.
    public let instant: Int64?
    /// L'instant est une date fixée à la pose (un déclencheur de calendrier). Faux pour un délai, dont iOS compte le
    /// prochain déclenchement depuis la lecture, pas depuis la pose : il ne se compare pas au plan.
    public let instantFixe: Bool
    /// La catégorie du plan (`NotificationPlanifiee.Categorie.rawValue`, la clé « categorie » de `userInfo`) ; nil
    /// pour une notification posée hors du plan.
    public let categorie: String?

    public var id: String { identifiant }

    public init(identifiant: String, titre: String, corps: String, instant: Int64?, instantFixe: Bool,
                categorie: String?) {
        self.identifiant = identifiant
        self.titre = titre
        self.corps = corps
        self.instant = instant
        self.instantFixe = instantFixe
        self.categorie = categorie
    }
}

/// Les notifications en attente (`UNUserNotificationCenter.getPendingNotificationRequests` dans l'app).
public protocol RappelsCentreNotifications: Sendable {
    func enAttente() async -> [RappelsNotificationEnAttente]
}

/// Un centre qui rend ce qu'on lui a dit de rendre.
public actor RappelsFauxCentreNotifications: RappelsCentreNotifications {
    private var notifications: [RappelsNotificationEnAttente]
    public private(set) var lectures = 0

    public init(_ notifications: [RappelsNotificationEnAttente] = []) {
        self.notifications = notifications
    }

    public func regler(_ notifications: [RappelsNotificationEnAttente]) {
        self.notifications = notifications
    }

    public func enAttente() -> [RappelsNotificationEnAttente] {
        lectures += 1
        return notifications
    }
}

// MARK: Ce que l'écran montre

/// Un texte de ligne : celui qu'iOS rend, déjà écrit, ou une chaîne du catalogue (une notification du plan qui
/// n'est pas en attente).
public enum RappelsTexte: Sendable, Hashable {
    case libelle(Libelle)
    case brut(String)
}

/// Ce que la ligne dit de la notification, comparée au plan.
public enum RappelsEcart: String, Sendable, Hashable, CaseIterable {
    /// En attente, dans le plan, à son instant.
    case conforme
    /// En attente et dans le plan, mais pas à l'instant du plan.
    case instantDifferent
    /// En attente, absente du plan : une pose ancienne qui n'a pas été retirée.
    case horsPlan
    /// En attente hors du plan, voulue : le « Mazal tov ! » de la fin de séance (`SeanceEnCours.identifiantFete`).
    case gardee
    /// Dans le plan, pas en attente : le plan n'a pas été reposé depuis, ou iOS l'a refusée.
    case absente

    /// Un écart à signaler.
    public var probleme: Bool {
        switch self {
        case .conforme, .gardee: false
        case .instantDifferent, .horsPlan, .absente: true
        }
    }
}

/// Une ligne de l'écran : une notification en attente, ou une notification du plan qui ne l'est pas.
public struct RappelsLigneDiagnostic: Sendable, Hashable, Identifiable {
    public let identifiant: String
    public let titre: RappelsTexte
    public let corps: RappelsTexte
    /// La catégorie du plan (« rappel », « chabbat », « levana », « vol », « seance ») ; nil hors du plan.
    public let categorie: NotificationPlanifiee.Categorie?
    /// L'instant montré : celui du centre pour une notification en attente, celui du plan sinon.
    public let instant: Int64?
    /// « Samedi 2026-11-28 07:00 » dans le fuseau du téléphone ; « — » sans instant.
    public let quand: String
    public let ecart: RappelsEcart
    /// Un rappel de hitbodedout qui tomberait un jour fait, un jour de repos ou une veille après midi : ce qui ne
    /// doit jamais arriver (recette R3).
    public let silenceEnfreint: Bool

    public var id: String { identifiant }

    /// Le nom de la catégorie (chaîne propre à iOS).
    public var libelleCategorie: Libelle {
        Libelle("rappels_categorie_" + (categorie?.rawValue ?? "autre"))
    }

    /// Ce que la ligne dit de l'écart (chaînes propres à iOS).
    public var etat: Libelle {
        Libelle("rappels_diagnostic_" + ecart.rawValue)
    }

    /// Ce qui est à signaler sur la ligne.
    public var probleme: Bool {
        ecart.probleme || silenceEnfreint
    }
}

/// Le nombre de notifications en attente d'une catégorie, et sa part du budget (PORTAGE.md § 2.2.2).
public struct RappelsCompte: Sendable, Hashable, Identifiable {
    /// nil : les notifications hors du plan.
    public let categorie: NotificationPlanifiee.Categorie?
    public let nombre: Int
    /// La part de la catégorie ; nil hors du plan.
    public let part: Int?

    public var id: String { categorie?.rawValue ?? "autre" }

    public var libelleCategorie: Libelle {
        Libelle("rappels_categorie_" + (categorie?.rawValue ?? "autre"))
    }

    /// « 12 / 30 », ou « 1 » hors du plan.
    public var texte: String {
        guard let part else { return String(nombre) }
        return String(nombre) + " / " + String(part)
    }
}

// MARK: Le modèle

/// L'écran de diagnostic. `charger()` lit le centre et calcule le plan ; la vue l'appelle à l'apparition et au
/// geste « Actualiser ».
@MainActor
@Observable
public final class RappelsDiagnosticModele {

    /// Le nombre de notifications en attente qu'iOS garde pour une app (Vérifié, PORTAGE.md § 2.2.2).
    public static let limite = 64

    private let magasin: Magasin
    private let horloge: any Horloge
    private let notificateur: any Notificateur
    private let centre: any RappelsCentreNotifications
    /// « fr », « en » ou « he » : le nom des jours.
    public let langue: String

    /// Une lecture a été faite : avant, la vue montre qu'elle charge.
    public private(set) var charge = false
    /// Une lecture est en cours.
    public private(set) var enCours = false
    public private(set) var notificationsAccordees = true
    /// Les lignes, par instant (sans instant en dernier), puis par identifiant.
    public private(set) var lignes: [RappelsLigneDiagnostic] = []
    /// Le nombre de notifications en attente.
    public private(set) var nombreEnAttente = 0
    /// L'heure de la lecture, « 2026-11-25 08:15 ».
    public private(set) var lecture: String = ""

    public init(magasin: Magasin, horloge: any Horloge, notificateur: any Notificateur,
                centre: any RappelsCentreNotifications, langue: String) {
        self.magasin = magasin
        self.horloge = horloge
        self.notificateur = notificateur
        self.centre = centre
        self.langue = Traducteur.langueApp(langue)
    }

    /// Un écran d'aperçu, sur un centre donné.
    public convenience init(apercu notifications: [RappelsNotificationEnAttente], reglages: Reglages = Reglages()) {
        self.init(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)), horloge: HorlogeSysteme(),
                  notificateur: FauxNotificateur(), centre: RappelsFauxCentreNotifications(notifications),
                  langue: "fr")
    }

    // MARK: Ce que l'écran montre

    public var titre: Libelle { Libelle("rappels_diagnostic_titre") }

    /// « 12 notifications en attente, sur 64 permises par iOS. »
    public var resume: Libelle {
        Libelle("rappels_diagnostic_resume", .entier(nombreEnAttente), .entier(RappelsDiagnosticModele.limite))
    }

    /// Le nombre de lignes à signaler.
    public var nombreDeProblemes: Int {
        lignes.filter(\.probleme).count
    }

    /// « Tout est conforme au plan. » ou « 3 écarts avec le plan. »
    public var verdict: Libelle {
        let n = nombreDeProblemes
        if n == 0 { return Libelle("rappels_diagnostic_verdict_conforme") }
        return Libelle("rappels_diagnostic_verdict_ecarts", .entier(n))
    }

    /// Les notifications sont refusées : rien de ce qui est en attente ne s'affichera.
    public var avertissement: Libelle? {
        notificationsAccordees ? nil : Libelle("reminders_permission_missing")
    }

    /// Le nombre en attente de chaque catégorie, dans l'ordre du plan, puis celles hors du plan s'il y en a.
    public var comptes: [RappelsCompte] {
        let enAttente = lignes.filter { $0.ecart != .absente }
        var res: [RappelsCompte] = NotificationPlanifiee.Categorie.allCases.map { categorie in
            RappelsCompte(categorie: categorie, nombre: enAttente.filter { $0.categorie == categorie }.count,
                          part: categorie.part)
        }
        let autres = enAttente.filter { $0.categorie == nil }.count
        if autres > 0 {
            res.append(RappelsCompte(categorie: nil, nombre: autres, part: nil))
        }
        return res
    }

    public var libelleActualiser: Libelle { Libelle("rappels_diagnostic_actualiser") }
    public var libelleVide: Libelle { Libelle("rappels_diagnostic_vide") }

    // MARK: La lecture

    /// Lit le centre et l'autorisation, calcule le plan d'après le magasin tel qu'il est (hors du fil principal : les
    /// zmanim de dix jours), puis compare. Une lecture demandée pendant une autre ne fait rien.
    public func charger() async {
        guard !enCours else { return }
        enCours = true
        defer { enCours = false }
        notificationsAccordees = await notificateur.autorisation()
        let attente = await centre.enAttente()
        let reglages = magasin.reglages
        let journal = magasin.journal
        let maintenant = horloge.maintenant
        let fuseau = horloge.fuseau
        let plan = await Task.detached(priority: .utility) {
            RappelsDiagnosticModele.planAttendu(reglages: reglages, journal: journal, maintenant: maintenant,
                                                fuseau: fuseau)
        }.value
        lignes = comparer(attente: attente, plan: plan, reglages: reglages, journal: journal, fuseau: fuseau)
        nombreEnAttente = attente.count
        let civile = fuseau.dateHeure(millis: maintenant)
        lecture = civile.jour.iso + " " + Store.formatMinutes(civile.minutesDuJour)
        charge = true
    }

    /// Le plan que `SystemeRappels` poserait maintenant. Les heures du vol s'y écrivent sans les aéroports
    /// (`instantTexte`) : seuls les identifiants et les instants comptent ici.
    nonisolated static func planAttendu(reglages: Reglages, journal: Journal, maintenant: Int64,
                                        fuseau: Fuseau) -> [NotificationPlanifiee] {
        PlanNotifications.planifier(reglages: reglages, journal: journal, volRappels: VolStockage.rappels(reglages),
                                    maintenant: maintenant, fuseau: fuseau)
    }

    /// Les lignes : chaque notification en attente, comparée au plan, puis chaque notification du plan qui n'est pas
    /// en attente ; triées par instant, puis par identifiant.
    func comparer(attente: [RappelsNotificationEnAttente], plan: [NotificationPlanifiee], reglages: Reglages,
                  journal: Journal, fuseau: Fuseau) -> [RappelsLigneDiagnostic] {
        var parIdentifiant: [String: NotificationPlanifiee] = [:]
        for notification in plan {
            parIdentifiant[notification.identifiant] = notification
        }
        var vus = Set<String>()
        var res: [RappelsLigneDiagnostic] = []
        for notification in attente {
            vus.insert(notification.identifiant)
            let prevue = parIdentifiant[notification.identifiant]
            let ecart: RappelsEcart
            if let prevue {
                if notification.instantFixe, let instant = notification.instant,
                   RappelsDiagnosticModele.distance(instant, prevue.instant) >= 1000 {
                    ecart = .instantDifferent
                } else {
                    ecart = .conforme
                }
            } else if notification.identifiant == SeanceEnCours.identifiantFete {
                ecart = .gardee
            } else {
                ecart = .horsPlan
            }
            let categorie = prevue?.categorie
                ?? notification.categorie.flatMap { NotificationPlanifiee.Categorie(rawValue: $0) }
            res.append(ligne(identifiant: notification.identifiant, titre: .brut(notification.titre),
                             corps: .brut(notification.corps), categorie: categorie, instant: notification.instant,
                             ecart: ecart, reglages: reglages, journal: journal, fuseau: fuseau))
        }
        for prevue in plan where !vus.contains(prevue.identifiant) {
            res.append(ligne(identifiant: prevue.identifiant, titre: .libelle(prevue.titre),
                             corps: .libelle(prevue.texte), categorie: prevue.categorie, instant: prevue.instant,
                             ecart: .absente, reglages: reglages, journal: journal, fuseau: fuseau))
        }
        return res.sorted { a, b in
            switch (a.instant, b.instant) {
            case let (x?, y?) where x != y: return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.identifiant < b.identifiant
            }
        }
    }

    private func ligne(identifiant: String, titre: RappelsTexte, corps: RappelsTexte,
                       categorie: NotificationPlanifiee.Categorie?, instant: Int64?, ecart: RappelsEcart,
                       reglages: Reglages, journal: Journal, fuseau: Fuseau) -> RappelsLigneDiagnostic {
        var quand = "—"
        var silence = false
        if let instant {
            let civile = fuseau.dateHeure(millis: instant)
            quand = TehilimModele.nomDuJour(civile.jour.jourDeSemaine, langue: langue) + " " + civile.jour.iso + " "
                + Store.formatMinutes(civile.minutesDuJour)
            if categorie == .rappel {
                silence = !RappelsDiagnosticModele.permis(civile, reglages: reglages, journal: journal, fuseau: fuseau)
            }
        }
        return RappelsLigneDiagnostic(identifiant: identifiant, titre: titre, corps: corps, categorie: categorie,
                                      instant: instant, quand: quand, ecart: ecart, silenceEnfreint: silence)
    }

    /// La règle du silence telle que le planificateur l'applique (PlanNotifications.rappels) : sans coucher du
    /// soleil, la limite de midi la veille d'un jour de repos.
    nonisolated static func permis(_ civile: DateHeure, reglages: Reglages, journal: Journal, fuseau: Fuseau) -> Bool {
        let jour = civile.jour
        let fuseauTelephone = fuseau.identifiant
        return ReminderRule.shouldNotify(
            nowMinutes: civile.heure * 60 + civile.minute,
            doneToday: Store.isDone(journal: journal, date: jour),
            todayIsRestDay: Store.isExempt(reglages: reglages, date: jour, fuseauTelephone: fuseauTelephone),
            tomorrowIsRestDay: Store.isEveOfRestDay(reglages: reglages, date: jour, fuseauTelephone: fuseauTelephone),
            sunsetMinutes: nil)
    }

    nonisolated private static func distance(_ a: Int64, _ b: Int64) -> Int64 {
        a > b ? a &- b : b &- a
    }
}
