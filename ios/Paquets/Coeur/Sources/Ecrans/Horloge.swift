import Foundation
import Coeur

/// L'heure qu'il est et le fuseau du téléphone, injectés : les modèles d'écran ne lisent jamais `Date()` ni
/// `TimeZone.current` (ECRANS.md), pour que leurs tests fixent l'instant.
public protocol Horloge: Sendable {
    /// L'instant présent, en millisecondes Unix (`System.currentTimeMillis()`).
    var maintenant: Int64 { get }
    /// Le fuseau du téléphone (`ZoneId.systemDefault()`).
    var fuseau: Fuseau { get }
}

extension Horloge {
    /// Le jour civil qu'il est dans le fuseau du téléphone : `LocalDate.now()` d'Android.
    public var aujourdhui: JourCivil {
        fuseau.jour(millis: maintenant)
    }

    /// L'heure civile qu'il est dans le fuseau du téléphone : `LocalDateTime.now()`.
    public var dateHeure: DateHeure {
        fuseau.dateHeure(millis: maintenant)
    }
}

/// L'horloge du téléphone : la seule des modèles d'écran à lire l'heure de la machine.
public struct HorlogeSysteme: Horloge {
    public init() {}

    public var maintenant: Int64 {
        Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
    }

    /// Le fuseau du système ; UTC s'il n'a pas d'identifiant que la base des fuseaux connaisse.
    public var fuseau: Fuseau {
        Fuseau(TimeZone.current.identifier) ?? .utc
    }
}

/// Une horloge arrêtée, pour les tests et les aperçus.
public struct HorlogeFixe: Horloge, Equatable {
    public var maintenant: Int64
    public var fuseau: Fuseau

    public init(maintenant: Int64, fuseau: Fuseau = .utc) {
        self.maintenant = maintenant
        self.fuseau = fuseau
    }

    /// Arrêtée à cette heure civile du fuseau (aux changements d'heure, la règle de `Fuseau.millis`).
    public init(_ dateHeure: DateHeure, fuseau: Fuseau) {
        self.init(maintenant: fuseau.millis(dateHeure), fuseau: fuseau)
    }
}
