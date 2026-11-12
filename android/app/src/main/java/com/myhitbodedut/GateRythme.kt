package com.myhitbodedut

/**
 * Le rythme auquel l'écran de garde interroge le système (check-up du 11/11).
 *
 * Séparé du service pour être testé sans appareil.
 */
object GateRythme {
    /** Barrière armée, écran allumé : une application bloquée doit être couverte aussitôt. */
    const val ARMEE_MS = 900L

    /** Barrière désarmée : il suffit de voir venir l'ouverture de la fenêtre. */
    const val REPOS_MS = 15_000L

    /** Écran éteint sans écoute de l'allumage : un tour par minute, par prudence. */
    const val ETEINT_MS = 60_000L

    /**
     * Délai avant le prochain tour, ou null pour s'arrêter : écran éteint,
     * aucune application ne passe au premier plan, et le rallumage relance
     * la boucle — à condition qu'on l'écoute ([relanceAllumage]).
     */
    fun delai(armee: Boolean, ecranAllume: Boolean, relanceAllumage: Boolean = true): Long? = when {
        !ecranAllume -> if (relanceAllumage) null else ETEINT_MS
        armee -> ARMEE_MS
        else -> REPOS_MS
    }
}
