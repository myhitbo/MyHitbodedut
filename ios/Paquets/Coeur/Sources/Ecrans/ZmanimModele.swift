import Foundation
import Observation
import Coeur

/// L'onglet Zmanim (ZmanimActivity.kt) : le lieu, le jour montré et ses horaires.
///
/// Un modèle d'écran n'affiche rien : la vue SwiftUI de l'app le lit et appelle ses actions. Toute sa
/// logique passe par les règles de Coeur ; lui se compile et se teste sous Linux, la vue non.
@MainActor
@Observable
public final class ZmanimModele {
    /// nil tant qu'aucun lieu n'est choisi : l'écran propose alors d'en choisir un.
    public var lieu: Zmanim.Lieu?
    /// Le jour montré.
    public var jour: JourCivil
    public var enIsrael: Bool
    /// Les minutes d'allumage avant la chki'a, parmi Zmanim.allumages.
    public var allumage: Int

    public init(lieu: Zmanim.Lieu?, jour: JourCivil, enIsrael: Bool, allumage: Int = Zmanim.allumageDefaut) {
        self.lieu = lieu
        self.jour = jour
        self.enIsrael = enIsrael
        self.allumage = allumage
    }

    /// Les horaires du jour montré (JourAffiche.horaires), allumage et sortie compris ; vide sans lieu.
    public var horaires: [Zmanim.Zman] {
        guard let lieu else { return [] }
        return JourAffiche.horaires(lieu: lieu, date: jour, enIsrael: enIsrael, minutes: allumage)
    }

    /// Le jour hébraïque du jour montré.
    public var jourHebreu: CalendrierJuif.Jour {
        CalendrierJuif.jour(jour, enIsrael: enIsrael)
    }

    public func jourSuivant() {
        jour = jour.plus(jours: 1)
    }

    public func jourPrecedent() {
        jour = jour.plus(jours: -1)
    }
}
