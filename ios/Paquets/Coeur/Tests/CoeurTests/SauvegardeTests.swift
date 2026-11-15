import Foundation
import Testing
@testable import Coeur

/// La sauvegarde JSON (PORTAGE.md § 3.9). Devant Android : les fichiers d'or de Tests/Vecteurs/sauvegarde,
/// importés par `Store.importJson` dans un téléphone neuf puis exportés, sur le Kotlin de la version Play
/// (Tests/Vecteurs/sauvegarde.json, tools/vecteurs_ios). Puis les cas d'import et d'export du site
/// (web/test/regles, journal-plus, musique, hitbodedut), les adaptations d'iOS, l'aller-retour, l'ordre
/// des clés, le dépôt, et la vraie sauvegarde du propriétaire (P7), qui n'est pas au dépôt.
/// Repris de la PR #29 (version 1) et porté sur la version 2.
@Suite("Sauvegarde")
struct SauvegardeTests {

    /// Le jour de l'import : il décide des journées à venir et date les historiques des réglages.
    private let aujourdhui = JourCivil.du("2026-11-15")

    /// Un téléphone neuf, comme le Theatre de l'oracle (fuseau UTC : hors d'Israël).
    private func neuf() -> Donnees { Donnees(reglages: Reglages(enIsrael: false)) }

    private func importer(_ texte: String, _ d: inout Donnees) -> Int? {
        Sauvegarde.importer(texte, dans: &d, aujourdhui: aujourdhui)
    }

    /// Un fichier d'or.
    private func fichier(_ nom: String) throws -> String {
        try Depot.texte("ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde/" + nom)
    }

    /// L'export rendu comparable, comme le fait l'oracle (VecteursSauvegarde.normalise) : sans l'instant,
    /// journées et journal enrichi par date, jours de pause et applications triés.
    private func normalise(_ texte: String) throws -> ObjetJSON {
        var o = try ObjetJSON(texte: texte)
        o["exported_at"] = nil
        for cle in ["days", "journal_plus"] {
            guard let objet = o.objet(cle) else { continue }
            o[cle] = .objet(ObjetJSON(objet.cles.sorted().map { ($0, objet[$0] ?? .nul) }))
        }
        for cle in ["paused_dates", "blocked_apps"] {
            guard let t = o.tableau(cle) else { continue }
            o[cle] = .tableau(t.indices.map { t.texte($0) }.sorted().map { JSON.chaine($0) })
        }
        return o
    }

    /// Ce qui diffère entre deux exports, clé par clé (et réglage par réglage), pour le message d'échec.
    private func ecarts(_ a: ObjetJSON, _ b: ObjetJSON) -> String {
        var lignes: [String] = []
        if a.cles != b.cles { lignes.append("clés \(a.cles) au lieu de \(b.cles)") }
        for cle in b.cles where a[cle] != b[cle] {
            if case .objet(let x)? = a[cle], case .objet(let y)? = b[cle] {
                for k in Set(x.cles + y.cles).sorted() where x[k] != y[k] {
                    lignes.append("\(cle).\(k) : \(x[k]?.texte() ?? "∅") au lieu de \(y[k]?.texte() ?? "∅")")
                }
            } else {
                lignes.append("\(cle) : \((a[cle]?.texte() ?? "∅").prefix(300)) au lieu de \((b[cle]?.texte() ?? "∅").prefix(300))")
            }
        }
        return lignes.joined(separator: " ; ")
    }

    /// Un cas des vecteurs : les fichiers importés à la suite, et ce qu'Android en a fait.
    private struct Cas {
        let nom: String
        let textes: [String]
        let comptes: [Int?]
        let export: String
        let histoireShabbat: String?
        let histoireIsrael: String?
        let texte: String?
    }

