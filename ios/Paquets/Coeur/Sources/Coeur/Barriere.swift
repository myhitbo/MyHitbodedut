import Foundation

/// « Je suis avec Hachem » sans Temps d'écran : l'état et sa raison (`GateStatus.kt`, plus les cinq pannes propres
/// à iOS du § 2.1.8 de PORTAGE.md), la fenêtre et le report (`Store.inWindow`, `Store.snooze`, `isSnoozed`), les
/// jours exemptés calculés d'avance pour l'extension de surveillance (§ 2.1.7), l'instantané `etat.json` qu'elle
/// lit et la boîte `boite.jsonl` où les extensions écrivent (§ 3.2). Aucune API d'Apple : ce que le système sait
/// (autorisation, sélection, activités inscrites, magasin actif, dernier réveil) arrive en argument.
///
/// Gardé dans `Coeur` ; ce qui sert aux extensions (`Instantane`, `etatExtension`, `Evenement`, `Boite`) ne touche ni
/// le calendrier ni le journal, et pourra passer dans le petit paquet `Barriere` du § 7.1.
/// Jugé par `Tests/Vecteurs/barriere.json` (tools/vecteurs_ios/VecteursBarriere.kt).
public enum Barriere {

    // MARK: États

    /// `GateStatus.colorOf` : vert quand la barrière veille, orange quand une action est attendue, neutre sinon.
    public enum Couleur: String, Sendable, CaseIterable {
        case marque = "brand", attention = "warning", discrete = "muted"
    }

    /// `GateState`, puis les pannes silencieuses d'iOS.
    public enum Etat: String, Sendable, CaseIterable {
        /// Tout est en place : ouvrir une application choisie montre le bouclier.
        case veille = "ARMED"
        case autorisationsManquantes = "MISSING_PERMISSIONS"
        case desactivee = "DISABLED"
        case aucuneApplication = "NO_APPS_SELECTED"
        case dejaFaite = "ALREADY_DONE"
        case jourExempte = "EXEMPT_DAY"
        case reportee = "SNOOZED"
        case horsFenetre = "OUTSIDE_WINDOW"
        /// Le mode est allumé mais iOS a retiré l'accès à Temps d'écran (il lève alors tout sans prévenir l'app).
        case autorisationRetiree = "AUTORISATION_RETIREE"
        /// Les jetons choisis ne valent plus rien (restauration, autre iPhone).
        case selectionARefaire = "SELECTION_A_REFAIRE"
        /// Les activités `fenetre` et `minuit` ne sont pas inscrites auprès du système.
        case surveillanceAbsente = "SURVEILLANCE_ABSENTE"
        /// La règle dit « veille » et le magasin `barriere` est inactif, ou l'inverse : l'app corrige d'elle-même.
        case bouclierDesaccorde = "BOUCLIER_DESACCORDE"
        /// L'extension de surveillance ne s'est pas réveillée depuis plus d'un jour.
        case surveillanceMuette = "SURVEILLANCE_MUETTE"

        public var propreAIOS: Bool {
            switch self {
            case .autorisationRetiree, .selectionARefaire, .surveillanceAbsente, .bouclierDesaccorde, .surveillanceMuette: true
            default: false
            }
        }

        /// `GateStatus.titleOf`. Les états propres à iOS ont des clés neuves, à écrire dans les chaînes d'iOS avec
        /// l'écran (tâche 28).
        public var cleTitre: String { "gate_\(racine)_title" }

        /// `GateStatus.detailOf`, la clé ; `Barriere.detail` donne les arguments.
        public var cleDetail: String { "gate_\(racine)_detail" }

        private var racine: String {
            switch self {
            case .veille: "armed"
            case .autorisationsManquantes: "permissions"
            case .desactivee: "disabled"
            case .aucuneApplication: "no_apps"
            case .dejaFaite: "done"
            case .jourExempte: "exempt"
            case .reportee: "snoozed"
            case .horsFenetre: "window"
            case .autorisationRetiree: "ios_autorisation_retiree"
            case .selectionARefaire: "ios_selection"
            case .surveillanceAbsente: "ios_surveillance_absente"
            case .bouclierDesaccorde: "ios_bouclier"
            case .surveillanceMuette: "ios_surveillance_muette"
            }
        }

