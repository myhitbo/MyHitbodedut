import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'apparence tirée des réglages (Apparence.kt) : le fond, l'accent et le mode d'origine pour des réglages
/// vides ou inconnus, la nuit imposée selon le mode, et la variante féminine des illustrations (Personnage.kt).
@Suite("Apparence choisie")
struct ApparenceChoisieTests {

    @Test func desReglagesVidesDonnentLApparenceDOrigine() {
        let apparence = ApparenceChoisie(Reglages())
        #expect(apparence.fond == .vert)
        #expect(apparence.accent == .vert)
        #expect(apparence.mode == .auto)
        #expect(apparence.adresse == nil)
        #expect(apparence == ApparenceChoisie())
    }

    @Test func leFondLAccentEtLeModeRegles() {
        var reglages = Reglages()
        reglages.setFond(.sable)
        reglages.setAccent(.bordeaux)
        reglages.setModeApparence("sombre")
        let apparence = ApparenceChoisie(reglages)
        #expect(apparence.fond == .sable)
        #expect(apparence.accent == .bordeaux)
        #expect(apparence.mode == .sombre)
    }

    @Test func unModeInconnuSuitLeTelephone() {
        var reglages = Reglages()
        reglages.setModeApparence("crepuscule")
        let apparence = ApparenceChoisie(reglages)
        #expect(apparence.mode == .auto)
        #expect(apparence.nuitImposee == nil)
    }

    @Test func laNuitImposeeSelonLeMode() {
        let auto = ApparenceChoisie(mode: .auto).nuitImposee
        let clair = ApparenceChoisie(mode: .clair).nuitImposee
        let sombre = ApparenceChoisie(mode: .sombre).nuitImposee
        #expect(auto == nil)
        #expect(clair == false)
        #expect(sombre == true)
    }

    @Test func lesClesDesModesSontCellesDesReglages() {
        let cles = ApparenceChoisie.Mode.allCases.map(\.rawValue)
        #expect(cles == Reglages.modesApparence)
    }

    @Test func tsadeketVoitLaPoseFeminine() {
        var reglages = Reglages()
        reglages.setAdresse("f")
        let apparence = ApparenceChoisie(reglages)
        #expect(apparence.adresse == .femme)
        #expect(apparence.image("char_welcome") == "char_f_welcome")
        #expect(apparence.image("char_tefillin") == "char_f_praying")
        // Ce qui n'est pas le personnage passe tel quel.
        #expect(apparence.image("tsiyoun") == "tsiyoun")
    }

    @Test func tsadikEtSansChoixGardentLeHassid() {
        var reglages = Reglages()
        reglages.setAdresse("m")
        let tsadik = ApparenceChoisie(reglages)
        #expect(tsadik.adresse == .homme)
        #expect(tsadik.image("char_welcome") == "char_welcome")
        let sansChoix = ApparenceChoisie(Reglages())
        #expect(sansChoix.image("char_welcome") == "char_welcome")
    }
}
