import Foundation
import Observation
import Coeur

/// Le mini-lecteur de la pratique (MiniLecteur.kt, demande du 19/10) : changer de morceau sans quitter la
/// hitbodedout. Replié, un disque qui tourne pendant la lecture, avec la photo du morceau, ou à défaut le hassid
/// à la guitare ; déplié, la pochette, le titre, la barre de position, l'aléatoire, précédent, lecture, suivant.
///
/// Il ne commande rien lui-même : il passe ses ordres au `MusiqueLecteur` de la séance et en lit l'état. Un seul
/// pour l'app, que l'accueil et l'écran de séance montrent ; il ne se montre que pendant une séance.
@MainActor
@Observable
public final class MusiqueMiniLecteurModele {

    private let magasin: Magasin
    private let lecteur: MusiqueLecteur
    private let pochettes: any MusiquePochettes
    private let attente: MusiqueAttente

    /// Déplié : le panneau ; replié : le disque seul.
    public private(set) var deplie = false
    /// Le doigt est sur la barre : elle suit le doigt, plus la lecture.
    public private(set) var glisse = false
    /// La position où le doigt a amené la barre, en millisecondes.
    public private(set) var positionGlissee = 0
    /// La photo enregistrée dans le fichier du morceau (JPEG, PNG) ; nil : le hassid à la guitare.
    public private(set) var pochette: Data?

    /// Les pochettes déjà lues, par morceau ; une valeur nil : pas de photo dans le fichier.
    @ObservationIgnored private var lues: [String: Data?] = [:]
    /// Le morceau dont la pochette est montrée.
    @ObservationIgnored private var morceauMontre: String?

    /// `attente` : l'intervalle de `suivre` (`Task.sleep` dans l'app).
    public init(magasin: Magasin, lecteur: MusiqueLecteur, pochettes: any MusiquePochettes,
                attente: @escaping MusiqueAttente = MusiqueAttentes.systeme) {
        self.magasin = magasin
        self.lecteur = lecteur
        self.pochettes = pochettes
        self.attente = attente
    }

    // MARK: Ce qu'il montre

    /// Il ne paraît que pendant une séance.
    public var visible: Bool { lecteur.seanceEnCours }

    /// Le morceau nommé : celui qui joue, sinon le morceau retenu ; aucun quand la musique est éteinte.
    public var morceau: MusicLibrary.Track? {
        let reglages = magasin.reglages
        guard reglages.musicEnabled else { return nil }
        let etat = MusiqueRegles.etat(reglages)
        return MusicLibrary.byId(etat, reglages.musicNow) ?? MusicLibrary.selected(etat)
    }

    /// Le titre, qui défile s'il est trop long ; « Désactivée » sans musique.
    public var titre: MusicLibrary.Titre {
        morceau?.title ?? .libelle(Libelle("music_off_short"))
    }

    /// Un morceau joue (pas en pause, pas interrompu).
    public var joue: Bool { lecteur.joue }

    /// Le grand bouton rond : « pause » pendant la lecture, « lecture » sinon.
    public var iconeLecture: String { joue ? "ic_lecteur_pause" : "ic_lecteur_lecture" }
    public var libelleLecture: Libelle { Libelle(joue ? "lecteur_pause" : "lecteur_lecture") }

    /// Le bouton aléatoire est allumé (opacité 1, sinon 0,45, et sélectionné pour l'accessibilité).
    public var aleatoire: Bool { magasin.reglages.musicShuffle }
    public var opaciteAleatoire: Double { aleatoire ? 1 : 0.45 }

    /// La durée du morceau, en millisecondes ; 0 sans morceau.
    public var duree: Int { max(lecteur.duree, 0) }

    /// Le bout de la barre : la durée, au moins 1.
    public var maximum: Int { max(duree, 1) }

