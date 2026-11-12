package com.myhitbodedut

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Historique des séances, avec les notes laissées après chacune. */
class JournalActivity : AppCompatActivity() {

    private val rows = mutableListOf<DayRecord>()
    private lateinit var adapter: Adapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_journal)
        // Les notes sont ce qu'il y a de plus intime : ni capture d'écran,
        // ni aperçu dans les applications récentes (revue du 01/10).
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_SECURE,
            android.view.WindowManager.LayoutParams.FLAG_SECURE
        )
        verrouiller(savedInstanceState)
        adapter = Adapter()
        findViewById<RecyclerView>(R.id.journal_list).apply {
            layoutManager = LinearLayoutManager(this@JournalActivity)
            adapter = this@JournalActivity.adapter
        }
    }

    /** Vrai une fois le code ou l'empreinte donnés, ou si le verrou n'est pas demandé. */
    private var ouvert = true

    private val demandeCode =
        registerForActivityResult(androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult()) { resultat ->
            if (resultat.resultCode == RESULT_OK) {
                ouvert = true
                findViewById<View>(android.R.id.content).visibility = View.VISIBLE
                reload()
            } else {
                finish()
            }
        }

    /**
     * Le verrou du journal (audit du 12/11) : rien ne s'affiche avant le code
     * ou l'empreinte du téléphone. Un téléphone sans verrouillage d'écran n'a
     * rien à demander : le journal s'ouvre, comme avant.
     */
    private fun verrouiller(etat: Bundle?) {
        if (!Store.journalVerrou(this) || etat?.getBoolean(ETAT_OUVERT) == true) return
        val garde = getSystemService(android.app.KeyguardManager::class.java) ?: return
        if (!garde.isDeviceSecure) return
        @Suppress("DEPRECATION")
        val demande = garde.createConfirmDeviceCredentialIntent(getString(R.string.journal_verrou_titre), null) ?: return
        ouvert = false
        findViewById<View>(android.R.id.content).visibility = View.INVISIBLE
        // Après une rotation, la demande est déjà à l'écran : on attend sa réponse.
        if (etat?.getBoolean(ETAT_DEMANDE) != true) demandeCode.launch(demande)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(ETAT_OUVERT, ouvert)
        outState.putBoolean(ETAT_DEMANDE, !ouvert)
    }

    override fun onResume() {
        super.onResume()
        if (ouvert) reload()
    }

    private fun reload() {
        rows.clear()
        rows.addAll(Store.days(this).values.sortedByDescending { it.date })
        adapter.notifyDataSetChanged()

        val empty = findViewById<View>(R.id.journal_empty)
        empty.visibility = if (rows.isEmpty()) View.VISIBLE else View.GONE
        findViewById<View>(R.id.journal_empty_commencer).setOnClickListener {
            startActivity(android.content.Intent(this, SessionActivity::class.java))
        }

        // Les journées faites seulement : une note seule n'en est pas une.
        val faites = rows.count { it.faite }
        val total = Store.totalMinutes(this)
        // Le graphique du mois (14/10), sous le résumé, dans le bandeau.
        val resume = findViewById<TextView>(R.id.journal_summary)
        val bandeau = resume.parent as ViewGroup
        bandeau.findViewWithTag<View>("graphique")?.let { bandeau.removeView(it) }
        val mois = java.time.YearMonth.now()
        bandeau.addView(JournalPlus.Graphique(this, JournalPlus.minutesDuMois(Store.days(this), mois), java.time.LocalDate.now().dayOfMonth).apply {
            tag = "graphique"
            contentDescription = getString(R.string.journal_graphique, mois.format(DateTimeFormatter.ofPattern("MMMM yyyy", resources.configuration.locales[0])))
            layoutParams = android.widget.LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
                .apply { topMargin = (12 * resources.displayMetrics.density).toInt() }
        })
        findViewById<TextView>(R.id.journal_summary).text = resources.getQuantityString(
            R.plurals.journal_summary,
            faites,
            faites,
            Store.formatDuration(this, total)
        )
    }

    private inner class Adapter : RecyclerView.Adapter<Adapter.Holder>() {

        // Les dates dans la langue de l'application : la langue par défaut de Java
        // gardait celle du téléphone, et un journal en anglais affichait
        // « mardi 29 septembre » sur un téléphone réglé en français.
        private val langue: Locale = resources.configuration.locales[0]
        private val formatter = DateTimeFormatter.ofPattern("EEEE d MMMM yyyy", langue)

        inner class Holder(view: View) : RecyclerView.ViewHolder(view) {
            val date: TextView = view.findViewById(R.id.entry_date)
            val duration: TextView = view.findViewById(R.id.entry_duration)
            val note: TextView = view.findViewById(R.id.entry_note)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder =
            Holder(LayoutInflater.from(parent.context).inflate(R.layout.item_journal, parent, false))

        override fun getItemCount(): Int = rows.size

        override fun onBindViewHolder(holder: Holder, position: Int) {
            val row = rows[position]
            // Une date illisible s'affiche telle quelle plutôt que de faire
            // tomber tout l'écran (revue du 29/09).
            holder.date.text = (Store.dateValide(row.date)?.format(formatter) ?: row.date)
                .replaceFirstChar { if (it.isLowerCase()) it.titlecase(langue) else it.toString() }
            holder.duration.text = when {
                row.noteSeule -> getString(R.string.journal_note_only)
                row.minutes > 0 -> Store.formatDuration(holder.itemView.context, row.minutes)
                else -> getString(R.string.today_declared)
            }
            // Le journal enrichi (14/10) : l'humeur et la gratitude sous la note.
            // Le sujet du jour (19/10), puis l'humeur, la gratitude et la chose à travailler.
            val sujets = row.themes.mapNotNull { ThemeRules.parse(it) }.distinct().joinToString(" · ") { getString(it.titre) }
            val plus = JournalPlus.resume(
                JournalPlus.lire(holder.itemView.context, row.date), getString(R.string.journal_gratitude),
                getString(R.string.journal_travail), if (sujets.isBlank()) "" else getString(R.string.journal_sujets, sujets),
            )
            val texte = listOf(row.note, plus).filter { it.isNotBlank() }.joinToString("\n")
            holder.note.visibility = if (texte.isBlank()) View.GONE else View.VISIBLE
            holder.note.text = texte
            holder.itemView.setOnClickListener {
                NoteDialog.show(this@JournalActivity, row.date, onSaved = { reload() })
            }
        }
    }

    private companion object {
        const val ETAT_OUVERT = "journal_ouvert"
        const val ETAT_DEMANDE = "journal_demande"
    }
}
