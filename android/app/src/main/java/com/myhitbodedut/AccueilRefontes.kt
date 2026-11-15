package com.myhitbodedut

import android.content.Intent
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.graphics.ColorUtils
import com.google.android.material.button.MaterialButton
import com.google.android.material.progressindicator.CircularProgressIndicator
import com.google.android.material.progressindicator.LinearProgressIndicator
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Les trois accueils refondus (15/11), choisis dans Réglages › Apparence :
 * « Ciel complet », « Bento » et « Pile ». Chacun prend la place du haut de
 * l'accueil classique (titre, anneaux, bouton et pastilles) ; les cartes du
 * moment, la relance, la note et les paliers restent dessous. Couché, l'accueil
 * reste classique : la hauteur manque.
 *
 * Rien n'est inventé : chaque tuile et chaque carte lit ce que l'accueil
 * classique lit déjà (Store, zmanim du lieu, ’hizouk, journal), et ouvre
 * l'écran qui va avec. La grande tuile et les boutons « Commencer » font
 * exactement ce que fait le bouton de l'accueil classique.
 */
class AccueilRefontes(private val a: MainActivity) {

    private val densite = a.resources.displayMetrics.density
    private fun dp(v: Float) = (v * densite).toInt()

    /** La disposition montrée au dernier rendu : revenir au classique rallume ses blocs. */
    private var montree = Store.Disposition.CLASSIQUE
    private var cablee = false
    private var bentoEntre = false
    private var hizoukRetourne = false
    private var noteDepliee = false

    /** Les blocs du haut de l'accueil classique, que les refontes remplacent. */
    private val classiques = intArrayOf(
        R.id.ciel, R.id.ciel_legende, R.id.accueil_marque, R.id.hero_greeting, R.id.status_title,
        R.id.status_ligne, R.id.today_detail, R.id.hero_anneaux, R.id.week_gauge_label,
        R.id.paliers_line, R.id.start_session, R.id.start_puces,
    )

    /** Ceux d'entre eux que l'accueil classique montre toujours (les autres, son rendu les règle). */
    private val toujours = intArrayOf(
        R.id.accueil_marque, R.id.status_title, R.id.status_ligne, R.id.hero_anneaux,
        R.id.week_gauge_label, R.id.paliers_line, R.id.start_session, R.id.start_puces,
    )

    private val heure = DateTimeFormatter.ofPattern("HH:mm")

    /** La disposition à montrer : la choisie, sauf couché ou sans ses vues. */
    fun disposition(): Store.Disposition {
        val choisie = Store.accueilDisposition(a)
        val couche = a.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        return if (couche || a.findViewById<View>(R.id.bento) == null) Store.Disposition.CLASSIQUE else choisie
    }

    /** Vrai quand les anneaux de l'accueil classique sont à l'écran. */
    val anneauxMontres: Boolean get() = disposition() == Store.Disposition.CLASSIQUE

    /** Le rendu, à la fin de chaque rafraîchissement de l'accueil. */
    fun rendre() {
        val d = disposition()
        cabler()
        a.findViewById<View>(R.id.ciel_complet)?.visibility = if (d == Store.Disposition.CIEL) View.VISIBLE else View.GONE
        a.findViewById<View>(R.id.bento)?.visibility = if (d == Store.Disposition.BENTO) View.VISIBLE else View.GONE
        a.findViewById<View>(R.id.pile)?.visibility = if (d == Store.Disposition.PILE) View.VISIBLE else View.GONE
        if (d == Store.Disposition.CLASSIQUE) {
            if (montree != Store.Disposition.CLASSIQUE) toujours.forEach { a.findViewById<View>(it)?.visibility = View.VISIBLE }
        } else {
            classiques.forEach { a.findViewById<View>(it)?.visibility = View.GONE }
        }
        pleinEcran(d == Store.Disposition.CIEL)
        montree = d
        when (d) {
            Store.Disposition.CIEL -> rendreCiel()
            Store.Disposition.BENTO -> rendreBento()
            Store.Disposition.PILE -> rendrePile()
            Store.Disposition.CLASSIQUE -> Unit
        }
    }

