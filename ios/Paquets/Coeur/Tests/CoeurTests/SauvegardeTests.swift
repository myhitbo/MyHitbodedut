import Foundation
import Testing
@testable import Coeur

/// La sauvegarde JSON (PORTAGE.md § 3.9). Devant Android : six cas importés par `Store.importJson`
/// dans un téléphone neuf puis exportés (Tests/Vecteurs/sauvegarde.json). Puis les cas d'import et
/// d'export du site (web/test/regles, journal-plus, musique, hitbodedut), les adaptations d'iOS,
/// l'aller-retour, l'ordre des clés et le dépôt. La vraie sauvegarde du propriétaire (P7) n'est pas
/// au dépôt : quand elle y sera, elle rejoindra les cas devant Android.
@Suite("Sauvegarde")
struct SauvegardeTests {

    private let aujourdhui = JourCivil.du("2026-11-15")

    private func neuf(enIsrael: Bool = false) -> Donnees { Donnees(reglages: Reglages(enIsrael: enIsrael)) }

    private func importer(_ texte: String, _ d: inout Donnees) -> Int? {
        Sauvegarde.importer(texte, dans: &d, aujourdhui: aujourdhui)
    }

    /// L'export d'iOS comme le vecteur d'Android : sans `exported_at`, ni `journal_plus` qu'Android
    /// n'écrit pas, les deux ensembles triés.
    private func commeAndroid(_ d: Donnees) throws -> ObjetJSON {
        var o = try ObjetJSON(texte: Sauvegarde.exporter(d, maintenant: 0))
        o["exported_at"] = nil
        o["journal_plus"] = nil
        for cle in ["paused_dates", "blocked_apps"] {
            let t = o.tableau(cle) ?? []
            o[cle] = .tableau(t.indices.map { t.texte($0) }.sorted().map { JSON.chaine($0) })
        }
        return o
    }

    private func cas(_ nom: String) throws -> ObjetJSON {
        let tous = try Depot.vecteurs("sauvegarde.json").tableau("cas") ?? []
        let trouve = tous.indices.compactMap { tous.objet($0) }.first { $0.texte("nom") == nom }
        return try #require(trouve)
    }

    private func importes(_ nom: String) throws -> Donnees {
        let c = try cas(nom)
        let fichiers = c.tableau("fichiers") ?? []
        var d = neuf()
        for i in fichiers.indices { _ = importer(fichiers.texte(i), &d) }
        return d
    }

    // MARK: Devant Android

    @Test func lesSixCasSeLisentEtSEcriventCommeSurAndroid() throws {
        let tous = try Depot.vecteurs("sauvegarde.json").tableau("cas") ?? []
        #expect(tous.count == 6)
        for c in tous.indices.compactMap({ tous.objet($0) }) {
            let nom = c.texte("nom")
            let fichiers = c.tableau("fichiers") ?? []
            let comptes = c.tableau("comptes") ?? []
            var d = neuf()
            var rendus: [Int?] = []
            for i in fichiers.indices { rendus.append(importer(fichiers.texte(i), &d)) }
            let attendus: [Int?] = comptes.indices.map { comptes.estNul($0) ? nil : comptes.entier($0) }
            #expect(rendus == attendus, "\(nom)")
            let rendu = try commeAndroid(d)
            let attendu = try ObjetJSON(texte: c.texte("export"))
            #expect(rendu == attendu, "\(nom) : \(rendu.texte()) au lieu de \(attendu.texte())")
        }
    }

