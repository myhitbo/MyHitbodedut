package com.myhitbodedut

import androidx.annotation.StringRes

/**
 * Une autorisation que l'application demande, et la raison qu'elle en donne.
 *
 * Elles étaient dispersées : les notifications se demandaient toutes seules
 * en activant la barrière, et se signalaient encore ailleurs dans l'écran
 * des rappels ; les trois autres vivaient au bas de l'écran principal, sous
 * six cartes. Personne ne pouvait dire d'un coup d'œil ce qui manquait.
 *
 * L'ordre est celui de l'utilité décroissante : sans notifications rien ne
 * s'affiche, sans batterie libre le rappel peut arriver en retard, et les
 * deux dernières ne servent qu'à la barrière du matin — elles disparaissent
 * de l'édition légère, qui n'en a pas.
 */
enum class Autorisation(
    val cle: String,
    @StringRes val titre: Int,
    @StringRes val pourquoi: Int,
    /** Elle ne sert qu'à la barrière, absente de l'édition légère. */
    val barriere: Boolean
) {
    NOTIFICATIONS(
        "notifications",
        R.string.permission_notifications,
        R.string.permission_notifications_why,
        false
    ),
    BATTERIE(
        "batterie",
        R.string.permission_battery,
        R.string.permission_battery_why,
        false
    ),
    OVERLAY(
        "overlay",
        R.string.permission_overlay,
        R.string.permission_overlay_why,
        true
    ),
    USAGE(
        "usage",
        R.string.permission_usage,
        R.string.permission_usage_why,
        true
    );
}

/** Ce qui est demandé, et ce qui manque. Sans appareil, pour être vérifiable. */
object PermissionRules {

    /** Les autorisations qu'il y a lieu de demander dans cette édition. */
    fun demandees(avecBarriere: Boolean): List<Autorisation> =
        Autorisation.values().filter { avecBarriere || !it.barriere }

    /**
     * Celles qu'il y a lieu de signaler comme manquantes en tête des Réglages (13/11,
     * TFRUX-05 et FACCUEIL-06). Aucune n'est obligatoire : les deux accès de la barrière ne
     * comptent que mode allumé, la batterie jamais, les notifications toujours (elles servent
     * la hitbodedout et le rappel de Birkat haLevana, allumé par défaut).
     */
    fun aSignaler(avecBarriere: Boolean, modeActif: Boolean, accordee: (Autorisation) -> Boolean): List<Autorisation> =
        demandees(avecBarriere).filterNot(accordee).filter {
            when (it) {
                Autorisation.BATTERIE -> false
                Autorisation.OVERLAY, Autorisation.USAGE -> modeActif
                else -> true
            }
        }

    /**
     * Celles qui manquent, dans l'ordre. L'état est passé plutôt que lu :
     * il demande un contexte Android, la règle non.
     */
    fun manquantes(avecBarriere: Boolean, accordee: (Autorisation) -> Boolean): List<Autorisation> =
        demandees(avecBarriere).filterNot(accordee)

    /**
     * La demande d'une permission vient de revenir : Android l'a-t-il refusée sans rien montrer ?
     * Après deux refus il ne pose plus la question, et il faut alors mener à l'écran système
     * (13/11, FACCUEIL-05). On le reconnaît à ce qu'il ne propose d'expliquer la demande ni avant
     * ni après : après un premier refus il le propose ([expliqueApres]), et un deuxième refus
     * donné à l'instant, question vue, le proposait encore juste avant ([expliquaitAvant]) —
     * on ne renvoie pas vers les réglages quelqu'un qui vient de répondre non.
     */
    fun refusSansQuestion(accordee: Boolean, expliquaitAvant: Boolean, expliqueApres: Boolean): Boolean =
        !accordee && !expliquaitAvant && !expliqueApres

    /**
     * Faut-il avertir qu'un rappel allumé ne s'affichera pas ? Oui s'il l'est sans les
     * notifications ; pas tant que la question d'Android est à l'écran, où rien n'est encore refusé.
     */
    fun rappelMuet(actif: Boolean, notifications: Boolean, demandeEnCours: Boolean): Boolean =
        actif && !notifications && !demandeEnCours
}
