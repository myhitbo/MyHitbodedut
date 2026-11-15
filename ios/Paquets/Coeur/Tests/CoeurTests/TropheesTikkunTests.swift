import Testing
@testable import Coeur

/// TropheesTikkunTest d'Android, porté : les trophées du Tikoun HaKlali (04/11), lectures complètes et jours
/// d'affilée. Rien ne reste à Android ; les vecteurs sont rejoués par TropheesTests.
@Suite("Trophées du Tikoun")
struct TropheesTikkunTests {

    private let d0 = JourCivil.du("2026-11-01")

    private func jours(_ n: Int...) -> Set<JourCivil> {
        var resultat = Set<JourCivil>()
        for i in n { resultat.insert(d0.plus(jours: i)) }
        return resultat
    }

    @Test func lesLecturesCompletesEtLaPlusLongueSuite() {
        let p = Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0, tikkun: jours(0, 1, 2, 5, 6, 9))
        let lectures = Trophees.valeur(p, .tikkun)
        #expect(lectures == 6)
        let suite = Trophees.valeur(p, .tikkunSerie)
        #expect(suite == 3)
        let cles = Set(Trophees.gagnes(p).map { $0.cle })
        let deuxieme = cles.contains("tikkun:2")
        #expect(deuxieme)
        let serie = cles.contains("tikkun_serie:1")
        #expect(serie)
    }

    @Test func sansTikounAucunDeSesTrophees() {
        let p = Trophees.Pratique(minutes: [d0: 20], notes: 0, meilleureSerie: 1)
        var aucun = true
        for n in Trophees.gagnes(p) where n.famille == .tikkun || n.famille == .tikkunSerie { aucun = false }
        #expect(aucun)
    }

    @Test func lesDatesDeGainSuiventLeJournalDuTikoun() {
        let dates = Trophees.datesGain([:], [], tikkun: jours(0, 1, 2)) { _ in false }
        let premiere = dates["tikkun:1"]
        #expect(premiere == d0)
        let deuxieme = dates["tikkun:2"]
        #expect(deuxieme == d0.plus(jours: 2))
        let serie = dates["tikkun_serie:1"]
        #expect(serie == d0.plus(jours: 2))
    }
}
