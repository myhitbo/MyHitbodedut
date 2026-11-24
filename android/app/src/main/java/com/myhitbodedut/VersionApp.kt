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
    SERENITE("serenite", R.string.version_serenite, R.string.version_serenite_desc, SereniteActivity::class.java,
        intArrayOf(0xFF14111F.toInt(), 0xFF4E3486.toInt(), 0xFFF2C6A0.toInt())),
    BENTO("bento", R.string.version_bento, R.string.version_bento_desc, BentoActivity::class.java,
        intArrayOf(0xFFF2F2EF.toInt(), 0xFF123B30.toInt(), 0xFFD9F56B.toInt())),
    INSTANT("instant", R.string.version_instant, R.string.version_instant_desc, InstantActivity::class.java,
        intArrayOf(0xFF141414.toInt(), 0xFF232323.toInt(), 0xFFC2D67A.toInt())),
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
            // CLEAR_TOP, depuis une notification ou une vignette : l'accueil de cette version déjà
            // ouvert dans la tâche est repris à neuf, avec l'intention reçue, au lieu d'en recevoir
            // un second par-dessus (relecture du 23/11). Pas depuis l'icône : sur une tâche ouverte
            // par une notification, Android repose MainActivity au-dessus de l'écran en cours, et
            // CLEAR_TOP aurait fermé cet écran — une saisie en cours avec lui.
            val recue = activite.intent
            val icone = recue?.action == Intent.ACTION_MAIN && recue.hasCategory(Intent.CATEGORY_LAUNCHER)
            activite.startActivity(
                Intent(activite, cible).apply {
                    if (!icone) addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    recue?.extras?.let(::putExtras)
                }
            )
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
