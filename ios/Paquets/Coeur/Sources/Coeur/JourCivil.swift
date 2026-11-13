/// Un jour civil, sans heure ni fuseau : l'équivalent de `java.time.LocalDate`.
///
/// Jamais de `Date` pour un jour : c'est la première source d'erreurs de fuseau
/// (PORTAGE.md § 3.3). Le calendrier est le grégorien proleptique, celui de `java.time`.
/// L'arithmétique passe par le numéro de jour julien, sans `Calendar`.
public struct JourCivil: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let annee: Int
    public let mois: Int
    public let jour: Int

    /// Les années admises par `init?(annee:mois:jour:)`. Bien au-delà de l'usage ;
    /// la borne garde l'arithmétique loin des dépassements.
    public static let annees: ClosedRange<Int> = -999_999...999_999

    /// Le 1er janvier 1970 en jour julien.
    private static let jourJulien1970 = 2_440_588

    /// `nil` si le mois ou le jour n'existe pas (le 30 février, le 31 avril…).
    public init?(annee: Int, mois: Int, jour: Int) {
        guard JourCivil.annees.contains(annee), (1...12).contains(mois),
              jour >= 1, jour <= JourCivil.joursDansLeMois(mois, annee: annee)
        else { return nil }
        self.init(verifie: annee, mois, jour)
    }

    /// Lecture stricte de « 2026-11-04 », comme `Store.dateValide` d'Android :
    /// dix caractères, chiffres ASCII, jour existant. « 2026-9-5 » et « 2026-02-30 » sont refusés.
    /// Seules les années à quatre chiffres (0000 à 9999) s'écrivent ainsi.
    public init?(iso: String) {
        let o = Array(iso.utf8)
        let tiret = UInt8(ascii: "-")
        guard o.count == 10, o[4] == tiret, o[7] == tiret else { return nil }
        func nombre(_ plage: Range<Int>) -> Int? {
            var valeur = 0
            for i in plage {
                let c = o[i]
                guard c >= UInt8(ascii: "0"), c <= UInt8(ascii: "9") else { return nil }
                valeur = valeur * 10 + Int(c - UInt8(ascii: "0"))
            }
            return valeur
        }
        guard let a = nombre(0..<4), let m = nombre(5..<7), let j = nombre(8..<10) else { return nil }
        self.init(annee: a, mois: m, jour: j)
    }

    /// Le jour dont c'est le numéro julien (2 440 588 : 1er janvier 1970).
    public init(jourJulien: Int) {
        let (a, m, j) = JourCivil.civil(depuis1970: jourJulien - JourCivil.jourJulien1970)
        self.init(verifie: a, m, j)
    }

    private init(verifie annee: Int, _ mois: Int, _ jour: Int) {
        self.annee = annee
        self.mois = mois
        self.jour = jour
    }

    /// « 2026-11-04 ». Hors de 0000…9999, l'écriture de `java.time` : « +10000-01-01 », « -0001-01-01 ».
    public var iso: String {
        func deux(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        func quatre(_ n: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, 4 - s.count)) + s
        }
        let a: String
        if annee < 0 {
            a = "-" + quatre(-annee)
        } else if annee > 9999 {
            a = "+" + String(annee)
        } else {
            a = quatre(annee)
        }
        return "\(a)-\(deux(mois))-\(deux(jour))"
    }

    public var description: String { iso }

    /// Le numéro du jour julien (à midi) : 2 440 588 pour le 1er janvier 1970.
    public var jourJulien: Int {
        JourCivil.joursDepuis1970(annee, mois, jour) + JourCivil.jourJulien1970
    }

    /// Le jour `jours` plus tard (plus tôt si négatif).
    public func plus(jours: Int) -> JourCivil {
        JourCivil(jourJulien: jourJulien + jours)
    }

    /// 1 = dimanche … 7 = samedi, comme `Calendar.DAY_OF_WEEK` d'Android.
    public var jourDeSemaine: Int {
        let r = (jourJulien + 1) % 7  // le jour julien 0 est un lundi
        return (r < 0 ? r + 7 : r) + 1
    }

    public static func < (gauche: JourCivil, droite: JourCivil) -> Bool {
        (gauche.annee, gauche.mois, gauche.jour) < (droite.annee, droite.mois, droite.jour)
    }

    // MARK: Calendrier grégorien proleptique

    public static func estBissextile(_ annee: Int) -> Bool {
        annee % 4 == 0 && (annee % 100 != 0 || annee % 400 == 0)
    }

    public static func joursDansLeMois(_ mois: Int, annee: Int) -> Int {
        switch mois {
        case 2: estBissextile(annee) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    // Algorithmes de H. Hinnant (« chrono-Compatible Low-Level Date Algorithms ») :
    // l'année commence en mars, pour que le 29 février tombe en fin d'année ;
    // les divisions sont ramenées à des quotients entiers positifs par ère de 400 ans.

    private static func joursDepuis1970(_ a: Int, _ m: Int, _ j: Int) -> Int {
        let y = m <= 2 ? a - 1 : a
        let ere = (y >= 0 ? y : y - 399) / 400
        let anneeDeLEre = y - ere * 400                                   // 0…399
        let moisDepuisMars = m > 2 ? m - 3 : m + 9                        // mars = 0
        let jourDeLAnnee = (153 * moisDepuisMars + 2) / 5 + j - 1         // 0…365
        let jourDeLEre = anneeDeLEre * 365 + anneeDeLEre / 4 - anneeDeLEre / 100 + jourDeLAnnee
        return ere * 146_097 + jourDeLEre - 719_468
    }

    private static func civil(depuis1970 n: Int) -> (Int, Int, Int) {
        let z = n + 719_468
        let ere = (z >= 0 ? z : z - 146_096) / 146_097
        let jourDeLEre = z - ere * 146_097                                // 0…146 096
        let anneeDeLEre = (jourDeLEre - jourDeLEre / 1460 + jourDeLEre / 36_524
            - jourDeLEre / 146_096) / 365                                 // 0…399
        let jourDeLAnnee = jourDeLEre - (365 * anneeDeLEre + anneeDeLEre / 4 - anneeDeLEre / 100)
        let moisDepuisMars = (5 * jourDeLAnnee + 2) / 153                 // 0…11
        let j = jourDeLAnnee - (153 * moisDepuisMars + 2) / 5 + 1
        let m = moisDepuisMars < 10 ? moisDepuisMars + 3 : moisDepuisMars - 9
        return (anneeDeLEre + ere * 400 + (m <= 2 ? 1 : 0), m, j)
    }
}

/// Encodé comme sa forme ISO, la clé des journées dans la sauvegarde JSON.
extension JourCivil: Codable {
    public init(from decoder: any Decoder) throws {
        let conteneur = try decoder.singleValueContainer()
        let texte = try conteneur.decode(String.self)
        guard let jour = JourCivil(iso: texte) else {
            throw DecodingError.dataCorruptedError(
                in: conteneur, debugDescription: "jour civil invalide : « \(texte) »")
        }
        self = jour
    }

    public func encode(to encoder: any Encoder) throws {
        var conteneur = encoder.singleValueContainer()
        try conteneur.encode(iso)
    }
}
