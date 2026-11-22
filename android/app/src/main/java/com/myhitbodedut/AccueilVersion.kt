package com.myhitbodedut

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Ce que partagent les accueils des versions (VersionApp) autres que Classique : ce que
 * MainActivity fait à chaque retour et qui ne doit pas dépendre de l'habillage — la séance
 * réconciliée, la barrière et les rappels programmés, le bravo en attente, la note demandée
 * par la notification de fin, la position reprise après un voyage, la présentation.
 *
 * Une sous-classe dessine son accueil dans [dessiner], appelé à chaque retour et quand les
 * fichiers (textes du jour) sont lus.
 */
abstract class AccueilVersion : AppCompatActivity(), NoteDialog.Hote {

    private val choixLieu = ChoixLieu(this) {
        dessiner()
        appliquerServices()
        ZmanimWidget.refresh(this)
    }

    /** La version que cet écran représente : si elle n'est plus la version choisie, on repart de MainActivity. */
    abstract val version: VersionApp

    /** Construit ou met à jour l'accueil. */
    abstract fun dessiner()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (VersionApp.courante(this) != version) {
            VersionApp.appliquer(this, VersionApp.courante(this))
            return
        }
        Notifications.ensureChannels(this)
        LangueApp.retenir(this)
        if (savedInstanceState == null) {
            if (!Store.hasOnboarded(this)) startActivity(Intent(this, OnboardingActivity::class.java))
            intent?.getStringExtra(MainActivity.EXTRA_ASK_NOTE)?.let { date ->
                if (!Store.hasPendingCelebration(this)) NoteDialog.show(this, date)
            }
            intent?.removeExtra(MainActivity.EXTRA_ASK_NOTE)
        }
    }

    override fun onResume() {
        super.onResume()
        if (isFinishing) return
        SessionService.reconcilier(this)
        appliquerServices()
        Data.prechauffer(this) {
            if (!isDestroyed && lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED)) dessiner()
        }
        dessiner()
        if (!NoteDialog.ouverte(this)) CelebrationActivity.showIfPending(this)
        StreakWidget.refresh(this)
        ZmanimWidget.refresh(this)
        choixLieu.rafraichirSiBesoin()
    }

    override fun noteEnregistree(date: String) = dessiner()

    private fun appliquerServices() {
        if (BuildConfig.HAS_GATE) {
            if (GateStatus.shouldRunService(this)) GateService.start(this) else GateService.stop(this)
        }
        Reminder.reschedule(this)
        ChabbatAlerte.programmer(this)
        LevanaAlerte.programmer(this)
        VolAlerte.programmer(this)
    }

    // --- Les gestes communs ----------------------------------------------------

    /** La séance d'un seul geste, réglée comme sur l'accueil Classique ; en cours, on y revient. */
    fun commencerSeance() {
        startActivity(Intent(this, SessionActivity::class.java)
            .putExtra(SessionActivity.EXTRA_START_NOW, !Store.isSessionRunning(this)))
    }

    /** L'écran de préparation : durée, sujet, musique, manière. */
    fun preparerSeance() = startActivity(Intent(this, SessionActivity::class.java))

    fun ouvrirZmanim() = startActivity(Intent(this, ZmanimActivity::class.java))
    fun ouvrirJournal() = startActivity(Intent(this, JournalActivity::class.java))
    fun ouvrirTextes() = startActivity(Intent(this, LibraryActivity::class.java))
    fun ouvrirSiddour() = startActivity(Intent(this, SiddurActivity::class.java))
    fun ouvrirTehilim() = startActivity(Intent(this, TehilimActivity::class.java))
    fun ouvrirChizuk() = startActivity(Intent(this, ChizukActivity::class.java))
    fun ouvrirMusique() = startActivity(Intent(this, MusicActivity::class.java))
    fun ouvrirReglages() = startActivity(Intent(this, SettingsActivity::class.java))
    fun ouvrirParcours() = startActivity(Intent(this, ParcoursActivity::class.java))
    fun ecrireNote() = NoteDialog.show(this, Store.today())

    fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

/**
 * Les données d'un accueil, lues d'un coup : ce que les maquettes montrent (salut, dates,
 * série, semaine, prochain zman, texte du jour, dernière note). Chaque morceau qui peut
 * manquer (pas de lieu, textes pas encore lus) est null plutôt que de casser l'écran.
 */
