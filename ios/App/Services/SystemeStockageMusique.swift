import Ecrans
import Foundation

/// La copie des morceaux qu'on ajoute depuis ses fichiers (PORTAGE.md § 2.2.4 et § 3.2) : sous
/// `Documents/Musique/`, ce qui survit au relancement et se sauvegarde avec l'iPhone. Android garde une adresse
/// `content://` et une permission persistante ; iOS copie le fichier.
///
/// La référence rendue est relative aux Documents (« Musique/Nigoun.m4a ») : elle a toujours une barre oblique,
/// qu'aucun morceau livré n'a. Un fichier déjà copié (même nom, même contenu) rend la référence de sa copie ; un
/// autre fichier du même nom prend « Musique/2-Nigoun.m4a », puis « Musique/3-… ».
struct SystemeStockageMusique: MusiqueStockage {

    /// Le dossier des copies, sous les Documents.
    static let dossier = "Musique"

    /// La copie est impossible : l'adresse choisie ne se lit pas.
    struct Illisible: Error, Sendable {}

    /// Les Documents de l'app.
    let documents: URL

    init(documents: URL = SystemeDossiers.documents) {
        self.documents = documents
    }

    func copier(_ source: URL) async throws -> String {
        // L'adresse que rend fileImporter est à accès protégé : ouvert le temps de la copie.
        let ouvert = source.startAccessingSecurityScopedResource()
        defer {
            if ouvert { source.stopAccessingSecurityScopedResource() }
        }
        let gestionnaire = FileManager.default
        let dossier = documents.appending(path: SystemeStockageMusique.dossier, directoryHint: .isDirectory)
        try gestionnaire.createDirectory(at: dossier, withIntermediateDirectories: true, attributes: nil)
        let nom = source.lastPathComponent
        guard !nom.isEmpty, nom != "/" else { throw Illisible() }
        var rang = 1
        while rang < 10_000 {
            let candidat = rang == 1 ? nom : String(rang) + "-" + nom
            let cible = dossier.appending(path: candidat, directoryHint: .notDirectory)
            let reference = SystemeStockageMusique.dossier + "/" + candidat
            if gestionnaire.fileExists(atPath: cible.path(percentEncoded: false)) {
                if gestionnaire.contentsEqual(atPath: cible.path(percentEncoded: false),
                                              andPath: source.path(percentEncoded: false)) {
                    return reference
                }
                rang += 1
                continue
            }
            try gestionnaire.copyItem(at: source, to: cible)
            return reference
        }
        throw Illisible()
    }

    func supprimer(_ reference: String) async {
        // Seule une copie de Documents/Musique s'efface : jamais un chemin qui en sortirait.
        guard reference.hasPrefix(SystemeStockageMusique.dossier + "/"), !reference.contains("..") else { return }
        let cible = documents.appending(path: reference, directoryHint: .notDirectory)
        try? FileManager.default.removeItem(at: cible)
    }
}
