import Foundation
import Testing
@testable import Coeur

/// Les réglages d'Android (Store.kt). PersonnalisationTest porté tel quel ; puis `Tests/Vecteurs/reglages.json`
/// (tools/vecteurs_ios/VecteursReglages.kt) : le défaut de chaque accesseur, ce qu'il relit après chaque
/// écriture (dans les bornes, aux bornes, au-delà, absurde) et d'une préférence posée à la main, et le
/// fichier de préférences « myhitbodedut » qui en résulte, octet pour octet et clé pour clé, clés
/// inconnues comprises. Les écrans qui posent ces réglages restent à Android.
@Suite("Réglages")
struct ReglagesTests {

    // MARK: PersonnalisationTest

    @Test func chaqueChoixMontreSonLivre() {
        let yalkut = Reglages.SourceHalakha.yalkut
        let benIshHai = Reglages.SourceHalakha.benIshHai
        let lesDeux = Reglages.SourceHalakha.lesDeux
        #expect(yalkut.montreYalkut)
        #expect(!yalkut.montreBenIshHai)
        #expect(!benIshHai.montreYalkut)
        #expect(benIshHai.montreBenIshHai)
        #expect(lesDeux.montreYalkut)
        #expect(lesDeux.montreBenIshHai)
    }

    @Test func memesClesQueLeWeb() {
        let sources = Reglages.SourceHalakha.allCases.map { $0.rawValue }
        #expect(sources == ["yalkut", "ben_ish_hai", "les_deux"])
        let ouvertures = Reglages.Ouverture.allCases.map { $0.rawValue }
        #expect(ouvertures == ["aujourdhui", "textes", "zmanim"])
    }

    // MARK: Ce que les vecteurs ne disent pas

