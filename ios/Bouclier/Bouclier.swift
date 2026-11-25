import Barriere
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// L'extension ShieldConfigurationDataSource : le visage du bouclier (PORTAGE.md § 2.1.4 ; BlockerView.kt et
/// view_blocker.xml d'Android). iOS la réveille quand une application, une catégorie ou un site retenus par un des
/// magasins nommés de la barrière s'ouvre ; elle rend le bouclier tel qu'il doit paraître, figé à cet instant.
///
/// Elle ne calcule rien et ne charge aucun catalogue : l'app a déposé dans le groupe d'apps (`barriere/`) les
/// textes déjà traduits (etat.json), les couleurs de la palette et l'essai en cours (bouclier.json), et les deux
/// poses du hassid du jour. Le visage (rien de fait, séance en cours, essai) et ce qu'il porte sont la règle
/// `VisageBouclier` du module Barriere, celle que la réplique de l'app dessine aussi.
///
/// Le nom de l'application retenue, que l'extension reçoit, n'est pas montré : aucune chaîne d'Android ne le dit
/// (§ 2.1.4, à décider). Le mot de 'hizouk du moment « porte » non plus : l'export ne marque pas encore ceux qui
/// tiennent dans le sous-titre.
///
/// Rien de ceci ne paraît sans l'entitlement Family Controls accordé par Apple à l'app et à cette extension : sans
/// lui, l'autorisation de Temps d'écran est refusée et aucun magasin ne retient rien.
class Bouclier: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        BouclierVisage.configuration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        BouclierVisage.configuration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        BouclierVisage.configuration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        BouclierVisage.configuration()
    }
}

/// Le bouclier composé d'après ce que l'app a déposé.
enum BouclierVisage {

    static func configuration() -> ShieldConfiguration {
        let maintenant = Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
        guard let conteneur = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ConteneurBarriere.groupe) else {
            // Sans le groupe d'apps (une signature incomplète) : le bouclier du système.
            return systeme
        }
        let etat = lire(Etat.nomFichier, dans: conteneur).flatMap { Etat.lire($0) }
        let decor = lire(DecorBouclier.nomFichier, dans: conteneur).flatMap { DecorBouclier.lire($0) } ?? DecorBouclier()
        let evenements = lire(Boite.nomFichier, dans: conteneur).map { Boite.lire($0) } ?? []
        guard let etat, !etat.bouclier.question.isEmpty else {
            // L'app n'a encore rien déposé : le bouclier du système, plutôt qu'un bouclier sans texte.
            return systeme
        }
        let visage = VisageBouclier.actuel(etat: etat, decor: decor, evenements: evenements, millis: maintenant)
        let textes = etat.bouclier
        let contenu = visage.contenu { textes[$0] }
        let mint = couleur(decor.sousTitre, repli: .white)
        let icone = UIImage(contentsOfFile: ConteneurBarriere.fichier(contenu.pose.fichier, dans: conteneur)
            .path(percentEncoded: false))
        let secondaire = contenu.secondaire.map { ShieldConfiguration.Label(text: $0, color: mint) }
        // Le sous-menu du bouton secondaire (iOS 26.4) : « Je l'ai déjà faite », « Plus tard (15 min) ».
        let sousMenu: [String]? = contenu.sousMenu.isEmpty ? nil : contenu.sousMenu
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: couleur(decor.fond, repli: .black),
            icon: icone,
            title: ShieldConfiguration.Label(text: contenu.titre, color: couleur(decor.titre, repli: .white)),
            subtitle: ShieldConfiguration.Label(text: contenu.sousTitre, color: mint),
            primaryButtonLabel: ShieldConfiguration.Label(text: contenu.principal,
                                                          color: couleur(decor.texteBouton, repli: .white)),
            primaryButtonBackgroundColor: couleur(decor.bouton, repli: .systemGreen),
            secondaryButtonLabel: secondaire,
            secondaryButtonSubmenuItems: sousMenu)
    }

    /// Le bouclier du système, sans rien de l'app. L'argument nommé choisit l'initialiseur d'iOS 26.4 : appelé
    /// sans argument, `ShieldConfiguration()` pourrait désigner les deux.
    private static var systeme: ShieldConfiguration {
        ShieldConfiguration(secondaryButtonSubmenuItems: nil)
    }

    /// Un fichier du dossier de la barrière ; nil s'il manque ou ne se lit pas.
    private static func lire(_ nom: String, dans conteneur: URL) -> Data? {
        try? Data(contentsOf: ConteneurBarriere.fichier(nom, dans: conteneur))
    }

    /// Une couleur `#RRGGBB` du décor ; `repli` si elle ne se lit pas.
    private static func couleur(_ hex: String, repli: UIColor) -> UIColor {
        guard let c = DecorBouclier.composantes(hex) else { return repli }
        return UIColor(red: CGFloat(c.rouge), green: CGFloat(c.vert), blue: CGFloat(c.bleu), alpha: 1)
    }
}
