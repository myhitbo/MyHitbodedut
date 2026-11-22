package com.myhitbodedut

import android.animation.ValueAnimator
import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import java.time.LocalDate
import java.time.format.TextStyle

/**
 * Version Instant (17/11, d'après une image de tableau de bord de bien-être fournie par le
 * propriétaire) : fond sombre, cartes arrondies, une grande carte en tête puis des mesures
 * lisibles d'un coup d'œil. Dans la carte de tête, à la place de la photo, le ciel réel du
 * moment (PaysageCiel, selon CielDuJour) avec les zmanim, en petit. Dessous : la jauge de la
 * semaine en demi-cercle, les minutes des sept derniers jours en barres, le 'hizouk sur une
 * carte vert olive, la dernière note. Titres en Bellefair.
 */
class InstantActivity : AccueilVersion() {

    override val version = VersionApp.INSTANT

    private lateinit var contenu: LinearLayout
    private val bellefair by lazy { VueVersion.police(this, R.font.bellefair) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return
        VueVersion.barres(this, FOND, clair = false)
        contenu = VueVersion.colonne(this).apply { setPadding(dp(16), dp(12), dp(16), dp(24)) }
        setContentView(ScrollView(this).apply {
            setBackgroundColor(FOND)
            addView(contenu)
        })
    }

    override fun dessiner() {
        val d = DonneesAccueil.lire(this)
        val phase = runCatching { CielDuJour.maintenant(this) }.getOrDefault(CielDuJour.Phase.JOUR)
        contenu.removeAllViews()
        contenu.addView(entete(d))
        contenu.addView(carteCiel(d, phase))
        contenu.addView(VueVersion.ligne(this).apply {
            gravity = Gravity.TOP
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            addView(carteJauge(d).apply { layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { topMargin = dp(12); marginEnd = dp(6) } })
            addView(carteSerie(d).apply { layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { topMargin = dp(12); marginStart = dp(6) } })
        })
        contenu.addView(carteMinutes())
        contenu.addView(carteHizouk(d))
        contenu.addView(carteJournal(d))
    }

    // --- En-tête : réglages à gauche, initiale à droite, comme l'image -----------------------

    private fun entete(d: DonneesAccueil): View = VueVersion.ligne(this).apply {
        setPadding(0, 0, 0, dp(8))
        addView(rond(R.drawable.ic_nav_settings_off, getString(R.string.version_reglages)) { ouvrirReglages() })
        addView(VueVersion.texte(context, d.dateCivile, 14f, DOUX).apply {
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            gravity = Gravity.CENTER
        })
        addView(rond(R.drawable.ic_nav_texts, getString(R.string.version_textes)) { ouvrirTextes() })
    }

    private fun rond(icone: Int, description: String, action: () -> Unit): View =
        VueVersion.icone(this, icone, ENCRE, description, action).apply { background = VueVersion.fond(context, 24, CARTE) }

