import Foundation
import Testing
@testable import Coeur

/// DirectionJerusalemTest, TerritoireIsraelTest et VillePlusProcheTest d'Android, portés ; puis la grille
/// du globe, le contour d'Israël point par point et la ville la plus proche devant la JVM
/// (Tests/Vecteurs/geographie_vol.json, tools/vecteurs_ios/VecteursGeographieVol.kt). Restent à la
/// boussole (tâche 25) le lissage du cap et le dessin de l'horizon, qui sont des écrans.
@Suite("Géographie")
struct GeographieTests {

    private struct Cas { let nom: String, lat: Double, lon: Double, gc: Double, rh: Double, km: Double }

    private let cas = [
        Cas(nom: "Paris", lat: 48.8566, lon: 2.3522, gc: 112.39, rh: 124.51, km: 3337.0),
        Cas(nom: "New York", lat: 40.7128, lon: -74.0060, gc: 54.01, rh: 95.80, km: 9189.0),
        Cas(nom: "Los Angeles", lat: 34.0522, lon: -118.2437, gc: 23.71, rh: 91.01, km: 12208.0),
        Cas(nom: "Melbourne", lat: -37.8136, lon: 144.9631, gc: 286.52, rh: 304.16, km: 13709.0),
        Cas(nom: "Buenos Aires", lat: -34.6037, lon: -58.3816, gc: 64.76, rh: 53.03, km: 12231.0),
        Cas(nom: "Montréal", lat: 45.5017, lon: -73.5673, gc: 54.90, rh: 99.22, km: 8851.0),
    ]

    @Test func lesDeuxDirectionsEtLaDistanceDesGrandesVilles() {
        for c in cas {
            let gc = DirectionJerusalem.grandCercle(c.lat, c.lon), rh = DirectionJerusalem.carte(c.lat, c.lon)
            #expect(abs(DirectionJerusalem.ecart(c.gc, gc)) <= 0.5, "\(c.nom) grand cercle : \(gc)")
            #expect(abs(DirectionJerusalem.ecart(c.rh, rh)) <= 0.05, "\(c.nom) cap constant : \(rh)")
            let d = DirectionJerusalem.distanceKm(c.lat, c.lon)
            #expect(abs(d - c.km) / c.km < 0.005, "\(c.nom) distance \(d)")
        }
    }

    @Test func parLePlusCourtCoteDuMeridienDe180Degres() {
        // De Honolulu, la loxodromie passe par l'ouest (cap 270° et plus), pas par l'est.
        let rh = DirectionJerusalem.carte(21.3069, -157.8583)
        #expect(rh > 270 && rh < 300, "\(rh)")
        // Depuis Jérusalem même, la distance est nulle, sans NaN.
        #expect(abs(DirectionJerusalem.distanceKm(DirectionJerusalem.latitude, DirectionJerusalem.longitude)) <= 1e-6)
    }

    @Test func lEcartLaToleranceLesDegresLesPointsCardinaux() {
        #expect(DirectionJerusalem.ecart(10, 0) == 10)
        #expect(DirectionJerusalem.ecart(350, 10) == -20)
        #expect(DirectionJerusalem.ecart(10, 350) == 20)
        #expect(DirectionJerusalem.face(4.0))
        #expect(DirectionJerusalem.face(-4.0))
        #expect(!DirectionJerusalem.face(4.1))
        #expect(DirectionJerusalem.degres(359.6) == 0)
        #expect(DirectionJerusalem.degres(54.01) == 54)
        #expect(DirectionJerusalem.point(54.0) == 1)
        #expect(DirectionJerusalem.point(95.8) == 2)
        #expect(DirectionJerusalem.point(350.0) == 0)
        // Le hassid suit le grand cercle ; la carte est l'autre, pour information.
        let d = DirectionJerusalem.directions(40.7128, -74.0060)
        #expect(d.suivie == DirectionJerusalem.grandCercle(40.7128, -74.0060))
        #expect(d.autre == DirectionJerusalem.carte(40.7128, -74.0060))
    }

