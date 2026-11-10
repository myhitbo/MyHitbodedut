package com.myhitbodedut

import android.app.Activity
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout

/**
 * Les trois traits du haut (10/11, « comme l'application Claude ») : sur chaque
 * écran secondaire, une barre fine, de la couleur de la barre d'état, porte un
 * bouton ☰ qui ramène au menu principal en refermant les écrans ouverts
 * par-dessus.
 *
 * Posée pour tous les écrans à la fois (Apparence.installer), comme les marges
 * des barres du système : aucune mise en page n'a à la prévoir. Le contenu de
 * l'écran est glissé sous la barre, sans changer d'identifiant ; ce que les
 * écrans ajoutent ensuite par-dessus le contenu (mini-lecteur, confettis,
 * réglages de lecture) reste par-dessus, barre comprise.
 */
object MenuPrincipal {

    /** L'accueil est le menu principal ; les autres occupent l'écran à dessein. */
    private val sansBarre: Set<Class<*>> = setOf(
        MainActivity::class.java,
        OnboardingActivity::class.java,
        CelebrationActivity::class.java,
        SessionActivity::class.java,
    )

    private const val HAUTEUR_DP = 48

    fun installer(activity: Activity) {
        if (activity.javaClass in sansBarre) return
        val contenu = activity.findViewById<FrameLayout>(android.R.id.content) ?: return
        if (contenu.findViewById<View>(R.id.menu_principal_barre) != null) return
        val ecran = contenu.getChildAt(0) ?: return

        val barre = FrameLayout(activity).apply {
            id = R.id.menu_principal_barre
            setBackgroundColor(couleurBarreEtat(activity))
        }
        barre.addView(ImageButton(activity).apply {
            setImageResource(R.drawable.ic_menu_principal)
            imageTintList = ColorStateList.valueOf(Color.WHITE)
            contentDescription = activity.getString(R.string.menu_principal)
            tooltipText = contentDescription
            setBackgroundResource(fondTouche(activity))
            setOnClickListener { revenir(activity) }
        }, FrameLayout.LayoutParams(dp(activity, HAUTEUR_DP), dp(activity, HAUTEUR_DP), Gravity.START or Gravity.CENTER_VERTICAL).apply {
            marginStart = dp(activity, 6)
        })

        val pile = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        contenu.removeView(ecran)
        pile.addView(barre, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(activity, HAUTEUR_DP)))
        pile.addView(ecran, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        contenu.addView(pile, 0, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
    }

    /**
     * L'accueil déjà ouvert est repris tel quel (onglet compris) et les écrans
     * au-dessus se ferment ; ouvert directement depuis un widget ou une
     * notification, l'écran laisse place à un accueil neuf.
     */
    fun revenir(activity: Activity) {
        activity.startActivity(Intent(activity, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
        activity.finish()
    }

    private fun couleurBarreEtat(activity: Activity): Int {
        val a = activity.theme.obtainStyledAttributes(intArrayOf(android.R.attr.statusBarColor))
        return try { a.getColor(0, 0) } finally { a.recycle() }
    }

    private fun fondTouche(activity: Activity): Int {
        val v = TypedValue()
        activity.theme.resolveAttribute(android.R.attr.selectableItemBackgroundBorderless, v, true)
        return v.resourceId
    }

    private fun dp(activity: Activity, valeur: Int): Int =
        (valeur * activity.resources.displayMetrics.density).toInt()
}
