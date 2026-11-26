import Coeur
import Ecrans
import Foundation
import Observation

/// Ce que l'app construit une fois et que ses écrans reçoivent (MyHitbodedutApp.kt) : le magasin du journal et des
/// réglages, sur les fichiers du dossier de l'app ; l'horloge ; les contenus exportés ; la séance partagée ; les
/// modèles des trois onglets et des réglages ; et la fabrique des modèles des autres écrans, chacun construit à
/// l'ouverture de son écran.
@MainActor
@Observable
final class ModelesApp {
    let magasin: Magasin
    let contenus: ContenusApp
    let horloge: any Horloge
    let traducteur: Traducteur
    /// « fr », « en », « he », « es » ou « ar ».
    let langue: String
    /// L'édition complète (`BuildConfig.HAS_GATE`) ; faux dans la construction SANS_BARRIERE.
    let barriere: Bool
    /// Les textes de 'hizouk non relus passent aussi, en debug.
    let debug: Bool
    private let hilloulot: HilloulotContenus
    private let notificateur: NotificateurSysteme
    private let lecteur: ContenusApp.Lecteur
    private let paquet: URL
    /// La table des hilloulot de la carte du jour, lue une fois, pour Zmanim et le calendrier.
    private let tableHilloulot: ZmanimHilloulotTable
    /// La position du téléphone pour les zmanim et la boussole (ChoixLieu.kt) : approximative.
    private let lieu: LieuSysteme

    /// Les notifications de l'app, posées d'après le plan (rappels, Chabbat, Levana, vol, fin de séance).
    let planificateur: PlanificateurNotifications

    /// La musique et l'ambiance de la séance, et de l'écran Musique.
    let musique: MusiqueLecteur
    /// La séance en cours, partagée : elle continue quand son écran se ferme.
    let seance: SeanceEnCours
    let accueil: AccueilModele
    /// L'accueil des versions Sérénité, Bento et Pile (VersionApp), montré à la place des onglets quand l'une d'elles
    /// est choisie.
    let accueilVersion: AccueilVersionModele
    /// Le mini-lecteur de la séance (MiniLecteur.kt), sur la musique partagée.
    let miniLecteur: MusiqueMiniLecteurModele
    let textes: TextesModele
    let chemin: CheminModele
    let zmanim: ZmanimModele
    let reglages: ReglagesModele
    /// La barrière « Je suis avec Hachem » : Temps d'écran, l'instantané des extensions (Services/TempsEcran.swift).
    let tempsEcran: TempsEcranApp
    /// Le verrou du journal (VerrouJournal.kt) : le code du téléphone, Face ID ou Touch ID (Services/CodeDuTelephone.swift).
    let verrouJournal: VerrouJournal

