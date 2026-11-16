import Foundation
import Observation
import Coeur

// L'écran Musique (MusicActivity.kt, activity_music.xml, item_track.xml) : la musique pendant la hitbodedout,
// le volume, la lecture aléatoire, l'ambiance, et la bibliothèque, avec l'écoute d'essai, le renommage, le
// retrait et l'ajout d'un fichier du téléphone. Ce qui joue pendant la séance est l'affaire du `MusiqueLecteur`
// partagé ; l'écran n'a que ses propres aperçus (un morceau, cinq secondes d'ambiance).

// MARK: Ce que l'écran montre

/// Une ligne de la bibliothèque (item_track.xml).
public struct MusiqueLigne: Sendable, Hashable, Identifiable {
    /// L'identifiant du morceau : celui de MusiquePlay, ou la référence de la copie d'un fichier ajouté.
    public let id: String
    /// Le nom donné, le nom du fichier, ou le titre livré (une clé du catalogue).
    public let titre: MusicLibrary.Titre
    /// « Livré avec l'application » ou « Depuis le téléphone ».
    public let origine: Libelle
    public let livre: Bool
    /// Le bouton radio : le morceau des séances ; aucun en lecture aléatoire.
    public let choisie: Bool
    /// L'écoute d'essai de ce morceau est en cours : le bouton montre « pause ».
    public let enApercu: Bool

    public init(id: String, titre: MusicLibrary.Titre, origine: Libelle, livre: Bool, choisie: Bool, enApercu: Bool) {
        self.id = id
        self.titre = titre
        self.origine = origine
        self.livre = livre
        self.choisie = choisie
        self.enApercu = enApercu
    }
}

/// Un choix du dialogue des ambiances (setSingleChoiceItems).
public struct MusiqueOptionAmbiance: Sendable, Hashable, Identifiable {
    public let ambiance: Ambiance
    public let titre: Libelle
    /// Le choix coché : l'ambiance enregistrée.
    public let choisie: Bool

    public var id: String { ambiance.cle }

    public init(ambiance: Ambiance, titre: Libelle, choisie: Bool) {
        self.ambiance = ambiance
        self.titre = titre
        self.choisie = choisie
    }
}

/// Le dialogue « Renommer » d'un morceau (MusicActivity.askRename).
public struct MusiqueRenommage: Sendable, Hashable, Identifiable {

    /// Le troisième bouton du dialogue.
    public enum Neutre: Sendable, Hashable {
        /// Un fichier ajouté : « Retirer ».
        case retirer
        /// Un morceau livré qui porte un nom donné : « Titre d'origine ».
        case titreOrigine
    }

    /// Le morceau renommé.
    public let id: String
    /// L'indication du champ vide : le titre actuel du morceau.
    public let indication: MusicLibrary.Titre
    /// nil : un morceau livré qui porte encore son titre, deux boutons seulement.
    public let neutre: Neutre?

    public init(id: String, indication: MusicLibrary.Titre, neutre: Neutre?) {
        self.id = id
        self.indication = indication
        self.neutre = neutre
    }

    public var titre: Libelle { Libelle("music_rename") }
    public var enregistrer: Libelle { Libelle("action_save") }
    public var retour: Libelle { Libelle("action_back") }

    /// Le libellé du troisième bouton, s'il y en a un.
    public var libelleNeutre: Libelle? {
        switch neutre {
        case .retirer?: Libelle("music_remove")
        case .titreOrigine?: Libelle("music_rename_reset")
        case nil: nil
        }
    }
}

// MARK: Le modèle

/// L'écran Musique. Ses réglages sont ceux du `Magasin`, lus à chaque fois : un changement fait ailleurs (le
/// mini-lecteur, l'accueil) se voit ici, comme `reload()` d'Android au retour sur l'écran.
///
/// Les écritures refusées par le disque ne remontent pas : le changement reste en mémoire et la prochaine
/// écriture l'emportera (Magasin), comme les préférences d'Android, qui ne refusent jamais.
@MainActor
@Observable
public final class MusiqueModele {

    private let magasin: Magasin
    private let lecteur: MusiqueLecteur
    /// L'écoute d'essai : un lecteur à part, comme le `MusicPlayer` propre à MusicActivity.
    private let apercu: any MusiqueSortieAudio
    /// L'aperçu d'une ambiance : un `AmbiancePlayer` à part.
    private let ambianceApercu: MusiqueAmbiances
    private let stockage: any MusiqueStockage
    private let attente: MusiqueAttente

