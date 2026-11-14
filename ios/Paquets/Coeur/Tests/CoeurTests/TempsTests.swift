import Foundation
import Testing
@testable import Coeur

/// Les heures civiles et les fuseaux devant `java.time` : `Tests/Vecteurs/temps.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursTemps.kt). Dix fuseaux, les jours où l'heure change, les heures qui
/// n'existent pas et celles qui existent deux fois.
@Suite("Temps")
struct TempsTests {

    private struct Vecteurs: Decodable {
        struct VersInstant: Decodable {
            let fuseau: String
            let jour: String
            let millis: [Int64]
            let relues: [String]
            let decalages: [Int]
        }
        struct VersCivil: Decodable {
            let fuseau: String
            let millis: Int64
            let jour: String
            let heure: Int
            let minute: Int
            let seconde: Int
            let milli: Int
            let decalage: Int
            let jourDeSemaineJava: Int
            let samedi: Bool
        }
        struct Champs: Decodable {
            let jour: String
            let heure: Int
            let minute: Int
            let seconde: Int
        }
        struct Arithmetique: Decodable {
            let depart: Champs
            let minutes: Int
            let arrivee: Champs
            let moinsQuatreHeures: String
        }

        let heures: [[Int]]
        let versInstant: [VersInstant]
        let versCivil: [VersCivil]
        let arithmetique: [Arithmetique]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/temps.json"))
    }

    private func dateHeure(_ c: Vecteurs.Champs) -> DateHeure {
        DateHeure(JourCivil.du(c.jour), heure: c.heure, minute: c.minute, seconde: c.seconde)
    }

    @Test func uneHeureCivileDevientLInstantDeJava() throws {
        let v = try vecteurs()
        var changements = 0
        for ligne in v.versInstant {
            let fuseau = try #require(Fuseau(ligne.fuseau), "fuseau « \(ligne.fuseau) » inconnu")
            let jour = JourCivil.du(ligne.jour)
            if Set(ligne.decalages).count > 1 { changements += 1 }
            for (rang, champs) in v.heures.enumerated() {
                let civile = DateHeure(jour, heure: champs[0], minute: champs[1], seconde: champs[2])
                let ou = "\(ligne.fuseau), \(civile)"
                let millis = fuseau.millis(civile)
                let attendu = ligne.millis[rang]
                #expect(millis == attendu, "\(ou) : atZone().toInstant()")
                let relue = fuseau.dateHeure(millis: attendu).description
                let relueAttendue = ligne.relues[rang]
                #expect(relue == relueAttendue, "\(ou) : l'heure relue de l'instant")
                let decalage = fuseau.decalage(millis: attendu)
                let decalageAttendu = ligne.decalages[rang]
                #expect(decalage == decalageAttendu, "\(ou) : le décalage")
            }
        }
        #expect(changements >= 15, "les vecteurs doivent couvrir des jours où l'heure change")
    }

    @Test func unInstantVuDUnFuseau() throws {
        for c in try vecteurs().versCivil {
            let fuseau = try #require(Fuseau(c.fuseau), "fuseau « \(c.fuseau) » inconnu")
            let ou = "\(c.fuseau), \(c.millis) ms"
            let vue = fuseau.dateHeure(millis: c.millis)
            let attendue = DateHeure(JourCivil.du(c.jour), heure: c.heure, minute: c.minute, seconde: c.seconde, milli: c.milli)
            #expect(vue == attendue, "\(ou) : ofInstant")
            let jour = fuseau.jour(millis: c.millis)
            #expect(jour == attendue.jour, "\(ou) : toLocalDate")
            let decalage = fuseau.decalage(millis: c.millis)
            #expect(decalage == c.decalage, "\(ou) : le décalage")
            // DayOfWeek de Java compte de lundi (1) à dimanche (7) ; JourCivil, de dimanche (1) à samedi (7).
            let commeJava = (vue.jour.jourDeSemaine + 5) % 7 + 1
            #expect(commeJava == c.jourDeSemaineJava, "\(ou) : le jour de la semaine")
            let samedi = vue.jour.jourDeSemaine == 7
            #expect(samedi == c.samedi, "\(ou) : samedi")
            let retour = fuseau.millis(vue)
            let meme = fuseau.dateHeure(millis: retour)
            #expect(meme == vue, "\(ou) : aller et retour")
        }
    }

    @Test func arithmetiqueDUneHeureCivile() throws {
        for a in try vecteurs().arithmetique {
            let depart = dateHeure(a.depart)
            let ou = "\(depart) + \(a.minutes) min"
            let arrivee = depart.plus(minutes: a.minutes)
            let attendue = dateHeure(a.arrivee)
            #expect(arrivee == attendue, "\(ou) : plusMinutes")
            let ecart = arrivee.millisDepuis(depart)
            #expect(ecart == a.minutes * 60_000, "\(ou) : l'écart")
            let avant = arrivee < depart
            #expect(avant == (a.minutes < 0), "\(ou) : l'ordre")
            let quatreHeuresPlusTot = depart.plus(heures: -4).jour.iso
            #expect(quatreHeuresPlusTot == a.moinsQuatreHeures, "\(depart) : minusHours(4).toLocalDate()")
        }
    }

    @Test func champsEtBornes() {
        let jour = JourCivil.du("2026-11-13")
        let soir = DateHeure(jour, heure: 23, minute: 59, seconde: 59, milli: 999)
        #expect(soir.heure == 23)
        #expect(soir.minute == 59)
        #expect(soir.seconde == 59)
        #expect(soir.milli == 999)
        #expect(soir.minutesDuJour == 1439)
        let lendemain = soir.plus(millis: 1)
        #expect(lendemain == DateHeure(JourCivil.du("2026-11-14")))
        let veille = DateHeure(jour, heure: -1)
        #expect(veille == DateHeure(JourCivil.du("2026-11-12"), heure: 23))
        #expect(soir.description == "2026-11-13T23:59:59")
        let inconnu = Fuseau("Mars/Olympus_Mons")
        #expect(inconnu == nil)
        #expect(Fuseau.utc.decalage(millis: 0) == 0)
    }
}
