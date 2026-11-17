// GateStatus.evaluate (GateStatus.kt) pour iOS : les dix états d'Android, dans le même ordre de priorité,
// et les cinq pannes propres à iOS (PORTAGE.md § 2.1.8), qui sont silencieuses et qu'il faut donc dire.
// Les sous-règles (Store.fenetreFaite, isExempt, isSnoozed, inWindow) sont reprises ici sur l'instantané
// `Etat`, parce que les extensions n'ont pas Coeur ; fenetreFaite rejoue les vecteurs de store.json
// (EvaluationTests), et toute la chaîne est confrontée aux règles de Store de Coeur (EtatBarriereTests).

/// Pourquoi la barrière est active, ou pourquoi elle ne l'est pas. Les noms bruts sont ceux de Kotlin
/// pour les dix états d'Android.
///
/// L'ordre des cas est l'ordre de priorité d'`evaluate` :
/// 1. le mode éteint, avant les accès (13/11, FACCUEIL-06) : on ne réclame pas un accès sensible pour une
///    fonction que personne n'a allumée ;
/// 2. l'autorisation de Temps d'écran (`MISSING_PERMISSIONS` d'Android) : le mode allumé, elle ne peut être
///    que retirée (iOS l'a reprise sans prévenir, puisque le mode ne s'allume qu'autorisé) ; `missingPermissions`
///    reste l'état de `GateRule` ;
/// 3. la sélection vide, comme sur Android ; puis la sélection à refaire (des jetons, mais que le système ne
///    reconnaît plus) : elle suppose une sélection, et vient donc juste après ;
/// 4. les pannes de la surveillance (absente, puis muette) avant les états du jour : une barrière dont la
///    surveillance ne tourne pas n'agira pas demain non plus, alors que « Journée validée » ou « Jour sans
///    obligation » passent d'eux-mêmes ; elles supposent un mode allumé avec une sélection valable. Elles
///    tiennent la place de `SERVICE_STOPPED` d'Android (le service arrêté), que l'iOS ne rend pas : il n'a pas
///    de service (§ 2.1.1) ;
/// 5. une hitbodedout en cours (13/11, TFRUX-02) : avant les états du jour, comme sur Android ;
/// 6. les états du jour d'Android, dans leur ordre (validée, exemptée, hors fenêtre, reportée) ;
/// 7. le bouclier désaccordé : la règle a parlé (« veille » ou non) et le magasin `barriere` dit l'inverse.
///    Il passe devant le verdict qu'il contredit, quel qu'il soit ;
/// 8. sinon, la barrière veille.
public enum GateState: String, Sendable, CaseIterable, Codable {
    case disabled = "DISABLED"
    case autorisationRetiree = "AUTORISATION_RETIREE"
    case missingPermissions = "MISSING_PERMISSIONS"
    case noAppsSelected = "NO_APPS_SELECTED"
    case selectionARefaire = "SELECTION_A_REFAIRE"
    case surveillanceAbsente = "SURVEILLANCE_ABSENTE"
    case surveillanceMuette = "SURVEILLANCE_MUETTE"
    /// Tout est réglé, mais le service qui surveille ne tourne pas (13/11, FBARRIERE-01). Android seul.
    case serviceStopped = "SERVICE_STOPPED"
    /// Une hitbodedout est en cours : les applications choisies attendent sa fin, à toute heure (13/11, TFRUX-02).
    case sessionRunning = "SESSION_RUNNING"
    case alreadyDone = "ALREADY_DONE"
    case exemptDay = "EXEMPT_DAY"
    case snoozed = "SNOOZED"
    case outsideWindow = "OUTSIDE_WINDOW"
    case bouclierDesaccorde = "BOUCLIER_DESACCORDE"
    /// Tout est en place : ouvrir une application choisie montrera le bouclier.
    case armed = "ARMED"

    /// Les dix états d'Android, les autres sont propres à iOS.
    public var android: Bool {
        switch self {
        case .armed, .missingPermissions, .disabled, .noAppsSelected, .serviceStopped, .sessionRunning, .alreadyDone,
             .exemptDay, .snoozed, .outsideWindow: true
        case .autorisationRetiree, .selectionARefaire, .surveillanceAbsente, .surveillanceMuette,
             .bouclierDesaccorde: false
        }
    }
}

