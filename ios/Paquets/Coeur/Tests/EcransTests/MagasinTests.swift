import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le Magasin : ce qu'il charge, ce qu'un changement montre aussitôt, ce qu'il écrit et dans quel ordre, ce
/// qu'il fait d'une écriture refusée. Sur la persistance en mémoire, qui compte ses écritures.
@Suite("Magasin")
@MainActor
struct MagasinTests {

    private let jour = JourCivil(annee: 2026, mois: 11, jour: 13)

    private func unJour() throws -> JourCivil {
        try #require(jour)
    }

    @Test func leMagasinChargeCeQueLaPersistanceGarde() async throws {
        let date = try unJour()
        var journal = Journal()
        journal.setFirstName("  David  ")
        journal[date] = Journee(minutes: 20, note: "Merci")
        var reglages = Reglages()
        reglages.setTargetMinutes(25)
        let persistance = PersistanceEnMemoire(Enregistrement(journal: journal, reglages: reglages))
        let magasin = try await Magasin.charger(persistance)
        #expect(magasin.journal.firstName == "David")
        let minutes = magasin.journal.record(date)?.minutes
        #expect(minutes == 20)
        #expect(magasin.reglages.targetMinutes == 25)
        // Charger n'écrit rien.
        let ecritures = await persistance.ecrituresJournal + persistance.ecrituresReglages
        #expect(ecritures == 0)
    }

    @Test func unChargementRefuseSeRend() async {
        let persistance = PersistanceEnMemoire()
        await persistance.faireEchouer(true)
        var refuse = false
        do {
            _ = try await Magasin.charger(persistance)
        } catch is PersistanceEnMemoire.Echec {
            refuse = true
        } catch {
            Issue.record("erreur inattendue : \(error)")
        }
        #expect(refuse)
    }

    @Test func modifierLeJournalLeMontrePuisLEcrit() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        let date = try unJour()
        try await magasin.modifierJournal { $0[date] = Journee(minutes: 12, note: "Une note") }
        let montree = magasin.journal.record(date)
        #expect(montree == Journee(minutes: 12, note: "Une note"))
        let ecrit = await persistance.enregistrement.journal
        #expect(ecrit == magasin.journal)
        let journal = await persistance.ecrituresJournal
        #expect(journal == 1)
        // Le journal seul : les réglages ne sont pas réécrits.
        let reglages = await persistance.ecrituresReglages
        #expect(reglages == 0)
    }

    @Test func modifierLesReglagesRendCeQueRendLeChangement() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        // Store.inIsrael : le premier accès fige la valeur du fuseau, un voyage ne la change plus.
        let fige: Bool = try await magasin.modifierReglages { $0.figeInIsrael(fuseauTelephone: "Asia/Jerusalem") }
        #expect(fige)
        let enVoyage = magasin.reglages.inIsrael(fuseauTelephone: "Europe/Paris")
        #expect(enVoyage)
        let ecrits = await persistance.enregistrement.reglages
        #expect(ecrits == magasin.reglages)
        let reglages = await persistance.ecrituresReglages
        #expect(reglages == 1)
        let journal = await persistance.ecrituresJournal
        #expect(journal == 0)
    }

    @Test func unChangementQuiNeChangeRienNEcritRien() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        try await magasin.modifierReglages { $0.setTargetMinutes(20) }
        try await magasin.modifierReglages { $0.setTargetMinutes(20) }
        let israel: Bool = try await magasin.modifierReglages { $0.figeInIsrael(fuseauTelephone: "Europe/Paris") }
        #expect(!israel)
        // Figée, la valeur ne s'écrit plus.
        try await magasin.modifierReglages { $0.figeInIsrael(fuseauTelephone: "Asia/Jerusalem") }
        let ecritures = await persistance.ecrituresReglages
        #expect(ecritures == 2)
        #expect(magasin.reglages.targetMinutes == 20)
    }

    @Test func lesEcrituresSuiventLOrdreDesChangements() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        var taches: [Task<Void, any Error>] = []
        for minutes in [10, 20, 30, 40, 50] {
            let tache = Task<Void, any Error> {
                try await magasin.modifierReglages { $0.setTargetMinutes(minutes) }
            }
            taches.append(tache)
        }
        for tache in taches {
            try await tache.value
        }
        // Le dernier écrit est le dernier fait, quel que soit l'ordre où les tâches ont couru.
        let ecrits = await persistance.enregistrement.reglages
        #expect(ecrits == magasin.reglages)
        let ecritures = await persistance.ecrituresReglages
        #expect(ecritures == 5)
    }

    @Test func uneEcritureRefuseeSeRendEtLeChangementResteEnMemoire() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        await persistance.faireEchouer(true)
        var refuse = false
        do {
            try await magasin.modifierJournal { $0.setFirstName("Rivka") }
        } catch is PersistanceEnMemoire.Echec {
            refuse = true
        }
        #expect(refuse)
        #expect(magasin.journal.firstName == "Rivka")
        let ecrit = await persistance.enregistrement.journal.firstName
        #expect(ecrit == "")
        // Le disque revenu, l'écriture suivante emporte aussi le changement d'avant.
        await persistance.faireEchouer(false)
        let date = try unJour()
        try await magasin.modifierJournal { $0[date] = Journee(minutes: 5, note: "") }
        let journal = await persistance.enregistrement.journal
        #expect(journal.firstName == "Rivka")
        let minutes = journal.record(date)?.minutes
        #expect(minutes == 5)
    }

    @Test func rechargerRelitCeQueLaPersistanceGarde() async throws {
        let persistance = PersistanceEnMemoire()
        let premier = Magasin(persistance: persistance)
        let second = Magasin(persistance: persistance)
        try await second.modifierJournal { $0.setFirstName("Yossef") }
        try await second.modifierReglages { $0.setOuverture(.zmanim) }
        #expect(premier.journal.firstName == "")
        try await premier.recharger()
        #expect(premier.journal == second.journal)
        #expect(premier.reglages == second.reglages)
        #expect(premier.reglages.ouverture == .zmanim)
    }

    @Test func unMagasinEnMemoire() async throws {
        var reglages = Reglages()
        reglages.setAllumage(40)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        #expect(magasin.reglages.allumage == 40)
        try await magasin.modifierReglages { $0.setAllumage(30) }
        #expect(magasin.reglages.allumage == 30)
    }

    @Test func lesFichiersGardentLeJournalEtLesReglagesDUnLancementALAutre() async throws {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent("MagasinTests-" + UUID().uuidString, isDirectory: true)
        defer { _ = try? FileManager.default.removeItem(at: dossier) }
        let date = try unJour()
        let premier = try await Magasin.charger(PersistanceFichiers(dossier: dossier))
        let vide = premier.journal.dates.isEmpty
        #expect(vide)
        try await premier.modifierJournal { $0[date] = Journee(minutes: 15, note: "Merci") }
        try await premier.modifierReglages { $0.setTargetMinutes(30) }
        // Un nouveau lancement : un autre dépôt sur le même dossier relit ce que le premier a écrit.
        let second = try await Magasin.charger(PersistanceFichiers(dossier: dossier))
        let journee = second.journal.record(date)
        #expect(journee == Journee(minutes: 15, note: "Merci"))
        #expect(second.reglages.targetMinutes == 30)
        let journal = FileManager.default.fileExists(atPath: dossier.appendingPathComponent(Depot.fichierJournal).path)
        let reglages = FileManager.default.fileExists(atPath: dossier.appendingPathComponent(Depot.fichierReglages).path)
        #expect(journal)
        #expect(reglages)
    }
}
