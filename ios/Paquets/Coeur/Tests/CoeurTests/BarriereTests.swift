import Foundation
import Testing
@testable import Coeur

/// La barrière d'iOS (PORTAGE.md § 2.1.5 à 2.1.8) : les treize états et leur ordre, le report de 5 et de 15 minutes,
/// la fenêtre de nuit un vendredi soir, les jours exemptés des deux années à venir, l'instantané que lit l'extension
/// et la boîte où elle écrit. Le constat du système (autorisation, sélection, activités, magasin, réveils) est forgé :
/// rien de Temps d'écran ne tourne ici.
@Suite("Barriere")
struct BarriereTests {

    private typealias Constat = Barriere.Constat

    private func avec(_ changer: (inout Constat) -> Void) -> Constat {
        var c = Constat()
        changer(&c)
        return c
    }

    private func paris() throws -> Fuseau { try #require(Fuseau("Europe/Paris")) }

    private func a(_ iso: String, _ h: Int, _ m: Int = 0, _ fuseau: Fuseau) -> DateHeureZonee {
        DateHeureZonee(DateHeure(JourCivil.du(iso), heure: h, minute: m), fuseau: fuseau)
    }

    // MARK: Les treize états

    @Test func lesTreizeEtats() {
        let cas: [(String, Constat, Barriere.Etat)] = [
            ("tout est en place", Constat(), .veille),
            ("rien d'autorisé, mode éteint", avec { $0.autorisation = .nonDemandee; $0.modeActif = false }, .autorisationsManquantes),
            ("mode éteint", avec { $0.modeActif = false; $0.magasinActif = false }, .desactivee),
            ("aucune application", avec { $0.applications = 0 }, .aucuneApplication),
            ("journée faite", avec { $0.fenetreFaite = true; $0.magasinActif = false }, .dejaFaite),
            ("Chabbat", avec { $0.jourExempte = true; $0.magasinActif = false }, .jourExempte),
            ("report", avec { $0.reportee = true; $0.magasinActif = false }, .reportee),
            ("hors de la fenêtre", avec { $0.dansFenetre = false; $0.magasinActif = false }, .horsFenetre),
            ("accès retiré, mode allumé", avec { $0.autorisation = .refusee }, .autorisationRetiree),
            ("jetons d'un autre iPhone", avec { $0.selectionValide = false }, .selectionARefaire),
            ("surveillance non inscrite", avec { $0.surveillanceInscrite = false }, .surveillanceAbsente),
            ("magasin inactif à l'heure de la veille", avec { $0.magasinActif = false }, .bouclierDesaccorde),
            ("surveillance muette", avec { $0.surveillanceMuette = true }, .surveillanceMuette),
        ]
        for (nom, constat, attendu) in cas {
            #expect(Barriere.evaluer(constat) == attendu, "\(nom)")
        }
        let vus = Set(cas.map { $0.2 })
        #expect(vus == Set(Barriere.Etat.allCases))
        #expect(Barriere.Etat.allCases.count == 13)
        let propres = Barriere.Etat.allCases.filter { $0.propreAIOS }
        #expect(propres.count == 5)
    }

    /// `GateStatus.evaluate` : sur les 128 combinaisons de ses sept conditions, le premier défaut dans l'ordre de
    /// Kotlin l'emporte.
    @Test func lOrdreDeGateStatus() {
        let ordre: [Barriere.Etat] = [.autorisationsManquantes, .desactivee, .aucuneApplication, .dejaFaite, .jourExempte,
                                      .reportee, .horsFenetre]
        for bits in 0..<128 {
            let defaut = (0..<7).map { bits & (1 << $0) != 0 }
            let attendu = ordre.indices.first { defaut[$0] }.map { ordre[$0] } ?? .veille
            let etat = Barriere.evaluerCommeAndroid(autorisee: !defaut[0], modeActif: !defaut[1], applications: defaut[2] ? 0 : 3,
                                                    fenetreFaite: defaut[3], jourExempte: defaut[4], reportee: defaut[5],
                                                    dansFenetre: !defaut[6])
            #expect(etat == attendu, "\(defaut)")
            // Sur iOS, avec tout le système en ordre et le magasin accordé, la même réponse.
            let constat = Constat(autorisation: defaut[0] ? .nonDemandee : .accordee, modeActif: !defaut[1],
                                  applications: defaut[2] ? 0 : 3, fenetreFaite: defaut[3], jourExempte: defaut[4],
                                  reportee: defaut[5], dansFenetre: !defaut[6], magasinActif: attendu == .veille)
            let ios = Barriere.evaluer(constat)
            let attenduIOS: Barriere.Etat = defaut[0] && !defaut[1] ? .autorisationRetiree : attendu
            #expect(ios == attenduIOS, "\(defaut)")
            #expect(Barriere.magasinAttendu(constat) == (attendu == .veille))
        }
    }

    @Test func lesPannesDIOSPassentAvantLaRegleDuJour() {
        let muetteLeChabbat = avec { $0.surveillanceMuette = true; $0.jourExempte = true; $0.magasinActif = false }
        #expect(Barriere.evaluer(muetteLeChabbat) == .surveillanceMuette)
        let absenteEtARefaire = avec { $0.surveillanceInscrite = false; $0.selectionValide = false }
        #expect(Barriere.evaluer(absenteEtARefaire) == .selectionARefaire)
        let eteintEtRetire = avec { $0.modeActif = false; $0.autorisation = .refusee }
        #expect(Barriere.evaluer(eteintEtRetire) == .autorisationsManquantes)
        // L'inverse du désaccord : la journée est faite et le magasin retient encore.
        let faiteMaisActif = avec { $0.fenetreFaite = true; $0.magasinActif = true }
        #expect(Barriere.evaluer(faiteMaisActif) == .bouclierDesaccorde)
        #expect(!Barriere.magasinAttendu(faiteMaisActif))
    }

    @Test func titresDetailsEtCouleurs() throws {
        #expect(Barriere.Etat.veille.cleTitre == "gate_armed_title")
        #expect(Barriere.Etat.horsFenetre.cleDetail == "gate_window_detail")
        #expect(Barriere.Etat.veille.couleur == .marque)
        #expect(Barriere.Etat.autorisationRetiree.couleur == .attention)
        #expect(Barriere.Etat.bouclierDesaccorde.couleur == .discrete)
        let veille = Barriere.detail(.veille, applications: 3, debut: 6 * 60, fin: 11 * 60)
        #expect(veille.quantite == 3 && veille.arguments == ["3", "11:00"])
        let hors = Barriere.detail(.horsFenetre, applications: 3, debut: 21 * 60, fin: 2 * 60)
        #expect(hors.quantite == nil && hors.arguments == ["21:00", "02:00"])
        // Les clés des huit états d'Android existent dans les trois langues.
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            let pluriels = catalogue.pluriels(langue)
            for etat in Barriere.Etat.allCases where !etat.propreAIOS {
                #expect(simples[etat.cleTitre] != nil, "\(langue) \(etat.cleTitre)")
                let detail = etat == .veille ? pluriels["\(etat.cleDetail)[other]"] : simples[etat.cleDetail]
                #expect(detail != nil, "\(langue) \(etat.cleDetail)")
            }
        }
    }

