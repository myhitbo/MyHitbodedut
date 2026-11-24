import Ecrans
import Foundation
import UIKit

/// L'icône de l'app (IconeLanceur, PORTAGE.md § 2.3) : `UIApplication.setAlternateIconName`, nil pour l'icône
/// principale. Une icône que le paquet ne déclare pas (`CFBundleAlternateIcons`) est refusée par iOS, et l'erreur
/// remonte à l'écran : rien ne fait croire qu'elle a changé.
@MainActor
final class SystemeIcone: ReglagesIcone {

    /// iOS ne permet pas de changer d'icône.
    struct NonPermis: Error, Sendable {}

    init() {}

    func nomActuel() async -> String? {
        UIApplication.shared.alternateIconName
    }

    func changer(_ nom: String?) async throws {
        guard UIApplication.shared.supportsAlternateIcons else { throw NonPermis() }
        try await UIApplication.shared.setAlternateIconName(nom)
    }
}
