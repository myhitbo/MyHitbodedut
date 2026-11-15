// Le journal d'Android devant la JVM : les journées que Store écrit dans la préférence « days » du
// fichier « myhitbodedut-journal » (addSession, setNote), celles qu'il relit d'un texte posé à la main
// et le texte qu'il réécrit alors, le journal enrichi (JournalPlus.lire, ecrire), son résumé, les
// minutes du mois, et le prénom. ModeleTests de Coeur les rejoue sur Journal et JournalPlus.
//
// Ce qu'on donne à Android est écrit en entier, pour être rejoué ; un texte long qu'il rend ne l'est
// pas : sa longueur en unités UTF-16 et son empreinte (String.hashCode) suffisent à dire qu'iOS écrit
// les mêmes octets. Les dates des journées sont passées en argument, et aucune opération ne regarde
// le jour qu'il est.

import com.myhitbodedut.DayRecord
import com.myhitbodedut.JournalPlus
import com.myhitbodedut.Store
import com.myhitbodedut.Theme
import java.time.YearMonth
import org.json.JSONObject

object VecteursModele : Generateur {
    override val fichier = "modele.json"

    private const val JOURNAL = "myhitbodedut-journal"

    /** Un texte : ses unités, son empreinte, et lui-même s'il est court. */
    private fun trace(s: String?): Map<String, Any?>? = s?.let {
        linkedMapOf("longueur" to it.length, "empreinte" to it.hashCode(), "texte" to it.takeIf { t -> t.length <= 600 })
    }

    private fun journee(r: DayRecord): Map<String, Any?> = linkedMapOf(
        "date" to r.date, "minutes" to r.minutes, "note" to trace(r.note), "themes" to r.themes, "noteSeule" to r.noteSeule,
    )

    private fun plus(p: JournalPlus.Plus): Map<String, Any?> = linkedMapOf(
        "avant" to p.avant, "apres" to p.apres, "gratitude" to p.gratitude, "travail" to p.travail, "vide" to p.vide,
    )

    private fun brut(t: Theatre, cle: String): String? = t.prefs(JOURNAL).valeurs[cle] as String?

    // --- Les journées écrites par Store ------------------------------------------------------------

    private val longue = "Hitbodedout dans les champs. ".repeat(180)
    private val hebreu = "\u05E8\u05B4\u05D1\u05BC\u05D5\u05B9\u05E0\u05D5\u05B9 \u05E9\u05B6\u05C1\u05DC \u05E2\u05D5\u05B9\u05DC\u05B8\u05DD, \u05D6\u05B7\u05DB\u05B5\u05BC\u05E0\u05B4\u05D9 \u05DC\u05B0\u05D4\u05B4\u05EA\u05B0\u05D1\u05BC\u05D5\u05B9\u05D3\u05B5\u05D3"

    /** [opération, arguments] : addSession(minutes, note, thème, date), setNote(date, note). */
    private val scenarios: List<Pair<String, List<List<Any?>>>> = listOf(
        "s\u00E9ances et notes" to listOf(
            listOf("addSession", 20, null, null, "2025-10-01"),
            listOf("addSession", 15, "merci", "gratitude", "2025-10-01"),
            listOf("addSession", -5, null, "famille", "2025-10-01"),
            listOf("addSession", 0, null, "gratitude", "2025-10-01"),
            listOf("setNote", "2025-10-03", "Pas pu aujourd'hui."),
            listOf("setNote", "2025-10-03", "   "),
            listOf("setNote", "2025-10-05", ""),
            listOf("setNote", "2025-10-05", " \t\n"),
            listOf("setNote", "2025-10-01", longue),
            listOf("addSession", 10, null, null, "2025-10-03"),
            listOf("setNote", "2025-09-30", "Avant le mois."),
            listOf("addSession", 5, null, "zivoug", "2025-09-30"),
            listOf("setNote", "2025-09-30", ""),
            listOf("addSession", 30, "", "autre", "2025-09-30"),
            listOf("setNote", "2025-10-03", hebreu),
            listOf("addSession", 1, longue, null, "2025-10-04"),
            listOf("setNote", "2025-10-06", "a".repeat(3998) + "\uD83D\uDE00" + "b"),
            listOf("setNote", "2025-10-07", "\u05D0\u05B8".repeat(2100)),
            listOf("setNote", "2025-10-08", "\u00A0\u2007"),
            listOf("setNote", "2025-10-08", "\u200B"),
            listOf("setNote", "2025-10-08", "\u00C9chappements : \" \\ / \u0001 \u2028 \t fin"),
        ),
        "s\u00E9rie d'un mois" to (1..31).map { j -> listOf<Any?>("addSession", j * 3, null, Theme.values()[j % 10].cle, "2025-12-%02d".format(j)) } +
            listOf(listOf("setNote", "2025-12-15", "Milieu du mois"), listOf("addSession", Int.MAX_VALUE, null, null, "2025-12-31"),
                listOf("addSession", 2, null, null, "2025-12-31")),
    )

