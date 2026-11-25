import Foundation
import Coeur

// Ce que la Live Activity de la séance montre, sur l'écran verrouillé et dans l'île dynamique (PORTAGE.md § 2.2.1) :
// la notification permanente de SessionService.kt (`runningText`, `session_running_title`, l'action
// « Terminer maintenant »), devenue un décompte que le système fait tourner seul (`Text(timerInterval:)`, dans
// Widgets/ActiviteSeance.swift). Rien n'y est recalculé à la seconde : l'app donne le début, la fin et ce que le
// décompte a le droit de dire ; elle ne renvoie l'état que s'il change (un réglage, le filtre de concentration).
//
// La règle est celle de l'écran de séance (`SeanceModele.decompte` et `legende`) : « Masquer le décompte »
// (`SessionRule.compteur`) l'emporte, et le filtre du mode de concentration (`ConcentrationFiltre`, propre à iOS)
// masque aussi. Promettre « rien à l'écran » et laisser le chiffre sur l'écran verrouillé ne serait pas tenir parole.
// Sous un décompte masqué, la légende est celle de la notification d'Android (`runningText` : session_running_hidden),
// pas celle de l'écran (session_hidden_caption) : hors de l'app, rien ne garantit encore le son qu'elle promet.
//
// Le masquage du filtre reste à part (`concentration`) : l'app le bascule seule sur une Live Activity déjà montrée,
// quand iOS l'appelle pour le filtre sans que les réglages soient lus (App/Services/SystemeActiviteEnDirect.swift).

/// L'état de la Live Activity d'une séance.
public struct SeanceActivite: Sendable, Hashable {

    /// Ce que dit le décompte.
    public enum Decompte: Sendable, Hashable, CaseIterable {
        /// Le temps restant, d'une séance minutée.
        case reste
        /// Le temps passé, d'une séance sans durée.
        case ecoule
        /// Rien.
        case masque
    }

    /// Le titre (la notification permanente d'Android, `SeanceEnCours.titreEnCours`).
    public static let titre = Libelle("session_running_title")
    /// Le bouton qui clôt la séance sans ouvrir l'app (ACTION_FINISH).
    public static let terminer = Libelle("session_finish_now")
    /// La légende d'un décompte masqué, par « Masquer le décompte » ou par le seul filtre de concentration
    /// (la notification permanente d'Android, `runningText`) : aucun son n'y est promis.
    public static let legendeConcentration = Libelle("session_running_hidden")
    /// Ce que dit une Live Activity dont la fin est passée sans que l'app soit revenue la clore : l'app, rouverte,
    /// l'inscrit (`SeanceEnCours.actualiser`). Chaîne propre à iOS (Ressources/Chaines/ios.xcstrings).
    public static let echue = Libelle("ios_seance_activite_echue")

    /// Le décompte selon « Masquer le décompte » et la sorte de séance (`Store.sessionCounter`).
    public let decompte: Decompte
    /// Le filtre du mode de concentration masque le décompte.
    public let concentration: Bool
    /// Le début de la séance, en millisecondes Unix.
    public let debut: Int64
    /// La fin montrée, en millisecondes Unix : la fin prévue, ou le plafond d'une séance sans durée ; jamais avant
    /// le début (l'intervalle du décompte ne peut pas être vide à l'envers).
    public let fin: Int64
    /// La légende sous le titre, hors filtre : celle de l'écran de séance, sauf sous un décompte masqué (celle de la
    /// notification d'Android).
    public let legende: Libelle

    private init(decompte: Decompte, concentration: Bool, debut: Int64, fin: Int64, legende: Libelle) {
        self.decompte = decompte
        self.concentration = concentration
        self.debut = debut
        self.fin = fin
        self.legende = legende
    }

    /// L'état d'une séance montrée de `debut` à `fin` (ce que `SeanceEnCours` passe à `ActiviteEnDirect`) ; nil si
    /// aucune séance n'est inscrite dans ces réglages : il n'y a rien à montrer.
    public static func pour(reglages: Reglages, debut: Int64, fin: Int64) -> SeanceActivite? {
        guard Store.hasSessionRecord(reglages: reglages) else { return nil }
        let decompte: Decompte
        let legende: Libelle
        switch Store.sessionCounter(reglages: reglages) {
        case .masque:
            decompte = .masque
            // SessionService.runningText (MASQUE) : sans la promesse du son de l'écran de séance.
            legende = SeanceActivite.legendeConcentration
        case .ecoule:
            decompte = .ecoule
            legende = Libelle("session_open_caption")
        case .reste:
            decompte = .reste
            legende = Libelle("session_target",
                              .libelle(Store.formatDuration(Store.sessionTarget(reglages: reglages))))
        }
        return SeanceActivite(decompte: decompte, concentration: ConcentrationFiltre.masqueDecompte(reglages),
                              debut: debut, fin: max(fin, debut), legende: legende)
    }

    /// Ce que le décompte montre vraiment : le filtre de concentration masque aussi.
    public var montre: Decompte {
        concentration ? .masque : decompte
    }

    /// La légende montrée : masqué par le seul filtre, celle d'un décompte masqué.
    public var legendeMontree: Libelle {
        concentration && decompte != .masque ? SeanceActivite.legendeConcentration : legende
    }
}
