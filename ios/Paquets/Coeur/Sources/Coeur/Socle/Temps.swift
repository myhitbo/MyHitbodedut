import Foundation

// Les heures civiles et les fuseaux comme `java.time` les compte. Les règles d'Android raisonnent
// sur des `LocalDateTime` (une date et une heure, sans fuseau) et passent par un fuseau pour en
// faire un instant : ici `DateHeure` et `Fuseau`. Jamais l'heure qu'il est ni le fuseau de la
// machine : tout se passe en argument. Jugé par `Tests/Vecteurs/temps.json`.

/// Une date et une heure civiles, sans fuseau : `java.time.LocalDateTime`, à la milliseconde.
public struct DateHeure: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let jour: JourCivil
    /// Millisecondes depuis minuit, de 0 à 86 399 999.
    public let millisDuJour: Int

    static let millisParJour = 86_400_000

    /// `date.atTime(heure, minute, seconde)`. Les champs hors bornes débordent sur les jours voisins.
    public init(_ jour: JourCivil, heure: Int = 0, minute: Int = 0, seconde: Int = 0, milli: Int = 0) {
        self.init(jour, millisDuJour: ((heure * 60 + minute) * 60 + seconde) * 1000 + milli)
    }

    /// Des millisecondes depuis minuit ; au-delà d'un jour, ou négatives, elles débordent sur les jours voisins.
    public init(_ jour: JourCivil, millisDuJour: Int) {
        let jours = Kotlin.floorDiv(millisDuJour, DateHeure.millisParJour)
        self.jour = jours == 0 ? jour : jour.plus(jours: jours)
        self.millisDuJour = Kotlin.floorMod(millisDuJour, DateHeure.millisParJour)
    }

    public var heure: Int { millisDuJour / 3_600_000 }
    public var minute: Int { millisDuJour / 60_000 % 60 }
    public var seconde: Int { millisDuJour / 1000 % 60 }
    public var milli: Int { millisDuJour % 1000 }

    /// Les minutes depuis minuit, de 0 à 1 439 : `hour * 60 + minute`.
    public var minutesDuJour: Int { millisDuJour / 60_000 }

    /// `plusSeconds`, `plusMinutes`, `plusHours`, `plusDays` ; négatif pour reculer.
    public func plus(jours: Int = 0, heures: Int = 0, minutes: Int = 0, secondes: Int = 0, millis: Int = 0) -> DateHeure {
        let decalage = ((heures * 60 + minutes) * 60 + secondes) * 1000 + millis
        return DateHeure(jours == 0 ? jour : jour.plus(jours: jours), millisDuJour: millisDuJour + decalage)
    }

    /// Les millisecondes de l'heure civile de `autre` jusqu'à celle-ci (négatif si elle la précède).
    public func millisDepuis(_ autre: DateHeure) -> Int {
        (jour.jourJulien - autre.jour.jourJulien) * DateHeure.millisParJour + millisDuJour - autre.millisDuJour
    }

    public static func < (gauche: DateHeure, droite: DateHeure) -> Bool {
        gauche.jour != droite.jour ? gauche.jour < droite.jour : gauche.millisDuJour < droite.millisDuJour
    }

    /// « 2026-11-13T08:15:30 », millisecondes omises.
    public var description: String {
        func deux(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        return "\(jour.iso)T\(deux(heure)):\(deux(minute)):\(deux(seconde))"
    }
}

/// Un fuseau horaire de la base IANA (« Asia/Jerusalem ») : `java.time.ZoneId`.
public struct Fuseau: Hashable, Sendable {
    public let identifiant: String
    private let zone: TimeZone

    /// `nil` si la base de fuseaux ne connaît pas cet identifiant.
    public init?(_ identifiant: String) {
        guard let zone = TimeZone(identifier: identifiant) else { return nil }
        self.identifiant = identifiant
        self.zone = zone
    }

    public static let utc: Fuseau = {
        guard let fuseau = Fuseau("UTC") else { preconditionFailure("le fuseau UTC manque à la base de fuseaux") }
        return fuseau
    }()

