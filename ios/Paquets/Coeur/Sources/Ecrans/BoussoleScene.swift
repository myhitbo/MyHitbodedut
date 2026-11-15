import Foundation
import Coeur

// Ce que dessine la boussole (BoussoleDessin.kt, BoussoleView.kt), en valeurs : le modèle décide quelle
// scène, ses angles, ses positions et ses textes ; la vue la trace dans un Canvas, sur le carré de 320 unités
// centré sur (0, 0) de la maquette (BoussoleDessin.cadrer), avec les couleurs fixes de la scène.

/// La scène de la boussole, une des trois de BoussoleView.onDraw.
public enum BoussoleScene: Sendable, Hashable {
    /// La rose fixe, le nord en haut (BoussoleDessin.rose) : sans capteur, ou tant qu'aucun cap n'est mesuré.
    case roseFixe(BoussoleRoseFixe)
    /// Le hassid se tourne (design C, par défaut ; BoussoleDessin.ecran).
    case hassid(BoussoleHassid)
    /// La rose des vents vivante, au choix (BoussoleDessin.roseVivante).
    case roseVivante(BoussoleRoseVivante)

    /// « ירושלים », l'étiquette des trois scènes (BoussoleDessin.JERUSALEM), dans toutes les langues.
    public static let jerusalem = "\u{05D9}\u{05E8}\u{05D5}\u{05E9}\u{05DC}\u{05D9}\u{05DD}"

    /// Combien d'unités d'horizon par degré d'écart (BoussoleDessin.PAR_DEGRE, un Float).
    public static let parDegre: Float = 2.2

    /// La position sur l'horizon d'un écart de cap (BoussoleDessin.xHorizon) : 2,2 unités par degré, en
    /// simple précision comme sur Android ; au-delà de ±150 unités, le point reste au bord.
    public static func xHorizon(_ ecart: Double) -> Double {
        Double(min(max(Float(ecart) * parDegre, -150), 150))
    }

    /// Où l'étiquette « ירושלים » se centre : sur le point, mais toujours entière dans le cadre (±124).
    public static func xEtiquette(_ xPoint: Double) -> Double {
        min(max(xPoint, -124), 124)
    }

    /// La scène est-elle face à Jérusalem ? Jamais pour la rose fixe.
    public var face: Bool {
        switch self {
        case .roseFixe: false
        case .hassid(let hassid): hassid.face
        case .roseVivante(let rose): rose.face
        }
    }
}

/// La rose fixe (BoussoleDessin.rose), dans un carré de 112 unités : le nord en haut, un triangle d'or vers
/// la direction principale, le hassid au centre, « N » en haut, les degrés en bas à droite et « ירושלים » en
/// bas à gauche.
public struct BoussoleRoseFixe: Sendable, Hashable {
    /// La direction principale, en degrés depuis le nord vrai : l'angle du triangle d'or.
    public let principale: Double
    /// Les degrés entiers écrits en bas à droite, suivis de « ° » (DirectionJerusalem.degres).
    public let degres: Int

    public init(principale: Double, degres: Int) {
        self.principale = principale
        self.degres = degres
    }
}

/// Le hassid de dos et l'horizon (BoussoleDessin.ecran) : Jérusalem glisse sur l'horizon ; arrivée au-dessus
/// de sa tête, il est face à elle et se hausse un peu.
public struct BoussoleHassid: Sendable, Hashable {
    /// De combien tourner, de -180 (à gauche) à +180 (à droite) : DirectionJerusalem.ecart(principale, cap).
    public let ecart: Double
    /// À ±4° : face à Jérusalem (DirectionJerusalem.face).
    public let face: Bool
    /// Le point de Jérusalem sur l'horizon (y = -90), en unités du carré de 320.
    public let xJerusalem: Double
    /// Le centre de l'étiquette « ירושלים » (de y = -124 à -102), entière dans le cadre.
    public let xEtiquette: Double
    /// Le petit rond pointillé bleu de l'autre direction, sur l'horizon.
    public let xAutre: Double
    /// Le haut de l'image du hassid : -68 face à Jérusalem (il se hausse), -62 sinon.
    public let yHassid: Double
    /// Le texte du haut (y = -132) : « Tournez à droite de 12° », « Face à Jérusalem ».
    public let consigne: Libelle