    private fun rejoue(nom: String, ops: List<List<Any?>>): Map<String, Any?> {
        val t = Theatre()
        val c = t.contexte
        val etapes = ops.mapIndexed { i, op ->
            when (op[0]) {
                "addSession" -> Store.addSession(c, op[1] as Int, op[2] as String?,
                    (op[3] as String?)?.let { cle -> Theme.values().first { it.cle == cle } }, op[4] as String)
                "setNote" -> Store.setNote(c, op[1] as String, op[2] as String)
                else -> error("op\u00E9ration inconnue : ${op[0]}")
            }
            // Les journées relues, à la dernière étape : le texte de chaque étape dit déjà tout, dans l'ordre.
            linkedMapOf("op" to op[0], "args" to op.drop(1), "days" to trace(brut(t, "days")),
                "journees" to if (i == ops.size - 1) Store.days(c).values.map(::journee) else null)
        }
        return linkedMapOf("nom" to nom, "etapes" to etapes)
    }

    // --- Les journées relues d'un texte posé à la main ---------------------------------------------

    private val textes: List<String> = listOf(
        "{}",
        """{"2025-10-01":{"minutes":20,"note":""},"2025-10-02":{"minutes":0,"note":"x","note_seule":true}}""",
        """{"2025-10-05":{"minutes":5,"note":"c"},"2025-09-01":{"minutes":1,"note":"a","themes":["famille","gratitude"]},"2025-10-01":{"minutes":2,"note":"b"}}""",
        """{"2025-13-01":{"minutes":1},"2025-02-29":{"minutes":2},"2024-02-29":{"minutes":3},"2025-1-01":{"minutes":4},"20251001":{"minutes":5},""" +
            """"2025-10-01T00:00":{"minutes":6}," 2025-10-02":{"minutes":7},"2025-10-03 ":{"minutes":8},"+2025-10-04":{"minutes":9},""" +
            """"0000-02-29":{"minutes":10},"9999-12-31":{"minutes":11},"0001-01-01":{"minutes":12},"2025-10-00":{"minutes":13},""" +
            """"2025-04-31":{"minutes":14},"":{"minutes":15},"2025-10-05":{"minutes":16},"\uFF12\uFF10\uFF12\uFF15-10-06":{"minutes":17}}""",
        """{"-0001-01-01":{"minutes":1},"+10000-01-01":{"minutes":2},"10000-01-01":{"minutes":3},"-2025-10-01":{"minutes":4}}""",
        """{"2025-10-01":5,"2025-10-02":"x","2025-10-03":null,"2025-10-04":[],"2025-10-05":{},"2025-10-06":true,"2025-10-07":{"minutes":7}}""",
        """{"2025-10-01":{"minutes":"20"},"2025-10-02":{"minutes":20.7},"2025-10-03":{"minutes":-5},"2025-10-04":{"minutes":1e10},""" +
            """"2025-10-05":{"minutes":3000000000},"2025-10-06":{"minutes":true},"2025-10-07":{"minutes":null},"2025-10-08":{"minutes":"abc"},""" +
            """"2025-10-09":{"minutes":"  12  "},"2025-10-10":{"minutes":-0.5},"2025-10-11":{"minutes":"1e3"},"2025-10-12":{"minutes":[1]},""" +
            """"2025-10-13":{"minutes":-2147483649},"2025-10-14":{"minutes":"2147483648"},"2025-10-15":{"minutes":"-9e18"},"2025-10-16":{"minutes":"0x10"}}""",
        """{"2025-10-01":{"minutes":1,"note":null},"2025-10-02":{"minutes":1,"note":5},"2025-10-03":{"minutes":1,"note":true},""" +
            """"2025-10-04":{"minutes":1,"note":{"a":1}},"2025-10-05":{"minutes":1,"note":[1,"b"]},"2025-10-06":{"minutes":1,"note":1.50},""" +
            """"2025-10-07":{"minutes":1,"note":1e2},"2025-10-08":{"minutes":1,"note":"\u00E9t\u00E9 \/ \"cit\u00E9\" \\ \u0001 \uD83D\uDE00"},""" +
            """"2025-10-09":{"minutes":1,"note":"\u05D1\u05B0\u05BC\u05E8\u05B5\u05D0\u05E9\u05B4\u05C1\u05D9\u05EA \u05D1\u05B8\u05BC\u05E8\u05B8\u05D0"},"2025-10-10":{"minutes":1,"note":-0},"2025-10-11":{"minutes":1,"note":12345678901234567890}}""",
        """{"2025-10-01":{"minutes":1,"themes":[]},"2025-10-02":{"minutes":1,"themes":["gratitude"]},"2025-10-03":{"minutes":1,"themes":["","  ","x"]},""" +
            """"2025-10-04":{"minutes":1,"themes":[null]},"2025-10-05":{"minutes":1,"themes":[1,true,{"a":1},2.5]},"2025-10-06":{"minutes":1,"themes":"gratitude"},""" +
            """"2025-10-07":{"minutes":1,"themes":[["a"]]},"2025-10-08":{"minutes":1,"themes":["famille","famille"," famille"]},""" +
            """"2025-10-09":{"minutes":1,"themes":{"0":"x"}},"2025-10-10":{"minutes":1,"themes":["\u00A0","\u200B"]}}""",
        """{"2025-10-01":{"note_seule":true},"2025-10-02":{"note_seule":false},"2025-10-03":{"note_seule":"true"},"2025-10-04":{"note_seule":"TRUE"},""" +
            """"2025-10-05":{"note_seule":"yes"},"2025-10-06":{"note_seule":1},"2025-10-07":{"note_seule":null},"2025-10-08":{"note_seule":"False"}}""",
        """{"2025-10-01":{"minutes":1,"note":"a","inconnu":{"x":[1,2]},"themes":["b"],"note_seule":false,"minutes":9}}""",
        """{"2025-10-01":{"minutes":1},"2025-10-02":{"minutes":2},"2025-10-01":{"minutes":3}}""",
        "\uFEFF{\"2025-10-01\":{\"minutes\":5}}",
        " \n\t{ \"2025-10-01\" : { \"minutes\" : 5 , \"note\" : \"a\" } } \n",
        """{"2025-10-01":{"minutes":5}} poubelle""",
        "",
        "{",
        "pas du json",
        "[]",
        "null",
        """{"a":}""",
        """{"2025-10-01":{"minutes":5},}""",
        """{"2025-10-01":{"minutes":5}""",
    )

