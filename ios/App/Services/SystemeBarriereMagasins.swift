import Barriere
import Foundation
#if !SANS_BARRIERE
import DeviceActivity
import FamilyControls
import ManagedSettings
#endif

/// Ce que l'app demande à Temps d'écran pour la barrière (PORTAGE.md § 2.1.2, § 2.1.5, § 2.1.6, § 2.1.10) : les
/// trois magasins nommés (`barriere`, `seance`, `essai`), qui portent les jetons de la sélection et que l'on active
/// ou désactive (`isActive`, iOS 26.5), et les cinq activités surveillées par `DeviceActivityCenter`.
///
/// La construction SANS_BARRIERE n'a ni les cadres ni les extensions : chaque fonction y est vide, et le dit.
/// Ailleurs, rien n'aboutit sans l'entitlement Family Controls accordé par Apple : `startMonitoring` lève, les
/// magasins ne retiennent rien, et la carte d'état des réglages le montre (autorisation refusée, surveillance
/// absente).
enum SystemeBarriereMagasins {

    /// Ce que les magasins disent d'eux-mêmes.
    struct Etats: Equatable {
        var barriere: Bool
        var seance: Bool
        var essai: Bool
    }

    #if SANS_BARRIERE

    static func etats() -> Etats? { nil }

    static func basculer(_ nom: String, _ actif: Bool) -> Bool { false }

    static func poserJetons(_ donnees: Data?, sur noms: [String]) {}

    static func vider(_ noms: [String]) {}

    static func inscrite(_ activite: ActiviteBarriere) -> Bool? { nil }

    static func planifier(_ etat: Etat, essai: DecorBouclier.Essai?, millis: Int64, fuseau: TimeZone) {}

    static func toutArreter() {}

    #else

    /// L'état des trois magasins.
    static func etats() -> Etats? {
        Etats(barriere: magasin(PilotageBarriere.magasinBarriere).isActive,
              seance: magasin(PilotageBarriere.magasinSeance).isActive,
              essai: magasin(PilotageBarriere.magasinEssai).isActive)
    }

    /// Active ou désactive un magasin ; vrai s'il a fallu le changer.
    static func basculer(_ nom: String, _ actif: Bool) -> Bool {
        let cible = magasin(nom)
        guard cible.isActive != actif else { return false }
        cible.isActive = actif
        return true
    }

    /// Les jetons de la sélection (barriere/selection.plist, SystemeFamilyControls) posés sur ces magasins :
    /// applications, catégories entières (pour les applications et pour les sites), sites.
    static func poserJetons(_ donnees: Data?, sur noms: [String]) {
        let selection = SystemeFamilyControls.selection(de: donnees)
        let applications = selection.applicationTokens
        let categories = selection.categoryTokens
        let sites = selection.webDomainTokens
        for nom in noms {
            let cible = magasin(nom)
            cible.shield.applications = applications.isEmpty ? nil : applications
            cible.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
            cible.shield.webDomains = sites.isEmpty ? nil : sites
            cible.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        }
    }

    /// Vide ces magasins : plus aucun jeton, plus aucun bouclier (l'extinction du mode, « Tout effacer », § 2.1.9).
    static func vider(_ noms: [String]) {
        for nom in noms {
            magasin(nom).clearAllSettings()
        }
    }

    /// L'activité est inscrite auprès du système (`DeviceActivityCenter.activities`).
    static func inscrite(_ activite: ActiviteBarriere) -> Bool? {
        DeviceActivityCenter().activities.contains(nomActivite(activite))
    }

