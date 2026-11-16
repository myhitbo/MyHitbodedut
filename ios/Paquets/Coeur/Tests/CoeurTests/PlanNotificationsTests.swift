import Foundation
import Testing
@testable import Coeur

/// Le planificateur de notifications (PlanNotifications.swift) : les tests neufs de la tâche 12 (ROADMAP), écrits
/// pour iOS, Android n'ayant pas de planificateur — jamais plus de 64 notifications, quels que soient les réglages ;
/// aucun rappel un jour de repos ni la veille après midi ; les rappels du jour disparaissent quand la journée est
/// faite ; ceux qui tomberaient pendant une séance sont retirés ; le report de 5 et de 15 minutes. Puis ce que
/// `Tests/Vecteurs/plan.json`, écrit par la JVM (tools/vecteurs_ios/VecteursPlan.kt), dit que les récepteurs
/// d'Android montreraient, alarme après alarme, pour 89 états : les rappels, la phrase du trophée, Chabbat,
/// Levana, le vol, avec les zmanim de KosherJava rendus tels quels. Restent à Android les récepteurs eux-mêmes,
/// les canaux, les icônes et AlarmManager.
@Suite("Planificateur de notifications")
struct PlanNotificationsTests {

    // MARK: Aides

    private static func fuseau(_ identifiant: String) -> Fuseau {
        guard let f = Fuseau(identifiant) else { preconditionFailure("fuseau inconnu : \(identifiant)") }
        return f
    }

    private static let paris = fuseau("Europe/Paris")

    /// Des zmanim factices, sans calcul astronomique : la sortie des étoiles à 18 h 30, l'allumage à 17 h moins
    /// les minutes réglées.
    private static func horairesFactices(_ lieu: Zmanim.Lieu, _ jour: JourCivil) -> [String: Int64] {
        guard let f = Fuseau(lieu.fuseau) else { return [:] }
        return ["tset": f.millis(DateHeure(jour, heure: 18, minute: 30))]
    }

    private static func allumageFactice(_ lieu: Zmanim.Lieu, _ jour: JourCivil, _ minutes: Int) -> Int64? {
        guard let f = Fuseau(lieu.fuseau) else { return nil }
        return f.millis(DateHeure(jour, heure: 17)) - Int64(minutes) * 60_000
    }

    private static func plan(_ reglages: Reglages, _ journal: Journal, _ maintenant: Int64, _ fuseau: Fuseau,
                             vol: [VolRappels.Rappel] = []) -> [NotificationPlanifiee] {
        PlanNotifications.planifier(reglages: reglages, journal: journal, volRappels: vol, maintenant: maintenant,
                                    fuseau: fuseau, horaires: horairesFactices, allumage: allumageFactice,
                                    heureVol: PlanNotifications.instantTexte)
    }

    private static func a(_ jour: String, _ heure: Int, _ minute: Int = 0) -> Int64 {
        paris.millis(DateHeure(JourCivil.du(jour), heure: heure, minute: minute))
    }

    private static func rappelsSeuls(_ plan: [NotificationPlanifiee]) -> [NotificationPlanifiee] {
        plan.filter { $0.categorie == .rappel }
    }

    private static func reglages(heures: [Int]) -> Reglages {
        var r = Reglages()
        r.setReminderEnabled(true)
        r.setReminderTimes(heures)
        r.setInIsrael(false)
        return r
    }

    /// Un état tiré au sort (graine fixe) : réglages, journal, maintenant, fuseau, rappels du vol.
    private struct Etat {
        var reglages: Reglages
        var journal: Journal
        var maintenant: Int64
        var fuseau: Fuseau
        var vol: [VolRappels.Rappel]
    }

