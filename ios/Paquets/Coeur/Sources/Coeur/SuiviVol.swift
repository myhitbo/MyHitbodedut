/// Le suivi d'un vol en direct (SuiviVol.kt, 28/10), option désactivée par défaut et propre à l'édition
/// complète : la position réelle de l'avion, demandée à OpenSky Network. Par défaut, l'accès anonyme et
/// gratuit : sans compte ni clé, le téléphone demande les avions d'un carré autour de la position estimée et
/// y cherche l'indicatif lui-même ; l'indicatif ne part pas. Si l'édition est construite avec un relais
/// (tools/relais_vol), c'est lui qu'on interroge : il reçoit l'indicatif et la position estimée.
/// La position reçue devient un relevé de la route (`Vol.Plan.releve`) ; le calcul reste celui de Vol.
///
/// Ici, la lecture des réponses seulement : les adresses à demander, la réponse du relais, celle d'OpenSky.
/// Le réseau (les fournisseurs `OpenSkyAnonyme` et `Relais` de Kotlin) reste à l'app. Les réponses se lisent
/// par `ObjetJSON`, avec les tolérances d'org.json. Les instants sont des millisecondes Unix.
/// Jugé par `Tests/Vecteurs/vol_suite.json` (tools/vecteurs_ios/VecteursVolSuite.kt), sections « indicatifs »,
/// « memes », « raisons », « releves », « adresses », « carres », « etats ».
public enum SuiviVol {

    public enum Resultat: Sendable, Hashable {
        case trouve(point: Vol.Point, altitudeMetres: Double?)
        /// L'avion n'est pas vu autour de la position estimée (hors couverture, indicatif inexact).
        case introuvable
        /// `raison` est un code de `Raison`, traduit à l'affichage : jamais du texte montré tel quel.
        case erreur(raison: String)
    }

    /// Les raisons d'une erreur, partagées avec RouteVol. Des codes et non des phrases : l'écran les traduit.
    public enum Raison {
        public static let horsLigne = "hors_ligne"
        public static let quota = "quota"
        public static let illisible = "illisible"
        public static let positionInvalide = "position_invalide"
        public static let relaisAbsent = "relais_absent"
        /// Le relais a répondu une erreur qu'on ne sait pas nommer.
        public static let service = "service"
        private static let prefixeServeur = "serveur_"

        public static func serveur(_ code: Int) -> String {
            code == 429 ? quota : prefixeServeur + String(code)
        }

        /// Le code HTTP d'une raison `serveur`, sinon nil.
        public static func codeServeur(_ raison: String) -> Int? {
            guard raison.commenceParUnites(prefixeServeur) else { return nil }
            return entierKotlin(raison.sansPremieresUnites(prefixeServeur.utf16.count))
        }

        /// Le message du relais (tools/relais_vol) : « opensky 429 », « opensky injoignable »… nil là où Kotlin
        /// lève (un code qui ne tient pas sur 32 bits) : `lire` en fait alors une réponse illisible.
        public static func duRelais(_ message: String) -> String? {
            guard let m = motifRelais.entiere(message.rogne) else { return service }
            guard let code = Int32(m.groupes[1]) else { return nil }
            return serveur(Int(code))
        }

        /// `\d` de la JVM : les seuls chiffres ASCII.
        private static let motifRelais = ExpressionReguliere("opensky ([0-9]+)")
    }

    /// D'où vient la position : le relais s'il est configuré à la construction (en HTTPS seulement), sinon OpenSky
    /// en accès anonyme. Le `fournisseur` de Kotlin, sans le réseau.
    public enum Fournisseur: Sendable, Hashable {
        case openSkyAnonyme
        case relais(String)
    }

    public static func fournisseur(_ relais: String) -> Fournisseur {
        relais.commenceParUnites("https://") ? .relais(relais) : .openSkyAnonyme
    }

    /// Une position plus vieille ne recale plus la route : l'avion a fait 150 km depuis. 10 minutes, en millisecondes
    /// (un nombre entier de secondes : `perime` en dépend).
    public static let fraicheurMax: Int64 = 10 * 60_000

