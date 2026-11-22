@preconcurrency import AVFoundation
import Coeur
import Ecrans
import Foundation

// Les adaptateurs de la musique (MusiqueServices.swift d'Ecrans) : la lecture d'un morceau (`AVAudioPlayer`, la
// session `.playback` pour que la musique tienne l'écran éteint), la boucle d'ambiance (`AVAudioEngine`), la copie
// des morceaux ajoutés (`Documents/Musique/`) et la pochette d'un fichier (les métadonnées d'`AVURLAsset`).

/// La lecture d'un morceau (MusicPlayer.kt) : un seul à la fois ; en jouer un autre arrête celui qui jouait.
actor SortieAudioSysteme: MusiqueSortieAudio {
    nonisolated let evenements: AsyncStream<MusiqueEvenementAudio>
    private let annonce: AsyncStream<MusiqueEvenementAudio>.Continuation
    private let paquet: URL
    private let documents: URL
    private var lecteur: AVAudioPlayer?
    private var delegue: SortieAudioDelegue?
    private var gain: Float = 1
    /// L'observation des interruptions, le temps de l'app (la sortie vit autant qu'elle).
    private let interruptions: any NSObjectProtocol

    /// `paquet` : le paquet de l'app (les morceaux livrés, « Musique/<id>.m4a ») ; `documents` : là où sont les
    /// copies des morceaux ajoutés.
    init(paquet: URL, documents: URL) {
        let (flux, suite) = AsyncStream.makeStream(of: MusiqueEvenementAudio.self)
        evenements = flux
        annonce = suite
        self.paquet = paquet
        self.documents = documents
        // Un appel, une alarme : le système coupe le son, puis le rend (AUDIOFOCUS_LOSS_TRANSIENT d'Android).
        interruptions = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                               object: nil, queue: nil) { avis in
            let infos = avis.userInfo
            guard let brut = infos?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let genre = AVAudioSession.InterruptionType(rawValue: brut) else { return }
            switch genre {
            case .began:
                suite.yield(.interruption)
            case .ended:
                let options = (infos?[AVAudioSessionInterruptionOptionKey] as? UInt).map {
                    AVAudioSession.InterruptionOptions(rawValue: $0)
                }
                suite.yield(.finInterruption(reprendre: options?.contains(.shouldResume) ?? false))
            @unknown default:
                break
            }
        }
    }

    func jouer(_ fichier: MusiqueFichierAudio, gain: Float, enBoucle: Bool, numero: Int) async -> Bool {
        lecteur?.stop()
        lecteur = nil
        delegue = nil
        let url: URL
        switch fichier {
        case .livre(let chemin): url = paquet.appending(path: chemin)
        case .ajoute(let reference): url = documents.appending(path: reference)
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let nouveau = try AVAudioPlayer(contentsOf: url)
            nouveau.numberOfLoops = enBoucle ? -1 : 0
            nouveau.volume = gain
            let delegue = SortieAudioDelegue(numero: numero, annonce: annonce)
            nouveau.delegate = delegue
            guard nouveau.play() else { return false }
            self.delegue = delegue
            self.gain = gain
            lecteur = nouveau
            return true
        } catch {
            return false
        }
    }

    func pause() async {
        lecteur?.pause()
    }

    func reprendre() async {
        lecteur?.play()
    }

    func aller(a millisecondes: Int) async {
        lecteur?.currentTime = TimeInterval(millisecondes) / 1000
    }

    func regler(gain: Float) async {
        self.gain = gain
        lecteur?.volume = gain
    }

    /// En fondu : dix pas de 60 ms (MusicPlayer.stop), couper net une musique de méditation étant désagréable.
    func arreter(fondu: Bool) async {
        guard let lecteur else { return }
        if fondu {
            let depart = lecteur.volume
            for pas in 1...10 {
                lecteur.volume = depart * Float(10 - pas) / 10
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
        lecteur.stop()
        self.lecteur = nil
        delegue = nil
    }

    func instantane() async -> MusiqueInstantane {
        guard let lecteur else { return MusiqueInstantane() }
        return MusiqueInstantane(joue: lecteur.isPlaying, position: Int(lecteur.currentTime * 1000),
                                 duree: Int(lecteur.duration * 1000))
    }
}

/// Le délégué d'`AVAudioPlayer` : la fin du morceau, ou son échec, sous le numéro de sa lecture.
private final class SortieAudioDelegue: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private let numero: Int
    private let annonce: AsyncStream<MusiqueEvenementAudio>.Continuation

    init(numero: Int, annonce: AsyncStream<MusiqueEvenementAudio>.Continuation) {
        self.numero = numero
        self.annonce = annonce
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        annonce.yield(flag ? .fin(numero: numero) : .echec(numero: numero))
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        annonce.yield(.echec(numero: numero))
    }
}

