import Foundation

/// Les grands écrans (tâche 29 : l'iPad, le téléphone couché), comme Android les traite : par la largeur disponible
/// (values-w600dp, values-w840dp, values-w1200dp, la règle de values/dimens.xml), le contenu des écrans s'écarte des
/// bords au lieu de s'étaler ; couché et assez large, le Jour met ses anneaux à côté de son en-tête
/// (layout-land/activity_main.xml).
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

    /// Le Jour en deux colonnes (les anneaux à côté de l'en-tête) : couché, téléphone ou tablette, comme
    /// layout-land/activity_main.xml, qu'Android choisit par l'orientation seule.
    public static func deuxColonnes(largeur: Double, hauteur: Double) -> Bool {
        largeur > hauteur
    }
}