    // --- Ce que les trois partagent -------------------------------------------------

    private class Jour(
        val zmanim: List<Zmanim.Zman>?,
        val lieu: Zmanim.Lieu?,
        val maintenant: ZonedDateTime,
        val reperes: CielDuJour.Reperes,
    ) {
        val minute: Int get() = maintenant.hour * 60 + maintenant.minute
    }

    private fun jour(): Jour {
        val lieu = Store.lieuZmanim(a)
        val zone = lieu?.let { runCatching { ZoneId.of(it.fuseau) }.getOrNull() } ?: ZoneId.systemDefault()
        val maintenant = ZonedDateTime.now(zone)
        val zmanim = lieu?.let { runCatching { Zmanim.jour(it, maintenant.toLocalDate()) }.getOrNull() }
        return Jour(zmanim, lieu, maintenant, zmanim?.let(CielDuJour::reperes) ?: CielDuJour.MOYENS)
    }

    /** Le prochain zman, avec la journée qui le porte ; la nuit tombée, le premier de demain (le lever). */
    private class Prochain(val zman: Zmanim.Zman, val journee: List<Zmanim.Zman>, val demain: Boolean)

    private fun prochain(j: Jour): Prochain? {
        val aujourdhui = j.zmanim ?: return null
        CielDuJour.prochain(aujourdhui, j.maintenant)?.let { return Prochain(it, aujourdhui, false) }
        val lieu = j.lieu ?: return null
        val demain = runCatching { Zmanim.jour(lieu, j.maintenant.toLocalDate().plusDays(1)) }.getOrNull() ?: return null
        return CielDuJour.prochain(demain, j.maintenant)?.let { Prochain(it, demain, true) }
    }

    /** « Lever du soleil (Nets) », ou « Lever du soleil (Nets) demain » une fois la nuit tombée. */
    private fun nom(p: Prochain): String {
        val nom = a.getString(CielDuJour.NOMS.getValue(p.zman.cle))
        return if (p.demain) a.getString(R.string.refonte_demain, nom) else nom
    }

    private fun dans(z: Zmanim.Zman, j: Jour): String {
        val minutes = ChronoUnit.MINUTES.between(j.maintenant, z.local!!).toInt().coerceAtLeast(1)
        return a.getString(R.string.refonte_dans, Store.formatDuration(a, minutes))
    }

    private fun zman(j: Jour, cle: String): Zmanim.Zman? =
        j.zmanim?.firstOrNull { it.cle == cle && it.statut == Zmanim.Statut.OK && it.local != null }

    private fun fait(): Boolean = Store.record(a)?.faite == true

    private fun etat(): Int = when {
        Store.isSessionRunning(a) -> R.string.status_running
        fait() -> R.string.status_done
        Store.isExempt(a, LocalDate.now()) -> R.string.status_rest
        else -> R.string.status_pending
    }

    /** Le texte du bouton de séance, celui de l'accueil classique. */
    private fun action(): String = when {
        Store.isSessionRunning(a) -> a.getString(R.string.action_back_to_session)
        fait() -> a.getString(R.string.action_another_session)
        else -> a.getString(R.string.action_start_session, Store.formatDuration(a, Store.targetMinutes(a)))
    }

    private fun serie(): String {
        val n = Store.streak(a)
        return when {
            n > 0 -> a.resources.getQuantityString(R.plurals.status_streak, n, n)
            Store.aDejaPratique(a) -> a.getString(R.string.status_streak_none)
            else -> a.getString(R.string.status_streak_first)
        }
    }

    private fun semaine(): String {
        val p = JaugeSemaine.progression(Store.currentWeek(a))
        return a.resources.getQuantityString(R.plurals.ring_week_detail, p.faits, p.faits, p.dus)
    }

