import Foundation

/// Ce qui lit une adresse : le réseau de l'app, ou un faux dans les tests. Rend (code HTTP, corps) ;
/// lève si la connexion n'aboutit pas. Coeur n'ouvre aucune connexion : l'app en fournit une, HTTPS
/// seulement et sans redirection, avec l'écran du vol (ROADMAP, tâche 26).
public typealias LecteurAdresse = @Sendable (String) throws -> (code: Int, corps: String)

/// `URLEncoder.encode(v, "UTF-8")` de Java : lettres et chiffres ASCII, « . - * _ » tels quels, l'espace
/// en « + », tout autre octet UTF-8 en %XX majuscules.
enum CodageURL {
    private static let hexadecimal = Array("0123456789ABCDEF")

    static func formulaire(_ texte: String) -> String {
        var sortie = ""
        for octet in texte.utf8 {
            switch octet {
            case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "."), UInt8(ascii: "-"), UInt8(ascii: "*"), UInt8(ascii: "_"):
                sortie.append(Character(Unicode.Scalar(octet)))
            case UInt8(ascii: " "):
                sortie.append("+")
            default:
                sortie.append("%")
                sortie.append(hexadecimal[Int(octet >> 4)])
                sortie.append(hexadecimal[Int(octet & 15)])
            }
        }
        return sortie
    }
}

/// `Instant.parse` d'un instant ISO-8601 en UTC (« 2026-11-10T18:30:00Z », fraction de seconde permise),
/// en millisecondes Unix ; nil s'il ne se lit pas.
enum InstantISO {
    private static let forme = ExpressionReguliere("([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\\.([0-9]{1,9}))?)?Z")

    static func lire(_ texte: String) -> Int64? {
        guard let m = forme.entiere(texte), let jour = JourCivil(iso: "\(m.groupes[1])-\(m.groupes[2])-\(m.groupes[3])"),
              let h = Int(m.groupes[4]), let mi = Int(m.groupes[5]), h < 24, mi < 60 else { return nil }
        let s = Int(m.groupes[6]) ?? 0
        let fraction = m.groupes[7]
        let millis = fraction.isEmpty ? 0 : Int((fraction + "00").prefix(3)) ?? 0
        guard s < 60 else { return nil }
        return Int64(jour.jourJulien - 2_440_588) * 86_400_000 + Int64(h * 3_600_000 + mi * 60_000 + s * 1000 + millis)
    }
}

/// Le suivi d'un vol en direct (SuiviVol.kt, 28/10), option désactivée par défaut et propre à l'édition
/// complète : la position réelle de l'avion, demandée à OpenSky Network, sans compte ni clé. Le téléphone
/// demande les avions d'un carré autour de la position estimée et y cherche l'indicatif lui-même ; avec un
/// relais (tools/relais_vol), c'est lui qu'on interroge. La position reçue devient un relevé de la route.
public enum SuiviVol {

    public enum Resultat: Sendable, Equatable {
        case trouve(Vol.Point, altitudeMetres: Double?)
        /// L'avion n'est pas vu autour de la position estimée (hors couverture, indicatif inexact).
        case introuvable
        /// Un code de `Raison`, traduit à l'affichage : jamais du texte montré tel quel.
        case erreur(String)
    }

    /// Les raisons d'une erreur, partagées avec RouteVol : des codes, traduits par l'écran.
    public enum Raison {
        public static let horsLigne = "hors_ligne"
        public static let quota = "quota"
        public static let illisible = "illisible"
        public static let positionInvalide = "position_invalide"
        public static let relaisAbsent = "relais_absent"
        /// Le relais a répondu une erreur qu'on ne sait pas nommer.
        public static let service = "service"
        private static let serveurPrefixe = "serveur_"

        public static func serveur(_ code: Int) -> String { code == 429 ? quota : "\(serveurPrefixe)\(code)" }

        /// Le code HTTP d'une raison `serveur`, sinon nil.
        public static func codeServeur(_ raison: String) -> Int? {
            raison.commenceParUnites(serveurPrefixe) ? Int(raison.sansPremieresUnites(serveurPrefixe.utf16.count)) : nil
        }

        private static let opensky = ExpressionReguliere("opensky ([0-9]+)")

        /// Le message du relais : « opensky 429 », « opensky injoignable »…
        public static func duRelais(_ message: String) -> String {
            guard let m = opensky.entiere(message.rogne), let code = Int(m.groupes[1]) else { return service }
            return serveur(code)
        }
    }

