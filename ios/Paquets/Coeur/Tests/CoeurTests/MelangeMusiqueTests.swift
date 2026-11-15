import Foundation
import Testing
@testable import Coeur

/// MelangeMusiqueTest d'Android, porté : tout, dans un ordre au hasard, sans répétition, avec les
/// graines du test (`Random(7)` devient `HasardKotlin(graine: 7)`). Puis tout
/// `Tests/Vecteurs/melange_musique.json`, écrit par la JVM (tools/vecteurs_ios/VecteursMelangeMusique.kt) :
/// la suite exacte des morceaux d'Android pour chaque graine et chaque scénario. Restent à Android
/// « la séance enchaîne les morceaux » et « la bibliothèque reste accessible sur petit écran », qui
/// lisent SessionService.kt, MusicPlayer.kt et le layout de l'écran de musique.
@Suite("Mélange de la musique")
struct MelangeMusiqueTests {

    private let ids: [String] = (1...12).map { n in n < 10 ? "niggoun_0\(n)" : "niggoun_\(n)" }

    /// Les identifiants comparés unité par unité, comme en Kotlin (« é » et « e » + accent diffèrent).
    private func memes(_ a: [String?], _ b: [String?]) -> Bool {
        if a.count != b.count { return false }
        for (x, y) in zip(a, b) {
            switch (x, y) {
            case (nil, nil):
                continue
            case let (.some(u), .some(v)):
                if !u.egalUnites(v) { return false }
            default:
                return false
            }
        }
        return true
    }

    @Test func aucunMorceauNeRevientAvantQueTousAientJoue() throws {
        var melange = MelangeMusique(hasard: HasardKotlin(graine: 7))
        for _ in 0..<5 {
            var tour: [String] = []
            for _ in 0..<ids.count {
                let rendu = melange.suivant(ids)
                let morceau = try #require(rendu)
                tour.append(morceau)
            }
            let joues = Set(tour)
            let tous = Set(ids)
            #expect(joues == tous, "un tour doit tout jouer une fois")
        }
    }

    @Test func jamaisDeuxFoisDeSuiteLeMemeMorceau() throws {
        for graine in Int32(1)...50 {
            var melange = MelangeMusique(hasard: HasardKotlin(graine: graine))
            var suite: [String] = []
            for _ in 0..<(ids.count * 6) {
                let rendu = melange.suivant(ids)
                let morceau = try #require(rendu)
                suite.append(morceau)
            }
            for k in 1..<suite.count {
                let a = suite[k - 1]
                let b = suite[k]
                #expect(a != b, "graine \(graine)")
            }
        }
    }

    @Test func lOrdreChangeDUnTourALAutre() throws {
        var melange = MelangeMusique(hasard: HasardKotlin(graine: 3))
        var premier: [String] = []
        for _ in 0..<ids.count {
            let rendu = melange.suivant(ids)
            let morceau = try #require(rendu)
            premier.append(morceau)
        }
        var second: [String] = []
        for _ in 0..<ids.count {
            let rendu = melange.suivant(ids)
            let morceau = try #require(rendu)
            second.append(morceau)
        }
        #expect(premier != second)
    }

    @Test func unMorceauRetireNeSortPlusEtUneBibliothequeVideNeJoueRien() {
        var melange = MelangeMusique(hasard: HasardKotlin(graine: 1))
        _ = melange.suivant(ids)
        let restants = Array(ids.dropFirst(6))
        for _ in 0..<20 {
            let morceau = melange.suivant(restants)
            let parmiLesRestants = morceau.map { restants.contains($0) } ?? false
            let nom = morceau ?? "rien"
            #expect(parmiLesRestants, "« \(nom) »")
        }
        let rien = melange.suivant([])
        #expect(rien == nil)
        var auHasard = MelangeMusique()
        let seul = auHasard.suivant(["seul"])
        #expect(seul == "seul")
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// Un appel répété : la bibliothèque passée à `suivant`, ce qu'il rend à chaque fois, `dernier` après.
        struct Appel: Decodable {
            let ids: [String]
            let rendus: [String?]
            let dernier: String?
        }
        struct Scenario: Decodable {
            let nom: String
            let appels: [Appel]
        }
        struct Graine: Decodable {
            let graine: Int32
            let scenarios: [Scenario]
        }
        /// `Random(Long)` : la graine écrite en texte, pour qu'aucun lecteur de JSON ne l'arrondisse.
        struct GraineLongue: Decodable {
            let graine: String
            let scenarios: [Scenario]
        }
        /// Six tours de douze niggounim : le rang de chaque morceau joué.
        struct Suite: Decodable {
            let graine: Int32
            let suite: [Int]
        }

        let graines: [Graine]
        let grainesLongues: [GraineLongue]
        let cinquante: [Suite]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/melange_musique.json"))
    }

    private func rejoue(_ hasard: HasardKotlin, _ scenario: Vecteurs.Scenario, _ contexte: String) {
        var melange = MelangeMusique(hasard: hasard)
        for (i, appel) in scenario.appels.enumerated() {
            var rendus: [String?] = []
            for _ in 0..<appel.rendus.count {
                rendus.append(melange.suivant(appel.ids))
            }
            let egaux = memes(rendus, appel.rendus)
            let obtenus = String(describing: rendus)
            let attendus = String(describing: appel.rendus)
            #expect(egaux, "\(contexte), \(scenario.nom), appel \(i) : \(obtenus) au lieu de \(attendus)")
            let dernier = memes([melange.dernier], [appel.dernier])
            #expect(dernier, "\(contexte), \(scenario.nom), appel \(i) : dernier")
        }
    }

    @Test func chaqueGraineJoueLaSuiteDAndroid() throws {
        let v = try vecteurs()
        let nombre = v.graines.count
        #expect(nombre > 5)
        for g in v.graines {
            for s in g.scenarios {
                rejoue(HasardKotlin(graine: g.graine), s, "graine \(g.graine)")
            }
        }
        for g in v.grainesLongues {
            let graine: Int64 = try #require(Int64(g.graine), "graine illisible : \(g.graine)")
            for s in g.scenarios {
                rejoue(HasardKotlin(graineLongue: graine), s, "graine longue \(g.graine)")
            }
        }
    }

    @Test func cinquanteGrainesSixToursCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.cinquante.count
        #expect(nombre == 50)
        for c in v.cinquante {
            var melange = MelangeMusique(hasard: HasardKotlin(graine: c.graine))
            var suite: [Int] = []
            for _ in 0..<c.suite.count {
                let rendu = melange.suivant(ids)
                let morceau = try #require(rendu)
                let rang = try #require(ids.firstIndex(of: morceau))
                suite.append(rang)
            }
            #expect(suite == c.suite, "graine \(c.graine)")
        }
    }
}
