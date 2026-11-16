import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le banc d'une présentation : sa persistance (qui compte les écritures), son magasin, un notificateur qui
/// accorde ou refuse, et des rappels qui retiennent chaque replanification.
@MainActor
private struct PresentationBanc {
    let persistance: PersistanceEnMemoire
    let magasin: Magasin
    let notificateur: FauxNotificateur
    let rappels: PresentationRappelsEnMemoire
    let modele: PresentationModele

    init(_ reglages: Reglages = Reglages(), index: Int = 0, accordee: Bool = true) {
        let enregistrement = Enregistrement(reglages: reglages)
        persistance = PersistanceEnMemoire(enregistrement)
        magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        notificateur = FauxNotificateur(accordee: accordee)
        rappels = PresentationRappelsEnMemoire()
        modele = PresentationModele(magasin: magasin, notificateur: notificateur, rappels: rappels, index: index)
    }
}

/// Les règles d'OnboardingActivity.kt qui se vérifient par des valeurs : quand la présentation se montre, ce
/// que porte chaque page, le parcours et ses sorties, les choix de l'adresse, de la durée et du rappel, et ce
/// qu'ils écrivent. La table des pages et ses bornes sont jugées dans CoeurTests (OnboardingTests).
@Suite("Modèle de la présentation")
@MainActor
struct PresentationModeleTests {

    // MARK: Quand la montrer

    @Test func laVersionDeLaPresentationEstCelleDesReglages() {
        #expect(Reglages.versionPresentation == Onboarding.version)
        #expect(Onboarding.version >= 2)
    }

    @Test func uneInstallationNeuveLaVoit() {
        let neuve = Reglages()
        #expect(PresentationModele.aMontrer(neuve))
    }

