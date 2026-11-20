import Foundation
import Testing
@testable import Barriere

// GateStatus.evaluate n'a pas de test d'Android : les cas viennent de PORTAGE.md § 2.1.5 à 2.1.8 et des
// critères de la tâche 12 de ROADMAP.md (les treize états, le report de 5 et de 15 minutes, la fenêtre de
// nuit un vendredi soir, la liste des jours exemptés, le repli du samedi). fenetreFaite rejoue les vecteurs
// de store.json (VecteursStore.kt) ; isExempt, isSnoozed et inWindow sont confrontés aux règles de Store de
// Coeur dans EtatBarriereTests (laBarriereSuitLesReglesDuStore).

/// Un instant en temps universel, donné par son jour, son heure et sa minute.
private func a(_ jour: String, _ heure: Int, _ minute: Int, secondes: Int64 = 0) -> Horodatage {
    let n = Int64(JoursIso.jourUnix(jour) ?? 0)
    let minutes = heure * 60 + minute
    return Horodatage(millis: n * JoursIso.millisParJour + Int64(minutes) * 60_000 + secondes * 1000, jour: jour, minutes: minutes)
}

/// L'instant `millis` relu en temps universel.
private func instant(_ millis: Int64) -> Horodatage {
    let jour = JoursIso.divisionEntiere(millis, JoursIso.millisParJour)
    let reste = millis - jour * JoursIso.millisParJour
    return Horodatage(millis: millis, jour: JoursIso.iso(jourUnix: Int(jour)), minutes: Int(reste / 60_000))
}

/// Une barrière qui veille un lundi matin : mode allumé, trois jetons, fenêtre de 6 h à 11 h, la liste des
/// jours chômés couvrant deux ans (les deux samedis qui suivent y suffisent ici).
private func veille() -> Etat {
    var etat = Etat()
    etat.enabled = true
    etat.nombreDeJetons = 3
    etat.windowStart = 6 * 60
    etat.windowEnd = 11 * 60
    etat.exemptesDepuis = "2026-11-16"
    etat.exemptesJusquau = "2028-11-15"
    etat.joursExemptes = ["2026-11-21", "2026-11-28"]
    return etat
}

@Suite struct EvaluationTests {

    let lundi = "2026-11-16"

    // MARK: Les treize états (§ 2.1.8)

