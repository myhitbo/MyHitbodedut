import Foundation
import Testing
@testable import Coeur

/// Le cap de la boussole (BoussoleActivity.kt, compagnon) : `aPlatLeHautDeLEcran` et
/// `droitLeDosDuTelephone` de RepriseBoussoleTest d'Android (le reste de ce test, la reprise de la
/// prière et le jour du tikoun, va avec Store) ; le filtre `lisser` est vérifié dans
/// DirectionJerusalemTests, comme sur Android. Puis `boussole.json` (VecteursBoussole.kt), rejoué en
/// entier : la JVM y a recopié capDevant et lisser, sous garde, BoussoleActivity n'étant pas compilé.
@Suite("Boussole")
struct BoussoleTests {

    /// La matrice Est-Nord-Haut ← téléphone de la spécification DeviceOrientation (Z·X·Y), ligne par ligne.
    private func matrice(_ alpha: Double, _ beta: Double, _ gamma: Double) -> [Float] {
        let r = Double.pi / 180
        let cA = cos(alpha * r)
        let sA = sin(alpha * r)
        let cB = cos(beta * r)
        let sB = sin(beta * r)
        let cG = cos(gamma * r)
        let sG = sin(gamma * r)
        let lignes: [Double] = [
            cA * cG - sA * sB * sG, -cB * sA, cG * sA * sB + cA * sG,
            cG * sA + cA * sB * sG, cA * cB, sA * sG - cA * cG * sB,
            -cB * sG, sB, cB * cG,
        ]
        return lignes.map { Float($0) }
    }

    private func proche(_ attendu: Double, _ mesure: Double) -> Bool {
        abs(DirectionJerusalem.ecart(attendu, mesure)) <= 0.01
    }

    @Test func aPlatLeHautDeLEcran() {
        for a in [0.0, 30.0, 90.0, 200.0, 359.0] {
            let cap = Boussole.capDevant(matrice(a, 0, 0))
            let juste = proche(360 - a, cap)
            #expect(juste, "alpha \(a) : \(cap)")
        }
    }

    @Test func droitLeDosDuTelephone() {
        let nord = Boussole.capDevant(matrice(0, 90, 0))
        let nordJuste = proche(0, nord)
        #expect(nordJuste, "\(nord)")
        let sud = Boussole.capDevant(matrice(180, 90, 0))
        let sudJuste = proche(180, sud)
        #expect(sudJuste, "\(sud)")
        // De 30° à la verticale : toujours l'est, sans saut.
        for b in [30.0, 45.0, 60.0, 80.0, 89.0, 89.9, 90.0] {
            let cap = Boussole.capDevant(matrice(270, b, 0))
            let juste = proche(90, cap)
            #expect(juste, "beta \(b) : \(cap)")
        }
    }

    // MARK: boussole.json

    private struct Vecteurs: Decodable {
        struct Rotation: Decodable {
            let alpha: Double
            let beta: Double
            let gamma: Double
            /// Les neuf Float de la matrice, en bits (`Float.toRawBits`).
            let bits: [Int32]
            let cap: Double
        }
        struct Quelconque: Decodable {
            let bits: [Int32]
            let cap: Double
        }
        struct Lisse: Decodable {
            let avant: Double?
            let mesure: Double
            let lisse: Double
        }
        let rotations: [Rotation]
        let quelconques: [Quelconque]
        let lisser: [Lisse]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/boussole.json"))
    }

    private func flottants(_ bits: [Int32]) -> [Float] {
        bits.map { Float(bitPattern: UInt32(bitPattern: $0)) }
    }

    /// Les mêmes Float qu'Android : seul atan2 peut différer, au dernier chiffre.
    @Test func lesCapsDeLaJVM() throws {
        let v = try vecteurs()
        #expect(v.rotations.count == 600)
        for c in v.rotations {
            let r = flottants(c.bits)
            let cap = Boussole.capDevant(r)
            let juste = abs(DirectionJerusalem.ecart(c.cap, cap)) <= 1e-9
            #expect(juste, "(\(c.alpha), \(c.beta), \(c.gamma)) : \(cap) au lieu de \(c.cap)")
            // La matrice du test est bien celle de la JVM, au Float près.
            let m = matrice(c.alpha, c.beta, c.gamma)
            var pire: Float = 0
            for (a, b) in zip(m, r) { pire = max(pire, abs(a - b)) }
            #expect(m.count == 9 && pire <= 1e-6, "matrice (\(c.alpha), \(c.beta), \(c.gamma)) : \(pire)")
        }
        #expect(v.quelconques.count == 114)
        for c in v.quelconques {
            let r = flottants(c.bits)
            let cap = Boussole.capDevant(r)
            let juste = abs(DirectionJerusalem.ecart(c.cap, cap)) <= 1e-9
            #expect(juste, "\(r) : \(cap) au lieu de \(c.cap)")
        }
    }

    /// Le filtre n'est que de l'arithmétique : à l'identique.
    @Test func leFiltreDeLaJVM() throws {
        let v = try vecteurs()
        #expect(v.lisser.count == 90)
        for c in v.lisser {
            let lisse = Boussole.lisser(c.avant, c.mesure)
            #expect(lisse == c.lisse, "lisser(\(String(describing: c.avant)), \(c.mesure)) : \(lisse) au lieu de \(c.lisse)")
        }
    }
}
