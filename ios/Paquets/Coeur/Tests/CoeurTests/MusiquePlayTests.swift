import Foundation
import Testing
@testable import Coeur

/// La liste des morceaux livrés (MusiquePlay.kt), recopiée par programme : elle doit rester celle
/// d'Android, morceau pour morceau et dans le même ordre (le premier est le morceau par défaut), et
/// celle que l'export a tirée pour iOS (`musique.json`, `ios/Ressources/Musique`).
@Suite("MusiquePlay")
struct MusiquePlayTests {

    private struct Fichier: Decodable {
        let musique: [Bundled]
    }

    private struct Bundled: Decodable {
        let id: String
        let rawRes: String
        let titleRes: String
    }

    private func vecteurs() throws -> [Bundled] {
        let donnees = try Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_b.json")
        return try JSONDecoder().decode(Fichier.self, from: donnees).musique
    }

    @Test func laTableEstCelleDAndroidDansLeMemeOrdre() throws {
        let attendus = try vecteurs()
        let table = MusiquePlay.morceaux
        #expect(table.count == attendus.count)
        for (rang, attendu) in attendus.enumerated() where rang < table.count {
            let m = table[rang]
            #expect(m.id == attendu.id, "rang \(rang)")
            #expect(m.rawRes == attendu.rawRes, "rang \(rang)")
            #expect(m.titleRes == attendu.titleRes, "rang \(rang)")
        }
    }

    @Test func laTableEstCelleQueLExportALivree() throws {
        let morceaux = try Morceau.lire(Depot.contenu("musique.json"))
        let table = MusiquePlay.morceaux
        #expect(table.count == morceaux.count)
        for (rang, morceau) in morceaux.enumerated() where rang < table.count {
            let m = table[rang]
            #expect(m.id == morceau.id, "rang \(rang)")
            #expect(m.titleRes == morceau.titre, "rang \(rang)")
            #expect("Musique/\(m.rawRes).m4a" == morceau.fichier, "rang \(rang)")
        }
        let ids = Set(table.map(\.id))
        #expect(ids.count == table.count, "un morceau livré deux fois")
    }

    @Test func chaqueTitreLivreADesMotsDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for m in MusiquePlay.morceaux {
                let titre = simples[m.titleRes] ?? ""
                #expect(!titre.blanc, "\(langue) : \(m.titleRes)")
            }
        }
    }
}