    public init(ecart: Double, face: Bool, xJerusalem: Double, xEtiquette: Double, xAutre: Double, yHassid: Double,
                consigne: Libelle) {
        self.ecart = ecart
        self.face = face
        self.xJerusalem = xJerusalem
        self.xEtiquette = xEtiquette
        self.xAutre = xAutre
        self.yHassid = yHassid
        self.consigne = consigne
    }
}

/// La rose des vents vivante (BoussoleDessin.roseVivante) : le cadran tourne avec le téléphone, le repère
/// fixe du haut est le cap ; l'aiguille d'or va vers la direction principale, le trait bleu pointillé vers
/// l'autre ; face à Jérusalem, un anneau d'or.
public struct BoussoleRoseVivante: Sendable, Hashable {
    /// Où pointe le haut du téléphone, depuis le nord vrai : le cadran tourne de -cap.
    public let cap: Double
    /// L'aiguille d'or et la zone d'or de ±tolérance, dans le cadran (depuis son nord).
    public let principale: Double
    /// Le trait bleu pointillé, dans le cadran.
    public let autre: Double
    /// Face à Jérusalem : l'anneau d'or, le repère du haut en or, le fond teinté d'or.
    public let face: Bool
    /// La demi-largeur de la zone d'or, en degrés (DirectionJerusalem.TOLERANCE).
    public let tolerance: Double
    /// Le texte du haut (y = -142).
    public let consigne: Libelle

    public init(cap: Double, principale: Double, autre: Double, face: Bool, tolerance: Double, consigne: Libelle) {
        self.cap = cap
        self.principale = principale
        self.autre = autre
        self.face = face
        self.tolerance = tolerance
        self.consigne = consigne
    }
}

/// Les deux tableaux de chaînes de la boussole (`<string-array>` d'Android, exportés dans
/// `ios/Ressources/Chaines/Tableaux.json`) : le catalogue d'iOS n'a pas de tableaux, ni le `Traducteur`.
public struct BoussoleTableaux: Sendable, Hashable {

    /// Un tableau manque ou n'a pas le nombre d'éléments attendu.
    public enum Erreur: Error, Equatable, Sendable {
        case incomplet(String)
    }

    /// Les huit points cardinaux, de N à NO dans le sens des aiguilles (`boussole_points`).
    public let points: [String]
    /// N, E, S, O, les lettres de la rose vivante (`boussole_cardinaux`).
    public let cardinaux: [String]

    /// Des tableaux donnés d'avance, pour un aperçu ; non vérifiés.
    public init(points: [String], cardinaux: [String]) {
        self.points = points
        self.cardinaux = cardinaux
    }

    /// Les tableaux d'une langue, lus dans Tableaux.json (langue → nom → éléments) ; un tableau que la langue
    /// n'a pas se prend du français, comme Android retombe sur `values/strings.xml`. Lève si les octets ne
    /// sont pas ce fichier, ou s'il manque un point ou une lettre.
    public init(donnees: Data, langue: String) throws {
        let tous = try JSONDecoder().decode([String: [String: [String]]].self, from: donnees)
        let ici = tous[langue] ?? [:]
        let repli = tous[Traducteur.repli] ?? [:]
        let points = ici["boussole_points"] ?? repli["boussole_points"] ?? []
        let cardinaux = ici["boussole_cardinaux"] ?? repli["boussole_cardinaux"] ?? []
        guard points.count == 8 else { throw Erreur.incomplet("boussole_points") }
        guard cardinaux.count == 4 else { throw Erreur.incomplet("boussole_cardinaux") }
        self.init(points: points, cardinaux: cardinaux)
    }

    /// Le point cardinal le plus proche d'une direction (`points[DirectionJerusalem.point(d)]`) ; vide pour
    /// des tableaux incomplets.
    public func point(_ direction: Double) -> String {
        let rang = DirectionJerusalem.point(direction)
        return points.indices.contains(rang) ? points[rang] : ""
    }
}
