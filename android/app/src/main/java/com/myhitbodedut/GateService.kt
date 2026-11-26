package com.myhitbodedut

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.view.Gravity
import android.view.WindowManager

/**
 * Service au premier plan : surveille l'application affichée et interpose
 * l'écran de garde tant que la pratique du jour n'est pas faite.
 */
class GateService : Service() {

    /** La langue choisie dans l'application, même avant Android 13 (LangueApp). */
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(LangueApp.envelopper(base))
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var windowManager: WindowManager
    private var overlay: BlockerView? = null
    private var overlayMode: BlockerMode? = null
    private var lastQuery = System.currentTimeMillis() - QUERY_BACKFILL_MS
    private var foregroundPackage: String? = null
    private var previewing = false

    /** startForeground a réussi au moins une fois : le service est bien au premier plan. */
    private var auPremierPlan = false

    /** Les applications jamais retenues (AppsProtegees), relues au plus une fois par minute. */
    private var protegeesMemo: Set<String> = emptySet()
    private var protegeesLues = 0L

    /**
     * Le rythme suit l'état (check-up du 11/11) : on interrogeait le système
     * toutes les 900 ms toute la journée, même barrière désarmée et écran
     * éteint. Désormais : 900 ms seulement quand la barrière est armée et
     * l'écran allumé, 15 s sinon ; écran éteint, la boucle s'arrête et
     * reprend à l'allumage (GateRythme).
     */
    private val tick = object : Runnable {
        override fun run() {
            val armee = evaluate()
            val delai = GateRythme.delai(armee = armee, ecranAllume = ecranAllume(), relanceAllumage = ecouteEcran) ?: return
            handler.postDelayed(this, delai)
        }
    }

    private fun ecranAllume(): Boolean =
        runCatching { getSystemService(PowerManager::class.java).isInteractive }.getOrDefault(true)

