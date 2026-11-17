package com.myhitbodedut

import android.content.Context
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/**
 * L'accueil selon l'heure (14/10) : la prière du moment (avec un lieu, ses
 * zmanim ; sans lieu, les heures fixes de SiddurMoment), et Birkat haLevana les
 * soirs où elle se dit. Chaque carte ouvre son texte, dans le noussa'h choisi.
 */
object AccueilMoment {

    private fun dp(c: Context, v: Int) = (v * c.resources.displayMetrics.density).toInt()

    fun cartes(c: Context): List<View> {
        val siddur = Data.siddur(c)
        val lieu = Store.lieuZmanim(c)
        // La nuit de Chabbat, de fête ou de 'Hol hamoed Pessa'h, pas de Tikoun 'hatsot (audit du 16/11) ; pas d'office
        // de semaine proposé un Chabbat ou un Yom tov (audit du 16/11, structure des offices).
        val moment = JourAffiche.momentOuvrable(
            if (lieu != null) JourAffiche.momentDuSiddour(lieu, java.time.Instant.now(), Store.inIsrael(c), Store.siddurNusah(c).cle)
            else SiddurMoment.suggestion(LocalTime.now(), JourAffiche.sansTikounHatsot(LocalDate.now(), Store.inIsrael(c))),
            LocalDate.now(), LocalTime.now(), Store.inIsrael(c))
        val vues = mutableListOf<View>()
        val mot = c.getString(Salutation.mot(LocalTime.now().hour))
        moment?.let(siddur::texte)?.let { t -> vues += carte(c, c.getString(R.string.siddur_maintenant), t.titre.he, SiddurMoment.illustration(t.id), mot) { SiddurLectureActivity.ouvrir(c, t.id) } }
        // Birkat haLevana : pendant la fenêtre, à partir de l'après-midi.
        val zone = lieu?.fuseau?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()
        val aujourdhui = LocalDate.now(zone)
        val f = Levana.fenetre(aujourdhui, zone, VueJour.usageLevana(c), Levana.Horaires.du(lieu, zone))
        // Ni un soir de Chabbat ou de Yom tov qui n'est pas le dernier (audit du 16/11, MB 426:12 ; YY 426:33).
        val etat = Levana.etat(f, aujourdhui, zone, Store.inIsrael(c))
        if (Store.levanaAffichee(c) && (etat == Levana.Etat.CeSoir || etat == Levana.Etat.DernierSoir) && LocalTime.now(zone).hour >= 14 &&
            java.time.Instant.now().isBefore(f.fin)) {
            siddur.texte("birkat_halevana")?.let { t ->
                vues += carte(c, c.getString(R.string.levana_ce_soir), t.titre.he, R.drawable.char_praise) { SiddurLectureActivity.ouvrir(c, t.id) }
            }
        }
        return vues
    }

    private fun carte(c: Context, etiquette: String, hebreu: String, image: Int, mot: String? = null, ouvrir: () -> Unit): View = LinearLayout(c).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setBackgroundResource(R.drawable.bg_card)
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(c, 12) }
        setPadding(dp(c, 12), dp(c, 8), dp(c, 12), dp(c, 8))
        foreground = Apparence.effetToucher(c)
        Effets.presse(this)
        setOnClickListener { ouvrir() }
        addView(PersonnageImageView(c).apply {
            setImageResource(image)
            adjustViewBounds = true
            contentDescription = null
            layoutParams = LinearLayout.LayoutParams(dp(c, 48), dp(c, 56))
        })
        addView(LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = dp(c, 12) }
            addView(TextView(c).apply {
                text = etiquette
                textSize = 12f
                isAllCaps = true
                letterSpacing = 0.06f
                setTextColor(Apparence.couleur(c, R.color.brand))
            })
            addView(TextView(c).apply {
                text = hebreu
                textSize = 21f
                setTypeface(typeface, Typeface.BOLD)
                textDirection = View.TEXT_DIRECTION_RTL
                textAlignment = View.TEXT_ALIGNMENT_VIEW_START
                setTextColor(Apparence.couleur(c, R.color.ink))
                PoliceHebraique.appliquer(this)
            })
            if (mot != null) addView(TextView(c).apply {
                text = mot
                textSize = 13f
                setTextColor(Apparence.couleur(c, R.color.muted))
            })
        })
        addView(ImageView(c).apply {
            layoutParams = LinearLayout.LayoutParams(dp(c, 22), dp(c, 22))
            setImageResource(R.drawable.ic_chevron)
            contentDescription = null
        })
    }
}
