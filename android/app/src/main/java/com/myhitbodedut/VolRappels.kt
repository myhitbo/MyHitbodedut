package com.myhitbodedut

import java.time.Duration
import java.time.Instant

/**
 * Les rappels pendant un vol (28/10) : Tefilat haDerekh cinq minutes après le
 * décollage prévu (délai choisi par l'utilisateur ; les sources la placent après
 * le décollage, ZMANIM.md « En vol »), le début de chaque prière dans l'avion et
 * l'approche de sa limite, le compte du Omer du soir.
 *
 * Les bornes des prières sont celles de la bannière des prières (HorairePriere) :
 * Min'ha de min'ha guedola à la chki'a, Arvit de la sortie des étoiles au milieu
 * de la nuit, Cha'harit jusqu'à la fin du temps de la tefila (GRA). La carte
 * « Prière du moment » (ZmanimWidget.prochaine) a les mêmes limites et, depuis le
 * 13/11 (FVOL-05), le même début de Min'ha ; elle garde ses propres débuts pour
 * Cha'harit (l'aube) et Arvit (la chki'a). Seul le début de Cha'harit n'était pas
 * dans la bannière : le lever du soleil (netz), le temps de la prière au départ
 * (Choul'han Aroukh O.H. 89, 1).
 * Le Omer : les jalons de VolCalendrier. Pas d'Android ici.
 */
object VolRappels {

    /** HAGOMEL (audit du 16/11) : à l'atterrissage d'un vol d'une heure douze ou plus, le rappel de bénir dans les trois jours. */
    enum class Type { TEFILAT_HADEREKH, PRIERE, PRIERE_FIN, OMER, HAGOMEL, CHEMA_FIN }

    data class Rappel(
        val type: Type,
        val instant: Instant,
        /** « chaharit », « minha », « arvit » : la prière qui commence ou finit ; au décollage, celle du moment. */
        val priere: String? = null,
        val limite: Instant? = null,
        val omer: Int = 0,
        /** Cha'harit : la fin du Chema du rite ([chemaCle]) et celle de l'autre avis (audit du 16/11). */
        val chema: Instant? = null,
        val chemaCle: String? = null,
        val chemaAutre: Instant? = null,
    )

    /**
     * La fin du Chema que suivent les rappels (audit du 16/11) : le Maguen Avraham pour les Edot
     * (Kitsour Yalkut Yosef 89:4, « לכתחלה יש להחמיר לקוראה קודם שיעבור ג' שעות מעמוד השחר »),
     * le Gra pour les autres ; l'autre avis est toujours nommé dans le texte. En vol, le profil est
     * le profil commun (Vol.kt) : la fin MGA y est en 72 min fixes.
     */
    fun cleChema(nusah: String) = if (nusah == "edot") "szks_mga" else "szks_gra"

    val APRES_DECOLLAGE: Duration = Duration.ofMinutes(5)
    val AVANT_LIMITE: Duration = Duration.ofMinutes(30)

    /**
     * Hagomel après un vol (audit du 16/11) : « הטס במטוס שיעור שעה ושתים עשרה דקות… יברך ברכת הגומל »
     * (Kitsour Yalkut Yosef 219:20-21). Le texte du rappel suit le noussa'h (VolAlerte.textes) : en Ashkenaz
     * et en Sfard, « selon votre usage » (Choul'han Aroukh O.H. 219:7 ; Igrot Moché O.H. 2).
     */
    val DUREE_HAGOMEL: Duration = Duration.ofMinutes(72)

    /** Chaque prière : le zman qui l'ouvre, celui qui la ferme. */
    val BORNES = listOf(
        Triple("chaharit", "netz", "szt_gra"),
        Triple("minha", "minha_gedola", "chkia"),
        Triple("arvit", "tset", "chatsot_layla"),
    )

    /** La prière ouverte à [t] et sa limite, aux bornes ci-dessus ; null entre deux prières. */
    fun ouverte(calcul: Vol.Calcul, t: Instant): Pair<String, Instant>? {
        val ev = calcul.evenements
        for ((priere, debut, fin) in BORNES) {
            // Arvit sans tsét sous l'avion : dès la chki'a, le repère de repli (audit du 16/11).
            val d = ev.lastOrNull {
                (it.cle == debut || (priere == "arvit" && it.cle == "chkia" && VolCalendrier.tsetManque(calcul, it))) && !it.instant.isAfter(t)
            } ?: continue
            val f = ev.firstOrNull { it.cle == fin && it.instant.isAfter(d.instant) } ?: continue
            if (t.isBefore(f.instant)) return priere to f.instant
        }
        return null
    }

