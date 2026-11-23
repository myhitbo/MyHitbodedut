import ActivityKit
import AppIntents
import Coeur
import Ecrans
import Foundation

// Ce que l'app et l'extension des widgets partagent (compilé dans les deux cibles, project.yml) : le dossier du
// journal et des réglages (le conteneur du groupe d'apps, que les widgets lisent), les noms des widgets que l'app
// fait redessiner, les attributs de la Live Activity de la séance (tâche 17, PORTAGE.md § 2.2.1) et l'action
// « Terminer maintenant » qu'elle et le widget de la série portent (SessionService.ACTION_FINISH).

/// Le dossier du journal et des réglages.
enum DossierApp {
    /// L'identifiant du groupe d'apps (les entitlements de l'app, des widgets et des extensions).
    static let groupe = "group.com.myhitbodedut"

    /// Le conteneur du groupe ; nil quand la signature ne le donne pas (une construction sans signature).
    static var partage: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupe)
    }

    /// Celui de l'app : le conteneur du groupe, sinon Application Support (les widgets n'y lisent alors rien).
    static var app: URL {
        partage ?? URL.applicationSupportDirectory.appending(path: "MyHitbodedut")
    }

    /// La langue de l'app (« fr », « en », « he », « es », « ar »), retenue par l'app à chaque lancement pour que les
    /// widgets parlent comme elle (LangueApp.envelopper) ; nil avant le premier lancement.
    static var langue: String? {
        UserDefaults(suiteName: groupe)?.string(forKey: "langue_app")
    }

    static func retenirLangue(_ langue: String) {
        UserDefaults(suiteName: groupe)?.set(langue, forKey: "langue_app")
    }
}

/// Les genres des widgets (`kind`), que l'app fait redessiner (ZmanimWidget.refresh, StreakWidget.refresh,
/// BoussoleWidget.refresh).
enum GenresWidgets {
    static let zmanimPetit = "zmanim-petit"
    static let zmanim = "zmanim"
    static let zmanimGrand = "zmanim-grand"
    static let serie = "serie"
    static let boussole = "boussole"
    static let verrouille = "zmanim-verrouille"
}

// MARK: La Live Activity de la séance

/// La séance en cours sur l'écran verrouillé et dans l'île dynamique : la notification permanente de
/// SessionService. Les textes arrivent déjà traduits par l'app (SeanceAffichee).
struct SeanceAttributs: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var debut: Date
        /// La fin prévue ; sans durée, le plafond de 240 minutes.
        var fin: Date
        /// Le minuteur descend vers la fin ; sinon il monte depuis le début.
        var decompte: Bool
        /// Compteur masqué : la phrase à la place du minuteur.
        var texteMasque: String?
    }

    /// « Hitbodedout en cours ».
    var titre: String
    /// « Terminer maintenant ».
    var terminer: String
}

/// Ce qui termine la séance de l'app : posé par l'app à son lancement (ModelesApp).
@MainActor
enum PontSeance {
    static var terminer: (@MainActor () async -> Void)?
}

/// « Terminer maintenant » (SessionService.ACTION_FINISH) : la Live Activity et le widget de la série terminent la
/// séance sans ouvrir l'app ; le temps passé est inscrit au jour du début, s'il fait au moins une minute.
struct TerminerSeanceIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "session_finish_now"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await TerminerSeanceIntent.terminer()
        return .result()
    }

    @MainActor
    private static func terminer() async {
        if let terminer = PontSeance.terminer {
            await terminer()
            return
        }
        // L'app n'a pas encore ses modèles (lancée en arrière-plan pour l'action) : la séance se termine sur les
        // fichiers, puis sa Live Activity se retire.
        if let magasin = try? await Magasin.charger(PersistanceFichiers(dossier: DossierApp.app)) {
            try? await SeanceEnCours(magasin: magasin, horloge: HorlogeSysteme()).terminer()
        }
        await SeanceAttributs.retirerTout()
    }
}

extension SeanceAttributs {
    /// Retire toutes les Live Activities de la séance, sans attendre.
    static func retirerTout() async {
        for activite in Activity<SeanceAttributs>.activities {
            await activite.end(nil, dismissalPolicy: .immediate)
        }
    }
}
