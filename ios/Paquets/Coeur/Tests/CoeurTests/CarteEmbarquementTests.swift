import Foundation
import Testing
@testable import Coeur

/// Le code des cartes d'embarquement (CarteEmbarquement.kt, BCBP de l'IATA) devant la JVM : tout ce que
/// `Tests/Vecteurs/vol_suite.json` en dit (tools/vecteurs_ios/VecteursVolSuite.kt), une quarantaine de codes lus à six
/// dates (bornes de l'année, 366e jour, chiffres d'Unicode, champs mal alignés). Le test d'Android
/// (`la carte d embarquement BCBP, sans garder le nom`) est dans SaisieVolTests.swift, comme sur Android.
@Suite("Carte d'embarquement")
struct CarteEmbarquementTests {

    private struct Fichier: Decodable {
        let cartes: [Carte]
    }

    /// [code, jour, [départ, arrivée, compagnie, numéro, date] ou null].
    private struct Carte: Decodable {
        let code: String
        let jour: String
        let troncon: CarteEmbarquement.Troncon?

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            code = try c.decode(String.self)
            jour = try c.decode(String.self)
            if try c.decodeNil() {
                troncon = nil
            } else {
                var t = try c.nestedUnkeyedContainer()
                let depart = try t.decode(String.self)
                let arrivee = try t.decode(String.self)
                let compagnie = try t.decode(String.self)
                let numero = try t.decode(String.self)
                let date = try t.decodeIfPresent(String.self).flatMap { JourCivil(iso: $0) }
                troncon = CarteEmbarquement.Troncon(depart: depart, arrivee: arrivee, compagnie: compagnie, numero: numero, date: date)
            }
        }
    }

    @Test func lesCartesSontLuesCommeSurLaJvm() throws {
        let f = try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vol_suite.json"))
        #expect(f.cartes.count >= 192)
        var lues = 0
        for x in f.cartes {
            let obtenu = CarteEmbarquement.lire(x.code, JourCivil.du(x.jour))
            #expect(obtenu == x.troncon, "« \(x.code) » le \(x.jour)")
            if obtenu != nil { lues += 1 }
        }
        // Les deux issues sont représentées.
        #expect(lues > 0)
        #expect(lues < f.cartes.count)
    }
}
