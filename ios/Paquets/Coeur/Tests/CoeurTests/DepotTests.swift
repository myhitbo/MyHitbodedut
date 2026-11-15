import Foundation
import Testing
@testable import Coeur

/// Le dépôt des fichiers d'iOS (Depot.swift) : journal.json et reglages.json, l'écriture atomique, la
/// lecture tolérante et la copie d'un fichier illisible, le pendant de la préférence days_corrompu
/// (Store.days). Android n'a pas de test d'exécution de ses préférences : elles sont celles du système.
/// Chaque test écrit dans un dossier temporaire qui n'est qu'à lui. Ici, `Depot` est l'aide des tests
/// (Fichiers.swift) : l'acteur s'écrit `Coeur.Depot`.
@Suite("Dépôt des fichiers")
struct DepotTests {

    private static func dossierNeuf() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("DepotTests-" + UUID().uuidString, isDirectory: true)
    }

    private static func efface(_ dossier: URL) {
        _ = try? FileManager.default.removeItem(at: dossier)
    }

    private static func pose(_ texte: String, _ nom: String, dans dossier: URL) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true, attributes: nil)
        try Data(texte.utf8).write(to: dossier.appendingPathComponent(nom))
    }

    private static func lis(_ nom: String, dans dossier: URL) throws -> String {
        String(decoding: try Data(contentsOf: dossier.appendingPathComponent(nom)), as: UTF8.self)
    }

    private static func existe(_ nom: String, dans dossier: URL) -> Bool {
        FileManager.default.fileExists(atPath: dossier.appendingPathComponent(nom).path)
    }

    @Test func unDepotNeufEstVideEtNEcritRien() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let depot = Coeur.Depot(dossier: dossier)
        let journal = try await depot.journal()
        let reglages = try await depot.reglages()
        let jours = journal.dates.count, vides = reglages.brut.estVide
        #expect(jours == 0)
        #expect(vides)
        let ecrit = FileManager.default.fileExists(atPath: dossier.path)
        #expect(!ecrit)
    }

    @Test func ecritEtRelitLeJournalEtLesReglages() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let jour = JourCivil.du("2026-10-01")
        let depot = Coeur.Depot(dossier: dossier, journalHorsSauvegarde: false)
        try await depot.modifier { journal in
            journal.addSession(minutes: 20, note: "merci", theme: "gratitude", date: jour)
            journal.ecrirePlus(JournalPlus.Plus(avant: 2, apres: 4, gratitude: "la famille"), pour: jour)
            journal.setFirstName("Hillel")
        }
        try await depot.modifierReglages { reglages in
            reglages.setTargetMinutes(30)
            reglages.setBlockedApps(["com.whatsapp"])
        }
        let journalEcrit = DepotTests.existe(Coeur.Depot.fichierJournal, dans: dossier)
        let reglagesEcrits = DepotTests.existe(Coeur.Depot.fichierReglages, dans: dossier)
        #expect(journalEcrit)
        #expect(reglagesEcrits)

        // Un autre dépôt sur le même dossier relit ce que le premier a écrit.
        let relu = Coeur.Depot(dossier: dossier)
        let journal = try await relu.journal()
        let reglages = try await relu.reglages()
        let journee = journal[jour], plus = journal.lirePlus(jour), prenom = journal.firstName
        #expect(journee == Journee(minutes: 20, note: "merci", themes: ["gratitude"]))
        #expect(plus == JournalPlus.Plus(avant: 2, apres: 4, gratitude: "la famille"))
        #expect(prenom == "Hillel")
        let duree = reglages.targetMinutes, applis = reglages.blockedApps
        #expect(duree == 30)
        #expect(applis == ["com.whatsapp"])

        // journal.json garde les préférences d'Android sous leurs noms ; reglages.json, les réglages tels quels.
        let objet = try ObjetJSON(texte: DepotTests.lis(Coeur.Depot.fichierJournal, dans: dossier))
        let cles = objet.cles
        #expect(cles == ["days", "journal_plus", "first_name"])
        let daysEcrits = objet.objet("days")?.texte()
        #expect(daysEcrits == journal.daysTexte)
        let texteReglages = try DepotTests.lis(Coeur.Depot.fichierReglages, dans: dossier)
        #expect(texteReglages == reglages.texte())
    }

    @Test func unJournalIllisibleEstMisDeCoteEtJamaisEcrase() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let illisible = "{\"days\":{\"2025-10-01\":{\"minutes\":5"
        try DepotTests.pose(illisible, Coeur.Depot.fichierJournal, dans: dossier)

        let depot = Coeur.Depot(dossier: dossier)
        let journal = try await depot.journal()
        let jours = journal.dates.count
        #expect(jours == 0)
        let copies = await depot.misDeCote
        let nombre = copies.count
        #expect(nombre == 1)
        let copie = try #require(copies.first)
        let nom = copie.lastPathComponent
        #expect(nom == "journal.illisible.json")
        let gardee = try DepotTests.lis("journal.illisible.json", dans: dossier)
        #expect(gardee == illisible)

        // L'écriture suivante remplace journal.json ; la copie reste telle quelle.
        try await depot.modifier { $0.addSession(minutes: 10, date: JourCivil.du("2025-10-02")) }
        let relu = try ObjetJSON(texte: DepotTests.lis(Coeur.Depot.fichierJournal, dans: dossier))
        let aDesJours = relu.objet("days")?.a("2025-10-02")
        #expect(aDesJours == true)
        let encore = try DepotTests.lis("journal.illisible.json", dans: dossier)
        #expect(encore == illisible)

        // Une seconde panne ne remplace pas la première copie : elle a la sienne.
        try DepotTests.pose("pas du json", Coeur.Depot.fichierJournal, dans: dossier)
        let autre = Coeur.Depot(dossier: dossier)
        _ = try await autre.journal()
        let secondes = await autre.misDeCote
        let secondNom = secondes.first?.lastPathComponent
        #expect(secondNom == "journal.illisible-2.json")
        let premiere = try DepotTests.lis("journal.illisible.json", dans: dossier)
        let seconde = try DepotTests.lis("journal.illisible-2.json", dans: dossier)
        #expect(premiere == illisible)
        #expect(seconde == "pas du json")
    }

    @Test func unFichierQuiNEstPasDeLUTF8EstMisDeCote() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true, attributes: nil)
        let octets = Data([0x7B, 0x22, 0xFF, 0xFE, 0x22, 0x3A, 0x31, 0x7D])
        try octets.write(to: dossier.appendingPathComponent(Coeur.Depot.fichierReglages))
        let depot = Coeur.Depot(dossier: dossier)
        let reglages = try await depot.reglages()
        let vides = reglages.brut.estVide
        #expect(vides)
        let gardes = try Data(contentsOf: dossier.appendingPathComponent("reglages.illisible.json"))
        #expect(gardes == octets)
    }

    @Test func desReglagesIllisiblesNeTouchentPasAuJournal() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let jour = JourCivil.du("2025-10-01")
        let premier = Coeur.Depot(dossier: dossier)
        try await premier.modifier { $0.addSession(minutes: 15, date: jour) }
        try DepotTests.pose("[]", Coeur.Depot.fichierReglages, dans: dossier)

        let depot = Coeur.Depot(dossier: dossier)
        let reglages = try await depot.reglages()
        let duree = reglages.targetMinutes
        #expect(duree == Reglages.defaultTarget)
        let journal = try await depot.journal()
        let journee = journal[jour]
        #expect(journee == Journee(minutes: 15, note: ""))
        let copies = await depot.misDeCote
        let noms = copies.map { $0.lastPathComponent }
        #expect(noms == ["reglages.illisible.json"])
    }

    @Test func unJournalDAndroidIllisibleGardeSaCopieDansDaysCorrompu() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        // La préférence days d'Android, gardée en texte, et illisible : le fichier, lui, se lit.
        try DepotTests.pose(#"{"days":"{pas du json","journal_plus":{},"first_name":"Moshe"}"#, Coeur.Depot.fichierJournal, dans: dossier)
        let depot = Coeur.Depot(dossier: dossier)
        let journal = try await depot.journal()
        let corrompu = journal.corrompu, prenom = journal.firstName
        #expect(corrompu == "{pas du json")
        #expect(prenom == "Moshe")
        let copies = await depot.misDeCote
        #expect(copies.isEmpty)
        try await depot.modifier { $0.addSession(minutes: 5, date: JourCivil.du("2025-10-03")) }
        let ecrit = try ObjetJSON(texte: DepotTests.lis(Coeur.Depot.fichierJournal, dans: dossier))
        let garde = ecrit.texte("days_corrompu")
        #expect(garde == "{pas du json")
        // Relu, le journal garde la copie et la journée.
        let relu = try await Coeur.Depot(dossier: dossier).journal()
        let copieRelue = relu.corrompu, journee = relu[JourCivil.du("2025-10-03")]
        #expect(copieRelue == "{pas du json")
        #expect(journee == Journee(minutes: 5, note: ""))
    }

    @Test func desJourneesQuiNeSeLisentPasFontMettreLeFichierDeCote() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let texte = #"{"days":[1,2,3],"first_name":"Moshe"}"#
        try DepotTests.pose(texte, Coeur.Depot.fichierJournal, dans: dossier)
        let depot = Coeur.Depot(dossier: dossier)
        let journal = try await depot.journal()
        let prenom = journal.firstName
        #expect(prenom == "Moshe")
        let gardee = try DepotTests.lis("journal.illisible.json", dans: dossier)
        #expect(gardee == texte)
    }

    @Test func importerEcritLesDeuxFichiers() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let depot = Coeur.Depot(dossier: dossier)
        let fichier = #"{"format":"myhitbodedut","days":{"2026-11-01":{"minutes":20,"note":"ici"},"2026-11-20":{"minutes":5}},"#
            + #""settings":{"target_minutes":25,"music_track":"hamelech_basade"},"blocked_apps":["com.whatsapp"]}"#
        let n = try await depot.importer(Data(fichier.utf8), aujourdhui: JourCivil.du("2026-11-15"),
                                         morceauxLivres: ["hamelech_basade"], fuseauTelephone: "UTC")
        #expect(n == 1)
        let relu = Coeur.Depot(dossier: dossier)
        let journal = try await relu.journal()
        let reglages = try await relu.reglages()
        let journee = journal[JourCivil.du("2026-11-01")]
        #expect(journee == Journee(minutes: 20, note: "ici"))
        let duree = reglages.targetMinutes, morceau = reglages.musicTrackId, applis = reglages.blockedApps
        #expect(duree == 25)
        #expect(morceau == "hamelech_basade")
        #expect(applis == ["com.whatsapp"])

        // L'export du dépôt se relit, et porte ce qui a été importé.
        let donnees = try await relu.exporter(maintenant: 1_794_578_000_000)
        let exporte = try ObjetJSON(texte: String(decoding: donnees, as: UTF8.self))
        let format = exporte.texte("format"), horodatage = exporte.texte("exported_at")
        let minutes = exporte.objet("days")?.objet("2026-11-01")?.entier("minutes")
        #expect(format == "myhitbodedut")
        #expect(horodatage == "2026-11-13T13:53:20.000Z")
        #expect(minutes == 20)
    }

    @Test func unImportRefuseNEcritRien() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let depot = Coeur.Depot(dossier: dossier)
        let aujourdhui = JourCivil.du("2026-11-15")
        let invalide = try await depot.importer(Data("pas du json".utf8), aujourdhui: aujourdhui, morceauxLivres: [])
        #expect(invalide == nil)
        let autre = try await depot.importer(Data(#"{"format":"autre","days":{"2026-11-01":{"minutes":5}}}"#.utf8),
                                             aujourdhui: aujourdhui, morceauxLivres: [])
        #expect(autre == nil)
        // Plus de 2 Mo : refusé avant d'être lu.
        var gros = Data(#"{"format":"myhitbodedut","x":""#.utf8)
        gros.append(Data(repeating: 0x61, count: Sauvegarde.importMaxOctets))
        gros.append(Data(#""}"#.utf8))
        let tropGros = try await depot.importer(gros, aujourdhui: aujourdhui, morceauxLivres: [])
        #expect(tropGros == nil)
        let journal = DepotTests.existe(Coeur.Depot.fichierJournal, dans: dossier)
        let reglages = DepotTests.existe(Coeur.Depot.fichierReglages, dans: dossier)
        #expect(!journal)
        #expect(!reglages)
    }

    @Test func modifierSansChangementNEcritRien() async throws {
        let dossier = DepotTests.dossierNeuf()
        defer { DepotTests.efface(dossier) }
        let depot = Coeur.Depot(dossier: dossier)
        try await depot.modifier { _ in }
        try await depot.modifierReglages { _ in }
        let ecrit = FileManager.default.fileExists(atPath: dossier.path)
        #expect(!ecrit)
    }
}
