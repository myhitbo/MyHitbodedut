import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le balisage des blocs (LectureBalisage) : ce que `Html.fromHtml(…, FROM_HTML_MODE_LEGACY)` puis
/// `premierMotAgrandi` d'Android font d'un bloc, et les paragraphes d'un bloc ou d'un titre selon les langues de
/// lecture (onBindViewHolder de SiddurLectureActivity). Le rendu des tailles et des couleurs reste à la vue.
@Suite("Balisage de la lecture")
@MainActor
struct LectureBalisageTests {

    private func textes(_ s: [LectureSegment]) -> [String] {
        s.map { $0.texte }
    }

    @Test func lesBlancsSeReduisentAUneEspace() {
        let s = LectureBalisage.segments("  א \n  ב  ", agrandir: false, police: .sans)
        let t = textes(s).joined()
        #expect(t == "א ב ")
    }

    @Test func leGrasDeTeteEstAgranditDUnQuart() {
        let s = LectureBalisage.segments("<b>א</b> ב", agrandir: true, police: .sans)
        #expect(s.count == 2)
        let premier = s[0]
        #expect(premier.texte == "א")
        #expect(premier.gras)
        #expect(premier.taille == 1.25)
        let second = s[1]
        #expect(second.texte == " ב")
        #expect(!second.gras)
        #expect(second.taille == 1)
    }

    @Test func uneConsigneNestPasAgrandie() {
        let s = LectureBalisage.segments("<b>א</b> ב", agrandir: false, police: .sans)
        let tailles = s.map { $0.taille }
        #expect(tailles == [1, 1])
    }

    @Test func unGrasPlusLoinNestPasAgrandi() {
        let s = LectureBalisage.segments("א <b>ב</b>", agrandir: true, police: .sans)
        let tailles = s.map { $0.taille }
        #expect(tailles == [1, 1])
        let gras = s.map { $0.gras }
        #expect(gras == [false, true])
    }

    @Test func smallReduitDeQuatreCinquiemesEtSeMultiplie() {
        let s = LectureBalisage.segments("א<small>ב<small>ג</small></small>", agrandir: false, police: .sans)
        #expect(textes(s) == ["א", "ב", "ג"])
        let tailles = s.map { $0.taille }
        #expect(tailles == [1, 0.8, 0.8 * 0.8])
    }

    @Test func laLigneVideDUneAerationEstReduite() {
        let s = LectureBalisage.segments("א<br><br>ב", agrandir: true, police: .sans)
        #expect(textes(s).joined() == "א\n\nב")
        // Le second saut, seul, à 0,3.
        let reduits = s.filter { $0.taille == 0.3 }.map { $0.texte }
        #expect(reduits == ["\n"])
    }

    @Test func uneBaliseInconnueEstIgnoreeEtUnChevronSeulReste() {
        let s = LectureBalisage.segments("<i>א</i> < ב", agrandir: false, police: .sans)
        #expect(textes(s).joined() == "א < ב")
    }

    @Test func lesSignesAbsentsDeLaPoliceSontMasques() {
        // Le meteg (U+05BD), que la police à empattements n'a pas, devient U+034F.
        let s = LectureBalisage.segments("\u{05D0}\u{05B8}\u{05BD}", agrandir: false, police: .serif)
        #expect(textes(s).joined() == "\u{05D0}\u{05B8}\u{034F}")
        let sans = LectureBalisage.segments("\u{05D0}\u{05B8}\u{05BD}", agrandir: false, police: .sans)
        #expect(textes(sans).joined() == "\u{05D0}\u{05B8}\u{05BD}")
    }

    // MARK: Les paragraphes d'un bloc

    @Test func uneConsigneResteEnHebreuSeul() {
        let p = LectureBalisage.paragraphes(texte: "אומרים", consigne: true, fr: "On dit", en: "Say",
                                            langues: .heFr, police: .sans)
        #expect(p.count == 1)
        #expect(p.first?.langue == "he")
        #expect(p.first?.texte == "אומרים")
    }

    @Test func unePriereEstAereeEtSonPremierMotEnGras() {
        let p = LectureBalisage.paragraphes(texte: "ברוך אתה", consigne: false, fr: nil, en: nil,
                                            langues: .heFr, police: .sans)
        #expect(p.count == 1)
        let segments = p.first?.segments ?? []
        #expect(segments.first?.texte == "ברוך")
        #expect(segments.first?.gras == true)
        #expect(segments.first?.taille == 1.25)
    }

    @Test func laTraductionSousLHebreuEstPlusPetiteEtDiscrete() {
        let p = LectureBalisage.paragraphes(texte: "ברוך", consigne: false, fr: "Béni", en: "Blessed",
                                            langues: .heFr, police: .sans)
        let langues = p.map { $0.langue }
        #expect(langues == ["he", "fr"])
        let traduction = p[1]
        #expect(traduction.texte == "Béni")
        #expect(traduction.taille == 0.84)
        #expect(traduction.discret)
        #expect(!traduction.policeHebraique)
        #expect(!traduction.droiteAGauche)
        #expect(p[0].droiteAGauche)
    }

    @Test func uneTraductionSeuleEstEnPleineTaille() {
        let p = LectureBalisage.paragraphes(texte: "ברוך", consigne: false, fr: "Béni", en: nil,
                                            langues: .fr, police: .sans)
        #expect(p.count == 1)
        #expect(p.first?.langue == "fr")
        #expect(p.first?.taille == 1)
        #expect(p.first?.discret == false)
    }

    @Test func sansTraductionLHebreuReste() {
        let p = LectureBalisage.paragraphes(texte: "ברוך", consigne: false, fr: nil, en: nil,
                                            langues: .en, police: .sans)
        let langues = p.map { $0.langue }
        #expect(langues == ["he"])
    }

    @Test func leTitreTraduitEstPlusPetit() {
        let p = LectureBalisage.titre("שחרית", fr: "Cha'harit", en: nil, langues: .heFr, police: .sans)
        let tailles = p.map { $0.taille }
        #expect(tailles == [1, 0.72])
        let gras = p.allSatisfy { $0.segments.allSatisfy { $0.gras } }
        #expect(gras)
    }
}
