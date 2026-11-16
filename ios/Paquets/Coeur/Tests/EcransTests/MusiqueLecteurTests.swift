import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La file de lecture de la séance (SessionService.kt, MusicPlayer.kt) : le critère de la tâche 18. Suivant,
/// « précédent » qui reprend le morceau au-delà de trois secondes, la lecture aléatoire sans redite, un morceau
/// illisible sauté ; puis la pause, la position, les fins de morceau, les interruptions, l'ambiance, la fin de
/// la séance. Le son est la sortie muette (MusiqueFausseSortieAudio), les morceaux livrés ceux de musique.json.
@Suite("Musique : la file de lecture")
@MainActor
struct MusiqueLecteurTests {

    /// Un seul acteur pour la suite : musique.json n'est lu qu'une fois.
    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    /// Le fichier livré d'un morceau.
    private func livre(_ id: String) -> MusiqueFichierAudio {
        .livre("Musique/\(id).m4a")
    }

    private struct Banc {
        let lecteur: MusiqueLecteur
        let sortie: MusiqueFausseSortieAudio
        let ambiance: MusiqueFausseSortieAmbiance
        let magasin: Magasin
    }

    /// Un lecteur sur des réglages donnés ; le hasard de la lecture aléatoire part de `graine`.
    private func banc(_ reglages: Reglages = Reglages(), illisibles: Set<MusiqueFichierAudio> = [],
                      graine: Int32 = 7) -> Banc {
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let sortie = MusiqueFausseSortieAudio(illisibles: illisibles)
        let ambiance = MusiqueFausseSortieAmbiance()
        let lecteur = MusiqueLecteur(magasin: magasin, contenus: Self.contenus, sortie: sortie, ambiance: ambiance,
                                     melange: MelangeMusique(hasard: HasardKotlin(graine: graine)),
                                     taux: 800, secondes: 1)
        return Banc(lecteur: lecteur, sortie: sortie, ambiance: ambiance, magasin: magasin)
    }

    private func aleatoire() -> Reglages {
        var reglages = Reglages()
        reglages.setMusicShuffle(true)
        return reglages
    }

    /// Les identifiants des morceaux de la bibliothèque, dans l'ordre.
    private var ids: [String] {
        MusicLibrary.all(MusicLibrary.Etat()).map { $0.id }
    }

    /// Le morceau qui joue, d'après `music_now`.
    private func maintenant(_ b: Banc) -> String? {
        b.magasin.reglages.musicNow
    }

    /// La fin du morceau qui joue : la sortie l'annonce, le lecteur la reçoit.
    private func finir(_ b: Banc) async throws {
        let annonce = await b.sortie.terminer()
        let fin = try #require(annonce)
        await b.lecteur.recevoir(fin)
    }

    // MARK: Le morceau retenu