    /// La position de la barre : celle du doigt pendant qu'il glisse, sinon celle de la lecture, bornée à la barre.
    public var position: Int {
        min(max(glisse ? positionGlissee : lecteur.position, 0), maximum)
    }

    /// Le temps écoulé et la durée, « m:ss » en chiffres latins (`"%d:%02d"` en Locale.US), chiffres tabulaires.
    public var ecoule: String { MusiqueRegles.temps(position) }
    public var total: String { MusiqueRegles.temps(duree) }

    /// Le disque tourne (un tour en 12 s) pendant la lecture, et s'arrête où il est en pause.
    public var disqueTourne: Bool { visible && joue }

    /// L'image du disque sans pochette : le hassid à la guitare, ou sa pose féminine pour צדקת (PersonnageImageView).
    public var imageParDefaut: String {
        Personnage.pour(Adresse.parse(magasin.reglages.adresse), "char_guitar")
    }

    /// Le temps entre deux relectures de l'état : une seconde replié, un quart de seconde déplié.
    public var intervalle: Int { deplie ? 250 : 1_000 }

    // MARK: Ses actions

    /// Toucher le disque.
    public func deplier() {
        deplie = true
    }

    /// Le bouton « replier ».
    public func replier() {
        deplie = false
    }

    /// Le doigt se pose sur la barre.
    public func commencerGlisse() {
        positionGlissee = position
        glisse = true
    }

    /// Le doigt glisse : le temps écoulé suit le doigt.
    public func glisser(a millisecondes: Int) {
        positionGlissee = min(max(millisecondes, 0), maximum)
    }

    /// Le doigt se lève : la lecture va là (CMD_POSITION).
    public func finirGlisse() async {
        glisse = false
        await lecteur.aller(a: positionGlissee)
    }

    /// Le grand bouton : pause si un morceau joue, sinon reprise (CMD_PAUSE, CMD_REPRENDRE).
    public func basculerLecture() async {
        if lecteur.joue {
            await lecteur.pause()
        } else {
            await lecteur.reprendre()
        }
        await suivrePochette()
    }

    public func suivant() async {
        await lecteur.suivant()
        await suivrePochette()
    }

    /// Au-delà de trois secondes, le morceau reprend au début ; sinon, le morceau d'avant.
    public func precedent() async {
        await lecteur.precedent()
        await suivrePochette()
    }

    /// Le bouton aléatoire : le réglage s'inverse et la séance suit.
    public func basculerAleatoire() async {
        do {
            try await magasin.modifierReglages { $0.setMusicShuffle(!$0.musicShuffle) }
        } catch {
            // Le changement reste en mémoire (Magasin) : la séance le suit quand même.
        }
        await lecteur.musiqueChangee()
        await suivrePochette()
    }

    /// Relit l'état de la lecture et la pochette (MiniLecteur.maj) ; rien hors séance.
    public func actualiser() async {
        guard lecteur.seanceEnCours else { return }
        await lecteur.actualiser()
        await suivrePochette()
    }

    /// Relit l'état sans fin, à l'`intervalle`, tant que la tâche qui l'appelle dure (le `.task` de la vue).
    public func suivre() async {
        while !Task.isCancelled {
            await actualiser()
            await attente(intervalle)
        }
    }

    // MARK: La pochette

    /// La photo d'un fichier ajouté, lue une fois par morceau ; un morceau livré montre le hassid.
    private func suivrePochette() async {
        let piste = morceau
        if let montre = morceauMontre, let id = piste?.id, montre.egalUnites(id) { return }
        morceauMontre = piste?.id
        guard let piste, let uri = piste.uri else {
            pochette = nil
            return
        }
        if let lue = lues[piste.id] {
            pochette = lue
            return
        }
        pochette = nil
        let image = await pochettes.pochette(.ajoute(uri))
        lues.updateValue(image, forKey: piste.id)
        if let montre = morceauMontre, montre.egalUnites(piste.id) {
            pochette = image
        }
    }
}