/// Ce que l'app, ou l'extension, constate du système au moment d'évaluer. Une valeur nil n'a pas été
/// observée : la règle qui la regarde ne joue pas (une extension n'interroge pas `DeviceActivityCenter`,
/// l'app ne regarde pas le magasin pendant l'essai réel).
public struct Constat: Sendable, Equatable {
    /// `AuthorizationCenter.shared.authorizationStatus == .approved`.
    public var autorise: Bool
    /// Les jetons de la sélection sont encore reconnus par le système.
    public var selectionValide: Bool?
    /// `DeviceActivityCenter().activities` contient l'activité `fenetre`.
    public var surveillanceInscrite: Bool?
    /// Le dernier réveil de l'extension de surveillance, en millisecondes Unix (la boîte).
    public var dernierReveil: Int64?
    /// Le magasin `barriere` est actif.
    public var magasinActif: Bool?

    public init(autorise: Bool = true, selectionValide: Bool? = nil, surveillanceInscrite: Bool? = nil,
                dernierReveil: Int64? = nil, magasinActif: Bool? = nil) {
        self.autorise = autorise
        self.selectionValide = selectionValide
        self.surveillanceInscrite = surveillanceInscrite
        self.dernierReveil = dernierReveil
        self.magasinActif = magasinActif
    }
}

/// La règle, sur l'instantané `Etat`.
public enum Evaluation {

    /// Au-delà d'un jour sans réveil, la surveillance est dite muette.
    public static let silenceMaximum: Int64 = 24 * 60 * 60 * 1000
    /// Un intervalle de `DeviceActivitySchedule` dure quinze minutes au moins (§ 2.1.5).
    public static let intervalleMinimum = 15

    /// L'état de la barrière à `maintenant`, ce que la carte d'état dit et ce sur quoi l'extension agit.
    public static func evaluate(_ etat: Etat, maintenant: Horodatage, constat: Constat = Constat()) -> GateState {
        if !etat.enabled { return .disabled }
        if !constat.autorise { return .autorisationRetiree }
        if etat.nombreDeJetons <= 0 { return .noAppsSelected }
        if constat.selectionValide == false { return .selectionARefaire }
        if constat.surveillanceInscrite == false { return .surveillanceAbsente }
        if let reveil = constat.dernierReveil, maintenant.millis - reveil > silenceMaximum { return .surveillanceMuette }
        // La séance passe avant le magasin : rien sur iOS ne pose encore le bouclier pendant une séance hors de la
        // fenêtre (l'écran SESSION_RUNNING d'Android), la carte le dit sans crier au désaccord.
        if seanceEnCours(etat, millis: maintenant.millis) { return .sessionRunning }
        let verdict = regleDuJour(etat, maintenant: maintenant)
        if let actif = constat.magasinActif, actif != (verdict == .armed) { return .bouclierDesaccorde }
        return verdict
    }

    public static func isArmed(_ etat: Etat, maintenant: Horodatage, constat: Constat = Constat()) -> Bool {
        evaluate(etat, maintenant: maintenant, constat: constat) == .armed
    }

    /// La règle d'Android sans les autorisations ni les pannes d'iOS : ce que l'extension de surveillance
    /// applique à ses rendez-vous pour activer ou désactiver le magasin `barriere`.
    public static func regle(_ etat: Etat, maintenant: Horodatage) -> GateState {
        if !etat.enabled { return .disabled }
        if etat.nombreDeJetons <= 0 { return .noAppsSelected }
        if seanceEnCours(etat, millis: maintenant.millis) { return .sessionRunning }
        return regleDuJour(etat, maintenant: maintenant)
    }

    /// `Store.isSessionRunning` (SessionRule.enCours) : une séance sans durée court tant qu'elle n'est pas close,
    /// une séance minutée jusqu'à son terme.
    public static func seanceEnCours(_ etat: Etat, millis: Int64) -> Bool {
        guard let s = etat.seance else { return false }
        if s.debut > 0 && s.minutes == 0 { return true }
        return s.fin > millis
    }

    // MARK: Les sous-règles de Store.kt

    /// `Store.fenetreFaite` : une fenêtre qui passe minuit (21:00–02:00) appartient au soir où elle commence ;
    /// compte une séance close après la fin de la fenêtre précédente (le même jour à `end`). Sans heure
    /// connue, le jour de la fenêtre fait foi. Fenêtre dans la journée : le jour civil. Les minutes suffisent :
    /// la borne tombe sur une minute pleine, tronquer l'instant de la séance ne change pas la comparaison.
    public static func fenetreFaite(start: Int, end: Int, maintenant: Horodatage, faitA: Horodatage?,
                                    jours: [String]) -> Bool {
        if start <= end { return jours.contains(maintenant.jour) }
        let jour = maintenant.minutes < end ? (JoursIso.plus(maintenant.jour, jours: -1) ?? maintenant.jour) : maintenant.jour
        guard let faitA else { return jours.contains(jour) }
        if faitA.jour != jour { return faitA.jour > jour }
        return faitA.minutes >= end
    }

