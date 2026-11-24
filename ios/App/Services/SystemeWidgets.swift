import Coeur
import Ecrans
import Foundation
import WidgetKit

/// Le rafraîchissement des widgets (StreakWidget.refresh, ZmanimWidget.refresh, BoussoleWidget.refresh d'Android) :
/// `WidgetCenter`. C'est le `BoussoleRafraichissement` de la boussole ; l'accueil, l'ajout de temps et les
/// réglages s'en servent aussi.
///
/// Avant de recharger, il dépose dans le groupe d'apps ce que le widget de la boussole montre (`BoussolePartagee`) :
/// le widget n'a ni le journal ni les règles, il dessine la direction que l'app a calculée, dans sa langue.
@MainActor
final class SystemeWidgets: BoussoleRafraichissement {

    private let magasin: Magasin
    private let traducteur: Traducteur

    init(magasin: Magasin, traducteur: Traducteur) {
        self.magasin = magasin
        self.traducteur = traducteur
    }

    func rafraichir() async {
        deposerBoussole()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// BoussoleWidget.vues : la direction principale de Jérusalem depuis le lieu des zmanim (selon la carte si le
    /// réglage le veut), ses degrés depuis le nord, et la lecture pour VoiceOver ; sans lieu, « Choisir le lieu ».
    func deposerBoussole() {
        guard let partage = UserDefaults(suiteName: BoussolePartagee.groupe) else { return }
        let reglages = magasin.reglages
        partage.set(traducteur.texte(cle: "boussole_nord"), forKey: BoussolePartagee.nord)
        partage.set(traducteur.texte(cle: "boussole_title"), forKey: BoussolePartagee.titre)
        guard let lieu = reglages.lieuZmanim else {
            partage.removeObject(forKey: BoussolePartagee.degres)
            partage.set(traducteur.texte(cle: "zmanim_choisir_lieu"), forKey: BoussolePartagee.lecture)
            return
        }
        let principale = DirectionJerusalem.directions(lieu.latitude, lieu.longitude,
                                                       selonCarte: reglages.boussoleCarte).principale
        let degres = DirectionJerusalem.degres(principale)
        partage.set(degres, forKey: BoussolePartagee.degres)
        partage.set(traducteur.texte(Libelle("boussole_widget_lecture", .texte(lieu.nom), .entier(degres))),
                    forKey: BoussolePartagee.lecture)
    }
}

/// Les clés que l'app et le widget de la boussole partagent (Widgets/Widgets.swift a les mêmes).
enum BoussolePartagee {
    static let groupe = "group.com.myhitbodedut"
    static let degres = "boussole.degres"
    static let nord = "boussole.nord"
    static let titre = "boussole.titre"
    static let lecture = "boussole.lecture"
}
