import Foundation
import Observation
import Coeur

// La musique de la séance : la file de lecture et ses règles (SessionService.kt, musique et mini-lecteur ;
// MusicPlayer.kt), et la lecture des ambiances (AmbiancePlayer d'Ambiance.kt). L'écran Musique, le mini-lecteur
// et la séance partagent un seul `MusiqueLecteur`, que l'app crée au lancement.

// MARK: Règles

/// Les petites règles de la musique, communes à l'écran, au lecteur et au mini-lecteur.
public enum MusiqueRegles {

    /// « Précédent » reprend le morceau au-delà de trois secondes, comme partout (SessionService.commande).
    public static let repriseAuDebut = 3_000
    /// Les morceaux joués retenus pour « précédent » (SessionService.noterJoue).
    public static let memoireJoues = 50
    /// Les essais d'un morceau au hasard avant de renoncer (SessionService.jouerAuHasard).
    public static let essais = 3
    /// L'aperçu d'une ambiance choisie, en millisecondes (MusicActivity.ecouterAmbiance).
    public static let apercuAmbiance = 5_000

    /// Ce que Store garde de la bibliothèque, lu dans les réglages.
    public static func etat(_ reglages: Reglages) -> MusicLibrary.Etat {
        MusicLibrary.Etat(names: reglages.musicNames, userTracks: reglages.musicUserTracks,
                          trackId: reglages.musicTrackId)
    }

    /// Recopie dans les réglages ce que MusicLibrary a changé, et cela seul : une préférence qu'Android n'a pas
    /// écrite reste absente.
    public static func poser(_ etat: MusicLibrary.Etat, dans reglages: inout Reglages) {
        let avant = MusiqueRegles.etat(reglages)
        if !etat.names.egalUnites(avant.names) { reglages.setMusicNames(etat.names) }
        if !etat.userTracks.egalUnites(avant.userTracks) { reglages.setMusicUserTracks(etat.userTracks) }
        if !memes(etat.trackId, avant.trackId) { reglages.setMusicTrackId(etat.trackId) }
    }

    /// `MusicPlayer.setVolume` : le pour cent, ramené entre 0 et 100, en gain de 0 à 1.
    public static func gainMusique(_ volume: Int) -> Float {
        Float(min(max(volume, 0), 100)) / 100
    }

    /// `AmbiancePlayer` : `volume / 100f * 0.8f`, l'ambiance un peu sous la musique.
    public static func gainAmbiance(_ volume: Int) -> Float {
        Float(volume) / 100 * 0.8
    }

    /// `MiniLecteur.temps` : « m:ss » d'une durée en millisecondes (`"%d:%02d"` en Locale.US), jamais négative.
    public static func temps(_ millisecondes: Int) -> String {
        let s = max(millisecondes / 1_000, 0)
        let secondes = s % 60
        return "\(s / 60):" + (secondes < 10 ? "0" : "") + "\(secondes)"
    }

    /// Le titre d'un morceau, en argument d'un libellé (`%1$@`).
    public static func argument(_ titre: MusicLibrary.Titre) -> Libelle.Argument {
        switch titre {
        case .nom(let nom): .texte(nom)
        case .libelle(let libelle): .libelle(libelle)
        }
    }

    /// Le titre d'un fichier ajouté (MusicActivity.displayName) : son nom sans l'extension
    /// (`substringBeforeLast('.')`) ; à défaut, le dernier segment de la référence de sa copie, comme Android
    /// prend celui de l'adresse quand le nom ne se lit pas.
    public static func titre(de source: URL, reference: String) -> String {
        let nom = source.lastPathComponent
        if !nom.isEmpty && nom != "/" {
            guard let point = nom.dernierePositionUnites(de: ".") else { return nom }
            return nom.premieresUnites(point)
        }
        guard let barre = reference.dernierePositionUnites(de: "/") else { return reference }
        return reference.sansPremieresUnites(barre + 1)
    }

    /// Deux identifiants, comparés unité par unité, comme en Kotlin.
    static func memes(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (.some(x), .some(y)): x.egalUnites(y)
        default: false
        }
    }
}

// MARK: Ambiances

