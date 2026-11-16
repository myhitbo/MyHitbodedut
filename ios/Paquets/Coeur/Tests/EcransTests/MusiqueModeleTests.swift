import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran Musique (MusicActivity.kt) : le résumé du bandeau dans chaque état, les interrupteurs, le volume,
/// l'ambiance et ses cinq secondes d'aperçu, la bibliothèque (le morceau choisi, l'écoute d'essai, le
/// renommage, le retrait), et l'ajout d'un fichier, copié dans l'app, qui survit à un relancement.
@Suite("Musique : l'écran")
@MainActor
struct MusiqueModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    /// Retient les attentes demandées, et rend la main aussitôt.
    private actor Attentes {
        private(set) var durees: [Int] = []

        func noter(_ millisecondes: Int) {
            durees.append(millisecondes)
        }
    }

    private struct Banc {
        let modele: MusiqueModele
        let lecteur: MusiqueLecteur
        let magasin: Magasin
        let persistance: PersistanceEnMemoire
        let seance: MusiqueFausseSortieAudio
        let apercu: MusiqueFausseSortieAudio
        let ambiance: MusiqueFausseSortieAmbiance
        let stockage: MusiqueFauxStockage
        let attentes: Attentes
    }

    private func banc(_ reglages: Reglages = Reglages(), illisibles: Set<MusiqueFichierAudio> = [],
                      persistance: PersistanceEnMemoire? = nil, stockage: MusiqueFauxStockage? = nil) async throws -> Banc {
        let disque = persistance ?? PersistanceEnMemoire(Enregistrement(reglages: reglages))
        let magasin = try await Magasin.charger(disque)
        let seance = MusiqueFausseSortieAudio()
        let lecteur = MusiqueLecteur(magasin: magasin, contenus: Self.contenus, sortie: seance,
                                     ambiance: MusiqueFausseSortieAmbiance(),
                                     melange: MelangeMusique(hasard: HasardKotlin(graine: 7)), taux: 800, secondes: 1)
        let apercu = MusiqueFausseSortieAudio(illisibles: illisibles)
        let ambiance = MusiqueFausseSortieAmbiance()
        let copies = stockage ?? MusiqueFauxStockage()
        let attentes = Attentes()
        let modele = MusiqueModele(magasin: magasin, lecteur: lecteur, apercu: apercu, ambianceApercu: ambiance,
                                   stockage: copies,
                                   attente: { millisecondes in await attentes.noter(millisecondes) },
                                   taux: 800, secondes: 1)
        return Banc(modele: modele, lecteur: lecteur, magasin: magasin, persistance: disque, seance: seance,
                    apercu: apercu, ambiance: ambiance, stockage: copies, attentes: attentes)
    }

    private func livre(_ id: String) -> MusiqueFichierAudio {
        .livre("Musique/\(id).m4a")
    }

    // MARK: Le bandeau

    @Test func leResumeParDefautNommeLePremierMorceauEtLeVolume() async throws {
        let b = try await banc()
        #expect(b.modele.titre == Libelle("music_title"))
        let attendu = Libelle("music_on_summary", .libelle(Libelle("track_hamelech_basade")), .entier(60))
        #expect(b.modele.resume == attendu)
        #expect(b.modele.musiqueActive)
        #expect(!b.modele.aleatoire)
        #expect(b.modele.volume == 60)
    }

    @Test func leResumeDansChaqueEtat() async throws {
        var eteinte = Reglages()
        eteinte.setMusicEnabled(false)
        eteinte.setMusicShuffle(true)
        let b1 = try await banc(eteinte)
        #expect(b1.modele.resume == Libelle("music_off_summary"))

        var hasard = Reglages()
        hasard.setMusicShuffle(true)
        hasard.setMusicVolume(35)
        let b2 = try await banc(hasard)
        #expect(b2.modele.resume == Libelle("music_shuffle_summary", .entier(35)))

        // Un nom donné s'écrit tel quel.
        var nomme = Reglages()
        nomme.setMusicTrackId("yanuka_nigoun_3")
        nomme.setMusicNames("{\"yanuka_nigoun_3\":\"Le Yanouka\"}")
        let b3 = try await banc(nomme)
        #expect(b3.modele.resume == Libelle("music_on_summary", .texte("Le Yanouka"), .entier(60)))
    }

    // MARK: Les interrupteurs et le volume

    @Test func lesInterrupteursEcriventLeurReglage() async throws {
        let b = try await banc()
        await b.modele.activerMusique(false)
        #expect(!b.magasin.reglages.musicEnabled)
        #expect(!b.modele.musiqueActive)
        await b.modele.activerAleatoire(true)
        #expect(b.magasin.reglages.musicShuffle)
        #expect(b.modele.aleatoire)
        // L'écriture est faite sur le disque.
        let ecrits = await b.persistance.enregistrement.reglages
        #expect(ecrits.musicShuffle)
        #expect(!ecrits.musicEnabled)
    }

    @Test func pendantLaSeanceLAleatoireRelanceLaMusique() async throws {
        let b = try await banc()
        await b.lecteur.commencerSeance()
        await b.modele.activerAleatoire(true)
        let enBoucle = await b.seance.enBoucle
        #expect(!enBoucle)
        let joues = await b.seance.joues.count
        #expect(joues == 2)
        await b.modele.activerMusique(false)
        let arrets = await b.seance.arrets
        #expect(arrets.last == true)
    }

    @Test func leVolumeEstBorneEtSuitLEcouteDEssai() async throws {
        let b = try await banc()
        await b.modele.choisirVolume(140)
        #expect(b.modele.volume == 100)
        await b.modele.choisirVolume(-1)
        #expect(b.modele.volume == 0)
        await b.modele.basculerApercu("yanuka_nigoun_3")
        await b.modele.choisirVolume(40)
        let gain = await b.apercu.gain
        #expect(gain == MusiqueRegles.gainMusique(40))
    }

    // MARK: L'ambiance

    @Test func lesSixAmbiancesDansLOrdreLeSilenceCoche() async throws {
        let b = try await banc()
        #expect(b.modele.ambiance == .silence)
        #expect(b.modele.ambianceTitre == Libelle("ambiance_silence"))
        let options = b.modele.optionsAmbiance
        let cles = options.map { $0.ambiance.cle }
        #expect(cles == ["silence", "pluie", "mer", "foret", "feu", "nuit"])
        let titres = options.map { $0.titre.cle }
        #expect(titres == ["ambiance_silence", "ambiance_pluie", "ambiance_mer", "ambiance_foret", "ambiance_feu",
                           "ambiance_nuit"])
        let cochees = options.filter { $0.choisie }.map { $0.ambiance }
        let silence: [Ambiance] = [.silence]
        #expect(cochees == silence)
    }

    @Test func choisirUneAmbianceLEnregistreEtLaFaitEntendreCinqSecondes() async throws {
        let b = try await banc()
        b.modele.ouvrirChoixAmbiance()
        #expect(b.modele.choixAmbianceOuvert)
        await b.modele.choisirAmbiance(.pluie)
        // L'arrêt est prévu dès la fin du choix (lu avant toute suspension : il pourrait déjà avoir eu lieu).
        let fin = try #require(b.modele.finApercuAmbiance)
        #expect(!b.modele.choixAmbianceOuvert)
        #expect(b.magasin.reglages.ambiance == "pluie")
        #expect(b.modele.ambianceTitre == Libelle("ambiance_pluie"))
        let cochees = b.modele.optionsAmbiance.filter { $0.choisie }.map { $0.ambiance }
        let pluie: [Ambiance] = [.pluie]
        #expect(cochees == pluie)
        let jouees = await b.ambiance.jouees
        #expect(jouees == pluie)
        let gain = await b.ambiance.gain
        #expect(gain == MusiqueRegles.gainAmbiance(60))
        // Cinq secondes plus tard, l'aperçu se tait.
        await fin.value
        let durees = await b.attentes.durees
        #expect(durees == [5_000])
        let boucle = await b.ambiance.enCours
        #expect(boucle == nil)
    }

    @Test func leSilenceNeSeFaitPasEntendre() async throws {
        var reglages = Reglages()
        reglages.setAmbiance("mer")
        let b = try await banc(reglages)
        await b.modele.choisirAmbiance(.silence)
        #expect(b.magasin.reglages.ambiance == "silence")
        let jouees = await b.ambiance.jouees
        #expect(jouees.isEmpty)
        let prevu = b.modele.finApercuAmbiance != nil
        #expect(!prevu)
    }

    @Test func pendantLaSeanceLAmbianceChangeSansApercu() async throws {
        let b = try await banc()
        await b.lecteur.commencerSeance()
        await b.modele.choisirAmbiance(.foret)
        let apercues = await b.ambiance.jouees
        #expect(apercues.isEmpty)
        #expect(b.lecteur.ambianceCourante == .foret)
    }

    @Test func fermerLeDialogueNeChangeRien() async throws {
        let b = try await banc()
        b.modele.ouvrirChoixAmbiance()
        b.modele.fermerChoixAmbiance()
        #expect(!b.modele.choixAmbianceOuvert)
        #expect(b.modele.ambiance == .silence)
    }

    // MARK: La bibliothèque

    @Test func lesVingtSixMorceauxLivresLePremierChoisi() async throws {
        let b = try await banc()
        let lignes = b.modele.lignes
        #expect(lignes.count == 26)
        let ids = lignes.map { $0.id }
        let attendus = MusiquePlay.morceaux.map { $0.id }
        #expect(ids == attendus)
        let choisies = lignes.filter { $0.choisie }.map { $0.id }
        #expect(choisies == ["hamelech_basade"])
        let premiere = try #require(lignes.first)
        #expect(premiere.titre == MusicLibrary.Titre.libelle(Libelle("track_hamelech_basade")))
        #expect(premiere.origine == Libelle("music_origin_bundled"))
        #expect(premiere.livre)
        let enEssai = lignes.filter { $0.enApercu }.count
        #expect(enEssai == 0)
    }

    @Test func choisirUnMorceauQuitteLaLectureAleatoire() async throws {
        let b = try await banc()
        await b.modele.activerAleatoire(true)
        let aucune = b.modele.lignes.filter { $0.choisie }.count
        #expect(aucune == 0)
        await b.modele.choisir("shpayer_pnima")
        #expect(b.magasin.reglages.musicTrackId == "shpayer_pnima")
        #expect(!b.modele.aleatoire)
        let choisies = b.modele.lignes.filter { $0.choisie }.map { $0.id }
        #expect(choisies == ["shpayer_pnima"])
    }

    @Test func lEcouteDEssaiSeBasculeEtNeBouclePas() async throws {
        let b = try await banc()
        await b.modele.basculerApercu("ianir_hello")
        #expect(b.modele.apercuId == "ianir_hello")
        let enCours = await b.apercu.enCours
        #expect(enCours == livre("ianir_hello"))
        let enBoucle = await b.apercu.enBoucle
        #expect(!enBoucle)
        let marquees = b.modele.lignes.filter { $0.enApercu }.map { $0.id }
        #expect(marquees == ["ianir_hello"])
        // Un autre morceau remplace le premier.
        await b.modele.basculerApercu("ianir_mirage")
        let suivant = await b.apercu.enCours
        #expect(suivant == livre("ianir_mirage"))
        // Le même bouton l'arrête.
        await b.modele.basculerApercu("ianir_mirage")
        #expect(b.modele.apercuId == nil)
        let arrete = await b.apercu.enCours
        #expect(arrete == nil)
        // L'écoute d'essai ne touche pas à la séance.
        let seance = await b.seance.demandes
        #expect(seance.isEmpty)
    }

    @Test func unMorceauIllisibleALEssaiLeDit() async throws {
        let b = try await banc(illisibles: [.livre("Musique/ianir_hello.m4a")])
        await b.modele.basculerApercu("ianir_hello")
        #expect(b.modele.apercuId == nil)
        #expect(b.modele.message == Libelle("music_play_failed"))
        b.modele.effacerMessage()
        #expect(b.modele.message == nil)
    }

    @Test func quitterLEcranArreteLesApercus() async throws {
        let b = try await banc()
        await b.modele.basculerApercu("ianir_hello")
        await b.modele.choisirAmbiance(.feu)
        await b.modele.quitter()
        #expect(b.modele.apercuId == nil)
        let morceau = await b.apercu.enCours
        #expect(morceau == nil)
        let boucle = await b.ambiance.enCours
        #expect(boucle == nil)
        let prevu = b.modele.finApercuAmbiance != nil
        #expect(!prevu)
    }

    // MARK: Renommer

    @Test func renommerUnMorceauLivrePuisLuiRendreSonTitre() async throws {
        let b = try await banc()
        b.modele.ouvrirRenommage("shpayer_kenout")
        let dialogue = try #require(b.modele.renommage)
        #expect(dialogue.neutre == nil)
        #expect(dialogue.libelleNeutre == nil)
        #expect(dialogue.indication == MusicLibrary.Titre.libelle(Libelle("track_shpayer_kenout")))
        #expect(dialogue.titre == Libelle("music_rename"))
        #expect(b.modele.texteRenommage == "")
        b.modele.texteRenommage = "  Kenout  "
        await b.modele.enregistrerRenommage()
        #expect(b.modele.renommage == nil)
        let trouvee = b.modele.lignes.first { $0.id == "shpayer_kenout" }
        let ligne = try #require(trouvee)
        #expect(ligne.titre == MusicLibrary.Titre.nom("Kenout"))
        // Le dialogue rouvert propose le titre d'origine, le champ rempli du nom donné.
        b.modele.ouvrirRenommage("shpayer_kenout")
        let second = try #require(b.modele.renommage)
        #expect(second.neutre == .titreOrigine)
        #expect(second.libelleNeutre == Libelle("music_rename_reset"))
        #expect(b.modele.texteRenommage == "Kenout")
        await b.modele.actionNeutreRenommage()
        let retrouvee = b.modele.lignes.first { $0.id == "shpayer_kenout" }
        let rendue = try #require(retrouvee)
        #expect(rendue.titre == MusicLibrary.Titre.libelle(Libelle("track_shpayer_kenout")))
    }

    @Test func unNomBlancRendLeTitreDOrigine() async throws {
        var reglages = Reglages()
        reglages.setMusicNames("{\"ianir_hello\":\"Shalom\"}")
        let b = try await banc(reglages)
        b.modele.ouvrirRenommage("ianir_hello")
        b.modele.texteRenommage = "   "
        await b.modele.enregistrerRenommage()
        let trouvee = b.modele.lignes.first { $0.id == "ianir_hello" }
        let ligne = try #require(trouvee)
        #expect(ligne.titre == MusicLibrary.Titre.libelle(Libelle("track_ianir_hello")))
    }

    @Test func annulerLeRenommageNeChangeRien() async throws {
        let b = try await banc()
        b.modele.ouvrirRenommage("ianir_hello")
        b.modele.texteRenommage = "Autre"
        b.modele.annulerRenommage()
        #expect(b.modele.renommage == nil)
        #expect(b.magasin.reglages.musicNames == "{}")
    }

    // MARK: Ajouter un fichier

    @Test func unFichierAjouteEstCopieChoisiEtSurvitAUnRelancement() async throws {
        let stockage = MusiqueFauxStockage()
        let b = try await banc(stockage: stockage)
        let source = URL(fileURLWithPath: "/Fichiers/Nigoun du soir.m4a")
        await b.modele.ajouter(source)
        let reference = "Musique/Nigoun du soir.m4a"
        let copiee = await stockage.existe(reference)
        #expect(copiee)
        let lignes = b.modele.lignes
        #expect(lignes.count == 27)
        let derniere = try #require(lignes.last)
        #expect(derniere.id == reference)
        #expect(derniere.titre == MusicLibrary.Titre.nom("Nigoun du soir"))
        #expect(derniere.origine == Libelle("music_origin_device"))
        #expect(!derniere.livre)
        #expect(derniere.choisie)
        #expect(b.modele.resume == Libelle("music_on_summary", .texte("Nigoun du soir"), .entier(60)))

        // Le relancement : un magasin relu du même disque, le même dossier de copies.
        let relance = try await banc(persistance: b.persistance, stockage: stockage)
        let relues = relance.modele.lignes
        #expect(relues.count == 27)
        let retrouvee = try #require(relues.last)
        #expect(retrouvee.id == reference)
        #expect(retrouvee.titre == MusicLibrary.Titre.nom("Nigoun du soir"))
        #expect(retrouvee.choisie)
        // Et il se joue depuis sa copie.
        let etat = MusiqueRegles.etat(relance.magasin.reglages)
        let morceau = MusicLibrary.byId(etat, reference)
        let piste = try #require(morceau)
        let chemin = await relance.lecteur.fichier(de: piste)
        let copie = MusiqueFichierAudio.ajoute(reference)
        #expect(chemin == copie)
        await relance.lecteur.commencerSeance()
        let joues = await relance.seance.joues
        #expect(joues == [copie])
    }

    @Test func leMemeFichierAjouteDeuxFoisNeFaitQuUneLigne() async throws {
        let b = try await banc()
        let source = URL(fileURLWithPath: "/Fichiers/Nigoun.mp3")
        await b.modele.ajouter(source)
        await b.modele.ajouter(source)
        #expect(b.modele.lignes.count == 27)
    }

    @Test func uneCopieRefuseeLeDitEtNAjouteRien() async throws {
        let stockage = MusiqueFauxStockage()
        await stockage.faireEchouer(true)
        let b = try await banc(stockage: stockage)
        await b.modele.ajouter(URL(fileURLWithPath: "/Fichiers/Nigoun.m4a"))
        #expect(b.modele.message == Libelle("music_add_failed"))
        #expect(b.modele.lignes.count == 26)
        #expect(b.magasin.reglages.musicTrackId == nil)
        b.modele.effacerMessage()
        b.modele.ajoutImpossible()
        #expect(b.modele.message == Libelle("music_add_failed"))
    }

    @Test func retirerUnFichierAjouteEffaceSaCopie() async throws {
        let stockage = MusiqueFauxStockage()
        let b = try await banc(stockage: stockage)
        await b.modele.ajouter(URL(fileURLWithPath: "/Fichiers/Nigoun.m4a"))
        let reference = "Musique/Nigoun.m4a"
        await b.modele.basculerApercu(reference)
        let essai = await b.apercu.enCours
        let copie = MusiqueFichierAudio.ajoute(reference)
        #expect(essai == copie)
        b.modele.ouvrirRenommage(reference)
        let dialogue = try #require(b.modele.renommage)
        #expect(dialogue.neutre == .retirer)
        #expect(dialogue.libelleNeutre == Libelle("music_remove"))
        #expect(dialogue.indication == MusicLibrary.Titre.nom("Nigoun"))
        await b.modele.actionNeutreRenommage()
        #expect(b.modele.lignes.count == 26)
        let existe = await stockage.existe(reference)
        #expect(!existe)
        let supprimees = await stockage.supprimees
        #expect(supprimees == [reference])
        // Il était le morceau choisi : le premier livré le redevient.
        #expect(b.magasin.reglages.musicTrackId == nil)
        let choisies = b.modele.lignes.filter { $0.choisie }.map { $0.id }
        #expect(choisies == ["hamelech_basade"])
        // Son écoute d'essai s'est arrêtée.
        #expect(b.modele.apercuId == nil)
        let arrete = await b.apercu.enCours
        #expect(arrete == nil)
    }

    // MARK: Les chaînes

    /// Chaque clé que l'écran et le mini-lecteur nomment est au catalogue, dans les trois langues.
    @Test func chaqueCleEstAuCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        var cles = ["music_title", "music_off_summary", "music_none_summary", "music_shuffle_summary",
                    "music_on_summary", "music_enable", "music_enable_hint", "music_volume", "music_shuffle",
                    "music_shuffle_hint", "ambiance_title", "music_library", "music_library_hint", "music_add",
                    "music_add_failed", "music_play_failed", "music_origin_bundled", "music_origin_device",
                    "music_rename", "music_remove", "music_rename_reset", "music_preview", "action_save",
                    "action_back", "music_off_short", "lecteur_ouvrir", "lecteur_replier", "lecteur_position",
                    "lecteur_aleatoire", "lecteur_precedent", "lecteur_suivant", "lecteur_lecture",
                    "lecteur_pause"]
        cles += Ambiance.allCases.map { $0.titre }
        cles += MusiquePlay.morceaux.map { $0.titleRes }
        for cle in cles {
            for langue in ["fr", "en", "he"] {
                let valeur = catalogue.valeur(cle, langue: langue)
                #expect(valeur != nil, "\(cle) manque en \(langue)")
            }
        }
    }
}
