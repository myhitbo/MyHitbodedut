package com.myhitbodedut

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import java.time.ZonedDateTime

/**
 * La vignette moyenne des zmanim (14/10, refaite le 28/10 avec une petite et
 * une grande : ZmanimVignette). Mise à jour toutes les demi-heures et à
 * chaque ouverture.
 */
class ZmanimWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        // Toutes les tailles, et le prochain changement reprogrammé (02/11) ; hors du fil principal (15/11).
        EnFond.recevoir(this) { ZmanimVignette.rafraichir(context) }
    }

    /**
     * La prière du moment (13/11 ; audit du 12/11, FVOL-05). [debut] null : elle est ouverte, jusqu'à
     * [limite] (null : sans limite affichée). [debut] non null : aucune prière n'est ouverte, la
     * prochaine, [priere], commence à [debut] et se fermera à [limite].
     */
    data class Moment(val priere: String, val limite: ZonedDateTime?, val debut: ZonedDateTime? = null)

    companion object {
        /**
         * La prière du moment et sa limite : Cha'harit jusqu'au sof zman tefila (GRA), Min'ha de min'ha
         * guedola à la chki'a, Arvit jusqu'à minuit. Entre la fin de Cha'harit et min'ha guedola, aucune
         * prière n'est ouverte : Min'ha est annoncée avec l'heure où elle commence (13/11, FVOL-05 —
         * avant, « Min'ha » s'affichait dès la fin de Cha'harit, avant 'hatsot, quand la bannière et les
         * rappels du vol la font commencer à min'ha guedola). Sans min'ha guedola dans [horaires],
         * l'ancienne règle.
         */
        fun prochaine(horaires: Map<String, ZonedDateTime?>, maintenant: ZonedDateTime): Moment {
            // Après minuit et avant l'aube, c'est encore la nuit d'Arvit (audit du 16/10) : jusqu'au
            // milieu de la nuit d'hier s'il n'est pas passé, sans limite affichée ensuite.
            val alot = horaires["alot"]
            if (alot != null && maintenant.isBefore(alot)) {
                return Moment("arvit", horaires["chatsot_layla"]?.minusDays(1)?.takeIf { maintenant.isBefore(it) })
            }
            val finChaharit = horaires["szt_gra"]
            if (finChaharit != null && maintenant.isBefore(finChaharit)) return Moment("chaharit", finChaharit)
            val chkia = horaires["chkia"]
            val guedola = horaires["minha_gedola"]
            // Une min'ha guedola d'après la chki'a est celle du lendemain (en vol, sans repère d'aube :
            // Vol.horaires donne alors les prochains de chaque zman) : Min'ha est ouverte.
            if (guedola != null && maintenant.isBefore(guedola) && (chkia == null || guedola.isBefore(chkia))) return Moment("minha", chkia, guedola)
            for ((priere, limite) in listOf("minha" to chkia, "arvit" to horaires["chatsot_layla"])) {
                if (limite != null && maintenant.isBefore(limite)) return Moment(priere, limite)
            }
            return Moment("arvit", null)
        }

        /** Les trois tailles (28/10) : ZmanimVignette ; et la boussole, qui suit le même lieu. */
        fun refresh(context: Context) {
            ZmanimVignette.rafraichir(context)
            BoussoleWidget.refresh(context)
        }
    }
}
