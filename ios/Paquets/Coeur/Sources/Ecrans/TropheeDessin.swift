import Foundation
import Coeur

// L'objet d'un trophée (TropheeDessin.kt, 12/10) : coupe, écusson, étoile, rosette, médaille, pièces,
// cristal, gemme ou harpe, dessiné d'après trophees_formes.json (tools/trophees_formes.py, le même fichier que
// la version web). Chaque partie a sa matière : métal (dégradé), métal bombé (radial), métal sombre, verre,
// verre clair, ruban, reflet. Sans métal, l'objet est gris.
//
// Ici, tout ce que TropheeDessin.draw décide, en valeurs : les chemins lus (TropheeChemin), la peinture de
// chaque partie, l'emblème (l'icône de la famille au trait, ou l'étoile « ★ » du grade) et ses couleurs. La vue
// n'a plus qu'à peindre : un carré de côté `cote`, la boîte de 100 mise à l'échelle `cote / 100`, chaque
// partie remplie (règle non nulle, celle d'Android et de SwiftUI par défaut), puis l'emblème.

/// Une couleur sRVB, composantes de 0 à 255 (`Color.argb` d'Android).
public struct TropheeCouleur: Sendable, Hashable {
    public var rouge: UInt8
    public var vert: UInt8
    public var bleu: UInt8
    /// L'opacité, de 0 (transparent) à 255 (opaque).
    public var alpha: UInt8

    public init(_ rouge: UInt8, _ vert: UInt8, _ bleu: UInt8, alpha: UInt8 = 0xFF) {
        self.rouge = rouge
        self.vert = vert
        self.bleu = bleu
        self.alpha = alpha
    }

    /// La même couleur à une autre opacité (`ColorUtils.setAlphaComponent`).
    public func opacite(_ alpha: UInt8) -> TropheeCouleur {
        TropheeCouleur(rouge, vert, bleu, alpha: alpha)
    }

    public static let blanc = TropheeCouleur(0xFF, 0xFF, 0xFF)
}

/// Les trois tons d'un métal (TropheeDessin.teintes) : clair (la face), foncé (le bord), sombre (la tranche,
/// le socle, l'emblème). Gris sans métal.
public struct TropheeTeintes: Sendable, Hashable {
    public let clair: TropheeCouleur
    public let fonce: TropheeCouleur
    public let sombre: TropheeCouleur

    public init(clair: TropheeCouleur, fonce: TropheeCouleur, sombre: TropheeCouleur) {
        self.clair = clair
        self.fonce = fonce
        self.sombre = sombre
    }

    /// Les tons d'un métal ; nil : le gris d'un trophée à venir.
    public static func de(_ metal: Trophees.Metal?) -> TropheeTeintes {
        switch metal {
        case .bronze:
            TropheeTeintes(clair: TropheeCouleur(0xF3, 0xC4, 0x9A), fonce: TropheeCouleur(0xA0, 0x60, 0x2E),
                           sombre: TropheeCouleur(0x6E, 0x3E, 0x1C))
        case .argent:
            TropheeTeintes(clair: TropheeCouleur(0xF4, 0xF6, 0xF8), fonce: TropheeCouleur(0x9A, 0xA3, 0xAC),
                           sombre: TropheeCouleur(0x5E, 0x67, 0x70))
        case .or:
            TropheeTeintes(clair: TropheeCouleur(0xFF, 0xE4, 0x8A), fonce: TropheeCouleur(0xC9, 0x96, 0x1A),
                           sombre: TropheeCouleur(0x8A, 0x62, 0x06))
        case .platine:
            TropheeTeintes(clair: TropheeCouleur(0xF7, 0xFA, 0xFF), fonce: TropheeCouleur(0x8C, 0xA2, 0xC4),
                           sombre: TropheeCouleur(0x55, 0x68, 0x8A))
        case nil:
            TropheeTeintes(clair: TropheeCouleur(0xE3, 0xE5, 0xE7), fonce: TropheeCouleur(0xB6, 0xBA, 0xBE),
                           sombre: TropheeCouleur(0x8E, 0x93, 0x98))
        }
    }
}

