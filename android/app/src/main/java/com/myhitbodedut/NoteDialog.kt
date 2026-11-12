package com.myhitbodedut

import android.app.Dialog
import android.content.DialogInterface
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.WindowManager
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatDialogFragment
import androidx.fragment.app.FragmentActivity

/**
 * Petite note libre laissée après une séance.
 *
 * Fragment de dialogue plutôt qu'AlertDialog nu (check-up du 11/11) : une
 * rotation ou un changement de palette recréait l'activité et emportait ce
 * qu'on était en train d'écrire. Le fragment est recréé avec son brouillon.
 *
 * Ce qu'on a écrit ne se perd plus d'un geste non plus (revue du 29/09) : un
 * toucher à côté ne ferme pas la fenêtre, et dès que le texte change, le
 * retour ne la ferme plus ; le bouton dit alors « Ne pas enregistrer » au
 * lieu de « Plus tard ».
 */
class NoteDialog : AppCompatDialogFragment() {

    /**
     * L'activité qui ouvre la note est prévenue par cette interface plutôt
     * que par des lambdas, qui ne survivraient pas à sa recréation.
     */
    interface Hote {
        fun noteEnregistree(date: String) {}
        fun noteFermee(date: String) {}
    }

    private lateinit var input: EditText
    private lateinit var gratitude: EditText
    private lateinit var travail: EditText
    private var avant = 0
    private var apres = 0

    private val dateNote: String get() = requireArguments().getString(ARG_DATE).orEmpty()
    private val hote: Hote? get() = activity as? Hote

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val ctx = requireActivity()
        val date = dateNote
        val density = ctx.resources.displayMetrics.density
        val pad = (16 * density).toInt()

        // Le hassid qui écrit : c'est une note qu'on laisse (demande du 29/09).
        val art = PersonnageImageView(ctx).apply {
            setImageResource(R.drawable.char_writing)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (120 * density).toInt()
            )
        }

        val initiale = Store.record(ctx, date)?.note.orEmpty()
        val etat = savedInstanceState
        input = EditText(ctx).apply {
            filters = arrayOf(android.text.InputFilter.LengthFilter(Store.NOTE_MAX))
            setText(etat?.getString(K_NOTE) ?: initiale)
            setHint(R.string.note_hint)
            setLines(4)
            gravity = Gravity.TOP or Gravity.START
        }

        // Le journal enrichi (14/10) : l'humeur avant et après, une gratitude.
        val plus = JournalPlus.lire(ctx, date)
        avant = etat?.getInt(K_AVANT, plus.avant) ?: plus.avant
        apres = etat?.getInt(K_APRES, plus.apres) ?: plus.apres
        fun humeurs(titre: Int, initiale: Int, choisir: (Int) -> Unit) = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, (8 * density).toInt(), 0, 0)
            addView(android.widget.TextView(ctx).apply { setText(titre); textSize = 13f })
            val rang = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
            val boutons = JournalPlus.HUMEURS.mapIndexed { i, e ->
                android.widget.TextView(ctx).apply {
                    text = e
                    textSize = 26f
                    gravity = Gravity.CENTER
                    // Hauteur minimale plutôt que fixe : en grande police, les
                    // visages étaient rognés (check-up du 11/11).
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    minHeight = (48 * density).toInt()
                    alpha = if (initiale == i + 1) 1f else 0.35f
                    contentDescription = "${i + 1}/5"
                }
            }
            boutons.forEachIndexed { i, b ->
                b.setOnClickListener {
                    val n = if (b.alpha == 1f) 0 else i + 1
                    boutons.forEachIndexed { j, x -> x.alpha = if (n == j + 1) 1f else 0.35f }
                    choisir(n)
                }
                rang.addView(b)
            }
            addView(rang)
        }
        gratitude = EditText(ctx).apply {
            filters = arrayOf(android.text.InputFilter.LengthFilter(JournalPlus.GRATITUDE_MAX))
            setText(etat?.getString(K_GRATITUDE) ?: plus.gratitude)
            setHint(R.string.journal_gratitude_hint)
            // Jusqu'à 200 caractères : sur une seule ligne, ni l'indice ni la
            // réponse ne se relisaient (check-up du 11/11).
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE or android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            minLines = 1
            maxLines = 3
        }
        // La seconde question de fin (19/10) : une chose à travailler.
        travail = EditText(ctx).apply {
            filters = arrayOf(android.text.InputFilter.LengthFilter(JournalPlus.GRATITUDE_MAX))
            setText(etat?.getString(K_TRAVAIL) ?: plus.travail)
            setHint(R.string.journal_travail_hint)
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE or android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            minLines = 1
            maxLines = 3
        }

        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, 0)
            addView(art)
            addView(input)
            addView(humeurs(R.string.journal_humeur_avant, avant) { avant = it })
            addView(humeurs(R.string.journal_humeur_apres, apres) { apres = it })
            addView(gratitude)
            addView(travail)
        }
        val defile = android.widget.ScrollView(ctx).apply { addView(layout) }

        val dialog = AlertDialog.Builder(ctx)
            .setTitle(R.string.note_title)
            .setView(defile)
            .setPositiveButton(R.string.action_save) { _, _ ->
                Store.setNote(ctx, date, input.text.toString().trim())
                JournalPlus.ecrire(ctx, date, JournalPlus.Plus(avant, apres, gratitude.text.toString().trim(), travail.text.toString().trim()))
                hote?.noteEnregistree(date)
                hote?.noteFermee(dateNote)
            }
            .setNegativeButton(R.string.action_later) { _, _ -> hote?.noteFermee(date) }
            .create()
        dialog.setCanceledOnTouchOutside(false)
        // Une note intime : pas de capture ni d'aperçu dans les Récents,
        // comme le journal.
        dialog.window?.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        fun suivre() {
            val change = input.text.toString().trim() != initiale.trim()
            isCancelable = !change
            dialog.getButton(DialogInterface.BUTTON_NEGATIVE)
                ?.setText(if (change) R.string.note_discard else R.string.action_later)
        }
        dialog.setOnShowListener { suivre() }
        input.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = suivre()
        })
        return dialog
    }

    override fun onCancel(dialog: DialogInterface) {
        super.onCancel(dialog)
        hote?.noteFermee(dateNote)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (!::input.isInitialized) return
        outState.putString(K_NOTE, input.text.toString())
        outState.putString(K_GRATITUDE, gratitude.text.toString())
        outState.putString(K_TRAVAIL, travail.text.toString())
        outState.putInt(K_AVANT, avant)
        outState.putInt(K_APRES, apres)
    }

    companion object {
        private const val TAG = "note"
        private const val ARG_DATE = "date"
        private const val K_NOTE = "note"
        private const val K_GRATITUDE = "gratitude"
        private const val K_TRAVAIL = "travail"
        private const val K_AVANT = "avant"
        private const val K_APRES = "apres"

        /** Ouvre la note de [date] ; une seule à la fois. */
        fun show(activity: FragmentActivity, date: String) {
            val fm = activity.supportFragmentManager
            if (fm.isStateSaved || fm.findFragmentByTag(TAG) != null) return
            NoteDialog().apply { arguments = Bundle().apply { putString(ARG_DATE, date) } }
                .show(fm, TAG)
        }
    }
}
