import Foundation
import Observation
import Coeur

// Le choix de la version (ChoixVersionActivity.kt d'Android, 17/11) : une fois au premier lancement, après la
// présentation, puis depuis les réglages (« Version de l'app »). Chaque version a sa carte : son nom, ce qu'elle
// change, et ses trois couleurs en aperçu. Quitter sans choisir garde Classique.
//
// Une version choisie est retenue (VersionApp.appliquer) : la racine de l'app montre aussitôt son accueil, sans pile
// d'écrans derrière (ios/App/Racine.swift).

/// Une carte de version.
public struct ChoixVersionCarte: Sendable, Hashable, Identifiable {
    public let version: VersionApp
    public let nom: Libelle
    public let description: Libelle
    /// Fond, carte, accent de l'aperçu (ARGB).
    public let apercu: [UInt32]
    /// La version actuelle : bord de l'accent, « ✓ » après le nom, « version actuelle » lu par VoiceOver.
    public let choisie: Bool

    public var id: String { version.cle }
}

@MainActor
@Observable
public final class ChoixVersionModele {

    private let magasin: Magasin

    /// L'écran a fini : la vue se ferme.
    public private(set) var ferme = false

    public init(magasin: Magasin) {
        self.magasin = magasin
    }

    /// L'écran se propose à l'accueil : la présentation vue, et aucune version encore choisie (MainActivity.onResume).
    public static func aProposer(_ reglages: Reglages) -> Bool {
        reglages.hasOnboarded && reglages.versionApp == nil
    }

    public var titre: Libelle { Libelle("version_choix_titre") }
    public var detail: Libelle { Libelle("version_choix_detail") }
    public var pied: Libelle { Libelle("version_choix_pied") }
    /// « version actuelle », ajouté à la lecture de la carte choisie.
    public var actuelle: Libelle { Libelle("version_choisie") }

    public var cartes: [ChoixVersionCarte] {
        let choisie = VersionApp.courante(magasin.reglages)
        return VersionApp.allCases.map { v in
            ChoixVersionCarte(version: v, nom: v.nom, description: v.description, apercu: v.apercu,
                              choisie: v == choisie)
        }
    }

    /// Une carte touchée : la version est retenue (VersionApp.appliquer), l'écran se ferme. Lève si les réglages ne
    /// s'écrivent pas.
    public func choisir(_ version: VersionApp) async throws {
        try await magasin.modifierReglages { $0.setVersionApp(version) }
        ferme = true
    }

    /// Retour sans choisir : au premier lancement, Classique, et la question ne revient pas.
    public func fermerSansChoisir() async throws {
        if magasin.reglages.versionApp == nil {
            try await magasin.modifierReglages { $0.setVersionApp(.classique) }
        }
        ferme = true
    }
}
