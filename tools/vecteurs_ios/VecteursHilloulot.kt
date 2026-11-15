// La hilloula du jour devant la JVM (Hilloulot.kt) : la table que lit Hilloulot.parse (une empreinte par
// jour), des tables d'essai, les clés de chaque mois (embolismique ou non, dernier jour, ashkenaz),
// clesPour et duJour chaque jour des années hébraïques 5786 (simple) et 5787 (embolismique), prochainJour,
// rangDansLAnnee, dateDe, embolismique contre KosherJava de 5700 à 5900, les liens, la recherche par nom
// et les biographies (avecBios, sur le vrai fichier et sur des fichiers d'essai).

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import com.kosherjava.zmanim.hebrewcalendar.JewishDate
import com.myhitbodedut.Hilloulot
import java.io.File
import java.time.LocalDate

object VecteursHilloulot : Generateur {
    override val fichier = "hilloulot.json"

    private val table: Map<String, List<Hilloulot.Hilloula>> = Hilloulot.parse(File(RES, "raw/hilloulot.json").readText())

    /** Une hilloula en une ligne : ses champs séparés par U+001F, null écrit U+0000. */
    private fun ligne(h: Hilloulot.Hilloula): String =
        listOf(h.he, h.fr, h.en, h.annee, h.sources, h.doute, h.description, h.article, h.hidabroot)
            .joinToString("\u001F") { it ?: "\u0000" }

    /** Une biographie en une ligne, de même. */
    private fun ligne(b: Hilloulot.Bio): String = listOf(b.source, b.texte, b.lien).joinToString("\u001F") { it ?: "\u0000" }

    /** L'empreinte d'une liste de lignes : jointes par un saut de ligne, puis String.hashCode(). */
    private fun empreinte(lignes: List<String>): Int = lignes.joinToString("\n").hashCode()

    /** Une table entière, champ par champ (les tables d'essai sont petites). */
    private fun ecrite(t: Map<String, List<Hilloulot.Hilloula>>): List<Any?> = t.entries.map { (cle, l) ->
        listOf(cle, l.map { h ->
            linkedMapOf("he" to h.he, "fr" to h.fr, "en" to h.en, "annee" to h.annee, "sources" to h.sources, "doute" to h.doute,
                "description" to h.description, "article" to h.article, "hidabroot" to h.hidabroot,
                "bios" to h.bios.map { listOf(it.source, it.texte, it.lien) })
        })
    }

    // --- La table et sa lecture --------------------------------------------------------------------

    private fun tableReelle(): Map<String, Any?> = linkedMapOf(
        "nombre" to table.size,
        "hilloulot" to table.values.sumOf { it.size },
        // Par jour, dans l'ordre du fichier : [clé, nombre de hilloulot, empreinte de leurs lignes].
        "jours" to table.entries.map { (cle, l) -> listOf(cle, l.size, empreinte(l.map(::ligne))) },
        "exemple" to ecrite(table.filterKeys { it == "7-30" }),
    )

    /** Des fichiers d'essai : ce que Json.nullable, optString et getString font des valeurs absentes, nulles, vides ou d'un autre type. */
    private val essaisLecture = listOf(
        """{"jours":{"7-1":[{"he":"א","fr":"","en":"  ","a":"x","s":"wh","d":null,"t":"desc","w":"art","i":"lien"}],"1-1":[]}}""",
        """{"jours":{"8-2":[{"he":5,"fr":7,"en":null,"a":null,"s":true}]}}""",
        """{"jours":{}}""",
        """{"jours":{"x":[{"he":"a"}]},"autre":1}""",
        """{"jours":{"7-1":[{"he":null}]}}""",
        """{"jours":{"7-1":[{"he":"a","fr":" ","en":"\u0085"}]}}""",
        """{"jours":{"7-1":[{"he":"a","fr":1.5,"en":10000000000,"d":false,"t":0}]}}""",
        """{"jours":{"7-1":[{"he":"a"}],"7-2":[{"he":"c"}],"7-1":[{"he":"b"}]}}""",
        """{"jours":{"7-1":[{"he":"בָּבָא סָאלִי","fr":"Baba Salé","en":"Baba Sali","a":"תשמ\"ד","s":"whml"}]}}""",
        """{"jours":[]}""",
        """{}""",
        """{"jours":{"7-1":{}}}""",
        """{"jours":{"7-1":[1]}}""",
        """{"jours":{"7-1":[{"fr":"x"}]}}""",
        """[]""",
        """pas du json""",
    )

