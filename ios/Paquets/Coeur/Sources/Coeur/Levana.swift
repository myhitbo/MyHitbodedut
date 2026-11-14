import Foundation

/// Birkat haLevana (Levana.kt ; revue du 14/10 sur le texte) :
///  - début : pas avant sept jours (Choulhan Aroukh O.H. 426:4) ; « la plupart des A'haronim »
///    permettent après trois jours (Michna Beroura 426:20) ; l'Ari attend sept jours ;
///  - fin : jusqu'au seizième jour non compris (426:3), soit quinze jours depuis le molad (MB 426:17) ;
///    le Rema : la mi-mois, 14 j 18 h 22 min (MB 426:19) ;
///  - pas avant Kippour ni avant Tich'a beAv (Rema 426:2) ; à leur sortie, oui ;
///  - motsaé Chabbat de préférence, si cette nuit tombe avant le 10 du mois, et pas un motsaé Chabbat
///    qui est Yom Tov.
/// Les heures sont celles de KosherJava (`getTchilasZmanKidushLevana3Days`, `7Days`,
/// `getSofZmanKidushLevana15Days`, `BetweenMoldos`), refaites à la milliseconde depuis le molad
/// (`CalendrierJuif.molad`). Les instants sont des millisecondes Unix. Le dessin de la lune et la jauge
/// sont des écrans : ils viendront avec le calendrier (ROADMAP, tâche 24).
public enum Levana {

    private static let jour: Int64 = 86_400_000
    /// Un mois lunaire moyen : 29 j 12 h 44 min 3,333 s (793 halakim).
    static let mois: Int64 = 2_551_443_333
    /// La moitié d'un mois lunaire, comme l'ajoute KosherJava : 14 j 18 h 22 min 1,666 s.
    private static let miMois: Int64 = 1_275_721_666

    /// Les trois usages : début (trois ou sept jours après le molad), fin (quinze jours ou mi-mois).
    public enum Usage: String, Sendable, CaseIterable {
        case troisMiMois = "trois_mi_mois"
        case septMiMois = "sept_mi_mois"
        case septQuinze = "sept_quinze"

        public var cle: String { rawValue }
        /// La chaîne qui le nomme.
        public var libelle: String { "levana_usage_\(rawValue)" }
        public var troisJours: Bool { self == .troisMiMois }
        public var quinzeJours: Bool { self == .septQuinze }

        /// L'usage par défaut d'un noussa'h : Edot haMizra'h le Choulhan Aroukh, Sefard l'Ari, Ashkenaz
        /// la Michna Beroura et le Rema.
        public static func duNusah(_ nusah: String) -> Usage {
            switch nusah {
            case "edot": .septQuinze
            case "sefard": .septMiMois
            default: .troisMiMois
            }
        }

        public static func duNusah(_ nusah: Nusah) -> Usage { duNusah(nusah.rawValue) }
    }

    public enum Restriction: String, Sendable {
        case kippour = "KIPPOUR"
        case tishaBeav = "TISHA_BEAV"
    }

    /// Une fenêtre : le molad, le début et la fin (millisecondes Unix), et ce qui a retardé le début.
    public struct Fenetre: Sendable, Equatable {
        public let molad: Int64
        public let debut: Int64
        public let fin: Int64
        public let restriction: Restriction?

        public var prochainMolad: Int64 { molad + Levana.mois }
        /// Le soir du début.
        public func premierSoir(_ fuseau: Fuseau) -> JourCivil { fuseau.jour(millis: debut) }
        /// Le soir de la nuit où la fenêtre se ferme.
        public func dernierSoir(_ fuseau: Fuseau) -> JourCivil { fuseau.jour(millis: fin - 12 * 3_600_000) }
    }

    public enum Etat: Sendable, Equatable {
        case dans(Int)
        case ceSoir
        case dernierSoir
    }

    /// La lune : la part éclairée du disque (0 à 1), si elle croît.
    public struct Lune: Sendable, Equatable {
        public let eclairage: Double
        public let croissante: Bool
    }