    @Test func laSeanceJoueLeMorceauRetenuEnBoucle() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        let joues = await b.sortie.joues
        #expect(joues == [livre("hamelech_basade")])
        let enBoucle = await b.sortie.enBoucle
        #expect(enBoucle)
        let gain = await b.sortie.gain
        #expect(gain == MusiqueRegles.gainMusique(Reglages.defaultVolume))
        #expect(maintenant(b) == "hamelech_basade")
        #expect(b.lecteur.seanceEnCours)
        #expect(b.lecteur.charge)
        #expect(b.lecteur.joue)
        let duree = b.lecteur.duree
        #expect(duree == 180_000)
        // Un morceau qui boucle ne finit pas : rien ne s'enchaîne.
        let fin = await b.sortie.terminer()
        #expect(fin == nil)
    }

    @Test func horsSeanceRienNeJoue() async {
        let b = banc()
        await b.lecteur.suivant()
        await b.lecteur.precedent()
        await b.lecteur.reprendre()
        await b.lecteur.musiqueChangee()
        let demandes = await b.sortie.demandes
        #expect(demandes.isEmpty)
        #expect(maintenant(b) == nil)
    }

    @Test func laMusiqueEteinteNeJouePasMaisLAmbianceSi() async {
        var reglages = Reglages()
        reglages.setMusicEnabled(false)
        reglages.setAmbiance("pluie")
        let b = banc(reglages)
        await b.lecteur.commencerSeance()
        let demandes = await b.sortie.demandes
        #expect(demandes.isEmpty)
        let ambiances = await b.ambiance.jouees
        #expect(ambiances == [.pluie])
        let gain = await b.ambiance.gain
        #expect(gain == MusiqueRegles.gainAmbiance(Reglages.defaultVolume))
        let boucle = await b.ambiance.enCours
        #expect(boucle?.taux == 800)
        #expect(boucle?.echantillons.count == 800)
        #expect(b.lecteur.ambianceCourante == .pluie)
    }

    // MARK: Suivant et précédent

    @Test func suivantPasseAuMorceauDApresQuiDevientLeMorceauRetenu() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        await b.lecteur.suivant()
        let joues = await b.sortie.joues
        #expect(joues == [livre("hamelech_basade"), livre("yanuka_nigoun_3")])
        #expect(maintenant(b) == "yanuka_nigoun_3")
        #expect(b.magasin.reglages.musicTrackId == "yanuka_nigoun_3")
        // Changer de morceau arrête l'ancien sans fondu, et le nouveau boucle comme avant.
        let arrets = await b.sortie.arrets
        #expect(arrets == [false])
        let enBoucle = await b.sortie.enBoucle
        #expect(enBoucle)
    }

    @Test func suivantApresLeDernierRevientAuPremier() async {
        var reglages = Reglages()
        reglages.setMusicTrackId("ianir_bessarabie")
        let b = banc(reglages)
        await b.lecteur.commencerSeance()
        #expect(maintenant(b) == "ianir_bessarabie")
        await b.lecteur.suivant()
        #expect(maintenant(b) == "hamelech_basade")
    }

    @Test func precedentAuDebutDuMorceauPrendLeMorceauDAvant() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        // Exactement trois secondes : ce n'est pas « au-delà ».
        await b.sortie.avancer(a: 3_000)
        await b.lecteur.precedent()
        let dernier = ids.last
        #expect(maintenant(b) == dernier)
        let joues = await b.sortie.joues
        #expect(joues == [livre("hamelech_basade"), livre("ianir_bessarabie")])
    }

    @Test func precedentApresTroisSecondesReprendLeMorceau() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        await b.sortie.avancer(a: 3_001)
        await b.lecteur.precedent()
        let position = await b.sortie.position
        #expect(position == 0)
        let joues = await b.sortie.joues
        #expect(joues == [livre("hamelech_basade")])
        #expect(maintenant(b) == "hamelech_basade")
        #expect(b.lecteur.position == 0)
    }

    @Test func suivantRallumeLaMusiqueEteinte() async {
        var reglages = Reglages()
        reglages.setMusicEnabled(false)
        let b = banc(reglages)
        await b.lecteur.commencerSeance()
        await b.lecteur.suivant()
        #expect(b.magasin.reglages.musicEnabled)
        #expect(maintenant(b) == "yanuka_nigoun_3")
    }

    // MARK: La lecture aléatoire

    /// Un tour entier sans redite, dans l'ordre du mélange d'Android pour la même graine ; au tour suivant, le
    /// dernier morceau n'ouvre pas le nouveau tour.
    @Test func laLectureAleatoireNeRepeteRienAvantQueToutAitJoue() async throws {
        let b = banc(aleatoire(), graine: 42)
        await b.lecteur.commencerSeance()
        var suite: [String] = []
        for _ in 0..<(ids.count * 2) {
            let id = try #require(maintenant(b))
            suite.append(id)
            try await finir(b)
        }
        let premierTour = Array(suite.prefix(ids.count))
        #expect(Set(premierTour) == Set(ids))
        #expect(premierTour.count == ids.count)
        let secondTour = Array(suite.suffix(ids.count))
        #expect(Set(secondTour) == Set(ids))
        for k in 1..<suite.count {
            #expect(suite[k] != suite[k - 1], "redite au rang \(k)")
        }
        // Le même mélange qu'Android : MelangeMusique, la même graine.
        var melange = MelangeMusique(hasard: HasardKotlin(graine: 42))
        var attendue: [String] = []
        for _ in 0..<suite.count {
            let tire = melange.suivant(ids)
            let id = try #require(tire)
            attendue.append(id)
        }
        #expect(suite == attendue)
        // En lecture aléatoire, un morceau ne boucle pas : sa fin enchaîne le suivant.
        let enBoucle = await b.sortie.enBoucle
        #expect(!enBoucle)
    }

    @Test func suivantEnAleatoireTireUnAutreMorceau() async throws {
        let b = banc(aleatoire())
        await b.lecteur.commencerSeance()
        let premier = try #require(maintenant(b))
        await b.lecteur.suivant()
        let second = try #require(maintenant(b))
        #expect(second != premier)
        // Le morceau retenu ne change pas en lecture aléatoire.
        #expect(b.magasin.reglages.musicTrackId == nil)
    }

    @Test func precedentEnAleatoireRejoueLeMorceauDAvant() async throws {
        let b = banc(aleatoire())
        await b.lecteur.commencerSeance()
        let premier = try #require(maintenant(b))
        try await finir(b)
        let second = try #require(maintenant(b))
        #expect(second != premier)
        await b.lecteur.precedent()
        #expect(maintenant(b) == premier)
        let dernier = await b.sortie.joues.last
        #expect(dernier == livre(premier))
        // Il reste en lecture aléatoire : sa fin enchaîne au hasard.
        let enBoucle = await b.sortie.enBoucle
        #expect(!enBoucle)
        try await finir(b)
        let apres = maintenant(b)
        #expect(apres != nil)
        #expect(apres != premier)
    }

    /// Au premier morceau de la séance, « précédent » en lecture aléatoire le rejoue du début (SessionService :
    /// l'histoire n'a qu'un morceau, il reste le dernier).
    @Test func precedentEnAleatoireAuPremierMorceauLeRejoue() async throws {
        let b = banc(aleatoire())
        await b.lecteur.commencerSeance()
        let premier = try #require(maintenant(b))
        await b.lecteur.precedent()
        #expect(maintenant(b) == premier)
        let joues = await b.sortie.joues
        #expect(joues == [livre(premier), livre(premier)])
    }

    // MARK: Le morceau illisible

    @Test func unMorceauIllisibleEstSauteEnLectureAleatoire() async throws {
        var melange = MelangeMusique(hasard: HasardKotlin(graine: 7))
        let tire1 = melange.suivant(ids)
        let tire2 = melange.suivant(ids)
        let premier = try #require(tire1)
        let second = try #require(tire2)
        let b = banc(aleatoire(), illisibles: [livre(premier)])
        await b.lecteur.commencerSeance()
        let demandes = await b.sortie.demandes
        #expect(demandes == [livre(premier), livre(second)])
        let joues = await b.sortie.joues
        #expect(joues == [livre(second)])
        #expect(maintenant(b) == second)
        #expect(b.lecteur.message == nil)
    }

    @Test func troisMorceauxIllisiblesDeSuiteLeDisent() async {
        let tous = Set(ids.map { livre($0) })
        let b = banc(aleatoire(), illisibles: tous)
        await b.lecteur.commencerSeance()
        let demandes = await b.sortie.demandes
        #expect(demandes.count == MusiqueRegles.essais)
        #expect(b.lecteur.message == Libelle("music_play_failed"))
        #expect(!b.lecteur.charge)
        b.lecteur.effacerMessage()
        #expect(b.lecteur.message == nil)
    }

    @Test func leMorceauRetenuIllisibleLeDit() async {
        let b = banc(illisibles: [livre("hamelech_basade")])
        await b.lecteur.commencerSeance()
        #expect(b.lecteur.message == Libelle("music_play_failed"))
        #expect(!b.lecteur.charge)
        let joues = await b.sortie.joues
        #expect(joues.isEmpty)
    }

    /// Un fichier ajouté dont la copie a disparu : sauté comme un fichier illisible.
    @Test func unFichierAjouteDisparuEstSaute() async {
        var reglages = aleatoire()
        var etat = MusiqueRegles.etat(reglages)
        MusicLibrary.addUserTrack(&etat, uri: "Musique/Disparu.m4a", title: "Disparu")
        MusiqueRegles.poser(etat, dans: &reglages)
        let b = banc(reglages, illisibles: [.ajoute("Musique/Disparu.m4a")])
        await b.lecteur.commencerSeance()
        for _ in 0..<40 {
            guard let fin = await b.sortie.terminer() else { break }
            await b.lecteur.recevoir(fin)
        }
        let joues = await b.sortie.joues
        #expect(!joues.contains(.ajoute("Musique/Disparu.m4a")))
        let demandes = await b.sortie.demandes
        #expect(demandes.contains(.ajoute("Musique/Disparu.m4a")))
        #expect(b.lecteur.message == nil)
    }

    /// Une erreur en cours de lecture fait comme la fin du morceau : le suivant part.
    @Test func unEchecEnCoursDeLectureEnchaine() async throws {
        let b = banc(aleatoire())
        await b.lecteur.commencerSeance()
        let premier = try #require(maintenant(b))
        let enCours = await b.sortie.numero
        let numero = try #require(enCours)
        await b.lecteur.recevoir(.echec(numero: numero))
        let second = try #require(maintenant(b))
        #expect(second != premier)
        let joues = await b.sortie.joues.count
        #expect(joues == 2)
    }

    // MARK: Fins de morceau

    @Test func laFinDUnMorceauRemplaceEstIgnoree() async throws {
        let b = banc(aleatoire())
        await b.lecteur.commencerSeance()
        let enCours = await b.sortie.numero
        let ancien = try #require(enCours)
        await b.lecteur.suivant()
        let avant = await b.sortie.joues.count
        await b.lecteur.recevoir(.fin(numero: ancien))
        let apres = await b.sortie.joues.count
        #expect(apres == avant)
    }

    @Test func laFinNEnchainePasQuandLaMusiqueEstEteinte() async throws {
        let b = banc(aleatoire())
        await b.lecteur.commencerSeance()
        let enCours = await b.sortie.numero
        let numero = try #require(enCours)
        try await b.magasin.modifierReglages { $0.setMusicEnabled(false) }
        await b.lecteur.recevoir(.fin(numero: numero))
        let joues = await b.sortie.joues.count
        #expect(joues == 1)
    }

    // MARK: Pause, reprise, position

    @Test func pauseEtReprise() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        await b.lecteur.pause()
        #expect(b.lecteur.enPause)
        #expect(!b.lecteur.joue)
        #expect(b.lecteur.charge)
        await b.lecteur.reprendre()
        #expect(!b.lecteur.enPause)
        #expect(b.lecteur.joue)
        let reprises = await b.sortie.reprises
        #expect(reprises == 1)
        // Reprendre ne relance pas le morceau du début.
        let joues = await b.sortie.joues.count
        #expect(joues == 1)
    }

    @Test func reprendreRallumeLaMusiqueEteinte() async {
        var reglages = Reglages()
        reglages.setMusicEnabled(false)
        let b = banc(reglages)
        await b.lecteur.commencerSeance()
        await b.lecteur.reprendre()
        #expect(b.magasin.reglages.musicEnabled)
        let joues = await b.sortie.joues
        #expect(joues == [livre("hamelech_basade")])
    }

    @Test func allerEstBorneParLaDuree() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        await b.lecteur.aller(a: 60_000)
        #expect(b.lecteur.position == 60_000)
        await b.lecteur.aller(a: 999_999)
        #expect(b.lecteur.position == 180_000)
        await b.lecteur.aller(a: -5)
        #expect(b.lecteur.position == 0)
    }

    @Test func uneInterruptionFinieRelanceSaufEnPause() async {
        let b = banc()
        await b.lecteur.commencerSeance()
        let coupure = await b.sortie.interrompre()
        await b.lecteur.recevoir(coupure)
        #expect(!b.lecteur.joue)
        await b.lecteur.recevoir(.finInterruption(reprendre: true))
        #expect(b.lecteur.joue)
        await b.lecteur.pause()
        await b.lecteur.recevoir(.finInterruption(reprendre: true))
        #expect(!b.lecteur.joue)
        let reprises = await b.sortie.reprises
        #expect(reprises == 1)
    }

    // MARK: Les réglages pendant la séance

    @Test func eteindreLaMusiqueLArreteEnFondu() async throws {
        let b = banc()
        await b.lecteur.commencerSeance()
        try await b.magasin.modifierReglages { $0.setMusicEnabled(false) }
        await b.lecteur.musiqueChangee()
        let arrets = await b.sortie.arrets
        #expect(arrets == [true])
        #expect(!b.lecteur.charge)
        // Rallumée, elle reprend le morceau retenu.
        try await b.magasin.modifierReglages { $0.setMusicEnabled(true) }
        await b.lecteur.musiqueChangee()
        let joues = await b.sortie.joues
        #expect(joues == [livre("hamelech_basade"), livre("hamelech_basade")])
    }

    @Test func passerALaLectureAleatoireRelanceLaMusique() async throws {
        let b = banc()
        await b.lecteur.commencerSeance()
        try await b.magasin.modifierReglages { $0.setMusicShuffle(true) }
        await b.lecteur.musiqueChangee()
        let arrets = await b.sortie.arrets
        #expect(arrets == [false])
        let enBoucle = await b.sortie.enBoucle
        #expect(!enBoucle)
        let joues = await b.sortie.joues.count
        #expect(joues == 2)
    }

    @Test func lAmbianceSuitSonReglage() async throws {
        let b = banc()
        await b.lecteur.commencerSeance()
        let rien = await b.ambiance.jouees
        #expect(rien.isEmpty)
        try await b.magasin.modifierReglages { $0.setAmbiance("mer") }
        await b.lecteur.musiqueChangee()
        let jouees = await b.ambiance.jouees
        #expect(jouees == [.mer])
        // La même ambiance ne change que de volume.
        try await b.magasin.modifierReglages { $0.setMusicVolume(100) }
        await b.lecteur.musiqueChangee()
        let encore = await b.ambiance.jouees
        #expect(encore == [.mer])
        let gain = await b.ambiance.gain
        #expect(gain == MusiqueRegles.gainAmbiance(100))
        // Le silence la fait taire.
        try await b.magasin.modifierReglages { $0.setAmbiance("silence") }
        await b.lecteur.musiqueChangee()
        let boucle = await b.ambiance.enCours
        #expect(boucle == nil)
    }

    @Test func laFinDeLaSeanceEteintToutEnFondu() async {
        var reglages = Reglages()
        reglages.setAmbiance("feu")
        let b = banc(reglages)
        await b.lecteur.commencerSeance()
        await b.lecteur.terminerSeance()
        let arrets = await b.sortie.arrets
        #expect(arrets == [true])
        let boucle = await b.ambiance.enCours
        #expect(boucle == nil)
        #expect(maintenant(b) == nil)
        #expect(!b.lecteur.seanceEnCours)
        #expect(b.lecteur.morceauEnCours == nil)
        // Après la séance, le mini-lecteur ne commande plus rien.
        await b.lecteur.suivant()
        let joues = await b.sortie.joues.count
        #expect(joues == 1)
    }

    // MARK: Les fichiers

    @Test func lesFichiersDesMorceauxLivresSontCeuxDeMusiqueJson() async {
        let b = banc()
        for piste in MusicLibrary.all(MusicLibrary.Etat()) {
            let chemin = await b.lecteur.fichier(de: piste)
            #expect(chemin == livre(piste.id), "\(piste.id)")
        }
        let ajoute = MusicLibrary.Track(id: "Musique/Nigoun.m4a", title: .nom("Nigoun"), uri: "Musique/Nigoun.m4a")
        let chemin = await b.lecteur.fichier(de: ajoute)
        #expect(chemin == .ajoute("Musique/Nigoun.m4a"))
        let inconnu = MusicLibrary.Track(id: "inconnu", title: .nom("?"), rawRes: "inconnu")
        let absent = await b.lecteur.fichier(de: inconnu)
        #expect(absent == nil)
    }

    // MARK: Les petites règles

    @Test func lesReglesDuVolumeEtDuTemps() {
        let soixante: Float = 0.6
        let plein: Float = 1
        let rien: Float = 0
        #expect(MusiqueRegles.gainMusique(60) == soixante)
        #expect(MusiqueRegles.gainMusique(150) == plein)
        #expect(MusiqueRegles.gainMusique(-3) == rien)
        let ambiance: Float = 60.0 / 100 * 0.8
        #expect(MusiqueRegles.gainAmbiance(60) == ambiance)
        #expect(MusiqueRegles.temps(0) == "0:00")
        #expect(MusiqueRegles.temps(999) == "0:00")
        #expect(MusiqueRegles.temps(61_000) == "1:01")
        #expect(MusiqueRegles.temps(180_000) == "3:00")
        #expect(MusiqueRegles.temps(3_600_000) == "60:00")
        #expect(MusiqueRegles.temps(-5_000) == "0:00")
    }

    @Test func leTitreDUnFichierAjoute() {
        let nigoun = URL(fileURLWithPath: "/tmp/Nigoun de Breslev.m4a")
        #expect(MusiqueRegles.titre(de: nigoun, reference: "Musique/Nigoun de Breslev.m4a") == "Nigoun de Breslev")
        let points = URL(fileURLWithPath: "/tmp/a.b.mp3")
        #expect(MusiqueRegles.titre(de: points, reference: "Musique/a.b.mp3") == "a.b")
        let sansExtension = URL(fileURLWithPath: "/tmp/Chant")
        #expect(MusiqueRegles.titre(de: sansExtension, reference: "Musique/Chant") == "Chant")
    }
}
