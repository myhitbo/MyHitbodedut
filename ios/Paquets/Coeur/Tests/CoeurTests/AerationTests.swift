import Foundation
import Testing
@testable import Coeur

/// AerationTest d'Android, porté : l'aération des paragraphes (28/10), mêmes vecteurs que web/test/aeration.test.mjs.
@Suite("Aeration")
struct AerationTests {

    private let phrase = String(repeating: "אבגד ", count: 60).rogne

    @Test func premierMot() {
        #expect(Aeration.premierMot("בָּרוּךְ אַתָּה") == "<b>בָּרוּךְ</b> אַתָּה")
        #expect(Aeration.premierMot("<b>מוֹדֶה אֲנִי</b> לְפָנֶיךָ") == "<b>מוֹדֶה אֲנִי</b> לְפָנֶיךָ")
        #expect(Aeration.premierMot("<small>בשבת:</small> רְצֵה") == "<small>בשבת:</small> רְצֵה")
        #expect(Aeration.premierMot("(בעשי״ת) זָכְרֵנוּ") == "(בעשי״ת) זָכְרֵנוּ")
    }

    @Test func courtResteEntier() {
        let court = String(repeating: "א", count: 300) + ": " + String(repeating: "ב", count: 100)
        #expect(Aeration.couper(court) == court)
    }

    @Test func longCoupeHorsSmall() {
        let long = "\(phrase): \(phrase): <small>\(String(repeating: "ה", count: 260)): \(String(repeating: "ו", count: 20))</small> \(phrase)"
        let r = Aeration.couper(long)
        #expect(r.components(separatedBy: "<br><br>").count == 3)
        #expect(!ExpressionReguliere("<small>[^<]*<br><br>").presente(dans: r))
        #expect(r.remplacantUnites("<br><br>", par: " ") == long)
    }

    @Test func psaumeJamaisCoupe() {
        let verset = String(repeating: "אֱֽלֹהִ֗ים יְחׇנֵּ֥נוּ וִיבָרְכֵ֑נוּ ", count: 12).rogne
        let avecTeamim = "<b>לַמְנַצֵּ֥חַ</b> \(verset)׃ \(verset)׃ \(verset)׃"
        let visibles = ExpressionReguliere("<[^>]+>").remplace(avecTeamim, par: "").utf16.count
        #expect(visibles > Aeration.long)
        #expect(Aeration.psaume(avecTeamim))
        #expect(Aeration.couper(avecTeamim) == avecTeamim)
        let sansTeamim = "<b>מִזְמוֹר</b> לְדָוִד: \(phrase): \(phrase)"
        #expect(Aeration.psaume(sansTeamim))
        #expect(Aeration.couper(sansTeamim) == sansTeamim)
        #expect(!Aeration.psaume("\(phrase): \(phrase)"))
    }

    @Test func lesDeuxEnsemble() {
        let r = Aeration.aerer("\(phrase): \(phrase)")
        #expect(r.commenceParUnites("<b>אבגד</b>"))
        #expect(r.contientUnites(":<br><br>אבגד"))
    }
}