data class DonneesAccueil(
    val prenom: String,
    val dateCivile: String,
    val dateHebraique: String?,
    val faite: Boolean,
    val minutesAujourdhui: Int,
    val serie: Int,
    val semaineFaits: Int,
    val semaineDus: Int,
    val totalMinutes: Int,
    val objectifMinutes: Int,
    val lieu: String?,
    val zmanim: List<ZmanAffiche>,
    val prochain: ZmanAffiche?,
    val pensee: PenseeAffichee?,
    val derniereNote: NoteAffichee?,
) {
    data class ZmanAffiche(val cle: String, val nom: String, val heure: String, val instant: ZonedDateTime)

    /**
     * Le soir, quand les zmanim du jour sont passés, [prochain] est null alors qu'un lieu est
     * choisi : on montre alors le dernier repère du jour (la sortie des étoiles) et son heure,
     * sans compte à rebours. Null aussi sans lieu : c'est le seul cas où l'on propose d'en
     * choisir un. Recette du 22/11 : Bento, Instant et Sérénité affichaient « Choisir un lieu »
     * chaque soir, lieu choisi ou non.
     */
    val dernierDuJour: ZmanAffiche? get() = if (prochain == null) zmanim.lastOrNull() else null
    data class PenseeAffichee(val hebreu: String, val traduction: String?, val reference: String)
    data class NoteAffichee(val date: LocalDate, val minutes: Int, val texte: String?)

    /** « dans 1 h 12 » jusqu'au prochain zman. */
    fun dans(context: Context, z: ZmanAffiche, maintenant: ZonedDateTime = ZonedDateTime.now(z.instant.zone)): String {
        val minutes = minutesAvant(maintenant, z.instant)
        return if (minutes < 60) context.getString(R.string.version_dans_min, minutes)
        else context.getString(R.string.version_dans_h, minutes / 60, minutes % 60)
    }

    companion object {
        /**
         * Les minutes entières jusqu'à [instant], jamais moins d'une : dans la dernière minute
         * avant un zman, les accueils annonçaient « dans 0 min » (recette du 22/11).
         */
        fun minutesAvant(maintenant: ZonedDateTime, instant: ZonedDateTime): Long =
            java.time.Duration.between(maintenant, instant).toMinutes().coerceAtLeast(1)

        /** Les zmanim qu'un accueil montre en bref, dans l'ordre du jour. */
        val REPERES = listOf("netz", "chatsot", "minha_ketana", "chkia", "tset")

        fun lire(c: Context): DonneesAccueil {
            val heure = DateTimeFormatter.ofPattern("HH:mm")
            val lieu = runCatching { Store.lieuZmanim(c) }.getOrNull()
            val fuseau = lieu?.fuseau?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()
            val maintenant = ZonedDateTime.now(fuseau)
            val jour = lieu?.let { l -> runCatching { Zmanim.jour(l, maintenant.toLocalDate()) }.getOrNull() }.orEmpty()
            val tset = jour.firstOrNull { it.cle == "tset" }?.local
            val hebraique = runCatching {
                CalendrierJuif.jour(ZmanimVignette.jourHebreuAffiche(maintenant, tset), Store.inIsrael(c)).dateHebraique
            }.getOrNull()
            fun affiche(z: Zmanim.Zman): ZmanAffiche? {
                val t = z.local ?: return null
                return ZmanAffiche(z.cle, Libelles.res("zman_${z.cle}")?.let(c::getString) ?: z.cle, t.format(heure), t)
            }
            val tous = jour.mapNotNull(::affiche)
            val semaine = JaugeSemaine.progression(Store.currentWeek(c))
            // Le texte du jour attend la lecture des fichiers hors du fil principal (Data.prechauffer) :
            // l'accueil se redessine quand elle est faite.
            val pensee = if (!Data.pret) null else runCatching {
                val p = SourceDuJour.choix(Data.library(c), LocalDate.now()) ?: return@runCatching null
                val traduction = when (ChizukCard.language(c)) {
                    "en" -> p.source.paragraphesEn.getOrNull(p.indice)
                    "he" -> null
                    else -> p.source.paragraphesFr.getOrNull(p.indice) ?: p.source.paragraphesEn.getOrNull(p.indice)
                }
                PenseeAffichee(
                    SourceDuJour.extrait(SourceDuJour.sansBalises(p.texte), 420),
                    traduction?.let { SourceDuJour.extrait(SourceDuJour.sansBalises(it), 420) },
                    Reference.localise(c, p.source.ref),
                )
            }.getOrNull()
            val verrou = VerrouJournal.actif(c)
            val note = Store.days(c).values
                .filter { it.faite || it.note.isNotBlank() }
                .maxByOrNull { it.date }
                ?.let { r -> NoteAffichee(Store.parse(r.date), r.minutes, r.note.takeIf { it.isNotBlank() && !verrou }) }
            return DonneesAccueil(
                prenom = Store.firstName(c),
                dateCivile = LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE d MMMM", langue(c)))
                    .replaceFirstChar { it.titlecase(langue(c)) },
                // Isolée : la date hébraïque garde son ordre de droite à gauche au milieu d'une ligne en français.
                dateHebraique = hebraique?.let { "\u2067$it\u2069" },
                faite = Store.isDone(c),
                minutesAujourdhui = Store.record(c)?.minutes ?: 0,
                serie = Store.streak(c),
                semaineFaits = semaine.faits,
                semaineDus = semaine.dus,
                totalMinutes = Store.totalMinutes(c),
                objectifMinutes = Store.targetMinutes(c),
                lieu = lieu?.nom,
                zmanim = tous.filter { it.cle in REPERES },
                prochain = tous.firstOrNull { it.instant.isAfter(maintenant) && it.cle != "chatsot_layla" },
                pensee = pensee,
                derniereNote = note,
            )
        }

        /** « Aujourd'hui », « Hier », sinon « lundi 28 septembre ». */
        fun jour(c: Context, date: LocalDate): String = when (date) {
            LocalDate.now() -> c.getString(R.string.version_aujourdhui)
            LocalDate.now().minusDays(1) -> c.getString(R.string.version_hier)
            else -> date.format(DateTimeFormatter.ofPattern("EEEE d MMMM", langue(c))).replaceFirstChar { it.titlecase(langue(c)) }
        }

        /** La langue de l'application (LangueApp), pas celle du téléphone. */
        private fun langue(c: Context): Locale = c.resources.configuration.locales[0]

        /** « 1 h 05 », « 20 min ». */
        fun duree(c: Context, minutes: Int): String =
            if (minutes < 60) c.getString(R.string.version_duree_min, minutes)
            else c.getString(R.string.version_duree_h, minutes / 60, minutes % 60)
    }
}