    /// « ely 001 » → « ELY001 » ; nil si ce n'est pas un indicatif OACI plausible (3 lettres puis 1 à 4 chiffres,
    /// deux lettres au plus). Seules les espaces sont ôtées, comme `replace(" ", "")`.
    public static func normaliser(_ texte: String) -> String? {
        let t = texte.uppercased().remplacantUnites(" ", par: "")
        return motifIndicatif.couvre(t) ? t : nil
    }

    private static let motifIndicatif = ExpressionReguliere("[A-Z]{3}[0-9]{1,4}[A-Z]{0,2}")
    private static let motifParties = ExpressionReguliere("([A-Z]{3})0*([0-9]+)([A-Z]*)")

    /// ELY001 et ELY1 sont le même vol : même préfixe, même numéro, mêmes lettres finales.
    public static func memeIndicatif(_ a: String, _ b: String) -> Bool {
        guard let pa = parties(a) else { return false }
        return pa == parties(b)
    }

    private static func parties(_ x: String) -> [String]? {
        guard let m = motifParties.entiere(x.uppercased().rogne) else { return nil }
        return Array(m.groupes.dropFirst())
    }

    /// La réponse du relais : { trouve, latitude, longitude, altitude_geo, altitude_baro, instant }, lue à
    /// `maintenant` (millisecondes Unix).
    public static func lire(_ json: String, _ maintenant: Int64) -> Resultat {
        guard let o = try? ObjetJSON(texte: json) else { return .erreur(raison: Raison.illisible) }
        if o.a("erreur") {
            // `getString` : toute valeur présente, en texte (`null` rend « null »).
            guard let raison = Raison.duRelais(o["erreur"]?.commeTexte ?? "") else { return .erreur(raison: Raison.illisible) }
            return .erreur(raison: raison)
        }
        if !o.booleen("trouve") { return .introuvable }
        // `Instant.parse(getString(…))`, `getDouble` : une valeur absente ou illisible rend la réponse illisible.
        guard let texte = o["instant"]?.commeTexte, let instant = instantISO(texte),
              let latitude = o["latitude"]?.commeDouble, let longitude = o["longitude"]?.commeDouble else {
            return .erreur(raison: Raison.illisible)
        }
        var altitude: Double?
        for cle in ["altitude_geo", "altitude_baro"] {
            let x = o.double(cle)
            if !x.isNaN {
                altitude = x
                break
            }
        }
        return position(instant, latitude, longitude, altitude, maintenant)
    }

    /// Un instant lu : les secondes depuis 1970 et les nanosecondes (0 ≤ nanos < 10⁹), comme `Instant`.
    private struct InstantLu {
        let secondes: Int64
        let nanos: Int64
    }

    /// La fin commune de `lire` et de `lireEtats` : la position vérifiée, puis sa fraîcheur.
    private static func position(_ instant: InstantLu, _ latitude: Double, _ longitude: Double, _ altitude: Double?,
                                 _ maintenant: Int64) -> Resultat {
        if !(latitude >= -90 && latitude <= 90) || !(longitude >= -180 && longitude <= 180) {
            return .erreur(raison: Raison.positionInvalide)
        }
        if perime(instant, maintenant) { return .introuvable }
        // Un instant trop lointain pour des millisecondes sur 64 bits (au-delà de l'an 292 millions) : Kotlin le
        // garderait, il ne s'écrit pas ici.
        let (enMillis, deborde) = instant.secondes.multipliedReportingOverflow(by: 1000)
        let (millis, deborde2) = enMillis.addingReportingOverflow(instant.nanos / 1_000_000)
        if deborde || deborde2 { return .erreur(raison: Raison.illisible) }
        return .trouve(point: Vol.Point(instant: millis, latitude: latitude, longitude: longitude), altitudeMetres: altitude)
    }

    /// `Duration.between(instant, maintenant) > FRAICHEUR_MAX`, à la nanoseconde.
    private static func perime(_ instant: InstantLu, _ maintenant: Int64) -> Bool {
        var secondes = Int64(Kotlin.floorDiv(Int(maintenant), 1000)) - instant.secondes
        var nanos = Int64(Kotlin.floorMod(Int(maintenant), 1000)) * 1_000_000 - instant.nanos
        if nanos < 0 {
            secondes -= 1
            nanos += 1_000_000_000
        }
        let limite = fraicheurMax / 1000
        return secondes > limite || (secondes == limite && nanos > 0)
    }

