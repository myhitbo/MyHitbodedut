import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran « Je viens d'Android » de la présentation (PORTAGE.md § 3.8 ; ROADMAP, tâche 15 : « il importe un
/// fichier d'or […] et lit la série attendue »). L'import passe par celui des réglages (`ReglagesModele`, qui se
/// conforme à `PresentationImport`) : une seule fusion, celle de Sauvegarde.importer, que ReglagesModeleTests et
/// SauvegardeTests jugent en détail. Ici : quand l'écran se montre, ce qu'il dit avant et après, ce qui est écrit,
/// et la suite vers les pages.
///
/// Deux fichiers d'or :
/// - la sauvegarde qu'écrit le vrai Store.exportJson d'Android sur la JVM (le scénario « aller-retour vers un
///   téléphone neuf » de `Tests/Vecteurs/sauvegarde.json`, tools/vecteurs_ios/VecteursSauvegarde.kt) ;
/// - `Tests/Sauvegardes/android-v1-presentation.json`, écrit à la main au format exact de Store.exportJson
///   (JSONObject.toString(2), les clés dans l'ordre d'Android) avec des journées récentes, pour une série en
///   cours. La vraie sauvegarde du propriétaire (préalable P7) viendra la rejoindre. Il n'est pas sous
///   `Tests/Ressources`, que l'export des contenus vide et réécrit.
@Suite("Présentation : « Je viens d'Android »")
@MainActor
struct PresentationAndroidTests {

