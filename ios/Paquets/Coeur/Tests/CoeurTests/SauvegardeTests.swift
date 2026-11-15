import Foundation
import Testing
@testable import Coeur

/// La sauvegarde (Store.exportJson, Store.importJson ; PORTAGE.md § 3.4 à 3.9). Android n'a pas de test
/// d'exécution de importJson (il demande un Context) : d'abord `Tests/Vecteurs/sauvegarde.json`
/// (tools/vecteurs_ios/VecteursSauvegarde.kt), où le vrai Store.importJson et le vrai Store.exportJson
/// répondent, scénario par scénario ; puis les cas d'import et d'export des tests du site
/// (web/test/regles.test.mjs, journal-plus.test.mjs, musique.test.mjs, hitbodedut.test.mjs), portés tels
/// quels — là où le site s'écarte d'Android (bornes, années avant 2000, clés de la barrière), iOS suit
/// Android et le test le dit ; enfin les lignes du § 3.9. La sauvegarde réelle du propriétaire
/// (`android-v1-reel.json`) n'est pas dans le dépôt : sa ligne reste à faire.
@Suite("Sauvegarde")
struct SauvegardeTests {

    private static let aujourdhui = JourCivil.du("2026-11-15")
    private static let livres: Set<String> = ["hamelech_basade", "yanuka_nigoun_3"]
    private static let maintenant: Int64 = 1_794_578_000_000

    /// Un import le 15 novembre 2026 (ou `aujourdhui`), sur un téléphone en UTC.
    private static func importe(_ texte: String, _ journal: inout Journal, _ reglages: inout Reglages,
                                aujourdhui: JourCivil = SauvegardeTests.aujourdhui) -> Int? {
        Sauvegarde.importer(texte: texte, journal: &journal, reglages: &reglages, aujourdhui: aujourdhui,
                            morceauxLivres: livres, fuseauTelephone: "UTC")
    }

    /// L'export relu.
    private static func exporte(_ journal: Journal, _ reglages: Reglages) throws -> ObjetJSON {
        try ObjetJSON(texte: Sauvegarde.exporter(journal: journal, reglages: reglages, maintenant: maintenant,
                                                 fuseauTelephone: "UTC"))
    }

    private static func trie(_ textes: [String]) -> [String] {
        textes.sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
    }

    // MARK: Les vecteurs d'Android

