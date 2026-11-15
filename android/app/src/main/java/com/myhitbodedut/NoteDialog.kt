package com.myhitbodedut

import android.app.Dialog
import android.content.DialogInterface
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import androidx.fragment.app.FragmentActivity

/**
 * Petite note libre laissée après une séance.
 *
 * Ce qu'on a écrit ne se perd plus d'un geste (revue du 29/09) : un
 * toucher à côté ne ferme plus la fenêtre, et dès que quelque chose change,
 * le retour ne la ferme plus non plus ; le bouton dit alors clairement
 * « Ne pas enregistrer » au lieu de « Plus tard ».
 *
 * Ni d'une rotation (13/11, audit FSEANCE-04, FDONNEES-03) : la fenêtre est
 * un fragment, que l'écran recréé retrouve tout seul, et chaque frappe est
 * gardée en brouillon (NoteBrouillon). La garde « quelque chose a changé »
 * couvre les cinq champs, pas la seule note.
 */
class NoteDialog : DialogFragment() {

    /**
     * L'écran qui porte la note. Il a pu être recréé depuis l'ouverture :
     * c'est lui qu'on prévient, pas une fonction retenue à l'ouverture.
     */
    interface Hote {
        /** La note du jour [date] vient d'être enregistrée. */
        fun noteEnregistree(date: String) {}

        /** La fenêtre s'est fermée, enregistrée ou non. */
        fun noteFermee(date: String) {}
    }

    private lateinit var date: String

    /** Ce que le journal garde déjà pour ce jour : la mesure de « quelque chose a changé ». */
    private lateinit var enregistre: NoteBrouillon.Etat

    private lateinit var champNote: EditText
    private lateinit var champGratitude: EditText
    private lateinit var champTravail: EditText
    private lateinit var humeurAvant: Humeurs
    private lateinit var humeurApres: Humeurs

    /** Vrai pendant que la fenêtre remplit elle-même ses champs : ce n'est pas une frappe. */
    private var remplissage = false

