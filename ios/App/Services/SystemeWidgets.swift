import Ecrans
import Foundation
import WidgetKit

/// Le rafraîchissement des widgets (StreakWidget.refresh, ZmanimWidget.refresh, BoussoleWidget.refresh d'Android) :
/// `WidgetCenter`. C'est le `BoussoleRafraichissement` de la boussole ; l'accueil, l'ajout de temps et les
/// réglages s'en servent aussi.
///
/// Toutes les chronologies sont rechargées : les widgets de l'app (tâche 25) n'ont pas encore leurs genres
/// (`kind`), et un rechargement de trop ne coûte qu'un calcul de chronologie au système.
@MainActor
final class SystemeWidgets: BoussoleRafraichissement {

    init() {}

    func rafraichir() async {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
