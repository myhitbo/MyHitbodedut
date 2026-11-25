import Foundation
import Observation
import Coeur

// L'écran des rappels (RemindersActivity.kt, activity_reminders.xml, item_reminder.xml) : l'interrupteur général,
// l'avertissement quand les notifications sont refusées, la phrase du trophée tout proche, puis la liste des heures,
// chacune à changer ou à retirer, et « Ajouter une heure ».
//
// Les réglages sont ceux d'Android, sous ses clés (Reglages, Coeur) : `reminder_on`, `reminder_times` (et
// `reminder_minutes`, tenue à jour pour l'export), `rappel_trophee_proche`. Chaque changement fait replanifier les
// notifications (`PresentationRappels`, Reminder.reschedule d'Android) : sur iOS le plan entier est posé d'avance
// (PORTAGE.md § 2.2.2), d'où une différence voulue : la phrase du trophée, qu'Android écrit au déclenchement, est
// calculée à la programmation, et l'interrupteur du trophée fait donc lui aussi replanifier.
//
// Android n'a pas de choix des jours : le rappel se tait de lui-même les jours de repos, la veille après midi et une
// fois la séance faite (ReminderRule, appliquée par PlanNotifications) ; l'écran le dit (`reminders_hint`).

// MARK: Ce que l'écran ouvre

/// Ce qu'ouvre l'écran des rappels.
public enum RappelsRoute: Sendable, Hashable {
    /// Les notifications de l'app dans les Réglages d'iOS (`openNotificationSettingsURLString`) : une demande déjà
    /// présentée ne se repose plus (Permissions.notificationSettingsIntent d'Android).
    case reglagesNotifications
    /// L'écran de diagnostic des notifications en attente (ROADMAP, tâche 19) : `RappelsDiagnosticModele`.
    case diagnostic
}

/// Le choix d'heure ouvert (le TimePickerDialog d'Android).
public enum RappelsDialogue: Sendable, Hashable, Identifiable {
    /// « Ajouter une heure » : part de la dernière heure réglée, de 7 h sans heure.
    case ajout
    /// Changer l'heure de ce rang dans la liste (toucher la ligne).
    case modification(Int)

    public var id: String {
        switch self {
        case .ajout: "ajout"
        case .modification(let rang): "modification-" + String(rang)
        }
    }
}

/// Une ligne de la liste (item_reminder.xml) : l'heure, et de quoi la retirer.
public struct RappelsHeure: Sendable, Hashable, Identifiable {
    /// Son rang dans la liste : ce que `ouvrirModification(_:)` et `retirer(_:)` reçoivent.
    public let rang: Int
    /// Les minutes depuis minuit, telles que réglées.
    public let minutes: Int
    /// « 07:05 » (Store.formatMinutes), comme sur Android quel que soit le format du téléphone.
    public let texte: String

    public var id: Int { rang }
}

// MARK: Le modèle

/// L'écran des rappels. Les réglages se lisent dans le `Magasin` à chaque fois (un rappel réglé dans la
/// présentation se voit ici) ; l'autorisation des notifications se relit par `rafraichir()`, que la vue appelle à
/// l'apparition et au retour au premier plan (onResume → render d'Android).
@MainActor
@Observable
public final class RappelsModele {

    private let magasin: Magasin
    private let notificateur: any Notificateur
    private let rappels: any PresentationRappels

    /// L'entrée de l'écran de diagnostic se montre en bas de l'écran (ROADMAP, tâche 19 ; recette R3).
    public let diagnosticVisible: Bool

    /// Le choix d'heure ouvert ; nil sans fenêtre. La vue le remet à nil quand la feuille est glissée vers le bas.
    public var dialogue: RappelsDialogue? = nil

    /// L'autorisation des notifications a été lue une fois au moins : avant, aucun avertissement.
    public private(set) var systemeLu = false
    public private(set) var notificationsAccordees = false

    /// La demande d'autorisation a déjà été présentée depuis cet écran : la suivante passe par les Réglages d'iOS,
    /// qui ne reposent jamais la question.
    private var notificationsDemandees = false

    public init(magasin: Magasin, notificateur: any Notificateur, rappels: any PresentationRappels,
                diagnosticVisible: Bool = true) {
        self.magasin = magasin
        self.notificateur = notificateur
        self.rappels = rappels
        self.diagnosticVisible = diagnosticVisible
    }