    // MARK: Ce que l'app constate

    /// Le mode allumé, trois applications, une fenêtre ; le système en ordre et le magasin accordé à la règle.
    private func donnees(debut: Int, fin: Int) -> Donnees {
        var r = Reglages(enIsrael: false)
        r.modeBarriere = true
        r.debutFenetre = debut
        r.finFenetre = fin
        return Donnees(reglages: r)
    }

    private func etat(_ d: Donnees, _ maintenant: DateHeureZonee) -> Barriere.Etat {
        var c = Barriere.constater(d, maintenant: maintenant, systeme: Barriere.Systeme(applications: 3))
        c.magasinActif = Barriere.magasinAttendu(c)
        return Barriere.evaluer(c)
    }

    /// La fenêtre de nuit un vendredi soir : comme sur Android, c'est le jour civil qui compte (README, « Shabbat et
    /// fêtes ») ; la barrière veille jusqu'à minuit le vendredi, se tait le Chabbat, reprend le dimanche à 0 h 30 sur la
    /// nuit du motsaé Chabbat. La séance de 21 h 30 du vendredi couvre la nuit.
    @Test func fenetreDeNuitUnVendrediSoir() throws {
        let z = try paris()
        var d = donnees(debut: 21 * 60, fin: 2 * 60)
        #expect(JourCivil.du("2026-11-13").jourDeSemaine == 6)
        let cas: [(DateHeureZonee, Barriere.Etat)] = [
            (a("2026-11-13", 20, 59, z), .horsFenetre),
            (a("2026-11-13", 21, 0, z), .veille),
            (a("2026-11-13", 23, 59, z), .veille),
            (a("2026-11-14", 0, 30, z), .jourExempte),
            (a("2026-11-14", 1, 59, z), .jourExempte),
            (a("2026-11-14", 2, 0, z), .jourExempte),
            (a("2026-11-14", 22, 0, z), .jourExempte),
            (a("2026-11-15", 0, 30, z), .veille),
            (a("2026-11-15", 2, 0, z), .horsFenetre),
        ]
        for (t, attendu) in cas {
            #expect(etat(d, t) == attendu, "\(t)")
        }
        // La séance de 21 h 30 du vendredi : la nuit est honorée, avant même le Chabbat.
        let seance = a("2026-11-13", 21, 30, z)
        Pratique.inscrire(&d, minutes: 20, jour: seance.jour, maintenant: seance)
        #expect(etat(d, a("2026-11-13", 22, 0, z)) == .dejaFaite)
        #expect(etat(d, a("2026-11-14", 0, 30, z)) == .dejaFaite)
        #expect(etat(d, a("2026-11-14", 22, 0, z)) == .jourExempte)
        #expect(etat(d, a("2026-11-15", 0, 30, z)) == .veille)
        // Sans Chabbat chômé, la nuit du vendredi au samedi reste retenue.
        var sansChabbat = donnees(debut: 21 * 60, fin: 2 * 60)
        sansChabbat.reglages.pauseShabbat = false
        #expect(etat(sansChabbat, a("2026-11-14", 0, 30, z)) == .veille)
    }

