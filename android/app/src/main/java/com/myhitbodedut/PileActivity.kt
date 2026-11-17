package com.myhitbodedut

import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import androidx.viewpager2.widget.ViewPager2
import kotlin.math.abs

/**
 * Version Pile (maquette « C · Pile — l'app en cartes du jour ») : plus d'onglets, la journée
 * se lit comme une pile de quatre cartes qu'on fait glisser du doigt — hitbodedout, 'hizouk,
 * zmanim, journal. Le 'hizouk se retourne pour la traduction. Polices : Secular One pour les
 * titres, Rubik pour le reste.
 */
class PileActivity : AccueilVersion() {

    override val version = VersionApp.PILE

    private lateinit var pages: ViewPager2
    private lateinit var position: TextView
    private lateinit var dateVue: TextView
    private var traductionVisible = false
    private var donnees: DonneesAccueil? = null

    private val titre by lazy { VueVersion.police(this, R.font.secular_one) }

    /** Un petit écran (480x854 : 569 dp de haut) ou un texte agrandi qui le rend aussi serré. */
    private val petit by lazy { resources.configuration.screenHeightDp / resources.configuration.fontScale.coerceAtLeast(1f) < 680 }
    private val corps by lazy { VueVersion.police(this, R.font.rubik, 400) }
    private val corpsGras by lazy { VueVersion.police(this, R.font.rubik, 600) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return
        VueVersion.barres(this, FOND, clair = false)
        setContentView(construire())
        pages.setCurrentItem(savedInstanceState?.getInt(ETAT_PAGE) ?: 0, false)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (::pages.isInitialized) outState.putInt(ETAT_PAGE, pages.currentItem)
    }

    private fun construire(): View {
        val racine = VueVersion.colonne(this).apply {
            setBackgroundColor(FOND)
            setPadding(0, dp(12), 0, dp(16))
        }
        // L'en-tête : la date, « Votre journée », la position dans la pile ; Textes et Réglages à droite.
        val entete = VueVersion.ligne(this).apply { setPadding(dp(24), 0, dp(8), 0) }
        val gauche = VueVersion.colonne(this).apply { layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f) }
        dateVue = VueVersion.texte(this, "", 14f, ENCRE_DOUCE, corps)
        gauche.addView(dateVue)
        gauche.addView(VueVersion.texte(this, getString(R.string.pile_titre), if (petit) 24f else 30f, ENCRE, titre, haut = 2))
        entete.addView(gauche)
        entete.addView(VueVersion.icone(this, R.drawable.ic_nav_texts, ENCRE_DOUCE, getString(R.string.version_textes)) { ouvrirTextes() })
        entete.addView(VueVersion.icone(this, R.drawable.ic_nav_settings_off, ENCRE_DOUCE, getString(R.string.version_reglages)) { ouvrirReglages() })
        racine.addView(entete)
        position = VueVersion.texte(this, "", 13f, ENCRE_DOUCE, corpsGras, haut = 6, espacement = 0.08f).apply {
            setPadding(dp(24), 0, dp(24), 0)
        }
        racine.addView(position)

