import Foundation
import Testing
@testable import Coeur

/// DureeSeanceTest d'Android, porté : les durées demandées par le propriétaire (28/09) et le temps saisi, borné.
/// Le troisième test lit le code de trois écrans d'Android (`DureeSeance.choisir` appelé partout) : il reste à
/// Android et reviendra avec les écrans d'iOS.
@Suite("DureeSeance")
struct DureeSeanceTests {

    @Test func lesDureesDemandeesParLeProprietaire() {
        #expect(DureeSeance.proposees == [5, 10, 15, 30, 60, 90])
    }

    @Test func leTempsSaisiEstBorneEntre1Et240Minutes() {
        #expect(DureeSeance.lire(" 25 ") == 25)
        #expect(DureeSeance.lire("0") == 1)
        #expect(DureeSeance.lire("600") == 240)
        #expect(DureeSeance.lire("") == nil)
        #expect(DureeSeance.lire("vingt") == nil)
    }

    /// Ce que `toIntOrNull` de Kotlin lit et que `Int(_:)` de Swift refuse : les chiffres d'autres écritures.
    @Test func lesChiffresDesAutresEcrituresSontLusCommeSurAndroid() {
        #expect(DureeSeance.lire("٢٥") == 25)
        #expect(DureeSeance.lire("３０") == 30)
        #expect(DureeSeance.lire("\u{00A0}25\u{00A0}") == 25)
        #expect(DureeSeance.lire("2147483648") == nil)
        #expect(DureeSeance.lire("-2147483648") == 1)
    }
}
