package com.myhitbodedut

import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset

/**
 * La prière du moment en vol (28/10) : les horaires de la route (Vol.horaires)
 * passés à ZmanimWidget.prochaine, dont la règle n'est pas réécrite.
 */
object VolPriere {

    /** Ce qui reste couvert par la fenêtre de calcul autour du vol (Vol.MARGE, moins un jour). */
    val COUVERT: Duration = Duration.ofHours(6)

    /**
     * La prière du moment en vol, comme ZmanimWidget.Moment : ouverte jusqu'à [limite] ; ou, [debut]
     * non null, pas encore ouverte — elle commence à [debut] (13/11, FVOL-05).
     */
    data class Moment(val priere: String, val limite: Instant?, val debut: Instant? = null)

    /** La prière du moment et sa limite ; null loin du vol : la fenêtre ne couvre plus. */
    fun priere(calcul: Vol.Calcul, maintenant: Instant): Moment? {
        if (maintenant.isBefore(calcul.plan.decollage - COUVERT) || maintenant.isAfter(calcul.plan.atterrissage + COUVERT)) return null
        val m = ZmanimWidget.prochaine(Vol.horaires(calcul, maintenant), maintenant.atZone(ZoneOffset.UTC))
        return Moment(m.priere, m.limite?.toInstant(), m.debut?.toInstant())
    }
}
