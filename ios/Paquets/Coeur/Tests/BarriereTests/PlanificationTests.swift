import Foundation
import Testing
@testable import Barriere

// Les rendez-vous et les magasins qui remplacent la boucle de GateService (PORTAGE.md § 2.1.5, § 2.1.6, § 2.1.10) :
// cinq activités au plus, des intervalles de quinze minutes au moins, un rendez-vous unique planifié à la minute
// pleine qui suit (le report de 5 et de 15 minutes du critère de la tâche 12), la fenêtre de nuit, et le bouclier
// désaccordé du § 2.1.8.

/// Un instant en temps universel.
private func a(_ jour: String, _ heure: Int, _ minute: Int, secondes: Int64 = 0) -> Horodatage {
    let n = Int64(JoursIso.jourUnix(jour) ?? 0)
    let minutes = heure * 60 + minute
    return Horodatage(millis: n * JoursIso.millisParJour + Int64(minutes) * 60_000 + secondes * 1000, jour: jour,
                      minutes: minutes)
}

/// Le même instant vu de Jérusalem en hiver (UTC+2) : le jour et la minute locaux, le même instant Unix.
private func aJerusalem(_ jour: String, _ heure: Int, _ minute: Int) -> Horodatage {
    let utc = a(jour, heure, minute)
    return Horodatage(millis: utc.millis - 2 * 3_600_000, jour: jour, minutes: heure * 60 + minute)
}

private func veille() -> Etat {
    var etat = Etat()
    etat.enabled = true
    etat.nombreDeJetons = 3
    etat.exemptesDepuis = "2026-11-16"
    etat.exemptesJusquau = "2028-11-15"
    etat.joursExemptes = ["2026-11-21"]
    return etat
}

@Suite struct PlanificationTests {

    let lundi = "2026-11-16"

    /// Le mode éteint ou sans application ne surveille rien ; allumé : la fenêtre et minuit, chaque jour.
    @Test func lesActivitesDeChaqueJour() {
        var eteint = veille()
        eteint.enabled = false
        #expect(Planification.plan(eteint, maintenant: a(lundi, 7, 0)).isEmpty)
        var vide = veille()
        vide.nombreDeJetons = 0
        #expect(Planification.plan(vide, maintenant: a(lundi, 7, 0)).isEmpty)
        let plan = Planification.plan(veille(), maintenant: a(lundi, 7, 0))
        #expect(Set(plan.keys) == [.fenetre, .minuit])
        #expect(plan[.fenetre] == Creneau(debut: Repere(heure: 6, minute: 0), fin: Repere(heure: 11, minute: 0), repete: true))
        #expect(plan[.minuit] == Creneau(debut: Repere(heure: 0, minute: 0), fin: Repere(heure: 23, minute: 59), repete: true))
        // Jamais plus de cinq activités, bien sous la limite de vingt.
        #expect(Activite.allCases.count == 5)
    }

    /// La fenêtre de nuit passe minuit tel quel (le système calcule la fin à la première 02:00 qui suit 21:00) ; une
    /// fenêtre trop courte est allongée jusqu'au quart d'heure du système.
    @Test func laFenetreDeNuitEtLaFenetreCourte() {
        var nuit = veille()
        nuit.windowStart = 21 * 60
        nuit.windowEnd = 2 * 60
        let plan = Planification.plan(nuit, maintenant: a(lundi, 20, 0))
        #expect(plan[.fenetre] == Creneau(debut: Repere(heure: 21, minute: 0), fin: Repere(heure: 2, minute: 0), repete: true))
        var courte = veille()
        courte.windowStart = 23 * 60 + 50
        courte.windowEnd = 23 * 60 + 55
        let allongee = Planification.plan(courte, maintenant: a(lundi, 20, 0))[.fenetre]
        #expect(allongee == Creneau(debut: Repere(heure: 23, minute: 50), fin: Repere(heure: 0, minute: 5), repete: true))
        #expect(Evaluation.fenetreAcceptable(start: 23 * 60 + 50, end: 23 * 60 + 55) == false)
        #expect(Evaluation.fenetreAcceptable(start: 23 * 60 + 50, end: 5) == true)
    }

