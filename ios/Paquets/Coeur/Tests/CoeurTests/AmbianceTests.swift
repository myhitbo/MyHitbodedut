import Foundation
import Testing
@testable import Coeur

/// AmbianceTest d'Android. Le calcul du son (AmbianceSynth : « chaque ambiance s'entend, sans saturer,
/// et le silence se tait », « le calcul est reproductible ») reste à l'app, avec la lecture ; ici, les
/// clés, les libellés, la clé inconnue, et aucun fichier d'ambiance dans ce qu'iOS livre.
@Suite("Ambiance")
struct AmbianceTests {

    private struct Fichier: Decodable {
        let ambiances: Ambiances
    }

    private struct Ambiances: Decodable {
        let entrees: [Entree]
        let of: [Appel]
    }

    private struct Entree: Decodable {
        let nom: String
        let cle: String
        let titre: String
    }

    /// [clé ou null, nom de l'ambiance rendue].
    private struct Appel: Decodable {
        let cle: String?
        let nom: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            cle = try c.decodeNil() ? nil : c.decode(String.self)
            nom = try c.decode(String.self)
        }
    }

    private func vecteurs() throws -> Ambiances {
        let donnees = try Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_b.json")
        return try JSONDecoder().decode(Fichier.self, from: donnees).ambiances
    }

    private func nom(_ a: Ambiance) -> String { String(describing: a).uppercased() }

    @Test func aucunFichierAudioNEstAjoutePourLesAmbiancesEtLaCleInconnueRendLeSilence() throws {
        // res/raw d'Android devient tout ce qu'iOS livre : ios/Ressources, et la liste des morceaux.
        let ressources = Depot.racine.appendingPathComponent("ios/Ressources")
        let chemins = try FileManager.default.subpathsOfDirectory(atPath: ressources.path)
        let fichiers = chemins.map { chemin in String(chemin.split(separator: "/").last ?? "") }
        let ambiances = fichiers.filter { $0.hasPrefix("ambiance") }
        #expect(ambiances.isEmpty, "\(ambiances)")
        let morceaux = try Morceau.lire(Depot.contenu("musique.json")).map(\.id).filter { $0.hasPrefix("ambiance") }
        #expect(morceaux.isEmpty, "\(morceaux)")
        let orage = Ambiance.of("orage")
        #expect(orage == .silence)
        let pluie = Ambiance.of("pluie")
        #expect(pluie == .pluie)
    }

    @Test func lesAmbiancesSontCellesDAndroidDansLeMemeOrdre() throws {
        let v = try vecteurs()
        let toutes = Ambiance.allCases
        #expect(toutes.count == v.entrees.count)
        for (rang, e) in v.entrees.enumerated() where rang < toutes.count {
            let a = toutes[rang]
            #expect(nom(a) == e.nom, "rang \(rang)")
            #expect(a.cle == e.cle, "\(e.nom)")
            #expect(a.titre == e.titre, "\(e.nom)")
        }
        #expect(v.of.count > 10)
        for appel in v.of {
            let a = Ambiance.of(appel.cle)
            #expect(nom(a) == appel.nom, "of(\(appel.cle ?? "null"))")
        }
    }

    @Test func chaqueAmbianceASonLibelleDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for a in Ambiance.allCases {
                let texte = simples[a.titre] ?? ""
                #expect(!texte.blanc, "\(langue) : \(a.titre)")
            }
        }
    }
}
