import Foundation
import Testing
@testable import Coeur

/// La direction de Jérusalem (DirectionJerusalemTest d'Android). Les valeurs attendues ne viennent pas
/// de ce code : grand cercle et distance par geographiclib (Karney, ellipsoïde WGS84), d'où la marge
/// d'un demi-degré et de 0,5 % pour la sphère ; cap constant par la formule de Mercator, calculée à
/// part en Python. New York : 54° et environ 95°, comme Chabad.org.
///
/// Reste au dessin de la boussole (BoussoleDessin.kt, avec l'écran) : les deux lignes de `xHorizon`
/// du quatrième test ; `lisser` y est vérifié ici, dans `Boussole`. S'y ajoutent
/// `boussoleSelonLaCarteAuChoix` de VoyageNuitTest et « la direction de Jérusalem tient avec 3 km
/// d'écart » de PositionApprocheeTest ; le reste de ces deux tests va avec la barrière, les vignettes
/// et les zmanim, ou reste à Android (le manifeste, ChoixLieu.kt, strings.xml). Puis `geo.json`
/// (VecteursGeo.kt), rejoué en entier.
@Suite("DirectionJerusalem")
struct DirectionJerusalemTests {

    private struct Cas {
        let nom: String
        let lat: Double
        let lon: Double
        let gc: Double
        let rh: Double
        let km: Double
    }

    private let cas = [
        Cas(nom: "Paris", lat: 48.8566, lon: 2.3522, gc: 112.39, rh: 124.51, km: 3337.0),
        Cas(nom: "New York", lat: 40.7128, lon: -74.0060, gc: 54.01, rh: 95.80, km: 9189.0),
        Cas(nom: "Los Angeles", lat: 34.0522, lon: -118.2437, gc: 23.71, rh: 91.01, km: 12208.0),
        Cas(nom: "Melbourne", lat: -37.8136, lon: 144.9631, gc: 286.52, rh: 304.16, km: 13709.0),
        Cas(nom: "Buenos Aires", lat: -34.6037, lon: -58.3816, gc: 64.76, rh: 53.03, km: 12231.0),
        Cas(nom: "Montréal", lat: 45.5017, lon: -73.5673, gc: 54.90, rh: 99.22, km: 8851.0),
    ]

    /// Deux angles à `marge` degrés près, de part et d'autre du nord compris.
    private func proches(_ attendu: Double, _ obtenu: Double, _ marge: Double) -> Bool {
        abs(DirectionJerusalem.ecart(attendu, obtenu)) <= marge
    }

    @Test func lesDeuxDirectionsEtLaDistanceDesGrandesVilles() {
        for c in cas {
            let gc = DirectionJerusalem.grandCercle(c.lat, c.lon)
            let gcJuste = proches(c.gc, gc, 0.5)
            #expect(gcJuste, "\(c.nom) grand cercle : \(gc) au lieu de \(c.gc)")
            let rh = DirectionJerusalem.carte(c.lat, c.lon)
            let rhJuste = proches(c.rh, rh, 0.05)
            #expect(rhJuste, "\(c.nom) cap constant : \(rh) au lieu de \(c.rh)")
            let d = DirectionJerusalem.distanceKm(c.lat, c.lon)
            let relatif = abs(d - c.km) / c.km
            #expect(relatif < 0.005, "\(c.nom) distance \(d)")
        }
    }

    @Test func parLePlusCourtCoteDuMeridienDe180Degres() {
        // De Honolulu, la loxodromie passe par l'ouest (cap 270° et plus), pas par l'est.
        let rh = DirectionJerusalem.carte(21.3069, -157.8583)
        #expect(rh > 270 && rh < 300, "\(rh)")
        // Depuis Jérusalem même, la distance est nulle, sans NaN.
        let d = DirectionJerusalem.distanceKm(DirectionJerusalem.latitude, DirectionJerusalem.longitude)
        #expect(abs(d) <= 1e-6, "\(d)")
    }

    @Test func lEcartLaToleranceLesDegresLesPointsCardinaux() {
        let e1 = DirectionJerusalem.ecart(10.0, 0.0)
        #expect(abs(e1 - 10) <= 1e-9, "\(e1)")
        let e2 = DirectionJerusalem.ecart(350.0, 10.0)
        #expect(abs(e2 + 20) <= 1e-9, "\(e2)")
        let e3 = DirectionJerusalem.ecart(10.0, 350.0)
        #expect(abs(e3 - 20) <= 1e-9, "\(e3)")
        let faceA = DirectionJerusalem.face(4.0)
        let faceB = DirectionJerusalem.face(-4.0)
        let faceC = DirectionJerusalem.face(4.1)
        #expect(faceA)
        #expect(faceB)
        #expect(!faceC)
        let d1 = DirectionJerusalem.degres(359.6)
        let d2 = DirectionJerusalem.degres(54.01)
        #expect(d1 == 0)
        #expect(d2 == 54)
        let p1 = DirectionJerusalem.point(54.0)
        let p2 = DirectionJerusalem.point(95.8)
        let p3 = DirectionJerusalem.point(350.0)
        #expect(p1 == 1)
        #expect(p2 == 2)
        #expect(p3 == 0)
        // Le hassid suit le grand cercle ; la carte est l'autre, pour information.
        let (p, a) = DirectionJerusalem.directions(40.7128, -74.0060)
        let gc = DirectionJerusalem.grandCercle(40.7128, -74.0060)
        let rh = DirectionJerusalem.carte(40.7128, -74.0060)
        #expect(abs(gc - p) <= 1e-9)
        #expect(abs(rh - a) <= 1e-9)
    }

