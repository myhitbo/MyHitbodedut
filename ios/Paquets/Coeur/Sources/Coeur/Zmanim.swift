import Foundation
import KosherSwift
import Synchronization

/// Les zmanim du jour, hors ligne, par KosherSwift 1.10.11 (`ComplexZmanimCalendar`) :
/// la transposition de `Zmanim.kt`, méthode pour méthode (PORTAGE.md § 5.1).
///
/// Le profil est fixe et chaque ligne nomme sa méthode : aucune appellation de communauté
/// ne choisit à la place de l'utilisateur (ZMANIM.md). Le juge est le même fichier que pour
/// Android et le site : `web/test/vecteurs_kosherjava.json`, à une seconde près.
///
/// Les objets de KosherSwift ne sortent jamais d'une fonction : seules des valeurs `Sendable`
/// en sortent. Leur calcul est sérialisé, parce que `NOAACalculator` écrit dans une variable
/// statique à chaque construction.
public enum Zmanim {

    public static let moteur = "KosherSwift 1.10.11, NOAACalculator"

    public struct Lieu: Sendable, Hashable, Codable {
        public var nom: String
        public var latitude: Double
        public var longitude: Double
        /// En mètres. Le profil calcule au niveau de la mer : elle n'entre dans aucun zman.
        public var altitude: Double
        /// Fuseau IANA, « Asia/Jerusalem ».
        public var fuseau: String

        public init(nom: String, latitude: Double, longitude: Double, altitude: Double = 0, fuseau: String) {
            self.nom = nom
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            self.fuseau = fuseau
        }
    }

    public enum Statut: String, Sendable {
        case ok
        /// L'événement n'a pas lieu ce jour-là (soleil de minuit, nuit polaire) : ce n'est pas une erreur.
        case absent
        /// Le calcul a échoué (fuseau inconnu) : une erreur technique, distincte d'un événement absent.
        case erreur
    }

    /// Une méthode : sa clé (libellé « zman_methode_<clé> ») et ses paramètres.
    public struct Methode: Sendable, Hashable {
        public let cle: String
        public let parametres: String

        public init(_ cle: String, _ parametres: String) {
            self.cle = cle
            self.parametres = parametres
        }
    }

    public struct Zman: Sendable, Equatable {
        public let cle: String
        public let methode: Methode
        public let statut: Statut
        /// L'instant ; sa date locale peut être le lendemain (`chatsot_layla`).
        public let instant: Date?
    }

    public struct Entree: Sendable, Equatable {
        public let cle: String
        public let methode: Methode
    }

    /// Le profil, dans l'ordre de la journée, avec la méthode de `ComplexZmanimCalendar` qui calcule chaque zman.
    public static let profil: [Entree] = [
        Entree(cle: "alot", methode: Methode("degres", "16.1")),              // getAlos16Point1Degrees
        Entree(cle: "misheyakir", methode: Methode("degres", "11.5")),        // getMisheyakir11Point5Degrees
        Entree(cle: "netz", methode: Methode("niveau_mer", "")),              // getSeaLevelSunrise
        Entree(cle: "szks_mga", methode: Methode("mga_72", "72")),            // getSofZmanShmaMGA
        Entree(cle: "szks_gra", methode: Methode("gra", "")),                 // getSofZmanShmaGRA
        Entree(cle: "szt_mga", methode: Methode("mga_72", "72")),             // getSofZmanTfilaMGA
        Entree(cle: "szt_gra", methode: Methode("gra", "")),                  // getSofZmanTfilaGRA
        Entree(cle: "chatsot", methode: Methode("meridien", "")),             // getChatzos (= getSunTransit)
        Entree(cle: "minha_gedola", methode: Methode("gra", "")),             // getMinchaGedola
        Entree(cle: "minha_ketana", methode: Methode("gra", "")),             // getMinchaKetana
        Entree(cle: "plag", methode: Methode("gra", "")),                     // getPlagHamincha
        Entree(cle: "chkia", methode: Methode("niveau_mer", "")),             // getSeaLevelSunset
        Entree(cle: "tset", methode: Methode("degres", "8.5")),               // getTzaisGeonim8Point5Degrees
        Entree(cle: "tset_rt", methode: Methode("minutes", "72")),            // getTzais72
        Entree(cle: "chatsot_layla", methode: Methode("milieu_chatsot", "")), // getSolarMidnight
    ]

