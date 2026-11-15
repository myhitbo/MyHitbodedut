package com.myhitbodedut

import java.time.LocalDate

/**
 * Ce que les trois accueils refondus (15/11 : Ciel complet, Bento, Pile) disent
 * de la journée, sans appareil : vérifiable par les tests.
 */
object Refontes {

    /** Le moment du jour, posé sur les zmanim du lieu. */
    enum class Periode(val libelle: Int, val conseil: Int) {
        AVANT_LEVER(R.string.periode_avant_lever, R.string.conseil_matin),
        MATIN(R.string.periode_matin, R.string.conseil_matin),
        APRES_HATSOT(R.string.periode_apres_hatsot, R.string.conseil_jour),
        MINHA_KETANA(R.string.periode_minha_ketana, R.string.conseil_jour),
        BEIN_HACHMACHOT(R.string.periode_bein_hachmachot, R.string.conseil_nuit),
        NUIT(R.string.periode_nuit, R.string.conseil_nuit),
    }

    /** Le moment de la minute [m] (0 à 1439) ; minuit passé, c'est encore la nuit jusqu'à l'aube. */
    fun periode(m: Int, r: CielDuJour.Reperes): Periode = when {
        m < r.netz - 72 -> Periode.NUIT
        m < r.netz -> Periode.AVANT_LEVER
        m < r.chatsot -> Periode.MATIN
        m < r.minhaKetana -> Periode.APRES_HATSOT
        m < r.chkia -> Periode.MINHA_KETANA
        m < r.tset -> Periode.BEIN_HACHMACHOT
        else -> Periode.NUIT
    }

    /** La part du jour écoulée à la minute [m], de 0 au lever à 1 au coucher. */
    fun partDuJour(m: Int, r: CielDuJour.Reperes): Float =
        if (r.chkia <= r.netz) 0f else ((m - r.netz).toFloat() / (r.chkia - r.netz)).coerceIn(0f, 1f)

    /**
     * Le ’hizouk du jour des tuiles et des cartes : le même toute la journée, un autre
     * le lendemain, sans toucher au sac des tirages (ChizukBag) ni à la relance.
     * Seuls les textes qui ont leur hébreu et une traduction comptent.
     */
    fun hizoukDuJour(items: List<ChizukItem>, jour: LocalDate): ChizukItem? {
        val candidats = items.filter { it.he.isNotBlank() && (it.fr.isNotBlank() || it.en.isNotBlank()) }
            .sortedBy { it.id }
        if (candidats.isEmpty()) return null
        return candidats[Math.floorMod(jour.toEpochDay() * PAS, candidats.size.toLong()).toInt()]
    }

    /** Le pas entre deux jours : deux jours voisins ne tombent pas sur deux textes voisins. */
    private const val PAS = 29L

    /** La dernière note du journal, jusqu'à [jusqua] compris ; null s'il n'y en a pas. */
    fun derniereNote(jours: Collection<DayRecord>, jusqua: String): DayRecord? =
        jours.filter { it.note.isNotBlank() && it.date <= jusqua }.maxByOrNull { it.date }

    /** Les sept barres de la semaine des tuiles : pleine faite, basse à venir ou exemptée. */
    fun barres(semaine: List<WeekDay>): List<Float> = semaine.map {
        when {
            it.done -> 1f
            it.future || it.exempt -> 0.18f
            else -> 0.35f
        }
    }
}