    /// Le décalage sur UTC en vigueur à cet instant (millisecondes Unix), en secondes.
    public func decalage(millis: Int64) -> Int {
        zone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(millis) / 1000))
    }

    /// `LocalDateTime.ofInstant(Instant.ofEpochMilli(millis), zone)` : l'instant vu de ce fuseau.
    public func dateHeure(millis: Int64) -> DateHeure {
        let local = millis + Int64(decalage(millis: millis)) * 1000
        let parJour = Int64(DateHeure.millisParJour)
        var jours = local / parJour
        var reste = local % parJour
        if reste < 0 {
            reste += parJour
            jours -= 1
        }
        return DateHeure(JourCivil(jourJulien: 2_440_588 + Int(jours)), millisDuJour: Int(reste))
    }

    /// `Instant.atZone(zone).toLocalDate()` : le jour civil de cet instant, vu de ce fuseau (`Store.dateOf`).
    public func jour(millis: Int64) -> JourCivil {
        dateHeure(millis: millis).jour
    }

    /// `dateHeure.atZone(zone).toInstant().toEpochMilli()`, avec les règles de `java.time` :
    /// dans l'heure qui n'existe pas (passage à l'heure d'été), l'heure est avancée de la durée du trou ;
    /// dans l'heure qui existe deux fois (retour à l'heure d'hiver), c'est la première qui est rendue.
    public func millis(_ dateHeure: DateHeure) -> Int64 {
        // L'heure civile comptée comme si elle était en UTC.
        let local = Int64(dateHeure.jour.jourJulien - 2_440_588) * Int64(DateHeure.millisParJour) + Int64(dateHeure.millisDuJour)
        let unJour = Int64(DateHeure.millisParJour)
        // Les décalages en vigueur la veille et le lendemain : s'ils diffèrent, l'heure change tout près.
        let avant = Int64(decalage(millis: local - unJour)) * 1000
        let apres = Int64(decalage(millis: local + unJour)) * 1000
        if avant == apres { return local - avant }
        let avantVaut = Int64(decalage(millis: local - avant)) * 1000 == avant
        let apresVaut = Int64(decalage(millis: local - apres)) * 1000 == apres
        if apresVaut && !avantVaut { return local - apres }
        // Les deux valent : l'heure existe deux fois, la première. Aucun ne vaut : l'heure n'existe pas,
        // et le décalage d'avant la rend avancée de la durée du trou.
        return local - avant
    }
}

/// Un instant vu d'un fuseau : `java.time.ZonedDateTime`, à la milliseconde.
/// L'ordre est celui des instants (`isBefore`, `isAfter`).
public struct DateHeureZonee: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Millisecondes Unix : `toInstant().toEpochMilli()`.
    public let millis: Int64
    public let fuseau: Fuseau

    /// `Instant.ofEpochMilli(millis).atZone(fuseau)`.
    public init(millis: Int64, fuseau: Fuseau) {
        self.millis = millis
        self.fuseau = fuseau
    }

    /// `ZonedDateTime.of(civile, fuseau)`, avec les règles de `Fuseau.millis` aux changements d'heure.
    public init(_ civile: DateHeure, fuseau: Fuseau) {
        self.init(millis: fuseau.millis(civile), fuseau: fuseau)
    }

    /// `toLocalDateTime()`.
    public var civile: DateHeure { fuseau.dateHeure(millis: millis) }

    /// `toLocalDate()`.
    public var jour: JourCivil { civile.jour }

    /// `hour * 60 + minute` de l'heure civile.
    public var minutesDuJour: Int { civile.minutesDuJour }

    /// `plusSeconds`, `plusMinutes`, `plusHours` : du temps qui s'écoule, compté sur l'instant.
    public func plus(heures: Int = 0, minutes: Int = 0, secondes: Int = 0) -> DateHeureZonee {
        DateHeureZonee(millis: millis + Int64((heures * 60 + minutes) * 60 + secondes) * 1000, fuseau: fuseau)
    }

    /// `plusDays` : le même jour civil décalé, à la même heure civile (pas 24 heures d'horloge).
    public func plus(jours: Int) -> DateHeureZonee {
        DateHeureZonee(civile.plus(jours: jours), fuseau: fuseau)
    }

    public static func < (gauche: DateHeureZonee, droite: DateHeureZonee) -> Bool {
        gauche.millis < droite.millis
    }

    public var description: String { "\(civile) [\(fuseau.identifiant)]" }
}