    private fun carte(fond: Int = CARTE, contenu: LinearLayout.() -> Unit): LinearLayout = VueVersion.colonne(this).apply {
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(12) }
        background = VueVersion.fond(context, 24, fond)
        setPadding(dp(18), dp(16), dp(18), dp(18))
        contenu()
    }

    private fun LinearLayout.titre(texte: String, couleur: Int = ENCRE) =
        addView(VueVersion.texte(context, texte, 15f, couleur).apply { setTypeface(typeface, android.graphics.Typeface.BOLD) })

    // --- La carte du ciel ------------------------------------------------------------------

    private fun carteCiel(d: DonneesAccueil, phase: CielDuJour.Phase): View = FrameLayout(this).apply {
        // Au moins 300 dp ; plus haute si le texte agrandi ou un écran étroit l'exigent, au lieu de
        // faire chevaucher le titre et les zmanim (petits écrans, 17/11).
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(4) }
        minimumHeight = dp(300)
        background = PaysageCiel(phase, resources.displayMetrics.density)
        outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: View, outline: android.graphics.Outline) = outline.setRoundRect(0, 0, view.width, view.height, dp(28).toFloat())
        }
        clipToOutline = true
        // Un voile en haut et en bas pour que le texte reste lisible sur un ciel clair.
        addView(View(context).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            background = android.graphics.drawable.GradientDrawable(android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0x8C000000.toInt(), 0x10000000, 0x99000000.toInt()))
        })
        val pile = VueVersion.colonne(context).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        addView(pile)
        pile.addView(VueVersion.colonne(context).apply {
            setPadding(dp(20), dp(18), dp(20), 0)
            addView(VueVersion.texte(context,
                if (d.faite) getString(R.string.serenite_faite) else getString(R.string.instant_titre),
                30f, BLANC, bellefair).apply { setLineSpacing(0f, 0.92f) })
            addView(VueVersion.texte(context, d.dateHebraique ?: "", 14f, 0xDDFFFFFF.toInt(), haut = 2))
            val enCours = Store.isSessionRunning(context)
            addView(VueVersion.texte(context,
                when {
                    enCours -> getString(R.string.version_reprendre)
                    d.faite -> getString(R.string.version_encore)
                    else -> getString(R.string.version_commencer, DonneesAccueil.duree(context, d.objectifMinutes))
                }, 15f, NOIR, haut = 14).apply {
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                background = VueVersion.fond(context, 22, BLANC)
                minHeight = dp(44)
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(18), 0, dp(18), 0)
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(14) }
                isClickable = true
                setOnClickListener { v ->
                    val o = ActivityOptions.makeScaleUpAnimation(v, 0, 0, v.width, v.height)
                    startActivity(Intent(context, SessionActivity::class.java).putExtra(SessionActivity.EXTRA_START_NOW, !enCours), o.toBundle())
                }
            })
        })
        pile.addView(View(context).apply { layoutParams = LinearLayout.LayoutParams(1, 0, 1f).apply { topMargin = dp(20) } })
        // Les zmanim, en petit : le prochain, puis les repères du jour sur une ligne.
        pile.addView(VueVersion.colonne(context).apply {
            setPadding(dp(20), 0, dp(20), dp(16))
            contentDescription = d.prochain?.let { getString(R.string.version_prochain, it.nom) + ", " + it.heure } ?: getString(R.string.version_sans_lieu)
            isClickable = true
            setOnClickListener { ouvrirZmanim() }
            val z = d.prochain
            addView(VueVersion.texte(context,
                z?.let { getString(R.string.version_prochain, it.nom) + " · " + it.heure + " · " + d.dans(context, it) } ?: getString(R.string.version_choisir_lieu),
                13f, BLANC).apply { maxLines = 2 })
            if (d.zmanim.isNotEmpty()) addView(VueVersion.texte(context,
                d.zmanim.joinToString("   ") { "${court(it.cle)} ${it.heure}" }, 11f, 0xB3FFFFFF.toInt(), haut = 4).apply {
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.END
            })
        })
    }

    /** Le nom court d'un zman pour la ligne discrète de la carte du ciel. */
    private fun court(cle: String): String = getString(when (cle) {
        "netz" -> R.string.instant_z_netz
        "chatsot" -> R.string.instant_z_chatsot
        "minha_ketana" -> R.string.instant_z_minha
        "chkia" -> R.string.instant_z_chkia
        else -> R.string.instant_z_tset
    })

    // --- Les mesures -----------------------------------------------------------------------

    private fun carteJauge(d: DonneesAccueil): View = carte {
        titre(getString(R.string.instant_semaine))
        addView(Jauge(context, d.semaineFaits, d.semaineDus).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(96)).apply { topMargin = dp(10) }
            contentDescription = getString(R.string.version_semaine, d.semaineFaits, d.semaineDus)
        })
        addView(VueVersion.texte(context, "${d.semaineFaits} / ${d.semaineDus}", 22f, ENCRE, bellefair).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = -dp(40) }
            gravity = Gravity.CENTER
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        })
        addView(VueVersion.texte(context, getString(R.string.instant_cette_semaine), 12f, DOUX).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            gravity = Gravity.CENTER
        })
    }

    private fun carteSerie(d: DonneesAccueil): View = carte {
        isClickable = true
        setOnClickListener { ouvrirParcours() }
        titre(getString(R.string.instant_serie))
        addView(VueVersion.texte(context, d.serie.toString(), 44f, ENCRE, bellefair, haut = 8).apply { includeFontPadding = false })
        addView(VueVersion.texte(context, resources.getQuantityString(R.plurals.bento_jours, d.serie), 12f, DOUX))
        addView(VueVersion.texte(context, getString(R.string.instant_total, DonneesAccueil.duree(context, d.totalMinutes)), 12f, OLIVE, haut = 12))
    }

    private fun carteMinutes(): View = carte {
        isClickable = true
        setOnClickListener { ouvrirJournal() }
        val jours = (6 downTo 0).map { LocalDate.now().minusDays(it.toLong()) }
        val tous = Store.days(context)
        val minutes = jours.map { j -> tous[j.format(java.time.format.DateTimeFormatter.ISO_LOCAL_DATE)]?.minutes ?: 0 }
        val moyenne = minutes.filter { it > 0 }.takeIf { it.isNotEmpty() }?.average()?.toInt() ?: 0
        titre(getString(R.string.instant_minutes))
        addView(VueVersion.texte(context, DonneesAccueil.duree(context, minutes.sum()), 26f, ENCRE, bellefair, haut = 6))
        addView(VueVersion.texte(context, getString(R.string.instant_moyenne, DonneesAccueil.duree(context, moyenne)), 12f, DOUX))
        val langue = resources.configuration.locales[0]
        addView(Barres(context, minutes, moyenne, jours.map { it.dayOfWeek.getDisplayName(TextStyle.NARROW, langue) }).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(130)).apply { topMargin = dp(10) }
            contentDescription = getString(R.string.instant_minutes) + " : " + minutes.joinToString(", ")
        })
    }

    private fun carteHizouk(d: DonneesAccueil): View = carte(OLIVE) {
        isClickable = true
        setOnClickListener { ouvrirChizuk() }
        addView(VueVersion.texte(context, getString(R.string.pile_hizouk), 11f, OLIVE_ENCRE, majuscules = true, espacement = 0.12f).apply {
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        val p = d.pensee
        if (p == null) addView(VueVersion.texte(context, getString(R.string.version_chargement), 15f, OLIVE_ENCRE, haut = 6))
        else {
            addView(VueVersion.hebreu(context, p.hebreu, 18f, OLIVE_ENCRE, haut = 6).apply { maxLines = 3; ellipsize = android.text.TextUtils.TruncateAt.END })
            addView(VueVersion.texte(context, p.reference, 12f, OLIVE_DOUX, haut = 6))
        }
    }

    private fun carteJournal(d: DonneesAccueil): View = carte {
        titre(getString(R.string.pile_journal))
        val n = d.derniereNote
        addView(VueVersion.texte(context,
            n?.let { DonneesAccueil.jour(context, it.date) + " · " + DonneesAccueil.duree(context, it.minutes) } ?: getString(R.string.version_journal_vide),
            13f, DOUX, haut = 4))
        n?.texte?.let { addView(VueVersion.texte(context, it, 15f, ENCRE, haut = 6).apply { maxLines = 3; ellipsize = android.text.TextUtils.TruncateAt.END }) }
        addView(VueVersion.bouton(context, getString(R.string.version_ecrire_note), OLIVE, OLIVE_ENCRE, taille = 15f) { ecrireNote() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(14)
        })
    }

    // --- Les dessins -----------------------------------------------------------------------

    /** La jauge en demi-cercle de l'image : des graduations, les faites en orangé. */
    private class Jauge(c: Context, private val faits: Int, private val dus: Int) : View(c) {
        private val d = c.resources.displayMetrics.density
        private val trait = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeWidth = 3 * d; strokeCap = Paint.Cap.ROUND }
        private var part = if (ValueAnimator.areAnimatorsEnabled()) 0f else 1f

        init {
            if (part == 0f) ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 900
                addUpdateListener { part = it.animatedValue as Float; invalidate() }
                start()
            }
        }

        override fun onDraw(canvas: Canvas) {
            val n = 36
            val cible = if (dus > 0) (faits.toFloat() / dus).coerceIn(0f, 1f) else 0f
            val cx = width / 2f
            val cy = height - 4 * d
            val r1 = minOf(width / 2f, height.toFloat()) - 6 * d
            val r2 = r1 - 14 * d
            for (i in 0..n) {
                val a = Math.PI * (1 - i.toDouble() / n)
                trait.color = if (i.toFloat() / n <= cible * part && cible > 0) ORANGE else GRADUATION
                canvas.drawLine(cx + (r2 * Math.cos(a)).toFloat(), cy - (r2 * Math.sin(a)).toFloat(),
                    cx + (r1 * Math.cos(a)).toFloat(), cy - (r1 * Math.sin(a)).toFloat(), trait)
            }
        }
    }

    /** Les minutes des sept derniers jours ; aujourd'hui en vert olive, la moyenne en pointillé. */
    private class Barres(c: Context, private val minutes: List<Int>, private val moyenne: Int, private val jours: List<String>) : View(c) {
        private val d = c.resources.displayMetrics.density
        private val barre = Paint(Paint.ANTI_ALIAS_FLAG)
        private val ligne = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x99FFFFFF.toInt(); strokeWidth = d; style = Paint.Style.STROKE
        }
        private val texte = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = DOUX; textSize = 11 * d; textAlign = Paint.Align.CENTER }
        private val r = RectF()
        private var pousse = if (ValueAnimator.areAnimatorsEnabled()) 0f else 1f

        init {
            if (pousse == 0f) ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 700
                addUpdateListener { pousse = it.animatedValue as Float; invalidate() }
                start()
            }
        }

        override fun onDraw(canvas: Canvas) {
            val bas = height - 18 * d
            val max = maxOf(minutes.maxOrNull() ?: 0, moyenne, 15).toFloat()
            val ecart = 8 * d
            val l = (width - ecart * (minutes.size - 1)) / minutes.size
            minutes.forEachIndexed { i, m ->
                val h = maxOf(4 * d, bas * (m / max)) * pousse
                val x = i * (l + ecart)
                barre.color = when {
                    i == minutes.lastIndex -> OLIVE
                    m > 0 -> BARRE
                    else -> GRADUATION
                }
                r.set(x, bas - h, x + l, bas)
                canvas.drawRoundRect(r, 5 * d, 5 * d, barre)
                canvas.drawText(jours[i], x + l / 2, height - 3 * d, texte)
            }
            if (moyenne > 0) {
                val y = bas - bas * (moyenne / max)
                canvas.drawLine(0f, y, width.toFloat(), y, ligne)
            }
        }
    }

    private companion object {
        // Les couleurs de l'image : noir doux, cartes grises, vert olive, orangé.
        val FOND = 0xFF141414.toInt()
        val CARTE = 0xFF232323.toInt()
        val ENCRE = 0xFFF2F2F2.toInt()
        val DOUX = 0xFF9A9A9A.toInt()
        val BLANC = 0xFFFFFFFF.toInt()
        val NOIR = 0xFF141414.toInt()
        val OLIVE = 0xFFC2D67A.toInt()
        val OLIVE_ENCRE = 0xFF1E2410.toInt()
        val OLIVE_DOUX = 0xFF46512A.toInt()
        val ORANGE = 0xFFE8865A.toInt()
        val GRADUATION = 0xFF3A3A3A.toInt()
        val BARRE = 0xFF5C5C5C.toInt()
    }
}
