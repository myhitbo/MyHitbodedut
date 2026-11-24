import Coeur
import Ecrans
import Foundation

/// Ce qu'un changement de réglage oblige à réécrire hors de l'écran (GateService, Reminder.reschedule,
/// LevanaAlerte.programmer, StreakWidget.refresh d'Android, que le système relance de lui-même ; iOS doit le
/// redéposer) : les notifications prévues, d'après le journal et les réglages tels qu'ils viennent d'être écrits,
/// et les widgets.
///
/// `.barriere` (l'instantané `barriere/etat.json` des extensions et la surveillance de Temps d'écran) ne fait
/// encore rien : la barrière demande FamilyControls, accordé par Apple à la signature (`SystemeTempsEcran`).
@MainActor
final class SystemeEffetsReglages: ReglagesEffets {

    private let rappels: SystemeRappels
    private let widgets: SystemeWidgets

    init(rappels: SystemeRappels, widgets: SystemeWidgets) {
        self.rappels = rappels
        self.widgets = widgets
    }

    func repercuter(_ quoi: ReglagesRepercussions, journal: Journal, reglages: Reglages) async {
        if quoi.contains(.rappels) {
            await rappels.replanifier(journal: journal, reglages: reglages)
        }
        if quoi.contains(.widgets) {
            await widgets.rafraichir()
        }
    }
}
