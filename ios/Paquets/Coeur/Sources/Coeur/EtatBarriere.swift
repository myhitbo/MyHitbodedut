import Barriere

// La barrière vue de l'app : ce qu'elle calcule pour remplir barriere/etat.json (PORTAGE.md § 2.1.4,
// § 2.1.7, § 3.2), puis la carte d'état des réglages (GateStatus.kt : titleOf, detailOf, colorOf). Les
// extensions n'ont ni calendrier ni catalogue : l'app leur donne les jours exemptés des deux années à venir
// et les textes du bouclier déjà traduits. L'évaluation elle-même est dans le module Barriere.

/// Ce que l'app dépose pour les extensions de Temps d'écran.
public enum EtatBarriere {

    /// Deux années à venir, aujourd'hui compris : environ 150 jours chômés.
    public static let horizon = 731

    /// Les jours chômés (Chabbat, Yom Tov : `Holidays.isRestDay`, Israël ou diaspora selon les réglages) des
    /// `jours` jours qui commencent à `depuis` ; aucun si « Chabbat et Yom Tov » est éteint. Les dates en
    /// pause n'y sont pas : elles vont à part (`Etat.joursEnPause`), l'écran les change d'un geste.
    public static func joursExemptes(reglages: Reglages, depuis: JourCivil, fuseauTelephone: String,
                                     jours: Int = EtatBarriere.horizon) -> [JourCivil] {
        guard reglages.shabbatMode, jours > 0 else { return [] }
        let israel = reglages.inIsrael(fuseauTelephone: fuseauTelephone)
        var resultat: [JourCivil] = []
        for decalage in 0..<jours {
            let jour = depuis.plus(jours: decalage)
            if Holidays.isRestDay(jour, inIsrael: israel) { resultat.append(jour) }
        }
        return resultat
    }

    /// L'instant `millis` vu de `fuseau`, par les règles de java.time (`Fuseau`), pour les règles de la barrière.
    public static func horodatage(millis: Int64, fuseau: Fuseau) -> Horodatage {
        let civile = fuseau.dateHeure(millis: millis)
        return Horodatage(millis: millis, jour: civile.jour.iso, minutes: civile.minutesDuJour)
    }

    /// Ce que `Store.fenetreFaite` regarde : la veille et le jour même s'ils sont faits, et l'instant de la
    /// dernière séance close (« seance_faite_a », lu comme `Store.fenetreFaite(journal:reglages:millis:fuseau:)`).
    public static func journee(journal: Journal, reglages: Reglages, millis: Int64, fuseau: Fuseau) -> Etat.JourneeValidee {
        let aujourdhui = fuseau.jour(millis: millis)
        var jours: [String] = []
        for jour in [aujourdhui.plus(jours: -1), aujourdhui] where journal.isDone(jour) {
            jours.append(jour.iso)
        }
        let faite = reglages.brut["seance_faite_a"]?.commeLong ?? 0
        return Etat.JourneeValidee(jours: jours, faitA: faite > 0 ? horodatage(millis: faite, fuseau: fuseau) : nil)
    }

    /// Les textes du bouclier avant traduction : les chaînes `blocker_*` de BlockerView.kt, et deux chaînes
    /// propres à iOS (ios.xcstrings) : le bouton « Autre réponse » et la notification de repli (§ 2.1.4).
    public struct TextesBouclier: Sendable, Equatable {
        public var question: Libelle
        public var sousTitre: Libelle
        public var serie: Libelle
        public var commencer: Libelle
        public var autreReponse: Libelle
        public var dejaFaite: Libelle
        public var plusTard: Libelle
        public var seanceTitre: Libelle
        public var seanceSousTitre: Libelle
        public var revenir: Libelle
        public var apercu: Libelle
        public var fermerApercu: Libelle
        public var notificationCommencer: Libelle