    public static func fenetreFaite(_ etat: Etat, maintenant: Horodatage) -> Bool {
        fenetreFaite(start: etat.windowStart, end: etat.windowEnd, maintenant: maintenant, faitA: etat.journee.faitA,
                     jours: etat.journee.jours)
    }

    /// `Store.isExempt` : une date en pause, ou un jour chômé si « Chabbat et Yom Tov » est actif. La liste
    /// des jours chômés couvre deux ans à partir de l'écriture ; hors de sa portée (l'app n'a pas été
    /// ouverte depuis), le samedi reste exempté par le jour de la semaine : le Chabbat n'est jamais retenu
    /// par erreur (§ 2.1.7).
    public static func isExempt(_ etat: Etat, jour: String) -> Bool {
        if etat.joursEnPause.contains(jour) { return true }
        guard etat.chabbat else { return false }
        let couvert = !etat.exemptesDepuis.isEmpty && !etat.exemptesJusquau.isEmpty
            && jour >= etat.exemptesDepuis && jour <= etat.exemptesJusquau
        if couvert { return etat.joursExemptes.contains(jour) }
        return JoursIso.jourDeSemaine(jour) == 7
    }

    /// `Store.isSnoozed` : le report court jusqu'à `snoozedUntil`, exclu.
    public static func isSnoozed(_ etat: Etat, millis: Int64) -> Bool {
        etat.snoozedUntil > millis
    }

    /// `Store.inWindow` : une fenêtre qui passe minuit court du début jusqu'à minuit, puis de minuit à la fin.
    public static func inWindow(start: Int, end: Int, minutes: Int) -> Bool {
        if start <= end { return minutes >= start && minutes < end }
        return minutes >= start || minutes < end
    }

    public static func inWindow(_ etat: Etat, minutes: Int) -> Bool {
        inWindow(start: etat.windowStart, end: etat.windowEnd, minutes: minutes)
    }

    // MARK: Le report (§ 2.1.6)

    /// `Store.snooze` : la fin du report demandé à `millis`.
    public static func finDuReport(_ etat: Etat, millis: Int64) -> Int64 {
        millis + Int64(etat.snoozeMinutes) * 60_000
    }

    /// Le report demandé à `millis`, porté dans l'instantané.
    public static func reporter(_ etat: inout Etat, millis: Int64) {
        etat.snoozedUntil = finDuReport(etat, millis: millis)
    }

    /// L'activité `report` : elle commence à la fin du report, où l'extension réarme, et dure l'intervalle
    /// minimal que le système accepte. Planifier le début évite l'intervalle trop court qu'un report de 5 ou
    /// de 10 minutes donnerait.
    public static func activiteReport(_ etat: Etat, millis: Int64) -> (debut: Int64, fin: Int64) {
        let debut = finDuReport(etat, millis: millis)
        return (debut, debut + Int64(intervalleMinimum) * 60_000)
    }

    /// La durée de la fenêtre en minutes ; une fenêtre de nuit passe minuit. Début et fin égaux : vide.
    public static func dureeFenetre(start: Int, end: Int) -> Int {
        start <= end ? end - start : end + 24 * 60 - start
    }

    /// L'écran de réglage refuse une fenêtre plus courte que l'intervalle minimal du système.
    public static func fenetreAcceptable(start: Int, end: Int) -> Bool {
        dureeFenetre(start: start, end: end) >= intervalleMinimum
    }

    // MARK: Aides

    /// Les états du jour d'Android, dans leur ordre (GateRule.etat : hors fenêtre avant le report, 13/11), une
    /// fois le mode allumé et la sélection faite.
    private static func regleDuJour(_ etat: Etat, maintenant: Horodatage) -> GateState {
        GateRule.etat(GateFaits(active: true, accesAccordes: true, applications: 1, serviceVivant: true, seanceEnCours: false,
                                faite: fenetreFaite(etat, maintenant: maintenant),
                                exempte: isExempt(etat, jour: maintenant.jour) || pauseDeLaVeilleEncore(etat, maintenant),
                                reportee: isSnoozed(etat, millis: maintenant.millis),
                                dansLaFenetre: inWindow(etat, minutes: maintenant.minutes)))
    }

    /// « Pause aujourd'hui » cochée le soir couvre la fenêtre de nuit en cours jusqu'à sa fin, au lieu de cesser à
    /// minuit (FBARRIERE-07). Chabbat et Yom Tov gardent la date civile.
    static func pauseDeLaVeilleEncore(_ etat: Etat, _ maintenant: Horodatage) -> Bool {
        guard GateRule.finDeFenetreDeNuit(minutes: maintenant.minutes, debut: etat.windowStart, fin: etat.windowEnd),
              let veille = JoursIso.plus(maintenant.jour, jours: -1) else { return false }
        return etat.joursEnPause.contains(veille)
    }
}

