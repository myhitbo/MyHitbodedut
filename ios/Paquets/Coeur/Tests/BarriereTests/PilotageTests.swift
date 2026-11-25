import Foundation
import Testing
@testable import Barriere

// Les règles des trois extensions (Pilotage.swift) : le visage du bouclier et ses boutons (BlockerView.kt :
// PROMPT, SESSION_RUNNING, PREVIEW), l'état vu par une extension (etat.json et la boîte), la consigne des
// magasins à chaque rendez-vous de la surveillance (PORTAGE.md § 2.1.4 à § 2.1.6, § 2.1.10) et le décor
// déposé par l'app. BlockerView n'a pas de test sur Android : les cas viennent du § 2.1 et de la recette R4.

/// Le temps universel : les instants des tests s'y lisent sans calcul de fuseau.
private let universel = TimeZone(secondsFromGMT: 0) ?? TimeZone.current

/// L'instant d'un jour à une heure, en temps universel.
private func millis(_ jour: String, _ heure: Int, _ minute: Int, secondes: Int64 = 0) -> Int64 {
    let n = Int64(JoursIso.jourUnix(jour) ?? 0)
    return n * JoursIso.millisParJour + Int64(heure * 60 + minute) * 60_000 + secondes * 1000
}

/// Une barrière allumée un lundi : trois jetons, fenêtre de 6 h à 11 h, les deux samedis suivants chômés.
private func allumee() -> Etat {
    var etat = Etat()
    etat.enabled = true
    etat.nombreDeJetons = 3
    etat.windowStart = 6 * 60
    etat.windowEnd = 11 * 60
    etat.snoozeMinutes = 15
    etat.exemptesDepuis = "2026-11-16"
    etat.exemptesJusquau = "2028-11-15"
    etat.joursExemptes = ["2026-11-21", "2026-11-28"]
    etat.bouclier.question = "Q"
    etat.bouclier.sousTitre = "S"
    etat.bouclier.serie = "Série"
    etat.bouclier.commencer = "Go"
    etat.bouclier.autreReponse = "Autre"
    etat.bouclier.dejaFaite = "Faite"
    etat.bouclier.plusTard = "Plus tard"
    etat.bouclier.seanceTitre = "En cours"
    etat.bouclier.seanceSousTitre = "Attendre"
    etat.bouclier.revenir = "Revenir"
    etat.bouclier.apercu = "APERÇU"
    etat.bouclier.fermerApercu = "Fermer"
    return etat
}

private func evenement(_ instant: Int64, _ genre: Evenement.Genre, _ detail: String = "") -> Evenement {
    Evenement(quand: Horodatage(millis: instant, fuseau: universel), genre: genre, detail: detail)
}

/// Un essai réel de deux minutes qui commence à `debut`.
private func essai(_ debut: Int64) -> DecorBouclier {
    var decor = DecorBouclier()
    decor.essai = DecorBouclier.Essai(debut: debut, fin: debut + PilotageBarriere.dureeEssai)
    return decor
}

@Suite struct PilotageTests {

    // MARK: Le visage

    @Test func leVisageSuitLEssaiPuisLaSeance() {
        let lundi = millis("2026-11-16", 7, 0)
        var etat = allumee()
        let invite = VisageBouclier.actuel(etat: etat, decor: nil, evenements: [], millis: lundi)
        #expect(invite == .invite)
        let sansEtat = VisageBouclier.actuel(etat: nil, decor: nil, evenements: [], millis: lundi)
        #expect(sansEtat == .invite)
        etat.seance = Etat.Seance(debut: lundi - 60_000, fin: lundi + 14 * 60_000, minutes: 15)
        let seance = VisageBouclier.actuel(etat: etat, decor: nil, evenements: [], millis: lundi)
        #expect(seance == .seance)
        // L'essai passe devant la séance, comme `previewing` d'Android.
        let apercu = VisageBouclier.actuel(etat: etat, decor: essai(lundi - 30_000), evenements: [], millis: lundi)
        #expect(apercu == .apercu)
    }

