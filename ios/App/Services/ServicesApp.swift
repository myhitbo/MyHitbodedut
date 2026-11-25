import Coeur
import Ecrans
import Foundation

/// Tous les adaptateurs du système, construits une fois par l'app, une fois le magasin chargé : ce que les modèles
/// d'écran reçoivent à la place des faux des tests (ECRANS.md). Chaque propriété est rangée sous le protocole
/// qu'elle réalise.
///
/// Les sorties audio de la séance et de l'aperçu sont distinctes : `MusiqueModele` en demande une seconde paire
/// (`sortieAudioApercu()`, `sortieAmbianceApercu()`), neuve à chaque ouverture de l'écran de la musique.
@MainActor
final class ServicesApp {

    let horloge: HorlogeSysteme
    /// `Notificateur`, `VolRetraitNotifications`, et la pose du plan.
    let notificateur: SystemeNotificateur
    /// `PresentationRappels`, et la replanification de tout le plan.
    let rappels: SystemeRappels
    /// `Localisation`, `LieuAutorisation`, `BoussoleAutorisationLieu`.
    let localisation: SystemeLocalisation
    /// `BoussoleRafraichissement`.
    let widgets: SystemeWidgets
    /// `AccueilSysteme`.
    let accueil: SystemeAccueil
    /// `AjoutTempsSysteme`.
    let ajoutTemps: SystemeAjoutTemps
    /// `ReglagesEffets`.
    let effetsReglages: SystemeEffetsReglages
    /// La barrière : etat.json et le décor des extensions, les magasins nommés, la surveillance, l'essai réel.
    let barriere: SystemeBarriere
    /// `TempsEcran`, `ReglagesBarriereSysteme` (sur `barriere`).
    let tempsEcran: SystemeTempsEcran
    /// `ActiviteEnDirect` : la Live Activity de la séance (ActivityKit), dans la langue de l'app.
    let activite: SystemeActiviteEnDirect
    /// `ReglagesIcone`.
    let icone: SystemeIcone
    /// `LecteurSon`.
    let son: SystemeLecteurSon
    /// `BoussoleCapteur`.
    let boussole: SystemeBoussoleCapteur
    /// `MusiqueSortieAudio` de la séance (celle du `MusiqueLecteur` partagé).
    let sortieAudio: SystemeSortieAudio
    /// `MusiqueSortieAmbiance` de la séance.
    let sortieAmbiance: SystemeSortieAmbiance
    /// `MusiqueStockage`.
    let stockage: SystemeStockageMusique
    /// `MusiquePochettes`.
    let pochettes: SystemePochettes
    /// `VolReseau` : il ne sert qu'avec une adresse de relais (`VolEnLigne`), que l'app n'a pas encore.
    let volReseau: SystemeVolReseau
    /// `VolLecteurBillet`.
    let lecteurBillet: SystemeLecteurBillet

    private let magasin: Magasin

    /// `lecteur` : celui des contenus de l'app (`ContenusApp.lecteur(dossier:)`), d'où les heures du vol tirent
    /// les aéroports.
    init(magasin: Magasin, traducteur: Traducteur, lecteur: @escaping ContenusApp.Lecteur, palettes: Palettes?,
         horloge: HorlogeSysteme = HorlogeSysteme()) {
        self.magasin = magasin
        self.horloge = horloge
        notificateur = SystemeNotificateur(traducteur: traducteur, horloge: horloge)
        rappels = SystemeRappels(magasin: magasin, notificateur: notificateur, traducteur: traducteur,
                                 horloge: horloge, aeroports: VolModele.lireAeroports(lecteur: lecteur))
        localisation = SystemeLocalisation()
        widgets = SystemeWidgets(magasin: magasin, traducteur: traducteur)
        accueil = SystemeAccueil(rappels: rappels, widgets: widgets, notificateur: notificateur)
        ajoutTemps = SystemeAjoutTemps(widgets: widgets, notificateur: notificateur)
        effetsReglages = SystemeEffetsReglages(rappels: rappels, widgets: widgets)
        barriere = SystemeBarriere(magasin: magasin, traducteur: traducteur, horloge: horloge, palettes: palettes,
                                   paquet: SystemeDossiers.paquet)
        tempsEcran = SystemeTempsEcran(barriere: barriere)
        activite = SystemeActiviteEnDirect(magasin: magasin, traducteur: traducteur)
        icone = SystemeIcone()
        son = SystemeLecteurSon()
        boussole = SystemeBoussoleCapteur()
        sortieAudio = SystemeSortieAudio()
        sortieAmbiance = SystemeSortieAmbiance()
        stockage = SystemeStockageMusique()
        pochettes = SystemePochettes()
        volReseau = SystemeVolReseau()
        lecteurBillet = SystemeLecteurBillet()
    }

    /// Une sortie audio pour l'aperçu de l'écran de la musique, qui n'écoute pas les interruptions.
    func sortieAudioApercu() -> SystemeSortieAudio {
        SystemeSortieAudio(ecouterInterruptions: false)
    }

    /// Une sortie d'ambiance pour l'aperçu de l'écran de la musique.
    func sortieAmbianceApercu() -> SystemeSortieAmbiance {
        SystemeSortieAmbiance()
    }

    /// « Plus tard » sous le rappel (ReminderReceiver, ACTION_SNOOZE) : le rappel revient dans
    /// `Reminder.snoozeMinutes`, et le plan le pose.
    func reporterRappel() async {
        let jusqua = horloge.maintenant + Int64(Reminder.snoozeMinutes) * 60_000
        do {
            try await magasin.modifierReglages { $0.setReminderSnoozedUntil(jusqua) }
        } catch {
            // Le report reste en mémoire ; le plan le pose quand même.
        }
        await rappels.replanifier()
    }

    // MARK: Ce que l'app construit avant les services

    /// La persistance réelle : `journal.json` et `reglages.json` dans le dossier de l'app (`SystemeDossiers.donnees`).
    static func persistance() -> PersistanceDepot {
        PersistanceDepot(dossier: SystemeDossiers.donnees)
    }

    /// Le magasin de l'app, lu sur ses fichiers. Si la lecture échoue (un fichier illisible qui n'a pas pu être mis
    /// de côté, un disque qui refuse), un magasin en mémoire, vide, qui n'écrit rien : les fichiers restent tels
    /// quels plutôt que d'être écrasés, et `enMemoire` le dit à l'app.
    static func chargerMagasin() async -> (magasin: Magasin, enMemoire: Bool) {
        do {
            return (try await Magasin.charger(persistance()), false)
        } catch {
            return (Magasin.enMemoire(), true)
        }
    }

    /// La version de l'app, pour l'écran des réglages : `CFBundleShortVersionString` et `CFBundleVersion`.
    static func version() -> ReglagesVersion {
        let infos = Bundle.main.infoDictionary ?? [:]
        let nom = infos["CFBundleShortVersionString"] as? String ?? ""
        let numero = (infos["CFBundleVersion"] as? String).flatMap { Int($0) } ?? 0
        return ReglagesVersion(nom: nom, numero: numero)
    }
}
