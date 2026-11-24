import AVFAudio
import Foundation

/// La session audio de l'app, partagée par la musique, les ambiances et le son de fin : `.playback`, pour que les
/// autres apps se taisent pendant la séance (le focus audio d'Android, AUDIOFOCUS_GAIN) et que la musique tienne
/// l'écran éteint (le mode d'arrière-plan « audio » de l'Info.plist).
enum SystemeSessionAudio {

    /// Pose la catégorie et active la session ; faux si iOS la refuse (un appel en cours) : rien ne joue alors.
    @MainActor
    static func activer() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }
}
