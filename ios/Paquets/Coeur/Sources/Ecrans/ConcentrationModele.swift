import Foundation
import Observation
import Coeur

// L'aide à la concentration, qui remplace « Ne pas déranger pendant la hitbodedout » (NePasDeranger.kt, la ligne
// settings_ne_pas_deranger de SettingsActivity ; PORTAGE.md § 2.2.6). Android passait lui-même le téléphone en
// mode « priorité » le temps de la séance ; iOS ne laisse aucune app activer un mode de concentration. L'écran
// apprend donc, pas à pas, à créer dans les Réglages d'iOS un mode « Hitbodedout » qui s'active de lui-même quand
// MyHitbodedut est ouverte, puis, s'il le veut, à y ajouter le filtre de l'app qui masque le décompte de la séance
// (ConcentrationFiltre). Le bouton ouvre les Réglages d'iOS (`UIApplication.openSettingsURLString`) : ils
// s'ouvrent sur la page de MyHitbodedut, et le texte le dit.
//
// Les étapes suivent les Réglages d'iOS 26 : Concentration, +, Personnalisé, le nom, les personnes et les apps
// autorisées, puis « Ajouter une planification » → « App » → MyHitbodedut. Toutes les chaînes sont propres à iOS
// (ios.xcstrings), sauf le titre de la ligne des réglages qui mène ici et « Cet écran de réglages n'existe pas ».

/// Une étape de l'aide : son rang dans sa pastille et ce qu'il faut faire.
public struct ConcentrationEtape: Sendable, Hashable, Identifiable {
    /// 1, 2, 3…
    public let numero: Int
    /// Le rang en chiffres ASCII, dans les trois langues (comme les conseils).
    public let numeroTexte: String
    public let texte: Libelle

    public var id: Int { numero }
}

/// L'écran d'aide du mode de concentration, poussé depuis la ligne « Ne pas déranger pendant la hitbodedout » des
/// réglages (`ReglagesRoute.aideConcentration`).
@MainActor
@Observable
public final class ConcentrationModele {
    private let magasin: Magasin

    /// « Cet écran de réglages n'existe pas sur ce téléphone. » si les Réglages n'ont pas pu s'ouvrir ; nil
    /// sinon. La vue le montre en alerte et le remet à nil quand on la ferme.
    public var message: Libelle?

    public init(magasin: Magasin) {
        self.magasin = magasin
    }

    /// Un modèle sur un magasin en mémoire, pour les aperçus.
    public static func apercu(masqueDecompte: Bool = false) -> ConcentrationModele {
        var reglages = Reglages()
        ConcentrationFiltre.poser(masqueDecompte, dans: &reglages)
        return ConcentrationModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)))
    }

    // MARK: Les textes

    /// Le titre de l'écran : celui de la ligne des réglages qui y mène (settings_ne_pas_deranger d'Android).
    public var titre: Libelle {
        Libelle("settings_ne_pas_deranger")
    }

    /// Pourquoi l'app ne le fait pas elle-même, et ce qu'on va faire à la place (la ligne des réglages le dit
    /// aussi).
    public var introduction: Libelle {
        Libelle("reglages_concentration_hint")
    }

    /// Le titre de la carte des étapes.
    public var titreEtapes: Libelle {
        Libelle("concentration_etapes_titre")
    }

    /// Les étapes, dans l'ordre des Réglages d'iOS 26.
    public var etapes: [ConcentrationEtape] {
        ConcentrationModele.clesEtapes.enumerated().map { rang, cle in
            ConcentrationEtape(numero: rang + 1, numeroTexte: String(rang + 1), texte: Libelle(cle))
        }
    }

    /// Ce que fait le mode une fois créé : il s'active à l'ouverture de l'app et s'éteint quand on la quitte.
    public var resultat: Libelle {
        Libelle("concentration_resultat")
    }

    /// « Ouvrir les Réglages ».
    public var libelleOuvrirReglages: Libelle {
        Libelle("concentration_ouvrir_reglages")
    }

    /// Ce que le bouton ouvre vraiment : la page de MyHitbodedut dans les Réglages, d'où l'on revient d'un cran
    /// pour trouver « Concentration ». Aucune app ne peut ouvrir directement la page Concentration.
    public var noteOuvrirReglages: Libelle {
        Libelle("concentration_ouvrir_reglages_note")
    }

    /// Le titre de la carte du filtre.
    public var titreFiltre: Libelle {
        Libelle("concentration_filtre_carte_titre")
    }

    /// Comment ajouter le filtre de l'app au mode, et ce qu'il fait.
    public var explicationFiltre: Libelle {
        Libelle("concentration_filtre_carte_texte")
    }

    /// Ce que le filtre fait en ce moment, d'après ce qu'iOS a dit à l'app : le décompte masqué, ou rien de masqué.
    public var etatFiltre: Libelle {
        filtreMasqueDecompte ? Libelle("concentration_filtre_etat_masque") : Libelle("concentration_filtre_etat_libre")
    }

    // MARK: L'état

    /// Le mode de concentration actif masque-t-il le décompte (ConcentrationFiltre) ? Relu dans le magasin à
    /// chaque fois : un filtre qui s'active pendant que l'écran est ouvert se voit tout de suite.
    public var filtreMasqueDecompte: Bool {
        ConcentrationFiltre.masqueDecompte(magasin.reglages)
    }

    // MARK: Les gestes

    /// Les Réglages n'ont pas pu s'ouvrir (`UIApplication.open` a refusé l'adresse) : le message des réglages
    /// d'Android.
    public func reglagesImpossibles() {
        message = Libelle("settings_screen_missing")
    }

    /// Les clés des étapes, dans l'ordre (ios.xcstrings).
    static let clesEtapes = [
        "concentration_etape_ouvrir",
        "concentration_etape_creer",
        "concentration_etape_autoriser",
        "concentration_etape_planifier",
        "concentration_etape_app",
    ]
}
