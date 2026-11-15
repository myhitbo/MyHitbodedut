import Foundation
import Testing
@testable import Coeur

/// JaugeSemaineTest d'Android, porté : la jauge de l'accueil, les jours faits sur les jours dus. Puis la semaine
/// elle-même (`Store.currentWeek`), du dimanche au samedi.
@Suite("JaugeSemaine")
struct JaugeSemaineTests {

    private let dimanche = JourCivil.du("2026-09-27")

    /// « f » faite, « x » exemptée, « a » à venir.
    private func semaine(_ etats: String...) -> [CaseSemaine] {
        etats.enumerated().map { i, e in
            CaseSemaine(date: dimanche.plus(jours: i), faite: e.contains("f"), exemptee: e.contains("x"), chabbat: i == 6,
                        aVenir: e.contains("a"))
        }
    }

    @Test func leChabbatChomeNeComptePasParmiLesJoursDus() {
        let p = JaugeSemaine.progression(semaine("f", "f", "", "a", "a", "a", "x"))
        #expect(p.faits == 2)
        #expect(p.dus == 6)
        #expect(abs(p.fraction - Float(2) / Float(6)) <= 0.0001)
    }

    @Test func uneSeanceFaiteUnJourExempteCompteQuandMeme() {
        let p = JaugeSemaine.progression(semaine("f", "f", "f", "f", "f", "f", "fx"))
        #expect(p.faits == 7)
        #expect(p.dus == 7)
        #expect(abs(p.fraction - 1) <= 0.0001)
    }

    @Test func uneSemaineSansJourDuResteVide() {
        let p = JaugeSemaine.progression(semaine("x", "x", "x", "x", "x", "x", "x"))
        #expect(p.fraction == 0)
    }

    /// `Store.currentWeek` : du dimanche au samedi, le samedi en fin de bande, demain à venir.
    @Test func laSemaineVaDuDimancheAuSamedi() {
        let mercredi = JourCivil.du("2026-09-30")
        let faits: Set<JourCivil> = [.du("2026-09-27"), .du("2026-09-29"), .du("2026-10-03")]
        let jours = Pratique.semaine(aujourdhui: mercredi, faits: faits) { $0.jourDeSemaine == 7 }
        let dates = jours.map { $0.date.iso }
        #expect(dates == ["2026-09-27", "2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03"])
        let faites = jours.map { $0.faite }
        #expect(faites == [true, false, true, false, false, false, true])
        let chabbats = jours.map { $0.chabbat }
        #expect(chabbats == [false, false, false, false, false, false, true])
        let exemptees = jours.map { $0.exemptee }
        #expect(exemptees == chabbats)
        let aVenir = jours.map { $0.aVenir }
        #expect(aVenir == [false, false, false, false, true, true, true])
        let p = JaugeSemaine.progression(jours)
        #expect(p == JaugeSemaine.Progression(faits: 3, dus: 7))
    }
}
