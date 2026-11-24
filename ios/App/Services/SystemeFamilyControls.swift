import Ecrans
import Foundation
#if !SANS_BARRIERE
import FamilyControls
#endif

/// L'autorisation de Temps d'écran et la sélection des applications de la barrière (PORTAGE.md § 2.1.2, § 2.1.3),
/// pour l'écran du choix des applications (`ApplicationsModele`) : `AppsAutorisation` et `AppsSelectionStock`.
///
/// La sélection (`FamilyActivitySelection`, Codable) est gardée en liste de propriétés dans le conteneur du groupe
/// d'apps, `barriere/selection.plist`, à côté de `barriere/etat.json` (PORTAGE.md § 3.2) : l'app seule l'écrit, les
/// extensions de la barrière la liront pour poser le bouclier. Ce fichier n'existait pas encore : son nom est ici
/// (`SystemeFamilyControls.fichier`), à reprendre par les extensions.
///
/// Rien ne fait semblant : sans l'entitlement `com.apple.developer.family-controls` accordé par Apple (décision D3),
/// `requestAuthorization` échoue et l'écran le dit ; sans le groupe d'apps accordé à la signature, le conteneur
/// n'existe pas, la sélection ne s'écrit pas, et l'écran le dit aussi.
///
/// Sans état, et hors de l'acteur principal : `AuthorizationCenter` n'est pas `Sendable`, il ne sort jamais d'une
/// fonction non isolée.
struct SystemeFamilyControls: AppsAutorisation, AppsSelectionStock, Sendable {

    /// Le groupe d'apps de l'app, des widgets et des extensions (project.yml).
    static let groupe = "group.com.myhitbodedut"
    /// Le dossier de la barrière dans le conteneur du groupe, où vivent aussi `etat.json` et `boite.jsonl`.
    static let dossier = "barriere"
    /// La sélection encodée (`PropertyListEncoder`).
    static let fichier = "selection.plist"

    /// Le conteneur du groupe n'existe pas : le groupe n'est pas accordé à la signature.
    struct GroupeAbsent: Error {}

    init() {}

    /// `barriere/selection.plist` dans le conteneur du groupe ; nil sans conteneur.
    private var adresse: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SystemeFamilyControls.groupe)?
            .appending(path: SystemeFamilyControls.dossier, directoryHint: .isDirectory)
            .appending(path: SystemeFamilyControls.fichier, directoryHint: .notDirectory)
    }

    // MARK: AppsSelectionStock

    func lire() async -> Data? {
        guard let adresse else { return nil }
        return try? Data(contentsOf: adresse)
    }

    /// Écriture atomique ; lisible dès le premier déverrouillage, pour l'extension de surveillance réveillée
    /// le matin, téléphone encore verrouillé. nil efface le fichier.
    func ecrire(_ donnees: Data?) async throws {
        guard let adresse else { throw GroupeAbsent() }
        let fichiers = FileManager.default
        if let donnees {
            try fichiers.createDirectory(at: adresse.deletingLastPathComponent(), withIntermediateDirectories: true)
            try donnees.write(to: adresse, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            // Hors de la sauvegarde iCloud (PORTAGE.md § 3.2 : des jetons liés à cet iPhone, inutilisables ailleurs),
            // après chaque écriture comme Depot : le remplacement atomique ne garde pas l'attribut. La sélection est
            // écrite même si l'attribut ne se pose pas : ne pas dire le contraire à l'écran.
            var cible = adresse
            var valeurs = URLResourceValues()
            valeurs.isExcludedFromBackup = true
            try? cible.setResourceValues(valeurs)
        } else if fichiers.fileExists(atPath: adresse.path(percentEncoded: false)) {
            try fichiers.removeItem(at: adresse)
        }
    }

    func compter(_ donnees: Data) async -> ApplicationsCompte? {
        #if SANS_BARRIERE
        return nil
        #else
        guard let selection = SystemeFamilyControls.decoder(donnees) else { return nil }
        return ApplicationsCompte(applications: selection.applicationTokens.count,
                                  categories: selection.categoryTokens.count,
                                  sites: selection.webDomainTokens.count)
        #endif
    }

    /// Le nombre de jetons de la sélection gardée (`ReglagesBarriereSysteme.nombreDeJetons`, `Etat.nombreDeJetons`) :
    /// une application, une catégorie ou un site vaut un ; 0 sans sélection lisible.
    func nombreDeJetons() async -> Int {
        guard let donnees = await lire() else { return 0 }
        return await compter(donnees)?.total ?? 0
    }

    // MARK: AppsAutorisation

    #if SANS_BARRIERE

    /// La construction sans barrière n'a pas l'entitlement : rien n'est demandé, rien n'est accordé.
    func etat() async -> AppsAutorisationEtat {
        .nonDemandee
    }

    func demander() async -> AppsDemandeIssue {
        .echec
    }

    #else

    func etat() async -> AppsAutorisationEtat {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            return .nonDemandee
        case .denied:
            return .refusee
        default:
            // `.approved`, et ce qu'iOS y ajoute (`.approvedWithDataAccess`).
            return .accordee
        }
    }

    /// La feuille du système (Face ID ou code), pour soi-même (`.individual`).
    func demander() async -> AppsDemandeIssue {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return .accordee
        } catch let erreur as FamilyControlsError {
            switch erreur {
            case .authorizationCanceled:
                return .annulee
            case .restricted:
                return .restreinte
            default:
                // L'entitlement absent, Temps d'écran indisponible, un compte qui ne convient pas, pas de code…
                return .echec
            }
        } catch {
            return .echec
        }
    }

    // MARK: La sélection, pour la vue de l'app

    /// Les octets d'une sélection ; nil si elle ne s'encode pas.
    static func donnees(de selection: FamilyActivitySelection) -> Data? {
        try? PropertyListEncoder().encode(selection)
    }

    /// La sélection de ces octets ; une sélection vide sans octets, ou s'ils ne se lisent pas.
    static func selection(de donnees: Data?) -> FamilyActivitySelection {
        donnees.flatMap(decoder) ?? FamilyActivitySelection()
    }

    private static func decoder(_ donnees: Data) -> FamilyActivitySelection? {
        try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: donnees)
    }

    #endif
}
