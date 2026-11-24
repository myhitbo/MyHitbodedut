import Barriere
import Ecrans
import Foundation

/// La barrière « Je suis avec Hachem » côté app (Family Controls, PORTAGE.md § 2.1) : l'autorisation de Temps
/// d'écran et la sélection des applications passent par SystemeFamilyControls (l'écran du choix des applications).
/// Le bouclier et la surveillance, eux, vivent dans les extensions (tâches 27 et 28) : l'app ne lève aucun
/// bouclier elle-même.
///
/// Temps d'écran demande l'entitlement `com.apple.developer.family-controls`, qu'Apple n'accorde en distribution
/// qu'à un compte de développeur, sur demande (décision D3) ; sans lui, `AuthorizationCenter` refuse, et l'écran des
/// réglages montre la barrière non autorisée, ce qui est vrai.
@MainActor
final class SystemeTempsEcran: TempsEcran, ReglagesBarriereSysteme {

    init() {}

    // MARK: TempsEcran

    /// La demande d'autorisation de Temps d'écran (`AuthorizationCenter`, SystemeFamilyControls) : vrai si elle
    /// est accordée. Sans l'entitlement accordé par Apple, iOS refuse et c'est faux.
    func demanderAutorisation() async -> Bool {
        await SystemeFamilyControls().demander() == .accordee
    }

    /// Aucun bouclier n'est posé par l'app : il n'y a rien à lever.
    func leverBoucliers() async {}

    // MARK: ReglagesBarriereSysteme

    /// Ce que l'app constate : l'autorisation de Temps d'écran telle qu'iOS la donne ; le reste (surveillance,
    /// bouclier) n'est pas encore connu de l'app (tâches 27 et 28).
    func constat() async -> Constat {
        Constat(autorise: await SystemeFamilyControls().etat() == .accordee)
    }

    /// Le nombre de jetons de la sélection gardée par l'écran du choix des applications.
    func nombreDeJetons() async -> Int {
        await SystemeFamilyControls().nombreDeJetons()
    }
}