    private func cas() throws -> [Cas] {
        let tous = try Depot.vecteurs("sauvegarde.json").tableau("cas") ?? []
        return try tous.indices.compactMap { tous.objet($0) }.map { (c: ObjetJSON) throws -> Cas in
            let textes: [String]
            if let f = c.tableau("fichiers") {
                textes = try f.indices.map { try fichier(f.texte($0)) }
            } else {
                let t = c.tableau("textes") ?? []
                textes = t.indices.map { t.texte($0) }
            }
            let comptes = c.tableau("comptes") ?? []
            let h = c.objet("historiques") ?? ObjetJSON()
            func historique(_ cle: String) -> String? {
                h.estNul(cle) ? nil : h.texte(cle).replacingOccurrences(of: "AUJOURDHUI", with: aujourdhui.iso)
            }
            return Cas(nom: c.texte("nom"), textes: textes,
                       comptes: comptes.indices.map { comptes.estNul($0) ? nil : comptes.entier($0) },
                       export: c.texte("export"), histoireShabbat: historique("pause_shabbat_histoire"),
                       histoireIsrael: historique("in_israel_histoire"), texte: c.a("texte") ? c.texte("texte") : nil)
        }
    }

    // MARK: Devant Android

    @Test func chaqueCasSeLitEtSEcritCommeSurAndroid() throws {
        let tous = try cas()
        #expect(tous.map(\.nom) == ["neuf", "android-v1-forge", "android-v2-forge", "fusion", "web-v2", "refuses", "chiffre",
                                    "aller-retour-v1", "aller-retour-v2"])
        for c in tous {
            var d = neuf()
            var comptes: [Int?] = []
            for texte in c.textes { comptes.append(importer(texte, &d)) }
            #expect(comptes == c.comptes, "\(c.nom) : journées lues")
            let rendu = try normalise(Sauvegarde.exporter(d, maintenant: 0))
            let attendu = try ObjetJSON(texte: c.export)
            #expect(rendu == attendu, "\(c.nom) : \(ecarts(rendu, attendu))")
            #expect(d.reglages.histoireShabbat == c.histoireShabbat, "\(c.nom) : pause_shabbat_histoire")
            #expect(d.reglages.histoireIsrael == c.histoireIsrael, "\(c.nom) : in_israel_histoire")
            if let texte = c.texte {
                // Ensembles d'un élément, journées dans l'ordre : l'export d'iOS est celui d'Android, octet pour octet.
                let ios = Sauvegarde.exporter(d, maintenant: 0).split(separator: "\n", omittingEmptySubsequences: false)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("\"exported_at\"") }.joined(separator: "\n")
                #expect(ios == texte, "\(c.nom) : l'export, octet pour octet")
            }
        }
    }

    @Test func leFichierForgeV1CouvreToutesLesBranches() throws {
        var d = neuf()
        let lues = importer(try fichier("android-v1-forge.json"), &d)
        #expect(lues == 13)
        let j = d.journal.jours
        #expect(j[.du("2020-03-03")]?.minutes == 25, "nombre écrit en chaîne")
        #expect(j[.du("2020-03-04")]?.minutes == 20, "décimal tronqué")
        #expect(j[.du("2020-03-05")]?.minutes == 0)
        #expect(j[.du("2020-03-05")]?.note.utf16.count == 4000)
        #expect(j[.du("2020-03-06")]?.minutes == 1440)
        #expect(j[.du("2020-03-06")]?.themes == ["inconnu", "famille", "7"], "une clé inconnue est gardée, un nombre lu en texte")
        #expect(j[.du("2020-03-07")]?.noteSeule == true, "booléen écrit en chaîne")
        #expect(j[.du("2020-03-01")]?.themes == ["gratitude", "parnassa", "gratitude"], "un doublon du fichier reste, comme sur Android")
        #expect(j[.du("2020-03-09")]?.minutes == 20, "4 294 967 316 ramené à 32 bits, comme intValue")
        #expect(j[.du("2020-03-09")]?.note == "12.5")
        #expect(j[.du("2020-03-10")]?.note == "null", "optString d'un null")
        #expect(j[.du("2020-03-11")]?.minutes == 9, "une clé répétée : la dernière valeur")
        #expect(j[.du("2020-03-12")]?.minutes == 100)
        let signe = try #require(JourCivil(java: "-0001-12-31"))
        #expect(j[signe]?.minutes == 2, "les années signées de java.time")
        #expect(j[.du("2099-01-01")] == nil)
        let r = d.reglages
        #expect(r.rappels == [1260], "reminder_minutes sans reminder_times")
        #expect(r.debutFenetre == 300 && r.finFenetre == 660, "« 300 » est lu ; 2000 n'est pas une heure")
        #expect(r.report == 240 && r.duree == 1 && r.objectifJour == 240 && r.volume == 100)
        #expect(!r.pauseShabbat && r.enIsrael && r.guidee && r.masquerDecompte && r.morceau == "yanuka_nigoun_3")
        #expect(d.journal.prenom == "Avraham Yitzhak Yaakov Moshe Aharon Dav", "rogné, coupé à 40, rogné encore")
        #expect(r.applisBloquees == ["com.whatsapp", "com.instagram.android", "5"])
        #expect(r.joursPause.map(\.iso).sorted() == ["+12345-01-01", "2020-01-10", "2020-01-12"])
    }

    @Test func lesAjoutsDeLaVersion2SontLusCommeSurAndroid() throws {
        var d = neuf()
        let lues = importer(try fichier("android-v2-forge.json"), &d)
        #expect(lues == 2)
        #expect(d.journal.plus[.du("2021-05-30")]
                == JournalPlus(avant: 5, apres: 0, gratitude: String(repeating: "g", count: 200), travail: "3"))
        #expect(d.journal.plus[.du("2021-05-31")] == JournalPlus(avant: 3, apres: 2))
        #expect(d.journal.plus.count == 2, "vide, à venir, mal datée ou pas un objet : écartées")
        #expect(d.reglages.tikkun == [JourCivil.du("2021-05-28"), JourCivil.du("2021-05-30")])
        #expect(d.lecture.favoris == ["s:chaharit", "l:likoutei_moharan", "s:a", "l:b"],
                "« s:a|l:b » se relit en deux favoris, comme sur Android")
        #expect(d.lecture.chizukFavoris == ["tehilim-145-18", "by-47-1"])
        #expect(d.lecture.marques == [
            MarquePage(cle: "l:likoutei_moharan", nusah: "", section: 3, bloc: 12, apercu: "אשרי תמימי דרך"),
            MarquePage(cle: "s:chaharit", nusah: "edot", section: 2, bloc: 4, apercu: "מודה"),
            MarquePage(cle: "s:arvit", nusah: "sefard", section: 0, bloc: 0, apercu: ""),
        ])
        let r = d.reglages
        #expect(r.enIsrael && r.enIsraelManuel && r.nusah == .ashkenaz && r.lectureEchelle == 2 && r.lecturePolice == "miriam")
        #expect(r.lectureSombre && r.lectureMasquee && !r.lectureEcranAllume && r.lectureLangues == "fr+en")
        #expect(r.rappels == [420, 600, 1260] && r.volume == 0 && r.debutFenetre == 1260 && r.finFenetre == 120)
    }

    @Test func leFichierDuSiteSeLitEnEntier() throws {
        var d = neuf()
        let lues = importer(try fichier("web-v2.json"), &d)
        #expect(lues == 3)
        #expect(d.journal.jours[.du("2022-01-30")] == Journee(minutes: 25, themes: ["gratitude", "famille"]))
        #expect(d.journal.jours[.du("2022-02-01")]?.noteSeule == true)
        #expect(d.journal.plus == [JourCivil.du("2022-01-30"): JournalPlus(avant: 2, apres: 4, gratitude: "La santé des enfants.",
                                                                           travail: "La patience.")])
        #expect(d.reglages.tikkun == [JourCivil.du("2022-01-31"), JourCivil.du("2022-02-01")])
        #expect(d.lecture.favoris == ["l:likoutei_moharan", "s:chaharit"])
        #expect(d.lecture.marques.count == 2)
        let r = d.reglages
        #expect(r.duree == 20 && r.objectifJour == 30 && r.enIsraelManuel && r.nusah == .sefard)
        #expect(r.lectureEchelle == Float(1.3) && r.lecturePolice == "frank" && r.lectureLangues == "he+fr")
        #expect(r.morceau == "ianir_hello" && r.adresse == "f" && r.fond == .sable && r.accent == .bordeaux && r.mode == .sombre)
        // La barrière et les rappels, que le site n'écrit pas, gardent les réglages d'ici.
        #expect(r.debutFenetre == 360 && r.finFenetre == 660 && r.rappels == [420])
        #expect(d.journal.prenom == "Sarah")
    }

    // MARK: Aller-retour

    @Test func importerExporterRendLeMeme() throws {
        for noms in [["android-v1-forge.json"], ["android-v2-forge.json"], ["fusion-1.json", "fusion-2.json"], ["web-v2.json"]] {
            var d = neuf()
            for n in noms { _ = importer(try fichier(n), &d) }
            var relu = neuf()
            let export = Sauvegarde.exporter(d, maintenant: 1_763_021_730_123)
            let lues = importer(export, &relu)
            #expect(lues == d.journal.jours.count, "\(noms)")
            #expect(relu.journal == d.journal && relu.lecture == d.lecture, "\(noms)")
            #expect(Sauvegarde.exporter(relu, maintenant: 0) == Sauvegarde.exporter(d, maintenant: 0), "\(noms)")
            let reglages = d.reglages.exportes(prenom: d.journal.prenom)
            #expect(reglages.count == (d.reglages.lectureLangues == nil ? 28 : 29), "\(noms) : \(reglages.cles)")
        }
    }

    // MARK: Les cas du site (web/test), portés

    @Test func uneSauvegardeDAndroidSeFondDansUnJournalExistant() throws {
        var d = neuf()
        d.journal.jours[.du("2026-09-28")] = Journee(minutes: 30, note: "ici", themes: ["gratitude"])
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
        #expect(d.journal.jours[.du("2026-09-28")] == Journee(minutes: 45, note: "ici", themes: ["gratitude", "famille"]))
        let r = d.reglages
        #expect(r.duree == 30 && r.adresse == "f" && r.fond == .sable && r.accent == .violet && r.mode == .sombre)
        #expect(r.joursPause == [JourCivil.du("2026-09-30")] && r.guidee && r.rappelActif && r.enIsrael)
        #expect(r.morceau == "", "niggoun_05 n'est pas un morceau livré")
        let export = try ObjetJSON(texte: Sauvegarde.exporter(d, maintenant: 0))
        let e = try #require(export.objet("settings"))
        #expect(e.tableau("reminder_times") == [JSON.entier(420), JSON.entier(1260)])
        #expect(e.texte("first_name") == "Hillel" && e.booleen("hide_countdown"))
        let jour = try #require(export.objet("days")?.objet("2026-09-20"))
        #expect(!jour.a("themes") && !jour.a("note_seule"))
    }

    @Test func unFichierQuiNEstPasUneSauvegardeEstRefuse() throws {
        var d = neuf()
        for texte in ["pas du json", #"{"format":"autre"}"#, "[]", "", #"{"days":{}}"#] {
            let lues = importer(texte, &d)
            #expect(lues == nil, "« \(texte) »")
        }
        #expect(d == neuf())
        #expect(Sauvegarde.texte(Data(repeating: 0x20, count: Sauvegarde.tailleMax + 1)) == nil, "au-delà de 2 Mo")
        #expect(Sauvegarde.texte(Data(repeating: 0x20, count: Sauvegarde.tailleMax)) != nil)
        // Comme String(octets, UTF_8) : un octet mal formé devient U+FFFD, la lecture continue.
        let abime = Data(#"{"format":"myhitbodedut","days":{"2026-11-01":{"minutes":5,"note":"a"#.utf8) + Data([0xFF])
            + Data(#""}}}"#.utf8)
        let texte = try #require(Sauvegarde.texte(abime))
        let lues = importer(texte, &d)
        #expect(lues == 1)
        #expect(d.journal.jours[.du("2026-11-01")]?.note == "a\u{FFFD}")
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
        let jour = try #require(d.journal.jours[.du("2026-09-20")])
        #expect(jour.minutes == 0 && jour.note.utf16.count == 4000)
        #expect(d.reglages.duree == 1, "Android ramène à DureeSeance.MIN ; le site garde l'ancienne valeur")
        #expect(d.reglages.volume == 100, "Android ramène à 100 ; le site garde l'ancienne valeur")
        #expect(d.reglages.joursPause == [JourCivil.du("2026-09-21")])
    }

    @Test func uneNoteSeuleSurvitALAllerRetour() throws {
        var d = neuf()
        d.journal.jours[.du("2026-11-14")] = Journee(minutes: 0, note: "une pensée", noteSeule: true)
        let o = try ObjetJSON(texte: Sauvegarde.exporter(d, maintenant: 0))
        #expect(o.objet("days")?.objet("2026-11-14")?.booleen("note_seule") == true)
        var t = neuf()
        _ = importer(o.texte(), &t)
        #expect(t.journal.jours[.du("2026-11-14")]?.faite == false)
        // Fusion : note seule des deux côtés seulement.
        _ = importer(#"{"format":"myhitbodedut","days":{"2026-11-14":{"minutes":10}}}"#, &t)
        #expect(t.journal.jours[.du("2026-11-14")] == Journee(minutes: 10, note: "une pensée"))
    }

    @Test func lesSujetsSeReunissentSansDoublonCommeAndroid() {
        var d = neuf()
        // Deux séances du même sujet, le même jour : Android garde le doublon (addSession), et la fusion le retire.
        d.journal.jours[.du("2026-11-10")] = Journee(minutes: 20, themes: ["famille", "famille", "e\u{301}"])
        _ = importer(#"{"format":"myhitbodedut","days":{"2026-11-10":{"minutes":5,"themes":["gratitude","famille","é"]}}}"#, &d)
        // « é » précomposé et « e » suivi de l'accent sont deux chaînes pour Kotlin : les deux restent.
        let attendus: [[UInt16]] = ["famille", "e\u{301}", "gratitude", "\u{e9}"].map { Array($0.utf16) }
        #expect(d.journal.jours[.du("2026-11-10")]?.themes.map { Array($0.utf16) } == attendus)
    }

    @Test func leJournalEnrichiNEcrasePasCeQuiEstDejaNote() throws {
        var a = neuf()
        a.journal.plus[.du("2026-11-01")] = JournalPlus(avant: 1, apres: 5, gratitude: "g", travail: "t")
        a.journal.plus[.du("2026-10-30")] = JournalPlus(avant: 3, apres: 3)
        let fichier = Sauvegarde.exporter(a, maintenant: 0)
        var b = neuf()
        b.journal.plus[.du("2026-10-30")] = JournalPlus(gratitude: "déjà là")
        let lues = importer(fichier, &b)
        #expect(lues == 0)
        #expect(b.journal.plus[.du("2026-11-01")] == JournalPlus(avant: 1, apres: 5, gratitude: "g", travail: "t"))
        #expect(b.journal.plus[.du("2026-10-30")] == JournalPlus(gratitude: "déjà là"))
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
        #expect(d.reglages.histoireShabbat == "2000-01-01=1,2026-11-15=0", "le changement est daté du jour de l'import")
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

    @Test func uneTailleDeLectureIllisibleEstIgnoree() {
        var d = neuf()
        _ = importer(#"{"format":"myhitbodedut","settings":{"lecture_echelle":"1.5"}}"#, &d)
        #expect(d.reglages.lectureEchelle == 1.5, "un nombre écrit en chaîne, comme optDouble")
        // Android garderait NaN, puis ne saurait plus exporter (JSONObject refuse NaN) : iOS l'ignore.
        _ = importer(#"{"format":"myhitbodedut","settings":{"lecture_echelle":"NaN"}}"#, &d)
        #expect(d.reglages.lectureEchelle == 1.5)
        _ = importer(#"{"format":"myhitbodedut","settings":{"lecture_echelle":"Infinity"}}"#, &d)
        #expect(d.reglages.lectureEchelle == 2)
        _ = importer(#"{"format":"myhitbodedut","settings":{"lecture_echelle":true}}"#, &d)
        #expect(d.reglages.lectureEchelle == 1, "pas un nombre : 1, la valeur par défaut d'optDouble ici")
    }

    @Test func lesMorceauxLivresSontCeuxDuContenu() throws {
        let ids = try Morceau.lire(Depot.contenu("musique.json")).map { $0.id }
        #expect(ids == Sauvegarde.morceauxLivres)
    }

    @Test func lesPolicesSontCellesDuKotlin() throws {
        let polices = try TablesKotlin.lire(Depot.contenu("tables.json")).polices.map(\.cle)
        #expect(polices == Reglages.polices)
    }

    // MARK: Ordre et forme

    @Test func lExportSuitLOrdreDAndroidIndenteDeDeuxEspaces() throws {
        var d = neuf()
        _ = importer(try fichier("android-v2-forge.json"), &d)
        let texte = Sauvegarde.exporter(d, maintenant: 1_763_021_730_123)
        #expect(texte.hasPrefix("{\n  \"format\": \"myhitbodedut\",\n  \"version\": 2,\n  \"exported_at\": \"2025-11-13T08:15:30.123Z\",\n  \"days\": {\n    \"2021-05-30\": {\n      \"minutes\": 12,"))
        let o = try ObjetJSON(texte: texte)
        #expect(o.cles == ["format", "version", "exported_at", "days", "settings", "paused_dates", "blocked_apps", "journal_plus",
                           "tikkun_journal", "favoris", "chizuk_favoris", "marques_pages"])
        let tous = try cas()
        let casNeuf = try #require(tous.first { $0.nom == "neuf" })
        let android = try #require(try ObjetJSON(texte: casNeuf.export).objet("settings"))
        let ios = try #require(try ObjetJSON(texte: Sauvegarde.exporter(neuf(), maintenant: 0)).objet("settings"))
        #expect(ios.cles == android.cles)
        #expect(!texte.hasPrefix("\u{FEFF}"))
        // Les journées par date, même quand l'ordre des chaînes dirait autre chose.
        var e = neuf()
        _ = importer(#"{"format":"myhitbodedut","days":{"2020-01-02":{"minutes":1},"-0001-01-01":{"minutes":1},"0999-12-31":{"minutes":1}}}"#, &e)
        let jours = try ObjetJSON(texte: Sauvegarde.exporter(e, maintenant: 0)).objet("days")?.cles
        #expect(jours == ["-0001-01-01", "0999-12-31", "2020-01-02"])
    }

    @Test func lInstantDExportEstEnUTCALaMilliseconde() {
        #expect(Sauvegarde.instant(0) == "1970-01-01T00:00:00.000Z")
        #expect(Sauvegarde.instant(1_763_021_730_005) == "2025-11-13T08:15:30.005Z")
        #expect(Sauvegarde.instant(-1) == "1969-12-31T23:59:59.999Z")
        #expect(Sauvegarde.nomDeFichier(.du("2026-11-13")) == "myhitbodedut-2026-11-13.json")
    }

    @Test func lesDatesDeJavaTime() {
        #expect(JourCivil(java: "2026-11-04")?.iso == "2026-11-04")
        #expect(JourCivil(java: "+12345-01-01")?.annee == 12345)
        #expect(JourCivil(java: "-0001-12-31")?.annee == -1)
        #expect(JourCivil(java: "0000-01-01")?.annee == 0)
        for faux in ["+2020-01-01", "2026-9-5", "2026-02-30", "-001-01-01", "12345-01-01", "20260101", "", "2026-11-04 "] {
            #expect(JourCivil(java: faux) == nil, "« \(faux) »")
        }
    }

    // MARK: Le dépôt

    private func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("depot-\(UUID().uuidString)")
    }

    @Test func leDepotEcritEtRelitSesTroisFichiers() async throws {
        let ici = dossier()
        defer { try? FileManager.default.removeItem(at: ici) }
        let depot = Coeur.Depot(dossier: ici, enIsrael: true)
        let lues = try await depot.importer(Data(try fichier("web-v2.json").utf8), aujourdhui: aujourdhui)
        #expect(lues == 3)
        _ = try await depot.importer(Data(try fichier("android-v2-forge.json").utf8), aujourdhui: aujourdhui)
        try await depot.modifier { $0.reglages.autres["ambiance"] = .chaine("pluie") }
        let avant = await depot.tout
        // Le site et le fichier forgé posent chacun une marque à Likoutei Moharan, section 3, bloc 12 : la
        // même place n'est gardée qu'une fois (Store.importerAjouts, memePlace), 2 + 3 − 1 marques.
        #expect(avant.lecture.marques.count == 4 && avant.reglages.tikkun.count == 4)
        let relu = Coeur.Depot(dossier: ici, enIsrael: false)
        let apres = await relu.tout
        #expect(apres == avant)
        #expect(apres.reglages.autres.texte("ambiance") == "pluie", "une clé qu'iOS ne lit pas encore est gardée")
        // Invalide : rien n'est écrit.
        let refus = try await relu.importer(Data("pas du json".utf8), aujourdhui: aujourdhui)
        #expect(refus == nil)
        let inchange = await relu.tout
        #expect(inchange == avant)
        let export = await relu.exporter(maintenant: Date(timeIntervalSince1970: 0))
        #expect(export.first == UInt8(ascii: "{"))
    }

    @Test func uneSauvegardeChiffreeDemandeSonMotDePasse() async throws {
        let ici = dossier()
        defer { try? FileManager.default.removeItem(at: ici) }
        let depot = Coeur.Depot(dossier: ici, enIsrael: false)
        let v = try ObjetJSON(texte: Depot.texte("web/test/vecteur_coffre.json"))
        let chiffre = Data(try #require(v.objet("chiffre")).texte().utf8)
        let jour = aujourdhui
        await #expect(throws: Coeur.Depot.Erreur.motDePasseAttendu) { try await depot.importer(chiffre, aujourdhui: jour) }
        await #expect(throws: Coeur.Depot.Erreur.motDePasseFaux) {
            try await depot.importer(chiffre, aujourdhui: jour, motDePasse: "faux")
        }
        let lues = try await depot.importer(chiffre, aujourdhui: jour, motDePasse: v.texte("mot_de_passe"))
        #expect(lues == 1)
        let note = await depot.journal.jours[.du("2026-11-12")]
        #expect(note == Journee(minutes: 20, note: "שלום — une note"))
        // L'export chiffré ne montre pas la note, et se relit avec son mot de passe.
        let export = await depot.exporter(maintenant: Date(timeIntervalSince1970: 0), motDePasse: "autre", iterations: 100_000)
        let texte = String(decoding: export, as: UTF8.self)
        #expect(Coffre.estChiffre(texte) && !texte.contains("une note"))
        let clair = try #require(Coffre.dechiffrer(texte, motDePasse: "autre"))
        #expect(try ObjetJSON(texte: clair).objet("days")?.objet("2026-11-12")?.texte("note") == "שלום — une note")
        await #expect(throws: Coeur.Depot.Erreur.tropGros) {
            try await depot.importer(Data(repeating: 0x20, count: Sauvegarde.tailleMax + 1), aujourdhui: jour)
        }
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
        try await depot.modifier { $0.journal.jours[.du("2026-11-14")] = Journee(minutes: 12) }
        let rouvert = await Coeur.Depot(dossier: ici, enIsrael: false).journal
        #expect(rouvert.jours.count == 1)
        // Une seconde panne ne remplace pas la première copie.
        try Data("autre".utf8).write(to: journal)
        _ = Coeur.Depot(dossier: ici, enIsrael: false)
        #expect(try Data(contentsOf: copie) == Data(#"{"days":{"2026-11-01":"#.utf8))
        #expect(Coeur.Depot.corrompu("reglages.json") == "reglages.corrompu.json")
        #expect(Coeur.Depot.corrompu("lecture.json") == "lecture.corrompu.json")
    }

    // MARK: La sauvegarde réelle (P7)

    /// La vraie sauvegarde du propriétaire, hors du dépôt (§ 3.9) : son chemin dans SAUVEGARDE_REELLE, et
    /// SAUVEGARDE_REELLE_MDP si elle est chiffrée. Elle se lit sans perte : tout ce qu'Android y a écrit
    /// revient dans l'export d'iOS, aux adaptations d'iOS près. Avec SAUVEGARDE_REELLE_ANDROID (ce que
    /// `gradle -p tools/vecteurs_ios reelle` en écrit), l'import d'iOS doit aussi égaler celui d'Android.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SAUVEGARDE_REELLE"] != nil))
    func laSauvegardeReelleSeLitSansPerte() throws {
        let env = ProcessInfo.processInfo.environment
        let chemin = try #require(env["SAUVEGARDE_REELLE"])
        let octets = try Data(contentsOf: URL(fileURLWithPath: chemin))
        var texte = try #require(Sauvegarde.texte(octets), "plus de 2 Mo")
        if Coffre.estChiffre(texte) {
            let motDePasse = try #require(env["SAUVEGARDE_REELLE_MDP"], "sauvegarde chiffrée : SAUVEGARDE_REELLE_MDP manque")
            texte = try #require(Coffre.dechiffrer(texte, motDePasse: motDePasse), "mot de passe faux ou fichier abîmé")
        }
        var d = neuf()
        let lu = importer(texte, &d)
        let lues = try #require(lu, "fichier refusé")
        let fichier = try normalise(texte)
        #expect(lues == (fichier.objet("days")?.count ?? 0), "chaque journée du fichier est lue")
        let rendu = try normalise(Sauvegarde.exporter(d, maintenant: 0))
        for cle in fichier.cles where cle != "version" {
            if cle == "settings", let attendus = fichier.objet(cle), let obtenus = rendu.objet(cle) {
                for k in attendus.cles where obtenus[k] != attendus[k] {
                    // Un morceau ajouté sur Android (une URI) ne désigne rien sur iOS.
                    if k == "music_track", !Sauvegarde.morceauxLivres.contains(attendus.texte(k)) { continue }
                    Issue.record("settings.\(k) : \(obtenus[k]?.texte() ?? "∅") au lieu de \(attendus[k]?.texte() ?? "∅")")
                }
            } else {
                #expect(rendu[cle] == fichier[cle], "\(cle) : perdu ou changé")
            }
        }
        if let oracle = env["SAUVEGARDE_REELLE_ANDROID"] {
            let brut = try Data(contentsOf: URL(fileURLWithPath: oracle))
            let android = try ObjetJSON(texte: String(decoding: brut, as: UTF8.self))
            let comptes = android.tableau("comptes") ?? []
            #expect(comptes.entier(0) == lues, "journées lues : Android en a lu \(comptes.entier(0))")
            let attendu = try ObjetJSON(texte: android.texte("export"))
            #expect(rendu == attendu, "devant Android : \(ecarts(rendu, attendu))")
        }
    }
}
