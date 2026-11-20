import Foundation
import Observation
import Coeur

// Ajouter du temps à un jour passé (AjoutTemps.kt d'Android, 16/10) : une hitbodedout faite hors du téléphone
// — dehors, le Chabbat, sans l'appareil — s'inscrit après coup, sur n'importe quel jour jusqu'à aujourd'hui,
// même un jour déjà fait (les minutes s'ajoutent, Store.addSession). Jamais un jour à venir
// (`AjoutTemps.possible`). S'ouvre depuis la bande de la semaine de l'accueil et depuis le calendrier.
//
// Un jour fait se corrige ou se retire (FDONNEES-04) : « Modifier » ouvre « Montrer la durée » (quand l'écran la
// propose), « Corriger la durée » (la durée inscrite est remplacée, Store.corrigerJour) et « Retirer cette
// journée » (après confirmation ; sa note reste, sans valider le jour).
//
// Trois fenêtres qui se suivent : le jour (ce qui y est inscrit, « Ajouter du temps », « Modifier »,
// « Retour ») ; la durée (les durées proposées, puis « Durée réglable… », DureeSeance.choisir) ; la durée
// réglable (un nombre de minutes, DureeSeance.saisir). Une durée choisie s'inscrit, ce qui est neuf est retenu
// comme fêté sans notification (l'app est ouverte : Celebrations.marquerNotifies), le widget se redessine, et
// un message bref le confirme (« Ajouté : 30 min. »).

/// Ce que le système fait après un ajout de temps : l'adaptateur de l'app redessine les widgets (WidgetCenter)
/// et retire le rappel « Il est temps… » déjà paru (UNUserNotificationCenter). À déplacer dans Services.swift
/// quand la séance en aura besoin aussi.
public protocol AjoutTempsSysteme: Sendable {
    /// Le widget de la série se redessine (StreakWidget.refresh).
    func rafraichirWidgets() async
    /// La journée est faite : le rappel du jour ne reste pas dans le centre de notifications (Store.addSession,
    /// `cancel(Notifications.ID_REMINDER)`, 02/11).
    func retirerRappelDuJour() async
}

/// Un système qui compte ce qu'on lui demande, pour les tests et les aperçus.
public actor AjoutTempsSystemeFaux: AjoutTempsSysteme {
    public private(set) var widgetsRafraichis = 0
    public private(set) var rappelsRetires = 0

    public init() {}

    public func rafraichirWidgets() {
        widgetsRafraichis += 1
    }

    public func retirerRappelDuJour() {
        rappelsRetires += 1
    }
}

/// La fenêtre montrée.
public enum AjoutTempsEtape: Sendable, Hashable {
    /// Le jour : son titre, ce qui y est inscrit, et les boutons.
    case jour
    /// « Combien de temps ? » : la liste des durées.
    case durees
    /// « Durée de la hitbodedout, en minutes » : le champ numérique.
    case saisie
    /// « Modifier » un jour fait : montrer, corriger, retirer.
    case modifier
    /// « Retirer cette journée ? » : la confirmation.
    case retrait
}

/// Une action de « Modifier » (AjoutTemps.modifier).
public enum AjoutTempsAction: String, Sendable, Hashable, CaseIterable, Identifiable {
    case montrer, corriger, retirer

    public var id: String { rawValue }

    public var libelle: Libelle {
        switch self {
        case .montrer: Libelle("jour_montrer_duree")
        case .corriger: Libelle("jour_corriger_duree")
        case .retirer: Libelle("jour_retirer")
        }
    }
}

/// Comment les fenêtres se sont fermées : l'écran qui les a ouvertes y répond.
public enum AjoutTempsIssue: Sendable, Hashable {
    /// Fermées sans rien inscrire (« Retour », un toucher à côté, une saisie qui n'est pas un nombre).
    case fermee
    /// « Montrer la durée » : l'accueil bascule l'affichage de la durée de ce jour sur la bande de la semaine.
    case montrer
    /// Des minutes ont été inscrites : l'écran qui l'a ouvert se rafraîchit (`apres()`).
    case ajoute(minutes: Int)
    /// La durée du jour a été corrigée ; 0 : la journée est retirée.
    case corrige(minutes: Int)
}

