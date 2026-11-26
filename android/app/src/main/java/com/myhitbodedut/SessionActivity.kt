package com.myhitbodedut

import android.app.NotificationManager
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import java.util.Locale

/** La séance elle-même : choix de la durée, puis décompte. */
class SessionActivity : AppCompatActivity() {

    private val handler = Handler(Looper.getMainLooper())

    private lateinit var countdown: TextView
    private lateinit var caption: TextView
    private lateinit var primary: Button
    private lateinit var secondary: Button
    private lateinit var durations: View
    private lateinit var openSession: Button
    private lateinit var art: ImageView
    private lateinit var musicLine: TextView
    private lateinit var chizuk: View
    private lateinit var stuck: Button
    private lateinit var theme: Button
    private lateinit var guide: View
    private lateinit var souffle: SouffleView
    private lateinit var calme: PratiqueCalme
    private lateinit var miniLecteur: MiniLecteur

    /**
     * Le temps courant de la hitbodedout guidée. Il appartient à la séance
     * et repart à zéro avec elle : un guide qui reprendrait là où l'on
     * s'était arrêté la veille rappellerait une dette.
     */
    private var guideStep = 0

    /** La question en cours de « Je ne sais pas quoi dire » ; -1 : aucune (19/10). */
    private var question = -1

    /**
     * Le bouton de blocage n'a de sens que s'il a un texte à donner. En
     * release, tant qu'aucun texte n'est relu, il n'y en a pas.
     */
    private val hasBlocage: Boolean by lazy {
        ChizukRules.forMoment(Data.chizuk(this), Moment.BLOCAGE, BuildConfig.DEBUG).isNotEmpty()
    }

    /** Pour repérer la fin d'une séance, qu'elle vienne du décompte ou du bouton. */
    private var wasRunning = false

    /** Une séance abandonnée n'est pas une séance close : pas de mot de fin. */
    private var cancelling = false

    /**
     * Le bravo a attendu la fermeture de la note d'« Écrire » : il s'ouvre
     * ensuite sans la reproposer (13/11, audit FSEANCE-03).
     */
    private var bravoApresNote = false

    /** La demande des notifications, proposée une fois au premier départ (13/11, FACCUEIL-05). */
    private val notifications = DemandeNotifications(this) { render() }