    private let dedans: [(String, Double, Double)] = [
        ("Jérusalem", 31.7769, 35.2224), ("Tel Aviv", 32.0853, 34.7818), ("Haïfa", 32.7940, 34.9896),
        ("Eilat", 29.5577, 34.9519), ("Beer Chéva", 31.2518, 34.7913), ("Mitspé Ramon", 30.6097, 34.8019),
        ("Kiryat Chmona", 33.2073, 35.5700), ("Metoula", 33.2770, 35.5790), ("Katsrin", 32.9930, 35.6900),
        ("Ariel", 32.1060, 35.1710), ("Hébron", 31.5326, 35.0998), ("Tibériade", 32.7922, 35.5312),
        ("Nahariya", 33.0058, 35.0950), ("Ashkelon", 31.6688, 34.5743), ("Ein Gedi", 31.4500, 35.3830),
        ("Netanya", 32.3215, 34.8532), ("Akko", 32.9281, 35.0818), ("Bet Chéan", 32.4973, 35.4968),
        ("Sderot", 31.5250, 34.5966), ("Yotvata", 29.8950, 35.0600),
        ("Ein Zivan", 33.1060, 35.8060), ("Majdal Chams", 33.2700, 35.7700),
    ]
    private let dehors: [(String, Double, Double)] = [
        ("Amman", 31.9539, 35.9106), ("Aqaba", 29.5321, 35.0063), ("Beyrouth", 33.8938, 35.5018),
        ("Tyr", 33.2705, 35.2038), ("Damas", 33.5138, 36.2765), ("Le Caire", 30.0444, 31.2357),
        ("El Arich", 31.1316, 33.7984), ("Taba", 29.4900, 34.8760), ("Paris", 48.8566, 2.3522),
        ("Irbid", 32.5556, 35.8500), ("Nicosie", 35.1856, 33.3823), ("Kerak", 31.1800, 35.7000),
        ("Kuneitra", 33.1256, 35.8244),
    ]

    @Test func lesVillesDIsraelSontDedans() {
        for (nom, lat, lon) in dedans { #expect(TerritoireIsrael.contient(latitude: lat, longitude: lon), "\(nom)") }
    }

    @Test func lesVillesVoisinesSontDehors() {
        for (nom, lat, lon) in dehors { #expect(!TerritoireIsrael.contient(latitude: lat, longitude: lon), "\(nom)") }
    }

    private func ville(_ id: Int64, _ nom: String, _ pays: String, _ lat: Double, _ lon: Double) -> Ville {
        Ville(id: id, nom: TexteLocalise(he: nom, fr: nom, en: nom), pays: pays, latitude: lat, longitude: lon,
              fuseau: pays == "IL" ? "Asia/Jerusalem" : "Europe/Paris")
    }

    @Test func laDistanceJerusalemTelAvivEstDEnviron54Km() {
        let d = Villes.distanceKm(31.76904, 35.21633, 32.08088, 34.78057)
        #expect(d >= 50 && d <= 58, "\(d)")
    }

    @Test func laPlusProcheEtRienAuDelaDe60Km() {
        let villes = [ville(1, "Jérusalem", "IL", 31.76904, 35.21633), ville(2, "Tel Aviv", "IL", 32.08088, 34.78057),
                      ville(3, "Paris", "FR", 48.85341, 2.3488)]
        #expect(Villes.plusProche(villes, 31.78, 35.20)?.id == 1) // Jérusalem, quartier ouest
        #expect(Villes.plusProche(villes, 32.05, 34.77)?.id == 2) // Jaffa
        #expect(Villes.plusProche(villes, 45.76, 4.84) == nil) // Lyon : Paris est à près de 400 km
    }

    // MARK: Devant la JVM

    private func vecteurs() throws -> ObjetJSON { try Depot.vecteurs("geographie_vol.json") }

    @Test func laGrilleDuGlobeSuitLaJVM() throws {
        let lignes = try vecteurs().tableau("directions") ?? []
        #expect(lignes.count == 306)
        for case .tableau(let r) in lignes {
            let lat = r.double(0), lon = r.double(1)
            let gc = DirectionJerusalem.grandCercle(lat, lon)
            #expect(abs(gc - r.double(2)) < 1e-9 && abs(DirectionJerusalem.carte(lat, lon) - r.double(3)) < 1e-9, "\(lat), \(lon)")
            #expect(abs(DirectionJerusalem.distanceKm(lat, lon) - r.double(4)) < 1e-6, "\(lat), \(lon)")
            #expect(DirectionJerusalem.degres(gc) == r.entier(5) && DirectionJerusalem.point(gc) == r.entier(6), "\(lat), \(lon)")
        }
    }

    @Test func leContourDIsraelPointParPoint() throws {
        let lignes = try vecteurs().textes("territoire")
        #expect(lignes.count == 85)
        for (i, attendu) in lignes.enumerated() {
            let lat = 29.30 + Double(i) * 0.05
            let rendu = (0...38).map { TerritoireIsrael.contient(latitude: lat, longitude: 34.10 + Double($0) * 0.05) ? "1" : "0" }.joined()
            #expect(rendu == attendu, "\(lat)")
        }
    }

    @Test func laVilleLaPlusProcheDUneGrille() throws {
        let villes = try Villes.lire(Depot.contenu("villes.json"))
        let lignes = try vecteurs().tableau("villes") ?? []
        #expect(lignes.count == 441)
        for case .tableau(let r) in lignes {
            let id = Villes.plusProche(villes, r.double(0), r.double(1))?.id ?? 0
            #expect(id == r.long(2), "\(r.double(0)), \(r.double(1))")
        }
    }
}