    /// Une liste de morceaux livrés, au format de musique.json (comme ReglagesModeleTests).
    private static func lecteurMusique(_ ids: [String]) -> ContenusApp.Lecteur {
        let objets = ids.map { #"{"id":"\#($0)","titre":"track_\#($0)","fichier":"Musique/\#($0).m4a","octets":1}"# }
        let texte = "[" + objets.joined(separator: ",") + "]"
        return { chemin in chemin == "musique.json" ? Data(texte.utf8) : nil }
    }

    /// Le banc : un magasin dont la persistance compte les écritures, l'onglet Réglages qui importe, et la
    /// présentation qui le lui demande.
    @MainActor
    private struct Banc {
        let persistance: PersistanceEnMemoire
        let magasin: Magasin
        let reglages: ReglagesModele
        let effets: ReglagesFauxEffets
        let notificateur: FauxNotificateur
        let rappels: PresentationRappelsEnMemoire
        let modele: PresentationModele

        init(_ enregistrement: Enregistrement = Enregistrement(), jour: JourCivil, fuseau: Fuseau = .utc,
             morceaux: [String] = ["hamelech_basade"], avecBarriere: Bool = true, index: Int = 0,
             accordee: Bool = true) {
            let persistance = PersistanceEnMemoire(enregistrement)
            let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
            let horloge = HorlogeFixe(DateHeure(jour, heure: 9), fuseau: fuseau)
            let effets = ReglagesFauxEffets()
            let reglages = ReglagesModele(magasin: magasin,
                                          contenus: ContenusApp(lecteur: PresentationAndroidTests.lecteurMusique(morceaux)),
                                          horloge: horloge, notificateur: FauxNotificateur(),
                                          tempsEcran: FauxTempsEcran(), activite: FausseActiviteEnDirect(),
                                          barriere: ReglagesFausseBarriere(), icone: ReglagesFausseIcone(),
                                          effets: effets, avecBarriere: avecBarriere, langue: "fr",
                                          version: ReglagesVersion(nom: "1.0", numero: 1))
            let android = PresentationAndroid(importeur: reglages, horloge: horloge, avecBarriere: avecBarriere)
            self.persistance = persistance
            self.magasin = magasin
            self.reglages = reglages
            self.effets = effets
            let notificateur = FauxNotificateur(accordee: accordee)
            let rappels = PresentationRappelsEnMemoire()
            self.notificateur = notificateur
            self.rappels = rappels
            modele = PresentationModele(magasin: magasin, notificateur: notificateur,
                                        rappels: rappels, index: index, android: android)
        }
    }

    /// Le mercredi 25 novembre 2026, le lendemain de l'export du fichier d'or.
    private static func mercredi() throws -> JourCivil {
        try #require(JourCivil(iso: "2026-11-25"))
    }

    private static func fichierDOr() throws -> Data {
        try Fichiers.donnees("ios/Paquets/Coeur/Tests/Sauvegardes/android-v1-presentation.json")
    }

    // MARK: Le vrai export d'Android

    private struct Scenario: Decodable {
        let nom: String
        let fuseau: String
        let fichier: String
        let importe: Int?
    }

    private struct Meta: Decodable {
        let aujourdhui: String
        let morceauxLivres: [String]
    }

    private struct Vecteurs: Decodable {
        let meta: Meta
        let scenarios: [Scenario]

        enum CodingKeys: String, CodingKey {
            case meta = "_meta"
            case scenarios
        }
    }

    /// Ce qu'écrit Store.exportJson sur un téléphone Android rempli, importé sur un iPhone neuf par la
    /// présentation : les journées, le prénom, l'adresse, la durée et le rappel sont là avant la première page.
    @Test func laSauvegardeQuEcritAndroidSeRelitParLaPresentation() async throws {
        let v = try JSONDecoder().decode(Vecteurs.self,
                                         from: Fichiers.donnees("ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde.json"))
        let trouves = v.scenarios.filter { $0.nom == "aller-retour vers un téléphone neuf" }
        let s = try #require(trouves.first)
        let attendues = try #require(s.importe)
        let jour = try #require(JourCivil(iso: v.meta.aujourdhui))
        let fuseau = try #require(Fuseau(s.fuseau))
        let banc = Banc(jour: jour, fuseau: fuseau, morceaux: v.meta.morceauxLivres)
        let m = banc.modele

        // Un téléphone neuf : l'écran se montre avant les pages.
        #expect(m.montreAndroid)
        #expect(m.titreAndroid == Libelle("presentation_android_titre"))
        #expect(m.illustrationAndroid == "char_welcome")
        #expect(m.bilanAndroid == nil)
        #expect(m.serieAndroid == nil)
        #expect(m.refusAndroid == nil)
        #expect(!m.importReussi)

        m.ouvrirImport()
        #expect(m.importOuvert)
        await m.importer(Data(s.fichier.utf8))
        #expect(!m.importOuvert)
        #expect(!m.importEnCours)
        let message = Libelle.pluriel("import_ok", quantite: attendues, .entier(attendues))
        let attendu: PresentationImportResultat = .importe(journees: attendues, message: message)
        #expect(m.resultatImport == attendu)
        #expect(m.importReussi)
        #expect(m.bilanAndroid == message)
        #expect(m.titreAndroid == Libelle("presentation_android_retrouve"))
        #expect(m.corpsAndroid == Libelle("presentation_android_suite"))
        // Des journées de mars 2025, relues le 1er janvier 2026 : pas de série en cours.
        #expect(m.serieAndroid == nil)
        // Trois applications retenues sur Android, qui ne migrent pas.
        #expect(m.applicationsAndroid == Libelle("presentation_android_applications", .libelle(Libelle("section_gate"))))

        // Les réglages repris se voient déjà : l'image au féminin, le rappel et son heure.
        #expect(m.adresse == .femme)
        #expect(m.illustrationAndroid == "char_f_thumbs_up")
        #expect(m.rappelActif)
        #expect(m.heureRappel == 300)
        // 40 minutes : aucune des quatre durées de la page n'est cochée.
        let cochees = m.durees.filter { $0.choisie }.map { $0.minutes }
        #expect(cochees.isEmpty)
        #expect(banc.magasin.journal.prenom == "יֹאֵל")
        let dates = banc.magasin.journal.dates.count
        #expect(dates == 2)

        // Écrit, et répercuté (barrière, notifications, widgets) ; le message n'est pas resté aux réglages.
        let enregistre = await banc.persistance.enregistrement
        #expect(enregistre.journal == banc.magasin.journal)
        #expect(enregistre.reglages == banc.magasin.reglages)
        let demandes = await banc.effets.demandes
        #expect(demandes == [.tout])
        #expect(banc.reglages.message == nil)

        // « Suivant » : la première page, la présentation pas encore vue.
        m.quitterAndroid()
        #expect(!m.montreAndroid)
        #expect(m.index == 0)
        #expect(m.titre == Libelle("onboarding_practice"))
        #expect(!m.termine)
        #expect(!banc.magasin.reglages.hasOnboarded)
    }

    // MARK: Le fichier d'or

    /// Le fichier d'or, importé le lendemain de son export : douze journées (la note seule du 13 comprise), et la
    /// série du 15 au 24 novembre, les deux Chabbat exemptés et la note seule du 13 qui l'arrête : neuf jours.
    @Test func leFichierDOrDitLesJourneesEtLaSerieAttendue() async throws {
        let jour = try PresentationAndroidTests.mercredi()
        let fichier = try PresentationAndroidTests.fichierDOr()
        let banc = Banc(jour: jour)
        let m = banc.modele
        await m.importer(fichier)

        let message = Libelle.pluriel("import_ok", quantite: 12, .entier(12))
        #expect(m.bilanAndroid == message)
        #expect(m.serieAndroid == Libelle.pluriel("status_streak", quantite: 9, .entier(9)))
        #expect(m.applicationsAndroid == Libelle("presentation_android_applications", .libelle(Libelle("section_gate"))))

        // Les journées : la note seule ne fait pas la journée.
        let journal = banc.magasin.journal
        let dates = journal.dates.count
        #expect(dates == 12)
        let treize = try #require(JourCivil(iso: "2026-11-13"))
        let noteSeule = try #require(journal[treize])
        #expect(!noteSeule.faite)
        let quinze = try #require(JourCivil(iso: "2026-11-15"))
        #expect(journal[quinze] == Journee(minutes: 30, note: "", themes: ["famille", "parnassa"]))
        #expect(journal.prenom == "Myriam")

        // Les réglages repris, dont la page des durées et celle du rappel.
        let reglages = banc.magasin.reglages
        #expect(m.adresse == .femme)
        #expect(m.illustrationAndroid == "char_f_thumbs_up")
        let cochees = m.durees.filter { $0.choisie }.map { $0.minutes }
        #expect(cochees == [30])
        #expect(m.rappelActif)
        #expect(m.heureRappel == 450)
        #expect(reglages.musicTrackId == "hamelech_basade")
        #expect(reglages.pausedDates == ["2026-10-05"])
        #expect(reglages.blockedApps == ["com.instagram.android", "com.whatsapp"])
        let enregistre = await banc.persistance.enregistrement
        #expect(enregistre.reglages == reglages)
        #expect(enregistre.journal == journal)
        // Les notifications déjà accordées : rien à demander, les effets des réglages ont replanifié.
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.isEmpty)
    }