        /// Les textes, résolus dans la langue de l'app par `resoudre`.
        public func textes(_ resoudre: (Libelle) -> String) -> Etat.Bouclier {
            var bouclier = Etat.Bouclier()
            bouclier.question = resoudre(question)
            bouclier.sousTitre = resoudre(sousTitre)
            bouclier.serie = resoudre(serie)
            bouclier.commencer = resoudre(commencer)
            bouclier.autreReponse = resoudre(autreReponse)
            bouclier.dejaFaite = resoudre(dejaFaite)
            bouclier.plusTard = resoudre(plusTard)
            bouclier.seanceTitre = resoudre(seanceTitre)
            bouclier.seanceSousTitre = resoudre(seanceSousTitre)
            bouclier.revenir = resoudre(revenir)
            bouclier.apercu = resoudre(apercu)
            bouclier.fermerApercu = resoudre(fermerApercu)
            bouclier.notificationCommencer = resoudre(notificationCommencer)
            return bouclier
        }
    }

    /// Les libellés du bouclier, comme BlockerView les compose : la série (`blocker_streak`, ou
    /// `blocker_streak_none` à zéro), la durée habituelle sur « Commencer », la durée du report sur « Plus
    /// tard ». Le décompte d'une séance minutée change de minute en minute : le bouclier, figé à son
    /// apparition, prend la phrase sans décompte (`blocker_session_hidden_subtitle`).
    public static func libelles(journal: Journal, reglages: Reglages, aujourdhui: JourCivil,
                                fuseauTelephone: String) -> TextesBouclier {
        let serie = Store.streak(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: fuseauTelephone)
        return TextesBouclier(
            question: Libelle("blocker_question"),
            sousTitre: Libelle("blocker_subtitle"),
            serie: serie > 0 ? Libelle.pluriel("blocker_streak", quantite: serie, .entier(serie)) : Libelle("blocker_streak_none"),
            commencer: Libelle("blocker_start", .libelle(Store.formatDuration(reglages.targetMinutes))),
            autreReponse: Libelle("bouclier_autre_reponse"),
            dejaFaite: Libelle("blocker_already_done"),
            plusTard: Libelle("blocker_snooze", .entier(reglages.snoozeMinutes)),
            seanceTitre: Libelle("blocker_session_title"),
            seanceSousTitre: Libelle("blocker_session_hidden_subtitle"),
            revenir: Libelle("blocker_back_to_session"),
            apercu: Libelle("blocker_preview_badge"),
            fermerApercu: Libelle("blocker_close_preview"),
            notificationCommencer: Libelle("bouclier_notification_commencer"))
    }

    /// L'instantané complet à `millis`, vu de `fuseau` (celui du téléphone). `nombreDeJetons` compte la
    /// sélection de Temps d'écran (une catégorie vaut un) ; `textes` résout un libellé dans la langue de l'app.
    public static func etat(journal: Journal, reglages: Reglages, millis: Int64, fuseau: Fuseau, nombreDeJetons: Int,
                            textes: (Libelle) -> String) -> Etat {
        let aujourdhui = fuseau.jour(millis: millis)
        let zone = fuseau.identifiant
        var resultat = Etat()
        resultat.ecritA = millis
        resultat.enabled = reglages.isEnabled
        resultat.windowStart = reglages.windowStart
        resultat.windowEnd = reglages.windowEnd
        resultat.snoozeMinutes = reglages.snoozeMinutes
        resultat.snoozedUntil = reglages.snoozedUntil
        resultat.chabbat = reglages.shabbatMode
        var exemptes: [String] = []
        for jour in joursExemptes(reglages: reglages, depuis: aujourdhui, fuseauTelephone: zone) {
            exemptes.append(jour.iso)
        }
        resultat.joursExemptes = exemptes
        resultat.exemptesDepuis = aujourdhui.iso
        resultat.exemptesJusquau = aujourdhui.plus(jours: horizon - 1).iso
        resultat.joursEnPause = reglages.pausedDates.sorted()
        resultat.journee = journee(journal: journal, reglages: reglages, millis: millis, fuseau: fuseau)
        if Store.isSessionRunning(reglages: reglages, millis: millis) {
            resultat.seance = Etat.Seance(debut: Store.sessionStartedAt(reglages: reglages),
                                          fin: Store.sessionEndsAt(reglages: reglages),
                                          minutes: Store.sessionTarget(reglages: reglages))
        }
        resultat.bouclier = libelles(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                     fuseauTelephone: zone).textes(textes)
        resultat.nombreDeJetons = max(nombreDeJetons, 0)
        return resultat
    }
}