    private static func tire(_ graine: Int32) -> Etat {
        var h = HasardKotlin(graine: graine)
        func n(_ borne: Int) -> Int { Int(h.nextInt(jusqua: Int32(borne))) }
        let lieux = [Lieux.jerusalem, Lieux.paris, Lieux.newYork, Lieux.melbourne, Lieux.tromso]
        let lieu = lieux[n(lieux.count)]
        let f = fuseau(lieu.fuseau)
        let jour = JourCivil(jourJulien: JourCivil.du("2026-01-01").jourJulien + n(730))
        let maintenant = f.millis(DateHeure(jour, heure: n(24), minute: n(60)))
        var r = Reglages()
        r.setReminderEnabled(n(6) != 0)
        // Parfois une heure tous les quarts d'heure, qui remplit la part des rappels en moins d'un jour.
        let nombreHeures = n(12) == 0 ? 96 : n(9)
        var heures: [Int] = []
        for k in 0..<nombreHeures {
            heures.append(nombreHeures == 96 ? k * 15 : n(1440))
        }
        r.setReminderTimes(heures)
        if n(4) == 0 { r.setShabbatMode(false) }
        if n(2) == 0 { r.setInIsrael(n(2) == 0) }
        if n(3) == 0 {
            var pauses: Set<String> = []
            for _ in 0..<(1 + n(4)) { pauses.insert(jour.plus(jours: n(12)).iso) }
            r.setPausedDates(pauses)
        }
        if n(5) != 0 { r.setLieuZmanim(lieu, ville: nil, maintenant: maintenant) }
        if n(4) == 0 { r.setLevanaRappel(false) }
        if n(5) == 0 { r.setVolRappelsActifs(false) }
        r.setTargetMinutes([5, 15, 20, 60][n(4)])
        if n(3) == 0 { r.setReminderSnoozedUntil(maintenant + Int64([5, 15, 30, -10][n(4)]) * 60_000) }
        if n(4) == 0 {
            Store.beginSession(reglages: &r, minutes: [0, 10, 30, 240][n(4)], millis: maintenant - Int64(n(60)) * 60_000)
        }
        var journal = Journal()
        for _ in 0..<n(6) { journal.addSession(minutes: 5 + n(40), date: jour.plus(jours: -n(8))) }
        if n(3) == 0 { journal.addSession(minutes: 20, date: jour) }
        var vol: [VolRappels.Rappel] = []
        if n(2) == 0 {
            var t = maintenant - Int64(n(60)) * 60_000
            for _ in 0..<n(60) {
                t += Int64(n(240)) * 60_000
                let type = VolRappels.Genre.allCases[n(4)]
                let priere: String? = ["chaharit", "minha", nil][n(3)]
                let limite: Int64? = n(2) == 0 ? t + 3_600_000 : nil
                vol.append(VolRappels.Rappel(type: type, instant: t, priere: priere, limite: limite, omer: n(49)))
            }
        }
        return Etat(reglages: r, journal: journal, maintenant: maintenant, fuseau: f, vol: vol)
    }

    // MARK: Le budget

    @Test func lesPartsEtLaMargeFontLeBudget() {
        var somme = PlanNotifications.marge
        for c in NotificationPlanifiee.Categorie.allCases { somme += c.part }
        #expect(somme == PlanNotifications.limite)
        let parts = NotificationPlanifiee.Categorie.allCases.map { $0.part }
        #expect(parts == [30, 4, 6, 14, 2])
    }

    @Test func jamaisPlusDe64QuelsQueSoientLesReglages() {
        for graine in Int32(0)..<Int32(300) {
            let e = Self.tire(graine)
            let plan = Self.plan(e.reglages, e.journal, e.maintenant, e.fuseau, vol: e.vol)
            let total = plan.count
            #expect(total <= PlanNotifications.limite, "graine \(graine)")
            #expect(total <= PlanNotifications.limite - PlanNotifications.marge, "graine \(graine)")
            for c in NotificationPlanifiee.Categorie.allCases {
                let n = plan.filter { $0.categorie == c }.count
                #expect(n <= c.part, "graine \(graine), \(c.rawValue)")
            }
            let identifiants = Set(plan.map { $0.identifiant }).count
            #expect(identifiants == total, "graine \(graine) : identifiants en double")
            for (k, p) in plan.enumerated() {
                let pasDansLePasse = p.instant >= e.maintenant
                #expect(pasDansLePasse, "graine \(graine) : \(p.identifiant)")
                if k > 0 {
                    let trie = plan[k - 1].instant <= p.instant
                    #expect(trie, "graine \(graine) : \(p.identifiant)")
                }
            }
        }
    }

