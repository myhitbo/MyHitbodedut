import Coeur
import Ecrans
import Foundation
import Vues

/// Tout ce que les écrans de l'app partagent, construit une fois le magasin lu : le magasin du journal et des
/// réglages, l'horloge, le traducteur, les contenus du paquet et les tables lues à la demande, la séance en cours
/// et la musique, les adaptateurs du système (`ServicesApp`), les modèles des cinq racines d'onglet, et la
/// navigation. Les écrans poussés construisent leur modèle à partir d'ici (Destinations.swift).
@MainActor
final class PartageApp {

    #if DEBUG
    /// Les écrans de débogage d'Android (`BuildConfig.DEBUG`) : les badges « à relire », la relecture.
    static let debug = true
    #else
    static let debug = false
    #endif

    #if SANS_BARRIERE
    /// La construction sans les extensions Temps d'écran (project-sans-barriere.yml, décision D3).
    static let avecBarriere = false
    #else
    static let avecBarriere = true
    #endif

    let magasin: Magasin
    /// Vrai si le journal n'a pu être lu : le magasin est alors en mémoire, et n'écrit rien sur les fichiers.
    let enMemoire: Bool
    let horloge: HorlogeSysteme
    let traducteur: Traducteur
    let palettes: Palettes?
    let contenus: ContenusApp
    let lecteur: ContenusApp.Lecteur
    /// `hilloulot.json` et les biographies, pour l'écran des hilloulot et la recherche.
    let hilloulot: HilloulotContenus
    /// La table des hilloulot de l'onglet Zmanim et du calendrier.
    let tableHilloulot: ZmanimHilloulotTable
    /// L'index de la recherche globale, préparé une fois pour l'app.
    let preparateur: RecherchePreparateur
    /// Les formes des trophées (`trophees_formes.json`) : l'accueil et les paliers.
    let formes: TropheeFormes
    /// Les points cardinaux de la boussole (Chaines/Tableaux.json), dans la langue de l'app.
    let tableaux: BoussoleTableaux
    let services: ServicesApp
    /// La séance qui tourne, partagée par l'accueil, l'écran de séance et les notifications.
    let seance: SeanceEnCours
    /// La musique et l'ambiance de la séance.
    let musique: MusiqueLecteur
    /// Le mini-lecteur posé sur l'écran de séance.
    let mini: MusiqueMiniLecteurModele

    // Les racines des cinq onglets, gardées tant que l'app vit.
    let accueil: AccueilModele
    let textes: TextesModele
    let zmanim: ZmanimModele
    let journal: JournalModele
    let reglages: ReglagesModele

    let navigation: Navigation

    var langue: String { traducteur.langue }

