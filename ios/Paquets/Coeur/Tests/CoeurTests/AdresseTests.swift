import Foundation
import Testing
@testable import Coeur

/// AdresseTest d'Android, porté : צדיק / צדקת, le bravo de fin de séance et le ’hazak d'une séance annulée. Les
/// textes hébreux sont lus dans le catalogue exporté au lieu de `values-iw/strings.xml`.
@Suite("Adresse")
struct AdresseTests {

    @Test func uneCleInconnueOuVideResteSansChoix() {
        #expect(Adresse.parse("m") == .homme)
        #expect(Adresse.parse("f") == .femme)
        #expect(Adresse.parse("") == nil)
        #expect(Adresse.parse(nil) == nil)
        #expect(Adresse.parse("x") == nil)
    }

    /// Sans choix, ni « Tsadik » ni « ’Hazak » : deviner le genre se tromperait pour quelqu'un.
    @Test func chaqueFormeASesPropresMotsEtLAbsenceDeChoixResteNeutre() {
        let bravos = [Adresse.bravo(pour: .homme), Adresse.bravo(pour: .femme), Adresse.bravo(pour: nil)]
        let hazaks = [Adresse.hazak(pour: .homme), Adresse.hazak(pour: .femme), Adresse.hazak(pour: nil)]
        #expect(Set(bravos).count == 3)
        #expect(Set(hazaks).count == 3)
        #expect(Adresse.bravo(pour: nil) == "celebration_neutral")
        #expect(Adresse.hazak(pour: nil) == "annulation_neutral")
    }

    @Test func lHebreuAccordeLeMotAuGenre() throws {
        let he = try Catalogue.lire().simples("he")
        let cas = [("celebration_tsadik", "צדיק"), ("celebration_tsadeket", "צדקת"),
                   ("annulation_hazak", "חזק!"), ("annulation_hizki", "חזקי!")]
        for (cle, mot) in cas {
            let texte = he[cle] ?? ""
            #expect(texte.contientUnites(mot), "\(cle) devrait contenir « \(mot) » : \(texte)")
        }
        // Chaque clé rendue par Adresse a son libellé, dans les trois langues.
        let catalogue = try Catalogue.lire()
        let cles = Adresse.allCases.flatMap { [$0.bravo, $0.nom, $0.hazak] } + ["celebration_neutral", "annulation_neutral"]
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles { #expect(chaines[cle] != nil, "\(langue) : \(cle)") }
        }
    }
}
