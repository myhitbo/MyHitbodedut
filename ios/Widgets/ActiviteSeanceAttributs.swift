import ActivityKit
import AppIntents
import Foundation

// Ce que l'app et l'extension Widgets partagent pour la Live Activity de la séance (PORTAGE.md § 2.2.1). Ce fichier
// est compilé dans les DEUX cibles (projet-commun.yml : la cible Widgets par son dossier, l'app par le gabarit App) :
// ActivityKit exige le même type d'attributs des deux côtés, et le bouton « Terminer » de l'extension nomme une
// intention que le système exécute dans le processus de l'app.
//
// Ce fichier est compilé dans l'app et dans l'extension (Foundation, ActivityKit, AppIntents seulement). Les textes
// arrivent déjà traduits, dans la langue de l'app (`SystemeActiviteEnDirect`, d'après la règle `SeanceActivite`
// d'Ecrans) : la Live Activity se dessine sans relire le catalogue.

/// Les attributs de la Live Activity de la séance. Rien de fixe : tout ce qui se montre peut changer pendant la
/// séance (le filtre de concentration, la langue de l'app au retour), et vit donc dans l'état.
struct ActiviteSeanceAttributs: ActivityAttributes {

    /// Ce que dit le décompte (`SeanceActivite.Decompte` d'Ecrans).
    enum Decompte: String, Codable, Hashable, Sendable {
        /// Le temps restant, jusqu'à `fin`.
        case reste
        /// Le temps passé depuis `debut`.
        case ecoule
        /// Rien.
        case masque
    }

    /// L'état de la séance montrée. Moins de 4 Ko encodé (la limite d'ActivityKit) : quelques phrases courtes.
    struct ContentState: Codable, Hashable, Sendable {
        /// Le décompte selon « Masquer le décompte » et la sorte de séance.
        var decompte: Decompte
        /// Le filtre du mode de concentration masque le décompte (`ConcentrationFiltre`) ; l'app le bascule seule
        /// quand iOS l'appelle pour le filtre (`ActiviteSeanceKit.concentration`).
        var concentration: Bool
        /// Le début de la séance.
        var debut: Date
        /// La fin prévue, ou le plafond d'une séance sans durée ; jamais avant `debut`.
        var fin: Date
        /// « Hitbodedout en cours ».
        var titre: String
        /// La légende sous le titre, hors filtre (`SeanceActivite.legende`).
        var legende: String
        /// « Le décompte est masqué. », la légende d'un décompte masqué (aussi par le seul filtre).
        var legendeConcentration: String
        /// « Terminer maintenant ».
        var terminer: String
        /// Ce que dit une séance dont la fin est passée sans que l'app soit revenue la clore.
        var echue: String
        /// La langue de l'app s'écrit de droite à gauche (l'hébreu), quelle que soit celle du téléphone.
        var droiteAGauche: Bool

        /// Le décompte tourne à l'écran (`SeanceActivite.montre` d'Ecrans, recopiée ici : l'extension n'a pas
        /// Ecrans, et le filtre peut basculer sans que l'app relise ses réglages).
        var decompteVisible: Bool {
            decompte != .masque && !concentration
        }

        /// La légende montrée (`SeanceActivite.legendeMontree`) : masqué par le seul filtre, aucun son n'est promis.
        var legendeMontree: String {
            concentration && decompte != .masque ? legendeConcentration : legende
        }

        /// L'intervalle du décompte, de `debut` à `fin`.
        var intervalle: ClosedRange<Date> {
            debut...max(debut, fin)
        }

        /// Le décompte descend vers la fin (une séance minutée) ; sinon il monte depuis le début.
        var descend: Bool {
            decompte == .reste
        }

        /// La phrase sous le titre ; `echue` (la fin est passée, `isStale` d'ActivityKit) : ce qu'il reste à faire.
        func phrase(echue: Bool) -> String {
            echue ? self.echue : legendeMontree
        }
    }
}

/// « Terminer maintenant » sur la Live Activity (l'action ACTION_FINISH de la notification d'Android) : la séance
/// se clôt et s'inscrit sans ouvrir l'app. Le système exécute une `LiveActivityIntent` dans le processus de l'app,
/// qu'il lance en arrière-plan au besoin : c'est là que `perform` passe par `SeanceEnCours.terminer()`
/// (`ActiviteSeanceRelais`, App/Services/SystemeActiviteEnDirect.swift). Dans l'extension, qui ne fait que nommer
/// l'intention pour son bouton, `perform` ne fait rien (`EXTENSION_WIDGETS`, posé par projet-commun.yml).
///
/// Ni Raccourcis ni Spotlight ne la proposent (`isDiscoverable`) : elle n'a de sens que sur une séance montrée.
struct ActiviteSeanceTerminer: LiveActivityIntent {

    static var title: LocalizedStringResource {
        LocalizedStringResource("ios_seance_terminer_intention", table: "ios")
    }

    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !EXTENSION_WIDGETS
        try await ActiviteSeanceRelais.terminer()
        #endif
        return .result()
    }
}
