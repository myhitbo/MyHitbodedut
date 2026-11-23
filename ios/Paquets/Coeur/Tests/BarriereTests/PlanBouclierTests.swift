import Foundation
import Testing
@testable import Barriere

// Le bouclier de Temps d'écran (PORTAGE.md § 2.1.4, § 2.1.10) : les visages de BlockerView.kt (PROMPT,
// SESSION_RUNNING, PREVIEW), leurs textes et leurs boutons, et ce que GateService fait de chaque bouton
// (onStartSession, onAlreadyDone, onSnooze, onDismiss), ramenés aux deux boutons et au sous-menu d'un bouclier.

/// Un instant en temps universel.
private func a(_ jour: String, _ heure: Int, _ minute: Int) -> Horodatage {
    let n = Int64(JoursIso.jourUnix(jour) ?? 0)
    let minutes = heure * 60 + minute
    return Horodatage(millis: n * JoursIso.millisParJour + Int64(minutes) * 60_000, jour: jour, minutes: minutes)
}

/// Une barrière qui veille un lundi de 6 h à 11 h, ses textes en français comme l'app les dépose.
private func veille() -> Etat {
    var etat = Etat()
    etat.enabled = true
    etat.nombreDeJetons = 2
    etat.exemptesDepuis = "2026-11-16"
    etat.exemptesJusquau = "2028-11-15"
    var b = Etat.Bouclier()
    b.question = "Avez-vous fait votre hitbodedout ?"
    b.sousTitre = "Un moment à l’écart avant le reste."
    b.serie = "Série en cours : 12 jours"
    b.commencer = "Commencer maintenant, 15 min"
    b.autreReponse = "Autre réponse"
    b.dejaFaite = "Je l’ai faite sans le téléphone"
    b.plusTard = "Plus tard (15 min)"
    b.seanceTitre = "Hitbodedout en cours"
    b.seanceSousTitre = "Hitbodedout en cours. Le téléphone peut attendre."
    b.revenir = "Revenir à la hitbodedout"
    b.apercu = "APERÇU, AUCUN EFFET"
    b.fermerApercu = "Fermer l’aperçu"
    b.continuer = "Continuer"
    b.titresLeve = ["ALREADY_DONE": "Journée validée", "SNOOZED": "Report en cours"]
    b.detailsLeve = ["ALREADY_DONE": "Plus rien ne sera bloqué d’ici la prochaine plage horaire."]
    b.apparence.iconeAppel = "char_praise.webp"
    b.apparence.iconeSeance = "char_praying.webp"
    b.apparence.iconeJoie = "char_guitar.webp"
    etat.bouclier = b
    return etat
}

@Suite struct PlanBouclierTests {

    let lundi = "2026-11-16"

    /// Le visage suit GateRule.ecran : l'invite dans la veille, la séance pendant une hitbodedout ; l'essai passe devant
    /// tout ; un bouclier resté posé sans raison dit l'état du moment.
    @Test func leVisageSuitLaRegle() {
        let base = veille()
        let matin = a(lundi, 7, 0)
        #expect(PlanBouclier.face(base, evenements: [], maintenant: matin) == .invite)
        // Hors de la fenêtre : levée, « hors de la plage horaire ».
        #expect(PlanBouclier.face(base, evenements: [], maintenant: a(lundi, 12, 0)) == .levee(.outsideWindow))
        // Pendant une séance, à toute heure.
        var enSeance = base
        enSeance.seance = Etat.Seance(debut: a(lundi, 15, 0).millis, fin: a(lundi, 15, 20).millis, minutes: 20)
        #expect(PlanBouclier.face(enSeance, evenements: [], maintenant: a(lundi, 15, 10)) == .seance)
        // La séance finie app fermée : le bouclier « en cours » demandé après la fin dit la journée validée (§ 2.1.10).
        #expect(PlanBouclier.face(enSeance, evenements: [], maintenant: a(lundi, 15, 21)) == .levee(.alreadyDone))
        // L'essai, même hors de la fenêtre, même le mode éteint ; sa fin exclue.
        var essai = base
        essai.enabled = false
        essai.essai = Etat.Essai(debut: a(lundi, 12, 0).millis, fin: a(lundi, 12, 2).millis)
        #expect(PlanBouclier.face(essai, evenements: [], maintenant: a(lundi, 12, 1)) == .apercu)
        #expect(PlanBouclier.face(essai, evenements: [], maintenant: a(lundi, 12, 2)) == .levee(.disabled))
        // « Fermer l'aperçu » écrit dans la boîte : l'essai est fini pour les extensions avant que l'app l'ait lu.
        let fin = Evenement(quand: a(lundi, 12, 1), genre: .essai, detail: Etat.essaiFini)
        #expect(PlanBouclier.face(essai, evenements: [fin], maintenant: a(lundi, 12, 1)) == .levee(.disabled))
    }

