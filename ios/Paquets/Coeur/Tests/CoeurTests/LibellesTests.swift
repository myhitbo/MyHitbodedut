import Foundation
import Testing
@testable import Coeur

/// La table des libellés (LibellesTest.kt) : elle couvre toutes les clés ajout_, fete_, zman_ du catalogue
/// exporté (Localizable.xcstrings, d'après values/strings.xml), puis `Tests/Vecteurs/interface_a.json`
/// rejoué : chaque clé de Libelles.kt, chaque chaîne de l'app et des clés voisines, comme `Libelles.res` les
/// rend sur Android.
@Suite("Libelles")
struct LibellesTests {

    private struct Vecteurs: Decodable {
        struct Entree: Decodable {
            let cle: String
            let res: String?
        }

        let libelles: [Entree]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_a.json"))
    }

    @Test func aucuneCleNeManqueALaTable() throws {
        // Le motif du test d'Android, sur chaque clé du catalogue (chaînes et pluriels).
        let motif = ExpressionReguliere("(?:ajout|fete|zman)_[a-z0-9_]+")
        let cles = try Catalogue.lire().strings.keys.filter { motif.couvre($0) }.sorted()
        let manquantes = cles.filter { Libelles.res($0) != $0 }
        let n = cles.count
        #expect(manquantes.isEmpty, "régénérer Libelles.kt : \(manquantes)")
        #expect(n >= 75)
    }

    /// La table, entrée par entrée et dans l'ordre d'Android (les vecteurs commencent par les clés du source),
    /// puis chaque clé lue : rien de plus, rien de moins.
    @Test func laTableEstCelleDAndroid() throws {
        let v = try vecteurs()
        let n = Libelles.table.count
        // 214 clés depuis les deux catégories du siddour (26/11) ; 194 depuis les הרחמן de la table repliés (22/11) ;
        // 192 après l'audit du 16/11, 124 avant.
        #expect(n == 214)
        for (rang, (ici, lu)) in zip(Libelles.table, v.libelles).enumerated() {
            let chaine: String? = ici.chaine
            #expect(ici.cle == lu.cle, "rang \(rang)")
            #expect(chaine == lu.res, "rang \(rang) : « \(lu.cle) »")
        }
        var dansLaTable = 0
        for lu in v.libelles {
            let res = Libelles.res(lu.cle)
            #expect(res == lu.res, "« \(lu.cle) »")
            if lu.res != nil {
                dansLaTable += 1
            }
        }
        #expect(dansLaTable == n, "clés de la table lues sur Android")
    }

    /// Chaque libellé de la table a sa chaîne dans les trois langues du catalogue.
    @Test func chaqueLibelleASaChaineDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for (cle, chaine) in Libelles.table {
                let presente = simples[chaine] != nil
                #expect(presente, "\(langue) : « \(chaine) » (\(cle)) manquant")
            }
        }
    }
}
