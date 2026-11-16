import Foundation
import Coeur

// Ce que la musique demande au système (ECRANS.md) : jouer un fichier, jouer une ambiance, copier un fichier
// ajouté, lire la pochette d'un morceau, attendre. Ici, les protocoles, sans aucune API d'Apple ; leurs
// adaptateurs viendront dans ios/App/Services/ (AVAudioPlayer et AVAudioSession(.playback), AVAudioEngine,
// FileManager, AVAsset) ; leurs faux, ci-dessous, servent aux tests et aux aperçus. Chacun est partageable
// entre fils (`Sendable`) et s'appelle en `await`.
//
// `LecteurSon` de Services.swift, plus ancien, ne sait que jouer et arrêter : `MusiqueSortieAudio` le remplace
// pour la musique (pause, reprise, position, fin de morceau, échec de lecture).

// MARK: Lecture d'un morceau

/// Le fichier d'un morceau, tel que la sortie audio le trouve.
public enum MusiqueFichierAudio: Sendable, Hashable {
    /// Un morceau livré : son chemin sous les ressources de l'app (`Morceau.fichier`, « Musique/<id>.m4a »).
    case livre(String)
    /// Un morceau ajouté : la référence de sa copie, relative aux Documents de l'app (`MusiqueStockage.copier`).
    case ajoute(String)
}

/// Ce que la sortie audio annonce d'elle-même, hors de toute demande.
public enum MusiqueEvenementAudio: Sendable, Hashable {
    /// Le morceau joué sans boucle sous ce numéro est arrivé au bout.
    case fin(numero: Int)
    /// Le morceau joué sous ce numéro s'est arrêté sur une erreur en cours de lecture. Sans écouteur d'erreur,
    /// le MediaPlayer d'Android appelle alors sa fin : le lecteur traite les deux de même.
    case echec(numero: Int)
    /// Le système coupe le son (un appel, une alarme) : AUDIOFOCUS_LOSS_TRANSIENT d'Android, le morceau est
    /// en pause sans que l'utilisateur l'ait demandé.
    case interruption
    /// Le système rend le son ; `reprendre` : il invite à relancer (AUDIOFOCUS_GAIN, `.shouldResume` d'iOS).
    case finInterruption(reprendre: Bool)
}

/// L'état de la sortie audio à un instant : `isPlaying`, `currentPosition` et `duration` du MediaPlayer.
public struct MusiqueInstantane: Sendable, Equatable {
    public var joue: Bool
    /// En millisecondes ; 0 sans morceau.
    public var position: Int
    /// En millisecondes ; 0 sans morceau.
    public var duree: Int

    public init(joue: Bool = false, position: Int = 0, duree: Int = 0) {
        self.joue = joue
        self.position = position
        self.duree = duree
    }
}

/// La lecture d'un morceau (MusicPlayer.kt) : `AVAudioPlayer` et `AVAudioSession(.playback)` dans l'app, pour
/// que les autres apps se taisent et que la musique tienne l'écran éteint. Un seul morceau à la fois : en jouer
/// un autre arrête, sans fondu, celui qui jouait.
public protocol MusiqueSortieAudio: Sendable {
    /// Joue ce fichier, du début, au gain donné (de 0 à 1) ; `enBoucle` : il reprend au début à sa fin, sinon il
    /// s'arrête et annonce `.fin(numero)`. Rend faux si le fichier ne se lit pas (absent, illisible, session
    /// audio refusée) : rien ne joue alors.
    func jouer(_ fichier: MusiqueFichierAudio, gain: Float, enBoucle: Bool, numero: Int) async -> Bool
    /// Met en pause ce qui joue.
    func pause() async
    /// Reprend ce qui est en pause.
    func reprendre() async
    /// Va à cette position, en millisecondes (déjà bornée par le lecteur).
    func aller(a millisecondes: Int) async
    /// Change le gain de ce qui joue, de 0 à 1.
    func regler(gain: Float) async
    /// Arrête ce qui joue ; `fondu` : en dix pas de 60 ms (MusicPlayer.stop), couper net une musique de
    /// méditation étant désagréable.
    func arreter(fondu: Bool) async
    /// L'état de ce qui joue.
    func instantane() async -> MusiqueInstantane
    /// Les fins de morceau, les échecs en cours de lecture et les interruptions, dans l'ordre. Un seul lecteur
    /// les lit (`MusiqueLecteur.ecouter`).
    var evenements: AsyncStream<MusiqueEvenementAudio> { get }
}