    private val tick = object : Runnable {
        override fun run() {
            render()
            handler.postDelayed(this, 1_000L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_session)

        countdown = findViewById(R.id.session_countdown)
        caption = findViewById(R.id.session_caption)
        primary = findViewById(R.id.session_primary)
        secondary = findViewById(R.id.session_secondary)
        durations = findViewById(R.id.session_durations)
        openSession = findViewById(R.id.session_open)
        art = findViewById(R.id.session_character)
        musicLine = findViewById(R.id.session_music)
        chizuk = findViewById(R.id.session_chizuk)
        stuck = findViewById(R.id.session_stuck)
        guide = findViewById(R.id.session_hitbodedut)
        theme = findViewById(R.id.session_theme)
        theme.setOnClickListener { pickTheme() }

        // La pratique calme (16/10) : la lueur derrière le minuteur, et ce qui
        // s'efface après six secondes sans toucher. Restent le minuteur,
        // « Terminer » et, si elle est demandée, la hitbodedout guidée.
        souffle = findViewById(R.id.session_souffle)
        souffle.cible = countdown
        souffle.couleur = Apparence.couleur(this, R.color.mint)
        val fond = findViewById<View>(R.id.session_fond)
        calme = PratiqueCalme(
            this, fond, Apparence.couleur(this, R.color.brand_dark),
            restes = { listOf(primary, guide) + if (::miniLecteur.isInitialized) miniLecteur.vues else emptyList() },
        ) {
            listOf(R.id.session_titre, R.id.session_scene, R.id.session_caption, R.id.session_music,
                R.id.session_secondary, R.id.session_theme, R.id.session_chizuk, R.id.session_stuck)
                .map { findViewById(it) }
        }

        // Une rotation, un passage en écran partagé ou le redimensionnement
        // d'une fenêtre recréent l'écran. Sans cela, le guide repartirait au
        // premier temps et le mot de clôture serait tiré une seconde fois.
        savedInstanceState?.let {
            guideStep = it.getInt(ETAT_GUIDE, 0)
            question = it.getInt(ETAT_QUESTION, -1)
            wasRunning = it.getBoolean(ETAT_EN_COURS, false)
            cancelling = it.getBoolean(ETAT_ABANDON, false)
            bravoApresNote = it.getBoolean(ETAT_BRAVO_APRES_NOTE, false)
        }

        // Le mini-lecteur (19/10) : changer de morceau sans quitter la pratique.
        miniLecteur = MiniLecteur(this)

        // « Je n'arrive pas à parler » : le moment « blocage ».
        // Puis, sous le texte, une question à la fois (propositions 3 et 15, 19/10).
        stuck.setOnClickListener {
            afficherChizuk(Moment.BLOCAGE)
            if (question < 0) question = 0
            renderQuestion()
        }
        findViewById<View>(R.id.session_question_suivante).setOnClickListener {
            question = QuestionsBlocage.suivante(question)
            renderQuestion()
            Effets.fondu(findViewById(R.id.session_questions))
        }

        // « Commencer simplement » (proposition 15) : parler, écrire, prier ou
        // recevoir une question ; chacun démarre la séance aussitôt.
        fun demarrer(ensuite: (() -> Unit)? = null) {
            SessionService.start(this, Store.targetMinutes(this))
            guideStep = 0
            drawOpening()
            render()
            // Écrire, prier ou une question ouvrent aussitôt autre chose : la proposition attendra un départ simple.
            if (ensuite == null) proposerNotifications() else ensuite()
        }
        findViewById<View>(R.id.simplement_parler).setOnClickListener { demarrer() }
        findViewById<View>(R.id.simplement_ecrire).setOnClickListener {
            demarrer { NoteDialog.show(this, Store.today()) }
        }
        findViewById<View>(R.id.simplement_prier).setOnClickListener {
            demarrer { startActivity(android.content.Intent(this, TefilotActivity::class.java)) }
        }
        findViewById<View>(R.id.simplement_question).setOnClickListener {
            demarrer { question = 0; renderQuestion() }
        }

        // « ouverture » : le mot du début de séance. Après une rotation, le texte
        // qu'on lisait est reposé, pas remplacé par un nouveau tirage (FSEANCE-10).
        if (savedInstanceState == null) drawOpening() else restaurerChizuk(savedInstanceState)

        // Une recréation (rotation, thème, langue) rejoue onCreate avec la
        // même intention : la demande de départ n'est lue qu'une fois, sinon
        // une nouvelle séance repartait seule après la fin de la précédente.
        if (savedInstanceState == null) lireDemande(intent)

        // « Sans durée » : la séance court jusqu'à ce qu'on l'arrête. Elle ne
        // touche pas à la durée habituelle, qui reste celle du bouton principal.
        openSession.setOnClickListener {
            SessionService.start(this, SessionRule.OUVERTE)
            guideStep = 0
            drawOpening()
            render()
            proposerNotifications()
        }

        intArrayOf(
            R.id.duration_5, R.id.duration_10, R.id.duration_15,
            R.id.duration_30, R.id.duration_60, R.id.duration_90
        ).forEach { id ->
            val button = findViewById<Button>(id)
            val minutes = button.tag.toString().toInt()
            button.text = Store.formatDuration(this, minutes)
            button.setOnClickListener { commencer(minutes) }
        }
        // « Continuer ? » dix secondes avant la fin (24/11) : l'option se choisit avant de commencer.
        findViewById<com.google.android.material.materialswitch.MaterialSwitch>(R.id.session_suite).apply {
            isChecked = Store.proposerSuite(this@SessionActivity)
            setOnCheckedChangeListener { _, oui -> Store.setProposerSuite(this@SessionActivity, oui) }
        }
        // Un temps choisi, entre 1 et 240 minutes.
        findViewById<Button>(R.id.session_custom).setOnClickListener {
            DureeSeance.saisir(this) { commencer(it) }
        }
    }

    /** L'écran est déjà ouvert (singleTop) : la nouvelle demande est lue aussi. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        lireDemande(intent)
        render()
    }

    /**
     * Venu du bouton « Commencer » d'un rappel, de l'accueil ou de la
     * vignette : la séance part seule, sinon le geste n'aurait fait
     * qu'ouvrir un écran de plus. Les extras sont retirés une fois lus.
     */
    private fun lireDemande(intent: Intent?) {
        intent ?: return
        // Rouvert depuis les Récents : Android rejoue l'intention d'origine,
        // extras compris. Une séance repartait seule (check-up du 11/11).
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) {
            intent.removeExtra(EXTRA_START_NOW)
            intent.removeExtra(EXTRA_DEPUIS_RAPPEL)
            return
        }
        if (intent.getBooleanExtra(EXTRA_DEPUIS_RAPPEL, false)) {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(Notifications.ID_REMINDER)
            Reminder.reschedule(this)
        }
        if (intent.getBooleanExtra(EXTRA_START_NOW, false) && !Store.isSessionRunning(this)) {
            SessionService.start(this, Store.targetMinutes(this))
            guideStep = 0
            drawOpening()
            proposerNotifications()
        }
        intent.removeExtra(EXTRA_START_NOW)
        intent.removeExtra(EXTRA_DEPUIS_RAPPEL)
    }

