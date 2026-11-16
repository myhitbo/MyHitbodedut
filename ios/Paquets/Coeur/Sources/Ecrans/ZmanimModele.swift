import Foundation
import Observation
import Coeur

/// L'onglet Zmanim (ZmanimActivity.kt) : le lieu, le jour montré et ses horaires.
///
/// Un modèle d'écran n'affiche rien : la vue SwiftUI de l'app le lit et appelle ses actions. Toute sa
/// logique passe par les règles de Coeur ; lui se compile et se teste sous Linux, la vue non.
///
/// Le lieu, Israël ou diaspora et l'allumage sont les réglages du `Magasin`, lus à chaque fois (un lieu choisi
/// ailleurs se voit ici) et écrits par ses actions ; le jour montré part d'aujourd'hui, dans le fuseau du
/// téléphone (`LocalDate.now()` d'Android), et se déplace sur place.
@MainActor
@Observable
public final class ZmanimModele {
    private let magasin: Magasin
    private let horloge: any Horloge

    /// Le jour montré.
    public var jour: JourCivil

    public init(magasin: Magasin, horloge: any Horloge) {
        self.magasin = magasin
        self.horloge = horloge
        jour = horloge.aujourdhui
    }

    /// Un lieu, un jour et des réglages donnés d'avance, dans un magasin en mémoire, l'horloge arrêtée à midi
    /// de ce jour : pour les tests et les aperçus.
    public convenience init(lieu: Zmanim.Lieu?, jour: JourCivil, enIsrael: Bool, allumage: Int = Zmanim.allumageDefaut) {
        var reglages = Reglages()
        if let lieu {
            reglages.setLieuZmanim(lieu, ville: nil, maintenant: 0)
        }
        reglages.setInIsrael(enIsrael)
        reglages.setAllumage(allumage)
        let fuseau = lieu.flatMap { Fuseau($0.fuseau) } ?? .utc
        self.init(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                  horloge: HorlogeFixe(DateHeure(jour, heure: 12), fuseau: fuseau))
    }

    /// nil tant qu'aucun lieu n'est choisi : l'écran propose alors d'en choisir un.
    public var lieu: Zmanim.Lieu? {
        magasin.reglages.lieuZmanim
    }

    /// Israël ou diaspora (Store.inIsrael) : le réglage, sinon ce que dit le fuseau du téléphone.
    public var enIsrael: Bool {
        magasin.reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// Les minutes d'allumage avant la chki'a, parmi Zmanim.allumages.
    public var allumage: Int {
        magasin.reglages.allumage
    }

    /// Le jour montré est-il aujourd'hui ?
    public var estAujourdhui: Bool {
        jour == horloge.aujourdhui
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

    public func revenirAujourdhui() {
        jour = horloge.aujourdhui
    }

    /// L'allumage choisi (ZmanimActivity.choisirAllumage), parmi Zmanim.allumages.
    public func choisirAllumage(_ minutes: Int) async throws {
        try await magasin.modifierReglages { $0.setAllumage(minutes) }
    }

    /// Le lieu choisi, une ville ou une position (ChoixLieu.kt) : il règle aussi Israël ou diaspora, et retient
    /// l'instant du choix.
    public func choisirLieu(_ lieu: Zmanim.Lieu, ville: Ville?) async throws {
        let maintenant = horloge.maintenant
        try await magasin.modifierReglages { $0.setLieuZmanim(lieu, ville: ville, maintenant: maintenant) }
    }
}