    init(magasin: Magasin, enMemoire: Bool, traducteur: Traducteur, palettes: Palettes?, contenus: ContenusApp,
         lecteur: @escaping ContenusApp.Lecteur, paquet: URL) {
        let horloge = HorlogeSysteme()
        self.magasin = magasin
        self.enMemoire = enMemoire
        self.horloge = horloge
        self.traducteur = traducteur
        self.palettes = palettes
        self.contenus = contenus
        self.lecteur = lecteur
        let langue = traducteur.langue
        let hilloulot = HilloulotContenus(lecteur: lecteur)
        self.hilloulot = hilloulot
        let tableHilloulot = ZmanimHilloulotTable(lecteur: lecteur)
        self.tableHilloulot = tableHilloulot
        preparateur = RecherchePreparateur(contenus: contenus, hilloulot: hilloulot, langue: langue)
        // Sans le fichier, des trophées sans dessin plutôt qu'un lancement qui échoue.
        formes = (try? TropheeFormes.lire(lecteur)) ?? TropheeFormes(formes: [:], icones: [:])
        tableaux = PartageApp.tableaux(paquet: paquet, langue: langue)

        let services = ServicesApp(magasin: magasin, traducteur: traducteur, lecteur: lecteur, horloge: horloge)
        self.services = services
        let musique = MusiqueLecteur(magasin: magasin, contenus: contenus, sortie: services.sortieAudio,
                                     ambiance: services.sortieAmbiance)
        self.musique = musique
        mini = MusiqueMiniLecteurModele(magasin: magasin, lecteur: musique, pochettes: services.pochettes)
        seance = SeanceEnCours(magasin: magasin, horloge: horloge, musique: musique, activite: services.activite,
                               son: services.son, notificateur: services.notificateur)

        accueil = AccueilModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                                barriere: PartageApp.avecBarriere, debug: PartageApp.debug, systeme: services.accueil)
        textes = TextesModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                              signalMusique: SystemeSignalMusique(lecteur: musique), relecture: PartageApp.debug)
        zmanim = ZmanimModele(magasin: magasin, horloge: horloge, contenus: contenus, hilloulot: tableHilloulot,
                              localisation: services.localisation, autorisation: services.localisation,
                              traducteur: traducteur)
        journal = JournalModele(magasin: magasin, horloge: horloge, traducteur: traducteur)
        reglages = ReglagesModele(magasin: magasin, contenus: contenus, horloge: horloge,
                                  notificateur: services.notificateur, tempsEcran: services.tempsEcran,
                                  activite: services.activite, barriere: services.tempsEcran, icone: services.icone,
                                  effets: services.effetsReglages, avecBarriere: PartageApp.avecBarriere,
                                  langue: langue, version: ServicesApp.version())
        navigation = Navigation(onglet: Onglet.initial(magasin.reglages))
    }

    /// Ce qui part au lancement, une fois la racine prête : la présentation d'une version neuve, l'écoute des
    /// annonces de la sortie audio, le routage des notifications touchées, le plan des notifications.
    func demarrer(reponses: SystemeReponsesNotifications) {
        if PresentationModele.aMontrer(magasin.reglages) {
            montrerPresentation()
        }
        // Une seule écoute pour toute la vie de l'app (la suite des annonces ne se parcourt qu'une fois).
        let musique = self.musique
        Task { await musique.ecouter() }
        reponses.brancher { [weak self] touchee in
            await self?.recevoir(touchee)
        }
        // Une séance restée inscrite (l'app tuée) est close ou reprise dès le lancement, quel que soit l'onglet
        // ouvert (SessionService.reconcilier, START_STICKY) : la musique repart avec elle.
        actualiserSeance()
        replanifier()
        // Ce que montrent les widgets (la boussole, la série, les zmanim), dans la langue de l'app, dès le lancement :
        // rafraichir() dépose la boussole, la copie du journal et des réglages, la langue, puis recharge les widgets.
        let widgets = services.widgets
        Task { await widgets.rafraichir() }
    }

    /// Le tour de la séance (SeanceEnCours.actualiser), au lancement et au retour au premier plan : une séance
    /// suivie arrivée à son terme hors de l'écran de séance est close et inscrite ; une séance qui n'est plus
    /// suivie est réconciliée. Deux tours qui se croisent n'inscrivent qu'une fois : la clôture s'écrit dans le
    /// magasin avant toute attente.
    func actualiserSeance() {
        let seance = self.seance
        Task { _ = try? await seance.actualiser() }
    }

    /// Le plan des notifications recalculé (Reminder.reschedule et ses voisins), hors du geste qui le demande.
    func replanifier() {
        let rappels = services.rappels
        Task { await rappels.replanifier() }
    }

    /// La présentation, à la page 0, en plein écran par-dessus les onglets.
    /// Sur un téléphone sans journée, l'écran « Je viens d'Android » précède la présentation (PORTAGE.md § 3.8).
    /// L'import passe par l'onglet Réglages : une seule fusion, et les mêmes répercussions.
    func montrerPresentation() {
        let android = PresentationAndroid(importeur: reglages, horloge: horloge, avecBarriere: PartageApp.avecBarriere)
        let modele = PresentationModele(magasin: magasin, notificateur: services.notificateur,
                                        rappels: services.rappels, index: 0, android: android)
        navigation.presentation = PresentationOuverte(modele: modele)
    }

    /// Les points cardinaux de la boussole ; sans le fichier, des tableaux vides (la rose sans lettres).
    private static func tableaux(paquet: URL, langue: String) -> BoussoleTableaux {
        let fichier = paquet.appending(path: "Chaines/Tableaux.json")
        if let donnees = try? Data(contentsOf: fichier),
           let tableaux = try? BoussoleTableaux(donnees: donnees, langue: langue) {
            return tableaux
        }
        return BoussoleTableaux(points: [], cardinaux: [])
    }
}
