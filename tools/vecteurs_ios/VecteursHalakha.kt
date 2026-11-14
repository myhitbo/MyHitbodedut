// Le Ben Ish 'Haï du jour devant la JVM (Halakha.kt, et la source qu'affiche HalakhaActivity) : le
// livre que lit Halakha.parse (une empreinte par section, pas le texte), les halakhot de chaque jour
// des années hébraïques 5786 à 5788 hors d'Israël et en Israël, les sections de chaque paracha de
// KosherJava (jointes et spéciales comprises) dans les deux années du livre et dans des livres
// d'essai, part, anneeDuLivre, choix, la recherche et la source.

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import com.kosherjava.zmanim.hebrewcalendar.JewishDate
import com.myhitbodedut.Halakha
import com.myhitbodedut.HalakhaActivity
import java.io.File
import java.time.LocalDate

object VecteursHalakha : Generateur {
    override val fichier = "halakha.json"

    private val livre: Halakha.Livre = Halakha.parse(File(RES, "raw/ben_ish_hai.json").readText())

    /** Les noms des sections dans l'ordre du livre (année 1, année 2, 'Hanouka) : les vecteurs les citent par leur rang. */
    private val noms: List<String> =
        (livre.annees.values.flatMap { secs -> secs.values.map { it.he } } + listOfNotNull(livre.hanouka?.he)).distinct()

    private fun rang(he: String): Int = noms.indexOf(he).also { check(it >= 0) { "section inconnue : $he" } }

    /** L'empreinte d'une liste de textes : joints par un saut de ligne, puis String.hashCode(). */
    private fun empreinte(textes: List<String>): Int = textes.joinToString("\n").hashCode()

    /** Des halakhot choisies : [numéro, rang du nom de leur section, année du livre] chacune, et l'empreinte de leurs textes. */
    private fun choisies(liste: List<Halakha.Choisie>): LinkedHashMap<String, Any?> = linkedMapOf(
        "choix" to liste.map { listOf(it.numero, rang(it.section), it.annee) },
        "texte" to empreinte(liste.map { it.texte }),
    )

    // --- Le jour -----------------------------------------------------------------------------------

    /** La paracha que Halakha.pour donne au livre : celle du Chabbat, sinon celle du Chabbat qui vient. */
    private fun parsha(d: LocalDate, enIsrael: Boolean): String {
        val cal = JewishCalendar(d).apply { setInIsrael(enIsrael) }
        return (cal.parshah.takeIf { it != JewishCalendar.Parsha.NONE } ?: cal.upcomingParshah).name
    }

    /** Les jours des années hébraïques 5786 à 5788 (du 23 septembre 2025 au 20 septembre 2028). */
    private val jours: List<LocalDate> = generateSequence(JewishDate(5786, JewishDate.TISHREI, 1).localDate) { it.plusDays(1) }
        .takeWhile { it.isBefore(JewishDate(5789, JewishDate.TISHREI, 1).localDate) }.toList()

    private fun jour(d: LocalDate): Map<String, Any?> {
        val hors = Halakha.pour(livre, d, false)
        val israel = Halakha.pour(livre, d, true)
        val cas = linkedMapOf<String, Any?>("jour" to d.toString(), "parsha" to parsha(d, false))
        cas.putAll(choisies(hors))
        // En Israël, seulement ce qui diffère : les semaines où la lecture d'Israël a un Chabbat d'avance.
        if (israel != hors || parsha(d, true) != parsha(d, false)) {
            cas["israel"] = linkedMapOf<String, Any?>("parsha" to parsha(d, true)).apply { putAll(choisies(israel)) }
        }
        return cas
    }

    // --- Les sections ------------------------------------------------------------------------------

    /** Toutes les parachiot de KosherJava, NONE et les Chabbatot spéciaux compris. */
    private val parachiot: List<String> = JewishCalendar.Parsha.values().map { it.name }