    @Test func lesLibellesSontDansLeCatalogue() throws {
        let catalogue = try Catalogue.lire()
        let libelles = Reglages.SourceHalakha.allCases.map { $0.libelle } + Reglages.Ouverture.allCases.map { $0.libelle }
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for libelle in libelles {
                let present = chaines[libelle] != nil
                #expect(present, "\(langue) : \(libelle)")
            }
        }
    }

    @Test func uneCleInconnueEstGardeeTelleQuelle() throws {
        var r = try Reglages(texte: "{\"x\":{\"a\":[1,2.5,null]},\"window_start\":400,\"y\":null,\"vol_numero\":\"LY315\"}")
        r.setWindow(startMinutes: 300, endMinutes: 800)
        r.setMusicTrackId(nil)
        r.setShabbatMode(false)
        let texte = r.texte()
        let attendu = "{\"x\":{\"a\":[1,2.5,null]},\"window_start\":300,\"y\":null,\"vol_numero\":\"LY315\","
            + "\"window_end\":800,\"pause_shabbat\":false}"
        #expect(texte == attendu)
        let relu = try Reglages(texte: texte)
        #expect(relu == r)
    }

    @Test func laLectureEstCelleDOrgJson() throws {
        // Android lève sur une préférence d'un autre type ; reglages.json se lit comme org.json.
        let r = try Reglages(texte: "{\"window_start\":\"400\",\"pause_shabbat\":\"false\",\"music_volume\":55.9,"
            + "\"music_track\":5,\"paused_dates\":[\"a\",1,null],\"lecture_echelle\":\"1.5\",\"in_israel\":\"TRUE\",\"enabled\":1}")
        let debut = r.windowStart, volume = r.musicVolume, echelle = r.lectureEchelle
        #expect(debut == 400)
        #expect(!r.shabbatMode)
        #expect(volume == 55)
        #expect(r.musicTrackId == nil)
        let pauses = r.pausedDates, pausesAttendues: Set<String> = ["a"]
        #expect(pauses == pausesAttendues)
        #expect(echelle == 1.5)
        #expect(r.inIsrael(fuseauTelephone: "UTC"))
        #expect(!r.isEnabled)
    }

    @Test func leReportCourtDeMaintenant() {
        var r = Reglages()
        r.setSnoozeMinutes(20)
        r.snooze(maintenant: 1_700_000_000_000)
        let fin = r.snoozedUntil
        #expect(fin == 1_700_001_200_000)
        #expect(r.isSnoozed(maintenant: 1_700_001_199_999))
        #expect(!r.isSnoozed(maintenant: 1_700_001_200_000))
        r.clearSnooze()
        let efface = r.snoozedUntil
        #expect(efface == 0)
        let texte = r.texte()
        #expect(texte == "{\"snooze_minutes\":20,\"snoozed_until\":0}")
    }

    @Test func leFuseauDuTelephoneDitIsraelTantQueRienNEstFige() {
        var r = Reglages()
        #expect(r.inIsrael(fuseauTelephone: "Asia/Jerusalem"))
        #expect(!r.inIsrael(fuseauTelephone: "Europe/Paris"))
        let fige = r.figeInIsrael(fuseauTelephone: "Asia/Jerusalem")
        #expect(fige)
        // Une fois figée, la valeur ne suit plus le fuseau : un voyage ne change pas le deuxième jour de fête.
        #expect(r.inIsrael(fuseauTelephone: "Europe/Paris"))
        let encore = r.figeInIsrael(fuseauTelephone: "Europe/Paris")
        #expect(encore)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Defauts: Decodable {
            let relu: String
            let prefsApresInIsrael: String
        }
        struct Etape: Decodable {
            let op: String
            let args: String
            let rendu: String?
            let relu: String
            let prefs: String
        }
        struct Ecriture: Decodable {
            let nom: String
            let depart: String
            let etapes: [Etape]
        }
        struct Lecture: Decodable {
            let prefs: String
            let relu: String
        }

        let defauts: Defauts
        let ecritures: [Ecriture]
        let lectures: [Lecture]
    }

    private struct Inconnu: Error {
        let nom: String
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/reglages.json"))
    }

    // Les valeurs, comme le générateur les écrit.

    private static func e(_ n: Int) -> JSON { .entier(Int64(n)) }

    private static func l(_ n: Int64) -> JSON { .entier(n) }

    private static func b(_ v: Bool) -> JSON { .booleen(v) }

    private static func t(_ s: String?) -> JSON {
        guard let s else { return .nul }
        return .chaine(s)
    }

    private static func n(_ v: Int?) -> JSON {
        guard let v else { return .nul }
        return .entier(Int64(v))
    }

    private static func ensemble(_ s: Set<String>?) -> JSON {
        guard let s else { return .nul }
        let triees = s.sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
        return .tableau(triees.map { JSON.chaine($0) })
    }

    private static func lieu(_ lieu: Zmanim.Lieu?) -> JSON {
        guard let lieu else { return .nul }
        return .objet(ObjetJSON([
            ("nom", .chaine(lieu.nom)), ("latitude", .decimal(lieu.latitude)), ("longitude", .decimal(lieu.longitude)),
            ("altitude", .decimal(lieu.altitude)), ("fuseau", .chaine(lieu.fuseau)),
        ]))
    }

    private static func celebration(_ c: Reglages.Celebration?) -> JSON {
        guard let c else { return .nul }
        return .objet(ObjetJSON([("minutes", e(c.minutes)), ("dateNote", t(c.dateNote))]))
    }

    /// L'accesseur de ce nom, lu comme le générateur l'écrit ; nil pour un nom inconnu. « :fuseau » nomme
    /// le fuseau du téléphone.
    private static func lis(_ nom: String, _ r: Reglages) -> JSON? {
        let parties = nom.split(separator: ":", maxSplits: 1).map { String($0) }
        if parties.count == 2 {
            let fuseau = parties[1]
            switch parties[0] {
            case "inIsrael": return b(r.inIsrael(fuseauTelephone: fuseau))
            case "lieuPerime": return b(r.lieuPerime(fuseauTelephone: fuseau))
            case "lieuAlertes": return lieu(r.lieuAlertes(fuseauTelephone: fuseau))
            default: return nil
            }
        }
        switch nom {
        case "windowStart": return e(r.windowStart)
        case "windowEnd": return e(r.windowEnd)
        case "snoozeMinutes": return e(r.snoozeMinutes)
        case "snoozedUntil": return l(r.snoozedUntil)
        case "targetMinutes": return e(r.targetMinutes)
        case "dailyGoal": return e(r.dailyGoal)
        case "shabbatMode": return b(r.shabbatMode)
        case "pausedDates": return ensemble(r.pausedDates)
        case "blockedApps": return ensemble(r.blockedApps)
        case "isEnabled": return b(r.isEnabled)
        case "reminderEnabled": return b(r.reminderEnabled)
        case "reminderMinutes": return e(r.reminderMinutes)
        case "reminderTimes": return .tableau(r.reminderTimes.map { e($0) })
        case "reminderSnoozedUntil": return l(r.reminderSnoozedUntil)
        case "hideCountdown": return b(r.hideCountdown)
        case "guidedHitbodedut": return b(r.guidedHitbodedut)
        case "nePasDeranger": return b(r.nePasDeranger)
        case "filtreAvantSeance": return n(r.filtreAvantSeance)
        case "ambiance": return t(r.ambiance)
        case "musicEnabled": return b(r.musicEnabled)
        case "musicTrackId": return t(r.musicTrackId)
        case "musicShuffle": return b(r.musicShuffle)
        case "musicNow": return t(r.musicNow)
        case "musicVolume": return e(r.musicVolume)
        case "musicUserTracks": return t(r.musicUserTracks)
        case "musicNames": return t(r.musicNames)
        case "hasOnboarded": return b(r.hasOnboarded)
        case "adresse": return t(r.adresse)
        case "langueApp": return t(r.langueApp)
        case "langueRepli": return b(r.langueRepli)
        case "modeApparence": return t(r.modeApparence)
        case "fond": return t(r.fond.rawValue)
        case "accent": return t(r.accent.rawValue)
        case "lectureEchelle": return .decimal(Double(r.lectureEchelle))
        case "lecturePolice": return t(r.lecturePolice)
        case "lectureLangues": return t(r.lectureLangues)
        case "lectureSombre": return b(r.lectureSombre)
        case "lectureMasquee": return b(r.lectureMasquee)
        case "siddurNusah": return t(r.siddurNusah.rawValue)
        case "sansTahanounFinTichri": return b(r.sansTahanounFinTichri)
        case "calendrierCivil": return b(r.calendrierCivil)
        case "allumage": return e(r.allumage)
        case "boussoleRose": return b(r.boussoleRose)
        case "boussoleCarte": return b(r.boussoleCarte)
        case "volRappelsActifs": return b(r.volRappelsActifs)
        case "suiviDirect": return b(r.suiviDirect)
        case "volIndicatif": return t(r.volIndicatif)
        case "volRappelVu": return l(r.volRappelVu)
        case "lieuZmanim": return lieu(r.lieuZmanim)
        case "lieuDepuis": return l(r.lieuDepuis)
        case "lieuVille": return l(r.lieuVille)
        case "mukafChoma": return b(r.mukafChoma)
        case "hemisphereSud": return b(r.hemisphereSud)
        case "hilloulotAffichees": return b(r.hilloulotAffichees)
        case "halakhaAffichee": return b(r.halakhaAffichee)
        case "sourceHalakha": return t(r.sourceHalakha.rawValue)
        case "levanaAffichee": return b(r.levanaAffichee)
        case "levanaUsage": return t(r.levanaUsage)
        case "levanaRappel": return b(r.levanaRappel)
        case "levanaRappelSoir": return t(r.levanaRappelSoir)
        case "ouverture": return t(r.ouverture.rawValue)
        case "anneauxFetes": return ensemble(r.anneauxFetes)
        case "paliersVus": return ensemble(r.paliersVus)
        case "paliersNotifies": return ensemble(r.paliersNotifies)
        case "tropheesVus": return ensemble(r.tropheesVus)
        case "tropheesNotifies": return ensemble(r.tropheesNotifies)
        case "tropheesProchesSignales": return ensemble(r.tropheesProchesSignales)
        case "gradeVu": return n(r.gradeVu)
        case "bilanVu": return t(r.bilanVu)
        case "rappelTropheeProche": return b(r.rappelTropheeProche)
        case "hasPendingCelebration": return b(r.hasPendingCelebration)
        default: return nil
        }
    }

    private static func texteOuNul(_ a: [JSON], _ rang: Int) -> String? {
        a.estNul(rang) ? nil : a.texte(rang)
    }

    private static func chaines(_ a: [JSON], _ rang: Int) -> Set<String> {
        Set((a.tableau(rang) ?? []).map { $0.commeTexte })
    }

    /// Une ville, lue comme les contenus exportés la donnent : seuls son identifiant et son pays comptent ici.
    private static func villeDe(id: Int64, pays: String, _ lieu: Zmanim.Lieu) throws -> Ville {
        let o = ObjetJSON([
            ("id", .entier(id)), ("nom", .objet(ObjetJSON([("he", .chaine("")), ("fr", .chaine(lieu.nom)), ("en", .chaine(""))]))),
            ("pays", .chaine(pays)), ("latitude", .decimal(lieu.latitude)), ("longitude", .decimal(lieu.longitude)),
            ("altitude", .decimal(lieu.altitude)), ("fuseau", .chaine(lieu.fuseau)),
        ])
        return try JSONDecoder().decode(Ville.self, from: Data(o.texte().utf8))
    }

    /// L'opération de ce nom, sur les arguments du générateur ; ce qu'elle rend, s'il y a lieu.
    private static func applique(_ op: String, _ a: [JSON], _ r: inout Reglages) throws -> JSON? {
        switch op {
        case "setWindow": r.setWindow(startMinutes: a.entier(0), endMinutes: a.entier(1))
        case "setSnoozeMinutes": r.setSnoozeMinutes(a.entier(0))
        case "clearSnooze": r.clearSnooze()
        case "setTargetMinutes": r.setTargetMinutes(a.entier(0))
        case "setDailyGoal": r.setDailyGoal(a.entier(0))
        case "setShabbatMode": r.setShabbatMode(a.booleen(0))
        case "setInIsrael": r.setInIsrael(a.booleen(0))
        case "figeInIsrael:UTC": return b(r.figeInIsrael(fuseauTelephone: "UTC"))
        case "togglePausedDate": r.togglePausedDate(a.texte(0))
        case "setBlockedApps": r.setBlockedApps(chaines(a, 0))
        case "setEnabled": r.setEnabled(a.booleen(0))
        case "setReminderEnabled": r.setReminderEnabled(a.booleen(0))
        case "setReminderMinutes": r.setReminderMinutes(a.entier(0))
        case "setReminderTimes":
            let heures = a.tableau(0) ?? []
            r.setReminderTimes(heures.indices.map { heures.entier($0) })
        case "setReminderSnoozedUntil": r.setReminderSnoozedUntil(a.long(0))
        case "setHideCountdown": r.setHideCountdown(a.booleen(0))
        case "setGuidedHitbodedut": r.setGuidedHitbodedut(a.booleen(0))
        case "setNePasDeranger": r.setNePasDeranger(a.booleen(0))
        case "setFiltreAvantSeance": r.setFiltreAvantSeance(a.estNul(0) ? nil : a.entier(0))
        case "setAmbiance": r.setAmbiance(a.texte(0))
        case "setMusicEnabled": r.setMusicEnabled(a.booleen(0))
        case "setMusicTrackId": r.setMusicTrackId(texteOuNul(a, 0))
        case "setMusicShuffle": r.setMusicShuffle(a.booleen(0))
        case "setMusicNow": r.setMusicNow(texteOuNul(a, 0))
        case "setMusicVolume": r.setMusicVolume(a.entier(0))
        case "setMusicUserTracks": r.setMusicUserTracks(a.texte(0))
        case "setMusicNames": r.setMusicNames(a.texte(0))
        case "setOnboarded": r.setOnboarded()
        case "setAdresse": r.setAdresse(texteOuNul(a, 0))
        case "setLangueApp": r.setLangueApp(a.texte(0))
        case "setLangueRepli": r.setLangueRepli(a.booleen(0))
        case "setModeApparence": r.setModeApparence(a.texte(0))
        case "setFond": r.setFond(Fond.de(a.texte(0)))
        case "setAccent": r.setAccent(Accent.de(a.texte(0)))
        case "setLectureEchelle": r.setLectureEchelle(Float(a.double(0)))
        case "setLecturePolice": r.setLecturePolice(a.texte(0))
        case "setLectureLangues": r.setLectureLangues(a.texte(0))
        case "setLectureSombre": r.setLectureSombre(a.booleen(0))
        case "setLectureMasquee": r.setLectureMasquee(a.booleen(0))
        case "setSiddurNusah": r.setSiddurNusah(Nusah.de(a.texte(0)))
        case "setSansTahanounFinTichriSfard": r.setSansTahanounFinTichriSfard(a.booleen(0))
        case "setCalendrierCivil": r.setCalendrierCivil(a.booleen(0))
        case "setAllumage": r.setAllumage(a.entier(0))
        case "setBoussoleRose": r.setBoussoleRose(a.booleen(0))
        case "setBoussoleCarte": r.setBoussoleCarte(a.booleen(0))
        case "setVolRappelsActifs": r.setVolRappelsActifs(a.booleen(0))
        case "setSuiviDirect": r.setSuiviDirect(a.booleen(0))
        case "setVolIndicatif": r.setVolIndicatif(a.texte(0))
        case "setVolRappelVu": r.setVolRappelVu(a.long(0))
        case "setLieuZmanim":
            // [nom, latitude, longitude, altitude, fuseau, ville ou null, pays, instant].
            let lieu = Zmanim.Lieu(nom: a.texte(0), latitude: a.double(1), longitude: a.double(2), altitude: a.double(3),
                                   fuseau: a.texte(4))
            let ville: Ville?
            if a.estNul(5) {
                ville = nil
            } else {
                ville = try villeDe(id: a.long(5), pays: a.texte(6), lieu)
            }
            r.setLieuZmanim(lieu, ville: ville, maintenant: a.long(7))
        case "setHilloulotAffichees": r.setHilloulotAffichees(a.booleen(0))
        case "setHalakhaAffichee": r.setHalakhaAffichee(a.booleen(0))
        case "setSourceHalakha":
            guard let source = Reglages.SourceHalakha(rawValue: a.texte(0)) else { throw Inconnu(nom: a.texte(0)) }
            r.setSourceHalakha(source)
        case "setLevanaAffichee": r.setLevanaAffichee(a.booleen(0))
        case "setLevanaUsage": r.setLevanaUsage(texteOuNul(a, 0))
        case "setLevanaRappel": r.setLevanaRappel(a.booleen(0))
        case "setLevanaRappelSoir": r.setLevanaRappelSoir(a.texte(0))
        case "setOuverture":
            guard let ouverture = Reglages.Ouverture(rawValue: a.texte(0)) else { throw Inconnu(nom: a.texte(0)) }
            r.setOuverture(ouverture)
        case "setAnneauxFetes": r.setAnneauxFetes(chaines(a, 0))
        case "setPaliersVus": r.setPaliersVus(chaines(a, 0))
        case "setPaliersNotifies": r.setPaliersNotifies(chaines(a, 0))
        case "setTropheesVus": r.setTropheesVus(chaines(a, 0))
        case "setTropheesNotifies": r.setTropheesNotifies(chaines(a, 0))
        case "setTropheesProchesSignales": r.setTropheesProchesSignales(chaines(a, 0))
        case "setGradeVu": r.setGradeVu(a.entier(0))
        case "setBilanVu": r.setBilanVu(a.texte(0))
        case "setRappelTropheeProche": r.setRappelTropheeProche(a.booleen(0))
        case "setPendingCelebration": r.setPendingCelebration(minutes: a.entier(0), dateNote: texteOuNul(a, 1))
        case "takePendingCelebration": return celebration(r.takePendingCelebration())
        default: throw Inconnu(nom: op)
        }
        return nil
    }

    /// Les accesseurs nommés par `attendu` (un objet {accesseur: valeur}), lus sur `r` et écrits de même.
    private static func relus(_ attendu: String, _ r: Reglages) throws -> String {
        var o = ObjetJSON()
        for nom in try ObjetJSON(texte: attendu).cles {
            guard let valeur = lis(nom, r) else { throw Inconnu(nom: nom) }
            o[nom] = valeur
        }
        return o.texte()
    }

    @Test func chaqueAccesseurALeDefautDAndroid() throws {
        let v = try vecteurs()
        var r = Reglages()
        let relu = try Self.relus(v.defauts.relu, r)
        let identique = relu.egalUnites(v.defauts.relu)
        #expect(identique, "\(relu)\n≠ \(v.defauts.relu)")
        let nombre = try ObjetJSON(texte: v.defauts.relu).count
        #expect(nombre > 70)
        r.figeInIsrael(fuseauTelephone: "UTC")
        let prefs = r.texte()
        #expect(prefs == v.defauts.prefsApresInIsrael)
    }

    @Test func chaqueEcritureEtSaRelectureCommeSurAndroid() throws {
        let v = try vecteurs()
        var etapes = 0
        for cas in v.ecritures {
            var r = try Reglages(texte: cas.depart)
            let depart = r.texte()
            let departIdentique = depart.egalUnites(cas.depart)
            #expect(departIdentique, "\(cas.nom) : départ \(depart)")
            for (rang, etape) in cas.etapes.enumerated() {
                let lu = try JSON.lire(etape.args)
                guard case .tableau(let args) = lu else {
                    Issue.record("\(cas.nom), étape \(rang) : arguments illisibles")
                    continue
                }
                let rendu = try Self.applique(etape.op, args, &r)
                if let attendu = etape.rendu {
                    let obtenu = ObjetJSON([("v", rendu ?? JSON.nul)]).texte()
                    let memeRendu = obtenu.egalUnites(attendu)
                    #expect(memeRendu, "\(cas.nom), étape \(rang) (\(etape.op)) : rendu \(obtenu) ≠ \(attendu)")
                }
                let relu = try Self.relus(etape.relu, r)
                let memeRelu = relu.egalUnites(etape.relu)
                #expect(memeRelu, "\(cas.nom), étape \(rang) (\(etape.op)) : \(relu) ≠ \(etape.relu)")
                let prefs = r.texte()
                let memesPrefs = prefs.egalUnites(etape.prefs)
                #expect(memesPrefs, "\(cas.nom), étape \(rang) (\(etape.op)) : \(prefs) ≠ \(etape.prefs)")
                etapes += 1
            }
        }
        #expect(etapes > 250)
    }

    @Test func chaquePreferencePoseeALaMainSeLitCommeSurAndroid() throws {
        let v = try vecteurs()
        #expect(v.lectures.count > 200)
        for lecture in v.lectures {
            let r = try Reglages(texte: lecture.prefs)
            let relu = try Self.relus(lecture.relu, r)
            let identique = relu.egalUnites(lecture.relu)
            #expect(identique, "\(lecture.prefs) : \(relu) ≠ \(lecture.relu)")
            // Le fichier relu et réécrit ne change pas, à une chose près : un Float −0 d'Android s'écrit « -0 »,
            // qu'org.json relit, comme sur Android, en l'entier 0, et réécrit « 0 ».
            let reecrit = r.texte()
            let attendu = lecture.prefs.remplacantUnites(":-0,", par: ":0,").remplacantUnites(":-0}", par: ":0}")
            let stable = reecrit.egalUnites(attendu)
            #expect(stable, "\(lecture.prefs) réécrit \(reecrit) ≠ \(attendu)")
        }
    }
}