/// GateStatus.kt : la source unique de vérité sur l'état de la barrière, que la carte d'état explique.
/// `shouldRunService` reste à Android : iOS ne fait tourner aucun service (§ 2.1.1).
public enum GateStatus {

    public static func evaluate(_ etat: Etat, maintenant: Horodatage, constat: Constat = Constat()) -> GateState {
        Evaluation.evaluate(etat, maintenant: maintenant, constat: constat)
    }

    public static func isArmed(_ etat: Etat, maintenant: Horodatage, constat: Constat = Constat()) -> Bool {
        evaluate(etat, maintenant: maintenant, constat: constat) == .armed
    }

    /// Le titre de la carte d'état. Ceux des cinq états d'iOS sont dans ios.xcstrings.
    public static func titleOf(_ state: GateState) -> Libelle {
        switch state {
        case .armed: Libelle("gate_armed_title")
        case .missingPermissions: Libelle("gate_permissions_title")
        case .disabled: Libelle("gate_disabled_title")
        case .noAppsSelected: Libelle("gate_no_apps_title")
        case .alreadyDone: Libelle("gate_done_title")
        case .exemptDay: Libelle("gate_exempt_title")
        case .snoozed: Libelle("gate_snoozed_title")
        case .outsideWindow: Libelle("gate_window_title")
        case .autorisationRetiree: Libelle("gate_revoked_title")
        case .selectionARefaire: Libelle("gate_reselect_title")
        case .surveillanceAbsente: Libelle("gate_monitor_missing_title")
        case .surveillanceMuette: Libelle("gate_monitor_silent_title")
        case .bouclierDesaccorde: Libelle("gate_mismatch_title")
        }
    }

    /// Le détail de la carte. « Veille » compte les applications retenues au pluriel de la langue (au
    /// singulier, « 1 applications sont bloquées » se lisait dans les trois langues ; l'hébreu a le duel)
    /// et donne la fin de la fenêtre ; « Hors de la fenêtre » en donne les deux bornes.
    public static func detailOf(_ state: GateState, applications: Int, windowStart: Int, windowEnd: Int) -> Libelle {
        switch state {
        case .armed:
            Libelle.pluriel("gate_armed_detail", quantite: applications, .entier(applications),
                            .texte(Store.formatMinutes(windowEnd)))
        case .missingPermissions: Libelle("gate_permissions_detail")
        case .disabled: Libelle("gate_disabled_detail")
        case .noAppsSelected: Libelle("gate_no_apps_detail")
        case .alreadyDone: Libelle("gate_done_detail")
        case .exemptDay: Libelle("gate_exempt_detail")
        case .snoozed: Libelle("gate_snoozed_detail")
        case .outsideWindow:
            Libelle("gate_window_detail", .texte(Store.formatMinutes(windowStart)), .texte(Store.formatMinutes(windowEnd)))
        case .autorisationRetiree: Libelle("gate_revoked_detail")
        case .selectionARefaire: Libelle("gate_reselect_detail")
        case .surveillanceAbsente: Libelle("gate_monitor_missing_detail")
        case .surveillanceMuette: Libelle("gate_monitor_silent_detail")
        case .bouclierDesaccorde: Libelle("gate_mismatch_detail")
        }
    }

    /// Le détail pour l'instantané : sur iOS, les applications se comptent en jetons de la sélection.
    public static func detailOf(_ state: GateState, etat: Etat) -> Libelle {
        detailOf(state, applications: etat.nombreDeJetons, windowStart: etat.windowStart, windowEnd: etat.windowEnd)
    }

    /// Le nom de la couleur (colors.xml) : vert quand la barrière veille, orange quand une action est
    /// attendue, neutre sinon. Les pannes d'iOS attendent un geste, sauf le bouclier désaccordé, que l'app
    /// corrige d'elle-même.
    public static func colorOf(_ state: GateState) -> String {
        switch state {
        case .armed, .alreadyDone: "brand"
        case .missingPermissions, .noAppsSelected, .autorisationRetiree, .selectionARefaire, .surveillanceAbsente,
             .surveillanceMuette: "warning"
        case .disabled, .exemptDay, .snoozed, .outsideWindow, .bouclierDesaccorde: "muted"
        }
    }
}
