// Store devant la JVM : les règles qui calculent sur le journal et les réglages, l'heure figée réglée pas à
// pas (bouchons/Horloge.kt). D'abord des scénarios : des suites d'opérations faites par le vrai Store sur un
// Theatre, à des instants choisis (Chabbat et Yom Tov en Israël et en diaspora, nuits des changements
// d'heure, fenêtre de nuit 21:00–02:00 un vendredi, minuit, 4 h pour le Tikoun), et après chaque opération
// ce que rendent les fonctions qui calculent, la préférence « days » et les réglages écrits (« prefs »,
// clés triées, en texte d'org.json). Puis les règles pures : fenetreFaite, repriseValable, jourTikkun,
// formatMinutes et formatDuration dans les trois langues. StoreTests de Coeur rejoue tout sur Journal et
// Reglages, l'instant et le fuseau passés en argument.
//
// Un texte long (le journal d'un trimestre) est écrit par sa longueur en unités UTF-16 et son empreinte
// (String.hashCode) ; « prefs », « days » et les trophées ne sont écrits qu'à l'étape qui les change (null sinon).
// AjoutTemps n'est pas compilé par l'oracle (fichiers.txt) : sa règle d'une ligne est jugée à la main.

import android.content.Context
import com.myhitbodedut.LocalizedText
import com.myhitbodedut.MarquesPages
import com.myhitbodedut.Moment
import com.myhitbodedut.Store
import com.myhitbodedut.Theme
import com.myhitbodedut.Ville
import com.myhitbodedut.Zmanim
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import org.json.JSONArray
import org.json.JSONObject

object VecteursStore : Generateur {
    override val fichier = "store.json"

    private const val PREFS = "myhitbodedut"
    private const val JOURNAL = "myhitbodedut-journal"

    /** Les places de lecture regardées à chaque étape. */
    private val CLES_LECTURE = listOf("s:chaharit", "l:likoutei_etsot")

    /** Un texte : ses unités, son empreinte, et lui-même s'il est court. */
    private fun trace(s: String): Map<String, Any?> =
        linkedMapOf("longueur" to s.length, "empreinte" to s.hashCode(), "texte" to s.takeIf { it.length <= 400 })

    /** Les réglages écrits, clés triées, comme org.json les écrit ; un StringSet en tableau trié. */
    private fun prefsTexte(t: Theatre): String {
        val valeurs = t.prefs(PREFS).valeurs
        val o = JSONObject()
        for (cle in valeurs.keys.sorted()) {
            val v = valeurs[cle]
            o.put(cle, if (v is Set<*>) JSONArray(v.map { it as String }.sorted()) else v)
        }
        return o.toString()
    }

    /** La préférence « days » ; absente, le journal vide qu'iOS écrit. */
    private fun daysTexte(t: Theatre): String = t.prefs(JOURNAL).valeurs["days"] as String? ?: "{}"

    private fun drapeaux(l: List<Boolean>) = l.joinToString("") { if (it) "1" else "0" }

    /** Des minutes par jour : leur nombre et l'empreinte de « jour=minutes » triés, joints par des virgules. */
    private fun empreinte(m: Map<LocalDate, Int>): Map<String, Any?> {
        val texte = m.entries.sortedBy { it.key }.joinToString(",") { "${it.key}=${it.value}" }
        return linkedMapOf("jours" to m.size, "empreinte" to texte.hashCode())
    }

