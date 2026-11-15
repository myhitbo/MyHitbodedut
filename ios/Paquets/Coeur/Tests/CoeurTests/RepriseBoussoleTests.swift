import Foundation
import Testing
@testable import Coeur

/// RepriseBoussoleTest d'Android, porté : les deux bugs du 02/11, la boussole qui s'affole téléphone droit, et la
/// prière du matin qui reprenait le lendemain là où on s'était arrêté la veille ; le jour du Tikoun bascule à 4 h.
@Suite("RepriseBoussole")
struct RepriseBoussoleTests {

    /// La matrice Est-Nord-Haut ← téléphone de la spécification DeviceOrientation (Z·X·Y), ligne par ligne.
    private func matrice(_ alpha: Double, _ beta: Double, _ gamma: Double) -> [Float] {
        let r = Double.pi / 180
        let (cA, sA) = (cos(alpha * r), sin(alpha * r))
        let (cB, sB) = (cos(beta * r), sin(beta * r))
        let (cG, sG) = (cos(gamma * r), sin(gamma * r))
        return [
            Float(cA * cG - sA * sB * sG), Float(-cB * sA), Float(cG * sA * sB + cA * sG),
            Float(cG * sA + cA * sB * sG), Float(cA * cB), Float(sA * sG - cA * cG * sB),
            Float(-cB * sG), Float(sB), Float(cB * cG),
        ]
    }

    private func proche(_ attendu: Double, _ mesure: Double) -> Bool {
        abs(DirectionJerusalem.ecart(attendu, mesure)) <= 0.01
    }

    @Test func aPlatLeHautDeLEcran() {
        for a in [0.0, 30.0, 90.0, 200.0, 359.0] {
            let cap = Boussole.capDevant(matrice(a, 0, 0))
            #expect(proche(360 - a, cap), "alpha \(a) : \(cap)")
        }
    }

    @Test func droitLeDosDuTelephone() {
        let nord = Boussole.capDevant(matrice(0, 90, 0))
        #expect(proche(0, nord))
        let sud = Boussole.capDevant(matrice(180, 90, 0))
        #expect(proche(180, sud))
        // De 30° à la verticale : toujours l'est, sans saut.
        for b in [30.0, 45.0, 60.0, 80.0, 89.0, 89.9, 90.0] {
            let cap = Boussole.capDevant(matrice(270, b, 0))
            #expect(proche(90, cap), "beta \(b) : \(cap)")
        }
    }

    @Test func priereReprendSeulementApresUneInterruption() {
        let t0: Int64 = 1_793_000_000_000
        #expect(Pratique.repriseValable("s:chaharit", quand: t0, maintenant: t0 + 20 * 60_000))
        #expect(!Pratique.repriseValable("s:chaharit", quand: t0, maintenant: t0 + Pratique.priereRepriseMillis))
        #expect(!Pratique.repriseValable("s:chaharit", quand: t0, maintenant: t0 + 24 * 3_600_000))
        // Place enregistrée avant la correction, sans heure : au début.
        #expect(!Pratique.repriseValable("s:chaharit", quand: 0, maintenant: t0))
    }

    @Test func livreReprendToujours() {
        let t0: Int64 = 1_793_000_000_000
        #expect(Pratique.repriseValable("l:likoutei_etsot", quand: t0, maintenant: t0 + 10 * 24 * 3_600_000))
        #expect(Pratique.repriseValable("l:likoutei_etsot", quand: 0, maintenant: t0))
    }

    @Test func tikounBasculeAQuatreHeures() {
        let t = DateHeure(.du("2026-11-01"), heure: 23, minute: 45)
        #expect(Pratique.jourTikkun(t) == "2026-11-01")
        #expect(Pratique.jourTikkun(t.plus(minutes: 20)) == "2026-11-01")
        #expect(Pratique.jourTikkun(DateHeure(.du("2026-11-02"), heure: 3, minute: 59)) == "2026-11-01")
        #expect(Pratique.jourTikkun(DateHeure(.du("2026-11-02"), heure: 9)) == "2026-11-02")
    }

    /// Le filtre de la boussole va par le plus court côté du cercle.
    @Test func leLissageVaParLePlusCourtCote() {
        #expect(Boussole.lisser(nil, 42) == 42)
        let franchi = Boussole.lisser(350, 10)
        #expect(abs(franchi - 354) < 1e-9)
    }
}