    /// Les rendez-vous de la surveillance, d'après l'instantané qui vient d'être écrit. Mode éteint ou sélection
    /// vide : plus aucun. Sinon `fenetre` et `minuit` chaque jour (réinscrites seulement si leurs heures changent),
    /// `report` à la fin du report en cours, `seance` à la fin de la séance minutée en cours, `essai` à la fin de
    /// l'essai. Un refus du système (fenêtre de moins de quinze minutes, entitlement absent) laisse l'activité
    /// absente : la carte d'état le dit (« Surveillance absente »).
    static func planifier(_ etat: Etat, essai: DecorBouclier.Essai?, millis: Int64, fuseau: TimeZone) {
        let centre = DeviceActivityCenter()
        if let essai, essai.fin > millis {
            ponctuelle(.essai, debut: essai.fin, fuseau: fuseau, centre: centre)
        } else {
            centre.stopMonitoring([nomActivite(.essai)])
        }
        guard etat.enabled, etat.nombreDeJetons > 0 else {
            centre.stopMonitoring([nomActivite(.fenetre), nomActivite(.minuit), nomActivite(.report),
                                   nomActivite(.seance)])
            return
        }
        quotidienne(.fenetre, debut: etat.windowStart, fin: etat.windowEnd, centre: centre)
        quotidienne(.minuit, debut: 0, fin: Evaluation.intervalleMinimum, centre: centre)
        if etat.snoozedUntil > millis {
            ponctuelle(.report, debut: etat.snoozedUntil, fuseau: fuseau, centre: centre)
        } else {
            centre.stopMonitoring([nomActivite(.report)])
        }
        if let seance = etat.seance, seance.fin > millis {
            ponctuelle(.seance, debut: seance.fin, fuseau: fuseau, centre: centre)
        } else {
            centre.stopMonitoring([nomActivite(.seance)])
        }
    }

    /// Plus aucune activité surveillée.
    static func toutArreter() {
        DeviceActivityCenter().stopMonitoring(ActiviteBarriere.allCases.map { nomActivite($0) })
    }

    // MARK: Aides

    private static func magasin(_ nom: String) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(nom))
    }

    private static func nomActivite(_ activite: ActiviteBarriere) -> DeviceActivityName {
        DeviceActivityName(activite.rawValue)
    }

    /// Une activité de chaque jour, de `debut` à `fin` (minutes depuis minuit) ; une fenêtre de nuit passe minuit.
    /// Laissée telle quelle si le système l'a déjà à ces heures.
    private static func quotidienne(_ activite: ActiviteBarriere, debut: Int, fin: Int, centre: DeviceActivityCenter) {
        let nom = nomActivite(activite)
        let voulueDebut = PilotageBarriere.heureMinute(debut)
        let voulueFin = PilotageBarriere.heureMinute(fin)
        if let actuelle = centre.schedule(for: nom), actuelle.repeats,
           actuelle.intervalStart.hour == voulueDebut.heure, actuelle.intervalStart.minute == voulueDebut.minute,
           actuelle.intervalEnd.hour == voulueFin.heure, actuelle.intervalEnd.minute == voulueFin.minute {
            return
        }
        let horaire = DeviceActivitySchedule(intervalStart: PilotageBarriere.composantesQuotidiennes(debut),
                                             intervalEnd: PilotageBarriere.composantesQuotidiennes(fin),
                                             repeats: true)
        try? centre.startMonitoring(nom, during: horaire)
    }

    /// Une activité d'un seul intervalle, qui commence à `debut` (millisecondes Unix) et dure l'intervalle minimal.
    /// Laissée telle quelle si le système l'a déjà pour ce début.
    private static func ponctuelle(_ activite: ActiviteBarriere, debut: Int64, fuseau: TimeZone,
                                   centre: DeviceActivityCenter) {
        let nom = nomActivite(activite)
        let intervalle = PilotageBarriere.intervallePonctuel(debut: debut)
        let voulu = PilotageBarriere.composantesDate(intervalle.debut, fuseau: fuseau)
        if let actuelle = centre.schedule(for: nom), !actuelle.repeats,
           actuelle.intervalStart.year == voulu.year, actuelle.intervalStart.month == voulu.month,
           actuelle.intervalStart.day == voulu.day, actuelle.intervalStart.hour == voulu.hour,
           actuelle.intervalStart.minute == voulu.minute, actuelle.intervalStart.second == voulu.second {
            return
        }
        let horaire = DeviceActivitySchedule(intervalStart: voulu,
                                             intervalEnd: PilotageBarriere.composantesDate(intervalle.fin, fuseau: fuseau),
                                             repeats: false)
        try? centre.startMonitoring(nom, during: horaire)
    }

    #endif
}
