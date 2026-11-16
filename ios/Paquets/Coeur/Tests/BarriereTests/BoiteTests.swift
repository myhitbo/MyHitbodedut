import Foundation
import Testing
@testable import Barriere

// barriere/boite.jsonl et barriere/etat.json (PORTAGE.md § 3.2) : sans équivalent sur Android, les cas
// viennent du § 2.1 (lecture tolérante, cinquante derniers événements, ajout seul, décodage tolérant).

private func moment(_ millis: Int64, _ jour: String = "2026-11-16", _ minutes: Int = 420) -> Horodatage {
    Horodatage(millis: millis, jour: jour, minutes: minutes)
}

@Suite struct BoiteTests {

    @Test func uneLigneSeRelit() {
        let evenement = Evenement(quand: moment(1_794_810_000_000), genre: .plusTard, detail: "15")
        let ligne = Boite.ligne(evenement)
        let fin = ligne.last
        #expect(fin == 0x0A)
        let texte = String(decoding: ligne, as: UTF8.self)
        #expect(texte == #"{"detail":"15","genre":"plus_tard","quand":{"jour":"2026-11-16","millis":1794810000000,"minutes":420}}"# + "\n")
        let relus = Boite.lire(ligne)
        #expect(relus == [evenement])
        let genre = relus.first?.genreConnu
        #expect(genre == .plusTard)
    }

    /// Une ligne vide, tronquée (un ajout interrompu) ou illisible est sautée ; les autres restent, dans
    /// l'ordre ; un genre inconnu se lit, un détail absent vaut vide, un retour chariot est admis.
    @Test func laLectureEstTolerante() {
        let texte = """
            {"genre":"deja_faite","quand":{"jour":"2026-11-16","millis":1,"minutes":5}}

            pas du JSON
            {"genre":"reveil","detail":"fenetre","quand":{"jour":"2026-11-16","millis":2,"minutes":6}}\r
            {"genre":"inconnu","quand":{"jour":"2026-11-16","millis":3,"minutes":7},"autre":true}
            {"genre":"plus_tard","quand":{"jour":"2026-11-16","millis":4}}
            {"genre":"armee"}
            [1, 2]
            {"genre":"levee","quand":{"jour":"2026-11-16","millis":5,"minutes":8}
            """
        let evenements = Boite.lire(Data(texte.utf8))
        var genres: [String] = []
        var details: [String] = []
        for evenement in evenements {
            genres.append(evenement.genre)
            details.append(evenement.detail)
        }
        #expect(genres == ["deja_faite", "reveil", "inconnu"])
        #expect(details == ["", "fenetre", ""])
        let inconnu = evenements.last?.genreConnu
        #expect(inconnu == nil)
        let rien = Boite.lire(Data())
        #expect(rien.isEmpty)
    }

    @Test func lesCinquanteDerniers() {
        var donnees = Data()
        for n in 0..<60 {
            donnees.append(Boite.ligne(Evenement(quand: moment(Int64(n)), genre: .reveil, detail: "minuit")))
        }
        let evenements = Boite.lire(donnees)
        let nombre = evenements.count
        #expect(nombre == Boite.maximum)
        let premier = evenements.first?.quand.millis
        #expect(premier == 10)
        let dernier = evenements.last?.quand.millis
        #expect(dernier == 59)
        let tous = Boite.lire(donnees, garder: 100)
        let nombreTotal = tous.count
        #expect(nombreTotal == 60)
    }

    @Test func ajouterPuisVider() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("boite-\(UUID().uuidString).jsonl")
        defer { _ = try? FileManager.default.removeItem(at: url) }
        let premier = Evenement(quand: moment(1), genre: .dejaFaite)
        let second = Evenement(quand: moment(2), genre: "reveil", detail: "fenetre")
        try Boite.ajouter(premier, a: url)
        try Boite.ajouter(second, a: url)
        let lus = try Boite.lire(Data(contentsOf: url))
        #expect(lus == [premier, second])
        try Boite.vider(url)
        let vide = try Boite.lire(Data(contentsOf: url))
        #expect(vide.isEmpty)
        try Boite.ajouter(premier, a: url)
        let apres = try Boite.lire(Data(contentsOf: url))
        #expect(apres == [premier])
    }

    @Test func leDernierReveil() {
        let evenements = [
            Evenement(quand: moment(30), genre: .reveil, detail: "fenetre"),
            Evenement(quand: moment(50), genre: .dejaFaite),
            Evenement(quand: moment(40), genre: .reveil, detail: "minuit"),
        ]
        let dernier = Boite.dernierReveil(evenements)
        #expect(dernier == 40)
        let aucun = Boite.dernierReveil([Evenement(quand: moment(1), genre: .plusTard)])
        #expect(aucun == nil)
    }

    /// « Je l'ai déjà faite » dans la boîte vaut une séance close : la nuit est validée même si l'app n'a
    /// pas encore versé l'événement au journal.
    @Test func laBoiteValideLaJournee() {
        var etat = Etat()
        etat.enabled = true
        etat.nombreDeJetons = 1
        etat.windowStart = 21 * 60
        etat.windowEnd = 2 * 60
        let soir = Horodatage(millis: 1_000, jour: "2026-11-16", minutes: 21 * 60 + 40)
        let nuit = Horodatage(millis: 2_000, jour: "2026-11-17", minutes: 30)
        let avant = Evaluation.evaluate(etat, maintenant: nuit)
        #expect(avant == .armed)
        let boite = [Evenement(quand: soir, genre: .dejaFaite), Evenement(quand: moment(500), genre: .reveil)]
        etat.journee = etat.journee.avec(boite)
        #expect(etat.journee.jours == ["2026-11-16"])
        #expect(etat.journee.faitA == soir)
        let apres = Evaluation.evaluate(etat, maintenant: nuit)
        #expect(apres == .alreadyDone)
        // Un « déjà faite » plus ancien ne recule pas l'instant de la séance.
        let ancien = Horodatage(millis: 10, jour: "2026-11-15", minutes: 600)
        let encore = etat.journee.avec([Evenement(quand: ancien, genre: .dejaFaite)])
        #expect(encore.faitA == soir)
        #expect(encore.jours == ["2026-11-15", "2026-11-16"])
    }
}