    /// MainActivity.showOnboardingOnce : une fois par version, installation existante comprise ; le booléen de
    /// la v1.96 ne la cache plus.
    @Test func uneInstallationExistanteLaRevoitUneFoisParVersion() throws {
        let v196 = try Reglages(texte: #"{"onboarded":true,"target_minutes":20}"#)
        #expect(PresentationModele.aMontrer(v196))
        let v1 = try Reglages(texte: #"{"onboarded_version":1}"#)
        #expect(PresentationModele.aMontrer(v1))
        let vue = try Reglages(texte: "{\"onboarded_version\":\(Onboarding.version)}")
        #expect(!PresentationModele.aMontrer(vue))
    }

    @Test func laFinLaRetientEtRetireLeBooleenDeLaV196() async throws {
        let reglages = try Reglages(texte: #"{"onboarded":true}"#)
        let banc = PresentationBanc(reglages)
        try await banc.modele.passer()
        #expect(banc.modele.termine)
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.hasOnboarded)
        let ancien = ecrits.brut.a("onboarded")
        #expect(!ancien)
        #expect(!PresentationModele.aMontrer(banc.magasin.reglages))
    }

    // MARK: Les pages

    @Test func laPremierePageOuvreLaPresentation() {
        let modele = PresentationModele.apercu()
        #expect(modele.index == 0)
        #expect(modele.nombreDePages == 7)
        #expect(modele.titre == Libelle("onboarding_practice"))
        #expect(modele.corps == Libelle("onboarding_practice_body"))
        #expect(modele.illustration == "char_open_arms")
        let etape = Libelle("onboarding_step", .entier(1), .entier(7))
        #expect(modele.etape == etape)
        #expect(!modele.retourVisible)
        #expect(modele.passerVisible)
        #expect(modele.libelleSuivant == Libelle("onboarding_next"))
        #expect(modele.libelleRetour == Libelle("onboarding_back"))
        #expect(modele.libellePasser == Libelle("onboarding_skip"))
        #expect(!modele.montreAdresse)
        #expect(!modele.montreDurees)
        #expect(!modele.montreRappel)
        #expect(!modele.termine)
        #expect(!modele.choixHeureOuvert)
    }

    @Test func leParcoursVaDePageEnPageJusquALaPromesse() async throws {
        let modele = PresentationModele.apercu()
        var cles: [String] = [modele.ecran.cle]
        for _ in 1..<Onboarding.ecrans.count {
            try await modele.suivant()
            cles.append(modele.ecran.cle)
        }
        #expect(cles == ["pratique", "seance", "jours", "textes", "reglages", "adresse", "prive"])
        #expect(modele.index == Onboarding.dernier)
        #expect(modele.estDerniere)
        #expect(modele.libelleSuivant == Libelle("onboarding_start"))
        #expect(!modele.passerVisible)
        #expect(modele.retourVisible)
        #expect(!modele.termine)
        let etape = Libelle("onboarding_step", .entier(7), .entier(7))
        #expect(modele.etape == etape)
    }

    /// La durée sur « seance », le rappel sur « jours », l'adresse sur « adresse » ; aucune autre page n'a de choix.
    @Test func chaquePageMontreSesChoixEtSeulementLesSiens() {
        for (rang, ecran) in Onboarding.ecrans.enumerated() {
            let modele = PresentationModele.apercu(index: rang)
            #expect(modele.ecran == ecran)
            #expect(modele.titre == Libelle(ecran.titre))
            #expect(modele.corps == Libelle(ecran.corps))
            #expect(modele.montreDurees == (ecran.cle == "seance"), "\(ecran.cle)")
            #expect(modele.montreRappel == (ecran.cle == "jours"), "\(ecran.cle)")
            #expect(modele.montreAdresse == (ecran.cle == "adresse"), "\(ecran.cle)")
            #expect(modele.retourVisible == (rang > 0), "\(ecran.cle)")
            #expect(modele.passerVisible == (rang < Onboarding.dernier), "\(ecran.cle)")
            let etape = Libelle("onboarding_step", .entier(rang + 1), .entier(7))
            #expect(modele.etape == etape)
        }
    }

    @Test func precedentRevientEtSArreteALaPremiere() {
        let modele = PresentationModele.apercu(index: 2)
        modele.precedent()
        #expect(modele.index == 1)
        modele.precedent()
        modele.precedent()
        #expect(modele.index == 0)
        #expect(!modele.termine)
    }

    @Test func unRangHorsBornesSeRameneDansLaPresentation() {
        let avant = PresentationModele.apercu(index: -4)
        #expect(avant.index == 0)
        let apres = PresentationModele.apercu(index: 40)
        #expect(apres.index == Onboarding.dernier)
    }

    // MARK: Les sorties

    @Test func commencerSurLaDernierePageFinitLaPresentation() async throws {
        let banc = PresentationBanc(index: Onboarding.dernier)
        try await banc.modele.suivant()
        #expect(banc.modele.termine)
        #expect(banc.modele.index == Onboarding.dernier)
        let vue = await banc.persistance.enregistrement.reglages.hasOnboarded
        #expect(vue)
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 1)
    }

    /// Elle se passe d'un geste, depuis n'importe quelle page.
    @Test func passerFinitDepuisNImporteQuellePage() async throws {
        for rang in Onboarding.ecrans.indices {
            let banc = PresentationBanc(index: rang)
            try await banc.modele.passer()
            #expect(banc.modele.termine)
            #expect(banc.magasin.reglages.hasOnboarded)
        }
    }

    @Test func terminerFermeLeChoixDeLHeure() async throws {
        let banc = PresentationBanc(index: 2)
        banc.modele.ouvrirChoixHeure()
        try await banc.modele.terminer()
        #expect(banc.modele.termine)
        #expect(!banc.modele.choixHeureOuvert)
    }

    /// Revue depuis les réglages : la première page, et rien de plus à écrire en sortant.
    @Test func laRevoirDepuisLesReglagesRepartDuDebutSansRienEcrire() async throws {
        var reglages = Reglages()
        reglages.setOnboarded()
        let banc = PresentationBanc(reglages)
        #expect(banc.modele.index == 0)
        try await banc.modele.passer()
        #expect(banc.modele.termine)
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 0)
    }

