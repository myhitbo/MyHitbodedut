import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'analyseur des chemins de trophees_formes.json (PathParser d'androidx, tel que TropheeDessin.kt s'en sert)
/// et les objets qu'on en peint. Critère de la tâche 20 : les 9 formes et les 11 icônes se lisent sans erreur.
@Suite("Chemins et objets des trophées")
@MainActor
struct TropheeCheminTests {

    // MARK: Aides

    private static func proche(_ a: Double, _ b: Double, _ ecart: Double = 1e-9) -> Bool {
        abs(a - b) <= ecart
    }

    private static func proche(_ a: TropheePoint, _ b: TropheePoint, _ ecart: Double = 1e-9) -> Bool {
        proche(a.x, b.x, ecart) && proche(a.y, b.y, ecart)
    }

    /// Deux listes de commandes égales, à `ecart` près sur chaque coordonnée.
    private static func egales(_ a: [TropheeCommande], _ b: [TropheeCommande], _ ecart: Double = 1e-9) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) {
            switch (x, y) {
            case (.deplacer(let p), .deplacer(let q)), (.ligne(let p), .ligne(let q)):
                if !proche(p, q, ecart) { return false }
            case (.quadratique(let c, let f), .quadratique(let d, let g)):
                if !proche(c, d, ecart) || !proche(f, g, ecart) { return false }
            case (.cubique(let c1, let c2, let f), .cubique(let d1, let d2, let g)):
                if !proche(c1, d1, ecart) || !proche(c2, d2, ecart) || !proche(f, g, ecart) { return false }
            case (.fermer, .fermer):
                continue
            default:
                return false
            }
        }
        return true
    }

    private static func distance(_ p: TropheePoint, _ centre: TropheePoint) -> Double {
        ((p.x - centre.x) * (p.x - centre.x) + (p.y - centre.y) * (p.y - centre.y)).squareRoot()
    }

    /// Les fins des cubiques d'un chemin.
    private static func finsDesCubiques(_ commandes: [TropheeCommande]) -> [TropheePoint] {
        var fins: [TropheePoint] = []
        for c in commandes {
            if case .cubique(_, _, let fin) = c { fins.append(fin) }
        }
        return fins
    }

    private static func formes() throws -> TropheeFormes {
        try TropheeFormes.lire(ContenusApp.lecteur(dossier: Fichiers.contenu))
    }

    private static func p(_ x: Double, _ y: Double) -> TropheePoint {
        TropheePoint(x, y)
    }

    // MARK: Le fichier

    @Test func lesNeufFormesEtLesOnzeIconesSeLisentSansErreur() throws {
        let lues = try Self.formes()
        let nombreFormes = lues.formes.count
        #expect(nombreFormes == 9)
        let nombreIcones = lues.icones.count
        #expect(nombreIcones == 11)
        // Le nombre de parties de chaque forme, tel que le fichier les écrit.
        let parties: [Trophees.Forme: Int] = [.coupe: 8, .ecusson: 5, .etoile: 18, .rosette: 6, .medaille: 6,
                                              .pieces: 12, .cristal: 3, .kinor: 11, .gemme: 6]
        for f in Trophees.Forme.allCases {
            let forme = try #require(lues.forme(f), "forme \(f.cle) absente")
            #expect(forme.parties.count == parties[f], "\(f.cle)")
            for (i, partie) in forme.parties.enumerated() {
                var commenceParDeplacer = false
                if let premiere = partie.chemin.commandes.first, case .deplacer = premiere { commenceParDeplacer = true }
                #expect(commenceParDeplacer, "\(f.cle)[\(i)]")
                // Tout se tient dans la boîte de 100.
                let boite = try #require(partie.chemin.boite)
                #expect(boite.min.x >= 0 && boite.min.y >= 0, "\(f.cle)[\(i)]")
                #expect(boite.max.x <= TropheeFormes.boite && boite.max.y <= TropheeFormes.boite, "\(f.cle)[\(i)]")
            }
        }
        for famille in Trophees.Famille.allCases {
            let icone = try #require(lues.icones[famille.icone], "icône \(famille.icone) absente")
            let boite = try #require(icone.boite)
            #expect(boite.min.x >= 0 && boite.min.y >= 0, "\(famille.icone)")
            #expect(boite.max.x <= TropheeFormes.boiteIcone && boite.max.y <= TropheeFormes.boiteIcone, "\(famille.icone)")
        }
    }

    @Test func lesEmblemesEtLesMatieresSontCeuxDuFichier() throws {
        let lues = try Self.formes()
        let coupe = try #require(lues.forme(.coupe))
        #expect(coupe.embleme == TropheeEmbleme(x: 50, y: 34, taille: 20))
        let pieces = try #require(lues.forme(.pieces))
        #expect(pieces.embleme == TropheeEmbleme(x: 70, y: 30, taille: 12))
        let matieresCoupe = coupe.parties.map { $0.matiere }
        #expect(matieresCoupe == [.metalSombre, .metalSombre, .metal, .metalSombre, .metal, .metalSombre, .metalBombe,
                                  .reflet])
        let cristal = try #require(lues.forme(.cristal))
        let matieresCristal = cristal.parties.map { $0.matiere }
        #expect(matieresCristal == [.verre, .verreClair, .reflet])
        // Chaque matière écrite est une matière connue (aucune ne retombe sur le reflet par défaut).
        struct Brut: Decodable {
            struct Forme: Decodable { let parts: [[String]] }
            let formes: [String: Forme]
        }
        let brut = try JSONDecoder().decode(Brut.self, from: Fichiers.donnees("ios/Ressources/Contenu/trophees_formes.json"))
        for (cle, forme) in brut.formes {
            for partie in forme.parts {
                let matiere = try #require(partie.first)
                let connue = TropheeMatiere(rawValue: matiere) != nil
                #expect(connue, "\(cle) : matière « \(matiere) »")
            }
        }
    }

    // MARK: Les commandes

    @Test func lesCommandesRelativesEtLesCourbesLisseesSuiventAndroid() throws {
        // Le premier pied de l'icône « premier_pas » : c relatif, s qui reflète c, S qui reflète s, puis S encore.
        let lu = try TropheeChemin("M8 4.5c1.7 0 2.5 1.8 2.5 4s-.8 4.5-2.5 4.5S5.5 10.7 5.5 8.5 6.3 4.5 8 4.5z")
        let attendu: [TropheeCommande] = [
            .deplacer(Self.p(8, 4.5)),
            .cubique(controle1: Self.p(9.7, 4.5), controle2: Self.p(10.5, 6.3), fin: Self.p(10.5, 8.5)),
            .cubique(controle1: Self.p(10.5, 10.7), controle2: Self.p(9.7, 13), fin: Self.p(8, 13)),
            .cubique(controle1: Self.p(6.3, 13), controle2: Self.p(5.5, 10.7), fin: Self.p(5.5, 8.5)),
            .cubique(controle1: Self.p(5.5, 6.3), controle2: Self.p(6.3, 4.5), fin: Self.p(8, 4.5)),
            .fermer,
            .deplacer(Self.p(8, 4.5)),
        ]
        let egal = Self.egales(lu.commandes, attendu)
        #expect(egal, "\(lu.commandes)")
    }

    @Test func lesDroitesHorizontalesVerticalesEtLesDeplacementsImplicites() throws {
        let lu = try TropheeChemin("m1 1 2 2H6v-2h-1V0zl1 0")
        let attendu: [TropheeCommande] = [
            .deplacer(Self.p(1, 1)), .ligne(Self.p(3, 3)), .ligne(Self.p(6, 3)), .ligne(Self.p(6, 1)),
            .ligne(Self.p(5, 1)), .ligne(Self.p(5, 0)), .fermer, .deplacer(Self.p(1, 1)), .ligne(Self.p(2, 1)),
        ]
        let egal = Self.egales(lu.commandes, attendu)
        #expect(egal, "\(lu.commandes)")
    }

    @Test func lesNombresSeDecoupentCommeSurAndroid() throws {
        // Un second point, un « - », un exposant (dont le « - » ne sépare pas), des virgules.
        let lu = try TropheeChemin("M1.5.5L-2-3,4e1-1e-1")
        let attendu: [TropheeCommande] = [
            .deplacer(Self.p(1.5, 0.5)), .ligne(Self.p(-2, -3)), .ligne(Self.p(40, -0.1)),
        ]
        let egal = Self.egales(lu.commandes, attendu)
        #expect(egal, "\(lu.commandes)")
    }

    @Test func lesQuadratiquesEtLeurReflet() throws {
        let lu = try TropheeChemin("M0 0Q1 1 2 0T4 0t2 0")
        let attendu: [TropheeCommande] = [
            .deplacer(Self.p(0, 0)),
            .quadratique(controle: Self.p(1, 1), fin: Self.p(2, 0)),
            .quadratique(controle: Self.p(3, -1), fin: Self.p(4, 0)),
            .quadratique(controle: Self.p(5, 1), fin: Self.p(6, 0)),
        ]
        let egal = Self.egales(lu.commandes, attendu)
        #expect(egal, "\(lu.commandes)")
        // Sans courbe avant, S et T prennent le point courant pour contrôle.
        let sansReflet = try TropheeChemin("M0 0L2 0S3 1 4 0T6 0")
        let attenduSans: [TropheeCommande] = [
            .deplacer(Self.p(0, 0)), .ligne(Self.p(2, 0)),
            .cubique(controle1: Self.p(2, 0), controle2: Self.p(3, 1), fin: Self.p(4, 0)),
            .quadratique(controle: Self.p(4, 0), fin: Self.p(6, 0)),
        ]
        let egalSans = Self.egales(sansReflet.commandes, attenduSans)
        #expect(egalSans, "\(sansReflet.commandes)")
    }

    // MARK: Les arcs

    @Test func unDemiCercleDevientDesCubiquesSurLeCercle() throws {
        // Le talon de l'icône « premier_pas » : un demi-cercle de rayon 1,5, de (9,5 ; 17,5) à (6,5 ; 17,5), par le bas.
        let lu = try TropheeChemin("M6.5 15.5h3v2a1.5 1.5 0 0 1-3 0z")
        let c = lu.commandes
        let debut = Self.egales(Array(c.prefix(3)), [.deplacer(Self.p(6.5, 15.5)), .ligne(Self.p(9.5, 15.5)),
                                                     .ligne(Self.p(9.5, 17.5))])
        #expect(debut)
        let fins = Self.finsDesCubiques(c)
        #expect(fins.count >= 2)
        let centre = Self.p(8, 17.5)
        for fin in fins {
            let d = Self.distance(fin, centre)
            #expect(Self.proche(d, 1.5, 1e-6), "\(fin)")
            #expect(fin.y >= 17.5 - 1e-6, "\(fin) au-dessus du diamètre")
        }
        let derniere = try #require(fins.last)
        #expect(Self.proche(derniere, Self.p(6.5, 17.5), 1e-6))
        let bas = fins.contains { Self.proche($0, Self.p(8, 19), 1e-6) }
        #expect(bas)
        // Le milieu de chaque cubique reste sur le cercle (un quart de cercle bien approché).
        var avant = Self.p(9.5, 17.5)
        for commande in c {
            guard case .cubique(let c1, let c2, let fin) = commande else { continue }
            let mx = (avant.x + 3 * c1.x + 3 * c2.x + fin.x) / 8
            let my = (avant.y + 3 * c1.y + 3 * c2.y + fin.y) / 8
            let d = Self.distance(Self.p(mx, my), centre)
            #expect(Self.proche(d, 1.5, 1e-3), "milieu \(mx), \(my)")
            avant = fin
        }
        let fin = c.suffix(2).map { $0 }
        let ferme = Self.egales(fin, [.fermer, .deplacer(Self.p(6.5, 15.5))])
        #expect(ferme)
    }

    @Test func deuxArcsFontLeCercleDeLaSeanceLongue() throws {
        let lu = try TropheeChemin("M4 13a8 8 0 1 0 16 0a8 8 0 1 0-16 0z")
        let fins = Self.finsDesCubiques(lu.commandes)
        let centre = Self.p(12, 13)
        for fin in fins {
            let d = Self.distance(fin, centre)
            #expect(Self.proche(d, 8, 1e-6), "\(fin)")
        }
        // Le premier arc passe par le bas, le second par le haut.
        let bas = fins.contains { Self.proche($0, Self.p(12, 21), 1e-6) }
        let droite = fins.contains { Self.proche($0, Self.p(20, 13), 1e-6) }
        let haut = fins.contains { Self.proche($0, Self.p(12, 5), 1e-6) }
        #expect(bas && droite && haut)
        let derniere = try #require(fins.last)
        #expect(Self.proche(derniere, Self.p(4, 13), 1e-6))
    }

    @Test func unRayonTropPetitGranditEtUnRayonNulFaitUneDroite() throws {
        let lu = try TropheeChemin("M0 0A1 1 0 0 1 10 0")
        let fins = Self.finsDesCubiques(lu.commandes)
        #expect(!fins.isEmpty)
        for fin in fins {
            // Le rayon grandit juste assez (÷ 1,99999) : le centre s'écarte à peine de (5, 0).
            let d = Self.distance(fin, Self.p(5, 0))
            #expect(Self.proche(d, 5, 0.02), "\(fin)")
        }
        let derniere = try #require(fins.last)
        #expect(Self.proche(derniere, Self.p(10, 0), 1e-3))
        let nul = try TropheeChemin("M0 0a0 3 0 0 1 4 0")
        let egal = Self.egales(nul.commandes, [.deplacer(Self.p(0, 0)), .ligne(Self.p(4, 0))])
        #expect(egal)
    }

    // MARK: Les erreurs

    @Test func cequiNeSeLitPasLeve() {
        #expect(throws: TropheeCheminErreur.vide) { try TropheeChemin("  ") }
        #expect(throws: TropheeCheminErreur.commandeInconnue("X")) { try TropheeChemin("X1 2") }
        #expect(throws: TropheeCheminErreur.commandeInconnue("1")) { try TropheeChemin("1 2 L3 4") }
        #expect(throws: TropheeCheminErreur.nombresIncomplets(commande: "L", nombres: 1)) { try TropheeChemin("M1 2L3") }
        #expect(throws: TropheeCheminErreur.nombresIncomplets(commande: "M", nombres: 0)) { try TropheeChemin("M") }
        #expect(throws: TropheeCheminErreur.nombreIllisible("-")) { try TropheeChemin("M1-") }
    }

    @Test func uneFormeIllisibleSeNomme() {
        let json = #"{"formes":{"coupe":{"embleme":[50,34,20],"parts":[["m","M0 0L"]]}},"icones":{}}"#
        #expect(throws: TropheeFormesErreur.chemin(ou: "coupe[0]",
                                                  erreur: .nombresIncomplets(commande: "L", nombres: 0))) {
            try TropheeFormes.lire(Data(json.utf8))
        }
        let sansEmbleme = #"{"formes":{"coupe":{"embleme":[50],"parts":[]}},"icones":{}}"#
        #expect(throws: TropheeFormesErreur.malFormee("coupe")) { try TropheeFormes.lire(Data(sansEmbleme.utf8)) }
        #expect(throws: ErreurContenu.absent(TropheeFormes.fichier)) {
            try TropheeFormes.lire { _ in nil }
        }
    }

    // MARK: Les objets peints

    @Test func lesNeufFormesSePeignentDansLesCinqMetaux() throws {
        let lues = try Self.formes()
        let metaux: [Trophees.Metal?] = [nil, .bronze, .argent, .or, .platine]
        for f in Trophees.Forme.allCases {
            for m in metaux {
                let dessin = try #require(lues.dessin(f, metal: m, icone: "jours"), "\(f.cle) \(String(describing: m))")
                let forme = try #require(lues.forme(f))
                #expect(dessin.parties.count == forme.parties.count)
            }
        }
        // Cinq teintes distinctes : quatre métaux et le gris.
        let claires = Set(metaux.map { TropheeTeintes.de($0).clair })
        #expect(claires.count == 5)
    }

    @Test func lesMatieresPrennentLesTeintesDuMetal() {
        let teintesOr = TropheeTeintes.de(.or)
        #expect(teintesOr == TropheeTeintes(clair: TropheeCouleur(0xFF, 0xE4, 0x8A), fonce: TropheeCouleur(0xC9, 0x96, 0x1A),
                                     sombre: TropheeCouleur(0x8A, 0x62, 0x06)))
        #expect(TropheeMatiere.metal.peinture(.or) == .diagonale(de: teintesOr.clair, a: teintesOr.fonce))
        #expect(TropheeMatiere.metalSombre.peinture(.or) == .unie(teintesOr.sombre))
        #expect(TropheeMatiere.metalBombe.peinture(.or) == .bombee(couleurs: [.blanc, teintesOr.clair, teintesOr.fonce],
                                                                  arrets: [0, 0.35, 1], centre: TropheePoint(35, 30),
                                                                  rayon: 75))
        // Le ruban est rouge sur un objet de métal, gris sur un objet à venir.
        #expect(TropheeMatiere.ruban.peinture(.bronze) == .unie(TropheeCouleur(0xD4, 0x3B, 0x3B)))
        #expect(TropheeMatiere.ruban.peinture(nil) == .unie(TropheeCouleur(0xB9, 0xBD, 0xC1)))
        #expect(TropheeMatiere.verre.peinture(nil) == .unie(TropheeCouleur(0xAA, 0xD7, 0xFF, alpha: 0xBF)))
        #expect(TropheeMatiere(cle: "inconnue") == .reflet)
    }

    @Test func lEmblemeEstLIconeAuTraitOuLEtoileDuGrade() throws {
        let lues = try Self.formes()
        // L'icône de la famille, au trait : au moins 20 % de la boîte, du ton sombre, estompée sans métal.
        let gris = try #require(lues.dessin(.medaille, metal: nil, icone: "jours"))
        let icone = try #require(lues.icones["jours"])
        let sombreGris = TropheeTeintes.de(nil).sombre
        #expect(gris.embleme == .trait(chemin: icone, centre: TropheePoint(50, 62), taille: 23,
                                       couleur: sombreGris.opacite(0xB3)))
        let pieces = try #require(lues.dessin(.pieces, metal: .or, icone: "heures"))
        let iconeHeures = try #require(lues.icones["heures"])
        #expect(pieces.embleme == .trait(chemin: iconeHeures, centre: TropheePoint(70, 30), taille: 20,
                                         couleur: TropheeTeintes.de(.or).sombre))
        // Le trait : au moins 2 sur 24, et au moins 1,3 point à l'écran.
        let epaisseurListe = gris.epaisseurIcone(cote: 30)
        #expect(Self.proche(epaisseurListe, 1.3 / (0.3 * (23.0 / 24.0))))
        #expect(gris.epaisseurIcone(cote: 120) == 2)
        // La médaille du grade porte l'étoile.
        let medaille = try #require(lues.medaille(.argent))
        #expect(medaille.embleme == .texte(TropheeDessin.etoile, centre: TropheePoint(50, 62), taille: 20,
                                           couleur: TropheeTeintes.de(.argent).sombre))
        #expect(medaille.epaisseurIcone(cote: 48) == 0)
        let medailleGrise = try #require(lues.medaille(nil))
        #expect(medailleGrise.embleme == .texte(TropheeDessin.etoile, centre: TropheePoint(50, 62), taille: 20,
                                                couleur: TropheeTeintes.de(nil).sombre.opacite(0x73)))
    }
}
