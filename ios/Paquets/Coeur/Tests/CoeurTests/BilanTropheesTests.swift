import Foundation
import Testing
@testable import Coeur

/// BilanTropheesTest d'Android, porté : les dates de gain, les trophées proches et le bilan de la semaine (16/10).
@Suite("BilanTrophees")
struct BilanTropheesTests {

    private let d0 = JourCivil.du("2026-09-06")  // un dimanche

    private func jours(_ n: Int, _ m: Int = 15, depuis: JourCivil? = nil) -> [JourCivil: Int] {
        let debut = depuis ?? d0
        var r: [JourCivil: Int] = [:]
        for i in 0..<n { r[debut.plus(jours: i)] = m }
        return r
    }

    @Test func chaqueNiveauEstDateDuJourOuLeSeuilEstAtteint() {
        let m = jours(10)
        let dates = Trophees.datesGain(m, notes: []) { _ in false }
        #expect(dates["premier_pas:1"] == d0)
        #expect(dates["premier_pas:3"] == d0.plus(jours: 2))
        #expect(dates["jours:1"] == d0.plus(jours: 6))  // 7 jours de pratique
        #expect(dates["serie:1"] == d0.plus(jours: 2))  // 3 jours d'affilée
        // Tout ce qui est gagné a une date, rien de ce qui ne l'est pas.
        let gagnes = Set(Trophees.gagnes(Trophees.Pratique(minutes: m, notes: 0, meilleureSerie: 10)).map { $0.cle })
        #expect(gagnes == Set(dates.keys))
    }

    @Test func lesNotesDatentLaPlume() {
        let dates = Trophees.datesGain(jours(2), notes: [d0.plus(jours: 5)]) { _ in false }
        #expect(dates["plume:1"] == d0.plus(jours: 5))
    }

    @Test func unTropheeProcheEstAUnDixiemeOuAUneUnite() throws {
        // 6 jours d'affilée : « 7 jours d'affilée » est à un jour.
        let p = Trophees.Pratique(minutes: jours(6), notes: 0, meilleureSerie: 6)
        let n = try #require(Trophees.proche(p))
        #expect(n.seuil - Trophees.valeur(p, n.famille) == 1)
        // Rien n'est proche au tout début.
        let debut = Trophees.proche(Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0))
        #expect(debut == nil || debut?.seuil == 1)
    }

    @Test func lesPlusProchesSontAGagnerEtDuPlusAvanceAuMoinsAvance() {
        let p = Trophees.Pratique(minutes: jours(8), notes: 0, meilleureSerie: 8)
        let l = Trophees.plusProches(p)
        #expect(l.count == 3)
        let gagnes = l.filter { Trophees.gagne(p, $0) }
        #expect(gagnes.isEmpty)
        let f = l.map { Trophees.fraction(p, $0) }
        let decroissantes = f.sorted(by: >)
        #expect(f == decroissantes)
    }

    @Test func leBilanDeLaSemaineEcoulee() throws {
        var m = jours(3, 20, depuis: d0.plus(jours: -7))
        for (jour, minutes) in jours(4, 30) { m[jour] = minutes }  // deux semaines
        let dates = Trophees.datesGain(m, notes: []) { _ in false }
        let b = try #require(BilanSemaine.precedente(d0.plus(jours: 8), minutes: m, dates: dates))  // le lundi suivant
        #expect(b.debut == d0)
        #expect(b.minutes == 120)
        #expect(b.jours == 4)
        #expect(b.precedente == 60)
        #expect(b.ecart == 60)
        #expect(b.record)
        let avant = b.trophees.filter { (dates[$0.cle] ?? d0.plus(jours: -1)) < d0 }
        #expect(avant.isEmpty)
    }

    @Test func uneSemaineVideNeFaitPasDeBilanEtLaPremiereNEstPasUnRecord() throws {
        #expect(BilanSemaine.precedente(d0.plus(jours: 30), minutes: jours(3), dates: [:]) == nil)
        let b = try #require(BilanSemaine.precedente(d0.plus(jours: 7), minutes: jours(3), dates: [:]))
        #expect(!b.record)
        #expect(b.precedente == 0)
    }

    @Test func leRejeuIncrementalRendLesMemesNiveauxQueLeCalculComplet() {
        let exempte = { (d: JourCivil) in d.jourDeSemaine == 7 }
        var m: [JourCivil: Int] = [:]
        var notes = Set<JourCivil>()
        for i in 0..<400 {
            let d = JourCivil.du("2025-03-01").plus(jours: i)
            if !exempte(d) && (i * 37) % 11 != 3 && !(121...131).contains(i) { m[d] = 5 + (i * 13) % 70 }
            if i % 9 == 0 { notes.insert(d) }
        }
        let dates = Trophees.datesGain(m, notes: notes, exempte: exempte)
        let p = Trophees.Pratique(minutes: m, notes: notes.count, meilleureSerie: Plaque.meilleureSerie(Set(m.keys), exempte: exempte))
        let gagnes = Set(Trophees.gagnes(p).map { $0.cle })
        #expect(gagnes == Set(dates.keys))
        for (cle, d) in dates {
            guard let n = Trophees.chemin.first(where: { $0.cle == cle }) else {
                Issue.record("\(cle) hors du chemin")
                continue
            }
            let avant = m.filter { $0.key < d }
            let pAvant = Trophees.Pratique(minutes: avant, notes: notes.filter { $0 < d }.count,
                                           meilleureSerie: Plaque.meilleureSerie(Set(avant.keys), exempte: exempte))
            #expect(!Trophees.gagne(pAvant, n), "\(cle) déjà gagné avant \(d)")
        }
    }

    @Test func unJourValideA0MinCompteCommeUnJourDePratique() {
        // « Terminer » avant la première minute valide le jour : la série le compte, les trophées aussi (16/10).
        let m = [d0: 0]
        #expect(Trophees.valeur(Trophees.Pratique(minutes: m, notes: 0, meilleureSerie: 1), .jours) == 1)
        let dates = Trophees.datesGain(m, notes: []) { _ in false }
        #expect(dates["premier_pas:1"] == d0)
    }
}