    /// Le profil des Edot (audit du 16/11) : les zmanim du Yalkut Yosef à la place de ceux de `profil` ; les autres
    /// lignes restent communes. L'heure zmanit est celle du Gra (du lever au coucher au niveau de la mer) :
    /// aube à 72 min zmaniyot avant le lever (Kitsour YY 89:12), michéyakir 6 min zmaniyot après, Maguen Avraham
    /// sur 72 min zmaniyot (58:3), tsét à 13,5 min zmaniyot (233:5), plag 1¼ heure zmanit avant ce tsét (263:45),
    /// Rabbénou Tam à 72 min zmaniyot (293:3, 7).
    public static let profilEdot: [String: Methode] = [
        "alot": Methode("zmaniyot_avant_netz", "72"),       // getAlos72Zmanis
        "misheyakir": Methode("zmaniyot_avant_netz", "66"), // lever − 1,1 heure zmanit
        "szks_mga": Methode("mga_72_zmaniyot", "72"),       // getSofZmanShmaMGA72MinutesZmanis
        "szt_mga": Methode("mga_72_zmaniyot", "72"),        // getSofZmanTfilaMGA72MinutesZmanis
        "plag": Methode("plag_yalkut_yosef", ""),           // coucher − 1,025 heure zmanit
        "tset": Methode("zmaniyot_apres_chkia", "13.5"),    // coucher + 0,225 heure zmanit
        "tset_rt": Methode("zmaniyot_apres_chkia", "72"),   // getTzais72Zmanis
    ]

    /// Le profil d'un noussa'h : `profil`, où les Edot prennent les lignes de `profilEdot` ; nil, le profil commun
    /// (Sfard, Ashkenaz, et tout appel sans noussa'h).
    public static func profil(nusah: Nusah?) -> [Entree] {
        guard nusah == .edot else { return profil }
        return profil.map { e in Entree(cle: e.cle, methode: profilEdot[e.cle] ?? e.methode) }
    }

    /// L'allumage : coucher au niveau de la mer moins `minutes` (getCandleLighting).
    public static func methodeAllumage(minutes: Int) -> Methode { Methode("avant_chkia", String(minutes)) }

    /// Les minutes d'allumage proposées dans les réglages ; 18 par défaut.
    public static let allumages = [18, 20, 22, 30, 40]
    public static let allumageDefaut = 18

    /// Les quinze zmanim du profil de `nusah` pour `date` au `lieu` (nil : le profil commun).
    public static func jour(lieu: Lieu, date: JourCivil, nusah: Nusah? = nil) -> [Zman] {
        let lignes = profil(nusah: nusah)
        let edot = nusah == .edot
        return verrou.withLock { _ in
            guard let c = calendrier(lieu, date) else {
                return lignes.map { Zman(cle: $0.cle, methode: $0.methode, statut: .erreur, instant: nil) }
            }
            // getSolarMidnight prend le milieu entre 'hatsot d'aujourd'hui et de demain ; si l'un
            // manque, l'événement est absent, comme dans Zmanim.kt.
            let nuitCalculable = c.getChatzos() != nil && calendrier(lieu, date.plus(jours: 1))?.getChatzos() != nil
            return lignes.map { entree in
                let instant: Date?
                if entree.cle == "chatsot_layla" && !nuitCalculable {
                    instant = nil
                } else if edot && profilEdot[entree.cle] != nil {
                    instant = valeurEdot(c, entree.cle)
                } else {
                    instant = valeur(c, entree.cle)
                }
                return Zman(cle: entree.cle, methode: entree.methode,
                            statut: instant == nil ? .absent : .ok, instant: instant)
            }
        }
    }

    /// Les heures du 'hamets la veille de Pessa'h (audit du 16/11) : fin de la consommation (fin de la 4e heure)
    /// et fin du bi'our (fin de la 5e heure), selon le Maguen Avraham puis selon le Gra. Edot : heures zmaniyot
    /// de l'aube à tsét, à 72 min zmaniyot (Kitsour Yalkut Yosef 443:1) ; les autres : la journée de 72 min fixes.
    public static func hamets(lieu: Lieu, date: JourCivil, nusah: Nusah? = nil) -> [Zman] {
        let edot = nusah == .edot
        let mga = edot ? Methode("mga_72_zmaniyot", "72") : Methode("mga_72", "72")
        let gra = Methode("gra", "")
        let cles: [(String, Methode, Int)] = [("hamets_achila", mga, 4), ("hamets_achila", gra, 4),
                                              ("hamets_biour", mga, 5), ("hamets_biour", gra, 5)]
        return verrou.withLock { _ in
            guard let c = calendrier(lieu, date) else {
                return cles.map { Zman(cle: $0.0, methode: $0.1, statut: .erreur, instant: nil) }
            }
            func heures(_ debut: Date?, _ heure: Int64, _ n: Int) -> Date? {
                guard let debut, heure != Int64.min else { return nil }
                return Date(timeIntervalSince1970: debut.timeIntervalSince1970 + Double(Int64(n) * heure) / 1000)
            }
            return cles.map { (cle, methode, n) in
                let instant: Date?
                if methode == gra {
                    instant = heures(c.getSeaLevelSunrise(), c.getShaahZmanisGra(), n)
                } else if edot {
                    instant = heures(c.getAlos72Zmanis(), c.getShaahZmanis72MinutesZmanis(), n)
                } else {
                    instant = heures(c.getAlos72(), c.getShaahZmanisMGA(), n)
                }
                return Zman(cle: cle, methode: methode, statut: instant == nil ? .absent : .ok, instant: instant)
            }
        }
    }