    private fun lectures(): List<Any?> = essaisLecture.map { json ->
        val lu = runCatching { Hilloulot.parse(json) }
        linkedMapOf("json" to json, "exception" to lu.isFailure, "table" to lu.getOrNull()?.let(::ecrite))
    }

    // --- Les clés d'un jour hébreu -----------------------------------------------------------------

    private val booleens = listOf(false, true)

    /** [mois, jour, embolismique, dernierJour, ashkenaz, clés] : les mois de KosherJava et leurs voisins hors bornes. */
    private fun cles(): List<Any?> = (listOf(-1, 0) + (1..14)).flatMap { mois ->
        listOf(0, 1, 7, 29, 30).flatMap { jour ->
            booleens.flatMap { e -> booleens.flatMap { d -> booleens.map { a -> listOf(mois, jour, e, d, a, Hilloulot.cles(mois, jour, e, d, a)) } } }
        }
    }

    /**
     * Chaque jour du 1er Tichri 5786 au 29 Eloul 5787 : [jour, clés, nombre, empreinte de duJour] hors d'Israël,
     * et pour les Ashkénazes [clés, nombre, empreinte] quand leurs clés diffèrent. En Israël, les mêmes (vérifié ici).
     */
    private fun jours(): List<Any?> {
        val debut = JewishDate(5786, JewishDate.TISHREI, 1).localDate
        val fin = JewishDate(5788, JewishDate.TISHREI, 1).localDate
        return generateSequence(debut) { it.plusDays(1) }.takeWhile { it.isBefore(fin) }.map { d ->
            val c = Hilloulot.clesPour(d, false)
            val p = Hilloulot.pour(table, d, false)
            check(Hilloulot.clesPour(d, true) == c) { "en Israël, d'autres clés le $d" }
            check(p == Hilloulot.duJour(table, c)) { "pour ≠ duJour le $d" }
            val ligneJour = mutableListOf<Any?>(d.toString(), c, p.size, empreinte(p.map(::ligne)))
            val ca = Hilloulot.clesPour(d, false, ashkenaz = true)
            check(Hilloulot.clesPour(d, true, ashkenaz = true) == ca) { "en Israël, d'autres clés ashkénazes le $d" }
            if (ca != c) {
                val pa = Hilloulot.pour(table, d, false, ashkenaz = true)
                ligneJour.addAll(listOf(ca, pa.size, empreinte(pa.map(::ligne))))
            }
            ligneJour
        }.toList()
    }

    /** Le classement d'un jour sur une table d'essai : les cas du test, des clés absentes et répétées. */
    private val tableClassement = """{"jours":{"8-23":[{"he":"un","s":"m"},{"he":"doute","s":"wm","t":"x","d":"faux"},""" +
        """{"he":"trois","s":"hwm","t":"x"},{"he":"deux","s":"wm"},{"he":"deux-notice","s":"wm","t":"x"}],""" +
        """"8-24":[{"he":"d1","s":"","d":"x"},{"he":"d2","s":"whmlie","d":"x","t":"x"},{"he":"z","s":""},{"he":"y","s":"w","t":"x"}]}}"""

    private fun classements(): Map<String, Any?> {
        val t = Hilloulot.parse(tableClassement)
        return linkedMapOf("table" to tableClassement, "cas" to listOf(
            listOf("8-23"), listOf("8-24"), listOf("8-23", "8-24"), listOf("8-24", "8-23"), listOf("8-23", "x", "8-23"), emptyList(), listOf("x"),
        ).map { c -> listOf(c, Hilloulot.duJour(t, c).map { it.he }) })
    }

    // --- prochainJour, rangDansLAnnee, dateDe, embolismique ----------------------------------------

