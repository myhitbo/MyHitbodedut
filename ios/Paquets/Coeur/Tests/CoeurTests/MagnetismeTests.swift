import Foundation
import Testing
@testable import Coeur

/// WMM2025 : les 100 valeurs de test de la NOAA (WMM2025_TestValues.txt, copiées par l'export sous
/// Tests/Ressources), à 0,01° près pour les angles et 0,1 nT pour le champ, comme web/test/boussole.test.mjs.
@Suite("Magnétisme")
struct MagnetismeTests {

    @Test func lesCentValeursDeTestDeLaNOAA() throws {
        let texte = String(decoding: try Depot.donnees("ios/Paquets/Coeur/Tests/Ressources/vecteurs_wmm2025.txt"), as: UTF8.self)
        let lignes = texte.components(separatedBy: "\n").filter { !$0.rogne.isEmpty && !$0.hasPrefix("#") }
        #expect(lignes.count == 100)
        for l in lignes {
            let v = l.split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { Double($0) }
            try #require(v.count >= 10, "\(l)")
            let c = Magnetisme.champ(v[2], v[3], altitudeKm: v[1], annee: v[0])
            #expect(abs(c.declinaison - v[4]) <= 0.01 && abs(c.inclinaison - v[5]) <= 0.01, "\(l)")
            #expect(abs(c.x - v[7]) <= 0.1 && abs(c.y - v[8]) <= 0.1 && abs(c.z - v[9]) <= 0.1, "\(l)")
        }
        #expect(Magnetisme.anneeDecimale(millis: JourCivil.du("2026-01-01").millisUTC()) == 2026)
    }
}
