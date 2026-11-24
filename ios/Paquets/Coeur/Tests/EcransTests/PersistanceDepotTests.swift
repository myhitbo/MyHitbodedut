import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La persistance de l'app sur les fichiers du dépôt (PersistanceDepot.swift) : ce qu'elle lit d'un dossier neuf,
/// ce qu'un magasin y écrit et qu'un autre relit (le relancement de l'app), ce qu'elle fait d'un fichier
/// illisible. Chaque test écrit dans un dossier temporaire qui n'est qu'à lui.
@Suite("Persistance sur le dépôt")
@MainActor
struct PersistanceDepotTests {

    private static func dossierNeuf() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistanceDepotTests-" + UUID().uuidString, isDirectory: true)
    }

    private static func efface(_ dossier: URL) {
        _ = try? FileManager.default.removeItem(at: dossier)
    }

    private static func existe(_ nom: String, dans dossier: URL) -> Bool {
        FileManager.default.fileExists(atPath: dossier.appendingPathComponent(nom).path)
    }

    private func unJour() throws -> JourCivil {
        try #require(JourCivil(annee: 2026, mois: 11, jour: 13))
    }

    @Test func unDossierNeufSeLitVideEtNEcritRien() async throws {
        let dossier = PersistanceDepotTests.dossierNeuf()
        defer { PersistanceDepotTests.efface(dossier) }
        let persistance = PersistanceDepot(dossier: dossier, journalHorsSauvegarde: false)
        let lu = try await persistance.lire()
        #expect(lu == Enregistrement())
        let cree = FileManager.default.fileExists(atPath: dossier.path)
        #expect(!cree)
    }

    @Test func ceQueLeMagasinEcritSeRelitAuRelancement() async throws {
        let dossier = PersistanceDepotTests.dossierNeuf()
        defer { PersistanceDepotTests.efface(dossier) }
        let date = try unJour()

        let magasin = try await Magasin.charger(PersistanceDepot(dossier: dossier, journalHorsSauvegarde: false))
        try await magasin.modifierJournal { journal in
            journal[date] = Journee(minutes: 20, note: "Merci")
            journal.setFirstName("David")
        }
        try await magasin.modifierReglages { $0.setTargetMinutes(25) }
        #expect(PersistanceDepotTests.existe(Depot.fichierJournal, dans: dossier))
        #expect(PersistanceDepotTests.existe(Depot.fichierReglages, dans: dossier))

        // Un second dépôt sur le même dossier : l'app relancée.
        let relu = try await Magasin.charger(PersistanceDepot(dossier: dossier, journalHorsSauvegarde: false))
        #expect(relu.journal == magasin.journal)
        #expect(relu.reglages == magasin.reglages)
        #expect(relu.journal.record(date) == Journee(minutes: 20, note: "Merci"))
        #expect(relu.journal.firstName == "David")
        #expect(relu.reglages.targetMinutes == 25)
    }

    @Test func unJournalIllisibleEstMisDeCoteEtLaLectureRepartDeRien() async throws {
        let dossier = PersistanceDepotTests.dossierNeuf()
        defer { PersistanceDepotTests.efface(dossier) }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true, attributes: nil)
        try Data("ceci n'est pas du JSON".utf8).write(to: dossier.appendingPathComponent(Depot.fichierJournal))

        let persistance = PersistanceDepot(dossier: dossier, journalHorsSauvegarde: false)
        let lu = try await persistance.lire()
        #expect(lu.journal == Journal())
        #expect(PersistanceDepotTests.existe("journal.illisible.json", dans: dossier))
        let copies = await persistance.misDeCote()
        #expect(copies.map(\.lastPathComponent) == ["journal.illisible.json"])

        // La copie survit à la première écriture, qui remplace le fichier illisible.
        let date = try unJour()
        var journal = Journal()
        journal[date] = Journee(minutes: 5, note: "")
        try await persistance.enregistrer(journal: journal)
        let copie = try Data(contentsOf: dossier.appendingPathComponent("journal.illisible.json"))
        #expect(String(decoding: copie, as: UTF8.self) == "ceci n'est pas du JSON")
        let relu = try await PersistanceDepot(dossier: dossier, journalHorsSauvegarde: false).lire()
        #expect(relu.journal.record(date)?.minutes == 5)
    }

    @Test func uneEcritureQuiNeChangeRienNeCreeAucunFichier() async throws {
        let dossier = PersistanceDepotTests.dossierNeuf()
        defer { PersistanceDepotTests.efface(dossier) }
        let persistance = PersistanceDepot(dossier: dossier, journalHorsSauvegarde: false)
        try await persistance.enregistrer(journal: Journal())
        try await persistance.enregistrer(reglages: Reglages())
        #expect(!PersistanceDepotTests.existe(Depot.fichierJournal, dans: dossier))
        #expect(!PersistanceDepotTests.existe(Depot.fichierReglages, dans: dossier))
    }
}
