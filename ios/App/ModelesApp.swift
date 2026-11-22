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
        seance = SeanceEnCours(magasin: magasin, horloge: horloge, notificateur: notificateur)
        accueil = AccueilModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue, barriere: barriere,
                                debug: debug)
        textes = TextesModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue, relecture: false)
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
        do {
            magasin = try await Magasin.charger(PersistanceFichiers(dossier: dossier))
        } catch {
            magasin = Magasin.enMemoire()
        }
        return ModelesApp(magasin: magasin, paquet: paquet, traducteur: traducteur)
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

    func choixVersion() -> ChoixVersionModele {
        ChoixVersionModele(magasin: magasin)
    }
}
