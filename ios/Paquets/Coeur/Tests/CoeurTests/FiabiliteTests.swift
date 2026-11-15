import Testing
@testable import Coeur

/// Les corrections de la revue du 29/09 sur la boucle de chaque jour (FiabiliteTest.kt) : ce qui s'inscrit à
/// la fin d'une séance (SessionRule), ce qu'une note peut valider, les vraies dates du journal, la durée
/// par défaut. Les quatre cas de l'heure des rappels (ReminderRule.prochainDeclenchement) sont portés avec
/// leur règle (ReminderRuleTests) ; les quatre branchements (le bouton « Commencer » du rappel, le
/// manifeste, les layouts des cartes, les barres du système) lisent le code d'Android et restent à Android.
@Suite("Fiabilité")
struct FiabiliteTests {

    private let minute: Int64 = 60_000
    private let debut: Int64 = 1_800_000_000_000

    // MARK: Minutes inscrites

    @Test func uneSeanceMinuteeNeCompteJamaisPlusQueSaDuree() {
        let fin = debut + 20 * minute
        // Fin constatée 40 minutes trop tard (écran éteint, service tué).
        let tard = SessionRule.minutesAInscrire(debutMillis: debut, finMillis: fin, maintenant: fin + 40 * minute)
        #expect(tard == 20)
        // Constatée à l'heure.
        let aLHeure = SessionRule.minutesAInscrire(debutMillis: debut, finMillis: fin, maintenant: fin)
        #expect(aLHeure == 20)
    }

    @Test func uneSeanceArreteeAvantSonTermeCompteLeTempsPasse() {
        let fin = debut + 20 * minute
        let douze = SessionRule.minutesAInscrire(debutMillis: debut, finMillis: fin, maintenant: debut + 12 * minute + 30_000)
        #expect(douze == 12)
        let rien = SessionRule.minutesAInscrire(debutMillis: debut, finMillis: fin, maintenant: debut + 30_000)
        #expect(rien == 0)
    }

    @Test func uneSeanceOuverteOublieeNeComptePasUneJournee() {
        let trenteCinq = SessionRule.minutesAInscrire(debutMillis: debut, finMillis: 0, maintenant: debut + 35 * minute)
        #expect(trenteCinq == 35)
        let plafond = SessionRule.minutesAInscrire(debutMillis: debut, finMillis: 0, maintenant: debut + 20 * 60 * minute)
        #expect(plafond == SessionRule.plafondOuverte)
    }

    @Test func sansDebutRienNeSInscrit() {
        let rien = SessionRule.minutesAInscrire(debutMillis: 0, finMillis: 0, maintenant: debut)
        #expect(rien == 0)
    }

    @Test func uneSeanceOrphelineEstEchueASonTermeOuAuPlafond() {
        let fin = debut + 20 * minute
        let avant = SessionRule.estEchue(debutMillis: debut, finMillis: fin, duree: 20, maintenant: fin - 1)
        #expect(!avant)
        let auTerme = SessionRule.estEchue(debutMillis: debut, finMillis: fin, duree: 20, maintenant: fin)
        #expect(auTerme)
        let ouverteUneHeure = SessionRule.estEchue(debutMillis: debut, finMillis: 0, duree: SessionRule.ouverte,
                                                   maintenant: debut + 60 * minute)
        #expect(!ouverteUneHeure)
        let plafond = debut + Int64(SessionRule.plafondOuverte) * minute
        let ouverteAuPlafond = SessionRule.estEchue(debutMillis: debut, finMillis: 0, duree: SessionRule.ouverte, maintenant: plafond)
        #expect(ouverteAuPlafond)
        let sansSeance = SessionRule.estEchue(debutMillis: 0, finMillis: 0, duree: 0, maintenant: debut)
        #expect(!sansSeance)
    }

    // MARK: Journées

    @Test func uneNoteSeuleNeFaitPasLaJournee() {
        let seule = Journee(minutes: 0, note: "une pensée", noteSeule: true).faite
        #expect(!seule)
        let declaree = Journee(minutes: 0, note: "", noteSeule: false).faite
        #expect(declaree)
        let faite = Journee(minutes: 20, note: "").faite
        #expect(faite)
    }

    @Test func seulesLesVraiesDatesEntrentAuJournal() {
        let vraie = Store.dateValide("2026-09-29")
        #expect(vraie != nil)
        for cle in ["2026-13-45", "2026-2-3", "2026-02-30", "x", ""] {
            let date = Store.dateValide(cle)
            #expect(date == nil, "« \(cle) » ne doit pas être acceptée")
        }
    }

    @Test func quinzeMinutesParDefautCommeLeConseilleLApplication() {
        let duree = Store.defaultTarget
        #expect(duree == 15)
    }
}
