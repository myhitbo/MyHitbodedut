package com.myhitbodedut

/**
 * Ce qu'une compilation a le droit d'afficher, et sous quelle forme.
 *
 * Deux règles, toutes deux tirées de _meta.regle_publication :
 *
 *  - en release, seul passe un texte relevé de la source ET relu par un
 *    humain. Un texte non relu peut porter une coquille, et une coquille
 *    dans un verset n'est pas une coquille ordinaire ;
 *  - l'hébreu affiché dépend de l'édition. Quand la licence de l'édition
 *    numérique n'est pas déclarée, on n'en reprend pas la vocalisation,
 *    qui est un travail éditorial : on affiche le texte sans nikkoud.
 *
 * Les fonctions prennent `debug` en paramètre plutôt que de lire
 * BuildConfig : c'est ce qui les rend vérifiables sans appareil.
 */
object ChizukRules {

    const val STATUT_PUBLIABLE = "verifie_texte"

    /** La règle de publication, telle quelle. */
    fun isPublishable(item: ChizukItem): Boolean =
        item.statutVerif == STATUT_PUBLIABLE && item.relu

    /** Un item retenu en debug mais que la release refuserait porte un badge. */
    fun needsProofreading(item: ChizukItem): Boolean = !isPublishable(item)

    /** Ce qu'une compilation affiche : tout en debug, le publiable en release. */
    fun visible(chizuk: Chizuk, debug: Boolean): List<ChizukItem> =
        if (debug) chizuk.items else chizuk.items.filter(::isPublishable)

    /** Ce qu'un moment donné a le droit de tirer. */
    fun forMoment(chizuk: Chizuk, moment: Moment, debug: Boolean): List<ChizukItem> =
        if (moment == Moment.DEMANDE) visible(chizuk, debug) else visible(chizuk, debug).filter { moment in it.moments }

    /**
     * L'hébreu à afficher. Pour une édition dont nikkoud_ok est faux, le fichier
     * livre déjà `he` sans vocalisation (LicencesEditionsTest l'impose) : il n'y a
     * rien à retirer à l'affichage.
     */
    fun hebrew(@Suppress("UNUSED_PARAMETER") chizuk: Chizuk, item: ChizukItem): String = item.he
}
