import Barriere
import DeviceActivity
import Foundation
import ManagedSettings

/// L'extension DeviceActivityMonitor de la barrière (PORTAGE.md § 2.1.5, § 2.1.6, § 2.1.10) : ce qui, sur Android,
/// était la boucle de GateService (`evaluate`, toutes les 900 ms) ne tourne sur iOS qu'aux rendez-vous donnés au
/// système par l'app (`SystemeBarriere`) : `fenetre` (chaque jour, de `window_start` à `window_end`), `minuit`
/// (chaque jour à 00:00), et trois activités d'un seul intervalle, `report`, `seance` et `essai`, qui commencent à
/// la fin du report, de la séance et de l'essai.
///
/// À chaque réveil, elle écrit le réveil dans la boîte (la carte d'état en tire « Surveillance muette »), lit
/// etat.json, bouclier.json et la boîte, et active ou désactive les trois magasins nommés selon la règle
/// `PilotageBarriere.consigne` du module Barriere, celle que l'app applique aussi ; chaque bascule est écrite dans
/// la boîte. Elle ne touche pas aux jetons des magasins, que l'app seule pose. Une activité d'un seul intervalle
/// est arrêtée dès son début.
///
/// L'extension a quelques mégaoctets de mémoire (§ 2.1.9) : elle ne lit que ces trois petits fichiers, ni journal,
/// ni calendrier, ni catalogue. iOS ne la réveille que lorsque l'appareil sert : un début de fenêtre à 6 h est
/// traité au premier déverrouillage. Rien de ceci ne tourne sans l'entitlement Family Controls accordé par Apple.
class Surveillance: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        SurveillanceReveil.recevoir(activity.rawValue, .debut)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        SurveillanceReveil.recevoir(activity.rawValue, .fin)
    }
}

/// Un rendez-vous reçu : la règle des magasins, appliquée.
enum SurveillanceReveil {

    static func recevoir(_ nom: String, _ borne: BorneActivite) {
        // Une activité d'une autre version de l'app : rien à faire.
        guard let activite = ActiviteBarriere(rawValue: nom) else { return }
        let rendezVous = RendezVous(activite, borne)
        let maintenant = Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
        let fuseau = TimeZone.current
        guard let conteneur = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ConteneurBarriere.groupe) else { return }
        let boite = ConteneurBarriere.fichier(Boite.nomFichier, dans: conteneur)
        let quand = Horodatage(millis: maintenant, fuseau: fuseau)
        try? FileManager.default.createDirectory(at: ConteneurBarriere.repertoire(dans: conteneur),
                                                 withIntermediateDirectories: true)
        try? Boite.ajouter(Evenement(quand: quand, genre: .reveil, detail: rendezVous.detail), a: boite)

        let etat = lire(Etat.nomFichier, dans: conteneur).flatMap { Etat.lire($0) }
        let decor = lire(DecorBouclier.nomFichier, dans: conteneur).flatMap { DecorBouclier.lire($0) }
        let evenements = lire(Boite.nomFichier, dans: conteneur).map { Boite.lire($0) } ?? []
        let consigne = PilotageBarriere.consigne(etat: etat, decor: decor, evenements: evenements, millis: maintenant,
                                                 fuseau: fuseau, rendezVous: rendezVous)
        basculer(PilotageBarriere.magasinBarriere, consigne.barriere, quand: quand, boite: boite)
        basculer(PilotageBarriere.magasinSeance, consigne.seance, quand: quand, boite: boite)
        // L'essai n'est jamais posé ici : l'app le pose ; la surveillance ne fait que le lever à sa fin.
        if !consigne.essai {
            basculer(PilotageBarriere.magasinEssai, false, quand: quand, boite: boite)
        }
        if PilotageBarriere.aArreter(rendezVous) {
            DeviceActivityCenter().stopMonitoring([DeviceActivityName(nom)])
        }
    }

    /// Active ou désactive un magasin nommé ; une bascule s'écrit dans la boîte (`armee`, `levee`).
    private static func basculer(_ nom: String, _ actif: Bool, quand: Horodatage, boite: URL) {
        let magasin = ManagedSettingsStore(named: ManagedSettingsStore.Name(nom))
        guard magasin.isActive != actif else { return }
        magasin.isActive = actif
        let genre: Evenement.Genre = actif ? .armee : .levee
        try? Boite.ajouter(Evenement(quand: quand, genre: genre, detail: "surveillance:" + nom), a: boite)
    }

    private static func lire(_ nom: String, dans conteneur: URL) -> Data? {
        try? Data(contentsOf: ConteneurBarriere.fichier(nom, dans: conteneur))
    }
}
