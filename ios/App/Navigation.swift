import Coeur
import Ecrans
import Foundation
import SwiftUI

/// Un écran poussé dans la pile d'un onglet, avec ses paramètres : la cible commune des routes de tous les écrans
/// (AccueilRoute, TextesRoute, LectureRoute, RechercheRoute, BibliothequeRoute, TefilotRoute, ChizukRoute,
/// JournalRoute, SeanceRoute, ZmanimRoute, ReglagesRoute), que Routage.swift traduit en `Ecran`. Chaque pile ne
/// déclare qu'une destination, `navigationDestination(for: Ecran.self)` (Destinations.swift).
///
/// Deux types de route n'y passent pas : `BibliothequeRoute.sousSection` et `.entree`, que `BibliothequeVue`
/// pousse elle-même avec sa propre destination, et `TehilimRoute`, de même pour `TehilimVue`. Les piles sont
/// donc des `NavigationPath`, qui acceptent les valeurs de plusieurs types.
enum Ecran: Hashable {
    // L'onglet Aujourd'hui.
    /// SessionActivity ; `commencer` : EXTRA_START_NOW (la séance part seule).
    case seance(commencer: Bool)
    /// PaliersActivity.
    case paliers
    /// ParcoursActivity (« Mon parcours »).
    case parcours
    /// MusicActivity.
    case musique
    /// TipsActivity.
    case conseils

    // L'onglet Textes.
    /// RechercheActivity.
    case recherche
    /// SiddurActivity : la liste du siddour.
    case siddour
    /// SiddurLectureActivity : un texte du siddour ou un livre, à une place ou non.
    case lecture(LectureCible)
    /// TehilimActivity.
    case tehilim
    /// TehilimLectureActivity.ouvrirMarque : un psaume, à un verset.
    case tehilimMarque(psaume: Int, verset: Int)
    /// TikkunFlowActivity.
    case tikkun
    /// TefilotActivity.
    case tefilot
    /// LibraryActivity : les livres seuls, ou les sources.
    case bibliotheque(livresSeuls: Bool)
    /// LibraryEntryActivity, EXTRA_ID.
    case entreeBibliotheque(String)
    /// ChizukActivity.
    case chizuk

    // L'onglet Zmanim.
    /// HalakhaActivity : un jour (EXTRA_DATE) ou une recherche (EXTRA_RECHERCHE).
    case halakha(date: JourCivil?, recherche: String?)
    /// HilloulotActivity : un jour ou une recherche.
    case hilloulot(date: JourCivil?, recherche: String?)
    /// CalendrierActivity.
    case calendrier
    /// VolActivity.
    case vol
    /// BoussoleActivity.
    case boussole

    // L'onglet Réglages.
    /// AppPickerActivity : le choix des applications de la barrière (FamilyActivityPicker).
    case applications
    /// L'aide à la concentration, qui remplace « Ne pas déranger » (NePasDeranger.kt, PORTAGE.md § 2.2.6).
    case concentration

    /// Un écran d'Android pas encore porté (la relecture, l'aperçu du bouclier) : son titre (une
    /// clé du catalogue) et « Bientôt », sans rien faire semblant.
    case bientot(cle: String)
}

/// Les feuilles posées par la racine, par-dessus les onglets.
enum Feuille: Hashable, Identifiable {
    /// La feuille des marque-pages (RepriseFavoris.listeSignets) : tous (nil), ceux du siddour (« s ») ou des
    /// livres (« l »).
    case marquesPages(recueil: String?)
    /// La note d'un jour (NoteDialog).
    case note(JourCivil)
    /// La dédicace (Dedicace.ouvrir), depuis les réglages : l'e-mail composé et ouvert dans la messagerie.
    case dedicace

    var id: Self { self }
}

/// Les écrans plein écran posés par la racine.
enum Couverture: Hashable, Identifiable {
    /// Le bravo de fin de séance, depuis l'accueil (CelebrationActivity).
    case celebration(CelebrationDemande)

    var id: Self { self }
}

/// La présentation ouverte (OnboardingActivity), avec son modèle, neuf à chaque ouverture.
struct PresentationOuverte: Identifiable {
    let id = UUID()
    let modele: PresentationModele
}

/// L'état de la navigation : l'onglet choisi, la pile de chaque onglet et ce que la racine présente par-dessus.
@MainActor
@Observable
final class Navigation {

    var onglet: Onglet
    var aujourdhui = NavigationPath()
    var textes = NavigationPath()
    var zmanim = NavigationPath()
    var journal = NavigationPath()
    var reglages = NavigationPath()

    var feuille: Feuille?
    var couverture: Couverture?
    var presentation: PresentationOuverte?
    /// Le dialogue « Ajouter du temps fait hors du téléphone » (AjoutTemps), depuis le calendrier.
    var ajout: AjoutTempsModele?

    init(onglet: Onglet) {
        self.onglet = onglet
    }

    /// Pousse un écran sur la pile d'un onglet : celui qu'on voit, sauf mention contraire.
    func pousser(_ ecran: Ecran, dans cible: Onglet? = nil) {
        pousserValeur(ecran, dans: cible ?? onglet)
    }

    /// Pousse une valeur d'un autre type que `Ecran` (une `BibliothequeRoute`), résolue par la destination d'un
    /// écran déjà dans la pile.
    func pousserValeur<Valeur: Hashable>(_ valeur: Valeur, dans cible: Onglet) {
        switch cible {
        case .aujourdhui: aujourdhui.append(valeur)
        case .textes: textes.append(valeur)
        case .zmanim: zmanim.append(valeur)
        case .journal: journal.append(valeur)
        case .reglages: reglages.append(valeur)
        }
    }

    /// Ramène la pile d'un onglet à sa racine.
    func vider(_ cible: Onglet) {
        switch cible {
        case .aujourdhui: aujourdhui = NavigationPath()
        case .textes: textes = NavigationPath()
        case .zmanim: zmanim = NavigationPath()
        case .journal: journal = NavigationPath()
        case .reglages: reglages = NavigationPath()
        }
    }

    /// Toutes les piles à leur racine, rien par-dessus (« Tout effacer » des réglages).
    func toutFermer() {
        for cible in Onglet.allCases {
            vider(cible)
        }
        feuille = nil
        couverture = nil
        presentation = nil
        ajout = nil
    }
}
