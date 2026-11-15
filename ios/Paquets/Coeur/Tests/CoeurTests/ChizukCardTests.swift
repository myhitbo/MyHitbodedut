import Foundation
import Testing
@testable import Coeur

/// ChizukCardTest d'Android, porté sur le chizuk.json exporté : la traduction suit la langue de
/// l'interface. Puis tout `Tests/Vecteurs/chizuk.json` pour la carte, écrit par la JVM
/// (tools/vecteurs_ios/VecteursChizuk.kt) : les traductions de chaque texte livré (en empreintes) et
/// des recueils écrits à la main, un gabarit dans des langues voisines des cinq attendues, et la
/// langue lue d'un Locale. Rien ne reste à Android ; le remplissage de view_chizuk.xml reviendra
/// avec l'écran d'iOS.
@Suite("'Hizouk : traduction affichée")
struct ChizukCardTests {

    private func livre() throws -> Chizuk {
        try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json"))
    }

    /// `DataFiles.chizuk.items.first()`.
    private func premier() throws -> ChizukItem {
        let c = try livre()
        return try #require(c.items.first)
    }

    @Test func enFrancaisLaTraductionFrancaise() throws {
        let item = try premier()
        let traduction = ChizukCard.translationOf(item, "fr")
        let egal = traduction.egalUnites(item.fr)
        #expect(egal, "« \(traduction) »")
    }

    @Test func enAnglaisLaTraductionAnglaise() throws {
        let item = try premier()
        let traduction = ChizukCard.translationOf(item, "en")
        let egal = traduction.egalUnites(item.en)
        #expect(egal, "« \(traduction) »")
    }

    @Test func enHebreuPasDeTraduction() throws {
        let item = try premier()
        // L'hébreu est déjà au-dessus ; le répéter mangerait la carte.
        let enHebreu = ChizukCard.translationOf(item, "he")
        #expect(enHebreu == "")
        // « iw » est l'ancien code d'Android pour l'hébreu, encore rendu.
        let enIw = ChizukCard.translationOf(item, "iw")
        #expect(enIw == "")
    }

    @Test func uneLangueInconnueRetombeSurLeFrancais() throws {
        let item = try premier()
        // L'exemple était « es » ; l'espagnol a été écrit puis retiré le 22/09. Un inconnu qui le
        // reste vaut mieux.
        let enAllemand = ChizukCard.translationOf(item, "de")
        let egalAllemand = enAllemand.egalUnites(item.fr)
        #expect(egalAllemand, "« \(enAllemand) »")
        let enFrancais = ChizukCard.translationOf(item, "fr")
        let egalFrancais = enFrancais.egalUnites(item.fr)
        #expect(egalFrancais, "« \(enFrancais) »")
    }

    @Test func chaqueTexteASesDeuxTraductionsEtSaReference() throws {
        let c = try livre()
        for item in c.items {
            let sansFrancais = item.fr.estBlanc
            #expect(!sansFrancais, "\(item.id) : pas de français")
            let sansAnglais = item.en.estBlanc
            #expect(!sansAnglais, "\(item.id) : pas d'anglais")
            let sansReference = item.ref.estBlanc
            #expect(!sansReference, "\(item.id) : pas de référence")
        }
    }

    /// `ChizukCard.language` met la langue du Locale en minuscules, et rend « he » pour « iw » : la JVM
    /// des vecteurs ne le montre pas, son Locale rendant déjà « he » (voir VecteursChizuk.kt).
    @Test func lAncienCodeDeLHebreuDevientHe() {
        let iw = ChizukCard.language("iw")
        #expect(iw == "he")
        let majuscules = ChizukCard.language("IW")
        #expect(majuscules == "he")
        let he = ChizukCard.language("he")
        #expect(he == "he")
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// Les traductions d'un texte livré, une empreinte (String.hashCode) par langue de `languesDesTextes`.
        struct TexteLivre: Decodable {
            let id: String
            let traductions: [Int32]
        }
        /// Les traductions d'un texte d'un recueil, en clair.
        struct Texte: Decodable {
            let id: String
            let traductions: [String]
        }
        struct Recueil: Decodable {
            let nom: String
            let json: String
            let textes: [Texte]
        }
        struct Traduction: Decodable {
            let langue: String
            let traduction: String
        }
        /// `language(context)` d'un Context dont le Locale vient de `etiquette` ; `langueDuLocale` est
        /// ce que ce Locale rend pour sa langue, l'entrée de `ChizukCard.language` ici.
        struct LangueDuContexte: Decodable {
            let etiquette: String
            let langueDuLocale: String
            let langue: String
        }
        let languesDesTextes: [String]
        let textes: [TexteLivre]
        let recueils: [Recueil]
        let gabarit: String
        let traductions: [Traduction]
        let languesDuContexte: [LangueDuContexte]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/chizuk.json"))
    }

    @Test func lesVecteursDesTextesLivres() throws {
        let v = try vecteurs()
        let langues = v.languesDesTextes
        #expect(langues == ["fr", "en", "he", "iw", "de"])
        let c = try livre()
        let nombre = v.textes.count
        #expect(nombre == c.items.count)
        for (item, t) in zip(c.items, v.textes) {
            let id = item.id
            #expect(id == t.id)
            let empreintes = langues.map { Kotlin.hashCode(ChizukCard.translationOf(item, $0)) }
            #expect(empreintes == t.traductions, "\(t.id) : translationOf")
        }
    }

    @Test func lesVecteursDesRecueils() throws {
        let v = try vecteurs()
        for r in v.recueils {
            let c = try JSONDecoder().decode(Chizuk.self, from: Data(r.json.utf8))
            let nombre = c.items.count
            #expect(nombre == r.textes.count, "\(r.nom) : nombre de textes")
            for (item, t) in zip(c.items, r.textes) {
                let id = item.id
                #expect(id == t.id, "\(r.nom)")
                let traductions = v.languesDesTextes.map { ChizukCard.translationOf(item, $0) }
                let egaux = traductions.count == t.traductions.count
                    && zip(traductions, t.traductions).allSatisfy { $0.egalUnites($1) }
                #expect(egaux, "\(r.nom), \(t.id) : \(traductions) au lieu de \(t.traductions)")
            }
        }
    }

    @Test func lesVecteursDuGabarit() throws {
        let v = try vecteurs()
        let item = try JSONDecoder().decode(ChizukItem.self, from: Data(v.gabarit.utf8))
        let nombre = v.traductions.count
        #expect(nombre == 28)
        for t in v.traductions {
            let traduction = ChizukCard.translationOf(item, t.langue)
            let egal = traduction.egalUnites(t.traduction)
            #expect(egal, "translationOf(« \(t.langue) ») : « \(traduction) » au lieu de « \(t.traduction) »")
        }
    }

    @Test func lesVecteursDeLaLangueDuContexte() throws {
        let v = try vecteurs()
        let nombre = v.languesDuContexte.count
        #expect(nombre == 23)
        for l in v.languesDuContexte {
            let langue = ChizukCard.language(l.langueDuLocale)
            let egal = langue.egalUnites(l.langue)
            #expect(egal, "« \(l.etiquette) » (\(l.langueDuLocale)) : « \(langue) » au lieu de « \(l.langue) »")
        }
    }
}
