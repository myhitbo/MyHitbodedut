import Foundation
import Observation
import Coeur

// La présentation du premier lancement (OnboardingActivity.kt, activity_onboarding.xml) : sept pages, une à la
// fois, et une sortie à tout moment. Les pages et le parcours sont les règles de Coeur (Onboarding.swift) ;
// l'image suit l'adresse (Personnage.pour), comme toute ImageView d'Android (PersonnageViewInflater).
//
// On y choisit l'adresse (le seul endroit avec les réglages), la durée habituelle et le rappel quotidien. Le
// rappel demande l'autorisation des notifications (le Notificateur des Services), puis fait replanifier les
// rappels (`PresentationRappels`, Reminder.reschedule d'Android).

// MARK: La replanification des rappels

/// Ce qui replanifie les rappels de la journée quand leurs réglages changent : `Reminder.reschedule(context)`
/// d'Android, que la présentation appelle après avoir allumé, éteint ou réglé le rappel. Dans l'app, le
/// planificateur des notifications (ROADMAP, tâche 12) ; dans les tests et les aperçus,
/// `PresentationRappelsEnMemoire`. Il reçoit les réglages tels qu'ils viennent d'être changés.
public protocol PresentationRappels: Sendable {
    func replanifier(_ reglages: Reglages) async
}

/// Des rappels qui retiennent chaque replanification demandée, sans rien programmer.
public actor PresentationRappelsEnMemoire: PresentationRappels {
    /// Les réglages de chaque replanification, dans l'ordre des demandes.
    public private(set) var replanifications: [Reglages] = []

    public init() {}

    public func replanifier(_ reglages: Reglages) {
        replanifications.append(reglages)
    }
}

// MARK: Ce que montrent les pages à choix

/// Un des quatre boutons de durée de la page « La hitbodedout » (onboarding_duree_0 à 3).
public struct PresentationDuree: Sendable, Hashable, Identifiable {
    /// 5, 10, 15 ou 30 (Onboarding.durees).
    public let minutes: Int
    /// « 15 min » (Store.formatDuration).
    public let libelle: Libelle
    /// C'est la durée habituelle réglée : le bouton est coché. Une durée réglée ailleurs (20, 45…) n'en coche
    /// aucun.
    public let choisie: Bool

    public var id: Int { minutes }
}

/// Un des deux boutons צדיק / צדקת de la page « Comment vous appeler ? » (onboarding_tsadik, onboarding_tsadeket).
public struct PresentationAdresse: Sendable, Hashable, Identifiable {
    public let adresse: Adresse
    /// « adresse_tsadik » ou « adresse_tsadeket ».
    public let libelle: Libelle
    /// C'est l'adresse réglée : le bouton est coché. Tant que rien n'est choisi, aucun ne l'est.
    public let choisie: Bool

    public var id: String { adresse.rawValue }
}

// MARK: Le modèle

/// La présentation (OnboardingActivity.kt) : la page montrée, ce qu'elle porte, et ses boutons.
///
/// Elle se montre une fois par version d'elle-même, installation existante comprise (`aMontrer`), et se revoit
/// depuis les réglages (« Revoir la présentation ») : un modèle neuf, à la première page. Quelle que soit la
/// sortie — « Commencer » sur la dernière page, « Passer », ou un geste qui ferme l'écran — elle est vue et ne
/// revient plus (`terminer`, `OnboardingActivity.finish`).
///
/// L'adresse, la durée et le rappel sont les réglages du `Magasin`, lus à chaque fois et écrits par les actions ;
/// la page montrée et l'état des dialogues sont à l'écran.
@MainActor
@Observable
public final class PresentationModele {
    private let magasin: Magasin
    private let notificateur: any Notificateur
    private let rappels: any PresentationRappels

    /// Le rang de la page montrée, de 0 à `Onboarding.dernier`. Il dure autant que l'écran : sur Android, une
    /// rotation ne ramenait pas à la première page (ETAT_INDEX).
    public private(set) var index: Int
    /// La présentation est finie : la vue se retire (`finish()`).
    public private(set) var termine = false
    /// Le choix de l'heure du rappel est ouvert (le TimePickerDialog d'Android).
    public private(set) var choixHeureOuvert = false
    /// La dernière demande d'autorisation des notifications a été refusée. Comme sur Android, le rappel reste
    /// réglé et la présentation n'en dit rien (c'est l'affaire des réglages, SettingsActivity) : la vue peut
    /// l'ignorer.
    public private(set) var notificationsRefusees = false

