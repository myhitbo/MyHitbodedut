package com.myhitbodedut

import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity

/**
 * Le choix de la version (17/11) : une fois au premier lancement, après la présentation, puis
 * depuis les réglages (« Version de l'app »). Chaque version a sa carte : son nom, ce qu'elle
 * change, et ses trois couleurs en aperçu. Quitter sans choisir garde Classique.
 */
class ChoixVersionActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val actuelle = Store.versionApp(this)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Premier lancement : sans choix, l'accueil d'origine, et la question ne revient pas.
                if (Store.versionApp(this@ChoixVersionActivity) == null) Store.setVersionApp(this@ChoixVersionActivity, VersionApp.CLASSIQUE)
                finish()
            }
        })
        val c = this
        val ink = Apparence.couleur(c, R.color.ink)
        val muted = Apparence.couleur(c, R.color.muted)
        val colonne = VueVersion.colonne(c).apply { setPadding(dp(20), dp(24), dp(20), dp(24)) }
        colonne.addView(VueVersion.texte(c, getString(R.string.version_choix_titre), 26f, ink).apply { setTypeface(typeface, android.graphics.Typeface.BOLD) })
        colonne.addView(VueVersion.texte(c, getString(R.string.version_choix_detail), 15f, muted, haut = 6))
        VersionApp.values().forEach { v -> colonne.addView(carte(v, v == (actuelle ?: VersionApp.CLASSIQUE), ink, muted)) }
        colonne.addView(VueVersion.texte(c, getString(R.string.version_choix_pied), 13f, muted, haut = 16))
        setContentView(ScrollView(c).apply { addView(colonne) })
    }

    private fun carte(v: VersionApp, choisie: Boolean, ink: Int, muted: Int): View {
        val c = this
        val accent = Apparence.couleur(c, R.color.brand)
        return VueVersion.ligne(c).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(14) }
            setPadding(dp(14), dp(14), dp(16), dp(14))
            background = VueVersion.fond(c, 20, Apparence.couleur(c, R.color.card), bord = if (choisie) accent else Apparence.couleur(c, R.color.line))
            isClickable = true
            isFocusable = true
            contentDescription = getString(v.nom) + ". " + getString(v.description) + if (choisie) ". " + getString(R.string.version_choisie) else ""
            setOnClickListener { VersionApp.appliquer(this@ChoixVersionActivity, v) }
            // L'aperçu : le fond de la version, une carte, son accent.
            addView(android.widget.FrameLayout(c).apply {
                layoutParams = LinearLayout.LayoutParams(dp(64), dp(88))
                background = VueVersion.fond(c, 14, v.apercu[0])
                addView(View(c).apply {
                    layoutParams = android.widget.FrameLayout.LayoutParams(dp(48), dp(52), Gravity.CENTER_HORIZONTAL or Gravity.TOP).apply { topMargin = dp(10) }
                    background = VueVersion.fond(c, 10, v.apercu[1])
                })
                addView(View(c).apply {
                    layoutParams = android.widget.FrameLayout.LayoutParams(dp(36), dp(10), Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM).apply { bottomMargin = dp(10) }
                    background = VueVersion.fond(c, 5, v.apercu[2])
                })
            })
            addView(VueVersion.colonne(c).apply {
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = dp(16) }
                addView(VueVersion.texte(c, getString(v.nom) + if (choisie) "  ✓" else "", 19f, if (choisie) accent else ink).apply {
                    setTypeface(typeface, android.graphics.Typeface.BOLD)
                })
                addView(VueVersion.texte(c, getString(v.description), 14f, muted, haut = 4))
            })
        }
    }

    private fun dp(v: Int) = VueVersion.dp(this, v)
}
