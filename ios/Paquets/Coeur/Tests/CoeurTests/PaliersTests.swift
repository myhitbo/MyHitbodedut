import Foundation
import Testing
@testable import Coeur

/// PaliersTest d'Android, porté : les paliers d'objectifs (11/10), après chaque palier le suivant.
@Suite("Paliers")
struct PaliersTests {

    @Test func apresSeptJoursDAffileeLePalierSuivantEstQuatorze() {
        let e = Paliers.etat(.serie, 7)
        #expect(e.atteint == 7)
        #expect(e.prochain == 14)
        #expect(e.reste == 7)
        #expect(e.rang == 2)  // 3 et 7
        #expect(Paliers.etat(.serie, 0).prochain == 3)
    }

    @Test func auDelaDeLEchelleLePasContinue() {
        #expect(Paliers.etat(.serie, 400).prochain == 730)
        #expect(Paliers.etat(.cumul, 61000).prochain == 72000)
    }

    @Test func lObjectifQuotidienEstUnPalierDuJour() {
        #expect(Paliers.echelle(.jour, jusqua: 0, objectifJour: 25).contains(25))
        #expect(Paliers.etat(.jour, 21, objectifJour: 25).prochain == 25)
    }

    @Test func lesPeriodesRepartentEtLeMoisEstLeMoisHebreu() throws {
        let aujourdhui = JourCivil.du("2026-10-14")  // mercredi, 3 'Hechvan 5787
        let minutes: [JourCivil: Int] = [
            .du("2026-10-10"): 20,  // samedi précédent : hors semaine, en Tichri
            .du("2026-10-12"): 30,  // 1 'Hechvan
            .du("2026-10-14"): 15,
        ]
        let b = Paliers.Bilan(aujourdhui: aujourdhui, minutes: minutes, serie: 2, debutMoisHebreu: .du("2026-10-12"),
                              objectifJour: 20)
        let etats = Paliers.etats(b)
        var e: [Paliers.Piste: Paliers.Etat] = [:]
        for etat in etats { e[etat.piste] = etat }
        #expect(e[.jour]?.valeur == 15)
        #expect(e[.semaine]?.valeur == 45)
        #expect(e[.mois]?.valeur == 45)
        #expect(e[.cumul]?.valeur == 65)
        #expect(e[.jours]?.valeur == 3)
        // Le jour se fête par date, la série une fois pour toutes.
        let m = Paliers.marques(etats, b)
        #expect(m.contains("jour:2026-10-14:15"))
        let series = m.filter { $0.hasPrefix("serie") }
        #expect(series.isEmpty)  // 2 jours : pas encore 3
        let nouvelles = Set(Paliers.nouveaux(etats, b, vus: []).map { $0.piste })
        #expect(nouvelles == [.jour, .semaine, .cumul, .jours])
        #expect(Paliers.nouveaux(etats, b, vus: m).isEmpty)
    }

    @Test func recordsEtPalierALaUne() throws {
        let minutes: [JourCivil: Int] = [.du("2026-10-04"): 30, .du("2026-10-05"): 40, .du("2026-10-12"): 20]
        let hechvan = JourCivil.du("2026-10-12")
        let r = Paliers.records(minutes) { $0 < hechvan ? "tichri" : "hechvan" }
        #expect(r == Paliers.Records(jour: 40, semaine: 70, mois: 70))
        let une = try #require(Paliers.aLaUne([Paliers.etat(.serie, 6), Paliers.etat(.jour, 5)]))
        #expect(une.piste == .serie)  // 6 sur 3→7 : 75 %, contre 5/10 : 50 %
    }
}