    private fun date(avecHebreu: Boolean): String {
        val langue = a.resources.configuration.locales[0]
        val jour = LocalDate.now()
        val texte = jour.format(DateTimeFormatter.ofPattern("EEEE d MMMM", langue)).replaceFirstChar { it.titlecase(langue) }
        if (!avecHebreu) return texte
        val hebreu = runCatching { CalendrierJuif.jour(jour, Store.inIsrael(a)).dateHebraique }.getOrNull()
        return if (hebreu.isNullOrBlank()) texte else "$texte · " + android.text.BidiFormatter.getInstance().unicodeWrap(hebreu)
    }

    /** Le ’hizouk du jour, s'il est lu : les fichiers de l'accueil se lisent hors du fil principal. */
    private fun hizouk(): Pair<ChizukItem, String>? {
        if (!Data.pret) return null
        val chizuk = runCatching { Data.chizuk(a) }.getOrNull() ?: return null
        val item = Refontes.hizoukDuJour(chizuk.items, LocalDate.now()) ?: return null
        val traduction = ChizukCard.translationOf(item, ChizukCard.language(a)).ifBlank { item.fr.ifBlank { item.en } }
        return item to traduction
    }

    /** La dernière note, et quand elle a été écrite ; null si le journal est verrouillé. */
    private fun note(): Pair<String, String>? {
        if (Store.journalVerrou(a)) return null
        val r = Refontes.derniereNote(Store.days(a).values, Store.today()) ?: return null
        val jour = runCatching { LocalDate.parse(r.date) }.getOrNull() ?: return null
        val quand = when (ChronoUnit.DAYS.between(jour, LocalDate.now())) {
            0L -> a.getString(R.string.refonte_aujourdhui)
            1L -> a.getString(R.string.refonte_hier)
            else -> jour.format(DateTimeFormatter.ofPattern("d MMMM", a.resources.configuration.locales[0]))
        }
        val titre = if (r.minutes > 0) a.getString(R.string.refonte_quand_duree, quand, Store.formatDuration(a, r.minutes)) else quand
        return titre to r.note
    }

    private fun couleur(attribut: Int): Int {
        val v = TypedValue()
        a.theme.resolveAttribute(attribut, v, true)
        return v.data
    }

    private fun ouvrir(classe: Class<*>) = a.startActivity(Intent(a, classe))

    /** Le bouton de l'accueil classique, caché mais câblé : un seul chemin vers la séance. */
    private fun commencer() {
        a.findViewById<View>(R.id.start_session)?.performClick()
    }

    private fun cabler() {
        if (cablee) return
        cablee = true
        a.findViewById<CielView>(R.id.ciel_complet_fond)?.apply {
            pleinEcran = true
            setOnClickListener { ouvrir(ZmanimActivity::class.java) }
            aChaqueMinute = { if (montree == Store.Disposition.CIEL) rendreCiel() }
        }
        a.findViewById<View>(R.id.ciel_complet_commencer)?.setOnClickListener { commencer() }

        a.findViewById<View>(R.id.bento_hitbo)?.setOnClickListener { commencer() }
        a.findViewById<View>(R.id.bento_serie)?.setOnClickListener { ouvrir(PaliersActivity::class.java) }
        a.findViewById<View>(R.id.bento_zmanim)?.setOnClickListener { ouvrir(ZmanimActivity::class.java) }
        a.findViewById<View>(R.id.bento_hizouk)?.setOnClickListener { ouvrir(ChizukActivity::class.java) }
        a.findViewById<View>(R.id.bento_ambiance)?.setOnClickListener { ouvrir(MusicActivity::class.java) }
        a.findViewById<View>(R.id.bento_journal)?.setOnClickListener { ouvrir(JournalActivity::class.java) }
        a.findViewById<View>(R.id.bento_recherche)?.setOnClickListener { ouvrir(RechercheActivity::class.java) }

        val pile = a.findViewById<PileCartes>(R.id.pile_cartes) ?: return
        pile.surChangement = { rendrePosition(it) }
        a.findViewById<View>(R.id.pile_precedente)?.setOnClickListener { pile.aller(-1) }
        a.findViewById<View>(R.id.pile_suivante)?.setOnClickListener { pile.aller(1) }
        a.findViewById<View>(R.id.pile_hitbo_commencer)?.setOnClickListener { commencer() }
        a.findViewById<View>(R.id.pile_hizouk_traduire)?.setOnClickListener { retourner(true) }
        a.findViewById<View>(R.id.pile_hizouk_hebreu_retour)?.setOnClickListener { retourner(false) }
        a.findViewById<View>(R.id.pile_zmanim_tous)?.setOnClickListener { ouvrir(ZmanimActivity::class.java) }
        a.findViewById<View>(R.id.pile_journal_deplier)?.setOnClickListener {
            noteDepliee = !noteDepliee
            rendreNoteDepliee()
        }
        a.findViewById<View>(R.id.pile_journal_ecrire)?.setOnClickListener { NoteDialog.show(a, Store.today()) }
        a.findViewById<View>(R.id.pile_hizouk)?.cameraDistance = 8000 * densite
    }