// MARK: GateRule.kt

/// Ce dont dépend l'état de la barrière, lu une fois (GateFaits de GateStatus.kt). Les faits sont passés plutôt
/// que lus : la règle est vérifiable sans le système.
public struct GateFaits: Sendable, Equatable {
    /// L'interrupteur « Je suis avec Hachem ».
    public var active: Bool
    /// Les accès (sur Android, l'affichage par-dessus et les données d'utilisation ; sur iOS, Temps d'écran).
    public var accesAccordes: Bool
    /// Le nombre d'applications choisies.
    public var applications: Int
    /// Le service de surveillance tourne (Android).
    public var serviceVivant: Bool
    public var seanceEnCours: Bool
    /// La fenêtre du jour est déjà honorée.
    public var faite: Bool
    /// Chabbat, Yom Tov ou jour mis en pause.
    public var exempte: Bool
    public var reportee: Bool
    public var dansLaFenetre: Bool

    public init(active: Bool, accesAccordes: Bool, applications: Int, serviceVivant: Bool, seanceEnCours: Bool,
                faite: Bool, exempte: Bool, reportee: Bool, dansLaFenetre: Bool) {
        self.active = active
        self.accesAccordes = accesAccordes
        self.applications = applications
        self.serviceVivant = serviceVivant
        self.seanceEnCours = seanceEnCours
        self.faite = faite
        self.exempte = exempte
        self.reportee = reportee
        self.dansLaFenetre = dansLaFenetre
    }
}

/// Ce que fait le toucher de la pastille « Avec Hachem » de l'accueil. Valeurs brutes : les noms de Kotlin.
public enum GesteBarriere: String, Sendable, CaseIterable {
    /// Il manque un accès ou une application : ouvrir les réglages sur la carte du mode.
    case regler = "REGLER"
    /// Tout est réglé mais le service est arrêté : le relancer.
    case relancer = "RELANCER"
    /// Allumer ou éteindre le mode, d'une touche (22/09).
    case basculer = "BASCULER"
}

/// La décision de la barrière, sans le système, pour être vérifiable (GateRule de GateStatus.kt, 13/11,
/// FPRODUIT-01). Jugée par `Tests/Vecteurs/barriere.json` (« regle », « fenetre », « service »).
public enum GateRule {

    /// L'état, dans l'ordre de ce qu'il faut dire d'abord. Le mode éteint passe avant les accès manquants (13/11,
    /// FACCUEIL-06). Une hitbodedout en cours passe avant la journée faite, le jour exempté, l'heure et le report :
    /// l'écran se pose alors à toute heure, et la carte comme la notification doivent le dire (TFRUX-02).
    public static func etat(_ f: GateFaits) -> GateState {
        if !f.active { return .disabled }
        if !f.accesAccordes { return .missingPermissions }
        if f.applications <= 0 { return .noAppsSelected }
        if !f.serviceVivant { return .serviceStopped }
        if f.seanceEnCours { return .sessionRunning }
        if f.faite { return .alreadyDone }
        if f.exempte { return .exemptDay }
        if !f.dansLaFenetre { return .outsideWindow }
        if f.reportee { return .snoozed }
        return .armed
    }

    /// Le service doit-il tourner ? Oui dès que les réglages sont bons, même hors fenêtre (Android seul).
    public static func doitTourner(avecBarriere: Bool, active: Bool, accesAccordes: Bool) -> Bool {
        avecBarriere && active && accesAccordes
    }

    /// L'heure (en minutes depuis minuit) est-elle dans la fenêtre ? Le début est compris, la fin non ; une
    /// fenêtre qui passe minuit (21:00–02:00) couvre le soir et la nuit.
    public static func dansLaFenetre(minutes: Int, debut: Int, fin: Int) -> Bool {
        debut <= fin ? minutes >= debut && minutes < fin : minutes >= debut || minutes < fin
    }

    /// Après minuit, dans la fin d'une fenêtre de nuit (21:00–02:00 à 00:30) : la fenêtre appartient au soir où
    /// elle a commencé (FBARRIERE-07, comme Store.fenetreFaite).
    public static func finDeFenetreDeNuit(minutes: Int, debut: Int, fin: Int) -> Bool {
        debut > fin && minutes < fin
    }

    /// Le toucher de la pastille d'accueil (13/11, FBARRIERE-08) : il ne bascule que si le mode peut agir. Sinon il
    /// mène aux réglages, au lieu d'afficher « activée » pour rien.
    public static func geste(_ f: GateFaits) -> GesteBarriere {
        if !f.accesAccordes || f.applications <= 0 { return .regler }
        if f.active && !f.serviceVivant { return .relancer }
        return .basculer
    }
}