        public var couleur: Couleur {
            switch self {
            case .veille, .dejaFaite: .marque
            case .autorisationsManquantes, .aucuneApplication, .autorisationRetiree, .selectionARefaire,
                 .surveillanceAbsente, .surveillanceMuette: .attention
            default: .discrete
            }
        }
    }

    /// Le détail d'un état : la clé de la chaîne et ses arguments, dans l'ordre de `GateStatus.detailOf`. Le détail
    /// de « veille » est un pluriel sur le nombre d'applications (une catégorie compte pour une).
    public struct Detail: Sendable, Equatable {
        public let cle: String
        /// Le nombre qui choisit la forme du pluriel ; nil pour une chaîne simple.
        public let quantite: Int?
        public let arguments: [String]
    }

    public static func detail(_ etat: Etat, applications: Int, debut: Int, fin: Int) -> Detail {
        switch etat {
        case .veille: Detail(cle: etat.cleDetail, quantite: applications, arguments: ["\(applications)", heure(fin)])
        case .horsFenetre: Detail(cle: etat.cleDetail, quantite: nil, arguments: [heure(debut), heure(fin)])
        default: Detail(cle: etat.cleDetail, quantite: nil, arguments: [])
        }
    }

    /// `Store.formatMinutes` : « 06:00 », « 23:59 ».
    public static func heure(_ minutes: Int) -> String {
        func deux(_ n: Int) -> String { n >= 0 && n < 10 ? "0\(n)" : "\(n)" }
        return "\(deux((minutes / 60) % 24)):\(deux(minutes % 60))"
    }

    // MARK: Évaluation

    /// `AuthorizationCenter.authorizationStatus` : non demandée, refusée, accordée.
    public enum Autorisation: String, Sendable, CaseIterable {
        case nonDemandee, refusee, accordee
    }

    /// Les activités que l'app inscrit auprès de `DeviceActivityCenter` (cinq des vingt permises, § 2.1.5).
    public enum Activite: String, Sendable, CaseIterable {
        case fenetre, minuit, report, seance, essai
    }

    /// Les deux activités répétées chaque jour : sans elles, la barrière ne s'arme ni ne se lève plus.
    public static let activitesPermanentes: Set<Activite> = [.fenetre, .minuit]

    /// Au-delà d'un jour sans réveil de l'extension, la surveillance est dite muette.
    public static let silenceMax: Int64 = 24 * 3_600_000

    /// Ce que le système dit, lu par l'app (jamais par `Coeur`).
    public struct Systeme: Sendable, Equatable {
        public var autorisation: Autorisation
        /// Les jetons de la sélection : applications, catégories et sites, une catégorie comptant pour un.
        public var applications: Int
        /// Les jetons sont-ils encore valables sur cet appareil ?
        public var selectionValide: Bool
        /// `DeviceActivityCenter.activities`.
        public var activites: Set<Activite>
        /// `ManagedSettingsStore(named: barriere).isActive`. L'essai et la séance ont leur propre magasin.
        public var magasinActif: Bool
        /// Le dernier réveil de l'extension de surveillance, écrit dans la boîte (millisecondes Unix).
        public var dernierReveil: Int64?
        /// Quand l'app a inscrit la surveillance : avant le premier réveil, c'est de là que court le silence.
        public var inscription: Int64?

        public init(autorisation: Autorisation = .accordee, applications: Int = 0, selectionValide: Bool = true,
                    activites: Set<Activite> = Barriere.activitesPermanentes, magasinActif: Bool = false,
                    dernierReveil: Int64? = nil, inscription: Int64? = nil) {
            self.autorisation = autorisation
            self.applications = applications
            self.selectionValide = selectionValide
            self.activites = activites
            self.magasinActif = magasinActif
            self.dernierReveil = dernierReveil
            self.inscription = inscription
        }
    }

    /// Ce qui décide de l'état, déjà constaté : la règle se lit d'un coup d'œil et se teste sans calendrier.
    public struct Constat: Sendable, Equatable {
        public var autorisation: Autorisation
        public var modeActif: Bool
        public var applications: Int
        public var fenetreFaite: Bool
        public var jourExempte: Bool
        public var reportee: Bool
        public var dansFenetre: Bool
        public var selectionValide: Bool
        public var surveillanceInscrite: Bool
        public var surveillanceMuette: Bool
        public var magasinActif: Bool