    @Test func lesTreizeEtats() {
        let matin = a(lundi, 7, 0)
        let base = veille()
        var cas: [(nom: String, etat: Etat, maintenant: Horodatage, constat: Constat, attendu: GateState)] = []
        cas.append(("veille, magasin actif", base, matin, Constat(magasinActif: true), .armed))
        cas.append(("autorisation retirée, mode allumé", base, matin, Constat(autorise: false), .autorisationRetiree))
        var eteint = base
        eteint.enabled = false
        // Le mode éteint passe avant les accès depuis le 13/11 (GateRule, FACCUEIL-06) : sans autorisation, éteint,
        // c'est « désactivé » ; MISSING_PERMISSIONS ne vient plus que de GateRule (iOS : allumé, l'accès est retiré).
        cas.append(("autorisation manquante, mode éteint", eteint, matin, Constat(autorise: false), .disabled))
        cas.append(("mode éteint", eteint, matin, Constat(), .disabled))
        var sansJeton = base
        sansJeton.nombreDeJetons = 0
        cas.append(("aucune application", sansJeton, matin, Constat(), .noAppsSelected))
        cas.append(("sélection à refaire", base, matin, Constat(selectionValide: false), .selectionARefaire))
        cas.append(("surveillance absente", base, matin, Constat(surveillanceInscrite: false), .surveillanceAbsente))
        cas.append(("surveillance muette", base, matin,
                    Constat(dernierReveil: matin.millis - Evaluation.silenceMaximum - 1), .surveillanceMuette))
        // Une hitbodedout en cours (13/11, TFRUX-02), même la journée validée et hors de la fenêtre.
        var enSeance = base
        enSeance.journee = Etat.JourneeValidee(jours: [lundi])
        enSeance.seance = Etat.Seance(debut: matin.millis - 60_000, fin: matin.millis + 60_000, minutes: 2)
        // Le bouclier « Hitbodedout en cours » est posé pendant la séance (GateRule.ecran) : le magasin actif.
        cas.append(("séance en cours", enSeance, a(lundi, 7, 0), Constat(magasinActif: true), .sessionRunning))
        var ouverte = base
        ouverte.seance = Etat.Seance(debut: matin.millis - 60_000, fin: 0, minutes: 0)
        cas.append(("séance sans durée", ouverte, a(lundi, 12, 0), Constat(), .sessionRunning))
        // Une séance minutée finie compte comme close à sa fin (Android l'inscrit alors) ; une séance commencée
        // avant d'être interrompue (l'app la retire de l'instantané) ne laisse rien.
        var finie = base
        finie.seance = Etat.Seance(debut: matin.millis - 120_000, fin: matin.millis, minutes: 2)
        cas.append(("séance finie", finie, matin, Constat(), .alreadyDone))
        var faite = base
        faite.journee = Etat.JourneeValidee(jours: [lundi])
        cas.append(("journée validée", faite, matin, Constat(), .alreadyDone))
        var enPause = base
        enPause.joursEnPause = [lundi]
        cas.append(("jour sans obligation", enPause, matin, Constat(), .exemptDay))
        var reporte = base
        reporte.snoozedUntil = matin.millis + 1
        cas.append(("report en cours", reporte, matin, Constat(), .snoozed))
        cas.append(("hors de la fenêtre", base, a(lundi, 11, 0), Constat(), .outsideWindow))
        cas.append(("bouclier désaccordé", base, matin, Constat(magasinActif: false), .bouclierDesaccorde))

        var vus = Set<GateState>()
        for c in cas {
            let etat = Evaluation.evaluate(c.etat, maintenant: c.maintenant, constat: c.constat)
            #expect(etat == c.attendu, "\(c.nom)")
            vus.insert(etat)
        }
        // MISSING_PERMISSIONS et SERVICE_STOPPED ne viennent que de GateRule : l'iOS dit l'accès retiré, et n'a pas de
        // service (les pannes de la surveillance en tiennent lieu).
        let tous = Set(GateState.allCases).subtracting([.missingPermissions, .serviceStopped])
        #expect(vus == tous)
        let nombre = GateState.allCases.count
        #expect(nombre == 15)
        var android: [String] = []
        for etat in GateState.allCases where etat.android {
            android.append(etat.rawValue)
        }
        let attendu = ["DISABLED", "MISSING_PERMISSIONS", "NO_APPS_SELECTED", "SERVICE_STOPPED", "SESSION_RUNNING",
                       "ALREADY_DONE", "EXEMPT_DAY", "SNOOZED", "OUTSIDE_WINDOW", "ARMED"]
        #expect(android == attendu)
    }

    // MARK: Le bouclier de la séance (GateService, GateRule.ecran)

    /// L'écran de garde : l'invite dans la veille, l'écran de la séance pendant une hitbodedout, à toute heure ;
    /// rien sinon.
    @Test func leVisageDuBouclier() {
        let ecrans = GateState.allCases.compactMap { etat in GateRule.ecran(etat).map { (etat, $0) } }
        #expect(ecrans.map(\.0) == [.sessionRunning, .armed])
        #expect(ecrans.map(\.1) == [.seance, .invite])
        let base = veille()
        #expect(Evaluation.bouclier(base, maintenant: a(lundi, 7, 0)) == .invite)
        #expect(Evaluation.bouclier(base, maintenant: a(lundi, 12, 0)) == nil)
        // Une séance de 20 minutes l'après-midi, hors de la fenêtre et la journée déjà faite : le bouclier de la
        // séance, puis, la séance finie, plus rien.
        var e = base
        e.journee = Etat.JourneeValidee(jours: [lundi])
        let debut = a(lundi, 15, 0)
        e.seance = Etat.Seance(debut: debut.millis, fin: debut.millis + 20 * 60_000, minutes: 20)
        #expect(Evaluation.bouclier(e, maintenant: a(lundi, 15, 10)) == .seance)
        #expect(Evaluation.evaluate(e, maintenant: a(lundi, 15, 10), constat: Constat(magasinActif: false)) == .bouclierDesaccorde)
        #expect(Evaluation.bouclier(e, maintenant: a(lundi, 15, 20)) == nil)
        // L'activité `seance` réveille la surveillance à la fin ; aucune pour une séance sans durée ou finie.
        let activite = Evaluation.activiteSeance(e, millis: a(lundi, 15, 10).millis)
        #expect(activite?.debut == debut.millis + 20 * 60_000)
        #expect(activite?.fin == debut.millis + 35 * 60_000)
        #expect(Evaluation.activiteSeance(e, millis: a(lundi, 15, 30).millis) == nil)
        var libre = base
        libre.seance = Etat.Seance(debut: debut.millis, fin: 0, minutes: 0)
        #expect(Evaluation.activiteSeance(libre, millis: debut.millis) == nil)
        #expect(Evaluation.bouclier(libre, maintenant: a(lundi, 23, 0)) == .seance)
    }

