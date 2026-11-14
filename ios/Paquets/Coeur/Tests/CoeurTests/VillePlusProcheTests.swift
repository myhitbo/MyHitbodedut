import Foundation
import Testing
@testable import Coeur

/// La ville la plus proche d'une position (VillePlusProcheTest d'Android, 16/10) : elle nomme la
/// position et dit Israël ou diaspora. Les trois villes du test sont lues comme `villes.json`, `Ville`
/// n'ayant pas d'autre initialiseur que son décodage. Puis `geo.json` (VecteursGeo.kt), rejoué en
/// entier sur les villes de `villes.json`.
@Suite("VillePlusProche")
struct VillePlusProcheTests {

    private func villesDuTest() throws -> [Ville] {
        let json = """
        {"villes": [
          {"id": 1, "nom": {"he": "Jérusalem", "fr": "Jérusalem", "en": "Jérusalem"}, "pays": "IL",
           "latitude": 31.76904, "longitude": 35.21633, "altitude": 0, "fuseau": "Asia/Jerusalem"},
          {"id": 2, "nom": {"he": "Tel Aviv", "fr": "Tel Aviv", "en": "Tel Aviv"}, "pays": "IL",
           "latitude": 32.08088, "longitude": 34.78057, "altitude": 0, "fuseau": "Asia/Jerusalem"},
          {"id": 3, "nom": {"he": "Paris", "fr": "Paris", "en": "Paris"}, "pays": "FR",
           "latitude": 48.85341, "longitude": 2.3488, "altitude": 0, "fuseau": "Europe/Paris"}
        ]}
        """
        return try Villes.lire(Data(json.utf8))
    }

    @Test func laDistanceJerusalemTelAvivEstDEnviron54Km() {
        let d = Villes.distanceKm(31.76904, 35.21633, 32.08088, 34.78057)
        let vraisemblable = (50.0...58.0).contains(d)
        #expect(vraisemblable, "\(d)")
    }

    @Test func laPlusProcheEtRienAuDelaDe60Km() throws {
        let villes = try villesDuTest()
        let jerusalem = Villes.plusProche(villes, 31.78, 35.20)?.id // Jérusalem, quartier ouest
        #expect(jerusalem == 1)
        let jaffa = Villes.plusProche(villes, 32.05, 34.77)?.id // Jaffa
        #expect(jaffa == 2)
        let lyon = Villes.plusProche(villes, 45.76, 4.84) // Lyon : Paris est à près de 400 km
        #expect(lyon == nil)
    }

    // MARK: geo.json

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let source: String
            let villes: Int
        }
        struct Point: Decodable {
            let lat: Double
            let lon: Double
            /// La plus proche à moins de 60 km, puis la plus proche sans limite et sa distance.
            let id: Int64?
            let proche: Int64
            let km: Double
            /// De combien la deuxième ville est plus loin que la première.
            let marge: Double
        }
        struct Seuil: Decodable {
            let lat: Double
            let lon: Double
            let maxKm: Double
            let id: Int64?
            /// La distance de la plus proche.
            let km: Double
        }
        struct Distance: Decodable {
            let lat1: Double
            let lon1: Double
            let lat2: Double
            let lon2: Double
            let km: Double
        }
        let constantes: Constantes
        let villes: [Point]
        let seuils: [Seuil]
        let distances: [Distance]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/geo.json"))
    }

    /// Une égalité à 1e-6 km près, entre deux villes ou avec le seuil, n'a pas de vainqueur certain
    /// d'une bibliothèque mathématique à l'autre : ces cas-là ne jugent que la distance.
    @Test func laVilleLaPlusProcheCommeLaJVM() throws {
        let v = try vecteurs()
        let villes = try Villes.lire(Depot.contenu("villes.json"))
        #expect(villes.count == v.constantes.villes)
        #expect(Villes.source == v.constantes.source)
        #expect(v.villes.count == 663)
        var trouvees = 0
        for p in v.villes {
            let dansLeRayon = Villes.plusProche(villes, p.lat, p.lon)
            let sansLimite = Villes.plusProche(villes, p.lat, p.lon, maxKm: Double.greatestFiniteMagnitude)
            let tranche = p.marge > 1e-6
            if tranche && abs(p.km - 60) > 1e-6 {
                #expect(dansLeRayon?.id == p.id, "(\(p.lat), \(p.lon)) à moins de 60 km")
            }
            if tranche {
                #expect(sansLimite?.id == p.proche, "(\(p.lat), \(p.lon)) sans limite")
            }
            if dansLeRayon != nil { trouvees += 1 }
            let laPlusProche = try #require(sansLimite)
            let km = Villes.distanceKm(p.lat, p.lon, laPlusProche.latitude, laPlusProche.longitude)
            #expect(abs(km - p.km) <= 1e-3, "(\(p.lat), \(p.lon)) : \(km) km au lieu de \(p.km)")
        }
        #expect(trouvees > 200, "\(trouvees) points à moins de 60 km d'une ville")
    }

    @Test func leSeuilEtLaDistanceCommeLaJVM() throws {
        let v = try vecteurs()
        let villes = try Villes.lire(Depot.contenu("villes.json"))
        #expect(v.seuils.count == 48)
        for s in v.seuils where abs(s.km - s.maxKm) > 1e-6 {
            let trouvee = Villes.plusProche(villes, s.lat, s.lon, maxKm: s.maxKm)
            #expect(trouvee?.id == s.id, "(\(s.lat), \(s.lon)) à moins de \(s.maxKm) km")
        }
        #expect(v.distances.count == 13)
        for d in v.distances {
            let km = Villes.distanceKm(d.lat1, d.lon1, d.lat2, d.lon2)
            #expect(abs(km - d.km) <= 1e-3, "(\(d.lat1), \(d.lon1)) → (\(d.lat2), \(d.lon2)) : \(km) au lieu de \(d.km)")
        }
        let vide = Villes.plusProche([], 31.78, 35.20)
        #expect(vide == nil)
    }
}