/// La lecture en boucle d'une ambiance (AmbiancePlayer d'Ambiance.kt) : la boucle se calcule hors de l'acteur
/// principal, et une boucle calculée trop tard pour une ambiance déjà changée est jetée. La séance en a une,
/// l'aperçu de l'écran Musique une autre.
@MainActor
@Observable
public final class MusiqueAmbiances {

    /// L'ambiance qui joue, ou va jouer dès sa boucle calculée ; le silence à l'arrêt.
    public private(set) var courante: Ambiance = .silence

    private let sortie: any MusiqueSortieAmbiance
    private let taux: Int
    private let secondes: Int
    /// Chaque demande a son numéro.
    @ObservationIgnored private var demande = 0

    /// `taux` et `secondes` : ceux de la boucle (un test les réduit).
    public init(sortie: any MusiqueSortieAmbiance, taux: Int = MusiqueAmbianceSynth.taux,
                secondes: Int = MusiqueAmbianceSynth.secondes) {
        self.sortie = sortie
        self.taux = taux
        self.secondes = secondes
    }

    /// `AmbiancePlayer.start` : la même ambiance ne change que de volume ; une autre arrête la précédente, puis
    /// se calcule et joue, sauf le silence.
    public func commencer(_ type: Ambiance, volume: Int) async {
        if type == courante {
            await sortie.regler(gain: MusiqueRegles.gainAmbiance(volume))
            return
        }
        demande += 1
        let numero = demande
        courante = type
        await sortie.arreter()
        if type == .silence { return }
        let taux = self.taux
        let secondes = self.secondes
        // Le calcul prend une fraction de seconde : hors de l'acteur principal.
        let pcm = await Task.detached(priority: .userInitiated) {
            MusiqueAmbianceSynth.pcm(MusiqueAmbianceSynth.generer(type, taux: taux, secondes: secondes))
        }.value
        guard numero == demande, courante == type else { return }
        await sortie.jouer(MusiqueBoucle(ambiance: type, echantillons: pcm, taux: taux),
                           gain: MusiqueRegles.gainAmbiance(volume))
    }

    /// `AmbiancePlayer.stop`.
    public func arreter() async {
        demande += 1
        courante = .silence
        await sortie.arreter()
    }
}

// MARK: Le lecteur

/// La musique de la séance (SessionService.kt, MusicPlayer.kt) : le morceau retenu, qui boucle, ou la lecture
/// aléatoire, un morceau puis un autre tiré du même sac, sans redite ; « suivant », « précédent » qui reprend le
/// morceau au-delà de trois secondes, la pause, la position ; l'ambiance sous la musique. Un morceau illisible
/// est sauté en lecture aléatoire plutôt que de laisser la séance muette.
///
/// Sur Android, un service tient la séance ; sur iOS, l'écran de séance appelle `commencerSeance` et
/// `terminerSeance`, l'écran Musique et le mini-lecteur `musiqueChangee` quand un réglage bouge, l'app
/// `ecouter` pour les fins de morceau. Les réglages sont ceux du `Magasin` : `music_now` y dit ce qui joue.
@MainActor
@Observable
public final class MusiqueLecteur {

    private let magasin: Magasin
    private let contenus: ContenusApp
    private let sortie: any MusiqueSortieAudio
    private let ambiances: MusiqueAmbiances
    @ObservationIgnored private var melange: MelangeMusique
    /// Les morceaux joués pendant la séance, pour « précédent ».
    @ObservationIgnored private var joues: [String] = []
    /// Le mode de ce qui joue : nil tant que rien n'a été lancé (SessionService.modeAleatoire).
    @ObservationIgnored private var modeAleatoire: Bool?
    /// Chaque lecture demandée a son numéro : une fin annoncée pour un autre numéro est ignorée.
    @ObservationIgnored private var numero = 0
    /// Le numéro du morceau dont la fin enchaîne le suivant (lecture aléatoire) ; nil s'il boucle.
    @ObservationIgnored private var enchaine: Int?
    /// Les fichiers des morceaux livrés, par identifiant (`musique.json`), lus à la première lecture.
    @ObservationIgnored private var fichiersLivres: [String: String]?

