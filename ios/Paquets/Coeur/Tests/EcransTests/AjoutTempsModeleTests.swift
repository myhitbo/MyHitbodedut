import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Ajouter du temps à un jour passé (AjoutTemps.kt, DureeSeance.kt) : le critère de la feuille de route,
/// « ajouter du temps à un jour passé suit AjoutTemps.possible » ; ce que montrent les trois fenêtres ; ce
/// qu'une durée choisie inscrit, retient et demande au système. La règle elle-même (AjoutTemps.possible,
/// Store.addSession, DureeSeance.lire) est jugée dans CoeurTests.
///
/// Restent au test d'interface : le titre du jour écrit en entier dans la langue de l'app, le champ numérique
/// prérempli et tout sélectionné, le message bref, la case de la bande qui bascule sur sa durée (« Montrer la
/// durée »), le bouton du calendrier.
@Suite("Modèle de l'ajout de temps")
@MainActor
struct AjoutTempsModeleTests {

    /// Jeudi 12 novembre 2026, à midi, en UTC.
    static let aujourdhui = "2026-11-12"

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    static func horloge() throws -> HorlogeFixe {
        let date = try jour(aujourdhui)
        return HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc)
    }

    private struct Banc {
        let modele: AjoutTempsModele?
        let magasin: Magasin
        let persistance: PersistanceEnMemoire
        let systeme: AjoutTempsSystemeFaux
    }

    private func fabriquer(_ iso: String, journal: Journal = Journal(), reglages: Reglages = Reglages(),
                           montrer: Bool = false) throws -> Banc {
        let enregistrement = Enregistrement(journal: journal, reglages: reglages)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let systeme = AjoutTempsSystemeFaux()
        let horloge = try Self.horloge()
        let date = try Self.jour(iso)
        let modele = AjoutTempsModele(magasin: magasin, horloge: horloge, systeme: systeme, date: date, montrer: montrer)
        return Banc(modele: modele, magasin: magasin, persistance: persistance, systeme: systeme)
    }

    // MARK: AjoutTemps.possible

    @Test func onAjouteDuTempsJusquAAujourdhuiJamaisAUnJourAVenir() throws {
        let passe = try fabriquer("2026-11-01").modele != nil
        #expect(passe)
        let ancien = try fabriquer("2020-02-29").modele != nil
        #expect(ancien)
        let aujourdhui = try fabriquer(Self.aujourdhui).modele != nil
        #expect(aujourdhui)
        let demain = try fabriquer("2026-11-13").modele != nil
        #expect(!demain)
        let horloge = try Self.horloge()
        let oui = try AjoutTempsModele.possible(Self.jour("2026-11-12"), horloge: horloge)
        #expect(oui)
        let non = try AjoutTempsModele.possible(Self.jour("2026-11-13"), horloge: horloge)
        #expect(!non)
    }

    // MARK: Le jour

    @Test func unJourSansRienLeDit() throws {
        let banc = try fabriquer("2026-11-10", montrer: true)
        let modele = try #require(banc.modele)
        #expect(modele.etape == .jour)
        #expect(modele.minutesFaites == nil)
        #expect(modele.message == Libelle("jour_rien"))
        // « Montrer la durée » n'a de sens que pour un jour fait.
        #expect(!modele.montrerDuree)
        modele.montrer()
        #expect(modele.etape == .jour)
        #expect(modele.issue == nil)
        #expect(modele.boutonAjouter == Libelle("jour_ajouter_temps"))
        #expect(modele.boutonRetour == Libelle("action_back"))
    }

    @Test func unJourFaitDitSaDureeEtProposeDeLaMontrer() throws {
        var journal = Journal()
        try journal.addSession(minutes: 20, date: Self.jour("2026-11-10"))
        let banc = try fabriquer("2026-11-10", journal: journal, montrer: true)
        let modele = try #require(banc.modele)
        #expect(modele.minutesFaites == 20)
        #expect(modele.message == Libelle("jour_fait", .libelle(Libelle("duration_minutes", .entier(20)))))
        #expect(modele.montrerDuree)
        modele.montrer()
        #expect(modele.etape == nil)
        #expect(modele.issue == .montrer)
    }

    @Test func leCalendrierNeProposePasDeMontrerLaDuree() throws {
        var journal = Journal()
        try journal.addSession(minutes: 20, date: Self.jour("2026-11-10"))
        let banc = try fabriquer("2026-11-10", journal: journal)
        let modele = try #require(banc.modele)
        #expect(!modele.montrerDuree)
    }

    @Test func uneNoteSeuleNEstPasUnJourFait() throws {
        var journal = Journal()
        try journal.setNote(date: Self.jour("2026-11-10"), note: "Une idée")
        let banc = try fabriquer("2026-11-10", journal: journal, montrer: true)
        let modele = try #require(banc.modele)
        #expect(modele.minutesFaites == nil)
        #expect(modele.message == Libelle("jour_rien"))
        #expect(!modele.montrerDuree)
    }

    @Test func retourFermeSansRienInscrire() async throws {
        let banc = try fabriquer("2026-11-10")
        let modele = try #require(banc.modele)
        modele.retour()
        #expect(modele.etape == nil)
        #expect(modele.issue == .fermee)
        #expect(banc.magasin.journal.jours.isEmpty)
        let ecritures = await banc.persistance.ecrituresJournal
        #expect(ecritures == 0)
    }

    // MARK: La durée

    @Test func lesDureesSontCellesDeLaSeancePuisLaDureeReglable() throws {
        let banc = try fabriquer("2026-11-10")
        let modele = try #require(banc.modele)
        modele.ajouterTemps()
        #expect(modele.etape == .durees)
        #expect(modele.titreDurees == Libelle("offline_how_long"))
        let minutes = modele.durees.map(\.minutes)
        #expect(minutes == [5, 10, 15, 30, 60, 90, nil])
        let libelles = modele.durees.map(\.libelle)
        #expect(libelles == [
            Libelle("duration_minutes", .entier(5)),
            Libelle("duration_minutes", .entier(10)),
            Libelle("duration_minutes", .entier(15)),
            Libelle("duration_minutes", .entier(30)),
            Libelle("duration_hours", .entier(1)),
            Libelle("duration_hours_minutes", .entier(1), .entier(30)),
            Libelle("duration_custom"),
        ])
    }

    @Test func uneDureeChoisieSAjouteAuJourDejaFait() async throws {
        let date = try Self.jour("2026-11-10")
        var journal = Journal()
        journal.addSession(minutes: 20, note: "Dehors", theme: "famille", date: date)
        let banc = try fabriquer("2026-11-10", journal: journal, montrer: true)
        let modele = try #require(banc.modele)
        modele.ajouterTemps()
        let premiereDeTrente = modele.durees.first { $0.minutes == 30 }
        let trente = try #require(premiereDeTrente)
        try await modele.choisir(trente)

        let journee = try #require(banc.magasin.journal.record(date))
        #expect(journee.minutes == 50)
        // La note et les sujets du jour restent ; aucun sujet n'est ajouté.
        #expect(journee.note == "Dehors")
        #expect(journee.themes == ["famille"])
        #expect(modele.etape == nil)
        #expect(modele.issue == .ajoute(minutes: 30))
        #expect(modele.confirmation == Libelle("jour_ajoute", .libelle(Libelle("duration_minutes", .entier(30)))))
        modele.confirmationVue()
        #expect(modele.confirmation == nil)
        // Ce qui est neuf est retenu comme fêté, sans notification : l'app est ouverte.
        let paliers = banc.magasin.reglages.paliersNotifies
        #expect(paliers != nil)
        let trophees = banc.magasin.reglages.tropheesNotifies
        #expect(trophees != nil)
        // Ce sont les marques et les trophées du journal après l'ajout (Celebrations.marquerNotifies).
        let horloge = try Self.horloge()
        let journalFinal = banc.magasin.journal
        let reglagesFinals = banc.magasin.reglages
        let telephone = horloge.fuseau.identifiant
        let attendu = Celebrations.marquerNotifies(
            Store.bilan(journal: journalFinal, reglages: reglagesFinals, aujourdhui: horloge.aujourdhui,
                        fuseauTelephone: telephone),
            Store.pratique(journal: journalFinal, reglages: reglagesFinals, aujourdhui: horloge.aujourdhui,
                           fuseauTelephone: telephone),
            paliersNotifies: nil, tropheesNotifies: nil)
        #expect(paliers == attendu.marques)
        #expect(trophees == attendu.trophees)
        let widgets = await banc.systeme.widgetsRafraichis
        #expect(widgets == 1)
        let rappels = await banc.systeme.rappelsRetires
        #expect(rappels == 1)
        let ecritures = await banc.persistance.ecrituresJournal
        #expect(ecritures == 1)
        let ecrituresReglages = await banc.persistance.ecrituresReglages
        #expect(ecrituresReglages == 1)
    }

    @Test func unJourPasseSansRienDevientFait() async throws {
        let date = try Self.jour("2026-11-01")
        var journal = Journal()
        journal.setNote(date: date, note: "Une idée")
        let banc = try fabriquer("2026-11-01", journal: journal)
        let modele = try #require(banc.modele)
        modele.ajouterTemps()
        let cinq = try #require(modele.durees.first)
        try await modele.choisir(cinq)
        let journee = try #require(banc.magasin.journal.record(date))
        #expect(journee.faite)
        #expect(journee.minutes == 5)
        #expect(journee.note == "Une idée")
        #expect(banc.magasin.journal.isDone(date))
    }

    @Test func laDureeReglableEstPreRempliePuisRameneeEntre1Et240() async throws {
        var reglages = Reglages()
        reglages.setTargetMinutes(25)
        let date = try Self.jour("2026-11-10")
        let banc = try fabriquer("2026-11-10", reglages: reglages)
        let modele = try #require(banc.modele)
        modele.ajouterTemps()
        let reglable = try #require(modele.durees.last)
        try await modele.choisir(reglable)
        #expect(modele.etape == .saisie)
        #expect(modele.saisie == "25")
        #expect(modele.titreSaisie == Libelle("duration_custom_title"))
        #expect(modele.indicationSaisie == Libelle("duration_custom_hint"))
        modele.saisie = " 500 "
        try await modele.validerSaisie()
        let minutes = banc.magasin.journal.record(date)?.minutes
        #expect(minutes == 240)
        #expect(modele.issue == .ajoute(minutes: 240))
    }

    @Test func uneSaisieQuiNEstPasUnNombreFermeSansRienInscrire() async throws {
        let banc = try fabriquer("2026-11-10")
        let modele = try #require(banc.modele)
        modele.ajouterTemps()
        let reglable = try #require(modele.durees.last)
        try await modele.choisir(reglable)
        modele.saisie = "un quart d'heure"
        try await modele.validerSaisie()
        #expect(modele.etape == nil)
        #expect(modele.issue == .fermee)
        #expect(modele.confirmation == nil)
        #expect(banc.magasin.journal.jours.isEmpty)
        let ecritures = await banc.persistance.ecrituresJournal
        #expect(ecritures == 0)
        let widgets = await banc.systeme.widgetsRafraichis
        #expect(widgets == 0)
    }

    @Test func lesFenetresSeSuiventDansLOrdre() async throws {
        let banc = try fabriquer("2026-11-10")
        let modele = try #require(banc.modele)
        // Sans passer par la liste, rien ne s'inscrit.
        let premiereDeTrente = modele.durees.first { $0.minutes == 30 }
        let trente = try #require(premiereDeTrente)
        try await modele.choisir(trente)
        #expect(modele.etape == .jour)
        try await modele.validerSaisie()
        #expect(modele.etape == .jour)
        #expect(banc.magasin.journal.jours.isEmpty)
    }

    @Test func uneEcritureRefuseeNInscritLeTempsQuUneFois() async throws {
        let date = try Self.jour("2026-11-10")
        let banc = try fabriquer("2026-11-10")
        let modele = try #require(banc.modele)
        await banc.persistance.faireEchouer(true)
        modele.ajouterTemps()
        let cinq = try #require(modele.durees.first)
        var refuse = false
        do {
            try await modele.choisir(cinq)
        } catch {
            refuse = true
        }
        // L'erreur remonte, mais le changement reste dans le Magasin : les fenêtres se ferment, pour qu'on ne
        // choisisse pas une seconde fois les mêmes minutes.
        #expect(refuse)
        #expect(modele.etape == nil)
        #expect(modele.issue == .ajoute(minutes: 5))
        let minutes = banc.magasin.journal.record(date)?.minutes
        #expect(minutes == 5)
        // Choisir encore ne fait rien : les fenêtres sont fermées.
        try await modele.choisir(cinq)
        let encore = banc.magasin.journal.record(date)?.minutes
        #expect(encore == 5)
        let widgets = await banc.systeme.widgetsRafraichis
        #expect(widgets == 1)
    }
}