    @Test func leFiltreSuitLeCapParLePlusCourtCote() {
        let premier = Boussole.lisser(nil, 10.0)
        #expect(abs(premier - 10) <= 1e-9, "\(premier)")
        // De 350° vers 10° : il passe par 354°, pas par 278°.
        let suivant = Boussole.lisser(350.0, 10.0)
        #expect(abs(suivant - 354) <= 1e-9, "\(suivant)")
    }

    // MARK: VoyageNuitTest

    @Test func boussoleSelonLaCarteAuChoix() {
        // New York : environ 54° par le grand cercle, 95° sur la carte de Mercator.
        let (gc, rh) = DirectionJerusalem.directions(40.7128, -74.0060)
        let (suivie, autre) = DirectionJerusalem.directions(40.7128, -74.0060, selonCarte: true)
        #expect(suivie == rh)
        #expect(autre == gc)
        let vraisemblables = (50.0...58.0).contains(gc) && (92.0...98.0).contains(rh)
        #expect(vraisemblables, "\(gc) \(rh)")
    }

    // MARK: PositionApprocheeTest

    /// `Math.toRadians` de Java (depuis Java 9) : un produit par π/180.
    private func radians(_ d: Double) -> Double { d * 0.017453292519943295 }

    /// Le point à `km` kilomètres de (lat, lon), vers le cap `cap` en degrés.
    private func decale(_ lat: Double, _ lon: Double, _ km: Double, _ cap: Double) -> (Double, Double) {
        let r = radians(cap)
        let dLat = km * cos(r) / 111.2
        let dLon = km * sin(r) / (111.2 * cos(radians(lat)))
        return (lat + dLat, lon + dLon)
    }

    /// De combien la direction tourne au pire, le lieu décalé de `km` vers les 24 caps de 15 en 15°.
    private func ecartMax(_ lat: Double, _ lon: Double, _ km: Double) -> Double {
        var pire = 0.0
        for cap in stride(from: 0, to: 360, by: 15) {
            let (la, lo) = decale(lat, lon, km, Double(cap))
            let e = abs(DirectionJerusalem.ecart(DirectionJerusalem.grandCercle(la, lo), DirectionJerusalem.grandCercle(lat, lon)))
            pire = max(pire, e)
        }
        return pire
    }

    @Test func laDirectionDeJerusalemTientAvec3KmDEcart() {
        let tolerance = Double(DirectionJerusalem.tolerance)
        let loin = [(48.8534, 2.3488), (40.7143, -74.006), (-37.814, 144.9633), (32.0853, 34.7818), (32.7940, 34.9896)]
        for (lat, lon) in loin {
            let d = DirectionJerusalem.distanceKm(lat, lon)
            let e = ecartMax(lat, lon, 3.0)
            if d >= 200 { #expect(e < 1.0, "à \(d) km : \(e)°") }
            if d >= 50 { #expect(e < tolerance, "à \(d) km : \(e)° dépasse la tolérance") }
        }
        // Tout près de Har haBayit, l'approximative ne suffit plus à la précision de la boussole :
        // c'est une limite connue (PUBLICATION_PLAY_STORE.md § 6.7), pas une erreur de calcul.
        let pres = ecartMax(31.7683, 35.2137, 3.0)
        #expect(pres > tolerance, "\(pres)")
    }

    // MARK: geo.json

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let latitude: Double
            let longitude: Double
            let tolerance: Double
        }
        struct Direction: Decodable {
            let lat: Double
            let lon: Double
            let grandCercle: Double
            let carte: Double
            let distanceKm: Double
        }
        struct Angle: Decodable {
            let d: Double
            let norm: Double
            let degres: Int
            let point: Int
            let face: Bool
        }
        struct Ecart: Decodable {
            let cible: Double
            let cap: Double
            let ecart: Double
        }
        struct Approchee: Decodable {
            let lat: Double
            let lon: Double
            let distanceKm: Double
            /// Avec 1, 3 et 10 km d'écart.
            let ecartMax: [Double]
        }
        let constantes: Constantes
        let directions: [Direction]
        let angles: [Angle]
        let ecarts: [Ecart]
        let approchee: [Approchee]
        struct Conseil: Decodable {
            let lat: Int
            /// « 1 » : le conseil du minyan, une colonne par longitude de -180 à 170, de dix en dix.
            let conseil: String
        }
        let conseilMinyan: [Conseil]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/geo.json"))
    }

