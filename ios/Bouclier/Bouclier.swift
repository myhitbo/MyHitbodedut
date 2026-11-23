import Barriere
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// L'extension du bouclier (ShieldConfigurationDataSource, PORTAGE.md § 2.1.4) : l'écran de garde d'Android
/// (BlockerView, view_blocker.xml) ramené à ce qu'un bouclier porte. Le visage vient de la règle (`PlanBouclier.face` :
/// l'invite, sa deuxième page, la séance, l'essai, ou le bouclier resté posé à tort), les textes de l'instantané, déjà
/// traduits dans la langue de l'app, les couleurs de la palette choisie, l'image du personnage du jour copiée par l'app.
/// Le texte est figé à l'apparition, comme l'écran d'Android à chaque tour.
class Bouclier: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    private func configuration() -> ShieldConfiguration {
        // Sans instantané (l'app jamais ouverte depuis l'installation), le bouclier du système.
        guard let fichiers = FichiersBarriere.duGroupe(), let etat = fichiers.lireEtat() else {
            return ShieldConfiguration()
        }
        let maintenant = Horodatage(millis: Int64((Date().timeIntervalSince1970 * 1000).rounded(.down)), fuseau: .current)
        let face = PlanBouclier.face(etat, evenements: fichiers.lireBoite().evenements, maintenant: maintenant)
        let contenu = PlanBouclier.contenu(face, etat: etat)
        let a = contenu.apparence
        let texte = Bouclier.couleur(a.texte)
        let image = contenu.icone.isEmpty ? nil : UIImage(contentsOfFile: fichiers.image(contenu.icone).path)
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: Bouclier.couleur(a.fond),
            icon: image,
            title: ShieldConfiguration.Label(text: contenu.titre, color: Bouclier.couleur(a.titre)),
            subtitle: ShieldConfiguration.Label(text: contenu.sousTitre, color: texte),
            primaryButtonLabel: ShieldConfiguration.Label(text: contenu.principal, color: Bouclier.couleur(a.texteBouton)),
            primaryButtonBackgroundColor: Bouclier.couleur(a.bouton),
            secondaryButtonLabel: contenu.secondaire.map { ShieldConfiguration.Label(text: $0, color: texte) },
            secondaryButtonSubmenuItems: contenu.sousMenu.isEmpty ? nil : contenu.sousMenu)
    }

    /// « #RRGGBB » de l'apparence ; le blanc pour un texte mal formé.
    private static func couleur(_ hex: String) -> UIColor {
        guard let rvb = ApparenceBouclier.rvb(hex) else { return .white }
        return UIColor(red: CGFloat(rvb.rouge) / 255, green: CGFloat(rvb.vert) / 255, blue: CGFloat(rvb.bleu) / 255, alpha: 1)
    }
}