    @Test func soixanteQuatreAuPlusMemeQuandToutDeborde() {
        var r = Self.reglages(heures: Array(0..<1440))
        let maintenant = Self.a("2026-10-14", 8)
        r.setLieuZmanim(Lieux.paris, ville: nil, maintenant: maintenant)
        // Une séance d'une minute qui finit dans dix secondes, puis un report avant le rappel de 8 h 01 : la part de
        // la séance est pleine aussi.
        r.setReminderSnoozedUntil(maintenant + 30_000)
        Store.beginSession(reglages: &r, minutes: 1, millis: maintenant - 50_000)
        var vol: [VolRappels.Rappel] = []
        for k in 0..<200 {
            vol.append(VolRappels.Rappel(type: .priere, instant: maintenant + Int64(k) * 600_000, priere: "minha"))
        }
        let plan = Self.plan(r, Journal(), maintenant, Self.paris, vol: vol)
        let total = plan.count
        #expect(total <= PlanNotifications.limite)
        let rappels = Self.rappelsSeuls(plan).count
        #expect(rappels == 30)
        let vols = plan.filter { $0.categorie == .vol }.count
        #expect(vols == 14)
        let chabbats = plan.filter { $0.categorie == .chabbat }.count
        #expect(chabbats == 4)
        let levana = plan.filter { $0.categorie == .levana }.count
        #expect(levana == 6)
        let seance = plan.filter { $0.categorie == .seance }.count
        #expect(seance == 2)
    }

    // MARK: Les jours de repos

    @Test func aucunRappelUnJourDeReposNiLaVeilleApresMidi() {
        // Du jeudi 15 au dimanche 18 octobre 2026 à Paris, Chabbat le samedi 17.
        let r = Self.reglages(heures: [420, 719, 720, 1260])
        let plan = Self.plan(r, Journal(), Self.a("2026-10-15", 6), Self.paris)
        let parJour = Dictionary(grouping: Self.rappelsSeuls(plan)) { p in Self.paris.jour(millis: p.instant).iso }
        let jeudi = (parJour["2026-10-15"] ?? []).map { Self.paris.dateHeure(millis: $0.instant).minutesDuJour }
        #expect(jeudi == [420, 719, 720, 1260])
        let vendredi = (parJour["2026-10-16"] ?? []).map { Self.paris.dateHeure(millis: $0.instant).minutesDuJour }
        #expect(vendredi == [420, 719])
        let samedi = parJour["2026-10-17"]?.count ?? 0
        #expect(samedi == 0)
        let dimanche = (parJour["2026-10-18"] ?? []).map { Self.paris.dateHeure(millis: $0.instant).minutesDuJour }
        #expect(dimanche == [420, 719, 720, 1260])
    }

    @Test func sansLOptionChabbatLeRappelSonneLeSamedi() {
        var r = Self.reglages(heures: [420, 1260])
        r.setShabbatMode(false)
        let plan = Self.plan(r, Journal(), Self.a("2026-10-15", 6), Self.paris)
        let samedi = Self.rappelsSeuls(plan).filter { Self.paris.jour(millis: $0.instant).iso == "2026-10-17" }.count
        #expect(samedi == 2)
    }

    @Test func aucunRappelUnJourDeReposQuelsQueSoientLesReglages() {
        for graine in Int32(1000)..<Int32(1200) {
            let e = Self.tire(graine)
            let tel = e.fuseau.identifiant
            let plan = Self.plan(e.reglages, e.journal, e.maintenant, e.fuseau, vol: e.vol)
            for p in plan where p.identifiant.hasPrefix("rappel-") {
                let civile = e.fuseau.dateHeure(millis: p.instant)
                let exempt = Store.isExempt(reglages: e.reglages, date: civile.jour, fuseauTelephone: tel)
                #expect(!exempt, "graine \(graine) : \(p.identifiant)")
                let veille = Store.isEveOfRestDay(reglages: e.reglages, date: civile.jour, fuseauTelephone: tel)
                let veilleApresMidi = veille && civile.minutesDuJour >= ReminderRule.noSunsetCutoffMinutes
                #expect(!veilleApresMidi, "graine \(graine) : \(p.identifiant)")
                if e.reglages.shabbatMode {
                    let repos = Holidays.isRestDay(civile.jour, inIsrael: e.reglages.inIsrael(fuseauTelephone: tel))
                    #expect(!repos, "graine \(graine) : \(p.identifiant)")
                }
                let fait = Store.isDone(journal: e.journal, date: civile.jour)
                #expect(!fait, "graine \(graine) : \(p.identifiant)")
                let pendant = Store.isSessionRunning(reglages: e.reglages, millis: p.instant)
                #expect(!pendant, "graine \(graine) : \(p.identifiant)")
                let apres = p.instant > e.maintenant
                #expect(apres, "graine \(graine) : \(p.identifiant)")
            }
        }
    }