    /** Ce que rend Halakha.sections : null, ou chaque part (section, indice de départ, nombre, empreinte des halakhot). */
    private fun sections(annee: Map<String, Halakha.Section>, parsha: String): List<Map<String, Any?>>? =
        Halakha.sections(annee, parsha)?.map { (s, depart, l) ->
            linkedMapOf("section" to s.he, "depart" to depart, "nombre" to l.size, "empreinte" to empreinte(l))
        }

    private fun section(he: String, n: Int) = Halakha.Section(he, (1..n).map { "$he $it" })

    /** Des années d'essai : vide, une jointe de 0, 1, 2 ou 5 halakhot, une part seule, les parts et la jointe ensemble… */
    private val essais: List<Map<String, Halakha.Section>> = listOf(
        emptyMap(),
        mapOf("TAZRIA_METZORA" to section("tm", 0)),
        mapOf("TAZRIA_METZORA" to section("tm", 1)),
        mapOf("TAZRIA_METZORA" to section("tm", 2)),
        mapOf("TAZRIA_METZORA" to section("tm", 5)),
        mapOf("TAZRIA" to section("t", 3)),
        mapOf("METZORA" to section("m", 4)),
        mapOf("TAZRIA" to section("t", 3), "METZORA" to section("m", 4), "TAZRIA_METZORA" to section("tm", 6)),
        mapOf("NITZAVIM_VAYEILECH" to section("nv", 7), "VAYEILECH" to section("v", 2)),
        mapOf("BEHAR_BECHUKOSAI" to section("bb", 9), "ACHREI_MOS" to section("a", 0)),
        mapOf("MATOS" to section("mt", 1), "MASEI" to section("ms", 0), "CHUKAS_BALAK" to section("cb", 3)),
        mapOf("BERESHIS" to section("b", 4), "SHKALIM" to section("s", 1)),
    )

    private val parachiotEssai: List<String> =
        Halakha.JOINTES.flatMap { (jointe, parts) -> listOf(jointe) + parts } + listOf("BERESHIS", "SHKALIM", "NONE", "", "XYZ")

    // --- Le choix ----------------------------------------------------------------------------------

    private val parachiotChoix = listOf("BERESHIS", "LECH_LECHA", "TAZRIA", "METZORA", "TAZRIA_METZORA", "ACHREI_MOS",
        "KEDOSHIM", "VAYAKHEL_PEKUDEI", "NITZAVIM", "VAYEILECH", "NITZAVIM_VAYEILECH", "BAMIDBAR", "DEVARIM",
        "VZOS_HABERACHA", "HAAZINU", "NONE", "SHKALIM", "", "XYZ")

    private fun choix(parsha: String, jour: Int, annee: Int, hanouka: Int): Map<String, Any?> =
        linkedMapOf<String, Any?>("parsha" to parsha, "jour" to jour, "annee" to annee, "hanouka" to hanouka)
            .apply { putAll(choisies(Halakha.choix(livre, parsha, jour, annee, hanouka))) }

    // --- La recherche ------------------------------------------------------------------------------

    /**
     * Les recherches des tests, puis des blancs, des voyelles, des te'amim, le sof passouk, des guillemets
     * (ASCII, guershayim, guéresh), le maqaf et le paseq, une lettre seule, une forme de présentation,
     * des mots fréquents et rares, du latin, des chiffres, un émoji.
     */
    private val requetes: List<String> = listOf(
        "ציצית", "צ",
        "", " ", "\t\n", "ציצית ", "  ציצית\n", " ציצית ", "　ציצית",
        "צִיצִית", "צִיצִ֑ית", "ְִ",
        "תפילין", "תְּפִלִּין", "שבת", "שַׁבָּת", "שבת׃", "שׁבת",
        "ק\"ש", "ק״ש", "ק'ש", "ה'", "ה׳", "ה״", "\"", "״׳", "'ה'", "\"שבת\"",
        "בית־הכנסת", "בית הכנסת", "בֵּית־הַכְּנֶסֶת", "־", "־ש־",
        "׀", "ש׀ב", "על־ידי",
        "ראש חודש", "חנוכה", "נר חנוכה", "פורים", "ברכה", "ברוך", "יין", "מצה", "סוכה", "לולב", "תשעה באב",
        "הלכות", "סימן", "סימן א", "אל", "של", "ו", "וְ", "abc", "Shabbat", "12", "😀",
    )