    // --- Ciel complet ----------------------------------------------------------------

    /**
     * Le ciel prend tout l'écran sous la barre du haut : la page perd ses marges autour de lui,
     * et sa hauteur est celle de la zone qui défile. Revenu à une autre disposition, tout revient.
     */
    private fun pleinEcran(oui: Boolean) {
        val vue = a.findViewById<View>(R.id.ciel_complet) ?: return
        val page = vue.parent as? ViewGroup ?: return
        page.clipToPadding = !oui
        val lp = vue.layoutParams as ViewGroup.MarginLayoutParams
        if (oui) {
            lp.marginStart = -page.paddingStart
            lp.marginEnd = -page.paddingEnd
            lp.topMargin = -page.paddingTop
            lp.bottomMargin = dp(4f)
            val zone = a.findViewById<View>(R.id.main_scroll)
            val h = zone?.height ?: 0
            if (h > 0) lp.height = h else zone?.post { if (montree == Store.Disposition.CIEL) pleinEcran(true) }
        } else {
            lp.marginStart = 0; lp.marginEnd = 0; lp.topMargin = 0; lp.bottomMargin = 0
        }
        vue.layoutParams = lp
    }

    private fun rendreCiel() {
        val j = jour()
        val ciel = CielDuJour.ciel(j.minute, j.reperes)
        a.findViewById<CielView>(R.id.ciel_complet_fond)?.montrer(ciel)

        // Le texte clair ou foncé selon la clarté du ciel ; la carte de verre, selon la nuit.
        val clair = CielDuJour.luminance(ciel.haut) > 0.28
        val encre = if (clair) ENCRE_SOMBRE else ENCRE_CLAIRE
        val nuit = ciel.nuit > 0.5f
        val verreEncre = if (nuit) ENCRE_CLAIRE else ENCRE_SOMBRE

        val periode = Refontes.periode(j.minute, j.reperes)
        val lieu = j.lieu?.nom
        texte(R.id.ciel_complet_lieu, listOfNotNull(lieu, date(avecHebreu = true)).joinToString(" · "), encre)
        texte(R.id.ciel_complet_heure, j.maintenant.format(heure), encre)
        texte(R.id.ciel_complet_moment, a.getString(periode.libelle), encre)
        texte(R.id.ciel_complet_prochain, when {
            j.zmanim == null -> a.getString(R.string.ciel_sans_lieu)
            // La nuit, le lever de demain : la phrase de Rabbi Na'hman est déjà dans la carte de verre.
            else -> prochain(j)?.let { p -> a.getString(R.string.refonte_prochain, nom(p), dans(p.zman, j)) }.orEmpty()
        }, encre)

        a.findViewById<View>(R.id.ciel_complet_verre)?.background = GradientDrawable().apply {
            cornerRadius = 26 * densite
            setColor(if (nuit) VERRE_NUIT else VERRE_JOUR)
        }
        texte(R.id.ciel_complet_etat, a.getString(etat()), verreEncre)
        texte(R.id.ciel_complet_serie, Store.streak(a).takeIf { it > 0 }
            ?.let { a.resources.getQuantityString(R.plurals.status_streak, it, it) }.orEmpty(), verreEncre)
        texte(R.id.ciel_complet_conseil, a.getString(periode.conseil), verreEncre)
        a.findViewById<MaterialButton>(R.id.ciel_complet_commencer)?.apply {
            text = action()
            // La nuit, le bouton prend l'or de la lune ; le jour, la couleur de l'habillage.
            if (nuit) {
                backgroundTintList = ColorStateList.valueOf(OR_NUIT)
                setTextColor(ENCRE_SOMBRE)
                iconTint = ColorStateList.valueOf(ENCRE_SOMBRE)
            } else {
                backgroundTintList = ColorStateList.valueOf(couleur(com.google.android.material.R.attr.colorPrimary))
                setTextColor(couleur(com.google.android.material.R.attr.colorOnPrimary))
                iconTint = ColorStateList.valueOf(couleur(com.google.android.material.R.attr.colorOnPrimary))
            }
        }
    }