    // MARK: La journée faite, la séance

    @Test func lesRappelsDuJourDisparaissentQuandLaJourneeEstFaite() {
        let r = Self.reglages(heures: [420, 780, 1260])
        let maintenant = Self.a("2026-10-14", 6)
        var journal = Journal()
        let avant = Self.rappelsSeuls(Self.plan(r, journal, maintenant, Self.paris))
        let duJourAvant = avant.filter { Self.paris.jour(millis: $0.instant).iso == "2026-10-14" }.count
        #expect(duJourAvant == 3)
        journal.addSession(minutes: 15, date: JourCivil.du("2026-10-14"))
        let apres = Self.rappelsSeuls(Self.plan(r, journal, maintenant, Self.paris))
        let duJourApres = apres.filter { Self.paris.jour(millis: $0.instant).iso == "2026-10-14" }.count
        #expect(duJourApres == 0)
        let suiteAvant = avant.filter { Self.paris.jour(millis: $0.instant).iso != "2026-10-14" }.map { $0.instant }
        let suiteApres = apres.map { $0.instant }
        #expect(suiteApres == suiteAvant)
    }

    @Test func ceuxQuiTomberaientPendantUneSeanceSontRetires() throws {
        var r = Self.reglages(heures: [780, 790, 1260])
        let maintenant = Self.a("2026-10-14", 12, 50)
        let sans = Self.rappelsSeuls(Self.plan(r, Journal(), maintenant, Self.paris)).prefix(3).map { $0.instant }
        let attendus = [Self.a("2026-10-14", 13), Self.a("2026-10-14", 13, 10), Self.a("2026-10-14", 21)]
        #expect(sans == attendus)
        Store.beginSession(reglages: &r, minutes: 45, millis: Self.a("2026-10-14", 12, 45))
        let plan = Self.plan(r, Journal(), maintenant, Self.paris)
        let premiers = Self.rappelsSeuls(plan).prefix(1).map { $0.instant }
        let neufHeures = [Self.a("2026-10-14", 21)]
        #expect(premiers == neufHeures)
        let seance = plan.first { $0.categorie == .seance }
        let fin = try #require(seance)
        let finAttendue = Self.a("2026-10-14", 13, 30)
        #expect(fin.instant == finAttendue)
        #expect(fin.titre == Libelle("session_done_title"))
        #expect(fin.texte == Libelle("session_done_text", .libelle(Libelle("duration_minutes", .entier(45)))))
    }

    @Test func uneSeanceOuverteTaitTousLesRappels() {
        var r = Self.reglages(heures: [780, 1260])
        let maintenant = Self.a("2026-10-14", 12, 50)
        Store.beginSession(reglages: &r, minutes: 0, millis: Self.a("2026-10-14", 12, 45))
        let plan = Self.plan(r, Journal(), maintenant, Self.paris)
        let rappels = Self.rappelsSeuls(plan).count
        #expect(rappels == 0)
        let fin = PlanNotifications.finDeSeance(reglages: r, maintenant: maintenant)
        #expect(fin == nil)
    }

    // MARK: Le report

    @Test func leReportDeCinqEtDeQuinzeMinutes() throws {
        let maintenant = Self.a("2026-10-14", 9)
        for minutes in [5, 15] {
            var r = Self.reglages(heures: [420, 780, 1260])
            r.setReminderSnoozedUntil(maintenant + Int64(minutes) * 60_000)
            let plan = Self.plan(r, Journal(), maintenant, Self.paris)
            let premier = plan.first { $0.categorie == .seance }
            let reporte = try #require(premier)
            let attendu = Self.a("2026-10-14", 9, minutes)
            #expect(reporte.instant == attendu, "\(minutes) min")
            #expect(reporte.identifiant == "rappel-reporte-" + String(reporte.instant), "\(minutes) min")
            #expect(reporte.actions == [.commencer, .plusTard], "\(minutes) min")
            #expect(reporte.titre == Libelle("reminder_title"), "\(minutes) min")
            let suivant = Self.rappelsSeuls(plan).first?.instant
            let treizeHeures = Self.a("2026-10-14", 13)
            #expect(suivant == treizeHeures, "\(minutes) min")
        }
    }