/// La boucle d'ambiance sous la musique (AmbiancePlayer, AudioTrack en mode statique) : des échantillons de 16 bits,
/// mono, joués sans fin par un `AVAudioPlayerNode`.
actor SortieAmbianceSysteme: MusiqueSortieAmbiance {
    private let moteur = AVAudioEngine()
    private let noeud = AVAudioPlayerNode()
    private var format: AVAudioFormat?

    func jouer(_ boucle: MusiqueBoucle, gain: Float) async {
        let nombre = boucle.echantillons.count
        guard nombre > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(boucle.taux), channels: 1,
                                         interleaved: false),
              let tampon = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(nombre)),
              let canal = tampon.floatChannelData?[0] else { return }
        tampon.frameLength = AVAudioFrameCount(nombre)
        for (rang, echantillon) in boucle.echantillons.enumerated() {
            canal[rang] = Float(echantillon) / 32_768
        }
        noeud.stop()
        if self.format != format {
            if self.format == nil {
                moteur.attach(noeud)
            } else {
                moteur.disconnectNodeOutput(noeud)
            }
            moteur.connect(noeud, to: moteur.mainMixerNode, format: format)
            self.format = format
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            if !moteur.isRunning { try moteur.start() }
        } catch {
            return
        }
        noeud.volume = gain
        noeud.scheduleBuffer(tampon, at: nil, options: .loops, completionHandler: nil)
        noeud.play()
    }

    func regler(gain: Float) async {
        noeud.volume = gain
    }

    func arreter() async {
        noeud.stop()
        moteur.pause()
    }
}

/// La copie des morceaux ajoutés depuis les Fichiers : sous `Documents/Musique/`, ce qui survit au relancement et
/// se sauvegarde (PORTAGE.md § 2.2.4) ; la référence est relative aux Documents.
struct StockageMusiqueSysteme: MusiqueStockage {
    let documents: URL

    func copier(_ source: URL) async throws -> String {
        let accede = source.startAccessingSecurityScopedResource()
        defer { if accede { source.stopAccessingSecurityScopedResource() } }
        let dossier = documents.appending(path: "Musique")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let nom = source.lastPathComponent.isEmpty ? "morceau" : source.lastPathComponent
        var cible = dossier.appending(path: nom)
        var rang = 2
        while FileManager.default.fileExists(atPath: cible.path) {
            let base = (nom as NSString).deletingPathExtension
            let extensionFichier = (nom as NSString).pathExtension
            cible = dossier.appending(path: extensionFichier.isEmpty ? "\(base)-\(rang)" : "\(base)-\(rang).\(extensionFichier)")
            rang += 1
        }
        try FileManager.default.copyItem(at: source, to: cible)
        return "Musique/" + cible.lastPathComponent
    }

    func supprimer(_ reference: String) async {
        try? FileManager.default.removeItem(at: documents.appending(path: reference))
    }
}

/// La pochette enregistrée dans un fichier audio (les métadonnées communes d'`AVURLAsset`).
struct PochettesSysteme: MusiquePochettes {
    let paquet: URL
    let documents: URL

    func pochette(_ fichier: MusiqueFichierAudio) async -> Data? {
        let url: URL
        switch fichier {
        case .livre(let chemin): url = paquet.appending(path: chemin)
        case .ajoute(let reference): url = documents.appending(path: reference)
        }
        let actif = AVURLAsset(url: url)
        guard let metadonnees = try? await actif.load(.commonMetadata) else { return nil }
        for element in metadonnees where element.commonKey == .commonKeyArtwork {
            if let donnees = try? await element.load(.dataValue) { return donnees }
        }
        return nil
    }
}

/// L'interrupteur de la musique, dans le volet de la séance (TextesModele) : la séance en cours suit le réglage
/// (SessionService.musicChanged).
struct SignalMusiqueSeance: TextesSignalMusique {
    let lecteur: MusiqueLecteur

    func musiqueChangee() async {
        await lecteur.musiqueChangee()
    }
}
