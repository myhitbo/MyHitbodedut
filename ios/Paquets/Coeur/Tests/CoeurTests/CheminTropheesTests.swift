import Foundation
import Testing
@testable import Coeur

/// CheminTropheesTest d'Android, porté : le chemin des trophées (15/10), une seule liste du plus facile au plus dur,
/// le prochain, le grade.
@Suite("CheminTrophees")
struct CheminTropheesTests {

    private func pratique(_ jours: Int, minutes: Int = 15, notes: Int = 0) -> Trophees.Pratique {
        var m: [JourCivil: Int] = [:]
        for i in 0..<jours { m[JourCivil.du("2026-09-01").plus(jours: i)] = minutes }
        return Trophees.Pratique(minutes: m, notes: notes, meilleureSerie: jours)
    }

    @Test func tousLesNiveauxUneSeuleFoisDuPlusFacileAuPlusDur() {
        let c = Trophees.chemin
        let total = Trophees.Famille.allCases.map { $0.seuils.count }.reduce(0, +)
        #expect(c.count == total)
        let cles = Set(c.map { $0.cle })
        #expect(cles.count == c.count)
        #expect(c.first == Trophees.Niveau(.premierPas, 1))
        let couts = c.map { Trophees.cout($0.famille, $0.seuil) }
        #expect(couts == couts.sorted())
    }

    @Test func lesGagnesSontCeuxDesNiveauxEtLeProchainNEstPasGagne() throws {
        let p = pratique(11, notes: 15)
        let parChemin = Set(Trophees.chemin.filter { Trophees.gagne(p, $0) })
        #expect(Trophees.gagnes(p) == parChemin)
        let n = try #require(Trophees.prochain(p))
        #expect(!Trophees.gagne(p, n))
    }

    @Test func unMateriauParGrade() {
        #expect(Trophees.grade(0) == .bronze)
        #expect(Trophees.grade(9) == .bronze)
        #expect(Trophees.grade(10) == .argent)
        #expect(Trophees.grade(25) == .or)
        #expect(Trophees.grade(60) == .platine)
    }

    @Test func sansPratiqueLeProchainEstLaPremiereHitbodedout() {
        #expect(Trophees.prochain(pratique(0)) == Trophees.Niveau(.premierPas, 1))
    }

    @Test func leProchainEstLePlusProche() throws {
        // 11 jours d'affilée : la série de 15 est à 73 % ; 15 jours de pratique aussi, mais plus loin au chemin.
        let n = try #require(Trophees.prochain(pratique(11, notes: 0)))
        #expect(Trophees.fraction(pratique(11), n) >= 0.7)
    }

    /// Le chemin, ses coûts et ses métaux sont ceux que la JVM a écrits dans tables.json, comme les seuils.
    @Test func leCheminEstCeluiDeTablesJson() throws {
        let trophees = try #require(try Depot.vecteurs("tables.json").objet("trophees"))
        let familles = trophees.tableau("familles") ?? []
        let attendues = familles.indices.compactMap { familles.objet($0) }
        #expect(attendues.count == Trophees.Famille.allCases.count)
        for (f, o) in zip(Trophees.Famille.allCases, attendues) {
            let s = o.tableau("seuils") ?? []
            let seuils = s.indices.map { s.entier($0) }
            #expect(f.cle == o.texte("cle"))
            #expect(f.icone == o.texte("icone"))
            #expect(f.forme.rawValue == o.texte("forme"))
            #expect(f.seuils == seuils, "\(f.cle)")
        }
        let chemin = trophees.tableau("chemin") ?? []
        let etapes = chemin.indices.compactMap { chemin.objet($0) }
        #expect(etapes.count == Trophees.chemin.count)
        for (n, o) in zip(Trophees.chemin, etapes) {
            let obtenu = "\(n.cle) \(n.seuil) \(Trophees.cout(n.famille, n.seuil)) \(n.metal.rawValue)"
            let attendu = "\(o.texte("cle")) \(o.entier("seuil")) \(o.double("cout")) \(o.texte("metal"))"
            #expect(obtenu == attendu)
        }
        let g = trophees.tableau("seuilsGrades") ?? []
        let grades = g.indices.map { g.entier($0) }
        #expect(grades == Trophees.seuilsGrades)
        let paliers = try #require(try Depot.vecteurs("tables.json").objet("paliers")?.objet("echelles"))
        for piste in Paliers.Piste.allCases {
            let e = try #require(paliers.objet(piste.cle))
            let b = e.tableau("base") ?? []
            let (base, pas) = Paliers.base(piste)
            let attendue = b.indices.map { b.entier($0) }
            #expect(base == attendue, "\(piste)")
            #expect(pas == e.entier("pas"), "\(piste)")
        }
    }
}
