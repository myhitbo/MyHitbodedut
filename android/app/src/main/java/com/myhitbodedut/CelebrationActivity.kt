package com.myhitbodedut

import android.animation.ValueAnimator
import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import kotlin.random.Random

/**
 * La fin d'une séance : le hassid danse, et l'application dit bravo.
 *
 * Elle s'ouvre une fois par séance close, où qu'on se trouve quand on
 * revient : sur l'écran de séance si on l'avait gardé ouvert, sur l'accueil
 * si la séance s'est achevée téléphone posé.
 *
 * Une séance annulée ouvre le même écran, sans danse : « ’Hazak », et un mot
 * de ’hizouk du moment « relance », ceux qui disent de ne jamais désespérer
 * (Likoutei Moharan II, 78 : אֵין שׁוּם יֵאוּשׁ בָּעוֹלָם כְּלָל). Demande du
 * propriétaire, 28/09.
 *
 * Depuis le 13/11, la fin de séance tient sur cet écran : sous le bravo,
 * l'humeur d'une touche, puis la gratitude, la chose à travailler et la note,
 * qui s'ouvraient dans une fenêtre à part après « Continuer ». Ce qui est
 * écrit est enregistré en quittant l'écran, par le bouton comme par le retour.
 */
class CelebrationActivity : AppCompatActivity() {

    private var danse: ValueAnimator? = null

    private val notes = Handler(Looper.getMainLooper())

    private val annulee: Boolean by lazy { intent.getBooleanExtra(EXTRA_ANNULEE, false) }

    /** Le jour de la séance (AAAA-MM-JJ) : celui dont la page du carnet est proposée ; null, pas de page. */
    private val dateNote: String? by lazy { intent.getStringExtra(EXTRA_NOTE_DATE)?.takeIf { !annulee } }

    /** L'humeur choisie après la séance, de 1 à 5 ; 0, aucune. */
    private var apres = 0

    /** La page du carnet telle qu'elle était à l'ouverture : on n'écrit que ce qui a changé. */
    private var initiale = JournalPlus.Plus()
    private var noteInitiale = ""

