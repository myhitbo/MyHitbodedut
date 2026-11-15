import Foundation
import Testing
@testable import Coeur

/// Le personnage au féminin pour qui a choisi צדקת (PersonnageTest.kt, audit 1.390, point 8), sur les images
/// livrées à iOS (ios/Ressources/Images, les noms de res/drawable-nodpi), et `Tests/Vecteurs/interface_a.json`
/// rejoué. Restent à Android « toutes les mises en page passent par le personnage » et « chaque image décodée
/// du personnage passe par la table », qui lisent le thème et le code des écrans d'Android.
@Suite("Personnage")
struct PersonnageTests {

    private struct Vecteurs: Decodable {
        struct Correspondance: Decodable {
            let hassid: String
            let feminine: String
        }
        struct Dessin: Decodable {
            let dessin: String
            let feminin: String
            let pourAucune: String
            let pourHomme: String
            let pourFemme: String
        }

        let personnageTable: [Correspondance]
        let personnageDessins: [Dessin]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_a.json"))
    }

    /// Les images livrées à iOS, sans leur extension (`substringBefore('.')`).
    private func dessins() throws -> [String] {
        let dossier = Depot.racine.appendingPathComponent("ios/Ressources/Images").path
        return try FileManager.default.contentsOfDirectory(atPath: dossier).map { $0.avantUnites(".") }
    }

    /// La table comme le test d'Android la lit : la pose du hassid, puis sa pose féminine.
    private func table() -> [String: String] {
        Dictionary(uniqueKeysWithValues: Personnage.feminins.map { ($0.hassid, $0.feminine) })
    }

    @Test func chaquePoseDuHassidASaPoseFeminine() throws {
        // char_face ne sert qu'à l'icône de lancement, qui reste la même pour tous.
        let hassid = try dessins().filter {
            $0.commenceParUnites("char_") && !$0.commenceParUnites("char_f_") && !$0.egalUnites("char_face")
        }.sorted()
        let cles = table().keys.sorted()
        #expect(hassid == cles)
    }

    @Test func chaquePoseFeminineLivreeSertEtChaquePoseCiteeExiste() throws {
        let feminines = try dessins().filter { $0.commenceParUnites("char_f_") }.sorted()
        let citees = Set(table().values).sorted()
        #expect(feminines == citees)
    }

    @Test func laTableNeToucheQuAuPersonnageEtNeSAppliqueQuUneFois() {
        let chevron = Personnage.feminin("ic_chevron")
        let guitare = Personnage.feminin("char_guitar")
        let dejaFeminine = Personnage.feminin("char_f_joy")
        #expect(chevron == "ic_chevron")
        #expect(guitare == "char_f_guitar")
        #expect(dejaFeminine == "char_f_joy")
    }

    @Test func leSiteSuitLaMemeTable() throws {
        let donnees = try Depot.donnees("web/src/js/personnage.js")
        let web = String(decoding: donnees, as: UTF8.self)
        // `\w` d'ICU déborde l'ASCII : la classe s'écrit en toutes lettres.
        let motif = ExpressionReguliere("(char_[A-Za-z0-9_]+): '(char_f_[A-Za-z0-9_]+)'")
        var jsTable: [String: String] = [:]
        for m in motif.toutes(web) {
            jsTable[m.groupes[1]] = m.groupes[2]
        }
        let ici = table()
        #expect(ici == jsTable)
    }

    /// La table, entrée par entrée et dans l'ordre d'Android : les 21 correspondances du personnage féminin.
    @Test func laTableEstCelleDAndroid() throws {
        let v = try vecteurs()
        let n = Personnage.feminins.count
        let lus = v.personnageTable.count
        #expect(n == 21)
        #expect(n == lus, "nombre de correspondances")
        for (rang, (ici, lu)) in zip(Personnage.feminins, v.personnageTable).enumerated() {
            #expect(ici.hassid == lu.hassid, "rang \(rang)")
            #expect(ici.feminine == lu.feminine, "rang \(rang) : \(lu.hassid)")
        }
    }

    /// Chaque dessin de l'app : au féminin, puis selon l'adresse, comme `Personnage.pour` le rend sur le vrai
    /// Store d'Android (sans adresse, צדיק, צדקת).
    @Test func chaqueDessinSuitAndroid() throws {
        let v = try vecteurs()
        let n = v.personnageDessins.count
        #expect(n > 50, "dessins lus")
        for d in v.personnageDessins {
            let feminin = Personnage.feminin(d.dessin)
            let aucune = Personnage.pour(nil, d.dessin)
            let homme = Personnage.pour(.homme, d.dessin)
            let femme = Personnage.pour(.femme, d.dessin)
            #expect(feminin == d.feminin, "\(d.dessin) : feminin")
            #expect(aucune == d.pourAucune, "\(d.dessin) : sans adresse")
            #expect(homme == d.pourHomme, "\(d.dessin) : צדיק")
            #expect(femme == d.pourFemme, "\(d.dessin) : צדקת")
        }
    }
}
