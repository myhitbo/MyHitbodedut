import Foundation
import Testing
@testable import Coeur

/// ChizukBagTest d'Android, porté : la rotation ne répète pas, et reprend où elle s'était arrêtée.
@Suite("ChizukBag")
struct ChizukBagTests {

    private let vivier = ["a", "b", "c", "d"]

    @Test func unCycleSortChaqueTexteUneFoisEtUneSeule() throws {
        var sortis: [String] = []
        var reste: [String] = []
        for _ in vivier {
            let tirage = ChizukBag.suivant(reste, vivier: vivier, dernier: sortis.last, melange: { $0 })
            sortis.append(try #require(tirage.id))
            reste = tirage.reste
        }
        #expect(Set(sortis) == Set(vivier))
        #expect(Set(sortis).count == vivier.count, "un texte est sorti deux fois : \(sortis)")
        #expect(reste.isEmpty, "le sac devrait être vide")
    }

    @Test func leCycleSuivantNeRouvrePasSurLeDernierTexteDuPrecedent() {
        let tirage = ChizukBag.suivant([], vivier: vivier, dernier: "a", melange: { $0 })
        #expect(tirage.id != "a")
        #expect(tirage.id == "b")
        #expect(tirage.reste.contains("a"), "« a » doit rester dans le cycle")
    }

    @Test func unVivierDUnSeulTexteLeRedonne() {
        let tirage = ChizukBag.suivant([], vivier: ["a"], dernier: "a", melange: { $0 })
        #expect(tirage.id == "a")
    }

    @Test func unVivierVideNeRendRien() {
        let tirage = ChizukBag.suivant(["a"], vivier: [], dernier: nil, melange: { $0 })
        #expect(tirage.id == nil)
        #expect(tirage.reste.isEmpty)
    }

    @Test func unTexteRetireDesDonneesNeRessortPasDuSac() {
        // « z » traîne dans le sac enregistré mais n'est plus publiable.
        let tirage = ChizukBag.suivant(["z", "b"], vivier: vivier, dernier: nil, melange: { $0 })
        #expect(tirage.id == "b")
        #expect(!tirage.reste.contains("z"))
    }

    @Test func leSacEnregistreRepriendLaOuIlSEtaitArrete() {
        let premier = ChizukBag.suivant([], vivier: vivier, dernier: nil, melange: { $0 })
        // Redémarrage : seul le contenu du sac est relu.
        let second = ChizukBag.suivant(premier.reste, vivier: vivier, dernier: premier.id, melange: { $0 })
        #expect(premier.id == "a")
        #expect(second.id == "b")
    }

    @Test func chaqueMomentTireDansSonPropreVivier() throws {
        let c = try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json"))
        var hasard = HasardKotlin(graine: 4)
        for moment in Moment.allCases {
            let ids = ChizukRules.pourMoment(c, moment, debug: true).map { $0.id }
            let tirage = ChizukBag.suivant([], vivier: ids, dernier: nil) { hasard.melange($0) }
            let dedans = tirage.id.map { ids.contains($0) } ?? false
            #expect(dedans, "\(moment.rawValue) : « \(tirage.id ?? "rien") » n'appartient pas à ce moment")
        }
    }
}
