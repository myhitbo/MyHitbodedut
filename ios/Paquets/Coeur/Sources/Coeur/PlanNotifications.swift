import Foundation

/// Le planificateur unique des notifications locales (PORTAGE.md § 2.2.2) : `(état, maintenant) → notifications`.
///
/// Android pose une alarme par sorte et décide quand elle sonne (`ReminderReceiver`, `ChabbatAlerteReceiver`,
/// `LevanaAlerteReceiver`, `VolAlerteReceiver`). iOS ne réveille pas l'app pour une notification locale et n'en
/// garde que 64 en attente : tout se décide ici, d'avance, avec les mêmes règles, chaque sorte dans sa part du
/// budget. L'app repasse le plan à chaque ouverture, séance inscrite ou commencée, changement de réglage, de lieu,
/// d'heure ou de fuseau. Les textes sont ceux des chaînes d'Android (`reminder_*`, `chabbat_alerte_*`,
/// `levana_rappel_*`) ; l'app les pose.
public enum PlanNotifications {

    /// Les notifications en attente qu'iOS garde (Vérifié).
    public static let limite = 64
    /// Ce qui reste libre sous la limite.
    public static let marge = 8
    /// Les rappels se posent dix jours d'avance ; sans ouverture ni rafraîchissement, ils s'arrêtent ensuite.
    public static let horizonJours = 10

    public enum Sorte: String, Sendable, CaseIterable {
        case rappel, rappelReporte = "rappel_reporte", finSeance = "fin_seance", chabbat, levana, vol

        /// La part du budget : trente rappels (dix jours à trois heures), quatre vendredis, six soirs de Levana,
        /// quatorze rappels du vol, un rappel reporté et une fin de séance ; huit de marge.
        public var part: Int {
            switch self {
            case .rappel: 30
            case .rappelReporte: 1
            case .finSeance: 1
            case .chabbat: 4
            case .levana: 6
            case .vol: 14
            }
        }
    }

    /// Une notification à poser.
    public struct Prevue: Sendable, Equatable {
        public let sorte: Sorte
        public let quand: DateHeureZonee
        /// Le soir de Birkat haLevana (le titre de la notification).
        public let soir: LevanaAlerte.Soir?
        /// Le rappel du vol.
        public let vol: VolRappels.Rappel?

        public init(sorte: Sorte, quand: DateHeureZonee, soir: LevanaAlerte.Soir? = nil, vol: VolRappels.Rappel? = nil) {
            self.sorte = sorte
            self.quand = quand
            self.soir = soir
            self.vol = vol
        }

        /// L'identifiant de la demande : le même d'un plan à l'autre tant que l'instant ne change pas.
        public var identifiant: String {
            var id = "\(sorte.rawValue)-\(quand.millis)"
            if let vol { id += "-\(vol.type.nom)" }
            return id
        }
    }

    /// La séance inscrite comme commencée (`session_started_at`, `session_ends_at`, `session_target`).
    public struct Seance: Sendable, Equatable {
        public let debut: Int64
        public let fin: Int64
        public let duree: Int

        public init(debut: Int64, fin: Int64, duree: Int) {
            self.debut = debut
            self.fin = fin
            self.duree = duree
        }
    }

    /// L'état d'où le plan se calcule.
    public struct Entree: Sendable {
        /// Maintenant, dans le fuseau du téléphone.
        public var maintenant: DateHeureZonee
        public var reglages: Reglages
        /// Les journées faites du journal.
        public var joursFaits: Set<JourCivil>
        public var seance: Seance?
        /// `Store.lieuAlertes` : le lieu des zmanim, sauf une position périmée par un voyage.
        public var lieuAlertes: Zmanim.Lieu?
        /// `Store.volRappels`.
        public var vol: [VolRappels.Rappel]

        public init(maintenant: DateHeureZonee, reglages: Reglages, joursFaits: Set<JourCivil> = [], seance: Seance? = nil,
                    lieuAlertes: Zmanim.Lieu? = nil, vol: [VolRappels.Rappel] = []) {
            self.maintenant = maintenant
            self.reglages = reglages
            self.joursFaits = joursFaits
            self.seance = seance
            self.lieuAlertes = lieuAlertes
            self.vol = vol
        }
    }

    /// Le plan, sur les zmanim du lieu des alertes et le calendrier de `Holidays`.
    public static func planifier(_ e: Entree) -> [Prevue] {
        let r = e.reglages
        let lieu = e.lieuAlertes
        let fuseauLevana = lieu.flatMap { Fuseau($0.fuseau) } ?? e.maintenant.fuseau
        return planifier(e, fuseauLevana: fuseauLevana,
                         allumage: { d in lieu.flatMap { ChabbatAlerte.allumage($0, d, minutes: r.allumage) } },
                         soirLevana: { LevanaAlerte.heure($0, lieu: lieu, fuseau: fuseauLevana) },
                         exempte: { Pratique.exempte($0, r) },
                         veilleDeRepos: { r.pauseShabbat && Holidays.isEveOfRestDay($0, inIsrael: r.enIsrael) })
    }