    private fun prochains(): List<Any?> = listOf(
        listOf("8-23", "2026-10-01", false, false), listOf("8-23", "2026-11-04", false, false),
        listOf("8-23", "2026-11-03", false, false), listOf("adar2-14", "2026-11-04", false, false),
        listOf("adar2-14", "2026-11-04", false, true), listOf("adar-14", "2026-11-04", false, false),
        listOf("adar-14", "2026-11-04", false, true), listOf("adar1-30", "2026-01-01", false, false),
        listOf("adar1-14", "2027-03-24", false, true), listOf("7-30", "2026-10-12", false, false),
        listOf("8-30", "2026-10-01", false, false), listOf("9-30", "2026-10-01", true, false),
        listOf("1-15", "2027-01-01", true, false), listOf("7-1", "2026-09-12", false, false),
        listOf("6-29", "2026-09-12", false, false), listOf("13-5", "2026-01-01", false, false),
        listOf("adar2-30", "2026-01-01", false, false), listOf("", "2026-01-01", false, false),
    ).map { (cle, depuis, israel, ashk) ->
        listOf(cle, depuis, israel, ashk,
            Hilloulot.prochainJour(cle as String, LocalDate.parse(depuis as String), israel as Boolean, ashk as Boolean)?.toString())
    }

    /** Des clés hors de la table : mois inconnus, nombres signés, débordements d'Int, tirets de trop. */
    private val clesBornes = listOf("7-1", "11-30", "adar1-1", "adar1-30", "adar-1", "adar-29", "adar2-1", "adar2-29", "1-1", "6-29",
        "13-5", "0-1", "14-2", "-5-3", "7-", "x-y", "+7-1", "adar3-1", "ADAR-1", "7-1-2", "2147483647-1", "7-2147483647",
        "07-01", " 7-1", "7- 1", "-1-1", "6-0", "12-31", "7--3", "-", "--")

    private fun rangs(): List<Any?> = (table.keys + clesBornes).map { listOf(it, Hilloulot.rangDansLAnnee(it)) }

    /** dateDe sur chaque clé de la table et des bornes de Reference.lettres ; une clé qui fait lever Kotlin écrit null. */
    private fun dates(): List<Any?> = (table.keys + listOf("7-0", "7-15", "7-16", "7-270", "7-275", "7-298", "7-304", "7-344",
        "7-499", "7-999", "7-1000", "7-+5", "7--3", "xx-3", "adar-14", "adar1-29", "adar2-7", "8-x", "7-1-2", "13-1"))
        .map { listOf(it, runCatching { Hilloulot.dateDe(it) }.getOrNull()) }

    private fun meton(): Map<String, Any?> = linkedMapOf(
        "kosherJava" to (5700..5900).map { a -> listOf(a, Hilloulot.embolismique(a), JewishCalendar(a, JewishCalendar.TISHREI, 1).isJewishLeapYear) },
        "bornes" to listOf(0, 1, -1, -19, 19, 3, 6, 8, 11, 14, 17, 5786, 5787, 306_783_378, 306_783_379, 2_000_000_000,
            Int.MAX_VALUE, Int.MIN_VALUE, -2_000_000_000).map { listOf(it, Hilloulot.embolismique(it)) },
    )

    // --- Les liens ---------------------------------------------------------------------------------

    private fun liens(): Map<String, Any?> {
        val articles = table.values.flatten().mapNotNull { it.article }
        return linkedMapOf(
            "hyomi" to listOf("2026-10-11", "2000-01-01", "1999-12-31", "2024-02-29", "2026-01-05", "2099-12-31")
                .map { listOf(it, Hilloulot.lienHyomi(LocalDate.parse(it))) },
            "halakha" to listOf("iw", "he", "HE", "he-IL", "iw-IL", "en", "EN", "en-US", "eng", "fr", "FR", "fr-CA", "es", "",
                "de", "h", "e", "iwx", "ar", "En", "hE").map { listOf(it, Hilloulot.lienHalakha(it)) },
            "articles" to listOf("Rabbi Nachman", "a b", "a+b", "a&b=c", "שלום עליכם", "~!*().-_'", "é", "😀", "a\tb", "100%",
                "", " ", "רבי ישראל אבוחצירא (הבאבא סאלי)", "ר' נחמן", "A-Z_a.z*0", "/?#[]@").map { listOf(it, Hilloulot.lienArticle(it)) },
            "table" to linkedMapOf("nombre" to articles.size, "empreinte" to empreinte(articles.map(Hilloulot::lienArticle)),
                "premiers" to articles.take(20).map { listOf(it, Hilloulot.lienArticle(it)) }),
        )
    }