/// La matière d'une partie, sous sa clé de trophees_formes.json (`_meta.matieres`).
public enum TropheeMatiere: String, Sendable, Hashable, CaseIterable {
    case metal = "m"
    case metalBombe = "mr"
    case metalSombre = "md"
    case verre = "v"
    case verreClair = "vc"
    case ruban = "r"
    case reflet = "w"

    /// Une clé inconnue se peint en reflet, comme la branche `else` d'Android.
    public init(cle: String) {
        self = TropheeMatiere(rawValue: cle) ?? .reflet
    }

    /// La peinture de la matière pour ce métal (nil : gris).
    public func peinture(_ metal: Trophees.Metal?) -> TropheePeinture {
        let t = TropheeTeintes.de(metal)
        switch self {
        case .metal:
            return .diagonale(de: t.clair, a: t.fonce)
        case .metalBombe:
            return .bombee(couleurs: [TropheeCouleur.blanc, t.clair, t.fonce], arrets: [0, 0.35, 1],
                           centre: TropheePoint(35, 30), rayon: 75)
        case .metalSombre:
            return .unie(t.sombre)
        case .verre:
            return .unie(TropheeCouleur(0xAA, 0xD7, 0xFF, alpha: 0xBF))
        case .verreClair:
            return .unie(TropheeCouleur(0xEB, 0xF7, 0xFF, alpha: 0xE6))
        case .ruban:
            return .unie(metal != nil ? TropheeCouleur(0xD4, 0x3B, 0x3B) : TropheeCouleur(0xB9, 0xBD, 0xC1))
        case .reflet:
            return .unie(TropheeCouleur(0xFF, 0xFF, 0xFF, alpha: 0x80))
        }
    }
}

/// Comment remplir une partie, dans la boîte de 100.
public enum TropheePeinture: Sendable, Hashable {
    /// Un dégradé linéaire de (0, 0) à (100, 100) : `LinearGradient` d'Android, étiré (CLAMP) au-delà.
    case diagonale(de: TropheeCouleur, a: TropheeCouleur)
    /// Un dégradé radial (`RadialGradient`) : les couleurs aux arrêts (de 0 à 1), du centre au rayon.
    case bombee(couleurs: [TropheeCouleur], arrets: [Double], centre: TropheePoint, rayon: Double)
    case unie(TropheeCouleur)
}

/// Où l'emblème se pose dans la boîte de 100 : son centre et sa taille (`embleme` du fichier).
public struct TropheeEmbleme: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let taille: Double

    public init(x: Double, y: Double, taille: Double) {
        self.x = x
        self.y = y
        self.taille = taille
    }
}

/// Une partie d'une forme : sa matière, son chemin.
public struct TropheePartie: Sendable, Hashable {
    public let matiere: TropheeMatiere
    public let chemin: TropheeChemin

    public init(matiere: TropheeMatiere, chemin: TropheeChemin) {
        self.matiere = matiere
        self.chemin = chemin
    }
}

/// Une forme lue : ses parties dans l'ordre où elles se peignent, et son emblème.
public struct TropheeForme: Sendable, Hashable {
    public let parties: [TropheePartie]
    public let embleme: TropheeEmbleme

    public init(parties: [TropheePartie], embleme: TropheeEmbleme) {
        self.parties = parties
        self.embleme = embleme
    }
}

/// Ce qui empêche de lire trophees_formes.json.
public enum TropheeFormesErreur: Error, Sendable, Hashable {
    /// Le chemin d'une partie (« coupe[3] ») ou d'une icône (« icone serie ») ne se lit pas.
    case chemin(ou: String, erreur: TropheeCheminErreur)
    /// Une forme dont l'emblème n'a pas trois nombres, ou une partie qui n'est pas [matière, chemin].
    case malFormee(String)
}

