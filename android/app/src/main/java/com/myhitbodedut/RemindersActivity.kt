package com.myhitbodedut

import android.app.TimePickerDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.materialswitch.MaterialSwitch

/**
 * Les rappels de hitbodedout.
 *
 * L'écran existe parce qu'une ligne dans la carte des réglages ne se trouve
 * pas : le rappel était là depuis le début, éteint, et invisible.
 *
 * Plusieurs heures peuvent être réglées. La règle ne change pas pour
 * autant : rien ne sonne un jour de repos, rien ne sonne la veille après
 * midi, et rien ne sonne une fois la séance faite.
 */
class RemindersActivity : AppCompatActivity() {

    /** La demande partagée (13/11) : après deux refus, elle mène à l'écran système au lieu de rester sans effet. */
    private val notifications = DemandeNotifications(this) { render() }

    private lateinit var heures: MutableList<Int>
    private lateinit var adapter: Adapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_reminders)

        heures = Store.reminderTimes(this).toMutableList()
        adapter = Adapter()
        findViewById<RecyclerView>(R.id.reminders_list).apply {
            layoutManager = LinearLayoutManager(this@RemindersActivity)
            adapter = this@RemindersActivity.adapter
        }

        findViewById<MaterialSwitch>(R.id.reminders_switch).apply {
            isChecked = Store.reminderEnabled(this@RemindersActivity)
            setOnCheckedChangeListener { _, coche ->
                Store.setReminderEnabled(this@RemindersActivity, coche)
                if (coche) notifications.lancer()
                Reminder.reschedule(this@RemindersActivity)
                render()
            }
        }

        findViewById<Button>(R.id.reminders_add).setOnClickListener { ajoute() }

        findViewById<MaterialSwitch>(R.id.reminders_trophee).apply {
            isChecked = Store.rappelTropheeProche(this@RemindersActivity)
            setOnCheckedChangeListener { _, coche -> Store.setRappelTropheeProche(this@RemindersActivity, coche) }
        }

        findViewById<TextView>(R.id.reminders_permission).setOnClickListener { notifications.lancer() }
    }

    override fun onResume() {
        super.onResume()
        render()
    }

    private fun render() {
        val actif = Store.reminderEnabled(this)
        findViewById<TextView>(R.id.reminders_summary).text = when {
            !actif -> getString(R.string.reminders_off)
            heures.isEmpty() -> getString(R.string.reminders_none)
            else -> resources.getQuantityString(
                R.plurals.reminders_count, heures.size, heures.size
            )
        }

        // Sans la permission, le rappel se programme et ne s'affiche jamais :
        // il faut le dire, pas laisser croire qu'il est actif.
        val manque = PermissionRules.rappelMuet(actif, Permissions.hasNotifications(this), notifications.enCours)
        findViewById<TextView>(R.id.reminders_permission).apply {
            visibility = if (manque) View.VISIBLE else View.GONE
            setText(R.string.reminders_permission_missing)
        }
        adapter.notifyDataSetChanged()
    }

    private fun ajoute() {
        val depart = heures.lastOrNull() ?: Store.DEFAULT_REMINDER
        TimePickerDialog(
            this,
            { _, h, m -> enregistre(heures + (h * 60 + m)) },
            (depart / 60) % 24, depart % 60, android.text.format.DateFormat.is24HourFormat(this),
        ).show()
    }

    private fun enregistre(nouvelles: List<Int>) {
        Store.setReminderTimes(this, nouvelles)
        heures = Store.reminderTimes(this).toMutableList()
        Reminder.reschedule(this)
        render()
    }

    private inner class Adapter : RecyclerView.Adapter<Adapter.Holder>() {

        inner class Holder(view: View) : RecyclerView.ViewHolder(view) {
            val heure: TextView = view.findViewById(R.id.reminder_hour)
            val retirer: Button = view.findViewById(R.id.reminder_remove)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = Holder(
            LayoutInflater.from(parent.context).inflate(R.layout.item_reminder, parent, false)
        )

        override fun getItemCount(): Int = heures.size

        override fun onBindViewHolder(holder: Holder, position: Int) {
            val minutes = heures[position]
            holder.heure.text = Store.formatHeure(this@RemindersActivity, minutes)
            holder.itemView.setOnClickListener {
                TimePickerDialog(
                    this@RemindersActivity,
                    { _, h, m ->
                        enregistre(heures.filterIndexed { i, _ -> i != position } + (h * 60 + m))
                    },
                    (minutes / 60) % 24, minutes % 60, android.text.format.DateFormat.is24HourFormat(this@RemindersActivity),
                ).show()
            }
            holder.retirer.setOnClickListener {
                enregistre(heures.filterIndexed { i, _ -> i != position })
            }
        }
    }
}
