// Le Yalkout Yossef du jour devant la JVM (YalkutYosef.kt) : le livre que lit YalkutYosef.parse (une
// empreinte par période), la période, le rang et les deux se'ifim de chaque jour des années
// hébraïques 5786 à 5788 hors d'Israël et en Israël, la fenêtre de fête de chaque jour de chaque
// mois (année simple ou embolismique), la période de jours d'avant 1970 et lointains, du, la
// recherche, la source de chaque se'if, le titre et le texte de la carte.

import com.kosherjava.zmanim.hebrewcalendar.JewishDate
import com.myhitbodedut.YalkutYosef
import java.io.File
import java.time.LocalDate

object VecteursYalkutYosef : Generateur {
    override val fichier = "yalkut_yosef.json"

    private val livre: YalkutYosef.Livre = YalkutYosef.parse(File(RES, "raw/yalkut_yosef.json").readText())

    /** L'empreinte d'un se'if : siman, lettre et texte joints par « | », puis String.hashCode(). */
    private fun empreinte(s: YalkutYosef.Seif): Int = "${s.siman}|${s.lettre}|${s.texte}".hashCode()

    // --- Le jour -----------------------------------------------------------------------------------

    /** Les jours des années hébraïques 5786 à 5788 (du 23 septembre 2025 au 20 septembre 2028). */
    private val jours: List<LocalDate> = generateSequence(JewishDate(5786, JewishDate.TISHREI, 1).localDate) { it.plusDays(1) }
        .takeWhile { it.isBefore(JewishDate(5789, JewishDate.TISHREI, 1).localDate) }.toList()

    private fun jour(d: LocalDate): Map<String, Any?> {
        val (p, rang) = YalkutYosef.periode(d, false)
        val hors = YalkutYosef.pour(livre, d, false)
        val cas = linkedMapOf<String, Any?>(
            "jour" to d.toString(), "periode" to p, "rang" to rang, "seifs" to hors.map(::empreinte),
            "titre" to YalkutYosef.titreCarte(hors).hashCode(), "carte" to YalkutYosef.texteCarte(hors).hashCode(),
        )
        // En Israël, seulement ce qui diffère (rien ne devrait : la date hébraïque ne dépend pas du lieu).
        val (pi, ri) = YalkutYosef.periode(d, true)
        val israel = YalkutYosef.pour(livre, d, true)
        if (pi != p || ri != rang || israel != hors) {
            cas["israel"] = linkedMapOf("periode" to pi, "rang" to ri, "seifs" to israel.map(::empreinte))
        }
        return cas
    }

    /** Les dates du test, puis autour du 1er janvier 1970 (rangs négatifs), des vendredis, des jours lointains. */
    private val dates = listOf("2027-03-25", "2027-03-24", "2026-10-12", "2026-10-23", "2026-10-21",
        "1969-12-12", "1969-12-19", "1969-12-26", "1969-12-31", "1970-01-01", "1970-01-02", "1970-01-09", "1970-01-16",
        "1960-01-01", "1900-01-05", "1899-12-29", "2000-01-07", "2023-12-08", "2024-03-29", "2099-12-25", "2100-03-01")

    // --- du, la recherche, la carte -----------------------------------------------------------------

    private fun seif(i: Int) = YalkutYosef.Seif("s$i", "l$i", "t$i")

    /** Les recherches du test, puis celles de VecteursHalakha (la même liste, recopiée : chaque générateur se compile seul). */
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
        // Ce qui ne se trouve que dans un siman, avec ou sans le tiret.
        "סימן א - הלכות השכמת הבוקר", "הלכות השכמת הבוקר", "השכמת",
    )

    private fun recherche(q: String): Map<String, Any?> {
        val r = YalkutYosef.recherche(livre, q)
        return linkedMapOf("requete" to q, "nombre" to r.size,
            "empreinte" to r.map(::empreinte).joinToString(",").hashCode(), "premiers" to r.take(3).map(::empreinte))
    }

    private val simanA = "סימן א - הלכות השכמת הבוקר"
    private val a = YalkutYosef.Seif(simanA, "ב", "צריך להקדים לקום בבוקר")
    private val b = YalkutYosef.Seif(simanA, "ג", "ונהגו בכמה קהלות ישראל")
    private val c = YalkutYosef.Seif("סימן ב - הלכות נטילת ידיים", "", "כשקם ממיטתו")
    private val d = YalkutYosef.Seif("", "א", "")
    // Deux simanim aux mêmes signes, dans un autre ordre (canoniquement équivalents) : Kotlin les distingue.
    private val e = YalkutYosef.Seif("סִּימן ג", "א", "ראשון")
    private val f = YalkutYosef.Seif("סִּימן ג", "ב", "שני")

    private val cartes: List<List<YalkutYosef.Seif>> =
        listOf(emptyList(), listOf(a), listOf(a, b), listOf(a, c), listOf(c), listOf(a, b, c), listOf(c, c), listOf(d), listOf(d, a),
            listOf(e, f), listOf(e, e))

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursYalkutYosef.kt", "livre" to "android/app/src/main/res/raw/yalkut_yosef.json"),
        "parJour" to YalkutYosef.PAR_JOUR,
        // Le livre lu : chaque période dans l'ordre du fichier, son nombre de se'ifim et l'empreinte de leur suite.
        "periodes" to livre.periodes.map { (p, l) ->
            linkedMapOf("periode" to p, "nombre" to l.size, "empreinte" to l.map(::empreinte).joinToString(",").hashCode())
        },
        // YalkutYosef.pour, chaque jour de trois années hébraïques.
        "pour" to jours.map(::jour),
        "periode" to dates.map { texte ->
            val (p, rang) = YalkutYosef.periode(LocalDate.parse(texte), false)
            linkedMapOf("jour" to texte, "periode" to p, "rang" to rang)
        },
        // YalkutYosef.fenetre pour les mois 0 à 14 (1 = Nissan … 13 = Adar II), du jour −1 au jour 32.
        "fenetre" to listOf(false, true).flatMap { emb ->
            (0..14).map { mois -> linkedMapOf("mois" to mois, "embolismique" to emb, "jours" to (-1..32).map { YalkutYosef.fenetre(mois, it, emb) }) }
        },
        // YalkutYosef.du sur des listes de 0 à 5 se'ifim : les rangs, dans la liste, des se'ifim rendus.
        "du" to (0..5).flatMap { n ->
            val seifs = (0 until n).map(::seif)
            listOf(Int.MIN_VALUE, -7, -3, -2, -1, 0, 1, 2, 3, 4, 7, 100, Int.MAX_VALUE).map { rang ->
                linkedMapOf("n" to n, "rang" to rang, "indices" to YalkutYosef.du(seifs, rang).map { seifs.indexOf(it) })
            }
        },
        "recherche" to requetes.map(::recherche),
        // YalkutYosef.source de chaque se'if du livre, dans l'ordre du fichier.
        "sources" to livre.periodes.values.flatten().map { YalkutYosef.source(it).hashCode() },
        "cartes" to cartes.map { l ->
            linkedMapOf(
                "seifs" to l.map { linkedMapOf("siman" to it.siman, "lettre" to it.lettre, "texte" to it.texte) },
                "sources" to l.map(YalkutYosef::source),
                "titre" to YalkutYosef.titreCarte(l),
                "texte" to YalkutYosef.texteCarte(l),
            )
        },
    )
}
