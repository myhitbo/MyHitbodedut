// Aeration.kt et MarquesPages.kt devant la JVM : l'aération d'un paragraphe (coupe aux fins de phrase,
// premier mot en gras, psaumes laissés entiers) sur les cas d'AerationTest, sur des seuils construits à
// la lettre près et sur des paragraphes entiers du siddour et des livres ; puis, pour tout le siddour
// Edot HaMizra'h et deux livres, une empreinte par paragraphe. Les marque-pages : aperçu, écriture et
// lecture du texte enregistré (lignes mal formées comprises), bascule et limite de 60, tri par texte.

import com.myhitbodedut.Aeration
import com.myhitbodedut.MarquesPages
import org.json.JSONObject
import java.io.File

object VecteursTexte : Generateur {
    override val fichier = "texte.json"

    private val balise = Regex("<[^>]+>")

    private fun visible(html: String): Int = html.replace(balise, "").length

    /** Les paragraphes d'un fichier de textes (siddour ou livre) : le champ « t » de chaque bloc, dans l'ordre. */
    private fun paragraphes(nom: String): List<String> {
        val textes = JSONObject(File(RES, "raw/$nom.json").readText()).getJSONArray("textes")
        val sortie = mutableListOf<String>()
        for (i in 0 until textes.length()) {
            val sections = textes.getJSONObject(i).getJSONArray("sections")
            for (j in 0 until sections.length()) {
                val blocs = sections.getJSONObject(j).getJSONArray("blocs")
                for (k in 0 until blocs.length()) {
                    val bloc = blocs.getJSONObject(k)
                    if (bloc.has("t")) sortie.add(bloc.getString("t"))
                }
            }
        }
        return sortie
    }

    /** Un texte rendu : sa longueur en unités UTF-16, son hashCode, et le texte lui-même s'il est court. */
    private fun rendu(s: String, entier: Boolean = false): Map<String, Any?> =
        linkedMapOf("n" to s.length, "h" to s.hashCode(), "t" to if (entier || s.length <= 200) s else null)

    /** Tout ce que l'aération rend d'un paragraphe ; `aereEntier` : « aerer » rendu en entier, `toutEntier` : tout. */
    private fun aeration(html: String, aereEntier: Boolean = false, toutEntier: Boolean = false): Map<String, Any?> {
        val coupe = Aeration.couper(html)
        val aere = Aeration.aerer(html)
        return linkedMapOf(
            "html" to html,
            "visibles" to visible(html),
            "psaume" to Aeration.psaume(html),
            "premierMot" to rendu(Aeration.premierMot(html), toutEntier),
            "couper" to rendu(coupe, toutEntier),
            "morceaux" to coupe.split("<br><br>").size,
            "aerer" to rendu(aere, aereEntier || toutEntier),
        )
    }

    // --- Les cas construits ----------------------------------------------------------------------

    private val phrase = "אבגד ".repeat(60).trim()
    private val verset = "אֱֽלֹהִ֗ים יְחׇנֵּ֥נוּ וִיבָרְכֵ֑נוּ ".repeat(12).trim()

    /** Les cas d'AerationTest, à l'identique. */
    private val casDuTest: List<String> = listOf(
        "בָּרוּךְ אַתָּה",
        "<b>מוֹדֶה אֲנִי</b> לְפָנֶיךָ",
        "<small>בשבת:</small> רְצֵה",
        "(בעשי״ת) זָכְרֵנוּ",
        "א".repeat(300) + ": " + "ב".repeat(100),
        "$phrase: $phrase: <small>${"ה".repeat(260)}: ${"ו".repeat(20)}</small> $phrase",
        "<b>לַמְנַצֵּ֥חַ</b> $verset׃ $verset׃ $verset׃",
        "<b>מִזְמוֹר</b> לְדָוִד: $phrase: $phrase",
        "$phrase: $phrase",
    )

    /** Le premier mot : ce qui le termine, ce qui l'empêche, les lettres qu'il admet. */
    private val premiersMots: List<String> = listOf(
        "", " ", "א", "אב", "אב ", " אב", "אב,ג", "אב:ג", "אב;ג", "אב.ג", "אב\tג", "אב\nג", "אב\rג", "אב\u000Bג",
        "אב\u000Cג", "אב ג", "אב ", "אב ג", "אב\u0085", "אב)ג", "אב!ג", "אב?", "אב-גד הו", "אב־גד הו",
        "אב\"ג ד", "אב'ג ד", "רש״י אומר", "ה׳ אלהינו", "\"אב\" ג", "-אב ג", "שָׁלוֹם עֲלֵיכֶם", "ﬠﬡ ﬢ", "אבabc ד",
        "abc def", "1 אב", "<b>אב</b> ג", "<B>אב</B> ג", " <b>אב</b>", "<small>אב</small> ג", "<br>אב ג", "(אב) ג",
        "[אב] ג", "״אב״ ג", "אב״", "׳", "-", "\"", "'", "אב׃ ג", "אב׀ ג", "־אב ג", "יִאב ג",
        "אבﭏﭐ ג", "מִזְמוֹר לְדָוִד",
    )

