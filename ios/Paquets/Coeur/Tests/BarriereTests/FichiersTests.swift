import Foundation
import Testing
@testable import Barriere

// Le dossier barriere/ du conteneur partagé (PORTAGE.md § 3.2, § 2.1.8) : l'instantané écrit d'un coup et seulement
// s'il change, la boîte où l'on ajoute et dont l'app retire ce qu'elle a lu sans perdre ce qui est arrivé entre-temps,
// le journal de la barrière qui garde les cinquante derniers événements, l'instantané vu avec la boîte, la sélection et
// son appareil.

private func moment(_ millis: Int64, _ jour: String = "2026-11-16", _ minutes: Int = 420) -> Horodatage {
    Horodatage(millis: millis, jour: jour, minutes: minutes)
}

/// Un dossier temporaire neuf.
private func dossierNeuf() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("barriere-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite struct FichiersTests {

    @Test func lInstantaneNEstReecritQueSIlChange() throws {
        let racine = try dossierNeuf()
        defer { try? FileManager.default.removeItem(at: racine) }
        let fichiers = FichiersBarriere(racine: racine)
        #expect(fichiers.etat.path.hasSuffix("/barriere/etat.json"))
        #expect(fichiers.lireEtat() == nil)
        var etat = Etat()
        etat.enabled = true
        etat.essai = Etat.Essai(debut: 1, fin: 2)
        let premiere = try fichiers.ecrire(etat)
        #expect(premiere)
        let seconde = try fichiers.ecrire(etat)
        #expect(!seconde)
        #expect(fichiers.lireEtat() == etat)
    }

    /// L'app lit la boîte, verse, puis retire ce qu'elle a lu : une ligne ajoutée entre-temps par une extension reste.
    @Test func laBoiteGardeCeQuiArriveEntreDeuxLectures() throws {
        let racine = try dossierNeuf()
        defer { try? FileManager.default.removeItem(at: racine) }
        let fichiers = FichiersBarriere(racine: racine)
        #expect(fichiers.lireBoite().evenements.isEmpty)
        try fichiers.ajouter(Evenement(quand: moment(1), genre: .reveil, detail: "fenetre"))
        try fichiers.ajouter(Evenement(quand: moment(2), genre: .plusTard, detail: "15"))
        let lu = fichiers.lireBoite()
        #expect(lu.evenements.map(\.genre) == ["reveil", "plus_tard"])
        try fichiers.ajouter(Evenement(quand: moment(3), genre: .dejaFaite))
        try fichiers.retirerLu(octets: lu.octets)
        #expect(fichiers.lireBoite().evenements.map(\.genre) == ["deja_faite"])
        // Une boîte vidée par ailleurs entre-temps ne garde rien.
        #expect(Boite.reste(Data([1, 2]), apres: 5).isEmpty)
        #expect(Boite.reste(Data([1, 2, 3]), apres: 1) == Data([2, 3]))
    }

    /// Le journal de la barrière : les cinquante derniers, dans l'ordre des instants, la boîte non versée comprise.
    @Test func leJournalDeLaBarriere() throws {
        let racine = try dossierNeuf()
        defer { try? FileManager.default.removeItem(at: racine) }
        let fichiers = FichiersBarriere(racine: racine)
        var neufs: [Evenement] = []
        for n in 0..<45 {
            neufs.append(Evenement(quand: moment(Int64(n * 10)), genre: .reveil, detail: "minuit"))
        }
        try fichiers.journaliser(neufs)
        try fichiers.journaliser([Evenement(quand: moment(5), genre: .armee, detail: "app")])
        try fichiers.journaliser((45..<52).map { Evenement(quand: moment(Int64($0 * 10)), genre: .levee, detail: "app") })
        let journal = fichiers.lireHistorique()
        #expect(journal.count == 50)
        #expect(journal.first?.quand.millis == 20)
        #expect(journal.last?.quand.millis == 510)
        let tries = journal.map(\.quand.millis)
        #expect(tries == tries.sorted())
        try fichiers.ajouter(Evenement(quand: moment(600), genre: .dejaFaite))
        #expect(fichiers.journal().last?.genre == "deja_faite")
        #expect(fichiers.journal().count == 50)
    }

    /// Le dernier signe de vie : un réveil de la surveillance, ou l'inscription de ses heures par l'app.
    @Test func leDernierSigneDeVie() {
        let evenements = [Evenement(quand: moment(10), genre: .reveil, detail: "fenetre"),
                          Evenement(quand: moment(30), genre: .inscrite),
                          Evenement(quand: moment(50), genre: .armee, detail: "surveillance"),
                          Evenement(quand: moment(20), genre: .reveil, detail: "minuit")]
        #expect(Boite.dernierSigneDeVie(evenements) == 30)
        #expect(Boite.dernierReveil(evenements) == 20)
        #expect(Boite.dernierSigneDeVie([]) == nil)
    }

    /// L'instantané vu avec la boîte : « Plus tard » porte le report pour la durée écrite, ou celle des réglages ; le
    /// report le plus lointain l'emporte ; la fin de l'essai le retire, pas une fin plus ancienne que lui.
    @Test func lInstantaneVuAvecLaBoite() {
        var etat = Etat()
        etat.snoozeMinutes = 10
        let vu = etat.avec([Evenement(quand: moment(60_000), genre: .plusTard, detail: "5")])
        #expect(vu.snoozedUntil == 360_000)
        let sansDetail = etat.avec([Evenement(quand: moment(60_000), genre: .plusTard)])
        #expect(sansDetail.snoozedUntil == 660_000)
        etat.snoozedUntil = 900_000
        #expect(etat.avec([Evenement(quand: moment(60_000), genre: .plusTard, detail: "5")]).snoozedUntil == 900_000)
        etat.essai = Etat.Essai(debut: 1_000, fin: 121_000)
        #expect(etat.essaiEnCours(millis: 1_000))
        #expect(!etat.essaiEnCours(millis: 121_000))
        #expect(etat.avec([Evenement(quand: moment(500), genre: .essai, detail: Etat.essaiFini)]).essai != nil)
        #expect(etat.avec([Evenement(quand: moment(2_000), genre: .essai, detail: Etat.essaiCommence)]).essai != nil)
        #expect(etat.avec([Evenement(quand: moment(2_000), genre: .essai, detail: Etat.essaiFini)]).essai == nil)
        let deja = etat.avec([Evenement(quand: moment(3_000), genre: .dejaFaite)])
        #expect(deja.journee.jours == ["2026-11-16"])
    }

    /// La sélection se relit avec son appareil ; venue d'un autre iPhone, elle est à refaire.
    @Test func laSelectionEtSonAppareil() throws {
        let racine = try dossierNeuf()
        defer { try? FileManager.default.removeItem(at: racine) }
        let fichiers = FichiersBarriere(racine: racine)
        #expect(fichiers.lireSelection() == nil)
        let selection = SelectionEnregistree(jetons: Data("{}".utf8), appareil: "A", applications: 2, categories: 1, sites: 1)
        try fichiers.ecrire(selection)
        #expect(fichiers.lireSelection() == selection)
        #expect(selection.nombreDeJetons == 4)
        #expect(selection.valable(sur: "A"))
        #expect(!selection.valable(sur: "B"))
        #expect(selection.valable(sur: ""))
        #expect(SelectionEnregistree(jetons: Data(), appareil: "", applications: 0, categories: 0, sites: 0).valable(sur: "B"))
    }

    /// Les champs neufs de l'instantané : l'essai, les textes du bouclier levé et l'apparence, relus à l'identique ;
    /// absents (un instantané d'une version précédente), leurs valeurs par défaut.
    @Test func lesChampsNeufsDeLInstantane() throws {
        var etat = Etat()
        etat.essai = Etat.Essai(debut: 5, fin: 125_005)
        etat.bouclier.continuer = "Continuer"
        etat.bouclier.notificationRevenir = "Touchez pour revenir"
        etat.bouclier.titresLeve = ["ALREADY_DONE": "Journée validée"]
        etat.bouclier.detailsLeve = ["ALREADY_DONE": "Plus rien ne sera bloqué."]
        etat.bouclier.apparence.fond = "#000000"
        etat.bouclier.apparence.iconeAppel = "char_praise.webp"
        let texte = String(decoding: try etat.donnees(), as: UTF8.self)
        for cle in ["\"essai\":{\"debut\":5,\"fin\":125005}", "\"titres_leve\":{\"ALREADY_DONE\":", "\"icone_appel\":\"char_praise.webp\"",
                    "\"notification_revenir\":"] {
            #expect(texte.contains(cle), "\(cle)")
        }
        #expect(Etat.lire(try etat.donnees()) == etat)
        let ancien = try #require(Etat.lire(Data(#"{"bouclier":{"question":"Q","apparence":{"fond":3}}}"#.utf8)))
        #expect(ancien.essai == nil)
        #expect(ancien.bouclier.titresLeve.isEmpty)
        #expect(ancien.bouclier.apparence == ApparenceBouclier())
    }
}
