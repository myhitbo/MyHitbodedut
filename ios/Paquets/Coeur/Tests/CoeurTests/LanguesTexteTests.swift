import Foundation
import Testing
@testable import Coeur

/// LanguesTexteTest d'Android, porté : les langues d'un texte à lire (04/11), le mode par défaut, l'ordre des
/// textes et l'hébreu faute de traduction ; Tehilim traduit verset par verset, et le Tikoun qui porte la même
/// traduction.
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

    @Test func tehilimTraduitVersetParVersetDomainePublic() throws {
        let t = try Tehilim.lire(Depot.contenu("tehilim.json"))
        for n in 1...150 {
            let total = t.versets(n).count
            for l in ["fr", "en"] {
                let manquants = (1...total).filter { (t.traduction(l, psaume: n, verset: $0) ?? "").estBlanc }
                #expect(manquants.isEmpty, "\(l) \(n) : \(manquants)")
                #expect(t.traduction(l, psaume: n, verset: total + 1) == nil, "\(l) \(n)")
            }
        }
        let fr = try #require(t.traduction("fr", psaume: 23, verset: 1))
        #expect(fr.contientUnites("Éternel est mon berger"))
        let en = try #require(t.traduction("en", psaume: 23, verset: 1))
        #expect(en.contientUnites("The LORD is my shepherd"))
        let traductions = try ObjetJSON(texte: Depot.texte("tehilim.json")).objet("traductions")
        for l in ["fr", "en"] {
            #expect(traductions?.objet(l)?.objet("edition")?.texte("licence") == "Public Domain", "\(l)")
        }
    }

    @Test func leTikkunPorteLaMemeTraductionQueTehilim() throws {
        let t = try Tehilim.lire(Depot.contenu("tehilim.json"))
        let psaumes = try ObjetJSON(texte: Depot.texte("tikkun_haklali.json")).tableau("psaumes") ?? []
        #expect(psaumes.count == 10)
        for i in psaumes.indices {
            let p = try #require(psaumes.objet(i))
            let versets = p.tableau("versets") ?? []
            for k in versets.indices {
                let v = try #require(versets.objet(k))
                let numero = p.entier("numero"), n = v.entier("n")
                #expect(t.traduction("fr", psaume: numero, verset: n) == v.texte("fr"), "fr \(numero):\(n)")
                #expect(t.traduction("en", psaume: numero, verset: n) == v.texte("en"), "en \(numero):\(n)")
            }
        }
    }

    @Test func chaqueModeASonLibelleDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for mode in LanguesTexte.Mode.allCases { #expect(chaines[mode.libelle] != nil, "\(langue) : \(mode.libelle)") }
        }
    }
}