    /** Ce que rendent les fonctions qui calculent, ici et maintenant. */
    private fun etat(c: Context): MutableMap<String, Any?> {
        // Le générateur n'est pas réécrit comme le code de l'app : l'heure figée se lit dans Horloge.
        val aujourdhui = Horloge.aujourdhui()
        val semaine = Store.currentWeek(c)
        val bilan = Store.bilan(c)
        val pratique = Store.pratique(c)
        val a = Store.anneaux(c)
        return linkedMapOf(
            "today" to Store.today(),
            "streak" to Store.streak(c),
            "meilleureSerie" to Store.meilleureSerie(c),
            "semaine" to linkedMapOf(
                "dimanche" to semaine.first().date.toString(),
                "faits" to drapeaux(semaine.map { it.done }),
                "exempts" to drapeaux(semaine.map { it.exempt }),
                "chabbats" to drapeaux(semaine.map { it.shabbat }),
                "futurs" to drapeaux(semaine.map { it.future }),
            ),
            "exempt" to Store.isExempt(c, aujourdhui),
            "veille" to Store.isEveOfRestDay(c, aujourdhui),
            "isDone" to Store.isDone(c),
            "record" to Store.record(c)?.minutes,
            "total" to Store.totalMinutes(c),
            "dejaPratique" to Store.aDejaPratique(c),
            "inWindow" to Store.inWindow(c),
            "fenetreFaite" to Store.fenetreFaite(c),
            "isSnoozed" to Store.isSnoozed(c),
            "dailyGoal" to Store.dailyGoal(c),
            "running" to Store.isSessionRunning(c),
            "open" to Store.isSessionOpen(c),
            "elapsed" to Store.sessionElapsedMinutes(c),
            "hasRecord" to Store.hasSessionRecord(c),
            "compteur" to Store.sessionCounter(c).name,
            "bilan" to linkedMapOf(
                "aujourdhui" to bilan.aujourdhui.toString(), "serie" to bilan.serie,
                "debutMoisHebreu" to bilan.debutMoisHebreu.toString(), "objectifJour" to bilan.objectifJour,
                "minutes" to empreinte(bilan.minutes),
            ),
            "pratique" to linkedMapOf(
                "notes" to pratique.notes, "meilleureSerie" to pratique.meilleureSerie,
                "tikkun" to pratique.tikkun.sorted().map { it.toString() }, "minutes" to empreinte(pratique.minutes),
            ),
            "trophees" to Store.datesTrophees(c).entries.sortedBy { it.key }
                .fold(linkedMapOf<String, Any?>()) { m, e -> m[e.key] = e.value.toString(); m },
            "anneaux" to listOf(a.jour.fait, a.jour.objectif, a.semaine.fait, a.semaine.objectif, a.serie.fait, a.serie.objectif),
            "jourTikkun" to Store.jourTikkun(),
            "tikkunDone" to Store.tikkunDone(c).sorted(),
            "tikkunJournal" to Store.tikkunJournal(c).sorted().map { it.toString() },
            "positions" to CLES_LECTURE.map { Store.positionLecture(c, it) },
            "favoris" to Store.favoris(c),
            "chizukFavoris" to Store.chizukFavoris(c),
            "marques" to MarquesPages.encoder(Store.marques(c)),
            "sac" to Store.chizukBag(c, Moment.OUVERTURE),
            "dernier" to Store.chizukLast(c, Moment.OUVERTURE),
            "celebration" to Store.hasPendingCelebration(c),
            // lieuPerime, lieuAlertes non nul, mukafChoma, hemisphereSud.
            "lieu" to drapeaux(listOf(Store.lieuPerime(c), Store.lieuAlertes(c) != null, Store.mukafChoma(c), Store.hemisphereSud(c))),
        )
    }

    // --- Les opérations ----------------------------------------------------------------------------

    private fun op(nom: String, vararg champs: Pair<String, Any?>): Map<String, Any?> =
        linkedMapOf<String, Any?>("op" to nom).apply { champs.forEach { (k, v) -> put(k, v) } }

    /** Le présent : une heure civile dans un fuseau (Horloge.regler). */
    private fun horloge(jour: String, heure: Int, minute: Int, zone: String, seconde: Int = 0) =
        op("horloge", "jour" to jour, "heure" to heure, "minute" to minute, "seconde" to seconde, "zone" to zone)

    /** Le temps passe : tant de minutes plus tard, même fuseau. */
    private fun avance(minutes: Int) = op("avance", "minutes" to minutes)

    /** Un voyage : le même instant, vu d'un autre fuseau. */
    private fun fuseau(zone: String) = op("fuseau", "zone" to zone)

    private fun seance(minutes: Int, note: String? = null, theme: String? = null, date: String? = null) =
        op("addSession", "minutes" to minutes, "note" to note, "theme" to theme, "date" to date)

    /** Des séances sur des jours donnés, dans l'ordre, sans sujet : une seule étape. */
    private fun seances(jours: List<String>, durees: List<Int>) = op("seances", "jours" to jours, "durees" to durees)