        public init(autorisation: Autorisation = .accordee, modeActif: Bool = true, applications: Int = 1,
                    fenetreFaite: Bool = false, jourExempte: Bool = false, reportee: Bool = false,
                    dansFenetre: Bool = true, selectionValide: Bool = true, surveillanceInscrite: Bool = true,
                    surveillanceMuette: Bool = false, magasinActif: Bool = true) {
            self.autorisation = autorisation
            self.modeActif = modeActif
            self.applications = applications
            self.fenetreFaite = fenetreFaite
            self.jourExempte = jourExempte
            self.reportee = reportee
            self.dansFenetre = dansFenetre
            self.selectionValide = selectionValide
            self.surveillanceInscrite = surveillanceInscrite
            self.surveillanceMuette = surveillanceMuette
            self.magasinActif = magasinActif
        }
    }

    /// `GateStatus.evaluate`, ligne pour ligne et dans le même ordre : les huit états d'Android.
    public static func evaluerCommeAndroid(autorisee: Bool, modeActif: Bool, applications: Int, fenetreFaite: Bool,
                                           jourExempte: Bool, reportee: Bool, dansFenetre: Bool) -> Etat {
        if !autorisee { return .autorisationsManquantes }
        if !modeActif { return .desactivee }
        if applications == 0 { return .aucuneApplication }
        if fenetreFaite { return .dejaFaite }
        if jourExempte { return .jourExempte }
        if reportee { return .reportee }
        if !dansFenetre { return .horsFenetre }
        return .veille
    }

    /// L'état sur iOS : l'ordre d'Android, les pannes d'iOS glissées là où elles empêchent la suite. L'autorisation
    /// manque : « retirée » si le mode est allumé (il ne s'allume qu'autorisé), « manquante » sinon. Puis la
    /// configuration (mode, sélection, surveillance), puis la règle du jour ; enfin, si le magasin ne dit pas ce que
    /// la règle dit, « désaccordé ».
    public static func evaluer(_ c: Constat) -> Etat {
        if c.autorisation != .accordee { return c.modeActif ? .autorisationRetiree : .autorisationsManquantes }
        if !c.modeActif { return .desactivee }
        if c.applications == 0 { return .aucuneApplication }
        if !c.selectionValide { return .selectionARefaire }
        if !c.surveillanceInscrite { return .surveillanceAbsente }
        if c.surveillanceMuette { return .surveillanceMuette }
        let regle = evaluerCommeAndroid(autorisee: true, modeActif: true, applications: c.applications,
                                        fenetreFaite: c.fenetreFaite, jourExempte: c.jourExempte, reportee: c.reportee,
                                        dansFenetre: c.dansFenetre)
        if c.magasinActif != (regle == .veille) { return .bouclierDesaccorde }
        return regle
    }

    /// Ce que la règle demande au magasin `barriere` : actif quand elle dit « veille », inactif sinon. C'est ainsi que
    /// l'app corrige « désaccordé ».
    public static func magasinAttendu(_ c: Constat) -> Bool {
        guard c.autorisation == .accordee, c.selectionValide else { return false }
        return evaluerCommeAndroid(autorisee: true, modeActif: c.modeActif, applications: c.applications,
                                   fenetreFaite: c.fenetreFaite, jourExempte: c.jourExempte, reportee: c.reportee,
                                   dansFenetre: c.dansFenetre) == .veille
    }

    /// Le constat, ici et maintenant (`maintenant` à l'heure du téléphone) : le journal, les réglages et le système.
    public static func constater(_ d: Donnees, maintenant: DateHeureZonee, systeme s: Systeme,
                                 exempte: (JourCivil) -> Bool) -> Constat {
        let r = d.reglages
        return Constat(autorisation: s.autorisation, modeActif: r.modeBarriere, applications: s.applications,
                       fenetreFaite: fenetreFaite(d, maintenant: maintenant), jourExempte: exempte(maintenant.jour),
                       reportee: reportee(jusqua: r.reporteJusqua, maintenant: maintenant.millis),
                       dansFenetre: dansFenetre(debut: r.debutFenetre, fin: r.finFenetre, minutes: maintenant.minutesDuJour),
                       selectionValide: s.selectionValide,
                       surveillanceInscrite: s.activites.isSuperset(of: activitesPermanentes),
                       surveillanceMuette: muette(dernierReveil: s.dernierReveil, inscription: s.inscription,
                                                  maintenant: maintenant.millis),
                       magasinActif: s.magasinActif)
    }