    @Test func leReportDeLaBarriereNAjouteAucuneNotification() {
        let maintenant = Self.a("2026-10-14", 9)
        let r = Self.reglages(heures: [420, 780, 1260])
        let sans = Self.plan(r, Journal(), maintenant, Self.paris)
        for minutes in [5, 15] {
            var reporte = r
            reporte.setSnoozeMinutes(minutes)
            Store.snooze(reglages: &reporte, millis: maintenant)
            let avec = Self.plan(reporte, Journal(), maintenant, Self.paris)
            #expect(avec == sans, "\(minutes) min")
        }
    }

    @Test func plusTardReporteDeTrenteMinutes() throws {
        let maintenant = Self.a("2026-10-14", 9)
        var r = Self.reglages(heures: [420, 780, 1260])
        r.setReminderSnoozedUntil(Reminder.snooze(maintenant: maintenant))
        let plan = Self.plan(r, Journal(), maintenant, Self.paris)
        let premier = plan.first { $0.categorie == .seance }
        let reporte = try #require(premier)
        let attendu = Self.a("2026-10-14", 9, 30)
        #expect(reporte.instant == attendu)
    }

    @Test func unReportApresLeProchainRappelSePerd() {
        // Comme sur Android : le rappel de 13 h sonne d'abord et consomme le report.
        let maintenant = Self.a("2026-10-14", 12, 50)
        var r = Self.reglages(heures: [420, 780, 1260])
        r.setReminderSnoozedUntil(Self.a("2026-10-14", 13, 20))
        let plan = Self.plan(r, Journal(), maintenant, Self.paris)
        let reportes = plan.filter { $0.categorie == .seance }.count
        #expect(reportes == 0)
    }

    // MARK: Les textes

    private static func resolu(_ l: Libelle, _ c: Catalogue, _ langue: String) -> String? {
        let simples = c.simples(langue)
        let pluriels = c.pluriels(langue)
        return l.texte(langue: langue, chaine: { simples[$0] }, pluriel: { cle, forme in pluriels[cle + "[" + forme + "]"] })
    }

