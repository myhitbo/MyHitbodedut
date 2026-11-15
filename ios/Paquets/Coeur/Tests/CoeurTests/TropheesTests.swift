import Foundation
import Testing
@testable import Coeur

/// TropheesTest d'Android, porté : les trophées à niveaux (12/10), valeurs, rangs, métaux, progression, nouveautés.
@Suite("Trophees")
struct TropheesTests {

    private let dimanche = JourCivil.du("2026-10-04")

    private func jours(_ n: Int, pas: Int = 1, minutes: Int = 20) -> [JourCivil: Int] {
        var r: [JourCivil: Int] = [:]
        for i in 0..<n { r[dimanche.plus(jours: i * pas)] = minutes }
        return r
    }

    @Test func rienSansPratiqueLePremierPasDesLePremierJour() {
        #expect(Trophees.gagnes(Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0)).isEmpty)
        let un = Trophees.gagnes(Trophees.Pratique(minutes: jours(1), notes: 0, meilleureSerie: 1))
        #expect(un.contains(Trophees.Niveau(.premierPas, 1)))
    }

    @Test func chaqueNiveauAtteintEstGagneEtLesRangsSuiventLesSeuils() {
        var minutes = jours(41)
        minutes[dimanche.plus(jours: 60)] = 130
        let p = Trophees.Pratique(minutes: minutes, notes: 26, meilleureSerie: 41)
        #expect(Trophees.rang(p, .jours) == 7)          // 42 jours : 7, 10, 15, 18, 20, 30, 40
        #expect(Trophees.rang(p, .serie) == 9)          // 41 : 3, 5, 7, 10, 15, 18, 20, 30, 40
        #expect(Trophees.rang(p, .seanceLongue) == 12)  // 130 min : de 10 à 120
        #expect(Trophees.rang(p, .plume) == 3)          // 26 notes : 1, 10, 25
        #expect(Trophees.rang(p, .retour) == 1)
        #expect(Trophees.semainesPleines(Set(jours(41).keys)) == 6)  // du 4/10 au vendredi 13/11
        let g = Trophees.gagnes(p)
        for k in 1...7 { #expect(g.contains(Trophees.Niveau(.jours, k))) }
        #expect(Trophees.rang(p, .premierPas) == 5)     // 42 jours : les cinq premiers
    }

    @Test func lesMetauxMontentDeBronzeAPlatineSansSauter() {
        for f in Trophees.Famille.allCases where f.seuils.count > 1 {
            let m = (1...f.seuils.count).map { Trophees.metal(f, $0) }
            #expect(m.first == .bronze, "\(f)")
            #expect(m.last == .platine, "\(f)")
            let sauts = zip(m, m.dropFirst()).filter { paire in !(0...1).contains(paire.1.rang - paire.0.rang) }
            #expect(sauts.isEmpty, "\(f)")
            let seuils = f.seuils
            let montent = zip(seuils, seuils.dropFirst()).allSatisfy { paire in paire.1 > paire.0 }
            #expect(montent, "\(f)")
        }
        #expect(Trophees.metal(.premierPas, 1) == .bronze)
    }

    @Test func laProgressionViseLeNiveauSuivantEtLeSommetResteAuDernierSeuil() {
        let pratiques = [
            Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0),
            Trophees.Pratique(minutes: jours(6, minutes: 70), notes: 12, meilleureSerie: 6),
            Trophees.Pratique(minutes: jours(700, pas: 1, minutes: 200), notes: 200, meilleureSerie: 700),
        ]
        for p in pratiques {
            for f in Trophees.Famille.allCases {
                let r = Trophees.rang(p, f)
                let pr = Trophees.progres(p, f)
                if r < f.seuils.count {
                    #expect(pr.cible == f.seuils[r])
                    #expect(pr.valeur < pr.cible)
                } else {
                    #expect(pr.cible == f.seuils.last)
                }
                #expect(pr.fraction >= 0 && pr.fraction <= 1)
            }
        }
    }

    @Test func lesNouveautesLePlusHautDeChaqueFamilleRienLaPremiereFoisNiDepuisLAncienFormat() {
        let g = Trophees.gagnes(Trophees.Pratique(minutes: jours(20), notes: 0, meilleureSerie: 20))
        #expect(Trophees.nouveaux(g, vus: nil).isEmpty)
        #expect(Trophees.nouveaux(g, vus: ["chai", "premier_pas"]).isEmpty)
        let n = Trophees.nouveaux(g, vus: ["premier_pas:1"])
        let familles = Set(n.map { $0.famille })
        #expect(familles.count == n.count)
        #expect(n.contains(Trophees.Niveau(.jours, 5)))
    }
}
