import Testing
@testable import Coeur

/// IlanotTest d'Android, porté : Birkat haIlanot (14/10), Nissan au nord ; Eloul et Tichri au sud
/// (SiddurMoment.moisIlanotSud).
@Suite("Ilanot")
struct IlanotTests {

    private let jerusalem = 31.77
    private let melbourne = -37.81

    @Test func nissanAuNordPasAuSud() {
        let nissan = JourCivil.du("2027-04-10") // 3 Nissan 5787
        #expect(SiddurMoment.ilanot(nissan, latitude: jerusalem))
        #expect(SiddurMoment.ilanot(nissan, latitude: nil))
        #expect(!SiddurMoment.ilanot(nissan, latitude: melbourne))
    }

    @Test func eloulEtTichriAuSudPasAuNord() {
        let tichri = JourCivil.du("2026-09-20") // 9 Tichri 5787
        let eloul = JourCivil.du("2027-09-05")  // Eloul 5787
        let hechvan = JourCivil.du("2026-10-25")
        #expect(SiddurMoment.ilanot(tichri, latitude: melbourne))
        #expect(SiddurMoment.ilanot(eloul, latitude: melbourne))
        #expect(!SiddurMoment.ilanot(hechvan, latitude: melbourne))
        #expect(!SiddurMoment.ilanot(tichri, latitude: jerusalem))
    }
}