    private fun note(date: String, texte: String) = op("setNote", "date" to date, "note" to texte)
    private fun reglage(nom: String, valeur: Boolean) = op(nom, "valeur" to valeur)
    private fun minutes(nom: String, minutes: Int) = op(nom, "minutes" to minutes)
    private fun pause(date: String) = op("togglePausedDate", "date" to date)
    private fun fenetre(debut: Int, fin: Int) = op("setWindow", "debut" to debut, "fin" to fin)
    private fun tikkun(numeros: List<Int>, valeur: Boolean) = op("setTikkunDone", "numeros" to numeros, "valeur" to valeur)
    private fun position(cle: String, position: Int) = op("setPositionLecture", "cle" to cle, "position" to position)
    private fun marque(cle: String, nusah: String, section: Int, bloc: Int, apercu: String) =
        op("basculerMarque", "cle" to cle, "nusah" to nusah, "section" to section, "bloc" to bloc, "apercu" to apercu)
    private fun sac(sac: List<String>, dernier: String?) = op("setChizukBag", "moment" to "ouverture", "sac" to sac, "dernier" to dernier)
    private fun poseTexte(cle: String, texte: String) = op("poseTexte", "cle" to cle, "texte" to texte)
    private fun lieu(nom: String, latitude: Double, longitude: Double, altitude: Double, fuseau: String, ville: Long? = null, pays: String? = null) =
        op("setLieuZmanim", "nom" to nom, "latitude" to latitude, "longitude" to longitude, "altitude" to altitude,
            "fuseau" to fuseau, "ville" to ville, "pays" to pays)

    private fun jours(premier: String, dernier: String, sauf: Set<String> = emptySet()): List<String> {
        val l = mutableListOf<String>()
        var d = LocalDate.parse(premier)
        while (!d.isAfter(LocalDate.parse(dernier))) {
            if (d.toString() !in sauf) l += d.toString()
            d = d.plusDays(1)
        }
        return l
    }

    /** Fait l'opération sur le vrai Store ; rend ce qu'elle rend, s'il y a lieu. */
    private fun execute(t: Theatre, o: Map<String, Any?>): Map<String, Any?> {
        val c = t.contexte
        val r = linkedMapOf<String, Any?>()
        fun i(k: String) = o[k] as Int
        fun s(k: String) = o[k] as String?
        when (o["op"]) {
            "horloge" -> Horloge.regler(LocalDate.parse(s("jour")).atTime(i("heure"), i("minute"), i("seconde")), ZoneId.of(s("zone")))
            "avance" -> Horloge.regler(Horloge.millis() + i("minutes") * 60_000L, Horloge.zone())
            "fuseau" -> Horloge.regler(Horloge.millis(), ZoneId.of(s("zone")))
            "addSession" -> {
                val theme = s("theme")?.let { cle -> Theme.values().first { it.cle == cle } }
                val date = s("date")
                if (date == null) Store.addSession(c, i("minutes"), s("note"), theme)
                else Store.addSession(c, i("minutes"), s("note"), theme, date)
            }
            "seances" -> {
                val jours = (o["jours"] as List<*>).map { it as String }
                val durees = (o["durees"] as List<*>).map { it as Int }
                jours.forEachIndexed { k, d -> Store.addSession(c, durees[k], theme = null, date = d) }
            }
            "setNote" -> Store.setNote(c, s("date")!!, s("note")!!)
            "unmarkToday" -> Store.unmarkToday(c)
            "beginSession" -> Store.beginSession(c, i("minutes"))
            "endSession" -> {
                val close = Store.endSession(c)
                r["seance"] = linkedMapOf("minutes" to close.minutes, "date" to close.date)
            }
            // Ce que fait le service à la fin d'une séance : la clore, puis l'inscrire au jour où elle a commencé.
            "cloreSeance" -> {
                val close = Store.endSession(c)
                Store.addSession(c, close.minutes, theme = null, date = close.date)
                r["seance"] = linkedMapOf("minutes" to close.minutes, "date" to close.date)
            }
            "snooze" -> Store.snooze(c)
            "clearSnooze" -> Store.clearSnooze(c)
            "setSnoozeMinutes" -> Store.setSnoozeMinutes(c, i("minutes"))
            "togglePausedDate" -> Store.togglePausedDate(c, s("date")!!)
            "setShabbatMode" -> Store.setShabbatMode(c, o["valeur"] as Boolean)
            "setInIsrael" -> Store.setInIsrael(c, o["valeur"] as Boolean)
            "setWindow" -> Store.setWindow(c, i("debut"), i("fin"))
            "setTargetMinutes" -> Store.setTargetMinutes(c, i("minutes"))
            "setDailyGoal" -> Store.setDailyGoal(c, i("minutes"))
            "setHideCountdown" -> Store.setHideCountdown(c, o["valeur"] as Boolean)
            "setTikkunDone" -> (o["numeros"] as List<*>).forEach { Store.setTikkunDone(c, it as Int, o["valeur"] as Boolean) }
            "resetTikkun" -> Store.resetTikkun(c)
            "setPositionLecture" -> Store.setPositionLecture(c, s("cle")!!, i("position"))
            "basculerFavori" -> Store.basculerFavori(c, s("cle")!!)
            "basculerChizukFavori" -> Store.basculerChizukFavori(c, s("cle")!!)
            "basculerMarque" -> r["pose"] = Store.basculerMarque(c, MarquesPages.Marque(s("cle")!!, s("nusah")!!, i("section"), i("bloc"), s("apercu")!!))
            "setChizukBag" -> Store.setChizukBag(c, Moment.values().first { it.key == s("moment") },
                (o["sac"] as List<*>).map { it as String }, s("dernier"))
            "setPendingCelebration" -> Store.setPendingCelebration(c, i("minutes"), s("dateNote"))
            "takePendingCelebration" -> {
                val cel = Store.takePendingCelebration(c)
                r["celebration"] = if (cel == null) linkedMapOf("existe" to false)
                    else linkedMapOf("existe" to true, "minutes" to cel.minutes, "dateNote" to cel.dateNote)
            }
            // Une préférence posée à la main (une version d'avant, un fichier abîmé), lue ensuite par Store.
            "poseTexte" -> t.prefs(PREFS).valeurs[s("cle")!!] = s("texte")!!
            "setLieuZmanim" -> {
                val nom = s("nom")!!
                val lieu = Zmanim.Lieu(nom, o["latitude"] as Double, o["longitude"] as Double, o["altitude"] as Double, s("fuseau")!!)
                val ville = (o["ville"] as Long?)?.let {
                    Ville(it, LocalizedText(nom, nom, nom), s("pays")!!, lieu.latitude, lieu.longitude, lieu.altitude, lieu.fuseau)
                }
                Store.setLieuZmanim(c, lieu, ville)
            }
            else -> error("opération inconnue : ${o["op"]}")
        }
        return r
    }