    /// La séance minutée finie dans la veille honore la fenêtre, jour et minute de sa fin lus dans le fuseau de
    /// `maintenant` ; une fenêtre de nuit (21:00–02:00) : la séance finie à 21 h 40 sert la nuit, même à 0 h 30.
    @Test func laSeanceFinieHonoreLaFenetre() {
        var e = veille()
        let debut = a(lundi, 7, 0)
        e.seance = Etat.Seance(debut: debut.millis, fin: debut.millis + 15 * 60_000, minutes: 15)
        #expect(Evaluation.regle(e, maintenant: a(lundi, 7, 20)) == .alreadyDone)
        #expect(Evaluation.regle(e, maintenant: a(lundi, 7, 10)) == .sessionRunning)
        var nuit = veille()
        nuit.windowStart = 21 * 60
        nuit.windowEnd = 2 * 60
        let soir = a(lundi, 21, 25)
        nuit.seance = Etat.Seance(debut: soir.millis, fin: soir.millis + 15 * 60_000, minutes: 15)
        #expect(Evaluation.regle(nuit, maintenant: a("2026-11-17", 0, 30)) == .alreadyDone)
        // Le fuseau de `maintenant` : à Paris (UTC+1), 7 h 20 locales ; la fin lue à 7 h 15 locales.
        let paris = Horodatage(millis: debut.millis + 20 * 60_000 - 3_600_000, jour: lundi, minutes: 7 * 60 + 20)
        var p = veille()
        p.seance = Etat.Seance(debut: paris.millis - 20 * 60_000, fin: paris.millis - 5 * 60_000, minutes: 15)
        let journee = Evaluation.journeeAvecSeanceClose(p, maintenant: paris)
        #expect(journee.faitA?.minutes == 7 * 60 + 15)
        #expect(journee.jours == [lundi])
    }

    /// Toutes les causes à la fois : chacune levée à son tour découvre la suivante, dans l'ordre de GateStatus.kt.
    @Test func lOrdreDePrioriteDAndroid() {
        let midi = a(lundi, 12, 0)
        var e = veille()
        e.enabled = false
        e.nombreDeJetons = 0
        e.journee = Etat.JourneeValidee(jours: [lundi])
        e.joursEnPause = [lundi]
        e.snoozedUntil = midi.millis + 60_000
        var vus: [GateState] = []
        vus.append(Evaluation.evaluate(e, maintenant: midi, constat: Constat(autorise: false)))
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        e.enabled = true
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        e.nombreDeJetons = 2
        e.seance = Etat.Seance(debut: midi.millis - 60_000, fin: 0, minutes: 0)
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        e.seance = nil
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        e.journee = Etat.JourneeValidee()
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        e.joursEnPause = []
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        e.windowEnd = 13 * 60
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        e.snoozedUntil = 0
        vus.append(Evaluation.evaluate(e, maintenant: midi))
        // GateRule (13/11) : le mode éteint avant les accès, la séance avant la journée, hors fenêtre avant le report.
        let attendu: [GateState] = [.disabled, .disabled, .noAppsSelected, .sessionRunning, .alreadyDone, .exemptDay,
                                    .outsideWindow, .snoozed, .armed]
        #expect(vus == attendu)
    }