    /** Les psaumes : té'amim (un pour deux mots suffit), ouvertures, et ce qui les défait. */
    private val psaumes: List<String> = listOf(
        "", " ", "<b></b>", "מזמור", "מזמור ", "מזמור:", "מזמור,", "מזמור לדוד", "מזמורים לדוד", "למנצח בנגינות", "לדוד ה׳",
        "שיר המעלות", "שירה", "תהלה לדוד", "תהלה", "תהלה ", "הללויה הללו", "הללויה:", "הללו את", "הללוי", "  מזמור לדוד",
        " מזמור לדוד", "\tמזמור לדוד", "<b>מִזְמוֹר</b> לְדָוִד", "מִזְמוֹר־לְדָוִד", "מזמור־לדוד", "מִזְמ֥וֹר לְדָוִ֑ד",
        "ומזמור לדוד", "א מזמור לדוד", "<small>מזמור</small> לדוד", "מזמור\nלדוד", "מזמור׃ לדוד",
        "אב֑ גד", "אב֑ גד הו", "אב֑ גד֑ הו וז", "א֑ב֑ ג", "אב֑\tגד", "אב֑ גד", "אב֑ גד הו", "א֑ ב ג ד",
        "<b>א֑</b> ב", "א֯ ב", "אְ ב", "א֐ ב", "׀ ׀", "֑֑֑", "a֑ b c d e f",
        "אב֑\u000Bגד הו", "אב֑\u000Cגד הו", "אב֑ גד הו", "אב֑ 　 גד הו",
    )

    /** Les seuils de la coupe, à la lettre près, en lettres latines pour un fichier court. */
    private val seuils: List<String> = buildList {
        // LONG : 500 lettres visibles restent entières, 501 se coupent.
        for (fin in listOf(247, 248, 249, 250)) add("a".repeat(250) + ": " + "b".repeat(fin))
        // MORCEAU : le deux-points doit être au moins la 250e lettre du morceau.
        for (debut in listOf(247, 248, 249, 250)) add("a".repeat(debut) + ": " + "b".repeat(400))
        // RESTE : il faut au moins 150 lettres après le deux-points.
        for (fin in listOf(146, 147, 148, 149, 150)) add("a".repeat(400) + ": " + "b".repeat(fin))
        // Plusieurs fins de phrase, rapprochées ou non.
        add(("a".repeat(120) + ": ").repeat(8))
        add(("a".repeat(260) + ": ").repeat(5))
        add(("a".repeat(249) + ": ").repeat(6) + "z")
        add(("a".repeat(250) + "׃ ").repeat(4))
        // Ce qui suit le deux-points : une espace seulement.
        add("a".repeat(300) + ": " + "b".repeat(300))
        add("a".repeat(300) + ":\t" + "b".repeat(300))
        add("a".repeat(300) + ":\n" + "b".repeat(300))
        add("a".repeat(300) + "::  " + "b".repeat(300))
        add("a".repeat(300) + ". " + "b".repeat(300) + ";" + " c".repeat(100))
        add("a".repeat(600) + ":")
        add("a".repeat(600) + ": ")
        add("a".repeat(400) + ": " + "b".repeat(200) + ": ")
        // Les balises ne comptent pas, ni dans le total ni dans le morceau.
        add("<b>" + "a".repeat(248) + "</b>: " + "b".repeat(300))
        add("<b>" + "a".repeat(250) + "</b>: " + "b".repeat(250))
        add("a".repeat(300) + "<br>: " + "b".repeat(300))
        add("a".repeat(300) + ":<br> " + "b".repeat(300))
        add("a".repeat(490) + "<i>" + "x".repeat(20) + "</i>: " + "b".repeat(5))
        // <small> : jamais coupé dedans, même imbriqué ; une fermeture de trop ne rend pas négatif.
        add("a".repeat(300) + "<small>: " + "b".repeat(300) + "</small>: " + "c".repeat(300))
        add("<small><small>" + "a".repeat(300) + "</small>: " + "b".repeat(300) + "</small>: " + "c".repeat(300))
        add("</small></small>" + "a".repeat(300) + ": " + "b".repeat(300))
        add("a".repeat(300) + "<SMALL>: " + "b".repeat(300) + "</SMALL>")
        add("a".repeat(300) + "<smallish>: " + "b".repeat(300) + "</small>: " + "c".repeat(300))
        add("a".repeat(300) + "<small/>: " + "b".repeat(300))
        // Des chevrons qui ne font pas une balise pour l'expression, ou une balise jamais fermée.
        add("a".repeat(300) + "<>: " + "b".repeat(300))
        add("a".repeat(300) + "<: " + "b".repeat(300))
        add("a".repeat(300) + ">: " + "b".repeat(300))
        add("a".repeat(300) + ": <" + "b".repeat(300))
        add("<" + "a".repeat(600) + ": " + "b".repeat(300))
        // Du texte hébreu vocalisé : les voyelles comptent comme des lettres.
        add("בְּ".repeat(100) + ": " + "שָׁ".repeat(100) + ": " + "לוֹם".repeat(60))
        add("בָּרוּךְ " + "אַתָּה ".repeat(50) + ": " + "בְּ".repeat(100))
        // Un paragraphe de té'amim reste entier, comme une ouverture de psaume.
        add("אב֑ גד ".repeat(60) + ": " + "a".repeat(300))
        add("לדוד " + "a".repeat(300) + ": " + "b".repeat(300))
        add("שיר" + "a".repeat(300) + ": " + "b".repeat(300))
    }

