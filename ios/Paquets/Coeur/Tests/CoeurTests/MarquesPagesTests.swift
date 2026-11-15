import Foundation
import Testing
@testable import Coeur

/// MarquesPagesTest d'Android, porté : les marque-pages (15/10), une place précise dans un texte.
@Suite("MarquesPages")
struct MarquesPagesTests {

    private let a = MarquesPages.Marque("s:chaharit", "edot", 3, 12, "ברוך שאמר")
    private let b = MarquesPages.Marque("s:chaharit", "edot", 1, 4, "הודו ליהוה")

    @Test func poserPuisRetirerLaMemePlace() {
        let une = MarquesPages.basculer([], a)
        #expect(une == [a])
        #expect(MarquesPages.basculer(une, a.avec(apercu: "autre")).isEmpty)
    }

    @Test func allerRetourParLeTexteEnregistre() {
        let l = [a, b, MarquesPages.Marque("l:likoutei_etsot", "", 0, 0, "אמת")]
        #expect(MarquesPages.decoder(MarquesPages.encoder(l)) == l)
        #expect(MarquesPages.decoder(nil).isEmpty)
    }

    @Test func cellesDuTexteDansLOrdreDuTexteEtPasDUnAutreNoussah() {
        let l = [a, b, a.avec(nusah: "sefard")]
        #expect(MarquesPages.duTexte(l, cle: "s:chaharit", nusah: "edot") == [b, a])
    }

    @Test func apercuSansVoyellesNiBalises() {
        #expect(MarquesPages.apercu("<b>בָּרוּךְ</b> שֶׁאָמַר וְהָיָה הָעוֹלָם", mots: 4) == "ברוך שאמר והיה העולם")
    }

    @Test func laListeNeGrossitPasSansFin() {
        var l: [MarquesPages.Marque] = []
        for k in 0..<(MarquesPages.maximum + 5) { l = MarquesPages.basculer(l, a.avec(bloc: k)) }
        #expect(l.count == MarquesPages.maximum)
        #expect(l.first?.bloc == MarquesPages.maximum + 4)
    }
}
