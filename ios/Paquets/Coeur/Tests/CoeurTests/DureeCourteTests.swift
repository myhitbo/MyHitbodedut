import Testing
@testable import Coeur

/// DureeCourteTest d'Android, porté : la durée à la place du ✓ (14/10) tient dans la case d'un jour. Les
/// durées que la JVM écrit dans `Tests/Vecteurs/jauge_semaine.json` sont rejouées par JaugeSemaineTests.
/// Rien ne reste à Android.
@Suite("Durée courte")
struct DureeCourteTests {

    /// Le signe des minutes est le prime, U+2032, comme dans JaugeSemaine.kt.
    @Test func formats() {
        let cinq = JaugeSemaine.dureeCourte(5)
        #expect(cinq == "5\u{2032}")
        let cinquanteNeuf = JaugeSemaine.dureeCourte(59)
        #expect(cinquanteNeuf == "59\u{2032}")
        let uneHeure = JaugeSemaine.dureeCourte(60)
        #expect(uneHeure == "1h")
        let uneHeureCinq = JaugeSemaine.dureeCourte(65)
        #expect(uneHeureCinq == "1h05")
        let deuxHeuresEtDemie = JaugeSemaine.dureeCourte(150)
        #expect(deuxHeuresEtDemie == "2h30")
    }
}
