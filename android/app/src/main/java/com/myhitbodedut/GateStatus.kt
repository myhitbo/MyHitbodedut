package com.myhitbodedut

import android.content.Context
import java.time.LocalDate

/** Pourquoi la barrière est active, ou pourquoi elle ne l'est pas. */
enum class GateState {
    /** Tout est en place : ouvrir une application choisie déclenchera l'écran. */
    ARMED,
    DISABLED,
    MISSING_PERMISSIONS,
    NO_APPS_SELECTED,

    /** Tout est réglé, mais le service qui surveille ne tourne pas (13/11, FBARRIERE-01). */
    SERVICE_STOPPED,

    /** Une hitbodedout est en cours : les applications choisies attendent sa fin, à toute heure (13/11, TFRUX-02). */
    SESSION_RUNNING,
    ALREADY_DONE,
    EXEMPT_DAY,
    SNOOZED,
    OUTSIDE_WINDOW
}

/**
 * Ce dont dépend l'état de la barrière, lu une fois. Les faits sont passés
 * plutôt que lus : ils demandent un contexte Android, la règle non.
 */
data class GateFaits(
    /** L'interrupteur « Je suis avec Hachem ». */
    val active: Boolean,
    /** Les deux accès spéciaux : affichage par-dessus et données d'utilisation. */
    val accesAccordes: Boolean,
    /** Le nombre d'applications choisies. */
    val applications: Int,
    /** Le service de surveillance tourne, ou Android vient d'accepter de le lancer. */
    val serviceVivant: Boolean,
    val seanceEnCours: Boolean,
    /** La fenêtre du jour est déjà honorée. */
    val faite: Boolean,
    /** Chabbat, Yom Tov ou jour mis en pause. */
    val exempte: Boolean,
    val reportee: Boolean,
    val dansLaFenetre: Boolean,
)

/** Ce que fait le toucher de la pastille « Avec Hachem » de l'accueil. */
enum class GesteBarriere {
    /** Il manque un accès ou une application : ouvrir les réglages sur la carte du mode. */
    REGLER,

    /** Tout est réglé mais le service est arrêté : le relancer. */
    RELANCER,

    /** Allumer ou éteindre le mode, d'une touche (22/09). */
    BASCULER
}

/**
 * La décision de la barrière, sans Android, pour être vérifiable (13/11, FPRODUIT-01) :
 * elle n'a jamais tourné sur un vrai téléphone, sa règle au moins est tenue par GateRuleTest.
 */
object GateRule {

    /**
     * L'état, dans l'ordre de ce qu'il faut dire d'abord. Le mode éteint passe avant les
     * accès manquants (13/11, FACCUEIL-06) : on ne réclame pas deux accès sensibles pour
     * une fonction que personne n'a allumée. Une hitbodedout en cours passe avant la
     * journée faite, le jour exempté, le report et l'heure : l'écran se pose alors à
     * toute heure, et la carte comme la notification doivent le dire (TFRUX-02).
     */
    fun etat(f: GateFaits): GateState = when {
        !f.active -> GateState.DISABLED
        !f.accesAccordes -> GateState.MISSING_PERMISSIONS
        f.applications <= 0 -> GateState.NO_APPS_SELECTED
        !f.serviceVivant -> GateState.SERVICE_STOPPED
        f.seanceEnCours -> GateState.SESSION_RUNNING
        f.faite -> GateState.ALREADY_DONE
        f.exempte -> GateState.EXEMPT_DAY
        f.reportee -> GateState.SNOOZED
        !f.dansLaFenetre -> GateState.OUTSIDE_WINDOW
        else -> GateState.ARMED
    }

    /** L'écran à poser devant une application choisie ; null quand il n'y a rien à poser. */
    fun ecran(etat: GateState): BlockerMode? = when (etat) {
        GateState.ARMED -> BlockerMode.PROMPT
        GateState.SESSION_RUNNING -> BlockerMode.SESSION_RUNNING
        else -> null
    }

    /** Le service doit-il tourner ? Oui dès que les réglages sont bons, même hors fenêtre. */
    fun doitTourner(avecBarriere: Boolean, active: Boolean, accesAccordes: Boolean): Boolean =
        avecBarriere && active && accesAccordes

    /**
     * L'heure (en minutes depuis minuit) est-elle dans la fenêtre ? Le début est compris,
     * la fin non ; une fenêtre qui passe minuit (21:00–02:00) couvre le soir et la nuit.
     */
    fun dansLaFenetre(minutes: Int, debut: Int, fin: Int): Boolean =
        if (debut <= fin) minutes >= debut && minutes < fin
        else minutes >= debut || minutes < fin

    /**
     * Une application peut-elle être choisie, et retenue ? Jamais MyHitbodedut elle-même,
     * ni celles qu'on ne retient jamais (AppsProtegees) : le Téléphone, l'écran d'accueil
     * et les Réglages d'Android (13/11, FBARRIERE-05).
     */
    fun proposable(paquet: String, propre: String, protegees: Set<String>): Boolean =
        paquet != propre && paquet !in protegees

    /**
     * L'écran se pose-t-il devant l'application au premier plan ? [protegees] n'est lu
     * que pour une application choisie : le service le demande à Android.
     */
    fun retenue(courante: String?, propre: String, choisies: Set<String>, protegees: () -> Set<String>): Boolean =
        courante != null && courante in choisies && proposable(courante, propre, protegees())