    /// L'adresse demandée au relais : seulement l'indicatif et la position estimée, arrondie au dixième de degré.
    public static func adresse(_ relais: String, _ indicatif: String, _ estime: Vol.Point) -> String {
        sansBarresFinales(relais) + "/position?indicatif=" + encoder(indicatif) +
            "&lat=" + Java.format(estime.latitude, decimales: 1) + "&lon=" + Java.format(estime.longitude, decimales: 1)
    }

    /// `trimEnd('/')`.
    private static func sansBarresFinales(_ s: String) -> String {
        var unites = Array(s.utf16)
        while let derniere = unites.last, derniere == 0x2F { unites.removeLast() }
        return Unites.texte(unites)
    }

    /// `URLEncoder.encode(texte, "UTF-8")` : lettres et chiffres ASCII, « . - * _ » tels quels, l'espace en « + »,
    /// tout autre octet UTF-8 en « %XY ».
    private static func encoder(_ texte: String) -> String {
        var sortie = ""
        for octet in texte.utf8 {
            switch octet {
            case 0x61...0x7A, 0x41...0x5A, 0x30...0x39, 0x2E, 0x2D, 0x2A, 0x5F:
                sortie.append(Character(Unicode.Scalar(octet)))
            case 0x20:
                sortie.append("+")
            default:
                let hexa = String(octet, radix: 16, uppercase: true)
                sortie += (hexa.utf16.count < 2 ? "%0" : "%") + hexa
            }
        }
        return sortie
    }

    public static let etats = "https://opensky-network.org/api/states/all"
    public static let demiCote = 5.0

    /// Les carrés à demander, [lamin, lomin, lamax, lomax] : un seul, ou deux de part et d'autre du méridien de
    /// 180° (tools/relais_vol, carres).
    public static func carres(_ lat: Double, _ lon: Double, _ d: Double = SuiviVol.demiCote) -> [[Double]] {
        let lamin = maxJava(-90.0, lat - d)
        let lamax = minJava(90.0, lat + d)
        let lomin = lon - d
        let lomax = lon + d
        if lomin < -180 { return [[lamin, lomin + 360, lamax, 180.0], [lamin, -180.0, lamax, lomax]] }
        if lomax > 180 { return [[lamin, lomin, lamax, 180.0], [lamin, -180.0, lamax, lomax - 360]] }
        return [[lamin, lomin, lamax, lomax]]
    }

    /// `maxOf` et `minOf` de Kotlin (`Math.max`, `Math.min`) : NaN l'emporte, là où `max` de Swift garderait l'autre.
    private static func maxJava(_ a: Double, _ b: Double) -> Double {
        if a.isNaN || b.isNaN { return .nan }
        return a >= b ? a : b
    }

    private static func minJava(_ a: Double, _ b: Double) -> Double {
        if a.isNaN || b.isNaN { return .nan }
        return a <= b ? a : b
    }

    /// L'adresse d'un carré [lamin, lomin, lamax, lomax] chez OpenSky.
    public static func adresseEtats(_ c: [Double]) -> String {
        etats + "?lamin=" + Java.format(c[0], decimales: 1) + "&lomin=" + Java.format(c[1], decimales: 1) +
            "&lamax=" + Java.format(c[2], decimales: 1) + "&lomax=" + Java.format(c[3], decimales: 1)
    }