    @Test func reportDeCinqEtDeQuinzeMinutes() throws {
        let z = try paris()
        for minutes in [5, 15] {
            var d = donnees(debut: 6 * 60, fin: 11 * 60)
            d.reglages.report = minutes
            let lundi = a("2026-11-16", 7, 0, z)
            #expect(etat(d, lundi) == .veille)
            Barriere.reporter(&d.reglages, maintenant: lundi.millis)
            #expect(d.reglages.reporteJusqua == lundi.millis + Int64(minutes) * 60_000)
            #expect(etat(d, lundi) == .reportee)
            #expect(etat(d, lundi.plus(minutes: minutes - 1)) == .reportee)
            #expect(etat(d, lundi.plus(minutes: minutes)) == .veille)
            // L'activité « report » commence à la fin du report et dure le minimum de quinze minutes.
            let intervalle = Barriere.intervalle(a: d.reglages.reporteJusqua, fuseau: z)
            #expect(intervalle.debut == DateHeure(JourCivil.du("2026-11-16"), heure: 7, minute: minutes))
            let duree = intervalle.fin.millisDepuis(intervalle.debut)
            #expect(duree == Barriere.dureeMinimale * 60_000)
            // L'extension, réveillée au début de l'activité, réarme ; une minute avant, non.
            let i = Barriere.instantane(d, maintenant: lundi, applications: 3, serie: 4)
            let debut = DateHeureZonee(intervalle.debut, fuseau: z)
            #expect(Barriere.doitRetenir(i, maintenant: debut))
            #expect(!Barriere.doitRetenir(i, maintenant: debut.plus(minutes: -1)))
        }
        // Un report qui finit en cours de minute : l'activité commence à la minute suivante, jamais avant.
        let t = a("2026-11-16", 7, 5, z).millis + 30_500
        let intervalle = Barriere.intervalle(a: t, fuseau: z)
        #expect(intervalle.debut == DateHeure(JourCivil.du("2026-11-16"), heure: 7, minute: 6))
        #expect(Barriere.durees == [5, 10, 15, 30, 60])
    }

    @Test func fenetresAcceptees() {
        #expect(Barriere.dureeFenetre(debut: 21 * 60, fin: 2 * 60) == 5 * 60)
        #expect(Barriere.dureeFenetre(debut: 6 * 60, fin: 11 * 60) == 5 * 60)
        #expect(Barriere.dureeFenetre(debut: 600, fin: 600) == 0)
        #expect(Barriere.fenetreAcceptee(debut: 600, fin: 615))
        #expect(!Barriere.fenetreAcceptee(debut: 600, fin: 614))
        #expect(!Barriere.fenetreAcceptee(debut: 1435, fin: 5))
        let plage = Barriere.plageFenetre(donnees(debut: 21 * 60 + 30, fin: 2 * 60).reglages)
        #expect(plage.debut == Barriere.Horaire(minutes: 21 * 60 + 30) && plage.fin.heure == 2 && plage.fin.minute == 0)
        #expect(Barriere.plageMinuit.debut.heure == 0 && Barriere.plageMinuit.fin.minute == 15)
    }

