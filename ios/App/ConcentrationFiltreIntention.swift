import AppIntents
import Ecrans
import Foundation

/// Le filtre de mode de concentration de l'app (PORTAGE.md § 2.2.6) : dans Réglages → Concentration → un mode →
/// « Filtres de concentration » → « Ajouter un filtre » → MyHitbodedut, l'utilisateur choisit de « Masquer le
/// décompte de la séance » tant que ce mode est actif. iOS appelle `perform()` quand le mode s'active, quand le
/// filtre change, et quand le mode s'éteint, avec alors les valeurs par défaut : `false` par défaut, pour qu'un
/// mode qui s'éteint rende toujours le décompte. Le choix s'écrit dans les réglages (`ConcentrationFiltre`, une clé
/// propre à iOS) ; l'écran de séance la lit (`SeanceModele.decompte`).
///
/// Les chaînes sont dans la table « ios » (Ressources/Chaines/ios.xcstrings), écrites en toutes lettres : les
/// métadonnées d'App Intents, extraites à la construction, veulent des littéraux (`ConcentrationFiltre.clesIntention`
/// les nomme pour le test du catalogue).
struct ConcentrationFiltreIntention: SetFocusFilterIntent {

    static var title: LocalizedStringResource {
        LocalizedStringResource("concentration_filtre_intention_titre", table: "ios")
    }

    static var description: IntentDescription? {
        IntentDescription(LocalizedStringResource("concentration_filtre_intention_description", table: "ios"))
    }

    @Parameter(title: LocalizedStringResource("concentration_filtre_masquer", table: "ios"), default: false)
    var masquerDecompte: Bool

    /// Ce que les Réglages montrent du filtre réglé : son titre, et le décompte masqué ou visible.
    var displayRepresentation: DisplayRepresentation {
        let resume = masquerDecompte
            ? LocalizedStringResource("concentration_filtre_resume_masque", table: "ios")
            : LocalizedStringResource("concentration_filtre_resume_libre", table: "ios")
        return DisplayRepresentation(title: LocalizedStringResource("concentration_filtre_intention_titre",
                                                                    table: "ios"),
                                     subtitle: resume)
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await ConcentrationRelais.ecrire(masquerDecompte)
        return .result()
    }
}

/// Le chemin du filtre jusqu'au magasin de l'app. Le magasin est lu une fois, au lancement (`Lancement.charger`),
/// qui le pose ici : le choix du filtre passe alors par lui, et l'écran de séance ouvert le voit tout de suite.
/// Quand iOS lance l'app en arrière-plan pour le seul filtre, aucune scène ne paraît et le magasin n'est pas lu :
/// le filtre lit alors les fichiers, y écrit son choix, et le lancement suivant le relira.
@MainActor
enum ConcentrationRelais {

    /// Le magasin de l'app, posé par `Lancement.charger` une fois lu ; nil avant.
    static var magasin: Magasin?

    static func ecrire(_ masquer: Bool) async throws {
        // La Live Activity montrée masque ou rend son décompte tout de suite, même quand iOS lance l'app pour le seul
        // filtre.
        await ActiviteSeanceKit.concentration(masquer)
        if let magasin {
            try await ConcentrationFiltre.ecrire(masquer, dans: magasin)
            return
        }
        let lu = try await Magasin.charger(ServicesApp.persistance())
        try await ConcentrationFiltre.ecrire(masquer, dans: lu)
        // Le lancement a pu lire ses fichiers pendant ce temps, avant cette écriture : il reçoit le même choix.
        if let vivant = magasin {
            try await ConcentrationFiltre.ecrire(masquer, dans: vivant)
        }
    }
}