    /// Le morceau en écoute d'essai (previewingId) ; il le reste à la fin du morceau, comme sur Android.
    public private(set) var apercuId: String?
    /// Le message à montrer une fois (le Toast d'Android) : un morceau illisible, un fichier non ajouté.
    public private(set) var message: Libelle?
    /// Le dialogue des ambiances est ouvert.
    public private(set) var choixAmbianceOuvert = false
    /// Le dialogue « Renommer » ouvert, nil sinon.
    public private(set) var renommage: MusiqueRenommage?
    /// Le champ du dialogue « Renommer » : le nom donné, vide pour un morceau qui porte son titre.
    public var texteRenommage = ""

    /// Chaque écoute d'essai demandée a son numéro : une réponse tardive d'une demande dépassée est ignorée.
    @ObservationIgnored private var numeroApercu = 0
    /// Chaque aperçu d'ambiance a son numéro : l'arrêt prévu d'un aperçu remplacé ne coupe pas le suivant.
    @ObservationIgnored private var numeroAmbiance = 0
    /// L'arrêt prévu de l'aperçu d'ambiance, cinq secondes après son début (`postDelayed`) ; le test l'attend.
    @ObservationIgnored var finApercuAmbiance: Task<Void, Never>?

    /// `lecteur` : le lecteur de la séance, partagé avec la séance et le mini-lecteur ; `apercu` et
    /// `ambianceApercu` : des sorties propres à l'écran ; `attente` : la durée de l'aperçu d'ambiance (rien dans
    /// un test) ; `taux` et `secondes` : ceux des boucles d'ambiance (un test les réduit).
    public init(magasin: Magasin, lecteur: MusiqueLecteur, apercu: any MusiqueSortieAudio,
                ambianceApercu: any MusiqueSortieAmbiance, stockage: any MusiqueStockage,
                attente: @escaping MusiqueAttente = MusiqueAttentes.systeme,
                taux: Int = MusiqueAmbianceSynth.taux, secondes: Int = MusiqueAmbianceSynth.secondes) {
        self.magasin = magasin
        self.lecteur = lecteur
        self.apercu = apercu
        self.ambianceApercu = MusiqueAmbiances(sortie: ambianceApercu, taux: taux, secondes: secondes)
        self.stockage = stockage
        self.attente = attente
    }

    private var reglages: Reglages { magasin.reglages }

    private var etat: MusicLibrary.Etat { MusiqueRegles.etat(magasin.reglages) }

    // MARK: Le bandeau

    /// « Musique ».
    public var titre: Libelle { Libelle("music_title") }

    /// La ligne sous le titre (renderSummary) : éteinte, vide, aléatoire, ou le morceau retenu et le volume.
    public var resume: Libelle {
        let etat = self.etat
        guard reglages.musicEnabled else { return Libelle("music_off_summary") }
        guard let choisi = MusicLibrary.selected(etat) else { return Libelle("music_none_summary") }
        if reglages.musicShuffle {
            return Libelle("music_shuffle_summary", .entier(reglages.musicVolume))
        }
        return Libelle("music_on_summary", MusiqueRegles.argument(choisi.title), .entier(reglages.musicVolume))
    }

    // MARK: La carte des réglages

    /// L'interrupteur « Jouer pendant la hitbodedout ».
    public var musiqueActive: Bool { reglages.musicEnabled }

    /// L'interrupteur « Lecture aléatoire ».
    public var aleatoire: Bool { reglages.musicShuffle }

    /// La barre du volume, de 0 à 100.
    public var volume: Int { reglages.musicVolume }

    /// L'ambiance choisie, pour la séance en cours ou la prochaine (AmbiancePlayer.choisie).
    public var ambiance: Ambiance { Ambiance.of(reglages.ambiance) }

    /// Son nom, sous « Ambiance ».
    public var ambianceTitre: Libelle { Libelle(ambiance.titre) }

    /// Les six choix du dialogue des ambiances, dans l'ordre d'Android, le choix enregistré coché.
    public var optionsAmbiance: [MusiqueOptionAmbiance] {
        let actuelle = ambiance
        return Ambiance.allCases.map { a in
            MusiqueOptionAmbiance(ambiance: a, titre: Libelle(a.titre), choisie: a == actuelle)
        }
    }

    // MARK: La bibliothèque

    /// Les morceaux livrés, puis ceux qu'on a ajoutés. En lecture aléatoire, aucun n'est « le » morceau de la
    /// séance.
    public var lignes: [MusiqueLigne] {
        let etat = self.etat
        let choisi = reglages.musicShuffle ? nil : MusicLibrary.selected(etat)?.id
        let enEssai = apercuId
        return MusicLibrary.all(etat).map { piste in
            MusiqueLigne(id: piste.id, titre: piste.title,
                         origine: Libelle(piste.isBundled ? "music_origin_bundled" : "music_origin_device"),
                         livre: piste.isBundled,
                         choisie: choisi.map { $0.egalUnites(piste.id) } ?? false,
                         enApercu: enEssai.map { $0.egalUnites(piste.id) } ?? false)
        }
    }

