package com.myhitbodedut

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.annotation.StringRes

/**
 * Les versions de l'application (17/11) : quatre manières d'habiter la même
 * pratique, dans le même APK. Classique est l'accueil d'origine (MainActivity) ;
 * les autres sont des accueils à part, tirés des maquettes du propriétaire,
 * qui ouvrent les mêmes écrans (séance, zmanim, textes, journal, réglages).
 *
 * Le journal, la série, les réglages et la barrière sont les mêmes d'une
 * version à l'autre : changer de version ne perd rien.
 *
 * On choisit au premier lancement (ChoixVersionActivity), et on change à tout
 * moment dans les réglages. MainActivity reste la porte d'entrée de tout
 * (lanceur, notifications, vignettes) : elle renvoie vers l'accueil choisi.
 */
enum class VersionApp(
    val cle: String,
    @StringRes val nom: Int,
    @StringRes val description: Int,
    /** L'accueil de cette version ; null pour Classique, qui est MainActivity elle-même. */
    val accueil: Class<out Activity>?,
    /** Trois couleurs pour l'aperçu de l'écran de choix : fond, carte, accent. */
    val apercu: IntArray,
) {
    CLASSIQUE("classique", R.string.version_classique, R.string.version_classique_desc, null,
        intArrayOf(0xFF0F3D2E.toInt(), 0xFF1E5A45.toInt(), 0xFF8FD9B6.toInt())),
    PILE("pile", R.string.version_pile, R.string.version_pile_desc, PileActivity::class.java,
        intArrayOf(0xFF1D1B2E.toInt(), 0xFF0E4D52.toInt(), 0xFF7FE7D9.toInt()));

    companion object {
        fun parse(cle: String?): VersionApp? = values().firstOrNull { it.cle == cle }

        /** La version en cours ; Classique tant qu'aucune n'est choisie. */
        fun courante(context: Context): VersionApp = Store.versionApp(context) ?: CLASSIQUE

        /**
         * Depuis MainActivity : si une autre version est choisie, ouvre son accueil avec
         * l'intention reçue (note à écrire, etc.) et rend true ; MainActivity se ferme alors.
         */
        fun rediriger(activite: Activity): Boolean {
            val cible = courante(activite).accueil ?: return false
            activite.startActivity(Intent(activite, cible).apply { activite.intent?.extras?.let(::putExtras) })
            activite.overridePendingTransition(0, 0)
            activite.finish()
            return true
        }

        /** Après un changement de version : l'application repart de son accueil, sans pile d'écrans derrière. */
        fun appliquer(activite: Activity, version: VersionApp) {
            Store.setVersionApp(activite, version)
            activite.startActivity(
                Intent(activite, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            )
            activite.finish()
        }
    }
}