    /// D'où vient la position : un relais, un autre service plus tard, un faux dans les tests.
    public protocol FournisseurPosition: Sendable {
        func position(_ indicatif: String, _ estime: Vol.Point) -> Resultat
    }

    /// Une position plus vieille ne recale plus la route : l'avion a fait 150 km depuis.
    public static let fraicheurMax: Int64 = 10 * 60_000

    private static let indicatif = ExpressionReguliere("[A-Z]{3}[0-9]{1,4}[A-Z]{0,2}")
    private static let parties = ExpressionReguliere("([A-Z]{3})0*([0-9]+)([A-Z]*)")

    /// « ely 001 » → « ELY001 » ; nil si ce n'est pas un indicatif OACI plausible.
    public static func normaliser(_ texte: String) -> String? {
        let t = texte.uppercased().replacingOccurrences(of: " ", with: "")
        return indicatif.couvre(t) ? t : nil
    }

    /// ELY001 et ELY1 sont le même vol : même préfixe, même numéro, mêmes lettres finales.
    public static func memeIndicatif(_ a: String, _ b: String) -> Bool {
        guard let pa = parties.entiere(a.uppercased().rogne) else { return false }
        guard let pb = parties.entiere(b.uppercased().rogne) else { return false }
        return Array(pa.groupes.dropFirst()) == Array(pb.groupes.dropFirst())
    }

    /// Ce que vaut une position lue : hors du globe, trop vieille, ou un relevé.
    private static func position(instant: Int64, latitude: Double, longitude: Double, altitude: Double?, maintenant: Int64) -> Resultat {
        if !(-90...90).contains(latitude) || !(-180...180).contains(longitude) { return .erreur(Raison.positionInvalide) }
        if maintenant - instant > fraicheurMax { return .introuvable }
        return .trouve(Vol.Point(instant: instant, latitude: latitude, longitude: longitude), altitudeMetres: altitude)
    }

    /// `getDouble` : un nombre, ou une chaîne qui se lit comme un nombre ; nil sinon.
    private static func nombre(_ o: ObjetJSON, _ cle: String) -> Double? {
        guard let v = o[cle], v != .nul, let d = v.commeDouble else { return nil }
        return d
    }

    /// La réponse du relais : { trouve, latitude, longitude, altitude_geo, altitude_baro, instant }.
    public static func lire(_ json: String, maintenant: Int64) -> Resultat {
        guard let o = try? ObjetJSON(texte: json) else { return .erreur(Raison.illisible) }
        if o.a("erreur") { return .erreur(Raison.duRelais(o.texte("erreur"))) }
        if !o.booleen("trouve") { return .introuvable }
        guard let instant = InstantISO.lire(o.texte("instant")), let lat = nombre(o, "latitude"), let lon = nombre(o, "longitude") else {
            return .erreur(Raison.illisible)
        }
        let altitude = ["altitude_geo", "altitude_baro"].lazy.map { o.double($0) }.first { !$0.isNaN }
        return position(instant: instant, latitude: lat, longitude: lon, altitude: altitude, maintenant: maintenant)
    }

    /// L'adresse demandée au relais : seulement l'indicatif et la position estimée, arrondie au dixième de degré.
    public static func adresse(_ relais: String, _ indicatif: String, _ estime: Vol.Point) -> String {
        var base = Array(relais.utf16)
        while base.last == 0x2F { base.removeLast() }
        return "\(Unites.texte(base))/position?indicatif=\(CodageURL.formulaire(indicatif))"
            + "&lat=\(Java.format(estime.latitude, decimales: 1))&lon=\(Java.format(estime.longitude, decimales: 1))"
    }

    public static let etats = "https://opensky-network.org/api/states/all"
    public static let demiCote = 5.0

    /// Les carrés à demander [lamin, lomin, lamax, lomax] : un seul, ou deux de part et d'autre du méridien de 180°.
    public static func carres(_ lat: Double, _ lon: Double, _ d: Double = demiCote) -> [[Double]] {
        let lamin = max(-90, lat - d), lamax = min(90, lat + d)
        let lomin = lon - d, lomax = lon + d
        if lomin < -180 { return [[lamin, lomin + 360, lamax, 180], [lamin, -180, lamax, lomax]] }
        if lomax > 180 { return [[lamin, lomin, lamax, 180], [lamin, -180, lamax, lomax - 360]] }
        return [[lamin, lomin, lamax, lomax]]
    }

