import Coeur
import Ecrans
import Foundation
import WidgetKit

/// Le rafraîchissement des widgets (StreakWidget.refresh, ZmanimWidget.refresh, BoussoleWidget.refresh d'Android) :
/// `WidgetCenter`. C'est le `BoussoleRafraichissement` de la boussole ; l'accueil, l'ajout de temps et les
/// réglages s'en servent aussi.
///
/// Avant de recharger, il dépose dans le groupe d'apps ce que les widgets lisent :
/// - pour la boussole, la direction et ses textes (`BoussolePartagee`) : ce widget dessine ce que l'app a calculé ;
/// - pour la série et les zmanim, une copie du journal et des réglages (`WidgetsPartage.dossier`, écrite par un
///   `Depot` comme les fichiers de l'app) et la langue de l'app (`WidgetsPartage.langue`) : ces widgets calculent
///   eux-mêmes leur chronologie avec Coeur (la série change à minuit, la prière à chaque zman), sans réveiller l'app.
///
/// Le conteneur du groupe n'existe qu'une fois le groupe d'apps accordé à la signature (SIGNATURE.md) : sans lui,
/// rien n'est déposé, et les widgets de la série et des zmanim montrent un journal neuf et « Choisir le lieu ».
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
        await deposerPratique()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// StreakWidget.Etat.lire et ZmanimVignette.vues lisaient les préférences d'Android ; l'extension ne voit pas les
    /// fichiers de l'app : sa copie, dans le conteneur du groupe. Le dépôt n'écrit que ce qui a changé.
    func deposerPratique() async {
        UserDefaults(suiteName: WidgetsPartage.groupe)?.set(traducteur.langue, forKey: WidgetsPartage.langue)
        guard let conteneur = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetsPartage.groupe) else { return }
        let copie = Depot(dossier: conteneur.appending(path: WidgetsPartage.dossier, directoryHint: .isDirectory))
        let journal = magasin.journal
        let reglages = magasin.reglages
        // Chaque fichier à part : un échec sur le journal ne doit pas priver les widgets des réglages (le lieu, la
        // séance en cours), ni l'inverse. Sur un échec, les widgets gardent la copie précédente jusqu'au prochain dépôt.
        _ = try? await copie.modifier { $0 = journal }
        _ = try? await copie.modifierReglages { $0 = reglages }
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
