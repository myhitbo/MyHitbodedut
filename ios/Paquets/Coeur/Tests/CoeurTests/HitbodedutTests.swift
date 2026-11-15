import Foundation
import Testing
@testable import Coeur

/// HitbodedutTest d'Android : la hitbodedout guidée, ses cinq temps, leur parcours, et le fait qu'ils sont bien ceux
/// de Likoutei Moharan II, 25 et pas une invention qui prendrait sa caution. Les trois cas qui lisent les gabarits
/// (view_hitbodedut.xml, activity_session.xml, activity_settings.xml) et HitbodedutCard.kt restent à Android ;
/// les libellés se vérifient ici dans le catalogue exporté.
@Suite("Hitbodedut")
struct HitbodedutTests {

    @Test func lesCinqTempsSontDistinctsEtComplets() throws {
        let mouvements = Hitbodedut.mouvements
        #expect(mouvements.count == 5)
        let cles = Set(mouvements.map(\.cle))
        let hebreux = Set(mouvements.map { Array($0.he.utf16) })
        let titres = Set(mouvements.map(\.titre))
        let invites = Set(mouvements.map(\.invite))
        let illustrations = Set(mouvements.map(\.illustration))
        #expect(cles.count == mouvements.count)
        #expect(hebreux.count == mouvements.count)
        #expect(titres.count == mouvements.count)
        #expect(invites.count == mouvements.count)
        for m in mouvements {
            #expect(!m.he.estBlanc, "« \(m.cle) » n'a pas d'hébreu")
            #expect(!m.illustration.isEmpty, "« \(m.cle) » n'a pas d'illustration")
            let livree = try Depot.lire("../Images/\(m.illustration).webp") != nil
            #expect(livree, "« \(m.cle) » : Images/\(m.illustration).webp absente")
            #expect(!m.source.estBlanc, "« \(m.cle) » n'a pas de source")
        }
        #expect(illustrations.count == mouvements.count)
    }

    /// Les cinq intitulés hébreux sont tirés de leur source, mot pour mot, points-voyelles compris. Ce test les fige :
    /// une reformulation qui garderait la référence sous une phrase inventée passerait sinon inaperçue.
    @Test func lesIntitulesSontCeuxDeLeursSources() {
        let attendus = [
            ("sihah", "לְפָרֵשׁ שִׂיחָתוֹ"),
            ("harata", "חֲרָטָה וּתְשׁוּבָה עַל הֶעָבָר"),
            ("bakasha", "בַּקָּשַׁת תַחֲנוּנִים"),
            ("torah", "לַעֲשׂוֹת מֵהַתּוֹרָה תְּפִלָּה"),
            ("hodaa", "נוֹתֵן שֶׁבַח וְהוֹדָיָה"),
        ]
        let cles = Hitbodedut.mouvements.map(\.cle)
        let clesAttendues = attendus.map { $0.0 }
        #expect(cles == clesAttendues)
        for (cle, he) in attendus {
            let trouve = Hitbodedut.mouvements.first { $0.cle == cle }
            #expect(trouve?.he.egalUnites(he) == true, "« \(cle) »")
        }
    }

    /// Les sources suivent la langue de l'interface (lot textes 2) : en hébreu, rien que de l'hébreu, numéros en
    /// lettres. La seconde moitié de « les intitulés sont ceux de leurs sources » d'Android.
    @Test func lesSourcesSuiventLaLangueDeLInterface() {
        let likouteiHe = Reference.localise(Hitbodedut.sourceLikoutei, "he")
        let rambamHe = Reference.localise(Hitbodedut.sourceRambam, "he")
        let likouteiEn = Reference.localise(Hitbodedut.sourceLikoutei, "en")
        let rambamEn = Reference.localise(Hitbodedut.sourceRambam, "en")
        #expect(likouteiHe.egalUnites("ליקוטי מוהר״ן תניינא, כ״ה"), "« \(likouteiHe) »")
        #expect(rambamHe.egalUnites("רמב״ם, הלכות תפילה א׳, ב׳"), "« \(rambamHe) »")
        #expect(likouteiEn == "Likutei Moharan II, 25")
        #expect(rambamEn == "Rambam, Hilchot Tefillah 1:2")
    }

    /// L'action de grâce n'est pas dans Likoutei Moharan II, 25 : elle ne doit donc pas s'en réclamer. Les quatre
    /// autres en viennent, et doivent s'en réclamer. C'est la seule façon de ne pas prêter au chapitre une caution
    /// qu'il ne donne pas.
    @Test func chaqueTempsSeReclameDeLaSourceDontIlVient() throws {
        func source(_ cle: String) throws -> String {
            let trouve = Hitbodedut.mouvements.first { $0.cle == cle }
            let m = try #require(trouve, "« \(cle) » absent")
            return m.source
        }
        for cle in ["sihah", "harata", "bakasha", "torah"] {
            let s = try source(cle)
            #expect(s == Hitbodedut.sourceLikoutei, "« \(cle) » vient du chapitre")
        }
        let hodaa = try source("hodaa")
        #expect(hodaa == Hitbodedut.sourceRambam)
    }

    /// Le Rambam place l'action de grâce après la demande, pas avant : « וְאַחַר כָּךְ נוֹתֵן שֶׁבַח וְהוֹדָיָה ».
    /// L'ordre affiché doit le suivre, sinon la référence ne tient plus.
    @Test func lActionDeGraceVientApresLaDemande() throws {
        let cles = Hitbodedut.mouvements.map(\.cle)
        let hodaa = try #require(cles.firstIndex(of: "hodaa"))
        let bakasha = try #require(cles.firstIndex(of: "bakasha"))
        #expect(hodaa > bakasha)
        #expect(Hitbodedut.estDernier(hodaa))
    }

    /// On avance, on recule, et on ne sort jamais des cinq.
    @Test func leParcoursResteDansSesBornes() {
        #expect(Hitbodedut.dernier == 4)
        #expect(Hitbodedut.suivant(0) == 1)
        #expect(Hitbodedut.suivant(3) == 4)
        #expect(Hitbodedut.suivant(4) == 4)
        #expect(Hitbodedut.suivant(99) == 4)
        #expect(Hitbodedut.precedent(1) == 0)
        #expect(Hitbodedut.precedent(0) == 0)
        #expect(Hitbodedut.precedent(-5) == 0)
        #expect(Hitbodedut.estPremier(0))
        #expect(!Hitbodedut.estPremier(1))
        #expect(Hitbodedut.estDernier(4))
        #expect(!Hitbodedut.estDernier(3))
    }

    /// Un indice aberrant rend un temps, jamais une erreur.
    @Test func unIndiceHorsBornesNeRomptPas() {
        #expect(Hitbodedut.mouvement(-1) == Hitbodedut.mouvements.first)
        #expect(Hitbodedut.mouvement(400) == Hitbodedut.mouvements.last)
        #expect(Hitbodedut.mouvement(Int.min) == Hitbodedut.mouvements.first)
        #expect(Hitbodedut.mouvement(Int.max) == Hitbodedut.mouvements.last)
    }

    @Test func lesLibellesExistentDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        var cles = ["settings_hitbodedut", "settings_hitbodedut_hint", "hitbodedut_step", "hitbodedut_previous",
                    "hitbodedut_next"]
        for m in Hitbodedut.mouvements { cles += [m.titre, m.invite] }
        #expect(cles.count == 15)
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                let present = !(chaines[cle] ?? "").estBlanc
                #expect(present, "\(langue) : « \(cle) » manquant")
            }
        }
    }
}
