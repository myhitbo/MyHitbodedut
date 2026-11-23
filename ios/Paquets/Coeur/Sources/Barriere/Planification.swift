// Ce qui remplace la boucle de GateService (toutes les 900 ms) sur iOS : des rendez-vous donnés d'avance au système
// (PORTAGE.md § 2.1.5, § 2.1.6, § 2.1.10) et deux magasins de réglages posés ou levés à chacun d'eux. Une extension ne
// tourne qu'à ces rendez-vous ; l'app, à chaque ouverture et à chaque changement, réécrit l'instantané et refait le
// plan. La règle est ici, sans DeviceActivity ni ManagedSettings, pour être vérifiée sous Linux ; l'app et les
// extensions la traduisent en `DeviceActivitySchedule` et en `ManagedSettingsStore`.

/// Les cinq activités surveillées (§ 2.1.5 : vingt au plus par app).
public enum Activite: String, Sendable, CaseIterable, Codable {
    /// La fenêtre du mode, chaque jour, de `window_start` à `window_end` (de nuit, elle passe minuit).
    case fenetre
    /// Chaque jour de 00:00 à 23:59 : le jour qui commence (un Chabbat, la nuit déjà validée par la séance du soir).
    case minuit
    /// Une fois, à la fin du report : la surveillance réarme.
    case report
    /// Une fois, à la fin d'une séance minutée : le bouclier « en cours » se lève.
    case seance
    /// Une fois, à la fin de l'essai réel : le magasin de l'essai se lève.
    case essai
}

/// Un instant d'un rendez-vous : l'heure et la minute, et le jour pour un rendez-vous unique.
public struct Repere: Sendable, Hashable {
    /// « AAAA-MM-JJ » pour un rendez-vous qui ne se répète pas ; nil pour une heure de chaque jour.
    public var jour: String?
    public var heure: Int
    public var minute: Int

    public init(jour: String? = nil, heure: Int, minute: Int) {
        self.jour = jour
        self.heure = heure
        self.minute = minute
    }

    /// L'heure d'une minute du jour (0 à 1439).
    public init(minutesDuJour: Int) {
        let m = ((minutesDuJour % 1440) + 1440) % 1440
        self.init(heure: m / 60, minute: m % 60)
    }
}

/// Le créneau d'une activité (`DeviceActivitySchedule`).
public struct Creneau: Sendable, Hashable {
    public var debut: Repere
    public var fin: Repere
    public var repete: Bool

    public init(debut: Repere, fin: Repere, repete: Bool) {
        self.debut = debut
        self.fin = fin
        self.repete = repete
    }
}

/// Les deux magasins nommés de réglages (`ManagedSettingsStore(named:)`). Le magasin `seance` du § 2.1.2 est fondu
/// dans `barriere` : le visage (invite ou séance) se choisit à l'affichage, d'après l'instantané (`PlanBouclier.face`),
/// si bien que la règle n'a qu'à dire si les applications sont retenues.
public enum NomMagasin: String, Sendable, CaseIterable {
    case barriere
    case essai
}

/// Ce que chaque magasin doit porter à un instant.
public struct MagasinsVoulus: Sendable, Equatable {
    /// Les applications choisies sont retenues par la barrière : l'invite ou la séance (GateRule.ecran).
    public var barriere: Bool
    /// L'essai réel court.
    public var essai: Bool

    public init(barriere: Bool, essai: Bool) {
        self.barriere = barriere
        self.essai = essai
    }
}

/// Le plan des rendez-vous et des magasins.
public enum Planification {

    /// Ce que les magasins doivent porter à `maintenant`, d'après l'instantané vu avec la boîte.
    public static func voulus(_ etat: Etat, maintenant: Horodatage) -> MagasinsVoulus {
        MagasinsVoulus(barriere: Evaluation.bouclier(etat, maintenant: maintenant) != nil,
                       essai: etat.essaiEnCours(millis: maintenant.millis))
    }

