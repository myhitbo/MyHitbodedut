import Testing
@testable import Coeur

/// Les bugs du 02/11 (RepriseBoussoleTest.kt) : la prière du matin qui reprenait le lendemain là où on
/// s'était arrêté la veille (Store.repriseValable), et le jour du Tikoun qui basculait à minuit
/// (Store.jourTikkun). Les deux cas de la boussole téléphone droit (BoussoleActivity.capDevant) sont portés
/// avec la boussole (BoussoleTests).
@Suite("Reprise de lecture et Tikoun")
struct RepriseBoussoleTests {

    private let t0: Int64 = 1_793_000_000_000

    @Test func priereReprendSeulementApresUneInterruption() {
        let apresVingtMinutes = Store.repriseValable("s:chaharit", quand: t0, maintenant: t0 + 20 * 60_000)
        #expect(apresVingtMinutes)
        let apresTroisHeures = Store.repriseValable("s:chaharit", quand: t0, maintenant: t0 + Store.priereRepriseMs)
        #expect(!apresTroisHeures)
        let leLendemain = Store.repriseValable("s:chaharit", quand: t0, maintenant: t0 + 24 * 3_600_000)
        #expect(!leLendemain)
        // Place enregistrée avant la correction, sans heure : au début.
        let sansHeure = Store.repriseValable("s:chaharit", quand: 0, maintenant: t0)
        #expect(!sansHeure)
    }

    @Test func livreReprendToujours() {
        let dixJoursApres = Store.repriseValable("l:likoutei_etsot", quand: t0, maintenant: t0 + 10 * 24 * 3_600_000)
        #expect(dixJoursApres)
        let sansHeure = Store.repriseValable("l:likoutei_etsot", quand: 0, maintenant: t0)
        #expect(sansHeure)
    }

    @Test func tikounBasculeAQuatreHeures() {
        let t = DateHeure(JourCivil.du("2026-11-01"), heure: 23, minute: 45)
        let leSoir = Store.jourTikkun(t).iso
        #expect(leSoir == "2026-11-01")
        let apresMinuit = Store.jourTikkun(t.plus(minutes: 20)).iso
        #expect(apresMinuit == "2026-11-01")
        let avantQuatreHeures = Store.jourTikkun(DateHeure(JourCivil.du("2026-11-02"), heure: 3, minute: 59)).iso
        #expect(avantQuatreHeures == "2026-11-01")
        let leMatin = Store.jourTikkun(DateHeure(JourCivil.du("2026-11-02"), heure: 9, minute: 0)).iso
        #expect(leMatin == "2026-11-02")
    }
}
