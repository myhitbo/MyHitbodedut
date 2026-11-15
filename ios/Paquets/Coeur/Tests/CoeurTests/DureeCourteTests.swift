import Foundation
import Testing
@testable import Coeur

/// DureeCourteTest d'Android, porté : la durée à la place du ✓ (14/10), qui tient dans la case d'un jour.
@Suite("DureeCourte")
struct DureeCourteTests {

    @Test func formats() {
        #expect(JaugeSemaine.dureeCourte(5) == "5′")
        #expect(JaugeSemaine.dureeCourte(59) == "59′")
        #expect(JaugeSemaine.dureeCourte(60) == "1h")
        #expect(JaugeSemaine.dureeCourte(65) == "1h05")
        #expect(JaugeSemaine.dureeCourte(150) == "2h30")
    }
}