    private fun rejoue(nom: String, ops: List<Map<String, Any?>>): Map<String, Any?> {
        val t = Theatre()
        var prefsAvant: String? = null
        var daysAvant: String? = null
        var tropheesAvant: Any? = null
        val etapes = ops.map { o ->
            val resultat = execute(t, o)
            val e = etat(t.contexte)
            // Les trophées, comme « prefs » et « days », ne sont écrits qu'à l'étape qui les change.
            val trophees = e["trophees"]
            if (trophees == tropheesAvant) e["trophees"] = null
            tropheesAvant = trophees
            // Après l'état : sa lecture a pu figer Israël ou diaspora (Store.inIsrael).
            val prefs = prefsTexte(t)
            val days = daysTexte(t)
            val etape = linkedMapOf<String, Any?>("op" to o, "millis" to Horloge.millis(), "zone" to Horloge.zone().id)
            etape.putAll(resultat)
            etape["etat"] = e
            etape["prefs"] = if (prefs != prefsAvant) trace(prefs) else null
            etape["days"] = if (days != daysAvant) trace(days) else null
            prefsAvant = prefs
            daysAvant = days
            etape
        }
        return linkedMapOf("nom" to nom, "etapes" to etapes)
    }

    // --- Les scénarios -----------------------------------------------------------------------------

    private const val PARIS = "Europe/Paris"
    private const val JERUSALEM = "Asia/Jerusalem"
    private const val NEW_YORK = "America/New_York"