/// Une sortie muette, qui retient ce qu'on lui a fait jouer ; le test y fait finir un morceau (`terminer`),
/// avancer la lecture (`avancer`) ou échouer un fichier (`illisibles`).
public actor MusiqueFausseSortieAudio: MusiqueSortieAudio {
    public nonisolated let evenements: AsyncStream<MusiqueEvenementAudio>
    private let annonce: AsyncStream<MusiqueEvenementAudio>.Continuation

    /// Ce qui est chargé ; nil à l'arrêt.
    public private(set) var enCours: MusiqueFichierAudio?
    /// Le numéro de ce qui est chargé.
    public private(set) var numero: Int?
    public private(set) var enBoucle = false
    public private(set) var joue = false
    public private(set) var gain: Float = 0
    public private(set) var position = 0
    public private(set) var duree = 0
    /// Chaque demande de lecture, lue ou non, dans l'ordre.
    public private(set) var demandes: [MusiqueFichierAudio] = []
    /// Ce qui a vraiment joué, dans l'ordre.
    public private(set) var joues: [MusiqueFichierAudio] = []
    /// Chaque arrêt demandé : vrai pour un arrêt en fondu.
    public private(set) var arrets: [Bool] = []
    public private(set) var pauses = 0
    public private(set) var reprises = 0
    private var illisibles: Set<MusiqueFichierAudio>
    private let dureeMorceau: Int

    /// `duree` : celle de chaque morceau, en millisecondes.
    public init(illisibles: Set<MusiqueFichierAudio> = [], duree: Int = 180_000) {
        let (flux, suite) = AsyncStream.makeStream(of: MusiqueEvenementAudio.self)
        evenements = flux
        annonce = suite
        self.illisibles = illisibles
        dureeMorceau = duree
    }

    public func jouer(_ fichier: MusiqueFichierAudio, gain: Float, enBoucle: Bool, numero: Int) -> Bool {
        demandes.append(fichier)
        vider()
        if illisibles.contains(fichier) { return false }
        enCours = fichier
        self.numero = numero
        self.enBoucle = enBoucle
        self.gain = gain
        joue = true
        duree = dureeMorceau
        joues.append(fichier)
        return true
    }

    public func pause() {
        pauses += 1
        joue = false
    }

    public func reprendre() {
        reprises += 1
        if enCours != nil { joue = true }
    }

    public func aller(a millisecondes: Int) {
        if enCours != nil { position = millisecondes }
    }

    public func regler(gain: Float) {
        self.gain = gain
    }

    public func arreter(fondu: Bool) {
        arrets.append(fondu)
        vider()
    }

    public func instantane() -> MusiqueInstantane {
        MusiqueInstantane(joue: joue, position: position, duree: duree)
    }

    // MARK: Ce que le test fait à la sortie

    /// Ce fichier ne se lira plus (un fichier ajouté qu'on a effacé).
    public func rendreIllisible(_ fichier: MusiqueFichierAudio) {
        illisibles.insert(fichier)
    }

    /// La lecture est arrivée à cette position.
    public func avancer(a millisecondes: Int) {
        if enCours != nil { position = millisecondes }
    }

    /// Le morceau arrive au bout : en boucle, il repart du début ; sinon il s'arrête et sa fin est annoncée,
    /// et rendue pour que le test la passe à `MusiqueLecteur.recevoir`. nil si rien ne finit.
    public func terminer() -> MusiqueEvenementAudio? {
        guard enCours != nil, let n = numero else { return nil }
        if enBoucle {
            position = 0
            return nil
        }
        joue = false
        position = duree
        let fin = MusiqueEvenementAudio.fin(numero: n)
        annonce.yield(fin)
        return fin
    }

    /// Le système coupe le son.
    public func interrompre() -> MusiqueEvenementAudio {
        joue = false
        annonce.yield(.interruption)
        return .interruption
    }

    private func vider() {
        enCours = nil
        numero = nil
        enBoucle = false
        joue = false
        position = 0
        duree = 0
    }
}

// MARK: Ambiances

/// Une boucle d'ambiance à jouer sans fin : des échantillons PCM de 16 bits, mono (AmbiancePlayer.jouer).
public struct MusiqueBoucle: Sendable, Equatable {
    public let ambiance: Ambiance
    public let echantillons: [Int16]
    /// Les échantillons par seconde.
    public let taux: Int

    public init(ambiance: Ambiance, echantillons: [Int16], taux: Int) {
        self.ambiance = ambiance
        self.echantillons = echantillons
        self.taux = taux
    }
}

/// La lecture en boucle d'une ambiance, sous la musique (AmbiancePlayer, AudioTrack en mode statique) :
/// `AVAudioEngine` et un `AVAudioPlayerNode` dans l'app. Une ambiance à la fois.
public protocol MusiqueSortieAmbiance: Sendable {
    /// Joue cette boucle sans fin, au gain donné (de 0 à 1), à la place de celle qui jouait.
    func jouer(_ boucle: MusiqueBoucle, gain: Float) async
    /// Change le gain de la boucle qui joue.
    func regler(gain: Float) async
    /// Arrête la boucle.
    func arreter() async
}

