import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le défilement automatique des écrans de lecture (ReglagesLecture.kt, 16/11) : le niveau de 1 à 10 gardé sous
/// `lecture_defilement_vitesse`, la vitesse de chaque niveau, le pas de chaque image, l'arrêt au bout et au
/// masquage du bouton, et le même défilement dans le siddour, les Tehilim et le Tikoun.
///
/// Restent au test d'interface : le texte qui défile vraiment (TimelineView, ScrollPosition), le doigt sur le
/// texte qui l'arrête (la phase du ScrollView), l'écran qui reste allumé.
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
    }
}
