// GateStatus.evaluate (GateStatus.kt) pour iOS : les huit états d'Android, dans le même ordre de priorité,
// et les cinq pannes propres à iOS (PORTAGE.md § 2.1.8), qui sont silencieuses et qu'il faut donc dire.
// Les sous-règles (Store.fenetreFaite, isExempt, isSnoozed, inWindow) sont reprises ici sur l'instantané
// `Etat`, parce que les extensions n'ont pas Coeur ; les tests les rejouent sur les vecteurs de store.json.

/// Pourquoi la barrière est active, ou pourquoi elle ne l'est pas. Les noms bruts sont ceux de Kotlin
/// pour les huit états d'Android.
///
/// L'ordre des cas est l'ordre de priorité d'`evaluate` :
/// 1. l'autorisation de Temps d'écran (`MISSING_PERMISSIONS` d'Android), affinée : retirée si le mode est
///    allumé (iOS l'a reprise sans prévenir, puisque le mode ne s'allume qu'autorisé), manquante sinon ;
/// 2. le mode éteint, puis la sélection vide, comme sur Android ; puis la sélection à refaire (des jetons,
///    mais que le système ne reconnaît plus) : elle suppose une sélection, et vient donc juste après ;
/// 3. les pannes de la surveillance (absente, puis muette) avant les états du jour : une barrière dont la
///    surveillance ne tourne pas n'agira pas demain non plus, alors que « Journée validée » ou « Jour sans
///    obligation » passent d'eux-mêmes ; elles supposent un mode allumé avec une sélection valable ;
/// 4. les états du jour d'Android, dans leur ordre (validée, exemptée, reportée, hors fenêtre) ;
/// 5. le bouclier désaccordé : la règle a parlé (« veille » ou non) et le magasin `barriere` dit l'inverse.
///    Il passe devant le verdict qu'il contredit, quel qu'il soit ;
/// 6. sinon, la barrière veille.
public enum GateState: String, Sendable, CaseIterable, Codable {
    case autorisationRetiree = "AUTORISATION_RETIREE"
    case missingPermissions = "MISSING_PERMISSIONS"
    case disabled = "DISABLED"
    case noAppsSelected = "NO_APPS_SELECTED"
    case selectionARefaire = "SELECTION_A_REFAIRE"
    case surveillanceAbsente = "SURVEILLANCE_ABSENTE"
    case surveillanceMuette = "SURVEILLANCE_MUETTE"
    case alreadyDone = "ALREADY_DONE"
    case exemptDay = "EXEMPT_DAY"
    case snoozed = "SNOOZED"
    case outsideWindow = "OUTSIDE_WINDOW"
    case bouclierDesaccorde = "BOUCLIER_DESACCORDE"
    /// Tout est en place : ouvrir une application choisie montrera le bouclier.
    case armed = "ARMED"

    /// Les huit états d'Android, les autres sont propres à iOS.
    public var android: Bool {
        switch self {
        case .armed, .missingPermissions, .disabled, .noAppsSelected, .alreadyDone, .exemptDay, .snoozed,
             .outsideWindow: true
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
        if !constat.autorise { return etat.enabled ? .autorisationRetiree : .missingPermissions }
        if !etat.enabled { return .disabled }
        if etat.nombreDeJetons <= 0 { return .noAppsSelected }
        if constat.selectionValide == false { return .selectionARefaire }
        if constat.surveillanceInscrite == false { return .surveillanceAbsente }
        if let reveil = constat.dernierReveil, maintenant.millis - reveil > silenceMaximum { return .surveillanceMuette }
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
        return regleDuJour(etat, maintenant: maintenant)
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

    /// Les états du jour d'Android, dans leur ordre, une fois le mode allumé et la sélection faite.
    private static func regleDuJour(_ etat: Etat, maintenant: Horodatage) -> GateState {
        if fenetreFaite(etat, maintenant: maintenant) { return .alreadyDone }
        if isExempt(etat, jour: maintenant.jour) { return .exemptDay }
        if isSnoozed(etat, millis: maintenant.millis) { return .snoozed }
        if !inWindow(etat, minutes: maintenant.minutes) { return .outsideWindow }
        return .armed
    }
}
