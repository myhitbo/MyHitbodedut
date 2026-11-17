package com.myhitbodedut

import android.animation.ValueAnimator
import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Version Bento (maquette « E · Bento — tuiles qui s'ouvrent ») : un tableau de bord en tuiles,
 * sans barre d'onglets. Chaque tuile est un aperçu vivant — l'anneau de la semaine, les barres de
 * la série, le prochain zman, le 'hizouk, l'égaliseur de l'ambiance, la dernière note — et
 * s'ouvre en plein écran depuis sa propre place. La recherche reste en bas, sous le pouce.
 * Police : Heebo.
 */
class BentoActivity : AccueilVersion() {

    override val version = VersionApp.BENTO

    private lateinit var grille: LinearLayout
    private var animee = false

    private val heebo by lazy { VueVersion.police(this, R.font.heebo, 400) }
    private val heeboGras by lazy { VueVersion.police(this, R.font.heebo, 700) }
    private val heeboNoir by lazy { VueVersion.police(this, R.font.heebo, 900) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return
        VueVersion.barres(this, FOND, clair = true)
        grille = VueVersion.colonne(this).apply { setPadding(dp(16), dp(20), dp(16), dp(16)) }
        val racine = VueVersion.colonne(this).apply { setBackgroundColor(FOND) }
        racine.addView(ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
            addView(grille)
        })
        racine.addView(recherche())
        setContentView(racine)
    }

    override fun dessiner() {
        val d = DonneesAccueil.lire(this)
        grille.removeAllViews()
        grille.addView(entete(d))
        grille.addView(tuileHitbodedout(d))
        grille.addView(rangee(tuileSerie(d), tuileZmanim(d)))
        grille.addView(tuileHizouk(d))
        grille.addView(rangee(tuileAmbiance(), tuileJournal(d)))
        grille.addView(rangee(
            petiteTuile(getString(R.string.bento_siddour), BLANC, ENCRE) { ouvrirSiddour() },
            petiteTuile(getString(R.string.bento_tehilim), BLANC, ENCRE) { ouvrirTehilim() },
        ))
        // Les tuiles entrent en cascade à la première ouverture seulement (maquette : +80 ms chacune).
        if (!animee && ValueAnimator.areAnimatorsEnabled()) {
            animee = true
            for (i in 0 until grille.childCount) grille.getChildAt(i).apply {
                alpha = 0f
                translationY = dp(10).toFloat()
                animate().alpha(1f).translationY(0f).setStartDelay(80L * i).setDuration(500).start()
            }
        }
    }

    // --- En-tête et recherche ------------------------------------------------------

    private fun entete(d: DonneesAccueil): View = VueVersion.ligne(this).apply {
        setPadding(dp(4), 0, 0, dp(12))
        addView(VueVersion.colonne(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            addView(VueVersion.texte(context, listOfNotNull(d.dateCivile, d.dateHebraique).joinToString(" · "), 14f, DOUX, heebo))
            addView(VueVersion.texte(context,
                // Bonjour le matin, bonsoir le soir (Salutation) ; sans prénom, « Votre journée ».
                if (d.prenom.isNotBlank()) getString(Salutation.chaine(java.time.LocalTime.now().hour), d.prenom) else getString(R.string.pile_titre),
                28f, ENCRE, heeboNoir))
        })
        // La pastille du hassid ouvre les réglages, comme l'avatar d'un compte.
        addView(FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
            background = VueVersion.fond(context, 24, CITRON)
            clipToOutline = true
            contentDescription = getString(R.string.version_reglages)
            isClickable = true
            setOnClickListener { ouvrirReglages() }
            addView(ImageView(context).apply {
                setImageResource(Personnage.pour(context, R.drawable.char_welcome))
                scaleType = ImageView.ScaleType.FIT_END
                layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            })
        })
    }

    private fun recherche(): View = VueVersion.ligne(this).apply {
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)).apply {
            setMargins(dp(16), dp(4), dp(16), dp(12))
        }
        background = VueVersion.fond(context, 28, BLANC)
        setPadding(dp(18), 0, dp(18), 0)
        isClickable = true
        isFocusable = true
        contentDescription = getString(R.string.bento_recherche)
        setOnClickListener { ouvrirDepuis(this, Intent(context, RechercheActivity::class.java)) }
        addView(ImageView(context).apply {
            setImageResource(R.drawable.ic_loupe)
            imageTintList = android.content.res.ColorStateList.valueOf(DOUX)
            layoutParams = LinearLayout.LayoutParams(dp(22), dp(22))
        })
        addView(VueVersion.texte(context, getString(R.string.bento_recherche), 15f, DOUX, heebo).apply {
            (layoutParams as LinearLayout.LayoutParams).marginStart = dp(10)
        })
    }

    // --- Les tuiles ------------------------------------------------------------------

    /** Une tuile : arrondie, qui s'enfonce un peu sous le doigt (maquette : 0,97 en 160 ms). */
    private fun tuile(fond: Int, hauteur: Int, description: String, action: (View) -> Unit): FrameLayout = FrameLayout(this).apply {
        // Le texte agrandi du système (jusqu'à 1,5) agrandit les tuiles d'autant : rien ne se chevauche.
        val echelle = resources.configuration.fontScale.coerceIn(1f, 1.5f)
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp((hauteur * echelle).toInt())).apply { topMargin = dp(10) }
        background = VueVersion.fond(context, 24, fond)
        clipToOutline = true
        setPadding(dp(18), dp(16), dp(18), dp(16))
        isClickable = true
        isFocusable = true
        contentDescription = description
        setOnClickListener { action(it) }
        setOnTouchListener { v, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> v.animate().scaleX(0.97f).scaleY(0.97f).setDuration(160).start()
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> v.animate().scaleX(1f).scaleY(1f).setDuration(160).start()
            }
            false
        }
    }

    private fun rangee(a: View, b: View): View = VueVersion.ligne(this).apply {
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        gravity = Gravity.TOP
        listOf(a, b).forEachIndexed { i, v ->
            v.layoutParams = LinearLayout.LayoutParams(0, (v.layoutParams as ViewGroup.MarginLayoutParams).height, 1f).apply {
                topMargin = dp(10)
                if (i == 0) marginEnd = dp(5) else marginStart = dp(5)
            }
            addView(v)
        }
    }

    /** L'écran s'ouvre en grandissant depuis la tuile touchée (le « container transform » de la maquette). */
    private fun ouvrirDepuis(tuile: View, intent: Intent) {
        val options = ActivityOptions.makeScaleUpAnimation(tuile, 0, 0, tuile.width, tuile.height)
        startActivity(intent, options.toBundle())
    }

    private fun tuileHitbodedout(d: DonneesAccueil): View = tuile(VERT, 208, getString(R.string.pile_hitbodedout)) { v ->
        ouvrirDepuis(v, Intent(this, SessionActivity::class.java).putExtra(SessionActivity.EXTRA_START_NOW, !Store.isSessionRunning(this)))
    }.apply {
        addView(ImageView(context).apply {
            setImageResource(Personnage.pour(context, R.drawable.char_debout))
            scaleType = ImageView.ScaleType.FIT_END
            layoutParams = FrameLayout.LayoutParams(dp(130), dp(180), Gravity.END or Gravity.BOTTOM).apply { setMargins(0, 0, -dp(14), -dp(16)) }
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        })
        // Une seule colonne, l'anneau en haut et le texte en bas, séparés par un ressort : sur un
        // écran étroit (320 dp) le titre passe sur deux lignes, et la tuile grandit au lieu de
        // faire chevaucher l'anneau et le titre (petits écrans, 17/11).
        layoutParams = (layoutParams as LinearLayout.LayoutParams).apply {
            minimumHeight = height
            height = ViewGroup.LayoutParams.WRAP_CONTENT
        }
        addView(VueVersion.colonne(context).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            addView(Anneau(context, d.semaineFaits, d.semaineDus, heeboGras).apply {
                layoutParams = LinearLayout.LayoutParams(dp(72), dp(72))
                contentDescription = getString(R.string.version_semaine, d.semaineFaits, d.semaineDus)
            })
            addView(View(context).apply { layoutParams = LinearLayout.LayoutParams(1, 0, 1f).apply { topMargin = dp(12) } })
            addView(VueVersion.colonne(context).apply {
            // La place à gauche du hassid (130 dp, débordant de 14) : le titre ne passe plus dessous.
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { marginEnd = dp(104) }
            addView(VueVersion.texte(context,
                if (d.faite) getString(R.string.bento_faite, DonneesAccueil.duree(context, d.minutesAujourdhui)) else getString(R.string.bento_hitbo_titre),
                22f, BLANC, heeboGras))
            val enCours = Store.isSessionRunning(context)
            addView(VueVersion.texte(context,
                when {
                    enCours -> getString(R.string.version_reprendre)
                    d.faite -> getString(R.string.version_encore)
                    // Texte agrandi ou écran étroit : « Commencer » seul, la durée ne tenait plus sur la ligne.
                    resources.configuration.fontScale > 1.15f || resources.configuration.screenWidthDp < 360 -> getString(R.string.version_commencer_court)
                    else -> getString(R.string.version_commencer, DonneesAccueil.duree(context, d.objectifMinutes))
                }, 15f, VERT, heeboGras, haut = 10).apply {
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.END
                background = VueVersion.fond(context, 21, CITRON)
                minHeight = dp(42)
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(18), 0, dp(18), 0)
            })
            })
        })
    }

    private fun tuileSerie(d: DonneesAccueil): View = tuile(BLANC, 150, resources.getQuantityString(R.plurals.version_serie, d.serie, d.serie)) { ouvrirParcours() }.apply {
        addView(VueVersion.colonne(context).apply {
            addView(VueVersion.texte(context, d.serie.toString(), 44f, ENCRE, heeboNoir).apply { includeFontPadding = false })
            addView(VueVersion.texte(context, resources.getQuantityString(R.plurals.bento_jours, d.serie), 13f, DOUX, heebo))
        })
        addView(Barres(context, Store.currentWeek(context).map { it.done }).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(36), Gravity.BOTTOM)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        })
    }

    private fun tuileZmanim(d: DonneesAccueil): View {
        val z = d.prochain
        val description = z?.let { getString(R.string.version_prochain, it.nom) + ", " + d.dans(this, it) } ?: getString(R.string.pile_zmanim)
        return tuile(BLEU_FOND, 150, description) { v -> ouvrirDepuis(v, Intent(this, ZmanimActivity::class.java)) }.apply {
            addView(VueVersion.colonne(context).apply {
                if (z == null) {
                    addView(VueVersion.texte(context, getString(R.string.pile_zmanim), 13f, BLEU_DOUX, heebo))
                    addView(VueVersion.texte(context, getString(R.string.version_choisir_lieu), 20f, BLEU_ENCRE, heeboNoir, haut = 4))
                } else {
                    addView(VueVersion.texte(context, z.nom, 13f, BLEU_DOUX, heebo).apply { maxLines = 2 })
                    addView(VueVersion.texte(context, d.dans(context, z), 26f, BLEU_ENCRE, heeboNoir, haut = 4).apply { includeFontPadding = false })
                }
            })
            d.zmanim.lastOrNull { it.cle == "chkia" }?.let { c ->
                addView(VueVersion.texte(context, "${c.nom} ${c.heure}", 13f, BLEU_DOUX, heebo).apply {
                    layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM)
                    maxLines = 1
                })
            }
        }
    }

    private fun tuileHizouk(d: DonneesAccueil): View = tuile(CREME, 124, getString(R.string.pile_hizouk)) { v ->
        ouvrirDepuis(v, Intent(this, ChizukActivity::class.java))
    }.apply {
        addView(VueVersion.colonne(context).apply {
            addView(VueVersion.texte(context, getString(R.string.pile_hizouk), 12f, CREME_ACCENT, heeboGras, majuscules = true, espacement = 0.16f))
            val p = d.pensee
            addView(if (p == null) VueVersion.texte(context, getString(R.string.version_chargement), 15f, CREME_ENCRE, heebo, haut = 6)
            else VueVersion.hebreu(context, p.hebreu, 19f, CREME_ENCRE, haut = 4).apply {
                maxLines = 2
                ellipsize = android.text.TextUtils.TruncateAt.END
            })
        })
    }

    private fun tuileAmbiance(): View {
        val ambiance = Ambiance.of(Store.ambiance(this))
        val morceau = if (Store.musicEnabled(this)) MusicLibrary.selected(this)?.title else null
        val nom = if (ambiance != Ambiance.SILENCE) getString(ambiance.titre) else morceau ?: getString(ambiance.titre)
        val joue = ambiance != Ambiance.SILENCE || morceau != null
        return tuile(NUIT, 124, getString(R.string.bento_ambiance) + ", " + nom) { v -> ouvrirDepuis(v, Intent(this, MusicActivity::class.java)) }.apply {
            addView(VueVersion.colonne(context).apply {
                addView(VueVersion.texte(context, getString(if (ambiance != Ambiance.SILENCE) R.string.bento_ambiance else R.string.bento_musique), 13f, NUIT_DOUX, heebo))
                addView(VueVersion.texte(context, nom, 17f, NUIT_ENCRE, heeboGras).apply { maxLines = 2; ellipsize = android.text.TextUtils.TruncateAt.END })
            })
            addView(Egaliseur(context, joue).apply {
                layoutParams = FrameLayout.LayoutParams(dp(46), dp(34), Gravity.BOTTOM or Gravity.START)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            })
        }
    }

    private fun tuileJournal(d: DonneesAccueil): View = tuile(BLANC, 124, getString(R.string.pile_journal)) { v ->
        ouvrirDepuis(v, Intent(this, JournalActivity::class.java))
    }.apply {
        addView(VueVersion.colonne(context).apply {
            val n = d.derniereNote
            addView(VueVersion.texte(context,
                if (n == null) getString(R.string.pile_journal)
                else getString(R.string.bento_journal_quand, DonneesAccueil.jour(context, n.date).lowercase(), DonneesAccueil.duree(context, n.minutes)),
                13f, DOUX, heebo).apply { maxLines = 1; ellipsize = android.text.TextUtils.TruncateAt.END })
            addView(VueVersion.texte(context, n?.texte ?: getString(R.string.version_ecrire_note), 15f, if (n?.texte != null) ENCRE else DOUX, heebo, haut = 4).apply {
                maxLines = 3
                ellipsize = android.text.TextUtils.TruncateAt.END
            })
        })
    }

    private fun petiteTuile(titre: String, fond: Int, encre: Int, action: () -> Unit): View = tuile(fond, 64, titre) { action() }.apply {
        addView(VueVersion.texte(context, titre, 16f, encre, heeboGras).apply {
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_VERTICAL)
        })
    }

    // --- Les aperçus vivants -------------------------------------------------------------

    /** L'anneau de la semaine : « 4/6 » au centre, l'arc se trace à l'ouverture. */
    private class Anneau(c: Context, private val faits: Int, private val dus: Int, police: android.graphics.Typeface?) : View(c) {
        private val d = c.resources.displayMetrics.density
        private val fond = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 7 * d; color = VERT_CLAIR }
        private val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 7 * d; color = CITRON; strokeCap = Paint.Cap.ROUND }
        private val texte = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = BLANC; textSize = 16 * d; textAlign = Paint.Align.CENTER; police?.let { typeface = it } }
        private var part = 0f
        private val cadre = RectF()

        init {
            val cible = if (dus > 0) (faits.toFloat() / dus).coerceIn(0f, 1f) else 0f
            if (ValueAnimator.areAnimatorsEnabled()) ValueAnimator.ofFloat(0f, cible).apply {
                duration = 1200
                startDelay = 300
                addUpdateListener { part = it.animatedValue as Float; invalidate() }
                start()
            } else part = cible
        }

        override fun onDraw(canvas: Canvas) {
            val m = 4 * d
            cadre.set(m, m, width - m, height - m)
            canvas.drawOval(cadre, fond)
            canvas.drawArc(cadre, -90f, 360f * part, false, arc)
            canvas.drawText("$faits/$dus", width / 2f, height / 2f - (texte.descent() + texte.ascent()) / 2, texte)
        }
    }

    /** Les sept jours de la semaine en barres : un jour fait monte haut, un jour vide reste bas. */
    private class Barres(c: Context, private val faits: List<Boolean>) : View(c) {
        private val d = c.resources.displayMetrics.density
        private val plein = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = VERT }
        private val vide = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = GRIS_BARRE }
        private var pousse = if (ValueAnimator.areAnimatorsEnabled()) 0f else 1f
        private val r = RectF()

        init {
            if (pousse == 0f) ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 700
                addUpdateListener { pousse = it.animatedValue as Float; invalidate() }
                start()
            }
        }

        override fun onDraw(canvas: Canvas) {
            if (faits.isEmpty()) return
            val ecart = 5 * d
            val l = (width - ecart * (faits.size - 1)) / faits.size
            faits.forEachIndexed { i, fait ->
                val h = height * (if (fait) 1f else 0.3f) * pousse
                val x = i * (l + ecart)
                r.set(x, height - h, x + l, height.toFloat())
                canvas.drawRoundRect(r, 3 * d, 3 * d, if (fait) plein else vide)
            }
        }
    }

    /** L'égaliseur de l'ambiance : cinq barres qui dansent tant qu'une musique ou une ambiance est choisie. */
    private class Egaliseur(c: Context, private val joue: Boolean) : View(c) {
        private val d = c.resources.displayMetrics.density
        private val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CITRON }
        private val periodes = longArrayOf(900, 1200, 800, 1100, 950)
        private val decalages = longArrayOf(0, 200, 100, 300, 150)
        private val r = RectF()
        private val anime = joue && ValueAnimator.areAnimatorsEnabled()

        override fun onDraw(canvas: Canvas) {
            val t = android.os.SystemClock.uptimeMillis()
            val l = 6 * d
            val ecart = 4 * d
            periodes.forEachIndexed { i, periode ->
                val phase = ((t + decalages[i]) % periode).toFloat() / periode
                val h = if (anime) height * (0.3f + 0.7f * (0.5f - 0.5f * kotlin.math.cos(phase * 2 * Math.PI.toFloat()))) else height * 0.3f
                val x = i * (l + ecart)
                r.set(x, height - h, x + l, height.toFloat())
                canvas.drawRoundRect(r, 3 * d, 3 * d, p)
            }
            if (anime && isShown) postInvalidateOnAnimation()
        }
    }

    private companion object {
        // Les couleurs de la maquette Bento.
        val FOND = 0xFFF2F2EF.toInt()
        val BLANC = 0xFFFFFFFF.toInt()
        val ENCRE = 0xFF121614.toInt()
        val DOUX = 0xFF555B57.toInt()
        val CITRON = 0xFFD9F56B.toInt()
        val VERT = 0xFF123B30.toInt()
        val VERT_CLAIR = 0xFF24574A.toInt()
        val GRIS_BARRE = 0xFFDADDD8.toInt()
        val BLEU_FOND = 0xFFE6ECF8.toInt()
        val BLEU_ENCRE = 0xFF16233F.toInt()
        val BLEU_DOUX = 0xFF3C4A69.toInt()
        val CREME = 0xFFFFF4DE.toInt()
        val CREME_ENCRE = 0xFF2B2118.toInt()
        val CREME_ACCENT = 0xFF8A4B14.toInt()
        val NUIT = 0xFF1B1C1F.toInt()
        val NUIT_ENCRE = 0xFFF2F2EF.toInt()
        val NUIT_DOUX = 0xFFB9BCB6.toInt()
    }
}