    /// Les pannes d'iOS : la sélection, puis la surveillance, avant les états du jour ; le désaccord du
    /// magasin passe devant le verdict qu'il contredit.
    @Test func lesPannesDIosALeurPlace() {
        let matin = a(lundi, 7, 0)
        var e = veille()
        e.journee = Etat.JourneeValidee(jours: [lundi])
        var constat = Constat(autorise: true, selectionValide: false, surveillanceInscrite: false,
                              dernierReveil: matin.millis - 2 * Evaluation.silenceMaximum, magasinActif: true)
        var vus: [GateState] = []
        vus.append(Evaluation.evaluate(e, maintenant: matin, constat: Constat(autorise: false, selectionValide: false)))
        vus.append(Evaluation.evaluate(e, maintenant: matin, constat: constat))
        constat.selectionValide = true
        vus.append(Evaluation.evaluate(e, maintenant: matin, constat: constat))
        constat.surveillanceInscrite = true
        vus.append(Evaluation.evaluate(e, maintenant: matin, constat: constat))
        constat.dernierReveil = matin.millis - Evaluation.silenceMaximum
        vus.append(Evaluation.evaluate(e, maintenant: matin, constat: constat))
        constat.magasinActif = false
        vus.append(Evaluation.evaluate(e, maintenant: matin, constat: constat))
        let attendu: [GateState] = [.autorisationRetiree, .selectionARefaire, .surveillanceAbsente, .surveillanceMuette,
                                    .bouclierDesaccorde, .alreadyDone]
        #expect(vus == attendu)

        // Les pannes supposent un mode allumé avec une sélection.
        let pannes = Constat(selectionValide: false, surveillanceInscrite: false, dernierReveil: 0, magasinActif: true)
        var eteint = veille()
        eteint.enabled = false
        let sansMode = Evaluation.evaluate(eteint, maintenant: matin, constat: pannes)
        #expect(sansMode == .disabled)
        var vide = veille()
        vide.nombreDeJetons = 0
        let sansSelection = Evaluation.evaluate(vide, maintenant: matin, constat: pannes)
        #expect(sansSelection == .noAppsSelected)
        // Ce qui n'est pas observé ne joue pas.
        let rien = Evaluation.evaluate(veille(), maintenant: matin, constat: Constat())
        #expect(rien == .armed)
        let arme = Evaluation.isArmed(veille(), maintenant: matin)
        #expect(arme)
    }

    @Test func laRegleDeLExtensionIgnoreLesConstats() {
        let matin = a(lundi, 7, 0)
        let regle = Evaluation.regle(veille(), maintenant: matin)
        #expect(regle == .armed)
        var eteint = veille()
        eteint.enabled = false
        let sansMode = Evaluation.regle(eteint, maintenant: matin)
        #expect(sansMode == .disabled)
        var vide = veille()
        vide.nombreDeJetons = 0
        let sansSelection = Evaluation.regle(vide, maintenant: matin)
        #expect(sansSelection == .noAppsSelected)
        let tard = Evaluation.regle(veille(), maintenant: a(lundi, 11, 0))
        #expect(tard == .outsideWindow)
    }

    // MARK: Le report (§ 2.1.6)

    @Test(arguments: [5, 15])
    func reportDeCinqEtDeQuinzeMinutes(minutes: Int) {
        var e = veille()
        e.snoozeMinutes = minutes
        let demande = a(lundi, 7, 0, secondes: 30)
        Evaluation.reporter(&e, millis: demande.millis)
        let fin = demande.millis + Int64(minutes) * 60_000
        #expect(e.snoozedUntil == fin)
        let juste = Evaluation.evaluate(e, maintenant: instant(fin - 1))
        #expect(juste == .snoozed)
        let pile = Evaluation.evaluate(e, maintenant: instant(fin))
        #expect(pile == .armed)
        let activite = Evaluation.activiteReport(e, millis: demande.millis)
        #expect(activite.debut == fin)
        #expect(activite.fin == fin + 15 * 60_000)

        // Un report demandé à 10 h 55 finit hors de la fenêtre : la barrière ne revient que le lendemain.
        var tard = veille()
        tard.snoozeMinutes = minutes
        let demandeTardive = a(lundi, 10, 55)
        Evaluation.reporter(&tard, millis: demandeTardive.millis)
        let finTardive = Evaluation.evaluate(tard, maintenant: instant(tard.snoozedUntil))
        #expect(finTardive == .outsideWindow)
        let lendemain = Evaluation.evaluate(tard, maintenant: a("2026-11-17", 6, 0))
        #expect(lendemain == .armed)
    }