    @Test func leFichierForgeCouvreToutesLesBranches() throws {
        let d = try importes("forge")
        let j = d.journal.jours
        #expect(j.count == 7)
        #expect(j[JourCivil.du("2020-03-03")]?.minutes == 25, "nombre écrit en chaîne")
        #expect(j[JourCivil.du("2020-03-04")]?.minutes == 20, "décimal tronqué")
        #expect(j[JourCivil.du("2020-03-05")]?.minutes == 0)
        #expect(j[JourCivil.du("2020-03-05")]?.note.utf16.count == 4000)
        #expect(j[JourCivil.du("2020-03-06")]?.minutes == 1440)
        #expect(j[JourCivil.du("2020-03-06")]?.themes == ["inconnu", "famille"], "une clé inconnue est gardée")
        #expect(j[JourCivil.du("2020-03-07")]?.noteSeule == true, "booléen écrit en chaîne")
        #expect(j[JourCivil.du("2020-03-01")]?.themes == ["gratitude", "parnassa"])
        let r = d.reglages
        #expect(r.rappels == [1260], "reminder_minutes sans reminder_times")
        #expect(d.journal.prenom == "Avraham Yitzhak Yaakov Moshe Aharon Davi")
        #expect(r.applisBloquees.sorted() == ["com.instagram.android", "com.whatsapp"])
        #expect(r.joursPause == ["2020-01-10", "2020-01-12"])
    }

    @Test func leFichierDuSiteApporteSonJournalEnrichi() throws {
        let d = try importes("web")
        #expect(d.journal.plus == [JourCivil.du("2022-02-01"): JournalPlus(avant: 2, apres: 4, gratitude: "La santé.", travail: "La patience.")])
        let o = try ObjetJSON(texte: Sauvegarde.exporter(d, maintenant: 0))
        let plus = try #require(o.objet("journal_plus")?.objet("2022-02-01"))
        #expect(plus.cles == ["avant", "apres", "gratitude", "travail"])
        #expect(plus.texte("travail") == "La patience.")
    }

    // MARK: Aller-retour

    @Test func importerExporterRendLeMeme() throws {
        for nom in ["forge", "fusion", "web"] {
            let d = try importes(nom)
            var relu = neuf()
            let lues = importer(Sauvegarde.exporter(d, maintenant: 1_763_021_730_123), &relu)
            #expect(lues == d.journal.jours.count)
            #expect(relu == d, "\(nom)")
            let exportes = d.reglages.exportes(prenom: d.journal.prenom)
            #expect(exportes.count == 21)
            #expect(relu.reglages.exportes(prenom: relu.journal.prenom) == exportes)
        }
    }

    // MARK: Les cas du site (web/test), portés

    @Test func uneSauvegardeDAndroidSeFondDansUnJournalExistant() throws {
        var d = neuf()
        d.journal.jours[JourCivil.du("2026-09-28")] = Journee(minutes: 30, note: "ici", themes: ["gratitude"])
        let android = """
            {"format":"myhitbodedut","version":1,"exported_at":"2026-09-28T10:00:00Z",
             "days":{"2026-09-28":{"minutes":45,"note":"","themes":["famille"]},"2026-09-20":{"minutes":60,"note":"là"}},
             "settings":{"window_start":360,"window_end":660,"snooze_minutes":15,"target_minutes":30,"daily_goal_minutes":0,
               "pause_shabbat":true,"in_israel":true,"reminder_enabled":true,"reminder_minutes":420,"music_enabled":false,
               "music_volume":40,"music_shuffle":true,"music_track":"niggoun_05","adresse":"f","apparence_mode":"sombre",
               "apparence_fond":"sable","apparence_accent":"violet","guided_hitbodedut":true,"reminder_times":[420,1260],
               "first_name":"Hillel","hide_countdown":true},
             "paused_dates":["2026-09-30"],"blocked_apps":["com.exemple"]}
            """
        let lues = importer(android, &d)
        #expect(lues == 2)
        #expect(d.journal.jours[JourCivil.du("2026-09-28")] == Journee(minutes: 45, note: "ici", themes: ["gratitude", "famille"]))
        let r = d.reglages
        #expect(r.duree == 30 && r.adresse == "f" && r.fond == .sable && r.accent == .violet && r.mode == .sombre)
        #expect(r.joursPause == ["2026-09-30"] && r.guidee && r.rappelActif && r.enIsrael)
        #expect(r.morceau == "", "niggoun_05 n'est pas un morceau livré")
        let e = try #require(try ObjetJSON(texte: Sauvegarde.exporter(d, maintenant: 0)).objet("settings"))
        #expect(e.tableau("reminder_times") == [JSON.entier(420), JSON.entier(1260)])
        #expect(e.texte("first_name") == "Hillel" && e.booleen("hide_countdown"))
        let jour = try #require(try ObjetJSON(texte: Sauvegarde.exporter(d, maintenant: 0)).objet("days")?.objet("2026-09-20"))
        #expect(!jour.a("themes") && !jour.a("note_seule"))
    }

