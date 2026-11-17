import Foundation
import KosherSwift
import Synchronization

/// Birkat haLevana (Levana.kt) : la fenêtre du mois selon l'usage suivi, le motsaé Chabbat conseillé,
/// l'état d'un soir, la place d'un instant dans le mois lunaire et la phase de la lune. Le dessin de la
/// lune et la jauge du mois (`Levana.Dessin`, `Levana.Jauge`, des vues) restent à l'app.
///
///  - début : pas avant sept jours (Choulhan Aroukh O.H. 426:4) ; « la plupart des A'haronim »
///    permettent après trois jours d'heure à heure (Michna Beroura 426:20) ; l'Ari attend sept jours ;
///  - fin : jusqu'au seizième jour, non compris (426:3), soit quinze jours depuis l'heure du molad
///    (MB 426:17) ; le Rema : la mi-mois, 14 j 18 h 22 min (MB 426:19) ;
///  - pas avant Kippour ni avant Tich'a beAv (Rema 426:2) ; à leur sortie, oui (Rema ; MB 426:11 pour
///    Tich'a beAv) ;
///  - motsaé Chabbat de préférence, si cette nuit tombe avant le 10 du mois (Rema 426:2, MB 426:6),
///    et pas un motsaé Chabbat qui est Yom Tov ;
///  - audit du 16/11 : le Yalkut Yosef compte selon la date (`septNuitQuinze`, jusqu'au lever du soleil qui
///    clôt la nuit du 15 ; Kitsour YY 426:28, 37) ; les nuits sont bornées par la sortie des étoiles et le lever
///    du lieu (`Horaires`) ; le dernier soir est celui dont la nuit commence avant la fin ; un soir de Chabbat
///    ou de Yom tov n'est pas le premier soir conseillé (MB 426:12 ; Kitsour YY 426:33).
///
/// Le molad et les bornes viennent de KosherSwift 1.10.11, comme de KosherJava sur Android
/// (`getMoladAsDate`, `getTchilasZmanKidushLevana3Days` et `7Days`, `getSofZmanKidushLevana15Days`), lus à
/// la milliseconde de KosherJava (`millis`). Seule la mi-mois est comptée ici : KosherSwift ajoute au molad
/// 1 275 721,667 s (`getSofZmanKidushLevanaBetweenMoldos`), KosherJava 2.5.0 354 h 22 min 1 s 666 ms, une
/// milliseconde de moins ; c'est Android qui fait foi. Le juge : `Tests/Vecteurs/levana.json`.
///
/// Les instants sont des millisecondes Unix, les jours des `JourCivil`, et le fuseau est toujours passé.
public enum Levana {

    /// Un mois lunaire moyen : 29 j 12 h 793 halakim, à la milliseconde (`MOIS` de Levana.kt).
    static let moisLunaire: Int64 = 2_551_443_333

    /// La mi-mois de KosherJava (`getSofZmanKidushLevanaBetweenMoldos`) : 354 h 22 min 1 s 666 ms après le molad.
    static let miMois: Int64 = 1_275_721_666

    /// Les usages : début (jours depuis le molad), fin (quinze jours, mi-mois, ou d'après la date). La clé est
    /// celle des préférences (`levana_usage`), le libellé le nom de sa chaîne.
    public enum Usage: String, CaseIterable, Sendable {
        case troisMiMois = "trois_mi_mois"
        case septMiMois = "sept_mi_mois"
        case septQuinze = "sept_quinze"
        /// Le Yalkut Yosef (audit du 16/11) : selon la date du mois, et non d'heure à heure : jamais la nuit du
        /// 16, même avant quinze jours révolus, et encore la fin de la nuit du 15, jusqu'au lever du soleil.
        case septNuitQuinze = "sept_nuit_quinze"

        public var cle: String { rawValue }

        /// `R.string.levana_usage_…`.
        public var libelle: String { "levana_usage_" + rawValue }

        public var troisJours: Bool { self == .troisMiMois }

        public var quinzeJours: Bool { self == .septQuinze }

        public var nuitDuQuinze: Bool { self == .septNuitQuinze }

        /// L'usage par défaut d'un noussa'h : Edot haMizra'h le Yalkut Yosef (d'après la date, audit du 16/11),
        /// Sefard l'Ari, Ashkenaz la Michna Beroura et le Rema.
        public static func duNusah(_ nusah: Nusah) -> Usage {
            switch nusah {
            case .edot: .septNuitQuinze
            case .sefard: .septMiMois
            case .ashkenaz: .troisMiMois
            }
        }
    }