    /** Écran rallumé ou déverrouillé : reprendre aussitôt, sans attendre le tour suivant. */
    private val ecran = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            handler.removeCallbacks(tick)
            if (intent.action != Intent.ACTION_SCREEN_OFF) handler.post(tick)
        }
    }

    /** L'allumage est écouté : la boucle peut s'arrêter écran éteint. */
    private var ecouteEcran = false

    override fun onCreate() {
        super.onCreate()
        enMarche = true
        demarrage = false
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        Notifications.ensureChannels(this)
        // Annonces du système (protégées) : elles arrivent aussi à un récepteur non exporté.
        ecouteEcran = runCatching {
            val filtre = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) registerReceiver(ecran, filtre, RECEIVER_NOT_EXPORTED)
            else registerReceiver(ecran, filtre)
        }.isSuccess
    }

    /**
     * Android exige startForeground dans les secondes qui suivent chaque
     * startForegroundService, service déjà lancé ou non.
     *
     * Il peut aussi le refuser (13/11, FPRODUIT-01 et FBARRIERE-06) : relance d'un service
     * collant en arrière-plan sous Android 12 et plus, application restreinte, type refusé
     * sous Android 14 et plus. L'exception n'était pas rattrapée : plantage, puis barrière
     * morte sans que rien le dise. Refusé, le service s'arrête proprement ; l'état passe à
     * « Mode arrêté » (GateState.SERVICE_STOPPED) et l'ouverture suivante de l'application
     * le relance, depuis le premier plan où Android l'accepte.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!startInForeground()) {
            enMarche = false
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_PREVIEW) {
            previewing = true
            showOverlay(BlockerMode.PREVIEW)
        }
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (ecouteEcran) runCatching { unregisterReceiver(ecran) }
        ecouteEcran = false
        hideOverlay()
        enMarche = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // --- Boucle de décision -------------------------------------------------

    /** Vrai quand la barrière est armée : il faut alors guetter de près. */
    private fun evaluate(): Boolean {
        if (previewing) return false
        // Un seul état par tour, pour la notification comme pour l'écran : ils ne peuvent
        // plus se contredire (13/11, TFRUX-02 : « Hors de la fenêtre » pendant un blocage).
        val etat = GateStatus.evaluate(this)
        rafraichirNotification(etat)

        val mode = GateRule.ecran(etat)
        if (mode == null) {
            hideOverlay()
            return false
        }

        if (GateRule.retenue(readForegroundPackage(), packageName, Store.blockedApps(this), ::protegees)) {
            showOverlay(mode)
        } else {
            hideOverlay()
        }
        return true
    }

    /**
     * Le Téléphone, l'écran d'accueil et les Réglages ne sont jamais retenus, même venus
     * d'une liste importée ou choisie avant le 13/11 (FBARRIERE-05). Le Téléphone ou
     * l'écran d'accueil par défaut peuvent changer : relus au plus une fois par minute,
     * et seulement quand une application choisie est au premier plan.
     */
    private fun protegees(): Set<String> {
        val maintenant = SystemClock.elapsedRealtime()
        if (protegeesLues == 0L || maintenant - protegeesLues > PROTEGEES_MS) {
            protegeesMemo = AppsProtegees.de(this)
            protegeesLues = maintenant
        }
        return protegeesMemo
    }

    /** Dernière application passée au premier plan, mémorisée entre deux tours. */
    private fun readForegroundPackage(): String? {
        val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = runCatching { usage.queryEvents(lastQuery - QUERY_OVERLAP_MS, now) }.getOrNull()
        if (events != null) {
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    foregroundPackage = event.packageName
                }
            }
        }
        lastQuery = now
        return foregroundPackage
    }

    // --- Écran de garde -----------------------------------------------------

    private fun showOverlay(mode: BlockerMode) {
        if (overlay != null && overlayMode == mode) {
            (overlay as? BlockerView)?.actualiser()
            return
        }
        hideOverlay()
        if (!Permissions.canDrawOverlays(this)) return

        val view = BlockerView(
            context = this,
            mode = mode,
            onStartSession = {
                previewing = false
                if (!Store.isSessionRunning(this)) {
                    // Démarrage d'un service de premier plan depuis un autre : on ne parie pas
                    // dessus. Il part avant que l'écran de garde soit retiré (13/11) : pour une
                    // application qui cible Android 15 ou plus, l'affichage par-dessus n'en
                    // exempte que si une fenêtre par-dessus est visible à cet instant.
                    runCatching { SessionService.start(this, Store.targetMinutes(this)) }
                }
                hideOverlay()
                openSession()
            },
            onAlreadyDone = {
                Store.addSession(this, 0)
                // La vignette de série et le rappel suivent aussitôt la journée faite (FBARRIERE-11, FDONNEES-15).
                runCatching { StreakWidget.refresh(this) }
                runCatching { Reminder.reschedule(this) }
                hideOverlay()
                goHome()
            },
            onSnooze = {
                Store.snooze(this)
                hideOverlay()
                goHome()
            },
            onDismiss = {
                previewing = false
                hideOverlay()
                if (!GateStatus.shouldRunService(this)) stopSelf()
            }
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            // Sans FLAG_KEEP_SCREEN_ON (audit du 12/11, FBARRIERE-02) : posé pour aller faire la
            // hitbodedout, le téléphone doit pouvoir se mettre en veille, et non rester allumé et
            // déverrouillé jusqu'à la fin de la fenêtre.
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE
        )
        params.gravity = Gravity.TOP or Gravity.START

        runCatching {
            windowManager.addView(view, params)
            overlay = view
            overlayMode = mode
        }.onFailure {
            overlay = null
            overlayMode = null
        }
    }

    private fun hideOverlay() {
        val view = overlay ?: return
        overlay = null
        overlayMode = null
        runCatching { windowManager.removeView(view) }
    }

    private fun openSession() {
        runCatching {
            startActivity(
                Intent(this, SessionActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            )
        }
    }

    private fun goHome() {
        runCatching {
            startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    // --- Notification permanente -------------------------------------------

    /** L'état affiché dans la notification permanente, pour la redessiner quand il change. */
    private var etatNotifie: GateState? = null

    /**
     * La notification suit l'état (bug du 02/11) : « Fait pour aujourd'hui » la veille
     * restait affiché le lendemain matin, mode armé, jusqu'au prochain démarrage du service.
     */
    private fun rafraichirNotification(state: GateState) {
        if (state == etatNotifie) return
        runCatching { getSystemService(NotificationManager::class.java).notify(Notifications.ID_GATE, notification(state)) }
    }

    /**
     * Rend vrai si le service est au premier plan. Un refus alors qu'il y était déjà
     * (startForeground est rappelé à chaque ouverture de l'application) ne l'en retire pas.
     */
    private fun startInForeground(): Boolean {
        val reussi = runCatching {
            val notification = notification(GateStatus.evaluate(this))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(Notifications.ID_GATE, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(Notifications.ID_GATE, notification)
            }
        }.isSuccess
        if (reussi) auPremierPlan = true
        return auPremierPlan
    }

    private fun notification(state: GateState): Notification {
        etatNotifie = state
        val open = PendingIntent.getActivity(
            this,
            0,
            MainActivity.depuisDehors(this),
            PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, Notifications.CHANNEL_GATE)
            .setContentTitle(getString(GateStatus.titleOf(state)))
            .setContentText(GateStatus.detailOf(this, state))
            .setStyle(Notification.BigTextStyle().bigText(GateStatus.detailOf(this, state)))
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val QUERY_BACKFILL_MS = 60_000L
        private const val QUERY_OVERLAP_MS = 2_000L
        private const val PROTEGEES_MS = 60_000L
        const val ACTION_PREVIEW = "com.myhitbodedut.PREVIEW_GATE"

        /**
         * Le service tourne dans ce processus, de sa création à son arrêt. Un processus
         * tué repart à faux, comme SessionService.enMarche.
         */
        @Volatile
        private var enMarche = false

        /** Android vient d'accepter de lancer le service, qui n'est pas encore né. */
        @Volatile
        private var demarrage = false

        /**
         * La surveillance tourne-t-elle (13/11, FBARRIERE-01) ? La carte d'état affichait
         * « veille » d'après les seuls réglages, service jamais lancé ou arrêté par Android.
         * Un démarrage accepté compte : le service naît un instant après l'appel, et l'écran
         * qui vient de le demander se dessine avant.
         */
        val vivant: Boolean
            get() = enMarche || demarrage

        /**
         * Demande le service ; rend faux si Android refuse de le lancer d'ici (arrière-plan
         * sous Android 12 et plus), au lieu de laisser l'exception fermer l'application.
         */
        fun start(context: Context): Boolean {
            val accepte = runCatching {
                context.startForegroundService(Intent(context, GateService::class.java))
            }.isSuccess
            demarrage = accepte && !enMarche
            return accepte
        }

        fun stop(context: Context) {
            demarrage = false
            context.stopService(Intent(context, GateService::class.java))
        }

        /** Affiche l'écran de garde une fois, sans effet, pour vérifier qu'il fonctionne. */
        fun preview(context: Context) {
            runCatching {
                context.startForegroundService(
                    Intent(context, GateService::class.java).setAction(ACTION_PREVIEW)
                )
            }
        }
    }
}