    /// « Passer », puis la feuille qui se retire et rappelle la fin (son `onDismiss`) : une seule écriture.
    @Test func terminerDeuxFoisNEcritQuUneFois() async throws {
        let banc = PresentationBanc(index: 3)
        try await banc.modele.passer()
        try await banc.modele.terminer()
        #expect(banc.modele.termine)
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 1)
    }

    /// Une rotation (ou une restauration d'état) reprend à la page où l'on était, ses choix compris.
    @Test func laPageRepriseGardeSesChoix() async throws {
        let banc = PresentationBanc(index: 1)
        try await banc.modele.choisirDuree(30)
        // L'écran recréé (rotation, restauration d'état) sur le même magasin, à la même page.
        let reprise = PresentationModele(magasin: banc.magasin, notificateur: banc.notificateur,
                                         rappels: banc.rappels, index: banc.modele.index)
        #expect(reprise.ecran.cle == "seance")
        #expect(reprise.montreDurees)
        let cochees = reprise.durees.filter { $0.choisie }.map { $0.minutes }
        #expect(cochees == [30])
        let etape = Libelle("onboarding_step", .entier(2), .entier(7))
        #expect(reprise.etape == etape)
        #expect(!reprise.termine)
    }

    /// Le glissement du `TabView` paginé : la page dite, ramenée dans les bornes, sans rien finir ni écrire.
    @Test func glisserAmeneLaPageSansRienFinir() async {
        let banc = PresentationBanc()
        banc.modele.afficher(page: 4)
        #expect(banc.modele.ecran.cle == "reglages")
        banc.modele.afficher(page: 99)
        #expect(banc.modele.index == Onboarding.dernier)
        banc.modele.afficher(page: -1)
        #expect(banc.modele.index == 0)
        #expect(!banc.modele.termine)
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 0)
    }

    @Test func uneEcritureRefuseeFermeQuandMemeLaPresentation() async throws {
        let banc = PresentationBanc()
        await banc.persistance.faireEchouer(true)
        var refusee = false
        do {
            try await banc.modele.passer()
        } catch is PersistanceEnMemoire.Echec {
            refusee = true
        }
        #expect(refusee)
        #expect(banc.modele.termine)
        // Le changement reste en mémoire : la prochaine écriture des réglages l'emportera.
        #expect(banc.magasin.reglages.hasOnboarded)
    }

    // MARK: La durée

    @Test func lesQuatreDureesEtLaDureeHabituelleCochee() {
        let modele = PresentationModele.apercu(index: 1)
        let minutes = modele.durees.map { $0.minutes }
        #expect(minutes == [5, 10, 15, 30])
        let libelles = modele.durees.map { $0.libelle }
        let attendus = [5, 10, 15, 30].map { Libelle("duration_minutes", .entier($0)) }
        #expect(libelles == attendus)
        // 15 minutes par défaut (Reglages.defaultTarget) : le troisième bouton.
        let cochees = modele.durees.filter { $0.choisie }.map { $0.minutes }
        #expect(cochees == [15])
    }

    @Test func choisirUneDureeLaRegleEtLaCoche() async throws {
        let banc = PresentationBanc(index: 1)
        try await banc.modele.choisirDuree(30)
        #expect(banc.magasin.reglages.targetMinutes == 30)
        let cochees = banc.modele.durees.filter { $0.choisie }.map { $0.minutes }
        #expect(cochees == [30])
        let ecrite = await banc.persistance.enregistrement.reglages.targetMinutes
        #expect(ecrite == 30)
    }

    @Test func uneDureeQuiNestPasDeLaPageEstIgnoree() async throws {
        let banc = PresentationBanc(index: 1)
        try await banc.modele.choisirDuree(20)
        #expect(banc.magasin.reglages.targetMinutes == Reglages.defaultTarget)
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 0)
    }

    /// selectionRequired d'Android : toucher la durée déjà cochée la laisse cochée, sans rien écrire.
    @Test func retoucherLaDureeCocheeNEcritRien() async throws {
        let banc = PresentationBanc(index: 1)
        try await banc.modele.choisirDuree(Reglages.defaultTarget)
        let cochees = banc.modele.durees.filter { $0.choisie }.map { $0.minutes }
        #expect(cochees == [Reglages.defaultTarget])
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 0)
    }

    @Test func uneDureeRegleeAilleursNeCocheAucunBouton() {
        var reglages = Reglages()
        reglages.setTargetMinutes(20)
        let modele = PresentationModele.apercu(reglages: reglages, index: 1)
        let cochees = modele.durees.filter { $0.choisie }
        #expect(cochees.isEmpty)
    }

    // MARK: L'adresse

    @Test func sansChoixAucuneAdresseNEstCochee() {
        let modele = PresentationModele.apercu(index: 5)
        #expect(modele.ecran.cle == "adresse")
        #expect(modele.adresse == nil)
        let adresses = modele.adresses.map { $0.adresse }
        #expect(adresses == [Adresse.homme, Adresse.femme])
        let libelles = modele.adresses.map { $0.libelle }
        #expect(libelles == [Libelle("adresse_tsadik"), Libelle("adresse_tsadeket")])
        let cochees = modele.adresses.filter { $0.choisie }
        #expect(cochees.isEmpty)
        #expect(modele.illustration == "char_dancing")
    }

    @Test func choisirTsadeketChangeLImageSurLaPageMeme() async throws {
        let banc = PresentationBanc(index: 5)
        try await banc.modele.choisirAdresse(.femme)
        #expect(banc.magasin.reglages.adresse == "f")
        #expect(banc.modele.adresse == Adresse.femme)
        let cochees = banc.modele.adresses.filter { $0.choisie }.map { $0.adresse }
        #expect(cochees == [Adresse.femme])
        #expect(banc.modele.illustration == "char_f_dancing")
        // Toucher encore צדקת ne retire pas le choix ; צדיק le change.
        try await banc.modele.choisirAdresse(.femme)
        #expect(banc.modele.adresse == Adresse.femme)
        try await banc.modele.choisirAdresse(.homme)
        #expect(banc.magasin.reglages.adresse == "m")
        #expect(banc.modele.illustration == "char_dancing")
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 2)
        let ecrite = await banc.persistance.enregistrement.reglages.adresse
        #expect(ecrite == "m")
    }

    /// Les illustrations suivent l'adresse (Personnage.pour) sur toutes les pages.
    @Test func lesImagesDeToutesLesPagesSuiventLAdresse() {
        var femme = Reglages()
        femme.setAdresse(Adresse.femme.cle)
        var homme = Reglages()
        homme.setAdresse(Adresse.homme.cle)
        for rang in Onboarding.ecrans.indices {
            let ecran = Onboarding.ecrans[rang]
            let sansChoix = PresentationModele.apercu(index: rang).illustration
            #expect(sansChoix == ecran.illustration)
            let tsadik = PresentationModele.apercu(reglages: homme, index: rang).illustration
            #expect(tsadik == ecran.illustration)
            let tsadeket = PresentationModele.apercu(reglages: femme, index: rang).illustration
            let feminine = Personnage.feminin(ecran.illustration)
            #expect(tsadeket == feminine)
            #expect(tsadeket != ecran.illustration, "\(ecran.cle) : pas de pose féminine")
        }
        let premiere = PresentationModele.apercu(reglages: femme).illustration
        #expect(premiere == "char_f_arms_up")
    }

    // MARK: Le rappel

    @Test func laPageDesJoursMontreLeRappelEteintASeptHeures() {
        let modele = PresentationModele.apercu(index: 2)
        #expect(modele.montreRappel)
        #expect(!modele.rappelActif)
        #expect(modele.heureRappel == 7 * 60)
        #expect(modele.heureRappelHeure == 7)
        #expect(modele.heureRappelMinute == 0)
        #expect(modele.libelleRappel == Libelle("onboarding_rappel"))
        let bouton = modele.libelleHeureRappel("07:00")
        let attendu = Libelle("onboarding_rappel_heure", .texte("07:00"))
        #expect(bouton == attendu)
        let description = modele.descriptionHeureRappel("7:00 AM")
        let attendue = Libelle("onboarding_rappel_heure_desc", .texte("7:00 AM"))
        #expect(description == attendue)
    }

    @Test func leBoutonMontreLaPremiereDesHeuresReglees() {
        var reglages = Reglages()
        reglages.setReminderTimes([1260, 495])
        let modele = PresentationModele.apercu(reglages: reglages, index: 2)
        #expect(modele.heureRappel == 495)
        #expect(modele.heureRappelHeure == 8)
        #expect(modele.heureRappelMinute == 15)
    }

    /// L'heure unique d'avant la liste, telle qu'écrite : 25 h se lit 1 h, comme Android l'écrit.
    @Test func uneHeureHorsDuJourSeRameneDansLeJour() throws {
        let reglages = try Reglages(texte: #"{"reminder_minutes":1500}"#)
        let modele = PresentationModele.apercu(reglages: reglages, index: 2)
        #expect(modele.heureRappelHeure == 1)
        #expect(modele.heureRappelMinute == 0)
    }

    @Test func allumerLeRappelDemandeLAutorisationEtReplanifie() async throws {
        let banc = PresentationBanc(index: 2, accordee: false)
        try await banc.modele.basculerRappel(true)
        #expect(banc.modele.rappelActif)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 1)
        // Refusée : le rappel reste réglé, comme sur Android.
        #expect(banc.modele.notificationsRefusees)
        let replanifications = await banc.rappels.replanifications
        let actifs = replanifications.map { $0.reminderEnabled }
        #expect(actifs == [true])
        let ecrit = await banc.persistance.enregistrement.reglages.reminderEnabled
        #expect(ecrit)
    }

    @Test func uneAutorisationDejaAccordeeNeSeRedemandePas() async throws {
        let banc = PresentationBanc(index: 2, accordee: true)
        try await banc.modele.basculerRappel(true)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
        #expect(!banc.modele.notificationsRefusees)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
    }

    @Test func eteindreLeRappelReplanifieSansRienDemander() async throws {
        var reglages = Reglages()
        reglages.setReminderEnabled(true)
        let banc = PresentationBanc(reglages, index: 2, accordee: false)
        try await banc.modele.basculerRappel(false)
        #expect(!banc.modele.rappelActif)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
        let replanifications = await banc.rappels.replanifications
        let actifs = replanifications.map { $0.reminderEnabled }
        #expect(actifs == [false])
    }

    @Test func lInterrupteurRemisASaPlaceNeFaitRien() async throws {
        let banc = PresentationBanc(index: 2)
        try await banc.modele.basculerRappel(false)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.isEmpty)
        let ecritures = await banc.persistance.ecrituresReglages
        #expect(ecritures == 0)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
    }

    @Test func unRappelAllumeSurUnDisqueQuiRefuseSeReplanifieQuandMeme() async throws {
        let banc = PresentationBanc(index: 2)
        await banc.persistance.faireEchouer(true)
        var refusee = false
        do {
            try await banc.modele.basculerRappel(true)
        } catch is PersistanceEnMemoire.Echec {
            refusee = true
        }
        #expect(refusee)
        #expect(banc.modele.rappelActif)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
    }

    @Test func ouvrirPuisFermerLeChoixDeLHeureNeChangeRien() async {
        let banc = PresentationBanc(index: 2)
        banc.modele.ouvrirChoixHeure()
        #expect(banc.modele.choixHeureOuvert)
        banc.modele.fermerChoixHeure()
        #expect(!banc.modele.choixHeureOuvert)
        #expect(!banc.modele.rappelActif)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.isEmpty)
    }

    /// OnboardingActivity.choisirHeure : la première heure est remplacée, les autres restent ; le rappel s'allume.
    @Test func choisirLHeureRemplaceLaPremiereEtAllumeLeRappel() async throws {
        var reglages = Reglages()
        reglages.setReminderTimes([480, 1260])
        let banc = PresentationBanc(reglages, index: 2, accordee: false)
        banc.modele.ouvrirChoixHeure()
        try await banc.modele.choisirHeureRappel(heure: 21, minute: 30)
        #expect(!banc.modele.choixHeureOuvert)
        // 8 h devient 21 h 30 ; 21 h reste ; la liste se retrie.
        #expect(banc.magasin.reglages.reminderTimes == [1260, 1290])
        #expect(banc.modele.heureRappel == 1260)
        #expect(banc.modele.rappelActif)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 1)
        let replanifications = await banc.rappels.replanifications
        let heures = replanifications.map { $0.reminderTimes }
        #expect(heures == [[1260, 1290]])
        // L'ancienne clé suit la première heure, pour l'export.
        #expect(banc.magasin.reglages.reminderMinutes == 1260)
        let ecrites = await banc.persistance.enregistrement.reglages.reminderTimes
        #expect(ecrites == [1260, 1290])
    }

    @Test func choisirLHeureAvecLAutorisationDejaAccordeeNeRedemandeRien() async throws {
        let banc = PresentationBanc(index: 2, accordee: true)
        try await banc.modele.choisirHeureRappel(heure: 7, minute: 45)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
        #expect(!banc.modele.notificationsRefusees)
        #expect(banc.modele.rappelActif)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
    }

    @Test func choisirLHeureSansListeReglee() async throws {
        let banc = PresentationBanc(index: 2)
        try await banc.modele.choisirHeureRappel(heure: 6, minute: 5)
        #expect(banc.magasin.reglages.reminderTimes == [365])
        #expect(banc.modele.heureRappelHeure == 6)
        #expect(banc.modele.heureRappelMinute == 5)
        #expect(banc.modele.rappelActif)
    }

    // MARK: Les chaînes et les images

    @Test func lesChainesDeLaPresentationSontAuCatalogueDansLesTroisLangues() throws {
        let catalogue = try CatalogueBrut.lire()
        let modele = PresentationModele.apercu()
        var libelles: [Libelle] = [modele.libelleSuivant, modele.libelleRetour, modele.libellePasser,
                                   modele.libelleRappel, modele.etape, Libelle("onboarding_start"),
                                   modele.libelleHeureRappel("7:00"), modele.descriptionHeureRappel("7:00")]
        libelles += modele.durees.map { $0.libelle }
        libelles += modele.adresses.map { $0.libelle }
        for rang in Onboarding.ecrans.indices {
            let page = PresentationModele.apercu(index: rang)
            libelles += [page.titre, page.corps]
        }
        for libelle in libelles {
            for langue in Traducteur.langues {
                let valeur = catalogue.valeur(libelle.cle, langue: langue)
                #expect(valeur != nil, "« \(libelle.cle) » manque en \(langue)")
            }
        }
    }

    @Test func lesLibellesSeResolventCommeSurAndroid() throws {
        let donnees = try Fichiers.catalogue()
        let francais = try Traducteur(catalogue: donnees, langue: "fr")
        let anglais = try Traducteur(catalogue: donnees, langue: "en")
        let modele = PresentationModele.apercu(index: 2)
        #expect(francais.texte(modele.etape) == "3 / 7")
        #expect(anglais.texte(modele.etape) == "3 / 7")
        #expect(francais.texte(modele.libelleHeureRappel("07:00")) == "à 07:00")
        #expect(anglais.texte(modele.libelleHeureRappel("7:00 AM")) == "at 7:00 AM")
        let trouvee = modele.durees.first { $0.minutes == 15 }
        let quinze = try #require(trouvee)
        #expect(francais.texte(quinze.libelle) == "15 min")
        // L'hébreu dit « 3 sur 7 » ; la vue le pose de droite à gauche.
        let hebreu = try Traducteur(catalogue: donnees, langue: "he")
        #expect(hebreu.texte(modele.etape) == "3 מתוך 7")
        let trente = PresentationModele.apercu(index: 1).durees.last
        let derniere = try #require(trente)
        #expect(derniere.minutes == 30)
        #expect(anglais.texte(derniere.libelle) == "30 min")
    }

    /// Chaque image de la présentation, et sa pose féminine, est livrée (ios/Ressources/Images).
    @Test func lesImagesDeLaPresentationSontLivrees() throws {
        let dossier = Fichiers.racine.appendingPathComponent("ios/Ressources/Images")
        let fichiers = try FileManager.default.contentsOfDirectory(atPath: dossier.path)
        let noms = Set(fichiers.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent })
        for ecran in Onboarding.ecrans {
            for nom in [ecran.illustration, Personnage.feminin(ecran.illustration)] {
                #expect(noms.contains(nom), "« \(nom) » n'est pas livrée")
            }
        }
    }
}
