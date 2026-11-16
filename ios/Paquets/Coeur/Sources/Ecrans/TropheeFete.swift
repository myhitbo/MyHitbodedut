import Foundation
import Observation
import Coeur

/// La fête de l'accueil (Confettis.kt, `Celebrations.ecran`, et FicheTrophee.feter ; 16/10 et 19/10) : à
/// chaque passage sur l'accueil (MainActivity.renderPaliers), ce qui est neuf depuis la dernière fois.
///
/// - Un trophée neuf ouvre sa fiche, avec confettis et étincelles ; plusieurs (un par famille, le plus
///   précieux d'abord, `Trophees.nouveaux`) s'ouvrent l'une après l'autre, chacune avec sa fête.
/// - Sinon, un palier neuf (le plus haut, `Celebrations.neuf`) : sa phrase en bandeau bref, et des étincelles
///   du grade autour de la ligne du grade de l'accueil.
/// - Le tout premier passage ne fête rien : les trophées vus et les paliers vus sont encore nil, une
///   installation qui a déjà de l'historique ne reçoit pas une pluie de vieux trophées.
///
/// Après chaque passage, ce qui est gagné est retenu comme vu (« paliers_vus », « trophees_vus ») : rien n'est
/// fêté deux fois, ni ici ni sur l'écran des paliers, qui écrit les mêmes clés.
@MainActor
@Observable
public final class TropheeFeteModele {

    /// Les fiches s'ouvrent ce délai après l'accueil (ms), le temps qu'il paraisse (`postDelayed(…, 500)`).
    nonisolated public static let retardFiches = 500
    /// Les étincelles d'un palier, ce délai après l'accueil (ms).
    nonisolated public static let retardEtincelles = 500

    private let magasin: Magasin
    private let horloge: any Horloge

    /// Les fiches à montrer, dans l'ordre : la première est ouverte, les autres attendent qu'elle se ferme.
    public private(set) var fiches: [TropheeFiche] = []
    /// La phrase d'un palier neuf, montrée brièvement (un `Toast` long sur Android, 3,5 s) ; nil sinon.
    public private(set) var palier: Libelle? = nil
    /// Les étincelles d'un palier neuf, du métal du grade, autour de la ligne du grade de l'accueil.
    public private(set) var etincelles: Trophees.Metal? = nil
    /// Monte à chaque fête de palier : la vue relance ses étincelles même si le grade n'a pas changé.
    public private(set) var fetesPalier = 0

    public init(magasin: Magasin, horloge: any Horloge) {
        self.magasin = magasin
        self.horloge = horloge
    }

    /// La fiche ouverte ; nil quand il n'y en a plus.
    public var ficheCourante: TropheeFiche? { fiches.first }

    /// Un passage sur l'accueil (onResume) : cherche ce qui est neuf, prépare la fête, puis retient tout ce qui
    /// est gagné comme vu. Lève si les réglages ne s'écrivent pas (la fête reste préparée).
    public func passer() async throws {
        let journal = magasin.journal
        let reglages = magasin.reglages
        let aujourdhui = horloge.aujourdhui
        let fuseau = horloge.fuseau.identifiant
        let bilan = Store.bilan(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: fuseau)
        let pratique = Store.pratique(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                      fuseauTelephone: fuseau)
        let vus = reglages.tropheesVus
        let neuf = Celebrations.neuf(bilan, pratique, paliersVus: reglages.paliersVus, tropheesVus: vus)
        let trophees = Trophees.nouveaux(Trophees.gagnes(pratique), vus: vus)
        if !trophees.isEmpty {
            let dates = Store.datesTrophees(journal: journal, reglages: reglages, fuseauTelephone: fuseau)
            let faits = Trophees.chemin.filter { Trophees.gagne(pratique, $0) }
            fiches = trophees.map { t in
                // Son rang parmi les gagnés ; à défaut, le dernier (FicheTrophee.feter).
                let rang = faits.firstIndex(of: t).map { $0 + 1 } ?? faits.count
                return TropheeFiche(niveau: t, pratique: pratique, dates: dates, rangGlobal: rang, feter: true)
            }
        } else if let message = neuf.message {
            palier = message
            etincelles = Trophees.grade(neuf.trophees.count)
            fetesPalier += 1
        }
        let marques = neuf.marques
        let cles = neuf.trophees
        try await magasin.modifierReglages { r in
            r.setPaliersVus(marques)
            r.setTropheesVus(cles)
        }
    }

    /// La fiche ouverte se ferme (« Continuer », ou un toucher hors de la carte) : la suivante s'ouvre.
    public func fermerFiche() {
        if !fiches.isEmpty { fiches.removeFirst() }
    }

    /// La phrase du palier a été montrée : elle s'efface.
    public func palierMontre() {
        palier = nil
    }
}
