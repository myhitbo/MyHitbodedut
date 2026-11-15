import Foundation

/// L'unique écrivain de `journal.json`, `reglages.json` et `lecture.json` (PORTAGE.md § 3.2) : écriture
/// atomique, et un fichier illisible mis de côté avant d'être remplacé, comme `days_corrompu` sur
/// Android. Repris de la PR #29, avec la lecture (favoris, marque-pages) et la sauvegarde chiffrée.
public actor Depot {
    public static let fichierJournal = "journal.json"
    public static let fichierReglages = "reglages.json"
    public static let fichierLecture = "lecture.json"

    /// Le nom de la copie d'un fichier illisible : « journal.corrompu.json ». Une seule est gardée,
    /// la première, comme Android (`if (!p.contains(KEY_DAYS_CORROMPU))`).
    public static func corrompu(_ nom: String) -> String {
        nom.hasSuffix(".json") ? String(nom.dropLast(5)) + ".corrompu.json" : nom + ".corrompu"
    }

    public enum Erreur: Error, Equatable {
        case ecriture(String)
        /// Au-delà de 2 Mo (`import_failed` d'Android).
        case tropGros
        /// Une sauvegarde chiffrée, sans mot de passe donné : le demander.
        case motDePasseAttendu
        /// Le mot de passe ne l'ouvre pas, ou le fichier est abîmé (`import_mdp_faux`) : le redemander.
        case motDePasseFaux
    }

    private let dossier: URL
    private var donnees: Donnees
    /// Le journal suit-il l'iPhone dans sa sauvegarde (iCloud ou ordinateur) ? Non par défaut, comme
    /// `backup_rules.xml` sur Android (§ 2.2.8, décision D6).
    private let journalSauvegarde: Bool

    /// Ouvre le dépôt d'un dossier (le conteneur partagé de l'app). `enIsrael` : la valeur déduite du
    /// fuseau, prise seulement si les réglages ne la portent pas encore.
    public init(dossier: URL, enIsrael: Bool, journalDansLaSauvegarde: Bool = false) {
        self.dossier = dossier
        journalSauvegarde = journalDansLaSauvegarde
        let journal = Depot.lire(dossier, Depot.fichierJournal).map { Journal($0) } ?? Journal()
        let reglages = Depot.lire(dossier, Depot.fichierReglages).map { Reglages($0, enIsrael: enIsrael) }
            ?? Reglages(enIsrael: enIsrael)
        let lecture = Depot.lire(dossier, Depot.fichierLecture).map { Lecture($0) } ?? Lecture()
        donnees = Donnees(journal: journal, reglages: reglages, lecture: lecture)
    }

    public var journal: Journal { donnees.journal }
    public var reglages: Reglages { donnees.reglages }
    public var lecture: Lecture { donnees.lecture }
    public var tout: Donnees { donnees }

    /// Modifie et écrit les trois fichiers.
    public func modifier(_ changement: @Sendable (inout Donnees) -> Void) throws {
        var d = donnees
        changement(&d)
        try ecrire(d)
    }

    /// Fusionne une sauvegarde (claire, ou chiffrée avec `motDePasse`) : le nombre de journées lues, ou
    /// nil si le fichier n'est pas une sauvegarde. Rien n'est écrit si l'import échoue.
    public func importer(_ fichier: Data, aujourdhui: JourCivil, motDePasse: String? = nil) throws -> Int? {
        guard var texte = Sauvegarde.texte(fichier) else { throw Erreur.tropGros }
        if Coffre.estChiffre(texte) {
            guard let motDePasse else { throw Erreur.motDePasseAttendu }
            guard let clair = Coffre.dechiffrer(texte, motDePasse: motDePasse) else { throw Erreur.motDePasseFaux }
            texte = clair
        }
        var d = donnees
        guard let lues = Sauvegarde.importer(texte, dans: &d, aujourdhui: aujourdhui) else { return nil }
        try ecrire(d)
        return lues
    }

    /// La sauvegarde, en UTF-8 sans BOM ; chiffrée si `motDePasse` n'est pas vide, comme sur Android.
    /// `iterations` ne se règle que dans les tests.
    public func exporter(maintenant: Date, motDePasse: String = "", iterations: Int = Coffre.iterations) -> Data {
        let clair = Sauvegarde.exporter(donnees, maintenant: maintenant)
        return Data((motDePasse.isEmpty ? clair : Coffre.chiffrer(clair, motDePasse: motDePasse, iterations: iterations)).utf8)
    }

    private func ecrire(_ d: Donnees) throws {
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            let journal = dossier.appendingPathComponent(Depot.fichierJournal)
            try Data(d.journal.objet.texte().utf8).write(to: journal, options: .atomic)
            #if canImport(Darwin)
            // L'écriture atomique remplace le fichier : la marque se repose à chaque fois.
            var marque = URLResourceValues()
            marque.isExcludedFromBackup = !journalSauvegarde
            var url = journal
            try url.setResourceValues(marque)
            #endif
            try Data(d.reglages.objet.texte().utf8).write(to: dossier.appendingPathComponent(Depot.fichierReglages),
                                                          options: .atomic)
            try Data(d.lecture.objet.texte().utf8).write(to: dossier.appendingPathComponent(Depot.fichierLecture),
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
        if let o = try? ObjetJSON(texte: String(decoding: octets, as: UTF8.self)) { return o }
        let copie = dossier.appendingPathComponent(corrompu(nom))
        if !FileManager.default.fileExists(atPath: copie.path) {
            try? octets.write(to: copie, options: .atomic)
        }
        return nil
    }
}
