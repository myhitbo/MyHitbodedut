#if !SANS_BARRIERE
import Barriere
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// Ce que l'app et les extensions de la barrière partagent pour parler à Temps d'écran (PORTAGE.md § 2.1.2) : les deux
// magasins nommés, la sélection décodée, les boucliers posés ou levés, les rendez-vous de DeviceActivity. Ce fichier est
// compilé dans l'app et dans les extensions Surveillance et BouclierAction (project.yml) ; la règle, elle, est dans
// Barriere (Planification, PlanBouclier), vérifiée sous Linux. Absent de la construction SANS_BARRIERE.

enum TempsEcranCommun {

    // MARK: Les magasins

    static func magasin(_ nom: NomMagasin) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(nom.rawValue))
    }

    /// Le magasin retient-il quelque chose ?
    static func estPose(_ nom: NomMagasin) -> Bool {
        let bouclier = magasin(nom).shield
        return bouclier.applications != nil || bouclier.applicationCategories != nil || bouclier.webDomains != nil
            || bouclier.webDomainCategories != nil
    }

    /// La sélection de Temps d'écran, décodée ; nil sans sélection lisible.
    static func selection(_ fichiers: FichiersBarriere) -> FamilyActivitySelection? {
        guard let enregistree = fichiers.lireSelection() else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: enregistree.jetons)
    }

    /// Pose le bouclier sur les applications, les catégories et les sites choisis (50 applications au plus, § 2.1.3).
    static func poser(_ nom: NomMagasin, selection: FamilyActivitySelection) {
        let store = magasin(nom)
        let applications = selection.applicationTokens
        let categories = selection.categoryTokens
        let sites = selection.webDomainTokens
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = sites.isEmpty ? nil : sites
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }

    static func lever(_ nom: NomMagasin) {
        magasin(nom).clearAllSettings()
    }

    /// Met les magasins d'accord avec ce que la règle veut ; rend les changements faits (le magasin, posé ou levé), pour
    /// le journal de la barrière. Sans sélection lisible, rien ne se pose.
    @discardableResult
    static func appliquer(_ voulus: MagasinsVoulus, fichiers: FichiersBarriere) -> [(nom: NomMagasin, pose: Bool)] {
        var changes: [(nom: NomMagasin, pose: Bool)] = []
        let choisie = selection(fichiers)
        for (nom, veut) in [(NomMagasin.barriere, voulus.barriere), (NomMagasin.essai, voulus.essai)] {
            let pose = estPose(nom)
            if veut && !pose, let choisie {
                poser(nom, selection: choisie)
                changes.append((nom, true))
            } else if !veut && pose {
                lever(nom)
                changes.append((nom, false))
            }
        }
        return changes
    }

    // MARK: Le journal

    /// L'instant présent vu du fuseau du téléphone.
    static func maintenant() -> Horodatage {
        Horodatage(millis: Int64((Date().timeIntervalSince1970 * 1000).rounded(.down)), fuseau: .current)
    }

    /// Ajoute une ligne à la boîte (les extensions) ; une écriture refusée ne change rien d'autre.
    static func noter(_ genre: Evenement.Genre, _ detail: String = "", fichiers: FichiersBarriere,
                      quand: Horodatage = maintenant()) {
        try? fichiers.ajouter(Evenement(quand: quand, genre: genre, detail: detail))
    }

    /// Les poses et les levées faites, en événements.
    static func evenements(_ changes: [(nom: NomMagasin, pose: Bool)], agent: AgentBarriere,
                           quand: Horodatage) -> [Evenement] {
        changes.map { change in
            switch change.nom {
            case .barriere: Evenement(quand: quand, genre: change.pose ? .armee : .levee, detail: agent.rawValue)
            case .essai: Evenement(quand: quand, genre: .essai, detail: change.pose ? Etat.essaiCommence : Etat.essaiFini)
            }
        }
    }

    // MARK: Les rendez-vous

    static func nom(_ activite: Activite) -> DeviceActivityName {
        DeviceActivityName(activite.rawValue)
    }

    /// Le créneau en `DeviceActivitySchedule` : une heure de chaque jour, ou un jour précis pour un rendez-vous unique
    /// (sans le jour, « 23:50 » se lirait aujourd'hui même s'il tombe demain).
    static func calendrier(_ creneau: Creneau) -> DeviceActivitySchedule {
        DeviceActivitySchedule(intervalStart: composantes(creneau.debut), intervalEnd: composantes(creneau.fin),
                               repeats: creneau.repete)
    }

    static func composantes(_ repere: Repere) -> DateComponents {
        var c = DateComponents()
        if let jour = repere.jour {
            let morceaux = jour.split(separator: "-").compactMap { Int($0) }
            if morceaux.count == 3 {
                c.year = morceaux[0]
                c.month = morceaux[1]
                c.day = morceaux[2]
            }
        }
        c.hour = repere.heure
        c.minute = repere.minute
        c.second = 0
        return c
    }

    static func repere(_ c: DateComponents) -> Repere? {
        guard let heure = c.hour, let minute = c.minute else { return nil }
        var jour: String?
        if let annee = c.year, let mois = c.month, let quantieme = c.day {
            jour = String(format: "%04d-%02d-%02d", annee, mois, quantieme)
        }
        return Repere(jour: jour, heure: heure, minute: minute)
    }

    /// Ce qui est surveillé maintenant, relu du système.
    static func surveille(_ centre: DeviceActivityCenter = DeviceActivityCenter()) -> [Activite: Creneau] {
        var resultat: [Activite: Creneau] = [:]
        for nom in centre.activities {
            guard let activite = Activite(rawValue: nom.rawValue), let calendrier = centre.schedule(for: nom),
                  let debut = repere(calendrier.intervalStart), let fin = repere(calendrier.intervalEnd) else { continue }
            resultat[activite] = Creneau(debut: debut, fin: fin, repete: calendrier.repeats)
        }
        return resultat
    }

    /// Met la surveillance d'accord avec le plan : n'arrête et ne redémarre que ce qui a changé. Rend les activités
    /// démarrées, et celles que le système a refusées.
    @discardableResult
    static func planifier(_ plan: [Activite: Creneau]) -> (demarrees: [Activite], refusees: [Activite]) {
        let centre = DeviceActivityCenter()
        let changements = Planification.changements(voulu: plan, actuel: surveille(centre))
        if !changements.arreter.isEmpty {
            centre.stopMonitoring(changements.arreter.map(nom))
        }
        var demarrees: [Activite] = []
        var refusees: [Activite] = []
        for activite in changements.demarrer {
            guard let creneau = plan[activite] else { continue }
            do {
                try centre.startMonitoring(nom(activite), during: calendrier(creneau))
                demarrees.append(activite)
            } catch {
                refusees.append(activite)
            }
        }
        return (demarrees, refusees)
    }

    /// Arrête une activité (un rendez-vous unique passé, l'essai fermé).
    static func arreter(_ activite: Activite) {
        DeviceActivityCenter().stopMonitoring([nom(activite)])
    }

    /// Le rendez-vous du report demandé depuis le bouclier : il commence à la fin du report (§ 2.1.6).
    static func planifierReport(_ etat: Etat, maintenant: Horodatage) {
        guard let creneau = Planification.plan(etat, maintenant: maintenant)[.report] else { return }
        let centre = DeviceActivityCenter()
        centre.stopMonitoring([nom(.report)])
        try? centre.startMonitoring(nom(.report), during: calendrier(creneau))
    }
}
#endif
