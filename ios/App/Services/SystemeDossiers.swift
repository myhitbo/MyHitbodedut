import Ecrans
import Foundation

/// Les dossiers de l'app, en un seul endroit : où vivent le journal et les réglages, les morceaux ajoutés, les
/// ressources livrées. Les modèles d'écran ne lisent jamais `Bundle.main` ni `FileManager` (ECRANS.md) : ce
/// qu'ils reçoivent vient d'ici.
enum SystemeDossiers {

    /// Le paquet de l'app : Musique/, Contenu/, Chaines/…
    static var paquet: URL {
        Bundle.main.bundleURL
    }

    /// Les Documents de l'app : les morceaux ajoutés y sont copiés (`Documents/Musique/`, PORTAGE.md § 3.2), et se
    /// sauvegardent avec l'iPhone.
    static var documents: URL {
        URL.documentsDirectory
    }

    /// Le dossier du journal et des réglages (`journal.json`, `reglages.json`) : « MyHitbodedut » dans
    /// Application Support, que l'utilisateur ne voit pas dans Fichiers. Le dépôt le crée à sa première écriture.
    ///
    /// PORTAGE.md § 3.2 les veut dans le conteneur du groupe d'apps, pour que les widgets les lisent ; ce
    /// conteneur n'existe qu'une fois le groupe accordé à la signature. Le jour où il l'est, ce dossier change ici
    /// seulement, et il faudra déplacer les deux fichiers une fois (sinon le journal paraîtrait vide).
    static var donnees: URL {
        URL.applicationSupportDirectory.appending(path: "MyHitbodedut", directoryHint: .isDirectory)
    }

    /// L'adresse d'un morceau : sous le paquet pour un morceau livré (« Musique/<id>.m4a »), sous les Documents pour
    /// un morceau ajouté (« Musique/Nigoun.m4a », la référence de sa copie).
    static func url(_ fichier: MusiqueFichierAudio) -> URL {
        switch fichier {
        case .livre(let chemin):
            return paquet.appending(path: chemin, directoryHint: .notDirectory)
        case .ajoute(let reference):
            return documents.appending(path: reference, directoryHint: .notDirectory)
        }
    }
}
