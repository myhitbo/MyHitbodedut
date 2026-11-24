import Ecrans
import Foundation

/// La séance sur l'écran verrouillé et dans l'île dynamique (ActivityKit, PORTAGE.md § 2.2.1) : PAS ENCORE
/// RÉALISÉE, et elle le dit.
///
/// Une Live Activity se dessine dans une extension de widgets, avec ses attributs partagés entre l'app et
/// l'extension ; l'extension Widgets n'en a pas encore (tâche 25). Sans elle, `Activity.request` n'aurait rien à
/// montrer. `commencer` lève donc `NonRealisee` : `SeanceEnCours` l'attrape, et la séance court pareil, sans
/// faire croire qu'elle est affichée.
@MainActor
final class SystemeActiviteEnDirect: ActiviteEnDirect {

    /// La Live Activity n'existe pas encore dans l'app.
    struct NonRealisee: Error, Sendable {}

    init() {}

    func commencer(debut: Int64, fin: Int64) async throws {
        throw NonRealisee()
    }

    /// Rien n'est montré : rien à retirer.
    func terminer() async {}
}