    /** Un grand journal : 400 jours, ni dans l'ordre ni complets, pour l'ordre et le débit. */
    private val grand: String = run {
        val o = JSONObject()
        for (i in 0 until 400) {
            val jour = java.time.LocalDate.of(2024, 1, 1).plusDays(((i * 37) % 700).toLong())
            val e = JSONObject().put("minutes", (i * 13) % 97).put("note", if (i % 3 == 0) "" else "Jour $i \u2014 ${hebreu.take(i % 20)}")
            if (i % 4 == 1) e.put("themes", org.json.JSONArray(listOf(Theme.values()[i % 10].cle, Theme.values()[(i + 3) % 10].cle)))
            if (i % 7 == 2) e.put("note_seule", true)
            o.put(jour.toString(), e)
        }
        o.toString()
    }

    private fun relis(texte: String): Map<String, Any?> {
        val t = Theatre()
        val c = t.contexte
        t.prefs(JOURNAL).valeurs["days"] = texte
        val journees = Store.days(c).values.map(::journee)
        val corrompu = brut(t, "days_corrompu")
        // Store réécrit le journal qu'il a lu : un import sans journée ni réglage ne fait que cela.
        check(Store.importJson(c, """{"format":"myhitbodedut"}""") == 0)
        return linkedMapOf("texte" to texte, "nombre" to journees.size, "journees" to journees.takeIf { it.size <= 60 },
            "corrompu" to (corrompu != null), "reecrit" to trace(brut(t, "days")))
    }

