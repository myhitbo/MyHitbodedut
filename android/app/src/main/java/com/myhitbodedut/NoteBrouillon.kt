package com.myhitbodedut

import android.content.Context
import org.json.JSONObject

/**
 * Le brouillon de la note (13/11, audit FSEANCE-04, FDONNEES-02 et 03).
 *
 * Ce qui est tapé dans la fenêtre de note est gardé à chaque frappe, par jour,
 * dans le fichier du journal : comme les notes, il ne part dans aucune
 * sauvegarde nuage et n'est pas exporté. Une rotation, un passage au thème
 * sombre ou la mort du processus recréent la fenêtre : elle repart du
 * brouillon, et toute fenêtre de la même note repart du même texte.
 * « Enregistrer » et « Ne pas enregistrer » l'effacent.
 */
object NoteBrouillon {

    /** Les cinq champs de la fenêtre de note, tels qu'ils sont à l'écran. */
    data class Etat(
        val note: String = "",
        val avant: Int = 0,
        val apres: Int = 0,
        val gratitude: String = "",
        val travail: String = "",
    )

    /** Les blancs de bord ne comptent pas : l'enregistrement les retire. */
    private fun propre(e: Etat) =
        e.copy(note = e.note.trim(), gratitude = e.gratitude.trim(), travail = e.travail.trim())

    /**
     * La fenêtre a-t-elle quelque chose à perdre ? Les cinq champs comptent :
     * la garde ne regardait que la note, et une humeur ou une gratitude
     * partaient au retour sans un mot.
     */
    fun modifie(enregistre: Etat, courant: Etat): Boolean = propre(enregistre) != propre(courant)

    /** Le brouillon à garder : rien tant que la fenêtre dit ce qui est déjà enregistré. */
    fun aGarder(enregistre: Etat, courant: Etat): Etat? = courant.takeIf { modifie(enregistre, it) }

    private fun tout(brut: String?): JSONObject =
        runCatching { JSONObject(brut ?: "{}") }.getOrDefault(JSONObject())

    /** Le brouillon du jour [date] dans [brut], ou null. */
    fun lireDans(brut: String?, date: String): Etat? {
        val o = tout(brut).optJSONObject(date) ?: return null
        return Etat(
            o.optString("note", "").take(Store.NOTE_MAX),
            o.optInt("avant", 0).coerceIn(0, 5),
            o.optInt("apres", 0).coerceIn(0, 5),
            o.optString("gratitude", "").take(JournalPlus.GRATITUDE_MAX),
            o.optString("travail", "").take(JournalPlus.GRATITUDE_MAX),
        )
    }

    /** [brut] avec le brouillon du jour posé, ou retiré si [etat] est null ; null quand il n'en reste aucun. */
    fun ecrireDans(brut: String?, date: String, etat: Etat?): String? {
        val t = tout(brut)
        if (etat == null) t.remove(date) else t.put(
            date,
            JSONObject().put("note", etat.note).put("avant", etat.avant).put("apres", etat.apres)
                .put("gratitude", etat.gratitude).put("travail", etat.travail),
        )
        return if (t.length() == 0) null else t.toString()
    }

    fun lire(context: Context, date: String): Etat? = lireDans(Store.noteBrouillonsBrut(context), date)

    /** Pose le brouillon du jour, ou le retire si [etat] est null. */
    fun garder(context: Context, date: String, etat: Etat?) {
        val avant = Store.noteBrouillonsBrut(context)
        val apres = ecrireDans(avant, date, etat)
        if (apres != avant) Store.setNoteBrouillonsBrut(context, apres)
    }
}
