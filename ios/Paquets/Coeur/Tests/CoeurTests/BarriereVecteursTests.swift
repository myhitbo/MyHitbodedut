import Foundation
import Testing
@testable import Coeur

/// La barrière, le planificateur et les vignettes devant la JVM (Tests/Vecteurs/barriere.json,
/// tools/vecteurs_ios/VecteursBarriere.kt) : la règle du rappel sur toutes ses entrées, l'alerte de Chabbat et le rappel
/// de Birkat haLevana sur les vrais zmanim de cinq lieux pendant un an, la prière du moment et la jauge à toute heure,
/// les jours exemptés de quatorze mois, la fenêtre posée autour de l'heure qu'il est, le report, et les titres,
/// couleurs et détails de `GateStatus` dans les trois langues. Les instants calculés par KosherSwift sont comparés à
/// 1,5 s près (KOSHERSWIFT.md : tous les zmanim de 1.10.11 tiennent la seconde).
@Suite("Barrière devant la JVM")
struct BarriereVecteursTests {

    private func vecteurs() throws -> ObjetJSON { try Depot.vecteurs("barriere.json") }

    private func lignes(_ cle: String) throws -> [[JSON]] {
        try vecteurs().tableau(cle)?.compactMap { valeur -> [JSON]? in
            if case .tableau(let r) = valeur { return r }
            return nil
        } ?? []
    }

    private func textes(_ cle: String) throws -> [[String]] {
        let t = try vecteurs().tableau(cle) ?? []
        return t.indices.map { t.texte($0).components(separatedBy: "|") }
    }

