package com.myhitbodedut

import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.android.material.materialswitch.MaterialSwitch
import java.time.format.DateTimeFormatter

/**
 * Écran principal (refonte du 13/11) : trois lieux en onglets — Le Jour, Les Livres,
 * Le Chemin — et la barre de départ, visible dans les trois, avec le volet de la séance.
 */
class MainActivity : AppCompatActivity(), NoteDialog.Hote {
    /** Les cartes du moment n'entrent en cascade qu'une fois par ouverture de l'accueil (19/10). */
    private var momentAnime = false


    /** Le texte de relance a déjà été tiré pour la rupture en cours. */
    private var relanceTiree = false

    /**
     * La présentation vient d'être lancée depuis onCreate : le onResume qui suit ne dessine
     * pas l'accueil qu'elle va couvrir, son retour repasse par onResume (examen du 14/11, constat 8).
     */
    private var presentationLancee = false

    /** La position du téléphone reprise au retour sur l'accueil, après un voyage (02/11). */
    private val choixLieu = ChoixLieu(this) {
        refresh()
        applyServiceState()
        ZmanimWidget.refresh(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Une autre version que Classique est choisie (VersionApp, 17/11) : son accueil prend la place.
        if (VersionApp.rediriger(this)) return
        setContentView(R.layout.activity_main)
        ouverture(savedInstanceState == null)
        jaugeCompacte()
        Notifications.ensureChannels(this)
        // Recopie la langue choisie pour les services réveillés seuls (LangueApp).
        LangueApp.retenir(this)
        // Une rotation ou un redimensionnement de fenêtre recrée l'écran :
        // sans cela, le texte de relance serait retiré à chaque fois.
        relanceTiree = savedInstanceState?.getBoolean(ETAT_RELANCE, false) ?: false
        // Une seule fois par création réelle : une recréation (fenêtre
        // redimensionnée) pendant la présentation en ouvrait une seconde.
        if (savedInstanceState == null) showOnboardingOnce()
        wireActions()
        suivreCiel()
        // L'écran d'ouverture choisi dans les réglages (14/10) : Textes s'ouvre sur place, Zmanim par-dessus.
        val ouverture = Store.ouverture(this)
        wireTabs(savedInstanceState?.getInt(ETAT_ONGLET, R.id.nav_today)
            ?: if (ouverture == Store.Ouverture.TEXTES) R.id.nav_texts else R.id.nav_today)
        if (savedInstanceState == null && ouverture == Store.Ouverture.ZMANIM && intent?.getStringExtra(EXTRA_ASK_NOTE) == null) {
            startActivity(Intent(this, ZmanimActivity::class.java))
        }
        // Venu de la notification de fin : la note du jour de la séance, pas
        // du jour où l'on touche la notification. Si le bravo attend encore,
        // c'est lui qui la proposera, après. Lue une seule fois : une
        // rotation ne la rouvre pas.
        if (savedInstanceState == null) {
            intent?.getStringExtra(EXTRA_ASK_NOTE)?.let { date ->
                if (!Store.hasPendingCelebration(this)) NoteDialog.show(this, date)
            }
            intent?.removeExtra(EXTRA_ASK_NOTE)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(ETAT_RELANCE, relanceTiree)
        outState.putInt(ETAT_ONGLET, findViewById<BottomNavigationView>(R.id.bottom_nav).selectedItemId)
    }

    // --- Onglets ------------------------------------------------------------

    /** Revenir des Livres ou du Chemin ramène au Jour avant de quitter l'application. */
    private val retourAujourdhui = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            findViewById<BottomNavigationView>(R.id.bottom_nav).selectedItemId = R.id.nav_today
        }
    }

