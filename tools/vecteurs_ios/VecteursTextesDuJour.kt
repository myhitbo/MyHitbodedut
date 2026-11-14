// Les textes du jour devant la JVM : la halakha du Ben Ish 'Haï (la paracha à venir), le Yalkout
// Yossef (périodes et Roch 'Hodech), les hilloulot (clés du jour, dates lisibles, rang dans l'année),
// la source du jour, la Méguila et Birkat haIlanot dans le siddour, les nombres en lettres, la forme
// sans voyelles de la recherche, et quelques recherches dans les trois livres.

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import com.myhitbodedut.Halakha
import com.myhitbodedut.Hilloulot
import com.myhitbodedut.LibraryLoader
import com.myhitbodedut.LibraryRules
import com.myhitbodedut.RechercheGlobale
import com.myhitbodedut.Reference
import com.myhitbodedut.SiddurMoment
import com.myhitbodedut.SourceDuJour
import com.myhitbodedut.YalkutYosef
import java.io.File
import java.time.LocalDate

object VecteursTextesDuJour : Generateur {
    override val fichier = "textes_du_jour.json"

    private val debut = LocalDate.of(2025, 9, 1)
    private val fin = LocalDate.of(2028, 9, 1)

    private val recherches = listOf(
        "ציצית", "שבת", "תפילין", "חנוכה", "בְּרָכָה", "צ", "א", "  ", "ה׳", "ר\"י", "כ״ה",
        "רבי", "צבי הירש חיות", "Moché", "moche", "Chelah", "Shelah", "Rabbi", "BAAL", "Ba'al",
    )

    private val textes = listOf(
        "", "  ", "Moché", "MOCHÉ  Rabbénou", "Birkot hacha’har", "l'‘homme’", "<b>gras</b> et <small>petit</small>",
        "בְּרֵאשִׁית בָּרָא", "מָה־אָשִׁיב", "ה׳ בכסלו", "ר\"י וְר' יוֹסֵי", "כ״ה בכסלו", "א׀ב",
        "\ta \n b\r\nc", "a b", " a ", "a b", "Ça, c'est l'été", "ÀÉÎÕÜ àéîõü ç",
        "שְׁמַע יִשְׂרָאֵל ה׳ אֱלֹהֵינוּ", "ﬁ", "Ⅻ", "é", "x<br/>y", "<", "a  b   c",
    )

    override fun produire(): Map<String, Any?> {
        fun lire(nom: String) = File(RES, "raw/$nom").readText()
        val halakha = Halakha.parse(lire("ben_ish_hai.json"))
        val yalkut = YalkutYosef.parse(lire("yalkut_yosef.json"))
        val hilloulot = Hilloulot.parse(lire("hilloulot.json"))
        val bibliotheque = LibraryLoader.parse(lire("bibliotheque.json"))
        val jours = generateSequence(debut) { it.plusDays(1) }.takeWhile { it.isBefore(fin) }.toList()

        fun halakhaDu(d: LocalDate, israel: Boolean): String {
            val cal = JewishCalendar(d).apply { setInIsrael(israel) }
            val parsha = cal.parshah.takeIf { it != JewishCalendar.Parsha.NONE } ?: cal.upcomingParshah
            val l = Halakha.pour(halakha, d, israel)
            return "${parsha.name}|" + l.joinToString(",") { "${it.annee}.${it.numero}" } + "|" +
                l.joinToString("/") { it.section }.hashCode()
        }

        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTextesDuJour.kt"),
            "debut" to debut.toString(),
            "nombre" to jours.size,
            // Par jour : la paracha du Chabbat qui vient, « année.numéro » de chaque halakha du jour et le
            // hashCode de leurs sections, hors d'Israël ; puis, séparé par une espace, ce qu'il en est en Israël
            // quand cela diffère.
            "halakha" to jours.map { d ->
                val diaspora = halakhaDu(d, false)
                val israel = halakhaDu(d, true)
                if (israel == diaspora) diaspora else "$diaspora $israel"
            },
            // Par jour : « période:rang » du Yalkout Yossef (hors d'Israël).
            "yalkut" to jours.map { d -> YalkutYosef.periode(d, false).let { (p, r) -> "$p:$r" } },
            // Par jour : les clés des hilloulot, puis celles des Ashkénazes.
            "hilloulot" to jours.map { d ->
                Hilloulot.clesPour(d, false).joinToString(",") + "|" + Hilloulot.clesPour(d, false, ashkenaz = true).joinToString(",")
            },
            // Quatre cents jours dès le 1er septembre 2026 : la source du jour et le rang de son paragraphe.
            "sourceDuJour" to jours.filter { !it.isBefore(LocalDate.of(2026, 9, 1)) }.take(400).map { d ->
                val p = SourceDuJour.choix(bibliotheque, d)!!
                "${p.source.id}:${LibraryRules.paragraphs(bibliotheque, p.source).indexOf(p.texte)}"
            },
            "candidats" to SourceDuJour.candidats(bibliotheque).size,
            "extraits" to listOf(
                "א".repeat(10) + " " + "ב".repeat(400),
                "un, deux; trois: " + "x".repeat(320),
                "court",
                "mot ".repeat(100),
                "a".repeat(320),
                "a".repeat(321),
                "abc def, ghi; " + "j".repeat(306) + " k",
            ).map { listOf(it, SourceDuJour.extrait(it)) },
            // Les jours de la Méguila (sous Cha'harit, sous Arvit ; ville ouverte, ville murée ; hors d'Israël, en Israël).
            "megila" to listOf("chaharit", "arvit").flatMap { moment ->
                listOf(false, true).flatMap { muree ->
                    listOf(false, true).map { israel ->
                        linkedMapOf("moment" to moment, "muree" to muree, "israel" to israel,
                            "jours" to jours.filter { SiddurMoment.megila(moment, it, israel, muree) }.map { it.toString() })
                    }
                }
            },
            // Les jours de Birkat haIlanot : sans latitude, à Jérusalem, à Melbourne.
            "ilanot" to listOf(null, 31.77, -37.81).map { lat ->
                linkedMapOf("latitude" to lat, "jours" to jours.filter { SiddurMoment.ilanot(it, lat) }.map { it.toString() })
            },
            "lettres" to (1..999).map { Reference.lettres(it) },
            // Chaque clé de hilloulot.json, dans l'ordre du fichier : sa date lisible et son rang dans l'année.
            "dates" to hilloulot.keys.map { listOf(it, Hilloulot.dateDe(it), Hilloulot.rangDansLAnnee(it)) },
            "nu" to textes.map { listOf(it, RechercheGlobale.nu(it)) },
            // Pour chaque recherche : le nombre de trouvailles et le hashCode de leur suite, dans les trois livres.
            "recherches" to recherches.map { q ->
                val h = Halakha.recherche(halakha, q)
                val y = YalkutYosef.recherche(yalkut, q)
                val r = Hilloulot.recherche(hilloulot, q)
                listOf(q,
                    h.size, h.joinToString("\n") { "${it.annee}/${it.section}/${it.numero}" }.hashCode(),
                    y.size, y.joinToString("\n") { "${it.siman}/${it.lettre}" }.hashCode(),
                    r.size, r.joinToString("\n") { "${it.first}/${it.second.he}" }.hashCode())
            },
        )
    }
}