    // MARK: La fenêtre de nuit (§ 2.1.5, § 2.1.7)

    /// Le jour civil compte, pas le coucher du soleil : la barrière agit le vendredi soir jusqu'à minuit,
    /// se tait le samedi, et reprend la nuit de samedi à dimanche.
    @Test func fenetreDeNuitUnVendrediSoir() {
        var e = veille()
        e.windowStart = 21 * 60
        e.windowEnd = 2 * 60
        let attendus: [(Horodatage, GateState)] = [
            (a("2026-11-20", 20, 59), .outsideWindow),
            (a("2026-11-20", 21, 0), .armed),
            (a("2026-11-20", 23, 59), .armed),
            (a("2026-11-21", 0, 0), .exemptDay),
            (a("2026-11-21", 1, 59), .exemptDay),
            (a("2026-11-21", 2, 0), .exemptDay),
            (a("2026-11-21", 21, 30), .exemptDay),
            (a("2026-11-22", 0, 30), .armed),
            (a("2026-11-22", 1, 59), .armed),
            (a("2026-11-22", 2, 0), .outsideWindow),
        ]
        for (quand, attendu) in attendus {
            let etat = Evaluation.evaluate(e, maintenant: quand)
            #expect(etat == attendu, "\(quand.jour) à \(quand.minutes) min")
        }

        // Une séance le vendredi à 21 h 30 couvre la nuit jusqu'à 2 h ; le samedi soir reste exempté, et la
        // nuit de samedi à dimanche n'est pas couverte par la séance de la veille.
        e.journee = Etat.JourneeValidee(jours: ["2026-11-20"], faitA: a("2026-11-20", 21, 30))
        let apresSeance: [(Horodatage, GateState)] = [
            (a("2026-11-20", 22, 0), .alreadyDone),
            (a("2026-11-21", 0, 30), .alreadyDone),
            (a("2026-11-21", 21, 30), .exemptDay),
            (a("2026-11-22", 0, 30), .armed),
        ]
        for (quand, attendu) in apresSeance {
            let etat = Evaluation.evaluate(e, maintenant: quand)
            #expect(etat == attendu, "après la séance : \(quand.jour) à \(quand.minutes) min")
        }
    }

    // MARK: Les jours exemptés (§ 2.1.7)

    @Test func laListeDesJoursExemptes() {
        var e = veille()
        e.joursExemptes = ["2026-11-21", "2026-11-24"]
        let yomTov = Evaluation.isExempt(e, jour: "2026-11-24")
        #expect(yomTov)
        let mercredi = Evaluation.isExempt(e, jour: "2026-11-25")
        #expect(!mercredi)
        let samedi = Evaluation.isExempt(e, jour: "2026-11-21")
        #expect(samedi)
        // Dans la portée de la liste, la liste fait foi, même un samedi qu'elle ne nomme pas.
        let samediAbsent = Evaluation.isExempt(e, jour: "2026-11-28")
        #expect(!samediAbsent)
        // « Chabbat et Yom Tov » éteint : la liste ne compte plus, les pauses si.
        e.chabbat = false
        let sansChabbat = Evaluation.isExempt(e, jour: "2026-11-21")
        #expect(!sansChabbat)
        e.joursEnPause = ["2026-11-18"]
        let pause = Evaluation.isExempt(e, jour: "2026-11-18")
        #expect(pause)
        let jourDeLaPause = Evaluation.evaluate(e, maintenant: a("2026-11-18", 7, 0))
        #expect(jourDeLaPause == .exemptDay)
    }

