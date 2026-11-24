import Barriere
import Ecrans
import Foundation

/// La barrière « Je suis avec Hachem » côté app (Family Controls et Managed Settings, PORTAGE.md § 2.1) : PAS ENCORE
/// RÉALISÉE, et elle le dit.
///
/// Temps d'écran demande l'entitlement `com.apple.developer.family-controls`, qu'Apple n'accorde en distribution
/// qu'à un compte de développeur, sur demande (décision D3) ; sans lui, `AuthorizationCenter` refuse. Cette
/// réalisation ne fait donc rien : l'autorisation n'est jamais dite accordée, aucun bouclier n'est dit levé.
/// L'écran des réglages montre alors la barrière non autorisée, ce qui est vrai.
@MainActor
final class SystemeTempsEcran: TempsEcran, ReglagesBarriereSysteme {

    init() {}

    // MARK: TempsEcran

    /// Rien n'est demandé : faux, l'autorisation n'est pas accordée.
    func demanderAutorisation() async -> Bool {
        false
    }

    /// Aucun bouclier n'est posé par l'app : il n'y a rien à lever.
    func leverBoucliers() async {}

    // MARK: ReglagesBarriereSysteme

    /// Ce que l'app constate : Temps d'écran n'est pas autorisé, le reste n'est pas connu.
    func constat() async -> Constat {
        Constat(autorise: false)
    }

    /// Aucune sélection d'applications n'existe sans Temps d'écran.
    func nombreDeJetons() async -> Int {
        0
    }
}
