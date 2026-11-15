package com.myhitbodedut

import java.time.LocalDate

/**
 * L'historique d'un réglage qui pèse sur le passé (13/11, audit FDONNEES-05).
 *
 * « Israël ou diaspora » et « Chabbat et Yom Tov » décident des jours exemptés, donc de la
 * série. Jugés avec la valeur du moment, ils changeaient le passé après coup : atterrir en
 * Israël faisait des deuxièmes jours de fête déjà passés des jours manqués, la série tombait,
 * puis revenait au retour. Chaque changement est donc daté, et un jour se juge avec la valeur
 * en vigueur ce jour-là.
 *
 * Forme gardée : « 2000-01-01=0,2026-11-05=1 » — la date d'effet puis 1 (oui) ou 0 (non), par
 * dates croissantes ; la première entrée vaut pour tout ce qui la précède. Vide : le réglage
 * n'a jamais changé, sa valeur du moment vaut pour tous les jours. Le site garde la même
 * chaîne (store.js). L'export ne la porte pas : un fichier importé date son réglage du jour.
 *
 * Rien d'Android ici.
 */
object HistoriqueReglage {

    data class Entree(val depuis: LocalDate, val valeur: Boolean)

    /** La date d'effet de la valeur d'avant le premier changement : avant tout journal. */
    val ORIGINE: LocalDate = LocalDate.of(2000, 1, 1)

    /** Au-delà, les plus anciens changements se fondent dans l'origine. */
    const val MAX = 200

    /** Les entrées lisibles, par dates croissantes, une par date ; le reste est ignoré. */
    fun decoder(brut: String?): List<Entree> {
        if (brut.isNullOrBlank()) return emptyList()
        val parDate = sortedMapOf<LocalDate, Boolean>()
        brut.split(',').forEach { morceau ->
            val date = runCatching { LocalDate.parse(morceau.substringBefore('=').trim()) }.getOrNull() ?: return@forEach
            when (morceau.substringAfter('=', "").trim()) {
                "1" -> parDate[date] = true
                "0" -> parDate[date] = false
            }
        }
        return parDate.map { Entree(it.key, it.value) }
    }

    fun encoder(histoire: List<Entree>): String =
        histoire.joinToString(",") { "${it.depuis}=${if (it.valeur) 1 else 0}" }

    /**
     * La valeur en vigueur le [jour]. Depuis le dernier changement, c'est [actuelle] (le
     * réglage lui-même fait foi) ; avant, celle de l'entrée en vigueur ce jour-là.
     */
    fun valeurLe(histoire: List<Entree>, jour: LocalDate, actuelle: Boolean): Boolean {
        if (histoire.isEmpty() || !jour.isBefore(histoire.last().depuis)) return actuelle
        return (histoire.lastOrNull { !it.depuis.isAfter(jour) } ?: histoire.first()).valeur
    }

    /**
     * L'historique après un changement fait [aujourdhui], de [ancienne] à [nouvelle] : le passé
     * garde [ancienne], le jour même et la suite prennent [nouvelle]. Changer puis revenir le
     * même jour ne laisse rien.
     */
    fun apresChangement(histoire: List<Entree>, aujourdhui: LocalDate, ancienne: Boolean, nouvelle: Boolean): List<Entree> {
        if (ancienne == nouvelle) return histoire
        val base = histoire.ifEmpty { listOf(Entree(ORIGINE, ancienne)) }
        // Jamais d'entrée à venir : une horloge reculée ne garde pas un changement du futur.
        val avant = base.filter { it.depuis.isBefore(aujourdhui) }.ifEmpty { listOf(Entree(ORIGINE, ancienne)) }
        val suite = if (avant.last().valeur == nouvelle) avant else avant + Entree(aujourdhui, nouvelle)
        if (suite.size <= MAX) return suite
        val gardees = suite.takeLast(MAX)
        return listOf(Entree(ORIGINE, gardees.first().valeur)) + gardees.drop(1)
    }
}
