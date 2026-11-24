import Foundation
import Coeur

/// La persistance de l'app : les fichiers d'Android portés (`journal.json` et `reglages.json`, PORTAGE.md § 3.2)
/// par l'acteur `Depot` de Coeur, l'unique écrivain de ces deux fichiers. Le `Magasin` la reçoit comme il reçoit
/// la persistance en mémoire des tests.
///
/// Ce que le dépôt fait déjà, et que cet adaptateur ne refait pas : l'écriture atomique (jamais un fichier à
/// moitié écrit), la lecture tolérante (un fichier absent est un dépôt neuf), la mise de côté d'un fichier
/// illisible (`journal.illisible.json`…) avant que la prochaine écriture ne le remplace, comme la préférence
/// `days_corrompu` d'Android, et l'exclusion du journal de la sauvegarde iCloud (décision D6).
///
/// Le dépôt garde en mémoire ce qu'il a lu ou écrit : une écriture du `Magasin` remplace le fichier entier par
/// la valeur qu'il tient, et rien n'est écrit quand elle ne change rien.
public struct PersistanceDepot: Persistance {

    /// Le dépôt des deux fichiers : l'app s'en sert aussi pour l'export et l'import de la sauvegarde.
    public let depot: Depot

    public init(depot: Depot) {
        self.depot = depot
    }

    /// Les fichiers de ce dossier ; `journalHorsSauvegarde` : le journal est exclu de la sauvegarde iCloud
    /// (sans effet hors des systèmes d'Apple).
    public init(dossier: URL, journalHorsSauvegarde: Bool = true) {
        depot = Depot(dossier: dossier, journalHorsSauvegarde: journalHorsSauvegarde)
    }

    public func lire() async throws -> Enregistrement {
        let journal = try await depot.journal()
        let reglages = try await depot.reglages()
        return Enregistrement(journal: journal, reglages: reglages)
    }

    public func enregistrer(journal: Journal) async throws {
        try await depot.modifier { $0 = journal }
    }

    public func enregistrer(reglages: Reglages) async throws {
        try await depot.modifierReglages { $0 = reglages }
    }

    /// Les copies des fichiers illisibles que ce dépôt a faites, dans l'ordre : l'app peut le dire.
    public func misDeCote() async -> [URL] {
        await depot.misDeCote
    }
}
