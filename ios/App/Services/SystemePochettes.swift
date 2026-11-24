import AVFoundation
import Ecrans
import Foundation

/// La photo enregistrée dans un fichier audio, pour le disque du mini-lecteur (MediaMetadataRetriever.embeddedPicture
/// d'Android) : l'élément « artwork » des métadonnées communes d'`AVURLAsset`. nil si le fichier n'en a pas, ou ne
/// se lit pas.
struct SystemePochettes: MusiquePochettes {

    init() {}

    func pochette(_ fichier: MusiqueFichierAudio) async -> Data? {
        let adresse = SystemeDossiers.url(fichier)
        let ouvert = adresse.startAccessingSecurityScopedResource()
        defer {
            if ouvert { adresse.stopAccessingSecurityScopedResource() }
        }
        let piste = AVURLAsset(url: adresse)
        guard let elements = try? await piste.load(.commonMetadata) else { return nil }
        for element in elements where element.commonKey == .commonKeyArtwork {
            if let donnees = try? await element.load(.dataValue) {
                return donnees
            }
        }
        return nil
    }
}