    /// Une séance est en cours : la musique peut jouer, le mini-lecteur se montre.
    public private(set) var seanceEnCours = false
    /// Un morceau est chargé, qu'il joue ou qu'on l'ait mis en pause (MusicPlayer.charge).
    public private(set) var charge = false
    /// Mis en pause depuis le mini-lecteur : une fin d'interruption ne le relance pas.
    public private(set) var enPause = false
    /// Ce qui joue, et où en est la lecture, en millisecondes, tels que la sortie les a dits à la dernière
    /// lecture de son état (`actualiser`, et après chaque commande).
    public private(set) var joue = false
    public private(set) var position = 0
    public private(set) var duree = 0
    /// Le message à montrer, une fois (le Toast d'Android) : « Ce morceau n'a pas pu être lu. »
    public private(set) var message: Libelle?

    /// `melange` : le hasard de la lecture aléatoire (une graine fixe dans un test) ; `taux` et `secondes` :
    /// ceux des boucles d'ambiance.
    public init(magasin: Magasin, contenus: ContenusApp, sortie: any MusiqueSortieAudio,
                ambiance: any MusiqueSortieAmbiance, melange: MelangeMusique = MelangeMusique(),
                taux: Int = MusiqueAmbianceSynth.taux, secondes: Int = MusiqueAmbianceSynth.secondes) {
        self.magasin = magasin
        self.contenus = contenus
        self.sortie = sortie
        self.melange = melange
        ambiances = MusiqueAmbiances(sortie: ambiance, taux: taux, secondes: secondes)
    }

    private var reglages: Reglages { magasin.reglages }

    private var etat: MusicLibrary.Etat { MusiqueRegles.etat(magasin.reglages) }

    /// L'ambiance qui joue sous la musique.
    public var ambianceCourante: Ambiance { ambiances.courante }

    /// Le morceau dont `music_now` dit qu'il joue ; nil hors séance.
    public var morceauEnCours: MusicLibrary.Track? {
        MusicLibrary.byId(etat, reglages.musicNow)
    }

    public func effacerMessage() {
        message = nil
    }

    // MARK: La séance

    /// La séance commence (SessionService.onStartCommand) : le morceau retenu, ou le hasard, et l'ambiance.
    public func commencerSeance() async {
        seanceEnCours = true
        await assurerMusique()
        await ambiances.commencer(Ambiance.of(reglages.ambiance), volume: reglages.musicVolume)
        await actualiser()
    }

    /// La séance est finie ou abandonnée (SessionService.stopSelfAndClear) : la musique s'éteint en fondu,
    /// l'ambiance se tait, `music_now` s'efface. La file de « précédent » repart de zéro à la séance suivante.
    public func terminerSeance() async {
        seanceEnCours = false
        joues = []
        modeAleatoire = nil
        await arreter(fondu: true)
        await ambiances.arreter()
        await ecrire { $0.setMusicNow(nil) }
    }

    /// Un réglage de la musique a bougé pendant la séance (SessionService.musicChanged, ACTION_MUSIC) :
    /// l'ambiance suit le sien, que la musique soit là ou non ; éteinte, la musique s'arrête en fondu ; passée
    /// de la lecture aléatoire au morceau choisi (ou l'inverse), elle repart ; rallumée, elle reprend.
    public func musiqueChangee() async {
        guard seanceEnCours else { return }
        await ambiances.commencer(Ambiance.of(reglages.ambiance), volume: reglages.musicVolume)
        if !reglages.musicEnabled {
            await arreter(fondu: true)
            await actualiser()
            return
        }
        if let mode = modeAleatoire, mode != reglages.musicShuffle {
            await arreter(fondu: false)
        }
        await assurerMusique()
        await actualiser()
    }

    // MARK: Le mini-lecteur

    /// CMD_PAUSE.
    public func pause() async {
        guard seanceEnCours else { return }
        enPause = true
        await sortie.pause()
        await actualiser()
    }

    /// CMD_REPRENDRE : la musique éteinte se rallume ; un morceau chargé reprend ; sinon le morceau retenu part.
    public func reprendre() async {
        guard seanceEnCours else { return }
        if !reglages.musicEnabled {
            await ecrire { $0.setMusicEnabled(true) }
            await assurerMusique()
        } else if charge {
            enPause = false
            await sortie.reprendre()
        } else {
            await assurerMusique()
        }
        await actualiser()
    }