    /// Le constat, les jours exemptés selon `Store.isExempt` (pause, Chabbat et Yom Tov).
    public static func constater(_ d: Donnees, maintenant: DateHeureZonee, systeme: Systeme) -> Constat {
        constater(d, maintenant: maintenant, systeme: systeme) { Pratique.exempte($0, d.reglages) }
    }

    /// L'état, ici et maintenant.
    public static func etat(_ d: Donnees, maintenant: DateHeureZonee, systeme: Systeme) -> Etat {
        evaluer(constater(d, maintenant: maintenant, systeme: systeme))
    }

    /// Aucun réveil de l'extension depuis plus d'un jour (depuis l'inscription, s'il n'y en a jamais eu).
    public static func muette(dernierReveil: Int64?, inscription: Int64?, maintenant: Int64) -> Bool {
        guard let depuis = [dernierReveil, inscription].compactMap({ $0 }).max() else { return false }
        return maintenant - depuis > silenceMax
    }

    /// `Store.fenetreFaite(context)` : l'instant que couvre la dernière séance (`seance_faite_a`), vu du fuseau du
    /// téléphone, et les journées faites du journal.
    public static func fenetreFaite(_ d: Donnees, maintenant: DateHeureZonee) -> Bool {
        let t = d.reglages.faiteA
        let faitA = t > 0 ? maintenant.fuseau.dateHeure(millis: t) : nil
        let jours = d.journal.jours
        return Pratique.fenetreFaite(debut: d.reglages.debutFenetre, fin: d.reglages.finFenetre,
                                     maintenant: maintenant.civile, faitA: faitA) { jours[$0]?.faite == true }
    }

    // MARK: Fenêtre et report

    /// `Store.inWindow` : `minutes` (depuis minuit) dans la fenêtre, de nuit comprise (21:00–02:00). Les bornes sont
    /// prises telles quelles ; `debut == fin` ne couvre rien.
    public static func dansFenetre(debut: Int, fin: Int, minutes: Int) -> Bool {
        debut <= fin ? minutes >= debut && minutes < fin : minutes >= debut || minutes < fin
    }

    /// La durée de la fenêtre en minutes, de nuit comprise ; 0 si elle ne couvre rien.
    public static func dureeFenetre(debut: Int, fin: Int) -> Int {
        Kotlin.floorMod(fin - debut, 24 * 60)
    }

    /// Un intervalle de `DeviceActivitySchedule` dure quinze minutes au moins : l'écran refuse une fenêtre plus courte.
    public static let dureeMinimale = 15

    public static func fenetreAcceptee(debut: Int, fin: Int) -> Bool {
        dureeFenetre(debut: debut, fin: fin) >= dureeMinimale
    }

    /// Les durées de report proposées par l'écran des réglages (`SettingsActivity`, `pickMinutes`).
    public static let durees = [5, 10, 15, 30, 60]

    /// `Store.isSnoozed`.
    public static func reportee(jusqua: Int64, maintenant: Int64) -> Bool { jusqua > maintenant }

    /// `Store.snooze` : « Plus tard » reporte de la durée réglée, en temps d'horloge.
    public static func reporter(_ r: inout Reglages, maintenant: Int64) {
        r.reporteJusqua = maintenant + Int64(r.report) * 60_000
    }

    /// `Store.clearSnooze`.
    public static func leverReport(_ r: inout Reglages) { r.reporteJusqua = 0 }

    /// Une heure du jour, pour un intervalle répété chaque jour.
    public struct Horaire: Sendable, Equatable {
        public let heure: Int
        public let minute: Int

        public init(minutes: Int) {
            let m = Kotlin.floorMod(minutes, 24 * 60)
            heure = m / 60
            minute = m % 60
        }
    }

