import Barriere
import DeviceActivity
import Foundation
import ManagedSettings

/// L'extension de surveillance de la barrière (DeviceActivityMonitor, PORTAGE.md § 2.1.2, § 2.1.5) : ce qui tient lieu
/// de la boucle de GateService quand l'app est fermée. iOS la réveille aux rendez-vous que l'app a donnés (la fenêtre,
/// minuit, la fin du report, de la séance ou de l'essai) ; elle lit l'instantané et la boîte, applique la règle
/// (`Planification.voulus`), pose ou lève le magasin `barriere` et celui de l'essai, et le note dans la boîte. Quelques
/// mégaoctets de mémoire : ni journal, ni calendrier, ni catalogue (§ 2.1.9).
class Surveillance: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        reveiller(activity, debut: true)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        reveiller(activity, debut: false)
    }

    /// Un réveil : le noter, appliquer la règle, et ne plus attendre un rendez-vous unique qui a servi.
    private func reveiller(_ activity: DeviceActivityName, debut: Bool) {
        guard let fichiers = FichiersBarriere.duGroupe() else { return }
        let maintenant = TempsEcranCommun.maintenant()
        TempsEcranCommun.noter(.reveil, activity.rawValue, fichiers: fichiers, quand: maintenant)
        guard let etat = fichiers.lireEtat() else { return }
        let vu = etat.avec(fichiers.lireBoite().evenements)
        let changes = TempsEcranCommun.appliquer(Planification.voulus(vu, maintenant: maintenant), fichiers: fichiers)
        for evenement in TempsEcranCommun.evenements(changes, agent: .surveillance, quand: maintenant) {
            try? fichiers.ajouter(evenement)
        }
        // Le report, la séance et l'essai sont des rendez-vous uniques : une fois servis, ils ne reviennent pas.
        if debut, let activite = Activite(rawValue: activity.rawValue), activite == .report || activite == .seance
            || activite == .essai {
            TempsEcranCommun.arreter(activite)
        }
    }
}