    /// La réponse d'OpenSky (/states/all) : l'avion en vol dont l'indicatif correspond, lu comme la réponse du relais.
    /// [icao24, callsign, pays, time_position, last_contact, longitude, latitude, baro_altitude, on_ground, …,
    /// geo_altitude (13)].
    public static func lireEtats(_ json: String, _ indicatif: String, _ maintenant: Int64) -> Resultat {
        guard let racine = try? ObjetJSON(texte: json) else { return .erreur(raison: Raison.illisible) }
        let liste = racine.tableau("states") ?? []
        for element in liste {
            // `getJSONArray` : un élément qui n'est pas un tableau rend toute la réponse illisible.
            guard case .tableau(let e) = element else { return .erreur(raison: Raison.illisible) }
            if e.estNul(1) || e.estNul(3) || e.estNul(5) || e.estNul(6) || e.booleen(8, defaut: false) { continue }
            if !memeIndicatif(e[1].commeTexte, indicatif) { continue }
            // Kotlin récrit l'état en réponse du relais : `getDouble` et `getLong` lèvent sur une valeur illisible,
            // `put` sur NaN et l'infini, et un zéro négatif s'y écrit « -0 », relu 0.
            guard let latitude = fini(e[6].commeDouble), let longitude = fini(e[5].commeDouble),
                  let secondes = e[3].commeLong else { return .erreur(raison: Raison.illisible) }
            var geo: Double?
            if !e.estNul(13) {
                guard let x = fini(e[13].commeDouble) else { return .erreur(raison: Raison.illisible) }
                geo = x
            }
            var baro: Double?
            if !e.estNul(7) {
                guard let x = fini(e[7].commeDouble) else { return .erreur(raison: Raison.illisible) }
                baro = x
            }
            // `Instant.ofEpochSecond` : hors des bornes d'`Instant`, une exception, donc illisible.
            if secondes < -31_557_014_167_219_200 || secondes > 31_556_889_864_403_199 { return .erreur(raison: Raison.illisible) }
            return position(InstantLu(secondes: secondes, nanos: 0), latitude, longitude, geo ?? baro, maintenant)
        }
        return .introuvable
    }

    /// Une valeur que `JSONObject.put` accepte, le zéro négatif ramené à zéro ; nil sinon.
    private static func fini(_ x: Double?) -> Double? {
        guard let x, x.isFinite else { return nil }
        return x == 0 ? 0 : x
    }

    // MARK: Lectures à la Java

    /// `Instant.parse` (ISO_INSTANT, sans égard à la casse) : « 2026-11-10T18:30:00Z », une fraction de 0 à 9
    /// chiffres, un décalage « Z » ou ±HH:MM[:ss] ; 24:00:00 est minuit du lendemain, 23:59:60 vaut 23:59:59.
    /// L'année : quatre chiffres, ou un signe (« + » au-delà de quatre chiffres, « - » pour les années négatives),
    /// dans les bornes de `JourCivil`.
    private static func instantISO(_ texte: String) -> InstantLu? {
        let u = Array(texte.utf16)
        var i = 0
        func chiffres(_ n: Int) -> Int? {
            guard i + n <= u.count else { return nil }
            var v = 0
            for k in i..<(i + n) {
                guard u[k] >= 0x30 && u[k] <= 0x39 else { return nil }
                v = v * 10 + Int(u[k] - 0x30)
            }
            i += n
            return v
        }
        func signe(_ c: UInt16) -> Bool {
            guard i < u.count, u[i] == c else { return false }
            i += 1
            return true
        }
        guard let annee = lireAnnee(u, &i), signe(0x2D), let mois = chiffres(2), signe(0x2D), let jourDuMois = chiffres(2),
              i < u.count, u[i] == 0x54 || u[i] == 0x74 else { return nil }
        i += 1
        guard var heure = chiffres(2), signe(0x3A), let minute = chiffres(2), signe(0x3A), var seconde = chiffres(2) else {
            return nil
        }
        var nanos = 0
        if signe(0x2E) {
            var lus = 0
            while lus < 9 && i < u.count && u[i] >= 0x30 && u[i] <= 0x39 {
                nanos = nanos * 10 + Int(u[i] - 0x30)
                lus += 1
                i += 1
            }
            while lus < 9 {
                nanos *= 10
                lus += 1
            }
        }
        guard i < u.count else { return nil }
        var decalage = 0
        if u[i] == 0x5A || u[i] == 0x7A {
            i += 1
        } else if u[i] == 0x2B || u[i] == 0x2D {
            let negatif = u[i] == 0x2D
            i += 1
            guard let h = deuxChiffres(u, i) else { return nil }
            i += 2
            guard signe(0x3A), let m = deuxChiffres(u, i) else { return nil }
            i += 2
            var s = 0
            if i < u.count && u[i] == 0x3A, let x = deuxChiffres(u, i + 1) {
                s = x
                i += 3
            }
            // Au-delà de 23 heures, Java lève ; `ZoneOffset` refuse plus de 18 heures : la réponse est illisible.
            let total = h * 3600 + m * 60 + s
            if h > 23 || total > 18 * 3600 { return nil }
            decalage = negatif ? -total : total
        } else {
            return nil
        }
        guard i == u.count else { return nil }
        var jours = 0
        if heure == 24 && minute == 0 && seconde == 0 && nanos == 0 {
            heure = 0
            jours = 1
        } else if heure == 23 && minute == 59 && seconde == 60 {
            seconde = 59
        }
        guard heure <= 23, minute <= 59, seconde <= 59,
              let jour = JourCivil(annee: annee, mois: mois, jour: jourDuMois) else { return nil }
        let depuis1970 = Int64(jour.jourJulien - 2_440_588 + jours)
        let secondes = depuis1970 * 86_400 + Int64(heure * 3600 + minute * 60 + seconde - decalage)
        return InstantLu(secondes: secondes, nanos: Int64(nanos))
    }