    public static func adresseEtats(_ c: [Double]) -> String {
        func f(_ v: Double) -> String { Java.format(v, decimales: 1) }
        return "\(etats)?lamin=\(f(c[0]))&lomin=\(f(c[1]))&lamax=\(f(c[2]))&lomax=\(f(c[3]))"
    }

    /// La réponse d'OpenSky (/states/all) : l'avion en vol dont l'indicatif correspond. [icao24, callsign,
    /// pays, time_position, last_contact, longitude, latitude, baro_altitude, on_ground, …, geo_altitude (13)].
    public static func lireEtats(_ json: String, _ indicatif: String, maintenant: Int64) -> Resultat {
        guard let o = try? ObjetJSON(texte: json) else { return .erreur(Raison.illisible) }
        for case .tableau(let e) in o.tableau("states") ?? [] {
            if e.estNul(1) || e.estNul(3) || e.estNul(5) || e.estNul(6) || e.booleen(8) { continue }
            if !memeIndicatif(e.texte(1), indicatif) { continue }
            guard let t = e[3].commeLong, let lat = e[6].commeDouble, let lon = e[5].commeDouble else { return .erreur(Raison.illisible) }
            let geo = e.estNul(13) ? nil : e[13].commeDouble
            let baro = e.estNul(7) ? nil : e[7].commeDouble
            return position(instant: t * 1000, latitude: lat, longitude: lon, altitude: geo ?? baro, maintenant: maintenant)
        }
        return .introuvable
    }

    /// OpenSky, accès anonyme et gratuit : rien que la zone part, l'indicatif est cherché ici.
    public struct OpenSkyAnonyme: FournisseurPosition {
        let lecteur: LecteurAdresse
        let horloge: @Sendable () -> Int64

        public init(lecteur: @escaping LecteurAdresse, horloge: @escaping @Sendable () -> Int64) {
            self.lecteur = lecteur
            self.horloge = horloge
        }

        public func position(_ indicatif: String, _ estime: Vol.Point) -> Resultat {
            var r = Resultat.introuvable
            for carre in carres(estime.latitude, estime.longitude) {
                guard let reponse = try? lecteur(adresseEtats(carre)) else { return .erreur(Raison.horsLigne) }
                if !(200...299).contains(reponse.code) { return .erreur(Raison.serveur(reponse.code)) }
                r = lireEtats(reponse.corps, indicatif, maintenant: horloge())
                if r != .introuvable { break }
            }
            return r
        }
    }

    /// Le relais OpenSky (tools/relais_vol), en HTTPS seulement.
    public struct Relais: FournisseurPosition {
        let relais: String
        let lecteur: LecteurAdresse?
        let horloge: @Sendable () -> Int64

        public init(_ relais: String, lecteur: LecteurAdresse? = nil, horloge: @escaping @Sendable () -> Int64 = { 0 }) {
            self.relais = relais
            self.lecteur = lecteur
            self.horloge = horloge
        }

        public func position(_ indicatif: String, _ estime: Vol.Point) -> Resultat {
            guard relais.hasPrefix("https://") else { return .erreur(Raison.relaisAbsent) }
            guard let lecteur, let reponse = try? lecteur(adresse(relais, indicatif, estime)) else { return .erreur(Raison.horsLigne) }
            if !(200...499).contains(reponse.code) { return .erreur(Raison.serveur(reponse.code)) }
            return lire(reponse.corps, maintenant: horloge())
        }
    }

    /// Le fournisseur de l'édition : le relais s'il est configuré, sinon OpenSky anonyme.
    public static func fournisseur(_ relais: String, lecteur: @escaping LecteurAdresse,
                                   horloge: @escaping @Sendable () -> Int64) -> any FournisseurPosition {
        relais.hasPrefix("https://") ? Relais(relais, lecteur: lecteur, horloge: horloge) : OpenSkyAnonyme(lecteur: lecteur, horloge: horloge)
    }
}

/// La route d'un numéro de vol (RouteVol.kt, 28/10), au toucher de la loupe, services en ligne activés :
/// le numéro part vers api.adsbdb.com, gratuit, sans compte ni clé ; rien d'autre. La réponse donne la
/// compagnie, l'indicatif OACI et les escales connues ; pas les heures, qui restent à saisir.
public enum RouteVol {
    public static let adsbdb = "https://api.adsbdb.com/v0"

    public struct Numero: Sendable, Equatable {
        public let code: String
        public let chiffres: String
        public let suffixe: String