    // --- Les paragraphes du siddour et des livres ------------------------------------------------

    private val siddur = paragraphes("siddur_edot")
    private val kokhvei = paragraphes("livre_kokhvei_or")
    private val tefila = paragraphes("livre_tefila_lishlomo")

    private fun coupe(p: String) = Aeration.couper(p) != p

    /** Quelques dizaines de paragraphes entiers : coupés, avec <small>, psaumes, courts, et deux livres. */
    private val entiers: List<String> = (
        siddur.filter { coupe(it) && !it.contains("<small") && visible(it) <= 900 }.take(8) +
            siddur.filter { coupe(it) && it.contains("<small") && visible(it) <= 1400 }.take(6) +
            siddur.filter { coupe(it) && visible(it) > 2000 }.take(1) +
            siddur.filter { visible(it) > Aeration.LONG && Aeration.psaume(it) && visible(it) <= 900 }.take(4) +
            siddur.filter { it.startsWith("<small") && visible(it) <= 1400 }.take(3) +
            siddur.filter { it.startsWith("<b>") && visible(it) <= 300 }.take(3) +
            siddur.filter { !it.startsWith("<") && visible(it) <= 200 }.take(4) +
            tefila.filter { coupe(it) }.take(3) +
            kokhvei.filter { coupe(it) && visible(it) <= 900 }.take(3)
        ).distinct()

    /** Une empreinte par paragraphe : [hashCode, longueur, morceaux, longueur aérée, hashCode aéré, psaume]. */
    private fun empreintes(l: List<String>): List<List<Int>> = l.map { p ->
        val aere = Aeration.aerer(p)
        listOf(p.hashCode(), p.length, Aeration.couper(p).split("<br><br>").size, aere.length, aere.hashCode(),
            if (Aeration.psaume(p)) 1 else 0)
    }

    // --- Les marque-pages ------------------------------------------------------------------------

    private fun marque(m: MarquesPages.Marque): Map<String, Any?> =
        linkedMapOf("cle" to m.cle, "nusah" to m.nusah, "section" to m.section, "bloc" to m.bloc, "apercu" to m.apercu)

    private val a = MarquesPages.Marque("s:chaharit", "edot", 3, 12, "ברוך שאמר")
    private val b = MarquesPages.Marque("s:chaharit", "edot", 1, 4, "הודו ליהוה")
    private val c = MarquesPages.Marque("l:likoutei_etsot", "", 0, 0, "אמת")