    /**
     * Le toucher de la pastille d'accueil (13/11, FBARRIERE-08) : il ne bascule que si le
     * mode peut agir. Sinon il mène aux réglages, au lieu d'afficher « activée » pour rien.
     */
    fun geste(f: GateFaits): GesteBarriere = when {
        !f.accesAccordes || f.applications <= 0 -> GesteBarriere.REGLER
        f.active && !f.serviceVivant -> GesteBarriere.RELANCER
        else -> GesteBarriere.BASCULER
    }
}

/**
 * Source unique de vérité sur l'état de la barrière.
 * Le service s'en sert pour décider, l'écran des réglages pour l'expliquer,
 * et la pastille « Avec Hachem » de l'accueil pour le dire en un mot.
 */
object GateStatus {

    /** Les faits du moment, lus dans les réglages, les autorisations et le service. */
    fun faits(context: Context): GateFaits = GateFaits(
        active = Store.isEnabled(context),
        accesAccordes = Permissions.allGranted(context),
        applications = Store.blockedApps(context).size,
        serviceVivant = GateService.vivant,
        seanceEnCours = Store.isSessionRunning(context),
        faite = Store.fenetreFaite(context),
        exempte = Store.isExempt(context, LocalDate.now()),
        reportee = Store.isSnoozed(context),
        dansLaFenetre = Store.inWindow(context),
    )

    fun evaluate(context: Context): GateState = GateRule.etat(faits(context))

    /** Le service doit-il tourner ? Oui dès que les réglages sont bons, même hors fenêtre. */
    fun shouldRunService(context: Context): Boolean =
        GateRule.doitTourner(BuildConfig.HAS_GATE, Store.isEnabled(context), Permissions.allGranted(context))

    fun titleOf(state: GateState): Int = when (state) {
        GateState.ARMED -> R.string.gate_armed_title
        GateState.MISSING_PERMISSIONS -> R.string.gate_permissions_title
        GateState.DISABLED -> R.string.gate_disabled_title
        GateState.NO_APPS_SELECTED -> R.string.gate_no_apps_title
        GateState.SERVICE_STOPPED -> R.string.gate_stopped_title
        GateState.SESSION_RUNNING -> R.string.blocker_session_title
        GateState.ALREADY_DONE -> R.string.gate_done_title
        GateState.EXEMPT_DAY -> R.string.gate_exempt_title
        GateState.SNOOZED -> R.string.gate_snoozed_title
        GateState.OUTSIDE_WINDOW -> R.string.gate_window_title
    }

    fun detailOf(context: Context, state: GateState): String = when (state) {
        // Au singulier, « 1 applications sont bloquees » se lisait dans les
        // trois langues. L'hebreu porte en plus le duel, que le francais et
        // l'anglais n'ont pas : c'est le pluriel qui le sait, pas le code.
        GateState.ARMED -> Store.blockedApps(context).size.let { combien ->
            context.resources.getQuantityString(
                R.plurals.gate_armed_detail,
                combien,
                combien,
                Store.formatMinutes(Store.windowEnd(context)),
            )
        }
        GateState.MISSING_PERMISSIONS -> context.getString(R.string.gate_permissions_detail)
        GateState.DISABLED -> context.getString(R.string.gate_disabled_detail)
        GateState.NO_APPS_SELECTED -> context.getString(R.string.gate_no_apps_detail)
        GateState.SERVICE_STOPPED -> context.getString(R.string.gate_stopped_detail)
        GateState.SESSION_RUNNING -> context.getString(R.string.gate_session_detail)
        GateState.ALREADY_DONE -> context.getString(R.string.gate_done_detail)
        GateState.EXEMPT_DAY -> context.getString(R.string.gate_exempt_detail)
        GateState.SNOOZED -> context.getString(R.string.gate_snoozed_detail)
        GateState.OUTSIDE_WINDOW -> context.getString(
            R.string.gate_window_detail,
            Store.formatMinutes(Store.windowStart(context)),
            Store.formatMinutes(Store.windowEnd(context))
        )
    }

    /** Vert quand la barrière veille, orange quand une action est attendue, neutre sinon. */
    fun colorOf(state: GateState): Int = when (state) {
        GateState.ARMED, GateState.SESSION_RUNNING, GateState.ALREADY_DONE -> R.color.brand
        GateState.MISSING_PERMISSIONS, GateState.NO_APPS_SELECTED, GateState.SERVICE_STOPPED -> R.color.warning
        else -> R.color.muted
    }

    /**
     * Le mot de la pastille « Avec Hachem » de l'accueil (13/11, FPRODUIT-02) : l'état réel,
     * en court. Elle lisait le seul interrupteur, et affichait « activée » sans accès ni
     * application choisie. Les titres de la carte sont repris quand ils tiennent sur une puce.
     */
    fun pastilleDe(state: GateState): Int = when (state) {
        GateState.ARMED -> R.string.start_focus_on
        GateState.DISABLED -> R.string.start_focus_off
        GateState.MISSING_PERMISSIONS, GateState.NO_APPS_SELECTED -> R.string.start_focus_setup
        GateState.SERVICE_STOPPED -> R.string.start_focus_stopped
        GateState.SESSION_RUNNING -> R.string.blocker_session_title
        GateState.ALREADY_DONE -> R.string.gate_done_title
        GateState.EXEMPT_DAY -> R.string.gate_exempt_title
        GateState.SNOOZED -> R.string.gate_snoozed_title
        GateState.OUTSIDE_WINDOW -> R.string.gate_window_title
    }
}