    /// Le bouclier désaccordé (§ 2.1.8) : le magasin `barriere` ne porte pas ce que les extensions, qui n'ont que
    /// l'instantané précédent et la boîte, auraient dû y mettre à `maintenant`. Un changement fait dans l'app (une
    /// séance commencée, un réglage) n'en est pas un : l'instantané précédent ne le connaissait pas encore. Sans
    /// instantané précédent (le premier lancement), rien à reprocher.
    public static func desaccord(ancien: Etat?, evenements: [Evenement], maintenant: Horodatage, barriereActif: Bool) -> Bool {
        guard let ancien else { return false }
        return voulus(ancien.avec(evenements), maintenant: maintenant).barriere != barriereActif
    }

    /// Les activités à surveiller à `maintenant` et leur créneau. Le mode éteint ou sans application ne surveille
    /// rien, sauf l'essai, qui ne dépend que de la sélection. Un rendez-vous unique commence à la minute pleine qui
    /// suit son instant (la règle compte à la minute : réarmer une seconde trop tôt trouverait le report encore en
    /// cours) et dure l'intervalle minimal du système ; passé, il n'est plus demandé.
    public static func plan(_ etat: Etat, maintenant: Horodatage) -> [Activite: Creneau] {
        var plan: [Activite: Creneau] = [:]
        if let essai = etat.essai, essai.fin > maintenant.millis {
            plan[.essai] = unique(essai.fin, maintenant: maintenant)
        }
        guard etat.enabled, etat.nombreDeJetons > 0 else { return plan }
        // Une fenêtre trop courte (venue d'une sauvegarde : l'écran la refuse) est allongée jusqu'au minimum du
        // système ; la règle, elle, garde la vraie fin.
        let duree = Evaluation.dureeFenetre(start: etat.windowStart, end: etat.windowEnd)
        let fin = duree >= Evaluation.intervalleMinimum ? etat.windowEnd : etat.windowStart + Evaluation.intervalleMinimum
        plan[.fenetre] = Creneau(debut: Repere(minutesDuJour: etat.windowStart), fin: Repere(minutesDuJour: fin), repete: true)
        plan[.minuit] = Creneau(debut: Repere(heure: 0, minute: 0), fin: Repere(heure: 23, minute: 59), repete: true)
        if etat.snoozedUntil > maintenant.millis {
            plan[.report] = unique(etat.snoozedUntil, maintenant: maintenant)
        }
        if let seance = Evaluation.activiteSeance(etat, millis: maintenant.millis) {
            plan[.seance] = unique(seance.debut, maintenant: maintenant)
        }
        return plan
    }

    /// Ce qu'il faut arrêter et (re)démarrer pour passer de ce qui est surveillé à ce qui doit l'être, dans l'ordre des
    /// activités : une activité dont le créneau a changé s'arrête puis redémarre ; une activité inchangée n'est pas
    /// touchée (la redémarrer pendant son intervalle le terminerait, puis le recommencerait).
    public static func changements(voulu: [Activite: Creneau], actuel: [Activite: Creneau])
        -> (arreter: [Activite], demarrer: [Activite]) {
        var arreter: [Activite] = []
        var demarrer: [Activite] = []
        for activite in Activite.allCases {
            let v = voulu[activite], a = actuel[activite]
            if v == a { continue }
            if a != nil { arreter.append(activite) }
            if v != nil { demarrer.append(activite) }
        }
        return (arreter, demarrer)
    }

    /// Un rendez-vous unique à `millis` : de la minute pleine qui suit (ou de `millis` s'il tombe sur une minute) à
    /// l'intervalle minimal plus loin, lus dans le fuseau de `maintenant`.
    static func unique(_ millis: Int64, maintenant: Horodatage) -> Creneau {
        let minute: Int64 = 60_000
        let debut = JoursIso.divisionEntiere(millis + minute - 1, minute) * minute
        let fin = debut + Int64(Evaluation.intervalleMinimum) * minute
        return Creneau(debut: repere(debut, maintenant: maintenant), fin: repere(fin, maintenant: maintenant), repete: false)
    }

    private static func repere(_ millis: Int64, maintenant: Horodatage) -> Repere {
        let h = Evaluation.instant(millis, commeMaintenant: maintenant)
        return Repere(jour: h.jour, heure: h.minutes / 60, minute: h.minutes % 60)
    }
}
