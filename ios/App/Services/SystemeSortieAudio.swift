import AVFAudio
import Ecrans
import Foundation

/// La lecture d'un morceau (MusicPlayer.kt d'Android) : `AVAudioPlayer` sur la session `.playback`. Un seul morceau
/// à la fois : en jouer un autre arrête, sans fondu, celui qui jouait. La fin d'un morceau joué sans boucle, une
/// erreur de décodage en cours de lecture et les interruptions du système (un appel, une alarme) sont annoncées dans
/// `evenements`, que `MusiqueLecteur.ecouter` lit.
///
/// L'app en crée deux : celle de la séance, que tient le `MusiqueLecteur` partagé, et celle de l'aperçu de l'écran
/// de la musique.
@MainActor
final class SystemeSortieAudio: NSObject, MusiqueSortieAudio, AVAudioPlayerDelegate {

    nonisolated let evenements: AsyncStream<MusiqueEvenementAudio>
    private let annonce: AsyncStream<MusiqueEvenementAudio>.Continuation

    private var lecteur: AVAudioPlayer?
    private var numero: Int?
    private var observateur: (any NSObjectProtocol)?

    /// `ecouterInterruptions` : la sortie annonce les interruptions du système (celle de la séance) ; celle de
    /// l'aperçu, qu'un appel arrête aussi, n'a personne pour les lire.
    init(ecouterInterruptions: Bool = true) {
        let (flux, suite) = AsyncStream.makeStream(of: MusiqueEvenementAudio.self)
        evenements = flux
        annonce = suite
        super.init()
        if ecouterInterruptions {
            observateur = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { notification in
                    guard let evenement = SystemeSortieAudio.evenement(notification.userInfo) else { return }
                    suite.yield(evenement)
                }
        }
    }

    /// L'annonce d'une interruption de la session : AUDIOFOCUS_LOSS_TRANSIENT, puis AUDIOFOCUS_GAIN avec
    /// `.shouldResume`.
    private nonisolated static func evenement(_ infos: [AnyHashable: Any]?) -> MusiqueEvenementAudio? {
        guard let brut = infos?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: brut) else { return nil }
        switch type {
        case .began:
            return .interruption
        case .ended:
            let options = (infos?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            return .finInterruption(reprendre: AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume))
        @unknown default:
            return nil
        }
    }

    // MARK: MusiqueSortieAudio

    func jouer(_ fichier: MusiqueFichierAudio, gain: Float, enBoucle: Bool, numero: Int) async -> Bool {
        vider()
        guard SystemeSessionAudio.activer() else { return false }
        let lecteur: AVAudioPlayer
        do {
            lecteur = try AVAudioPlayer(contentsOf: SystemeDossiers.url(fichier))
        } catch {
            return false
        }
        lecteur.delegate = self
        lecteur.numberOfLoops = enBoucle ? -1 : 0
        lecteur.volume = SystemeSortieAudio.borne(gain)
        _ = lecteur.prepareToPlay()
        guard lecteur.play() else { return false }
        self.lecteur = lecteur
        self.numero = numero
        return true
    }

    func pause() async {
        lecteur?.pause()
    }

    func reprendre() async {
        guard let lecteur, SystemeSessionAudio.activer() else { return }
        _ = lecteur.play()
    }

    func aller(a millisecondes: Int) async {
        lecteur?.currentTime = TimeInterval(max(millisecondes, 0)) / 1000
    }

    func regler(gain: Float) async {
        lecteur?.volume = SystemeSortieAudio.borne(gain)
    }

    /// Le fondu de MusicPlayer.stop : dix pas de 60 ms, le volume ramené à rien, puis l'arrêt. Un morceau lancé
    /// pendant le fondu n'en est pas touché : le fondu ne tient que le lecteur qu'il arrête.
    func arreter(fondu: Bool) async {
        guard let lecteur = detacher() else { return }
        guard fondu, lecteur.isPlaying else {
            lecteur.stop()
            return
        }
        let depart = lecteur.volume
        for pas in stride(from: 9, through: 0, by: -1) {
            lecteur.volume = depart * Float(pas) / 10
            try? await Task.sleep(for: .milliseconds(60))
        }
        lecteur.stop()
    }

    func instantane() async -> MusiqueInstantane {
        guard let lecteur else { return MusiqueInstantane() }
        return MusiqueInstantane(joue: lecteur.isPlaying,
                                 position: Int((lecteur.currentTime * 1000).rounded(.down)),
                                 duree: Int((lecteur.duration * 1000).rounded(.down)))
    }

    /// Arrête et oublie le lecteur courant.
    private func vider() {
        detacher()?.stop()
    }

    /// Oublie le lecteur courant sans l'arrêter, et le rend : ses annonces à venir ne portent plus de numéro.
    @discardableResult
    private func detacher() -> AVAudioPlayer? {
        let ancien = lecteur
        ancien?.delegate = nil
        lecteur = nil
        numero = nil
        return ancien
    }

    private func fini(_ joueur: ObjectIdentifier, echec: Bool) {
        guard let lecteur, ObjectIdentifier(lecteur) == joueur, let numero else { return }
        annonce.yield(echec ? .echec(numero: numero) : .fin(numero: numero))
    }

    private static func borne(_ gain: Float) -> Float {
        min(max(gain, 0), 1)
    }

    // MARK: AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let joueur = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            self?.fini(joueur, echec: !flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let joueur = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            self?.fini(joueur, echec: true)
        }
    }
}
