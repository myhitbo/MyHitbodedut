import Foundation
import Coeur

/// Les trois onglets de l'app, dans l'ordre de la barre d'Android (`res/menu/nav_main.xml`, refonte du 13/11) :
/// Le Jour, Les Livres, Le Chemin.
///
/// Sur Android, les trois lieux changent de panneau sur place. Zmanim et Réglages ne sont plus des onglets : la
/// date hébraïque et la roue, en tête du Jour, les ouvrent par-dessus (`AccueilModele.entete`). Sur iOS, ce sont
/// trois onglets réels, chacun avec sa pile de navigation (PORTAGE.md § 1.2).
public enum Onglet: String, Sendable, CaseIterable, Identifiable {
    case aujourdhui, textes, chemin

    public var id: String { rawValue }

    /// La clé du titre de l'onglet dans le catalogue : celle d'`android:title` dans nav_main.xml. L'onglet du
    /// Chemin garde sur Android l'identifiant de l'ancien Journal (`nav_journal`), mais prend le titre `nav_chemin`.
    public var cle: String {
        switch self {
        case .aujourdhui: "nav_today"
        case .textes: "nav_texts"
        case .chemin: "nav_chemin"
        }
    }

    /// Le symbole SF de l'icône, nommé au trait : la barre d'onglets d'iOS en montre d'elle-même la variante
    /// pleine (`.fill`) quand elle existe, là où Android change d'icône (`ic_nav_*_off` au repos, `ic_nav_*_on`
    /// actif) ; l'onglet choisi se distingue par la couleur.
    public var symbole: String {
        switch self {
        // ic_nav_today : la maison, porte ouverte.
        case .aujourdhui: "house"
        // ic_nav_texts : la couverture d'un livre, la tranche plus claire.
        case .textes: "book.closed"
        // ic_nav_chemin : un sentier au trait arrondi, entre deux bornes.
        case .chemin: "point.topleft.down.curvedto.point.bottomright.up"
        }
    }

    /// L'onglet d'un écran d'ouverture (Store.Ouverture). Zmanim s'ouvre par-dessus le Jour, comme sur Android
    /// (`zmanimParDessus`).
    public init(_ ouverture: Reglages.Ouverture) {
        switch ouverture {
        case .aujourdhui, .zmanim: self = .aujourdhui
        case .textes: self = .textes
        }
    }

    /// L'onglet choisi au lancement : celui du réglage « ecran_ouverture » (MainActivity.onCreate), Aujourd'hui
    /// par défaut.
    public static func initial(_ reglages: Reglages) -> Onglet {
        Onglet(reglages.ouverture)
    }

    /// Au lancement, Zmanim s'ouvre par-dessus le Jour (réglage « Zmanim »), sauf quand l'app s'ouvre pour écrire
    /// la note d'une séance (EXTRA_ASK_NOTE).
    public static func zmanimParDessus(_ reglages: Reglages, pourUneNote: Bool = false) -> Bool {
        reglages.ouverture == .zmanim && !pourUneNote
    }
}
