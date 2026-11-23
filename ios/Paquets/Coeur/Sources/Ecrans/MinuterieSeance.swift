import Foundation
import Observation
import Coeur

// La « minuterie système » (tâche 17, PORTAGE.md § 2.2.1) : un signal de fin sûr, téléphone en silencieux. Sur Android,
// une séance minutée finit par la sonnerie de notification, et par un son de plus quand le décompte est masqué
// (SessionService.finishSession, chime) : quelque chose doit dire que le temps est écoulé. Sur iOS, la notification de
// fin se tait en silencieux et sous un mode de concentration ; ce réglage, propre à iOS et éteint d'origine, pose en
// plus une alarme d'AlarmKit à l'heure de la fin, que le système fait sonner malgré le silencieux et la concentration.
//
// Une alarme à heure fixe, pas une minuterie qui décompte : la Live Activity de la séance montre déjà le temps qui reste
// (et le tait sous « Masquer le décompte ») ; un décompte d'AlarmKit en ferait un second, qu'il faudrait de plus
// dessiner dans l'extension des widgets. L'alarme est posée au début d'une séance minutée (`SeanceEnCours.commencer`),
// retirée par « Terminer maintenant » et « Abandonner » ; arrivée à son terme, la séance la laisse sonner, et le son de
// fin de l'app se tait (un seul son, comme sur Android). Sans l'autorisation des alarmes, rien n'est posé : la
// séance finit comme avant, par la notification.
//
// L'appel au système (AlarmKit) est derrière `MinuterieSysteme`, que l'app branche (App/Services/Minuterie.swift).

/// Où en est l'autorisation des alarmes (`AlarmManager.AuthorizationState`).
public enum EtatMinuterie: Sendable, Hashable {
    case accordee
    /// Refusée : seuls les Réglages d'iOS la rendent.
    case refusee
    /// iOS n'a pas encore posé la question.
    case aDemander
}

/// Les alarmes du système (AlarmKit dans l'app).
public protocol MinuterieSysteme: Sendable {
    /// Où en est l'autorisation, sans rien demander.
    func etat() async -> EtatMinuterie
    /// Demande l'autorisation (iOS ne pose la question qu'une fois) ; vrai si elle est accordée.
    func demanderAutorisation() async -> Bool
    /// Pose l'alarme de fin de séance à `fin` (millisecondes Unix), à la place de toute autre ; `titre` est ce que
    /// l'alarme affiche. Vrai si elle est posée.
    func poser(fin: Int64, titre: Libelle) async -> Bool
    /// Retire l'alarme de fin de séance, posée ou en train de sonner.
    func retirer() async
}

/// Des alarmes qui ne sonnent pas, et retiennent ce qu'on leur demande : pour les tests et les aperçus.
public actor FausseMinuterie: MinuterieSysteme {
    public private(set) var autorisation: EtatMinuterie
    /// Ce que donnera une demande d'autorisation.
    private let reponse: Bool
    /// L'heure de l'alarme posée ; nil sans alarme.
    public private(set) var posee: Int64? = nil
    public private(set) var titre: Libelle? = nil
    public private(set) var poses = 0
    public private(set) var retraits = 0
    public private(set) var demandes = 0

    public init(autorisation: EtatMinuterie = .accordee, reponse: Bool = true) {
        self.autorisation = autorisation
        self.reponse = reponse
    }

    public func etat() -> EtatMinuterie { autorisation }

    public func demanderAutorisation() -> Bool {
        demandes += 1
        if autorisation == .aDemander { autorisation = reponse ? .accordee : .refusee }
        return autorisation == .accordee
    }

    public func poser(fin: Int64, titre: Libelle) -> Bool {
        guard autorisation == .accordee else { return false }
        poses += 1
        posee = fin
        self.titre = titre
        return true
    }

    public func retirer() {
        retraits += 1
        posee = nil
        titre = nil
    }
}

/// Le réglage « minuterie système », propre à iOS (clé « minuterie_systeme », hors de l'export d'Android) : éteint
/// d'origine. Comme `SeanceSujet`, il se lit et s'écrit dans l'objet des réglages sans toucher aux autres clés.
public enum MinuterieReglage {

    public static let cle = "minuterie_systeme"

    /// Seul un booléen vrai l'allume.
    public static func lire(_ reglages: Reglages) -> Bool {
        if case .booleen(let valeur)? = reglages.brut[cle] { return valeur }
        return false
    }

    public static func poser(_ actif: Bool, dans reglages: inout Reglages) {
        var brut = reglages.brut
        brut[cle] = .booleen(actif)
        reglages = Reglages(brut: brut)
    }
}

/// La ligne « Minuterie système » des réglages : l'interrupteur montre ce qui sonnera vraiment (le réglage, et
/// l'autorisation des alarmes), comme celui du verrou du journal.
@MainActor
@Observable
public final class MinuterieModele {

    /// Le titre de l'alarme : celui de la notification de fin (SessionService.notifyCompleted).
    public static let titreAlarme = Libelle("session_done_title")

    private let magasin: Magasin
    private let systeme: any MinuterieSysteme
    /// L'autorisation, telle que lue au dernier `rafraichir`.
    public private(set) var etat: EtatMinuterie = .aDemander

    public init(magasin: Magasin, systeme: any MinuterieSysteme) {
        self.magasin = magasin
        self.systeme = systeme
    }

    /// L'alarme sonnera à la fin d'une séance minutée : le réglage est allumé et les alarmes autorisées.
    public var actif: Bool {
        MinuterieReglage.lire(magasin.reglages) && etat == .accordee
    }

    /// Relit l'autorisation (onResume des réglages) : retirée dans les Réglages d'iOS, l'interrupteur s'éteint.
    public func rafraichir() async {
        etat = await systeme.etat()
    }

    /// L'interrupteur. L'allumer demande l'autorisation des alarmes si iOS ne l'a pas encore posée ; refusée, il reste
    /// éteint et rend le message à dire. L'éteindre retire l'alarme d'une séance en cours. Rend le message, ou nil.
    @discardableResult
    public func basculer(_ voulu: Bool) async throws -> Libelle? {
        guard voulu else {
            try await magasin.modifierReglages { MinuterieReglage.poser(false, dans: &$0) }
            await systeme.retirer()
            return nil
        }
        var lu = await systeme.etat()
        if lu == .aDemander {
            _ = await systeme.demanderAutorisation()
            lu = await systeme.etat()
        }
        etat = lu
        guard lu == .accordee else { return Libelle("reglages_minuterie_refusee") }
        try await magasin.modifierReglages { MinuterieReglage.poser(true, dans: &$0) }
        return nil
    }
}
