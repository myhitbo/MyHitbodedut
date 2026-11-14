// Le socle de Coeur devant la JVM : ce que rendent Java, Kotlin et le org.json d'Android pour les
// quelques opérations dont la sémantique ne va pas de soi en Swift (hashCode, hasard de Kotlin,
// modulo, arrondi, chaînes comptées en unités UTF-16, blancs de Kotlin, lecture tolérante et
// écriture du JSON).

import kotlin.math.roundToInt
import kotlin.math.roundToLong
import kotlin.random.Random
import org.json.JSONArray
import org.json.JSONObject

object VecteursSocle : Generateur {
    override val fichier = "socle.json"

    private val textes = listOf(
        "", "a", "abc", "Hitbodedout", "trophee_serie_7", "éàç", "שלום", "בְּרֵאשִׁית", "מָה־אָשִׁיב", "ה׳ בכסלו",
        "😀", "a😀b", " x ", " \t x \n", "  ", "İstanbul", "ǅ", "ß", "ΌΣΟΣ", "é", "é",
        "\u001Cx\u001F", "\u0085x\u0085", " x ", "　x　", "​x​", "﻿x",
    )

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursSocle.kt", "moteur" to "JVM, Kotlin ${KotlinVersion.CURRENT}"),
        "chaines" to textes.map { s ->
            linkedMapOf(
                // Les unités UTF-16 : certaines chaînes coupent une paire de substitution, ce que le JSON ne sait pas écrire.
                "unites" to s.map { it.code }, "hash" to s.hashCode(), "longueur" to s.length,
                "blanc" to s.isBlank(), "rogne" to s.trim().map { it.code },
                "minuscules" to s.lowercase().map { it.code }, "majuscules" to s.uppercase().map { it.code },
                "prend2" to s.take(2).map { it.code }, "retire2" to s.drop(2).map { it.code },
                "dernier2" to s.takeLast(2).map { it.code },
            )
        },
        "recherches" to listOf(
            Triple("מָה־אָשִׁיב", "מ", "ה"), Triple("בְּרֵאשִׁית", "ב", "ית"), Triple("בְּרֵאשִׁית", "בר", "שית"),
            Triple("abcabc", "bc", "c"), Triple("é", "e", "́"), Triple("é", "e", "é"),
            Triple("a😀b", "😀", "b"), Triple("", "", ""), Triple("abc", "", "abc"), Triple("abc", "abcd", "bc"),
            Triple("aaa", "aa", "b"), Triple("a.b.c", ".", "-"), Triple("שלום עולם", " ", "ם"),
        ).map { (s, a, b) ->
            linkedMapOf(
                "s" to s.map { it.code }, "a" to a.map { it.code }, "b" to b.map { it.code },
                "contientA" to s.contains(a), "commenceA" to s.startsWith(a), "finitB" to s.endsWith(b),
                "indiceA" to s.indexOf(a), "dernierIndiceB" to s.lastIndexOf(b), "egalA" to (s == a),
                "remplaceAParB" to s.replace(a, b).map { it.code },
                "avantB" to s.substringBefore(b).map { it.code }, "apresA" to s.substringAfter(a).map { it.code },
            )
        },
        "hasard" to listOf(0, 1, 7, 42, -1, 2026, "pluie".hashCode(), Int.MAX_VALUE, Int.MIN_VALUE).map { graine ->
            val r = Random(graine)
            linkedMapOf(
                "graine" to graine,
                "entiers" to List(6) { r.nextInt() },
                "bornes" to listOf(1, 2, 3, 4, 10, 100, 1000, 65536, 1_000_000).map { r.nextInt(it) },
                "intervalles" to listOf(0 to 10, -5 to 5, 100 to 101, 3 to 1000).map { (a, b) -> r.nextInt(a, b) },
                "longs" to List(3) { r.nextLong().toString() },
                "flottants" to List(4) { r.nextFloat().toDouble() },
                "doubles" to List(4) { r.nextDouble() },
                "booleens" to List(8) { r.nextBoolean() },
                "melange" to (0 until 12).toList().shuffled(Random(graine)),
                "melangeCourt" to listOf("a", "b", "c").shuffled(Random(graine)),
                "tirage" to List(5) { listOf("a", "b", "c", "d", "e").random(r) },
            )
        },
        "hasardLong" to listOf(0L, 1L, 1234567890123L, -1L, Long.MAX_VALUE).map { graine ->
            val r = Random(graine)
            linkedMapOf("graine" to graine.toString(), "entiers" to List(4) { r.nextInt() })
        },
        "modulo" to listOf(7 to 3, -7 to 3, 7 to -3, -7 to -3, 0 to 5, -1 to 7, 14 to 7, -14 to 7, 1_000_000_007 to 13).map { (a, b) ->
            linkedMapOf("a" to a, "b" to b, "reste" to a % b, "quotient" to a / b,
                "floorMod" to Math.floorMod(a, b), "floorDiv" to Math.floorDiv(a, b), "mod" to a.mod(b))
        },
        "arrondis" to listOf(0.0, 0.5, 1.5, 2.5, -0.5, -1.5, -2.5, 0.49999999999999994, 2.4999, -2.5001, 1e9 + 0.5, -0.0,
            3.14159, 1234.5, 0.05, 0.15, 0.25, 0.35, 2.675, -0.05, 99.95, 1e12 + 0.5, 3e9, -3e9).map { x ->
            linkedMapOf("x" to x, "roundToInt" to x.roundToInt(), "roundToLong" to x.roundToLong().toString(),
                "mathRound" to Math.round(x).toString(), "mathRoundFloat" to Math.round(x.toFloat()),
                "rint" to Math.rint(x), "versInt" to x.toInt(), "versLong" to x.toLong().toString(),
                "f0" to "%.0f".format(java.util.Locale.ROOT, x), "f1" to "%.1f".format(java.util.Locale.ROOT, x),
                "f2" to "%.2f".format(java.util.Locale.ROOT, x), "texte" to x.toString())
        },
        "arrondisFlottants" to listOf(0 to 1, 1 to 2, 5 to 2, 7 to 2, 10 to 3, 20 to 3, 100 to 7, 1439 to 31, 95 to 10, 45 to 10, 1 to 3).map { (a, b) ->
            linkedMapOf("a" to a, "b" to b, "arrondi" to Math.round(a.toFloat() / b), "quotient" to (a.toFloat() / b).toDouble())
        },
        "formats" to listOf(0, 5, 9, 10, 59, 60, 61, 125, 600, 1439).map { m ->
            linkedMapOf("m" to m, "hhmm" to String.format(java.util.Locale.US, "%02d:%02d", (m / 60) % 24, m % 60),
                "hmm" to String.format(java.util.Locale.ROOT, "%d:%02d", m / 60, m % 60))
        },
        "nombresLus" to listOf("20", "20.7", " 7 ", "\t12\n", "\u00a012", "abc", "", "  ", "1e2", "1E2", "1e", "1e+", "1.", ".5", "+5", "-5", "--5",
            "NaN", "nan", "-NaN", "Infinity", "-Infinity", "+Infinity", "inf", "0x10", "20d", "20D", "20f", "20F", "20L", "1_000",
            "1,5", "１２", "٣", "1e400", "-1e400", "1e-400", "1.7976931348623157E308", "9007199254740993", "0.1", "00012", "-0", "-0.0",
            "1 2", "2147483648", "-2147483649", "9223372036854775807", "1e19").map { t ->
            val d = try { java.lang.Double.parseDouble(t) } catch (e: NumberFormatException) { null }
            linkedMapOf("texte" to t, "lu" to (d != null), "valeur" to d?.let { nombre(it) },
                "versInt" to d?.toInt(), "versLong" to d?.toLong()?.toString())
        },
        "nombresEcrits" to listOf(0.0, -0.0, 1.0, 1.5, 20.0, 1000.0, 0.01, 0.001, 0.0001, 1e7, 9999999.0, 12345678.9, 1e10, 1e21, 1e-7,
            1.0 / 3, 2.0 / 3, 0.1 + 0.2, 123456.789, 1.2345678901234567E19, 2.2250738585072014E-308, 1.7976931348623157E308, 100.0, 0.5, -1.9, 3.0e9,
            9.223372036854775807E18, 1e15, 1e16, 123456789012345680.0, 0.3, 2.5e-5).flatMap { listOf(it, -it) }.distinct().map { d ->
            linkedMapOf("bits" to java.lang.Double.doubleToRawLongBits(d).toString(), "texte" to d.toString(),
                "json" to runCatching { JSONObject.numberToString(d) }.getOrNull())
        },
        "expressions" to expressions(),
        "json" to textesJson.map { (texte, strict, ios) -> lecture(texte, strict, ios) },
        "jsonEcrit" to ecritures(),
    )

    // --- JSON : le org.json d'Android ------------------------------------------------------------

    /**
     * Le texte ; s'il est du JSON au sens strict (RFC 8259) ; et si iOS l'accepte : tout le JSON strict,
     * plus ce qu'Android ignore après l'objet. Android en accepte davantage (apostrophes, commentaires…).
     */
    private val textesJson: List<Triple<String, Boolean, Boolean>> = listOf(
        Triple("""{"a":1,"b":-2,"c":3000000000,"d":1.5,"e":-0.0,"f":1e3,"g":"20","h":"20.7","i":" 7 ","j":"abc","k":true,"l":"TRUE","m":"false","n":null,"o":[1,"x",null,2.5,{"p":1},true,"3"],"q":{"r":"s"},"s":"","t":"null","u":12345678901234567890,"v":9223372036854775807,"w":-9223372036854775808,"x":1E-2,"y":"1e2","z":"NaN","aa":"0x10","ab":"  ","ac":2147483648,"ad":-2147483649,"ae":"2147483648","af":0,"ag":-1.9,"ah":"-1.9","ai":1e10,"aj":"1e10","ak":false,"al":"yes","am":0.5,"an":"٣","ao":4294967297,"ap":"-0","aq":-0,"ar":1.0,"as":100.0e-1,"at":"20d","au":"1.","av":".5","aw":"+5"}""", true, true),
        Triple("""{"s":"a\"b\\c\/d\b\f\n\r\t\u00e9\u05d0\ud83d\ude00 / é א 😀 \u0001 \u007f"}""", true, true),
        Triple("""{"b":1,"a":2,"b":3}""", true, true),
        Triple("""{"a":{},"b":[],"c":[[]],"d":[{}],"e":{"f":[1,{"g":null}]}}""", true, true),
        Triple("""{"days":{"2026-11-03":{"minutes":20,"note":"Dehors.","themes":["gratitude","parnassa"]},"2026-11-04":{"minutes":0,"note":"x","note_seule":true}},"paused_dates":[]}""", true, true),
        Triple("\uFEFF{ \"a\" : 1 ,\n\t\"b\" : [ 1 , 2 ] }\n", true, true),
        Triple("""  {"a":1}  """, true, true),
        Triple("""{"a":1} suite""", false, true),
        Triple("""{"a":1}{"b":2}""", false, true),
        Triple("""{'a':1}""", false, false),
        Triple("""{a:1}""", false, false),
        Triple("""{"a":1,}""", false, false),
        Triple("""{"a":01}""", false, false),
        Triple("""{"a":.5}""", false, false),
        Triple("""{"a":+1}""", false, false),
        Triple("""{"a":1 /* c */}""", false, false),
        Triple("""{"a":tRue}""", false, false),
        Triple("""{"a":"x" "b":1}""", false, false),
        Triple("""{"a";1}""", false, false),
        Triple("""{"a":"\x"}""", false, false),
        Triple("", false, false),
        Triple("   ", false, false),
        Triple("[]", false, false),
        Triple("[1]", false, false),
        Triple("\"x\"", false, false),
        Triple("1", false, false),
        Triple("null", false, false),
        Triple("{", false, false),
        Triple("""{"a":}""", false, false),
        Triple("""{"a":[1,2}""", false, false),
        Triple("""{"a":"x}""", false, false),
        Triple("""{"a" 1}""", false, false),
    )

    // --- Expressions régulières ----------------------------------------------------------------------
    // Sur un téléphone, les expressions d'Android sont celles d'ICU, comme NSRegularExpression ; la JVM
    // d'ici a son propre moteur. Les deux s'accordent sur ces motifs, écrits sans \s, \w, \b ni \d, que
    // les deux moteurs n'étendent pas de même aux caractères hors ASCII.

    private class Cas(val motif: String, val options: Set<RegexOption>, val textes: List<String>, val gabarit: String? = null)

    private fun expressions(): List<Map<String, Any?>> = listOf(
        Cas("<[^>]+>", emptySet(), listOf("<b>מוֹדֶה</b> <small>האשה אומרת: מוֹדָה</small> אֲנִי", "sans balise", "")),
        Cas("[\\u0591-\\u05C7]", emptySet(), listOf("בְּרֵאשִׁית בָּרָא", "מָה־אָשִׁיב", "abc")),
        Cas("([0-9]+):([0-9]+)", emptySet(), listOf("à 12:30 et 7:05, puis 23:59", "12h30", ":"), "$2 après $1"),
        Cas("(?<![\\u05D0-\\u05EA])ה['׳]", emptySet(), listOf("לפני ה' יתברך", "ה׳ בכסלו", "אלה' x", "תורת ה'")),
        Cas("a|ab", emptySet(), listOf("ab", "a", "abab", "b")),
        Cas("(a)|(b)", emptySet(), listOf("b", "a", "ab", "c")),
        Cas(",[ \\t]*", emptySet(), listOf("a, b,c,,d,", ",", "abc", "")),
        Cas("([a-z]+)@([a-z]+)", emptySet(), listOf("x@y et moi@ici", "@"), "$2 chez $1"),
        Cas("tel aviv", setOf(RegexOption.IGNORE_CASE), listOf("TEL AVIV", "Tel Aviv-Yafo", "telaviv")),
        Cas("\\p{M}+", emptySet(), listOf("é", "בְּרֵאשִׁית", "abc")),
        Cas("x*", emptySet(), listOf("axb", "", "xx")),
        Cas("^[a-z]+$", setOf(RegexOption.MULTILINE), listOf("un\ndeux\nTrois\nquatre", "seul")),
        Cas("a.c", setOf(RegexOption.DOT_MATCHES_ALL), listOf("a\nc abc", "ac")),
        Cas("a.c", emptySet(), listOf("a\nc abc", "ac")),
        Cas("(^|[.:] )[א-ת]{1,2} ", emptySet(), listOf("א בְּרֵאשִׁית. ב וְהָאָרֶץ: יג וַיְהִי", "שלום עולם")),
        Cas("[A-Za-zÀ-ÿ]{3,}", emptySet(), listOf("MyHitbodedut שלום été", "ab cd", "")),
        Cas("(?:^|[ (\\[>־])[ובלמשכה]{0,2}ה['׳](?![\"'״])", emptySet(), listOf("לפני ה' יתברך", "(וה' אמר)", "ה״א", "זה'")),
        Cas("\\$([0-9]+)", emptySet(), listOf("prix $12 ou $7"), "\\$$1 !"),
    ).map { c ->
        val r = Regex(c.motif, c.options)
        linkedMapOf(
            "motif" to c.motif, "options" to c.options.map { it.name }.sorted(), "gabarit" to c.gabarit,
            "textes" to c.textes.map { t ->
                fun resultat(m: MatchResult) = linkedMapOf("valeur" to m.value, "debut" to m.range.first, "fin" to m.range.last + 1,
                    "groupes" to m.groupValues, "plages" to m.groups.map { g -> g?.range?.let { listOf(it.first, it.last + 1) } })
                linkedMapOf(
                    "texte" to t,
                    "premiere" to r.find(t)?.let(::resultat),
                    "depuis2" to (if (t.length >= 2) r.find(t, 2)?.let(::resultat) else null),
                    "toutes" to r.findAll(t).map(::resultat).toList(),
                    "presente" to r.containsMatchIn(t),
                    "entiere" to r.matches(t),
                    "sans" to r.replace(t, ""),
                    "gabarit" to c.gabarit?.let { r.replace(t, it) },
                    "crochets" to r.replace(t) { "[" + it.value + "]" },
                    "morceaux" to r.split(t),
                )
            },
        )
    }

    private fun nombre(d: Double): String = if (d.isNaN()) "NaN" else d.toString()

    /** Ce qu'Android lit d'une valeur, par chacun de ses accesseurs tolérants. */
    private fun lectures(present: Boolean, nul: Boolean, optInt: Int, optLong: Long, optDouble: Double, optFaux: Boolean,
                         optVrai: Boolean, optString: String, objet: Boolean, tableau: Boolean) = linkedMapOf(
        "present" to present, "nul" to nul, "optInt" to optInt, "optLong" to optLong.toString(),
        "optDouble" to nombre(optDouble), "optBooleanFaux" to optFaux, "optBooleanVrai" to optVrai,
        "optString" to optString, "objet" to objet, "tableau" to tableau,
    )

    private fun lecture(texte: String, strict: Boolean, ios: Boolean): Map<String, Any?> {
        val base = linkedMapOf<String, Any?>("texte" to texte, "strict" to strict, "ios" to ios)
        val o = try { JSONObject(texte) } catch (e: Exception) { return base + ("android" to false) }
        val cles = o.keys().asSequence().toList()
        val valeurs = (cles + "absente").map { k ->
            linkedMapOf<String, Any?>("cle" to k) + lectures(o.has(k), o.isNull(k), o.optInt(k, -1), o.optLong(k, -1L),
                o.optDouble(k), o.optBoolean(k, false), o.optBoolean(k, true), o.optString(k, "∅"),
                o.optJSONObject(k) != null, o.optJSONArray(k) != null)
        }
        val tableaux = cles.mapNotNull { k -> o.optJSONArray(k)?.let { k to it } }.map { (k, a) ->
            linkedMapOf("cle" to k, "elements" to (0..a.length()).map { i ->
                lectures(i < a.length(), a.isNull(i), a.optInt(i, -1), a.optLong(i, -1L), a.optDouble(i),
                    a.optBoolean(i, false), a.optBoolean(i, true), a.optString(i, "∅"),
                    a.optJSONObject(i) != null, a.optJSONArray(i) != null)
            })
        }
        return base + linkedMapOf("android" to true, "cles" to cles, "valeurs" to valeurs, "tableaux" to tableaux,
            "compact" to o.toString(), "indente" to o.toString(2))
    }

    /** Des objets bâtis par le code, comme `Store.exportJson` : ce qu'Android en écrit. */
    private fun ecritures(): List<Map<String, Any?>> {
        val nombres = JSONObject().put("entier", 20).put("zero", 0).put("negatif", -5).put("long", 3000000000L)
            .put("rond", 20.0).put("demi", 0.5).put("moinsZero", -0.0).put("grand", 1e21).put("petit", 1e-7)
            .put("tiers", 1.0 / 3).put("flottant", 1.5f).put("vrai", true).put("faux", false).put("nul", JSONObject.NULL)
        val textes = JSONObject().put("guillemet", "a\"b").put("barres", "a\\b/c").put("controles", "\b\u000C\n\r\t\u0001\u001f\u007f")
            .put("hebreu", "בְּרֵאשִׁית").put("visage", "😀").put("lignes", "  ").put("vide", "")
            .put("clé accentuée", "é").put("cle\"guillemet", 1)
        val formes = JSONObject().put("objetVide", JSONObject()).put("tableauVide", JSONArray())
            .put("tableau", JSONArray().put(1).put("x").put(JSONObject.NULL).put(JSONArray().put(true)).put(JSONObject().put("k", "v")))
            .put("imbrique", JSONObject().put("a", JSONObject().put("b", JSONArray().put(JSONObject()))))
        val sauvegarde = JSONObject().put("format", "myhitbodedut").put("version", 1)
            .put("days", JSONObject().put("2026-11-03", JSONObject().put("minutes", 20).put("note", "Dehors, avant le lever du jour.")
                .put("themes", JSONArray().put("gratitude").put("parnassa"))))
            .put("paused_dates", JSONArray()).put("blocked_apps", JSONArray().put("com.instagram.android"))
        return listOf("nombres" to nombres, "textes" to textes, "formes" to formes, "sauvegarde" to sauvegarde, "vide" to JSONObject())
            .map { (nom, o) -> linkedMapOf("nom" to nom, "compact" to o.toString(), "indente2" to o.toString(2), "indente4" to o.toString(4)) }
    }
}
