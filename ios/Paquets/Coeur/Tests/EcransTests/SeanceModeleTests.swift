import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran de séance (SessionActivity) : ce qu'il montre à l'arrêt et pendant la séance (le chiffre, la
/// légende, les boutons, la musique), le passage au bravo, l'abandon et « ’Hazak », le mot de 'hizouk de chaque
/// moment, la hitbodedout guidée, les questions, le sujet, la durée réglable, « Commencer simplement », la
/// pratique calme et la lueur du souffle. Avec une horloge que le test avance, un petit fichier de 'hizouk écrit
/// ici (mélange fixé) et le guide des sujets exporté.
///
/// Restent au test d'interface : la séance d'une minute menée par les boutons jusqu'au journal à l'écran, le
/// décompte qui défile (TimelineView), les fondus du calme et l'assombrissement du fond, les barres du système
/// cachées, la lueur qui respire et « Réduire les animations », le geste qui réveille sans toucher le bouton
/// dessous, l'écran gardé allumé, les dialogues, VoiceOver.
@Suite("Modèle de l'écran de séance")
@MainActor
struct SeanceModeleTests {

    /// Deux textes d'ouverture, un de blocage, un de clôture, un de relance ; tous publiables.
    static let petit = """
    {"_meta": {"version": "t", "editions": {
        "pd": {"titre": "PD", "licence": "Public Domain", "nikkoud_ok": true}}},
     "items": [
       {"id": "o1", "moments": ["ouverture"], "edition": "pd", "ref": "Tehilim 1:1", "he": "\u{05D0}",
        "fr": "O1 fr", "en": "O1 en", "statut_verif": "verifie_texte", "relu": true},
       {"id": "o2", "moments": ["ouverture"], "edition": "pd", "ref": "Tehilim 1:2", "he": "\u{05D1}",
        "fr": "O2 fr", "en": "O2 en", "statut_verif": "verifie_texte", "relu": true},
       {"id": "b1", "moments": ["blocage"], "edition": "pd", "ref": "Tehilim 1:3", "he": "\u{05D2}",
        "fr": "B1 fr", "en": "B1 en", "statut_verif": "verifie_texte", "relu": true},
       {"id": "c1", "moments": ["cloture"], "edition": "pd", "ref": "Tehilim 1:4", "he": "\u{05D3}",
        "fr": "C1 fr", "en": "", "statut_verif": "verifie_texte", "relu": true},
       {"id": "r1", "moments": ["relance"], "edition": "pd", "ref": "Tehilim 1:5", "he": "\u{05D4}",
        "fr": "R1 fr", "en": "R1 en", "statut_verif": "verifie_texte", "relu": true}
     ]}
    """

    /// Rien pour le blocage.
    static let sansBlocage = """
    {"_meta": {"version": "t", "editions": {
        "pd": {"titre": "PD", "licence": "Public Domain", "nikkoud_ok": true}}},
     "items": [
       {"id": "o1", "moments": ["ouverture"], "edition": "pd", "ref": "Tehilim 1:1", "he": "\u{05D0}",
        "fr": "O1 fr", "en": "O1 en", "statut_verif": "verifie_texte", "relu": true}
     ]}
    """

    /// Le petit fichier de 'hizouk, et les autres contenus tels qu'exportés.
    static func contenus(_ json: String = SeanceModeleTests.petit) -> ContenusApp {
        let donnees = Data(json.utf8)
        let exportes = ContenusApp.lecteur(dossier: Fichiers.contenu)
        return ContenusApp(lecteur: { chemin in try chemin == "chizuk.json" ? donnees : exportes(chemin) })
    }

    struct Banc {
        let modele: SeanceModele
        let seance: SeanceEnCours
        let magasin: Magasin
        let horloge: SeanceHorlogeReglable
        let contenus: ContenusApp
    }

    static func banc(_ dateHeure: DateHeure, fuseau: Fuseau = .utc, reglages: Reglages = Reglages(),
                     journal: Journal = Journal(), chizuk: String = SeanceModeleTests.petit) -> Banc {
        let magasin = Magasin.enMemoire(Enregistrement(journal: journal, reglages: reglages))
        let horloge = SeanceHorlogeReglable(dateHeure, fuseau: fuseau)
        let seance = SeanceEnCours(magasin: magasin, horloge: horloge, musique: SeanceFausseMusique())
        let fournis = Self.contenus(chizuk)
        let modele = SeanceModele(seance: seance, contenus: fournis, langue: "fr", debug: false, melange: { $0 })
        return Banc(modele: modele, seance: seance, magasin: magasin, horloge: horloge, contenus: fournis)
    }

    private static func duree(_ minutes: Int) -> Libelle {
        Store.formatDuration(minutes)
    }

    // MARK: À l'arrêt

    @Test func aLArretLEcranProposeLaDureeHabituelle() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        #expect(!b.modele.enCours)
        #expect(b.modele.titre == Libelle("session_screen_title"))
        #expect(b.modele.decompte == .duree(Self.duree(15)))
        #expect(b.modele.texteDecompte(a: b.horloge.maintenant) == nil)
        #expect(b.modele.decompteAccessible == nil)
        #expect(b.modele.legende == Libelle("session_idle_caption"))
        #expect(b.modele.libellePrincipal == Libelle("session_start", .libelle(Self.duree(15))))
        #expect(b.modele.libelleSecondaire == nil)
        #expect(b.modele.libelleSujet == Libelle("session_theme_none"))
        #expect(b.modele.choixVisibles)
        let minutes = b.modele.durees.map { $0.minutes }
        #expect(minutes == [5, 10, 15, 30, 60, 90])
        #expect(b.modele.durees[4].libelle == Libelle("duration_hours", .entier(1)))
        #expect(b.modele.durees[5].libelle == Libelle("duration_hours_minutes", .entier(1), .entier(30)))
        #expect(b.modele.guide == nil)
        #expect(b.modele.question == nil)
        #expect(!b.modele.blocageVisible)
        #expect(!b.modele.souffleActif)
        #expect(b.modele.image == Poses.call(jour))
        #expect(b.modele.route == nil)
        // Le mot d'ouverture, tiré en paraissant.
        let carte = try #require(b.modele.carte)
        #expect(carte.moment == .ouverture)
        #expect(carte.id == "o1")
        #expect(carte.titre == Libelle("moment_ouverture"))
        #expect(carte.texte == "\u{05D0}")
        #expect(carte.second == "O1 fr")
        #expect(carte.texteDroiteAGauche)
        #expect(carte.image == "char_open_arms")
    }

    @Test func rouvrirNeTirePasUnAutreMot() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        await b.modele.ouvrir()
        await b.modele.revenir()
        #expect(b.modele.carte?.id == "o1")
        #expect(b.modele.tirages == 1)
    }

    @Test func faiteAujourdhuiLaLegendeDitCeQuiAEteFait() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var journal = Journal()
        journal.addSession(minutes: 4, date: jour)
        let b = Self.banc(DateHeure(jour, heure: 18), journal: journal)
        await b.modele.ouvrir()
        #expect(b.modele.legende == Libelle("session_idle_done", .libelle(Self.duree(4))))
        // Le grand chiffre reste la durée de la prochaine.
        #expect(b.modele.decompte == .duree(Self.duree(15)))
        #expect(b.modele.image == Poses.joy(jour))
    }

    @Test func lePersonnageSuitLAdresse() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var reglages = Reglages()
        reglages.setAdresse("f")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        #expect(b.modele.image == Personnage.pour(.femme, Poses.call(jour)))
        #expect(b.modele.carte?.image == "char_f_arms_up")
    }

    // MARK: Le critère : une séance d'une minute jusqu'au bravo, la note, le journal

    @Test func uneSeanceDUneMinuteVaJusquAuBravoPuisALaNoteEtAuJournal() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.commencer(minutes: 1)

        #expect(b.modele.enCours)
        #expect(b.magasin.reglages.targetMinutes == 1)
        let debut = b.seance.debut
        #expect(b.modele.decompte == .reste(fin: debut + 60_000))
        #expect(b.modele.texteDecompte(a: debut + 15_000) == "00:45")
        #expect(b.modele.texteDecompte(a: debut + 90_000) == "00:00")
        #expect(b.modele.legende == Libelle("session_target", .libelle(Self.duree(1))))
        #expect(b.modele.libellePrincipal == Libelle("session_finish_now"))
        #expect(b.modele.libelleSecondaire == Libelle("session_cancel"))
        #expect(!b.modele.choixVisibles)
        #expect(b.modele.souffleActif)
        #expect(b.modele.image == Poses.during(jour))
        #expect(b.modele.carte?.moment == .ouverture)
        #expect(b.modele.decompteAccessible == Libelle("session_remaining", .libelle(Self.duree(1))))

        // La minute passe : la séance se clôt, le mot de clôture paraît, le bravo s'ouvre.
        b.horloge.avancer(secondes: 60)
        await b.modele.actualiser()
        #expect(!b.modele.enCours)
        let attendu = CelebrationDemande(minutes: 1, dateNote: jour)
        #expect(b.modele.route == .celebration(attendu))
        #expect(b.modele.carte?.moment == .cloture)
        #expect(b.modele.carte?.id == "c1")
        #expect(!b.magasin.reglages.hasPendingCelebration)

        // Le bravo.
        let bravo = CelebrationModele(demande: attendu, magasin: b.magasin, contenus: b.contenus, horloge: b.horloge,
                                      langue: "fr", debug: false)
        await bravo.charger()
        #expect(bravo.titre == Libelle("celebration_neutral"))
        #expect(bravo.sousTitre == Libelle.pluriel("celebration_minutes", quantite: 1, .entier(1)))
        #expect(bravo.danse)
        #expect(bravo.carte == nil)
        #expect(bravo.partageVisible)
        #expect(bravo.continuer() == .note(jour))

        // La note.
        let note = NoteModele(date: jour, magasin: b.magasin)
        #expect(note.texte == "")
        note.ecrire("  Merci pour aujourd’hui  ")
        note.choisirApres(4)
        note.ecrireGratitude("La lumière")
        try await note.enregistrer()
        b.modele.fermerRoute()

        // La journée, au journal.
        let journee = try #require(b.magasin.journal.record(jour))
        #expect(journee.minutes == 1)
        #expect(journee.note == "Merci pour aujourd’hui")
        #expect(journee.faite)
        #expect(b.magasin.journal.joursFaits.contains(jour))
        let plus = b.magasin.journal.lirePlus(jour)
        #expect(plus.apres == 5)
        #expect(plus.gratitude == "La lumière")
        // Le retour à l'écran : la journée est faite, aucun second bravo.
        await b.modele.actualiser()
        #expect(b.modele.route == nil)
        #expect(b.modele.legende == Libelle("session_idle_done", .libelle(Self.duree(1))))
    }

    @Test func leBravoAttenduAilleursSOuvreEnArrivant() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var reglages = Reglages()
        reglages.setPendingCelebration(minutes: 12, dateNote: "2026-11-15")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        let veille = try SeanceOutils.jour("2026-11-15")
        #expect(b.modele.route == .celebration(CelebrationDemande(minutes: 12, dateNote: veille)))
    }

    @Test func unAutreEcranOuvertRetientLeBravo() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.simplementPrier()
        #expect(b.modele.route == .tefilot)
        b.horloge.avancer(minutes: 15)
        await b.modele.actualiser()
        // Les prières sont par-dessus : le bravo attend leur fermeture.
        #expect(b.modele.route == .tefilot)
        #expect(b.magasin.reglages.hasPendingCelebration)
        b.modele.fermerRoute()
        await b.modele.actualiser()
        #expect(b.modele.route == .celebration(CelebrationDemande(minutes: 15, dateNote: jour)))
    }

    // MARK: Le critère : un abandon montre « ’Hazak ! » et n'inscrit rien

    @Test func unAbandonMontreHazakEtNInscritRien() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var reglages = Reglages()
        reglages.setAdresse("m")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        try await b.modele.commencer(minutes: 20)
        b.horloge.avancer(minutes: 5)
        await b.modele.actualiser()

        b.modele.secondaire()
        #expect(b.modele.dialogue == .abandonner)
        #expect(SeanceDialogue.abandonner.titre == Libelle("session_cancel_title"))
        #expect(SeanceDialogue.abandonner.message == Libelle("session_cancel_message"))
        #expect(SeanceDialogue.abandonner.confirmer == Libelle("session_cancel"))
        #expect(SeanceDialogue.abandonner.retour == Libelle("action_back"))
        #expect(SeanceDialogue.abandonner.destructif)
        try await b.modele.confirmerAbandonner()

        #expect(b.modele.dialogue == nil)
        #expect(!b.modele.enCours)
        #expect(b.modele.route == .celebration(.annulation))
        #expect(b.magasin.journal.record(jour) == nil)
        #expect(!b.magasin.reglages.hasPendingCelebration)
        // Pas de mot de clôture après un abandon, ni au tour suivant.
        await b.modele.actualiser()
        #expect(b.modele.carte?.moment == .ouverture)

        let hazak = CelebrationModele(demande: .annulation, magasin: b.magasin, contenus: b.contenus,
                                      horloge: b.horloge, langue: "fr", debug: false)
        await hazak.charger()
        #expect(hazak.titre == Libelle("annulation_hazak"))
        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: "fr")
        #expect(traducteur.texte(hazak.titre) == "\u{2019}Hazak\u{202F}!")
        #expect(hazak.sousTitre == Libelle("annulation_subtitle"))
        #expect(!hazak.danse)
        #expect(hazak.poseA == "char_walking")
        #expect(hazak.poseB == nil)
        #expect(!hazak.partageVisible)
        #expect(hazak.continuer() == .fermer)
        #expect(hazak.carte?.moment == .relance)
        #expect(hazak.carte?.id == "r1")
    }

    // MARK: Terminer

    @Test func terminerDemandeConfirmationEtAvantUneMinuteNInscritRien() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.commencer(minutes: 20)
        b.horloge.avancer(secondes: 40)
        try await b.modele.principal()
        #expect(b.modele.dialogue == .terminer)
        #expect(b.modele.enCours)
        #expect(SeanceDialogue.terminer.titre == Libelle("session_finish_title"))
        #expect(SeanceDialogue.terminer.message == Libelle("session_finish_message"))
        #expect(SeanceDialogue.terminer.confirmer == Libelle("session_finish_now"))
        try await b.modele.confirmerTerminer()
        #expect(!b.modele.enCours)
        #expect(b.modele.route == nil)
        #expect(b.magasin.journal.record(jour) == nil)
        // La séance close a son mot de fin, même sans minute.
        #expect(b.modele.carte?.moment == .cloture)
    }

    @Test func terminerApresTroisMinutesOuvreLeBravo() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.principal()
        #expect(b.seance.duree == 15)
        b.horloge.avancer(minutes: 3, secondes: 20)
        try await b.modele.principal()
        try await b.modele.confirmerTerminer()
        #expect(b.modele.route == .celebration(CelebrationDemande(minutes: 3, dateNote: jour)))
        #expect(b.magasin.journal.record(jour)?.minutes == 3)
    }

    @Test func uneSeanceCommenceeA23h59SInscritLaVeilleEtSaNoteAussi() async throws {
        let paris = try SeanceOutils.paris()
        let veille = try SeanceOutils.jour("2026-11-15")
        let b = Self.banc(DateHeure(veille, heure: 23, minute: 59), fuseau: paris)
        await b.modele.ouvrir()
        try await b.modele.commencer(minutes: 5)
        b.horloge.avancer(minutes: 5)
        await b.modele.actualiser()
        #expect(b.modele.route == .celebration(CelebrationDemande(minutes: 5, dateNote: veille)))
        #expect(b.magasin.journal.record(veille)?.minutes == 5)
    }

    // MARK: Les compteurs

    @Test func unDecompteMasqueNeMontreNiChiffreNiLueur() async throws {
        var reglages = Reglages()
        reglages.setHideCountdown(true)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        // À l'arrêt, la durée se montre quand même.
        #expect(b.modele.decompte == .duree(Self.duree(15)))
        try await b.modele.commencer(minutes: 10)
        #expect(b.modele.decompte == .masque)
        #expect(b.modele.texteDecompte(a: b.horloge.maintenant) == nil)
        #expect(b.modele.legende == Libelle("session_hidden_caption"))
        #expect(!b.modele.souffleActif)
        #expect(b.modele.decompteAccessible == Libelle("session_running_hidden"))
    }

    @Test func uneSeanceSansDureeCompteALEndroit() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.commencerSansDuree()
        #expect(b.seance.ouverte)
        // La durée habituelle ne bouge pas.
        #expect(b.magasin.reglages.targetMinutes == 15)
        let debut = b.seance.debut
        #expect(b.modele.decompte == .ecoule(debut: debut))
        #expect(b.modele.texteDecompte(a: debut + 65_000) == "01:05")
        #expect(b.modele.texteDecompte(a: debut - 5_000) == "00:00")
        #expect(b.modele.legende == Libelle("session_open_caption"))
        #expect(b.modele.souffleActif)
        #expect(b.modele.libelleSansDuree == Libelle("session_open"))
    }

    @Test func lesMinutesEtLesSecondesSEcriventSurDeuxChiffres() {
        #expect(SeanceModele.minutesSecondes(0) == "00:00")
        #expect(SeanceModele.minutesSecondes(59_999) == "00:59")
        #expect(SeanceModele.minutesSecondes(61_000) == "01:01")
        #expect(SeanceModele.minutesSecondes(14 * 60_000 + 59_000) == "14:59")
        #expect(SeanceModele.minutesSecondes(100 * 60_000) == "100:00")
    }

    // MARK: La musique

    @Test func laLigneDeMusique() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        let premier = try #require(MusicLibrary.selected(MusicLibrary.Etat()))
        guard case .libelle(let titre) = premier.title else {
            Issue.record("Un morceau livré se nomme par une chaîne")
            return
        }
        #expect(b.modele.ligneMusique == Libelle("session_music_line", .libelle(titre)))
        try await b.magasin.modifierReglages { $0.setMusicShuffle(true) }
        #expect(b.modele.ligneMusique == Libelle("session_music_line", .libelle(Libelle("music_shuffle_short"))))
        try await b.magasin.modifierReglages { $0.setMusicNow(premier.id) }
        #expect(b.modele.ligneMusique == Libelle("session_music_line", .libelle(titre)))
        try await b.magasin.modifierReglages { $0.setMusicEnabled(false) }
        #expect(b.modele.ligneMusique == nil)
    }

    // MARK: Les questions et le blocage

    @Test func uneQuestionALaFoisEtOnRecommenceApresLaDerniere() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.simplementQuestion()
        #expect(b.modele.enCours)
        let total = QuestionsBlocage.questions.count
        let premiere = try #require(b.modele.question)
        #expect(premiere.rang == 0)
        #expect(premiere.texte == Libelle(QuestionsBlocage.questions[0]))
        #expect(premiere.position == Libelle("question_rang", .entier(1), .entier(total)))
        #expect(premiere.progression == 100 / total)
        for _ in 0..<total {
            b.modele.questionSuivante()
        }
        #expect(b.modele.question?.rang == 0)
        #expect(b.modele.changementsQuestion == total)
        b.modele.questionSuivante()
        #expect(b.modele.question?.progression == 2 * 100 / total)
        // La séance close, la question s'en va.
        try await b.modele.principal()
        try await b.modele.confirmerTerminer()
        #expect(b.modele.question == nil)
    }

    @Test func jeNArrivePasAParlerDonneUnTexteEtUneQuestion() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        #expect(!b.modele.blocageVisible)
        try await b.modele.simplementParler()
        #expect(b.modele.blocageVisible)
        #expect(b.modele.libelleBlocage == Libelle("chizuk_stuck"))
        await b.modele.bloque()
        #expect(b.modele.carte?.moment == .blocage)
        #expect(b.modele.carte?.id == "b1")
        #expect(b.modele.carte?.titre == Libelle("moment_blocage"))
        #expect(b.modele.question?.rang == 0)
        b.modele.questionSuivante()
        await b.modele.bloque()
        // Une question déjà posée reste.
        #expect(b.modele.question?.rang == 1)
    }

    @Test func sansTexteDeBlocageLeBoutonSeCache() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), chizuk: Self.sansBlocage)
        await b.modele.ouvrir()
        try await b.modele.simplementParler()
        #expect(!b.modele.blocageVisible)
        // Rien de la clôture : la carte se cache.
        try await b.modele.principal()
        try await b.modele.confirmerTerminer()
        #expect(b.modele.carte == nil)
    }

    // MARK: La hitbodedout guidée

    @Test func leGuideMontreUnTempsALaFois() async throws {
        var reglages = Reglages()
        reglages.setGuidedHitbodedut(true)
        SeanceSujet.poser(.gratitude, dans: &reglages)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        #expect(b.modele.guide == nil)
        try await b.modele.simplementParler()

        let sujets = try GuideSujets.lire(Fichiers.donnees("ios/Ressources/Contenu/guide_sujets.json"))
        let premier = try #require(b.modele.guide)
        let mouvement = Hitbodedut.mouvements[0]
        #expect(premier.etape == 0)
        #expect(premier.rang == Libelle("hitbodedut_step", .entier(1), .entier(5)))
        #expect(premier.hebreu == mouvement.he)
        #expect(premier.titre == Libelle(mouvement.titre))
        #expect(premier.invitation == Libelle(mouvement.invite))
        #expect(premier.image == mouvement.illustration)
        #expect(premier.source == Reference.localise(mouvement.source, "fr"))
        #expect(premier.sujet != nil)
        #expect(premier.sujet == GuideSujets.invitation(sujets, theme: .gratitude, cle: mouvement.cle, langue: "fr"))
        #expect(!premier.precedentVisible)
        #expect(premier.suivantVisible)

        for _ in 0..<6 {
            b.modele.guideSuivant()
        }
        let dernier = try #require(b.modele.guide)
        #expect(dernier.etape == 4)
        #expect(dernier.precedentVisible)
        #expect(!dernier.suivantVisible)
        b.modele.guidePrecedent()
        #expect(b.modele.guide?.etape == 3)

        // Sans sujet, l'invitation du sujet se cache.
        try await b.modele.choisirSujet(nil)
        #expect(b.modele.guide?.sujet == nil)
        // « Autre chose » n'en a pas non plus.
        try await b.modele.choisirSujet(.autre)
        #expect(b.modele.guide?.sujet == nil)

        // Une nouvelle séance repart au premier temps.
        try await b.modele.principal()
        try await b.modele.confirmerTerminer()
        #expect(b.modele.guide == nil)
        try await b.modele.simplementParler()
        #expect(b.modele.guide?.etape == 0)
    }

    @Test func sansGuideDemandeRienNeParait() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.simplementParler()
        #expect(b.modele.guide == nil)
    }

    // MARK: Le sujet

    @Test func leSujetSeChoisitDansLaListeAucunEnTete() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        b.modele.choisirSujet()
        #expect(b.modele.dialogue == .sujet)
        #expect(SeanceDialogue.sujet.confirmer == nil)
        #expect(SeanceDialogue.sujet.retour == nil)
        let choix = b.modele.choixSujets
        #expect(choix.count == 11)
        #expect(choix[0].theme == nil)
        #expect(choix[0].libelle == Libelle("session_theme_none_short"))
        #expect(choix[1].theme == .emotions)
        #expect(choix[2].libelle == Libelle("theme_gratitude"))

        try await b.modele.choisirSujet(.gratitude)
        #expect(b.modele.dialogue == nil)
        #expect(b.modele.sujetChoisi == .gratitude)
        #expect(b.modele.libelleSujet == Libelle("session_theme_chosen", .libelle(Libelle("theme_gratitude"))))
        #expect(b.magasin.reglages.brut["session_theme"] == .chaine("gratitude"))
        try await b.modele.choisirSujet(nil)
        #expect(b.modele.libelleSujet == Libelle("session_theme_none"))
        #expect(b.magasin.reglages.brut["session_theme"] == nil)
    }

    // MARK: Les durées

    @Test func uneDureeProposeeDevientLaDureeHabituelle() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        try await b.modele.commencer(minutes: 30)
        #expect(b.seance.duree == 30)
        #expect(b.magasin.reglages.targetMinutes == 30)
        // Le mot d'ouverture est tiré de nouveau au départ.
        #expect(b.modele.carte?.id == "o2")
    }

    @Test func laDureeReglableVaDeUnADeuxCentQuarante() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        #expect(b.modele.libelleDureeReglable == Libelle("duration_custom"))
        b.modele.saisirDuree()
        #expect(b.modele.dialogue == .duree)
        #expect(b.modele.saisieInitiale == "15")
        #expect(b.modele.indicationDuree == Libelle("duration_custom_hint"))
        #expect(SeanceDialogue.duree.titre == Libelle("duration_custom_title"))

        // Pas un nombre, ou hors de 1 à 240 : la boîte reste ouverte et le dit (FACCUEIL-15).
        try await b.modele.validerDuree("douze")
        #expect(b.modele.dialogue == .duree)
        #expect(b.modele.erreurSaisie == Libelle("duration_custom_hint"))
        #expect(!b.modele.enCours)
        try await b.modele.validerDuree("999")
        try await b.modele.validerDuree("0")
        #expect(b.modele.dialogue == .duree)
        #expect(!b.modele.enCours)

        try await b.modele.validerDuree(" 25 ")
        #expect(b.modele.dialogue == nil)
        #expect(b.modele.erreurSaisie == nil)
        #expect(b.seance.duree == 25)
        #expect(b.magasin.reglages.targetMinutes == 25)
    }

    /// Android écrit la durée habituelle puis lance la séance, quoi qu'il arrive : un disque qui refuse ne la
    /// retient pas.
    @Test func uneDureeRefuseeParLeDisqueLanceQuandMemeLaSeance() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        let horloge = SeanceHorlogeReglable(DateHeure(jour, heure: 10))
        let seance = SeanceEnCours(magasin: magasin, horloge: horloge)
        let modele = SeanceModele(seance: seance, contenus: Self.contenus(), langue: "fr", debug: false,
                                  melange: { $0 })
        await modele.ouvrir()
        await persistance.faireEchouer(true)
        var refuse = false
        do {
            try await modele.commencer(minutes: 30)
        } catch is PersistanceEnMemoire.Echec {
            refuse = true
        }
        #expect(refuse)
        #expect(modele.enCours)
        #expect(seance.duree == 30)
        #expect(magasin.reglages.targetMinutes == 30)
    }

    // MARK: Commencer simplement, et la demande de départ

    @Test func ecrireOuvreLaNoteDuJourEtPrierLesPrieres() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        #expect(b.modele.libellesSimplement == [Libelle("simplement_parler"), Libelle("simplement_ecrire"),
                                                Libelle("simplement_prier"), Libelle("simplement_question")])
        try await b.modele.simplementEcrire()
        #expect(b.modele.enCours)
        #expect(b.modele.route == .note(jour))
        b.modele.fermerRoute()
        try await b.modele.simplementPrier()
        #expect(b.modele.route == .tefilot)
    }

    @Test func uneDemandeDeDepartLanceLaDureeHabituelleUneFois() async throws {
        var reglages = Reglages()
        reglages.setTargetMinutes(10)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir(.commencer)
        #expect(b.modele.enCours)
        #expect(b.seance.duree == 10)
        let debut = b.seance.debut
        b.horloge.avancer(minutes: 2)
        await b.modele.ouvrir(.commencer)
        #expect(b.seance.debut == debut)
    }

    // MARK: La pratique calme

    @Test func laPratiqueDevientCalmeApresSixSecondesSansGeste() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.modele.ouvrir()
        b.horloge.avancer(secondes: 10)
        await b.modele.actualiser()
        // À l'arrêt, rien ne s'efface.
        #expect(!b.modele.calme)

        try await b.modele.commencer(minutes: 10)
        b.horloge.avancer(secondes: 5)
        await b.modele.actualiser()
        #expect(!b.modele.calme)
        #expect(b.modele.opaciteEffacable == 1)
        b.horloge.avancer(secondes: 1)
        await b.modele.actualiser()
        #expect(b.modele.calme)
        #expect(b.modele.opaciteEffacable == 0)

        // Le premier toucher réveille et il est avalé ; le suivant passe.
        #expect(b.modele.toucher())
        #expect(!b.modele.calme)
        #expect(!b.modele.toucher())
        b.horloge.avancer(secondes: 5)
        await b.modele.actualiser()
        #expect(!b.modele.calme)
        b.horloge.avancer(secondes: 1)
        await b.modele.actualiser()
        #expect(b.modele.calme)

        // Avec VoiceOver, rien ne s'efface.
        b.modele.lecteurEcranChange(true)
        #expect(!b.modele.calme)
        b.horloge.avancer(secondes: 30)
        await b.modele.actualiser()
        #expect(!b.modele.calme)
        b.modele.lecteurEcranChange(false)

        // La séance finie, le calme s'en va.
        b.horloge.avancer(minutes: 10)
        await b.modele.actualiser()
        #expect(!b.modele.enCours)
        #expect(!b.modele.calme)
    }

    // MARK: Le souffle

    @Test func leSouffleGranditEnQuatreSecondesEtDecroitEnSix() {
        #expect(SeanceSouffle.phase(0) == 0)
        #expect(abs(SeanceSouffle.phase(2_000) - 0.5) < 1e-6)
        #expect(SeanceSouffle.phase(4_000) == 1)
        #expect(abs(SeanceSouffle.phase(7_000) - 0.5) < 1e-6)
        #expect(SeanceSouffle.phase(10_000) == 0)
        #expect(SeanceSouffle.phase(14_000) == 1)
        #expect(SeanceSouffle.phase(-6_000) == 1)
        #expect(SeanceSouffle.phase(1_000) < SeanceSouffle.phase(2_000))
        #expect(SeanceSouffle.phase(5_000) > SeanceSouffle.phase(6_000))
        #expect(abs(SeanceSouffle.echelle(0) - 0.78) < 1e-12)
        #expect(abs(SeanceSouffle.echelle(1) - 1) < 1e-12)
        #expect(abs(SeanceSouffle.opacite(0) - 0.16) < 1e-12)
        #expect(abs(SeanceSouffle.opacite(1) - 0.42) < 1e-12)
        #expect(SeanceSouffle.phaseImmobile == 0.6)
    }

    // MARK: Les chaînes

    /// Chaque clé que l'écran, le bravo et la note emploient est au catalogue, dans les trois langues (sauf
    /// `action_ok`, à ajouter).
    @Test func chaqueCleEstAuCatalogueEnTroisLangues() throws {
        let catalogue = try CatalogueBrut.lire()
        var cles: [String] = [
            "session_screen_title", "session_hidden_caption", "session_open_caption", "session_target",
            "session_idle_done", "session_idle_caption", "session_start", "session_finish_now", "session_cancel",
            "session_finish_title", "session_finish_message", "session_cancel_title", "session_cancel_message",
            "action_back", "session_theme_none", "session_theme_chosen", "session_theme_none_short",
            "session_theme_title", "session_music_line", "music_shuffle_short", "duration_custom",
            "duration_custom_hint", "duration_custom_title", "session_open", "simplement_parler",
            "simplement_ecrire", "simplement_prier", "simplement_question", "chizuk_stuck", "question_rang",
            "question_suivante", "hitbodedut_step", "hitbodedut_previous", "hitbodedut_next",
            "moment_ouverture", "moment_blocage", "moment_cloture", "moment_relance", "session_running_title",
            "session_running_hidden", "session_elapsed", "session_remaining", "duration_minutes", "duration_hours",
            "duration_hours_minutes", "celebration_neutral", "celebration_tsadik", "celebration_tsadeket",
            "annulation_neutral", "annulation_hazak", "annulation_hizki", "annulation_subtitle",
            "celebration_continue", "partage_action", "partage_texte", "partage_serie", "partage_lien",
            "partage_choix", "note_title", "note_hint", "journal_humeur_avant", "journal_humeur_apres",
            "journal_gratitude_hint", "journal_travail_hint", "action_save", "action_later", "note_discard",
            "celebration_titre",
        ]
        cles += QuestionsBlocage.questions
        cles += Theme.allCases.map { $0.titre }
        cles += Hitbodedut.mouvements.flatMap { [$0.titre, $0.invite] }
        for cle in cles {
            for langue in Traducteur.langues {
                #expect(catalogue.valeur(cle, langue: langue) != nil, "\(cle) en \(langue)")
            }
        }
        for cle in ["celebration_minutes", "partage_minutes"] {
            for langue in Traducteur.langues {
                #expect(catalogue.forme(cle, "other", langue: langue) != nil, "\(cle) en \(langue)")
            }
        }
    }
}