    /** Vrai pendant que l'écran remplit lui-même ses champs : ce n'est pas une frappe à garder. */
    private var remplissage = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_celebration)
        // Petit écran (15/10) : la scène, mesurée sans limite dans le défilement, prenait la
        // hauteur de l'image et repoussait « Bravo » et « Continuer » hors de l'écran.
        findViewById<FrameLayout>(R.id.celebration_stage).apply {
            val haut = resources.displayMetrics.heightPixels
            if (haut / resources.displayMetrics.density < 720) {
                layoutParams = (layoutParams as LinearLayout.LayoutParams).apply { height = (haut * 0.42).toInt(); weight = 0f }
            }
        }

        val minutes = intent.getIntExtra(EXTRA_MINUTES, 0)
        findViewById<TextView>(R.id.celebration_minutes).apply {
            if (annulee) {
                visibility = View.VISIBLE
                setText(R.string.annulation_subtitle)
            } else {
                visibility = if (minutes > 0) View.VISIBLE else View.GONE
                text = resources.getQuantityString(R.plurals.celebration_minutes, minutes, minutes)
            }
        }
        val chizuk = findViewById<View>(R.id.celebration_chizuk)
        // Un jour la danse, le lendemain la guitare (12/10), le surlendemain le pouce levé (13/10) :
        // le personnage se balance au même rythme.
        val seul = when (Math.floorMod(java.time.LocalDate.now().toEpochDay(), 3L)) {
            1L -> R.drawable.char_guitar
            2L -> R.drawable.char_thumbs_up
            else -> null
        }
        if (!annulee && seul != null) {
            findViewById<ImageView>(R.id.celebration_art).setImageResource(seul)
            findViewById<ImageView>(R.id.celebration_art_b).setImageResource(seul)
        }
        if (annulee) {
            findViewById<ImageView>(R.id.celebration_art).setImageResource(R.drawable.char_walking)
            if (ChizukCard.show(chizuk, Moment.RELANCE) == null) chizuk.visibility = View.GONE
        } else {
            chizuk.visibility = View.GONE
        }
        // Sans choix enregistré, le titre reste neutre : la question
        // צדיק / צדקת ne se pose que dans la présentation (demande du 28/09).
        val adresse = Store.adresse(this)
        findViewById<TextView>(R.id.celebration_title).setText(
            if (annulee) Adresse.hazak(adresse) else Adresse.bravo(adresse)
        )
        carnet(savedInstanceState)
        // Partager la séance faite (12/10) : un texte et le lien de la version web, par le choix du téléphone.
        findViewById<Button>(R.id.celebration_share).apply {
            visibility = if (!annulee && minutes > 0) View.VISIBLE else View.GONE
            setOnClickListener { partager(minutes) }
        }
        findViewById<Button>(R.id.celebration_continue).setOnClickListener {
            enregistrer()
            finish()
        }
        // Le retour enregistre aussi : ce qu'on a écrit ne se perd pas d'un geste (revue du 29/09).
        onBackPressedDispatcher.addCallback(this, object : androidx.activity.OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                enregistrer()
                finish()
            }
        })
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(ETAT_APRES, apres)
        outState.putBoolean(ETAT_SUITE, findViewById<View>(R.id.celebration_suite).visibility == View.VISIBLE)
    }

    /**
     * La page du carnet sous le bravo : cinq humeurs, puis — dès qu'on en
     * touche une, ou « Écrire une note » — la gratitude, la chose à
     * travailler et la note. Préremplie avec ce que le jour porte déjà
     * (une seconde séance le même jour).
     */
    private fun carnet(etat: Bundle?) {
        val date = dateNote ?: return
        findViewById<View>(R.id.celebration_carnet).visibility = View.VISIBLE
        initiale = JournalPlus.lire(this, date)
        noteInitiale = Store.record(this, date)?.note.orEmpty()
        // Ce qui a été tapé puis perdu (processus tué, écran recréé) revient du brouillon,
        // comme dans la fenêtre de note (NoteBrouillon, audit FSEANCE-04, FDONNEES-02 et 03).
        val brouillon = NoteBrouillon.lire(this, date)
        apres = etat?.getInt(ETAT_APRES, brouillon?.apres ?: initiale.apres) ?: (brouillon?.apres ?: initiale.apres)
        val gratitude = findViewById<android.widget.EditText>(R.id.celebration_gratitude)
        val travail = findViewById<android.widget.EditText>(R.id.celebration_travail)
        val note = findViewById<android.widget.EditText>(R.id.celebration_note)
        gratitude.filters = arrayOf(android.text.InputFilter.LengthFilter(JournalPlus.GRATITUDE_MAX))
        travail.filters = arrayOf(android.text.InputFilter.LengthFilter(JournalPlus.GRATITUDE_MAX))
        note.filters = arrayOf(android.text.InputFilter.LengthFilter(Store.NOTE_MAX))
        // À la première création seulement : une rotation garde ce qui est en cours de saisie.
        if (etat == null) {
            remplissage = true
            gratitude.setText(brouillon?.gratitude ?: initiale.gratitude)
            travail.setText(brouillon?.travail ?: initiale.travail)
            note.setText(brouillon?.note ?: noteInitiale)
            remplissage = false
        }
        val d = resources.displayMetrics.density
        val rang = findViewById<LinearLayout>(R.id.celebration_humeurs)
        val cases = JournalPlus.HUMEURS.mapIndexed { i, emoji ->
            TextView(this).apply {
                text = emoji
                textSize = 26f
                gravity = android.view.Gravity.CENTER
                setBackgroundResource(R.drawable.bg_humeur)
                contentDescription = "${i + 1}/5"
                isSelected = apres == i + 1
                layoutParams = LinearLayout.LayoutParams(0, (56 * d).toInt(), 1f).apply {
                    if (i > 0) marginStart = (8 * d).toInt()
                }
            }
        }
        cases.forEachIndexed { i, case ->
            case.setOnClickListener {
                // Retoucher l'humeur choisie la retire.
                apres = if (apres == i + 1) 0 else i + 1
                cases.forEachIndexed { j, c -> c.isSelected = apres == j + 1 }
                ouvrirSuite(anime = true)
                suivre()
            }
            rang.addView(case)
        }
        findViewById<Button>(R.id.celebration_ecrire).setOnClickListener {
            ouvrirSuite(anime = true)
            note.requestFocus()
        }
        val suit = object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: android.text.Editable?) {
                if (!remplissage) suivre()
            }
        }
        listOf(gratitude, travail, note).forEach { it.addTextChangedListener(suit) }
        // Un brouillon en attente rouvre la page du carnet, là où on l'avait laissée.
        if (etat?.getBoolean(ETAT_SUITE, false) == true || brouillon != null) ouvrirSuite(anime = false)
        majBouton()
    }

    /**
     * La suite du carnet apparaît, et la scène se réduit pour lui laisser la
     * place : le hassid continue de danser, plus petit, en tête de la page.
     */
    private fun ouvrirSuite(anime: Boolean) {
        val suite = findViewById<View>(R.id.celebration_suite)
        if (suite.visibility == View.VISIBLE) return
        suite.visibility = View.VISIBLE
        findViewById<View>(R.id.celebration_ecrire).visibility = View.GONE
        findViewById<View>(R.id.celebration_share).visibility = View.GONE
        findViewById<FrameLayout>(R.id.celebration_stage).apply {
            minimumHeight = 0
            layoutParams = (layoutParams as LinearLayout.LayoutParams).apply {
                height = (PETITE_SCENE_DP * resources.displayMetrics.density).toInt()
                weight = 0f
            }
        }
        if (anime && ValueAnimator.areAnimatorsEnabled()) {
            suite.alpha = 0f
            suite.animate().alpha(1f).setDuration(220L).start()
        }
    }

    /** Ce que la page porte maintenant. */
    private fun saisie(): Pair<JournalPlus.Plus, String> = Pair(
        initiale.copy(
            apres = apres,
            gratitude = findViewById<android.widget.EditText>(R.id.celebration_gratitude).text.toString().trim(),
            travail = findViewById<android.widget.EditText>(R.id.celebration_travail).text.toString().trim(),
        ),
        findViewById<android.widget.EditText>(R.id.celebration_note).text.toString().trim(),
    )

    /** La page, dans la forme du brouillon de note : ce qui est enregistré, puis ce qui est à l'écran. */
    private fun etatEnregistre() = NoteBrouillon.Etat(noteInitiale, initiale.avant, initiale.apres, initiale.gratitude, initiale.travail)
    private fun etatCourant(): NoteBrouillon.Etat {
        val (plus, note) = saisie()
        return NoteBrouillon.Etat(note, plus.avant, plus.apres, plus.gratitude, plus.travail)
    }

    /** Chaque frappe et chaque humeur : le bouton suit, et le brouillon garde ce qui n'est pas encore enregistré. */
    private fun suivre() {
        val date = dateNote ?: return
        NoteBrouillon.garder(this, date, NoteBrouillon.aGarder(etatEnregistre(), etatCourant()))
        majBouton()
    }

    /** « Enregistrer » dès que la page porte quelque chose de neuf ; « Continuer » sinon. */
    private fun majBouton() {
        if (dateNote == null) return
        val (plus, note) = saisie()
        findViewById<Button>(R.id.celebration_continue).setText(
            if (plus != initiale || note != noteInitiale.trim()) R.string.action_save else R.string.celebration_continue
        )
    }

    /** N'écrit que ce qui a changé : une page laissée telle quelle ne touche à rien. */
    private fun enregistrer() {
        val date = dateNote ?: return
        val (plus, note) = saisie()
        if (note != noteInitiale.trim()) Store.setNote(this, date, note)
        if (plus != initiale) JournalPlus.ecrire(this, date, plus)
        initiale = plus
        noteInitiale = note
        // Enregistré : le brouillon n'a plus rien à garder.
        NoteBrouillon.garder(this, date, null)
    }

    override fun onStart() {
        super.onStart()
        danser()
    }

    override fun onStop() {
        danse?.cancel()
        danse = null
        notes.removeCallbacksAndMessages(null)
        super.onStop()
    }

    /**
     * Une danse de hassid, pas une image qui tremble : à chaque temps il
     * saute, retombe en pliant un peu les genoux, et change de jambe — les
     * deux poses superposées se relaient au moment où il touche le sol. Le
     * corps se balance d'un côté puis de l'autre sur deux temps, et des
     * notes montent de la scène.
     *
     * Rien si les animations sont coupées dans le téléphone : c'est souvent
     * un choix d'accessibilité, pas un oubli. La pose fixe reste alors.
     */
    private fun danser() {
        if (annulee || !ValueAnimator.areAnimatorsEnabled()) return
        val danseur = findViewById<View>(R.id.celebration_dancer)
        val poseA = findViewById<View>(R.id.celebration_art)
        val poseB = findViewById<View>(R.id.celebration_art_b)
        val saut = 16f * resources.displayMetrics.density

        danse = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2 * DanseMesure.TEMPS_MS
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener {
                val t = it.animatedValue as Float
                val pas = DanseMesure.pas(t)
                danseur.pivotX = danseur.width / 2f
                danseur.pivotY = danseur.height.toFloat()
                danseur.translationY = -saut * pas.hauteur
                danseur.scaleX = 1f + 0.04f * pas.flexion
                danseur.scaleY = 1f - 0.05f * pas.flexion
                danseur.rotation = 6f * pas.balance
                poseA.alpha = 1f - pas.poseB
                poseB.alpha = pas.poseB
            }
            start()
        }
        notes.post(object : Runnable {
            override fun run() {
                lancerNote()
                notes.postDelayed(this, DanseMesure.TEMPS_MS + 180L)
            }
        })
    }

    /** Une note ou une étoile qui monte de la scène et s'efface. */
    private fun lancerNote() {
        val scene = findViewById<FrameLayout>(R.id.celebration_stage)
        if (scene.width == 0) return
        val dp = resources.displayMetrics.density
        val note = TextView(this).apply {
            text = SIGNES[Random.nextInt(SIGNES.size)]
            textSize = 18f + Random.nextInt(8)
            // La scène est une plaque claire de jour comme de nuit.
            setTextColor(Apparence.couleur(this@CelebrationActivity, R.color.on_plate))
        }
        val cote = if (Random.nextBoolean()) 0.18f else 0.72f
        scene.addView(
            note,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
        )
        note.x = scene.width * (cote + Random.nextFloat() * 0.1f)
        note.y = scene.height * 0.55f
        note.animate()
            .translationYBy(-scene.height * 0.45f)
            .translationXBy((Random.nextFloat() - 0.5f) * 30f * dp)
            .rotation((Random.nextFloat() - 0.5f) * 40f)
            .alpha(0f)
            .setDuration(1700L)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction { scene.removeView(note) }
            .start()
    }

    private fun partager(minutes: Int) {
        val serie = Store.streak(this)
        val texte = listOfNotNull(
            getString(R.string.partage_texte, resources.getQuantityString(R.plurals.partage_minutes, minutes, minutes)),
            if (serie >= 2) getString(R.string.partage_serie, serie) else null,
            getString(R.string.partage_lien, LIEN_WEB),
        ).joinToString("\n")
        val envoi = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, texte)
        runCatching { startActivity(Intent.createChooser(envoi, getString(R.string.partage_choix))) }
    }

    companion object {
        /** La version web de l'application, jointe à chaque partage. */
        const val LIEN_WEB = "https://myhitbodedut.pages.dev/"

        const val EXTRA_MINUTES = "minutes"
        const val EXTRA_ANNULEE = "annulee"
        const val EXTRA_NOTE_DATE = "note_date"

        private const val ETAT_APRES = "apres"
        private const val ETAT_SUITE = "suite"

        /** La hauteur de la scène quand le carnet est ouvert. */
        private const val PETITE_SCENE_DP = 132

        private val SIGNES = arrayOf("♪", "♫", "♪", "✦")

        /** Après une séance annulée : pas de bravo, un encouragement. */
        fun annulation(activity: Activity) {
            activity.startActivity(
                Intent(activity, CelebrationActivity::class.java).putExtra(EXTRA_ANNULEE, true)
            )
        }

        /**
         * Ouvre le bravo si une séance vient de se clore. La marque est
         * retirée avant l'ouverture, pas à la fermeture : deux écrans qui
         * reprennent la main l'un après l'autre ne l'ouvriraient pas deux fois.
         *
         * [sansNote] : la note vient d'être proposée (mode « Écrire », le
         * bravo a attendu sa fermeture) ; « Continuer » ne la rouvre pas
         * (13/11, audit FSEANCE-03).
         */
        fun showIfPending(activity: Activity, sansNote: Boolean = false) {
            val celebration = Store.takePendingCelebration(activity) ?: return
            activity.startActivity(
                Intent(activity, CelebrationActivity::class.java)
                    .putExtra(EXTRA_MINUTES, celebration.minutes)
                    .putExtra(EXTRA_NOTE_DATE, celebration.dateNote.takeUnless { sansNote })
            )
        }
    }
}