    /// Un écran d'aperçu : des réglages donnés, dans un magasin en mémoire, avec des services qui ne font rien.
    public convenience init(apercu reglages: Reglages) {
        self.init(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                  notificateur: FauxNotificateur(),
                  rappels: PresentationRappelsEnMemoire())
    }

    private var reglages: Reglages { magasin.reglages }

    // MARK: Le système

    /// Relit l'autorisation des notifications (onResume).
    public func rafraichir() async {
        notificationsAccordees = await notificateur.autorisation()
        systemeLu = true
    }

    // MARK: Ce que l'écran montre

    public var titre: Libelle { Libelle("reminders_title") }

    /// Sous le titre du bandeau (render) : désactivés, aucune heure, ou le nombre d'heures réglées.
    public var resume: Libelle {
        if !reglages.reminderEnabled { return Libelle("reminders_off") }
        let nombre = reglages.reminderTimes.count
        if nombre == 0 { return Libelle("reminders_none") }
        return Libelle.pluriel("reminders_count", quantite: nombre, .entier(nombre))
    }

    /// L'illustration du bandeau, la pose féminine pour qui a choisi צדקת.
    public var illustration: String {
        Personnage.pour(Adresse.parse(reglages.adresse), "char_pointing")
    }

    /// Le rappel est allumé (`reminder_on`).
    public var actif: Bool { reglages.reminderEnabled }

    public var libelleInterrupteur: Libelle { Libelle("reminders_enable") }
    public var indicationInterrupteur: Libelle { Libelle("reminders_enable_hint") }

    /// « Les notifications sont refusées… » : le rappel est allumé mais ne s'affichera pas. Il faut le dire, pas
    /// laisser croire qu'il est actif. Nil tant que l'autorisation n'a pas été lue.
    public var avertissement: Libelle? {
        guard actif, systemeLu, !notificationsAccordees else { return nil }
        return Libelle("reminders_permission_missing")
    }

    /// Le rappel dit qu'un trophée est tout proche (`rappel_trophee_proche`, activé par défaut).
    public var tropheeProche: Bool { reglages.rappelTropheeProche }
    public var libelleTropheeProche: Libelle { Libelle("rappel_trophee_reglage") }

    public var titreHeures: Libelle { Libelle("reminders_hours") }
    public var indicationHeures: Libelle { Libelle("reminders_hours_hint") }
    /// Ce qui ne sonne pas : les jours de repos, une fois la hitbodedout faite (Android n'a pas de choix des jours).
    public var indicationJours: Libelle { Libelle("reminders_hint") }
    public var libelleAjouter: Libelle { Libelle("reminders_add") }
    public var libelleRetirer: Libelle { Libelle("reminders_remove") }
    /// Le lien vers l'écran de diagnostic (chaîne propre à iOS).
    public var libelleDiagnostic: Libelle { Libelle("rappels_diagnostic_titre") }

    /// Les heures réglées, dans l'ordre (Store.reminderTimes : triées et sans doublon).
    public var heures: [RappelsHeure] {
        var lignes: [RappelsHeure] = []
        for (rang, minutes) in reglages.reminderTimes.enumerated() {
            lignes.append(RappelsHeure(rang: rang, minutes: minutes, texte: Store.formatMinutes(minutes)))
        }
        return lignes
    }

    // MARK: Le choix de l'heure

    /// Les minutes d'où part le choix ouvert, ramenées dans la journée comme Android les donne au TimePickerDialog
    /// (`(minutes / 60) % 24`, `minutes % 60`) ; une valeur négative d'une ancienne version aussi.
    public var minutesDialogue: Int {
        let heures = reglages.reminderTimes
        let depart: Int
        switch dialogue {
        case .some(.modification(let rang)) where rang >= 0 && rang < heures.count:
            depart = heures[rang]
        default:
            depart = heures.last ?? Reglages.defaultReminder
        }
        return Kotlin.floorMod(depart, ReminderRule.minutesParJour)
    }

    /// L'heure (0 à 23) d'où part le choix.
    public var heureDialogue: Int { minutesDialogue / 60 }
    /// Les minutes (0 à 59) d'où part le choix.
    public var minuteDialogue: Int { minutesDialogue % 60 }

    /// « Ajouter une heure ».
    public func ouvrirAjout() {
        dialogue = .ajout
    }

