import Testing
@testable import Coeur

/// BilanTropheesTest d'Android, porté : les dates de gain, les trophées proches et le bilan de la semaine
/// (16/10). Rien ne reste à Android ; les vecteurs sont rejoués par TropheesTests.
@Suite("Bilan et dates des trophées")
struct BilanTropheesTests {

    private let d0 = JourCivil.du("2026-09-06")  // un dimanche

    private func jours(_ n: Int, minutes: Int = 15, depuis: JourCivil? = nil) -> [JourCivil: Int] {
        let debut = depuis ?? d0
        var m: [JourCivil: Int] = [:]
        for i in 0..<max(n, 0) { m[debut.plus(jours: i)] = minutes }
        return m
    }

    @Test func chaqueNiveauEstDateDuJourOuLeSeuilEstAtteint() {
        let m = jours(10)
        let dates = Trophees.datesGain(m, []) { _ in false }
        let premierPas = dates["premier_pas:1"]
        #expect(premierPas == d0)
        let troisieme = dates["premier_pas:3"]
        #expect(troisieme == d0.plus(jours: 2))
        let septJours = dates["jours:1"]
        #expect(septJours == d0.plus(jours: 6))  // 7 jours de pratique
        let serie = dates["serie:1"]
        #expect(serie == d0.plus(jours: 2))  // 3 jours d'affilée
        // Tout ce qui est gagné a une date, rien de ce qui ne l'est pas.
        let p = Trophees.Pratique(minutes: m, notes: 0, meilleureSerie: 10)
        let gagnes = Set(Trophees.gagnes(p).map { $0.cle })
        let datees = Set(dates.keys)
        #expect(gagnes == datees)
    }

    @Test func lesNotesDatentLaPlume() {
        let dates = Trophees.datesGain(jours(2), [d0.plus(jours: 5)]) { _ in false }
        let plume = dates["plume:1"]
        #expect(plume == d0.plus(jours: 5))
    }

    @Test func unTropheeProcheEstAUnDixiemeOuAUneUnite() throws {
        // 6 jours d'affilée : « 7 jours d'affilée » est à un jour.
        let p = Trophees.Pratique(minutes: jours(6), notes: 0, meilleureSerie: 6)
        let n = try #require(Trophees.proche(p))
        let reste = n.seuil - Trophees.valeur(p, n.famille)
        #expect(reste == 1)
        // Rien n'est proche au tout début.
        let auDebut = Trophees.proche(Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0))
        var procheEtLoin = false
        if let a = auDebut, a.seuil > 1 { procheEtLoin = true }
        #expect(!procheEtLoin)
    }

    @Test func lesPlusProchesSontAGagnerEtDuPlusAvanceAuMoinsAvance() {
        let p = Trophees.Pratique(minutes: jours(8), notes: 0, meilleureSerie: 8)
        let l = Trophees.plusProches(p)
        let nombre = l.count
        #expect(nombre == 3)
        var aucunGagne = true
        for n in l where Trophees.gagne(p, n) { aucunGagne = false }
        #expect(aucunGagne)
        let f = l.map { Trophees.fraction(p, $0) }
        let decroissantes = f.sorted(by: >)
        #expect(decroissantes == f)
    }

    @Test func leBilanDeLaSemaineEcoulee() throws {
        var m = jours(3, minutes: 20, depuis: d0.plus(jours: -7))  // deux semaines
        for (j, v) in jours(4, minutes: 30) { m[j] = v }
        let dates = Trophees.datesGain(m, []) { _ in false }
        let b = try #require(BilanSemaine.precedente(d0.plus(jours: 8), minutes: m, dates: dates))  // le lundi suivant
        let debut = b.debut
        #expect(debut == d0)
        let minutes = b.minutes
        #expect(minutes == 120)
        let nombreDeJours = b.jours
        #expect(nombreDeJours == 4)
        let precedente = b.precedente
        #expect(precedente == 60)
        let ecart = b.ecart
        #expect(ecart == 60)
        let record = b.record
        #expect(record)
        for n in b.trophees {
            let date = try #require(dates[n.cle], "\(n.cle)")
            let dansLaSemaine = date >= d0
            #expect(dansLaSemaine, "\(n.cle)")
        }
    }

    @Test func uneSemaineVideNeFaitPasDeBilanEtLaPremiereNEstPasUnRecord() throws {
        let vide = BilanSemaine.precedente(d0.plus(jours: 30), minutes: jours(3), dates: [:])
        #expect(vide == nil)
        let b = try #require(BilanSemaine.precedente(d0.plus(jours: 7), minutes: jours(3), dates: [:]))
        let record = b.record
        #expect(!record)
        let precedente = b.precedente
        #expect(precedente == 0)
    }

    @Test func leRejeuIncrementalRendLesMemesNiveauxQueLeCalculComplet() throws {
        let exempt: (JourCivil) -> Bool = { $0.jourDeSemaine == 7 }
        let debut = JourCivil.du("2025-03-01")
        var m: [JourCivil: Int] = [:]
        var notes = Set<JourCivil>()
        for i in 0..<400 {
            let d = debut.plus(jours: i)
            if !exempt(d) && (i * 37) % 11 != 3 && !(121...131).contains(i) { m[d] = 5 + (i * 13) % 70 }
            if i % 9 == 0 { notes.insert(d) }
        }
        let dates = Trophees.datesGain(m, notes, exempt: exempt)
        let p = Trophees.Pratique(minutes: m, notes: notes.count,
                                  meilleureSerie: Plaque.meilleureSerie(Set(m.keys), exempt: exempt))
        let gagnes = Set(Trophees.gagnes(p).map { $0.cle })
        let datees = Set(dates.keys)
        #expect(gagnes == datees)
        for (cle, d) in dates {
            let trouve = Trophees.chemin.first(where: { $0.cle == cle })
            let n = try #require(trouve, "\(cle)")
            let avant = m.filter { $0.key < d }
            var notesAvant = 0
            for jour in notes where jour < d { notesAvant += 1 }
            let pAvant = Trophees.Pratique(minutes: avant, notes: notesAvant,
                                           meilleureSerie: Plaque.meilleureSerie(Set(avant.keys), exempt: exempt))
            let dejaGagne = Trophees.gagne(pAvant, n)
            #expect(!dejaGagne, "\(cle) déjà gagné avant \(d.iso)")
        }
    }

    @Test func unJourValideA0MinCompteCommeUnJourDePratique() {
        // « Terminer » avant la première minute valide le jour : la série le compte, les trophées aussi (audit du 16/10).
        let m = [d0: 0]
        let nombreDeJours = Trophees.valeur(Trophees.Pratique(minutes: m, notes: 0, meilleureSerie: 1), .jours)
        #expect(nombreDeJours == 1)
        let dates = Trophees.datesGain(m, []) { _ in false }
        let premierPas = dates["premier_pas:1"]
        #expect(premierPas == d0)
    }
}