    @Test func unFichierQuiNEstPasUneSauvegardeEstRefuse() {
        var d = neuf()
        for texte in ["pas du json", #"{"format":"autre"}"#, "[]", "", #"{"days":{}}"#] {
            let lues = importer(texte, &d)
            #expect(lues == nil, "« \(texte) »")
        }
        #expect(d == neuf())
        let gros = Data(repeating: 0x20, count: Sauvegarde.tailleMax + 1)
        let trop = Sauvegarde.importer(gros, dans: &d, aujourdhui: aujourdhui)
        let illisible = Sauvegarde.importer(Data([0xFF, 0xFE]), dans: &d, aujourdhui: aujourdhui)
        #expect(trop == nil && illisible == nil)
    }

    @Test func lImportRejetteLesDatesFaussesOuAVenirEtBorneLesValeurs() throws {
        var d = neuf()
        let n = importer("""
            {"format":"myhitbodedut","version":1,
             "days":{"2026-13-45":{"minutes":10},"x":{"minutes":10},"2099-01-01":{"minutes":10},"2026-11-16":{"minutes":10},
               "2026-11-15":{"minutes":3},"2026-09-20":{"minutes":-5,"note":"\(String(repeating: "a", count: 5000))"}},
             "settings":{"target_minutes":0,"music_volume":500,"snooze_minutes":15},
             "paused_dates":["2026-02-30","2026-09-21"]}
            """, &d)
        #expect(n == 2, "aujourd'hui est accepté, demain non")
        let jour = try #require(d.journal.jours[JourCivil.du("2026-09-20")])
        #expect(jour.minutes == 0 && jour.note.utf16.count == 4000)
        #expect(d.reglages.duree == 1, "Android ramène à DureeSeance.MIN ; le site garde l'ancienne valeur")
        #expect(d.reglages.volume == 100, "Android ramène à 100 ; le site garde l'ancienne valeur")
        #expect(d.reglages.joursPause == ["2026-09-21"])
    }

