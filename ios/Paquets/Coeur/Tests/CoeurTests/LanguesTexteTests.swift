import Foundation
import Testing
@testable import Coeur

/// LanguesTexteTest d'Android, porté : les langues d'un texte à lire (04/11), le mode par défaut, l'ordre des
/// textes et l'hébreu faute de traduction.
@Suite("LanguesTexte")
struct LanguesTexteTests {

    @Test func parDefautLaRegleDAvant() {
        #expect(LanguesTexte.defaut("he") == .he)
        #expect(LanguesTexte.defaut("iw") == .he)
        #expect(LanguesTexte.defaut("fr") == .heFr)
        #expect(LanguesTexte.defaut("en") == .heEn)
    }

    @Test func lesTextesDansLOrdreDuModeLHebreuFauteDeTraduction() {
        #expect(LanguesTexte.textes(.frEn, he: "אחד", fr: "un", en: "one") == [LanguesTexte.Texte("fr", "un"), LanguesTexte.Texte("en", "one")])
        #expect(LanguesTexte.textes(.fr, he: "אחד", fr: nil, en: "one") == [LanguesTexte.Texte("he", "אחד")])
        #expect(LanguesTexte.textes(.heEn, he: "אחד", fr: "un", en: "one") == [LanguesTexte.Texte("he", "אחד"), LanguesTexte.Texte("en", "one")])
        #expect(LanguesTexte.manque(.heFr, aTraduction: false))
        #expect(!LanguesTexte.manque(.he, aTraduction: false))
    }

    @Test func chaqueModeASonLibelleDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for mode in LanguesTexte.Mode.allCases { #expect(chaines[mode.libelle] != nil, "\(langue) : \(mode.libelle)") }
        }
    }
}