    // MARK: Actions des réglages

    /// L'interrupteur de la musique : la séance en cours suit (SessionService.musicChanged).
    public func activerMusique(_ oui: Bool) async {
        await ecrire { $0.setMusicEnabled(oui) }
        await lecteur.musiqueChangee()
    }

    /// L'interrupteur de la lecture aléatoire : la séance en cours suit.
    public func activerAleatoire(_ oui: Bool) async {
        await ecrire { $0.setMusicShuffle(oui) }
        await lecteur.musiqueChangee()
    }

    /// La barre du volume (ramené entre 0 et 100) : l'écoute d'essai suit tout de suite ; la séance en cours,
    /// comme sur Android, au prochain morceau.
    public func choisirVolume(_ pourcent: Int) async {
        await ecrire { $0.setMusicVolume(pourcent) }
        if apercuId != nil {
            await apercu.regler(gain: MusiqueRegles.gainMusique(reglages.musicVolume))
        }
    }

    public func ouvrirChoixAmbiance() {
        choixAmbianceOuvert = true
    }

    /// « Retour » du dialogue des ambiances.
    public func fermerChoixAmbiance() {
        choixAmbianceOuvert = false
    }

    /// Une ambiance choisie : enregistrée, suivie par la séance en cours, et cinq secondes pour l'entendre,
    /// sauf pendant une séance (elle la joue déjà) et pour le silence. Le dialogue se ferme.
    public func choisirAmbiance(_ choix: Ambiance) async {
        choixAmbianceOuvert = false
        await ecrire { $0.setAmbiance(choix.cle) }
        await lecteur.musiqueChangee()
        await ecouterAmbiance(choix)
    }

    // MARK: Actions de la bibliothèque

    /// Toucher une ligne ou son bouton radio : ce morceau devient celui des séances, et la lecture aléatoire
    /// s'éteint. Hors lecture aléatoire, comme sur Android, la séance en cours n'en est pas avertie : elle le
    /// jouera au prochain départ. En lecture aléatoire, si : sur Android, `isChecked = false` déclenche l'écouteur
    /// de l'interrupteur, donc `SessionService.musicChanged`, et la séance passe au morceau choisi.
    public func choisir(_ id: String) async {
        let quitteAleatoire = reglages.musicShuffle
        await ecrire { r in
            r.setMusicTrackId(id)
            if r.musicShuffle { r.setMusicShuffle(false) }
        }
        if quitteAleatoire {
            await lecteur.musiqueChangee()
        }
    }

    /// Le bouton de lecture d'une ligne (togglePreview) : écoute ce morceau, sans boucle, au volume choisi ;
    /// le même bouton l'arrête ; un autre morceau remplace le premier. Un morceau illisible le dit.
    public func basculerApercu(_ id: String) async {
        if let enCours = apercuId, enCours.egalUnites(id) {
            await arreterApercu()
            return
        }
        await arreterApercu()
        guard let morceau = MusicLibrary.byId(etat, id) else { return }
        numeroApercu += 1
        let ici = numeroApercu
        var lance = false
        if let chemin = await lecteur.fichier(de: morceau) {
            // L'écran a été quitté (ou un autre essai demandé) pendant la recherche du fichier : rien ne part.
            guard ici == numeroApercu else { return }
            lance = await apercu.jouer(chemin, gain: MusiqueRegles.gainMusique(reglages.musicVolume),
                                       enBoucle: false, numero: ici)
        }
        guard ici == numeroApercu else { return }
        if !lance {
            message = Libelle("music_play_failed")
            return
        }
        apercuId = morceau.id
    }

    /// Arrête l'écoute d'essai, sans fondu (stopPreview).
    public func arreterApercu() async {
        numeroApercu += 1
        apercuId = nil
        await apercu.arreter(fondu: false)
    }

    /// Le crayon d'une ligne, ou un appui long : le dialogue « Renommer », le champ rempli du nom donné.
    public func ouvrirRenommage(_ id: String) {
        let etat = self.etat
        guard let morceau = MusicLibrary.byId(etat, id) else { return }
        let nom = MusicLibrary.customName(etat, id: morceau.id)
        let neutre: MusiqueRenommage.Neutre?
        if !morceau.isBundled {
            neutre = .retirer
        } else if nom != nil {
            neutre = .titreOrigine
        } else {
            neutre = nil
        }
        texteRenommage = nom ?? ""
        renommage = MusiqueRenommage(id: morceau.id, indication: morceau.title, neutre: neutre)
    }