/// Une ligne de la liste des durées.
public struct AjoutTempsDuree: Sendable, Hashable, Identifiable {
    /// Les minutes proposées ; nil pour « Durée réglable… ».
    public let minutes: Int?
    public let libelle: Libelle

    public var id: Int { minutes ?? 0 }

    public init(minutes: Int?, libelle: Libelle) {
        self.minutes = minutes
        self.libelle = libelle
    }
}

/// Les fenêtres de l'ajout de temps à un jour.
@MainActor
@Observable
public final class AjoutTempsModele {

    // Les textes fixes (AjoutTemps.kt, DureeSeance.kt).
    public let boutonAjouter = Libelle("jour_ajouter_temps")
    public let boutonMontrer = Libelle("jour_montrer_duree")
    public let boutonRetour = Libelle("action_back")
    public let boutonModifier = Libelle("jour_modifier")
    public let boutonRetirer = Libelle("jour_retirer")
    public let titreSaisie = Libelle("duration_custom_title")
    public let indicationSaisie = Libelle("duration_custom_hint")
    /// « OK » du champ : `android.R.string.ok` sur Android, une chaîne du système ; clé neuve à ajouter au
    /// catalogue (fr « OK », en « OK », he « אישור »).
    public let boutonValider = Libelle("action_ok")

    private let magasin: Magasin
    private let horloge: any Horloge
    private let systeme: any AjoutTempsSysteme
    private let montrerPropose: Bool

    /// Le jour : la vue l'écrit en titre, en entier, dans la langue de l'app (`FormatStyle.FULL`).
    public let date: JourCivil
    /// La fenêtre montrée ; nil une fois toutes fermées (`issue` dit comment).
    public private(set) var etape: AjoutTempsEtape? = nil
    /// Comment elles se sont fermées ; nil tant qu'une est ouverte.
    public private(set) var issue: AjoutTempsIssue? = nil
    /// Le nombre écrit dans le champ de la durée réglable.
    public var saisie = ""
    /// La saisie refusée (vide, illisible, hors de 1 à 240) : la boîte reste ouverte et le dit sous le champ
    /// (FACCUEIL-15, DureeSeance.valide) ; nil sinon.
    public private(set) var erreurSaisie: Libelle? = nil
    /// La liste des durées sert à corriger le jour, non à y ajouter.
    public private(set) var correction = false
    /// Le message bref après un ajout (« Ajouté : 30 min. », un Toast court sur Android) ; nil sinon.
    public private(set) var confirmation: Libelle? = nil

    /// Le jour `date`, s'il est permis d'y ajouter du temps (aujourd'hui ou avant) ; nil sinon, et rien ne
    /// s'ouvre. `montrer` : l'écran qui l'ouvre propose « Montrer la durée » (la bande de la semaine de
    /// l'accueil, pour un jour fait) ; le calendrier ne la propose pas.
    public init?(magasin: Magasin, horloge: any Horloge, systeme: any AjoutTempsSysteme, date: JourCivil,
                 montrer: Bool = false) {
        guard AjoutTemps.possible(date, aujourdhui: horloge.aujourdhui) else { return nil }
        self.magasin = magasin
        self.horloge = horloge
        self.systeme = systeme
        self.date = date
        montrerPropose = montrer
        etape = .jour
    }

    /// Peut-on ajouter du temps à ce jour (aujourd'hui ou avant) ? L'accueil rend une case touchable, le
    /// calendrier montre son bouton « Ajouter du temps fait hors du téléphone », d'après cette règle.
    public static func possible(_ date: JourCivil, horloge: any Horloge) -> Bool {
        AjoutTemps.possible(date, aujourdhui: horloge.aujourdhui)
    }