    // --- Le journal enrichi ---------------------------------------------------------------------------

    private class CasPlus(val brut: String?, val lus: List<String>, val ecritures: List<Pair<String, JournalPlus.Plus>>)

    private val casPlus = listOf(
        CasPlus(null, listOf("2025-10-01"), listOf("2025-10-01" to JournalPlus.Plus(2, 4, "merci", "la patience"),
            "2025-10-02" to JournalPlus.Plus(travail = "\u00E9couter"), "2025-10-01" to JournalPlus.Plus(), "2025-10-03" to JournalPlus.Plus(gratitude = "  "))),
        CasPlus("{}", listOf("2025-10-01"), listOf("2025-10-01" to JournalPlus.Plus(7, -2, "x".repeat(250), "\uD83D\uDE00".repeat(120)),
            "2025-10-01" to JournalPlus.Plus(5, 0, "", ""), "2025-10-02" to JournalPlus.Plus(0, 0, "\u00A0", "\u2007"))),
        CasPlus("""{"2025-10-01":{"avant":-1,"apres":6,"gratitude":"a","travail":"b"},"2025-10-02":{"avant":"3","apres":2.9,"gratitude":5,"travail":null},""" +
            """"2025-10-03":{"avant":true,"apres":null},"2025-10-04":"pas un objet","2025-10-05":{},"pas une date":{"avant":1},""" +
            """"2025-10-06":{"avant":99,"apres":-99,"gratitude":"${"g".repeat(230)}","travail":"${"\u05D0\u05B8".repeat(150)}","autre":[1]}}""",
            listOf("2025-10-01", "2025-10-02", "2025-10-03", "2025-10-04", "2025-10-05", "2025-10-06", "2025-10-07"),
            listOf("2025-10-05" to JournalPlus.Plus(1, 1), "2025-10-02" to JournalPlus.Plus(), "2025-10-08" to JournalPlus.Plus(3, 3, "fin"))),
        CasPlus("[", listOf("2025-10-01"), listOf("2025-10-01" to JournalPlus.Plus(1, 2))),
        CasPlus("[]", listOf("2025-10-01"), listOf("2025-10-09" to JournalPlus.Plus(apres = 5))),
        CasPlus("""{"2025-10-01":{"avant":2,"apres":4,"gratitude":"merci","travail":""}} reste""", listOf("2025-10-01"),
            listOf("2025-10-01" to JournalPlus.Plus(2, 4, "merci"))),
    )

    private fun rejouePlus(cas: CasPlus): Map<String, Any?> {
        val t = Theatre()
        val c = t.contexte
        if (cas.brut != null) t.prefs(JOURNAL).valeurs["journal_plus"] = cas.brut
        val lus = cas.lus.map { d -> linkedMapOf("date" to d, "plus" to plus(JournalPlus.lire(c, d))) }
        val ecritures = cas.ecritures.map { (d, p) ->
            JournalPlus.ecrire(c, d, p)
            linkedMapOf("date" to d, "plus" to plus(p), "brut" to trace(brut(t, "journal_plus")), "relu" to plus(JournalPlus.lire(c, d)))
        }
        return linkedMapOf("brut" to cas.brut, "lus" to lus, "ecritures" to ecritures)
    }

    // --- Le résumé et les minutes du mois -----------------------------------------------------------