    /// Les heures qui bornent les nuits d'un lieu (audit du 16/11) : la sortie des étoiles (soir) et le lever du
    /// soleil (matin) ; sans lieu, 20 h et 6 h, de simples repères. Instants en millisecondes Unix.
    public struct Horaires {
        public let fuseau: Fuseau
        private let tset: (JourCivil) -> Int64?
        private let netz: (JourCivil) -> Int64?

        public init(fuseau: Fuseau, tset: @escaping (JourCivil) -> Int64? = { _ in nil },
                    netz: @escaping (JourCivil) -> Int64? = { _ in nil }) {
            self.fuseau = fuseau
            self.tset = tset
            self.netz = netz
        }

        public func soir(_ d: JourCivil) -> Int64 { tset(d) ?? fuseau.millis(DateHeure(d, heure: 20)) }

        public func matin(_ d: JourCivil) -> Int64 { netz(d) ?? fuseau.millis(DateHeure(d, heure: 6)) }

        /// Les horaires d'un lieu (Zmanim, profil commun) ; sans lieu, les repères de 20 h et 6 h.
        public static func du(_ lieu: Zmanim.Lieu?, fuseau: Fuseau) -> Horaires {
            guard let lieu else { return Horaires(fuseau: fuseau) }
            func instant(_ cle: String) -> (JourCivil) -> Int64? {
                { d in
                    Zmanim.jour(lieu: lieu, date: d).first { $0.cle == cle }?.instant
                        .map { Int64(($0.timeIntervalSince1970 * 1000).rounded(.down)) }
                }
            }
            return Horaires(fuseau: fuseau, tset: instant("tset"), netz: instant("netz"))
        }
    }

    /// Pourquoi pas ce soir : la nuit est Chabbat ou Yom tov (Michna Beroura 426:12 ; Kitsour Yalkut Yosef
    /// 426:33). Le nom est celui de l'énumération d'Android.
    public enum Chome: String, Sendable {
        case chabbat = "CHABBAT"
        case yomTov = "YOM_TOV"
    }

    /// Le nom est celui de l'énumération d'Android.
    public enum Restriction: String, Sendable {
        case kippour = "KIPPOUR"
        case tishaBeav = "TISHA_BEAV"
    }

    public struct Fenetre: Sendable, Hashable {
        public let molad: Int64
        public let debut: Int64
        public let fin: Int64
        public let restriction: Restriction?
        /// Le dernier soir : le jour de la fin si la nuit (tsét du lieu, sinon 20 h) y commence avant elle, sinon
        /// la veille (audit du 16/11 : « fin − 12 h » désignait l'été un soir déjà fermé ; O.H. 426:3).
        public let dernier: JourCivil

        public init(molad: Int64, debut: Int64, fin: Int64, restriction: Restriction? = nil, dernier: JourCivil) {
            self.molad = molad
            self.debut = debut
            self.fin = fin
            self.restriction = restriction
            self.dernier = dernier
        }

        public var prochainMolad: Int64 { molad + Levana.moisLunaire }

        /// Le premier soir : le jour du début, vu du fuseau.
        public func premierSoir(_ fuseau: Fuseau) -> JourCivil {
            fuseau.jour(millis: debut)
        }

        /// Le dernier soir (`dernier`), quel que soit le fuseau.
        public func dernierSoir(_ fuseau: Fuseau) -> JourCivil { dernier }
    }

    public enum Etat: Sendable, Hashable {
        case dans(jours: Int)
        case ceSoir
        case dernierSoir
        /// Un soir de la fenêtre qui est Chabbat ou Yom tov, sans être le dernier (audit du 16/11).
        case pasCeSoir(Chome)
    }

    /// La lune : la part éclairée du disque (0 à 1), si elle croît.
    public struct Lune: Sendable, Hashable {
        public let eclairage: Double
        public let croissante: Bool

        public init(eclairage: Double, croissante: Bool) {
            self.eclairage = eclairage
            self.croissante = croissante
        }
    }