    /// Une préférence d'Android : [clé, type, valeur].
    private struct Pref: Decodable {
        let cle: String
        let valeur: JSON

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            cle = try c.decode(String.self)
            let type = try c.decode(String.self)
            switch type {
            case "int", "long":
                valeur = try .entier(c.decode(Int64.self))
            case "bool":
                valeur = try .booleen(c.decode(Bool.self))
            case "string":
                valeur = try .chaine(c.decode(String.self))
            case "float":
                valeur = try .decimal(c.decode(Double.self))
            case "set":
                valeur = try .tableau(c.decode([String].self).map { JSON.chaine($0) })
            default:
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "type inconnu : " + type)
            }
        }
    }

    /// Les préférences du fichier « myhitbodedut-journal ».
    private struct EtatJournal: Decodable {
        let days: String?
        let journalPlus: String?
        let firstName: String?
        let daysCorrompu: String?

        enum CodingKeys: String, CodingKey {
            case days
            case journalPlus = "journal_plus"
            case firstName = "first_name"
            case daysCorrompu = "days_corrompu"
        }
    }

    private struct Etat: Decodable {
        let prefs: [Pref]
        let journal: EtatJournal
    }

    private struct Scenario: Decodable {
        let nom: String
        let avant: Etat
        let fichier: String
        let importe: Int?
        let apres: Etat
        let export: String
        let pausedDates: [String]
        let blockedApps: [String]
        let firstName: String
    }

    private struct Meta: Decodable {
        let aujourdhui: String
        let fuseau: String
        let morceauxLivres: [String]
    }

    private struct Vecteurs: Decodable {
        let meta: Meta
        let scenarios: [Scenario]

        enum CodingKeys: String, CodingKey {
            case meta = "_meta"
            case scenarios
        }
    }

    private static func objet(_ prefs: [Pref]) -> ObjetJSON {
        ObjetJSON(prefs.map { ($0.cle, $0.valeur) })
    }

    /// L'export d'Android, ses journées dans l'ordre des dates et ses ensembles dans l'ordre des unités
    /// UTF-16 : c'est ainsi qu'iOS les écrit (un ensemble d'Android sort dans l'ordre de son HashSet).
    private static func normalise(_ android: ObjetJSON) -> ObjetJSON {
        var o = android
        if let days = android.objet("days") {
            var paires: [(JourCivil, String)] = []
            for cle in days.cles {
                if let jour = Journal.dateValide(cle) {
                    paires.append((jour, cle))
                }
            }
            paires.sort { $0.0 < $1.0 }
            var tries = ObjetJSON()
            for (_, cle) in paires {
                tries[cle] = days[cle]
            }
            o["days"] = .objet(tries)
        }
        for cle in ["paused_dates", "blocked_apps"] {
            if let elements = android.tableau(cle) {
                var textes: [String] = []
                for rang in elements.indices {
                    textes.append(elements.texte(rang))
                }
                o[cle] = .tableau(trie(textes).map { JSON.chaine($0) })
            }
        }
        return o
    }

    @Test func vecteursDAndroid() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde.json"))
        let aujourdhui = try #require(JourCivil(iso: v.meta.aujourdhui))
        let livres = Set(v.meta.morceauxLivres)
        // Les morceaux que nomment les vecteurs sont livrés sur iOS.
        let livresIos = try Set(Morceau.lire(Depot.contenu("musique.json")).map { $0.id })
        let tousLivres = livres.isSubset(of: livresIos)
        #expect(tousLivres, "\(livres)")
        let nombre = v.scenarios.count
        #expect(nombre >= 80)

        for s in v.scenarios {
            var journal = Journal(daysTexte: s.avant.journal.days, journalPlusTexte: s.avant.journal.journalPlus,
                                  prenom: s.avant.journal.firstName ?? "", corrompu: s.avant.journal.daysCorrompu)
            var reglages = Reglages(brut: SauvegardeTests.objet(s.avant.prefs))
            let importe = Sauvegarde.importer(texte: s.fichier, journal: &journal, reglages: &reglages, aujourdhui: aujourdhui,
                                              morceauxLivres: livres, fuseauTelephone: v.meta.fuseau)
            #expect(importe == s.importe, "\(s.nom) : le nombre importé")

            // Le journal : la préférence days réécrite à l'identique, le prénom, la copie d'un journal illisible.
            let days = journal.daysTexte
            let daysConformes = days.egalUnites(s.apres.journal.days ?? "{}")
            #expect(daysConformes, "\(s.nom) : la préférence days\n\(days)")
            let prenom = journal.prenom
            let prenomConforme = prenom.egalUnites(s.apres.journal.firstName ?? "")
            #expect(prenomConforme, "\(s.nom) : le prénom gardé « \(prenom) »")
            let corrompu = journal.corrompu
            #expect(corrompu == s.apres.journal.daysCorrompu, "\(s.nom) : days_corrompu")
            let plus = journal.journalPlusTexte
            let plusConforme = plus.egalUnites(s.apres.journal.journalPlus ?? "{}")
            #expect(plusConforme, "\(s.nom) : journal_plus")

            // Les réglages : les mêmes clés, dans le même ordre, avec les mêmes valeurs.
            let attendus = SauvegardeTests.objet(s.apres.prefs)
            let reglagesConformes = reglages.brut == attendus
            #expect(reglagesConformes, "\(s.nom) : les réglages\n\(reglages.texte())\n\(attendus.texte())")
            let pauses = SauvegardeTests.trie(Array(reglages.pausedDates))
            #expect(pauses == s.pausedDates, "\(s.nom) : paused_dates")
            let applis = SauvegardeTests.trie(Array(reglages.blockedApps))
            #expect(applis == s.blockedApps, "\(s.nom) : blocked_apps")
            let prenomLu = journal.firstName
            let prenomLuConforme = prenomLu.egalUnites(s.firstName)
            #expect(prenomLuConforme, "\(s.nom) : firstName « \(prenomLu) »")

            // L'export : celui d'Android se relit et se réécrit à l'octet ; celui d'iOS, sans exported_at
            // ni journal_plus, est le même, aux ordres près des journées et des ensembles.
            let android = try ObjetJSON(texte: s.export)
            let reecrit = android.texte(indentation: 2)
            let reecritConforme = reecrit.egalUnites(s.export)
            #expect(reecritConforme, "\(s.nom) : l'export d'Android réécrit\n\(reecrit)")
            var ios = Sauvegarde.objet(journal: journal, reglages: reglages, maintenant: 0, fuseauTelephone: v.meta.fuseau)
            ios["exported_at"] = nil
            ios["journal_plus"] = nil
            let texteIos = ios.texte(indentation: 2)
            let texteAndroid = SauvegardeTests.normalise(android).texte(indentation: 2)
            let exportConforme = texteIos.egalUnites(texteAndroid)
            #expect(exportConforme, "\(s.nom) : l'export\n\(texteIos)\n\(texteAndroid)")
        }
    }

    // MARK: regles.test.mjs

    private static let android = #"""
        {"format":"myhitbodedut","version":1,"exported_at":"2026-09-28T10:00:00Z",
         "days":{"2026-09-28":{"minutes":45,"note":"","themes":["famille"]},"2026-09-20":{"minutes":60,"note":"là"}},
         "settings":{"window_start":360,"window_end":660,"snooze_minutes":15,"target_minutes":30,"daily_goal_minutes":0,
          "pause_shabbat":true,"in_israel":true,"reminder_enabled":true,"reminder_minutes":420,"music_enabled":false,
          "music_volume":40,"music_shuffle":true,"music_track":"niggoun_05","adresse":"f","apparence_mode":"sombre",
          "apparence_fond":"sable","apparence_accent":"violet","guided_hitbodedut":true,"reminder_times":[420,1260],
          "first_name":"Hillel","hide_countdown":true},
         "paused_dates":["2026-09-30"],"blocked_apps":["com.exemple"]}
        """#

    @Test func unFichierDeSauvegardeAndroidSeRelitEtLExportGardeLeMemeFormat() throws {
        var journal = Journal(daysTexte: #"{"2026-09-28":{"minutes":30,"note":"ici","themes":["gratitude"]}}"#)
        var reglages = Reglages()
        let n = SauvegardeTests.importe(SauvegardeTests.android, &journal, &reglages)
        #expect(n == 2)
        // Conflit : la séance la plus longue, la note non vide, les sujets réunis.
        let jour = journal[JourCivil.du("2026-09-28")]
        #expect(jour == Journee(minutes: 45, note: "ici", themes: ["gratitude", "famille"], noteSeule: false))
        let duree = reglages.targetMinutes, adresse = reglages.adresse, fond = reglages.fond
        #expect(duree == 30)
        #expect(adresse == "f")
        #expect(fond == .sable)
        let pause = reglages.pausedDates.contains("2026-09-30")
        #expect(pause)
        let guide = reglages.guidedHitbodedut
        #expect(guide)
        // Adaptation d'iOS : « niggoun_05 » n'est pas un morceau livré sur iOS, il n'est pas repris.
        let morceau = reglages.musicTrackId
        #expect(morceau == nil)

        let exporte = try SauvegardeTests.exporte(journal, reglages)
        let format = exporte.texte("format"), version = exporte.entier("version")
        #expect(format == "myhitbodedut")
        #expect(version == 1)
        let settings = try #require(exporte.objet("settings"))
        let fichier = try ObjetJSON(texte: SauvegardeTests.android)
        let attendues = try #require(fichier.objet("settings"))
        let cles = settings.cles.sorted(), clesAttendues = attendues.cles.sorted()
        #expect(cles == clesAttendues)
        // Ce que l'iPhone ne sait pas régler repart tel qu'il est arrivé.
        let debut = settings.entier("window_start"), rappel = settings.booleen("reminder_enabled")
        #expect(debut == 360)
        #expect(rappel)
        let heures = settings.tableau("reminder_times") ?? []
        #expect(heures == [JSON.entier(420), JSON.entier(1260)])
        let prenom = settings.texte("first_name"), decompte = settings.booleen("hide_countdown")
        #expect(prenom == "Hillel")
        #expect(decompte)
        let applis = exporte.tableau("blocked_apps") ?? []
        #expect(applis == [JSON.chaine("com.exemple")])
        // Une journée sans sujet n'a pas de clé « themes ».
        let sansSujet = try #require(exporte.objet("days")?.objet("2026-09-20"))
        let aDesSujets = sansSujet.a("themes")
        #expect(!aDesSujets)
    }

    @Test func unFichierQuiNEstPasUneSauvegardeEstRefuse() {
        var journal = Journal()
        var reglages = Reglages()
        let pasDuJson = SauvegardeTests.importe("pas du json", &journal, &reglages)
        #expect(pasDuJson == nil)
        let autre = SauvegardeTests.importe(#"{"format":"autre"}"#, &journal, &reglages)
        #expect(autre == nil)
        let rienNAChange = reglages.brut.estVide && journal.dates.isEmpty
        #expect(rienNAChange)
    }

    @Test func uneNoteSeuleNeValidePasLaJourneeEtSurvitAUnAllerRetour() throws {
        let jour = SauvegardeTests.aujourdhui
        var s = Journal()
        s.setNote(date: jour, note: "une pensée")
        let faite = s.isDone(jour)
        #expect(!faite)
        let seule = s[jour]?.noteSeule
        #expect(seule == true)
        // L'export la marque, et l'import la relit telle quelle.
        let exporte = try SauvegardeTests.exporte(s, Reglages())
        let marque = exporte.objet("days")?.objet(jour.iso)?.booleen("note_seule")
        #expect(marque == true)
        var t = Journal()
        var reglages = Reglages()
        let n = SauvegardeTests.importe(exporte.texte(indentation: 2), &t, &reglages)
        #expect(n == 1)
        let relueFaite = t.isDone(jour)
        #expect(!relueFaite)
        // Une hitbodedout le même jour la transforme en journée faite, note gardée.
        s.addSession(minutes: 10, date: jour)
        let faiteEnsuite = s.isDone(jour), note = s[jour]?.note
        #expect(faiteEnsuite)
        #expect(note == "une pensée")
        // Une note seule effacée disparaît.
        var u = Journal()
        u.setNote(date: jour, note: "x")
        u.setNote(date: jour, note: "")
        let effacee = u[jour]
        #expect(effacee == nil)
    }

    @Test func lImportRejetteLesDatesFaussesOuAVenirEtBorneLesValeurs() throws {
        var journal = Journal()
        var reglages = Reglages()
        let note = String(repeating: "a", count: 5000)
        let texte = [
            #"{"format":"myhitbodedut","version":1,"days":{"2026-13-45":{"minutes":10},"x":{"minutes":10},"#,
            #""2099-01-01":{"minutes":10},"2026-09-20":{"minutes":-5,"note":""#, note, #""}},"#,
            #""settings":{"target_minutes":0,"music_volume":500,"snooze_minutes":15},"paused_dates":["2026-02-30","2026-09-21"]}"#,
        ].joined()
        let n = SauvegardeTests.importe(texte, &journal, &reglages)
        #expect(n == 1)
        let jour = try #require(journal[JourCivil.du("2026-09-20")])
        let longueur = jour.note.utf16.count
        #expect(jour.minutes == 0)
        #expect(longueur == 4000)
        // Le site garde l'ancienne valeur d'un réglage hors bornes (15 et 60) ; Android, et iOS avec lui,
        // la ramène dans ses bornes (Store.importJson : coerceIn).
        let duree = reglages.targetMinutes, volume = reglages.musicVolume, report = reglages.snoozeMinutes
        #expect(duree == 1)
        #expect(volume == 100)
        #expect(report == 15)
        let pauseValable = reglages.pausedDates.contains("2026-09-21")
        let pauseFausse = reglages.pausedDates.contains("2026-02-30")
        #expect(pauseValable)
        #expect(!pauseFausse)
        let fausse = Journal.dateValide("2026-02-30"), vraie = Journal.dateValide("2026-09-29")
        #expect(fausse == nil)
        #expect(vraie == JourCivil.du("2026-09-29"))
    }

    @Test func relectureDu0211SauvegardeDatesNotes() throws {
        // Le site n'écrit les réglages de la barrière et des rappels que s'ils sont venus d'un import ; iOS a
        // la barrière et les rappels, et écrit leurs vraies valeurs, comme Android (PORTAGE.md § 3.6).
        let exporte = try SauvegardeTests.exporte(Journal(), Reglages())
        let settings = try #require(exporte.objet("settings"))
        for cle in ["window_start", "window_end", "snooze_minutes", "reminder_enabled", "reminder_minutes", "reminder_times"] {
            let present = settings.a(cle)
            #expect(present, "\(cle)")
        }
        // Le fond « contraste » existe des deux côtés.
        var journal = Journal()
        var reglages = Reglages()
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","version":1,"days":{},"settings":{"apparence_fond":"contraste"}}"#,
                                    &journal, &reglages)
        let fond = reglages.fond
        #expect(fond == .contraste)
        // Le site refuse une année d'avant 2000 ; Android l'accepte, et iOS avec lui.
        let lointaine = SauvegardeTests.importe(#"{"format":"myhitbodedut","version":1,"days":{"0202-01-01":{"minutes":5}}}"#,
                                                &journal, &reglages)
        #expect(lointaine == 1)
        let avant2000 = Journal.dateValide("1999-12-31"), pasBissextile = Journal.dateValide("2026-02-29")
        let bissextile = Journal.dateValide("2028-02-29")
        #expect(avant2000 != nil)
        #expect(pasBissextile == nil)
        #expect(bissextile != nil)
    }

    // MARK: journal-plus.test.mjs

    @Test func laSauvegardeExporteeReimporteeSansEcraserCeQuiEstDejaNote() throws {
        let deuxNovembre = JourCivil.du("2026-11-02")
        let premier = JourCivil.du("2026-11-01"), trente = JourCivil.du("2026-10-30")
        var a = Journal()
        a.ecrirePlus(JournalPlus.Plus(avant: 1, apres: 5, gratitude: "g", travail: "t"), pour: premier)
        a.ecrirePlus(JournalPlus.Plus(avant: 3, apres: 3), pour: trente)
        let fichier = Sauvegarde.exporter(journal: a, reglages: Reglages(), maintenant: SauvegardeTests.maintenant)
        let relu = try ObjetJSON(texte: fichier)
        let ecrit = relu.objet("journal_plus")?.objet("2026-11-01")
        #expect(ecrit == ObjetJSON([("avant", .entier(1)), ("apres", .entier(5)), ("gratitude", .chaine("g")), ("travail", .chaine("t"))]))

        var b = Journal()
        var reglagesB = Reglages()
        b.ecrirePlus(JournalPlus.Plus(gratitude: "déjà là"), pour: trente)
        let n = SauvegardeTests.importe(fichier, &b, &reglagesB, aujourdhui: deuxNovembre)
        #expect(n == 0)
        let pris = b.lirePlus(premier), garde = b.lirePlus(trente)
        #expect(pris == JournalPlus.Plus(avant: 1, apres: 5, gratitude: "g", travail: "t"))
        #expect(garde == JournalPlus.Plus(gratitude: "déjà là"))

        // Un fichier d'Android, sans la clé, s'importe comme avant ; une date future ou fausse est ignorée.
        var c = Journal()
        var reglagesC = Reglages()
        let sansCle = SauvegardeTests.importe(#"{"format":"myhitbodedut","version":1,"days":{}}"#, &c, &reglagesC, aujourdhui: deuxNovembre)
        #expect(sansCle == 0)
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","journal_plus":{"2027-01-01":{"avant":2},"2026-02-30":{"avant":2}}}"#,
                                    &c, &reglagesC, aujourdhui: deuxNovembre)
        let exporteC = try SauvegardeTests.exporte(c, reglagesC)
        let plusC = exporteC.objet("journal_plus")
        #expect(plusC == ObjetJSON())
    }

    // MARK: musique.test.mjs

    @Test func laLectureAleatoireGardeeEtRendueParLaSauvegarde() throws {
        var reglages = Reglages()
        let auDepart = reglages.musicShuffle
        #expect(!auDepart)
        reglages.setMusicShuffle(true)
        let exporte = try SauvegardeTests.exporte(Journal(), reglages)
        let ecrit = exporte.objet("settings")?.booleen("music_shuffle")
        #expect(ecrit == true)
        var autreJournal = Journal()
        var autre = Reglages()
        _ = SauvegardeTests.importe(exporte.texte(indentation: 2), &autreJournal, &autre)
        let relu = autre.musicShuffle
        #expect(relu)
        // Une valeur qui n'est pas un booléen ne change rien.
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","days":{},"settings":{"music_shuffle":"oui"}}"#, &autreJournal, &autre)
        let garde = autre.musicShuffle
        #expect(garde)
    }

    // MARK: hitbodedut.test.mjs

    @Test func leGuideEstEteintParDefautEtPasseParLaSauvegarde() throws {
        var journal = Journal()
        var reglages = Reglages()
        let auDepart = reglages.guidedHitbodedut
        #expect(!auDepart)
        reglages.setGuidedHitbodedut(true)
        var json = try SauvegardeTests.exporte(journal, reglages)
        let ecrit = json.objet("settings")?.booleen("guided_hitbodedut")
        #expect(ecrit == true)
        var autreJournal = Journal()
        var autre = Reglages()
        _ = SauvegardeTests.importe(json.texte(), &autreJournal, &autre)
        let relu = autre.guidedHitbodedut
        #expect(relu)
        var settings = try #require(json.objet("settings"))
        settings["guided_hitbodedut"] = .booleen(false)
        json["settings"] = .objet(settings)
        _ = SauvegardeTests.importe(json.texte(), &autreJournal, &autre)
        let eteint = autre.guidedHitbodedut
        #expect(!eteint)
        // Une sauvegarde sans la clé ne touche pas au réglage (Store.importJson : settings.has).
        settings["guided_hitbodedut"] = nil
        json["settings"] = .objet(settings)
        _ = SauvegardeTests.importe(json.texte(), &journal, &reglages)
        let garde = reglages.guidedHitbodedut
        #expect(garde)
    }

    // MARK: PORTAGE.md § 3.9

    @Test func unFichierAndroidForgeToutesLesBranches() throws {
        var journal = Journal()
        var reglages = Reglages()
        let longue = String(repeating: "x", count: 5000)
        let texte = [
            #"{"format":"myhitbodedut","version":1,"exported_at":"2026-11-13T08:15:30.123456789Z","days":{"#,
            #""2026-11-03":{"minutes":20,"note":"Dehors."},"2026-11-04":{"minutes":0,"note":"Pas pu.","note_seule":true},"#,
            #""2026-11-4":{"minutes":10,"note":"mal formée"},"2026-11-16":{"minutes":10,"note":"demain"},"#,
            #""2026-11-05":{"minutes":1441,"note":""#, longue, #""},"2026-11-06":{"minutes":"20","note_seule":"true"}},"#,
            #""settings":{"reminder_minutes":480,"target_minutes":"30","music_volume":"70","pause_shabbat":"false"}}"#,
        ].joined()
        let n = SauvegardeTests.importe(texte, &journal, &reglages)
        #expect(n == 4)
        let sansSujet = journal[JourCivil.du("2026-11-03")]
        #expect(sansSujet == Journee(minutes: 20, note: "Dehors."))
        let seule = journal[JourCivil.du("2026-11-04")]
        #expect(seule == Journee(minutes: 0, note: "Pas pu.", noteSeule: true))
        let bornee = try #require(journal[JourCivil.du("2026-11-05")])
        let longueur = bornee.note.utf16.count
        #expect(bornee.minutes == 1440)
        #expect(longueur == 4000)
        let enChaines = journal[JourCivil.du("2026-11-06")]
        #expect(enChaines == Journee(minutes: 20, note: "", noteSeule: true))
        let demain = journal[JourCivil.du("2026-11-16")]
        #expect(demain == nil)
        let dates = journal.dates.count
        #expect(dates == 4)
        let heures = reglages.reminderTimes, duree = reglages.targetMinutes, volume = reglages.musicVolume
        let chabbat = reglages.shabbatMode
        #expect(heures == [480])
        #expect(duree == 30)
        #expect(volume == 70)
        #expect(!chabbat)
    }

    @Test func unFichierDuSiteAvecJournalPlusSansReglagesDeLaBarriere() {
        var journal = Journal()
        var reglages = Reglages()
        reglages.setWindow(startMinutes: 1200, endMinutes: 300)
        reglages.setReminderTimes([300, 900])
        let texte = #"""
            {"format":"myhitbodedut","version":1,"exported_at":"2026-11-02T10:00:00.000Z",
             "days":{"2026-11-01":{"minutes":15,"note":"web"}},
             "settings":{"target_minutes":20,"daily_goal_minutes":0,"pause_shabbat":true,"in_israel":false,"guided_hitbodedut":false,
              "first_name":"","hide_countdown":false,"music_enabled":true,"music_volume":60,"music_shuffle":false,"music_track":"",
              "adresse":"","apparence_mode":"auto","apparence_fond":"vert","apparence_accent":"vert"},
             "paused_dates":[],"blocked_apps":[],
             "journal_plus":{"2026-11-01":{"avant":2,"apres":4,"gratitude":"La santé des enfants.","travail":"La patience."}}}
            """#
        let n = SauvegardeTests.importe(texte, &journal, &reglages)
        #expect(n == 1)
        let debut = reglages.windowStart, fin = reglages.windowEnd, heures = reglages.reminderTimes
        #expect(debut == 1200)
        #expect(fin == 300)
        #expect(heures == [300, 900])
        let plus = journal.lirePlus(JourCivil.du("2026-11-01"))
        #expect(plus == JournalPlus.Plus(avant: 2, apres: 4, gratitude: "La santé des enfants.", travail: "La patience."))
        let duree = reglages.targetMinutes
        #expect(duree == 20)
    }

    /// Un état où tout est posé, autrement que par défaut.
    private static func etatComplet() -> (Journal, Reglages) {
        var x = Journal()
        x.addSession(minutes: 25, note: "deux \"séances\" / une \\ note", theme: "famille", date: JourCivil.du("2026-10-02"))
        x.addSession(minutes: 5, theme: "e\u{301}", date: JourCivil.du("2026-10-02"))
        x.setNote(date: JourCivil.du("2026-09-30"), note: "seule")
        x.addSession(minutes: 10, date: JourCivil.du("2026-10-01"))
        x.ecrirePlus(JournalPlus.Plus(avant: 2, apres: 4, gratitude: "merci", travail: "la patience"), pour: JourCivil.du("2026-10-01"))
        x.setFirstName("  Hillel ")
        var r = Reglages()
        r.setWindow(startMinutes: 1200, endMinutes: 300)
        r.setSnoozeMinutes(30)
        r.setTargetMinutes(40)
        r.setDailyGoal(50)
        r.setShabbatMode(false)
        r.setInIsrael(true)
        r.setReminderEnabled(true)
        r.setReminderTimes([1260, 420])
        r.setHideCountdown(true)
        r.setGuidedHitbodedut(true)
        r.setMusicEnabled(false)
        r.setMusicVolume(35)
        r.setMusicShuffle(true)
        r.setMusicTrackId("yanuka_nigoun_3")
        r.setAdresse("f")
        r.setModeApparence("sombre")
        r.setFond(.rose)
        r.setAccent(.ambre)
        r.togglePausedDate("2026-05-01")
        r.setBlockedApps(["com.instagram.android", "com.whatsapp"])
        return (x, r)
    }

    @Test func allerRetourImporterExporterRendLeMemeEtat() {
        let (x, r) = SauvegardeTests.etatComplet()
        let fichier = Sauvegarde.exporter(journal: x, reglages: r, maintenant: SauvegardeTests.maintenant, fuseauTelephone: "UTC")
        var y = Journal()
        var s = Reglages()
        let n = SauvegardeTests.importe(fichier, &y, &s)
        #expect(n == 3)
        let jours = y.jours == x.jours, plus = y.plus == x.plus
        #expect(jours)
        #expect(plus)
        let prenom = y.firstName
        #expect(prenom == "Hillel")
        // Les réglages relus s'exportent comme ceux d'origine : le même fichier, à l'octet.
        let refait = Sauvegarde.exporter(journal: y, reglages: s, maintenant: SauvegardeTests.maintenant, fuseauTelephone: "UTC")
        let identique = refait.egalUnites(fichier)
        #expect(identique, "\(refait)")
    }

    @Test func exporterApresImporterAndroidGardeLesApplicationsEtLes21Reglages() throws {
        // Le fichier d'Android du site, avec un morceau livré sur iOS.
        let texte = SauvegardeTests.android.replacingOccurrences(of: "niggoun_05", with: "hamelech_basade")
        var journal = Journal()
        var reglages = Reglages()
        _ = SauvegardeTests.importe(texte, &journal, &reglages)
        let exporte = try SauvegardeTests.exporte(journal, reglages)
        let fichier = try ObjetJSON(texte: texte)
        let attendus = try #require(fichier.objet("settings"))
        let settings = try #require(exporte.objet("settings"))
        let nombre = settings.count
        #expect(nombre == 21)
        for cle in Sauvegarde.clesReglages {
            let valeur = settings[cle], attendue = attendus[cle]
            #expect(valeur == attendue, "\(cle)")
        }
        let applis = exporte.tableau("blocked_apps"), applisAttendues = fichier.tableau("blocked_apps")
        #expect(applis == applisAttendues)
    }

    @Test func lExportDIOSRelueDonneLesMemesValeursEtLesClesDansLOrdreDAndroid() throws {
        let (x, r) = SauvegardeTests.etatComplet()
        let texte = Sauvegarde.exporter(journal: x, reglages: r, maintenant: SauvegardeTests.maintenant, fuseauTelephone: "UTC")
        let racine = try ObjetJSON(texte: texte)
        let cles = racine.cles
        #expect(cles == ["format", "version", "exported_at", "days", "settings", "paused_dates", "blocked_apps", "journal_plus"])
        let settings = try #require(racine.objet("settings"))
        let clesReglages = settings.cles, nombre = Sauvegarde.clesReglages.count
        #expect(clesReglages == Sauvegarde.clesReglages)
        #expect(nombre == 21)
        // Relue puis réécrite, la sauvegarde d'iOS rend les mêmes octets : l'indentation est celle d'Android.
        let reecrit = racine.texte(indentation: 2)
        let memesOctets = reecrit.egalUnites(texte)
        #expect(memesOctets)
        let debut = texte.commenceParUnites("{\n  \"format\": \"myhitbodedut\",\n  \"version\": 1,\n  \"exported_at\": \"2026-11-13T13:53:20.000Z\",\n")
        #expect(debut, "\(texte)")
        // Les journées dans l'ordre des dates, même ajoutées dans le désordre.
        let days = try #require(racine.objet("days"))
        let ordre = days.cles
        #expect(ordre == ["2026-09-30", "2026-10-01", "2026-10-02"])
        // themes et note_seule absents quand ils sont vides ou faux.
        let simple = try #require(days.objet("2026-10-01"))
        let clesSimple = simple.cles
        #expect(clesSimple == ["minutes", "note"])
        let seule = try #require(days.objet("2026-09-30"))
        let clesSeule = seule.cles
        #expect(clesSeule == ["minutes", "note", "note_seule"])
        let fenetre = settings.entier("window_start"), report = settings.entier("snooze_minutes")
        let israel = settings.booleen("in_israel"), morceau = settings.texte("music_track")
        let fond = settings.texte("apparence_fond"), prenom = settings.texte("first_name")
        #expect(fenetre == 1200)
        #expect(report == 30)
        #expect(israel)
        #expect(morceau == "yanuka_nigoun_3")
        #expect(fond == "rose")
        #expect(prenom == "Hillel")
        let heures = settings.tableau("reminder_times") ?? []
        #expect(heures == [JSON.entier(420), JSON.entier(1260)])
        let applis = racine.tableau("blocked_apps") ?? []
        #expect(applis == [JSON.chaine("com.instagram.android"), JSON.chaine("com.whatsapp")])
        let plus = racine.objet("journal_plus")?.objet("2026-10-01")
        #expect(plus == ObjetJSON([("avant", .entier(2)), ("apres", .entier(4)), ("gratitude", .chaine("merci")),
                                   ("travail", .chaine("la patience"))]))
    }

    // MARK: Ce que les vecteurs ne disent pas

    @Test func aujourdhuiEstAccepteDemainNon() {
        var journal = Journal()
        var reglages = Reglages()
        let texte = [
            #"{"format":"myhitbodedut","days":{"2026-11-15":{"minutes":5},"2026-11-16":{"minutes":6}},"#,
            #""journal_plus":{"2026-11-15":{"avant":1},"2026-11-16":{"avant":2}}}"#,
        ].joined()
        let n = SauvegardeTests.importe(texte, &journal, &reglages)
        #expect(n == 1)
        let aujourdhui = journal[JourCivil.du("2026-11-15")], demain = journal[JourCivil.du("2026-11-16")]
        #expect(aujourdhui == Journee(minutes: 5, note: ""))
        #expect(demain == nil)
        let plus = journal.lirePlus(JourCivil.du("2026-11-15")).avant, plusDemain = journal.lirePlus(JourCivil.du("2026-11-16")).vide
        #expect(plus == 1)
        #expect(plusDemain)
        // Le dernier jour de l'année : le lendemain est dans l'année suivante.
        var fin = Journal()
        let finAnnee = SauvegardeTests.importe(#"{"format":"myhitbodedut","days":{"2026-12-31":{"minutes":1},"2027-01-01":{"minutes":2}}}"#,
                                               &fin, &reglages, aujourdhui: JourCivil.du("2026-12-31"))
        #expect(finAnnee == 1)
    }

    @Test func lesAdaptationsDIOS() throws {
        var journal = Journal()
        var reglages = Reglages()
        reglages.setModeApparence("sombre")
        reglages.setFond(.rose)
        reglages.setAccent(.ambre)
        // Un morceau ajouté sur Android, ou qu'iOS ne livre pas, n'est pas repris ; un morceau livré l'est.
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","settings":{"music_track":"content://media/external/audio/media/42"}}"#,
                                    &journal, &reglages)
        let uri = reglages.musicTrackId
        #expect(uri == nil)
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","settings":{"music_track":"niggoun_05"}}"#, &journal, &reglages)
        let inconnu = reglages.musicTrackId
        #expect(inconnu == nil)
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","settings":{"music_track":"hamelech_basade"}}"#, &journal, &reglages)
        let livre = reglages.musicTrackId
        #expect(livre == "hamelech_basade")
        // Une apparence inconnue est ignorée (Android la ramènerait à « auto » et au vert).
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","settings":{"apparence_mode":"nuit","apparence_fond":"violet","apparence_accent":"rouge"}}"#,
                                    &journal, &reglages)
        let mode = reglages.modeApparence, fond = reglages.fond, accent = reglages.accent
        #expect(mode == "sombre")
        #expect(fond == .rose)
        #expect(accent == .ambre)
        // Les applications d'Android sont gardées telles quelles, et repartent à l'export.
        _ = SauvegardeTests.importe(#"{"format":"myhitbodedut","blocked_apps":["com.instagram.android"]}"#, &journal, &reglages)
        let exporte = try SauvegardeTests.exporte(journal, reglages)
        let applis = exporte.tableau("blocked_apps") ?? []
        #expect(applis == [JSON.chaine("com.instagram.android")])
        // 2 Mo au plus.
        let debut = #"{"format":"myhitbodedut","x":""#, fin = #""}"#
        let place = Sauvegarde.importMaxOctets - debut.utf8.count - fin.utf8.count
        let juste = debut + String(repeating: "a", count: place) + fin
        let tropGros = debut + String(repeating: "a", count: place + 1) + fin
        let accepte = SauvegardeTests.importe(juste, &journal, &reglages)
        let refuse = SauvegardeTests.importe(tropGros, &journal, &reglages)
        #expect(accepte == 0)
        #expect(refuse == nil)
        // Le JSON relâché qu'org.json accepte n'est écrit par aucun des trois programmes : refusé.
        let relache = SauvegardeTests.importe("{'format':'myhitbodedut'}", &journal, &reglages)
        #expect(relache == nil)
    }

    @Test func lHorodatageEstEnUTCAvecSesMillisecondes() {
        let cas: [(Int64, String)] = [
            (0, "1970-01-01T00:00:00.000Z"),
            (-1, "1969-12-31T23:59:59.999Z"),
            (1_762_000_000_123, "2025-11-01T12:26:40.123Z"),
            (1_794_578_000_000, "2026-11-13T13:53:20.000Z"),
            (253_402_300_799_999, "9999-12-31T23:59:59.999Z"),
        ]
        for (millis, attendu) in cas {
            let texte = Sauvegarde.horodatage(millis)
            #expect(texte == attendu, "\(millis)")
        }
        let nom = Sauvegarde.nomDeFichier(JourCivil.du("2026-11-13"))
        #expect(nom == "myhitbodedut-2026-11-13.json")
    }
}
