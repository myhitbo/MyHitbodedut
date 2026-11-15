import Foundation
import Testing
@testable import Coeur

/// ChizukCardTest d'Android, porté : la traduction suit la langue de l'interface.
@Suite("ChizukCard")
struct ChizukCardTests {

    private func items() throws -> [ChizukItem] {
        try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json")).items
    }

    @Test func enFrancaisLaTraductionFrancaise() throws {
        let item = try #require(try items().first)
        #expect(ChizukCarte.traduction(item, "fr") == item.fr)
    }

    @Test func enAnglaisLaTraductionAnglaise() throws {
        let item = try #require(try items().first)
        #expect(ChizukCarte.traduction(item, "en") == item.en)
    }

    @Test func enHebreuPasDeTraduction() throws {
        let item = try #require(try items().first)
        #expect(ChizukCarte.traduction(item, "he") == "")
        // « iw » est l'ancien code d'Android pour l'hébreu, encore rendu.
        #expect(ChizukCarte.traduction(item, "iw") == "")
    }

    @Test func uneLangueInconnueRetombeSurLeFrancais() throws {
        let item = try #require(try items().first)
        #expect(ChizukCarte.traduction(item, "de") == item.fr)
        #expect(ChizukCarte.traduction(item, "fr") == item.fr)
    }

    @Test func chaqueTexteASesDeuxTraductionsEtSaReference() throws {
        for item in try items() {
            #expect(!item.fr.estBlanc, "\(item.id) : pas de français")
            #expect(!item.en.estBlanc, "\(item.id) : pas d'anglais")
            #expect(!item.ref.estBlanc, "\(item.id) : pas de référence")
        }
    }
}