    private func zone(_ id: String) throws -> Fuseau { try #require(Fuseau(id), "fuseau « \(id) » inconnu") }

    private func lieu(_ nom: String) throws -> Zmanim.Lieu {
        let tous = [Lieux.jerusalem, Lieux.paris, Lieux.newYork, Lieux.melbourne, Lieux.tromso]
        return try #require(tous.first { $0.nom == nom }, "lieu « \(nom) »")
    }

    /// « - » pour null, sinon des millisecondes.
    private func millis(_ texte: String) -> Int64? { texte == "-" ? nil : Int64(texte) }

    private func proche(_ a: Int64?, _ b: Int64?, _ tolerance: Int64 = 1500) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (x?, y?): abs(x - y) <= tolerance
        default: false
        }
    }

    // MARK: Rappels

    @Test func regleDuRappel() throws {
        let cas = try textes("regle")
        #expect(cas.count == 480)
        for c in cas {
            let r = ReminderRule.doitSonner(maintenant: Int(c[0]) ?? 0, faite: c[1] == "1", repos: c[2] == "1",
                                            veilleDeRepos: c[3] == "1", coucher: Int(c[4]))
            #expect(r == (c[5] == "1"), "\(c)")
        }
    }

    @Test func prochainesHeures() throws {
        let cas = try textes("prochaines")
        #expect(cas.count == 225)
        for c in cas {
            let heures = c[1].isEmpty ? [] : c[1].components(separatedBy: ",").compactMap { Int($0) }
            let r = ReminderRule.minutesAvantProchain(Int(c[0]) ?? 0, heures: heures)
            #expect(r == Int(c[2]), "\(c)")
        }
    }

    @Test func chabbatDansTroisHeures() throws {
        let cas = try textes("chabbat")
        #expect(cas.count == 400)
        for c in cas {
            let l = try lieu(c[0])
            let minutes = Int(c[1]) ?? 18
            let fuseau = try zone(c[2])
            let maintenant = DateHeureZonee(millis: Int64(c[3]) ?? 0, fuseau: fuseau)
            let r = ChabbatAlerte.prochaine(maintenant) { ChabbatAlerte.allumage(l, $0, minutes: minutes) }
            #expect(proche(r?.millis, millis(c[4])), "\(c) → \(r?.millis ?? -1)")
        }
    }

    @Test func rappelsDeBirkatHaLevana() throws {
        let cas = try textes("levana")
        #expect(cas.count == 432)
        for c in cas {
            var l: Zmanim.Lieu?
            if c[0] != "-" { l = try lieu(c[0]) }
            let fuseau = try zone(l?.fuseau ?? "Europe/Paris")
            let usage = try #require(Levana.Usage(rawValue: c[1]))
            let maintenant = DateHeureZonee(millis: Int64(c[2]) ?? 0, fuseau: fuseau)
            let r = LevanaAlerte.prochain(maintenant, usage: usage) { LevanaAlerte.heure($0, lieu: l, fuseau: fuseau) }
            #expect(proche(r?.quand.millis, millis(c[3])), "\(c) → \(r?.quand.millis ?? -1)")
            #expect((r?.soir.rawValue ?? "-") == c[4], "\(c)")
        }
    }

    // MARK: Vignettes

    @Test func vignettesSurLesVraisZmanim() throws {
        let cas = try textes("vignettes")
        #expect(cas.count == 460)
        var memoire: [String: [String: DateHeureZonee]] = [:]
        func horaires(_ l: Zmanim.Lieu, _ d: JourCivil) -> [String: DateHeureZonee] {
            let cle = "\(l.nom) \(d.iso)"
            if let h = memoire[cle] { return h }
            let h = ZmanimVignette.horaires(l, d)
            memoire[cle] = h
            return h
        }
        for c in cas {
            let l = try lieu(c[0])
            let fuseau = try zone(l.fuseau)
            let m = DateHeureZonee(millis: Int64(c[1]) ?? 0, fuseau: fuseau)
            let aujourdhui = horaires(l, m.jour)
            let p = ZmanimWidget.prochaine(aujourdhui, maintenant: m)
            #expect(p.priere == c[2], "\(c)")
            #expect(proche(p.limite?.millis, millis(c[3])), "\(c) limite")
            let debut = ZmanimVignette.debut(p.priere, aujourdhui)
            #expect(proche(debut?.millis, millis(c[4])), "\(c) début")
            let ecoule = ZmanimVignette.ecoule(debut: debut, fin: p.limite, maintenant: m)
            #expect(abs(ecoule - (Int(c[5]) ?? -9)) <= 1, "\(c) écoulé \(ecoule)")
            #expect(ZmanimVignette.jourHebreuAffiche(m, tset: aujourdhui["tset"]).iso == c[6], "\(c) jour")
            let tous: [DateHeureZonee?] = Array(aujourdhui.values) + Array(horaires(l, m.jour.plus(jours: 1)).values)
            let changement = ZmanimVignette.prochainChangement(tous, maintenant: m)
            #expect(proche(changement.millis, millis(c[7])), "\(c) changement")
        }
    }

    @Test func prieresSurDesHorairesForges() throws {
        let cas = try textes("prieres")
        #expect(cas.count == 451)
        for c in cas {
            let fuseau = try zone(c[0])
            let jour = JourCivil.du(c[0] == "Asia/Jerusalem" ? "2026-10-14" : "2026-03-29")
            func t(_ j: JourCivil, _ h: Int, _ m: Int) -> DateHeureZonee {
                DateHeureZonee(DateHeure(j, heure: h, minute: m), fuseau: fuseau)
            }
            var horaires: [String: DateHeureZonee] = [:]
            if c[1] == "alot,chatsot_layla*" {
                horaires = ["alot": t(jour, 5, 0), "chatsot_layla": t(jour.plus(jours: 1), 2, 30)]
            } else {
                let tous = ["alot": t(jour, 5, 20), "szt_gra": t(jour, 10, 30), "chkia": t(jour, 17, 50),
                            "chatsot_layla": t(jour, 23, 40).plus(minutes: 70)]
                for cle in c[1].components(separatedBy: ",") where !cle.isEmpty { horaires[cle] = tous[cle] }
            }
            let m = DateHeureZonee(millis: Int64(c[2]) ?? 0, fuseau: fuseau)
            let p = ZmanimWidget.prochaine(horaires, maintenant: m)
            #expect(p.priere == c[3], "\(c)")
            #expect(p.limite?.millis == millis(c[4]), "\(c)")
        }
    }

    @Test func partsEcoulees() throws {
        let cas = try textes("ecoules")
        #expect(cas.count == 113)
        let fuseau = try zone("Asia/Jerusalem")
        func instant(_ s: String) -> DateHeureZonee? { millis(s).map { DateHeureZonee(millis: $0, fuseau: fuseau) } }
        for c in cas {
            let m = try #require(instant(c[2]))
            let r = ZmanimVignette.ecoule(debut: instant(c[0]), fin: instant(c[1]), maintenant: m)
            #expect(r == Int(c[3]), "\(c)")
        }
    }

    // MARK: Barrière

    @Test func joursExemptesEtVeilles() throws {
        let cas = try lignes("exemptions")
        #expect(cas.count == 4)
        for c in cas {
            var r = Reglages(enIsrael: c.booleen(1))
            r.pauseShabbat = c.booleen(0)
            let pauses = c.tableau(2) ?? []
            r.joursPause = Set(pauses.indices.map { pauses.texte($0) })
            let debut = JourCivil.du(c.texte(3))
            let chiffres = Array(c.texte(4).utf8)
            var attendus: [JourCivil] = []
            for (k, chiffre) in chiffres.enumerated() {
                let d = debut.plus(jours: k)
                let v = Int(chiffre) - 48
                let exempte = Pratique.exempte(d, r)
                let veille = r.pauseShabbat && Holidays.isEveOfRestDay(d, inIsrael: r.enIsrael)
                #expect(exempte == (v & 1 != 0), "\(d) \(c.booleen(0)) \(c.booleen(1))")
                #expect(veille == (v & 2 != 0), "\(d) veille")
                if v & 1 != 0 { attendus.append(d) }
            }
            let liste = Barriere.joursExemptes(depuis: debut, reglages: r, jours: chiffres.count)
            #expect(liste == attendus)
        }
    }

    @Test func fenetrePoseeAutourDeLHeure() throws {
        let cas = try textes("fenetres_relatives")
        #expect(cas.count == 64)
        for c in cas {
            let a = Int(c[0]) ?? 0, b = Int(c[1]) ?? 0
            for m in [0, 1, 59, 60, 61, 600, 719, 720, 1380, 1438, 1439] {
                let r = Barriere.dansFenetre(debut: Kotlin.floorMod(m + a, 1440), fin: Kotlin.floorMod(m + b, 1440), minutes: m)
                #expect(r == (c[2] == "1"), "\(c) à \(m)")
            }
        }
        let brutes = try textes("fenetres_brutes")
        #expect(brutes.count == 8)
        for c in brutes {
            let debut = Int(c[0]) ?? 0, fin = Int(c[1]) ?? 0
            let dedans = (0..<1440).filter { Barriere.dansFenetre(debut: debut, fin: fin, minutes: $0) }.count
            #expect(dedans == (c[2] == "1" ? 1440 : 0), "\(c)")
        }
    }

    @Test func reportEtJourneeDejaFaite() throws {
        let cas = try lignes("reports")
        let durees = cas.filter { $0.texte(0) == "report" }.map { $0.entier(1) }
        #expect(durees == Barriere.durees)
        let fuseau = try zone("Europe/Paris")
        let t: Int64 = 1_793_000_000_000
        for c in cas where c.texte(0) == "report" {
            #expect(c.booleen(2) && c.booleen(3))
            var r = Reglages(enIsrael: false)
            r.report = c.entier(1)
            Barriere.reporter(&r, maintenant: t)
            #expect(r.reporteJusqua == t + Int64(c.entier(1)) * 60_000)
            #expect(Barriere.reportee(jusqua: r.reporteJusqua, maintenant: t))
            #expect(!Barriere.reportee(jusqua: r.reporteJusqua, maintenant: r.reporteJusqua))
        }
        let faite = try #require(cas.first { $0.texte(0) == "deja_faite" })
        let nuit = try #require(cas.first { $0.texte(0) == "deja_faite_nuit" })
        var d = Donnees(reglages: Reglages(enIsrael: false))
        Barriere.reporter(&d.reglages, maintenant: t)
        let maintenant = DateHeureZonee(millis: t, fuseau: fuseau)
        Pratique.inscrire(&d, minutes: 0, jour: maintenant.jour, maintenant: maintenant)
        let jour = d.journal.jours[maintenant.jour]
        #expect(jour?.minutes == faite.entier(1))
        #expect(jour?.faite == faite.booleen(2))
        #expect(Barriere.reportee(jusqua: d.reglages.reporteJusqua, maintenant: t) == faite.booleen(4))
        #expect(d.reglages.reporteJusqua == faite.long(5))
        #expect(Barriere.fenetreFaite(d, maintenant: maintenant) == faite.booleen(6))
        d.reglages.debutFenetre = 21 * 60
        d.reglages.finFenetre = 2 * 60
        #expect(Barriere.fenetreFaite(d, maintenant: maintenant) == nuit.booleen(1))
    }

    @Test func defautsDeStore() throws {
        let o = try #require(try vecteurs().objet("defauts"))
        let r = Reglages(enIsrael: false)
        #expect(r.debutFenetre == o.entier("debut"))
        #expect(r.finFenetre == o.entier("fin"))
        #expect(r.report == o.entier("report"))
        #expect(r.modeBarriere == o.booleen("actif"))
        #expect(r.applisBloquees.count == o.entier("applications"))
        #expect(r.reporteJusqua == o.long("reporte_jusqua"))
        #expect(r.pauseShabbat == o.booleen("chabbat"))
        #expect(r.rappelActif == o.booleen("rappel_actif"))
        let rappels = o.tableau("rappels") ?? []
        let attendus = rappels.indices.map { rappels.entier($0) }
        #expect(r.rappels == attendus)
        #expect(r.rappelReporteJusqua == o.long("rappel_reporte"))
        #expect(r.levanaRappel == o.booleen("levana_rappel"))
        #expect(r.allumage == o.entier("allumage"))
        #expect(ReminderRule.reportMinutes == o.entier("report_rappel"))
        #expect(ChabbatAlerte.avanceHeures == o.entier("avance_chabbat"))
        #expect(ReminderRule.limiteSansCoucher == o.entier("sans_coucher"))
    }

    @Test func etatsTitresEtCouleurs() throws {
        let cas = try lignes("etats")
        let noms = cas.map { $0.texte(0) }
        let android = Barriere.Etat.allCases.filter { !$0.propreAIOS }.map { $0.rawValue }
        #expect(noms == android)
        for c in cas {
            let etat = try #require(Barriere.Etat(rawValue: c.texte(0)))
            #expect("string/" + etat.cleTitre == c.texte(1))
            #expect("color/" + etat.couleur.rawValue == c.texte(2))
        }
    }

    /// La forme de pluriel que choisit Android pour ces trois langues (CLDR, entiers), comme `Theatre` sur la JVM.
    private func forme(_ langue: String, _ n: Int) -> String {
        switch langue {
        case "fr": n == 0 || n == 1 ? "one" : "other"
        case "he": n == 1 ? "one" : n == 2 ? "two" : "other"
        default: n == 1 ? "one" : "other"
        }
    }

    @Test func detailsDansLesTroisLangues() throws {
        let cas = try lignes("details")
        #expect(cas.count == 48)
        let catalogue = try Catalogue.lire()
        for c in cas {
            let langue = c.texte(0)
            let etat = try #require(Barriere.Etat(rawValue: c.texte(1)))
            let detail = Barriere.detail(etat, applications: c.entier(2), debut: c.entier(3), fin: c.entier(4))
            var gabarit: String?
            if let n = detail.quantite {
                let pluriels = catalogue.pluriels(langue)
                gabarit = pluriels["\(detail.cle)[\(forme(langue, n))]"] ?? pluriels["\(detail.cle)[other]"]
            } else {
                gabarit = catalogue.simples(langue)[detail.cle]
            }
            var texte = try #require(gabarit, "\(langue) \(detail.cle)")
            for (k, argument) in detail.arguments.enumerated() {
                for marque in ["%\(k + 1)$lld", "%\(k + 1)$@"] {
                    texte = texte.replacingOccurrences(of: marque, with: argument)
                }
            }
            #expect(texte == c.texte(5), "\(langue) \(etat)")
        }
    }

    // MARK: DixAmeliorations

    @Test func extraitsDeRecherche() throws {
        let cas = try lignes("extraits")
        #expect(cas.count == 40)
        for c in cas {
            #expect(RechercheGlobale.extrait(c.texte(0), c.texte(1)) == c.texte(2), "« \(c.texte(1)) »")
        }
    }

    @Test func resumesDuJournal() throws {
        let cas = try lignes("resumes")
        #expect(cas.count == 12)
        for c in cas {
            let plus = JournalPlus(avant: c.entier(0), apres: c.entier(1), gratitude: c.texte(2), travail: c.texte(3))
            let r = JournalPlus.resume(plus, gratitude: "G", travail: c.texte(5), sujets: c.texte(4))
            #expect(r == c.texte(6), "\(c)")
        }
    }

    @Test func minutesDuMois() throws {
        let jours: [JourCivil: Journee] = [
            JourCivil.du("2026-10-01"): Journee(minutes: 20),
            JourCivil.du("2026-10-03"): Journee(minutes: 0, note: "note", noteSeule: true),
            JourCivil.du("2026-10-31"): Journee(minutes: 45),
            JourCivil.du("2028-02-29"): Journee(minutes: 12),
            JourCivil.du("2028-02-01"): Journee(minutes: 0),
            JourCivil.du("2026-11-01"): Journee(minutes: 7),
        ]
        let cas = try lignes("mois")
        #expect(cas.count == 4)
        for c in cas {
            let attendu = c.tableau(2) ?? []
            let minutes = JournalPlus.minutesDuMois(jours, annee: c.entier(0), mois: c.entier(1))
            let valeurs = attendu.indices.map { attendu.entier($0) }
            #expect(minutes == valeurs, "\(c.entier(0))-\(c.entier(1))")
        }
    }
}