@Suite struct EtatTests {

    private func complet() -> Etat {
        var etat = Etat()
        etat.ecritA = 1_794_810_000_000
        etat.enabled = true
        etat.windowStart = 21 * 60
        etat.windowEnd = 2 * 60
        etat.snoozeMinutes = 5
        etat.snoozedUntil = 1_794_810_300_000
        etat.chabbat = true
        etat.joursExemptes = ["2026-11-21", "2026-11-28"]
        etat.exemptesDepuis = "2026-11-16"
        etat.exemptesJusquau = "2028-11-15"
        etat.joursEnPause = ["2026-12-01"]
        etat.journee = Etat.JourneeValidee(jours: ["2026-11-16"], faitA: moment(1_794_800_000_000, "2026-11-16", 1290))
        etat.seance = Etat.Seance(debut: 1_794_809_000_000, fin: 0, minutes: 0)
        var bouclier = Etat.Bouclier()
        bouclier.question = "Avez-vous fait votre hitbodedout ?"
        bouclier.serie = "Série en cours : 12 jours"
        bouclier.notificationCommencer = "Touchez pour commencer votre hitbodedout"
        etat.bouclier = bouclier
        etat.nombreDeJetons = 51
        return etat
    }

    @Test func allerRetour() throws {
        let etat = complet()
        let donnees = try etat.donnees()
        let relu = try #require(Etat.lire(donnees))
        #expect(relu == etat)
        let encore = try relu.donnees()
        #expect(encore == donnees)
        let texte = String(decoding: donnees, as: UTF8.self)
        for cle in ["\"window_start\":1260", "\"jours_exemptes\":[\"2026-11-21\",\"2026-11-28\"]", "\"nombre_de_jetons\":51",
                    "\"fait_a\":{", "\"notification_commencer\":", "\"exemptes_jusquau\":\"2028-11-15\""] {
            let present = texte.contains(cle)
            #expect(present, "\(cle)")
        }
        // Sans séance, la clé est absente.
        var sansSeance = etat
        sansSeance.seance = nil
        let court = try String(decoding: sansSeance.donnees(), as: UTF8.self)
        let seance = court.contains("\"seance\"")
        #expect(!seance)
    }

    /// Une clé absente ou d'un autre type prend sa valeur par défaut, comme `optInt` d'Android ; une clé
    /// inconnue est ignorée ; ce qui n'est pas un objet JSON ne se lit pas.
    @Test func laLectureEstTolerante() throws {
        let vide = try #require(Etat.lire(Data("{}".utf8)))
        #expect(vide == Etat())
        #expect(vide.windowStart == 360)
        #expect(vide.windowEnd == 660)
        #expect(vide.snoozeMinutes == 15)
        #expect(vide.chabbat)
        #expect(vide.version == Etat.versionActuelle)
        let bizarre = Data(#"""
            {"enabled":"oui","window_start":1260,"seance":{"debut":5},"bouclier":{"question":"Q","serie":3},
             "inconnue":[1,2],"journee":{"jours":["2026-11-16"],"fait_a":{"millis":1}},"nombre_de_jetons":"trois"}
            """#.utf8)
        let e = try #require(Etat.lire(bizarre))
        #expect(!e.enabled)
        #expect(e.windowStart == 1260)
        let debut = e.seance?.debut
        #expect(debut == 5)
        let fin = e.seance?.fin
        #expect(fin == 0)
        #expect(e.bouclier.question == "Q")
        #expect(e.bouclier.serie == "")
        #expect(e.journee.jours == ["2026-11-16"])
        #expect(e.journee.faitA == nil)
        #expect(e.nombreDeJetons == 0)
        let tableau = Etat.lire(Data("[1]".utf8))
        #expect(tableau == nil)
        let texte = Etat.lire(Data("pas du JSON".utf8))
        #expect(texte == nil)
    }
}