    private val apercus: List<Pair<String, Int>> = listOf(
        "<b>בָּרוּךְ</b> שֶׁאָמַר וְהָיָה הָעוֹלָם" to 4, "<b>בָּרוּךְ</b> שֶׁאָמַר וְהָיָה הָעוֹלָם" to 6,
        "" to 6, " " to 6, "<b></b>" to 6, "א" to 0, "א ב ג" to 0, "א ב ג" to 1, "א ב ג" to 2, "א ב ג" to 3, "א ב ג" to 100,
        "מָה־אָשִׁיב לַיהוָה" to 6, "יְהוָה ׀ רֹעִי" to 6, "א|ב|ג|ד" to 6, "א\nב\tג\rד" to 6, "א\u000Bב\u000Cג" to 6,
        "א ב ג" to 6, "  א   ב  " to 6, " א ב " to 6, "א ב ג" to 6, "<small>בשבת:</small> רְצֵה" to 6,
        "<b>מוֹדֶה</b> <small>האשה אומרת: מוֹדָה</small> אֲנִי לְפָנֶיךָ מֶלֶךְ חַי וְקַיָּם" to 6,
        "אֱֽלֹהִ֗ים יְחׇנֵּ֥נוּ וִיבָרְכֵ֑נוּ" to 6, "בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים׃" to 6, "a<br>b<i>c</i>" to 6,
        "<<b>>א" to 6, "א < ב > ג" to 6, "שָׁלוֹםׇ עוֹלָם" to 6, "שלום׈ עולם" to 6, "֐א׆ב" to 6,
        "un deux trois quatre cinq six sept huit" to 6, "un deux trois quatre cinq six sept huit" to 5,
        "Ça va : très bien" to 6, "é é" to 6, "😀 ב" to 6,
    )

    /** Des textes enregistrés : bien formés, puis abîmés (champs manquants ou en trop, nombres illisibles). */
    private val enregistres: List<String?> = listOf(
        null, "", "\n", "\n\n", "\t", "\t\t\t\t", "a\tb\t1\t2\tc", "a\tb\t1\t2\t", "\t\t0\t0\t", "a\tb\t1\t2",
        "a\tb\t1\t2\tc\td\te", "a\tb\t1\t2\tc\n", "\na\tb\t1\t2\tc", "a\tb\t1\t2\tc\r\nd\te\t3\t4\tf",
        "a\tb\tx\t2\tc", "a\tb\t1\tx\tc", "a\tb\t\t2\tc", "a\tb\t1\t\tc", "a\tb\t+1\t-2\tc", "a\tb\t-0\t+0\tc",
        "a\tb\t 1\t2\tc", "a\tb\t1 \t2\tc", "a\tb\t1.0\t2\tc", "a\tb\t1e2\t2\tc", "a\tb\t0x10\t2\tc", "a\tb\t007\t2\tc",
        "a\tb\t2147483647\t-2147483648\tc", "a\tb\t2147483648\t0\tc", "a\tb\t0\t-2147483649\tc",
        "a\tb\t99999999999999999999\t0\tc", "a\tb\t+\t0\tc", "a\tb\t-\t0\tc", "a\tb\t--1\t0\tc", "a\tb\t+-1\t0\tc",
        "a\tb\t٣\t۴\tc", "a\tb\t１２\t٠\tc", "a\tb\t①\t0\tc", "a\tb\t½\t0\tc", "a\tb\t३\t༣\tc", "a\tb\t 1\t0\tc",
        "s:chaharit\tedot\t3\t12\tברוך שאמר\ns:chaharit\tedot\t1\t4\tהודו ליהוה\nl:likoutei_etsot\t\t0\t0\tאמת",
        "s:x\tsefard\t1\t2\tבְּרֵאשִׁית\nmauvaise ligne\ns:y\t\t3\t4\t",
        "é\té\t1\t1\té", "😀\t😀\t5\t6\t😀",
    )

    private val listes: List<List<MarquesPages.Marque>> = listOf(
        emptyList(), listOf(a), listOf(a, b, c), listOf(c, c),
        listOf(MarquesPages.Marque("", "", 0, 0, "")),
        listOf(MarquesPages.Marque("s:x", "edot", -1, Int.MIN_VALUE, "a b"), MarquesPages.Marque("s:x", "edot", Int.MAX_VALUE, 0, "")),
        // Un aperçu qui porterait une tabulation ou un saut de ligne ne se relit pas tel quel.
        listOf(MarquesPages.Marque("s:x", "edot", 1, 2, "a\tb"), MarquesPages.Marque("s:y", "", 3, 4, "c\nd")),
        listOf(MarquesPages.Marque("s:x\ty", "edot", 1, 2, "z")),
    )