    /// Un intervalle répété chaque jour : `fenetre` et `minuit`.
    public struct Plage: Sendable, Equatable {
        public let debut: Horaire
        public let fin: Horaire
    }

    /// Un intervalle qui n'a lieu qu'une fois : `report`, `seance`, `essai`. Heures civiles du fuseau du téléphone.
    public struct Intervalle: Sendable, Equatable {
        public let debut: DateHeure
        public let fin: DateHeure
    }

    /// L'activité `fenetre` : de `window_start` à `window_end`, chaque jour.
    public static func plageFenetre(_ r: Reglages) -> Plage {
        Plage(debut: Horaire(minutes: r.debutFenetre), fin: Horaire(minutes: r.finFenetre))
    }

    /// L'activité `minuit` : elle réévalue chaque jour à 00:00 (fenêtre de nuit, Chabbat qui commence).
    public static let plageMinuit = Plage(debut: Horaire(minutes: 0), fin: Horaire(minutes: dureeMinimale))

    /// Une activité dont le **début** est l'instant voulu (fin du report, de la séance, de l'essai) : arrondi à la
    /// minute suivante, pour que la réévaluation ne tombe jamais un instant trop tôt, et la fin quinze minutes plus
    /// tard, la durée minimale (§ 2.1.6).
    public static func intervalle(a instant: Int64, fuseau: Fuseau) -> Intervalle {
        let minute: Int64 = 60_000
        let reste = ((instant % minute) + minute) % minute
        let debut = reste == 0 ? instant : instant - reste + minute
        return Intervalle(debut: fuseau.dateHeure(millis: debut),
                          fin: fuseau.dateHeure(millis: debut + Int64(dureeMinimale) * minute))
    }

    /// L'essai réel : deux minutes de bouclier « APERÇU, AUCUN EFFET ».
    public static let dureeEssai: Int64 = 2 * 60_000

    // MARK: Jours exemptés, pour l'extension

    /// Deux années de jours à venir, aujourd'hui compris.
    public static let horizonJours = 731

    /// La liste que l'extension consulte au lieu du calendrier : les jours exemptés de `depuis` jusqu'à l'horizon,
    /// plus les jours en pause au-delà ; triés.
    public static func joursExemptes(depuis: JourCivil, reglages: Reglages, jours: Int = horizonJours,
                                     exempte: (JourCivil) -> Bool) -> [JourCivil] {
        var resultat = Set((0..<max(jours, 0)).map { depuis.plus(jours: $0) }.filter(exempte))
        for iso in reglages.joursPause {
            if let j = JourCivil(iso: iso), !(j < depuis) { resultat.insert(j) }
        }
        return resultat.sorted()
    }

    public static func joursExemptes(depuis: JourCivil, reglages: Reglages, jours: Int = horizonJours) -> [JourCivil] {
        joursExemptes(depuis: depuis, reglages: reglages, jours: jours) { Pratique.exempte($0, reglages) }
    }

    // MARK: L'instantané de l'extension (etat.json)

    /// Ce que l'app écrit pour les extensions dans `barriere/etat.json` : de quoi décider sans journal ni calendrier.
    public struct Instantane: Sendable, Equatable {
        public var ecritLe: Int64
        public var modeActif: Bool
        public var applications: Int
        public var debut: Int
        public var fin: Int
        public var report: Int
        public var reporteJusqua: Int64
        public var faitA: Int64
        /// Les journées faites parmi la veille et le jour même (la fenêtre de nuit regarde la veille).
        public var joursFaits: [JourCivil]
        public var joursExemptes: [JourCivil]
        /// Le dernier jour que la liste couvre ; au-delà, le samedi reste exempté si Chabbat l'est.
        public var exemptesJusqua: JourCivil
        public var chabbat: Bool
        public var serie: Int

        public static let version = 1

        public init(ecritLe: Int64, modeActif: Bool, applications: Int, debut: Int, fin: Int, report: Int,
                    reporteJusqua: Int64, faitA: Int64, joursFaits: [JourCivil], joursExemptes: [JourCivil],
                    exemptesJusqua: JourCivil, chabbat: Bool, serie: Int) {
            self.ecritLe = ecritLe
            self.modeActif = modeActif
            self.applications = applications
            self.debut = debut
            self.fin = fin
            self.report = report
            self.reporteJusqua = reporteJusqua
            self.faitA = faitA
            self.joursFaits = joursFaits
            self.joursExemptes = joursExemptes
            self.exemptesJusqua = exemptesJusqua
            self.chabbat = chabbat
            self.serie = serie
        }

