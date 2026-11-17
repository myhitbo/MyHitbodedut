package com.myhitbodedut

import android.app.ActivityOptions
import android.content.Intent
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Version Sérénité (maquette « P2 · Sérénité pro — la carte du soir s'ouvre en paysage ») :
 * une application de recueillement haut de gamme. L'accueil tient dans une grande carte-paysage
 * qui suit le ciel du moment (CielDuJour) — étoiles la nuit, soleil couchant, matin bleu —
 * avec la silhouette du hassid ; dessous, le 'hizouk, le prochain zman et la semaine. Quatre
 * onglets en bas : Aujourd'hui, Zmanim, Textes, Journal. Titres en Bellefair.
 */
class SereniteActivity : AccueilVersion() {

    override val version = VersionApp.SERENITE

    private lateinit var contenu: LinearLayout
    private lateinit var racine: LinearLayout
    private lateinit var onglets: LinearLayout
    private var k = Palette.NUIT

    private val bellefair by lazy { VueVersion.police(this, R.font.bellefair) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return
        contenu = VueVersion.colonne(this).apply { setPadding(dp(20), dp(20), dp(20), dp(24)) }
        onglets = VueVersion.ligne(this)
        racine = VueVersion.colonne(this).apply {
            addView(ScrollView(context).apply {
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
                addView(contenu)
            })
            addView(onglets)
        }
        setContentView(racine)
    }

    override fun dessiner() {
        val phase = runCatching { CielDuJour.maintenant(this) }.getOrDefault(CielDuJour.Phase.NUIT)
        k = if (phase == CielDuJour.Phase.JOUR || phase == CielDuJour.Phase.AUBE) Palette.JOUR else Palette.NUIT
        VueVersion.barres(this, k.fond, clair = k == Palette.JOUR)
        racine.setBackgroundColor(k.fond)
        val d = DonneesAccueil.lire(this)
        contenu.removeAllViews()
        contenu.addView(entete(d))
        contenu.addView(cartePaysage(d, phase))
        contenu.addView(carteHizouk(d))
        contenu.addView(carteZman(d))
        contenu.addView(semaine(d))
        dessinerOnglets()
    }

    // --- En-tête ---------------------------------------------------------------------

    private fun entete(d: DonneesAccueil): View = VueVersion.colonne(this).apply {
        addView(VueVersion.ligne(context).apply {
            addView(VueVersion.texte(context,
                if (d.prenom.isNotBlank()) getString(Salutation.chaine(java.time.LocalTime.now().hour), d.prenom) else getString(R.string.pile_titre),
                32f, k.texte, bellefair).apply { layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f) })
            // L'initiale du prénom ouvre le profil, c'est-à-dire les réglages.
            addView(VueVersion.texte(context, d.prenom.firstOrNull()?.uppercase() ?: "⚙", 16f, k.texte).apply {
                layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
                gravity = Gravity.CENTER
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                background = VueVersion.fond(context, 24, k.bouton, bord = k.boutonBord)
                contentDescription = getString(R.string.version_reglages)
                isClickable = true
                setOnClickListener { ouvrirReglages() }
            })
        })
        addView(VueVersion.texte(context,
            listOfNotNull(d.dateCivile, d.dateHebraique, resources.getQuantityString(R.plurals.version_serie, d.serie, d.serie)).joinToString(" · "),
            14f, k.texte2, haut = 4))
    }

    // --- La carte-paysage ------------------------------------------------------------

    private fun cartePaysage(d: DonneesAccueil, phase: CielDuJour.Phase): View = FrameLayout(this).apply {
        // La moitié de l'écran, entre 300 et 380 dp, agrandie avec le texte du système : sur un
        // 480x854 le titre et le bouton restaient sous les onglets (petits écrans, 17/11).
        val haut = (resources.configuration.screenHeightDp / 2).coerceIn(300, 380) * resources.configuration.fontScale.coerceIn(1f, 1.4f)
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(haut.toInt())).apply { topMargin = dp(18) }
        background = PaysageCiel(phase, resources.displayMetrics.density)
        outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: View, outline: android.graphics.Outline) = outline.setRoundRect(0, 0, view.width, view.height, dp(32).toFloat())
        }
        clipToOutline = true
        val enCours = Store.isSessionRunning(context)
        contentDescription = getString(R.string.serenite_ouvrir, getString(R.string.serenite_titre, DonneesAccueil.duree(context, d.objectifMinutes)))
        isClickable = true
        isFocusable = true
        setOnClickListener { v ->
            val options = ActivityOptions.makeScaleUpAnimation(v, 0, 0, v.width, v.height)
            startActivity(Intent(context, SessionActivity::class.java).putExtra(SessionActivity.EXTRA_START_NOW, !enCours), options.toBundle())
        }
        // La silhouette du hassid, posée sur la colline.
        addView(ImageView(context).apply {
            setImageResource(Personnage.pour(context, R.drawable.char_debout))
            setColorFilter(0xE0000000.toInt(), android.graphics.PorterDuff.Mode.SRC_IN)
            scaleType = ImageView.ScaleType.FIT_END
            layoutParams = FrameLayout.LayoutParams(dp(56), dp(84), Gravity.END or Gravity.BOTTOM).apply { setMargins(0, 0, dp(96), dp(112)) }
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        })
        // Le voile du bas, sous le texte.
        addView(View(context).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(190), Gravity.BOTTOM)
            background = android.graphics.drawable.GradientDrawable(android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(android.graphics.Color.TRANSPARENT, 0xE614111F.toInt()))
        })
        addView(VueVersion.colonne(context).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM).apply {
                setMargins(dp(20), 0, dp(92), dp(22))
            }
            addView(VueVersion.texte(context, getString(when {
                enCours -> R.string.serenite_en_cours
                d.faite -> R.string.serenite_faite
                phase == CielDuJour.Phase.NUIT || phase == CielDuJour.Phase.COUCHER -> R.string.serenite_ce_soir
                else -> R.string.serenite_aujourdhui
            }), 12f, PECHE_CLAIR, majuscules = true, espacement = 0.1f).apply { setTypeface(typeface, android.graphics.Typeface.BOLD) })
            addView(VueVersion.texte(context,
                if (d.faite && !enCours) getString(R.string.serenite_titre, DonneesAccueil.duree(context, d.minutesAujourdhui))
                else getString(R.string.serenite_titre, DonneesAccueil.duree(context, d.objectifMinutes)),
                30f, 0xFFFFFFFF.toInt(), bellefair, haut = 4))
            addView(VueVersion.texte(context, reglage(), 14f, 0xFFD9D0E6.toInt(), haut = 6))
        })
        // Le bouton rond : commencer, ou revenir à la hitbodedout en cours.
        addView(TextView(context).apply {
            layoutParams = FrameLayout.LayoutParams(dp(56), dp(56), Gravity.END or Gravity.BOTTOM).apply { setMargins(0, 0, dp(20), dp(24)) }
            background = VueVersion.fond(context, 28, PECHE)
            text = "▶"
            textSize = 20f
            gravity = Gravity.CENTER
            setTextColor(VIOLET)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        })
        // « Modifier » : durée, sujet, musique.
        addView(VueVersion.texte(context, getString(R.string.serenite_modifier), 14f, 0xFFFFFFFF.toInt()).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(44), Gravity.END or Gravity.TOP).apply { setMargins(0, dp(14), dp(14), 0) }
            gravity = Gravity.CENTER
            setPadding(dp(16), 0, dp(16), 0)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            background = VueVersion.fond(context, 22, 0x40FFFFFF)
            contentDescription = getString(R.string.version_preparer)
            isClickable = true
            setOnClickListener { preparerSeance() }
        })
    }

    /** « Pluie · Le niggoun du Yanuka », « Silence ». */
    private fun reglage(): String {
        val ambiance = Ambiance.of(Store.ambiance(this))
        val morceau = if (Store.musicEnabled(this)) MusicLibrary.selected(this)?.title else null
        return listOfNotNull(getString(ambiance.titre).takeIf { ambiance != Ambiance.SILENCE || morceau == null }, morceau).joinToString(" · ")
    }

    // --- Les cartes du dessous -------------------------------------------------------

    private fun carte(haut: Int = 14, contenu: LinearLayout.() -> Unit): LinearLayout = VueVersion.colonne(this).apply {
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(haut) }
        background = VueVersion.fond(context, 24, k.carte, bord = k.ligne)
        setPadding(dp(18), dp(16), dp(18), dp(16))
        contenu()
    }

    private fun LinearLayout.titreSection(texte: String, action: String? = null, ouvrir: (() -> Unit)? = null) {
        addView(VueVersion.ligne(context).apply {
            addView(VueVersion.texte(context, texte, 13f, k.texte2, majuscules = true, espacement = 0.1f).apply {
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            })
            if (action != null && ouvrir != null) addView(VueVersion.texte(context, action, 14f, k.accent).apply {
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                minHeight = dp(40)
                gravity = Gravity.CENTER_VERTICAL
                isClickable = true
                setOnClickListener { ouvrir() }
            })
        })
    }

    private fun carteHizouk(d: DonneesAccueil): View = carte(18) {
        titreSection(getString(R.string.pile_hizouk), getString(R.string.serenite_lire)) { ouvrirChizuk() }
        val p = d.pensee
        if (p == null) {
            addView(VueVersion.texte(context, getString(R.string.version_chargement), 15f, k.texte2, haut = 6))
            return@carte
        }
        addView(VueVersion.hebreu(context, p.hebreu, 20f, k.texte, haut = 6).apply {
            maxLines = 3
            ellipsize = android.text.TextUtils.TruncateAt.END
        })
        p.traduction?.let {
            addView(VueVersion.texte(context, it, 17f, k.texte, bellefair, haut = 8).apply {
                maxLines = 3
                ellipsize = android.text.TextUtils.TruncateAt.END
                setLineSpacing(dp(3).toFloat(), 1f)
            })
        }
        addView(VueVersion.texte(context, p.reference, 13f, k.texte2, haut = 8))
    }

    private fun carteZman(d: DonneesAccueil): View = carte {
        titreSection(d.lieu?.let { getString(R.string.pile_zmanim_lieu, it) } ?: getString(R.string.pile_zmanim), getString(R.string.serenite_tout_voir)) { ouvrirZmanim() }
        val z = d.prochain
        if (z == null) {
            addView(VueVersion.texte(context, getString(R.string.version_sans_lieu), 15f, k.texte2, haut = 6))
            return@carte
        }
        addView(VueVersion.texte(context, z.nom, 24f, k.texte, bellefair, haut = 4))
        addView(VueVersion.texte(context, "${z.heure} · ${d.dans(context, z)}", 15f, k.texte2, haut = 2))
    }

    private fun semaine(d: DonneesAccueil): View = carte {
        titreSection(getString(R.string.serenite_cette_semaine), getString(R.string.serenite_tout_voir)) { ouvrirJournal() }
        val verrou = VerrouJournal.actif(context)
        val jours = Store.days(context).values.filter { it.faite }.sortedByDescending { it.date }.take(3)
        if (jours.isEmpty()) {
            addView(VueVersion.texte(context, getString(R.string.version_journal_vide), 15f, k.texte2, haut = 6))
        }
        jours.forEachIndexed { i, r ->
            addView(VueVersion.colonne(context).apply {
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(if (i == 0) 6 else 12) }
                addView(VueVersion.ligne(context).apply {
                    addView(VueVersion.texte(context, DonneesAccueil.jour(context, Store.parse(r.date)), 15f, k.texte).apply {
                        layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                    })
                    addView(VueVersion.texte(context, DonneesAccueil.duree(context, r.minutes), 15f, k.texte2))
                })
                if (r.note.isNotBlank() && !verrou) addView(VueVersion.texte(context, r.note, 14f, k.texte2, haut = 2).apply {
                    maxLines = 1
                    ellipsize = android.text.TextUtils.TruncateAt.END
                })
            })
        }
        addView(VueVersion.bouton(context, getString(R.string.version_ecrire_note), k.accent, k.accent, trait = true, taille = 15f) { ecrireNote() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(16)
        })
    }

    // --- Les onglets -------------------------------------------------------------------

    private fun dessinerOnglets() {
        onglets.removeAllViews()
        onglets.setBackgroundColor(k.fond)
        onglets.setPadding(dp(8), dp(6), dp(8), dp(8))
        listOf(
            Triple(R.string.version_aujourdhui, R.drawable.ic_nav_today, null),
            Triple(R.string.pile_zmanim, R.drawable.ic_ciel, { ouvrirZmanim() }),
            Triple(R.string.version_textes, R.drawable.ic_nav_texts, { ouvrirTextes() }),
            Triple(R.string.pile_journal, R.drawable.ic_marque_etude, { ouvrirJournal() }),
        ).forEach { (nom, icone, action) ->
            val actif = action == null
            onglets.addView(VueVersion.colonne(this).apply {
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_HORIZONTAL
                minimumHeight = dp(56)
                setPadding(0, dp(6), 0, dp(4))
                contentDescription = getString(nom)
                isSelected = actif
                isClickable = true
                setOnClickListener { action?.invoke() }
                addView(ImageView(context).apply {
                    setImageResource(icone)
                    imageTintList = android.content.res.ColorStateList.valueOf(if (actif) k.accent else k.texte2)
                    layoutParams = LinearLayout.LayoutParams(dp(24), dp(24))
                    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                })
                addView(VueVersion.texte(context, getString(nom), 12f, if (actif) k.accent else k.texte2, haut = 4).apply {
                    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                    if (actif) setTypeface(typeface, android.graphics.Typeface.BOLD)
                })
            })
        }
    }

    // --- Les couleurs ------------------------------------------------------------------

    /** Les deux palettes de la maquette : la nuit (et le soir), le jour (et l'aube). */
    private enum class Palette(
        val fond: Int, val texte: Int, val texte2: Int, val carte: Int, val ligne: Int,
        val bouton: Int, val boutonBord: Int, val accent: Int,
    ) {
        NUIT(0xFF14111F.toInt(), 0xFFF4EEF8.toInt(), 0xFFB3A9C4.toInt(), 0xFF1F1A2E.toInt(), 0xFF2C2545.toInt(),
            0xFF1F1A2E.toInt(), 0xFF2E2742.toInt(), 0xFFF2C6A0.toInt()),
        JOUR(0xFFF7F2EA.toInt(), 0xFF231C33.toInt(), 0xFF5F566E.toInt(), 0xFFFFFFFF.toInt(), 0xFFEEE6F3.toInt(),
            0xFFFFFFFF.toInt(), 0xFFDCD2C6.toInt(), 0xFF5B3FA0.toInt()),
    }

    private companion object {
        val PECHE = 0xFFF2C6A0.toInt()
        val PECHE_CLAIR = 0xFFF7CDA8.toInt()
        val VIOLET = 0xFF2E2366.toInt()
    }
}