/// Une sortie d'ambiance muette, qui retient ce qu'on lui a fait jouer.
public actor MusiqueFausseSortieAmbiance: MusiqueSortieAmbiance {
    /// La boucle qui joue ; nil à l'arrêt.
    public private(set) var enCours: MusiqueBoucle?
    public private(set) var gain: Float = 0
    /// Les ambiances jouées, dans l'ordre.
    public private(set) var jouees: [Ambiance] = []
    public private(set) var arrets = 0

    public init() {}

    public func jouer(_ boucle: MusiqueBoucle, gain: Float) {
        enCours = boucle
        self.gain = gain
        jouees.append(boucle.ambiance)
    }

    public func regler(gain: Float) {
        self.gain = gain
    }

    public func arreter() {
        enCours = nil
        arrets += 1
    }
}

// MARK: Fichiers ajoutés

/// La copie, dans l'app, des morceaux qu'on ajoute depuis ses fichiers (PORTAGE.md § 2.2.4 et § 3.2,
/// `Documents/Musique/`) : Android garde une adresse et une permission persistante, iOS copie le fichier, ce
/// qui survit au relancement et se sauvegarde.
public protocol MusiqueStockage: Sendable {
    /// Copie le fichier choisi (l'adresse que rend `fileImporter`, à accès protégé : l'adaptateur ouvre et
    /// referme cet accès) et rend la référence de la copie, relative aux Documents (« Musique/Nigoun.m4a ») :
    /// jamais blanche, unique, avec une barre oblique (aucun morceau livré n'en a), et la même pour un fichier
    /// déjà copié. Elle sert d'identifiant au morceau (`uri` de MusicLibrary). Lève si la copie échoue.
    func copier(_ source: URL) async throws -> String
    /// Efface la copie d'un morceau retiré de la bibliothèque ; rien si elle n'existe plus.
    func supprimer(_ reference: String) async
}

/// Un stockage en mémoire : il retient les copies faites ; `faireEchouer` simule une copie refusée.
public actor MusiqueFauxStockage: MusiqueStockage {

    /// L'erreur d'une copie refusée.
    public struct Echec: Error, Equatable, Sendable {
        public init() {}
    }

    /// Les copies présentes : référence → adresse d'origine.
    public private(set) var copies: [String: URL] = [:]
    /// Les références effacées, dans l'ordre.
    public private(set) var supprimees: [String] = []
    private var refuse = false

    public init() {}

    public func faireEchouer(_ oui: Bool) {
        refuse = oui
    }

    public func copier(_ source: URL) throws -> String {
        if refuse { throw Echec() }
        for (reference, origine) in copies where origine == source {
            return reference
        }
        let nom = source.lastPathComponent
        var reference = "Musique/" + nom
        var rang = 1
        while copies[reference] != nil {
            rang += 1
            reference = "Musique/\(rang)-" + nom
        }
        copies[reference] = source
        return reference
    }

    public func supprimer(_ reference: String) {
        copies[reference] = nil
        supprimees.append(reference)
    }

    /// La copie existe-t-elle encore ?
    public func existe(_ reference: String) -> Bool {
        copies[reference] != nil
    }
}

// MARK: Pochettes

/// La photo enregistrée dans un fichier audio (MediaMetadataRetriever.embeddedPicture d'Android, les
/// métadonnées d'`AVAsset` dans l'app), pour le disque du mini-lecteur.
public protocol MusiquePochettes: Sendable {
    /// Les octets de l'image (JPEG, PNG), nil si le fichier n'en a pas ou ne se lit pas.
    func pochette(_ fichier: MusiqueFichierAudio) async -> Data?
}

/// Des pochettes données d'avance.
public actor MusiqueFaussesPochettes: MusiquePochettes {
    private let images: [MusiqueFichierAudio: Data]
    /// Les fichiers dont on a demandé la pochette, dans l'ordre.
    public private(set) var demandes: [MusiqueFichierAudio] = []

    public init(_ images: [MusiqueFichierAudio: Data] = [:]) {
        self.images = images
    }

    public func pochette(_ fichier: MusiqueFichierAudio) -> Data? {
        demandes.append(fichier)
        return images[fichier]
    }
}

// MARK: Attente

/// Attendre tant de millisecondes (`postDelayed` d'Android) : `Task.sleep` dans l'app, rien dans les tests.
public typealias MusiqueAttente = @Sendable (_ millisecondes: Int) async -> Void

public enum MusiqueAttentes {
    /// L'attente réelle ; une tâche annulée cesse d'attendre.
    public static let systeme: MusiqueAttente = { millisecondes in
        _ = try? await Task.sleep(nanoseconds: UInt64(max(millisecondes, 0)) * 1_000_000)
    }

    /// Aucune attente : ce qui suit l'attente a lieu aussitôt.
    public static let immediate: MusiqueAttente = { _ in }
}