    /** Le retour referme d'abord le volet de la séance, s'il est ouvert. */
    private val retourVolet = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() = montrerVolet(false)
    }

    /**
     * Les trois lieux changent de panneau sur place : Le Jour, Les Livres,
     * Le Chemin (13/11). Zmanim et Réglages ne sont plus des onglets : la date
     * hébraïque et la roue, en tête du Jour, portent leurs identifiants.
     */
    private fun wireTabs(onglet: Int) {
        onBackPressedDispatcher.addCallback(this, retourAujourdhui)
        // Ajouté après : c'est lui qui répond le premier quand le volet est ouvert.
        onBackPressedDispatcher.addCallback(this, retourVolet)
        val nav = findViewById<BottomNavigationView>(R.id.bottom_nav)
        nav.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_today, R.id.nav_texts, R.id.nav_journal -> {
                    montrerPanneau(item.itemId)
                    // Revenir sur le Jour rejoue les anneaux, comme à l'ouverture.
                    if (item.itemId == R.id.nav_today) {
                        findViewById<AnneauxView>(R.id.week_gauge).rejouer()
                    }
                    true
                }
                else -> false
            }
        }
        // Un onglet retenu par une version d'avant la refonte (Zmanim, Réglages) n'existe plus.
        val connu = onglet.takeIf { nav.menu.findItem(it) != null } ?: R.id.nav_today
        nav.selectedItemId = connu
        montrerPanneau(connu)
    }

    private fun montrerPanneau(onglet: Int) {
        montrerVolet(false)
        findViewById<View>(R.id.main_scroll).visibility = if (onglet == R.id.nav_today) View.VISIBLE else View.GONE
        findViewById<View>(R.id.texts_scroll).visibility = if (onglet == R.id.nav_texts) View.VISIBLE else View.GONE
        findViewById<View>(R.id.chemin_scroll).visibility = if (onglet == R.id.nav_journal) View.VISIBLE else View.GONE
        retourAujourdhui.isEnabled = onglet != R.id.nav_today
        fondBarreDepart()
    }

    // --- Le volet de la séance ------------------------------------------------

    /**
     * Le volet monte au-dessus de la barre de départ, le voile s'assombrit
     * derrière lui ; refermé, il redescend. Sans animations dans le téléphone,
     * il apparaît et disparaît d'un coup.
     */
    private fun montrerVolet(ouvert: Boolean) {
        val volet = findViewById<View>(R.id.depart_volet)
        val voile = findViewById<View>(R.id.depart_voile)
        if (ouvert == (volet.visibility == View.VISIBLE) && ouvert == retourVolet.isEnabled) return
        retourVolet.isEnabled = ouvert
        findViewById<View>(R.id.depart_regler).animate().rotation(if (ouvert) 180f else 0f).setDuration(180L).start()
        volet.animate().cancel()
        voile.animate().cancel()
        if (!android.animation.ValueAnimator.areAnimatorsEnabled()) {
            volet.visibility = if (ouvert) View.VISIBLE else View.GONE
            voile.visibility = volet.visibility
            volet.translationY = 0f
            voile.alpha = 1f
            return
        }
        if (ouvert) {
            voile.alpha = 0f
            voile.visibility = View.VISIBLE
            voile.animate().alpha(1f).setDuration(180L).start()
            volet.visibility = View.VISIBLE
            // La hauteur n'est connue qu'après la première mesure.
            volet.post {
                volet.translationY = volet.height.toFloat()
                volet.animate().translationY(0f).setDuration(220L)
                    .setInterpolator(android.view.animation.DecelerateInterpolator()).start()
            }
        } else {
            voile.animate().alpha(0f).setDuration(160L).withEndAction { voile.visibility = View.GONE }.start()
            volet.animate().translationY(volet.height.toFloat()).setDuration(160L)
                .setInterpolator(android.view.animation.AccelerateInterpolator())
                .withEndAction { volet.visibility = View.GONE; volet.translationY = 0f }.start()
        }
    }

    override fun onResume() {
        super.onResume()
        // Une séance restée inscrite sans service (application tuée) est
        // close ou relancée avant d'afficher quoi que ce soit.
        SessionService.reconcilier(this)
        applyServiceState()
        // Les fichiers de l'accueil se lisent hors du fil principal ; lus, l'accueil se redessine,
        // s'il est encore à l'écran (sinon le prochain onResume le fait).
        Data.prechauffer(this) {
            if (!isDestroyed && lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED)) refresh()
        }
        if (presentationLancee) {
            presentationLancee = false
            return
        }
        // Au retour de la présentation, ou à la première ouverture après la mise à jour : le choix de la version.
        if (Store.hasOnboarded(this) && Store.versionApp(this) == null) {
            startActivity(Intent(this, ChoixVersionActivity::class.java))
            return
        }
        refresh()
        renderPaliers()
        // Chaque retour sur l'accueil : le hassid au centre, les anneaux se
        // remplissent, puis il salue ou fête l'anneau qui vient de se fermer (04/10).
        findViewById<View>(R.id.hero_plate).apply {
            animate().cancel()
            rotationY = 0f
        }
        montrerFace(Plaque.Face.HASSID)
        findViewById<AnneauxView>(R.id.week_gauge).rejouer()
        // La séance s'est close téléphone posé : le bravo attendait ici. Sauf par-dessus
        // une note en cours de frappe : il attend alors sa fermeture (13/11, audit FSEANCE-03).
        if (!NoteDialog.ouverte(this)) CelebrationActivity.showIfPending(this)
        // La vignette d'accueil suit ce que l'écran vient de montrer.
        StreakWidget.refresh(this)
        ZmanimWidget.refresh(this)
        choixLieu.rafraichirSiBesoin()
        findViewById<View>(R.id.hero_plate).postDelayed(veilleCiel, CIEL_MS)
        gardeCiel.reprendre()
    }

    override fun onPause() {
        findViewById<View>(R.id.hero_plate).removeCallbacks(veilleCiel)
        gardeCiel.suspendre()
        super.onPause()
    }

    // --- Le ciel du Jour (étape 3, 14/11 ; sur toute la page depuis le 24/11) ----------------

    /**
     * Le ciel du moment en fond de tout le Jour (CielPage), et non plus dans la plaque du hassid :
     * « s'affiche dans l'arrière-plan de la première page sur toute la page, pas dans le logo dans
     * les anneaux » (le propriétaire, 24/11).
     */
    private val cielPage by lazy { CielPage(resources.displayMetrics.density) }

    /** Ses petites animations (CielVivant) : seulement quand le téléphone les permet et que l'accueil est devant. */
    private val gardeCiel = GardeCiel(this) { cielPage.anime = it }

    /** L'accueil resté ouvert passe de l'aube au jour, du coucher à la nuit, sans attendre un retour. */
    private val veilleCiel = object : Runnable {
        override fun run() {
            renderCiel()
            findViewById<View>(R.id.hero_plate).postDelayed(this, CIEL_MS)
        }
    }

    /**
     * Le ciel du moment (CielDuJour) : en fond de tout le Jour (CielPage, teintes adaptées au
     * thème par TeintesCiel pour que chaque texte reste lisible), sous la barre de départ quand
     * le Jour est devant, et devant la date hébraïque. Avec la palette « Contraste élevé », pas
     * de ciel : on l'a choisie pour le plus fort contraste, le papier uni reste.
     */
    private fun renderCiel() {
        val phase = CielDuJour.maintenant(this)
        val scroll = findViewById<android.widget.ScrollView>(R.id.main_scroll)
        if (Store.fond(this) == Apparence.Fond.CONTRASTE) {
            scroll.background = null
        } else {
            val sombre = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                android.content.res.Configuration.UI_MODE_NIGHT_YES
            cielPage.regler(phase, TeintesCiel.pourPage(phase, sombre, encresDuJour(), Apparence.couleur(this, R.color.paper)), sombre)
            if (scroll.background !== cielPage) scroll.background = cielPage
        }
        fondBarreDepart()
        findViewById<TextView>(R.id.nav_zmanim).setCompoundDrawablesRelativeWithIntrinsicBounds(CielDuJour.icone(phase), 0, R.drawable.ic_chevron, 0)
    }

    /**
     * Les encres posées sur le ciel du Jour et le contraste qu'elles y gardent, ceux de
     * PaletteTest : le titre (7:1), le texte secondaire, l'accent (palier, boutons-liens) et les
     * légendes des anneaux (4,5:1).
     */
    private fun encresDuJour(): List<TeintesCiel.Encre> = listOf(
        TeintesCiel.Encre(Apparence.couleur(this, R.color.ink), 7.0),
        TeintesCiel.Encre(Apparence.couleur(this, R.color.muted), 4.5),
        TeintesCiel.Encre(Apparence.couleur(this, R.color.brand), 4.5),
        TeintesCiel.Encre(getColor(R.color.ring_week_text), 4.5),
        TeintesCiel.Encre(getColor(R.color.ring_streak_text), 4.5),
    )

    /** La barre de départ prend la couleur du bas du ciel quand le Jour est devant ; le papier ailleurs. */
    private fun fondBarreDepart() {
        val jour = findViewById<View>(R.id.main_scroll).visibility == View.VISIBLE
        val ciel = findViewById<View>(R.id.main_scroll).background === cielPage
        findViewById<View>(R.id.depart_barre).setBackgroundColor(
            cielPage.teintes?.bas?.takeIf { jour && ciel } ?: Apparence.couleur(this, R.color.paper))
    }

    /**
     * Le ciel monte avec la page, et sait où sont les anneaux et les textes : l'astre se pose à
     * côté des anneaux, aucune étoile sous un texte. Revu à chaque mise en page du Jour.
     */
    private fun suivreCiel() {
        val scroll = findViewById<android.widget.ScrollView>(R.id.main_scroll)
        scroll.setOnScrollChangeListener { _, _, y, _, _ -> cielPage.defilement = y }
        scroll.viewTreeObserver.addOnGlobalLayoutListener { if (scroll.isShown) placerCiel(scroll) }
    }

    private fun placerCiel(scroll: android.widget.ScrollView) {
        val contenu = scroll.getChildAt(0) as? android.view.ViewGroup ?: return
        val zones = ArrayList<PlanCiel.Zone>()
        val cadre = android.graphics.Rect()
        fun zone(v: View): PlanCiel.Zone {
            cadre.set(0, 0, v.width, v.height)
            contenu.offsetDescendantRectToMyCoords(v, cadre)
            return PlanCiel.Zone((cadre.left + contenu.left).toFloat(), (cadre.top + contenu.top).toFloat(),
                (cadre.right + contenu.left).toFloat(), (cadre.bottom + contenu.top).toFloat())
        }
        val anneaux = findViewById<View>(R.id.week_gauge)
        fun parcourir(g: android.view.ViewGroup) {
            for (i in 0 until g.childCount) {
                val v = g.getChildAt(i)
                if (v.visibility != View.VISIBLE || v === anneaux) continue
                when {
                    v is android.view.ViewGroup && v.background == null -> parcourir(v)
                    // Un texte, une icône, une carte, une case de la semaine : ce qu'on lit ou touche.
                    v is TextView || v is ImageView || v.background != null -> zones += zone(v)
                    v is android.view.ViewGroup -> parcourir(v)
                }
            }
        }
        parcourir(contenu)
        cielPage.placer((anneaux.parent as? View)?.let(::zone), zones)
    }

    /**
     * La présentation, une fois par version d'elle-même, installation
     * existante comprise : c'est là seulement qu'on choisit צדיק / צדקת.
     * Elle se passe d'un geste, et on la revoit depuis les réglages.
     */
    private fun showOnboardingOnce() {
        if (Store.hasOnboarded(this)) return
        presentationLancee = true
        startActivity(Intent(this, OnboardingActivity::class.java))
    }

    // --- Actions ------------------------------------------------------------

    private fun wireActions() {
        // Un seul geste : les puces au-dessus portent déjà la durée, le sujet
        // et la musique. L'écran de séance redemandait la durée, et il
        // fallait toucher « Commencer » une seconde fois (revue du 29/09).
        findViewById<Button>(R.id.start_session).setOnClickListener {
            montrerVolet(false)
            startActivity(
                Intent(this, SessionActivity::class.java)
                    .putExtra(SessionActivity.EXTRA_START_NOW, !Store.isSessionRunning(this))
            )
        }
        // L'écran de préparation sans EXTRA_START_NOW : durées, « Sans durée », Parler / Écrire / Prier / Une question.
        findViewById<Button>(R.id.start_prepare).setOnClickListener {
            startActivity(Intent(this, SessionActivity::class.java))
        }
        findViewById<Button>(R.id.today_offline).setOnClickListener { declarerHorsTelephone() }
        // La barre de départ : sa flèche ouvre et referme le volet ; le voile le referme.
        findViewById<View>(R.id.depart_regler).setOnClickListener {
            montrerVolet(findViewById<View>(R.id.depart_volet).visibility != View.VISIBLE)
        }
        findViewById<View>(R.id.depart_voile).setOnClickListener { montrerVolet(false) }
        // En tête du Jour : la date hébraïque ouvre le ciel (zmanim, calendrier, hilloulot, boussole), la roue les réglages.
        findViewById<View>(R.id.nav_zmanim).setOnClickListener { startActivity(Intent(this, ZmanimActivity::class.java)) }
        findViewById<View>(R.id.nav_settings).setOnClickListener { startActivity(Intent(this, SettingsActivity::class.java)) }
        // Le Chemin : le journal, le parcours, les trophées.
        findViewById<View>(R.id.journal_button).setOnClickListener { startActivity(Intent(this, JournalActivity::class.java)) }
        findViewById<View>(R.id.trophees_paliers).setOnClickListener { startActivity(Intent(this, PaliersActivity::class.java)) }
        findViewById<View>(R.id.parcours_button).setOnClickListener { startActivity(Intent(this, ParcoursActivity::class.java)) }
        findViewById<View>(R.id.start_duration).setOnClickListener {
            pickDuration()
        }
        findViewById<View>(R.id.start_theme).setOnClickListener {
            pickTheme()
        }
        findViewById<View>(R.id.start_focus).setOnClickListener {
            // La barrière du matin. En édition légère elle n'existe pas,
            // et la ligne est retirée plutôt que rendue inopérante. Elle ne bascule que si le
            // mode peut agir (13/11, FBARRIERE-08) : sinon elle mène à la carte d'état.
            when (GateRule.geste(GateStatus.faits(this))) {
                GesteBarriere.REGLER -> startActivity(
                    Intent(this, SettingsActivity::class.java)
                        .putExtra(SettingsActivity.EXTRA_CARTE_BARRIERE, true)
                )
                GesteBarriere.RELANCER -> {
                    GateService.start(this)
                    refresh()
                }
                GesteBarriere.BASCULER -> {
                    Store.setEnabled(this, !Store.isEnabled(this))
                    applyServiceState()
                    refresh()
                }
            }
        }
        findViewById<View>(R.id.music_button).setOnClickListener {
            startActivity(Intent(this, MusicActivity::class.java))
        }
        findViewById<View>(R.id.chizuk_button).setOnClickListener {
            startActivity(Intent(this, ChizukActivity::class.java))
        }
        findViewById<View>(R.id.tips_button).setOnClickListener {
            startActivity(Intent(this, TipsActivity::class.java))
        }
        findViewById<View>(R.id.reminders_button).setOnClickListener {
            startActivity(Intent(this, RemindersActivity::class.java))
        }
        findViewById<View>(R.id.recherche_button).setOnClickListener {
            startActivity(Intent(this, RechercheActivity::class.java))
        }
        findViewById<View>(R.id.tikkun_button).setOnClickListener {
            startActivity(Intent(this, TikkunFlowActivity::class.java))
        }
        findViewById<View>(R.id.siddur_button).setOnClickListener {
            startActivity(Intent(this, SiddurActivity::class.java))
        }
        findViewById<View>(R.id.tehilim_button).setOnClickListener {
            startActivity(Intent(this, TehilimActivity::class.java))
        }
        findViewById<View>(R.id.tefilot_button).setOnClickListener {
            startActivity(Intent(this, TefilotActivity::class.java))
        }
        findViewById<View>(R.id.livres_button).setOnClickListener {
            startActivity(Intent(this, LibraryActivity::class.java).putExtra(LibraryActivity.EXTRA_LIVRES, true))
        }
        findViewById<View>(R.id.library_button).setOnClickListener {
            startActivity(Intent(this, LibraryActivity::class.java))
        }
        findViewById<View>(R.id.halakha_button).setOnClickListener {
            startActivity(Intent(this, HalakhaActivity::class.java))
        }

        // L'écran de relecture n'existe que pour lever les relu=false des
        // données : il n'a rien à faire dans une version publiée. Sa classe
        // n'est compilée qu'en debug (src/debug) : on la nomme par son nom. Pas dans verifR8
        // (14/11) : débogable mais sans src/debug, le bouton y menait à une classe absente, et il
        // se voyait sur les captures de la fiche Play.
        findViewById<View>(R.id.proofread_button).apply {
            visibility = if (BuildConfig.DEBUG && BuildConfig.BUILD_TYPE == "debug") View.VISIBLE else View.GONE
            setOnClickListener {
                startActivity(Intent().setClassName(this@MainActivity, "com.myhitbodedut.ProofreadActivity"))
            }
        }
        // La plaque ronde coupe l'illustration à son bord, au creux des anneaux.
        findViewById<View>(R.id.hero_plate).apply {
            clipToOutline = true
            setOnClickListener { toucherPlaque() }
        }
        findViewById<Button>(R.id.today_note).setOnClickListener {
            NoteDialog.show(this, Store.today())
        }
    }

    /** La note enregistrée se lit aussitôt sur l'accueil (NoteDialog.Hote). */
    override fun noteEnregistree(date: String) {
        refresh()
    }

    /** Le bravo qui attendait la fermeture de la note s'ouvre, sans la reproposer. */
    override fun noteFermee(date: String) {
        CelebrationActivity.showIfPending(this, sansNote = true)
    }

    /**
     * Une hitbodedout faite sans le téléphone : aujourd'hui, ou hier si hier
     * n'est pas encore fait, puis sa durée. Elle est inscrite comme les
     * autres, et le bravo suit si c'est aujourd'hui.
     */
    private fun declarerHorsTelephone() {
        // Les deux dates sont figées au geste : la fenêtre peut rester
        // ouverte à cheval sur minuit.
        val aujourdhui = Store.today()
        val hier = Store.parse(aujourdhui).minusDays(1).toString()
        val hierOuvert = hierOuvert()
        // Hier encore ouvert : toujours demander le jour, aujourd'hui fait ou non (TFRUX-07) ;
        // sinon le temps d'une seconde séance de la journée partait sur hier, sans un mot.
        if (hierOuvert) {
            AlertDialog.Builder(this)
                .setTitle(R.string.offline_which_day)
                .setItems(arrayOf(getString(R.string.offline_today), getString(R.string.offline_yesterday))) { _, i ->
                    choisirDureeHorsTelephone(if (i == 0) aujourdhui else hier, aujourdhui)
                }
                .show()
        } else {
            choisirDureeHorsTelephone(aujourdhui, aujourdhui)
        }
    }

    /** Hier n'est ni fait ni exempté : on peut encore l'inscrire. */
    private fun hierOuvert(): Boolean {
        val hier = Store.parse(Store.today()).minusDays(1)
        return !Store.isDone(this, hier.toString()) && !Store.isExempt(this, hier)
    }

    private fun choisirDureeHorsTelephone(date: String, aujourdhui: String) {
        val estAujourdhui = date == aujourdhui
        DureeSeance.choisir(this, if (estAujourdhui) R.string.offline_how_long_today else R.string.offline_how_long_yesterday) { minutes ->
            val dejaFait = Store.isDone(this, date)
            // Sans sujet : celui des puces est celui de la PROCHAINE séance.
            Store.addSession(this, minutes, theme = null, date = date)
            // Le jour est nommé : hier ne reçoit plus le temps en silence.
            android.widget.Toast.makeText(this,
                getString(if (estAujourdhui) R.string.offline_added_today else R.string.offline_added_yesterday,
                    Store.formatDuration(this, minutes)), android.widget.Toast.LENGTH_SHORT).show()
            // L'application est ouverte : la fête se fait à l'écran, pas par une notification (comme AjoutTemps).
            Celebrations.marquerNotifies(this)
            // Le bravo ne fête que la journée qui vient d'être faite, pas un temps ajouté à une journée déjà faite.
            if (estAujourdhui && !dejaFait) Store.setPendingCelebration(this, minutes, date)
            refresh()
            StreakWidget.refresh(this)
            CelebrationActivity.showIfPending(this)
        }
    }

    /**
     * La durée de la prochaine séance. Le même choix que dans les
     * réglages : c'est la même valeur, atteinte de plus près.
     */
    private fun pickDuration() {
        DureeSeance.choisir(this, R.string.settings_target) {
            Store.setTargetMinutes(this, it)
            refresh()
        }
    }

    /** Le sujet de la prochaine séance. « Aucun » en tête : il est facultatif. */
    private fun pickTheme() {
        val sujets = Theme.values()
        val libelles = (listOf(getString(R.string.session_theme_none_short)) +
            sujets.map { getString(it.titre) }).toTypedArray()
        AlertDialog.Builder(this)
            .setTitle(R.string.session_theme_title)
            .setItems(libelles) { _, index ->
                Store.setSessionTheme(this, if (index == 0) null else sujets[index - 1])
                refresh()
            }
            .show()
    }

    // --- Rendu --------------------------------------------------------------

    private fun refresh() {
        renderToday()
        renderWeek()
        // Ce qui suit lit le siddour, la bibliothèque et le Tikoun : seulement une fois lus hors
        // du fil principal (Data.prechauffer, examen du 14/11, constat 8), qui rappelle refresh().
        if (Data.pret) renderDonnees()
        renderGauge()
        renderSwitches()
        renderMusic()
        renderRelance()
        renderTehilim()
        renderReminders()
        renderStartCard()
        renderEntete()
        renderCiel()
        renderChemin()
    }

    /** Les cartes de l'accueil qui lisent les fichiers de données. */
    private fun renderDonnees() {
        // Reprendre la lecture et les favoris (14/10), en tête de la Bibliothèque.
        findViewById<LinearLayout>(R.id.reprise_favoris).apply {
            removeAllViews()
            runCatching { RepriseFavoris.lignes(this@MainActivity) }.getOrDefault(emptyList()).forEach { addView(it) }
        }
        // L'accueil selon l'heure (14/10).
        findViewById<LinearLayout>(R.id.accueil_moment).apply {
            removeAllViews()
            // Un changement dans la tefila, annoncé quelques jours avant (16/10).
            runCatching { RappelsTefilaVue.cartes(this@MainActivity) }.getOrDefault(emptyList()).forEach { addView(it) }
            runCatching { AccueilMoment.cartes(this@MainActivity) }.getOrDefault(emptyList()).forEach { addView(it) }
            // La source du jour (19/10) : la même toute la journée, distincte du 'hizouk.
            runCatching { SourceDuJour.carte(this@MainActivity) }.getOrNull()?.let { addView(it) }
            // Les effets (19/10) : à la première apparition de l'accueil, les cartes entrent en cascade.
            if (!momentAnime) { momentAnime = true; Effets.enfants(this, depart = 450) }
        }
        renderTikkun()
    }

    /**
     * En tête du Jour : la date hébraïque, qui change à la sortie des étoiles
     * du lieu comme sur la vignette des zmanim (minuit, sans lieu).
     */
    private fun renderEntete() {
        val date = runCatching {
            val lieu = Store.lieuZmanim(this)
            val fuseau = lieu?.fuseau?.let { runCatching { java.time.ZoneId.of(it) }.getOrNull() } ?: java.time.ZoneId.systemDefault()
            val maintenant = java.time.ZonedDateTime.now(fuseau)
            val tset = lieu?.let { l -> Zmanim.jour(l, maintenant.toLocalDate(), Store.siddurNusah(this).cle).firstOrNull { it.cle == "tset" }?.local }
            CalendrierJuif.jour(ZmanimVignette.jourHebreuAffiche(maintenant, tset), Store.inIsrael(this)).dateHebraique
        }.getOrNull()
        findViewById<TextView>(R.id.nav_zmanim).apply {
            text = date ?: getString(R.string.nav_zmanim)
            contentDescription = getString(R.string.jour_ciel, date ?: getString(R.string.nav_zmanim))
        }
    }

    /**
     * Le Chemin : la série, la meilleure, le total ; les minutes du mois en
     * barres, comme en tête du journal ; et l'état du journal et des trophées.
     */
    private fun renderChemin() {
        val total = Store.totalMinutes(this)
        val faites = Store.joursFaits(this).size
        val langue = resources.configuration.locales[0]
        findViewById<TextView>(R.id.chemin_serie).text = String.format(langue, "%d", Store.streak(this))
        findViewById<TextView>(R.id.chemin_meilleure).text = String.format(langue, "%d", Store.meilleureSerie(this))
        findViewById<TextView>(R.id.chemin_total).text = Store.formatDuration(this, total)
        findViewById<TextView>(R.id.journal_state).text =
            resources.getQuantityString(R.plurals.journal_summary, faites, faites, Store.formatDuration(this, total))
        val pratique = Store.pratique(this)
        val prochain = Trophees.prochain(pratique)
        findViewById<TextView>(R.id.trophees_state).text =
            if (prochain == null) getString(R.string.trophees_tous) else getString(R.string.accueil_prochain_trophee,
                TropheesVue.description(this, prochain.famille, prochain.seuil),
                prochain.seuil - Trophees.valeur(pratique, prochain.famille).coerceAtMost(prochain.seuil))
        val mois = java.time.YearMonth.now()
        findViewById<LinearLayout>(R.id.chemin_mois).apply {
            removeAllViews()
            val nom = mois.format(DateTimeFormatter.ofPattern("LLLL yyyy", langue))
            addView(VueJour.texte(context, nom.replaceFirstChar { it.titlecase(langue) }, 13f, R.color.muted))
            addView(JournalPlus.Graphique(context, JournalPlus.minutesDuMois(Store.days(context), mois), java.time.LocalDate.now().dayOfMonth,
                Apparence.couleur(context, R.color.brand)).apply {
                contentDescription = getString(R.string.journal_graphique, nom)
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                    .apply { topMargin = (8 * resources.displayMetrics.density).toInt() }
            })
        }
    }

    /**
     * La carte de départ : ce avec quoi on entre dans la séance. Rien n'y
     * est obligatoire — la durée a sa valeur habituelle, le sujet peut
     * rester « aucun », la musique et la concentration peuvent être
     * éteintes.
     */
    private fun renderStartCard() {
        findViewById<TextView>(R.id.start_duration_value).text =
            Store.formatDuration(this, Store.targetMinutes(this))

        val sujet = Store.sessionTheme(this)
        findViewById<TextView>(R.id.start_theme_value).setText(
            sujet?.titre ?: R.string.session_theme_none_short
        )

        val focus = findViewById<View>(R.id.start_focus)
        focus.visibility = if (BuildConfig.HAS_GATE) View.VISIBLE else View.GONE
        if (BuildConfig.HAS_GATE) {
            findViewById<TextView>(R.id.start_focus_value).setText(
                GateStatus.pastilleDe(GateStatus.evaluate(this))
            )
        }
    }

    /**
     * « שלום Avraham » : l'accueil se tait s'il n'a personne à nommer, et
     * l'état du jour prend alors la place du titre.
     */
    private fun renderGreeting() {
        val prenom = Store.firstName(this)
        findViewById<TextView>(R.id.hero_greeting).apply {
            visibility = if (prenom.isBlank()) View.GONE else View.VISIBLE
            // Bonjour le matin, bonsoir le soir (Salutation).
            if (prenom.isNotBlank()) {
                text = getString(Salutation.chaine(java.time.LocalTime.now().hour), prenom)
            }
        }
        findViewById<TextView>(R.id.status_title).apply {
            val titre = prenom.isBlank()
            textSize = if (titre) 20f else 15f
            // Titre : la police système en gras ; ligne d'état : Varela Round, comme sous le titre.
            typeface = if (titre) Typeface.DEFAULT_BOLD else androidx.core.content.res.ResourcesCompat.getFont(this@MainActivity, R.font.varela_round)
            setTextColor(Apparence.couleur(this@MainActivity, if (titre) R.color.ink else R.color.muted))
        }
    }

    /**
     * Les trois anneaux autour du hassid : le jour (minutes sur l'objectif),
     * la semaine (jours faits sur jours dus), la série (jours d'affilée sur
     * le prochain palier). Sous eux, la semaine en toutes lettres, ou le
     * détail de l'anneau qu'on a touché.
     */
    private fun renderGauge() {
        val semaine = JaugeSemaine.progression(Store.currentWeek(this))
        val etat = Store.anneaux(this)
        val anneaux = findViewById<AnneauxView>(R.id.week_gauge)
        anneaux.montrer(etat)
        // La semaine et la série s'accordent au nombre (13/11, TFRLANGUE-01) : « 1 jour sur 7 ».
        anneaux.contentDescription = getString(
            R.string.rings_description,
            Store.formatDuration(this, etat.jour.fait), Store.formatDuration(this, etat.jour.objectif),
            resources.getQuantityString(R.plurals.ring_week_detail, semaine.faits, semaine.faits, semaine.dus),
            resources.getQuantityString(R.plurals.ring_streak_detail, etat.serie.fait, etat.serie.fait, etat.serie.objectif)
        )
        anneaux.surChoix = { quel ->
            renderLegende(quel)
            // Toucher un anneau montre sa face au centre ; le relâcher ramène le hassid.
            if (quel != face.anneau) tournerPlaque(if (quel == null) Plaque.Face.HASSID else Plaque.pour(quel))
        }
        anneaux.surRempli = { apresRemplissage() }
        renderLegende(anneaux.misEnAvant)
    }

    /**
     * La fin d'un remplissage. Un anneau qui vient de se fermer est fêté
     * (les anneaux battent, le hassid saute trois fois), une seule fois par
     * jour, par semaine ou par palier ; sinon le hassid salue d'un saut.
     */
    private fun apresRemplissage() {
        val etat = Store.anneaux(this)
        val aujourdhui = java.time.LocalDate.now()
        val nouveaux = Anneaux.aFeter(etat, aujourdhui, Store.anneauxFetes(this))
        Store.setAnneauxFetes(this, Anneaux.marques(etat, aujourdhui))
        if (nouveaux.isEmpty()) {
            if (face == Plaque.Face.HASSID) sautiller(1)
        } else {
            // L'anneau fermé passe devant, et sa face s'affiche au centre le
            // temps de la fête ; le hassid revient ensuite en sautant.
            findViewById<AnneauxView>(R.id.week_gauge).apply {
                performHapticFeedback(
                    if (android.os.Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM
                    else HapticFeedbackConstants.LONG_PRESS
                )
                feter(nouveaux.first())
            }
        }
    }

    // --- Le centre des anneaux (Plaque) ---------------------------------------

    /** La face montrée au centre des anneaux. */
    private var face = Plaque.Face.HASSID

    private val retourHassid = Runnable { tournerPlaque(Plaque.Face.HASSID) }

    /** Un toucher au centre : la face suivante, en tournant, avec un petit retour au doigt. */
    private fun toucherPlaque() {
        findViewById<View>(R.id.hero_plate).performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
        tournerPlaque(Plaque.suivante(face))
    }

    /**
     * La plaque tourne sur elle-même comme une pièce : à mi-tour, la face
     * change ; le chiffre monte ensuite depuis zéro. Sans animations dans le
     * téléphone, la face change d'un coup.
     */
    private fun tournerPlaque(vers: Plaque.Face) {
        val plaque = findViewById<View>(R.id.hero_plate)
        plaque.removeCallbacks(retourHassid)
        if (vers != Plaque.Face.HASSID) plaque.postDelayed(retourHassid, Plaque.RETOUR_MS)
        if (vers == face) return
        plaque.animate().cancel()
        if (!android.animation.ValueAnimator.areAnimatorsEnabled()) {
            plaque.rotationY = 0f
            montrerFace(vers)
            return
        }
        plaque.cameraDistance = 9000f * resources.displayMetrics.density
        plaque.animate().rotationY(90f).setDuration(140L)
            .setInterpolator(android.view.animation.AccelerateInterpolator())
            .withEndAction {
                montrerFace(vers)
                plaque.rotationY = -90f
                plaque.animate().rotationY(0f).setDuration(200L)
                    .setInterpolator(android.view.animation.DecelerateInterpolator())
                    .withEndAction { if (vers == Plaque.Face.HASSID) sautiller(1) }
                    .start()
            }
            .start()
    }

    /** Remplit la plaque avec [vers], et met en avant l'anneau dont elle parle. */
    private fun montrerFace(vers: Plaque.Face) {
        face = vers
        val hassid = findViewById<View>(R.id.hero_character)
        val chiffres = findViewById<View>(R.id.hero_face)
        val plaque = findViewById<View>(R.id.hero_plate)
        if (vers == Plaque.Face.HASSID) {
            plaque.removeCallbacks(retourHassid)
            hassid.visibility = View.VISIBLE
            chiffres.visibility = View.GONE
            plaque.contentDescription = getString(R.string.rings_character_hint)
        } else {
            hassid.visibility = View.INVISIBLE
            chiffres.visibility = View.VISIBLE
            remplirFace(vers)
        }
        // Le disque clair, sous le hassid comme sous les chiffres : le ciel est passé derrière toute
        // la page (24/11). Clair de nuit aussi, les illustrations sont dessinées pour un fond clair.
        plaque.setBackgroundResource(R.drawable.bg_gauge_plate)
        findViewById<AnneauxView>(R.id.week_gauge).mettreEnAvant(vers.anneau)
    }

    /** Le chiffre de la face et ce qu'il compte ; le chiffre monte depuis zéro. */
    private fun remplirFace(vers: Plaque.Face) {
        val etat = Store.anneaux(this)
        val valeur = findViewById<TextView>(R.id.hero_face_value)
        val legende = findViewById<TextView>(R.id.hero_face_caption)
        val duree: (Int) -> String = { Store.formatDuration(this, it) }
        val (cible, texte, legendeTexte) = when (vers) {
            Plaque.Face.JOUR -> Triple(etat.jour.fait, duree,
                getString(R.string.plaque_jour, duree(etat.jour.objectif)))
            Plaque.Face.SEMAINE -> Triple(etat.semaine.fait,
                { n: Int -> getString(R.string.plaque_semaine_valeur, n, etat.semaine.objectif) },
                getString(R.string.plaque_semaine))
            Plaque.Face.SERIE -> Triple(etat.serie.fait, { n: Int -> n.toString() },
                resources.getQuantityString(R.plurals.plaque_serie, etat.serie.fait, etat.serie.fait, etat.serie.objectif))
            Plaque.Face.MEILLEURE -> Triple(Store.meilleureSerie(this), { n: Int -> n.toString() },
                getString(R.string.plaque_meilleure))
            Plaque.Face.TOTAL -> Triple(Store.totalMinutes(this), duree, getString(R.string.plaque_total))
            Plaque.Face.JOURS -> {
                val jours = Store.joursFaits(this).size
                Triple(jours, { n: Int -> n.toString() },
                    resources.getQuantityString(R.plurals.plaque_jours, jours, jours))
            }
            Plaque.Face.MOYENNE -> Triple(
                Plaque.moyenne(Store.totalMinutes(this), Store.joursFaits(this).size), duree,
                getString(R.string.plaque_moyenne))
            Plaque.Face.HASSID -> return
        }
        legende.text = legendeTexte
        valeur.setTextColor(Apparence.couleur(this, when (vers.anneau) {
            // La plaque reste claire la nuit : des encres fixes, pas celles qui s'éclaircissent (FACCUEIL-02).
            Anneaux.Quel.JOUR -> R.color.on_plate
            Anneaux.Quel.SEMAINE -> R.color.ring_week_on_plate
            Anneaux.Quel.SERIE -> R.color.ring_streak_on_plate
            null -> R.color.on_plate_ink
        }))
        findViewById<View>(R.id.hero_plate).contentDescription = listOf(texte(cible), legendeTexte).joinToString(" ")
        compteurFace?.cancel()
        if (cible <= 0 || !android.animation.ValueAnimator.areAnimatorsEnabled()) {
            valeur.text = texte(cible)
            return
        }
        valeur.text = texte(0)
        compteurFace = android.animation.ValueAnimator.ofInt(0, cible).apply {
            duration = 650L
            interpolator = android.view.animation.DecelerateInterpolator()
            addUpdateListener { valeur.text = texte(it.animatedValue as Int) }
            start()
        }
    }

    /**
     * Le palier le plus proche, sous les anneaux (11/10), et la fête d'un
     * palier atteint depuis la dernière visite : une fois par palier (et par
     * jour, semaine ou mois pour les paliers de durée).
     */
    private fun renderPaliers() {
        // L'accueil montre le grade et le prochain trophée (16/10, points 3 et 4) : les paliers
        // ont rejoint la ligne des trophées, et deux objectifs côte à côte se disputaient l'attention.
        val p = Store.pratique(this)
        val grade = Trophees.grade(Trophees.gagnes(p).size)
        val prochain = Trophees.prochain(p)
        findViewById<TextView>(R.id.paliers_line).apply {
            val texte = if (prochain == null) getString(R.string.trophees_tous) else getString(R.string.accueil_prochain_trophee,
                TropheesVue.description(context, prochain.famille, prochain.seuil),
                prochain.seuil - Trophees.valeur(p, prochain.famille).coerceAtMost(prochain.seuil))
            text = "$texte  ›"
            val taille = (26 * resources.displayMetrics.density).toInt()
            setCompoundDrawablesRelative(TropheeDessin(context, Trophees.Forme.MEDAILLE, grade, "★").apply { setBounds(0, 0, taille, taille) }, null, null, null)
            compoundDrawablePadding = (8 * resources.displayMetrics.density).toInt()
            contentDescription = getString(R.string.grade_titre, TropheesVue.metal(context, grade)) + ". " + texte
            setOnClickListener { startActivity(Intent(this@MainActivity, PaliersActivity::class.java)) }
        }
        // Un palier ou un trophée neuf : des étincelles du grade (16/10, animation E).
        Celebrations.ecran(this)
        bilanDeLaSemaine()
    }

    /** Le bilan de la semaine écoulée (16/10, point 7) : à la première ouverture de la semaine, une fois. */
    private fun bilanDeLaSemaine() {
        // Rien à calculer quand le bilan de cette semaine a déjà été montré.
        val debut = BilanSemaine.debutSemaine(java.time.LocalDate.now()).minusDays(7)
        if (Store.bilanVu(this) == debut.toString()) return
        val minutes = Store.bilan(this).minutes
        val b = BilanSemaine.precedente(java.time.LocalDate.now(), minutes, Store.datesTrophees(this))
        if (b == null) { Store.setBilanVu(this, debut.toString()); return }
        Store.setBilanVu(this, b.debut.toString())
        val d = resources.displayMetrics.density
        val vue = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding((24 * d).toInt(), (8 * d).toInt(), (24 * d).toInt(), 0)
            addView(VueJour.texte(context, getString(R.string.bilan_minutes, Store.formatDuration(context, b.minutes),
                resources.getQuantityString(R.plurals.palier_n_jours, b.jours, b.jours)), 17f, R.color.ink, gras = true))
            if (b.ecart > 0 && b.precedente > 0) addView(VueJour.texte(context, getString(R.string.bilan_plus, Store.formatDuration(context, b.ecart)), 15f, R.color.muted, haut = 6))
            if (b.record) addView(VueJour.texte(context, getString(R.string.bilan_record), 15f, R.color.brand, gras = true, haut = 6))
            if (b.trophees.isNotEmpty()) {
                addView(VueJour.texte(context, getString(R.string.bilan_trophees), 15f, R.color.muted, haut = 10))
                // La pratique lue une fois, pas une fois par niveau (04/11).
                val pratique = Store.pratique(context)
                val faits = Trophees.chemin.filter { Trophees.gagne(pratique, it) }
                addView(android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.HORIZONTAL
                    b.trophees.take(6).forEach { t ->
                        addView(View(context).apply {
                            background = TropheeDessin(context, t.famille.forme, Trophees.grade(faits.indexOf(t) + 1), t.famille.icone)
                            contentDescription = TropheesVue.description(context, t.famille, t.seuil)
                        }, android.widget.LinearLayout.LayoutParams((40 * d).toInt(), (40 * d).toInt()).apply { marginEnd = (6 * d).toInt() })
                    }
                })
            }
        }
        com.google.android.material.dialog.MaterialAlertDialogBuilder(this).setTitle(R.string.bilan_titre).setView(vue)
            .setPositiveButton(R.string.celebration_continue, null).show()
    }

    /** Le compteur qui fait monter le chiffre de la face ; arrêté quand la face change. */
    private var compteurFace: android.animation.ValueAnimator? = null

    /** La légende sous les anneaux : la semaine, ou l'anneau mis en avant. */
    private fun renderLegende(quel: Anneaux.Quel?) {
        val etat = Store.anneaux(this)
        val semaine = etat.semaine
        val legende = findViewById<TextView>(R.id.week_gauge_label)
        legende.text = when (quel) {
            Anneaux.Quel.JOUR -> getString(
                if (etat.jour.atteint) R.string.ring_day_reached else R.string.ring_day_detail,
                Store.formatDuration(this, etat.jour.fait), Store.formatDuration(this, etat.jour.objectif)
            )
            Anneaux.Quel.SERIE -> if (etat.serie.atteint) getString(R.string.ring_streak_reached, etat.serie.fait, etat.serie.objectif)
                else resources.getQuantityString(R.plurals.ring_streak_detail, etat.serie.fait, etat.serie.fait, etat.serie.objectif)
            else -> resources.getQuantityString(R.plurals.week_gauge, semaine.fait, semaine.fait, semaine.objectif)
        }
        legende.setTextColor(
            Apparence.couleur(
                this,
                when (quel) {
                    Anneaux.Quel.JOUR -> R.color.brand
                    Anneaux.Quel.SEMAINE -> R.color.ring_week_text
                    Anneaux.Quel.SERIE -> R.color.ring_streak_text
                    null -> R.color.muted
                }
            )
        )
    }

    /**
     * Le petit saut du hassid, [fois] de suite. Rien si les animations sont
     * coupées dans le téléphone (Options pour les développeurs ou
     * Accessibilité → Supprimer les animations).
     */
    private fun sautiller(fois: Int) {
        if (fois <= 0 || !android.animation.ValueAnimator.areAnimatorsEnabled()) return
        val hassid = findViewById<ImageView>(R.id.hero_character)
        val saut = 10f * resources.displayMetrics.density
        hassid.animate().cancel()
        hassid.pivotX = hassid.width / 2f
        hassid.pivotY = hassid.height.toFloat()
        hassid.animate()
            .translationY(-saut).scaleX(1.04f).scaleY(1.06f).rotation(-3f)
            .setDuration(220L)
            .setInterpolator(android.view.animation.DecelerateInterpolator())
            .withEndAction {
                hassid.animate()
                    .translationY(0f).scaleX(1f).scaleY(1f).rotation(3f)
                    .setDuration(260L)
                    .setInterpolator(android.view.animation.BounceInterpolator())
                    .withEndAction {
                        hassid.animate().rotation(0f).setDuration(160L)
                            .withEndAction { sautiller(fois - 1) }
                            .start()
                    }
                    .start()
            }
            .start()
    }

    /** L'état de la musique, sur la carte qui lui est consacrée. */
    private fun renderMusic() {
        val track = MusicLibrary.selected(this)
        findViewById<TextView>(R.id.music_state).text = when {
            !Store.musicEnabled(this) -> getString(R.string.music_off_summary)
            track == null -> getString(R.string.music_none_summary)
            Store.musicShuffle(this) -> getString(R.string.music_shuffle_summary, Store.musicVolume(this))
            else -> getString(R.string.music_on_summary, track.title, Store.musicVolume(this))
        }
    }

    /** L'état des rappels, lisible sans ouvrir leur écran. */
    private fun renderReminders() {
        val heures = Store.reminderTimes(this)
        findViewById<TextView>(R.id.reminders_state).text = when {
            !Store.reminderEnabled(this) -> getString(R.string.reminders_off)
            heures.isEmpty() -> getString(R.string.reminders_none)
            else -> resources.getQuantityString(
                R.plurals.reminders_count, heures.size, heures.size
            )
        }
    }

    /** Ou en est le Tikoun du jour, sans avoir a ouvrir la section. */
    /** La ligne Tehilim dit la portion du jour, selon le mois hébraïque. */
    private fun renderTehilim() {
        val (jour, longueur) = CycleTehilim.jourHebreu(java.time.LocalDate.now())
        findViewById<TextView>(R.id.tehilim_state).text =
            getString(R.string.tehilim_today, TehilimTexte.portion(this, CycleTehilim.duMois(jour, longueur)))
    }

    private fun renderTikkun() {
        val tikkun = Data.tikkun(this)
        val dits = Store.tikkunDone(this).size
        val total = tikkun.psaumes.size
        findViewById<TextView>(R.id.tikkun_state).text = when (dits) {
            0 -> getString(R.string.tikkun_progress_none, total, tikkun.versets)
            total -> getString(R.string.tikkun_progress_all)
            else -> getString(R.string.tikkun_progress, dits, total)
        }
    }

    /**
     * Le moment « relance » : un mot après une rupture de série.
     *
     * La carte n'apparaît qu'à quelqu'un qui a déjà pratiqué et dont la série
     * est retombée à zéro. Elle n'a rien à dire à un premier jour, ni à une
     * série en cours.
     */
    private fun renderRelance() {
        val card = findViewById<View>(R.id.relance_chizuk)
        val brisee = Store.streak(this) == 0 && Store.aDejaPratique(this)
        if (!brisee) {
            card.visibility = View.GONE
            relanceTiree = false
            return
        }
        // refresh() repasse à chaque retour d'écran et après chaque permission
        // accordée : on ne retire pas un texte que l'utilisateur est en train
        // de lire, seulement au premier affichage de la rupture.
        if (!relanceTiree) {
            ChizukCard.show(card, Moment.RELANCE)
            relanceTiree = true
        }
    }

    private fun renderToday() {
        renderGreeting()
        val record = Store.record(this)
        // Une note seule ne fait pas la journée.
        val done = record?.faite == true
        findViewById<ImageView>(R.id.hero_character).setImageResource(Character.greeting(done))
        // L'état dit ce qui est vrai maintenant : une hitbodedout en cours
        // n'est pas « pas encore faite », et un jour de Shabbat, de fête ou de
        // pause n'attend rien (revue du 30/09, sur le modèle de la salutation).
        findViewById<TextView>(R.id.status_title).setText(
            when {
                Store.isSessionRunning(this) -> R.string.status_running
                done -> R.string.status_done
                Store.isExempt(this, java.time.LocalDate.now()) -> R.string.status_rest
                else -> R.string.status_pending
            }
        )

        val streak = Store.streak(this)
        // « Série à relancer » ne se dit qu'à qui en a déjà eu une : le
        // premier jour, ce serait accueillir quelqu'un par un échec.
        findViewById<TextView>(R.id.status_streak).text = when {
            streak > 0 -> resources.getQuantityString(R.plurals.status_streak, streak, streak)
            Store.aDejaPratique(this) -> getString(R.string.status_streak_none)
            else -> getString(R.string.status_streak_first)
        }

        val total = Store.totalMinutes(this)
        // Le premier jour, « 0 min au total » n'apprend rien : la phrase
        // d'accueil reste seule sur la ligne.
        val avecTotal = total > 0
        findViewById<View>(R.id.status_separator).visibility = if (avecTotal) View.VISIBLE else View.GONE
        findViewById<TextView>(R.id.status_total).apply {
            visibility = if (avecTotal) View.VISIBLE else View.GONE
            text = getString(R.string.status_total, Store.formatDuration(this@MainActivity, total))
        }

        val minutesToday = record?.minutes ?: 0
        val detail = findViewById<TextView>(R.id.today_detail)
        detail.visibility = if (done) View.VISIBLE else View.GONE
        if (done) {
            detail.text = if (minutesToday > 0) {
                getString(R.string.today_minutes, Store.formatDuration(this, minutesToday))
            } else {
                getString(R.string.today_declared)
            }
        }
        findViewById<Button>(R.id.today_note).visibility = if (done) View.VISIBLE else View.GONE
        // Tant qu'aujourd'hui ou hier peut encore être inscrit.
        findViewById<Button>(R.id.today_offline).visibility =
            if ((!done || hierOuvert()) && !Store.isSessionRunning(this)) View.VISIBLE else View.GONE

        findViewById<Button>(R.id.start_prepare).visibility =
            if (Store.isSessionRunning(this)) View.GONE else View.VISIBLE

        findViewById<Button>(R.id.start_session).text = when {
            Store.isSessionRunning(this) -> getString(R.string.action_back_to_session)
            done -> getString(R.string.action_another_session)
            else -> getString(
                R.string.action_start_session,
                Store.formatDuration(this, Store.targetMinutes(this))
            )
        }
    }

    /** Les jours faits dont on a touché la case : leur durée remplace le ✓. */
    private val joursMontres = mutableSetOf<java.time.LocalDate>()

    private fun renderWeek() {
        val strip = findViewById<LinearLayout>(R.id.week_strip)
        strip.removeAllViews()
        // Les jours dans la langue de l'application, pas celle du téléphone.
        val formatter = DateTimeFormatter.ofPattern("EEE", resources.configuration.locales[0])
        Store.currentWeek(this).forEach { day ->
            val cell = layoutInflater.inflate(R.layout.item_day, strip, false)
            val label = cell.findViewById<TextView>(R.id.day_label)
            val mark = cell.findViewById<TextView>(R.id.day_mark)
            label.text = day.date.format(formatter)

            // Le samedi chômé porte les bougies de Chabbat, pas une lanterne.
            val restDay = day.shabbat && day.exempt
            val aujourdhui = day.date == java.time.LocalDate.now()
            // La semaine en lanternes (14/11) : allumée quand la hitbodedout est faite, qui attend
            // aujourd'hui, éteinte sinon. Le numéro du jour reste dessous : la bande se lit comme
            // un calendrier. Un jour fait touché montre sa durée à la place du numéro (14/10).
            val minutes = Store.record(this, day.date.toString())?.minutes ?: 0
            val montre = day.done && day.date in joursMontres
            mark.text = when {
                montre -> JaugeSemaine.dureeCourte(minutes)
                day.exempt && !day.done && !restDay -> "—"
                else -> day.date.dayOfMonth.toString()
            }
            if (montre) mark.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, mark.textSize * 0.8f)
            cell.findViewById<ImageView>(R.id.day_lanterne).apply {
                setImageResource(when {
                    day.done -> R.drawable.lanterne_allumee
                    restDay -> R.drawable.bougies_chabbat
                    aujourdhui && !day.exempt -> R.drawable.lanterne_aujourdhui
                    else -> R.drawable.lanterne_eteinte
                })
                // Les jours à venir et les jours de pause, en retrait.
                alpha = if (!day.done && !restDay && (day.future || day.exempt)) 0.5f else 1f
            }
            // Tout jour jusqu'à aujourd'hui s'ouvre (16/10) : y ajouter du temps fait hors du
            // téléphone ; un jour fait peut aussi montrer sa durée sur la bande (14/10).
            if (AjoutTemps.possible(day.date)) {
                cell.isClickable = true
                cell.foreground = Apparence.effetToucher(this@MainActivity)
                cell.setOnClickListener {
                    AjoutTemps.ouvrir(this, day.date, montrer = {
                        if (!joursMontres.remove(day.date)) joursMontres.add(day.date)
                        renderWeek()
                    }) { refresh(); renderPaliers() }
                }
            }
            // Le jour en toutes lettres avant l'état (FACCUEIL-12) : sept « à faire » de suite ne disaient rien.
            val jourLu = day.date.format(java.time.format.DateTimeFormatter.ofPattern("EEEE d", resources.configuration.locales[0]))
            cell.contentDescription = jourLu + ", " + when {
                day.done -> getString(R.string.week_done) + " · " + Store.formatDuration(this, minutes)
                restDay -> getString(R.string.settings_shabbat)
                day.exempt -> getString(R.string.gate_exempt_title)
                else -> getString(R.string.week_todo)
            }

            // Aujourd'hui, à la couleur de la marque, comme le cadre de sa lanterne.
            val enAvant = aujourdhui && !day.done && !day.exempt
            label.setTextColor(Apparence.couleur(this, if (enAvant) R.color.brand else R.color.muted))
            if (enAvant) label.setTypeface(label.typeface, Typeface.BOLD)
            mark.setTextColor(
                Apparence.couleur(
                    this,
                    when {
                        enAvant || restDay -> R.color.brand
                        day.future || day.exempt -> R.color.muted
                        else -> R.color.ink
                    }
                )
            )
            strip.addView(cell)
        }
    }

    /** Le seul interrupteur restant ici : la musique, sur sa propre carte. */
    private fun renderSwitches() {
        bindSwitch(R.id.music_switch_main, Store.musicEnabled(this)) { checked ->
            Store.setMusicEnabled(this, checked)
            SessionService.musicChanged(this)
            refresh()
        }
    }

    /** Pose la valeur sans déclencher l'écouteur, puis le réarme. */
    private fun bindSwitch(id: Int, checked: Boolean, onChange: (Boolean) -> Unit) {
        val view = findViewById<MaterialSwitch>(id)
        view.setOnCheckedChangeListener(null)
        view.isChecked = checked
        view.setOnCheckedChangeListener { _, value -> onChange(value) }
    }

    // --- Service, permissions, sauvegarde -----------------------------------

    private fun applyServiceState() {
        if (BuildConfig.HAS_GATE) {
            if (GateStatus.shouldRunService(this)) GateService.start(this) else GateService.stop(this)
        }
        Reminder.reschedule(this)
        ChabbatAlerte.programmer(this)
        LevanaAlerte.programmer(this)
        VolAlerte.programmer(this)
    }

    // --- Sélecteurs ---------------------------------------------------------

    /**
     * Petit écran et texte du système agrandi (15/10) : les lignes de l'en-tête et de la
     * légende s'allongent, et la jauge de 136dp repoussait encore « Commencer » sous les
     * onglets (capture 480x854, police 1,3). La jauge descend alors à 96dp.
     *
     * 22/11 (capture 480x854) : à 96dp, le hassid tenait dans 16dp de large, et la plaque
     * (marge 24dp) cachait l'anneau du jour (30dp d'anneaux). « Commencer » vit désormais
     * dans la barre fixe (13/11) : la jauge remonte à 136dp, les anneaux s'affinent (6dp,
     * écarts de 2dp), la plaque s'arrête juste à l'intérieur, et son retrait suit sa taille.
     */
    private fun jaugeCompacte() {
        val c = resources.configuration
        if (c.fontScale <= 1.1f || c.screenHeightDp >= 640 || c.orientation != android.content.res.Configuration.ORIENTATION_PORTRAIT) return
        val d = resources.displayMetrics.density
        val anneaux = findViewById<AnneauxView>(R.id.week_gauge)
        anneaux.geometrie = AnneauxDessin.Geometrie(epaisseur = 6f * d, ecart = 2f * d)
        val cadre = anneaux.parent as View
        cadre.layoutParams = (cadre.layoutParams as android.view.ViewGroup.MarginLayoutParams).apply {
            width = (136 * d).toInt(); height = (136 * d).toInt(); topMargin = (8 * d).toInt()
        }
        // Les anneaux (22dp) et 2dp d'air ; le trait mis en avant (x1,3) n'y entre pas.
        val marge = (anneaux.geometrie.largeur + 2 * d).toInt()
        findViewById<View>(R.id.hero_plate).apply {
            layoutParams = (layoutParams as android.view.ViewGroup.MarginLayoutParams).apply { setMargins(marge, marge, marge, marge) }
            setPadding((8 * d).toInt(), (6 * d).toInt(), (8 * d).toInt(), (2 * d).toInt())
        }
    }

    /**
     * L'écran d'ouverture (13/10, refait le 15/10) : le 'hassid debout, souriant, devant
     * le היכל הציון de Rabbi Na'hman à Ouman, une seconde et demie au démarrage, puis un
     * fondu. Il se pose par-dessus l'accueil dès le premier dessin : plus d'écran vide
     * pendant que l'application attend (capture du 15/10, trois secondes de menthe).
     * Photo : la façade du היכל הציון, fournie par le porteur le 15/11 (tools/ouverture_tziyoun.py).
     */
    private fun ouverture(demarrage: Boolean) {
        // Le fond du thème (la palette choisie) remplace celui de l'ouverture.
        val fond = android.util.TypedValue().also { theme.resolveAttribute(android.R.attr.colorBackground, it, true) }.data
        window.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(fond))
        if (!demarrage) return
        val decor = window.decorView as android.view.ViewGroup
        val haut = resources.displayMetrics.heightPixels
        val voile = android.widget.FrameLayout(this).apply {
            layoutDirection = View.LAYOUT_DIRECTION_LTR
            setBackgroundColor(getColor(R.color.ouverture_fond))
            isClickable = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            // La façade, centrée : l'enseigne reste entière (15/11).
            addView(android.widget.ImageView(context).apply {
                setImageResource(R.drawable.scene_ouverture_tombe)
                scaleType = android.widget.ImageView.ScaleType.MATRIX
                addOnLayoutChangeListener { v, l, t, r, b, _, _, _, _ ->
                    val d = (v as android.widget.ImageView).drawable ?: return@addOnLayoutChangeListener
                    val w = (r - l).toFloat(); val h = (b - t).toFloat()
                    val k = maxOf(w / d.intrinsicWidth, h / d.intrinsicHeight)
                    v.imageMatrix = android.graphics.Matrix().apply {
                        setScale(k, k)
                        postTranslate((w - d.intrinsicWidth * k) / 2f, (h - d.intrinsicHeight * k) / 2f)
                    }
                }
            }, android.widget.FrameLayout.LayoutParams(-1, -1))
            addView(View(context).apply {
                background = android.graphics.drawable.GradientDrawable(
                    android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                    intArrayOf(0x00000000, 0x00000000, 0x99102820.toInt()))
            }, android.widget.FrameLayout.LayoutParams(-1, -1))
            addView(PersonnageImageView(context).apply {
                setImageResource(R.drawable.char_debout)
                adjustViewBounds = true
                scaleType = android.widget.ImageView.ScaleType.FIT_END
            }, android.widget.FrameLayout.LayoutParams(-2, (haut * 0.5).toInt(), android.view.Gravity.BOTTOM or android.view.Gravity.LEFT).apply {
                bottomMargin = (haut * 0.03).toInt()
            })
        }
        decor.addView(voile, android.view.ViewGroup.LayoutParams(-1, -1))
        // La seconde et demie se compte depuis le premier dessin du voile, pas depuis
        // onCreate : sur un téléphone lent, l'écran du système occupait déjà ce temps.
        voile.viewTreeObserver.addOnPreDrawListener(object : android.view.ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                voile.viewTreeObserver.removeOnPreDrawListener(this)
                // « Supprimer les animations » (FACCUEIL-24) : pas d'attente imposée ; et un toucher
                // referme le voile sans attendre la fin du délai.
                var parti = false
                val effacer = Runnable {
                    if (parti) return@Runnable
                    parti = true
                    voile.animate().alpha(0f).setDuration(350).withEndAction { decor.removeView(voile) }.start()
                }
                voile.setOnClickListener { voile.removeCallbacks(effacer); effacer.run() }
                voile.postDelayed(effacer, if (android.animation.ValueAnimator.areAnimatorsEnabled()) OUVERTURE_MS else 0L)
                return true
            }
        })
    }

    companion object {
        /** La durée de l'écran d'ouverture (15/10 : une seconde et demie). */
        const val OUVERTURE_MS = 1500L

        /** Le jour de la séance dont la note est proposée (AAAA-MM-JJ). */
        const val EXTRA_ASK_NOTE = "ask_note"

        /** Survit à une rotation ou au redimensionnement d'une fenêtre. */
        private const val ETAT_RELANCE = "relance_tiree"

        /** Le ciel du Jour se revoit chaque minute tant que l'accueil est devant. */
        private const val CIEL_MS = 60_000L

        /** L'onglet affiché, pour qu'une rotation ne ramène pas à « Aujourd'hui ». */
        private const val ETAT_ONGLET = "onglet"
    }
}
