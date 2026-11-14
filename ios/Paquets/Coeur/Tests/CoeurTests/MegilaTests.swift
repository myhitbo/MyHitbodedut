import Testing
@testable import Coeur

/// MegilaTest d'Android, porté : la Méguila d'Esther dans le siddour (13/10, SiddurMoment.megila), sous
/// Arvit la nuit qui ouvre Pourim, sous Cha'harit le jour ; le 15 Adar dans une ville murée, le vendredi
/// 14 quand le 15 est un Chabbat (Pourim mechoulach, 5785).
@Suite("Méguila")
struct MegilaTests {

    private func megila(_ moment: String, _ date: String, _ muree: Bool) -> Bool {
        SiddurMoment.megila(moment, .du(date), israel: false, mukafChoma: muree)
    }

    @Test func villeOuverte14AdarII5787() {
        #expect(megila("arvit", "2027-03-22", false))
        #expect(megila("chaharit", "2027-03-23", false))
        #expect(!megila("minha", "2027-03-23", false))
        #expect(!megila("chaharit", "2027-03-24", false))
        #expect(!megila("arvit", "2027-03-23", false))
    }

    @Test func villeMuree15AdarII5787() {
        #expect(!megila("chaharit", "2027-03-23", true))
        #expect(megila("arvit", "2027-03-23", true))
        #expect(megila("chaharit", "2027-03-24", true))
    }

    @Test func pourimMechoulach5785VilleMureeLeVendredi14() {
        #expect(megila("arvit", "2025-03-13", true))
        #expect(megila("chaharit", "2025-03-14", true))
        #expect(!megila("chaharit", "2025-03-15", true))
        #expect(megila("chaharit", "2025-03-14", false))
    }
}