        public var objet: ObjetJSON {
            ObjetJSON([
                ("version", .entier(Int64(Instantane.version))), ("ecrit_le", .entier(ecritLe)),
                ("mode", .booleen(modeActif)), ("applications", .entier(Int64(applications))),
                ("window_start", .entier(Int64(debut))), ("window_end", .entier(Int64(fin))),
                ("snooze_minutes", .entier(Int64(report))), ("snoozed_until", .entier(reporteJusqua)),
                ("seance_faite_a", .entier(faitA)), ("jours_faits", .tableau(joursFaits.map { .chaine($0.iso) })),
                ("jours_exemptes", .tableau(joursExemptes.map { .chaine($0.iso) })),
                ("exemptes_jusqua", .chaine(exemptesJusqua.iso)), ("pause_shabbat", .booleen(chabbat)),
                ("serie", .entier(Int64(serie))),
            ])
        }

        /// La relecture, tolérante : nil si le fichier n'est pas un instantané lisible (l'extension ne retient alors
        /// rien plutôt que de retenir à tort).
        public init?(_ o: ObjetJSON) {
            guard o.entier("version") == Instantane.version, let jusqua = JourCivil(iso: o.texte("exemptes_jusqua"))
            else { return nil }
            func jours(_ cle: String) -> [JourCivil] {
                let t = o.tableau(cle) ?? []
                return t.indices.compactMap { JourCivil(iso: t.texte($0)) }
            }
            self.init(ecritLe: o.long("ecrit_le"), modeActif: o.booleen("mode"), applications: o.entier("applications"),
                      debut: o.entier("window_start", defaut: 6 * 60), fin: o.entier("window_end", defaut: 11 * 60),
                      report: o.entier("snooze_minutes", defaut: 15), reporteJusqua: o.long("snoozed_until"),
                      faitA: o.long("seance_faite_a"), joursFaits: jours("jours_faits"),
                      joursExemptes: jours("jours_exemptes"), exemptesJusqua: jusqua,
                      chabbat: o.booleen("pause_shabbat", defaut: true), serie: o.entier("serie"))
        }

        /// L'instantané mis à jour des événements de la boîte que l'app n'a pas encore versés, dans l'ordre :
        /// « Je l'ai déjà faite » inscrit la journée et lève le report (`Store.addSession(0)`), « Plus tard » pose
        /// le report.
        public func avec(_ evenements: [Evenement], fuseau: Fuseau) -> Instantane {
            var i = self
            for e in Barriere.chronologique(evenements) {
                switch e.sorte {
                case .dejaFaite:
                    let jour = fuseau.jour(millis: e.instant)
                    if !i.joursFaits.contains(jour) { i.joursFaits.append(jour) }
                    i.faitA = max(i.faitA, e.instant)
                    i.reporteJusqua = 0
                case .report:
                    if let jusqua = e.jusqua { i.reporteJusqua = jusqua }
                case .commencer, .reveil:
                    break
                }
            }
            return i
        }
    }

    /// L'instantané que l'app écrit à `maintenant` (heure du téléphone).
    public static func instantane(_ d: Donnees, maintenant: DateHeureZonee, applications: Int, serie: Int,
                                  exempte: (JourCivil) -> Bool) -> Instantane {
        let r = d.reglages
        let aujourdhui = maintenant.jour
        let faits = [aujourdhui.plus(jours: -1), aujourdhui].filter { d.journal.jours[$0]?.faite == true }
        return Instantane(ecritLe: maintenant.millis, modeActif: r.modeBarriere, applications: applications,
                          debut: r.debutFenetre, fin: r.finFenetre, report: r.report, reporteJusqua: r.reporteJusqua,
                          faitA: r.faiteA, joursFaits: faits,
                          joursExemptes: joursExemptes(depuis: aujourdhui, reglages: r, exempte: exempte),
                          exemptesJusqua: aujourdhui.plus(jours: horizonJours - 1), chabbat: r.pauseShabbat, serie: serie)
    }