    private fun texte(id: Int, t: String, couleur: Int) {
        a.findViewById<TextView>(id)?.apply {
            text = t
            visibility = if (t.isBlank()) View.GONE else View.VISIBLE
            setTextColor(couleur)
        }
    }

    // --- Bento -----------------------------------------------------------------------

    private fun rendreBento() {
        val prenom = Store.firstName(a)
        a.findViewById<TextView>(R.id.bento_date)?.text = date(avecHebreu = true)
        a.findViewById<TextView>(R.id.bento_bonjour)?.text =
            if (prenom.isBlank()) a.getString(R.string.nav_today)
            else a.getString(Salutation.chaine(java.time.LocalTime.now().hour), prenom)
        a.findViewById<ImageView>(R.id.bento_avatar)?.setImageResource(Character.greeting(fait()))

        // La grande tuile : la semaine en anneau, l'état du jour, ce qu'un toucher fait.
        val p = JaugeSemaine.progression(Store.currentWeek(a))
        a.findViewById<CircularProgressIndicator>(R.id.bento_anneau)?.apply {
            max = p.dus.coerceAtLeast(1)
            setProgressCompat(p.faits.coerceAtMost(max), false)
            trackColor = ColorUtils.setAlphaComponent(couleur(R.attr.mhOnBrand), 0x40)
        }
        a.findViewById<TextView>(R.id.bento_anneau_texte)?.text = a.getString(R.string.refonte_anneau, p.faits, p.dus)
        a.findViewById<TextView>(R.id.bento_hitbo_titre)?.setText(etat())
        a.findViewById<TextView>(R.id.bento_hitbo_action)?.text = action()
        a.findViewById<View>(R.id.bento_hitbo)?.contentDescription =
            listOf(a.getString(etat()), semaine(), action()).joinToString(". ")

        // La série, et la semaine en sept barres.
        val n = Store.streak(a)
        a.findViewById<TextView>(R.id.bento_serie_nombre)?.text = n.toString()
        a.findViewById<TextView>(R.id.bento_serie_texte)?.text = a.resources.getQuantityString(R.plurals.refonte_jours_texte, n)
        a.findViewById<View>(R.id.bento_serie)?.contentDescription = listOf(serie(), semaine()).joinToString(". ")
        a.findViewById<LinearLayout>(R.id.bento_barres)?.let { barres(it, Refontes.barres(Store.currentWeek(a)), 34f) }

        // Le prochain zman.
        val j = jour()
        val z = prochain(j)
        val nomVue = a.findViewById<TextView>(R.id.bento_zman_nom)
        val reste = a.findViewById<TextView>(R.id.bento_zman_dans)
        val chkia = a.findViewById<TextView>(R.id.bento_zman_chkia)
        when {
            j.zmanim == null -> {
                nomVue?.setText(R.string.refonte_choisir_ville); reste?.text = ""; chkia?.text = ""
            }
            z == null -> {
                nomVue?.setText(R.string.periode_nuit); reste?.text = ""; chkia?.text = ""
            }
            else -> {
                nomVue?.text = nom(z)
                reste?.text = dans(z.zman, j)
                // Le coucher du même jour que le prochain zman : celui de demain, la nuit tombée.
                chkia?.text = z.journee.firstOrNull { it.cle == "chkia" && it.statut == Zmanim.Statut.OK && it.local != null }
                    ?.let { a.getString(R.string.refonte_zman_heure, a.getString(R.string.zman_chkia), it.local!!.format(heure)) }.orEmpty()
            }
        }
        a.findViewById<View>(R.id.bento_zmanim)?.contentDescription =
            listOf(nomVue?.text, reste?.text, chkia?.text).filterNot { it.isNullOrBlank() }.joinToString(". ")

        // Le ’hizouk du jour ; la tuile attend que les fichiers soient lus.
        val h = hizouk()
        a.findViewById<View>(R.id.bento_hizouk)?.visibility = if (h == null) View.GONE else View.VISIBLE
        a.findViewById<TextView>(R.id.bento_hizouk_texte)?.text = h?.first?.he.orEmpty()

        // L'ambiance de la prochaine séance.
        val piste = if (Store.musicEnabled(a)) MusicLibrary.selected(a) else null
        val ambiance = AmbiancePlayer.choisie(a)
        a.findViewById<TextView>(R.id.bento_ambiance_nom)?.text = piste?.title ?: a.getString(ambiance.titre)
        val silence = piste == null && ambiance == Ambiance.SILENCE
        a.findViewById<LinearLayout>(R.id.bento_egaliseur)?.let {
            barres(it, if (silence) List(5) { 0.15f } else EGALISEUR, 24f, pleines = true)
        }

        // La dernière note, ou ce qui l'empêche.
        val note = note()
        a.findViewById<TextView>(R.id.bento_journal_titre)?.text = note?.first
            ?.let { a.getString(R.string.refonte_journal_titre, it) } ?: a.getString(R.string.refonte_journal)
        a.findViewById<TextView>(R.id.bento_journal_texte)?.text = when {
            Store.journalVerrou(a) -> a.getString(R.string.refonte_journal_verrouille)
            note == null -> a.getString(R.string.refonte_journal_vide)
            else -> note.second
        }

        // À la première apparition, les tuiles entrent en cascade.
        if (!bentoEntre) {
            bentoEntre = true
            a.findViewById<ViewGroup>(R.id.bento)?.let { Effets.enfants(it) }
        }
    }

