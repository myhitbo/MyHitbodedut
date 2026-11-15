import Foundation
import Testing
@testable import Coeur

/// FiabiliteTest d'Android, porté : les corrections de la revue du 29/09 sur la boucle de chaque jour — ce qui
/// s'inscrit à la fin d'une séance, l'heure des rappels aux changements d'heure, ce qu'une note peut valider, les
/// seules vraies dates, la durée par défaut. Les quatre tests de « branchements » lisent le code, le manifeste et
/// les layouts d'Android (bouton du rappel, récepteurs, taille des cartes, barres du système) : ils y restent.
@Suite("Fiabilite")
struct FiabiliteTests {

    private let minute: Int64 = 60_000
    private let debut: Int64 = 1_800_000_000_000

    // MARK: Minutes inscrites

    @Test func uneSeanceMinuteeNeCompteJamaisPlusQueSaDuree() {
        let fin = debut + 20 * minute
        // Fin constatée 40 minutes trop tard (écran éteint, service tué).
        #expect(SessionRule.minutesAInscrire(debut: debut, fin: fin, maintenant: fin + 40 * minute) == 20)
        // Constatée à l'heure.
        #expect(SessionRule.minutesAInscrire(debut: debut, fin: fin, maintenant: fin) == 20)
    }

    @Test func uneSeanceArreteeAvantSonTermeCompteLeTempsPasse() {
        let fin = debut + 20 * minute
        #expect(SessionRule.minutesAInscrire(debut: debut, fin: fin, maintenant: debut + 12 * minute + 30_000) == 12)
        #expect(SessionRule.minutesAInscrire(debut: debut, fin: fin, maintenant: debut + 30_000) == 0)
    }

    @Test func uneSeanceOuverteOublieeNeComptePasUneJournee() {
        #expect(SessionRule.minutesAInscrire(debut: debut, fin: 0, maintenant: debut + 35 * minute) == 35)
        #expect(SessionRule.minutesAInscrire(debut: debut, fin: 0, maintenant: debut + 20 * 60 * minute) == SessionRule.plafondOuverte)
    }

    @Test func sansDebutRienNeSInscrit() {
        #expect(SessionRule.minutesAInscrire(debut: 0, fin: 0, maintenant: debut) == 0)
    }

    @Test func uneSeanceOrphelineEstEchueASonTermeOuAuPlafond() {
        let fin = debut + 20 * minute
        #expect(!SessionRule.estEchue(debut: debut, fin: fin, duree: 20, maintenant: fin - 1))
        #expect(SessionRule.estEchue(debut: debut, fin: fin, duree: 20, maintenant: fin))
        #expect(!SessionRule.estEchue(debut: debut, fin: 0, duree: SessionRule.ouverte, maintenant: debut + 60 * minute))
        #expect(SessionRule.estEchue(debut: debut, fin: 0, duree: SessionRule.ouverte,
                                     maintenant: debut + Int64(SessionRule.plafondOuverte) * minute))
        #expect(!SessionRule.estEchue(debut: 0, fin: 0, duree: 0, maintenant: debut))
    }

    // MARK: Heure des rappels

    private func a(_ annee: Int, _ mois: Int, _ jour: Int, _ h: Int, _ m: Int = 0) throws -> DateHeureZonee {
        let paris = try #require(Fuseau("Europe/Paris"))
        let date = try #require(JourCivil(annee: annee, mois: mois, jour: jour))
        return DateHeureZonee(DateHeure(date, heure: h, minute: m), fuseau: paris)
    }

    @Test func leProchainRappelUnJourOrdinaire() throws {
        let maintenant = try a(2026, 9, 29, 6, 30)
        let sept = try a(2026, 9, 29, 7)
        #expect(ReminderRule.prochainDeclenchement(maintenant, heures: [7 * 60]) == sept)
        // Toutes passées : la première du lendemain.
        let soir = try a(2026, 9, 29, 21)
        let lendemain = try a(2026, 9, 30, 7)
        #expect(ReminderRule.prochainDeclenchement(soir, heures: [7 * 60, 20 * 60]) == lendemain)
        #expect(ReminderRule.prochainDeclenchement(maintenant, heures: []) == nil)
    }

    /// Passage à l'heure d'été (29/03/2026 à Paris) : la nuit dure une heure de moins. Ajouter 9 heures de minutes
    /// à 22 h faisait sonner à 8 h.
    @Test func leRappelGardeSonHeureAuPassageALHeureDEte() throws {
        let veille = try a(2026, 3, 28, 22)
        let rappel = try #require(ReminderRule.prochainDeclenchement(veille, heures: [7 * 60]))
        #expect(rappel.civile.heure == 7)
        #expect(rappel.jour.jour == 29)
        #expect(rappel.millis - veille.millis == 8 * 3_600_000)
    }

    /// Retour à l'heure d'hiver (25/10/2026) : la nuit dure une heure de plus.
    @Test func leRappelGardeSonHeureAuRetourALHeureDHiver() throws {
        let veille = try a(2026, 10, 24, 22)
        let rappel = try #require(ReminderRule.prochainDeclenchement(veille, heures: [7 * 60]))
        #expect(rappel.civile.heure == 7)
        #expect(rappel.millis - veille.millis == 10 * 3_600_000)
    }

    @Test func uneHeureQuiNExistePasCeJourLaEstRepoussee() throws {
        let veille = try a(2026, 3, 28, 22)
        let rappel = try #require(ReminderRule.prochainDeclenchement(veille, heures: [2 * 60 + 30]))
        #expect(rappel.jour.jour == 29)
        #expect(rappel.civile.heure == 3)
        #expect(rappel.civile.minute == 30)
    }

    // MARK: Journées

    @Test func uneNoteSeuleNeFaitPasLaJournee() {
        #expect(!Journee(minutes: 0, note: "une pensée", noteSeule: true).faite)
        #expect(Journee(minutes: 0, note: "", noteSeule: false).faite)
        #expect(Journee(minutes: 20, note: "").faite)
    }

    @Test func seulesLesVraiesDatesEntrentAuJournal() {
        #expect(JourCivil(iso: "2026-09-29") != nil)
        for texte in ["2026-13-45", "2026-2-3", "2026-02-30", "x", ""] {
            #expect(JourCivil(iso: texte) == nil, "« \(texte) » ne doit pas être acceptée")
        }
    }

    @Test func quinzeMinutesParDefautCommeLeConseilleLApplication() {
        #expect(Pratique.dureeParDefaut == 15)
        #expect(Reglages(enIsrael: false).duree == Pratique.dureeParDefaut)
    }
}