        public init(_ code: String, _ chiffres: String, _ suffixe: String) {
            self.code = code
            self.chiffres = chiffres
            self.suffixe = suffixe
        }
    }

    public enum Resultat: Sendable, Equatable {
        case trouve(indicatif: String?, compagnie: String, escales: [String], de: String, vers: String)
        /// Le vol connu ne part pas de l'aéroport choisi.
        case autreDepart(indicatif: String?, compagnie: String, escales: [String])
        case introuvable
        case invalide
        case erreur(String)
    }

    private static let forme = ExpressionReguliere("([A-Z]{3}|[A-Z][A-Z0-9]|[0-9][A-Z])([0-9]{1,4})([A-Z]?)")
    private static let blancs = ExpressionReguliere("[ \\t\\n\\u000B\\f\\r]+")
    private static let codeIata = ExpressionReguliere("[A-Z0-9]{3}")
    private static let icao = ExpressionReguliere("[A-Z]{3}")

    /// « ly 81 » → LY / 81 ; « ELY081 » → ELY / 81 ; nil sinon.
    public static func normaliser(_ texte: String) -> Numero? {
        guard let m = forme.entiere(blancs.remplace(texte.uppercased(), par: "")) else { return nil }
        var chiffres = Array(m.groupes[2].utf16)
        while chiffres.first == 0x30 { chiffres.removeFirst() }
        return Numero(m.groupes[1], chiffres.isEmpty ? "0" : Unites.texte(chiffres), m.groupes[3])
    }

    /// `response.flightroute` d'adsbdb : le tronçon qui part de `depart` (IATA) s'il est donné, sinon le premier.
    public static func lire(_ json: String, _ depart: String?) -> Resultat {
        guard let o = try? ObjetJSON(texte: json) else { return .erreur(SuiviVol.Raison.illisible) }
        guard let r = o.objet("response")?.objet("flightroute") else { return .introuvable }
        let escales = ["origin", "midpoint", "destination"].compactMap { k -> String? in
            guard let iata = r.objet(k)?.texte("iata_code"), codeIata.couvre(iata) else { return nil }
            return iata
        }
        let indicatif = SuiviVol.normaliser(r.texte("callsign_icao"))
        let compagnie = r.objet("airline")?.texte("name") ?? ""
        let i = depart.map { d in escales.firstIndex(of: d) ?? -1 } ?? 0
        if escales.count < 2 { return .introuvable }
        if i < 0 || i >= escales.count - 1 { return .autreDepart(indicatif: indicatif, compagnie: compagnie, escales: escales) }
        return .trouve(indicatif: indicatif, compagnie: compagnie, escales: escales, de: escales[i], vers: escales[i + 1])
    }

    private struct ErreurHttp: Error { let code: Int }

    /// Le numéro → la route. adsbdb refuse certains numéros IATA courts (« QF9 ») : on reprend alors avec
    /// l'indicatif OACI de chaque compagnie qui porte ce code (adsbdb /airline). Hors du fil de l'interface.
    public static func chercher(_ numero: String, _ depart: String?, lecteur: LecteurAdresse) -> Resultat {
        guard let n = normaliser(numero) else { return .invalide }
        func demande(_ chemin: String) throws -> String? {
            let (code, corps) = try lecteur("\(adsbdb)/\(chemin)")
            if code == 404 || code == 400 { return nil }
            if !(200...299).contains(code) { throw ErreurHttp(code: code) }
            return corps
        }
        do {
            if let corps = try demande("callsign/\(CodageURL.formulaire(n.code + n.chiffres + n.suffixe))") { return lire(corps, depart) }
            if n.code.utf16.count != 2 { return .introuvable }
            guard let reponse = try demande("airline/\(CodageURL.formulaire(n.code))") else { return .introuvable }
            guard let o = try? ObjetJSON(texte: reponse) else { return .erreur(SuiviVol.Raison.illisible) }
            let compagnies = o.tableau("response") ?? []
            for i in compagnies.indices {
                let code = compagnies.objet(i)?.texte("icao") ?? ""
                if !icao.couvre(code) { continue }
                if let corps = try demande("callsign/\(code)\(n.chiffres)\(n.suffixe)") { return lire(corps, depart) }
            }
            return .introuvable
        } catch let e as ErreurHttp {
            return .erreur(SuiviVol.Raison.serveur(e.code))
        } catch {
            return .erreur(SuiviVol.Raison.horsLigne)
        }
    }
}