    private fun recherche(q: String): Map<String, Any?> {
        val r = Halakha.recherche(livre, q)
        return linkedMapOf(
            "requete" to q,
            "nombre" to r.size,
            "empreinte" to r.joinToString("\n") { "${it.annee}|${it.section}|${it.numero}|${it.texte.hashCode()}" }.hashCode(),
            "premiers" to r.take(3).map { listOf(it.numero, rang(it.section), it.annee) },
        )
    }

    // --- La source ---------------------------------------------------------------------------------

    private val numeros = listOf(1, 2, 9, 10, 11, 14, 15, 16, 17, 19, 20, 21, 30, 99, 100, 270, 275, 400, 999, 1000, 0, -1)

    private val anneesSource = listOf(1 to "לך לך", 2 to "תזריע", 0 to "", 3 to "הלכות חנוכה")

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursHalakha.kt", "livre" to "android/app/src/main/res/raw/ben_ish_hai.json"),
        "noms" to noms,
        // Le livre lu : chaque année et ses sections dans l'ordre du fichier, 'Hanouka.
        "annees" to livre.annees.map { (a, secs) ->
            linkedMapOf("annee" to a, "sections" to secs.map { (p, s) ->
                linkedMapOf("paracha" to p, "section" to s.he, "nombre" to s.halakhot.size, "empreinte" to empreinte(s.halakhot))
            })
        },
        "hanouka" to livre.hanouka?.let { linkedMapOf("section" to it.he, "nombre" to it.halakhot.size, "empreinte" to empreinte(it.halakhot)) },
        // Halakha.pour, chaque jour de trois années hébraïques.
        "pour" to jours.map(::jour),
        // Halakha.sections pour chaque paracha, dans les deux années du livre.
        "sections" to listOf("1", "2").flatMap { a ->
            val annee = livre.annees[a].orEmpty()
            parachiot.map { p -> linkedMapOf("annee" to a, "parsha" to p, "parts" to sections(annee, p)) }
        },
        // … et dans des années d'essai.
        "sectionsEssai" to essais.map { annee ->
            linkedMapOf(
                "livre" to annee.map { (p, s) -> linkedMapOf("paracha" to p, "section" to s.he, "halakhot" to s.halakhot) },
                "resultats" to parachiotEssai.map { p -> linkedMapOf("parsha" to p, "parts" to sections(annee, p)) },
            )
        },
        // Halakha.part : [0, n[ sur `parts` jours ; au-delà des parts seulement quand la liste est courte (sinon Kotlin lève).
        "part" to (0..16).flatMap { n ->
            listOf(1, 2, 3, 7, 8).map { parts ->
                val items = (0 until n).toList()
                val jours = if (n < parts) 0..(2 * parts) else 0 until parts
                linkedMapOf("n" to n, "parts" to parts, "jours" to jours.map { Halakha.part(items, it, parts) })
            }
        },
        "anneeDuLivre" to (listOf(Int.MIN_VALUE, -3, -2, -1, 0, 1, 2, 3) + (5780..5800) + listOf(Int.MAX_VALUE))
            .map { listOf(it, Halakha.anneeDuLivre(it)) },
        // Halakha.choix : des parachiot simples, jointes, séparées, absentes ou inconnues, chaque jour de la semaine,
        // une année impaire et une paire ; puis 'Hanouka, du jour −1 au jour 9.
        "choix" to parachiotChoix.flatMap { p -> listOf(5786, 5787).flatMap { a -> (0..6).map { j -> choix(p, j, a, 0) } } } +
            (-1..9).map { h -> choix("VAYESHEV", 0, 5787, h) },
        "recherche" to requetes.map(::recherche),
        // HalakhaActivity.source (recopiée mot pour mot dans les bouchons).
        "source" to anneesSource.flatMap { (a, s) ->
            numeros.map { n ->
                linkedMapOf("annee" to a, "section" to s, "numero" to n, "source" to HalakhaActivity.source(Halakha.Choisie("…", n, s, a)))
            }
        },
    )
}
