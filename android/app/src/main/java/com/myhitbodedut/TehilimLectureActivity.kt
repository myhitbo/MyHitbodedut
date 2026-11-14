package com.myhitbodedut

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * La lecture : un psaume, ou une portion d'un seul trait.
 *
 * Chaque verset porte son numéro en lettres, petit et discret, pour qu'on
 * retrouve sa place sans que la lecture en soit hachée. Un psaume seul a
 * deux boutons, précédent et suivant ; une portion n'en a aucun.
 */
class TehilimLectureActivity : AppCompatActivity() {

    private lateinit var portion: Portion
    private var reglages: ReglagesLecture? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_tehilim_lecture)
        // L'écran recréé (rotation, thème) reprend le psaume où l'on en était, non celui de l'intent
        // (audit du 12/11, FLECTURE-04) : ce qu'on lisait, et le verset en haut de l'écran.
        val etat = savedInstanceState?.takeIf { it.containsKey(ETAT_PRESENT) }
        val source = { cle: String, defaut: Int -> etat?.getInt("etat_$cle", defaut) ?: intent.getIntExtra(cle, defaut) }
        portion = Portion(
            debut = source(DEBUT, 1).coerceIn(1, Tehilim.PSAUMES),
            fin = source(FIN, 1).coerceIn(1, Tehilim.PSAUMES),
            debutVerset = source(DEBUT_VERSET, 1),
            finVerset = source(FIN_VERSET, 0).takeIf { it > 0 },
        )
        findViewById<Button>(R.id.lecture_previous).setOnClickListener { afficher(Portion(portion.debut - 1, portion.debut - 1)) }
        findViewById<Button>(R.id.lecture_next).setOnClickListener { afficher(Portion(portion.debut + 1, portion.debut + 1)) }
        // Le bouton de lecture : taille des lettres et lecture de nuit (pas de nusah ici).
        reglages = ReglagesLecture.installer(this, findViewById<ScrollView>(R.id.lecture_scroll), auDessusDe = findViewById(R.id.lecture_nav), gardeSaPlace = true) {
            afficher(portion, garderPlace = true)
        }
        afficher(portion)
        if (etat != null) {
            if (etat.getInt(ETAT_PSAUME, 0) > 0) allerAuVerset(etat.getInt(ETAT_PSAUME), etat.getInt(ETAT_VERSET))
        } else {
            // Ouvert depuis un marque-page (28/10) : le verset marqué en haut de l'écran.
            intent.getIntExtra(MARQUE_VERSET, 0).takeIf { it > 0 }?.let { v -> allerAuVerset(portion.debut, v) }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(ETAT_PRESENT, portion.debut)
        outState.putInt("etat_$DEBUT", portion.debut)
        outState.putInt("etat_$FIN", portion.fin)
        outState.putInt("etat_$DEBUT_VERSET", portion.debutVerset)
        outState.putInt("etat_$FIN_VERSET", portion.finVerset ?: 0)
        versetDuHaut()?.let { (n, v) ->
            outState.putInt(ETAT_PSAUME, n)
            outState.putInt(ETAT_VERSET, v)
        }
    }

    /** La position d'une vue dans le texte qui défile. */
    private fun hautDans(vue: View, defile: View): Int {
        var y = vue.top
        var parent = vue.parent as? View
        while (parent != null && parent !== defile) { y += parent.top; parent = parent.parent as? View }
        return y
    }

    /** Le verset (psaume, verset) en haut de l'écran : celui qu'on retrouve après un redessin ou une rotation. */
    private fun versetDuHaut(): Pair<Int, Int>? {
        val defile = findViewById<ScrollView>(R.id.lecture_scroll)
        val y = defile.scrollY
        if (y <= 0) return null
        val trouve = blocs.entries.filter { hautDans(it.value, defile) + it.value.height > y }
            .minByOrNull { hautDans(it.value, defile) }?.key
        if (trouve != null) return trouve
        for ((n, place) in places.toSortedMap()) {
            val (vue, versets) = place
            val layout = vue.layout ?: continue
            val dedans = y - hautDans(vue, defile)
            if (dedans >= vue.height) continue
            val o = layout.getLineStart(layout.getLineForVertical(dedans.coerceAtLeast(0)))
            val v = versets.firstOrNull { o <= it.second }?.third ?: versets.lastOrNull()?.third ?: continue
            return n to v
        }
        return null
    }

    /** L'écran reste allumé tant qu'on lit (FLECTURE-01). */
    private val veille by lazy { VeilleLecture(this) }

    override fun onResume() {
        super.onResume()
        veille.toucher()
    }

    override fun onUserInteraction() {
        super.onUserInteraction()
        veille.toucher()
    }

    override fun onPause() {
        super.onPause()
        veille.arreter()
    }

    /** Les versets affichés, psaume par psaume : la vue, et pour chaque verset sa place dans le texte. */
    private val places = mutableMapOf<Int, Pair<TextView, List<Triple<Int, Int, Int>>>>()

    /** En lecture traduite (04/11), un bloc par verset : (psaume, verset) → sa vue. */
    private val blocs = mutableMapOf<Pair<Int, Int>, View>()

    private fun allerAuVerset(n: Int, v: Int) {
        val defile = findViewById<ScrollView>(R.id.lecture_scroll)
        blocs[n to v]?.let { bloc ->
            defile.post {
                var y = bloc.top
                var parent = bloc.parent as? View
                while (parent != null && parent !== defile) { y += parent.top; parent = parent.parent as? View }
                defile.scrollTo(0, (y - dp(8)).coerceAtLeast(0))
            }
            return
        }
        defile.post {
            val (vue, versets) = places[n] ?: return@post
            val debut = versets.firstOrNull { it.third == v }?.first ?: return@post
            val ligne = vue.layout?.getLineForOffset(debut) ?: return@post
            var y = vue.top + vue.layout.getLineTop(ligne)
            var parent = vue.parent as? View
            while (parent != null && parent !== defile) { y += parent.top; parent = parent.parent as? View }
            defile.scrollTo(0, (y - dp(8)).coerceAtLeast(0))
        }
    }

    private fun afficher(p: Portion, garderPlace: Boolean = false) {
        // Redessiné sur place (taille, langues, marque-page) : on revient au verset qui était en haut.
        val repere = if (garderPlace) versetDuHaut() else null
        portion = p
        rendu = ReglagesLecture.rendu(this)
        val livre = Data.tehilim(this)
        findViewById<TextView>(R.id.lecture_title).text = TehilimTexte.portion(this, p)
        val versets = p.psaumes.sumOf { n -> p.versets(n, livre.versets(n).size).count() }
        findViewById<TextView>(R.id.lecture_subtitle).text =
            resources.getQuantityString(R.plurals.tehilim_verses, versets, versets)

        val contenu = findViewById<LinearLayout>(R.id.lecture_content)
        contenu.removeAllViews()
        places.clear()
        blocs.clear()
        val mode = LanguesTexte.mode(this)
        val marques = MarquesPages.duTexte(Store.marques(this), CLE, "").map { it.section to it.bloc }.toSet()
        p.psaumes.forEachIndexed { i, n ->
            val tous = livre.versets(n)
            contenu.addView(titre(getString(R.string.tikkun_psalm_he, Reference.lettres(n)), i == 0))
            // L'hébreu seul garde son bloc d'un seul tenant ; avec une traduction, verset par verset (04/11).
            contenu.addView(if (mode == LanguesTexte.Mode.HE) texte(n, tous, p.versets(n, tous.size), marques)
                else texteTraduit(n, tous, p.versets(n, tous.size), marques, mode, livre))
        }

        // Un psaume seul se lit de proche en proche ; une portion d'un trait.
        val seul = p.debut == p.fin && !p.partielle
        findViewById<View>(R.id.lecture_nav).visibility = if (seul) View.VISIBLE else View.GONE
        findViewById<View>(R.id.lecture_previous).visibility = if (p.debut > 1) View.VISIBLE else View.INVISIBLE
        findViewById<View>(R.id.lecture_next).visibility = if (p.debut < Tehilim.PSAUMES) View.VISIBLE else View.INVISIBLE
        findViewById<ScrollView>(R.id.lecture_scroll).apply {
            setBackgroundColor(rendu.fond)
            if (!garderPlace) scrollTo(0, 0)
        }
        repere?.let { (n, v) -> allerAuVerset(n, v) }
    }

    private var rendu = ReglagesLecture.Rendu(1f, false, 0, 0, 0, 0)

    private fun titre(texte: String, premier: Boolean): View = TextView(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = if (premier) 0 else dp(24)
            bottomMargin = dp(12)
            marginStart = dp(16)
            marginEnd = dp(16)
        }
        text = texte
        layoutDirection = View.LAYOUT_DIRECTION_RTL
        textAlignment = View.TEXT_ALIGNMENT_VIEW_START
        textSize = 20f * rendu.echelle
        setTypeface(typeface, android.graphics.Typeface.BOLD)
        setTextColor(rendu.titre)
        PoliceHebraique.appliquer(this)
    }

    /**
     * Les versets d'un psaume en un seul bloc, chacun précédé de son numéro en lettres.
     * Marque-pages (28/10), comme au siddour : un appui long sur un verset le marque ou le démarque ;
     * un verset marqué porte un trait de la couleur des titres et son numéro dans cette couleur.
     */
    private fun texte(n: Int, versets: List<String>, quels: IntRange, marques: Set<Pair<Int, Int>>): View = TextView(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = dp(4)
            marginStart = dp(16)
            marginEnd = dp(16)
        }
        val discret = rendu.discret
        val bloc = SpannableStringBuilder()
        val rangs = mutableListOf<Triple<Int, Int, Int>>()
        quels.forEach { v ->
            val verset = versets.getOrNull(v - 1) ?: return@forEach
            // Entre deux versets, une demi-ligne vide : chaque verset se détache (19/10).
            if (bloc.isNotEmpty()) {
                bloc.append("\n")
                val vide = bloc.length
                bloc.append("\n")
                bloc.setSpan(RelativeSizeSpan(0.4f), vide, bloc.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            val debut = bloc.length
            bloc.append(Reference.lettres(v)).append(" ")
            bloc.setSpan(ForegroundColorSpan(discret), debut, bloc.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            bloc.setSpan(RelativeSizeSpan(0.7f), debut, bloc.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            bloc.append(verset)
            rangs.add(Triple(debut, bloc.length, v))
            if (n to v in marques) {
                bloc.setSpan(ForegroundColorSpan(rendu.titre), debut, debut + Reference.lettres(v).length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                bloc.setSpan(android.text.style.QuoteSpan(rendu.titre), debut, bloc.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }
        text = bloc
        places[n] = this to rangs
        var x = 0f
        var y = 0f
        setOnTouchListener { _, e -> x = e.x; y = e.y; reglages?.toucher(e); false }
        setOnLongClickListener {
            val o = getOffsetForPosition(x, y)
            val (_, _, v) = rangs.firstOrNull { o in it.first..it.second } ?: return@setOnLongClickListener false
            val pose = Store.basculerMarque(this@TehilimLectureActivity, MarquesPages.Marque(CLE, "", n, v,
                "${Reference.lettres(n)}, ${Reference.lettres(v)} · ${MarquesPages.apercu(versets[v - 1], 5)}"))
            android.widget.Toast.makeText(this@TehilimLectureActivity, if (pose) R.string.marque_posee else R.string.marque_retiree, android.widget.Toast.LENGTH_SHORT).show()
            afficher(portion, garderPlace = true)
            true
        }
        layoutDirection = View.LAYOUT_DIRECTION_RTL
        textAlignment = View.TEXT_ALIGNMENT_VIEW_START
        textSize = 19f * rendu.echelle
        setLineSpacing(dp(8).toFloat() * rendu.echelle, 1f)
        setTextColor(rendu.texte)
        setTextIsSelectable(false)
        PoliceHebraique.appliquer(this)
    }

    /**
     * Les versets avec leur traduction (04/11) : pour chaque verset, l'hébreu et/ou la
     * traduction choisie, l'une sous l'autre. Un appui long marque le verset, comme en hébreu seul.
     */
    private fun texteTraduit(n: Int, versets: List<String>, quels: IntRange, marques: Set<Pair<Int, Int>>,
                             mode: LanguesTexte.Mode, livre: Tehilim): View = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            marginStart = dp(16)
            marginEnd = dp(16)
        }
        quels.forEach { v ->
            val verset = versets.getOrNull(v - 1) ?: return@forEach
            val textes = LanguesTexte.textes(mode, verset, livre.traduction("fr", n, v), livre.traduction("en", n, v))
            val avecHebreu = textes.any { it.first == "he" }
            val marque = n to v in marques
            val bloc = LinearLayout(this@TehilimLectureActivity).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(12) }
                setPadding(dp(8), dp(4), dp(8), dp(6))
                if (marque) background = android.graphics.drawable.GradientDrawable().apply {
                    cornerRadius = dp(10).toFloat()
                    setColor(androidx.core.graphics.ColorUtils.setAlphaComponent(rendu.titre, 0x22))
                }
            }
            textes.forEach { (langue, t) ->
                if (langue == "he") bloc.addView(TextView(this@TehilimLectureActivity).apply {
                    val s = SpannableStringBuilder(Reference.lettres(v)).append(" ")
                    s.setSpan(ForegroundColorSpan(if (marque) rendu.titre else rendu.discret), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    s.setSpan(RelativeSizeSpan(0.7f), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    text = s.append(t)
                    layoutDirection = View.LAYOUT_DIRECTION_RTL
                    textAlignment = View.TEXT_ALIGNMENT_VIEW_START
                    textSize = 19f * rendu.echelle
                    setLineSpacing(dp(8).toFloat() * rendu.echelle, 1f)
                    setTextColor(rendu.texte)
                    PoliceHebraique.appliquer(this)
                }) else {
                    // Sans l'hébreu, le numéro du verset en chiffres devant la traduction.
                    val s = SpannableStringBuilder()
                    if (!avecHebreu && s.isEmpty() && bloc.childCount == 0) {
                        s.append("$v ")
                        s.setSpan(ForegroundColorSpan(if (marque) rendu.titre else rendu.discret), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        s.setSpan(RelativeSizeSpan(0.75f), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    }
                    s.append(t)
                    bloc.addView(LanguesTexte.vueTraduction(this@TehilimLectureActivity, s, rendu, seule = !avecHebreu).apply {
                        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
                            .apply { topMargin = if (bloc.childCount > 0) dp(4) else 0 }
                    })
                }
            }
            bloc.setOnTouchListener { _, e -> reglages?.toucher(e); false }
            bloc.setOnLongClickListener {
                val pose = Store.basculerMarque(this@TehilimLectureActivity, MarquesPages.Marque(CLE, "", n, v,
                    "${Reference.lettres(n)}, ${Reference.lettres(v)} · ${MarquesPages.apercu(verset, 5)}"))
                android.widget.Toast.makeText(this@TehilimLectureActivity, if (pose) R.string.marque_posee else R.string.marque_retiree, android.widget.Toast.LENGTH_SHORT).show()
                afficher(portion, garderPlace = true)
                true
            }
            blocs[n to v] = bloc
            addView(bloc)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val DEBUT = "debut"
        private const val FIN = "fin"
        private const val DEBUT_VERSET = "debut_verset"
        private const val FIN_VERSET = "fin_verset"
        private const val MARQUE_VERSET = "marque_verset"
        private const val ETAT_PRESENT = "etat_present"
        private const val ETAT_PSAUME = "etat_psaume"
        private const val ETAT_VERSET = "etat_verset"

        /** La clé des marque-pages des Tehilim : le psaume en section, le verset en bloc. */
        const val CLE = "t:tehilim"

        /** Ouvre le psaume d'un marque-page, à son verset. */
        fun ouvrirMarque(context: Context, m: MarquesPages.Marque) {
            context.startActivity(
                Intent(context, TehilimLectureActivity::class.java)
                    .putExtra(DEBUT, m.section).putExtra(FIN, m.section).putExtra(MARQUE_VERSET, m.bloc)
            )
        }

        fun ouvrir(context: Context, p: Portion) {
            context.startActivity(
                Intent(context, TehilimLectureActivity::class.java)
                    .putExtra(DEBUT, p.debut)
                    .putExtra(FIN, p.fin)
                    .putExtra(DEBUT_VERSET, p.debutVerset)
                    .putExtra(FIN_VERSET, p.finVerset ?: 0)
            )
        }
    }
}
