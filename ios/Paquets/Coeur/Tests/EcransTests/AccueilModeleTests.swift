import Foundation
import Testing
import Coeur
import Barriere
@testable import Ecrans

/// L'accueil (MainActivity.kt, onglet Aujourd'hui) : ce qu'il montre dans ses quatre états (pas encore faite, en
/// cours, faite, jour sans obligation), ce que font ses gestes, et la règle de la feuille de route qui se vérifie
/// par des valeurs : avec « Réduire les animations », les anneaux sont pleins d'emblée et rien ne bouge ; un anneau
/// fermé et un trophée neuf sont fêtés une fois. Restent au test d'interface : les captures des quatre états, le
/// rendu des anneaux, les animations elles-mêmes, la lecture d'écran.
@Suite("Modèle de l'accueil")
@MainActor
struct AccueilModeleTests {

    // MARK: Le banc

    /// Lundi 16 novembre 2026 ; Chabbat le 21.
    static let lundi = "2026-11-16"
    static let contenus = ContenusApp(dossier: Fichiers.contenu)

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    static func journal(_ seances: [(String, Int)]) throws -> Journal {
        var j = Journal()
        for (iso, minutes) in seances {
            let date = try jour(iso)
            j.addSession(minutes: minutes, date: date)
        }
        return j
    }

    struct Banc {
        let modele: AccueilModele
        let magasin: Magasin
        let persistance: PersistanceEnMemoire
        let systeme: FauxAccueilSysteme
        let aujourdhui: JourCivil
    }