    private val scenarios: List<Pair<String, List<Map<String, Any?>>>> = listOf(
        // Pessa'h 5786 : le 15 Nissan est le jeudi 2 avril 2026 ; le vendredi 3 est fête en diaspora seulement.
        "Pessa'h en diaspora puis en Israël" to listOf(
            horloge("2026-04-08", 20, 0, PARIS),
            reglage("setInIsrael", false),
            seances(jours("2026-03-25", "2026-04-08", setOf("2026-03-28", "2026-04-02", "2026-04-03", "2026-04-04")),
                listOf(20, 25, 5, 60, 15, 15, 30, 45, 20, 20, 10)),
            horloge("2026-04-09", 8, 0, PARIS),
            reglage("setInIsrael", true),
            reglage("setShabbatMode", false),
            pause("2026-04-04"),
            pause("2026-04-03"),
            pause("2026-04-02"),
            pause("2026-03-28"),
            reglage("setShabbatMode", true),
            pause("2026-04-03"),
            seance(12),
            minutes("setDailyGoal", 30),
            seance(25, note = "Après la fête", theme = "gratitude"),
        ),
        // Tichri 5787 à Jérusalem, Israël ou diaspora jamais réglé : la première lecture le fige d'après le
        // fuseau, et un voyage ne le change plus. Kippour le lundi 21 septembre, Souccot le samedi 26,
        // le dimanche 27 fête en diaspora seulement, Chemini Atseret le samedi 3 octobre, Sim'hat Torah
        // de la diaspora le dimanche 4.
        "Tichri à Jérusalem, puis le voyage" to listOf(
            horloge("2026-09-20", 10, 0, JERUSALEM),
            seances(jours("2026-09-13", "2026-09-20", setOf("2026-09-13", "2026-09-19")), listOf(15, 15, 15, 15, 15, 15)),
            horloge("2026-09-21", 18, 0, JERUSALEM),
            seances(jours("2026-09-22", "2026-09-25"), listOf(20, 20, 20, 20)),
            horloge("2026-09-25", 20, 0, JERUSALEM),
            fuseau(PARIS),
            horloge("2026-09-28", 7, 0, PARIS),
            reglage("setInIsrael", false),
            seance(30, theme = "famille"),
            horloge("2026-10-05", 9, 0, PARIS),
            seances(jours("2026-09-29", "2026-10-02"), listOf(10, 10, 10, 10)),
            reglage("setInIsrael", true),
            seance(10),
        ),
        // La fenêtre de nuit (21:00–02:00) un vendredi soir à Paris, le report, et l'annulation du jour.
        "Fenêtre de nuit un vendredi" to listOf(
            horloge("2026-11-06", 20, 59, PARIS),
            reglage("setInIsrael", false),
            fenetre(21 * 60, 2 * 60),
            avance(1),
            minutes("setSnoozeMinutes", 15),
            op("snooze"),
            avance(14),
            avance(1),
            op("snooze"),
            seance(25),
            horloge("2026-11-06", 23, 59, PARIS, seconde = 59),
            avance(1),
            horloge("2026-11-07", 1, 59, PARIS),
            avance(1),
            horloge("2026-11-07", 21, 30, PARIS),
            horloge("2026-11-08", 0, 30, PARIS),
            seance(15),
            horloge("2026-11-08", 1, 59, PARIS),
            horloge("2026-11-08", 21, 30, PARIS),
            fenetre(6 * 60, 11 * 60),
            op("unmarkToday"),
            fenetre(23 * 60, 0),
            op("clearSnooze"),
            fenetre(600, 600),
        ),
        // Les séances aux nuits des changements d'heure, et une séance commencée avant minuit.
        "Séances aux changements d'heure" to listOf(
            horloge("2026-03-29", 1, 50, PARIS),
            reglage("setInIsrael", false),
            minutes("beginSession", 20),
            avance(10),
            avance(15),
            op("cloreSeance"),
            horloge("2026-10-25", 2, 30, PARIS),
            minutes("beginSession", 0),
            avance(60),
            reglage("setHideCountdown", true),
            avance(300),
            op("cloreSeance"),
            reglage("setHideCountdown", false),
            horloge("2026-10-25", 23, 50, PARIS),
            minutes("beginSession", 30),
            avance(20),
            op("cloreSeance"),
            horloge("2026-11-01", 1, 30, NEW_YORK),
            minutes("beginSession", 45),
            fuseau(PARIS),
            avance(30),
            op("cloreSeance"),
            horloge("2026-11-01", 10, 0, PARIS),
            minutes("beginSession", 20),
            horloge("2026-10-31", 22, 0, PARIS),
            op("cloreSeance"),
            op("endSession"),
            minutes("beginSession", -5),
            avance(500),
            op("endSession"),
        ),
        // Le Tikoun : le jour bascule à 4 h ; les dix psaumes dits entrent au journal.
        "Tikoun à quatre heures" to listOf(
            horloge("2026-11-01", 23, 45, JERUSALEM),
            reglage("setInIsrael", true),
            tikkun(listOf(16, 32, 41), true),
            avance(20),
            tikkun(listOf(42, 59, 77, 90, 105, 137, 150), true),
            tikkun(listOf(16), false),
            tikkun(listOf(16, 999), true),
            horloge("2026-11-02", 3, 59, JERUSALEM),
            avance(1),
            tikkun(listOf(150), true),
            op("resetTikkun"),
            poseTexte("tikkun_done", " 16, 32,x,,\u0661\u0662, -4 "),
            poseTexte("tikkun_day", "2026-11-02"),
            poseTexte("tikkun_journal", "2026-11-01, 2026-02-30,x,2025-12-31 ,+2026-01-01,2026-1-05"),
            tikkun(listOf(16, 32, 41, 42, 59, 77, 90, 105, 137, 150), true),
            horloge("2026-11-03", 9, 0, JERUSALEM),
            tikkun(listOf(16, 32, 41, 42, 59, 77, 90, 105, 137, 150), true),
            seances(jours("2026-11-01", "2026-11-03"), listOf(10, 10, 10)),
        ),
        // La lecture, le 'hizouk, le bravo et le lieu des zmanim.
        "Lecture, 'hizouk, bravo, lieu" to listOf(
            horloge("2026-11-02", 7, 0, PARIS),
            reglage("setInIsrael", false),
            position("s:chaharit", 12),
            position("l:likoutei_etsot", 40),
            avance(179),
            avance(1),
            position("s:chaharit", 0),
            position("s:chaharit", -3),
            position("s:chaharit", 5),
            horloge("2026-11-02", 9, 0, PARIS),
            op("basculerFavori", "cle" to "s:chaharit"),
            op("basculerFavori", "cle" to "l:likoutei_etsot"),
            op("basculerFavori", "cle" to "s:chaharit"),
            op("basculerChizukFavori", "cle" to "c1"),
            op("basculerChizukFavori", "cle" to "c2"),
            op("basculerChizukFavori", "cle" to "c1"),
            poseTexte("favoris", "|s:a|| |l:b|\u00A0|s:a"),
            op("basculerFavori", "cle" to "s:a"),
            marque("s:chaharit", "edot", 1, 2, "\u05DE\u05D5\u05B9\u05D3\u05B6\u05D4 \u05D0\u05B2\u05E0\u05B4\u05D9"),
            marque("l:likoutei_etsot", "", 0, 7, "Emouna"),
            marque("s:chaharit", "edot", 1, 2, "autre aperçu"),
            sac(listOf("a", "b", "c"), "z"),
            sac(emptyList(), null),
            poseTexte("chizuk_bag_ouverture", "a\n\n  \nb\n"),
            poseTexte("chizuk_last_ouverture", "  "),
            op("setPendingCelebration", "minutes" to 20, "dateNote" to "2026-11-02"),
            op("takePendingCelebration"),
            op("takePendingCelebration"),
            op("setPendingCelebration", "minutes" to -5, "dateNote" to null),
            lieu("Paris", 48.8566, 2.3522, 35.0, PARIS),
            fuseau(NEW_YORK),
            lieu("J\u00E9rusalem", 31.7683, 35.2137, 754.0, JERUSALEM, 281184L, "IL"),
            lieu("Melbourne", -37.8136, 144.9631, 31.0, "Australia/Melbourne"),
            lieu("Vieille ville", 31.7767, 35.2345, 800.0, JERUSALEM),
            fuseau(JERUSALEM),
        ),
        // Minuit à New York, la semaine du dimanche au samedi, les anneaux, les notes, un long trimestre.
        "Minuit, la semaine et les trophées" to listOf(
            horloge("2026-11-14", 23, 59, NEW_YORK, seconde = 59),
            reglage("setInIsrael", false),
            seances(jours("2026-08-01", "2026-11-13"), (0 until 105).map { (it * 7) % 50 + 5 }),
            minutes("setDailyGoal", 30),
            minutes("setTargetMinutes", 20),
            seance(10),
            avance(1),
            minutes("setDailyGoal", 0),
            minutes("setTargetMinutes", 0),
            note("2026-11-15", "Une pens\u00E9e"),
            note("2026-11-10", "Merci"),
            note("2026-11-15", " "),
            seance(40, note = "Au matin", theme = "emotions"),
            seance(-10),
            op("unmarkToday"),
            horloge("2026-11-21", 12, 0, NEW_YORK),
            horloge("2026-11-23", 12, 0, NEW_YORK),
            seance(5, date = "2026-11-22"),
        ),
        // Une note seule : gardée, elle ne fait pas la journée (ni série ni pratique), mais compte pour la
        // plume ; une note blanche sur un jour vide n'écrit rien ; une note trop longue est coupée ; une
        // séance valide ensuite le jour en gardant sa note.
        "Une note seule" to listOf(
            horloge("2026-06-10", 9, 0, PARIS),
            reglage("setInIsrael", false),
            note("2026-06-09", " "),
            note("2026-06-09", "Une pensée"),
            note("2026-06-09", "Une autre pensée"),
            note("2026-06-08", "א".repeat(2050) + "y".repeat(2000)),
            seance(0, date = "2026-06-09"),
            note("2026-06-09", ""),
            note("2026-06-08", " "),
        ),
    )