    /** La bascule : poser, retirer, reposer ailleurs, déborder la limite de 60. */
    private fun bascules(): Map<String, Any?> {
        val operations = buildList {
            add(a); add(b); add(a.copy(apercu = "autre")); add(a); add(c); add(b.copy(nusah = "sefard")); add(b)
            add(a.copy(cle = "s:minha")); add(a.copy(section = 4)); add(a.copy(bloc = 13)); add(c.copy(apercu = ""))
            for (i in 0 until 64) add(a.copy(bloc = 100 + i, apercu = "n$i"))
            add(a.copy(bloc = 163)); add(a.copy(bloc = 104)); add(a.copy(bloc = 104)); add(b)
        }
        var l = emptyList<MarquesPages.Marque>()
        val etapes = operations.map { m ->
            l = MarquesPages.basculer(l, m)
            linkedMapOf("marque" to marque(m), "taille" to l.size, "empreinte" to MarquesPages.encoder(l).hashCode(),
                "premiere" to l.firstOrNull()?.let { marque(it) })
        }
        return linkedMapOf("etapes" to etapes, "finale" to l.map { marque(it) })
    }

    private fun duTexte(): List<Map<String, Any?>> {
        val l = listOf(
            a, b, a.copy(nusah = "sefard"), c, b.copy(bloc = 2), b.copy(section = 1, bloc = 4, apercu = "double"),
            a.copy(section = 0, bloc = 99), a.copy(section = -1), MarquesPages.Marque("s:chaharit", "", 0, 0, "sans noussa'h"),
            MarquesPages.Marque("s:minha", "edot", 0, 1, "minha"), c.copy(section = 2, bloc = 1), c.copy(section = 1, bloc = 9),
            MarquesPages.Marque("S:chaharit", "edot", 0, 0, "majuscule"), b.copy(bloc = 4, apercu = "triple"),
        )
        return listOf("s:chaharit" to "edot", "s:chaharit" to "sefard", "s:chaharit" to "", "l:likoutei_etsot" to "",
            "s:minha" to "edot", "s:absent" to "edot", "S:chaharit" to "edot", "" to "").map { (cle, nusah) ->
            linkedMapOf("cle" to cle, "nusah" to nusah, "resultat" to MarquesPages.duTexte(l, cle, nusah).map { marque(it) })
        }.let { listOf(linkedMapOf("liste" to l.map { marque(it) }, "requetes" to it)) }
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTexte.kt"),
        "constantes" to linkedMapOf("long" to Aeration.LONG, "morceau" to Aeration.MORCEAU, "reste" to Aeration.RESTE,
            "max" to MarquesPages.MAX),
        // L'aération des cas d'AerationTest (rendus entiers), puis des cas construits.
        "casDuTest" to casDuTest.map { aeration(it, toutEntier = true) },
        "premiersMots" to premiersMots.map { aeration(it) },
        "psaumes" to psaumes.map { aeration(it) },
        "seuils" to seuils.map { aeration(it) },
        // Des paragraphes entiers ; « aerer » y est rendu en entier.
        "paragraphes" to entiers.map { aeration(it, aereEntier = true) },
        // Tout le siddour Edot HaMizra'h et deux livres, une empreinte par paragraphe (ordre du fichier).
        "corpus" to listOf("siddur_edot", "livre_kokhvei_or", "livre_tefila_lishlomo").map { nom ->
            linkedMapOf("fichier" to "$nom.json", "empreintes" to empreintes(paragraphes(nom)))
        },
        // Les aperçus des marque-pages : cas construits, puis un paragraphe du siddour sur onze (rang dans « corpus »).
        "apercus" to apercus.map { (texte, mots) -> linkedMapOf("texte" to texte, "mots" to mots, "apercu" to MarquesPages.apercu(texte, mots)) },
        "apercusDuSiddur" to siddur.indices.filter { it % 11 == 0 }.map { i ->
            linkedMapOf("rang" to i, "mots" to (if (i % 2 == 0) 6 else 5), "apercu" to MarquesPages.apercu(siddur[i], if (i % 2 == 0) 6 else 5))
        },
        "apercusParDefaut" to listOf(siddur[0], siddur[1], "<b>בָּרוּךְ</b> שֶׁאָמַר וְהָיָה הָעוֹלָם בָּרוּךְ הוּא בָּרוּךְ עוֹשֶׂה")
            .map { linkedMapOf("texte" to it, "apercu" to MarquesPages.apercu(it)) },
        "encodages" to listes.map { l ->
            val texte = MarquesPages.encoder(l)
            linkedMapOf("marques" to l.map { marque(it) }, "texte" to texte, "relues" to MarquesPages.decoder(texte).map { marque(it) })
        },
        "decodages" to enregistres.map { s -> linkedMapOf("texte" to s, "marques" to MarquesPages.decoder(s).map { marque(it) }) },
        "bascules" to bascules(),
        "duTexte" to duTexte(),
    )
}