    /// Le rappel repris allumé, sans l'autorisation des notifications : elle se demande dès l'import, comme
    /// l'interrupteur de la page « jours », et les rappels se replanifient. Refusée, le rappel reste réglé.
    @Test func unRappelReprisSansAutorisationLaDemande() async throws {
        let jour = try PresentationAndroidTests.mercredi()
        let fichier = try PresentationAndroidTests.fichierDOr()
        let banc = Banc(jour: jour, accordee: false)
        await banc.modele.importer(fichier)
        #expect(banc.modele.importReussi)
        #expect(banc.modele.rappelActif)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 1)
        #expect(banc.modele.notificationsRefusees)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications == [banc.magasin.reglages])
    }

    /// L'édition légère n'a pas la barrière : rien à dire des applications retenues sur Android.
    @Test func lEditionLegereNeParlePasDesApplications() async throws {
        let jour = try PresentationAndroidTests.mercredi()
        let fichier = try PresentationAndroidTests.fichierDOr()
        let banc = Banc(jour: jour, avecBarriere: false)
        await banc.modele.importer(fichier)
        #expect(banc.modele.importReussi)
        #expect(banc.modele.applicationsAndroid == nil)
    }

    // MARK: Les refus

    /// Un fichier qui n'est pas une sauvegarde, ou illisible : l'écran le dit, reste, et rien n'est écrit ; un
    /// bon fichier choisi ensuite s'importe.
    @Test func unFichierRefuseLaisseLEcranEtNeChangeRien() async throws {
        let jour = try PresentationAndroidTests.mercredi()
        let fichier = try PresentationAndroidTests.fichierDOr()
        let banc = Banc(jour: jour)
        let m = banc.modele
        await m.importer(Data("pas du JSON".utf8))
        let invalide: PresentationImportResultat = .refuse(Libelle("import_invalid"))
        #expect(m.resultatImport == invalide)
        #expect(m.refusAndroid == Libelle("import_invalid"))
        #expect(m.montreAndroid)
        #expect(!m.importReussi)
        #expect(m.bilanAndroid == nil)
        #expect(m.serieAndroid == nil)
        #expect(m.applicationsAndroid == nil)
        #expect(m.titreAndroid == Libelle("presentation_android_titre"))
        await m.importer(nil)
        #expect(m.refusAndroid == Libelle("import_failed"))
        let ecritures = await banc.persistance.ecrituresJournal + banc.persistance.ecrituresReglages
        #expect(ecritures == 0)
        let demandes = await banc.effets.demandes
        #expect(demandes.isEmpty)
        #expect(banc.reglages.message == nil)

        await m.importer(fichier)
        #expect(m.importReussi)
        #expect(m.refusAndroid == nil)
    }