    // --- Les règles pures --------------------------------------------------------------------------

    private fun civile(d: LocalDateTime) = "%sT%02d:%02d:%02d".format(java.util.Locale.ROOT, d.toLocalDate(), d.hour, d.minute, d.second)

    /** Les jours faits essayés pour chaque fenêtre, autour du 2 novembre 2026. */
    private val d = LocalDate.of(2026, 11, 2)
    private val ensembles: List<Set<LocalDate>> = listOf(emptySet(), setOf(d), setOf(d.plusDays(1)), setOf(d.minusDays(1)), setOf(d, d.plusDays(1)))

    private fun fenetres(): List<Map<String, Any?>> {
        val cas = mutableListOf<Map<String, Any?>>()
        // Les six cas de VoyageNuitTest ; « faites » : un drapeau par ensemble de jours faits (« ensembles »).
        val nuit = 21 * 60 to 2 * 60
        fun un(debut: Int, fin: Int, maintenant: LocalDateTime, faitA: LocalDateTime?) {
            cas += linkedMapOf("debut" to debut, "fin" to fin, "maintenant" to civile(maintenant), "faitA" to faitA?.let(::civile),
                "faites" to drapeaux(ensembles.map { jours -> Store.fenetreFaite(debut, fin, maintenant, faitA) { it in jours } }))
        }
        un(nuit.first, nuit.second, d.plusDays(1).atTime(0, 30), d.atTime(21, 30))
        un(nuit.first, nuit.second, d.plusDays(1).atTime(0, 40), d.plusDays(1).atTime(0, 30))
        un(nuit.first, nuit.second, d.plusDays(1).atTime(21, 30), d.plusDays(1).atTime(0, 30))
        un(nuit.first, nuit.second, d.atTime(21, 30), d.atTime(10, 0))
        un(nuit.first, nuit.second, d.atTime(23, 0), d.minusDays(1).atTime(21, 30))
        un(nuit.first, nuit.second, d.plusDays(1).atTime(1, 0), null)
        un(6 * 60, 12 * 60, d.atTime(7, 0), null)
        un(6 * 60, 12 * 60, d.atTime(7, 0), d.atTime(7, 0))
        // Le balayage : des fenêtres de nuit et de jour, des heures de part et d'autre des bornes.
        val bornes = listOf(21 * 60 to 2 * 60, 23 * 60 + 30 to 30, 22 * 60 to 0, 1439 to 1, 6 * 60 to 11 * 60, 600 to 600, 0 to 1439)
        val maintenants = listOf(d.atTime(0, 29), d.atTime(0, 30), d.atTime(1, 59), d.atTime(2, 0), d.atTime(20, 59), d.atTime(21, 0),
            d.atTime(23, 59, 59), d.plusDays(1).atTime(1, 0))
        val faits = listOf(null, d.minusDays(1).atTime(21, 30), d.atTime(1, 59, 59), d.atTime(2, 0), d.atTime(21, 30), d.plusDays(1).atTime(0, 30))
        for ((debut, fin) in bornes) for (m in maintenants) for (f in faits) un(debut, fin, m, f)
        return cas
    }