    public static func instantane(_ d: Donnees, maintenant: DateHeureZonee, applications: Int, serie: Int) -> Instantane {
        instantane(d, maintenant: maintenant, applications: applications, serie: serie) { Pratique.exempte($0, d.reglages) }
    }

    /// Le jour est-il exempté, d'après la liste ? Au-delà de ce qu'elle couvre, le samedi l'est si Chabbat l'est :
    /// le Chabbat n'est jamais retenu par erreur.
    public static func exempte(_ i: Instantane, _ jour: JourCivil) -> Bool {
        if i.joursExemptes.contains(jour) { return true }
        return i.chabbat && i.exemptesJusqua < jour && jour.jourDeSemaine == 7
    }

    /// Ce que l'extension de surveillance décide à son réveil, de l'instantané seul (et de la boîte, par
    /// `Instantane.avec`) : la règle d'Android sans autorisation ni système, qu'elle ne sait pas lire.
    public static func etatExtension(_ i: Instantane, maintenant: DateHeureZonee) -> Etat {
        let faitA = i.faitA > 0 ? maintenant.fuseau.dateHeure(millis: i.faitA) : nil
        let faits = Set(i.joursFaits)
        let faite = Pratique.fenetreFaite(debut: i.debut, fin: i.fin, maintenant: maintenant.civile, faitA: faitA) {
            faits.contains($0)
        }
        return evaluerCommeAndroid(autorisee: true, modeActif: i.modeActif, applications: i.applications,
                                   fenetreFaite: faite, jourExempte: exempte(i, maintenant.jour),
                                   reportee: reportee(jusqua: i.reporteJusqua, maintenant: maintenant.millis),
                                   dansFenetre: dansFenetre(debut: i.debut, fin: i.fin, minutes: maintenant.minutesDuJour))
    }

    /// Le magasin `barriere` doit-il être actif ?
    public static func doitRetenir(_ i: Instantane, maintenant: DateHeureZonee) -> Bool {
        etatExtension(i, maintenant: maintenant) == .veille
    }

    // MARK: La boîte (boite.jsonl)

    /// Un événement écrit par une extension : un appui sur le bouclier, ou un réveil de la surveillance.
    public struct Evenement: Sendable, Equatable {
        public enum Sorte: String, Sendable, CaseIterable {
            /// « Commencer maintenant » : l'app, en s'ouvrant, démarre la séance.
            case commencer
            /// « Je l'ai déjà faite ».
            case dejaFaite = "deja_faite"
            /// « Plus tard » : le report jusqu'à `jusqua`.
            case report
            /// La surveillance s'est réveillée (début ou fin de l'intervalle d'une activité) et a laissé le magasin
            /// actif ou non.
            case reveil
        }

        public let sorte: Sorte
        public let instant: Int64
        public let jusqua: Int64?
        public let activite: Activite?
        public let debut: Bool?
        public let actif: Bool?

        public init(_ sorte: Sorte, instant: Int64, jusqua: Int64? = nil, activite: Activite? = nil,
                    debut: Bool? = nil, actif: Bool? = nil) {
            self.sorte = sorte
            self.instant = instant
            self.jusqua = jusqua
            self.activite = activite
            self.debut = debut
            self.actif = actif
        }

        public var objet: ObjetJSON {
            var o = ObjetJSON([("t", .entier(instant)), ("e", .chaine(sorte.rawValue))])
            if let jusqua { o["jusqua"] = .entier(jusqua) }
            if let activite { o["activite"] = .chaine(activite.rawValue) }
            if let debut { o["debut"] = .booleen(debut) }
            if let actif { o["actif"] = .booleen(actif) }
            return o
        }

        /// nil pour une ligne d'une sorte inconnue ou sans instant.
        public init?(_ o: ObjetJSON) {
            guard let sorte = Sorte(rawValue: o.texte("e")), o.a("t") else { return nil }
            self.init(sorte, instant: o.long("t"), jusqua: o.a("jusqua") ? o.long("jusqua") : nil,
                      activite: o.a("activite") ? Activite(rawValue: o.texte("activite")) : nil,
                      debut: o.a("debut") ? o.booleen("debut") : nil, actif: o.a("actif") ? o.booleen("actif") : nil)
        }
    }

