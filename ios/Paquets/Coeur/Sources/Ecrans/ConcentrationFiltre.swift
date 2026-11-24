import Foundation
import Coeur

// Le filtre de mode de concentration (PORTAGE.md § 2.2.6) : iOS ne laisse aucune app activer un mode de
// concentration (NePasDeranger.kt n'a pas d'équivalent), mais un mode que l'utilisateur a créé peut, quand il
// s'active ou se désactive, dire à l'app ce qu'elle doit faire. L'app reçoit ce choix par un `SetFocusFilterIntent`
// (ios/App/ConcentrationFiltreIntention.swift) et l'écrit ici, dans les réglages, sous une clé propre à iOS
// qu'Android ignore : l'écran de séance la lit (`SeanceModele.decompte`).

/// « Masquer le décompte de la séance » quand le mode de concentration qui porte le filtre est actif.
public enum ConcentrationFiltre {

    /// La clé propre à iOS, dans les réglages (absente d'Android, qui ne la lit pas) ; absente : rien n'est masqué.
    public static let cle = "ios_concentration_masquer_decompte"

    /// Les chaînes du filtre dans les Réglages d'iOS (table « ios »), que l'intention de l'app écrit en toutes
    /// lettres (les métadonnées d'App Intents veulent des littéraux) : le titre, la description, le paramètre et
    /// les deux résumés. Le test vérifie qu'elles sont au catalogue, dans les trois langues.
    public static let clesIntention = [
        "concentration_filtre_intention_titre",
        "concentration_filtre_intention_description",
        "concentration_filtre_masquer",
        "concentration_filtre_resume_masque",
        "concentration_filtre_resume_libre",
    ]

    /// Le filtre actif masque-t-il le décompte ? Vrai seulement pour une valeur lue vraie comme Android lit un
    /// booléen (`commeBooleen` : true, ou la chaîne « true ») ; un nombre ne compte pas.
    public static func masqueDecompte(_ reglages: Reglages) -> Bool {
        reglages.brut[cle]?.commeBooleen ?? false
    }

    /// Le choix du filtre : vrai pose la clé ; faux la retire, pour que des réglages sans filtre restent ceux
    /// d'Android. Les autres préférences gardent leur place.
    public static func poser(_ masquer: Bool, dans reglages: inout Reglages) {
        var brut = reglages.brut
        brut[cle] = masquer ? JSON.booleen(true) : nil
        reglages = Reglages(brut: brut)
    }

    /// Écrit le choix dans le magasin (un choix qui ne change rien n'écrit rien, `Magasin.modifierReglages`).
    @MainActor
    public static func ecrire(_ masquer: Bool, dans magasin: Magasin) async throws {
        try await magasin.modifierReglages { reglages in
            poser(masquer, dans: &reglages)
        }
    }
}