    /// Le report de 5 et de 15 minutes : un rendez-vous unique qui commence à la fin du report, à la minute pleine qui
    /// suit, et dure le quart d'heure minimal ; au-delà, il n'est plus demandé.
    @Test func leRendezVousDuReport() {
        var etat = veille()
        for minutes in [5, 15] {
            etat.snoozeMinutes = minutes
            let appui = a(lundi, 6, 40, secondes: 30)
            Evaluation.reporter(&etat, millis: appui.millis)
            let plan = Planification.plan(etat, maintenant: appui)
            let fin = 40 + minutes + 1
            #expect(plan[.report] == Creneau(debut: Repere(jour: lundi, heure: 6, minute: fin),
                                             fin: Repere(jour: lundi, heure: 7, minute: fin + 15 - 60), repete: false),
                    "report de \(minutes) min")
            // À la minute de reprise, la règle réarme : le report est fini.
            let reprise = a(lundi, 6, fin)
            #expect(Evaluation.regle(etat, maintenant: reprise) == .armed)
            #expect(Planification.plan(etat, maintenant: reprise)[.report] == nil)
        }
        // Un report qui finit sur une minute pleine commence à cette minute.
        etat.snoozedUntil = a(lundi, 8, 0).millis
        #expect(Planification.plan(etat, maintenant: a(lundi, 7, 45))[.report]?.debut == Repere(jour: lundi, heure: 8, minute: 0))
    }

    /// Les rendez-vous uniques se lisent dans le fuseau du téléphone, et passent minuit avec leur jour.
    @Test func lesRendezVousUniquesPortentLeurJour() {
        var etat = veille()
        etat.snoozedUntil = aJerusalem(lundi, 23, 55).millis
        let plan = Planification.plan(etat, maintenant: aJerusalem(lundi, 23, 50))
        #expect(plan[.report] == Creneau(debut: Repere(jour: lundi, heure: 23, minute: 55),
                                         fin: Repere(jour: "2026-11-17", heure: 0, minute: 10), repete: false))
    }

    /// La séance minutée réveille la surveillance à sa fin ; l'essai a son rendez-vous, même le mode éteint.
    @Test func laSeanceEtLEssai() {
        var etat = veille()
        etat.seance = Etat.Seance(debut: a(lundi, 15, 0).millis, fin: a(lundi, 15, 20).millis, minutes: 20)
        let plan = Planification.plan(etat, maintenant: a(lundi, 15, 5))
        #expect(plan[.seance] == Creneau(debut: Repere(jour: lundi, heure: 15, minute: 20),
                                         fin: Repere(jour: lundi, heure: 15, minute: 35), repete: false))
        #expect(Planification.plan(etat, maintenant: a(lundi, 15, 20))[.seance] == nil)
        var essai = veille()
        essai.enabled = false
        essai.essai = Etat.Essai(debut: a(lundi, 12, 0).millis, fin: a(lundi, 12, 2).millis)
        #expect(Planification.plan(essai, maintenant: a(lundi, 12, 1)) ==
                [.essai: Creneau(debut: Repere(jour: lundi, heure: 12, minute: 2), fin: Repere(jour: lundi, heure: 12, minute: 17),
                                 repete: false)])
        #expect(Planification.plan(essai, maintenant: a(lundi, 12, 2)).isEmpty)
    }

    /// Les magasins suivent GateRule.ecran et l'essai.
    @Test func lesMagasinsVoulus() {
        let etat = veille()
        #expect(Planification.voulus(etat, maintenant: a(lundi, 7, 0)) == MagasinsVoulus(barriere: true, essai: false))
        #expect(Planification.voulus(etat, maintenant: a(lundi, 12, 0)) == MagasinsVoulus(barriere: false, essai: false))
        // Samedi : le Chabbat, aucun bouclier.
        #expect(Planification.voulus(etat, maintenant: a("2026-11-21", 7, 0)).barriere == false)
        var seance = etat
        seance.seance = Etat.Seance(debut: a(lundi, 15, 0).millis, fin: 0, minutes: 0)
        #expect(Planification.voulus(seance, maintenant: a(lundi, 15, 1)).barriere)
        var essai = etat
        essai.essai = Etat.Essai(debut: a(lundi, 12, 0).millis, fin: a(lundi, 12, 2).millis)
        #expect(Planification.voulus(essai, maintenant: a(lundi, 12, 1)) == MagasinsVoulus(barriere: false, essai: true))
    }

    /// Le bouclier désaccordé : ce que les extensions auraient dû faire d'après l'instantané précédent et la boîte.
    @Test func leBouclierDesaccorde() {
        let ancien = veille()
        let matin = a(lundi, 7, 0)
        // La surveillance n'a pas armé au début de la fenêtre : désaccord.
        #expect(Planification.desaccord(ancien: ancien, evenements: [], maintenant: matin, barriereActif: false))
        #expect(!Planification.desaccord(ancien: ancien, evenements: [], maintenant: matin, barriereActif: true))
        // « Plus tard » a levé le bouclier : l'action l'a écrit, aucun désaccord.
        let plusTard = Evenement(quand: a(lundi, 6, 55), genre: .plusTard, detail: "15")
        #expect(!Planification.desaccord(ancien: ancien, evenements: [plusTard], maintenant: matin, barriereActif: false))
        // Hors de la fenêtre, un bouclier encore posé : désaccord.
        #expect(Planification.desaccord(ancien: ancien, evenements: [], maintenant: a(lundi, 12, 0), barriereActif: true))
        // Premier lancement : rien à reprocher.
        #expect(!Planification.desaccord(ancien: nil, evenements: [], maintenant: matin, barriereActif: false))
    }

    /// Ne redémarrer que ce qui a changé : une activité inchangée n'est pas touchée.
    @Test func lesChangements() {
        let fenetre = Creneau(debut: Repere(heure: 6, minute: 0), fin: Repere(heure: 11, minute: 0), repete: true)
        let minuit = Creneau(debut: Repere(heure: 0, minute: 0), fin: Repere(heure: 23, minute: 59), repete: true)
        let report = Creneau(debut: Repere(jour: "2026-11-16", heure: 6, minute: 56),
                             fin: Repere(jour: "2026-11-16", heure: 7, minute: 11), repete: false)
        let autreFenetre = Creneau(debut: Repere(heure: 7, minute: 0), fin: Repere(heure: 11, minute: 0), repete: true)
        let rien = Planification.changements(voulu: [.fenetre: fenetre, .minuit: minuit], actuel: [.minuit: minuit, .fenetre: fenetre])
        #expect(rien.arreter.isEmpty && rien.demarrer.isEmpty)
        let c = Planification.changements(voulu: [.fenetre: autreFenetre, .minuit: minuit, .report: report],
                                          actuel: [.fenetre: fenetre, .minuit: minuit, .essai: report])
        #expect(c.arreter == [.fenetre, .essai])
        #expect(c.demarrer == [.fenetre, .report])
    }
}
