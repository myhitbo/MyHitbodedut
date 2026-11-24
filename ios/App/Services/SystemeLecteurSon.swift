import AVFAudio
import Ecrans
import Foundation

/// Le son de fin d'un décompte masqué (la sonnerie de notification d'Android, SessionService), et tout fichier des
/// ressources qu'un écran fait jouer : `AVAudioPlayer` sur la session `.playback`.
///
/// Le fichier se cherche dans le paquet : tel quel s'il a une extension (« Musique/<id>.m4a »), sinon sous
/// Musique/ puis à la racine, en .m4a, .caf, .wav ou .mp3. Un fichier introuvable lève `Absent` : le son de fin
/// (`SeanceEnCours.sonDeFin`, « fin_seance ») n'est pas encore livré dans Ressources/, et la séance se clôt pareil,
/// sans faire croire qu'il a sonné.
@MainActor
final class SystemeLecteurSon: LecteurSon {

    /// Le fichier n'est pas dans le paquet.
    struct Absent: Error, Sendable {
        let fichier: String
    }

    /// La session audio a été refusée, ou le fichier ne se lit pas.
    struct Illisible: Error, Sendable {
        let fichier: String
    }

    private var lecteur: AVAudioPlayer?

    init() {}

    func jouer(fichier: String, volume: Int) async throws {
        arreterMaintenant()
        guard let adresse = SystemeLecteurSon.adresse(fichier) else { throw Absent(fichier: fichier) }
        guard SystemeSessionAudio.activer() else { throw Illisible(fichier: fichier) }
        let lecteur = try AVAudioPlayer(contentsOf: adresse)
        lecteur.volume = Float(min(max(volume, 0), 100)) / 100
        _ = lecteur.prepareToPlay()
        guard lecteur.play() else { throw Illisible(fichier: fichier) }
        self.lecteur = lecteur
    }

    func arreter() async {
        arreterMaintenant()
    }

    private func arreterMaintenant() {
        lecteur?.stop()
        lecteur = nil
    }

    private static func adresse(_ fichier: String) -> URL? {
        let paquet = SystemeDossiers.paquet
        let gestionnaire = FileManager.default
        var candidats: [String] = []
        if !(fichier as NSString).pathExtension.isEmpty {
            candidats.append(fichier)
        } else {
            for extensionSon in ["m4a", "caf", "wav", "mp3"] {
                candidats.append("Musique/" + fichier + "." + extensionSon)
                candidats.append(fichier + "." + extensionSon)
            }
        }
        for chemin in candidats {
            let url = paquet.appending(path: chemin, directoryHint: .notDirectory)
            if gestionnaire.fileExists(atPath: url.path(percentEncoded: false)) {
                return url
            }
        }
        return nil
    }
}