        pages = ViewPager2(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply { topMargin = dp(12) }
            offscreenPageLimit = 3
            adapter = Cartes()
            // Les cartes voisines dépassent : on voit qu'il y a une pile.
            (getChildAt(0) as RecyclerView).apply {
                setPadding(dp(24), 0, dp(40), 0)
                clipToPadding = false
                overScrollMode = View.OVER_SCROLL_NEVER
            }
            setPageTransformer { page, pos ->
                // La carte suivante attend derrière, un peu plus petite et plus sombre.
                val p = pos.coerceIn(-1f, 1f)
                val echelle = 1f - 0.06f * abs(p)
                page.scaleY = echelle
                page.alpha = 1f - 0.35f * abs(p)
            }
            registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                override fun onPageSelected(p: Int) {
                    position.text = getString(R.string.pile_position, p + 1, NB)
                }
            })
        }
        racine.addView(pages)
        return racine
    }

    override fun dessiner() {
        val d = DonneesAccueil.lire(this)
        donnees = d
        dateVue.text = listOfNotNull(d.dateCivile, d.dateHebraique).joinToString(" · ")
        position.text = getString(R.string.pile_position, pages.currentItem + 1, NB)
        pages.adapter?.notifyDataSetChanged()
    }

    // --- Les quatre cartes ---------------------------------------------------------

    private inner class Cartes : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = NB
        override fun getItemViewType(position: Int) = position
        override fun onCreateViewHolder(parent: ViewGroup, type: Int): RecyclerView.ViewHolder {
            val cadre = FrameLayout(parent.context).apply {
                layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                setPadding(dp(4), 0, dp(4), 0)
            }
            return object : RecyclerView.ViewHolder(cadre) {}
        }

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
            val cadre = holder.itemView as FrameLayout
            cadre.removeAllViews()
            val d = donnees ?: return
            cadre.addView(when (position) {
                0 -> carteHitbodedout(d)
                1 -> carteHizouk(d)
                2 -> carteZmanim(d)
                else -> carteJournal(d)
            })
        }
    }

    /** Le corps d'une carte : un dégradé, arrondi, qui défile si le texte agrandi déborde. */
    private fun carte(haut: Int, bas: Int, contenu: LinearLayout.() -> Unit): View = ScrollView(this).apply {
        layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        background = VueVersion.fond(this@PileActivity, 28, haut, bas)
        isFillViewport = true
        clipToOutline = true
        addView(VueVersion.colonne(this@PileActivity).apply {
            setPadding(dp(24), dp(24), dp(24), dp(24))
            contenu()
        })
    }

    private fun LinearLayout.etiquette(texte: String, couleur: Int) =
        addView(VueVersion.texte(context, texte, 13f, couleur, corpsGras, majuscules = true, espacement = 0.12f))

    /** Une place qui pousse le bas de la carte (boutons) contre son bord. */
    private fun LinearLayout.ressort() = addView(View(context).apply { layoutParams = LinearLayout.LayoutParams(1, 0, 1f) })

    private fun carteHitbodedout(d: DonneesAccueil) = carte(HITBO_HAUT, HITBO_BAS) {
        etiquette(getString(R.string.pile_hitbodedout), HITBO_ACCENT)
        addView(VueVersion.texte(context,
            if (d.faite) getString(R.string.pile_hitbo_faite, DonneesAccueil.duree(context, d.minutesAujourdhui))
            else if (d.prenom.isNotBlank()) getString(R.string.pile_hitbo_titre_prenom, d.prenom) else getString(R.string.pile_hitbo_titre),
            // Plus petit sur un petit écran : en 28 sp le titre prenait trois lignes et poussait
            // « Commencer » sous le bord de la carte (480x854, 17/11).
            if (petit) 22f else 28f, HITBO_ENCRE, titre, haut = 14))
        addView(VueVersion.texte(context, resources.getQuantityString(R.plurals.version_serie, d.serie, d.serie), 17f, HITBO_ENCRE, corpsGras, haut = 22))
        addView(VueVersion.texte(context, getString(R.string.version_semaine, d.semaineFaits, d.semaineDus), 15f, HITBO_DOUCE, corps, haut = 4))
        // Les jours de la semaine en pastilles : faits pleins, à venir creux.
        addView(VueVersion.ligne(context).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(14) }
            Store.currentWeek(context).forEach { j ->
                addView(View(context).apply {
                    layoutParams = LinearLayout.LayoutParams(dp(12), dp(12)).apply { marginEnd = dp(8) }
                    background = if (j.done) VueVersion.fond(context, 6, HITBO_ACCENT)
                    else VueVersion.fond(context, 6, android.graphics.Color.TRANSPARENT, bord = HITBO_DOUCE)
                })
            }
        })
        // Le hassid occupe le milieu de la carte : il accueille, ou se réjouit quand c'est fait.
        addView(android.widget.ImageView(context).apply {
            setImageResource(Personnage.pour(context, Character.greeting(d.faite)))
            scaleType = android.widget.ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply { topMargin = dp(12) }
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        })
        val enCours = Store.isSessionRunning(context)
        addView(VueVersion.bouton(context,
            when {
                enCours -> getString(R.string.version_reprendre)
                d.faite -> getString(R.string.version_encore)
                else -> getString(R.string.version_commencer, DonneesAccueil.duree(context, d.objectifMinutes))
            },
            HITBO_ACCENT, HITBO_BOUTON_ENCRE, corpsGras) { commencerSeance() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(24)
        })
        addView(VueVersion.bouton(context, getString(R.string.version_preparer), HITBO_DOUCE, HITBO_ENCRE, corps, trait = true) { preparerSeance() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(10)
        })
    }

    private fun carteHizouk(d: DonneesAccueil) = carte(HIZ_HAUT, HIZ_BAS) {
        etiquette(getString(R.string.pile_hizouk), HIZ_ACCENT)
        val p = d.pensee
        if (p == null) {
            addView(VueVersion.texte(context, getString(R.string.version_chargement), 16f, HIZ_ENCRE, corps, haut = 16))
            return@carte
        }
        val montreTraduction = traductionVisible && p.traduction != null
        if (montreTraduction) {
            etiquette(getString(R.string.pile_traduction), HIZ_DOUCE)
            addView(VueVersion.texte(context, p.traduction, 18f, HIZ_ENCRE, corps, haut = 10).apply { setLineSpacing(dp(4).toFloat(), 1f) })
        } else {
            addView(VueVersion.hebreu(context, p.hebreu, 22f, HIZ_ENCRE, haut = 14))
        }
        addView(VueVersion.texte(context, p.reference, 14f, HIZ_DOUCE, corps, haut = 14).apply { setTypeface(typeface, Typeface.ITALIC) })
        ressort()
        if (p.traduction != null) {
            addView(VueVersion.bouton(context, getString(if (montreTraduction) R.string.pile_revoir_hebreu else R.string.pile_voir_traduction),
                HIZ_ACCENT, HIZ_ENCRE, corpsGras, trait = true) {
                traductionVisible = !traductionVisible
                retourner(1)
            }.apply { (layoutParams as LinearLayout.LayoutParams).topMargin = dp(20) })
        }
        addView(VueVersion.bouton(context, getString(R.string.version_plus_de_textes), HIZ_ACCENT, HIZ_BOUTON_ENCRE, corpsGras) { ouvrirChizuk() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(10)
        })
    }

    /** La carte se retourne sur elle-même (le 'hizouk : hébreu au recto, traduction au verso). */
    private fun retourner(position: Int) {
        val rv = pages.getChildAt(0) as RecyclerView
        val vue = rv.findViewHolderForAdapterPosition(position)?.itemView
        if (vue == null || !android.animation.ValueAnimator.areAnimatorsEnabled()) {
            pages.adapter?.notifyItemChanged(position)
            return
        }
        vue.cameraDistance = 8000 * resources.displayMetrics.density
        vue.animate().rotationY(90f).setDuration(160).withEndAction {
            pages.adapter?.notifyItemChanged(position)
            vue.rotationY = -90f
            vue.animate().rotationY(0f).setDuration(160).start()
        }.start()
    }

    private fun carteZmanim(d: DonneesAccueil) = carte(ZM_HAUT, ZM_BAS) {
        etiquette(d.lieu?.let { getString(R.string.pile_zmanim_lieu, it) } ?: getString(R.string.pile_zmanim), ZM_ACCENT)
        if (d.zmanim.isEmpty()) {
            addView(VueVersion.texte(context, getString(R.string.version_sans_lieu), 16f, ZM_ENCRE, corps, haut = 16))
            ressort()
            addView(VueVersion.bouton(context, getString(R.string.version_choisir_lieu), ZM_ACCENT, ZM_BOUTON_ENCRE, corpsGras) { ouvrirZmanim() })
            return@carte
        }
        d.prochain?.let { z ->
            addView(VueVersion.texte(context, getString(R.string.version_prochain, z.nom), 22f, ZM_ENCRE, titre, haut = 14))
            addView(VueVersion.texte(context, d.dans(context, z), 16f, ZM_DOUCE, corps, haut = 2))
        }
        addView(View(context).apply { layoutParams = LinearLayout.LayoutParams(1, dp(10)) })
        d.zmanim.forEach { z ->
            val passe = d.prochain?.let { z.instant.isBefore(it.instant) } ?: true
            addView(VueVersion.ligne(context).apply {
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(12) }
                addView(VueVersion.texte(context, z.nom, 16f, if (passe) ZM_DOUCE else ZM_ENCRE, corps).apply {
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                })
                addView(VueVersion.texte(context, z.heure, 17f, if (passe) ZM_DOUCE else ZM_ENCRE, corpsGras))
            })
        }
        ressort()
        addView(VueVersion.bouton(context, getString(R.string.version_tous_zmanim), ZM_ACCENT, ZM_BOUTON_ENCRE, corpsGras) { ouvrirZmanim() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(20)
        })
    }

    private fun carteJournal(d: DonneesAccueil) = carte(JR_HAUT, JR_BAS) {
        etiquette(getString(R.string.pile_journal), JR_ACCENT)
        val n = d.derniereNote
        if (n == null) {
            addView(VueVersion.texte(context, getString(R.string.version_journal_vide), 17f, JR_ENCRE, corps, haut = 14))
        } else {
            addView(VueVersion.texte(context, listOf(DonneesAccueil.jour(context, n.date), DonneesAccueil.duree(context, n.minutes)).joinToString(", "),
                20f, JR_ENCRE, titre, haut = 14))
            addView(VueVersion.texte(context, n.texte ?: getString(R.string.version_note_sans_texte), 16f, if (n.texte != null) JR_ENCRE else JR_DOUCE, corps, haut = 10).apply {
                setLineSpacing(dp(4).toFloat(), 1f)
                maxLines = 9
                ellipsize = android.text.TextUtils.TruncateAt.END
            })
        }
        ressort()
        addView(VueVersion.bouton(context, getString(R.string.version_ecrire_note), JR_ACCENT, JR_BOUTON_ENCRE, corpsGras) { ecrireNote() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(20)
        })
        addView(VueVersion.bouton(context, getString(R.string.version_tout_journal), JR_ACCENT, JR_ENCRE, corps, trait = true) { ouvrirJournal() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(10)
        })
        addView(VueVersion.bouton(context, getString(R.string.version_parcours), JR_ACCENT, JR_ENCRE, corps, trait = true) { ouvrirParcours() }.apply {
            (layoutParams as LinearLayout.LayoutParams).topMargin = dp(10)
        })
    }

    private companion object {
        const val NB = 4
        const val ETAT_PAGE = "pile_page"

        // Les couleurs de la maquette Pile.
        val FOND = 0xFF15131F.toInt()
        val ENCRE = 0xFFF1EEF8.toInt()
        val ENCRE_DOUCE = 0xFFA9A4BE.toInt()

        val HITBO_HAUT = 0xFF136067.toInt()
        val HITBO_BAS = 0xFF0B3236.toInt()
        val HITBO_ACCENT = 0xFF7FE7D9.toInt()
        val HITBO_ENCRE = 0xFFEAFBF8.toInt()
        val HITBO_DOUCE = 0xFFA9E3DC.toInt()
        val HITBO_BOUTON_ENCRE = 0xFF07302F.toInt()

        val HIZ_HAUT = 0xFF34307A.toInt()
        val HIZ_BAS = 0xFF1B1940.toInt()
        val HIZ_ACCENT = 0xFFC9C6F0.toInt()
        val HIZ_ENCRE = 0xFFF3F2FF.toInt()
        val HIZ_DOUCE = 0xFFB4B0E2.toInt()
        val HIZ_BOUTON_ENCRE = 0xFF1B1940.toInt()

        val ZM_HAUT = 0xFF9E4A22.toInt()
        val ZM_BAS = 0xFF3B1F14.toInt()
        val ZM_ACCENT = 0xFFF5C9A8.toInt()
        val ZM_ENCRE = 0xFFFFF1E6.toInt()
        val ZM_DOUCE = 0xFFE0B49A.toInt()
        val ZM_BOUTON_ENCRE = 0xFF3B1F14.toInt()

        val JR_HAUT = 0xFF574634.toInt()
        val JR_BAS = 0xFF2B2118.toInt()
        val JR_ACCENT = 0xFFE9D9C3.toInt()
        val JR_ENCRE = 0xFFF8F0E4.toInt()
        val JR_DOUCE = 0xFFCFC0AB.toInt()
        val JR_BOUTON_ENCRE = 0xFF2B2118.toInt()
    }
}
