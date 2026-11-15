import Foundation
import Testing
@testable import Coeur

/// ChizukBagTest d'Android, porté : la rotation ne répète pas, et un sac relu reprend là où il
/// s'était arrêté. Puis tout `Tests/Vecteurs/chizuk.json` pour le sac, écrit par la JVM
/// (tools/vecteurs_ios/VecteursChizuk.kt) : des tirages isolés et des suites de tirages, mélangés par
/// l'identité, l'ordre inverse ou kotlin.random.Random(graine), que HasardKotlin rejoue ici. Rien ne
/// reste à Android ; l'écriture du sac dans les préférences (Store.chizukBag) n'est pas de ce fichier.
@Suite("'Hizouk : sac sans remise")
struct ChizukBagTests {

    private let pool = ["a", "b", "c", "d"]

    /// Mélange déterministe : laisse l'ordre tel quel.
    private static func identite(_ liste: [String]) -> [String] { liste }

    @Test func unCycleSortChaqueTexteUneFoisEtUneSeule() throws {
        var sortis: [String] = []
        var reste: [String] = []
        for _ in 0..<pool.count {
            let draw = ChizukBag.next(remaining: reste, pool: pool, last: sortis.last, shuffle: Self.identite)
            let id = try #require(draw.id)
            sortis.append(id)
            reste = draw.remaining
        }
        let distincts = Set(sortis)
        let attendus = Set(pool)
        #expect(distincts == attendus)
        let nombre = distincts.count
        #expect(nombre == pool.count, "un texte est sorti deux fois : \(sortis)")
        let vide = reste.isEmpty
        #expect(vide, "le sac devrait être vide")
    }

    @Test func leCycleSuivantNeRouvrePasSurLeDernierTexteDuPrecedent() {
        // Le sac est vide, le dernier sorti est « a », et le mélange le remettrait en tête : il doit
        // repartir en fin de sac.
        let draw = ChizukBag.next(remaining: [], pool: pool, last: "a", shuffle: Self.identite)
        let id = draw.id
        #expect(id != "a")
        #expect(id == "b")
        let garde = draw.remaining.contains("a")
        #expect(garde, "« a » doit rester dans le cycle")
    }

    @Test func unVivierDUnSeulTexteLeRedonne() {
        let draw = ChizukBag.next(remaining: [], pool: ["a"], last: "a", shuffle: Self.identite)
        let id = draw.id
        #expect(id == "a")
    }

    @Test func unVivierVideNeRendRien() {
        let draw = ChizukBag.next(remaining: ["a"], pool: [], last: nil, shuffle: Self.identite)
        let id = draw.id
        #expect(id == nil)
        let vide = draw.remaining.isEmpty
        #expect(vide)
    }

    @Test func unTexteRetireDesDonneesNeRessortPasDuSac() {
        // « z » traîne dans le sac enregistré mais n'est plus publiable.
        let draw = ChizukBag.next(remaining: ["z", "b"], pool: pool, last: nil, shuffle: Self.identite)
        let id = draw.id
        #expect(id == "b")
        let traine = draw.remaining.contains("z")
        #expect(!traine)
    }

    @Test func leSacEnregistreRepriendLaOuIlSEtaitArrete() {
        let premier = ChizukBag.next(remaining: [], pool: pool, last: nil, shuffle: Self.identite)
        // Redémarrage : seul le contenu du sac est relu.
        let second = ChizukBag.next(remaining: premier.remaining, pool: pool, last: premier.id, shuffle: Self.identite)
        let idPremier = premier.id
        #expect(idPremier == "a")
        let idSecond = second.id
        #expect(idSecond == "b")
    }

    /// Le mélange par défaut, comme dans le test Kotlin : un tirage au hasard, qui doit rester dans le
    /// vivier de son moment.
    @Test func chaqueMomentTireDansSonPropreVivier() throws {
        let chizuk = try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json"))
        for moment in Moment.allCases {
            let ids = ChizukRules.forMoment(chizuk, moment, debug: true).map(\.id)
            let draw = ChizukBag.next(remaining: [], pool: ids)
            let id = draw.id ?? "nil"
            let dedans = draw.id != nil && Self.contient(ids, id)
            #expect(dedans, "\(moment.rawValue) : « \(id) » n'appartient pas à ce moment")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// Un tirage isolé : `next(remaining, pool, last, mélange)` rend `id` et `reste`.
        struct Tirage: Decodable {
            let remaining: [String]
            let pool: [String]
            let last: String?
            let melange: String
            let graine: Int32?
            let id: String?
            let reste: [String]
        }
        struct Phase: Decodable {
            let pool: [String]
            let tirages: Int
        }
        /// Une suite : chaque tirage reçoit le sac restant du précédent et son identifiant comme dernier,
        /// un seul mélange pour toute la suite.
        struct Suite: Decodable {
            let nom: String
            let melange: String
            let graine: Int32?
            let phases: [Phase]
            let ids: [String?]
            let restes: [[String]]
        }
        /// Sur le fichier livré, en release : deux cycles et un tirage par moment.
        struct SuiteDuLivre: Decodable {
            let moment: String
            let debug: Bool
            let graine: Int32
            let tirages: Int
            let ids: [String?]
            let tailles: [Int]
        }
        let tirages: [Tirage]
        let suites: [Suite]
        let suitesDuLivre: [SuiteDuLivre]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/chizuk.json"))
    }

    /// Le mélange nommé d'un vecteur : l'identité, l'ordre inverse, ou kotlin.random.Random(graine),
    /// dont l'état avance d'un remplissage à l'autre comme celui de la fermeture Kotlin.
    private struct Melange {
        let nom: String
        var hasard: HasardKotlin

        init(_ nom: String, graine: Int32?) {
            self.nom = nom
            hasard = HasardKotlin(graine: graine ?? 0)
        }

        mutating func melanger(_ liste: [String]) -> [String] {
            switch nom {
            case "identite": return liste
            case "inverse": return Array(liste.reversed())
            default: return hasard.melange(liste)
            }
        }
    }

    private static let melangesConnus = ["identite", "inverse", "graine"]

    /// `id in liste` de Kotlin, unité UTF-16 par unité.
    private static func contient(_ liste: [String], _ id: String) -> Bool {
        liste.contains { $0.egalUnites(id) }
    }

    private static func memeId(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.egalUnites(y)
        default: return false
        }
    }

