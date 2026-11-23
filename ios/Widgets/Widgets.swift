import SwiftUI
import WidgetKit

/// Les widgets de l'app (tâche 25) et la Live Activity de la séance (tâche 17), ceux d'Android dans les tailles
/// d'iOS : la série (StreakWidget, trois tailles), les trois vignettes des zmanim (ZmanimVignette) et leur pendant de
/// l'écran verrouillé, la boussole (BoussoleWidget).
@main
struct WidgetsMyHitbodedut: WidgetBundle {
    var body: some Widget {
        SerieWidget()
        ZmanimPetitWidget()
        ZmanimWidget()
        ZmanimGrandWidget()
        ZmanimVerrouilleWidget()
        BoussoleWidget()
        SeanceActiviteWidget()
    }
}
