import Testing
@testable import Ecrans

/// Les marges des grands écrans (values-w600dp, -w840dp, -w1200dp de dimens.xml), le Jour couché en deux colonnes
/// (layout-land/activity_main.xml), et les deux colonnes de l'iPad.
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

    @Test func laPlaceEstLaLargeurMoinsLesBords() {
        #expect(GrandEcran.place(largeur: 402) == 370)
        #expect(GrandEcran.place(largeur: 744) == 648)
        #expect(GrandEcran.place(largeur: 1032) == 792)
        #expect(GrandEcran.place(largeur: 1376) == 736)
        #expect(GrandEcran.place(largeur: 1210) == 570)
        #expect(GrandEcran.place(largeur: 0) == 0)
    }

    @Test func lIPadSeMetEnDeuxColonnesQuandLaPlaceLePermet() {
        // L'iPad 13 pouces debout puis couché, l'iPad Air 11 pouces debout : deux colonnes.
        #expect(GrandEcran.deuxColonnes(place: GrandEcran.place(largeur: 1032)))
        #expect(GrandEcran.deuxColonnes(place: GrandEcran.place(largeur: 1376)))
        #expect(GrandEcran.deuxColonnes(place: GrandEcran.place(largeur: 820)))
        // L'iPhone debout, l'iPad mini debout, l'iPad Pro 11 pouces couché (la marge de w1200dp) : une colonne.
        #expect(!GrandEcran.deuxColonnes(place: GrandEcran.place(largeur: 440)))
        #expect(!GrandEcran.deuxColonnes(place: GrandEcran.place(largeur: 744)))
        #expect(!GrandEcran.deuxColonnes(place: GrandEcran.place(largeur: 1210)))
        #expect(GrandEcran.deuxColonnes(place: 700))
        #expect(!GrandEcran.deuxColonnes(place: 699))
    }

    @Test func uneColonneAuxTaillesDAccessibiliteEtSurUnTelephoneCouche() {
        #expect(!GrandEcran.deuxColonnes(place: 792, texteAccessible: true))
        // Un iPhone Pro Max couché : 736 points de place, mais la hauteur compacte d'un téléphone.
        #expect(!GrandEcran.deuxColonnes(place: 736, hauteurCompacte: true))
    }

    @Test func leJourSeMetEnDeuxColonnesCoucheOuSurLIPad() {
        // Un iPad 13 pouces couché, puis debout ; un iPhone couché (874 × 402), puis debout.
        #expect(GrandEcran.deuxColonnes(largeur: 1376, hauteur: 1032))
        #expect(GrandEcran.deuxColonnes(largeur: 1032, hauteur: 1376))
        #expect(GrandEcran.deuxColonnes(largeur: 874, hauteur: 402))
        #expect(!GrandEcran.deuxColonnes(largeur: 402, hauteur: 874))
        // L'iPad mini debout : une colonne ; l'iPad debout aux tailles d'accessibilité aussi, mais couché, deux,
        // comme le téléphone couché (layout-land ne regarde que l'orientation).
        #expect(!GrandEcran.deuxColonnes(largeur: 744, hauteur: 1133))
        #expect(!GrandEcran.deuxColonnes(largeur: 1032, hauteur: 1376, texteAccessible: true))
        #expect(GrandEcran.deuxColonnes(largeur: 1376, hauteur: 1032, texteAccessible: true))
    }
}