    /// La boîte compte avant que l'app ne l'ait versée : « Je l'ai faite » et « Plus tard » lèvent le bouclier
    /// (GateService : addSession, snooze), et « Autre réponse » montre la deuxième page cinq minutes.
    @Test func laBoiteChangeLeVisage() {
        let base = veille()
        let deja = Evenement(quand: a(lundi, 7, 0), genre: .dejaFaite)
        #expect(PlanBouclier.face(base, evenements: [deja], maintenant: a(lundi, 7, 1)) == .levee(.alreadyDone))
        let plusTard = Evenement(quand: a(lundi, 7, 0), genre: .plusTard, detail: "5")
        #expect(PlanBouclier.face(base, evenements: [plusTard], maintenant: a(lundi, 7, 4)) == .levee(.snoozed))
        #expect(PlanBouclier.face(base, evenements: [plusTard], maintenant: a(lundi, 7, 5)) == .invite)
        let autre = Evenement(quand: a(lundi, 7, 0), genre: .autreReponse)
        #expect(PlanBouclier.face(base, evenements: [autre], maintenant: a(lundi, 7, 4)) == .autreReponse)
        #expect(PlanBouclier.face(base, evenements: [autre], maintenant: a(lundi, 7, 5)) == .invite)
        // Une horloge remise en arrière ne laisse pas la deuxième page pour toujours.
        #expect(PlanBouclier.face(base, evenements: [autre], maintenant: a(lundi, 6, 59)) == .invite)
    }

    /// Les textes de BlockerView, mode par mode.
    @Test func leContenuDeChaqueVisage() {
        let etat = veille()
        let invite = PlanBouclier.contenu(.invite, etat: etat)
        #expect(invite.icone == "char_praise.webp")
        #expect(invite.titre == "Avez-vous fait votre hitbodedout ?")
        #expect(invite.sousTitre == "Un moment à l’écart avant le reste.\nSérie en cours : 12 jours")
        #expect(invite.principal == "Commencer maintenant, 15 min")
        #expect(invite.secondaire == "Autre réponse")
        #expect(invite.sousMenu == ["Je l’ai faite sans le téléphone", "Plus tard (15 min)"])
        let page = PlanBouclier.contenu(.autreReponse, etat: etat)
        #expect(page.principal == "Je l’ai faite sans le téléphone")
        #expect(page.secondaire == "Plus tard (15 min)")
        #expect(page.sousMenu.isEmpty)
        let seance = PlanBouclier.contenu(.seance, etat: etat)
        #expect(seance.icone == "char_praying.webp")
        #expect(seance.titre == "Hitbodedout en cours")
        #expect(seance.sousTitre == "Hitbodedout en cours. Le téléphone peut attendre.")
        #expect(seance.principal == "Revenir à la hitbodedout")
        #expect(seance.secondaire == nil)
        let apercu = PlanBouclier.contenu(.apercu, etat: etat)
        #expect(apercu.sousTitre == "APERÇU, AUCUN EFFET\nUn moment à l’écart avant le reste.")
        #expect(apercu.principal == "Fermer l’aperçu")
        #expect(apercu.secondaire == nil)
        let levee = PlanBouclier.contenu(.levee(.alreadyDone), etat: etat)
        #expect(levee.icone == "char_guitar.webp")
        #expect(levee.titre == "Journée validée")
        #expect(levee.sousTitre == "Plus rien ne sera bloqué d’ici la prochaine plage horaire.")
        #expect(levee.principal == "Continuer")
        // Un état sans texte déposé : rien plutôt qu'une clé.
        #expect(PlanBouclier.contenu(.levee(.exemptDay), etat: etat).titre == "")
        // Sans série écrite, le sous-titre seul.
        var sansSerie = etat
        sansSerie.bouclier.serie = ""
        #expect(PlanBouclier.contenu(.invite, etat: sansSerie).sousTitre == "Un moment à l’écart avant le reste.")
    }

    /// Les boutons de BlockerView : Commencer (onStartSession), « Je l'ai faite » (onAlreadyDone), Plus tard (onSnooze),
    /// Revenir (onStartSession pendant la séance), Fermer l'aperçu (onDismiss) ; Continuer pour le bouclier levé.
    @Test func lesGestes() {
        #expect(PlanBouclier.geste(.invite, .principal) == .commencer)
        #expect(PlanBouclier.geste(.invite, .secondaire) == .autreReponse)
        #expect(PlanBouclier.geste(.invite, .sousMenu(0)) == .dejaFaite)
        #expect(PlanBouclier.geste(.invite, .sousMenu(1)) == .plusTard)
        #expect(PlanBouclier.geste(.invite, .sousMenu(2)) == .rien)
        #expect(PlanBouclier.geste(.autreReponse, .principal) == .dejaFaite)
        #expect(PlanBouclier.geste(.autreReponse, .secondaire) == .plusTard)
        #expect(PlanBouclier.geste(.seance, .principal) == .revenir)
        #expect(PlanBouclier.geste(.seance, .secondaire) == .rien)
        #expect(PlanBouclier.geste(.apercu, .principal) == .fermerApercu)
        #expect(PlanBouclier.geste(.apercu, .sousMenu(0)) == .rien)
        #expect(PlanBouclier.geste(.levee(.snoozed), .principal) == .continuer)
        #expect(PlanBouclier.geste(.levee(.snoozed), .secondaire) == .rien)
    }

    /// Les couleurs de l'apparence se relisent en composantes ; un texte mal formé ne se lit pas.
    @Test func lesCouleurs() {
        let rvb = ApparenceBouclier.rvb("#173C32")
        #expect(rvb?.rouge == 0x17)
        #expect(rvb?.vert == 0x3C)
        #expect(rvb?.bleu == 0x32)
        #expect(ApparenceBouclier.rvb("#dff5e8")?.bleu == 0xE8)
        #expect(ApparenceBouclier.rvb("173C32") == nil)
        #expect(ApparenceBouclier.rvb("#17X C32") == nil)
        #expect(ApparenceBouclier.rvb("#173C3") == nil)
    }
}
