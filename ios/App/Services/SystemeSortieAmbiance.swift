import AVFAudio
import Ecrans
import Foundation

/// La lecture en boucle d'une ambiance sous la musique (AmbiancePlayer d'Android, un AudioTrack en mode statique) :
/// `AVAudioEngine` et un `AVAudioPlayerNode`, la boucle rendue par `MusiqueAmbianceSynth` (PCM 16 bits, mono)
/// recopiée en flottants dans un tampon que le nœud rejoue sans fin (`.loops`). Une ambiance à la fois.
///
/// L'app en crée deux : celle de la séance, que tient le `MusiqueLecteur` partagé, et celle de l'aperçu de l'écran
/// de la musique.
@MainActor
final class SystemeSortieAmbiance: MusiqueSortieAmbiance {

    private let moteur = AVAudioEngine()
    private let noeud = AVAudioPlayerNode()
    private var gain: Float = 1

    init() {
        moteur.attach(noeud)
    }

    func jouer(_ boucle: MusiqueBoucle, gain: Float) async {
        arreterMaintenant()
        guard !boucle.echantillons.isEmpty, boucle.taux > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(boucle.taux),
                                         channels: 1, interleaved: false),
              let tampon = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(boucle.echantillons.count)),
              let canal = tampon.floatChannelData?[0] else { return }
        for (rang, echantillon) in boucle.echantillons.enumerated() {
            canal[rang] = Float(echantillon) / 32_768
        }
        tampon.frameLength = AVAudioFrameCount(boucle.echantillons.count)
        guard SystemeSessionAudio.activer() else { return }
        moteur.disconnectNodeOutput(noeud)
        moteur.connect(noeud, to: moteur.mainMixerNode, format: format)
        do {
            try moteur.start()
        } catch {
            // Sans moteur (session refusée), l'ambiance se tait ; la musique et la séance continuent.
            return
        }
        self.gain = SystemeSortieAmbiance.borne(gain)
        noeud.volume = self.gain
        programmer(tampon)
        noeud.play()
    }

    func regler(gain: Float) async {
        self.gain = SystemeSortieAmbiance.borne(gain)
        noeud.volume = self.gain
    }

    func arreter() async {
        arreterMaintenant()
    }

    private func arreterMaintenant() {
        noeud.stop()
        if moteur.isRunning {
            moteur.stop()
        }
    }

    /// La boucle sans fin, sans rappel : elle ne finit qu'à l'arrêt du nœud.
    private func programmer(_ tampon: AVAudioPCMBuffer) {
        noeud.scheduleBuffer(tampon, at: nil, options: .loops, completionHandler: nil)
    }

    private static func borne(_ gain: Float) -> Float {
        min(max(gain, 0), 1)
    }
}