    fun rappels(calcul: Vol.Calcul, enIsrael: Boolean, nusah: String = Zmanim.NUSAH_COMMUN): List<Rappel> {
        val cle = cleChema(nusah)
        val autre = if (cle == "szks_mga") "szks_gra" else "szks_mga"
        return (rappelsPrieres(calcul, enIsrael).map { r ->
            if (r.type != Type.PRIERE || r.priere != "chaharit") r
            else {
                // La première fin du Chema après le lever, avant la fin de la Téfila.
                fun fin(c: String) = calcul.evenements.firstOrNull { it.cle == c && it.instant.isAfter(r.instant) && (r.limite == null || !it.instant.isAfter(r.limite)) }?.instant
                r.copy(chema = fin(cle), chemaCle = cle, chemaAutre = fin(autre))
            }
        } + rappelsChema(calcul, cle, autre)).sortedWith(compareBy({ it.instant }, { it.type.ordinal }))
    }

    /**
     * « Plus que 30 min pour le Chema » (audit du 16/11) : dans l'avion, après Tefilat haDerekh,
     * et seulement le matin (une aube passée sous l'avion, sans coucher depuis).
     */
    private fun rappelsChema(calcul: Vol.Calcul, cle: String, autre: String): List<Rappel> {
        val plan = calcul.plan
        val t0 = plan.decollage + APRES_DECOLLAGE
        val ev = calcul.evenements
        return ev.filter { it.cle == cle }.mapNotNull { f ->
            val t = f.instant - AVANT_LIMITE
            val aube = ev.lastOrNull { it.cle == "alot" && !it.instant.isAfter(t) } ?: return@mapNotNull null
            val coucher = ev.lastOrNull { it.cle == "chkia" && !it.instant.isAfter(t) }
            if (t.isBefore(t0) || t.isAfter(plan.atterrissage) || (coucher != null && coucher.instant.isAfter(aube.instant))) return@mapNotNull null
            val l = ev.firstOrNull { it.cle == autre && it.instant.isAfter(aube.instant) }?.instant
            Rappel(Type.CHEMA_FIN, t, "chaharit", f.instant, chema = f.instant, chemaCle = cle, chemaAutre = l)
        }
    }

    private fun rappelsPrieres(calcul: Vol.Calcul, enIsrael: Boolean): List<Rappel> {
        val plan = calcul.plan
        val dansLAvion = { t: Instant -> !t.isBefore(plan.decollage) && !t.isAfter(plan.atterrissage) }
        val res = mutableListOf<Rappel>()
        val t0 = plan.decollage + APRES_DECOLLAGE
        if (dansLAvion(t0)) {
            val o = ouverte(calcul, t0)
            res += Rappel(Type.TEFILAT_HADEREKH, t0, o?.first, o?.second)
        }
        for ((priere, debut, fin) in BORNES) {
            calcul.evenements.filter { it.cle == debut && dansLAvion(it.instant) && it.instant.isAfter(t0) }.forEach { d ->
                val limite = calcul.evenements.firstOrNull { it.cle == fin && it.instant.isAfter(d.instant) }?.instant
                res += Rappel(Type.PRIERE, d.instant, priere, limite)
            }
            // L'approche de la limite (sauf Arvit, qui se dit encore après le milieu de la nuit) :
            // seulement si la prière est déjà ouverte à ce moment-là.
            if (priere == "arvit") continue
            calcul.evenements.filter { it.cle == fin }.forEach { f ->
                val t = f.instant - AVANT_LIMITE
                if (dansLAvion(t) && t.isAfter(t0) && ouverte(calcul, t)?.first == priere) res += Rappel(Type.PRIERE_FIN, t, priere, f.instant)
            }
        }
        // Vol polaire sans tsét (audit du 16/11) : Arvit annoncée à la chki'a, repère de repli
        // (VolCalendrier.tsetManque), comme le Omer ; jamais à Rabbénou Tam.
        calcul.evenements.filter { it.cle == "chkia" && dansLAvion(it.instant) && it.instant.isAfter(t0) && VolCalendrier.tsetManque(calcul, it) }
            .forEach { d ->
                val limite = calcul.evenements.firstOrNull { it.cle == "chatsot_layla" && it.instant.isAfter(d.instant) }?.instant
                res += Rappel(Type.PRIERE, d.instant, "arvit", limite)
            }
        VolCalendrier.jalons(calcul, enIsrael, 0).filter { it.type == VolCalendrier.Type.OMER }
            .forEach { res += Rappel(Type.OMER, it.instant, omer = it.omer) }
        if (Duration.between(plan.decollage, plan.atterrissage) >= DUREE_HAGOMEL) res += Rappel(Type.HAGOMEL, plan.atterrissage)
        return res
    }
}
