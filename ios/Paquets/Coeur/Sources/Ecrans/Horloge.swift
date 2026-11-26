import Foundation
import Coeur
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// L'heure qu'il est et le fuseau du téléphone, injectés : les modèles d'écran ne lisent jamais `Date()` ni
/// `TimeZone.current` (ECRANS.md), pour que leurs tests fixent l'instant.
public protocol Horloge: Sendable {
    /// L'instant présent, en millisecondes Unix (`System.currentTimeMillis()`).
    var maintenant: Int64 { get }
    /// Le fuseau du téléphone (`ZoneId.systemDefault()`).
    var fuseau: Fuseau { get }
    /// L'horloge qui ne recule jamais (SystemClock.elapsedRealtime et le compte des démarrages) : la séance s'y mesure
    /// depuis le 24/11 ; `.absente` par défaut, la séance se mesure alors à l'heure murale.
    var monotone: HorlogeMonotone { get }
}

extension Horloge {
    public var monotone: HorlogeMonotone { .absente }

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

    /// Le temps depuis le démarrage, sommeil compris (`CLOCK_MONOTONIC` de Darwin, `CLOCK_BOOTTIME` de Linux), et le
    /// démarrage qu'il compte : une empreinte de la session de démarrage (`kern.bootsessionuuid`), que le téléphone
    /// change à chaque démarrage. L'une ou l'autre illisible : `.absente`.
    public var monotone: HorlogeMonotone {
        guard let demarrage = HorlogeSysteme.demarrage else { return .absente }
        var t = timespec()
        #if canImport(Darwin)
        guard clock_gettime(CLOCK_MONOTONIC, &t) == 0 else { return .absente }
        #else
        guard clock_gettime(CLOCK_BOOTTIME, &t) == 0 else { return .absente }
        #endif
        return HorlogeMonotone(millis: Int64(t.tv_sec) * 1000 + Int64(t.tv_nsec) / 1_000_000, demarrage: demarrage)
    }

    /// L'empreinte de la session de démarrage, lue une fois : un entier positif sur 31 bits (`String.hashCode` de
    /// Kotlin, ramené au positif) ; nil si le système ne la donne pas.
    static let demarrage: Int? = {
        #if canImport(Darwin)
        var taille = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &taille, nil, 0) == 0, taille > 1 else { return nil }
        var octets = [CChar](repeating: 0, count: taille)
        guard sysctlbyname("kern.bootsessionuuid", &octets, &taille, nil, 0) == 0 else { return nil }
        let uuid = String(decoding: octets.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        #else
        guard let brut = try? String(contentsOfFile: "/proc/sys/kernel/random/boot_id", encoding: .utf8) else { return nil }
        let uuid = brut.trimmingCharacters(in: .whitespacesAndNewlines)
        #endif
        guard !uuid.isEmpty else { return nil }
        return Int(Kotlin.hashCode(uuid) & 0x7FFF_FFFF)
    }()
}

/// Une horloge arrêtée, pour les tests et les aperçus.
public struct HorlogeFixe: Horloge, Equatable {
    public var maintenant: Int64
    public var fuseau: Fuseau
    /// L'horloge monotone de l'essai ; absente par défaut (la séance à l'heure murale).
    public var monotone: HorlogeMonotone = .absente

    public init(maintenant: Int64, fuseau: Fuseau = .utc) {
        self.maintenant = maintenant
        self.fuseau = fuseau
    }

    /// Arrêtée à cette heure civile du fuseau (aux changements d'heure, la règle de `Fuseau.millis`).
    public init(_ dateHeure: DateHeure, fuseau: Fuseau) {
        self.init(maintenant: fuseau.millis(dateHeure), fuseau: fuseau)
    }
}
