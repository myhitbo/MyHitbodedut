import Foundation

/// Les grands écrans (tâche 29 : l'iPad, le téléphone couché), comme Android les traite : par la largeur disponible
/// (values-w600dp, values-w840dp, values-w1200dp, la règle de values/dimens.xml), le contenu des écrans s'écarte des
/// bords au lieu de s'étaler ; couché et assez large, le Jour met ses anneaux à côté de son en-tête
/// (layout-land/activity_main.xml). Au-delà d'Android, qui garde une colonne sur la tablette : quand la place entre
/// les marges en tient deux, l'iPad met côte à côte les deux moitiés de Zmanim, du calendrier, du Chemin, des
/// réglages et de l'accueil Sérénité (`DeuxColonnes`, Vues/GrandEcranVue.swift), et le Jour, debout aussi, ses
/// anneaux à côté de l'en-tête.
public enum GrandEcran {

    /// La marge de téléphone que chaque écran laisse déjà sur ses côtés (« edge » de values-w360dp et values : 16 à
    /// 24 dp ; les vues d'iOS en posent 16).
    public static let margeTelephone: Double = 16

    /// « edge » d'Android pour cette largeur (en points, un dp valant un point).
    public static func bord(largeur: Double) -> Double {
        switch largeur {
        case 1200...: 320
        case 840...: 120
        case 600...: 48
        default: margeTelephone
        }
    }

    /// Ce que la racine ajoute, de chaque côté, aux marges des écrans : « edge » moins la marge de téléphone, soit
    /// « wide_gutter » d'Android (0, 32, 104, 304).
    public static func marge(largeur: Double) -> Double {
        max(bord(largeur: largeur) - margeTelephone, 0)
    }

    /// La place entre les marges d'un écran de cette largeur : sa largeur, « edge » ôté de chaque côté.
    public static func place(largeur: Double) -> Double {
        max(largeur - 2 * bord(largeur: largeur), 0)
    }

    /// La place qu'il faut pour deux colonnes : deux colonnes d'au moins 340 points, la largeur d'un téléphone (370
    /// sur l'iPhone 17 Pro, sa marge ôtée). L'iPad debout en a de 724 (11 pouces) à 792 (13 pouces), couché de 736
    /// (13 pouces) à 940 ; l'iPad mini debout n'en a que 648, l'iPad Pro 11 pouces couché 570 (1 210 points de
    /// large : la marge de values-w1200dp).
    public static let placeDeuxColonnes: Double = 700

    /// Deux colonnes côte à côte dans cette place (`DeuxColonnes`) : assez large, mais jamais aux tailles
    /// d'accessibilité du texte (chaque colonne n'aurait plus que quelques mots par ligne), ni sur un téléphone couché
    /// (`hauteurCompacte`, la classe de hauteur compacte d'iOS), où Android garde une colonne hors du Jour : un
    /// iPhone Pro Max couché a pourtant 736 points de place, mais l'iPhone reste tel quel.
    public static func deuxColonnes(place: Double, texteAccessible: Bool = false, hauteurCompacte: Bool = false) -> Bool {
        !texteAccessible && !hauteurCompacte && place >= placeDeuxColonnes
    }

    /// Le Jour en deux colonnes (les anneaux à côté de l'en-tête) : couché, téléphone ou tablette, comme
    /// layout-land/activity_main.xml, qu'Android choisit par l'orientation seule ; debout, sur un écran qui a la
    /// place de deux colonnes (l'iPad), sauf aux tailles d'accessibilité du texte.
    public static func deuxColonnes(largeur: Double, hauteur: Double, texteAccessible: Bool = false) -> Bool {
        largeur > hauteur || deuxColonnes(place: place(largeur: largeur), texteAccessible: texteAccessible)
    }
}
