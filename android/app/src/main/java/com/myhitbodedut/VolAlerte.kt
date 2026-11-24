package com.myhitbodedut

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Les notifications des rappels en vol (VolRappels). Comme l'alerte de Chabbat :
 * une seule alarme inexacte, celle du prochain rappel, reprogrammée à chaque
 * déclenchement, au démarrage et à chaque calcul du vol. La liste est calculée
 * par VolActivity et gardée avec le vol (Store) : le récepteur ne refait pas le
 * calcul, il lit la liste. En mode avion aussi : rien ne passe par le réseau.
 */
object VolAlerte {

    private const val REQUETE = 160

    /** Un rappel déclenché avec un peu de retard (Android regroupe les alarmes) s'affiche encore ; au-delà, il est passé. */
    private const val TOLERANCE_MS = 20 * 60_000L

    /** Garde les rappels d'un vol calculé et programme le prochain ; une liste vide les efface. */
    fun enregistrer(context: Context, rappels: List<VolRappels.Rappel>) {
        Store.setVolRappels(context, rappels)
        programmer(context)
    }

    fun programmer(context: Context) {
        Alarme.annuler(context, REQUETE, VolAlerteReceiver::class.java)
        if (!Store.volRappelsActifs(context)) return
        val maintenant = System.currentTimeMillis()
        val vu = Store.volRappelVu(context)
        val prochain = Store.volRappels(context).map { it.instant.toEpochMilli() }.filter { it > vu && it > maintenant - TOLERANCE_MS }.minOrNull() ?: return
        Alarme.poser(context, REQUETE, VolAlerteReceiver::class.java, prochain.coerceAtLeast(maintenant))
    }

    /** L'étiquette de notification d'un rappel : son type et sa prière, pour que deux rappels dus d'un coup ne s'écrasent pas. */
    fun etiquette(r: VolRappels.Rappel): String = "vol:${r.type.name}:${r.priere.orEmpty()}"

    /** Les rappels dus maintenant, pas encore montrés (plusieurs peuvent tomber à la même minute). */
    fun dus(rappels: List<VolRappels.Rappel>, vu: Long, maintenant: Long): List<VolRappels.Rappel> =
        rappels.filter { val t = it.instant.toEpochMilli(); t > vu && t <= maintenant + 60_000L && t > maintenant - TOLERANCE_MS }

    /** « mar. 10 · 18:42 TLV · 11:42 JFK » (VolActivity) : l'heure du départ et celle de l'arrivée. */
    fun deuxHeures(plan: Vol.Plan, t: Instant, locale: Locale): String {
        val jour = DateTimeFormatter.ofPattern("EEE d", locale)
        val heure = DateTimeFormatter.ofPattern("HH:mm", locale)
        val dep = Vol.zone(plan.depart.fuseau)?.let { t.atZone(it) } ?: return t.toString()
        val arr = Vol.zone(plan.arrivee.fuseau)?.let { t.atZone(it) } ?: return t.toString()
        val autreJour = if (arr.toLocalDate() != dep.toLocalDate()) "${arr.format(jour)} " else ""
        return "${dep.format(jour)} \u2066${dep.format(heure)} ${plan.depart.iata}\u2069 · $autreJour\u2066${arr.format(heure)} ${plan.arrivee.iata}\u2069"
    }

    fun nomPriere(c: Context, priere: String?) = c.getString(when (priere) {
        "chaharit" -> R.string.widget_zmanim_chaharit
        "minha" -> R.string.widget_zmanim_minha
        else -> R.string.widget_zmanim_arvit
    })

    /** Le titre et le texte d'un rappel ; [plan] donne les heures des deux aéroports. */
    fun textes(c: Context, r: VolRappels.Rappel, plan: Vol.Plan?): Pair<String, String> {
        val locale = Chiffres.locale(ChizukCard.language(c))
        val heure = { t: Instant -> plan?.let { deuxHeures(it, t, locale) } ?: t.toString() }
        return when (r.type) {
            VolRappels.Type.TEFILAT_HADEREKH -> c.getString(R.string.vol_rappel_derekh_titre) to
                (c.getString(R.string.vol_rappel_derekh_texte) +
                    (r.limite?.let { "\n" + c.getString(R.string.vol_rappel_derekh_priere, nomPriere(c, r.priere), heure(it)) } ?: ""))
            VolRappels.Type.PRIERE -> c.getString(R.string.vol_rappel_priere_titre, nomPriere(c, r.priere)) to
                (r.limite?.let { c.getString(R.string.vol_rappel_priere_texte, nomPriere(c, r.priere), heure(it)) }
                    ?: c.getString(R.string.vol_rappel_priere_sans_limite, nomPriere(c, r.priere))) +
                // Cha'harit : le Chema d'abord (audit du 16/11).
                (r.chema?.let { "\n" + texteChema(c, r, heure) } ?: "")
            VolRappels.Type.PRIERE_FIN -> c.getString(R.string.vol_rappel_fin_titre, nomPriere(c, r.priere)) to
                c.getString(R.string.vol_rappel_fin_texte, heure(r.limite ?: r.instant))
            VolRappels.Type.OMER -> c.getString(R.string.vol_rappel_omer_titre) to c.getString(R.string.vol_rappel_omer_texte, r.omer.toString())
            // Audit du 16/11 : obligation en Edot (Kitsour Yalkut Yosef 219:20) ; selon l'usage ailleurs.
            VolRappels.Type.HAGOMEL -> c.getString(R.string.vol_rappel_gomel_titre) to
                c.getString(if (Store.siddurNusah(c) == Nusah.EDOT) R.string.vol_rappel_gomel_texte_edot else R.string.vol_rappel_gomel_texte)
            VolRappels.Type.CHEMA_FIN -> c.getString(R.string.vol_rappel_chema_titre) to texteChema(c, r, heure)
        }
    }