    @Test func uneNoteSeuleSurvitALAllerRetour() throws {
        var d = neuf()
        d.journal.jours[JourCivil.du("2026-11-14")] = Journee(minutes: 0, note: "une pensée", noteSeule: true)
        let o = try ObjetJSON(texte: Sauvegarde.exporter(d, maintenant: 0))
        #expect(o.objet("days")?.objet("2026-11-14")?.booleen("note_seule") == true)
        var t = neuf()
        _ = importer(o.texte(), &t)
        #expect(t.journal.jours[JourCivil.du("2026-11-14")]?.faite == false)
        // Fusion : note seule des deux côtés seulement.
        _ = importer(#"{"format":"myhitbodedut","days":{"2026-11-14":{"minutes":10}}}"#, &t)
        #expect(t.journal.jours[JourCivil.du("2026-11-14")] == Journee(minutes: 10, note: "une pensée"))
    }

    @Test func leJournalEnrichiNEcrasePasCeQuiEstDejaNote() throws {
        var a = neuf()
        a.journal.plus[JourCivil.du("2026-11-01")] = JournalPlus(avant: 1, apres: 5, gratitude: "g", travail: "t")
        a.journal.plus[JourCivil.du("2026-10-30")] = JournalPlus(avant: 3, apres: 3)
        let fichier = Sauvegarde.exporter(a, maintenant: 0)
        var b = neuf()
        b.journal.plus[JourCivil.du("2026-10-30")] = JournalPlus(gratitude: "déjà là")
        let lues = importer(fichier, &b)
        #expect(lues == 0)
        #expect(b.journal.plus[JourCivil.du("2026-11-01")] == JournalPlus(avant: 1, apres: 5, gratitude: "g", travail: "t"))
        #expect(b.journal.plus[JourCivil.du("2026-10-30")] == JournalPlus(gratitude: "déjà là"))
        var c = neuf()
        let aucune = importer(#"{"format":"myhitbodedut","version":1,"days":{}}"#, &c)
        #expect(aucune == 0)
        _ = importer(#"{"format":"myhitbodedut","journal_plus":{"2027-01-01":{"avant":2},"2026-02-30":{"avant":2},"2026-11-02":{"avant":9,"gratitude":"\#(String(repeating: "g", count: 300))"}}}"#, &c)
        #expect(c.journal.plus == [JourCivil.du("2026-11-02"): JournalPlus(avant: 5, gratitude: String(repeating: "g", count: 200))])
    }

    @Test func uneCleAbsenteNeTouchePasAuReglage() {
        var d = neuf()
        _ = importer(#"{"format":"myhitbodedut","settings":{"guided_hitbodedut":true,"music_shuffle":true,"hide_countdown":true}}"#, &d)
        #expect(d.reglages.guidee && d.reglages.aleatoire && d.reglages.masquerDecompte)
        _ = importer(#"{"format":"myhitbodedut","settings":{"music_shuffle":"oui","first_name":"  Sarah "}}"#, &d)
        #expect(d.reglages.guidee && d.reglages.aleatoire && d.reglages.masquerDecompte, "« oui » n'est pas un booléen")
        #expect(d.journal.prenom == "Sarah")
        _ = importer(#"{"format":"myhitbodedut","settings":{"guided_hitbodedut":false,"pause_shabbat":"FALSE"}}"#, &d)
        #expect(!d.reglages.guidee && !d.reglages.pauseShabbat)
    }

    // MARK: Adaptations d'iOS

    @Test func uneValeurInconnueEstIgnoreeUnMorceauDoitEtreLivre() {
        var d = neuf()
        _ = importer(#"{"format":"myhitbodedut","settings":{"apparence_fond":"contraste","apparence_accent":"ambre","music_track":"ianir_hello","adresse":"m"}}"#, &d)
        #expect(d.reglages.fond == .contraste && d.reglages.accent == .ambre && d.reglages.morceau == "ianir_hello" && d.reglages.adresse == "m")
        _ = importer(#"{"format":"myhitbodedut","settings":{"apparence_mode":"nuit","apparence_fond":"noir","apparence_accent":"or","music_track":"content://media/42","adresse":"x"}}"#, &d)
        #expect(d.reglages.mode == .auto && d.reglages.fond == .contraste && d.reglages.accent == .ambre)
        #expect(d.reglages.morceau == "ianir_hello" && d.reglages.adresse == "m")
    }

    @Test func lesMorceauxLivresSontCeuxDuContenu() throws {
        let ids = try Morceau.lire(Depot.contenu("musique.json")).map { $0.id }
        #expect(ids == Sauvegarde.morceauxLivres)
    }

    // MARK: Ordre et forme

    @Test func lExportSuitLOrdreDAndroidIndenteDeDeuxEspaces() throws {
        let texte = Sauvegarde.exporter(try importes("forge"), maintenant: 1_763_021_730_123)
        #expect(texte.hasPrefix("{\n  \"format\": \"myhitbodedut\",\n  \"version\": 1,\n  \"exported_at\": \"2025-11-13T08:15:30.123Z\",\n  \"days\": {\n    \"2020-03-01\": {\n      \"minutes\": 20,"))
        let o = try ObjetJSON(texte: texte)
        #expect(o.cles == ["format", "version", "exported_at", "days", "settings", "paused_dates", "blocked_apps", "journal_plus"])
        let jours = o.objet("days")?.cles ?? []
        #expect(jours == jours.sorted())
        let android = try cas("neuf").objetDeLExport("settings").cles
        #expect(o.objet("settings")?.cles == android)
        #expect(!texte.hasPrefix("\u{FEFF}"))
    }

    @Test func lInstantDExportEstEnUTCALaMilliseconde() {
        #expect(Sauvegarde.instant(0) == "1970-01-01T00:00:00.000Z")
        #expect(Sauvegarde.instant(1_763_021_730_005) == "2025-11-13T08:15:30.005Z")
        #expect(Sauvegarde.instant(-1) == "1969-12-31T23:59:59.999Z")
        #expect(Sauvegarde.nomDeFichier(JourCivil.du("2026-11-13")) == "myhitbodedut-2026-11-13.json")
    }

    // MARK: Le dépôt

    private func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("depot-\(UUID().uuidString)")
    }

    @Test func leDepotEcritEtRelitSesDeuxFichiers() async throws {
        let ici = dossier()
        defer { try? FileManager.default.removeItem(at: ici) }
        let depot = Coeur.Depot(dossier: ici, enIsrael: true)
        let fichier = Data(try cas("forge").tableau("fichiers")?.texte(0).utf8 ?? "".utf8)
        let lues = try await depot.importer(fichier, aujourdhui: aujourdhui)
        #expect(lues == 7)
        try await depot.modifier { $0.reglages.autres["siddur_nusah"] = .chaine("sefard") }
        let avant = await depot.tout
        let relu = Coeur.Depot(dossier: ici, enIsrael: false)
        let apres = await relu.tout
        #expect(apres == avant)
        #expect(apres.reglages.autres.texte("siddur_nusah") == "sefard", "une clé inconnue d'iOS est gardée")
        // Invalide : rien n'est écrit.
        let refus = try await relu.importer(Data("pas du json".utf8), aujourdhui: aujourdhui)
        #expect(refus == nil)
        let inchange = await relu.tout
        #expect(inchange == avant)
        let export = await relu.exporter(maintenant: 0)
        #expect(export.first == UInt8(ascii: "{"))
    }

    @Test func unFichierIllisibleEstMisDeCoteEtNonEcrase() async throws {
        let ici = dossier()
        defer { try? FileManager.default.removeItem(at: ici) }
        try FileManager.default.createDirectory(at: ici, withIntermediateDirectories: true)
        let journal = ici.appendingPathComponent(Coeur.Depot.fichierJournal)
        let copie = ici.appendingPathComponent(Coeur.Depot.corrompu(Coeur.Depot.fichierJournal))
        try Data(#"{"days":{"2026-11-01":"#.utf8).write(to: journal)
        let depot = Coeur.Depot(dossier: ici, enIsrael: false)
        let vide = await depot.journal
        #expect(vide == Journal())
        #expect(try Data(contentsOf: copie) == Data(#"{"days":{"2026-11-01":"#.utf8))
        try await depot.modifier { $0.journal.jours[JourCivil.du("2026-11-14")] = Journee(minutes: 12) }
        let rouvert = await Coeur.Depot(dossier: ici, enIsrael: false).journal
        #expect(rouvert.jours.count == 1)
        // Une seconde panne ne remplace pas la première copie.
        try Data("autre".utf8).write(to: journal)
        _ = Coeur.Depot(dossier: ici, enIsrael: false)
        #expect(try Data(contentsOf: copie) == Data(#"{"days":{"2026-11-01":"#.utf8))
        #expect(Coeur.Depot.corrompu("reglages.json") == "reglages.corrompu.json")
    }
}

private extension ObjetJSON {
    /// Un objet de l'export (une chaîne) d'un cas des vecteurs.
    func objetDeLExport(_ cle: String) throws -> ObjetJSON {
        try ObjetJSON(texte: texte("export")).objet(cle) ?? ObjetJSON()
    }
}