    /// La lune à un instant : Meeus, Astronomical Algorithms, ch. 48 (angle de phase approché), à un
    /// ou deux pour cent près, assez pour un dessin. Même formule que phaseLune() du web.
    public static func phase(millis: Int64) -> Lune {
        let jj = Double(millis) / 86_400_000.0 + 2_440_587.5
        let t = (jj - 2_451_545) / 36_525
        let r = Double.pi / 180
        let d = 297.8501921 + 445_267.1114034 * t
        let m = 357.5291092 + 35_999.0502909 * t
        let mp = 134.9633964 + 477_198.8675055 * t
        // Les termes dans l'ordre de Kotlin, qui les ajoute de gauche à droite.
        var i = 180 - d
        i -= 6.289 * sin(mp * r)
        i += 2.1 * sin(m * r)
        i -= 1.274 * sin((2 * d - mp) * r)
        i -= 0.658 * sin(2 * d * r)
        i -= 0.214 * sin(2 * mp * r)
        i -= 0.11 * sin(d * r)
        let reste = (d.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return Lune(eclairage: (1 + cos(i * r)) / 2, croissante: reste < 180)
    }

    /// La fenêtre du mois hébreu de `date`.
    private static func du(_ date: JourCivil, _ usage: Usage, _ fuseau: Fuseau) -> Fenetre {
        let ici = CalendrierJuif.dateJuive(date)
        let molad = CalendrierJuif.molad(annee: ici.annee, mois: ici.mois)
        var debut = molad + (usage.troisJours ? 3 : 7) * jour
        let fin = molad + (usage.quinzeJours ? 15 * jour : miMois)
        var restriction: Restriction?
        // Tichri et Av : pas avant la sortie de Kippour, de Tich'a beAv (le jeûne, même repoussé au 10).
        let moisDuDebut = CalendrierJuif.dateJuive(fuseau.jour(millis: debut)).mois
        if moisDuDebut == CalendrierJuif.Mois.tichri || moisDuDebut == CalendrierJuif.Mois.av {
            let tichri = moisDuDebut == CalendrierJuif.Mois.tichri
            let base = fuseau.jour(millis: molad)
            for k in -9...12 {
                let j = base.plus(jours: k)
                if tichri ? CalendrierJuif.estKippour(j) : CalendrierJuif.estTichaBeav(j) {
                    let sortie = soir(j, fuseau)
                    if sortie > debut {
                        debut = sortie
                        restriction = tichri ? .kippour : .tishaBeav
                    }
                    break
                }
            }
        }
        return Fenetre(molad: molad, debut: debut, fin: fin, restriction: restriction)
    }

    /// La fenêtre qui concerne le soir de `date` : celle du mois, ou celle du mois suivant si elle est passée.
    public static func fenetre(_ date: JourCivil, _ fuseau: Fuseau, _ usage: Usage = .septMiMois) -> Fenetre {
        let ici = du(date, usage, fuseau)
        if date <= ici.dernierSoir(fuseau) { return ici }
        let quantieme = CalendrierJuif.dateJuive(date).jour
        return du(date.plus(jours: 31 - quantieme + 2), usage, fuseau)
    }

    /// Le motsaé Chabbat conseillé de la fenêtre, à partir de `date` : sa nuit avant le 10, et pas Yom Tov.
    public static func motsaeChabbat(_ f: Fenetre, _ date: JourCivil, _ fuseau: Fuseau) -> JourCivil? {
        var d = f.premierSoir(fuseau)
        let dernier = f.dernierSoir(fuseau)
        while d <= dernier {
            if d.jourDeSemaine == 7 {
                let nuit = d.plus(jours: 1)
                if CalendrierJuif.dateJuive(nuit).jour <= 10 && !CalendrierJuif.estYomTovChome(nuit) {
                    return d >= date ? d : nil
                }
            }
            d = d.plus(jours: 1)
        }
        return nil
    }

    public static func etat(_ f: Fenetre, _ date: JourCivil, _ fuseau: Fuseau) -> Etat {
        let premier = f.premierSoir(fuseau)
        if date < premier { return .dans(premier.jourJulien - date.jourJulien) }
        return date == f.dernierSoir(fuseau) ? .dernierSoir : .ceSoir
    }

    /// La place d'un instant dans le mois lunaire, de 0 (molad) à 1 (molad suivant).
    public static func part(_ f: Fenetre, _ millis: Int64) -> Float {
        Float(min(max(Double(millis - f.molad) / Double(mois), 0), 1))
    }

    /// Le soir de `date` (20 h) : le point posé sur la jauge, l'heure de la lune dessinée.
    public static func soir(_ date: JourCivil, _ fuseau: Fuseau) -> Int64 {
        fuseau.millis(DateHeure(date, heure: 20))
    }
}