    /** Des barres de hauteurs [parts] (de 0 à 1) ; pleines à la couleur de l'habillage, sinon à celle des traits. */
    private fun barres(groupe: LinearLayout, parts: List<Float>, hauteur: Float, pleines: Boolean = false) {
        groupe.removeAllViews()
        val marque = couleur(R.attr.mhBrand)
        val trait = couleur(R.attr.mhLine)
        parts.forEach { part ->
            groupe.addView(View(a).apply {
                setBackgroundResource(R.drawable.bg_barre)
                backgroundTintList = ColorStateList.valueOf(if (pleines || part >= 1f) marque else trait)
                layoutParams = LinearLayout.LayoutParams(0, dp(hauteur * part.coerceIn(0.1f, 1f)), 1f).apply {
                    marginStart = dp(2f); marginEnd = dp(2f)
                }
            })
        }
    }

    // --- Pile ------------------------------------------------------------------------

    private fun rendrePile() {
        a.findViewById<TextView>(R.id.pile_date)?.text = date(avecHebreu = true)

        // 1. La hitbodedout.
        a.findViewById<ImageView>(R.id.pile_hitbo_image)?.setImageResource(Character.greeting(fait()))
        a.findViewById<TextView>(R.id.pile_hitbo_titre)?.setText(etat())
        a.findViewById<TextView>(R.id.pile_hitbo_detail)?.text = listOf(serie(), semaine()).joinToString("\n")
        a.findViewById<Button>(R.id.pile_hitbo_commencer)?.text = action()

        // 2. Le ’hizouk, recto hébreu, verso traduction.
        val h = hizouk()
        a.findViewById<TextView>(R.id.pile_hizouk_hebreu)?.text = h?.first?.he ?: a.getString(R.string.lecture_chargement)
        a.findViewById<TextView>(R.id.pile_hizouk_ref)?.text = h?.first?.ref?.let { Reference.localise(a, it) }.orEmpty()
        a.findViewById<TextView>(R.id.pile_hizouk_traduction)?.text = h?.second.orEmpty()
        a.findViewById<View>(R.id.pile_hizouk_traduire)?.visibility = if (h?.second.isNullOrBlank()) View.GONE else View.VISIBLE
        rendreFace()

        // 3. Les zmanim.
        val j = jour()
        val z = prochain(j)
        a.findViewById<TextView>(R.id.pile_zmanim_lieu)?.text = a.getString(R.string.pile_zmanim_lieu, j.lieu?.nom ?: "—")
        a.findViewById<TextView>(R.id.pile_zmanim_prochain)?.text = when {
            j.zmanim == null -> a.getString(R.string.ciel_sans_lieu)
            z == null -> a.getString(R.string.ciel_nuit)
            else -> a.getString(R.string.pile_prochain, nom(z))
        }
        a.findViewById<TextView>(R.id.pile_zmanim_dans)?.apply {
            text = z?.let { dans(it.zman, j) }.orEmpty()
            visibility = if (z == null) View.GONE else View.VISIBLE
        }
        a.findViewById<LinearProgressIndicator>(R.id.pile_zmanim_jour)?.apply {
            max = 1000
            setProgressCompat((Refontes.partDuJour(j.minute, j.reperes) * 1000).toInt(), false)
        }
        a.findViewById<LinearLayout>(R.id.pile_zmanim_liste)?.let { liste ->
            liste.removeAllViews()
            listOf("netz", "chatsot", "minha_ketana", "chkia").mapNotNull { cle -> zman(j, cle)?.let { cle to it } }
                .forEach { (cle, zm) -> liste.addView(ligneZman(a.getString(CielDuJour.NOMS.getValue(cle)), zm.local!!.format(heure))) }
        }

        // 4. Le journal.
        val note = note()
        a.findViewById<TextView>(R.id.pile_journal_titre)?.text = when {
            Store.journalVerrou(a) -> a.getString(R.string.refonte_journal_verrouille)
            // Le bouton « Écrire la note du jour » est juste dessous : pas de « Touchez pour écrire ».
            note == null -> a.getString(R.string.refonte_journal_aucune)
            else -> note.first
        }
        a.findViewById<TextView>(R.id.pile_journal_texte)?.apply {
            text = note?.second.orEmpty()
            visibility = if (note == null) View.GONE else View.VISIBLE
        }
        rendreNoteDepliee()

        val pile = a.findViewById<PileCartes>(R.id.pile_cartes) ?: return
        rendrePosition(pile.position)
    }

