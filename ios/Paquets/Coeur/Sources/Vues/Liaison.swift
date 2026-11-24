import Observation
import SwiftUI

// Une liaison (Binding) lue et écrite par deux fermetures de l'acteur principal.
//
// Pourquoi pas Binding(get:set:) : avec des fermetures @MainActor, Swift 6.3.3 (Xcode 26.6) plante en génération de
// code sur le thunk qui convertit la fermeture @isolated(any) attendue par Binding (le 24/11/2026, sur arm64 comme sur
// x86_64). Ici, la liaison passe par un chemin de clé sur un petit objet observable : aucune fermeture n'est convertie.

/// L'objet derrière la liaison : sa propriété `valeur` lit et écrit par les fermetures reçues. L'observation suit
/// les propriétés du modèle que lit `lire`, comme elle le ferait dans le corps d'une vue.
@MainActor
@Observable
final class Passerelle<Valeur> {
    @ObservationIgnored private let lire: @MainActor () -> Valeur
    @ObservationIgnored private let ecrire: @MainActor (Valeur) -> Void

    init(lire: @escaping @MainActor () -> Valeur, ecrire: @escaping @MainActor (Valeur) -> Void) {
        self.lire = lire
        self.ecrire = ecrire
    }

    var valeur: Valeur {
        get { lire() }
        set { ecrire(newValue) }
    }
}

extension Binding {
    /// La liaison qui lit par `lire` et écrit par `ecrire`, sur l'acteur principal.
    @MainActor
    static func passerelle(_ lire: @escaping @MainActor () -> Value,
                           _ ecrire: @escaping @MainActor (Value) -> Void) -> Binding<Value> {
        Bindable(Passerelle(lire: lire, ecrire: ecrire)).valeur
    }
}
