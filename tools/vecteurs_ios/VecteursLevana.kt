// Birkat haLevana (Levana.kt) devant la JVM : le molad de KosherJava et ses quatre heures, les
// fenêtres des trois usages avec la restriction de Tichri et d'Av, le soir retenu dans trois fuseaux,
// l'état du jour et le motsaé Chabbat conseillé ; la phase de la lune et la place d'un instant dans le mois.

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import com.myhitbodedut.Levana
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

object VecteursLevana : Generateur {
    override val fichier = "levana.json"

    private val jerusalem = ZoneId.of("Asia/Jerusalem")
    private val usages = Levana.Usage.entries

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursLevana.kt", "usages" to usages.map { it.cle }),
        // Un mois hébreu par ligne, de Tichri 5780 à Av 5800, lu le 2 du mois : le jour civil, l'année et le
        // mois (KosherJava) ; le molad, le début à trois et à sept jours, la fin à quinze jours et à la
        // mi-mois (millisecondes Unix) ; puis, à Jérusalem et pour chaque usage, le début de la fenêtre de
        // Levana.fenetre et sa restriction (sa fin est l'une des deux de KosherJava).
        "mois" to mois(),
        // Du 1er septembre 2026 au 30 septembre 2027 à Jérusalem : chaque jour dans l'usage par défaut, un
        // jour sur trois dans les deux autres ; à Paris et à New York, un jour sur quatre dans l'usage par défaut :
        // « jour|usage|fuseau|restriction|premier soir|dernier soir|état|motsaé Chabbat ».
        "jours" to jours(),
        // La lune toutes les douze heures, soixante jours durant : instant, part éclairée, croissante.
        "phases" to (0 until 120).map { k ->
            val t = Instant.parse("2026-10-01T00:00:00Z").plusSeconds(k * 43_200L)
            val l = Levana.phase(t)
            listOf(t.toEpochMilli(), l.eclairage, l.croissante)
        },
        // La place d'un instant dans la fenêtre de 'Hechvan 5787 (usage par défaut, Jérusalem), de deux
        // jours avant le molad à deux jours après le suivant.
        "parts" to Levana.fenetre(LocalDate.of(2026, 10, 14), jerusalem).let { f ->
            (-2..32).map { k ->
                val t = f.molad.plusSeconds(k * 86_400L + 3_600L)
                listOf(t.toEpochMilli(), Levana.part(f, t).toDouble())
            }
        },
    )

    private fun mois(): List<Any?> {
        val lignes = mutableListOf<Any?>()
        var d = LocalDate.of(2019, 10, 1) // 2 Tichri 5780
        while (d.isBefore(LocalDate.of(2040, 8, 20))) {
            val c = JewishCalendar(d)
            if (c.jewishDayOfMonth == 2) {
                lignes.add(listOf<Any?>(
                    d.toString(), c.jewishYear, c.jewishMonth,
                    c.moladAsDate.time, c.tchilasZmanKidushLevana3Days.time, c.tchilasZmanKidushLevana7Days.time,
                    c.sofZmanKidushLevana15Days.time, c.sofZmanKidushLevanaBetweenMoldos.time,
                ) + usages.flatMap { u ->
                    val f = Levana.fenetre(d, jerusalem, u)
                    check(f.fin == (if (u.quinzeJours) c.sofZmanKidushLevana15Days else c.sofZmanKidushLevanaBetweenMoldos).toInstant())
                    listOf(f.debut.toEpochMilli(), f.restriction?.name)
                })
            }
            d = d.plusDays(1)
        }
        return lignes
    }

    private fun jours(): List<String> {
        val lignes = mutableListOf<String>()
        fun ligne(d: LocalDate, u: Levana.Usage, zone: ZoneId) {
            val f = Levana.fenetre(d, zone, u)
            val etat = when (val e = Levana.etat(f, d, zone)) {
                is Levana.Etat.Dans -> "D${e.jours}"
                Levana.Etat.CeSoir -> "C"
                Levana.Etat.DernierSoir -> "L"
            }
            lignes += listOf(d, u.cle, zone.id, f.restriction?.name ?: "-", f.premierSoir(zone), f.dernierSoir(zone), etat,
                Levana.motsaeChabbat(f, d, zone) ?: "-").joinToString("|")
        }
        var d = LocalDate.of(2026, 9, 1)
        var i = 0
        while (!d.isAfter(LocalDate.of(2027, 9, 30))) {
            ligne(d, Levana.Usage.SEPT_MI_MOIS, jerusalem)
            if (i % 3 == 0) listOf(Levana.Usage.TROIS_MI_MOIS, Levana.Usage.SEPT_QUINZE).forEach { ligne(d, it, jerusalem) }
            if (i % 4 == 0) listOf("Europe/Paris", "America/New_York").forEach { ligne(d, Levana.Usage.SEPT_MI_MOIS, ZoneId.of(it)) }
            d = d.plusDays(1)
            i++
        }
        return lignes
    }
}