    @Test func lEssaiDureDeuxMinutesSaufSiOnLeFerme() {
        let debut = millis("2026-11-16", 14, 0)
        let decor = essai(debut)
        let avant = PilotageBarriere.essaiEnCours(decor: decor, evenements: [], millis: debut - 1)
        #expect(!avant)
        let pendant = PilotageBarriere.essaiEnCours(decor: decor, evenements: [], millis: debut + 119_999)
        #expect(pendant)
        let apres = PilotageBarriere.essaiEnCours(decor: decor, evenements: [], millis: debut + 120_000)
        #expect(!apres)
        let ferme = [evenement(debut + 30_000, .essai, PilotageBarriere.finEssai)]
        let leve = PilotageBarriere.essaiEnCours(decor: decor, evenements: ferme, millis: debut + 60_000)
        #expect(!leve)
        // La fin d'un essai précédent ne lève pas celui-ci.
        let ancien = [evenement(debut - 600_000, .essai, PilotageBarriere.finEssai)]
        let toujours = PilotageBarriere.essaiEnCours(decor: decor, evenements: ancien, millis: debut + 60_000)
        #expect(toujours)
        let sansDecor = PilotageBarriere.essaiEnCours(decor: nil, evenements: [], millis: debut)
        #expect(!sansDecor)
    }

    // MARK: Ce que porte chaque visage

    @Test func lesTroisVisagesDeBlockerView() {
        let textes = allumee().bouclier
        let invite = VisageBouclier.invite.contenu { textes[$0] }
        #expect(invite.pose == .appel)
        #expect(invite.badge == nil)
        #expect(invite.titre == "Q")
        #expect(invite.lignes == ["S", "Série"])
        #expect(invite.principal == "Go")
        #expect(invite.secondaire == "Autre")
        #expect(invite.sousMenu == ["Faite", "Plus tard"])
        #expect(invite.sousTitre == "S\nSérie")

        let seance = VisageBouclier.seance.contenu { textes[$0] }
        #expect(seance.pose == .priere)
        #expect(seance.titre == "En cours")
        #expect(seance.sousTitre == "Attendre")
        #expect(seance.principal == "Revenir")
        #expect(seance.secondaire == nil)
        #expect(seance.sousMenu.isEmpty)

        let apercu = VisageBouclier.apercu.contenu { textes[$0] }
        #expect(apercu.pose == .appel)
        #expect(apercu.badge == "APERÇU")
        #expect(apercu.titre == "Q")
        #expect(apercu.sousTitre == "APERÇU\nS\nSérie")
        #expect(apercu.principal == "Fermer")
        #expect(apercu.secondaire == nil)
    }

    /// Un texte vide (etat.json d'une autre version) ne laisse pas de ligne blanche dans le sous-titre.
    @Test func leSousTitreSauteLesLignesVides() {
        var textes = allumee().bouclier
        textes.serie = ""
        let invite = VisageBouclier.invite.contenu { textes[$0] }
        #expect(invite.sousTitre == "S")
    }

    @Test func chaqueBoutonSonAction() {
        #expect(VisageBouclier.invite.action(.principal) == .commencer)
        #expect(VisageBouclier.invite.action(.secondaire) == .aucune)
        #expect(VisageBouclier.invite.action(.sousMenu(0)) == .dejaFaite)
        #expect(VisageBouclier.invite.action(.sousMenu(1)) == .plusTard)
        #expect(VisageBouclier.invite.action(.sousMenu(2)) == .aucune)
        #expect(VisageBouclier.seance.action(.principal) == .revenir)
        #expect(VisageBouclier.seance.action(.secondaire) == .aucune)
        #expect(VisageBouclier.seance.action(.sousMenu(0)) == .aucune)
        #expect(VisageBouclier.apercu.action(.principal) == .fermerApercu)
        #expect(VisageBouclier.apercu.action(.sousMenu(1)) == .aucune)
    }

    // MARK: L'état vu par une extension