    private static func memes(_ a: [String], _ b: [String]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0.egalUnites($1) }
    }

    private static func memesIds(_ a: [String?], _ b: [String?]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { memeId($0, $1) }
    }

    private static func ecrit(_ id: String?) -> String { id.map { "« \($0) »" } ?? "nil" }

    /// Rejoue des phases (un vivier, un nombre de tirages) : le sac restant et le dernier sorti
    /// passent d'un tirage au suivant, comme Store.setChizukBag les écrit.
    private static func rejoue(_ melange: inout Melange, _ phases: [(pool: [String], tirages: Int)]) -> [ChizukBag.Draw] {
        var sortis: [ChizukBag.Draw] = []
        var reste: [String] = []
        var dernier: String?
        for phase in phases {
            for _ in 0..<phase.tirages {
                let draw = ChizukBag.next(remaining: reste, pool: phase.pool, last: dernier) { melange.melanger($0) }
                sortis.append(draw)
                reste = draw.remaining
                dernier = draw.id
            }
        }
        return sortis
    }

    @Test func lesVecteursDesTirages() throws {
        let v = try vecteurs()
        let nombre = v.tirages.count
        #expect(nombre == 133)
        for (rang, t) in v.tirages.enumerated() {
            let connu = Self.melangesConnus.contains(t.melange)
            #expect(connu, "tirage \(rang) : mélange inconnu « \(t.melange) »")
            var melange = Melange(t.melange, graine: t.graine)
            let draw = ChizukBag.next(remaining: t.remaining, pool: t.pool, last: t.last) { melange.melanger($0) }
            let dernier = Self.ecrit(t.last)
            let contexte = "tirage \(rang) : next(\(t.remaining), \(t.pool), \(dernier), \(t.melange))"
            let idEgal = Self.memeId(draw.id, t.id)
            let rendu = Self.ecrit(draw.id)
            let attendu = Self.ecrit(t.id)
            #expect(idEgal, "\(contexte) rend \(rendu) au lieu de \(attendu)")
            let resteEgal = Self.memes(draw.remaining, t.reste)
            #expect(resteEgal, "\(contexte) laisse \(draw.remaining) au lieu de \(t.reste)")
        }
    }

    @Test func lesVecteursDesSuites() throws {
        let v = try vecteurs()
        let nombre = v.suites.count
        #expect(nombre == 9)
        for s in v.suites {
            let connu = Self.melangesConnus.contains(s.melange)
            #expect(connu, "\(s.nom) : mélange inconnu « \(s.melange) »")
            var melange = Melange(s.melange, graine: s.graine)
            let sortis = Self.rejoue(&melange, s.phases.map { (pool: $0.pool, tirages: $0.tirages) })
            let ids = sortis.map(\.id)
            let idsEgaux = Self.memesIds(ids, s.ids)
            let lus = ids.map(Self.ecrit)
            let attendus = s.ids.map(Self.ecrit)
            #expect(idsEgaux, "\(s.nom) : \(lus) au lieu de \(attendus)")
            let restes = sortis.map(\.remaining)
            let tirages = restes.count
            #expect(tirages == s.restes.count, "\(s.nom) : nombre de tirages")
            for (rang, (reste, attendu)) in zip(restes, s.restes).enumerated() {
                let egaux = Self.memes(reste, attendu)
                #expect(egaux, "\(s.nom), tirage \(rang) : \(reste) au lieu de \(attendu)")
            }
        }
    }

    @Test func lesVecteursDuFichierLivre() throws {
        let v = try vecteurs()
        let chizuk = try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json"))
        let nombre = v.suitesDuLivre.count
        #expect(nombre == Moment.allCases.count)
        for s in v.suitesDuLivre {
            let moment = try #require(Moment(rawValue: s.moment), "moment inconnu « \(s.moment) »")
            let pool = ChizukRules.forMoment(chizuk, moment, debug: s.debug).map(\.id)
            let tirages = 2 * pool.count + 1
            #expect(tirages == s.tirages, "\(s.moment) : nombre de tirages")
            var melange = Melange("graine", graine: s.graine)
            let sortis = Self.rejoue(&melange, [(pool: pool, tirages: tirages)])
            let ids = sortis.map(\.id)
            let idsEgaux = Self.memesIds(ids, s.ids)
            let lus = ids.map(Self.ecrit)
            let attendus = s.ids.map(Self.ecrit)
            #expect(idsEgaux, "\(s.moment) : \(lus) au lieu de \(attendus)")
            let tailles = sortis.map(\.remaining.count)
            #expect(tailles == s.tailles, "\(s.moment) : tailles du sac")
        }
    }
}