    // MARK: Quand l'écran se montre

    @Test func lEcranNeSeMontreQueSurUnTelephoneNeufAuDepart() throws {
        let jour = try PresentationAndroidTests.mercredi()
        // Sans import offert (« Revoir la présentation », les aperçus) : les pages d'emblée.
        let sansImport = PresentationModele.apercu()
        #expect(!sansImport.montreAndroid)
        // Un téléphone neuf, à la première page : l'écran.
        let neuf = Banc(jour: jour)
        #expect(neuf.modele.montreAndroid)
        // Une page restaurée : les pages.
        let restauree = Banc(jour: jour, index: 3)
        #expect(!restauree.modele.montreAndroid)
        #expect(restauree.modele.index == 3)
        // Un journal déjà rempli (une présentation revue après une nouvelle version) : les pages.
        var journal = Journal()
        journal[jour] = Journee(minutes: 15, note: "", themes: [])
        let rempli = Banc(Enregistrement(journal: journal), jour: jour)
        #expect(!rempli.modele.montreAndroid)
        // Les pages ignorent les gestes de l'écran.
        rempli.modele.ouvrirImport()
        #expect(!rempli.modele.importOuvert)
        // L'aperçu de l'écran.
        let apercu = PresentationModele.apercu(importAndroid: .refuse(Libelle("import_invalid")))
        #expect(apercu.montreAndroid)
    }

    /// « Non, je commence ici » : la première page, sans rien écrire ; l'écran ne revient pas et un fichier choisi
    /// ensuite n'est pas importé.
    @Test func passerMeneALaPremierePageSansRienEcrire() async throws {
        let faux = PresentationFauxImport(resultat: .importe(journees: 1, message: Libelle.pluriel("import_ok", quantite: 1, .entier(1))))
        let jour = try PresentationAndroidTests.mercredi()
        let horloge = HorlogeFixe(DateHeure(jour, heure: 9), fuseau: .utc)
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        let m = PresentationModele(magasin: magasin, notificateur: FauxNotificateur(),
                                   rappels: PresentationRappelsEnMemoire(),
                                   android: PresentationAndroid(importeur: faux, horloge: horloge, avecBarriere: true))
        #expect(m.montreAndroid)
        #expect(m.libelleIgnorerAndroid == Libelle("presentation_android_ignorer"))
        #expect(m.libelleImporterAndroid == Libelle("presentation_android_importer"))
        #expect(m.libelleContinuerAndroid == Libelle("onboarding_next"))
        #expect(m.libelleImportEnCours == Libelle("presentation_android_en_cours"))
        let corps = Libelle("presentation_android_corps", .libelle(Libelle("settings_title")),
                            .libelle(Libelle("section_data")), .libelle(Libelle("action_export")))
        #expect(m.corpsAndroid == corps)

        m.quitterAndroid()
        #expect(!m.montreAndroid)
        #expect(m.index == 0)
        #expect(!m.termine)
        m.ouvrirImport()
        #expect(!m.importOuvert)
        await m.importer(Data("{}".utf8))
        #expect(faux.recus.isEmpty)
        #expect(m.resultatImport == nil)
        let ecritures = await persistance.ecrituresJournal + persistance.ecrituresReglages
        #expect(ecritures == 0)
    }

