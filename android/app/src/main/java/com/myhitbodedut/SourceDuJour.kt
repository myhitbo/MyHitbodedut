package com.myhitbodedut

import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.button.MaterialButton
import java.time.LocalDate

/**
 * La source du jour (proposition 10 de la feuille de route, 19/10) : un
 * paragraphe des sources de la bibliothèque, le même toute la journée et pour
 * tous, distinct du 'hizouk, avec deux sorties : commencer, ou lire la suite.
 *
 * Seules les sources libres y entrent (les entrées « source » de
 * bibliotheque.json, dans la forme que leur licence permet) ; jamais les
 * articles sans autorisation. Le web choisit le même paragraphe le même jour
 * (regles.js, SourceDuJour).
 *
 * La carte suit les langues de lecture (LanguesTexte), comme la carte de 'hizouk et la
 * fiche de la source : l'hébreu et sa traduction par défaut en français et en anglais
 * (13/11, audit du 12/11, COUV-08, BIBLIO-03, FACCUEIL-08, FWEBCODE-08 : elle ne
 * montrait que l'hébreu, alors que chaque paragraphe est traduit).
 */
object SourceDuJour {

    /** [indice] : le rang du paragraphe dans sa source, celui de ses traductions. */
    data class Pensee(val source: SourceEntry, val texte: String, val indice: Int)

    /** Un paragraphe plus court n'a pas assez à dire seul. */
    const val MIN = 80

    /** Le pas entre deux jours : premier, il fait passer d'une source à l'autre plutôt que de paragraphe en paragraphe. */
    private const val PAS = 37L

    fun candidats(library: Library): List<Pensee> =
        library.entrees.filterIsInstance<SourceEntry>().flatMap { s ->
            // Le rang d'abord, le filtre ensuite : un paragraphe court écarté ne décale pas les traductions.
            LibraryRules.paragraphs(library, s).withIndex().filter { it.value.length >= MIN }.map { Pensee(s, it.value, it.index) }
        }

    fun choix(library: Library, jour: LocalDate): Pensee? {
        val c = candidats(library)
        if (c.isEmpty()) return null
        return c[Math.floorMod(jour.toEpochDay() * PAS, c.size.toLong()).toInt()]
    }

    /** Un extrait qui tient sur l'accueil : coupé à un mot, jamais au milieu. */
    fun extrait(texte: String, max: Int = 320): String =
        if (texte.length <= max) texte else texte.take(max).substringBeforeLast(' ').trimEnd(',', ' ', ':', ';') + "…"

    /**
     * Ce que la carte donne à lire, dans l'ordre des langues choisies : (langue, extrait). La
     * règle de LanguesTexte : une traduction absente est sautée, et l'hébreu reste s'il n'y a rien.
     */
    fun textes(p: Pensee, mode: LanguesTexte.Mode): List<Pair<String, String>> =
        LanguesTexte.textes(mode, p.texte, p.source.paragraphesFr.getOrNull(p.indice), p.source.paragraphesEn.getOrNull(p.indice))
            .map { (langue, texte) -> langue to extrait(texte) }

    fun carte(c: Context): View? {
        val p = choix(Data.library(c), LocalDate.now()) ?: return null
        val textes = textes(p, LanguesTexte.mode(c))
        val avecHebreu = textes.any { it.first == "he" }
        fun dp(v: Int) = (v * c.resources.displayMetrics.density).toInt()
        return LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.bg_card)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(12) }
            setPadding(dp(16), dp(12), dp(16), dp(8))
            addView(TextView(c).apply {
                setText(R.string.source_du_jour)
                textSize = 12f
                isAllCaps = true
                letterSpacing = 0.06f
                setTextColor(Apparence.couleur(c, R.color.brand))
            })
            textes.forEachIndexed { rang, (langue, texte) ->
                addView(TextView(c).apply {
                    text = texte
                    textAlignment = View.TEXT_ALIGNMENT_VIEW_START
                    setPadding(0, dp(if (rang == 0) 8 else 2), 0, dp(4))
                    if (langue == "he") {
                        textSize = 18f
                        setLineSpacing(dp(4).toFloat(), 1f)
                        textDirection = View.TEXT_DIRECTION_RTL
                        layoutDirection = View.LAYOUT_DIRECTION_RTL
                        setTextColor(Apparence.couleur(c, R.color.ink))
                        PoliceHebraique.appliquer(this)
                    } else {
                        // La traduction : de gauche à droite en toute langue d'interface, plus discrète
                        // sous l'hébreu, à l'encre quand elle est seule (comme la carte de 'hizouk).
                        textSize = if (avecHebreu) 15f else 17f
                        setLineSpacing(dp(3).toFloat(), 1f)
                        textDirection = View.TEXT_DIRECTION_LTR
                        layoutDirection = View.LAYOUT_DIRECTION_LTR
                        setTextColor(Apparence.couleur(c, if (avecHebreu) R.color.muted else R.color.ink))
                    }
                })
            }
            addView(TextView(c).apply {
                text = Reference.localise(c, p.source.ref)
                textSize = 13f
                setTypeface(typeface, Typeface.ITALIC)
                setTextColor(Apparence.couleur(c, R.color.muted))
            })
            addView(LinearLayout(c).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(8), 0, 0)
                // Un seul « Commencer » sur l'accueil, celui du haut (29/10) : la source invite à lire.
                addView(MaterialButton(c, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                    setText(R.string.source_du_jour_lire)
                    setOnClickListener {
                        c.startActivity(Intent(c, LibraryEntryActivity::class.java).putExtra(LibraryEntryActivity.EXTRA_ID, p.source.id))
                    }
                })
            })
        }
    }
}