    // MARK: Le jour

    /// Les minutes déjà inscrites ce jour, s'il est fait ; nil sinon (une note seule n'est pas faite).
    public var minutesFaites: Int? {
        guard let journee = magasin.journal.record(date), journee.faite else { return nil }
        return journee.minutes
    }

    /// Sous le titre : « Rien d'inscrit ce jour. » ou « Inscrit ce jour : 30 min. ».
    public var message: Libelle {
        guard let minutes = minutesFaites else { return Libelle("jour_rien") }
        return Libelle("jour_fait", .libelle(Store.formatDuration(minutes)))
    }

    /// « Montrer la durée » : proposé par l'écran qui ouvre, pour un jour fait ; sous « Modifier » depuis
    /// FDONNEES-04.
    public var montrerDuree: Bool {
        montrerPropose && minutesFaites != nil
    }

    /// Le bouton du milieu, « Modifier », pour un jour fait seulement.
    public var modifiable: Bool {
        minutesFaites != nil
    }

    /// « Modifier » : la liste des actions.
    public func modifier() {
        guard etape == .jour, modifiable else { return }
        etape = .modifier
    }

    /// Les actions de « Modifier », dans l'ordre d'Android.
    public var actions: [AjoutTempsAction] {
        montrerDuree ? [.montrer, .corriger, .retirer] : [.corriger, .retirer]
    }

    public func choisirAction(_ action: AjoutTempsAction) {
        guard etape == .modifier else { return }
        switch action {
        case .montrer: montrer()
        case .corriger:
            correction = true
            etape = .durees
        case .retirer:
            etape = .retrait
        }
    }

    /// « Retirer cette journée (30 min) ? Sa note, si elle en a une, reste. »
    public var messageRetrait: Libelle {
        Libelle("jour_retirer_confirmation", .libelle(Store.formatDuration(minutesFaites ?? 0)))
    }

    /// La journée retirée confirmée : la durée passe à 0 (Store.corrigerJour).
    public func confirmerRetrait() async throws {
        guard etape == .retrait else { return }
        try await corriger(0)
    }

    /// « Ajouter du temps fait hors du téléphone » : la liste des durées.
    public func ajouterTemps() {
        guard etape == .jour else { return }
        etape = .durees
    }

    /// « Montrer la durée ».
    public func montrer() {
        guard montrerDuree, etape == .jour || etape == .modifier else { return }
        fermer(.montrer)
    }

    /// « Retour », un toucher à côté d'une fenêtre, le geste de retour : tout se ferme sans rien inscrire.
    public func retour() {
        fermer(.fermee)
    }

    // MARK: La durée

    /// Le titre de la liste : « Combien de temps ? », ou « Corriger la durée ».
    public var titreDurees: Libelle {
        Libelle(correction ? "jour_corriger_duree" : "offline_how_long")
    }

    /// 5 min, 10 min, 15 min, 30 min, 1 h, 1 h 30, puis « Durée réglable… » (DureeSeance.choisir).
    public var durees: [AjoutTempsDuree] {
        var lignes = DureeSeance.proposees.map { AjoutTempsDuree(minutes: $0, libelle: Store.formatDuration($0)) }
        lignes.append(AjoutTempsDuree(minutes: nil, libelle: Libelle("duration_custom")))
        return lignes
    }

    /// Une ligne de la liste touchée : une durée s'inscrit, « Durée réglable… » ouvre le champ, prérempli avec la
    /// durée habituelle (et tout sélectionné).
    public func choisir(_ duree: AjoutTempsDuree) async throws {
        guard etape == .durees else { return }
        if let minutes = duree.minutes {
            try await (correction ? corriger(minutes) : inscrire(minutes))
        } else {
            saisie = String(magasin.reglages.targetMinutes)
            etape = .saisie
        }
    }