    private fun ligneZman(nom: String, h: String) = LinearLayout(a).apply {
        orientation = LinearLayout.HORIZONTAL
        setPadding(0, dp(6f), 0, dp(6f))
        addView(TextView(a).apply {
            text = nom
            textSize = 15f
            setTextColor(couleur(R.attr.mhInk))
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        })
        addView(TextView(a).apply {
            text = h
            textSize = 15f
            fontFeatureSettings = "tnum"
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setTextColor(couleur(R.attr.mhInk))
        })
    }

    /** La position dans la pile : « 2 / 4 », les points, et la carte dite au lecteur d'écran. */
    private fun rendrePosition(i: Int) {
        val pile = a.findViewById<PileCartes>(R.id.pile_cartes) ?: return
        val n = pile.childCount
        a.findViewById<TextView>(R.id.pile_position)?.text = a.getString(R.string.pile_position, i + 1, n)
        a.findViewById<LinearLayout>(R.id.pile_points)?.let { points ->
            points.removeAllViews()
            val encre = couleur(R.attr.mhInk)
            repeat(n) { k ->
                points.addView(View(a).apply {
                    setBackgroundResource(R.drawable.bg_point)
                    backgroundTintList = ColorStateList.valueOf(encre)
                    alpha = if (k == i) 1f else 0.3f
                    layoutParams = LinearLayout.LayoutParams(dp(if (k == i) 22f else 8f), dp(8f)).apply {
                        marginStart = dp(3f); marginEnd = dp(3f)
                    }
                })
            }
        }
        pile.dessus?.let { carte ->
            val nom = when (carte.id) {
                R.id.pile_hitbo -> R.string.pile_hitbo
                R.id.pile_hizouk -> R.string.refonte_hizouk
                R.id.pile_zmanim -> R.string.nav_zmanim
                else -> R.string.refonte_journal
            }
            pile.contentDescription = a.getString(R.string.pile_position, i + 1, n) + ". " + a.getString(nom)
        }
    }

