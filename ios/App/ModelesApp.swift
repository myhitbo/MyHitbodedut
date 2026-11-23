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

    /// La musique et l'ambiance de la séance, et de l'écran Musique.
    let musique: MusiqueLecteur
    /// La séance en cours, partagée : elle continue quand son écran se ferme.
    let seance: SeanceEnCours
    let accueil: AccueilModele
    let textes: TextesModele
    let chemin: CheminModele
    let zmanim: ZmanimModele
    let reglages: ReglagesModele

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
        seance = SeanceEnCours(magasin: magasin, horloge: horloge, musique: musique, notificateur: notificateur)
        accueil = AccueilModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue, barriere: barriere,
                                debug: debug)
        textes = TextesModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                              signalMusique: SignalMusiqueSeance(lecteur: musique), relecture: false)
        chemin = CheminModele(magasin: magasin, horloge: horloge)
        zmanim = ZmanimModele(magasin: magasin, horloge: horloge, contenus: contenus, traducteur: traducteur)
        reglages = ReglagesModele(magasin: magasin, contenus: contenus, horloge: horloge, notificateur: notificateur,
                                  tempsEcran: TempsEcranAbsent(), activite: ActiviteAbsente(), barriere: BarriereAbsente(),
                                  icone: IconeSysteme(), effets: EffetsAbsents(), avecBarriere: barriere, langue: langue,
                                  version: ModelesApp.version())
    }

    /// Le magasin lu sur les fichiers du dossier de l'app (le conteneur du groupe d'apps quand la signature le donne,
    /// sinon Application Support). Une lecture impossible (une copie de côté refusée) laisse l'app en mémoire plutôt
    /// que de ne pas s'ouvrir.
    static func charger(paquet: URL, traducteur: Traducteur) async -> ModelesApp {
        let groupe = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.myhitbodedut")
        let dossier = groupe ?? URL.applicationSupportDirectory.appending(path: "MyHitbodedut")
        let magasin: Magasin
        if let demo = await Captures.magasinDemo(paquet: paquet, langue: traducteur.langue) {
            // Les captures d'écran de la CI (Captures.swift) : la démonstration, en mémoire.
            magasin = demo
        } else {
            do {
                magasin = try await Magasin.charger(PersistanceFichiers(dossier: dossier))
            } catch {
                magasin = Magasin.enMemoire()
            }
        }
        let modeles = ModelesApp(magasin: magasin, paquet: paquet, traducteur: traducteur)
        // Les fins de morceau et les interruptions, le temps de l'app (MusiqueLecteur.ecouter).
        let musique = modeles.musique
        Task { await musique.ecouter() }
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
        JournalNoteModele(magasin: magasin, date: jour)
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
        PresentationModele(magasin: magasin, notificateur: notificateur, rappels: RappelsAbsents(),
                           avecBarriere: barriere)
    }

    /// Le vol, hors ligne : ni relais, ni billet, ni relevé de position tant que leurs adaptateurs ne sont pas écrits.
    func vol() -> VolModele {
        VolModele(magasin: magasin, horloge: horloge, aeroports: VolModele.lireAeroports(lecteur: lecteur),
                  notificateur: notificateur, traducteur: traducteur, formats: .langue(langue))
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