    private init(magasin: Magasin, paquet: URL, traducteur: Traducteur) {
        self.magasin = magasin
        self.traducteur = traducteur
        langue = traducteur.langue
        let horloge = HorlogeSysteme()
        self.horloge = horloge
        let lecteur = ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu"))
        self.lecteur = lecteur
        self.paquet = paquet
        let contenus = ContenusApp(lecteur: lecteur)
        self.contenus = contenus
        hilloulot = HilloulotContenus(lecteur: lecteur)
        let notificateur = NotificateurSysteme(traducteur: traducteur)
        self.notificateur = notificateur
        let tableHilloulot = ZmanimHilloulotTable(lecteur: lecteur)
        self.tableHilloulot = tableHilloulot
        let lieu = LieuSysteme(precision: .approchee)
        self.lieu = lieu
        let planificateur = PlanificateurNotifications(magasin: magasin, horloge: horloge,
                                                       centre: CentreNotificationsSysteme(traducteur: traducteur),
                                                       aeroports: VolModele.lireAeroports(lecteur: lecteur),
                                                       formats: .langue(traducteur.langue))
        self.planificateur = planificateur
        let activite = ActiviteSysteme(traducteur: traducteur)
        #if SANS_BARRIERE
        barriere = false
        #else
        barriere = true
        #endif
        #if DEBUG
        debug = true
        #else
        debug = false
        #endif
        let musique = MusiqueLecteur(magasin: magasin, contenus: contenus,
                                     sortie: SortieAudioSysteme(paquet: paquet, documents: URL.documentsDirectory),
                                     ambiance: SortieAmbianceSysteme())
        self.musique = musique
        // La minuterie système (tâche 17) : l'alarme d'AlarmKit à la fin d'une séance minutée (Services/Minuterie.swift).
        let alarmes = MinuterieAlarmes(traducteur: traducteur)
        seance = SeanceEnCours(magasin: magasin, horloge: horloge, musique: musique, activite: activite,
                               notificateur: notificateur, minuterie: alarmes)
        let verrouJournal = VerrouJournal(magasin: magasin, code: CodeDuTelephoneSysteme(traducteur: traducteur))
        self.verrouJournal = verrouJournal
        let tempsEcran = TempsEcranApp(magasin: magasin, horloge: horloge, traducteur: traducteur, paquet: paquet,
                                       palettes: (try? lecteur("palettes.json")).flatMap { try? Palettes.lire($0) })
        self.tempsEcran = tempsEcran
        accueil = AccueilModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue, barriere: barriere,
                                debug: debug, systemeBarriere: tempsEcran)
        accueilVersion = AccueilVersionModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue)
        miniLecteur = MusiqueMiniLecteurModele(magasin: magasin, lecteur: musique,
                                               pochettes: PochettesSysteme(paquet: paquet, documents: URL.documentsDirectory))
        textes = TextesModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                              signalMusique: SignalMusiqueSeance(lecteur: musique), relecture: false)
        chemin = CheminModele(magasin: magasin, horloge: horloge)
        zmanim = ZmanimModele(magasin: magasin, horloge: horloge, contenus: contenus, hilloulot: tableHilloulot,
                              localisation: lieu, autorisation: lieu, traducteur: traducteur)
        reglages = ReglagesModele(magasin: magasin, contenus: contenus, horloge: horloge, notificateur: notificateur,
                                  tempsEcran: tempsEcran, activite: activite, barriere: tempsEcran,
                                  icone: IconeSysteme(), effets: EffetsSysteme(planificateur: planificateur),
                                  avecBarriere: barriere, langue: langue, version: ModelesApp.version())
        reglages.verrouJournal = verrouJournal
        reglages.minuterie = MinuterieModele(magasin: magasin, systeme: alarmes)
        accueilVersion.verrou = verrouJournal
    }

    /// Le magasin lu sur les fichiers du dossier de l'app (le conteneur du groupe d'apps quand la signature le donne,
    /// sinon Application Support). Une lecture impossible (une copie de côté refusée) laisse l'app en mémoire plutôt
    /// que de ne pas s'ouvrir.
    static func charger(paquet: URL, traducteur: Traducteur) async -> ModelesApp {
        let magasin: Magasin
        if let demo = await Captures.magasinDemo(paquet: paquet, langue: traducteur.langue) {
            // Les captures d'écran de la CI (Captures.swift) : la démonstration, en mémoire.
            magasin = demo
        } else {
            do {
                magasin = try await Magasin.charger(PersistanceFichiers(dossier: DossierApp.app))
            } catch {
                magasin = Magasin.enMemoire()
            }
        }
        let modeles = ModelesApp(magasin: magasin, paquet: paquet, traducteur: traducteur)
        // La barrière : « Commencer » touché sur le bouclier ouvre la séance (onStartSession) ; puis la synchronisation,
        // à chaque changement et à chaque retour au premier plan.
        let accueil = modeles.accueil
        modeles.tempsEcran.commencer = { accueil.commencer() }
        modeles.tempsEcran.demarrer()
        // Les fins de morceau et les interruptions, le temps de l'app (MusiqueLecteur.ecouter).
        let musique = modeles.musique
        Task { await musique.ecouter() }
        // « Terminer maintenant » de la Live Activity et du widget de la série (TerminerSeanceIntent).
        let seance = modeles.seance
        PontSeance.terminer = { try? await seance.terminer() }
        // Les boutons du rappel, puis les notifications d'après le plan (BootReceiver : au lancement).
        CentreNotificationsSysteme.enregistrerCategories(traducteur)
        DossierApp.retenirLangue(traducteur.langue)
        let planificateur = modeles.planificateur
        ReportDuRappel.planificateur = planificateur
        // Les réponses de « Continuer ? » données dans la notification (24/11).
        SuiteDeSeance.seance = seance
        SuiteDeSeance.planificateur = planificateur
        Task { await planificateur.replanifier() }
        return modeles
    }

    /// `CFBundleShortVersionString` et `CFBundleVersion` (BuildConfig.VERSION_NAME, VERSION_CODE).
    private static func version() -> ReglagesVersion {
        let infos = Bundle.main.infoDictionary ?? [:]
        let nom = infos["CFBundleShortVersionString"] as? String ?? "0"
        let numero = Int(infos["CFBundleVersion"] as? String ?? "") ?? 0
        return ReglagesVersion(nom: nom, numero: numero)
    }

    // MARK: Les modèles des écrans, construits à leur ouverture

    func seanceModele() -> SeanceModele {
        SeanceModele(seance: seance, contenus: contenus, langue: langue, debug: debug)
    }

    func celebration(_ demande: CelebrationDemande) -> CelebrationModele {
        CelebrationModele(demande: demande, magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                          debug: debug)
    }

    func note(_ jour: JourCivil) -> JournalNoteModele {
        // Ouverte hors du journal (l'accueil, la séance, le bravo) : une note déjà écrite attend le code.
        JournalNoteModele(magasin: magasin, date: jour, verrou: verrouJournal)
    }

    func journal() -> JournalModele {
        JournalModele(magasin: magasin, horloge: horloge, traducteur: traducteur)
    }

    func parcours() -> ParcoursModele {
        ParcoursModele(magasin: magasin, horloge: horloge)
    }

    func paliers() -> PaliersModele {
        PaliersModele(magasin: magasin, horloge: horloge)
    }

    func recherche() -> RechercheModele {
        RechercheModele(magasin: magasin, contenus: contenus, hilloulot: hilloulot, langue: langue)
    }

    func tikkun() -> TikkunModele {
        TikkunModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue)
    }

    func tehilim() -> TehilimModele {
        TehilimModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue)
    }

    func tehilimLecture(_ cible: TehilimLectureCible) -> TehilimLectureModele {
        TehilimLectureModele(magasin: magasin, contenus: contenus, langue: langue, cible: cible)
    }

    func tefilot() -> TefilotModele {
        TefilotModele(magasin: magasin, contenus: contenus, langue: langue)
    }

    func bibliotheque(livresSeuls: Bool) -> BibliothequeModele {
        BibliothequeModele(magasin: magasin, contenus: contenus, langue: langue, livresSeuls: livresSeuls)
    }

    func sousSection(_ id: String) -> BibliothequeSousSectionModele {
        BibliothequeSousSectionModele(magasin: magasin, contenus: contenus, langue: langue, id: id)
    }

    func entree(_ id: String) -> BibliothequeEntreeModele {
        BibliothequeEntreeModele(magasin: magasin, contenus: contenus, langue: langue, id: id)
    }

    func chizuk() -> ChizukModele {
        ChizukModele(magasin: magasin, contenus: contenus, langue: langue, debug: debug)
    }

    func conseils() -> ConseilsModele {
        ConseilsModele(magasin: magasin)
    }

    func halakha(recherche: String?, date: JourCivil? = nil) -> HalakhaModele {
        HalakhaModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue, date: date,
                      recherche: recherche)
    }

    func hilloulotModele(recherche: String?, date: JourCivil? = nil) -> HilloulotModele {
        HilloulotModele(magasin: magasin, contenus: hilloulot, horloge: horloge, langue: langue, date: date,
                        recherche: recherche)
    }

    func presentation() -> PresentationModele {
        PresentationModele(magasin: magasin, notificateur: notificateur, rappels: planificateur,
                           avecBarriere: barriere)
    }

    /// Le vol, hors ligne (décision D10 : ni relais ni services en ligne) : le billet lu sur le téléphone (Vision,
    /// App/Services/Billet.swift), le relevé GPS, qui marche en mode avion ; ses rappels passent par le planificateur
    /// des notifications.
    func vol() -> VolModele {
        VolModele(magasin: magasin, horloge: horloge, aeroports: VolModele.lireAeroports(lecteur: lecteur),
                  notificateur: NotificateurDuPlan(systeme: notificateur, planificateur: planificateur),
                  retrait: planificateur, localisation: LieuSysteme(precision: .gps),
                  lecteurBillet: LecteurBilletSysteme(), traducteur: traducteur, formats: .langue(langue))
    }

    // MARK: Le ciel : le calendrier, la boussole ; les rappels

    /// Le calendrier : le choix du lieu est celui de Zmanim.
    func calendrier() -> CalendrierModele {
        CalendrierModele(magasin: magasin, horloge: horloge, contenus: contenus, hilloulot: tableHilloulot,
                         choixLieu: zmanim.choixLieu, langue: langue)
    }

    /// La boussole de Jérusalem : CoreMotion, la position approximative, et son widget redessiné.
    func boussole() -> BoussoleModele {
        BoussoleModele(magasin: magasin, contenus: contenus, horloge: horloge, traducteur: traducteur,
                       tableaux: tableauxBoussole(), capteur: BoussoleCapteurSysteme(), localisation: lieu,
                       autorisationLieu: lieu, rafraichissement: BoussoleRafraichissementSysteme())
    }

    /// Les points cardinaux de la langue (Tableaux.json) ; ceux du français si le fichier manque.
    private func tableauxBoussole() -> BoussoleTableaux {
        if let donnees = try? Data(contentsOf: paquet.appending(path: "Chaines/Tableaux.json")),
           let tableaux = try? BoussoleTableaux(donnees: donnees, langue: langue) {
            return tableaux
        }
        return BoussoleTableaux(points: ["N", "NE", "E", "SE", "S", "SO", "O", "NO"], cardinaux: ["N", "E", "S", "O"])
    }

    func rappels() -> RappelsModele {
        let planificateur = self.planificateur
        return RappelsModele(magasin: magasin, notificateur: notificateur, rappels: planificateur,
                             plan: { planificateur.plan })
    }

    /// Ajouter du temps à un jour (AjoutTemps.kt) ; nil pour un jour à venir.
    func ajoutTemps(_ jour: JourCivil) -> AjoutTempsModele? {
        AjoutTempsModele(magasin: magasin, horloge: horloge, systeme: AjoutTempsSystemeApp(planificateur: planificateur),
                         date: jour)
    }

    /// L'écran Musique : l'écoute d'essai et l'aperçu d'ambiance ont leurs propres sorties, à côté de la séance.
    func musiqueModele() -> MusiqueModele {
        let documents = URL.documentsDirectory
        return MusiqueModele(magasin: magasin, lecteur: musique,
                             apercu: SortieAudioSysteme(paquet: paquet, documents: documents),
                             ambianceApercu: SortieAmbianceSysteme(), stockage: StockageMusiqueSysteme(documents: documents))
    }

    func choixVersion() -> ChoixVersionModele {
        ChoixVersionModele(magasin: magasin)
    }
}
