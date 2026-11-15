import Foundation
import Coeur

/// Les cinq onglets de l'app, dans l'ordre de la barre d'Android (`res/menu/nav_main.xml`).
///
/// Sur Android, Aujourd'hui et Textes changent de panneau sur place ; Zmanim, Journal et Réglages ouvrent leur
/// écran par-dessus. Sur iOS, ce sont cinq onglets réels, chacun avec sa pile de navigation (PORTAGE.md § 1.2).
public enum Onglet: String, Sendable, CaseIterable, Identifiable {
    case aujourdhui, textes, zmanim, journal, reglages

    public var id: String { rawValue }

    /// La clé du titre de l'onglet dans le catalogue : celle d'`android:title` dans nav_main.xml. L'onglet
    /// Réglages y prend `settings_title` (son identifiant Android, `nav_settings`, n'a pas de chaîne).
    public var cle: String {
        switch self {
        case .aujourdhui: "nav_today"
        case .textes: "nav_texts"
        case .zmanim: "nav_zmanim"
        case .journal: "nav_journal"
        case .reglages: "settings_title"
        }
    }

    /// Le symbole SF de l'icône, au trait : la barre d'onglets d'iOS le remplit quand l'onglet est choisi,
    /// comme les icônes d'Android (`ic_nav_*_off` au repos, `ic_nav_*_on` actif).
    public var symbole: String {
        switch self {
        // ic_nav_today : la maison, porte ouverte.
        case .aujourdhui: "house"
        // ic_nav_texts : la couverture d'un livre, la tranche plus claire.
        case .textes: "book.closed"
        // ic_nav_zmanim : l'horloge et ses aiguilles.
        case .zmanim: "clock"
        // ic_nav_journal : le crayon, et la ligne qu'il écrit.
        case .journal: "pencil.line"
        // ic_nav_settings : les curseurs, leurs boutons.
        case .reglages: "slider.horizontal.3"
        }
    }

    /// L'onglet d'un écran d'ouverture (Store.Ouverture). Sur Android, Zmanim s'ouvre par-dessus
    /// Aujourd'hui ; ici, c'est son onglet.
    public init(_ ouverture: Reglages.Ouverture) {
        switch ouverture {
        case .aujourdhui: self = .aujourdhui
        case .textes: self = .textes
        case .zmanim: self = .zmanim
        }
    }

    /// L'onglet choisi au lancement : celui du réglage « ecran_ouverture » (MainActivity.onCreate), Aujourd'hui
    /// par défaut.
    public static func initial(_ reglages: Reglages) -> Onglet {
        Onglet(reglages.ouverture)
    }
}
