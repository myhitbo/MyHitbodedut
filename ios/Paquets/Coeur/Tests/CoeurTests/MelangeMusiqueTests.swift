import Foundation
import Testing
@testable import Coeur

/// MelangeMusiqueTest d'Android, porté : la lecture aléatoire (28/09), tout, dans un ordre au hasard, sans
/// répétition, avec le hasard de Kotlin pour les mêmes graines. Les deux tests qui lisent le service, le lecteur et
/// le layout de la musique d'Android y restent (tâche 18).
@Suite("MelangeMusique")
struct MelangeMusiqueTests {

    private let ids = (1...12).map { $0 < 10 ? "niggoun_0\($0)" : "niggoun_\($0)" }

    private func melange(_ graine: Int32) -> MelangeMusique { MelangeMusique(hasard: HasardKotlin(graine: graine)) }

    @Test func aucunMorceauNeRevientAvantQueTousAientJoue() {
        var m = melange(7)
        for _ in 0..<5 {
            let tour = ids.map { _ in m.suivant(ids) ?? "" }
            #expect(Set(tour) == Set(ids), "un tour doit tout jouer une fois")
        }
    }

    @Test func jamaisDeuxFoisDeSuiteLeMemeMorceau() {
        for graine: Int32 in 1...50 {
            var m = melange(graine)
            let suite = (0..<(ids.count * 6)).map { _ in m.suivant(ids) ?? "" }
            let doubles = zip(suite, suite.dropFirst()).filter { paire in paire.0 == paire.1 }
            #expect(doubles.isEmpty, "graine \(graine)")
        }
    }

    @Test func lOrdreChangeDUnTourALAutre() {
        var m = melange(3)
        let premier = ids.map { _ in m.suivant(ids) ?? "" }
        let second = ids.map { _ in m.suivant(ids) ?? "" }
        #expect(premier != second)
    }

    @Test func unMorceauRetireNeSortPlusEtUneBibliothequeVideNeJoueRien() {
        var m = melange(1)
        _ = m.suivant(ids)
        let restants = Array(ids.dropFirst(6))
        for _ in 0..<20 {
            let suivant = m.suivant(restants) ?? ""
            #expect(restants.contains(suivant))
        }
        #expect(m.suivant([]) == nil)
        var seul = MelangeMusique()
        #expect(seul.suivant(["seul"]) == "seul")
    }
}