    @Test func surveillanceMuetteApresUnJour() {
        let t: Int64 = 1_800_000_000_000
        let jour: Int64 = 24 * 3_600_000
        #expect(!Barriere.muette(dernierReveil: nil, inscription: nil, maintenant: t))
        #expect(!Barriere.muette(dernierReveil: t - jour, inscription: nil, maintenant: t))
        #expect(Barriere.muette(dernierReveil: t - jour - 1, inscription: nil, maintenant: t))
        // Jamais réveillée : le silence court depuis l'inscription.
        #expect(Barriere.muette(dernierReveil: nil, inscription: t - 2 * jour, maintenant: t))
        #expect(!Barriere.muette(dernierReveil: t - 3 * jour, inscription: t - 60_000, maintenant: t))
        let s = Barriere.Systeme(applications: 2, activites: [.fenetre], dernierReveil: t)
        let c = Barriere.constater(donnees(debut: 360, fin: 660), maintenant: DateHeureZonee(millis: t, fuseau: .utc), systeme: s)
        #expect(!c.surveillanceInscrite)
        #expect(Barriere.evaluer(c) == .surveillanceAbsente)
    }

    // MARK: Jours exemptés, instantané, extension

    @Test func joursExemptesDesDeuxAnneesAVenir() {
        var r = Reglages(enIsrael: false)
        r.joursPause = ["2026-11-17", "2029-01-02", "2020-01-01"]
        let depuis = JourCivil.du("2026-11-15")
        let liste = Barriere.joursExemptes(depuis: depuis, reglages: r)
        #expect(liste.count > 110 && liste.count < 170, "\(liste.count)")
        let samedis = (0..<Barriere.horizonJours).map { depuis.plus(jours: $0) }.filter { $0.jourDeSemaine == 7 }
        let tous = Set(liste)
        #expect(tous.isSuperset(of: samedis))
        #expect(tous.contains(JourCivil.du("2026-11-17")) && tous.contains(JourCivil.du("2029-01-02")))
        #expect(!tous.contains(JourCivil.du("2020-01-01")))
        // Rosh Hachana 5787 tombe les 12 et 13 septembre 2026, avant ; 5788, les 2 et 3 octobre 2027.
        #expect(tous.contains(JourCivil.du("2027-10-02")) && tous.contains(JourCivil.du("2027-10-03")))
        #expect(liste == liste.sorted())
        r.pauseShabbat = false
        let pauses = Barriere.joursExemptes(depuis: depuis, reglages: r)
        #expect(pauses == [JourCivil.du("2026-11-17"), JourCivil.du("2029-01-02")])
    }

    @Test func lInstantaneSeRelitEtLExtensionDitCommeLApp() throws {
        let z = try paris()
        var d = donnees(debut: 6 * 60, fin: 11 * 60)
        d.reglages.joursPause = ["2026-11-18"]
        let mardi = a("2026-11-17", 9, 0, z)
        Pratique.inscrire(&d, minutes: 15, jour: mardi.jour, maintenant: mardi)
        let i = Barriere.instantane(d, maintenant: mardi, applications: 3, serie: 2)
        let relu = try #require(Barriere.Instantane(i.objet))
        #expect(relu == i)
        let texte = i.objet.texte()
        let objet = try ObjetJSON(texte: texte)
        let reluTexte = try #require(Barriere.Instantane(objet))
        #expect(reluTexte == i)
        var autreVersion = i.objet
        autreVersion["version"] = .entier(2)
        #expect(Barriere.Instantane(autreVersion) == nil)
        #expect(i.joursFaits == [mardi.jour])
        // Une semaine, toutes les 37 minutes : l'extension, de l'instantané écrit à l'instant, dit ce que dit l'app.
        var t = a("2026-11-15", 0, 0, z)
        let fin = a("2026-11-22", 0, 0, z)
        var compte = 0
        while t < fin {
            let instantane = Barriere.instantane(d, maintenant: t, applications: 3, serie: 0)
            let app = etat(d, t)
            #expect(Barriere.etatExtension(instantane, maintenant: t) == app, "\(t)")
            compte += 1
            t = t.plus(minutes: 37)
        }
        #expect(compte > 250)
    }