/// Les formes et les icônes de trophees_formes.json, lues une fois (TropheeDessin.formes et .icones, que
/// Android garde en cache) : l'app les lit au lancement et les passe à toutes les vues qui dessinent un trophée.
public struct TropheeFormes: Sendable, Hashable {
    /// Le chemin du fichier dans les contenus exportés (`res/raw/trophees_formes.json` d'Android).
    public static let fichier = "trophees_formes.json"
    /// Le côté de la boîte des formes.
    public static let boite = 100.0
    /// Le côté de la boîte des icônes.
    public static let boiteIcone = 24.0

    /// Les formes, par clé (`Trophees.Forme.cle`).
    public let formes: [String: TropheeForme]
    /// Les icônes au trait, par clé (`Trophees.Famille.icone`).
    public let icones: [String: TropheeChemin]

    public init(formes: [String: TropheeForme], icones: [String: TropheeChemin]) {
        self.formes = formes
        self.icones = icones
    }

    /// Lit le fichier exporté par le lecteur des contenus (`ContenusApp.lecteur(dossier:)` dans l'app).
    public static func lire(_ lecteur: ContenusApp.Lecteur) throws -> TropheeFormes {
        guard let donnees = try lecteur(fichier) else { throw ErreurContenu.absent(fichier) }
        return try lire(donnees)
    }

    /// Lit les octets de trophees_formes.json ; chaque chemin passe par l'analyseur, et la première erreur se
    /// rend en nommant la forme ou l'icône.
    public static func lire(_ donnees: Data) throws -> TropheeFormes {
        let brut = try JSONDecoder().decode(Fichier.self, from: donnees)
        var formes: [String: TropheeForme] = [:]
        for (cle, forme) in brut.formes {
            guard forme.embleme.count == 3 else { throw TropheeFormesErreur.malFormee(cle) }
            var parties: [TropheePartie] = []
            for (i, partie) in forme.parts.enumerated() {
                guard partie.count == 2 else { throw TropheeFormesErreur.malFormee("\(cle)[\(i)]") }
                do {
                    let chemin = try TropheeChemin(partie[1])
                    parties.append(TropheePartie(matiere: TropheeMatiere(cle: partie[0]), chemin: chemin))
                } catch let erreur as TropheeCheminErreur {
                    throw TropheeFormesErreur.chemin(ou: "\(cle)[\(i)]", erreur: erreur)
                }
            }
            let e = forme.embleme
            formes[cle] = TropheeForme(parties: parties, embleme: TropheeEmbleme(x: e[0], y: e[1], taille: e[2]))
        }
        var icones: [String: TropheeChemin] = [:]
        for (cle, trace) in brut.icones {
            do {
                icones[cle] = try TropheeChemin(trace)
            } catch let erreur as TropheeCheminErreur {
                throw TropheeFormesErreur.chemin(ou: "icone \(cle)", erreur: erreur)
            }
        }
        return TropheeFormes(formes: formes, icones: icones)
    }

    public func forme(_ f: Trophees.Forme) -> TropheeForme? {
        formes[f.cle]
    }

    /// Ce que la vue peint pour un objet : la forme, du métal donné (nil : gris), avec l'icône `icone` (la clé
    /// d'une icône au trait, ou un caractère comme « ★ »). nil si la forme manque au fichier.
    public func dessin(_ f: Trophees.Forme, metal: Trophees.Metal?, icone: String) -> TropheeDessin? {
        guard let lue = formes[f.cle] else { return nil }
        return TropheeDessin(forme: f, metal: metal, lue: lue, icone: icone, trace: icones[icone])
    }

    /// L'objet d'un niveau : la forme et l'icône de sa famille.
    public func dessin(_ niveau: Trophees.Niveau, metal: Trophees.Metal?) -> TropheeDessin? {
        dessin(niveau.famille.forme, metal: metal, icone: niveau.famille.icone)
    }