    /// Le plan, les heures et le calendrier donnés : `allumage` (nil sans lieu ni allumage ce jour-là), `soirLevana`
    /// (l'heure du rappel un soir, vue de `fuseauLevana`), `exempte` (`Store.isExempt`) et `veilleDeRepos`
    /// (`Store.isEveOfRestDay`). Trié par instant, jamais plus de `limite - marge`.
    public static func planifier(_ e: Entree, fuseauLevana: Fuseau, allumage: (JourCivil) -> DateHeureZonee?,
                                 soirLevana: (JourCivil) -> DateHeureZonee, exempte: (JourCivil) -> Bool,
                                 veilleDeRepos: (JourCivil) -> Bool) -> [Prevue] {
        let r = e.reglages
        var plan = rappels(e, exempte: exempte, veilleDeRepos: veilleDeRepos)
        if let s = e.seance, s.duree != SessionRule.ouverte, s.fin > e.maintenant.millis {
            plan.append(Prevue(sorte: .finSeance, quand: DateHeureZonee(millis: s.fin, fuseau: e.maintenant.fuseau)))
        }
        if e.lieuAlertes != nil {
            for a in ChabbatAlerte.suivantes(e.maintenant, nombre: Sorte.chabbat.part, allumage: allumage) {
                plan.append(Prevue(sorte: .chabbat, quand: a))
            }
        }
        if r.levanaRappel {
            let depuis = DateHeureZonee(millis: e.maintenant.millis, fuseau: fuseauLevana)
            for (quand, soir) in LevanaAlerte.suivants(depuis, nombre: Sorte.levana.part, usage: LevanaAlerte.usage(r),
                                                       heure: soirLevana) {
                plan.append(Prevue(sorte: .levana, quand: quand, soir: soir))
            }
        }
        if r.volRappelsActifs {
            let vus = e.vol.enumerated()
                .filter { $0.element.instant > r.volRappelVu && $0.element.instant > e.maintenant.millis }
                .sorted { ($0.element.instant, $0.element.type.rawValue, $0.offset) < ($1.element.instant, $1.element.type.rawValue, $1.offset) }
                .prefix(Sorte.vol.part)
            for (_, v) in vus {
                plan.append(Prevue(sorte: .vol, quand: DateHeureZonee(millis: v.instant, fuseau: e.maintenant.fuseau), vol: v))
            }
        }
        let rang = Dictionary(uniqueKeysWithValues: Sorte.allCases.enumerated().map { ($0.element, $0.offset) })
        let trie = plan.enumerated().sorted {
            ($0.element.quand.millis, rang[$0.element.sorte] ?? 0, $0.offset) < ($1.element.quand.millis, rang[$1.element.sorte] ?? 0, $1.offset)
        }
        return Array(trie.map { $0.element }.prefix(limite - marge))
    }

    /// Les rappels de hitbodedout : chaque heure choisie des dix jours à venir, trente au plus, là où
    /// `ReminderRule.doitSonner` le permet à l'heure dite (jour fait, jour de repos, veille après midi) et jamais
    /// pendant la séance en cours ; puis le rappel reporté par « Plus tard ».
    static func rappels(_ e: Entree, exempte: (JourCivil) -> Bool, veilleDeRepos: (JourCivil) -> Bool) -> [Prevue] {
        let r = e.reglages
        guard r.rappelActif else { return [] }
        func sonne(_ t: DateHeureZonee) -> Bool {
            let jour = t.jour
            guard ReminderRule.doitSonner(maintenant: t.minutesDuJour, faite: e.joursFaits.contains(jour),
                                          repos: exempte(jour), veilleDeRepos: veilleDeRepos(jour), coucher: nil)
            else { return false }
            // Pas de rappel pendant une hitbodedout : elle est en train de se faire.
            if let s = e.seance, SessionRule.enCours(debut: s.debut, fin: s.fin, duree: s.duree, maintenant: t.millis) {
                return false
            }
            return true
        }
        let heures = ReminderRule.propres(r.rappels)
        var vus = Set<Int64>()
        var liste: [Prevue] = []
        jours: for k in 0..<horizonJours {
            let jour = e.maintenant.jour.plus(jours: k)
            for h in heures {
                let t = DateHeureZonee(DateHeure(jour, heure: h / 60, minute: h % 60), fuseau: e.maintenant.fuseau)
                guard t > e.maintenant, vus.insert(t.millis).inserted, sonne(t) else { continue }
                liste.append(Prevue(sorte: .rappel, quand: t))
                if liste.count >= Sorte.rappel.part { break jours }
            }
        }
        // Le report passe seulement s'il tombe avant le prochain rappel réglé : sur Android, le rappel qui sonne
        // d'abord consomme le report (`Reminder.reschedule`, `ReminderReceiver`).
        let reporte = r.rappelReporteJusqua
        if reporte > e.maintenant.millis {
            let prochain = ReminderRule.prochainDeclenchement(e.maintenant, heures: r.rappels)
            let t = DateHeureZonee(millis: reporte, fuseau: e.maintenant.fuseau)
            if prochain.map({ reporte < $0.millis }) ?? true, sonne(t) {
                liste.append(Prevue(sorte: .rappelReporte, quand: t))
            }
        }
        return liste
    }

    /// « Plus tard » sur la notification du rappel : le report d'une demi-heure (`Reminder.snooze`).
    public static func reporterRappel(_ r: inout Reglages, maintenant: Int64) {
        r.rappelReporteJusqua = maintenant + Int64(ReminderRule.reportMinutes) * 60_000
    }
}
