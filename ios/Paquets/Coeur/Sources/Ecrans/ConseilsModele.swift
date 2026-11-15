import Foundation
import Observation
import Coeur

// Les conseils pour la hitbodedout (TipsActivity.kt, activity_tips.xml, item_tip.xml) : dix cartes, en lecture
// seule. La table est la règle de Coeur (Tips.swift) ; l'image de chaque carte suit l'adresse (Personnage.pour),
// comme toute ImageView d'Android (PersonnageViewInflater).

/// Une carte de l'écran des conseils (item_tip.xml) : le rang dans sa pastille, le titre, l'image, le texte.
public struct ConseilsLigne: Sendable, Hashable, Identifiable {
    /// 1 à 10.
    public let numero: Int
    /// Le rang tel qu'Android l'écrit (`number.toString()`) : en chiffres ASCII, dans les trois langues.
    public let numeroTexte: String
    /// « tip_1_title »…
    public let titre: Libelle
    /// « tip_1_body »…
    public let corps: Libelle
    /// Le nom de l'image (ios/Ressources/Images), la pose féminine pour qui a choisi צדקת.
    public let illustration: String

    public var id: Int { numero }
}

/// L'écran des conseils (TipsActivity) : le bandeau et les dix cartes, dans l'ordre.
///
/// L'adresse est le réglage du `Magasin`, lue à chaque fois : un choix fait ailleurs change les images ici.
@MainActor
@Observable
public final class ConseilsModele {
    private let magasin: Magasin

    public init(magasin: Magasin) {
        self.magasin = magasin
    }

    /// Les conseils pour une adresse donnée d'avance, dans un magasin en mémoire : pour les aperçus.
    public static func apercu(adresse: Adresse? = nil) -> ConseilsModele {
        var reglages = Reglages()
        reglages.setAdresse(adresse?.cle)
        return ConseilsModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)))
    }

    /// Le titre du bandeau, « Conseils pour la hitbodedout » (tips_title) : c'est aussi le titre de l'écran.
    public var titre: Libelle {
        Libelle("tips_title")
    }

    /// La ligne sous le titre, « Dix repères pour commencer et pour tenir. » (tips_hint).
    public var indication: Libelle {
        Libelle("tips_hint")
    }

    /// L'adresse réglée ; nil tant que rien n'est choisi.
    public var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }

    /// Les dix cartes, dans l'ordre de Tips.all.
    public var lignes: [ConseilsLigne] {
        let adresse = self.adresse
        return Tips.all.map { conseil in
            ConseilsLigne(numero: conseil.number,
                          numeroTexte: String(conseil.number),
                          titre: Libelle(conseil.titleRes),
                          corps: Libelle(conseil.bodyRes),
                          illustration: Personnage.pour(adresse, conseil.art))
        }
    }
}
