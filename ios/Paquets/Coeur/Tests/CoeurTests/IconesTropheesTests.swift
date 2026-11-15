import Foundation
import Testing
@testable import Coeur

/// IconesTropheesTest d'Android, porté : les icônes des familles (16/10, variante B), une par famille, au trait,
/// dans le fichier partagé avec le web. Android lit res/raw/trophees_formes.json ; ici, le contenu exporté
/// (ios/Ressources/Contenu/trophees_formes.json). Rien ne reste à Android.
@Suite("Icônes des trophées")
struct IconesTropheesTests {

    private struct Formes: Decodable {
        let icones: [String: String]
    }

    private func lireIcones() throws -> [String: String] {
        try JSONDecoder().decode(Formes.self, from: Depot.contenu("trophees_formes.json")).icones
    }

    @Test func chaqueFamilleASonIconeAuTrait() throws {
        let icones = try lireIcones()
        for f in Trophees.Famille.allCases {
            let trace = icones[f.icone]
            #expect(trace != nil, "\(f.cle) sans icône")
            let commenceParM = trace?.commenceParUnites("M") ?? false
            #expect(commenceParM, "\(f.cle) : un tracé commence par M")
        }
        let nombre = icones.count
        let familles = Trophees.Famille.allCases.count
        #expect(nombre == familles)
    }

    @Test func plusAucunEmoji() {
        for f in Trophees.Famille.allCases {
            var ascii = true
            for u in f.icone.utf16 where u >= 128 { ascii = false }
            #expect(ascii, "\(f.cle)")
        }
    }
}