    /// CMD_POSITION : va à cette position, bornée par la durée du morceau.
    public func aller(a millisecondes: Int) async {
        guard seanceEnCours, charge else { return }
        let instant = await sortie.instantane()
        await sortie.aller(a: min(max(millisecondes, 0), max(instant.duree, 0)))
        await actualiser()
    }

    /// CMD_SUIVANT.
    public func suivant() async {
        guard seanceEnCours else { return }
        await changer(+1)
        await actualiser()
    }

    /// CMD_PRECEDENT : au-delà de trois secondes, le morceau reprend au début ; sinon, le morceau d'avant.
    public func precedent() async {
        guard seanceEnCours else { return }
        let instant = await sortie.instantane()
        if charge && instant.position > MusiqueRegles.repriseAuDebut {
            await sortie.aller(a: 0)
        } else {
            await changer(-1)
        }
        await actualiser()
    }

    /// Relit l'état de la sortie : ce qui joue, la position, la durée (MiniLecteur.maj, chaque seconde, et
    /// quatre fois par seconde le lecteur déplié).
    public func actualiser() async {
        let instant = await sortie.instantane()
        joue = instant.joue
        position = instant.position
        duree = instant.duree
    }

    // MARK: Ce que la sortie annonce

    /// Lit les annonces de la sortie tant que dure la tâche qui l'appelle (le `.task` de la racine de l'app).
    public func ecouter() async {
        for await evenement in sortie.evenements {
            await recevoir(evenement)
        }
    }

    /// Une annonce de la sortie. La fin (ou l'échec) du morceau qui joue en lecture aléatoire enchaîne le
    /// suivant, si la séance dure et que la musique est active ; celle d'un autre numéro est ignorée. Une
    /// interruption finie relance le morceau, sauf s'il a été mis en pause.
    public func recevoir(_ evenement: MusiqueEvenementAudio) async {
        switch evenement {
        case .fin(let n), .echec(let n):
            guard n == numero else { return }
            joue = false
            guard enchaine == n else { return }
            if seanceEnCours && reglages.musicEnabled {
                await jouerAuHasard(essais: MusiqueRegles.essais)
            }
        case .interruption:
            joue = false
        case .finInterruption(let relancer):
            if relancer && charge && !enPause {
                await sortie.reprendre()
            }
        }
        await actualiser()
    }

    // MARK: Les fichiers

    /// Le fichier d'un morceau : la copie d'un morceau ajouté, ou le fichier livré que nomme `musique.json` ;
    /// nil si on ne le trouve pas (il ne pourra pas être lu). L'écoute d'essai de l'écran Musique s'en sert.
    public func fichier(de morceau: MusicLibrary.Track) async -> MusiqueFichierAudio? {
        if let uri = morceau.uri { return .ajoute(uri) }
        if fichiersLivres == nil, let morceaux = try? await contenus.musique() {
            var fichiers: [String: String] = [:]
            for m in morceaux where fichiers[m.id] == nil {
                fichiers[m.id] = m.fichier
            }
            fichiersLivres = fichiers
        }
        guard let chemin = fichiersLivres?[morceau.id] else { return nil }
        return .livre(chemin)
    }

    // MARK: La file (SessionService)

    /// `ensureMusic` : lance le morceau retenu, si la musique est active, la séance en cours et rien de chargé.
    private func assurerMusique() async {
        guard seanceEnCours, reglages.musicEnabled, !charge else { return }
        modeAleatoire = reglages.musicShuffle
        if reglages.musicShuffle {
            await jouerAuHasard(essais: MusiqueRegles.essais)
            return
        }
        guard let morceau = MusicLibrary.selected(etat) else { return }
        await ecrire { $0.setMusicNow(morceau.id) }
        noterJoue(morceau.id)
        let lance = await lancer(morceau, enchainer: false)
        if !lance { message = Libelle("music_play_failed") }
    }