    func banc(_ journal: Journal = Journal(), _ reglages: Reglages = Reglages(), iso: String = AccueilModeleTests.lundi,
              heure: Int = 10, barriere: Bool = false, langue: String = "fr", presentationVue: Bool = true,
              tempsEcran: ReglagesFausseBarriere? = nil) throws -> Banc {
        var r = reglages
        if presentationVue {
            r.setOnboarded()
            // Une version déjà choisie : le choix ne se propose pas par-dessus l'accueil (ChoixVersionModeleTests).
            if r.versionApp == nil { r.setVersionApp(.classique) }
        }
        let enregistrement = Enregistrement(journal: journal, reglages: r)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let date = try Self.jour(iso)
        let horloge = HorlogeFixe(DateHeure(date, heure: heure), fuseau: .utc)
        let systeme = FauxAccueilSysteme()
        let modele = AccueilModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: langue,
                                   barriere: barriere, systeme: systeme, systemeBarriere: tempsEcran, melange: { $0 })
        return Banc(modele: modele, magasin: magasin, persistance: persistance, systeme: systeme, aujourdhui: date)
    }

    // MARK: Les quatre états

    @Test func pasEncoreFaite() throws {
        let b = try banc()
        let m = b.modele
        #expect(m.etatDuJour == .aFaire)
        #expect(m.titreEtat == Libelle("status_pending"))
        // Le premier jour : ni « série à relancer », ni « 0 min au total ».
        #expect(m.ligneSerie == Libelle("status_streak_first"))
        #expect(m.ligneTotal == nil)
        #expect(m.detailDuJour == nil)
        #expect(m.libelleNote == nil)
        #expect(m.libelleHorsTelephone == Libelle("action_done_offline"))
        #expect(m.libelleCommencer == Libelle("action_start_session", .libelle(Store.formatDuration(15))))
        #expect(m.imageHassid == "char_welcome")
        // Sans prénom, l'accueil se tait et l'état du jour devient le titre.
        #expect(m.salutation == nil)
        #expect(m.etatEstTitre)
    }

    @Test func enCours() throws {
        var r = Reglages()
        let date = try Self.jour(Self.lundi)
        Store.beginSession(reglages: &r, minutes: 15, millis: Fuseau.utc.millis(DateHeure(date, heure: 9, minute: 55)))
        let b = try banc(Journal(), r)
        let m = b.modele
        #expect(m.etatDuJour == .enCours)
        #expect(m.titreEtat == Libelle("status_running"))
        #expect(m.libelleCommencer == Libelle("action_back_to_session"))
        // Une séance en cours ne se déclare pas faite sans le téléphone.
        #expect(m.libelleHorsTelephone == nil)
        m.commencer()
        #expect(m.routes == [.seance(demarrer: false)])
    }

    @Test func faite() throws {
        let b = try banc(Self.journal([(Self.lundi, 20)]))
        let m = b.modele
        #expect(m.etatDuJour == .faite)
        #expect(m.titreEtat == Libelle("status_done"))
        #expect(m.detailDuJour == Libelle("today_minutes", .libelle(Store.formatDuration(20))))
        #expect(m.libelleNote == Libelle("action_write_note"))
        #expect(m.libelleCommencer == Libelle("action_another_session"))
        #expect(m.ligneSerie == Libelle.pluriel("status_streak", quantite: 1, .entier(1)))
        #expect(m.ligneTotal == Libelle("status_total", .libelle(Store.formatDuration(20))))
        #expect(m.imageHassid == Poses.greeting(true, jour: b.aujourdhui))
        // Hier (dimanche) n'est ni fait ni exempté : on peut encore l'inscrire.
        #expect(m.libelleHorsTelephone == Libelle("action_done_offline"))
        m.commencer()
        m.ecrireNote()
        #expect(m.routes == [.seance(demarrer: true), .note(b.aujourdhui)])
    }

    @Test func faiteSansMinuteur() throws {
        let b = try banc(Self.journal([(Self.lundi, 0), ("2026-11-15", 10)]))
        #expect(b.modele.detailDuJour == Libelle("today_declared"))
        // Aujourd'hui et hier faits : plus rien à inscrire sans le téléphone.
        #expect(b.modele.libelleHorsTelephone == nil)
    }

    @Test func jourSansObligation() throws {
        // Samedi 21 novembre : Chabbat, « Chabbat et Yom Tov » étant actif par défaut.
        let b = try banc(iso: "2026-11-21")
        let m = b.modele
        #expect(m.etatDuJour == .repos)
        #expect(m.titreEtat == Libelle("status_rest"))
        let samedi = try #require(m.semaine.last)
        #expect(samedi.marque == .libelle(Libelle("week_shabbat_mark")))
        #expect(samedi.couleurMarque == .brand)
        #expect(samedi.fond == .exempte)
        #expect(samedi.accessibilite == [Libelle("settings_shabbat")])
    }

    // MARK: L'en-tête

    @Test func salutationSelonLHeure() throws {
        var journal = Journal()
        journal.setFirstName("Avraham")
        let matin = try banc(journal, heure: 9).modele
        #expect(matin.salutation == Libelle("hero_greeting_morning", .texte("Avraham")))
        #expect(!matin.etatEstTitre)
        let apresMidi = try banc(journal, heure: 15).modele
        #expect(apresMidi.salutation == Libelle("hero_greeting_afternoon", .texte("Avraham")))
        let soir = try banc(journal, heure: 22).modele
        #expect(soir.salutation == Libelle("hero_greeting_evening", .texte("Avraham")))
    }

    @Test func serieARelancer() throws {
        // Une séance le jeudi 5, rien depuis : la série est retombée à zéro.
        let b = try banc(Self.journal([("2026-11-05", 30)]))
        #expect(b.modele.ligneSerie == Libelle("status_streak_none"))
        #expect(b.modele.ligneTotal == Libelle("status_total", .libelle(Store.formatDuration(30))))
    }

    // MARK: Commencer et les pastilles

    @Test func commencerLanceLaSeance() throws {
        let m = try banc().modele
        m.commencer()
        #expect(m.routes == [.seance(demarrer: true)])
        m.routeOuverte()
        #expect(m.routes.isEmpty)
    }

    @Test func leVoletSOuvreParLaFlecheEtSeFermeAuDepart() async throws {
        let m = try banc().modele
        #expect(!m.volet)
        #expect(!m.feuilleOuverte)
        #expect(m.titreVolet == Libelle("depart_titre"))
        #expect(m.libelleRegler == Libelle("depart_regler"))
        m.basculerVolet()
        #expect(m.volet)
        #expect(m.feuilleOuverte)
        m.basculerVolet()
        #expect(!m.volet)
        // Une boîte ouverte depuis le volet prend sa place, puis le rend en se fermant.
        m.basculerVolet()
        try await m.toucherPastille(.duree)
        #expect(m.dialogue == .duree(.prochaine))
        #expect(m.feuilleOuverte)
        m.fermerDialogue()
        #expect(m.volet)
        #expect(m.feuilleOuverte)
        // La feuille baissée d'un geste : la boîte et le volet se ferment.
        try await m.toucherPastille(.sujet)
        m.fermerFeuille()
        #expect(m.dialogue == nil)
        #expect(!m.feuilleOuverte)
        // « Commencer » referme le volet (start_session : montrerVolet(false)), la musique aussi.
        m.basculerVolet()
        m.commencer()
        #expect(!m.volet)
        m.basculerVolet()
        try await m.toucherPastille(.musique)
        #expect(!m.volet)
        #expect(m.routes == [.seance(demarrer: true), .musique])
        m.basculerVolet()
        m.fermerVolet()
        #expect(!m.volet)
    }

    @Test func pastillesParDefaut() throws {
        let m = try banc().modele
        let genres = m.pastilles.map { $0.genre }
        #expect(genres == [.duree, .sujet, .musique])
        #expect(m.pastilles[0].valeur == .libelle(Store.formatDuration(15)))
        #expect(m.pastilles[1].valeur == .libelle(Libelle("session_theme_none_short")))
        #expect(m.pastilles[0].etiquette == Libelle("start_duration"))
    }

    @Test func pastilleMusique() throws {
        // Par défaut, le premier morceau livré, sous son titre.
        let defaut = try #require(MusicLibrary.selected(MusicLibrary.Etat()))
        guard case .libelle(let titre) = defaut.title else {
            Issue.record("le premier morceau livré n'a pas de titre du catalogue")
            return
        }
        let m0 = try banc().modele
        #expect(m0.pastilles[2].valeur == .libelle(titre))
        var eteinte = Reglages()
        eteinte.setMusicEnabled(false)
        let m1 = try banc(Journal(), eteinte).modele
        #expect(m1.pastilles[2].valeur == .libelle(Libelle("music_off_summary")))
        var aleatoire = Reglages()
        aleatoire.setMusicShuffle(true)
        let m2 = try banc(Journal(), aleatoire).modele
        #expect(m2.pastilles[2].valeur == .libelle(Libelle("music_shuffle_short")))
    }

    @Test func pastilleMusiqueOuvreLaMusique() async throws {
        let m = try banc().modele
        try await m.toucherPastille(.musique)
        #expect(m.routes == [.musique])
    }

    @Test func barriereDuMatin() async throws {
        let sans = try banc().modele
        let genres = sans.pastilles.map { $0.genre }
        #expect(!genres.contains(.barriere))

        // Trois applications retenues, Temps d'écran autorisé : la pastille bascule le mode (GesteBarriere.BASCULER),
        // et dit l'état réel (GateStatus.pastilleDe) : à midi, hors de la fenêtre de 6 h à 11 h.
        let b = try banc(heure: 12, barriere: true, tempsEcran: ReglagesFausseBarriere(jetons: 3))
        let m = b.modele
        await m.apparaitre()
        #expect(m.pastilles.last?.valeur == .libelle(Libelle("start_focus_off")))
        #expect(m.gesteBarriere == .basculer)
        try await m.toucherPastille(.barriere)
        #expect(b.magasin.reglages.isEnabled)
        #expect(m.etatBarriere == .outsideWindow)
        #expect(m.pastilles.last?.valeur == .libelle(Libelle("gate_window_title")))
        // apparaitre, puis le geste.
        let appliques = await b.systeme.etatsAppliques
        #expect(appliques == 2)
        let ecrit = await b.persistance.enregistrement.reglages.isEnabled
        #expect(ecrit)
    }

    /// Dans la fenêtre, rien de fait : la pastille dit « Activé » ; la journée faite, « Journée validée ».
    @Test func laPastilleDitLEtatReel() async throws {
        var r = Reglages()
        r.setEnabled(true)
        let b = try banc(Journal(), r, heure: 7, barriere: true, tempsEcran: ReglagesFausseBarriere(jetons: 2))
        let m = b.modele
        await m.apparaitre()
        #expect(m.etatBarriere == .armed)
        #expect(m.pastilles.last?.valeur == .libelle(Libelle("start_focus_on")))
        let fait = try banc(try Self.journal([(Self.lundi, 15)]), r, heure: 7, barriere: true,
                            tempsEcran: ReglagesFausseBarriere(jetons: 2)).modele
        await fait.apparaitre()
        #expect(fait.pastilles.last?.valeur == .libelle(Libelle("gate_done_title")))
    }

    /// Sans application ou sans autorisation, le toucher mène à la carte du mode (GesteBarriere.REGLER) au lieu
    /// d'afficher « activée » pour rien ; la surveillance arrêtée, il la relance (RELANCER).
    @Test func laPastilleNeBasculeQueSiLeModePeutAgir() async throws {
        let vide = try banc(barriere: true, tempsEcran: ReglagesFausseBarriere(jetons: 0))
        await vide.modele.apparaitre()
        #expect(vide.modele.gesteBarriere == .regler)
        try await vide.modele.toucherPastille(.barriere)
        #expect(vide.modele.routes.last == .reglages(carteBarriere: true))
        #expect(!vide.magasin.reglages.isEnabled)

        let refuse = try banc(barriere: true, tempsEcran: ReglagesFausseBarriere(constat: Constat(autorise: false),
                                                                                 jetons: 3))
        await refuse.modele.apparaitre()
        #expect(refuse.modele.gesteBarriere == .regler)

        var r = Reglages()
        r.setEnabled(true)
        let arrete = try banc(Journal(), r, heure: 7, barriere: true,
                              tempsEcran: ReglagesFausseBarriere(constat: Constat(surveillanceInscrite: false), jetons: 3))
        await arrete.modele.apparaitre()
        #expect(arrete.modele.gesteBarriere == .relancer)
        #expect(arrete.modele.pastilles.last?.valeur == .libelle(Libelle("start_focus_stopped")))
        try await arrete.modele.toucherPastille(.barriere)
        let relances = await arrete.systeme.etatsAppliques
        #expect(relances == 2)
        #expect(arrete.magasin.reglages.isEnabled)
    }

    // MARK: L'en-tête du Jour

    /// La date hébraïque du jour, sans lieu (minuit du téléphone) ; elle ouvre les zmanim, la roue les réglages.
    @Test func lEnTeteOuvreLesZmanimEtLesReglages() throws {
        let m = try banc().modele
        let e = m.entete
        let date = try #require(e.dateHebraique)
        let attendue = CalendrierJuif.jour(try Self.jour(Self.lundi), enIsrael: false).dateHebraique
        #expect(date == attendue)
        #expect(e.titre == .brut(attendue))
        #expect(e.accessibilite == Libelle("jour_ciel", .texte(attendue)))
        #expect(e.ciel == .jour)
        #expect(e.reglages == Libelle("settings_title"))
        m.ouvrirZmanim()
        m.ouvrirReglages()
        #expect(m.routes == [.zmanim, .reglages(carteBarriere: false)])
        m.preparer()
        #expect(m.routes.last == .seance(demarrer: false))
        #expect(m.libellePreparer == Libelle("start_prepare"))
    }

    /// Avec un lieu, la date change à la sortie des étoiles : à 23 h à Jérusalem, c'est déjà le lendemain hébreu.
    @Test func lEnTeteBasculeATset() throws {
        var r = Reglages()
        r.setLieuZmanim(Zmanim.Lieu(nom: "Jérusalem", latitude: 31.778, longitude: 35.2354, fuseau: "UTC"), ville: nil,
                        maintenant: 0)
        let soir = try banc(Journal(), r, heure: 23).modele
        let demain = CalendrierJuif.jour(try Self.jour("2026-11-17"), enIsrael: false).dateHebraique
        #expect(soir.entete.dateHebraique == demain)
        #expect(soir.entete.ciel == .nuit)
        let matin = try banc(Journal(), r, heure: 10).modele
        let aujourdhui = CalendrierJuif.jour(try Self.jour(Self.lundi), enIsrael: false).dateHebraique
        #expect(matin.entete.dateHebraique == aujourdhui)
    }

    @Test func dureeDeLaProchaineSeance() async throws {
        let b = try banc()
        let m = b.modele
        try await m.toucherPastille(.duree)
        #expect(m.dialogue == .duree(.prochaine))
        #expect(m.titreDialogue == Libelle("settings_target"))
        let minutes = m.optionsDuree.map { $0.minutes }
        #expect(minutes == [5, 10, 15, 30, 60, 90, nil])
        #expect(m.optionsDuree.last?.libelle == Libelle("duration_custom"))
        try await m.choisirDuree(30)
        #expect(m.dialogue == nil)
        #expect(b.magasin.reglages.targetMinutes == 30)
        #expect(m.libelleCommencer == Libelle("action_start_session", .libelle(Store.formatDuration(30))))
    }

    @Test func dureeReglable() async throws {
        let b = try banc()
        let m = b.modele
        try await m.toucherPastille(.duree)
        try await m.choisirDuree(nil)
        #expect(m.dialogue == .dureeLibre(.prochaine))
        #expect(m.titreDialogue == Libelle("duration_custom_title"))
        #expect(m.texteDureeLibre == "15")
        #expect(m.indicationDureeLibre == Libelle("duration_custom_hint"))
        #expect(m.libelleValider == Libelle("action_ok"))
        // Hors de 1 à 240, ou pas un nombre : la boîte reste ouverte et le dit (FACCUEIL-15).
        try await m.validerDureeLibre(" 500 ")
        #expect(m.dialogue == .dureeLibre(.prochaine))
        #expect(m.erreurSaisie == Libelle("duration_custom_hint"))
        #expect(b.magasin.reglages.targetMinutes == 15)
        try await m.validerDureeLibre("abc")
        #expect(m.dialogue == .dureeLibre(.prochaine))
        try await m.validerDureeLibre(" 240 ")
        #expect(m.dialogue == nil)
        #expect(m.erreurSaisie == nil)
        #expect(b.magasin.reglages.targetMinutes == 240)
    }

    @Test func sujetDeLaProchaineSeance() async throws {
        let b = try banc()
        let m = b.modele
        try await m.toucherPastille(.sujet)
        #expect(m.dialogue == .sujet)
        #expect(m.titreDialogue == Libelle("session_theme_title"))
        #expect(m.optionsSujet.count == Theme.allCases.count + 1)
        #expect(m.optionsSujet.first?.theme == nil)
        try await m.choisirSujet(.gratitude)
        #expect(m.sujet == .gratitude)
        #expect(m.pastilles[1].valeur == .libelle(Libelle("theme_gratitude")))
        // Sous la clé d'Android, que la séance lit.
        #expect(b.magasin.reglages.brut["session_theme"] == .chaine("gratitude"))
        try await m.toucherPastille(.sujet)
        try await m.choisirSujet(nil)
        #expect(m.sujet == nil)
        #expect(b.magasin.reglages.brut["session_theme"] == nil)
    }

    // MARK: Sans le téléphone

    @Test func horsTelephoneHier() async throws {
        let b = try banc()
        let m = b.modele
        let hier = b.aujourdhui.plus(jours: -1)
        m.declarerHorsTelephone()
        #expect(m.dialogue == .jourHorsTelephone(aujourdhui: b.aujourdhui, hier: hier))
        #expect(m.titreDialogue == Libelle("offline_which_day"))
        #expect(m.optionsJourHorsTelephone == [Libelle("offline_today"), Libelle("offline_yesterday")])
        m.choisirJourHorsTelephone(hier: true)
        #expect(m.dialogue == .duree(.horsTelephone(hier)))
        #expect(m.titreDialogue == Libelle("offline_how_long"))
        try await m.choisirDuree(20)
        #expect(b.magasin.journal.record(hier)?.minutes == 20)
        // Hier : pas de bravo.
        #expect(!b.magasin.reglages.hasPendingCelebration)
        #expect(m.routes.isEmpty)
        // Des minutes inscrites retirent le rappel du jour déjà paru (Store.addSession).
        let retires = await b.systeme.rappelsRetires
        #expect(retires == 1)
        // Ce qui est neuf est su sans notification.
        #expect(b.magasin.reglages.tropheesNotifies != nil)
    }

    @Test func horsTelephoneAujourdhuiOuvreLeBravo() async throws {
        // Hier déjà fait : seul aujourd'hui reste, sans question.
        let b = try banc(Self.journal([("2026-11-15", 10)]))
        let m = b.modele
        m.declarerHorsTelephone()
        #expect(m.dialogue == .duree(.horsTelephone(b.aujourdhui)))
        try await m.choisirDuree(10)
        #expect(b.magasin.journal.isDone(b.aujourdhui))
        #expect(m.routes == [.celebration(minutes: 10, dateNote: Self.lundi)])
        // Le bravo est pris : il ne se rouvrira pas.
        #expect(!b.magasin.reglages.hasPendingCelebration)
        let vignettes = await b.systeme.vignettesRafraichies
        #expect(vignettes == 1)
        #expect(m.etatDuJour == .faite)
    }

    @Test func horsTelephoneHierExempte() throws {
        // Lundi : hier dimanche. Mis en pause, il n'est plus ouvert ; aujourd'hui seul.
        var r = Reglages()
        r.togglePausedDate("2026-11-15")
        let b = try banc(Journal(), r)
        b.modele.declarerHorsTelephone()
        #expect(b.modele.dialogue == .duree(.horsTelephone(b.aujourdhui)))
    }

    // MARK: La bande de la semaine

    @Test func bandeDeLaSemaine() throws {
        let b = try banc(Self.journal([("2026-11-15", 25)]))
        let m = b.modele
        let jours = m.semaine
        #expect(jours.count == 7)
        let dates = jours.map { $0.date.iso }
        #expect(dates == ["2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19", "2026-11-20", "2026-11-21"])
        let dimanche = jours[0]
        #expect(dimanche.marque == .brut("\u{2713}"))
        #expect(dimanche.fond == .faite)
        #expect(dimanche.couleurMarque == .white)
        #expect(dimanche.couleurEtiquette == .white)
        #expect(dimanche.accessibilite == [Libelle("week_done"), Store.formatDuration(25)])
        #expect(dimanche.ouvrable)
        let lundi = jours[1]
        #expect(lundi.marque == .brut("16"))
        #expect(lundi.fond == .aujourdhui)
        #expect(lundi.couleurMarque == .ink)
        #expect(lundi.accessibilite == [Libelle("week_todo")])
        let mardi = jours[2]
        #expect(mardi.couleurMarque == .muted)
        #expect(mardi.fond == .aFaire)
        #expect(!mardi.ouvrable)
    }

    @Test func montrerLaDureeDUnJour() throws {
        let b = try banc(Self.journal([("2026-11-15", 80)]))
        let m = b.modele
        let dimanche = try Self.jour("2026-11-15")
        m.ouvrirJour(dimanche)
        let attendu = AccueilJourDialogue(date: dimanche, message: Libelle("jour_fait", .libelle(Store.formatDuration(80))),
                                          ajouter: Libelle("jour_ajouter_temps"), montrer: Libelle("jour_montrer_duree"),
                                          retour: Libelle("action_back"))
        #expect(m.dialogue == .jour(attendu))
        m.montrerDuree()
        #expect(m.dialogue == nil)
        #expect(m.semaine[0].marque == .brut("1h20"))
        #expect(m.semaine[0].marqueReduite)
        // Demandée encore : le ✓ revient.
        m.ouvrirJour(dimanche)
        m.montrerDuree()
        #expect(m.semaine[0].marque == .brut("\u{2713}"))
        #expect(!m.semaine[0].marqueReduite)
    }

    @Test func ajouterDuTempsAUnJour() async throws {
        let b = try banc()
        let m = b.modele
        let dimanche = try Self.jour("2026-11-15")
        m.ouvrirJour(dimanche)
        guard case .jour(let boite)? = m.dialogue else {
            Issue.record("la boîte du jour ne s'est pas ouverte")
            return
        }
        #expect(boite.message == Libelle("jour_rien"))
        #expect(boite.montrer == nil)
        m.ajouterTemps()
        #expect(m.dialogue == .duree(.ajout(dimanche)))
        try await m.choisirDuree(25)
        #expect(b.magasin.journal.record(dimanche)?.minutes == 25)
        #expect(m.message == Libelle("jour_ajoute", .libelle(Store.formatDuration(25))))
        #expect(m.routes.isEmpty)
        let retires = await b.systeme.rappelsRetires
        #expect(retires == 1)
        m.messageMontre()
        #expect(m.message == nil)
    }

    @Test func unJourAVenirNeSOuvrePas() throws {
        let m = try banc().modele
        let mardi = try Self.jour("2026-11-17")
        m.ouvrirJour(mardi)
        #expect(m.dialogue == nil)
    }

    // MARK: Les anneaux et la plaque

    @Test func legendeEtAnneauTouche() throws {
        let b = try banc(Self.journal([(Self.lundi, 10)]))
        let m = b.modele
        let etat = m.anneaux
        #expect(m.legende == Libelle.pluriel("week_gauge", quantite: etat.semaine.fait, .entier(etat.semaine.fait),
                                             .entier(etat.semaine.objectif)))
        #expect(m.couleurLegende == .muted)
        m.toucherAnneau(.jour)
        #expect(m.misEnAvant == .jour)
        #expect(m.face == .jour)
        #expect(m.legende == Libelle("ring_day_detail", .libelle(Store.formatDuration(10)), .libelle(Store.formatDuration(15))))
        #expect(m.couleurLegende == .brand)
        #expect(m.retourHassidPrevu != nil)
        #expect(m.touches == 1)
        // Un second toucher le remet avec les autres, et le hassid revient.
        m.toucherAnneau(.jour)
        #expect(m.misEnAvant == nil)
        #expect(m.face == .hassid)
        #expect(m.retourHassidPrevu == nil)
        m.toucherAnneau(.serie)
        #expect(m.face == .serie)
        #expect(m.legende == Libelle.pluriel("ring_streak_detail", quantite: 1, .entier(1), .entier(7)))
        #expect(m.couleurLegende == .ringStreak)
    }

    @Test func descriptionDesAnneaux() throws {
        let m = try banc(Self.journal([(Self.lundi, 10)])).modele
        // Dimanche à vendredi dus, samedi chômé : six jours dus, un fait.
        #expect(m.descriptionAnneaux == Libelle("rings_description", .libelle(Store.formatDuration(10)),
                                                .libelle(Store.formatDuration(15)), .entier(1), .entier(6),
                                                .entier(1), .entier(7)))
    }

    @Test func lesFacesDeLaPlaque() throws {
        let b = try banc(Self.journal([("2026-11-15", 30), (Self.lundi, 10)]))
        let m = b.modele
        #expect(m.plaque == nil)
        #expect(m.accessibilitePlaque == [.libelle(Libelle("rings_character_hint"))])
        var faces: [Plaque.Face] = []
        for _ in 0..<8 {
            m.toucherPlaque()
            faces.append(m.face)
        }
        #expect(faces == [.jour, .semaine, .serie, .meilleure, .total, .jours, .moyenne, .hassid])
        #expect(m.touches == 8)

        m.toucherPlaque()
        let jour = try #require(m.plaque)
        #expect(jour.cible == 10)
        #expect(jour.texte == .libelle(Store.formatDuration(10)))
        #expect(jour.legende == Libelle("plaque_jour", .libelle(Store.formatDuration(15))))
        #expect(jour.couleur == .brand)
        #expect(jour.compte)
        #expect(m.misEnAvant == .jour)

        m.toucherPlaque()
        let semaine = try #require(m.plaque)
        #expect(semaine.texte == .libelle(Libelle("plaque_semaine_valeur", .entier(2), .entier(6))))
        #expect(semaine.valeur(0) == .libelle(Libelle("plaque_semaine_valeur", .entier(0), .entier(6))))
        #expect(semaine.couleur == .ringWeek)

        m.toucherPlaque()
        let serie = try #require(m.plaque)
        #expect(serie.texte == .brut("2"))
        #expect(serie.legende == Libelle.pluriel("plaque_serie", quantite: 2, .entier(2), .entier(7)))
        #expect(serie.accessibilite == [.brut("2"), .libelle(serie.legende)])

        m.toucherPlaque()
        #expect(m.plaque?.cible == 2)
        // La meilleure série parle aussi de la série.
        #expect(m.misEnAvant == .serie)

        m.toucherPlaque()
        let total = try #require(m.plaque)
        #expect(total.cible == 40)
        #expect(total.couleur == .ink)
        #expect(m.misEnAvant == nil)

        m.toucherPlaque()
        #expect(m.plaque?.legende == Libelle.pluriel("plaque_jours", quantite: 2, .entier(2)))

        m.toucherPlaque()
        #expect(m.plaque?.cible == 20)
        #expect(m.plaque?.legende == Libelle("plaque_moyenne"))
    }

    @Test func leHassidRevientSansToucher() throws {
        let m = try banc().modele
        m.toucherPlaque()
        let premier = try #require(m.retourHassidPrevu)
        m.toucherPlaque()
        let second = try #require(m.retourHassidPrevu)
        // Un retour d'avant le dernier toucher ne compte plus.
        m.retourHassid(premier)
        #expect(m.face == .semaine)
        m.retourHassid(second)
        #expect(m.face == .hassid)
        #expect(m.misEnAvant == nil)
        #expect(m.retourHassidPrevu == nil)
    }

    @Test func remplissageAnime() async throws {
        let b = try banc(Self.journal([(Self.lundi, 10)]))
        let m = b.modele
        await m.apparaitre()
        let numero = try #require(m.remplissage)
        #expect(m.avanceDepart == 0)
        #expect(m.anneauxMontres == m.anneaux)
        // Un autre passage repart de zéro, sous un autre numéro.
        m.ongletChoisi()
        let suivant = try #require(m.remplissage)
        #expect(suivant != numero)
        // Le remplissage d'avant ne prévient plus.
        try await m.remplissageFini(numero)
        #expect(m.remplissage == suivant)
        try await m.remplissageFini(suivant)
        #expect(m.remplissage == nil)
        #expect(m.avanceDepart == 1)
        // Aucun anneau fermé : le hassid salue d'un saut.
        #expect(m.saut?.fois == 1)
        #expect(m.feteAnneau == nil)
        // Retourner la plaque s'anime.
        m.toucherPlaque()
        #expect(m.retournements == 1)
    }

    @Test func reduireLesAnimationsLaisseLesAnneauxImmobiles() async throws {
        let b = try banc(Self.journal([(Self.lundi, 15)]))
        let m = b.modele
        m.reduireAnimations = true
        await m.apparaitre()
        // Pleins d'emblée : aucun remplissage, l'avance part de 1.
        #expect(m.remplissage == nil)
        #expect(m.avanceDepart == 1)
        let traits = m.traits(avance: m.avanceDepart)
        let pleins = AccueilAnneaux.traits(m.anneaux, misEnAvant: nil, avance: 1)
        #expect(traits == pleins)
        m.ongletChoisi()
        #expect(m.remplissage == nil)
        // La face change d'un coup, le chiffre s'écrit d'un coup, le hassid ne saute pas.
        m.toucherPlaque()
        #expect(m.face == .jour)
        #expect(m.retournements == 0)
        #expect(m.plaque?.compte == false)
        let retour = try #require(m.retourHassidPrevu)
        m.retourHassid(retour)
        #expect(m.saut == nil)
        // Comme sur Android, les animations coupées ne fêtent rien.
        try await m.remplissageFini(1)
        #expect(m.feteAnneau == nil)
        #expect(b.magasin.reglages.anneauxFetes.isEmpty)
        // Les cartes du moment n'entrent pas en cascade (Effets.cascade).
        #expect(!m.cascade)
    }

    @Test func revenirDeTextesNeRejoueQueLesAnneaux() async throws {
        let b = try banc(Self.journal([(Self.lundi, 10)]))
        let m = b.modele
        await m.apparaitre()
        m.toucherPlaque()
        let avant = try #require(m.remplissage)
        m.ongletChoisi()
        let apres = try #require(m.remplissage)
        #expect(apres != avant)
        // Le panneau change sur place : la face montrée reste (pas d'onResume).
        #expect(m.face == .jour)
    }

    @Test func unAnneauFermeEstFeteUneFois() async throws {
        // Quinze minutes aujourd'hui : l'objectif du jour (la durée habituelle) est atteint.
        let b = try banc(Self.journal([(Self.lundi, 15)]))
        let m = b.modele
        await m.apparaitre()
        let premier = try #require(m.remplissage)
        try await m.remplissageFini(premier)
        let fete = try #require(m.feteAnneau)
        #expect(fete.quel == .jour)
        #expect(m.misEnAvant == .jour)
        #expect(m.face == .jour)
        #expect(m.saut == nil)
        #expect(m.legende == Libelle("ring_day_reached", .libelle(Store.formatDuration(15)), .libelle(Store.formatDuration(15))))
        #expect(b.magasin.reglages.anneauxFetes == ["jour:2026-11-16"])
        let ecrit = await b.persistance.enregistrement.reglages.anneauxFetes
        #expect(ecrit == ["jour:2026-11-16"])
        // La fête finie, l'anneau rend la place et le hassid revient.
        m.finFeteAnneau(fete.numero)
        #expect(m.misEnAvant == nil)
        #expect(m.face == .hassid)

        // Au passage suivant : plus de fête, le hassid salue.
        await m.apparaitre()
        let second = try #require(m.remplissage)
        try await m.remplissageFini(second)
        #expect(m.feteAnneau == fete)
        #expect(m.saut != nil)
    }

    @Test func dessinDesAnneaux() throws {
        let etat = Anneaux.Etat(jour: Anneaux.Anneau(quel: .jour, fait: 22, objectif: 15),
                                semaine: Anneaux.Anneau(quel: .semaine, fait: 3, objectif: 6),
                                serie: Anneaux.Anneau(quel: .serie, fait: 0, objectif: 7))
        let traits = AccueilAnneaux.traits(etat, misEnAvant: .semaine, avance: 1)
        let quels = traits.map { $0.quel }
        #expect(quels == [.serie, .semaine, .jour])
        let retraits = traits.map { $0.retrait }
        #expect(retraits == [4, 15, 26])
        #expect(traits[1].epaisseur == 8 * 1.3)
        #expect(traits[1].opacite == 1)
        #expect(traits[0].opacite == 70.0 / 255.0)
        // La série à zéro : la piste seule.
        #expect(!traits[0].tourPlein)
        #expect(traits[0].reste == 0)
        // La semaine à moitié : un arc de 180°, à la teinte de base.
        #expect(abs(traits[1].reste - 0.5) < 1e-6)
        #expect(!traits[1].assombri)
        // Le jour à 22 sur 15 : un tour plein, et un second tour assombri.
        #expect(traits[2].tourPlein)
        #expect(traits[2].assombri)
        #expect(abs(traits[2].reste - Double(Float(22) / Float(15) - 1)) < 1e-6)
        // Au départ d'un remplissage, rien que les pistes.
        let depart = AccueilAnneaux.traits(etat, misEnAvant: nil, avance: 0)
        let arcs = depart.filter { $0.tourPlein || $0.reste > 0 }
        #expect(arcs.isEmpty)
    }

    @Test func anneauSousLeDoigt() {
        // Un carré de 176 : la série de 0 à 8 depuis le bord, la semaine de 11 à 19, le jour de 22 à 30.
        #expect(AccueilAnneaux.sousLePoint(cote: 176, x: 88, y: 4) == .serie)
        #expect(AccueilAnneaux.sousLePoint(cote: 176, x: 88, y: 15) == .semaine)
        #expect(AccueilAnneaux.sousLePoint(cote: 176, x: 88, y: 26) == .jour)
        #expect(AccueilAnneaux.sousLePoint(cote: 176, x: 88, y: 40) == nil)
        #expect(AccueilAnneaux.sousLePoint(cote: 176, x: 88, y: 88) == nil)
        #expect(AccueilAnneaux.sousLePoint(cote: 176, x: -1, y: 88) == nil)
        // La marge d'un demi-écart : 9,4 depuis le bord est encore la série.
        #expect(AccueilAnneaux.sousLePoint(cote: 176, x: 88, y: 9.4) == .serie)
    }

    // MARK: Les trophées, le bilan, la fête

    @Test func ligneDuProchainTrophee() throws {
        let b = try banc()
        let p = Store.pratique(journal: Journal(), reglages: b.magasin.reglages, aujourdhui: b.aujourdhui,
                               fuseauTelephone: "UTC")
        let prochain = try #require(Trophees.prochain(p))
        let reste = prochain.seuil - min(Trophees.valeur(p, prochain.famille), prochain.seuil)
        let texte = Libelle("accueil_prochain_trophee", .libelle(TropheeTextes.description(prochain)), .entier(reste))
        let ligne = b.modele.ligneTrophee
        #expect(ligne.texte == texte)
        #expect(ligne.grade == Trophees.grade(0))
        #expect(ligne.accessibilite == [TropheeTextes.grade(Trophees.grade(0)), texte])
        b.modele.ouvrirPaliers()
        b.modele.ouvrirParcours()
        #expect(b.modele.routes == [.paliers, .parcours])
    }

    /// Six jours de dix minutes, sans deux jours de suite ni vendredi (comme TropheeFeteModeleTests) : deux
    /// semaines de trente minutes, celle du 1ᵉʳ et celle du 8 novembre.
    static let sixJours: [(String, Int)] = [
        ("2026-11-01", 10), ("2026-11-03", 10), ("2026-11-05", 10),
        ("2026-11-08", 10), ("2026-11-10", 10), ("2026-11-12", 10),
    ]

    @Test func unTropheeNeufEstFeteUneFois() async throws {
        let b = try banc(Self.journal(Self.sixJours))
        let m = b.modele
        // Le tout premier passage ne fête rien.
        await m.apparaitre()
        #expect(m.fete.fiches.isEmpty)
        // Le septième jour : « 7 jours de pratique ».
        try await b.magasin.modifierJournal { $0.addSession(minutes: 10, date: b.aujourdhui) }
        await m.apparaitre()
        let niveaux = m.fete.fiches.map { $0.niveau }
        #expect(niveaux == [Trophees.Niveau(famille: .jours, rang: 1)])
        m.fete.fermerFiche()
        await m.apparaitre()
        #expect(m.fete.fiches.isEmpty)
    }

    @Test func bilanDeLaSemaineUneFois() async throws {
        let b = try banc(Self.journal(Self.sixJours))
        let m = b.modele
        await m.apparaitre()
        let bilan = try #require(m.bilan)
        let dimanche = try Self.jour("2026-11-08")
        #expect(bilan.debut == dimanche)
        #expect(bilan.titre == Libelle("bilan_titre"))
        #expect(bilan.minutes == Libelle("bilan_minutes", .libelle(Store.formatDuration(30)),
                                         .libelle(Libelle.pluriel("palier_n_jours", quantite: 3, .entier(3)))))
        // Autant que la semaine d'avant : ni « de plus », ni record.
        #expect(bilan.plus == nil)
        #expect(bilan.record == nil)
        #expect(bilan.bouton == Libelle("celebration_continue"))
        #expect(b.magasin.reglages.bilanVu == "2026-11-08")
        m.fermerBilan()
        await m.apparaitre()
        #expect(m.bilan == nil)
    }

    @Test func uneSemaineVideNeFaitPasDeBilan() async throws {
        let b = try banc()
        await b.modele.apparaitre()
        #expect(b.modele.bilan == nil)
        // Retenue quand même : rien n'est recalculé avant la semaine suivante.
        #expect(b.magasin.reglages.bilanVu == "2026-11-08")
    }

    // MARK: Le passage

    @Test func premierPassage() async throws {
        let b = try banc(presentationVue: false)
        let m = b.modele
        await m.apparaitre()
        #expect(m.routes == [.presentation])
        #expect(m.cascade)
        let appliques = await b.systeme.etatsAppliques
        let vignettes = await b.systeme.vignettesRafraichies
        #expect(appliques == 1)
        #expect(vignettes == 1)
        m.routeOuverte()
        await m.apparaitre()
        // Une fois par création : ni présentation ni cascade au retour.
        #expect(m.routes.isEmpty)
        #expect(!m.cascade)
    }

    @Test func leBravoEnAttenteSOuvreAuPassage() async throws {
        var r = Reglages()
        r.setPendingCelebration(minutes: 20, dateNote: Self.lundi)
        let b = try banc(Self.journal([(Self.lundi, 20)]), r)
        let m = b.modele
        // Le bravo attend : c'est lui qui proposera la note.
        m.demanderNote(b.aujourdhui)
        #expect(m.routes.isEmpty)
        await m.apparaitre()
        #expect(m.routes == [.celebration(minutes: 20, dateNote: Self.lundi)])
        #expect(!b.magasin.reglages.hasPendingCelebration)
        let ecrit = await b.persistance.enregistrement.reglages.hasPendingCelebration
        #expect(!ecrit)
    }

    @Test func laNoteDepuisLaNotification() throws {
        let m = try banc().modele
        let hier = try Self.jour("2026-11-15")
        m.demanderNote(hier)
        #expect(m.routes == [.note(hier)])
    }

    // MARK: La relance

    @Test func motDeRelanceApresUneRupture() async throws {
        let b = try banc(Self.journal([("2026-11-05", 30)]))
        let m = b.modele
        await m.apparaitre()
        let carte = try #require(m.relance)
        #expect(carte.moment == Libelle("moment_relance"))
        // Le même texte tant que dure la rupture.
        await m.apparaitre()
        #expect(m.relance?.id == carte.id)
        #expect(Store.chizukLast(reglages: b.magasin.reglages, moment: .relance) == carte.id)
    }

    @Test func pasDeRelanceSansRupture() async throws {
        let premier = try banc()
        await premier.modele.apparaitre()
        #expect(premier.modele.relance == nil)
        let enSerie = try banc(Self.journal([("2026-11-15", 10)]))
        await enSerie.modele.apparaitre()
        #expect(enSerie.modele.relance == nil)
    }

    // MARK: Les cartes du moment

    @Test func lesCartesDuMatin() async throws {
        let m = try banc(heure: 10).modele
        await m.apparaitre()
        let cartes = m.cartes
        var priere: AccueilPriere? = nil
        var source: AccueilSource? = nil
        for carte in cartes {
            switch carte {
            case .priere(let p): if priere == nil { priere = p }
            case .source(let s): source = s
            case .rappel: break
            }
        }
        // Sans lieu, les heures fixes : Cha'harit à 10 h.
        let p = try #require(priere)
        #expect(p.id == "chaharit")
        #expect(p.etiquette == Libelle("siddur_maintenant"))
        #expect(p.mot == Libelle("moment_mot_matin"))
        #expect(p.image == SiddurMoment.illustration("chaharit"))
        #expect(p.route == .siddour("chaharit"))
        #expect(!p.hebreu.isEmpty)
        // Pas de Birkat haLevana le matin.
        let ids = cartes.map { $0.id }
        #expect(!ids.contains("priere:birkat_halevana"))
        // La source du jour ferme la liste.
        let s = try #require(source)
        #expect(s.titre == Libelle("source_du_jour"))
        #expect(s.bouton == Libelle("source_du_jour_lire"))
        #expect(s.route == .entreeBibliotheque(s.id))
        #expect(ids.last == "source:" + s.id)
        m.ouvrir(p.route)
        #expect(m.routes == [.siddour("chaharit")])
    }

    @Test func lesCartesDuSoir() async throws {
        let b = try banc(heure: 20)
        let m = b.modele
        await m.apparaitre()
        let ids = m.cartes.map { $0.id }
        // Sans lieu, 20 h : Arvit, et le mot du soir.
        let arvit = try #require(ids.firstIndex(of: "priere:arvit"))
        guard case .priere(let p) = m.cartes[arvit] else {
            Issue.record("la carte d'Arvit n'est pas une prière")
            return
        }
        #expect(p.mot == Libelle("moment_mot_soir"))
        #expect(p.image == SiddurMoment.illustration("arvit"))
        // Birkat haLevana, après 14 h, quand la fenêtre est ouverte ce soir (AccueilMoment.cartes), juste après
        // la prière de l'heure.
        let r = b.magasin.reglages
        let usage = Levana.Usage.duNusah(r.siddurNusah)
        let fenetre = Levana.fenetre(b.aujourdhui, fuseau: .utc, usage: usage)
        var ouverte = true
        if case .dans = Levana.etat(fenetre, b.aujourdhui, fuseau: .utc) { ouverte = false }
        let levana = ids.firstIndex(of: "priere:birkat_halevana")
        #expect((levana != nil) == ouverte)
        if let levana {
            #expect(levana == arvit + 1)
            guard case .priere(let l) = m.cartes[levana] else {
                Issue.record("la carte de Birkat haLevana n'est pas une prière")
                return
            }
            #expect(l.etiquette == Libelle("levana_ce_soir"))
            #expect(l.image == "char_praise")
            #expect(l.mot == nil)
            #expect(l.route == .siddour("birkat_halevana"))
        }
    }

    @Test func lesRappelsDeTefila() throws {
        let b = try banc()
        let jour = b.aujourdhui
        let attendus = RappelsTefila.prochains(jour) { CalendrierJuif.jour($0, enIsrael: false) }
        let rappels = b.modele.rappels
        let genres = rappels.map { $0.genre }
        let genresAttendus = attendus.map { $0.genre }
        #expect(genres == genresAttendus)
        let cles = rappels.map { $0.id }
        let clesAttendues = attendus.map { $0.genre.rawValue + ":" + $0.date.iso }
        #expect(cles == clesAttendues)
    }

    @Test func leMomentDUnChangement() throws {
        let lundi = try Self.jour(Self.lundi)
        func quand(_ genre: RappelsTefila.Genre, _ decalage: Int) -> AccueilQuand {
            AccueilModele.quand(RappelsTefila.Rappel(genre, lundi.plus(jours: decalage)), aujourdhui: lundi)
        }
        // Dans la journée (Moussaf).
        #expect(quand(.guechemDebut, 0) == .aujourdhui)
        #expect(quand(.guechemDebut, 1) == .demain)
        #expect(quand(.guechemDebut, 3) == .jour(lundi.plus(jours: 3)))
        // Le soir de la veille (Arvit).
        #expect(quand(.omer, 0) == .hierSoir)
        #expect(quand(.omer, 1) == .ceSoir)
        #expect(quand(.omer, 2) == .demainSoir)
        #expect(quand(.omer, 3) == .soir(lundi.plus(jours: 2)))
        // Le soir d'un samedi : motsaé Chabbat (le changement tombe le dimanche 22).
        #expect(quand(.omer, 6) == .motsae)

        let rappel = AccueilRappel(genre: .omer, date: lundi.plus(jours: 3), titre: Libelle("rappel_omer_titre"),
                                   cleCorps: "rappel_omer", quand: .soir(lundi.plus(jours: 2)),
                                   source: Libelle("rappel_source", .texte("489:1")))
        let corps = rappel.corps { _ in "Mercredi" }
        #expect(corps == Libelle("rappel_omer", .libelle(Libelle("rappel_soir", .texte("Mercredi")))))
    }

    // MARK: Le catalogue

    /// Chaque clé que l'accueil nomme existe dans le catalogue, en français, en anglais et en hébreu.
    @Test func clesDuCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        let cles = [
            "app_name", "hero_greeting_morning", "hero_greeting_afternoon", "hero_greeting_evening",
            "status_running", "status_done", "status_rest", "status_pending", "status_streak", "status_streak_none",
            "status_streak_first", "status_separator", "status_total", "today_minutes", "today_declared",
            "rings_description", "rings_character_hint", "plaque_jour", "plaque_semaine_valeur", "plaque_semaine",
            "plaque_serie", "plaque_meilleure", "plaque_total", "plaque_jours", "plaque_moyenne", "ring_day_reached",
            "ring_day_detail", "ring_streak_reached", "ring_streak_detail", "week_gauge", "trophees_tous",
            "accueil_prochain_trophee", "grade_titre", "action_back_to_session", "action_another_session",
            "action_start_session", "start_duration", "start_theme", "music_title", "start_focus", "music_off_summary",
            "music_none_summary",
            "music_shuffle_short", "start_focus_on", "start_focus_off", "session_theme_none_short",
            "session_theme_title", "settings_target", "duration_custom", "duration_custom_hint",
            "duration_custom_title", "action_back", "offline_which_day", "offline_today", "offline_yesterday",
            "offline_how_long", "week_shabbat_mark", "week_done", "week_todo", "settings_shabbat",
            "gate_exempt_title", "action_write_note", "action_done_offline", "trophees_paliers", "parcours_title",
            "bilan_titre", "bilan_minutes", "bilan_plus", "bilan_record", "bilan_trophees", "celebration_continue",
            "palier_n_jours", "siddur_maintenant", "levana_ce_soir", "moment_mot_matin", "moment_mot_journee",
            "moment_mot_soir", "moment_mot_nuit", "source_du_jour", "source_du_jour_lire",
            "rappel_pluie_debut_titre", "rappel_pluie_debut_edot", "rappel_pluie_debut", "rappel_pluie_fin_titre",
            "rappel_pluie_fin_edot", "rappel_pluie_fin", "rappel_guechem_titre", "rappel_guechem_debut",
            "rappel_guechem_fin", "rappel_dix_jours_titre", "rappel_dix_jours", "rappel_omer_titre", "rappel_omer",
            "rappel_source", "rappel_aujourdhui", "rappel_demain", "rappel_hier_soir", "rappel_motsae",
            "rappel_ce_soir", "rappel_demain_soir", "rappel_soir", "jour_rien", "jour_fait", "jour_ajouter_temps",
            "jour_montrer_duree", "jour_ajoute", "moment_relance", "jour_ciel", "nav_zmanim", "settings_title",
            "start_prepare", "start_focus_setup", "start_focus_stopped", "gate_window_title", "gate_done_title",
        ]
        for cle in cles {
            for langue in ["fr", "en", "he"] {
                let traduite = catalogue.strings[cle]?.localizations?[langue] != nil
                #expect(traduite, "\(cle) manque en \(langue)")
            }
        }
    }
}