    /// « Retour » du dialogue « Renommer ».
    public func annulerRenommage() {
        renommage = nil
    }

    /// « Enregistrer » : le nom du champ, sans ses blancs autour ; vide, le morceau reprend son titre.
    public func enregistrerRenommage() async {
        guard let dialogue = renommage else { return }
        renommage = nil
        let nom = texteRenommage.rogne
        await modifierBibliotheque { MusicLibrary.rename(&$0, id: dialogue.id, title: nom) }
    }

    /// Le troisième bouton : « Retirer » un fichier ajouté (et sa copie), ou « Titre d'origine ».
    public func actionNeutreRenommage() async {
        guard let dialogue = renommage, let neutre = dialogue.neutre else { return }
        renommage = nil
        switch neutre {
        case .retirer:
            // Sa copie va être effacée : l'écoute d'essai ne la lit plus.
            if let enCours = apercuId, enCours.egalUnites(dialogue.id) {
                await arreterApercu()
            }
            await modifierBibliotheque { MusicLibrary.removeUserTrack(&$0, id: dialogue.id) }
            await stockage.supprimer(dialogue.id)
        case .titreOrigine:
            await modifierBibliotheque { MusicLibrary.rename(&$0, id: dialogue.id, title: "") }
        }
    }

    /// Un fichier choisi dans « Ajouter un morceau du téléphone » (le `fileImporter` de la vue) : copié dans
    /// l'app, ajouté sous le nom du fichier sans son extension, et retenu pour les séances. Une copie refusée
    /// le dit, et rien n'est ajouté.
    public func ajouter(_ source: URL) async {
        let reference: String
        do {
            reference = try await stockage.copier(source)
        } catch {
            message = Libelle("music_add_failed")
            return
        }
        let nom = MusiqueRegles.titre(de: source, reference: reference)
        await modifierBibliotheque { etat in
            MusicLibrary.addUserTrack(&etat, uri: reference, title: nom)
            etat.trackId = reference
        }
    }

    /// Le choix du fichier a échoué (le `fileImporter` rend une erreur) : comme une copie refusée.
    public func ajoutImpossible() {
        message = Libelle("music_add_failed")
    }

    /// Le message a été montré.
    public func effacerMessage() {
        message = nil
    }

    /// L'écran disparaît (onPause) : l'écoute d'essai et l'aperçu d'ambiance s'arrêtent.
    public func quitter() async {
        await arreterApercu()
        numeroAmbiance += 1
        finApercuAmbiance?.cancel()
        finApercuAmbiance = nil
        await ambianceApercu.arreter()
    }

    // MARK: En coulisse

    /// `ecouterAmbiance` : arrête l'aperçu précédent, puis cinq secondes de celle-ci, hors séance et hors silence.
    private func ecouterAmbiance(_ choix: Ambiance) async {
        numeroAmbiance += 1
        let ici = numeroAmbiance
        finApercuAmbiance?.cancel()
        finApercuAmbiance = nil
        await ambianceApercu.arreter()
        if lecteur.seanceEnCours || choix == .silence { return }
        await ambianceApercu.commencer(choix, volume: reglages.musicVolume)
        guard ici == numeroAmbiance else { return }
        let attente = self.attente
        finApercuAmbiance = Task { [weak self] in
            await attente(MusiqueRegles.apercuAmbiance)
            await self?.finirApercuAmbiance(ici)
        }
    }

    /// L'arrêt prévu d'un aperçu, s'il est encore le dernier demandé. La tâche reste nommée jusqu'au prochain
    /// aperçu ou au départ de l'écran : un test peut l'attendre même si elle a déjà fini.
    private func finirApercuAmbiance(_ numero: Int) async {
        guard numero == numeroAmbiance else { return }
        await ambianceApercu.arreter()
    }

    /// Change la bibliothèque (MusicLibrary) et recopie dans les réglages ce qui a changé.
    private func modifierBibliotheque(_ changement: (inout MusicLibrary.Etat) -> Void) async {
        await ecrire { reglages in
            var etat = MusiqueRegles.etat(reglages)
            changement(&etat)
            MusiqueRegles.poser(etat, dans: &reglages)
        }
    }

    private func ecrire(_ changement: (inout Reglages) -> Void) async {
        do {
            try await magasin.modifierReglages(changement)
        } catch {
            return
        }
    }
}