    @Test func listePerimeeLeSamediResteExempte() throws {
        let z = try paris()
        let d = donnees(debut: 0, fin: 23 * 60 + 59)
        var i = Barriere.instantane(d, maintenant: a("2026-11-15", 9, 0, z), applications: 3, serie: 0)
        i.joursExemptes = []
        i.exemptesJusqua = JourCivil.du("2026-11-01")
        #expect(Barriere.etatExtension(i, maintenant: a("2026-11-21", 10, 0, z)) == .jourExempte)
        #expect(Barriere.etatExtension(i, maintenant: a("2026-11-22", 10, 0, z)) == .veille)
        i.chabbat = false
        #expect(Barriere.etatExtension(i, maintenant: a("2026-11-21", 10, 0, z)) == .veille)
    }

    // MARK: La boîte

    @Test func laBoiteSEcritEtSeRelit() {
        let evenements: [Barriere.Evenement] = [
            Barriere.Evenement(.reveil, instant: 1000, activite: .fenetre, debut: true, actif: true),
            Barriere.Evenement(.report, instant: 2000, jusqua: 2000 + 15 * 60_000),
            Barriere.Evenement(.dejaFaite, instant: 3000),
            Barriere.Evenement(.commencer, instant: 4000),
        ]
        let fichier = evenements.map { Barriere.Boite.ligne($0) }.joined()
        let lignes = fichier.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lignes.count == 4)
        #expect(Barriere.Boite.lire(fichier) == evenements)
        // Une ligne vide, une ligne coupée par une écriture interrompue, une sorte inconnue : ignorées.
        let abime = "\n" + fichier + "{\"t\": 5000, \"e\": \"inconnue\"}\n{\"t\": 6000, \"e\": \"rep"
        #expect(Barriere.Boite.lire(abime) == evenements)
    }

    @Test func verserLaBoite() throws {
        let z = try paris()
        var d = donnees(debut: 6 * 60, fin: 11 * 60)
        let lundi = a("2026-11-16", 7, 10, z)
        let evenements: [Barriere.Evenement] = [
            Barriere.Evenement(.reveil, instant: lundi.millis - 600_000, activite: .fenetre, debut: true, actif: true),
            Barriere.Evenement(.report, instant: lundi.millis - 300_000, jusqua: lundi.millis + 600_000),
            Barriere.Evenement(.dejaFaite, instant: lundi.millis),
            Barriere.Evenement(.commencer, instant: lundi.millis + 1000),
            Barriere.Evenement(.reveil, instant: lundi.millis + 5000, activite: .report, debut: true, actif: false),
        ]
        let ancien = (0..<60).map { Barriere.Evenement(.reveil, instant: Int64($0), activite: .minuit, debut: true, actif: false) }
        // L'extension, avant que l'app ne verse : « déjà faite » lève le report et honore la fenêtre.
        let i = Barriere.instantane(d, maintenant: lundi.plus(minutes: -11), applications: 3, serie: 0)
        let vu = i.avec(evenements, fuseau: z)
        #expect(vu.reporteJusqua == 0)
        #expect(Barriere.etatExtension(vu, maintenant: lundi.plus(minutes: 1)) == .dejaFaite)
        let reporteSeul = i.avec(Array(evenements.prefix(2)), fuseau: z)
        #expect(Barriere.etatExtension(reporteSeul, maintenant: lundi) == .reportee)
        // L'app verse : la journée est inscrite à zéro minute, à l'instant de l'appui.
        let v = Barriere.verser(evenements, dans: &d, journal: ancien, fuseau: z)
        #expect(d.journal.jours[lundi.jour] == Journee(minutes: 0))
        #expect(d.reglages.faiteA == lundi.millis)
        #expect(d.reglages.reporteJusqua == 0)
        #expect(v.dernierReveil == lundi.millis + 5000)
        #expect(v.demandeDeSeance == lundi.millis + 1000)
        #expect(v.journal.count == Barriere.tailleJournal)
        #expect(v.journal.last == evenements.last)
        #expect(etat(d, lundi.plus(minutes: 1)) == .dejaFaite)
    }
}
