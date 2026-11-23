import Coeur
import Ecrans
import Foundation
import LocalAuthentication

// Le code du téléphone pour le verrou du journal (VerrouJournal.kt : KeyguardManager.isDeviceSecure et
// createConfirmDeviceCredentialIntent). `.deviceOwnerAuthentication` : Face ID ou Touch ID, et le code du téléphone à
// défaut ; sans code réglé sur le téléphone, la règle ne peut pas être évaluée, et il n'y a rien à demander.

@MainActor
final class CodeDuTelephoneSysteme: CodeDuTelephone {
    let traducteur: Traducteur

    init(traducteur: Traducteur) {
        self.traducteur = traducteur
    }

    /// Le téléphone a un code : sans lui, `.deviceOwnerAuthentication` ne peut pas être évaluée (`passcodeNotSet`).
    var ecranProtege: Bool {
        var erreur: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &erreur)
    }

    /// La demande du système ; `raison` se lit sous Touch ID et au-dessus du code (Face ID montre la sienne,
    /// NSFaceIDUsageDescription). Annulée ou ratée : faux. Hors du fil principal : le contexte naît et meurt ici.
    nonisolated func demander(raison: Libelle) async -> Bool {
        let contexte = LAContext()
        var erreur: NSError?
        guard contexte.canEvaluatePolicy(.deviceOwnerAuthentication, error: &erreur) else { return false }
        do {
            return try await contexte.evaluatePolicy(.deviceOwnerAuthentication,
                                                     localizedReason: traducteur.texte(raison))
        } catch {
            return false
        }
    }
}
