package com.myhitbodedut

import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Chabbat, les fêtes et le compte du Omer en vol (28/10) : la règle de
 * JourAffiche.horaires (isAssurBemelacha de KosherJava), appliquée aux
 * chki'a et aux tsét de la route au lieu de celles d'un lieu fixe.
 *
 *  - chki'a la veille d'un jour chômé : entrée (et l'heure d'allumage,
 *    [minutes] avant cette chki'a) ;
 *  - tsét d'un jour chômé suivi d'un jour ouvré : sortie ;
 *  - tsét d'un jour chômé suivi d'un autre : le jour suivant commence ;
 *    sauf une fête un vendredi (audit du 12/11, FCALENDRIER-01) : Chabbat
 *    entre à la chki'a, avec l'allumage avant elle, comme une veille ;
 *  - tsét pendant le Omer : le jour qui se compte ce soir.
 *
 * Le jour civil est celui du point sous l'avion (fuseau nautique, comme
 * Vol) ; Israël ou diaspora, le réglage de l'application. Ce sont deux choix
 * de calcul, pas des règles : ZMANIM.md, « En vol ». Aucun conseil n'est
 * donné (allumer à bord, compter avant ou après une escale…).
 * Pas d'Android ici : testable sur la machine virtuelle seule.
 */
object VolCalendrier {

    enum class Type { ENTREE, SORTIE, ENCHAINEMENT, OMER }

    data class Jalon(
        val type: Type,
        val instant: Instant,
        /** Le jour qui commence (entrée, enchaînement, Omer) ou qui finit (sortie), au point sous l'avion. */
        val date: LocalDate,
        val chabbat: Boolean,
        /** Les clés « fete_<clé> » de ce jour. */
        val fetes: List<String>,
        val omer: Int = 0,
        /** L'allumage, [minutes] avant la chki'a : à l'entrée seulement. */
        val allumage: Instant? = null,
        val latitude: Double,
        val longitude: Double,
        /**
         * Pas de tsét à 8,5° sous l'avion après cette chki'a (vol polaire, audit du 16/11) : un
         * repère de repli, dit comme un choix de calcul. Omer : la chki'a (Kitsour YY 489:18 admet
         * le compte en bein hachmachot ; MB 489:14). Sortie et enchaînement : Rabbénou Tam (72 min),
         * plus strict, jamais la chki'a.
         */
        val repli: Boolean = false,
    )

    /**
     * Une ligne de date franchie pendant le Omer (audit du 16/11) : le compte personnel et celui
     * du lieu ne coïncident plus ; l'écran donne les avis (Rav Chlomo Zalman Auerbach : sans
     * bénédiction ; le Rabbi de Loubavitch : le compte personnel ; Kitsour YY 489 : par analogie,
     * les deux comptes sans bénédiction) sans trancher.
     */
    fun ligneDateOmer(calcul: Vol.Calcul, enIsrael: Boolean): Boolean = calcul.lignesDate.any { l ->
        listOf(l.avant, l.apres, l.avant.plusDays(1), l.apres.plusDays(1)).any { CalendrierJuif.jour(it, enIsrael).omer > 0 }
    }

    /** Après la chki'a [e], le prochain repère de la nuit ou du matin n'est pas un tsét : il manque (audit du 16/11). */
    fun tsetManque(calcul: Vol.Calcul, e: Vol.Evenement): Boolean =
        calcul.evenements.firstOrNull { it.instant.isAfter(e.instant) && it.cle in setOf("tset", "alot", "misheyakir", "netz", "chkia") }?.cle != "tset"

    fun jalons(calcul: Vol.Calcul, enIsrael: Boolean, minutes: Int): List<Jalon> = calcul.enVol.flatMap { e ->
        if (e.cle != "chkia" && e.cle != "tset") return@flatMap emptyList()
        val jour = e.instant.atZone(ZoneId.of(Vol.fuseauNautique(e.longitude))).toLocalDate()
        val aujourdhui = CalendrierJuif.jour(jour, enIsrael)
        val demain = CalendrierJuif.jour(jour.plusDays(1), enIsrael)
        fun jalon(type: Type, j: CalendrierJuif.Jour, allumage: Instant? = null, omer: Int = 0, ev: Vol.Evenement = e, repli: Boolean = false) =
            Jalon(type, ev.instant, j.date, j.date.dayOfWeek == DayOfWeek.SATURDAY, j.fetes, omer, allumage, ev.latitude, ev.longitude, repli)
        val vendredi = jour.dayOfWeek == DayOfWeek.FRIDAY
        val repli = e.cle == "chkia" && tsetManque(calcul, e)
        // Rabbénou Tam après cette chki'a, s'il est dans le vol : le repli de la sortie.
        val rt = if (repli) calcul.enVol.firstOrNull { it.cle == "tset_rt" && it.instant.isAfter(e.instant) } else null
        buildList {
            if (e.cle == "chkia" && demain.chome && (!aujourdhui.chome || vendredi)) add(jalon(Type.ENTREE, demain, e.instant - Duration.ofMinutes(minutes.toLong())))
            if (e.cle == "tset") {
                if (aujourdhui.chome && !demain.chome) add(jalon(Type.SORTIE, aujourdhui))
                if (aujourdhui.chome && demain.chome && !vendredi) add(jalon(Type.ENCHAINEMENT, demain))
                if (demain.omer > 0) add(jalon(Type.OMER, demain, omer = demain.omer))
            }
            if (repli) {
                if (rt != null && aujourdhui.chome && !demain.chome) add(jalon(Type.SORTIE, aujourdhui, ev = rt, repli = true))
                if (rt != null && aujourdhui.chome && demain.chome && !vendredi) add(jalon(Type.ENCHAINEMENT, demain, ev = rt, repli = true))
                if (demain.omer > 0) add(jalon(Type.OMER, demain, omer = demain.omer, repli = true))
            }
        }
    }.sortedBy { it.instant }
}
