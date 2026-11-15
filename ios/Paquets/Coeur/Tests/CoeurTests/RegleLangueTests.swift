import Foundation
import Testing
@testable import Coeur

/// RegleLangueTest d'Android, porté : en hébreu rien que de l'hébreu, en anglais l'hébreu et
/// l'anglais, en français l'hébreu et le français, jamais de repli ; puis tout le chapitre
/// « regleLangue » de `Tests/Vecteurs/langues.json` (tools/vecteurs_ios/VecteursLangues.kt).
/// Restent à Android ce qui lit ses écrans et ses layouts : ProofreadActivity.kt (`l ecran de
/// relecture…`), LibraryEntryActivity.kt, activity_settings.xml (`le bouton de langue…`), activity_main.xml
/// et activity_tikkun_flow.xml ; leurs chaînes se vérifient ici sur le catalogue exporté.
@Suite("RegleLangue")
struct RegleLangueTests {

    @Test func enHebreuRienQueDeLHebreu() {
        let hebreuSeul: Set<String> = ["he"]
        let he = RegleLangue.permises("he")
        #expect(he == hebreuSeul)
        let iw = RegleLangue.permises("iw")
        #expect(iw == hebreuSeul)
        let francais = RegleLangue.permet("he", "fr")
        #expect(!francais, "le français ne doit pas passer en mode hébreu")
        let anglais = RegleLangue.permet("he", "en")
        #expect(!anglais, "l'anglais ne doit pas passer en mode hébreu")
        let traduit = RegleLangue.traduit("iw")
        #expect(!traduit, "pas de traduction à côté de l'hébreu")
    }

    @Test func enAnglaisLHebreuEtLAnglaisPasLeFrancais() {
        let attendu: Set<String> = ["he", "en"]
        let permises = RegleLangue.permises("en")
        #expect(permises == attendu)
        let hebreu = RegleLangue.permet("en", "he")
        #expect(hebreu)
        let francais = RegleLangue.permet("en", "fr")
        #expect(!francais, "c'est le défaut que le propriétaire a vu sur son téléphone")
    }

    @Test func enFrancaisLHebreuEtLeFrancaisPasLAnglais() {
        let attendu: Set<String> = ["he", "fr"]
        let permises = RegleLangue.permises("fr")
        #expect(permises == attendu)
        let hebreu = RegleLangue.permet("fr", "he")
        #expect(hebreu)
        let anglais = RegleLangue.permet("fr", "en")
        #expect(!anglais)
    }

    @Test func aucunRepliDUneLangueSurUneAutre() {
        // C'est le cœur de la règle : un texte qui n'existe pas dans la langue du mode ne s'affiche
        // pas, il ne se remplace pas.
        let seulementFrancais: [String: String?] = ["fr": "une note"]
        let fr = RegleLangue.choisit("fr", seulementFrancais)
        #expect(fr == "une note")
        let en = RegleLangue.choisit("en", seulementFrancais)
        #expect(en == nil, "l'anglais retombait sur le français")
        let he = RegleLangue.choisit("he", seulementFrancais)
        #expect(he == nil, "l'hébreu retombait sur le français")
        let hebreuVide: [String: String?] = ["fr": "x", "he": ""]
        let vide = RegleLangue.choisit("en", hebreuVide)
        #expect(vide == nil)
    }

