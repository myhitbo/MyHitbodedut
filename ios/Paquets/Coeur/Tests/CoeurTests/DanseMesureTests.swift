import Foundation
import Testing
@testable import Coeur

/// DanseMesureTest d'Android, porté : la danse du bravo, deux pas qui s'enchaînent sans à-coup. Le test qui lit le
/// layout et l'écran de la célébration d'Android y reste (tâche 16).
@Suite("DanseMesure")
struct DanseMesureTests {

    private let instants = (0...400).map { Float($0) / 400 }

    @Test func chaqueValeurResteDansSesBornes() {
        for t in instants {
            let pas = DanseMesure.pas(t)
            #expect(pas.hauteur >= 0 && pas.hauteur <= 1, "\(t)")
            #expect(pas.flexion >= 0 && pas.flexion <= 1, "\(t)")
            #expect(pas.balance >= -1 && pas.balance <= 1, "\(t)")
            #expect(pas.poseB >= 0 && pas.poseB <= 1, "\(t)")
        }
    }

    /// Aucun saut d'image : la boucle, et le passage d'un temps à l'autre, sont continus.
    @Test func leMouvementEstContinuBoucleComprise() {
        let tous = instants + [1]
        for (a, b) in zip(tous, tous.dropFirst()) {
            let x = DanseMesure.pas(a), y = DanseMesure.pas(b)
            #expect(abs(x.hauteur - y.hauteur) < 0.05, "hauteur à \(a)")
            #expect(abs(x.balance - y.balance) < 0.05, "balance à \(a)")
            // Le relais des poses est bref (un dixième de temps) : continu, simplement plus raide.
            #expect(abs(x.poseB - y.poseB) < 0.3, "pose à \(a)")
        }
    }

    @Test func ilChangeDeJambeAChaqueTempsEtToucheLeSolEnChangeant() {
        #expect(abs(DanseMesure.pas(0.2).poseB - 0) <= 0.001)
        #expect(abs(DanseMesure.pas(0.7).poseB - 1) <= 0.001)
        #expect(abs(DanseMesure.pas(0).hauteur - 0) <= 0.001)
        #expect(abs(DanseMesure.pas(0.5).hauteur - 0) <= 0.001)
        #expect(abs(DanseMesure.pas(0.25).hauteur - 1) <= 0.001)
        #expect(abs(DanseMesure.pas(0.5).flexion - 1) <= 0.001)
    }
}