    /// L'allumage des bougies ce jour-là au `lieu`, `minutes` avant la chki'a.
    public static func allumage(lieu: Lieu, date: JourCivil, minutes: Int) -> Zman {
        verrou.withLock { _ in
            let methode = methodeAllumage(minutes: minutes)
            guard let c = calendrier(lieu, date) else {
                return Zman(cle: "allumage", methode: methode, statut: .erreur, instant: nil)
            }
            c.candleLightingOffset = minutes
            let instant = c.getCandleLighting()
            return Zman(cle: "allumage", methode: methode, statut: instant == nil ? .absent : .ok, instant: instant)
        }
    }

    // MARK: KosherSwift

    private static let verrou = Mutex(())

    /// Le calendrier de KosherSwift réglé comme celui d'Android : midi local du jour, niveau de la mer,
    /// NOAA, 'hatsot astronomique. `nil` si le fuseau est inconnu. Pour les tests et ce fichier seulement.
    static func calendrier(_ lieu: Lieu, _ date: JourCivil) -> ComplexZmanimCalendar? {
        guard let fuseau = TimeZone(identifier: lieu.fuseau), let midi = midiLocal(date, fuseau) else { return nil }
        let geo = GeoLocation(locationName: lieu.nom, latitude: lieu.latitude, longitude: lieu.longitude,
                              elevation: lieu.altitude, timeZone: fuseau)
        let c = ComplexZmanimCalendar(location: geo)
        c.workingDate = midi
        // Explicite, même si c'est le défaut : le profil calcule au niveau de la mer.
        c.useElevation = false
        // 'Hatsot = passage au méridien, comme getChatzos de KosherJava 2.5.0.
        c.useAstronomicalChatzos = true
        // L'algorithme de la NOAA, écrit plutôt que laissé au défaut : comparé à ses formules par les tests.
        c.astronomicalCalculator = NOAACalculator(geoLocation: geo)
        return c
    }

    static func midiLocal(_ date: JourCivil, _ fuseau: TimeZone) -> Date? {
        var gregorien = Calendar(identifier: .gregorian)
        gregorien.timeZone = fuseau
        return gregorien.date(from: DateComponents(year: date.annee, month: date.mois, day: date.jour, hour: 12))
    }

    /// Les lignes de `profilEdot`, en heures zmaniyot du Gra (lever et coucher au niveau de la mer).
    private static func valeurEdot(_ c: ComplexZmanimCalendar, _ cle: String) -> Date? {
        let heure = c.getShaahZmanisGra()
        func decale(_ d: Date?, _ heures: Double) -> Date? {
            guard let d, heure != Int64.min else { return nil }
            // Math.round de Java : au plus proche, la moitié vers le haut.
            let ms = (heures * Double(heure) + 0.5).rounded(.down)
            return Date(timeIntervalSince1970: d.timeIntervalSince1970 + ms / 1000)
        }
        switch cle {
        case "alot": return c.getAlos72Zmanis()
        case "misheyakir": return decale(c.getSeaLevelSunrise(), -1.1)
        case "szks_mga": return c.getSofZmanShmaMGA72MinutesZmanis()
        case "szt_mga": return c.getSofZmanTfilaMGA72MinutesZmanis()
        case "plag": return decale(c.getSeaLevelSunset(), -1.025)
        case "tset": return decale(c.getSeaLevelSunset(), 0.225)
        case "tset_rt": return c.getTzais72Zmanis()
        default: return nil
        }
    }

    private static func valeur(_ c: ComplexZmanimCalendar, _ cle: String) -> Date? {
        switch cle {
        case "alot": c.getAlos16Point1Degrees()
        case "misheyakir": c.getMisheyakir11Point5Degrees()
        case "netz": c.getSeaLevelSunrise()
        case "szks_mga": c.getSofZmanShmaMGA()
        case "szks_gra": c.getSofZmanShmaGRA()
        case "szt_mga": c.getSofZmanTfilaMGA()
        case "szt_gra": c.getSofZmanTfilaGRA()
        case "chatsot": c.getChatzos()
        case "minha_gedola": c.getMinchaGedola()
        case "minha_ketana": c.getMinchaKetana()
        case "plag": c.getPlagHamincha()
        case "chkia": c.getSeaLevelSunset()
        case "tset": c.getTzaisGeonim8Point5Degrees()
        case "tset_rt": c.getTzais72()
        case "chatsot_layla": c.getSolarMidnight()
        default: nil
        }
    }
}