    /// Deux chiffres ASCII d'un décalage, de 00 à 59 (`parseDigits` de Java) ; nil sinon.
    private static func deuxChiffres(_ u: [UInt16], _ i: Int) -> Int? {
        guard i + 2 <= u.count, u[i] >= 0x30 && u[i] <= 0x39, u[i + 1] >= 0x30 && u[i + 1] <= 0x39 else { return nil }
        let v = Int(u[i] - 0x30) * 10 + Int(u[i + 1] - 0x30)
        return v <= 59 ? v : nil
    }

    /// L'année d'ISO_LOCAL_DATE (4 à 10 chiffres, `SignStyle.EXCEEDS_PAD` en lecture stricte) : sans signe, quatre
    /// chiffres exactement ; « + » seulement au-delà de quatre ; « - » suivi d'au moins quatre chiffres, pas « -0000 ».
    private static func lireAnnee(_ u: [UInt16], _ i: inout Int) -> Int? {
        var negatif = false
        var positif = false
        if i < u.count && u[i] == 0x2B {
            positif = true
            i += 1
        } else if i < u.count && u[i] == 0x2D {
            negatif = true
            i += 1
        }
        var valeur = 0
        var lus = 0
        while lus < 10 && i < u.count && u[i] >= 0x30 && u[i] <= 0x39 {
            valeur = valeur * 10 + Int(u[i] - 0x30)
            lus += 1
            i += 1
        }
        if lus < 4 { return nil }
        if negatif { return valeur == 0 ? nil : -valeur }
        if positif { return lus > 4 ? valeur : nil }
        return lus > 4 ? nil : valeur
    }

    /// `toIntOrNull()` de Kotlin : un signe facultatif, puis des chiffres décimaux d'Unicode (`Character.digit`) ;
    /// nil hors des 32 bits.
    private static func entierKotlin(_ texte: String) -> Int? {
        let unites = Array(texte.utf16)
        guard let premiere = unites.first else { return nil }
        var debut = 0
        var negatif = false
        if premiere < 0x30 {
            if unites.count == 1 { return nil }
            if premiere == 0x2D {
                negatif = true
            } else if premiere != 0x2B {
                return nil
            }
            debut = 1
        }
        var valeur: Int64 = 0
        for u in unites[debut...] {
            guard let c = chiffre(u) else { return nil }
            valeur = valeur * 10 + Int64(c)
            if valeur > 2_147_483_648 { return nil }
        }
        if negatif { return Int(-valeur) }
        return valeur > 2_147_483_647 ? nil : Int(valeur)
    }

    /// `Character.digit(c, 10)` de Java : la valeur d'un chiffre décimal d'Unicode (catégorie Nd), nil sinon.
    private static func chiffre(_ u: UInt16) -> Int? {
        if u >= 0x30 && u <= 0x39 { return Int(u - 0x30) }
        guard let scalaire = Unicode.Scalar(u), scalaire.properties.numericType == .decimal,
              let valeur = scalaire.properties.numericValue else { return nil }
        return Int(valeur)
    }
}