    /// La médaille d'un grade, frappée de l'étoile (PaliersActivity.medaille) ; nil : grise.
    public func medaille(_ grade: Trophees.Metal?) -> TropheeDessin? {
        dessin(.medaille, metal: grade, icone: TropheeDessin.etoile)
    }

    /// Ce que le fichier écrit ; `_meta` est ignoré.
    private struct Fichier: Decodable {
        struct Forme: Decodable {
            let embleme: [Double]
            let parts: [[String]]
        }
        let formes: [String: Forme]
        let icones: [String: String]
    }
}

/// L'emblème posé sur l'objet.
public enum TropheeEmblemeDessin: Sendable, Hashable {
    /// L'icône de la famille, au trait (boîte de 24, bouts et angles ronds), centrée en `centre`, de côté
    /// `taille` dans la boîte de 100 ; l'épaisseur se calcule par `TropheeDessin.epaisseurIcone(cote:)`.
    case trait(chemin: TropheeChemin, centre: TropheePoint, taille: Double, couleur: TropheeCouleur)
    /// Un caractère (« ★ »), centré en `centre` (horizontalement, et la hauteur de ses lettres centrée sur
    /// y), en corps `taille` dans la boîte de 100, dans la police par défaut (maigre).
    case texte(String, centre: TropheePoint, taille: Double, couleur: TropheeCouleur)
}

/// Une partie à peindre : son chemin et sa peinture.
public struct TropheeTrace: Sendable, Hashable {
    public let peinture: TropheePeinture
    public let chemin: TropheeChemin

    public init(peinture: TropheePeinture, chemin: TropheeChemin) {
        self.peinture = peinture
        self.chemin = chemin
    }
}

/// Un objet à peindre : TropheeDessin.draw en valeurs.
public struct TropheeDessin: Sendable, Hashable {
    /// L'étoile des médailles de grade.
    public static let etoile = "\u{2605}"

    public let forme: Trophees.Forme
    /// nil : gris.
    public let metal: Trophees.Metal?
    /// Dans l'ordre où elles se peignent, chacune avec sa peinture.
    public let parties: [TropheeTrace]
    public let embleme: TropheeEmblemeDessin

    init(forme: Trophees.Forme, metal: Trophees.Metal?, lue: TropheeForme, icone: String, trace: TropheeChemin?) {
        self.forme = forme
        self.metal = metal
        parties = lue.parties.map { TropheeTrace(peinture: $0.matiere.peinture(metal), chemin: $0.chemin) }
        let teintes = TropheeTeintes.de(metal)
        let e = lue.embleme
        if let trace {
            // L'icône au trait, du ton sombre du métal (16/10) ; estompée sans métal. Emblème d'au moins 20 %
            // (audit du 16/10).
            embleme = .trait(chemin: trace, centre: TropheePoint(e.x, e.y), taille: max(e.taille * 1.15, 20),
                             couleur: teintes.sombre.opacite(metal != nil ? 0xFF : 0xB3))
        } else {
            // L'étoile du grade prend le ton sombre du métal (04/11).
            embleme = .texte(icone, centre: TropheePoint(e.x, e.y), taille: e.taille,
                             couleur: teintes.sombre.opacite(metal != nil ? 0xFF : 0x73))
        }
    }

    /// L'épaisseur du trait de l'icône, en unités de sa boîte de 24, pour un objet peint sur `cote` points :
    /// au moins 2, et au moins 1,3 point à l'écran (audit du 16/10 : lisible en liste). Un point d'iOS vaut un
    /// dp d'Android. 0 pour un emblème en texte.
    public func epaisseurIcone(cote: Double) -> Double {
        guard case .trait(_, _, let taille, _) = embleme, cote > 0 else { return 0 }
        return max(2, 1.3 / ((cote / TropheeFormes.boite) * (taille / TropheeFormes.boiteIcone)))
    }
}