    /// Toucher une ligne : changer son heure.
    public func ouvrirModification(_ rang: Int) {
        guard rang >= 0, rang < reglages.reminderTimes.count else { return }
        dialogue = .modification(rang)
    }

    /// Le choix fermé sans rien choisir : rien ne change.
    public func fermerDialogue() {
        dialogue = nil
    }

    /// L'heure choisie : ajoutée à la liste, ou mise à la place de celle qu'on a touchée (`enregistre`). La liste se
    /// retrie et perd ses doublons (Store.setReminderTimes). Le rappel ne s'allume pas pour autant, comme sur
    /// Android.
    public func choisir(heure: Int, minute: Int) async {
        guard let ouvert = dialogue else { return }
        dialogue = nil
        let nouvelle = heure * 60 + minute
        let heures = reglages.reminderTimes
        let nouvelles: [Int]
        switch ouvert {
        case .ajout:
            nouvelles = heures + [nouvelle]
        case .modification(let rang):
            nouvelles = RappelsModele.sans(rang, heures) + [nouvelle]
        }
        await enregistrer { $0.setReminderTimes(nouvelles) }
    }

    /// « Retirer » sur une ligne.
    public func retirer(_ rang: Int) async {
        let heures = reglages.reminderTimes
        guard rang >= 0, rang < heures.count else { return }
        let nouvelles = RappelsModele.sans(rang, heures)
        await enregistrer { $0.setReminderTimes(nouvelles) }
    }

    // MARK: Les interrupteurs

    /// L'interrupteur général. L'allumer demande l'autorisation des notifications s'il le faut (et rend la route
    /// des Réglages d'iOS si la question a déjà été posée) ; l'allumer ou l'éteindre fait replanifier. Un réglage
    /// qui ne change rien ne fait rien (l'interrupteur remis à sa place par l'écran).
    public func basculer(_ actif: Bool) async -> RappelsRoute? {
        guard actif != self.actif else { return nil }
        await ecrire { $0.setReminderEnabled(actif) }
        var route: RappelsRoute?
        if actif {
            route = await demanderNotificationsSiBesoin()
        }
        await rappels.replanifier(magasin.reglages)
        return route
    }

    /// L'interrupteur du trophée tout proche. Sur iOS la phrase s'écrit à la programmation : il fait replanifier.
    public func basculerTropheeProche(_ oui: Bool) async {
        guard oui != tropheeProche else { return }
        await enregistrer { $0.setRappelTropheeProche(oui) }
    }

    /// Toucher l'avertissement : la question d'iOS, ou ses Réglages si elle a déjà été posée.
    public func toucherAvertissement() async -> RappelsRoute? {
        await demanderNotificationsSiBesoin()
    }

    // MARK: Aides

    /// demandeNotificationsSiBesoin : rien si l'autorisation est accordée ; la question d'iOS la première fois ;
    /// les Réglages d'iOS ensuite, la question ne se reposant plus.
    private func demanderNotificationsSiBesoin() async -> RappelsRoute? {
        if await notificateur.autorisation() {
            notificationsAccordees = true
            systemeLu = true
            return nil
        }
        if notificationsDemandees { return .reglagesNotifications }
        notificationsDemandees = true
        notificationsAccordees = await notificateur.demanderAutorisation()
        systemeLu = true
        return nil
    }

    /// Change les réglages, les écrit, puis replanifie d'après les réglages tels qu'ils sont (`enregistre`).
    private func enregistrer(_ changement: (inout Reglages) -> Void) async {
        await ecrire(changement)
        await rappels.replanifier(magasin.reglages)
    }

    /// Change les réglages et les écrit. Une écriture refusée ne dit rien, comme Store sur Android : le changement
    /// reste en mémoire (Magasin), et la replanification le suit, comme ce que l'écran montre.
    private func ecrire(_ changement: (inout Reglages) -> Void) async {
        do {
            try await magasin.modifierReglages(changement)
        } catch {
            // La persistance a refusé d'écrire : le changement reste en mémoire.
        }
    }

    /// La liste sans l'élément de ce rang (`filterIndexed { i, _ -> i != position }`).
    nonisolated private static func sans(_ rang: Int, _ heures: [Int]) -> [Int] {
        var reste: [Int] = []
        for (i, h) in heures.enumerated() where i != rang {
            reste.append(h)
        }
        return reste
    }
}
