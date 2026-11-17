// Les chronologies des vignettes des zmanim devant la JVM : ce que la vignette d'Android montrerait
// (ZmanimVignette.vues) à des instants pris dans une journée entière, pour cinq lieux et six dates (les deux
// changements d'heure, Israël compris, le jour et la nuit polaires à Tromsø, la veille de Roch Hachana) :
// la prière du moment et la clé de sa limite (ZmanimWidget.prochaine), la date dont le jour hébreu est montré
// (ZmanimVignette.jourHebreuAffiche, qui bascule à tsét), la journée de la grande vignette (aujourd'hui, ou demain
// une fois la nuit tombée) et l'indice du prochain zman, la date hébraïque et la pastille (fête ou paracha). Les
// instants : toutes les demi-heures depuis minuit, chaque zman du jour, une milliseconde avant chacun, et le milieu
// de la nuit d'hier tel que ZmanimWidget.prochaine le compte. ChronologiesTests de Coeur rejoue tout avec les
// zmanim écrits ici (KosherJava), sans rien recalculer.
//
// La journée de la grande vignette et son prochain zman sont calculés dans vues(), qui dessine : ces quatre lignes
// sont recopiées ici (« journee »), le reste est le vrai code d'Android.

import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.Libelles
import com.myhitbodedut.Zmanim
import com.myhitbodedut.ZmanimVignette
import com.myhitbodedut.ZmanimWidget
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.TemporalAdjusters

object VecteursChronologies : Generateur {
    override val fichier = "chronologies.json"

    private const val MINUTE = 60_000L

    private val LIEUX = listOf(
        Zmanim.Lieu("Jérusalem", 31.76904, 35.21633, 0.0, "Asia/Jerusalem") to true,
        Zmanim.Lieu("Paris", 48.85341, 2.3488, 0.0, "Europe/Paris") to false,
        Zmanim.Lieu("New York", 40.71427, -74.00597, 0.0, "America/New_York") to false,
        Zmanim.Lieu("Melbourne", -37.814, 144.96332, 0.0, "Australia/Melbourne") to false,
        Zmanim.Lieu("Tromsø", 69.6492, 18.9553, 0.0, "Europe/Oslo") to false,
    )
    private val DATES = listOf("2026-03-27", "2026-03-29", "2026-06-21", "2026-09-11", "2026-10-25", "2026-12-21").map(LocalDate::parse)

    private fun millis(z: ZonedDateTime): Long = z.toInstant().toEpochMilli()

    private fun horaires(lieu: Zmanim.Lieu, d: LocalDate): Map<String, ZonedDateTime?> =
        Zmanim.jour(lieu, d).associate { it.cle to it.local }

    private fun ecrites(h: Map<String, ZonedDateTime?>): Map<String, Long> =
        linkedMapOf<String, Long>().apply { h.forEach { (k, v) -> if (v != null) put(k, millis(v)) } }

    /** D'où vient la limite : sa clé, « veille » (le milieu de la nuit d'hier), ou rien. */
    private fun cleDe(limite: ZonedDateTime?, h: Map<String, ZonedDateTime?>): String? {
        if (limite == null) return null
        val cles = listOf("szt_gra", "chkia", "chatsot_layla").filter { h[it] == limite } +
            listOfNotNull("veille".takeIf { h["chatsot_layla"]?.minusDays(1) == limite })
        check(cles.size == 1) { "limite ambiguë : $limite, $cles" }
        return cles.single()
    }

    /** La date hébraïque et la pastille d'une date (ZmanimVignette.vues). */
    private fun hebreu(d: LocalDate, israel: Boolean): Map<String, Any?> {
        val jour = CalendrierJuif.jour(d, israel)
        val fete = jour.fetes.firstNotNullOfOrNull { Libelles.res(it) }?.let { Identifiants.entree(it) }
        val paracha = CalendrierJuif.jour(d.with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY)), israel).paracha
        return linkedMapOf("date" to jour.dateHebraique, "fete" to fete, "paracha" to paracha)
    }

    private fun journee(lieu: Zmanim.Lieu, h: Map<String, ZonedDateTime?>, d: LocalDate, maintenant: ZonedDateTime): Pair<Boolean, Int> {
        // ZmanimVignette.vues : la journée d'aujourd'hui, ou de demain une fois la nuit tombée.
        var journee = ZmanimVignette.JOURNEE.mapNotNull { k -> h[k]?.let { k to it } }
        var demain = false
        if (journee.none { it.second.isAfter(maintenant) }) {
            val h2 = horaires(lieu, d.plusDays(1))
            journee = ZmanimVignette.JOURNEE.mapNotNull { k -> h2[k]?.let { k to it } }
            demain = true
        }
        return demain to journee.indexOfFirst { it.second.isAfter(maintenant) }
    }

    private fun jour(lieu: Zmanim.Lieu, israel: Boolean, d: LocalDate): Map<String, Any?> {
        val zone = ZoneId.of(lieu.fuseau)
        val h = horaires(lieu, d)
        val debut = millis(d.atStartOfDay(zone))
        val fin = millis(d.plusDays(1).atStartOfDay(zone))
        val instants = sortedSetOf<Long>()
        var t = debut
        while (t < fin) { instants += t; t += 30 * MINUTE }
        val reperes = h.values.filterNotNull().map(::millis) + listOfNotNull(h["chatsot_layla"]?.minusDays(1)?.let(::millis))
        for (r in reperes) if (r in debut until fin) { instants += r; if (r - 1 >= debut) instants += r - 1 }
        val dates = sortedMapOf<String, Map<String, Any?>>()
        val reponses = instants.map { ms ->
            val maintenant = Instant.ofEpochMilli(ms).atZone(zone)
            val (priere, limite, debut) = ZmanimWidget.prochaine(h, maintenant)
            val jourHebreu = ZmanimVignette.jourHebreuAffiche(maintenant, h["tset"])
            dates.getOrPut(jourHebreu.toString()) { hebreu(jourHebreu, israel) }
            val (demain, prochain) = journee(lieu, h, d, maintenant)
            // Le début d'une Min'ha pas encore ouverte (FVOL-05) : son instant, ou null.
            listOf(ms, priere, cleDe(limite, h), jourHebreu.toString(), demain, prochain, debut?.let(::millis))
        }
        return linkedMapOf(
            "lieu" to lieu.nom, "latitude" to lieu.latitude, "longitude" to lieu.longitude, "fuseau" to lieu.fuseau,
            "israel" to israel, "jour" to d.toString(),
            "horaires" to ecrites(h), "demain" to ecrites(horaires(lieu, d.plusDays(1))),
            "veille" to h["chatsot_layla"]?.minusDays(1)?.let(::millis),
            "hebreu" to dates, "reponses" to reponses,
        )
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to linkedMapOf("source" to "tools/vecteurs_ios/VecteursChronologies.kt", "journee" to ZmanimVignette.JOURNEE),
        "jours" to LIEUX.flatMap { (lieu, israel) -> DATES.map { d -> jour(lieu, israel, d) } },
    )
}
