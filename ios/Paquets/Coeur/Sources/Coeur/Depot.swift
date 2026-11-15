import Foundation

/// L'unique écrivain de `journal.json` et de `reglages.json` (PORTAGE.md § 3.2) : écriture atomique,
/// et un fichier illisible mis de côté avant d'être remplacé, comme `days_corrompu` sur Android.
public actor Depot {
    public static let fichierJournal = "journal.json"
    public static let fichierReglages = "reglages.json"

    /// Le nom de la copie d'un fichier illisible : « journal.corrompu.json ». Une seule est gardée,
    /// la première, comme Android (`if (!p.contains(KEY_DAYS_CORROMPU))`).
    public static func corrompu(_ nom: String) -> String {
        nom.hasSuffix(".json") ? String(nom.dropLast(5)) + ".corrompu.json" : nom + ".corrompu"
    }

    public enum Erreur: Error, Equatable {
        case ecriture(String)
    }

    private let dossier: URL
    private var donnees: Donnees

    /// Ouvre le dépôt d'un dossier (le conteneur partagé de l'app). `enIsrael` : la valeur déduite du
    /// fuseau, prise seulement si les réglages ne la portent pas encore.
    public init(dossier: URL, enIsrael: Bool) {
        self.dossier = dossier
        let journal = Depot.lire(dossier, Depot.fichierJournal).map { Journal($0) } ?? Journal()
        let reglages = Depot.lire(dossier, Depot.fichierReglages).map { Reglages($0, enIsrael: enIsrael) }
            ?? Reglages(enIsrael: enIsrael)
        donnees = Donnees(journal: journal, reglages: reglages)
    }

    public var journal: Journal { donnees.journal }
    public var reglages: Reglages { donnees.reglages }
    public var tout: Donnees { donnees }

    /// Modifie et écrit les deux fichiers.
    public func modifier(_ changement: @Sendable (inout Donnees) -> Void) throws {
        var d = donnees
        changement(&d)
        try ecrire(d)
    }

    /// Fusionne une sauvegarde ; nil si le fichier est invalide, `Sauvegarde.Refus` s'il est trop gros
    /// (et rien n'est écrit).
    public func importer(_ fichier: Data, aujourdhui: JourCivil) throws -> Int? {
        var d = donnees
        guard let lues = try Sauvegarde.importer(fichier, dans: &d, aujourdhui: aujourdhui) else { return nil }
        try ecrire(d)
        return lues
    }

    /// La sauvegarde, en UTF-8 sans BOM.
    public func exporter(maintenant: Int64) -> Data {
        Data(Sauvegarde.exporter(donnees, maintenant: maintenant).utf8)
    }

    private func ecrire(_ d: Donnees) throws {
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            let journal = dossier.appendingPathComponent(Depot.fichierJournal)
            try Data(d.journal.objet.texte().utf8).write(to: journal, options: .atomic)
            // Hors de la sauvegarde iCloud, comme backup_rules.xml (§ 3.2, décision D6). L'écriture atomique
            // remplace le fichier : la marque est reposée à chaque fois.
            #if canImport(Darwin)
            var marque = journal
            var hors = URLResourceValues()
            hors.isExcludedFromBackup = true
            try marque.setResourceValues(hors)
            #endif
            try Data(d.reglages.objet.texte().utf8).write(to: dossier.appendingPathComponent(Depot.fichierReglages),
                                                          options: .atomic)
        } catch {
            throw Erreur.ecriture(String(describing: error))
        }
        donnees = d
    }

    /// Le fichier lu ; nil s'il manque. Illisible, il est copié de côté (une fois) et nil est rendu.
    private static func lire(_ dossier: URL, _ nom: String) -> ObjetJSON? {
        let url = dossier.appendingPathComponent(nom)
        guard let octets = try? Data(contentsOf: url) else { return nil }
        if let texte = String(data: octets, encoding: .utf8), let o = try? ObjetJSON(texte: texte) { return o }
        let copie = dossier.appendingPathComponent(corrompu(nom))
        if !FileManager.default.fileExists(atPath: copie.path) {
            try? octets.write(to: copie, options: .atomic)
        }
        return nil
    }
}