    @Test func lesTextesSeResolventDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        var r = Self.reglages(heures: [420, 1260])
        let maintenant = Self.a("2026-10-14", 9)
        r.setLieuZmanim(Lieux.paris, ville: nil, maintenant: maintenant)
        r.setReminderSnoozedUntil(maintenant + 5 * 60_000)
        Store.beginSession(reglages: &r, minutes: 90, millis: maintenant - 60_000)
        var vol: [VolRappels.Rappel] = []
        for (k, type) in VolRappels.Genre.allCases.enumerated() {
            vol.append(VolRappels.Rappel(type: type, instant: maintenant + Int64(k + 1) * 3_600_000, priere: "minha",
                                         limite: maintenant + 9_000_000, omer: 12))
        }
        vol.append(VolRappels.Rappel(type: .priere, instant: maintenant + 7 * 3_600_000, priere: nil))
        let plan = Self.plan(r, Journal(), maintenant, Self.paris, vol: vol)
        let categories = Set(plan.map { $0.categorie })
        #expect(categories == Set(NotificationPlanifiee.Categorie.allCases))
        // Ce que la notification ouvre : Birkat haLevana (LevanaAlerteReceiver), VolAlerte.texteSiddur, sinon l'accueil.
        let ouverts = plan.map { $0.categorie.rawValue + ":" + ($0.texteSiddur ?? "-") }
        for o in ouverts where o.hasPrefix("levana:") {
            #expect(o == "levana:birkat_halevana")
        }
        let vols = ouverts.filter { $0.hasPrefix("vol:") }
        #expect(vols == ["vol:tefilat_haderekh", "vol:minha", "vol:minha", "vol:sefirat_haomer", "vol:arvit"])
        let autres = ouverts.filter { !$0.hasPrefix("levana:") && !$0.hasPrefix("vol:") && !$0.hasSuffix(":-") }
        let aucunAutre = autres.isEmpty
        #expect(aucunAutre, "\(autres)")
        for langue in Catalogue.langues {
            for p in plan {
                var libelles = [p.titre, p.texte]
                if let suite = p.suite { libelles.append(suite) }
                for l in libelles {
                    let texte = Self.resolu(l, catalogue, langue)
                    #expect(texte != nil, "\(langue) : \(p.identifiant) \(l)")
                }
                for action in p.actions {
                    let present = catalogue.simples(langue)[action.libelle] != nil
                    #expect(present, "\(langue) : \(action.libelle)")
                }
            }
        }
    }

    @Test func instantTexteEcritCommeJava() {
        let rond = PlanNotifications.instantTexte(Self.a("2026-10-14", 9))
        #expect(rond == "2026-10-14T07:00:00Z")
        let fin = PlanNotifications.instantTexte(1_000_000_000_123)
        #expect(fin == "2001-09-09T01:46:40.123Z")
        let zero = PlanNotifications.instantTexte(0)
        #expect(zero == "1970-01-01T00:00:00Z")
    }

    // MARK: Les vecteurs de la JVM

    /// Un élément de tableau mêlé : un nombre, un texte ou null.
    private enum Brut: Decodable {
        case nombre(Int64)
        case texte(String)
        case nul

        init(from decoder: any Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() {
                self = .nul
            } else if let n = try? c.decode(Int64.self) {
                self = .nombre(n)
            } else {
                self = .texte(try c.decode(String.self))
            }
        }

        var nombre: Int64? {
            if case .nombre(let n) = self { return n }
            return nil
        }

        var texte: String? {
            if case .texte(let t) = self { return t }
            return nil
        }
    }

    private struct Fichier: Decodable {
        let cas: [Cas]
    }

    private struct Trophee: Decodable {
        let cle: String
        let famille: String
        let seuil: Int
        let reste: Int
    }

    private struct Cas: Decodable {
        let nom: String
        let fuseau: String
        let maintenant: Int64
        let prefs: String
        let days: String
        let jours: [String: String]
        let volRappels: [[Brut]]
        let rappels: [[Brut]]
        let trophee: Trophee?
        let allumages: [String: Brut]
        let chabbat: [Int64]
        let tsets: [String: Brut]
        let levana: [[Brut]]
        let vol: [[Brut]]
    }

    private static func vecteurs() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/plan.json"))
    }

    private static func rappelDuVol(_ ligne: [Brut]) throws -> VolRappels.Rappel {
        let nom = try #require(ligne[0].texte)
        let type = try #require(VolRappels.Genre(rawValue: nom.lowercased()))
        let instant = try #require(ligne[1].nombre)
        let omer = try #require(ligne[4].nombre)
        return VolRappels.Rappel(type: type, instant: instant, priere: ligne[2].texte, limite: ligne[3].nombre,
                                 omer: Int(omer))
    }

    @Test func lesVecteursCouvrentLesCasVoulus() throws {
        let f = try Self.vecteurs()
        let nombre = f.cas.count
        #expect(nombre == 89)
        var reportes = 0
        var chabbats = 0
        var levanas = 0
        var vols = 0
        for c in f.cas {
            reportes += c.rappels.filter { $0.count == 2 && $0[1].texte == "reporte" }.count
            chabbats += c.chabbat.count
            levanas += c.levana.count
            vols += c.vol.count
        }
        #expect(reportes >= 5)
        #expect(chabbats >= 100)
        #expect(levanas >= 300)
        #expect(vols >= 200)
    }

    @Test func lesRappelsSontCeuxDAndroid() throws {
        for c in try Self.vecteurs().cas {
            let f = Self.fuseau(c.fuseau)
            let reglages = try Reglages(texte: c.prefs)
            let journal = Journal(daysTexte: c.days)
            // Ce que Store dit des dix jours : exempté, veille d'un jour chômé, fait.
            for (iso, drapeaux) in c.jours {
                let jour = JourCivil.du(iso)
                let exempt = Store.isExempt(reglages: reglages, date: jour, fuseauTelephone: c.fuseau)
                let veille = Store.isEveOfRestDay(reglages: reglages, date: jour, fuseauTelephone: c.fuseau)
                let fait = Store.isDone(journal: journal, date: jour)
                let rendu = (exempt ? "1" : "0") + (veille ? "1" : "0") + (fait ? "1" : "0")
                #expect(rendu == drapeaux, "\(c.nom) : \(iso)")
            }
            let rendus = PlanNotifications.rappels(reglages: reglages, journal: journal, maintenant: c.maintenant, fuseau: f)
            let instants = rendus.map { $0.instant }
            let attendus = c.rappels.compactMap { $0.first?.nombre }
            #expect(instants == attendus, "\(c.nom)")
            let categories = rendus.map { $0.categorie == .seance ? "reporte" : "rappel" }
            let categoriesAttendues = c.rappels.compactMap { $0.count == 2 ? $0[1].texte : nil }
            #expect(categories == categoriesAttendues, "\(c.nom)")
            // La phrase du trophée, sous le premier rappel montré.
            let aujourdhui = f.jour(millis: c.maintenant)
            let proche = PlanNotifications.tropheeProche(reglages: reglages, journal: journal, aujourdhui: aujourdhui,
                                                         fuseauTelephone: c.fuseau)
            let cle = proche?.cle
            #expect(cle == c.trophee?.cle, "\(c.nom)")
            if let t = c.trophee {
                let description = Libelle.pluriel("trophee_" + t.famille.lowercased() + "_desc", quantite: t.seuil, .entier(t.seuil))
                let phrase = Libelle("rappel_trophee_proche", .entier(t.reste), .libelle(description))
                #expect(proche?.phrase == phrase, "\(c.nom)")
                if let premier = rendus.first {
                    #expect(premier.suite == phrase, "\(c.nom)")
                    #expect(premier.trophee == t.cle, "\(c.nom)")
                }
            } else if let premier = rendus.first {
                #expect(premier.suite == nil, "\(c.nom)")
            }
        }
    }

    @Test func chabbatEtLevanaSontCeuxDAndroid() throws {
        for c in try Self.vecteurs().cas {
            let f = Self.fuseau(c.fuseau)
            let reglages = try Reglages(texte: c.prefs)
            let allumages = c.allumages
            let tsets = c.tsets
            let chabbat = PlanNotifications.chabbat(reglages: reglages, maintenant: c.maintenant, fuseau: f,
                                                    allumage: { _, jour, _ in allumages[jour.iso]?.nombre })
            let instants = chabbat.map { $0.instant }
            #expect(instants == c.chabbat, "\(c.nom)")
            let levana = PlanNotifications.levana(reglages: reglages, maintenant: c.maintenant, fuseau: f,
                                                  horaires: { _, jour in
                                                      guard let tset = tsets[jour.iso]?.nombre else { return [:] }
                                                      return ["tset": tset]
                                                  })
            let soirs = levana.map { $0.instant }
            let soirsAttendus = c.levana.compactMap { $0.first?.nombre }
            #expect(soirs == soirsAttendus, "\(c.nom)")
            let titres = levana.map { $0.titre }
            let titresAttendus = c.levana.compactMap { ligne in
                ligne.count == 2 ? ligne[1].texte.map { Libelle("levana_rappel_" + $0.lowercased()) } : nil
            }
            #expect(titres == titresAttendus, "\(c.nom)")
        }
    }

    @Test func leVolEstCeluiDAndroid() throws {
        for c in try Self.vecteurs().cas {
            let reglages = try Reglages(texte: c.prefs)
            var rappels: [VolRappels.Rappel] = []
            for ligne in c.volRappels { rappels.append(try Self.rappelDuVol(ligne)) }
            let rendus = PlanNotifications.vol(reglages: reglages, rappels: rappels, maintenant: c.maintenant, nombre: 40,
                                               heure: PlanNotifications.instantTexte)
            let instants = rendus.map { $0.instant }
            let attendus = c.vol.compactMap { $0.first?.nombre }
            #expect(instants == attendus, "\(c.nom)")
            let n = min(rendus.count, c.vol.count)
            for k in 0..<n {
                let ligne = c.vol[k]
                let type = (ligne[1].texte ?? "").lowercased()
                let instant = ligne[2].nombre ?? -1
                let suffixe = "-" + type + "-" + String(instant)
                let bon = rendus[k].identifiant.hasSuffix(suffixe)
                #expect(bon, "\(c.nom) : \(rendus[k].identifiant) au lieu de …\(suffixe)")
            }
        }
    }
}