    /// « OK » du champ : un nombre de 1 à 240 minutes s'inscrit ; sinon la boîte reste ouverte et le dit (FACCUEIL-15).
    public func validerSaisie() async throws {
        guard etape == .saisie else { return }
        guard let minutes = DureeSeance.valide(saisie) else {
            erreurSaisie = Libelle("duration_custom_hint")
            return
        }
        erreurSaisie = nil
        try await (correction ? corriger(minutes) : inscrire(minutes))
    }

    /// Le message bref a été montré.
    public func confirmationVue() {
        confirmation = nil
    }

    // MARK: L'inscription

    /// Store.addSession au jour choisi (sans sujet), puis ce qui est neuf retenu comme fêté (paliers et
    /// trophées notifiés), le widget, le rappel du jour, et le message. Une écriture qui échoue laisse le
    /// changement dans le Magasin (la prochaine écriture l'emportera) : les minutes sont inscrites, les fenêtres
    /// se ferment quand même, et l'erreur remonte ensuite. Laisser la liste ouverte inviterait à choisir encore,
    /// et les minutes s'ajouteraient deux fois.
    private func inscrire(_ minutes: Int) async throws {
        var journal = magasin.journal
        var reglages = magasin.reglages
        let maintenant = horloge.maintenant
        let fuseau = horloge.fuseau
        Store.addSession(journal: &journal, reglages: &reglages, minutes: minutes, note: nil, theme: nil, date: date,
                         millis: maintenant, fuseau: fuseau)
        let aujourdhui = horloge.aujourdhui
        let telephone = fuseau.identifiant
        let bilan = Store.bilan(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: telephone)
        let pratique = Store.pratique(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                      fuseauTelephone: telephone)
        let neuf = Celebrations.marquerNotifies(bilan, pratique, paliersNotifies: reglages.paliersNotifies,
                                                tropheesNotifies: reglages.tropheesNotifies)
        reglages.setPaliersNotifies(neuf.marques)
        reglages.setTropheesNotifies(neuf.trophees)
        let journalFinal = journal
        let reglagesFinals = reglages
        var echec: (any Error)? = nil
        do {
            try await magasin.modifierJournal { $0 = journalFinal }
        } catch {
            echec = error
        }
        do {
            try await magasin.modifierReglages { $0 = reglagesFinals }
        } catch {
            if echec == nil {
                echec = error
            }
        }
        await systeme.rafraichirWidgets()
        if minutes > 0 {
            await systeme.retirerRappelDuJour()
        }
        confirmation = Libelle("jour_ajoute", .libelle(Store.formatDuration(minutes)))
        fermer(.ajoute(minutes: minutes))
        if let echec {
            throw echec
        }
    }

    /// Store.corrigerJour : la durée du jour remplacée (0 la retire ; la note reste). Aujourd'hui retiré, l'instant
    /// de la dernière séance n'honore plus la barrière. Le widget se redessine et un mot le confirme.
    private func corriger(_ minutes: Int) async throws {
        var journal = magasin.journal
        var reglages = magasin.reglages
        Store.corrigerJour(journal: &journal, reglages: &reglages, date: date, minutes: minutes,
                           aujourdhui: horloge.aujourdhui)
        let journalFinal = journal
        let reglagesFinals = reglages
        var echec: (any Error)? = nil
        do {
            try await magasin.modifierJournal { $0 = journalFinal }
        } catch {
            echec = error
        }
        do {
            try await magasin.modifierReglages { $0 = reglagesFinals }
        } catch {
            if echec == nil { echec = error }
        }
        await systeme.rafraichirWidgets()
        confirmation = minutes > 0 ? Libelle("jour_corrige", .libelle(Store.formatDuration(minutes))) : Libelle("jour_retire")
        fermer(.corrige(minutes: minutes))
        if let echec { throw echec }
    }

    private func fermer(_ comment: AjoutTempsIssue) {
        etape = nil
        issue = comment
    }
}
