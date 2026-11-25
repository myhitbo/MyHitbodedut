package com.myhitbodedut

import android.view.View

/**
 * Le bilan de la semaine écoulée (16/10, point 7) : à la première ouverture de la semaine, une
 * fois. Sur tous les accueils depuis le 24/11 ; il ne s'ouvrait que sur le Classique.
 */
object BilanSemaineVue {

    fun montrerSiDu(activite: android.app.Activity) {
        // Rien à calculer quand le bilan de cette semaine a déjà été montré.
        val debut = BilanSemaine.debutSemaine(java.time.LocalDate.now()).minusDays(7)
        if (Store.bilanVu(activite) == debut.toString()) return
        val minutes = Store.bilan(activite).minutes
        val b = BilanSemaine.precedente(java.time.LocalDate.now(), minutes, Store.datesTrophees(activite))
        if (b == null) { Store.setBilanVu(activite, debut.toString()); return }
        Store.setBilanVu(activite, b.debut.toString())
        val d = activite.resources.displayMetrics.density
        val vue = android.widget.LinearLayout(activite).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding((24 * d).toInt(), (8 * d).toInt(), (24 * d).toInt(), 0)
            addView(VueJour.texte(context, context.getString(R.string.bilan_minutes, Store.formatDuration(context, b.minutes),
                context.resources.getQuantityString(R.plurals.palier_n_jours, b.jours, b.jours)), 17f, R.color.ink, gras = true))
            if (b.ecart > 0 && b.precedente > 0) addView(VueJour.texte(context, context.getString(R.string.bilan_plus, Store.formatDuration(context, b.ecart)), 15f, R.color.muted, haut = 6))
            if (b.record) addView(VueJour.texte(context, context.getString(R.string.bilan_record), 15f, R.color.brand, gras = true, haut = 6))
            if (b.trophees.isNotEmpty()) {
                addView(VueJour.texte(context, context.getString(R.string.bilan_trophees), 15f, R.color.muted, haut = 10))
                // La pratique lue une fois, pas une fois par niveau (04/11).
                val pratique = Store.pratique(context)
                val faits = Trophees.chemin.filter { Trophees.gagne(pratique, it) }
                addView(android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.HORIZONTAL
                    b.trophees.take(6).forEach { t ->
                        addView(View(context).apply {
                            background = TropheeDessin(context, t.famille.forme, Trophees.grade(faits.indexOf(t) + 1), t.famille.icone)
                            contentDescription = TropheesVue.description(context, t.famille, t.seuil)
                        }, android.widget.LinearLayout.LayoutParams((40 * d).toInt(), (40 * d).toInt()).apply { marginEnd = (6 * d).toInt() })
                    }
                })
            }
        }
        com.google.android.material.dialog.MaterialAlertDialogBuilder(activite).setTitle(R.string.bilan_titre).setView(vue)
            .setPositiveButton(R.string.celebration_continue, null).show()
    }
}