    /** « Fin du Chema (Maguen Avraham) : … ; au besoin, selon le Gra : … » (audit du 16/11). */
    private fun texteChema(c: Context, r: VolRappels.Rappel, heure: (Instant) -> String): String {
        val chema = heure(r.chema ?: r.instant)
        val autre = r.chemaAutre?.let(heure) ?: "—"
        return if (r.chemaCle == "szks_mga") c.getString(R.string.vol_rappel_chema_mga, chema, autre)
        else c.getString(R.string.vol_rappel_chema_gra, chema, autre)
    }

    /** Le texte du siddur qu'ouvre le rappel, et le hassid qui l'accompagne. */
    fun texteSiddur(r: VolRappels.Rappel): String = when (r.type) {
        VolRappels.Type.TEFILAT_HADEREKH -> "tefilat_haderekh"
        VolRappels.Type.OMER -> "sefirat_haomer"
        VolRappels.Type.HAGOMEL -> "hagomel"
        else -> r.priere ?: "arvit"
    }

    /** L'illustration en carré : une image haute (le hassid debout) garde le haut, le visage. */
    fun icone(c: Context, r: VolRappels.Rappel): android.graphics.Bitmap {
        val b = BitmapFactory.decodeResource(c.resources, Personnage.pour(c, illustration(r)))
        return if (b.height > b.width) android.graphics.Bitmap.createBitmap(b, 0, 0, b.width, b.width) else b
    }

    fun illustration(r: VolRappels.Rappel): Int = when (r.type) {
        VolRappels.Type.TEFILAT_HADEREKH, VolRappels.Type.HAGOMEL -> R.drawable.scene_airport
        VolRappels.Type.OMER -> R.drawable.char_tehilim
        else -> SiddurMoment.illustration(r.priere ?: "arvit")
    }
}

/**
 * Montre les rappels dus, puis programme le suivant. Hors du fil principal (15/11, EnFond) : les
 * aéroports (550 ko de JSON) s'y analysaient quand le processus venait d'être relancé.
 */
class VolAlerteReceiver : BroadcastReceiver() {
    override fun onReceive(brut: Context, intent: Intent) {
        val context = LangueApp.envelopper(brut)
        EnFond.recevoir(this) {
            Notifications.ensureChannels(context)
            val maintenant = System.currentTimeMillis()
            val dus = if (Store.volRappelsActifs(context)) VolAlerte.dus(Store.volRappels(context), Store.volRappelVu(context), maintenant) else emptyList()
            val plan = Store.vol(context, Data.aeroports(context))
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            dus.forEach { r ->
                val (titre, texte) = VolAlerte.textes(context, r, plan)
                // Une intention par texte ouvert : les extras ne distinguent pas deux PendingIntent, et
                // FLAG_UPDATE_CURRENT ferait ouvrir à la notification de Min'ha, restée affichée, le texte
                // d'Arvit (même type, même code) maintenant que chaque rappel garde la sienne (FVOL-16).
                val ouvrir = PendingIntent.getActivity(
                    context, 161 + r.type.ordinal,
                    SiddurLectureActivity.intent(context, VolAlerte.texteSiddur(r))
                        .setData(android.net.Uri.fromParts("vol-rappel", VolAlerte.texteSiddur(r), null)),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                val n = Notification.Builder(context, Notifications.CHANNEL_REMINDER)
                    .setSmallIcon(R.drawable.ic_notification)
                    .setLargeIcon(VolAlerte.icone(context, r))
                    .setContentTitle(titre)
                    .setContentText(texte)
                    .setStyle(Notification.BigTextStyle().bigText(texte))
                    .setContentIntent(ouvrir)
                    .setAutoCancel(true)
                    .build()
                // Chaque rappel garde sa notification (FVOL-16) : un lot de rappels dus d'un coup (Doze) ne s'écrase pas.
                runCatching { manager.notify(VolAlerte.etiquette(r), if (r.type == VolRappels.Type.OMER) Notifications.ID_VOL_OMER else Notifications.ID_VOL, n) }
            }
            dus.maxOfOrNull { it.instant.toEpochMilli() }?.let { Store.setVolRappelVu(context, it) }
            VolAlerte.programmer(context)
        }
    }
}