    /** Lance une séance de cette durée, qui devient aussi la durée habituelle. */
    private fun commencer(minutes: Int) {
        Store.setTargetMinutes(this, minutes)
        SessionService.start(this, minutes)
        guideStep = 0
        drawOpening()
        render()
        proposerNotifications()
    }

    /**
     * Au premier départ, si les notifications manquent (Android 13 ne les accorde plus d'office) :
     * sans elles ni le temps qui reste ni la fin de la séance ne s'affichent téléphone posé. Une
     * phrase le dit, puis Android pose sa question. La séance est déjà partie et n'attend pas la
     * réponse ; accordées, la notification de séance apparaît au tour suivant du service. Une
     * seule fois : « Plus tard » est une réponse, et la carte des autorisations reste dans les réglages.
     */
    private fun proposerNotifications() {
        if (Permissions.hasNotifications(this) || Store.notificationsProposees(this)) return
        Store.setNotificationsProposees(this)
        com.google.android.material.dialog.MaterialAlertDialogBuilder(this)
            .setTitle(R.string.permission_notifications)
            .setMessage(R.string.session_notifications_pourquoi)
            .setNegativeButton(R.string.action_later, null)
            .setPositiveButton(R.string.action_grant) { _, _ -> notifications.lancer() }
            .show()
    }

    override fun onResume() {
        super.onResume()
        SessionService.reconcilier(this)
        handler.removeCallbacks(tick)
        handler.post(tick)
        if (::miniLecteur.isInitialized) miniLecteur.reprendre()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(ETAT_GUIDE, guideStep)
        outState.putInt(ETAT_QUESTION, question)
        chizukAffiche?.let { (moment, id) ->
            outState.putString(ETAT_CHIZUK_MOMENT, moment.name)
            outState.putString(ETAT_CHIZUK_ID, id)
        }
        outState.putBoolean(ETAT_EN_COURS, wasRunning)
        outState.putBoolean(ETAT_ABANDON, cancelling)
        outState.putBoolean(ETAT_BRAVO_APRES_NOTE, bravoApresNote)
    }

    override fun onPause() {
        handler.removeCallbacks(tick)
        miniLecteur.suspendre()
        // La lueur s'arrête avec l'écran ; render() la relance au retour.
        souffle.actif = false
        super.onPause()
    }

    override fun onDestroy() {
        fermerQuestionSuite()
        calme.liberer()
        miniLecteur.fermer()
        super.onDestroy()
    }

    /** Un toucher réveille l'écran calme ; ce premier geste ne touche rien d'autre. */
    override fun dispatchTouchEvent(ev: MotionEvent): Boolean =
        calme.toucher(ev) || super.dispatchTouchEvent(ev)