    /// `barriere/boite.jsonl` : une ligne JSON par événement, ajoutée par les extensions, lue puis vidée par l'app.
    public enum Boite {
        /// La ligne à ajouter au fichier, retour à la ligne compris.
        public static func ligne(_ e: Evenement) -> String { e.objet.texte() + "\n" }

        /// Les événements du fichier, dans l'ordre ; une ligne vide, coupée par une écriture interrompue ou d'une
        /// sorte inconnue est ignorée.
        public static func lire(_ texte: String) -> [Evenement] {
            texte.components(separatedBy: "\n").compactMap { ligne in
                guard !ligne.estBlanc, let o = try? ObjetJSON(texte: ligne) else { return nil }
                return Evenement(o)
            }
        }
    }

    /// Les événements dans l'ordre de leurs instants ; à instant égal, dans l'ordre d'écriture.
    static func chronologique(_ evenements: [Evenement]) -> [Evenement] {
        evenements.enumerated().sorted { ($0.element.instant, $0.offset) < ($1.element.instant, $1.offset) }.map { $0.element }
    }

    /// Le journal de la barrière garde les cinquante derniers événements (§ 2.1.8).
    public static let tailleJournal = 50

    /// Ce que l'app retient de la boîte en la versant.
    public struct Versement: Sendable, Equatable {
        /// Le dernier réveil de la surveillance connu.
        public let dernierReveil: Int64?
        /// Le dernier « Commencer » du bouclier : l'app démarre la séance.
        public let demandeDeSeance: Int64?
        /// Le journal de la barrière, les plus anciens d'abord.
        public let journal: [Evenement]
    }

    /// Verse la boîte dans les données (`fuseau` : celui du téléphone) : « Je l'ai déjà faite » inscrit la journée
    /// à zéro minute (`Store.addSession(0)`, au jour et à l'instant de l'appui) et lève le report ; « Plus tard » pose
    /// le report. Le journal de la barrière reçoit tout.
    public static func verser(_ evenements: [Evenement], dans d: inout Donnees, journal: [Evenement] = [],
                              dernierReveil: Int64? = nil, fuseau: Fuseau) -> Versement {
        var reveil = dernierReveil
        var demande: Int64?
        for e in chronologique(evenements) {
            switch e.sorte {
            case .dejaFaite:
                let a = DateHeureZonee(millis: e.instant, fuseau: fuseau)
                Pratique.inscrire(&d, minutes: 0, jour: a.jour, maintenant: a)
            case .report:
                if let jusqua = e.jusqua { d.reglages.reporteJusqua = jusqua }
            case .commencer:
                demande = max(demande ?? e.instant, e.instant)
            case .reveil:
                reveil = max(reveil ?? e.instant, e.instant)
            }
        }
        let tout = chronologique(journal + evenements)
        return Versement(dernierReveil: reveil, demandeDeSeance: demande, journal: Array(tout.suffix(tailleJournal)))
    }
}

extension Pratique {

    /// `Store.addSession` : valide la journée `jour` (celle où la séance a commencé) ; les minutes s'ajoutent, le
    /// sujet s'ajoute à ceux du jour, la note remplace l'ancienne si elle est donnée. L'instant couvert pour la
    /// fenêtre de nuit (`seance_faite_a`) est maintenant pour aujourd'hui, au plus tard la dernière seconde d'un jour
    /// passé ; le report de la barrière est levé.
    public static func inscrire(_ d: inout Donnees, minutes: Int, jour: JourCivil, note: String? = nil,
                                theme: String? = nil, maintenant: DateHeureZonee) {
        let ici = d.journal.jours[jour]
        d.journal.jours[jour] = Journee(minutes: (ici?.minutes ?? 0) + max(minutes, 0), note: note ?? ici?.note ?? "",
                                        themes: (ici?.themes ?? []) + (theme.map { [$0] } ?? []), noteSeule: false)
        let credit = jour == maintenant.jour
            ? maintenant.millis
            : min(maintenant.millis, maintenant.fuseau.millis(DateHeure(jour, heure: 23, minute: 59, seconde: 59)))
        if credit > d.reglages.faiteA { d.reglages.faiteA = credit }
        d.reglages.reporteJusqua = 0
    }
}
