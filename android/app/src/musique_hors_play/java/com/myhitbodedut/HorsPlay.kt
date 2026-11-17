package com.myhitbodedut

/**
 * Ce que seule la version GitHub dit (FBARRIERE-21) : installée hors boutique, Android grise
 * l'accès tant que les « paramètres restreints » ne sont pas autorisés. Référence directe et non
 * getIdentifier : la réduction des ressources de la version publiée retirerait la chaîne.
 * src/musique_play, pris par la construction Play, n'a pas la chaîne et rend null.
 */
internal object HorsPlay {
    val DIVULGATION_RESTREINTS: Int? = R.string.divulgation_restreints
}
