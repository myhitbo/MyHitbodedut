import Testing
@testable import Ecrans

/// Les marges des grands écrans (values-w600dp, -w840dp, -w1200dp de dimens.xml) et le Jour couché en deux colonnes
/// (layout-land/activity_main.xml).
@Suite("Grands écrans")
struct GrandEcranTests {

    @Test func lesBordsSuiventLesLargeursDAndroid() {
        #expect(GrandEcran.bord(largeur: 390) == 16)
        #expect(GrandEcran.bord(largeur: 599) == 16)
        #expect(GrandEcran.bord(largeur: 600) == 48)
        #expect(GrandEcran.bord(largeur: 839) == 48)
        #expect(GrandEcran.bord(largeur: 840) == 120)
        #expect(GrandEcran.bord(largeur: 1200) == 320)
    }

    @Test func laRacineAjouteLeWideGutter() {
        // wide_gutter d'Android : 0, 32, 104, 304.
        #expect(GrandEcran.marge(largeur: 402) == 0)
        #expect(GrandEcran.marge(largeur: 744) == 32)
        #expect(GrandEcran.marge(largeur: 1032) == 104)
        #expect(GrandEcran.marge(largeur: 1376) == 304)
    }

    @Test func leJourSeMetEnDeuxColonnesCoucheSeulement() {
        // Un iPad 13 pouces couché, puis debout ; un iPhone couché (874 × 402), puis debout.
        #expect(GrandEcran.deuxColonnes(largeur: 1376, hauteur: 1032))
        #expect(!GrandEcran.deuxColonnes(largeur: 1032, hauteur: 1376))
        #expect(GrandEcran.deuxColonnes(largeur: 874, hauteur: 402))
        #expect(!GrandEcran.deuxColonnes(largeur: 402, hauteur: 874))
    }
}