    /// DirectionJerusalem.conseilMinyan (audit du 16/11) : les deux méthodes diffèrent de plus de 20°.
    @Test func leConseilDuMinyanCommeLaJVM() throws {
        let v = try vecteurs()
        #expect(v.conseilMinyan.count == 17)
        var oui = 0
        for ligne in v.conseilMinyan {
            let calcule = stride(from: -180, through: 170, by: 10).map {
                DirectionJerusalem.conseilMinyan(Double(ligne.lat), Double($0)) ? "1" : "0"
            }.joined()
            #expect(calcule == ligne.conseil, "latitude \(ligne.lat)")
            oui += ligne.conseil.filter { $0 == "1" }.count
        }
        #expect(oui > 0)
        // Los Angeles : 23,8° contre 91,0°.
        #expect(DirectionJerusalem.conseilMinyan(34.05, -118.24))
        #expect(!DirectionJerusalem.conseilMinyan(48.8534, 2.3488))
    }

    @Test func lesConstantesSontCellesDuKotlin() throws {
        let c = try vecteurs().constantes
        #expect(c.latitude == DirectionJerusalem.latitude)
        #expect(c.longitude == DirectionJerusalem.longitude)
        #expect(c.tolerance == Double(DirectionJerusalem.tolerance))
    }

    /// sin, cos, tan, ln, atan2 et acos diffèrent parfois au dernier chiffre de la JVM : un millionième
    /// de degré et un mètre de marge, bien en deçà d'une faute de formule.
    @Test func lesDirectionsEtLesDistancesDeLaJVMSurLeGlobe() throws {
        let v = try vecteurs()
        #expect(v.directions.count == 632)
        for c in v.directions {
            let gc = DirectionJerusalem.grandCercle(c.lat, c.lon)
            let rh = DirectionJerusalem.carte(c.lat, c.lon)
            let km = DirectionJerusalem.distanceKm(c.lat, c.lon)
            let gcJuste = proches(c.grandCercle, gc, 1e-6)
            let rhJuste = proches(c.carte, rh, 1e-6)
            let kmJuste = abs(km - c.distanceKm) <= 1e-3
            #expect(gcJuste, "grand cercle (\(c.lat), \(c.lon)) : \(gc) au lieu de \(c.grandCercle)")
            #expect(rhJuste, "carte (\(c.lat), \(c.lon)) : \(rh) au lieu de \(c.carte)")
            #expect(kmJuste, "distance (\(c.lat), \(c.lon)) : \(km) au lieu de \(c.distanceKm)")
            // directions() rend les deux mêmes, dans l'ordre choisi.
            let (p, a) = DirectionJerusalem.directions(c.lat, c.lon)
            let (pc, ac) = DirectionJerusalem.directions(c.lat, c.lon, selonCarte: true)
            let ordre = p == gc && a == rh && pc == rh && ac == gc
            #expect(ordre, "directions (\(c.lat), \(c.lon))")
        }
    }

    /// norm, degres, point, face et ecart ne sont que de l'arithmétique : à l'identique.
    @Test func lesAnglesEtLesEcartsALIdentique() throws {
        let v = try vecteurs()
        #expect(v.angles.count == 376)
        for c in v.angles {
            let norm = DirectionJerusalem.norm(c.d)
            let degres = DirectionJerusalem.degres(c.d)
            let point = DirectionJerusalem.point(c.d)
            let face = DirectionJerusalem.face(c.d)
            #expect(norm == c.norm, "norm(\(c.d)) : \(norm) au lieu de \(c.norm)")
            #expect(degres == c.degres, "degres(\(c.d)) : \(degres) au lieu de \(c.degres)")
            #expect(point == c.point, "point(\(c.d)) : \(point) au lieu de \(c.point)")
            #expect(face == c.face, "face(\(c.d))")
        }
        #expect(v.ecarts.count == 174)
        for c in v.ecarts {
            let e = DirectionJerusalem.ecart(c.cible, c.cap)
            #expect(e == c.ecart, "ecart(\(c.cible), \(c.cap)) : \(e) au lieu de \(c.ecart)")
        }
    }

    @Test func lEcartMaximalDUnePositionApprocheeCommeLaJVM() throws {
        let v = try vecteurs()
        #expect(v.approchee.count == 8)
        for c in v.approchee {
            let d = DirectionJerusalem.distanceKm(c.lat, c.lon)
            #expect(abs(d - c.distanceKm) <= 1e-3, "distance (\(c.lat), \(c.lon)) : \(d)")
            for (rang, km) in [1.0, 3.0, 10.0].enumerated() where rang < c.ecartMax.count {
                let e = ecartMax(c.lat, c.lon, km)
                let attendu = c.ecartMax[rang]
                #expect(abs(e - attendu) <= 1e-6, "(\(c.lat), \(c.lon)) à \(km) km : \(e) au lieu de \(attendu)")
            }
        }
    }
}
