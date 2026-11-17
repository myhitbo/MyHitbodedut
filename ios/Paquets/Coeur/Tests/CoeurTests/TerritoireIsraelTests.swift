import Foundation
import Testing
@testable import Coeur

/// Israël ou diaspora d'après la position (TerritoireIsraelTest d'Android, 16/10) : des villes de part
/// et d'autre des frontières, les mêmes. Puis `geo.json` (VecteursGeo.kt), rejoué en entier et à
/// l'identique : le contour que la JVM lit dans TerritoireIsrael.kt, une grille autour d'Israël au
/// cinquantième de degré, et le bord (chaque sommet, ses voisins, le milieu de chaque côté).
@Suite("TerritoireIsrael")
struct TerritoireIsraelTests {

    private let dedans: [(String, Double, Double)] = [
        ("Jérusalem", 31.7769, 35.2224), ("Tel Aviv", 32.0853, 34.7818), ("Haïfa", 32.7940, 34.9896),
        ("Eilat", 29.5577, 34.9519), ("Beer Chéva", 31.2518, 34.7913), ("Mitspé Ramon", 30.6097, 34.8019),
        ("Kiryat Chmona", 33.2073, 35.5700), ("Metoula", 33.2770, 35.5790), ("Katsrin", 32.9930, 35.6900),
        ("Ariel", 32.1060, 35.1710), ("Hébron", 31.5326, 35.0998), ("Tibériade", 32.7922, 35.5312),
        ("Nahariya", 33.0058, 35.0950), ("Ashkelon", 31.6688, 34.5743), ("Ein Gedi", 31.4500, 35.3830),
        ("Netanya", 32.3215, 34.8532), ("Akko", 32.9281, 35.0818), ("Bet Chéan", 32.4973, 35.4968),
        ("Sderot", 31.5250, 34.5966), ("Yotvata", 29.8950, 35.0600), ("Ein Zivan", 33.1060, 35.8060),
        ("Majdal Chams", 33.2700, 35.7700),
    ]
    private let dehors: [(String, Double, Double)] = [
        ("Amman", 31.9539, 35.9106), ("Aqaba", 29.5321, 35.0063), ("Beyrouth", 33.8938, 35.5018),
        ("Tyr", 33.2705, 35.2038), ("Damas", 33.5138, 36.2765), ("Le Caire", 30.0444, 31.2357),
        ("El Arich", 31.1316, 33.7984), ("Taba", 29.4900, 34.8760), ("Paris", 48.8566, 2.3522),
        ("Irbid", 32.5556, 35.8500), ("Nicosie", 35.1856, 33.3823), ("Kerak", 31.1800, 35.7000),
        ("Kuneitra", 33.1256, 35.8244),
    ]

    @Test func lesVillesDIsraelSontDedans() {
        for (nom, lat, lon) in dedans {
            let oui = TerritoireIsrael.contient(lat, lon)
            #expect(oui, "\(nom)")
        }
    }

    @Test func lesVillesVoisinesSontDehors() {
        for (nom, lat, lon) in dehors {
            let oui = TerritoireIsrael.contient(lat, lon)
            #expect(!oui, "\(nom)")
        }
    }

    // MARK: geo.json

    private struct Vecteurs: Decodable {
        struct Ligne: Decodable {
            let lat: Double
            /// « 1 » dedans, « 0 » dehors, une colonne par longitude de `territoireLongitudes`.
            let dedans: String
        }
        struct Bord: Decodable {
            let lat: Double
            let lon: Double
            let dedans: Bool
        }
        let contour: [[Double]]
        let territoireLongitudes: [Double]
        let territoire: [Ligne]
        let bords: [Bord]
        /// [impliquée, actuelle, premier lieu, déclaré, région à enregistrer, question à poser].
        struct DecisionRegion: Decodable {
            let impliquee, actuelle, premierLieu, declare: Bool
            let region, proposition: Bool?

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                impliquee = try c.decode(Bool.self)
                actuelle = try c.decode(Bool.self)
                premierLieu = try c.decode(Bool.self)
                declare = try c.decode(Bool.self)
                region = try c.decodeIfPresent(Bool.self)
                proposition = try c.decodeIfPresent(Bool.self)
            }
        }
        let decisionRegion: [DecisionRegion]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/geo.json"))
    }

    /// TerritoireIsrael.decisionRegion (audit du 16/11) : les seize combinaisons de la JVM.
    @Test func laDecisionDeRegionCommeLaJVM() throws {
        let v = try vecteurs()
        #expect(v.decisionRegion.count == 16)
        for d in v.decisionRegion {
            let r = TerritoireIsrael.decisionRegion(impliquee: d.impliquee, actuelle: d.actuelle, premierLieu: d.premierLieu,
                                                    declare: d.declare)
            #expect(r.region == d.region, "\(d)")
            #expect(r.proposition == d.proposition, "\(d)")
        }
    }

    @Test func leContourEstCeluiDuKotlin() throws {
        let v = try vecteurs()
        let contour = TerritoireIsrael.contour
        #expect(contour.count == 45)
        #expect(contour == v.contour)
    }

    @Test func laGrilleEtLeBordCommeLaJVM() throws {
        let v = try vecteurs()
        let colonnes = v.territoireLongitudes.count
        let un = UInt8(ascii: "1")
        var points = 0
        var nombreDedans = 0
        for ligne in v.territoire {
            let attendus = Array(ligne.dedans.utf8)
            #expect(attendus.count == colonnes, "ligne \(ligne.lat)")
            for (rang, lon) in v.territoireLongitudes.enumerated() where rang < attendus.count {
                let obtenu = TerritoireIsrael.contient(ligne.lat, lon)
                let attendu = attendus[rang] == un
                points += 1
                if obtenu { nombreDedans += 1 }
                #expect(obtenu == attendu, "(\(ligne.lat), \(lon))")
            }
        }
        #expect(points == 211 * 96)
        #expect(nombreDedans > 0 && nombreDedans < points, "\(nombreDedans) points dedans")
        for b in v.bords {
            let obtenu = TerritoireIsrael.contient(b.lat, b.lon)
            #expect(obtenu == b.dedans, "bord (\(b.lat), \(b.lon))")
        }
        #expect(v.bords.count == 45 * 8)
    }
}