    override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
        if (event.action == android.view.KeyEvent.ACTION_DOWN) calme.touche()
        return super.dispatchKeyEvent(event)
    }

    private fun render() {
        renderMusicLine()
        miniLecteur.maj()
        renderTheme()

        // « cloture » : au passage de « en cours » à « terminée », que la
        // séance se soit achevée d'elle-même ou par le bouton.
        val running = Store.isSessionRunning(this)
        if (wasRunning && !running) {
            if (cancelling) cancelling = false else afficherChizuk(Moment.CLOTURE)
        }
        wasRunning = running
        // L'écran ne reste allumé que pendant une séance, pas sur l'écran de départ (FSEANCE-19).
        // Au seul changement : render() repasse chaque seconde, et chaque addFlags ou clearFlags
        // renvoie les attributs de la fenêtre au gestionnaire de fenêtres.
        val allume = (window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) != 0
        if (running && !allume) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else if (!running && allume) window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        souffle.actif = running
        calme.suivre(running)
        // Chaque seconde, et pas au seul passage à « terminée » : c'est le
        // service qui clôt la séance, et il peut le faire quelques secondes
        // après que le décompte a touché zéro ici.
        // Mode « Écrire » : une fenêtre ne met pas l'écran en pause, et le
        // bravo s'ouvrait par-dessus la note en cours de frappe, puis en
        // proposait une seconde. Il attend qu'elle se ferme (13/11).
        if (!running) {
            if (NoteDialog.ouverte(this)) {
                if (Store.hasPendingCelebration(this)) bravoApresNote = true
            } else {
                CelebrationActivity.showIfPending(this, sansNote = bravoApresNote)
                bravoApresNote = false
            }
        }

        if (running) {
            art.setImageResource(Character.during())
            // Une séance ouverte n'a rien à décompter : elle compte à
            // l'endroit, depuis son début. Un décompte masqué ne compte pas
            // du tout.
            val counter = Store.sessionCounter(this)
            countdown.visibility =
                if (counter == SessionRule.Compteur.MASQUE) View.GONE else View.VISIBLE
            if (counter != SessionRule.Compteur.MASQUE) {
                val maintenant = Store.maintenantSeance(this)
                val millis = if (counter == SessionRule.Compteur.ECOULE) {
                    (maintenant - Store.sessionStartedAt(this)).coerceAtLeast(0)
                } else {
                    (Store.sessionEndsAt(this) - maintenant).coerceAtLeast(0)
                }
                countdown.text = String.format(
                    Locale.US, "%02d:%02d", millis / 60_000L, (millis / 1_000L) % 60
                )
            }
            caption.text = when (counter) {
                // Sans durée, aucun son ne viendra : la légende ne le promet pas (13/11, audit FSEANCE-05).
                SessionRule.Compteur.MASQUE -> getString(
                    if (Store.isSessionOpen(this)) R.string.session_open_hidden_caption
                    else R.string.session_hidden_caption
                )
                SessionRule.Compteur.ECOULE -> getString(R.string.session_open_caption)
                SessionRule.Compteur.RESTE -> getString(
                    R.string.session_target,
                    Store.formatDuration(this, Store.sessionTarget(this))
                )
            }
            durations.visibility = View.GONE
            openSession.visibility = View.GONE
            findViewById<View>(R.id.session_suite).visibility = View.GONE
            questionSuite()
            findViewById<View>(R.id.session_custom).visibility = View.GONE
            stuck.visibility = if (hasBlocage) View.VISIBLE else View.GONE
            findViewById<View>(R.id.session_simplement).visibility = View.GONE
            renderQuestion()
            renderGuide()

            primary.visibility = View.VISIBLE
            primary.setText(R.string.session_finish_now)
            primary.setOnClickListener { confirmFinish() }

            secondary.visibility = View.VISIBLE
            secondary.setText(R.string.session_cancel)
            secondary.setOnClickListener { confirmCancel() }
        } else {
            art.setImageResource(
                if (Store.isDone(this)) Character.joy() else Character.call()
            )
            countdown.visibility = View.VISIBLE
            countdown.text = Store.formatDuration(this, Store.targetMinutes(this))
            // Fait, le grand chiffre reste la durée de la prochaine : la légende dit ce qui a
            // été fait aujourd'hui (13/10 : 4 min faites, l'écran montrait « 5 min »).
            caption.text = if (Store.isDone(this))
                getString(R.string.session_idle_done, Store.formatDuration(this, Store.record(this)?.minutes ?: 0))
            else getString(R.string.session_idle_caption)
            fermerQuestionSuite()
            durations.visibility = View.VISIBLE
            openSession.visibility = View.VISIBLE
            findViewById<View>(R.id.session_suite).visibility = View.VISIBLE
            findViewById<View>(R.id.session_custom).visibility = View.VISIBLE
            stuck.visibility = View.GONE
            findViewById<View>(R.id.session_simplement).visibility = View.VISIBLE
            question = -1
            renderQuestion()
            HitbodedutCard.hide(guide)

            primary.visibility = View.VISIBLE
            primary.text = getString(
                R.string.session_start,
                Store.formatDuration(this, Store.targetMinutes(this))
            )
            primary.setOnClickListener {
                SessionService.start(this, Store.targetMinutes(this))
                guideStep = 0
                drawOpening()
                render()
                proposerNotifications()
            }
            secondary.visibility = View.GONE
        }
    }

    /** La question en cours, ou rien. */
    private fun renderQuestion() {
        val panneau = findViewById<View>(R.id.session_questions)
        if (question < 0 || !Store.isSessionRunning(this)) {
            panneau.visibility = View.GONE
            return
        }
        panneau.visibility = View.VISIBLE
        findViewById<android.widget.TextView>(R.id.session_question).setText(QuestionsBlocage.QUESTIONS[question])
        findViewById<android.widget.TextView>(R.id.session_question_rang).text =
            getString(R.string.question_rang, question + 1, QuestionsBlocage.QUESTIONS.size)
        findViewById<com.google.android.material.progressindicator.LinearProgressIndicator>(R.id.session_question_jauge)
            .setProgressCompat((question + 1) * 100 / QuestionsBlocage.QUESTIONS.size, true)
    }

    /**
     * La hitbodedout guidée, quand elle est demandée. Le pas courant ne
     * change que sur les boutons de la carte : render() repasse chaque
     * seconde et avancerait tout seul.
     */
    private fun renderGuide() {
        if (!Store.guidedHitbodedut(this)) {
            HitbodedutCard.hide(guide)
            return
        }
        HitbodedutCard.bind(guide, guideStep) { step ->
            guideStep = step
            renderGuide()
        }
    }

    /**
     * Le sujet, et son choix. « Aucun » ouvre la liste : c'est la valeur
     * de depart, et il faut pouvoir y revenir.
     */
    private fun renderTheme() {
        val choisi = Store.sessionTheme(this)
        theme.text = if (choisi == null) {
            getString(R.string.session_theme_none)
        } else {
            getString(R.string.session_theme_chosen, getString(choisi.titre))
        }
    }

    private fun pickTheme() {
        val sujets = Theme.values()
        // « Aucun » en tête : c'est la valeur de départ, et le choix le
        // plus fréquent. L'enfouir sous dix entrées le rendrait difficile
        // à reprendre.
        val libelles = (listOf(getString(R.string.session_theme_none_short)) +
            sujets.map { getString(it.titre) }).toTypedArray()
        AlertDialog.Builder(this)
            .setTitle(R.string.session_theme_title)
            .setItems(libelles) { _, index ->
                Store.setSessionTheme(this, if (index == 0) null else sujets[index - 1])
                renderTheme()
            }
            .show()
    }

    private fun renderMusicLine() {
        // En lecture aléatoire, le morceau qui joue réellement, pas le morceau choisi.
        val choisi = if (Store.musicEnabled(this)) MusicLibrary.selected(this) else null
        // Ce qui joue réellement, dans tous les modes : le morceau touché dans l'écran Musique
        // peut ne pas encore avoir remplacé l'ancien (FSEANCE-07). Hors séance seulement le
        // morceau choisi : « en cours » peut rester d'une séance morte avec le processus, que
        // reconcilier() a close sans l'effacer.
        val enSeance = Store.isSessionRunning(this)
        val maintenant = if (enSeance) Store.musicNow(this) else null
        val track = if (choisi != null) {
            MusicLibrary.byId(this, maintenant) ?: choisi
        } else {
            choisi
        }
        musicLine.visibility = if (track == null) View.GONE else View.VISIBLE
        if (track != null) {
            musicLine.text = if (Store.musicShuffle(this) && maintenant == null) {
                getString(R.string.session_music_line, getString(R.string.music_shuffle_short))
            } else {
                getString(R.string.session_music_line, track.title)
            }
        }
    }

    /** La fenêtre « Continuer ? » ouverte sur cet écran, s'il y en a une. */
    private var suiteDialogue: AlertDialog? = null

    /**
     * « Continuer la hitbodedout ? » (24/11) : quand le service a posé la question et que cet écran
     * est devant les yeux, la même question ici, avec ses quatre réponses — la notification n'en
     * porte que trois. Elle se ferme si l'on répond dans la notification, ou à la fin.
     */
    private fun questionSuite() {
        val posee = Store.suiteEtat(this) == Store.SUITE_POSEE && !Store.isSessionOpen(this)
        if (!posee) { fermerQuestionSuite(); return }
        if (suiteDialogue?.isShowing == true) return
        val pas = Store.sessionPas(this)
        val choix = buildList {
            add(getString(R.string.session_suite_oui_plus, Store.formatDuration(this@SessionActivity, 5)) to 5)
            if (pas > 0 && pas != 5) add(getString(R.string.session_suite_oui_plus, Store.formatDuration(this@SessionActivity, pas)) to pas)
            add(getString(R.string.session_suite_oui_sans_fin) to SessionRule.OUVERTE)
            add(getString(R.string.session_suite_non) to -1)
        }
        suiteDialogue = com.google.android.material.dialog.MaterialAlertDialogBuilder(this)
            .setTitle(R.string.session_suite_titre)
            .setItems(choix.map { it.first }.toTypedArray()) { _, i ->
                val minutes = choix[i].second
                if (minutes < 0) SessionService.nePasContinuer(this) else SessionService.continuer(this, minutes)
                suiteDialogue = null
                handler.postDelayed({ if (!isFinishing) render() }, 300L)
            }
            // Fermée sans choix : comme « Non », la séance va à son terme.
            .setOnCancelListener { SessionService.nePasContinuer(this); suiteDialogue = null }
            .show()
    }

    private fun fermerQuestionSuite() {
        suiteDialogue?.let { if (it.isShowing) runCatching { it.dismiss() } }
        suiteDialogue = null
    }

    private fun confirmFinish() {
        AlertDialog.Builder(this)
            .setTitle(R.string.session_finish_title)
            .setMessage(
                // Avant une minute pleine, rien n'est inscrit (FSEANCE-12).
                if (SessionRule.minutesEcoulees(Store.sessionStartedAt(this), Store.maintenantSeance(this)) < 1) {
                    R.string.session_finish_short
                } else {
                    R.string.session_finish_message
                },
            )
            .setPositiveButton(R.string.session_finish_now) { _, _ ->
                // La note est proposée par le bravo, après lui : ouverte ici,
                // elle se retrouvait sous l'écran du bravo (revue du 29/09).
                SessionService.finishNow(this)
            }
            .setNegativeButton(R.string.action_back, null)
            .show()
    }

    private fun confirmCancel() {
        AlertDialog.Builder(this)
            .setTitle(R.string.session_cancel_title)
            .setMessage(
                if (Store.isDone(this)) R.string.session_cancel_message_done else R.string.session_cancel_message,
            )
            .setPositiveButton(R.string.session_cancel) { _, _ ->
                cancelling = true
                SessionService.cancel(this)
                render()
                CelebrationActivity.annulation(this)
            }
            .setNegativeButton(R.string.action_back, null)
            .show()
    }

    /**
     * Tire le mot d'ouverture. Appelé à l'entrée sur l'écran et au démarrage
     * de chaque séance, jamais depuis render(), qui repasse chaque seconde.
     */
    private fun drawOpening() {
        afficherChizuk(Moment.OUVERTURE)
    }

    /** Le texte de 'hizouk à l'écran : (moment, identifiant), gardé pour la recréation (rotation). */
    private var chizukAffiche: Pair<Moment, String>? = null

    private fun afficherChizuk(moment: Moment) {
        val item = ChizukCard.show(chizuk, moment)
        chizukAffiche = item?.let { moment to it.id }
    }

    /** Repose le texte lu avant une rotation, sans rien tirer (FSEANCE-10). */
    private fun restaurerChizuk(etat: Bundle) {
        val moment = etat.getString(ETAT_CHIZUK_MOMENT)?.let { nom -> Moment.values().firstOrNull { it.name == nom } }
        val id = etat.getString(ETAT_CHIZUK_ID)
        val data = Data.chizuk(this)
        val item = if (moment != null && id != null) data.byId(id) else null
        if (moment != null && item != null) {
            ChizukCard.bind(chizuk, data, item, moment)
            chizukAffiche = moment to item.id
        } else {
            chizuk.visibility = View.GONE
        }
    }

    companion object {
        /** Posé par le bouton « Commencer » d'une notification de rappel. */
        const val EXTRA_START_NOW = "start_now"

        /** Posé par le rappel : l'écran retire la notification. */
        const val EXTRA_DEPUIS_RAPPEL = "depuis_rappel"

        private const val ETAT_GUIDE = "guide_step"
        private const val ETAT_QUESTION = "question"
        private const val ETAT_CHIZUK_MOMENT = "chizuk_moment"
        private const val ETAT_CHIZUK_ID = "chizuk_id"
        private const val ETAT_EN_COURS = "was_running"
        private const val ETAT_ABANDON = "cancelling"
        private const val ETAT_BRAVO_APRES_NOTE = "bravo_apres_note"
    }
}
