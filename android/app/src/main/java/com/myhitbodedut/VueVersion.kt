package com.myhitbodedut

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.annotation.DrawableRes
import androidx.annotation.FontRes
import androidx.core.content.res.ResourcesCompat

/**
 * Les briques des accueils des versions (VersionApp) : textes, cartes, boutons, dessinés
 * en code comme le reste de l'application, avec la police et les couleurs de chaque version.
 * Les couleurs sont fixes, choisies avec les maquettes : chaque version a son ambiance, de jour
 * comme de nuit (les réglages Fond et Boutons valent pour Classique).
 */
object VueVersion {

    fun dp(c: Context, v: Number): Int = (v.toFloat() * c.resources.displayMetrics.density).toInt()

    fun police(c: Context, @FontRes res: Int): Typeface? = runCatching { ResourcesCompat.getFont(c, res) }.getOrNull()

    /** Une police variable (Rubik, Heebo) à une graisse donnée : Android 9 et plus ; avant, la graisse d'origine. */
    fun police(c: Context, @FontRes res: Int, graisse: Int): Typeface? {
        val base = police(c, res) ?: return null
        return if (android.os.Build.VERSION.SDK_INT >= 28) Typeface.create(base, graisse, false) else base
    }

    fun texte(
        c: Context, valeur: CharSequence?, taille: Float, couleur: Int,
        police: Typeface? = null, haut: Int = 0, majuscules: Boolean = false, espacement: Float = 0f,
    ): TextView = TextView(c).apply {
        text = valeur
        setTextSize(TypedValue.COMPLEX_UNIT_SP, taille)
        setTextColor(couleur)
        police?.let { typeface = it }
        isAllCaps = majuscules
        letterSpacing = espacement
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(c, haut) }
    }

    /** Un texte hébreu : de droite à gauche, la police hébraïque choisie dans les réglages. */
    fun hebreu(c: Context, valeur: String, taille: Float, couleur: Int, haut: Int = 0): TextView =
        texte(c, valeur, taille, couleur, haut = haut).apply {
            textDirection = View.TEXT_DIRECTION_RTL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            textAlignment = View.TEXT_ALIGNMENT_VIEW_START
            setLineSpacing(dp(c, 5).toFloat(), 1f)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(c, haut) }
            PoliceHebraique.appliquer(this)
        }

    /** Un fond arrondi, uni ou en dégradé du haut vers le bas. */
    fun fond(c: Context, rayon: Number, vararg couleurs: Int, bord: Int? = null): GradientDrawable =
        (if (couleurs.size > 1) GradientDrawable(GradientDrawable.Orientation.TL_BR, couleurs) else GradientDrawable().apply { setColor(couleurs[0]) }).apply {
            cornerRadius = dp(c, rayon).toFloat()
            bord?.let { setStroke(dp(c, 1), it) }
        }

    fun colonne(c: Context): LinearLayout = LinearLayout(c).apply { orientation = LinearLayout.VERTICAL }

    fun ligne(c: Context): LinearLayout = LinearLayout(c).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }

    /** Un bouton en pilule, plein ou au trait, avec l'onde du toucher. */
    fun bouton(
        c: Context, libelle: CharSequence, fondCouleur: Int, encre: Int, police: Typeface? = null,
        trait: Boolean = false, taille: Float = 16f, rayon: Number = 28, action: () -> Unit,
    ): TextView = texte(c, libelle, taille, encre, police).apply {
        gravity = Gravity.CENTER
        minHeight = dp(c, 52)
        setPadding(dp(c, 22), dp(c, 12), dp(c, 22), dp(c, 12))
        val forme = if (trait) fond(c, rayon, android.graphics.Color.TRANSPARENT, bord = fondCouleur) else fond(c, rayon, fondCouleur)
        background = RippleDrawable(ColorStateList.valueOf(encre and 0x33FFFFFF), forme, fond(c, rayon, fondCouleur))
        isClickable = true
        isFocusable = true
        setOnClickListener { action() }
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    }

    /** Une icône touchable de 48 dp, teintée, avec sa description pour TalkBack. */
    fun icone(c: Context, @DrawableRes res: Int, teinte: Int, description: String, action: () -> Unit): ImageView = ImageView(c).apply {
        setImageResource(res)
        imageTintList = ColorStateList.valueOf(teinte)
        contentDescription = description
        scaleType = ImageView.ScaleType.CENTER
        val attr = TypedValue()
        c.theme.resolveAttribute(android.R.attr.selectableItemBackgroundBorderless, attr, true)
        setBackgroundResource(attr.resourceId)
        layoutParams = LinearLayout.LayoutParams(dp(c, 48), dp(c, 48))
        setOnClickListener { action() }
    }

    /** Le fond de la version jusque sous la barre d'état et la barre de gestes, et des icônes lisibles dessus. */
    fun barres(activite: android.app.Activity, fond: Int, clair: Boolean) {
        // Barres.installer a déjà posé la bande de la barre d'état aux couleurs du thème : la version la recouvre.
        activite.findViewById<View>(android.R.id.content)?.background = android.graphics.drawable.ColorDrawable(fond)
        activite.window.decorView.setBackgroundColor(fond)
        // Jusqu'à Android 14, le système peint encore la barre d'état de la couleur du thème.
        @Suppress("DEPRECATION")
        activite.window.statusBarColor = fond
        @Suppress("DEPRECATION")
        activite.window.navigationBarColor = fond
        androidx.core.view.WindowCompat.getInsetsController(activite.window, activite.window.decorView).apply {
            isAppearanceLightStatusBars = clair
            isAppearanceLightNavigationBars = clair
        }
    }
}