    private fun resumes(): List<Map<String, Any?>> {
        val cas = mutableListOf(
            listOf(JournalPlus.Plus(2, 4, "merci", "la patience"), "G", "T", "Sujet : Famille"),
            listOf(JournalPlus.Plus(travail = "\u00E9couter"), "G", "T", ""),
            listOf(JournalPlus.Plus(2, 4, "merci"), "G", "", ""),
            listOf(JournalPlus.Plus(), "G", "", ""),
            listOf(JournalPlus.Plus(0, 3), "Gratitude", "\u00C0 travailler", ""),
            listOf(JournalPlus.Plus(3, 0), "Gratitude", "\u00C0 travailler", "   "),
            listOf(JournalPlus.Plus(-1, 6, " ", "\u00A0"), "G", "T", "\u2007"),
            listOf(JournalPlus.Plus(1, 5, "\u05EA\u05BC\u05D5\u05B9\u05D3\u05B8\u05D4", "\u05E1\u05B7\u05D1\u05B0\u05DC\u05B8\u05E0\u05D5\u05BC\u05EA"), "\u05D4\u05DB\u05E8\u05EA \u05D4\u05D8\u05D5\u05D1", "\u05DC\u05E2\u05D1\u05D5\u05D3 \u05E2\u05DC", "\u05E0\u05D5\u05E9\u05D0 : \u05DE\u05E9\u05E4\u05D7\u05D4"),
            listOf(JournalPlus.Plus(0, 0, "a\nb", "c"), "", "", "\u200B"),
        )
        for (avant in -1..6) for (apres in listOf(0, 1, 5, 6)) cas += listOf(JournalPlus.Plus(avant, apres), "G", "T", "")
        return cas.map { (p, g, t, s) ->
            p as JournalPlus.Plus
            linkedMapOf("plus" to plus(p), "gratitude" to g, "travail" to t, "sujets" to s,
                "resume" to JournalPlus.resume(p, g as String, t as String, s as String))
        }
    }

    private fun mois(): List<Map<String, Any?>> {
        val jours = linkedMapOf(
            "2026-10-01" to DayRecord("2026-10-01", 20, ""),
            "2026-10-03" to DayRecord("2026-10-03", 0, "note", noteSeule = true),
            "2026-10-31" to DayRecord("2026-10-31", 45, ""),
            "2026-10-15" to DayRecord("2026-10-15", -7, "x"),
            "2026-10-16" to DayRecord("2026-10-16", 12, "seule", noteSeule = true),
            "2026-09-30" to DayRecord("2026-09-30", 99, ""),
            "2026-11-01" to DayRecord("2026-11-01", 98, ""),
            "2024-02-29" to DayRecord("2024-02-29", 29, ""),
            "2024-02-01" to DayRecord("2024-02-01", 1, ""),
            "2026-02-28" to DayRecord("2026-02-28", 28, ""),
            "2000-02-29" to DayRecord("2000-02-29", 2000, ""),
            "2100-02-28" to DayRecord("2100-02-28", 2100, ""),
        )
        return listOf(YearMonth.of(2026, 10), YearMonth.of(2026, 9), YearMonth.of(2026, 11), YearMonth.of(2024, 2), YearMonth.of(2026, 2),
            YearMonth.of(2000, 2), YearMonth.of(2100, 2), YearMonth.of(2026, 1), YearMonth.of(2026, 4)).map { m ->
            linkedMapOf("annee" to m.year, "mois" to m.monthValue, "minutes" to JournalPlus.minutesDuMois(jours, m))
        }.let { listOf(linkedMapOf("journees" to jours.values.map(::journee), "mois" to it)) }
    }

    // --- Le prénom ------------------------------------------------------------------------------------

    private val prenoms = listOf("", "Moshe", "  Moshe  ", "a".repeat(50), "\u05DE\u05B9\u05E9\u05B6\u05C1\u05D4", "a" + " ".repeat(38) + "bc",
        "b".repeat(39) + " x", "\u00A0Moshe\u00A0", "\u200BMoshe", "a".repeat(38) + "\uD83D\uDE00", "\u05E9\u05C1\u05B8".repeat(20), "\t\n")

    private fun prenom(nom: String): Map<String, Any?> {
        val t = Theatre()
        Store.setFirstName(t.contexte, nom)
        return linkedMapOf("nom" to nom, "garde" to brut(t, "first_name"), "lu" to Store.firstName(t.contexte))
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursModele.kt"),
        "constantes" to linkedMapOf("noteMax" to Store.NOTE_MAX, "gratitudeMax" to JournalPlus.GRATITUDE_MAX, "humeurs" to JournalPlus.HUMEURS),
        "scenarios" to scenarios.map { (nom, ops) -> rejoue(nom, ops) },
        "relectures" to (textes + grand).map(::relis),
        "plus" to casPlus.map(::rejouePlus),
        "resumes" to resumes(),
        "mois" to mois(),
        "prenoms" to prenoms.map(::prenom),
    )
}