    /** Le ’hizouk se retourne : un quart de tour, la face change, un quart de tour. */
    private fun retourner(versTraduction: Boolean) {
        val carte = a.findViewById<View>(R.id.pile_hizouk) ?: return
        hizoukRetourne = versTraduction
        if (!android.animation.ValueAnimator.areAnimatorsEnabled()) { rendreFace(); return }
        carte.animate().cancel()
        carte.animate().rotationY(90f).setDuration(180).withEndAction {
            rendreFace()
            carte.rotationY = -90f
            carte.animate().rotationY(0f).setDuration(180).start()
        }.start()
    }

    private fun rendreFace() {
        a.findViewById<View>(R.id.pile_hizouk_recto)?.visibility = if (hizoukRetourne) View.GONE else View.VISIBLE
        a.findViewById<View>(R.id.pile_hizouk_verso)?.visibility = if (hizoukRetourne) View.VISIBLE else View.GONE
    }

    /** La note repliée sur cinq lignes ; « Lire la suite » seulement si elle en a plus. */
    private fun rendreNoteDepliee() {
        val texte = a.findViewById<TextView>(R.id.pile_journal_texte) ?: return
        val bouton = a.findViewById<Button>(R.id.pile_journal_deplier) ?: return
        texte.maxLines = if (noteDepliee) Int.MAX_VALUE else 5
        bouton.setText(if (noteDepliee) R.string.pile_replier else R.string.pile_lire_suite)
        bouton.visibility = View.GONE
        if (texte.visibility != View.VISIBLE) return
        texte.post {
            val long = texte.layout?.let { l -> noteDepliee || (l.lineCount > 0 && l.getEllipsisCount(l.lineCount - 1) > 0) } ?: false
            bouton.visibility = if (long) View.VISIBLE else View.GONE
        }
    }

    private companion object {
        const val ENCRE_SOMBRE = 0xFF18203A.toInt()
        const val ENCRE_CLAIRE = 0xFFF5F2EA.toInt()
        const val VERRE_JOUR = 0xD1FFFFFF.toInt()
        const val VERRE_NUIT = 0xB811162C.toInt()
        const val OR_NUIT = 0xFFF3D27A.toInt()
        val EGALISEUR = listOf(0.45f, 0.85f, 0.6f, 1f, 0.7f)
    }
}
