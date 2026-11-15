import Foundation
import Testing
@testable import Coeur

/// TropheesTikkunTest d'Android, porté : les trophées du Tikoun HaKlali (04/11), lectures complètes et jours d'affilée.
@Suite("TropheesTikkun")
struct TropheesTikkunTests {

    private let d0 = JourCivil.du("2026-11-01")

    private func jours(_ n: Int...) -> Set<JourCivil> { Set(n.map { d0.plus(jours: $0) }) }

    @Test func lesLecturesCompletesEtLaPlusLongueSuite() {
        let p = Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0, tikkun: jours(0, 1, 2, 5, 6, 9))
        #expect(Trophees.valeur(p, .tikkun) == 6)
        #expect(Trophees.valeur(p, .tikkunSerie) == 3)
        let cles = Set(Trophees.gagnes(p).map { $0.cle })
        #expect(cles.contains("tikkun:2"))
        #expect(cles.contains("tikkun_serie:1"))
    }

    @Test func sansTikounAucunDeSesTrophees() {
        let p = Trophees.Pratique(minutes: [d0: 20], notes: 0, meilleureSerie: 1)
        let duTikoun = Trophees.gagnes(p).filter { $0.famille == .tikkun || $0.famille == .tikkunSerie }
        #expect(duTikoun.isEmpty)
    }

    @Test func lesDatesDeGainSuiventLeJournalDuTikoun() {
        let dates = Trophees.datesGain([:], notes: [], tikkun: jours(0, 1, 2)) { _ in false }
        #expect(dates["tikkun:1"] == d0)
        #expect(dates["tikkun:2"] == d0.plus(jours: 2))
        #expect(dates["tikkun_serie:1"] == d0.plus(jours: 2))
    }
}
