import Foundation
import Testing
@testable import Coeur

/// RegleLangueTest d'Android, porté : en hébreu, rien que de l'hébreu ; aucun repli d'une langue sur une autre ; le
/// registre des notes de sources reste dans les données. Les tests qui lisent un écran ou un layout d'Android
/// (relecture, bibliothèque, réglages, titre du Tikoun) y restent ; la partie « chaînes » du dernier est gardée
/// (`tikkun_title` dans les trois langues, `tikkun_title_he`, `library_note` et `library_edition` disparues).
@Suite("RegleLangue")
struct RegleLangueTests {

    @Test func enHebreuRienQueDeLHebreu() {
        #expect(RegleLangue.permises("he") == ["he"])
        #expect(RegleLangue.permises("iw") == ["he"])
        #expect(!RegleLangue.permet("he", "fr"), "le français ne doit pas passer en mode hébreu")
        #expect(!RegleLangue.permet("he", "en"), "l'anglais ne doit pas passer en mode hébreu")
        #expect(!RegleLangue.traduit("iw"), "pas de traduction à côté de l'hébreu")
    }

    @Test func enAnglaisLHebreuEtLAnglaisPasLeFrancais() {
        #expect(RegleLangue.permises("en") == ["he", "en"])
        #expect(RegleLangue.permet("en", "he"))
        #expect(!RegleLangue.permet("en", "fr"), "c'est le défaut que le propriétaire a vu sur son téléphone")
    }

    @Test func enFrancaisLHebreuEtLeFrancaisPasLAnglais() {
        #expect(RegleLangue.permises("fr") == ["he", "fr"])
        #expect(RegleLangue.permet("fr", "he"))
        #expect(!RegleLangue.permet("fr", "en"))
    }

    @Test func aucunRepliDUneLangueSurUneAutre() {
        let seulementFrancais = ["fr": "une note"]
        #expect(RegleLangue.choisit("fr", seulementFrancais) == "une note")
        #expect(RegleLangue.choisit("en", seulementFrancais) == nil, "l'anglais retombait sur le français")
        #expect(RegleLangue.choisit("he", seulementFrancais) == nil, "l'hébreu retombait sur le français")
        #expect(RegleLangue.choisit("en", ["fr": "x", "he": ""]) == nil)
    }

    /// Retirer l'affichage n'est pas effacer ce qui a été vérifié : 26 sources portent leur note.
    @Test func leRegistreDesSourcesResteDansLesDonnees() throws {
        let racine = try JSON.lire(Depot.texte("bibliotheque.json"))
        var avecNote = 0
        func marche(_ n: JSON) {
            switch n {
            case .objet(let o):
                if o.texte("type") == "source" && !o.texte("note").estBlanc { avecNote += 1 }
                for (_, v) in o.paires { marche(v) }
            case .tableau(let t):
                for v in t { marche(v) }
            case .nul, .booleen, .entier, .decimal, .chaine:
                break
            }
        }
        marche(racine)
        #expect(avecNote == 26, "le registre des notes de sources a été perdu")
    }

    @Test func lesChainesDuTitreDuTikounEtDeLaBibliotheque() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            #expect(chaines["tikkun_title"] != nil, "\(langue) ne porte pas tikkun_title")
            for morte in ["tikkun_title_he", "library_note", "library_edition"] {
                #expect(chaines[morte] == nil, "\(langue) porte encore « \(morte) »")
            }
        }
    }

    /// `LangueApp.repli` (29/10) : un téléphone sans langue livrée passe en anglais.
    @Test func unTelephoneSansLangueLivreePasseEnAnglais() {
        #expect(LangueApp.repli(["es-ES"]) == "en")
        #expect(LangueApp.repli(["es", "fr-FR"]) == nil)
        #expect(LangueApp.repli(["iw-IL"]) == nil)
        #expect(LangueApp.repli([]) == "en")
    }
}
