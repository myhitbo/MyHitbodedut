import Barriere
import Ecrans
import Foundation

/// La barrière « Je suis avec Hachem » côté app (Family Controls, PORTAGE.md § 2.1), pour l'écran des réglages :
/// l'autorisation de Temps d'écran (SystemeFamilyControls), la levée de tout (« Tout effacer ») et le constat de la
/// carte d'état. Le dépôt pour les extensions, les magasins nommés et la surveillance sont dans `SystemeBarriere`,
/// que ce service reçoit ; sans lui (`SystemeTempsEcran()`), il ne fait que l'autorisation et le compte des jetons.
///
/// Temps d'écran demande l'entitlement `com.apple.developer.family-controls`, qu'Apple n'accorde en distribution
/// qu'à un compte de développeur, sur demande (décision D3) ; sans lui, `AuthorizationCenter` refuse, et l'écran des
/// réglages montre la barrière non autorisée, ce qui est vrai.
@MainActor
final class SystemeTempsEcran: TempsEcran, ReglagesBarriereSysteme {

    private let barriere: SystemeBarriere?

    init(barriere: SystemeBarriere? = nil) {
        self.barriere = barriere
    }

    // MARK: TempsEcran

    /// La demande d'autorisation de Temps d'écran (`AuthorizationCenter`, SystemeFamilyControls) : vrai si elle
    /// est accordée, et la barrière est alors redéposée (les magasins ne retenaient rien sans elle). Sans
    /// l'entitlement accordé par Apple, iOS refuse et c'est faux.
    func demanderAutorisation() async -> Bool {
        let accordee = await SystemeFamilyControls().demander() == .accordee
        if accordee {
            await barriere?.deposer()
        }
        return accordee
    }

    /// « Tout effacer » : les magasins vidés, la surveillance arrêtée (SystemeBarriere.toutLever).
    func leverBoucliers() async {
        await barriere?.toutLever()
    }

    // MARK: ReglagesBarriereSysteme

    /// Ce que l'app constate (SystemeBarriere.constat) : l'autorisation, la surveillance inscrite, son dernier réveil,
    /// le magasin `barriere`. Sans `SystemeBarriere`, l'autorisation seule.
    func constat() async -> Constat {
        if let barriere {
            return await barriere.constat()
        }
        return Constat(autorise: await SystemeFamilyControls().etat() == .accordee)
    }

    /// Le nombre de jetons de la sélection gardée par l'écran du choix des applications.
    func nombreDeJetons() async -> Int {
        await SystemeFamilyControls().nombreDeJetons()
    }
}
