import Foundation
import Observation
import Coeur

// Le Chemin (refonte d'Android du 13/11) : le troisième onglet de l'accueil, le panneau chemin_scroll
// d'activity_main.xml (MainActivity.renderChemin). En tête, trois chiffres — la série, la meilleure série, le temps
// total — puis les minutes de chaque jour du mois en barres, comme en tête du journal ; dessous, trois cartes :
// le journal (« 12 hitbodedout, 4 h 30 au total »), « Mon parcours », et les trophées (le prochain à gagner).
//
// Lu du Magasin à chaque fois : un jour inscrit ailleurs se voit aussitôt.

/// Où mène une carte du Chemin.
public enum CheminRoute: Sendable, Hashable {
    /// JournalActivity.
    case journal
    /// ParcoursActivity : « Mon parcours ».
    case parcours
    /// PaliersActivity : les trophées et les paliers.
    case paliers
}

/// Un des trois chiffres de tête (CheminStat, style CheminValeur) : la valeur en grand, ce qu'elle compte dessous.
public struct CheminChiffre: Sendable, Hashable, Identifiable {
    public let id: String
    public let valeur: AccueilTexte
    public let libelle: Libelle
}

@MainActor
@Observable
public final class CheminModele {

    private let magasin: Magasin
    private let horloge: any Horloge

    /// Les écrans à ouvrir, dans l'ordre : la vue ouvre le premier puis appelle `routeOuverte()`.
    public private(set) var routes: [CheminRoute] = []

    public init(magasin: Magasin, horloge: any Horloge) {
        self.magasin = magasin
        self.horloge = horloge
    }

    /// « Le Chemin » (nav_chemin), titre du panneau.
    public var titre: Libelle { Libelle("nav_chemin") }

    /// La série, la meilleure, le total. Les deux séries sont des nombres que la vue écrit dans les chiffres de la
    /// langue de l'app (`String.format(langue, "%d")`) ; le total, une durée (Store.formatDuration).
    public var serie: Int {
        Store.streak(journal: magasin.journal, reglages: magasin.reglages, aujourdhui: horloge.aujourdhui,
                     fuseauTelephone: horloge.fuseau.identifiant)
    }

    public var meilleure: Int {
        Store.meilleureSerie(journal: magasin.journal, reglages: magasin.reglages, aujourdhui: horloge.aujourdhui,
                             fuseauTelephone: horloge.fuseau.identifiant)
    }

    public var total: Libelle {
        Store.formatDuration(Store.totalMinutes(journal: magasin.journal))
    }

    /// Les trois chiffres, dans l'ordre du panneau.
    public var chiffres: [CheminChiffre] {
        [CheminChiffre(id: "serie", valeur: .brut(String(serie)), libelle: Libelle("chemin_stat_serie")),
         CheminChiffre(id: "meilleure", valeur: .brut(String(meilleure)), libelle: Libelle("chemin_stat_meilleure")),
         CheminChiffre(id: "total", valeur: .libelle(total), libelle: Libelle("chemin_stat_total"))]
    }

    /// Le mois en cours en barres (JournalPlus.Graphique) ; la vue le titre du mois et de l'année (« LLLL yyyy »).
    public var graphique: JournalGraphique {
        JournalGraphique(journal: magasin.journal, aujourdhui: horloge.aujourdhui)
    }

    /// « Journal » et son état : « 12 hitbodedout, 4 h 30 au total » (journal_summary). Les journées faites
    /// seulement (une note seule n'en est pas une) ; le temps, de toutes les journées.
    public var libelleJournal: Libelle { Libelle("nav_journal") }

    public var etatJournal: Libelle {
        let journal = magasin.journal
        let faites = Store.joursFaits(journal: journal).count
        return Libelle.pluriel("journal_summary", quantite: faites, .entier(faites),
                               .libelle(Store.formatDuration(Store.totalMinutes(journal: journal))))
    }

    /// « Mon parcours » et sa phrase (chemin_parcours_hint).
    public var libelleParcours: Libelle { Libelle("parcours_title") }
    public var indicationParcours: Libelle { Libelle("chemin_parcours_hint") }

    /// « Trophées » et le prochain à gagner : « Encore 3 jours pour … » (accueil_prochain_trophee), ou « Tous les
    /// trophées sont gagnés » (trophees_tous).
    public var libelleTrophees: Libelle { Libelle("chemin_trophees") }

    public var etatTrophees: Libelle {
        let p = Store.pratique(journal: magasin.journal, reglages: magasin.reglages, aujourdhui: horloge.aujourdhui,
                               fuseauTelephone: horloge.fuseau.identifiant)
        guard let prochain = Trophees.prochain(p) else { return Libelle("trophees_tous") }
        let reste = prochain.seuil - min(Trophees.valeur(p, prochain.famille), prochain.seuil)
        return Libelle("accueil_prochain_trophee", .libelle(TropheeTextes.description(prochain)), .entier(reste))
    }

    public func ouvrir(_ route: CheminRoute) {
        routes.append(route)
    }

    /// L'écran en tête de `routes` est ouvert.
    public func routeOuverte() {
        if !routes.isEmpty { routes.removeFirst() }
    }
}