    /// La moitié « chaînes » de `ni note ni edition ne s affichent sous un texte` : aucune langue ne
    /// porte plus `library_note` ni `library_edition`, et le lien vers Sefaria, seule attribution qui
    /// reste, a sa chaîne. Ce que LibraryEntryActivity.kt affiche reste à Android.
    @Test func niNoteNiEditionNeSAffichentSousUnTexte() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for cle in ["library_note", "library_edition"] {
                let presente = simples[cle] != nil
                #expect(!presente, "\(langue) porte encore la chaîne « \(cle) », que plus rien n'affiche")
            }
            let sefaria = simples["library_open_sefaria"] != nil
            #expect(sefaria, "\(langue) : le lien vers Sefaria est la seule attribution qui reste : il doit rester")
        }
        let nulle = catalogue.strings["library_note"] == nil && catalogue.strings["library_edition"] == nil
        #expect(nulle, "le catalogue garde une clé que plus rien n'affiche")
    }

    @Test func leRegistreDesSourcesResteDansLesDonnees() throws {
        // Retirer l'affichage n'est pas effacer ce qui a été vérifié.
        let racine = try JSON.lire(String(decoding: Depot.contenu("bibliotheque.json"), as: UTF8.self))
        var avecNote = 0
        func marche(_ n: JSON) {
            switch n {
            case .objet(let o):
                if o.texte("type").egalUnites("source") && !o.texte("note").estBlanc { avecNote += 1 }
                for paire in o.paires { marche(paire.valeur) }
            case .tableau(let t):
                for element in t { marche(element) }
            default:
                break
            }
        }
        marche(racine)
        let nombre = avecNote
        #expect(nombre == 26, "le registre des notes de sources a été perdu")
    }

    /// La moitié « chaînes » de `le titre du Tikoun suit la langue de l interface, pas fige en hebreu` :
    /// la chaîne morte `tikkun_title_he` a disparu, `tikkun_title` est traduite dans les trois langues.
    /// Ce que pointent les layouts reste à Android.
    @Test func leTitreDuTikounSuitLaLangueDeLInterfacePasFigeEnHebreu() throws {
        let catalogue = try Catalogue.lire()
        let morte = catalogue.strings["tikkun_title_he"] != nil
        #expect(!morte, "tikkun_title_he traîne encore dans les ressources : la chaîne morte devrait disparaître")
        for langue in Catalogue.langues {
            let titre = catalogue.simples(langue)["tikkun_title"] ?? ""
            let present = !titre.estBlanc
            #expect(present, "\(langue) ne porte pas tikkun_title")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        let regleLangue: Regle
    }

    /// Pour chaque étiquette : `permet` pour chacune de `languesDuTexte`, `choisit` pour chacun des
    /// `recueils`, dans leur ordre.
    private struct Regle: Decodable {
        let etiquettes: [Etiquette]
        let normaliseNul: String
        let languesDuTexte: [String]
        let recueils: [[String: String?]]
    }

    private struct Etiquette: Decodable {
        let etiquette: String
        let normalise: String
        let permises: [String]
        let traduit: Bool
        let permet: [Bool]
        let choisit: [String?]
    }

    /// `==` de Kotlin sur deux chaînes peut-être nulles : les mêmes unités UTF-16.
    private func meme(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case (let x?, let y?): x.egalUnites(y)
        default: false
        }
    }

    @Test func lesVecteursDeLaJVM() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/langues.json"))
        let r = v.regleLangue
        let nul = RegleLangue.normalise(nil)
        #expect(nul == r.normaliseNul)
        let nombre = r.etiquettes.count
        #expect(nombre > 40, "aucune étiquette lue : la lecture est cassée")
        for e in r.etiquettes {
            let x = e.etiquette
            let normalise = RegleLangue.normalise(x)
            let normaliseOk = normalise.egalUnites(e.normalise)
            #expect(normaliseOk, "normalise(« \(x) ») = « \(normalise) », attendu « \(e.normalise) »")
            let permises = RegleLangue.permises(x)
            let attendues = Set(e.permises)
            #expect(permises == attendues, "permises(« \(x) »)")
            let traduit = RegleLangue.traduit(x)
            #expect(traduit == e.traduit, "traduit(« \(x) »)")
            let nombrePermet = e.permet.count
            #expect(nombrePermet == r.languesDuTexte.count, "permet(« \(x) ») : vecteur incomplet")
            for (t, attendu) in zip(r.languesDuTexte, e.permet) {
                let permet = RegleLangue.permet(x, t)
                #expect(permet == attendu, "permet(« \(x) », « \(t) »)")
            }
            let nombreChoisit = e.choisit.count
            #expect(nombreChoisit == r.recueils.count, "choisit(« \(x) ») : vecteur incomplet")
            for (rang, (recueil, attendu)) in zip(r.recueils, e.choisit).enumerated() {
                let choisi = RegleLangue.choisit(x, recueil)
                let ok = meme(choisi, attendu)
                #expect(ok, "choisit(« \(x) », recueil \(rang)) = « \(choisi ?? "nil") », attendu « \(attendu ?? "nil") »")
            }
        }
    }
}