    /// Une sauvegarde importée ne s'importe pas une seconde fois depuis cet écran (les réglages le permettent).
    @Test func uneSeuleSauvegardeParLEcran() async throws {
        let message = Libelle.pluriel("import_ok", quantite: 3, .entier(3))
        let faux = PresentationFauxImport(resultat: .importe(journees: 3, message: message))
        let jour = try PresentationAndroidTests.mercredi()
        let horloge = HorlogeFixe(DateHeure(jour, heure: 9), fuseau: .utc)
        let m = PresentationModele(magasin: Magasin.enMemoire(), notificateur: FauxNotificateur(),
                                   rappels: PresentationRappelsEnMemoire(),
                                   android: PresentationAndroid(importeur: faux, horloge: horloge, avecBarriere: true))
        await m.importer(Data("a".utf8))
        await m.importer(Data("b".utf8))
        let recus = faux.recus.count
        #expect(recus == 1)
        #expect(m.bilanAndroid == message)
        // Le magasin n'a pas bougé (le faux n'écrit rien) : pas de série, pas d'applications.
        #expect(m.serieAndroid == nil)
        #expect(m.applicationsAndroid == nil)
        // Le sélecteur fermé sans fichier ne change rien.
        m.fermerImport()
        #expect(!m.importOuvert)
        #expect(m.montreAndroid)
    }

    // MARK: Les chaînes

    /// Les chaînes neuves sont dans ios.xcstrings, en français, en anglais et en hébreu, avec leurs arguments ;
    /// celles d'Android qu'elles nomment sont au catalogue.
    @Test func lesChainesDeLEcranSontAuxCatalogues() throws {
        let ios = try JSONDecoder().decode(CatalogueBrut.self,
                                           from: Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings"))
        let android = try CatalogueBrut.lire()
        let arguments: [String: [String]] = [
            "presentation_android_titre": [],
            "presentation_android_corps": ["%1$@", "%2$@", "%3$@"],
            "presentation_android_importer": [],
            "presentation_android_ignorer": [],
            "presentation_android_en_cours": [],
            "presentation_android_retrouve": [],
            "presentation_android_suite": [],
            "presentation_android_applications": ["%1$@"],
        ]
        for (cle, attendus) in arguments {
            let deja = android.strings[cle] != nil
            #expect(!deja, "« \(cle) » est déjà une clé d'Android")
            for langue in Traducteur.langues {
                let valeur = try #require(ios.valeur(cle, langue: langue), "« \(cle) » manque en \(langue)")
                #expect(!valeur.isEmpty, "« \(cle) » est vide en \(langue)")
                for argument in attendus {
                    let present = valeur.contains(argument)
                    #expect(present, "« \(cle) » en \(langue) n'a pas \(argument)")
                }
            }
        }
        for cle in ["settings_title", "section_data", "action_export", "section_gate", "onboarding_next",
                    "import_invalid", "import_failed"] {
            for langue in Traducteur.langues {
                let valeur = android.valeur(cle, langue: langue)
                #expect(valeur != nil, "« \(cle) » manque en \(langue)")
            }
        }
        for cle in ["import_ok", "status_streak"] {
            for langue in Traducteur.langues {
                let autre = android.forme(cle, "other", langue: langue)
                #expect(autre != nil, "le pluriel « \(cle) » manque en \(langue)")
            }
        }
    }
}