    private fun reprises(): List<Map<String, Any?>> {
        val t0 = 1_793_000_000_000L
        val h = 3_600_000L
        val cas = listOf(
            Triple("s:chaharit", t0, t0 + 20 * 60_000L), Triple("s:chaharit", t0, t0 + Store.PRIERE_REPRISE_MS),
            Triple("s:chaharit", t0, t0 + 24 * h), Triple("s:chaharit", 0L, t0),
            Triple("l:likoutei_etsot", t0, t0 + 10 * 24 * h), Triple("l:likoutei_etsot", 0L, t0),
            Triple("s:chaharit", t0, t0), Triple("s:chaharit", t0, t0 + Store.PRIERE_REPRISE_MS - 1), Triple("s:chaharit", t0, t0 - 1),
            Triple("s:chaharit", -5L, t0), Triple("s:chaharit", 1L, 1L), Triple("s:chaharit", 1L, 0L),
            Triple("s:", t0, t0 + h), Triple("s", t0, t0 + 10 * h), Triple("S:chaharit", t0, t0 + 10 * h), Triple("", 0L, 0L),
            Triple(" s:x", t0, t0 + 10 * h), Triple("l:x", -1L, Long.MIN_VALUE), Triple("s:x", Long.MIN_VALUE, Long.MAX_VALUE),
            Triple("s:x", Long.MAX_VALUE, Long.MIN_VALUE), Triple("s:x", 1L, Long.MIN_VALUE), Triple("s:x", Long.MAX_VALUE - 5, Long.MAX_VALUE),
            Triple("s:\u05EA\u05E4\u05D9\u05DC\u05D4", t0, t0 + h), Triple("s:x", t0, t0 + 3 * h - 1), Triple("s:x", t0, t0 + 3 * h + 1),
            Triple("s:chaharit", 0L, 60_000L), Triple("s:x", 0L, 0L),
        )
        return cas.map { (cle, quand, maintenant) ->
            linkedMapOf("cle" to cle, "quand" to quand, "maintenant" to maintenant, "valable" to Store.repriseValable(cle, quand, maintenant))
        }
    }