    /// `jouerAuHasard` : un morceau tiré du sac, qui à sa fin enchaîne le suivant ; un morceau illisible
    /// (fichier ajouté effacé) est sauté, trois essais en tout.
    private func jouerAuHasard(essais: Int) async {
        let morceaux = MusicLibrary.all(etat)
        guard let id = melange.suivant(morceaux.map { $0.id }),
              let morceau = morceaux.first(where: { $0.id.egalUnites(id) }) else { return }
        await ecrire { $0.setMusicNow(morceau.id) }
        noterJoue(morceau.id)
        let lance = await lancer(morceau, enchainer: true)
        if lance { return }
        if essais > 1 {
            await jouerAuHasard(essais: essais - 1)
        } else {
            message = Libelle("music_play_failed")
        }
    }

    /// `noterJoue` : sans doublon consécutif, cinquante au plus.
    private func noterJoue(_ id: String) {
        if let dernier = joues.last, dernier.egalUnites(id) { return }
        joues.append(id)
        while joues.count > MusiqueRegles.memoireJoues {
            joues.removeFirst()
        }
    }

    /// `changer` : la musique se rallume ; en lecture aléatoire, « suivant » tire au hasard et « précédent »
    /// rejoue le morceau d'avant (le hasard, s'il n'y en a pas) ; sinon, le morceau voisin dans la bibliothèque,
    /// en boucle, devient le morceau retenu.
    private func changer(_ sens: Int) async {
        await ecrire { $0.setMusicEnabled(true) }
        let morceaux = MusicLibrary.all(etat)
        if morceaux.isEmpty { return }
        await arreter(fondu: false)
        if reglages.musicShuffle {
            if sens > 0 {
                await jouerAuHasard(essais: MusiqueRegles.essais)
                return
            }
            if joues.count >= 2 { joues.removeLast() }
            guard let id = joues.last, let morceau = morceaux.first(where: { $0.id.egalUnites(id) }) else {
                await jouerAuHasard(essais: MusiqueRegles.essais)
                return
            }
            await ecrire { $0.setMusicNow(morceau.id) }
            _ = await lancer(morceau, enchainer: true)
            return
        }
        var ici = 0
        if let maintenant = reglages.musicNow,
           let rang = morceaux.firstIndex(where: { $0.id.egalUnites(maintenant) }) {
            ici = rang
        }
        let morceau = morceaux[Kotlin.floorMod(ici + sens, morceaux.count)]
        await ecrire { $0.setMusicTrackId(morceau.id) }
        await assurerMusique()
    }

    /// `MusicPlayer.start` : arrête ce qui joue, puis joue `morceau` ; `enchainer` (lecture aléatoire) : il ne
    /// boucle pas, sa fin enchaîne le suivant. Faux s'il n'a pas pu être lu.
    private func lancer(_ morceau: MusicLibrary.Track, enchainer: Bool) async -> Bool {
        numero += 1
        let ici = numero
        enchaine = nil
        charge = false
        enPause = false
        joue = false
        let trouve = await fichier(de: morceau)
        // Une autre commande (un arrêt, la fin de la séance, un autre morceau) est passée pendant la recherche du
        // fichier : c'est elle qui décide, rien ne part, et rien n'est à signaler.
        guard ici == numero else { return true }
        // MusicPlayer.start arrête d'abord ce qui joue : un morceau introuvable ne laisse pas jouer l'ancien.
        guard let chemin = trouve else {
            await sortie.arreter(fondu: false)
            return false
        }
        let lance = await sortie.jouer(chemin, gain: MusiqueRegles.gainMusique(reglages.musicVolume),
                                       enBoucle: !enchainer, numero: ici)
        // Une autre commande est passée pendant l'attente : c'est elle qui décide.
        guard ici == numero else { return lance }
        charge = lance
        joue = lance
        if lance && enchainer { enchaine = ici }
        return lance
    }

    /// `MusicPlayer.stop` : plus rien n'est chargé ; une fin annoncée ensuite pour ce morceau est ignorée.
    private func arreter(fondu: Bool) async {
        numero += 1
        enchaine = nil
        charge = false
        joue = false
        position = 0
        duree = 0
        await sortie.arreter(fondu: fondu)
    }

    /// Change les réglages. Une écriture refusée laisse le changement en mémoire (Magasin), et la prochaine
    /// l'emportera : la musique, elle, continue, comme les préférences d'Android qui ne refusent jamais.
    private func ecrire(_ changement: (inout Reglages) -> Void) async {
        do {
            try await magasin.modifierReglages(changement)
        } catch {
            return
        }
    }
}
