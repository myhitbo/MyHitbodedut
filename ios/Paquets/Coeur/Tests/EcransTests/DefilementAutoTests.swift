import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le défilement automatique des écrans de lecture (ReglagesLecture.kt, 16/11) : le niveau de 1 à 10 gardé sous
/// `lecture_defilement_vitesse`, la vitesse de chaque niveau, le pas de chaque image, l'arrêt au bout et au
/// masquage du bouton, et le même défilement dans le siddour, les Tehilim, le Tikoun, les sources de la
/// bibliothèque, la halakha et les hilloulot (ces deux-là sans lune ni langues, comme Android) ; l'écran allumé
/// tant qu'un écran le demande (`EcranAllumeDemandes`).
///
/// Restent au test d'interface et à l'iPhone : le texte qui défile vraiment (TimelineView, ScrollPosition), le doigt
/// sur le texte qui l'arrête (`ToucherDuTexte`, la phase du ScrollView), `isIdleTimerDisabled` lui-même.
@Suite("Le défilement automatique")
@MainActor
struct DefilementAutoTests {

    private static func defilement(_ reglages: Reglages = Reglages()) -> (DefilementAuto, Magasin) {
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        return (DefilementAuto(magasin: magasin), magasin)
    }

    private static func brut(_ texte: String) throws -> Reglages {
        try Reglages(texte: texte)
    }

    // MARK: Le niveau

    @Test func leNiveauEstTroisParDefaut() {
        let (d, _) = Self.defilement()
        #expect(d.niveau == 3)
        #expect(Reglages().lectureDefilementVitesse == 3)
        #expect(!d.actif)
        #expect(!d.commandeVisible)
        #expect(!d.garderEcranAllume)
    }

    @Test func leNiveauLuEstRameneDeUnADix() throws {
        #expect(try Self.brut(#"{"lecture_defilement_vitesse":0}"#).lectureDefilementVitesse == 1)
        #expect(try Self.brut(#"{"lecture_defilement_vitesse":-4}"#).lectureDefilementVitesse == 1)
        #expect(try Self.brut(#"{"lecture_defilement_vitesse":11}"#).lectureDefilementVitesse == 10)
        #expect(try Self.brut(#"{"lecture_defilement_vitesse":7}"#).lectureDefilementVitesse == 7)
        // Comme getInt d'org.json : un nombre écrit en chaîne se lit, un booléen rend le défaut.
        #expect(try Self.brut(#"{"lecture_defilement_vitesse":"8"}"#).lectureDefilementVitesse == 8)
        #expect(try Self.brut(#"{"lecture_defilement_vitesse":true}"#).lectureDefilementVitesse == 3)
    }

    @Test func leNiveauEcritEstRameneDeUnADix() {
        var r = Reglages()
        r.setLectureDefilementVitesse(42)
        #expect(r.texte() == #"{"lecture_defilement_vitesse":10}"#)
        r.setLectureDefilementVitesse(0)
        #expect(r.texte() == #"{"lecture_defilement_vitesse":1}"#)
        r.setLectureDefilementVitesse(5)
        #expect(r.lectureDefilementVitesse == 5)
    }

    @Test func plusEtMoinsViteRestentDeUnADix() async throws {
        let (d, magasin) = Self.defilement()
        #expect(d.moinsViteActif && d.plusViteActif)
        for _ in 0..<12 { try await d.plusVite() }
        #expect(d.niveau == 10)
        #expect(!d.plusViteActif)
        #expect(magasin.reglages.brut["lecture_defilement_vitesse"] == .entier(10))
        for _ in 0..<12 { try await d.moinsVite() }
        #expect(d.niveau == 1)
        #expect(!d.moinsViteActif)
        try await d.plusVite()
        #expect(d.niveau == 2)
    }