    @Test func laBoiteCompteAvantQueLAppNeLaVerse() {
        let etat = allumee()
        let maintenant = millis("2026-11-16", 7, 0)
        let fait = etat.vu(avec: [evenement(maintenant - 60_000, .dejaFaite)], millis: maintenant, fuseau: universel)
        #expect(fait.journee.jours == ["2026-11-16"])
        let etatFait = Evaluation.regle(fait, maintenant: Horodatage(millis: maintenant, fuseau: universel))
        #expect(etatFait == .alreadyDone)

        let reporte = etat.vu(avec: [evenement(maintenant, .plusTard, "5")], millis: maintenant, fuseau: universel)
        #expect(reporte.snoozedUntil == maintenant + 5 * 60_000)
        // Sans durée lisible, celle des réglages.
        let parDefaut = etat.vu(avec: [evenement(maintenant, .plusTard)], millis: maintenant, fuseau: universel)
        #expect(parDefaut.snoozedUntil == maintenant + 15 * 60_000)
        // Rejouer le même événement ne change rien.
        let deuxFois = reporte.vu(avec: [evenement(maintenant, .plusTard, "5")], millis: maintenant, fuseau: universel)
        #expect(deuxFois == reporte)
    }

    @Test func uneSeanceFinieValideLaJournee() {
        var etat = allumee()
        let debut = millis("2026-11-16", 6, 30)
        etat.seance = Etat.Seance(debut: debut, fin: debut + 15 * 60_000, minutes: 15)
        let pendant = etat.vu(avec: [], millis: debut + 60_000, fuseau: universel)
        #expect(pendant.seance != nil)
        #expect(pendant.journee.jours.isEmpty)
        let apres = etat.vu(avec: [], millis: debut + 15 * 60_000, fuseau: universel)
        #expect(apres.seance == nil)
        #expect(apres.journee.jours == ["2026-11-16"])
        #expect(apres.journee.faitA?.millis == debut + 15 * 60_000)
        // Une séance sans durée court jusqu'à ce que l'app la close.
        etat.seance = Etat.Seance(debut: debut, fin: 0, minutes: 0)
        let ouverte = etat.vu(avec: [], millis: debut + 5 * 3_600_000, fuseau: universel)
        #expect(ouverte.seance != nil)
    }

    // MARK: La consigne des magasins

