package com.myhitbodedut

import android.app.Activity
import android.text.InputType
import android.widget.EditText
import android.widget.FrameLayout
import androidx.appcompat.app.AlertDialog

/**
 * Les durées de séance proposées, et la durée réglable.
 *
 * Demande du propriétaire, 28/09 : 5, 10, 15, 30 minutes, 1 h, 1 h 30, ou
 * un temps choisi. La même liste partout — accueil, réglages, écran de
 * séance — pour qu'une durée vue à un endroit se retrouve à l'autre.
 */
object DureeSeance {

    val PROPOSEES = intArrayOf(5, 10, 15, 30, 60, 90)

    const val MIN = 1
    const val MAX = 240

    /** Le nombre saisi, ramené entre 1 et 240 minutes ; null si ce n'est pas un nombre. */
    fun lire(texte: String): Int? = texte.trim().toIntOrNull()?.coerceIn(MIN, MAX)

    /** Les durées proposées, puis « Durée réglable… ». */
    fun choisir(activity: Activity, titre: Int, onChoisi: (Int) -> Unit) {
        val libelles = PROPOSEES.map { Store.formatDuration(activity, it) } +
            activity.getString(R.string.duration_custom)
        AlertDialog.Builder(activity)
            .setTitle(titre)
            .setItems(libelles.toTypedArray()) { _, i ->
                if (i < PROPOSEES.size) onChoisi(PROPOSEES[i]) else saisir(activity, onChoisi)
            }
            .show()
    }

    /** Un temps libre, en minutes, prérempli avec la durée habituelle. */
    fun saisir(activity: Activity, onChoisi: (Int) -> Unit) {
        val marge = (20 * activity.resources.displayMetrics.density).toInt()
        val champ = EditText(activity).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            hint = activity.getString(R.string.duration_custom_hint)
            setText(Store.targetMinutes(activity).toString())
            selectAll()
        }
        val cadre = FrameLayout(activity).apply {
            setPadding(marge, marge / 2, marge, 0)
            addView(champ)
        }
        val boite = AlertDialog.Builder(activity)
            .setTitle(R.string.duration_custom_title)
            .setView(cadre)
            .setPositiveButton(android.R.string.ok, null)
            .setNegativeButton(R.string.action_back, null)
            .show()
        // Une saisie vide ou illisible garde la boîte ouverte et le dit (FACCUEIL-15), au lieu de se taire.
        boite.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
            val minutes = lire(champ.text.toString())
            if (minutes == null) champ.error = activity.getString(R.string.duration_custom_hint)
            else { boite.dismiss(); onChoisi(minutes) }
        }
    }
}