    @Test func leNiveauSeGardeDansLesReglages() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        let d = DefilementAuto(magasin: magasin)
        try await d.plusVite()
        try await d.plusVite()
        #expect(d.niveau == 5)
        // Relu du disque, et par le texte de reglages.json.
        let relu = try await Magasin.charger(persistance)
        #expect(DefilementAuto(magasin: relu).niveau == 5)
        let texte = relu.reglages.texte()
        #expect(try Reglages(texte: texte).lectureDefilementVitesse == 5)
        // Qu'il défile ou non ne se garde pas.
        d.lancer()
        #expect(!DefilementAuto(magasin: try await Magasin.charger(persistance)).actif)
    }

    // MARK: La vitesse

    @Test func laVitesseDeChaqueNiveau() {
        let attendues: [Double] = [6, 8.4, 11.76, 16.464, 23.0496, 32.26944, 45.177216, 63.2481024, 88.54734336,
                                   123.966280704]
        for (rang, attendue) in attendues.enumerated() {
            let v = DefilementAuto.vitesse(rang + 1, echelle: 1)
            #expect(abs(v - attendue) < 1e-9, "niveau \(rang + 1) : \(v)")
        }
        #expect(abs(DefilementAuto.vitesse(3, echelle: 2) - 23.52) < 1e-9)
        #expect(abs(DefilementAuto.vitesse(1, echelle: 0.8) - 4.8) < 1e-9)
    }

    @Test func laVitesseSuitLaTailleDesLettres() async throws {
        var r = Reglages()
        r.setLectureEchelle(1.5)
        r.setLectureDefilementVitesse(2)
        let (d, _) = Self.defilement(r)
        #expect(abs(d.pointsParSeconde - 12.6) < 1e-5)
    }

    // MARK: Le pas de chaque image

    @Test func rienNeBougeALArret() {
        let (d, _) = Self.defilement()
        let pas = d.avancer(position: 100, ecoule: 1, fin: 1000)
        #expect(pas.position == 100)
        #expect(!pas.finAtteinte)
    }

    @Test func millePetitesImagesFontLeMemeCheminQuUneGrande() {
        for niveau in 1...10 {
            var r = Reglages()
            r.setLectureDefilementVitesse(niveau)
            let (petites, _) = Self.defilement(r)
            let (grande, _) = Self.defilement(r)
            petites.lancer()
            grande.lancer()
            var position = 0.0
            for _ in 0..<600 {
                position = petites.avancer(position: position, ecoule: 1.0 / 60, fin: 100_000).position
            }
            let dUnCoup = grande.avancer(position: 0, ecoule: 10, fin: 100_000).position
            #expect(position == dUnCoup, "niveau \(niveau) : \(position) ≠ \(dUnCoup)")
            #expect(dUnCoup == (DefilementAuto.vitesse(niveau, echelle: 1) * 10 + 1e-6).rounded(.down))
            // Seuls des points entiers s'ajoutent.
            #expect(position == position.rounded())
        }
    }

    @Test func lesFractionsAttendentLImageSuivante() {
        let (d, _) = Self.defilement()
        d.lancer()
        // Niveau 3 : 11,76 points par seconde ; une image de 1/60 s fait 0,196 point.
        var position = 0.0
        for _ in 0..<5 {
            position = d.avancer(position: position, ecoule: 1.0 / 60, fin: 1000).position
        }
        #expect(position == 0)
        position = d.avancer(position: position, ecoule: 1.0 / 60, fin: 1000).position
        #expect(position == 1)
    }

    @Test func leBoutDuTexteArreteLeDefilement() {
        let (d, _) = Self.defilement()
        d.lancer()
        let presque = d.avancer(position: 990, ecoule: 0.5, fin: 1000)
        #expect(presque.position == 995)
        #expect(!presque.finAtteinte)
        let bout = d.avancer(position: presque.position, ecoule: 1, fin: 1000)
        #expect(bout.position == 1000)
        #expect(bout.finAtteinte)
        #expect(!d.actif)
        #expect(!d.garderEcranAllume)
        // Déjà au bout (un texte plus court que l'écran) : il s'arrête aussitôt.
        d.lancer()
        let court = d.avancer(position: 0, ecoule: 1, fin: 0)
        #expect(court.position == 0 && court.finAtteinte)
        #expect(!d.actif)
    }

    // MARK: Les boutons et leurs noms

    @Test func leBoutonLanceEtArrete() {
        let (d, _) = Self.defilement()
        #expect(d.libelleBouton == Libelle("lecture_defiler"))
        d.basculer()
        #expect(d.actif)
        #expect(d.commandeVisible && d.garderEcranAllume)
        #expect(d.libelleBouton == Libelle("lecture_defiler_pause"))
        #expect(d.libelleVitesse == Libelle("lecture_vitesse", .entier(3)))
        d.basculer()
        #expect(!d.actif)
        d.basculer()
        d.arreter()
        #expect(!d.actif && !d.commandeVisible)
    }

    // MARK: Les écrans de lecture

    @Test func lesEcransDeLectureLePartagent() async throws {
        let magasin = Magasin.enMemoire()
        let siddour = LectureModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                    horloge: HorlogeFixe(maintenant: 0), langue: "fr", cible: .siddour("chaharit"))
        let tehilim = TehilimBarreLecture(magasin: magasin, langue: "fr")
        try await siddour.defilementAuto.plusVite()
        #expect(tehilim.defilementAuto.niveau == 4)
        // Le niveau est commun, pas le fait de défiler.
        tehilim.defilementAuto.lancer()
        #expect(!siddour.defilementAuto.actif)
        // Quitter le lecteur l'arrête.
        siddour.defilementAuto.lancer()
        try await siddour.quitter()
        #expect(!siddour.defilementAuto.actif)
    }

    @Test func masquerLeBoutonArreteLeDefilement() async throws {
        // Comme ReglagesLecture.masquer d'Android (24/11) : plus rien à l'écran, pas même la commande.
        let magasin = Magasin.enMemoire()
        let siddour = LectureModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                    horloge: HorlogeFixe(maintenant: 0), langue: "fr", cible: .siddour("chaharit"))
        siddour.defilementAuto.lancer()
        try await siddour.masquer()
        #expect(!siddour.defilementAuto.actif && !siddour.defilementAuto.commandeVisible)
        let tehilim = TehilimBarreLecture(magasin: magasin, langue: "fr")
        tehilim.defilementAuto.lancer()
        try await tehilim.masquer()
        #expect(!tehilim.defilementAuto.actif && !tehilim.defilementAuto.commandeVisible)
        let source = BibliothequeBarreLecture(magasin: magasin, langue: "fr")
        source.defilementAuto.lancer()
        try await source.masquer()
        #expect(!source.defilementAuto.actif && !source.defilementAuto.commandeVisible)
    }

    // MARK: La halakha, les hilloulot, les sources (24/11)

    /// Comme HalakhaActivity et HilloulotActivity (ReglagesLecture.installer, `avecNuit` et `avecLangues` faux) :
    /// A−, %, A+, la police, le défilement automatique, masquer, replier ; le niveau commun aux écrans de lecture.
    @Test func laHalakhaEtLesHilloulotDefilentSansLuneNiLangues() async throws {
        let magasin = Magasin.enMemoire()
        let horloge = HorlogeFixe(maintenant: 0)
        let halakha = HalakhaModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                    horloge: horloge, langue: "fr")
        let hilloulot = HilloulotModele(magasin: magasin, contenus: HilloulotContenus(dossier: Fichiers.contenu),
                                        horloge: horloge, langue: "fr")
        for barre in [halakha.barre, hilloulot.barre] {
            #expect(!barre.avecNuit && !barre.avecLangues)
            #expect(barre.pastilleVisible && !barre.barreVisible)
            #expect(!barre.defilementAuto.actif)
        }
        let tehilim = TehilimBarreLecture(magasin: magasin, langue: "fr")
        #expect(tehilim.avecNuit && tehilim.avecLangues)
        try await halakha.barre.defilementAuto.plusVite()
        #expect(hilloulot.barre.defilementAuto.niveau == 4)
        #expect(tehilim.defilementAuto.niveau == 4)
        // La taille des lettres de la barre est celle que la halakha et les hilloulot appliquent.
        try await hilloulot.barre.changerTaille(plus: true)
        #expect(halakha.echelle == 1.1)
        #expect(hilloulot.echelle == 1.1)
        // Masquer arrête le défilement ; deux touchers (retrouver) rendent la barre dépliée.
        halakha.barre.defilementAuto.lancer()
        try await halakha.barre.masquer()
        #expect(!halakha.barre.defilementAuto.actif)
        #expect(!halakha.barre.pastilleVisible && !halakha.barre.barreVisible)
        try await halakha.barre.retrouver()
        #expect(halakha.barre.barreVisible)
    }

    /// La source d'une entrée de la bibliothèque (LibraryEntryActivity) a le défilement automatique dans sa barre, au
    /// niveau commun.
    @Test func uneSourceDeLaBibliothequeDefileAussi() async throws {
        let magasin = Magasin.enMemoire()
        let entree = BibliothequeEntreeModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                              langue: "fr", id: "src-lm2-25")
        await entree.charger()
        #expect(entree.barreLectureVisible)
        let siddour = LectureModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                    horloge: HorlogeFixe(maintenant: 0), langue: "fr", cible: .siddour("chaharit"))
        try await siddour.defilementAuto.plusVite()
        #expect(entree.barre.defilementAuto.niveau == 4)
        entree.barre.defilementAuto.basculer()
        #expect(entree.barre.defilementAuto.actif && entree.barre.defilementAuto.garderEcranAllume)
        #expect(!siddour.defilementAuto.actif)
    }

    // MARK: L'écran allumé

    /// Le défilement qui s'arrête rend l'écran à ce qu'il était : allumé si la séance le demande encore, à la veille
    /// du téléphone sinon (keepScreenOn d'Android, qui s'ajoute au drapeau de la fenêtre sans y toucher).
    @Test func lEcranResteAllumeTantQuUnEcranLeDemande() {
        let demandes = EcranAllumeDemandes()
        #expect(!demandes.allume)
        #expect(demandes.garder(true, pour: "seance"))
        #expect(demandes.garder(true, pour: "defilement-1"))
        #expect(demandes.garder(false, pour: "defilement-1"))
        #expect(demandes.allume)
        #expect(!demandes.garder(false, pour: "seance"))
        // Sans la séance : le défilement seul, puis plus rien.
        #expect(demandes.garder(true, pour: "defilement-2"))
        #expect(demandes.garder(true, pour: "defilement-2"))
        #expect(!demandes.garder(false, pour: "defilement-2"))
        // Retirer une demande absente ne change rien.
        #expect(!demandes.garder(false, pour: "defilement-3"))
        #expect(demandes.demandeurs.isEmpty)
    }

    /// VeilleLecture.kt (FLECTURE-01) : dix minutes après le dernier toucher, la veille du téléphone reprend ; le
    /// réglage « Garder l'écran allumé pendant la lecture », allumé d'origine, le coupe, même entre deux touchers.
    @Test func laVeilleDeLectureDureDixMinutesApresLeDernierToucher() async throws {
        let magasin = Magasin.enMemoire()
        let veille = VeilleLecture(magasin: magasin)
        #expect(veille.permise)
        #expect(VeilleLecture.delai == 600_000)
        #expect(!veille.allume(1_000))
        #expect(veille.toucher(1_000) == 601_000)
        #expect(veille.allume(600_999))
        #expect(!veille.allume(601_000))
        // Un toucher repousse l'échéance.
        veille.toucher(300_000)
        #expect(veille.allume(899_999))
        // L'écran quitté : plus rien.
        veille.arreter()
        #expect(veille.jusqua == nil)
        #expect(!veille.allume(300_001))
        // Le réglage coupé : rien à garder, ni au toucher, ni pour une échéance déjà posée.
        veille.toucher(0)
        try await magasin.modifierReglages { $0.setLectureEcranAllume(false) }
        #expect(!veille.permise)
        #expect(!veille.allume(1))
        #expect(veille.toucher(2) == nil)
        #expect(!veille.allume(3))
    }

    /// Les quatre écrans de lecture d'Android ont la veille (le lecteur, les Tehilim et le Tikoun par leur barre, une
    /// entrée de la bibliothèque), sur le même réglage.
    @Test func lesQuatreEcransDeLectureOntLaVeille() async throws {
        var reglages = Reglages()
        reglages.setLectureEcranAllume(false)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let lecteur = LectureModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                    horloge: HorlogeFixe(maintenant: 0), langue: "fr", cible: .siddour("chaharit"))
        let tehilim = TehilimBarreLecture(magasin: magasin, langue: "fr")
        let entree = BibliothequeEntreeModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                              langue: "fr", id: "src-lm2-25")
        for veille in [lecteur.veille, tehilim.veille, entree.veille] {
            #expect(!veille.permise)
            #expect(veille.toucher(0) == nil)
        }
        try await magasin.modifierReglages { $0.setLectureEcranAllume(true) }
        for veille in [lecteur.veille, tehilim.veille, entree.veille] {
            #expect(veille.toucher(0) == VeilleLecture.delai)
        }
    }
}