    @Test func laBarriereVeilleDansLaFenetre() {
        let etat = allumee()
        let dedans = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: [],
                                               millis: millis("2026-11-16", 7, 0), fuseau: universel)
        #expect(dedans == ConsigneMagasins(barriere: true, seance: false, essai: false))
        let dehors = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: [],
                                               millis: millis("2026-11-16", 12, 0), fuseau: universel)
        #expect(dehors == ConsigneMagasins(barriere: false, seance: false, essai: false))
        // Samedi chômé : rien.
        let chabbat = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: [],
                                                millis: millis("2026-11-21", 7, 0), fuseau: universel)
        #expect(!chabbat.barriere)
        // Sans etat.json, rien ; mode éteint, rien.
        let sansEtat = PilotageBarriere.consigne(etat: nil, decor: nil, evenements: [],
                                                 millis: millis("2026-11-16", 7, 0), fuseau: universel)
        #expect(sansEtat == ConsigneMagasins(barriere: false, seance: false, essai: false))
        var eteinte = etat
        eteinte.enabled = false
        let eteint = PilotageBarriere.consigne(etat: eteinte, decor: nil, evenements: [],
                                               millis: millis("2026-11-16", 7, 0), fuseau: universel)
        #expect(!eteint.barriere)
    }

    /// Les rendez-vous comptent à leur borne, même reçus quelques secondes avant.
    @Test func lesBornesDeLaFenetre() {
        let etat = allumee()
        let tot = millis("2026-11-16", 5, 59, secondes: 58)
        let sansRendezVous = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: [], millis: tot,
                                                       fuseau: universel)
        #expect(!sansRendezVous.barriere)
        let debut = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: [], millis: tot, fuseau: universel,
                                              rendezVous: RendezVous(.fenetre, .debut))
        #expect(debut.barriere)
        // Le début de la fenêtre ne pose rien un jour déjà validé.
        let fait = [evenement(millis("2026-11-16", 5, 30), .dejaFaite)]
        let dejaFait = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: fait, millis: tot,
                                                 fuseau: universel, rendezVous: RendezVous(.fenetre, .debut))
        #expect(!dejaFait.barriere)
        let finTot = millis("2026-11-16", 10, 59, secondes: 59)
        let fin = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: [], millis: finTot, fuseau: universel,
                                            rendezVous: RendezVous(.fenetre, .fin))
        #expect(!fin.barriere)
    }

    /// § 2.1.6 : le report lève la barrière, l'activité `report` la remet à l'heure dite.
    @Test(arguments: [5, 15])
    func leReportPuisLeRetour(minutes: Int) {
        let etat = allumee()
        let appui = millis("2026-11-16", 7, 0)
        let boite = [evenement(appui, .plusTard, String(minutes))]
        let pendant = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: boite, millis: appui + 60_000,
                                                fuseau: universel)
        #expect(!pendant.barriere)
        let finDuReport = appui + Int64(minutes) * 60_000
        let retour = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: boite, millis: finDuReport,
                                               fuseau: universel, rendezVous: RendezVous(.report, .debut))
        #expect(retour.barriere)
        // Reçu deux secondes avant l'heure dite, le rendez-vous compte à son heure.
        let tot = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: boite, millis: finDuReport - 2000,
                                            fuseau: universel, rendezVous: RendezVous(.report, .debut))
        #expect(tot.barriere)
        #expect(PilotageBarriere.aArreter(RendezVous(.report, .debut)))
    }

    /// § 2.1.10 : pendant la séance, le magasin `seance` retient à toute heure ; à sa fin, tout se lève.
    @Test func laSeanceEtSaFin() {
        var etat = allumee()
        let debut = millis("2026-11-16", 13, 0)
        let fin = debut + 15 * 60_000
        etat.seance = Etat.Seance(debut: debut, fin: fin, minutes: 15)
        let pendant = PilotageBarriere.consigne(etat: etat, decor: nil, evenements: [], millis: debut + 60_000,
                                                fuseau: universel)
        #expect(pendant == ConsigneMagasins(barriere: false, seance: true, essai: false))
        // Dans la fenêtre aussi, la séance retient seule.
        var matin = allumee()
        let tot = millis("2026-11-16", 7, 0)
        matin.seance = Etat.Seance(debut: tot, fin: tot + 15 * 60_000, minutes: 15)
        let matinee = PilotageBarriere.consigne(etat: matin, decor: nil, evenements: [], millis: tot + 60_000,
                                                fuseau: universel)
        #expect(matinee == ConsigneMagasins(barriere: false, seance: true, essai: false))
        // L'activité `seance`, à la fin prévue, même reçue un peu tôt : la journée est validée, rien ne retient.
        let fini = PilotageBarriere.consigne(etat: matin, decor: nil, evenements: [], millis: tot + 15 * 60_000 - 1500,
                                             fuseau: universel, rendezVous: RendezVous(.seance, .debut))
        #expect(fini == ConsigneMagasins(barriere: false, seance: false, essai: false))
        #expect(PilotageBarriere.aArreter(RendezVous(.seance, .debut)))
    }

    @Test func lEssaiEtSaFin() {
        let etat = allumee()
        let debut = millis("2026-11-16", 14, 0)
        let decor = essai(debut)
        let pendant = PilotageBarriere.consigne(etat: etat, decor: decor, evenements: [], millis: debut + 1000,
                                                fuseau: universel)
        #expect(pendant == ConsigneMagasins(barriere: false, seance: false, essai: true))
        let fin = PilotageBarriere.consigne(etat: etat, decor: decor, evenements: [], millis: debut + 119_000,
                                            fuseau: universel, rendezVous: RendezVous(.essai, .debut))
        #expect(!fin.essai)
        // Sans etat.json, l'essai vaut quand même.
        let seul = PilotageBarriere.consigne(etat: nil, decor: decor, evenements: [], millis: debut + 1000,
                                             fuseau: universel)
        #expect(seul.essai)
    }

    @Test func lesActivitesPonctuellesSArretentADebut() {
        #expect(!PilotageBarriere.aArreter(RendezVous(.fenetre, .debut)))
        #expect(!PilotageBarriere.aArreter(RendezVous(.minuit, .debut)))
        #expect(!PilotageBarriere.aArreter(RendezVous(.report, .fin)))
        #expect(PilotageBarriere.aArreter(RendezVous(.essai, .debut)))
        let ponctuelles = ActiviteBarriere.allCases.filter { $0.ponctuelle }
        #expect(ponctuelles == [.report, .seance, .essai])
        #expect(RendezVous(.minuit, .fin).detail == "minuit:fin")
        let intervalle = PilotageBarriere.intervallePonctuel(debut: 1000)
        #expect(intervalle.debut == 1000)
        #expect(intervalle.fin == 1000 + 15 * 60_000)
        let soir = PilotageBarriere.heureMinute(21 * 60 + 30)
        #expect(soir.heure == 21)
        #expect(soir.minute == 30)
        let minuit = PilotageBarriere.heureMinute(24 * 60)
        #expect(minuit.heure == 0)
        #expect(minuit.minute == 0)
    }

    /// Les bornes que l'app et l'extension d'action donnent à `DeviceActivitySchedule`.
    @Test func lesComposantesDesBornes() {
        let quotidienne = PilotageBarriere.composantesQuotidiennes(21 * 60 + 5)
        #expect(quotidienne == DateComponents(hour: 21, minute: 5))
        let date = PilotageBarriere.composantesDate(millis("2026-11-16", 7, 5, secondes: 30), fuseau: universel)
        // Champ par champ : le calendrier peut y ajouter `isLeapMonth`.
        #expect(date.year == 2026)
        #expect(date.month == 11)
        #expect(date.day == 16)
        #expect(date.hour == 7)
        #expect(date.minute == 5)
        #expect(date.second == 30)
        // Le fuseau du téléphone décide de la date civile : 23 h 30 universelles sont déjà le lendemain à Jérusalem.
        let jerusalem = TimeZone(identifier: "Asia/Jerusalem") ?? universel
        let tard = PilotageBarriere.composantesDate(millis("2026-11-16", 23, 30), fuseau: jerusalem)
        #expect(tard.day == 17)
        #expect(tard.hour == 1)
    }

    // MARK: Le décor

    @Test func leDecorSeRelitEtToleresLesManques() throws {
        var decor = DecorBouclier()
        decor.fond = "#102030"
        decor.essai = DecorBouclier.Essai(debut: 5, fin: 120_005)
        let relu = DecorBouclier.lire(try decor.donnees())
        #expect(relu == decor)
        let partiel = DecorBouclier.lire(Data(#"{"bouton":"#ABCDEF","essai":{"debut":"x"},"autre":1}"#.utf8))
        #expect(partiel?.bouton == "#ABCDEF")
        #expect(partiel?.fond == DecorBouclier().fond)
        #expect(partiel?.essai == DecorBouclier.Essai(debut: 0, fin: 0))
        let rien = DecorBouclier.lire(Data("[]".utf8))
        #expect(rien == nil)
    }

    @Test func lesCouleursDuDecor() throws {
        // Les couleurs par défaut sont celles de la palette d'origine.
        let defaut = DecorBouclier()
        #expect(defaut.fond == "#173C32")
        #expect(defaut.bouton == "#16775A")
        let vert = try #require(DecorBouclier.composantes("#16775a"))
        #expect(vert.rouge == Double(0x16) / 255)
        #expect(vert.vert == Double(0x77) / 255)
        #expect(vert.bleu == Double(0x5A) / 255)
        // Un tuple n'est pas Equatable : chaque refus se compte.
        var refusees = 0
        for ecriture in ["16775A", "#16775", "#16775G", "#FF16775A", ""] where DecorBouclier.composantes(ecriture) == nil {
            refusees += 1
        }
        #expect(refusees == 5)
    }
}