    /// La liste couvre deux ans ; au-delà (l'app n'a pas été ouverte), le samedi reste exempté par le jour
    /// de la semaine, et seulement lui.
    @Test func leRepliDuSamediQuandLaListeEstPerimee() {
        var e = veille()
        e.exemptesJusquau = "2026-12-31"
        e.joursExemptes = ["2026-11-21", "2026-11-28", "2027-01-05"]
        let samedi = Evaluation.isExempt(e, jour: "2027-01-02")
        #expect(samedi)
        let lundiSuivant = Evaluation.isExempt(e, jour: "2027-01-04")
        #expect(!lundiSuivant)
        // Un jour de la liste hors de sa portée n'est plus cru : la liste est périmée.
        let horsPortee = Evaluation.isExempt(e, jour: "2027-01-05")
        #expect(!horsPortee)
        let barriere = Evaluation.evaluate(e, maintenant: a("2027-01-02", 7, 0))
        #expect(barriere == .exemptDay)
        // Avant le début de la liste (l'horloge a reculé), même repli.
        let avant = Evaluation.isExempt(e, jour: "2026-11-14")
        #expect(avant)
        // Sans liste du tout, le samedi est exempté.
        var neuf = veille()
        neuf.exemptesDepuis = ""
        neuf.exemptesJusquau = ""
        neuf.joursExemptes = []
        let sansListe = Evaluation.isExempt(neuf, jour: "2026-11-21")
        #expect(sansListe)
        let vendredi = Evaluation.isExempt(neuf, jour: "2026-11-20")
        #expect(!vendredi)
        // « Chabbat et Yom Tov » éteint : pas de repli.
        neuf.chabbat = false
        let eteint = Evaluation.isExempt(neuf, jour: "2026-11-21")
        #expect(!eteint)
        // Un jour illisible n'est pas un samedi.
        var illisible = veille()
        illisible.exemptesJusquau = ""
        let pasUnJour = Evaluation.isExempt(illisible, jour: "samedi")
        #expect(!pasUnJour)
    }

    // MARK: Les sous-règles de Store.kt

    @Test func inWindowAuxBornes() {
        let cas: [(Int, Int, Int, Bool)] = [
            (360, 660, 359, false), (360, 660, 360, true), (360, 660, 659, true), (360, 660, 660, false),
            (1260, 120, 1259, false), (1260, 120, 1260, true), (1260, 120, 1439, true), (1260, 120, 0, true),
            (1260, 120, 119, true), (1260, 120, 120, false), (600, 600, 600, false), (600, 600, 0, false),
            (0, 1439, 0, true), (0, 1439, 1438, true), (0, 1439, 1439, false),
        ]
        for (debut, fin, minutes, attendu) in cas {
            let dedans = Evaluation.inWindow(start: debut, end: fin, minutes: minutes)
            #expect(dedans == attendu, "\(debut)–\(fin) à \(minutes)")
        }
    }

    @Test func uneFenetreDeMoinsDeQuinzeMinutesEstRefusee() {
        let cas: [(Int, Int, Bool)] = [(360, 375, true), (360, 374, false), (1430, 5, true), (1431, 5, false),
                                       (600, 600, false), (1260, 120, true), (0, 1439, true)]
        for (debut, fin, attendu) in cas {
            let acceptee = Evaluation.fenetreAcceptable(start: debut, end: fin)
            #expect(acceptee == attendu, "\(debut)–\(fin)")
        }
        let nuit = Evaluation.dureeFenetre(start: 1260, end: 120)
        #expect(nuit == 300)
    }

    private struct Vecteurs: Decodable {
        struct Cas: Decodable {
            let debut: Int
            let fin: Int
            let maintenant: String
            let faitA: String?
            let faites: String
        }
        let ensembles: [[String]]
        let fenetre: [Cas]
    }

    /// « 2026-11-03T00:30:00 » : le jour et la minute ; l'instant ne sert pas à fenetreFaite.
    private func civil(_ texte: String) -> Horodatage {
        let heure = Int(texte.dropFirst(11).prefix(2)) ?? -1
        let minute = Int(texte.dropFirst(14).prefix(2)) ?? -1
        return Horodatage(millis: 0, jour: String(texte.prefix(10)), minutes: heure * 60 + minute)
    }

