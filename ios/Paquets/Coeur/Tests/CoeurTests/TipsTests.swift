import Foundation
import Testing
@testable import Coeur

/// Les dix conseils (TipsTest.kt) : leurs chaînes, dans les trois langues du catalogue exporté
/// (Localizable.xcstrings, d'après les strings.xml d'Android), puis la table de Tips.kt rejouée de
/// `Tests/Vecteurs/interface_a.json`. Android traite une traduction manquante comme une erreur de Lint ; ces
/// tests le signalent plus tôt et plus clairement.
@Suite("Tips")
struct TipsTests {

    private struct Vecteurs: Decodable {
        struct Conseil: Decodable {
            let number: Int
            let titleRes: String
            let bodyRes: String
            let art: String
        }

        let tips: [Conseil]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_a.json"))
    }

    /// Le motif du test d'Android, sur la clé entière.
    private static let motif = ExpressionReguliere("tip_[0-9]+_(?:title|body)|tips_[a-z]+")

    private func cles(_ catalogue: Catalogue, _ langue: String) -> Set<String> {
        Set(catalogue.simples(langue).keys.filter { TipsTests.motif.couvre($0) })
    }

    @Test func lesDixConseilsSontCompletsDansChaqueLangue() throws {
        let catalogue = try Catalogue.lire()
        let attendues: [String] = (1...10).flatMap { ["tip_\($0)_title", "tip_\($0)_body"] } +
            ["tips_title", "tips_hint", "tips_open"]
        for langue in Catalogue.langues {
            let trouvees = cles(catalogue, langue)
            let manquantes = attendues.filter { !trouvees.contains($0) }
            #expect(manquantes.isEmpty, "\(langue) : clés manquantes \(manquantes)")
        }
    }

    @Test func aucuneLangueNePorteDeConseilEnTrop() throws {
        let catalogue = try Catalogue.lire()
        let reference = cles(catalogue, "fr")
        for langue in Catalogue.langues {
            let trouvees = cles(catalogue, langue)
            #expect(trouvees == reference, "\(langue) diverge de la langue par défaut")
        }
    }

    @Test func aucunConseilNEstVide() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for i in 1...10 {
                for cle in ["tip_\(i)_title", "tip_\(i)_body"] {
                    let valeur = simples[cle] ?? ""
                    let longueur = valeur.rogne.utf16.count
                    #expect(longueur > 10, "\(langue)/\(cle) est vide")
                }
            }
        }
    }

    /// La table, entrée par entrée et dans l'ordre d'Android.
    @Test func lesConseilsSontCeuxDAndroid() throws {
        let v = try vecteurs()
        let n = Tips.all.count
        let lus = v.tips.count
        #expect(n == 10)
        #expect(n == lus, "nombre de conseils")
        for (ici, lu) in zip(Tips.all, v.tips) {
            #expect(ici.number == lu.number)
            #expect(ici.titleRes == lu.titleRes, "conseil \(lu.number) : titre")
            #expect(ici.bodyRes == lu.bodyRes, "conseil \(lu.number) : texte")
            #expect(ici.art == lu.art, "conseil \(lu.number) : illustration")
        }
    }

    /// Chaque conseil nomme des chaînes du catalogue, dans les trois langues, et une image livrée à iOS.
    @Test func chaqueConseilNommeDesChainesEtUneImageLivrees() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for tip in Tips.all {
                let titre = simples[tip.titleRes] != nil
                let texte = simples[tip.bodyRes] != nil
                #expect(titre, "\(langue) : « \(tip.titleRes) » manquant")
                #expect(texte, "\(langue) : « \(tip.bodyRes) » manquant")
            }
        }
        for tip in Tips.all {
            let chemin = Depot.racine.appendingPathComponent("ios/Ressources/Images/\(tip.art).webp").path
            let livree = FileManager.default.fileExists(atPath: chemin)
            #expect(livree, "\(tip.art).webp manque")
        }
    }
}