    private fun joursTikkun(): List<Map<String, Any?>> {
        val instants = listOf(
            LocalDateTime.of(2026, 11, 1, 23, 45), LocalDateTime.of(2026, 11, 2, 0, 5), LocalDateTime.of(2026, 11, 2, 3, 59),
            LocalDateTime.of(2026, 11, 2, 9, 0), LocalDateTime.of(2026, 11, 2, 3, 59, 59, 999_000_000), LocalDateTime.of(2026, 11, 2, 4, 0),
            LocalDateTime.of(2026, 11, 2, 4, 0, 0, 1_000_000), LocalDateTime.of(2027, 1, 1, 0, 0), LocalDateTime.of(2027, 1, 1, 4, 0),
            LocalDateTime.of(2024, 3, 1, 2, 0), LocalDateTime.of(2028, 3, 1, 3, 30), LocalDateTime.of(2026, 3, 1, 3, 59),
            LocalDateTime.of(2026, 1, 1, 0, 0), LocalDateTime.of(2026, 12, 31, 23, 59, 59), LocalDateTime.of(2026, 3, 29, 2, 30),
            LocalDateTime.of(2026, 10, 25, 2, 30), LocalDateTime.of(2000, 3, 1, 1, 0), LocalDateTime.of(1900, 3, 1, 1, 0),
        )
        return instants.map { linkedMapOf("civile" to civile(it), "milli" to it.nano / 1_000_000, "jour" to Store.jourTikkun(it)) }
    }

    private fun formats(): List<Map<String, Any?>> {
        val theatres = listOf("fr", "en", "he").map { it to Theatre(it) }
        val minutes = listOf(Int.MIN_VALUE, -1441, -61, -60, -59, -1, 0, 1, 9, 10, 59, 60, 61, 69, 70, 119, 120, 121, 599, 600,
            1439, 1440, 1441, 2879, 100_000, Int.MAX_VALUE)
        return minutes.map { m ->
            linkedMapOf<String, Any?>("minutes" to m, "formatMinutes" to Store.formatMinutes(m)).apply {
                theatres.forEach { (langue, t) -> put(langue, Store.formatDuration(t.contexte, m)) }
            }
        }
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursStore.kt"),
        "constantes" to linkedMapOf("noteMax" to Store.NOTE_MAX, "defaultTarget" to Store.DEFAULT_TARGET,
            "priereRepriseMs" to Store.PRIERE_REPRISE_MS, "clesLecture" to CLES_LECTURE),
        "scenarios" to scenarios.map { (nom, ops) -> rejoue(nom, ops) },
        "ensembles" to ensembles.map { s -> s.sorted().map { it.toString() } },
        "fenetre" to fenetres(),
        "reprises" to reprises(),
        "jourTikkun" to joursTikkun(),
        "formats" to formats(),
    )
}