    /// Les cas de fenetreFaite de store.json (VoyageNuitTest et le balayage), pour chaque ensemble de jours faits.
    @Test func fenetreFaiteRejoueLesVecteursDeStore() throws {
        let ici = URL(fileURLWithPath: #filePath)
        let url = ici.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Vecteurs/store.json")
        let v = try JSONDecoder().decode(Vecteurs.self, from: Data(contentsOf: url))
        let nombre = v.fenetre.count
        #expect(nombre == 344)
        var comptes = 0
        for c in v.fenetre {
            let drapeaux = Array(c.faites)
            let nombreDeDrapeaux = drapeaux.count
            #expect(nombreDeDrapeaux == v.ensembles.count)
            for (rang, jours) in v.ensembles.enumerated() where rang < drapeaux.count {
                let faite = Evaluation.fenetreFaite(start: c.debut, end: c.fin, maintenant: civil(c.maintenant),
                                                    faitA: c.faitA.map(civil), jours: jours)
                let attendu = drapeaux[rang] == "1"
                #expect(faite == attendu, "\(c.debut)–\(c.fin) à \(c.maintenant), séance \(c.faitA ?? "-"), jours \(jours)")
                comptes += 1
            }
        }
        #expect(comptes == 344 * 5)
    }

    // MARK: Les jours et les instants

    @Test func lesJoursIso() {
        let zero = JoursIso.jourUnix("1970-01-01")
        #expect(zero == 0)
        let jeudi = JoursIso.jourDeSemaine("1970-01-01")
        #expect(jeudi == 5)
        let samedi = JoursIso.jourDeSemaine("2026-11-21")
        #expect(samedi == 7)
        let dimanche = JoursIso.jourDeSemaine("2026-11-22")
        #expect(dimanche == 1)
        let veille1970 = JoursIso.jourDeSemaine("1969-12-31")
        #expect(veille1970 == 4)
        let bissextile = JoursIso.jourUnix("2000-02-29")
        #expect(bissextile == 11_016)
        for faux in ["2026-02-29", "1900-02-29", "2026-13-01", "2026-00-10", "2026-1-01", "2026-01-1", "", "2026/01/01",
                     "2026-01-32", "２０26-01-01", "2026-01-01T00"] {
            let lu = JoursIso.jourUnix(faux)
            #expect(lu == nil, "\(faux)")
        }
        let nouvelAn = JoursIso.plus("2026-12-31", jours: 1)
        #expect(nouvelAn == "2027-01-01")
        let hier = JoursIso.plus("2027-03-01", jours: -1)
        #expect(hier == "2027-02-28")
        let illisible = JoursIso.plus("demain", jours: 1)
        #expect(illisible == nil)
        // L'aller-retour, de l'an 0 à l'an 9999.
        var ecarts = 0
        for n in stride(from: -719_528, through: 2_932_896, by: 991) {
            let iso = JoursIso.iso(jourUnix: n)
            if JoursIso.jourUnix(iso) != n { ecarts += 1 }
        }
        #expect(ecarts == 0)
        let premier = JoursIso.iso(jourUnix: -719_528)
        #expect(premier == "0000-01-01")
        let dernier = JoursIso.iso(jourUnix: 2_932_896)
        #expect(dernier == "9999-12-31")
    }

    @Test func unInstantVuDUnFuseau() throws {
        let paris = try #require(TimeZone(identifier: "Europe/Paris"))
        let hiver = Horodatage(millis: a("2026-11-20", 20, 0).millis, fuseau: paris)
        #expect(hiver.jour == "2026-11-20")
        #expect(hiver.minutes == 21 * 60)
        let ete = Horodatage(millis: a("2026-06-30", 22, 30).millis, fuseau: paris)
        #expect(ete.jour == "2026-07-01")
        #expect(ete.minutes == 30)
        let utc = try #require(TimeZone(identifier: "UTC"))
        for millis: Int64 in [-1, 0, 59_999, 60_000, 86_399_999, 86_400_000, 1_794_578_000_000] {
            let vu = Horodatage(millis: millis, fuseau: utc)
            let attendu = instant(millis)
            #expect(vu == attendu, "\(millis)")
        }
        let avant1970 = Horodatage(millis: -1, fuseau: utc)
        #expect(avant1970.jour == "1969-12-31")
        #expect(avant1970.minutes == 1439)
    }
}
