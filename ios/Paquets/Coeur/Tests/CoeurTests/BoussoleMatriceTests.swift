import Foundation
import Testing
@testable import Coeur

/// La matrice de la boussole d'après la gravité et le champ (SensorManager.getRotationMatrix et
/// remapCoordinateSystem, branche accéléromètre + magnétomètre de BoussoleActivity.onSensorChanged) : une
/// orientation connue du téléphone donne, dans ses axes, la gravité et le champ terrestre ; la matrice qu'on en
/// tire doit être celle de l'orientation, et le cap celui que donne `capDevant`.
@Suite("Boussole : matrice")
struct BoussoleMatriceTests {

    /// La matrice Est-Nord-Haut ← téléphone de la spécification DeviceOrientation (Z·X·Y), comme BoussoleTests.
    private func matrice(_ alpha: Double, _ beta: Double, _ gamma: Double) -> [Double] {
        let r = Double.pi / 180
        let cA = cos(alpha * r), sA = sin(alpha * r)
        let cB = cos(beta * r), sB = sin(beta * r)
        let cG = cos(gamma * r), sG = sin(gamma * r)
        return [
            cA * cG - sA * sB * sG, -cB * sA, cG * sA * sB + cA * sG,
            cG * sA + cA * sB * sG, cA * cB, sA * sG - cA * cG * sB,
            -cB * sG, sB, cB * cG,
        ]
    }

    /// Un vecteur du repère Est-Nord-Haut dans les axes du téléphone : la transposée de la matrice.
    private func dansLeTelephone(_ r: [Double], _ v: [Double]) -> [Double] {
        (0..<3).map { colonne in (0..<3).reduce(0) { $0 + r[$1 * 3 + colonne] * v[$1] } }
    }

    /// Le champ terrestre en France, à peu près : 21 µT vers le nord, 43 µT vers le bas.
    private let champTerrestre = [0.0, 21, -43]

    @Test func aPlatLeHautVersLeNord() throws {
        let r = try #require(Boussole.matriceRotation(gravite: [0, 0, 9.81], champ: [0, 21, -43]))
        let attendue: [Float] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
        for (a, b) in zip(r, attendue) { #expect(abs(a - b) < 1e-5) }
        #expect(abs(DirectionJerusalem.ecart(0, Boussole.capDevant(r))) < 1e-3)
    }

    @Test func retrouveLOrientation() throws {
        for (alpha, beta, gamma) in [(0.0, 0.0, 0.0), (30, 10, -5), (200, 80, 0), (300, 45, 20), (90, -30, 60)] {
            let r = matrice(alpha, beta, gamma)
            let gravite = dansLeTelephone(r, [0, 0, 9.81]).map { Float($0) }
            let champ = dansLeTelephone(r, champTerrestre).map { Float($0) }
            let tiree = try #require(Boussole.matriceRotation(gravite: gravite, champ: champ))
            for (a, b) in zip(tiree, r) {
                #expect(abs(Double(a) - b) < 1e-4, "(\(alpha), \(beta), \(gamma))")
            }
        }
    }

    @Test func coreMotionLaGraviteVersLeSol() throws {
        // Téléphone tenu droit face à l'est : CoreMotion dit la gravité vers le bas de l'écran, en g.
        let r = matrice(270, 90, 0)
        let graviteCoreMotion = dansLeTelephone(r, [0, 0, -1])
        let champ = dansLeTelephone(r, champTerrestre)
        let tiree = try #require(Boussole.matriceCoreMotion(gravite: graviteCoreMotion, champ: champ))
        // Droit, le dos du téléphone regarde vers l'est : 90° (bug du 02/11, capDevant).
        #expect(abs(DirectionJerusalem.ecart(90, Boussole.capDevant(tiree))) < 0.01)
    }

    @Test func chuteLibreEtPoleMagnetique() {
        #expect(Boussole.matriceRotation(gravite: [0, 0, 0.5], champ: [0, 21, -43]) == nil)
        // Un champ parallèle à la gravité ne dit pas où est le nord.
        #expect(Boussole.matriceRotation(gravite: [0, 0, 9.81], champ: [0, 0, -50]) == nil)
        #expect(Boussole.matriceRotation(gravite: [0, 9.81], champ: [0, 21, -43]) == nil)
    }

    @Test func leHautDeLEcranEnPaysage() throws {
        // À plat, le haut du téléphone vers le nord. Écran tourné d'un quart de tour (ROTATION_90 : le haut du
        // téléphone à gauche), le haut de l'écran est le bord droit du téléphone : l'est, 90°.
        let r = try #require(Boussole.matriceRotation(gravite: [0, 0, 9.81], champ: [0, 21, -43]))
        #expect(abs(DirectionJerusalem.ecart(0, Boussole.capDevant(Boussole.remapper(r, rotation: 0)))) < 1e-3)
        #expect(abs(DirectionJerusalem.ecart(90, Boussole.capDevant(Boussole.remapper(r, rotation: 1)))) < 1e-3)
        #expect(abs(DirectionJerusalem.ecart(180, Boussole.capDevant(Boussole.remapper(r, rotation: 2)))) < 1e-3)
        #expect(abs(DirectionJerusalem.ecart(270, Boussole.capDevant(Boussole.remapper(r, rotation: 3)))) < 1e-3)
        // Le z de l'écran reste celui du téléphone.
        let paysage = Boussole.remapper(r, rotation: 1)
        #expect(paysage[2] == r[2] && paysage[5] == r[5] && paysage[8] == r[8])
        #expect(Boussole.remapper(r, rotation: 4) == r)
        #expect(Boussole.remapper([1, 2], rotation: 1) == [1, 2])
    }
}
