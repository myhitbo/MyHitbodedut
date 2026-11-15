import Foundation
import Testing
@testable import Coeur

/// ReminderRuleTest d'Android, porté : le calendrier raisonne en date civile, la fête commence au coucher du soleil.
/// Sans ville réglée, on ne calcule aucun coucher : la veille d'un jour chômé, plus aucun rappel après midi.
@Suite("ReminderRule")
struct ReminderRuleTests {

    private func h(_ heure: Int) -> Int { heure * 60 }

    @Test func jourOrdinaireLeRappelPasse() {
        #expect(ReminderRule.doitSonner(maintenant: h(19), faite: false, repos: false, veilleDeRepos: false, coucher: nil))
    }

    @Test func pratiqueDejaFaitePasDeRappel() {
        #expect(!ReminderRule.doitSonner(maintenant: h(7), faite: true, repos: false, veilleDeRepos: false, coucher: nil))
    }

    @Test func jourChomePasDeRappel() {
        #expect(!ReminderRule.doitSonner(maintenant: h(7), faite: false, repos: true, veilleDeRepos: false, coucher: nil))
    }

    @Test func veilleDeFeteSansVilleRienApresMidi() {
        #expect(ReminderRule.doitSonner(maintenant: h(11), faite: false, repos: false, veilleDeRepos: true, coucher: nil))
        #expect(!ReminderRule.doitSonner(maintenant: h(12), faite: false, repos: false, veilleDeRepos: true, coucher: nil))
        #expect(!ReminderRule.doitSonner(maintenant: h(19), faite: false, repos: false, veilleDeRepos: true, coucher: nil))
    }

    @Test func veilleDeFeteAvecVilleLeCoucherDuSoleilFaitFoi() {
        let coucher = 18 * 60 + 40
        #expect(ReminderRule.doitSonner(maintenant: h(17), faite: false, repos: false, veilleDeRepos: true, coucher: coucher))
        #expect(!ReminderRule.doitSonner(maintenant: coucher, faite: false, repos: false, veilleDeRepos: true, coucher: coucher))
    }
}
