import Testing
@testable import Coeur

/// JourCorrigeTest d'Android, porté (FDONNEES-04) : corriger ou retirer une journée inscrite par erreur. Le
/// dernier cas d'Android, qui lit le dialogue d'AjoutTemps.kt, viendra avec l'écran.
@Suite("Journée corrigée")
struct JourCorrigeTests {
    private let jour = Journee(minutes: 200, note: "", themes: ["famille"])

    @Test func corrigerRemplaceLesMinutesAuLieuDeLesAjouter() throws {
        let c = try #require(Pratique.jourCorrige(jour, minutes: 20))
        #expect(c.minutes == 20 && c.themes == ["famille"] && c.faite)
        #expect(Pratique.jourCorrige(jour, minutes: 5000)?.minutes == 1440)
    }

    @Test func retirerUneJourneeSansNoteLaFaitDisparaitre() {
        #expect(Pratique.jourCorrige(jour, minutes: 0) == nil)
        #expect(Pratique.jourCorrige(nil, minutes: 20) == nil)
    }

    @Test func retirerUneJourneeGardeSaNoteSansValiderLeJour() throws {
        var avecNote = jour
        avecNote.note = "ma note"
        let c = try #require(Pratique.jourCorrige(avecNote, minutes: 0))
        #expect(c.note == "ma note" && c.minutes == 0 && c.noteSeule && !c.faite && c.themes.isEmpty)
    }

    @Test func corrigerUnJourNonFaitNeChangeRien() {
        let date = JourCivil.du("2026-11-10")
        var journal = Journal(jours: [date: Journee(minutes: 0, note: "une pensée", noteSeule: true)])
        Pratique.corrigerJour(&journal, date, minutes: 30)
        #expect(journal.jours[date]?.noteSeule == true)
        journal.jours[date] = jour
        Pratique.corrigerJour(&journal, date, minutes: 0)
        #expect(journal.jours[date] == nil)
    }

    /// FDONNEES-05 : un samedi d'avant l'arrêt de la pause du Chabbat reste exempté, ceux d'après non.
    @Test func lExemptionSuitLeReglageEnVigueurCeJourLa() {
        var r = Reglages(enIsrael: false)
        r.changerPauseShabbat(false, aujourdhui: .du("2026-11-10"))
        #expect(Pratique.exempte(.du("2026-11-07"), r), "samedi d'avant le changement")
        #expect(!Pratique.exempte(.du("2026-11-14"), r), "samedi d'après")
        r.joursPause.insert(.du("2026-11-14"))
        #expect(Pratique.exempte(.du("2026-11-14"), r), "une pause du jour l'emporte")
    }
}