    /** Une rangée de cinq humeurs ; toucher celle qui est choisie la retire (0 : non notée). */
    private inner class Humeurs(activity: FragmentActivity, titre: Int) {
        var valeur = 0
            private set

        private val density = activity.resources.displayMetrics.density

        private val boutons = JournalPlus.HUMEURS.mapIndexed { i, e ->
            TextView(activity).apply {
                text = e
                textSize = 26f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(0, (44 * density).toInt(), 1f)
                contentDescription = activity.getString(R.string.journal_humeur_n, i + 1)
                setOnClickListener {
                    poser(if (valeur == i + 1) 0 else i + 1)
                    suivre()
                }
            }
        }

        val vue = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, (8 * density).toInt(), 0, 0)
            addView(TextView(activity).apply { setText(titre); textSize = 13f })
            addView(LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                boutons.forEach { addView(it) }
            })
        }

        fun poser(n: Int) {
            valeur = n
            boutons.forEachIndexed { j, b -> b.alpha = if (n == j + 1) 1f else 0.35f }
        }
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val activity = requireActivity()
        date = requireArguments().getString(ARG_DATE).orEmpty()
        val density = activity.resources.displayMetrics.density
        val pad = (16 * density).toInt()

        // Le hassid qui écrit : c'est une note qu'on laisse (demande du 29/09).
        val art = PersonnageImageView(activity).apply {
            setImageResource(R.drawable.char_writing)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (120 * density).toInt()
            )
        }

        champNote = EditText(activity).apply {
            filters = arrayOf(android.text.InputFilter.LengthFilter(Store.NOTE_MAX))
            setHint(R.string.note_hint)
            setLines(4)
            gravity = Gravity.TOP or Gravity.START
        }

        // Le journal enrichi (14/10) : l'humeur avant et après, une gratitude.
        humeurAvant = Humeurs(activity, R.string.journal_humeur_avant)
        humeurApres = Humeurs(activity, R.string.journal_humeur_apres)
        champGratitude = EditText(activity).apply {
            filters = arrayOf(android.text.InputFilter.LengthFilter(JournalPlus.GRATITUDE_MAX))
            setHint(R.string.journal_gratitude_hint)
            setSingleLine()
        }
        // La seconde question de fin (19/10) : une chose à travailler.
        champTravail = EditText(activity).apply {
            filters = arrayOf(android.text.InputFilter.LengthFilter(JournalPlus.GRATITUDE_MAX))
            setHint(R.string.journal_travail_hint)
            setSingleLine()
        }

        // Le brouillon s'il y en a un (fenêtre recréée, processus tué), sinon ce qui est enregistré.
        remplir(depart())
        val frappe = object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = suivre()
        }
        listOf(champNote, champGratitude, champTravail).forEach { it.addTextChangedListener(frappe) }

        val layout = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, 0)
            addView(art)
            addView(champNote)
            addView(humeurAvant.vue)
            addView(humeurApres.vue)
            addView(champGratitude)
            addView(champTravail)
        }
        val defile = android.widget.ScrollView(activity).apply { addView(layout) }

        val dialog = AlertDialog.Builder(activity)
            .setTitle(R.string.note_title)
            .setView(defile)
            .setPositiveButton(R.string.action_save) { _, _ -> enregistrer() }
            .setNegativeButton(R.string.action_later) { _, _ -> abandonner() }
            .create()
        dialog.setCanceledOnTouchOutside(false)
        // La note est ce qu'il y a de plus intime : ni capture ni enregistrement d'écran, comme la liste
        // du journal (JournalActivity) ; la fenêtre est à part et n'hérite pas du drapeau (FDONNEES-12).
        dialog.window?.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        return dialog
    }

    /**
     * À chaque retour de l'écran. Une autre fenêtre de la même note a pu
     * écrire entre-temps (celle du bravo, ouvert par-dessus un écran resté
     * en dessous) : toute fenêtre repart de ce qui est gardé (FDONNEES-02).
     * Les boutons n'existent qu'une fois la fenêtre montrée : c'est ici que
     * « Plus tard » devient « Ne pas enregistrer » pour un brouillon repris.
     */
    override fun onStart() {
        super.onStart()
        val garde = depart()
        if (garde != courant()) remplir(garde)
        montrerGarde()
    }

    /** Ce que la fenêtre doit montrer : le brouillon du jour, sinon ce que le journal garde. */
    private fun depart(): NoteBrouillon.Etat {
        val context = requireContext()
        val plus = JournalPlus.lire(context, date)
        enregistre = NoteBrouillon.Etat(
            Store.record(context, date)?.note.orEmpty(), plus.avant, plus.apres, plus.gratitude, plus.travail,
        )
        return NoteBrouillon.lire(context, date) ?: enregistre
    }

    private fun courant() = NoteBrouillon.Etat(
        champNote.text.toString(), humeurAvant.valeur, humeurApres.valeur,
        champGratitude.text.toString(), champTravail.text.toString(),
    )

    private fun remplir(etat: NoteBrouillon.Etat) {
        remplissage = true
        champNote.setText(etat.note)
        // On reprend là où l'on écrivait : à la fin.
        champNote.setSelection(champNote.text.length)
        humeurAvant.poser(etat.avant)
        humeurApres.poser(etat.apres)
        champGratitude.setText(etat.gratitude)
        champTravail.setText(etat.travail)
        remplissage = false
    }

    /** À chaque frappe et à chaque humeur : le brouillon suit, et la fenêtre sait ce qu'elle a à perdre. */
    private fun suivre() {
        if (remplissage) return
        val context = context ?: return
        NoteBrouillon.garder(context, date, NoteBrouillon.aGarder(enregistre, courant()))
        montrerGarde()
    }

    /** Dès que quelque chose a changé, le retour ne ferme plus, et le bouton dit ce qu'il fait. */
    private fun montrerGarde() {
        val change = NoteBrouillon.modifie(enregistre, courant())
        isCancelable = !change
        (dialog as? AlertDialog)?.getButton(DialogInterface.BUTTON_NEGATIVE)
            ?.setText(if (change) R.string.note_discard else R.string.action_later)
    }

    private fun enregistrer() {
        val context = requireContext()
        val etat = courant()
        // Le journal enrichi d'abord : setNote regarde s'il reste de quoi garder la ligne du jour (FDONNEES-14).
        JournalPlus.ecrire(context, date, JournalPlus.Plus(etat.avant, etat.apres, etat.gratitude.trim(), etat.travail.trim()))
        Store.setNote(context, date, etat.note.trim())
        NoteBrouillon.garder(context, date, null)
        hote()?.noteEnregistree(date)
        hote()?.noteFermee(date)
    }

    /** « Plus tard », ou « Ne pas enregistrer » : ce qui était tapé est laissé, brouillon compris. */
    private fun abandonner() {
        NoteBrouillon.garder(requireContext(), date, null)
        hote()?.noteFermee(date)
    }

    /**
     * Le retour, possible tant que rien n'a changé. La fermeture se dit ici
     * et sur les deux boutons, pas dans onDismiss : le fragment y passe aussi
     * quand l'écran est recréé, et le bravo se serait fermé à la rotation.
     */
    override fun onCancel(dialog: DialogInterface) {
        super.onCancel(dialog)
        hote()?.noteFermee(date)
    }

    private fun hote(): Hote? = activity as? Hote

    companion object {
        private const val ETIQUETTE = "note"
        private const val ARG_DATE = "date"

        /** Ouvre la note du jour [date] sur cet écran ; une seule à la fois. */
        fun show(activity: FragmentActivity, date: String) {
            val fragments = activity.supportFragmentManager
            if (fragments.isStateSaved || fragments.findFragmentByTag(ETIQUETTE) != null) return
            NoteDialog().apply { arguments = Bundle().apply { putString(ARG_DATE, date) } }
                .show(fragments, ETIQUETTE)
        }

        /** Une note est ouverte sur cet écran : le bravo attend qu'elle se ferme (FSEANCE-03). */
        fun ouverte(activity: FragmentActivity): Boolean =
            activity.supportFragmentManager.findFragmentByTag(ETIQUETTE) != null
    }
}
