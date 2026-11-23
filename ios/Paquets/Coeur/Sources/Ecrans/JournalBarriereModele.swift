import Foundation
import Observation
import Coeur
import Barriere

// Le journal de la barrière (PORTAGE.md § 2.1.8) : les cinquante derniers événements (armée à 06:02 par la
// surveillance, report de 15 min, levée par la séance…), du plus récent au plus ancien, que l'on peut partager. Android
// n'en a pas besoin, son service se voit dans sa notification permanente ; sur iOS la surveillance et le bouclier
// tournent dans des extensions muettes, et sans Mac ni débogueur c'est aussi l'outil de mise au point sur l'iPhone.

/// Une ligne du journal.
public struct JournalBarriereLigne: Sendable, Equatable, Identifiable {
    public let id: Int
    /// « 16/11 06:02 », dans le fuseau du téléphone au moment de l'événement.
    public let quand: String
    public let texte: Libelle
}

/// L'écran du journal de la barrière.
@MainActor
@Observable
public final class JournalBarriereModele {

    private let systeme: any BarriereSysteme

    /// Du plus récent au plus ancien.
    public private(set) var lignes: [JournalBarriereLigne] = []
    public private(set) var lu = false

    public init(systeme: any BarriereSysteme) {
        self.systeme = systeme
    }

    public func rafraichir() async {
        let evenements = await systeme.journal()
        lignes = JournalBarriereModele.lignes(evenements)
        lu = true
    }

    public var titre: Libelle { Libelle("journal_barriere_titre") }

    /// « Aucun événement pour l'instant. », une fois le journal lu et vide.
    public var vide: Libelle? {
        lu && lignes.isEmpty ? Libelle("journal_barriere_vide") : nil
    }

    /// Les lignes d'un journal tenu du plus ancien au plus récent, retournées.
    public static func lignes(_ evenements: [Evenement]) -> [JournalBarriereLigne] {
        evenements.enumerated().reversed().map { rang, evenement in
            JournalBarriereLigne(id: rang, quand: quand(evenement.quand), texte: libelle(evenement))
        }
    }

    /// « JJ/MM HH:MM ».
    static func quand(_ h: Horodatage) -> String {
        let morceaux = h.jour.split(separator: "-")
        let date = morceaux.count == 3 ? "\(morceaux[2])/\(morceaux[1])" : h.jour
        return date + " " + Store.formatMinutes(h.minutes)
    }

    /// Ce que dit un événement : le bouton touché, le report, le réveil et son activité, la pose ou la levée et qui
    /// l'a faite, l'essai, l'inscription des heures ; un genre inconnu (écrit par une autre version) se dit tel quel.
    public static func libelle(_ evenement: Evenement) -> Libelle {
        switch evenement.genreConnu {
        case .dejaFaite:
            return Libelle("journal_barriere_bouton", .libelle(Libelle("blocker_already_done")))
        case .commencer:
            return Libelle("journal_barriere_bouton", .libelle(Libelle("reminder_action_start")))
        case .autreReponse:
            return Libelle("journal_barriere_bouton", .libelle(Libelle("bouclier_autre_reponse")))
        case .plusTard:
            return Libelle("journal_barriere_report", .entier(Int(evenement.detail) ?? 0))
        case .reveil:
            return Libelle("journal_barriere_reveil", .libelle(activite(evenement.detail)))
        case .armee:
            return Libelle("journal_barriere_armee", .libelle(agent(evenement.detail)))
        case .levee:
            return Libelle("journal_barriere_levee", .libelle(agent(evenement.detail)))
        case .essai:
            return Libelle(evenement.detail == Etat.essaiFini ? "journal_barriere_essai_fin" : "journal_barriere_essai_debut")
        case .inscrite:
            return Libelle("journal_barriere_inscrite")
        case nil:
            return Libelle("journal_barriere_inconnu", .texte(evenement.genre))
        }
    }

    /// L'activité réveillée (`Activite`).
    static func activite(_ nom: String) -> Libelle {
        switch Activite(rawValue: nom) {
        case .fenetre: Libelle("journal_barriere_activite_fenetre")
        case .minuit: Libelle("journal_barriere_activite_minuit")
        case .report: Libelle("journal_barriere_activite_report")
        case .seance: Libelle("journal_barriere_activite_seance")
        case .essai: Libelle("journal_barriere_activite_essai")
        case nil: Libelle("journal_barriere_inconnu", .texte(nom))
        }
    }

    /// Qui a posé ou levé le bouclier.
    static func agent(_ detail: String) -> Libelle {
        switch AgentBarriere(rawValue: detail) {
        case .surveillance: Libelle("journal_barriere_par_surveillance")
        case .app: Libelle("journal_barriere_par_app")
        case .bouclier: Libelle("journal_barriere_par_bouclier")
        case .correction: Libelle("journal_barriere_par_correction")
        case nil: Libelle("journal_barriere_inconnu", .texte(detail))
        }
    }

    /// Le texte à partager : une ligne par événement, du plus récent au plus ancien, dans la langue de l'app.
    public func partage(_ traducteur: Traducteur) -> String {
        ([traducteur.texte(titre)] + lignes.map { $0.quand + "  " + traducteur.texte($0.texte) }).joined(separator: "\n")
    }
}