    // --- La recherche ------------------------------------------------------------------------------

    private val requetes = listOf("צבי הירש חיות", "א", "Chelah", "Shelah", "Moché", "moche", "MOCHE", "רבי", "בעל שם טוב",
        "האר\"י", "האריז\"ל", "רבי נחמן", "Nachman", "NACHMAN", "Baal", "ab", "  ", "", "רמב\"ם", "רמב״ם", "חיד\"א", "ָ",
        "בָּבָא סָאלִי", "באבא סאלי", "Rabbi", "rabbi", "Rav", "גאון", "zz", "יוסף", "Yossef", "Joseph", "Ari", "chaim", "Haïm",
        "Ḥayyim", " רבי ", "ר'", "תשמ", "ben", "Rabbénou", "l’Ari", "<b>רבי</b>", "שלמה־זלמן", "ה")

    private fun recherches(): List<Any?> = requetes.map { q ->
        val r = Hilloulot.recherche(table, q)
        linkedMapOf("q" to q, "nombre" to r.size, "empreinte" to empreinte(r.map { (cle, h) -> cle + "\u001F" + ligne(h) }),
            "premiers" to r.take(5).map { (cle, h) -> listOf(cle, h.he) })
    }

    // --- Les biographies ---------------------------------------------------------------------------

    private fun bios(): Map<String, Any?> {
        val complete = Hilloulot.avecBios(table, File(RES, "raw/hilloulot_bios.json").readText())
        return linkedMapOf(
            "nombre" to complete.values.sumOf { l -> l.sumOf { it.bios.size } },
            // Par jour : [clé, nombre de biographies, empreinte de « rang de la hilloula U+001F ligne de la biographie »].
            "jours" to complete.entries.map { (cle, l) ->
                val lignes = l.flatMapIndexed { i, h -> h.bios.map { "$i\u001F" + ligne(it) } }
                listOf(cle, lignes.size, empreinte(lignes))
            },
        )
    }

    private val tableBios = """{"jours":{"7-1":[{"he":"a"},{"he":"b"},{"he":"c"}],"8-2":[{"he":"d"}]}}"""

    private val essaisBios = listOf(
        """{"7-1":[[["m","texte","https://x"]],0,[["l","t2",""],["m",5,null]]],"9-9":[[["m","x","y"]]]}""",
        """{"7-1":"x"}""",
        """{"7-1":[[["m"]]]}""",
        """{"7-1":[[5]]}""",
        """{"7-1":[[[]]]}""",
        """{"7-1":[[]]}""",
        """{"7-1":[[["m","t"]]]}""",
        """{"7-1":[[["m","t","  "]]],"8-2":[[["l","u"," "]]]}""",
        """[]""",
        """{"7-1":[[[null,true,1.5]]]}""",
        """{"7-1":[[["m","t","u"]],[["m","t","u"]],[["m","t","u"]],[["m","t","u"]]]}""",
        """{}""",
        """{"8-2":[[["m","מָה טֹבוּ","https://exemple.org/א"],["l","ב","https://b"]]]}""",
    )

    private fun biosEssais(): Map<String, Any?> {
        val t = Hilloulot.parse(tableBios)
        return linkedMapOf("table" to tableBios, "cas" to essaisBios.map { json ->
            val r = runCatching { Hilloulot.avecBios(t, json) }
            linkedMapOf("json" to json, "exception" to r.isFailure, "table" to r.getOrNull()?.let(::ecrite))
        })
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursHilloulot.kt"),
        "table" to tableReelle(),
        "lectures" to lectures(),
        "cles" to cles(),
        "jours" to jours(),
        "classements" to classements(),
        "prochains" to prochains(),
        "rangs" to rangs(),
        "dates" to dates(),
        "meton" to meton(),
        "liens" to liens(),
        "recherches" to recherches(),
        "bios" to bios(),
        "biosEssais" to biosEssais(),
    )
}