    /// La lune à un instant : Meeus, Astronomical Algorithms, ch. 48 (angle de phase approché) ; à un ou deux
    /// pour cent près, assez pour un dessin. Même formule que phaseLune() du web ; les termes sont sommés dans
    /// l'ordre de Kotlin.
    public static func phase(_ t: Int64) -> Lune {
        let jj: Double = Double(t) / 86_400_000.0 + 2_440_587.5
        let siecles: Double = (jj - 2_451_545) / 36_525
        let r: Double = Double.pi / 180
        let d: Double = 297.8501921 + 445_267.1114034 * siecles
        let m: Double = 357.5291092 + 35_999.0502909 * siecles
        let mp: Double = 134.9633964 + 477_198.8675055 * siecles
        let t1: Double = 6.289 * sin(mp * r)
        let t2: Double = 2.1 * sin(m * r)
        let t3: Double = 1.274 * sin((2 * d - mp) * r)
        let t4: Double = 0.658 * sin(2 * d * r)
        let t5: Double = 0.214 * sin(2 * mp * r)
        let t6: Double = 0.11 * sin(d * r)
        let i: Double = 180 - d - t1 + t2 - t3 - t4 - t5 - t6
        let eclairage: Double = (1 + cos(i * r)) / 2
        let elongation: Double = (d.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return Lune(eclairage: eclairage, croissante: elongation < 180)
    }

    /// La fenêtre qui concerne le soir de `date` : celle du mois, ou celle du mois suivant si elle est passée.
    /// `horaires` : les nuits du lieu ; par défaut 20 h et 6 h.
    public static func fenetre(_ date: JourCivil, fuseau: Fuseau, usage: Usage = .septMiMois,
                               horaires: Horaires? = nil) -> Fenetre {
        let h = horaires ?? Horaires(fuseau: fuseau)
        return verrou.withLock { _ in fenetreSousVerrou(date, usage, h) }
    }

    /// La nuit qui suit le jour civil `date` est-elle Chabbat ou Yom tov (le second jour seulement en diaspora) ?
    /// Lekhat'hila, on ne bénit pas la lune ces soirs-là, sauf si le délai va passer (audit du 16/11).
    public static func nuitChomee(_ date: JourCivil, enIsrael: Bool) -> Chome? {
        if date.jourDeSemaine == 6 { return .chabbat }
        let yomTov = verrou.withLock { _ in calendrier(date.plus(jours: 1), enIsrael: enIsrael).isYomTovAssurBemelacha() }
        return yomTov ? .yomTov : nil
    }

    /// Le premier soir où l'on peut bénir lekhat'hila : ni Chabbat ni Yom tov, sinon le dernier soir.
    public static func premierPossible(_ f: Fenetre, fuseau: Fuseau, enIsrael: Bool) -> JourCivil {
        var d = f.premierSoir(fuseau)
        while d < f.dernier && nuitChomee(d, enIsrael: enIsrael) != nil { d = d.plus(jours: 1) }
        return d
    }

    /// Le soir de `date` sort-il d'un jeûne autre que Kippour ? Selon les A'haronim, on bénit alors après avoir
    /// goûté quelque chose ; selon le Rema, on attend un autre soir (audit du 16/11 : Rema 426:2, MB 426:11).
    public static func sortieDeJeune(_ date: JourCivil, enIsrael: Bool) -> Bool {
        verrou.withLock { _ in
            let c = calendrier(date, enIsrael: enIsrael)
            return c.isTaanis() && c.getYomTovIndex() != JewishCalendar.YOM_KIPPUR
        }
    }

    /// Le motsaé Chabbat conseillé de la fenêtre, à partir de `date` : sa nuit avant le 10, et pas Yom Tov.
    /// Seul le premier samedi qui convient compte : s'il précède `date`, il n'y en a plus.
    public static func motsaeChabbat(_ f: Fenetre, _ date: JourCivil, fuseau: Fuseau) -> JourCivil? {
        let premier = f.premierSoir(fuseau)
        return verrou.withLock { _ in motsaeSousVerrou(premier, f.dernier, date) }
    }

    /// `enIsrael` : pour le Yom tov de la nuit (le second jour seulement en diaspora).
    public static func etat(_ f: Fenetre, _ date: JourCivil, fuseau: Fuseau, enIsrael: Bool = true) -> Etat {
        let premier = f.premierSoir(fuseau)
        if date < premier { return .dans(jours: premier.jourJulien - date.jourJulien) }
        if date == f.dernier { return .dernierSoir }
        if let chome = nuitChomee(date, enIsrael: enIsrael) { return .pasCeSoir(chome) }
        return .ceSoir
    }

    /// La place d'un instant dans le mois lunaire, de 0 (molad) à 1 (molad suivant).
    public static func part(_ f: Fenetre, _ t: Int64) -> Float {
        let x: Double = Double(t - f.molad) / Double(moisLunaire)
        return Float(min(max(x, 0), 1))
    }

    /// Le soir de `date` (20 h) : le point posé sur la jauge, l'heure de la lune dessinée, la sortie supposée
    /// d'un jeûne.
    public static func soir(_ date: JourCivil, fuseau: Fuseau) -> Int64 {
        fuseau.millis(DateHeure(date, heure: 20))
    }

    // MARK: KosherSwift

    /// KosherSwift n'est pas `Sendable` : ses objets ne sortent pas de ce fichier, ses calculs passent ici.
    private static let verrou = Mutex(())

    private static func fenetreSousVerrou(_ date: JourCivil, _ usage: Usage, _ h: Horaires) -> Fenetre {
        let ici = du(date, usage, h)
        if date <= ici.dernier { return ici }
        let jour = calendrier(date).getJewishDayOfMonth()
        return du(date.plus(jours: 31 - jour + 2), usage, h)
    }

    /// La fenêtre du mois hébreu de `date` (`du` de Levana.kt).
    private static func du(_ date: JourCivil, _ usage: Usage, _ h: Horaires) -> Fenetre {
        let fuseau = h.fuseau
        let c = calendrier(date)
        let molad = millis(c.getMoladAsDate())
        var debut = millis(usage.troisJours ? c.getTchilasZmanKidushLevana3Days() : c.getTchilasZmanKidushLevana7Days())
        let fin: Int64
        if usage.nuitDuQuinze {
            // Le Yalkut Yosef : jusqu'au lever du soleil qui clôt la nuit du 15 (audit du 16/11, YY 426:28).
            fin = h.matin(date.plus(jours: 15 - c.getJewishDayOfMonth()))
        } else if usage.quinzeJours {
            fin = millis(c.getSofZmanKidushLevana15Days())
        } else {
            fin = molad + miMois
        }
        var restriction: Restriction?
        // Tichri et Av : pas avant la sortie de Kippour, de Tich'a beAv (le jeûne, même repoussé au 10), à la
        // sortie des étoiles du lieu (audit du 16/11 : non plus à 20 h, avant la fin du jeûne l'été).
        let moisDuDebut = moisHebreu(calendrier(fuseau.jour(millis: debut)))
        let tichri = moisDuDebut == CalendrierJuif.Mois.tichri
        if tichri || moisDuDebut == CalendrierJuif.Mois.av {
            let cible = tichri ? JewishCalendar.YOM_KIPPUR : JewishCalendar.TISHA_BEAV
            let base = fuseau.jour(millis: molad)
            for k in -9...12 {
                let j = base.plus(jours: k)
                if calendrier(j).getYomTovIndex() == cible {
                    let sortie = h.soir(j)
                    if sortie > debut {
                        debut = sortie
                        restriction = tichri ? Restriction.kippour : Restriction.tishaBeav
                    }
                    break
                }
            }
        }
        let jourFin = fuseau.jour(millis: fin)
        let dernier = h.soir(jourFin) < fin ? jourFin : jourFin.plus(jours: -1)
        return Fenetre(molad: molad, debut: debut, fin: fin, restriction: restriction, dernier: dernier)
    }

    private static func motsaeSousVerrou(_ premier: JourCivil, _ dernier: JourCivil, _ date: JourCivil) -> JourCivil? {
        var d = premier
        while d <= dernier {
            if d.jourDeSemaine == 7 {
                let nuit = calendrier(d.plus(jours: 1))
                if nuit.getJewishDayOfMonth() <= 10 && !nuit.isYomTovAssurBemelacha() {
                    return d < date ? nil : d
                }
            }
            d = d.plus(jours: 1)
        }
        return nil
    }

    /// `JewishCalendar(date)` de KosherJava : le jour civil à midi UTC, lu en UTC, hors d'Israël et sans
    /// les fêtes modernes (comme CalendrierJuif et Holidays).
    private static func calendrier(_ date: JourCivil, enIsrael: Bool = false) -> JewishCalendar {
        let utc = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let midi = Date(timeIntervalSince1970: Double(date.jourJulien - 2_440_588) * 86_400 + 43_200)
        return JewishCalendar(workingDate: midi, timezone: utc, inIsrael: enIsrael, useModernHolidays: false)
    }

    /// Le mois hébreu numéroté comme KosherJava (`CalendrierJuif.Mois`).
    private static func moisHebreu(_ c: JewishCalendar) -> Int {
        CalendrierJuif.moisKosherJava(c.getJewishMonth(), embolismique: c.isJewishLeapYear())
    }

    /// Un instant de KosherSwift en millisecondes Unix, tronqué comme KosherJava le tronque. Un 'helek vaut
    /// 10/3 s : le molad tombe sur un tiers de milliseconde, dont KosherJava ne garde que la milliseconde
    /// entière (`(int) (1000 * …)`) et KosherSwift les tiers. L'instant est donc lu en tiers de
    /// milliseconde, ce qui absorbe l'arrondi du `Double` de `Date` (bien moins d'un tiers), puis tronqué.
    private static func millis(_ date: Date) -> Int64 {
        let tiers = Kotlin.versLong((date.timeIntervalSince1970 * 3_000).rounded())
        let (quotient, reste) = tiers.quotientAndRemainder(dividingBy: 3)
        return reste < 0 ? quotient - 1 : quotient
    }
}