    /// `index` : la page où reprendre (une restauration d'état), ramenée dans les bornes ; la première sinon.
    public init(magasin: Magasin, notificateur: any Notificateur, rappels: any PresentationRappels, index: Int = 0) {
        self.magasin = magasin
        self.notificateur = notificateur
        self.rappels = rappels
        self.index = min(max(index, 0), Onboarding.dernier)
    }

    /// Une présentation sur des réglages donnés d'avance, dans un magasin en mémoire, avec un notificateur qui
    /// accorde tout et des rappels qui ne programment rien : pour les aperçus.
    public static func apercu(reglages: Reglages = Reglages(), index: Int = 0) -> PresentationModele {
        PresentationModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                           notificateur: FauxNotificateur(),
                           rappels: PresentationRappelsEnMemoire(),
                           index: index)
    }

    // MARK: Quand la montrer

    /// La présentation est-elle à montrer à l'ouverture de l'app (MainActivity.showOnboardingOnce) ? Tant que la
    /// version vue (« onboarded_version ») est inférieure à celle de la présentation (`Reglages.versionPresentation`,
    /// Onboarding.version) : une fois par version, installation existante comprise, le booléen de la v1.96
    /// (« onboarded ») ne la cachant plus.
    nonisolated public static func aMontrer(_ reglages: Reglages) -> Bool {
        !reglages.hasOnboarded
    }

    // MARK: La page montrée

    /// La page montrée (Onboarding.ecran).
    public var ecran: OnboardingEcran {
        Onboarding.ecran(index)
    }

    /// Le nombre de pages : sept.
    public var nombreDePages: Int {
        Onboarding.ecrans.count
    }

    /// La pastille du haut, « 3 / 7 » (onboarding_step).
    public var etape: Libelle {
        Libelle("onboarding_step", .entier(index + 1), .entier(Onboarding.ecrans.count))
    }

    /// Le titre de la page.
    public var titre: Libelle {
        Libelle(ecran.titre)
    }

    /// Le texte de la page.
    public var corps: Libelle {
        Libelle(ecran.corps)
    }

    /// L'adresse réglée ; nil tant que rien n'est choisi.
    public var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }

    /// Le nom de l'image de la page (ios/Ressources/Images), la pose féminine pour qui a choisi צדקת : elle change
    /// dès que l'adresse est choisie, sur la page même.
    public var illustration: String {
        Personnage.pour(adresse, ecran.illustration)
    }

    /// La page porte les deux boutons צדיק / צדקת (la page « adresse »).
    public var montreAdresse: Bool {
        ecran.choixAdresse
    }

    /// La page porte les quatre durées (la page « seance »).
    public var montreDurees: Bool {
        ecran.choixDuree
    }

    /// La page porte le rappel quotidien et son heure (la page « jours »).
    public var montreRappel: Bool {
        ecran.choixRappel
    }

    // MARK: Les choix

    /// Les deux boutons d'adresse, צדיק puis צדקת.
    public var adresses: [PresentationAdresse] {
        let choisie = adresse
        return Adresse.allCases.map { une in
            PresentationAdresse(adresse: une, libelle: Libelle(une.nom), choisie: une == choisie)
        }
    }

    /// Les quatre boutons de durée, dans l'ordre d'Onboarding.durees.
    public var durees: [PresentationDuree] {
        let cible = magasin.reglages.targetMinutes
        return Onboarding.durees.map { minutes in
            PresentationDuree(minutes: minutes, libelle: PresentationModele.libelleDuree(minutes), choisie: minutes == cible)
        }
    }

    /// L'intitulé de l'interrupteur du rappel.
    public var libelleRappel: Libelle {
        Libelle("onboarding_rappel")
    }

    /// Le rappel quotidien est allumé.
    public var rappelActif: Bool {
        magasin.reglages.reminderEnabled
    }

    /// La première heure de rappel, en minutes depuis minuit, de 0 à 1439 : celle que le bouton montre et d'où
    /// part le choix de l'heure ; 7 h sans heure réglée (Store.DEFAULT_REMINDER). Les autres heures se règlent
    /// dans les réglages. Une heure hors du jour, venue d'une ancienne version, se ramène dans le jour comme
    /// Android l'écrit (`(minutes / 60) % 24`, `minutes % 60`) ; une négative, qui l'aurait fait planter, aussi.
    public var heureRappel: Int {
        let premiere = magasin.reglages.reminderTimes.first ?? Reglages.defaultReminder
        return Kotlin.floorMod(premiere, ReminderRule.minutesParJour)
    }

    /// L'heure (0 à 23) de la première heure de rappel.
    public var heureRappelHeure: Int {
        heureRappel / 60
    }

    /// Les minutes (0 à 59) de la première heure de rappel.
    public var heureRappelMinute: Int {
        heureRappel % 60
    }

    /// Le texte du bouton de l'heure, « à 07:00 » (onboarding_rappel_heure) : la vue y glisse l'heure qu'elle a
    /// mise en forme (24 h ou 12 h selon le téléphone, `DateFormat.is24HourFormat`).
    public func libelleHeureRappel(_ heureMiseEnForme: String) -> Libelle {
        Libelle("onboarding_rappel_heure", .texte(heureMiseEnForme))
    }

    /// Ce que VoiceOver dit du bouton de l'heure, « Heure du rappel : 07:00 » (onboarding_rappel_heure_desc).
    public func descriptionHeureRappel(_ heureMiseEnForme: String) -> Libelle {
        Libelle("onboarding_rappel_heure_desc", .texte(heureMiseEnForme))
    }

    // MARK: Les boutons du bas

    /// La page montrée est la dernière, celle de la promesse.
    public var estDerniere: Bool {
        Onboarding.estDernier(index)
    }

    /// « Précédent » se voit, sauf sur la première page, où sa place reste vide (INVISIBLE, pas GONE).
    public var retourVisible: Bool {
        !Onboarding.estPremier(index)
    }

    /// « Passer » se voit, sauf sur la dernière page, où sa place reste vide.
    public var passerVisible: Bool {
        !Onboarding.estDernier(index)
    }

    /// Le grand bouton : « Commencer » sur la dernière page, « Suivant » ailleurs.
    public var libelleSuivant: Libelle {
        Onboarding.estDernier(index) ? Libelle("onboarding_start") : Libelle("onboarding_next")
    }

    public var libelleRetour: Libelle {
        Libelle("onboarding_back")
    }

    public var libellePasser: Libelle {
        Libelle("onboarding_skip")
    }

    // MARK: Le parcours

    /// Le grand bouton : la page suivante, ou, sur la dernière, la fin de la présentation.
    public func suivant() async throws {
        if Onboarding.estDernier(index) {
            try await terminer()
        } else {
            index = Onboarding.suivant(index)
        }
    }

    /// « Précédent » : la page d'avant ; rien sur la première.
    public func precedent() {
        index = Onboarding.precedent(index)
    }

    /// La page amenée par un glissement du doigt (le `TabView` paginé de PORTAGE.md, que la vue lie à `index`),
    /// ramenée dans les bornes. Android n'a que ses boutons : glisser ne termine rien et n'écrit rien.
    public func afficher(page: Int) {
        index = min(max(page, 0), Onboarding.dernier)
    }

    /// « Passer » : la présentation finit d'un geste, depuis n'importe quelle page.
    public func passer() async throws {
        try await terminer()
    }

    /// La fin de la présentation, quelle que soit la sortie (« Commencer », « Passer », la feuille glissée vers le
    /// bas) : elle est vue dans sa version actuelle et ne revient plus (Store.setOnboarded, qui retire aussi le
    /// booléen de la v1.96). La vue se retire aussitôt ; une écriture refusée se rend à l'appelant, le
    /// changement restant en mémoire (Magasin). La revoir depuis les réglages n'écrit rien de plus.
    public func terminer() async throws {
        termine = true
        choixHeureOuvert = false
        try await magasin.modifierReglages { $0.setOnboarded() }
    }

    // MARK: Les choix

    /// צדיק ou צדקת (OnboardingActivity.choisir). Toucher le bouton déjà coché le laisse coché : le choix est
    /// facultatif, mais une fois fait il se change et ne s'efface pas ici.
    public func choisirAdresse(_ adresse: Adresse) async throws {
        try await magasin.modifierReglages { $0.setAdresse(adresse.cle) }
    }

    /// La durée habituelle, parmi les quatre de la page (Onboarding.durees) ; une autre est ignorée. C'est celle
    /// du bouton « Commencer » de l'accueil.
    public func choisirDuree(_ minutes: Int) async throws {
        guard Onboarding.durees.contains(minutes) else { return }
        try await magasin.modifierReglages { $0.setTargetMinutes(minutes) }
    }

    /// L'interrupteur du rappel. L'allumer demande l'autorisation des notifications si elle n'est pas déjà
    /// accordée ; l'allumer ou l'éteindre fait replanifier les rappels. Un réglage qui ne change rien ne fait
    /// rien (Android ignorait l'interrupteur remis à sa place par l'écran).
    public func basculerRappel(_ actif: Bool) async throws {
        guard actif != rappelActif else { return }
        let echec = await ecrire { $0.setReminderEnabled(actif) }
        if actif {
            await demanderNotifications()
        }
        await rappels.replanifier(magasin.reglages)
        if let echec { throw echec }
    }

    /// Le bouton de l'heure : ouvre son choix, qui part de la première heure de rappel (`heureRappelHeure`,
    /// `heureRappelMinute`).
    public func ouvrirChoixHeure() {
        choixHeureOuvert = true
    }

    /// Le choix de l'heure fermé sans rien choisir : rien ne change.
    public func fermerChoixHeure() {
        choixHeureOuvert = false
    }

    /// L'heure choisie (OnboardingActivity.choisirHeure) : elle remplace la première heure de rappel, les autres
    /// restent (la liste se retrie) ; le rappel s'allume, l'autorisation se demande s'il le faut, et les rappels
    /// se replanifient.
    public func choisirHeureRappel(heure: Int, minute: Int) async throws {
        choixHeureOuvert = false
        let heures = magasin.reglages.reminderTimes
        let nouvelles = [heure * 60 + minute] + Array(heures.dropFirst())
        let echec = await ecrire { reglages in
            reglages.setReminderTimes(nouvelles)
            reglages.setReminderEnabled(true)
        }
        await demanderNotifications()
        await rappels.replanifier(magasin.reglages)
        if let echec { throw echec }
    }

    // MARK: Aides

    /// Change les réglages et les écrit ; rend l'erreur d'une écriture refusée au lieu de la lever, pour que la
    /// suite (l'autorisation, la replanification) suive ce que l'écran montre, le changement restant en mémoire.
    private func ecrire(_ changement: (inout Reglages) -> Void) async -> (any Error)? {
        do {
            try await magasin.modifierReglages(changement)
            return nil
        } catch {
            return error
        }
    }

    /// L'autorisation des notifications : rien si elle est déjà accordée, la question sinon (iOS ne la pose
    /// qu'une fois). OnboardingActivity.demanderNotifications.
    private func demanderNotifications() async {
        if await notificateur.autorisation() {
            notificationsRefusees = false
            return
        }
        let accordee = await notificateur.demanderAutorisation()
        notificationsRefusees = !accordee
    }

    /// Store.formatDuration : « 45 min », « 2 h », « 1 h 05 » (Store.swift est encore en chantier dans Coeur).
    /// La division et le reste tronquent vers zéro, comme en Kotlin.
    nonisolated private static func libelleDuree(_ minutes: Int) -> Libelle {
        if minutes < 60 { return Libelle("duration_minutes", .entier(minutes)) }
        if minutes % 60 == 0 { return Libelle("duration_hours", .entier(minutes / 60)) }
        return Libelle("duration_hours_minutes", .entier(minutes / 60), .entier(minutes % 60))
    }
}
