import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le mini-lecteur de la pratique (MiniLecteur.kt) : il ne paraît que pendant une séance, nomme le morceau qui
/// joue (« Désactivée » sans musique), bascule lecture et pause, l'aléatoire, suit la position et le doigt sur
/// la barre, et montre la pochette d'un fichier ajouté, lue une fois, ou le hassid à la guitare.
@Suite("Musique : le mini-lecteur")
@MainActor
struct MusiqueMiniLecteurModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private struct Banc {
        let mini: MusiqueMiniLecteurModele
        let lecteur: MusiqueLecteur
        let sortie: MusiqueFausseSortieAudio
        let magasin: Magasin
        let pochettes: MusiqueFaussesPochettes
    }

    private func banc(_ reglages: Reglages = Reglages(), images: [MusiqueFichierAudio: Data] = [:]) -> Banc {
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let sortie = MusiqueFausseSortieAudio()
        let lecteur = MusiqueLecteur(magasin: magasin, contenus: Self.contenus, sortie: sortie,
                                     ambiance: MusiqueFausseSortieAmbiance(),
                                     melange: MelangeMusique(hasard: HasardKotlin(graine: 7)), taux: 800, secondes: 1)
        let pochettes = MusiqueFaussesPochettes(images)
        let mini = MusiqueMiniLecteurModele(magasin: magasin, lecteur: lecteur, pochettes: pochettes,
                                            attente: MusiqueAttentes.immediate)
        return Banc(mini: mini, lecteur: lecteur, sortie: sortie, magasin: magasin, pochettes: pochettes)
    }

    /// Deux fichiers ajoutés, le premier retenu.
    private func avecFichiers() -> Reglages {
        var reglages = Reglages()
        var etat = MusiqueRegles.etat(reglages)
        MusicLibrary.addUserTrack(&etat, uri: "Musique/Avec.m4a", title: "Avec")
        MusicLibrary.addUserTrack(&etat, uri: "Musique/Sans.m4a", title: "Sans")
        etat.trackId = "Musique/Avec.m4a"
        MusiqueRegles.poser(etat, dans: &reglages)
        return reglages
    }

    @Test func ilNeParaitQuePendantUneSeance() async {
        let b = banc()
        #expect(!b.mini.visible)
        await b.lecteur.commencerSeance()
        #expect(b.mini.visible)
        await b.lecteur.terminerSeance()
        #expect(!b.mini.visible)
        #expect(!b.mini.disqueTourne)
    }

    @Test func ilNommeLeMorceauQuiJoue() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        await b.mini.actualiser()
        #expect(b.mini.titre == MusicLibrary.Titre.libelle(Libelle("track_hamelech_basade")))
        await b.mini.suivant()
        #expect(b.mini.titre == MusicLibrary.Titre.libelle(Libelle("track_yanuka_nigoun_3")))
        #expect(b.mini.morceau?.id == "yanuka_nigoun_3")
    }

    @Test func sansMusiqueIlDitDesactivee() async {
        var reglages = Reglages()
        reglages.setMusicEnabled(false)
        let b = banc(reglages)
        await b.lecteur.commencerSeance()
        #expect(b.mini.morceau == nil)
        #expect(b.mini.titre == MusicLibrary.Titre.libelle(Libelle("music_off_short")))
        #expect(!b.mini.joue)
        #expect(b.mini.iconeLecture == "ic_lecteur_lecture")
        // Le grand bouton rallume la musique.
        await b.mini.basculerLecture()
        #expect(b.magasin.reglages.musicEnabled)
        #expect(b.mini.joue)
    }

    @Test func leGrandBoutonBasculeLectureEtPause() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        #expect(b.mini.joue)
        #expect(b.mini.iconeLecture == "ic_lecteur_pause")
        #expect(b.mini.libelleLecture == Libelle("lecteur_pause"))
        #expect(b.mini.disqueTourne)
        await b.mini.basculerLecture()
        #expect(!b.mini.joue)
        #expect(b.mini.iconeLecture == "ic_lecteur_lecture")
        #expect(b.mini.libelleLecture == Libelle("lecteur_lecture"))
        #expect(!b.mini.disqueTourne)
        let pauses = await b.sortie.pauses
        #expect(pauses == 1)
        await b.mini.basculerLecture()
        #expect(b.mini.joue)
        let reprises = await b.sortie.reprises
        #expect(reprises == 1)
    }

    @Test func precedentApresTroisSecondesReprendLeMorceau() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        await b.sortie.avancer(a: 45_000)
        await b.mini.actualiser()
        #expect(b.mini.position == 45_000)
        #expect(b.mini.ecoule == "0:45")
        await b.mini.precedent()
        #expect(b.mini.position == 0)
        #expect(b.mini.morceau?.id == "hamelech_basade")
    }

    @Test func leBoutonAleatoireInverseLeReglageEtLaSeanceSuit() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        #expect(!b.mini.aleatoire)
        #expect(b.mini.opaciteAleatoire == 0.45)
        await b.mini.basculerAleatoire()
        #expect(b.mini.aleatoire)
        #expect(b.mini.opaciteAleatoire == 1)
        #expect(b.magasin.reglages.musicShuffle)
        let enBoucle = await b.sortie.enBoucle
        #expect(!enBoucle)
        await b.mini.basculerAleatoire()
        #expect(!b.magasin.reglages.musicShuffle)
        let boucleDeNouveau = await b.sortie.enBoucle
        #expect(boucleDeNouveau)
    }

    @Test func laBarreEtLesTemps() async {
        let b = banc()
        #expect(b.mini.maximum == 1)
        #expect(b.mini.total == "0:00")
        await b.lecteur.commencerSeance()
        await b.mini.actualiser()
        #expect(b.mini.duree == 180_000)
        #expect(b.mini.maximum == 180_000)
        #expect(b.mini.total == "3:00")
        #expect(b.mini.ecoule == "0:00")
        // Le doigt sur la barre : elle suit le doigt, bornée, puis la lecture va là.
        b.mini.commencerGlisse()
        #expect(b.mini.glisse)
        b.mini.glisser(a: 61_500)
        #expect(b.mini.position == 61_500)
        #expect(b.mini.ecoule == "1:01")
        await b.sortie.avancer(a: 10_000)
        await b.lecteur.actualiser()
        #expect(b.mini.position == 61_500)
        b.mini.glisser(a: 999_999)
        #expect(b.mini.position == 180_000)
        b.mini.glisser(a: 90_000)
        await b.mini.finirGlisse()
        #expect(!b.mini.glisse)
        let position = await b.sortie.position
        #expect(position == 90_000)
        #expect(b.mini.position == 90_000)
    }

    @Test func deplierEtReplier() {
        let b = banc()
        #expect(!b.mini.deplie)
        #expect(b.mini.intervalle == 1_000)
        b.mini.deplier()
        #expect(b.mini.deplie)
        #expect(b.mini.intervalle == 250)
        b.mini.replier()
        #expect(!b.mini.deplie)
    }

    @Test func horsSeanceActualiserNeLitRien() async {
        let b = banc(avecFichiers())
        await b.mini.actualiser()
        let demandes = await b.pochettes.demandes
        #expect(demandes.isEmpty)
        #expect(b.mini.pochette == nil)
    }

    // MARK: La pochette

    @Test func laPochetteDUnFichierAjouteEstLueUneFois() async {
        let image = Data([0xFF, 0xD8, 0xFF])
        let b = banc(avecFichiers(), images: [.ajoute("Musique/Avec.m4a"): image])
        await b.lecteur.commencerSeance()
        await b.mini.actualiser()
        #expect(b.mini.pochette == image)
        // Le morceau suivant n'a pas de photo : le hassid à la guitare.
        await b.mini.suivant()
        #expect(b.mini.morceau?.id == "Musique/Sans.m4a")
        #expect(b.mini.pochette == nil)
        #expect(b.mini.imageParDefaut == "char_guitar")
        // Retour au morceau d'avant : sa pochette gardée, sans relire le fichier.
        await b.mini.precedent()
        #expect(b.mini.morceau?.id == "Musique/Avec.m4a")
        #expect(b.mini.pochette == image)
        await b.mini.actualiser()
        let demandes = await b.pochettes.demandes
        let attendues: [MusiqueFichierAudio] = [.ajoute("Musique/Avec.m4a"), .ajoute("Musique/Sans.m4a")]
        #expect(demandes == attendues)
    }

    @Test func leDisqueSansPochetteSuitLAdresse() {
        #expect(banc().mini.imageParDefaut == "char_guitar")
        var tsadik = Reglages()
        tsadik.setAdresse(Adresse.homme.cle)
        #expect(banc(tsadik).mini.imageParDefaut == "char_guitar")
        var tsadeket = Reglages()
        tsadeket.setAdresse(Adresse.femme.cle)
        #expect(banc(tsadeket).mini.imageParDefaut == "char_f_guitar")
    }

    @Test func unMorceauLivreMontreLeHassid() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        await b.mini.actualiser()
        #expect(b.mini.pochette == nil)
        let demandes = await b.pochettes.demandes
        #expect(demandes.isEmpty)
    }
}
