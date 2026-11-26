package com.myhitbodedut

import android.content.Context
import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import org.json.JSONArray
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate

/**
 * La lecture de la Torah du jour (demande du 26/11 : « le texte de la paracha concordant le jour de
 * lecture de la Torah ») : quelle lecture à quel office, ses montées et sa haftara, selon Israël ou la
 * diaspora, Jérusalem (Pourim le 15) et le noussa'h.
 *
 * Les données (res/raw/lecture_torah.json, tools/lecture_torah_construction.py) viennent de
 * @hebcal/leyning 10.1.0 (BSD-2-Clause) et des écarts sourcés des Edot ; le calcul suit celui
 * d'hebcal (getLeyningOnDate, specialReadings2), sur KosherJava comme le reste du calendrier
 * (CalendrierJuif.kt). Le jumeau web est web/src/js/lecture-torah.js : web/test/lecture-torah.test.mjs
 * le compare jour par jour à hebcal et écrit web/test/vecteurs_lecture_torah.json, que
 * LectureTorahTest relit ici — les deux réponses sont identiques.
 *
 * Pas d'Android dans le calcul (seul [donnees] et [texte] lisent les ressources) : testable sur la
 * machine virtuelle seule.
 */
object LectureTorah {

    const val CHAHARIT = "chaharit"
    const val MINHA = "minha"
    val OFFICES = listOf(CHAHARIT, MINHA)
    val NUSAH = listOf("edot", "sefard", "ashkenaz")

    data class Montee(val cle: String, val libelle: LocalizedText, val livre: String, val debut: String, val fin: String)
    data class Passage(val livre: String, val debut: String, val fin: String)

    /**
     * Une lecture : [cle] « parasha:VAYETZEI+… », « semaine:VAYETZEI » ou la clé d'hebcal d'une fête ;
     * [raisons] les Chabbatot qui changent le maftir ou la haftara (Chabbat Chekalim…).
     */
    data class Lecture(
        val cle: String,
        val titre: LocalizedText,
        val raisons: List<LocalizedText>,
        val montees: List<Montee>,
        val haftara: List<Passage>,
    )

    /** « Genèse 32:4–13 », « Isaïe 61:10–63:9 » : un passage dans la langue [langue] (les livres de [d]). */
    fun reference(d: Donnees, livre: String, debut: String, fin: String, langue: String): String {
        val nom = d.livres[livre]?.forLanguage(langue) ?: livre
        val (c1, v1) = debut.split(":")
        val (c2, v2) = fin.split(":")
        val plage = when {
            debut == fin -> debut
            c1 == c2 -> "$c1:$v1–$v2"
            else -> "$debut–$fin"
        }
        return "$nom $plage"
    }

    /** [fin] : « פ » ou « ס » quand le verset clôt un paragraphe. */
    data class Verset(val chapitre: Int, val verset: Int, val texte: String, val fin: String?)

    /** Une entrée de lecture_torah.json : listes [montée, livre, début, fin] ou [livre, début, fin]. */
    class Entree(
        val titre: LocalizedText?,
        val alias: String?,
        val champs: Map<String, List<List<String>>>,
        val maftir: Map<String, List<String>>,
        val maftirIsrael: Map<String, List<String>>,
    )

    class Donnees(
        val parachiot: Map<String, Entree>,
        val lectures: Map<String, Entree>,
        val montees: Map<String, LocalizedText>,
        /** Les noms des livres (« Genesis » → בראשית, Genèse, Genesis), pour nommer un passage. */
        val livres: Map<String, LocalizedText> = emptyMap(),
    )

    fun parse(json: String): Donnees {
        val o = JSONObject(json)
        fun listes(a: JSONArray) = (0 until a.length()).map { i -> a.getJSONArray(i).let { x -> (0 until x.length()).map { x.getString(it) } } }
        fun table(t: JSONObject?) = t?.keys()?.asSequence()?.associateWith { k -> t.getJSONArray(k).let { x -> (0 until x.length()).map { x.getString(it) } } }.orEmpty()
        fun entree(e: JSONObject): Entree {
            val champs = mutableMapOf<String, List<List<String>>>()
            e.keys().forEach { k -> if (k.startsWith("alyot") || k.startsWith("haftara") || k == "semaine") champs[k] = listes(e.getJSONArray(k)) }
            return Entree(
                titre = e.optJSONObject("titre")?.let { LocalizedText.parse(it) },
                alias = Json.nullable(e, "alias"),
                champs = champs,
                maftir = table(e.optJSONObject("maftir")),
                maftirIsrael = table(e.optJSONObject("maftir_israel")),
            )
        }
        fun entrees(t: JSONObject) = t.keys().asSequence().associateWith { entree(t.getJSONObject(it)) }
        val m = o.getJSONObject("montees")
        val l = o.getJSONObject("livres")
        return Donnees(
            parachiot = entrees(o.getJSONObject("parachiot")),
            lectures = entrees(o.getJSONObject("lectures")),
            montees = m.keys().asSequence().associateWith { LocalizedText.parse(m.getJSONObject(it)) },
            livres = l.keys().asSequence().associateWith { LocalizedText.parse(l.getJSONObject(it)) },
        )
    }

    // --- Le calendrier --------------------------------------------------------------------------------

    private const val NISSAN = 1
    private const val SIVAN = 3
    private const val AV = 5
    private const val TISHREI = 7

    private fun cal(date: LocalDate, il: Boolean, muk: Boolean) = JewishCalendar(date).apply {
        setInIsrael(il)
        setIsMukafChoma(muk)
    }

    /** Le jour de Sim'hat Torah : 22 Tichri en Israël, 23 en diaspora. */
    private fun simhatTorah(il: Boolean) = if (il) 22 else 23

    /**
     * La paracha lue le Chabbat [date] ou, à défaut (fête), celle qui vient dans le cycle :
     * findParshaHaShavua d'hebcal. Entre Kippour et Sim'hat Torah, Vézot haBérakha.
     */
    fun parachaDeLaSemaine(date: LocalDate, il: Boolean): String {
        var s = date
        while (true) {
            val jc = cal(s, il, false)
            val p = jc.parshah
            if (p != JewishCalendar.Parsha.NONE) return p.name
            if (s == date && jc.jewishMonth == TISHREI && jc.jewishDayOfMonth > 2 && jc.jewishDayOfMonth <= simhatTorah(il)) return "VZOS_HABERACHA"
            s = s.plusDays(7)
        }
    }

    /**
     * Chabbat à Min'ha : le début de la paracha qui suit (Choul'han Aroukh O.H. 135:2 et 292:1, « ואפי'
     * חל יו"ט להיות בשבת קוראין בפרשה הבאה » ; Kitsour Yalkout Yossef 292:5). De Kippour à Sim'hat
     * Torah, Vézot haBérakha, la seule qui reste avant Berèchit.
     */
    fun parachaApres(date: LocalDate, il: Boolean): String {
        val jc = cal(date, il, false)
        val d = jc.jewishDayOfMonth
        if (jc.jewishMonth == TISHREI && d >= 10 && d <= simhatTorah(il)) return "VZOS_HABERACHA"
        return parachaDeLaSemaine(date.plusDays(7), il)
    }

    private fun chabbatSuivant(date: LocalDate): LocalDate =
        date.plusDays(((DayOfWeek.SATURDAY.value - date.dayOfWeek.value + 7) % 7).toLong())

    /** La clé de la lecture d'une fête (holiday-readings.json d'hebcal), en semaine ou un Chabbat sans paracha. */
    fun cleFete(jc: JewishCalendar, date: LocalDate, il: Boolean, muk: Boolean): String? {
        val m = jc.jewishMonth
        val d = jc.jewishDayOfMonth
        val ch = jc.dayOfWeek == 7
        fun sur(cle: String) = if (ch) "$cle (on Shabbat)" else cle
        val yt = jc.yomTovIndex
        if (m == TISHREI) {
            if (d == 1) return sur("Rosh Hashana I")
            if (d == 2) return "Rosh Hashana II"
            if (d == 15) return sur("Sukkot I")
            if (d == 16 && !il) return "Sukkot II"
            if (d >= (if (il) 16 else 17) && d <= 20) {
                if (ch) return "Sukkot Shabbat Chol ha-Moed"
                val n = d - (if (il) 15 else 16)
                return if (il) "Sukkot Chol ha-Moed Day $n (Israel)" else "Sukkot Chol ha-Moed Day $n"
            }
            if (d == 21) return if (il) "Sukkot Final Day (Hoshana Raba) (Israel)" else "Sukkot Final Day (Hoshana Raba)"
            if (d == 22) return if (il) sur("Simchat Torah") else sur("Shmini Atzeret")
            if (d == 23 && !il) return "Simchat Torah"
        }
        if (yt == JewishCalendar.FAST_OF_GEDALYAH) return "Tzom Gedaliah"
        if (yt == JewishCalendar.YOM_KIPPUR) return sur("Yom Kippur")
        if (jc.isChanukah) {
            val j = jc.dayOfChanukah
            val rc = jc.isRoshChodesh
            if (ch && rc) return "Shabbat Rosh Chodesh Chanukah" // toujours le sixième jour
            if (rc && j == 7) return "Chanukah Day 7 (on Rosh Chodesh)"
            if (rc) return "Chanukah Day 6"
            return if (ch) "Chanukah Day $j (on Shabbat)" else "Chanukah Day $j"
        }
        if (yt == JewishCalendar.TENTH_OF_TEVES) return "Asara B'Tevet"
        if (yt == JewishCalendar.FAST_OF_ESTHER) return "Ta'anit Esther"
        if (yt == JewishCalendar.SEVENTEEN_OF_TAMMUZ) return "Tzom Tammuz"
        if (yt == JewishCalendar.TISHA_BEAV) return "Tish'a B'Av"
        // Pourim : le 14, ou le 15 dans une ville murée (Jérusalem), où il est « Chouchan Pourim ».
        if (jc.isPurim && !ch) return if (muk) "Shushan Purim" else "Purim"
        if (m == NISSAN) {
            if (d == 15) return sur("Pesach I")
            if (d == 16) return if (il) "Pesach II (CH''M)" else "Pesach II"
            if (d in 17..20) {
                if (ch) return "Pesach Shabbat Chol ha-Moed"
                // Pessa'h un jeudi : « ראה אתה » (פסל) le Chabbat 17, puis קדש, בכספא, במדברא du dimanche au
                // mardi (Choul'han Aroukh O.H. 490:5 ; Kitsour Yalkout Yossef 488:12, pour Israël aussi : hebcal
                // y relit פסל le lundi et omet קדש, écart voulu).
                val jeudi = date.minusDays((d - 15).toLong()).dayOfWeek == DayOfWeek.THURSDAY
                val n = if (jeudi) mapOf(18 to 1, 19 to 2, 20 to 4).getValue(d) else d - 16
                return "Pesach Chol ha-Moed Day $n"
            }
            if (d == 21) return sur("Pesach VII")
            if (d == 22 && !il) return sur("Pesach VIII")
        }
        if (m == SIVAN) {
            if (d == 6) return if (il) "Shavuot" else "Shavuot I"
            if (d == 7 && !il) return sur("Shavuot II")
        }
        if (jc.isRoshChodesh && !ch) return "Rosh Chodesh"
        return null
    }

    /** Les lectures qui changent le maftir ou la haftara d'un Chabbat à paracha (specialReadings2 d'hebcal). */
    fun speciales(jc: JewishCalendar, p: String, muk: Boolean): List<String> = buildList {
        val rc = jc.isRoshChodesh
        val sp = jc.specialShabbos
        if (sp == JewishCalendar.Parsha.SHUVA) add("Shabbat Shuva (with ${if (p == "VAYEILECH") "Vayeilech" else "Ha'azinu"})")
        if (jc.isChanukah) add(if (rc) "Shabbat Rosh Chodesh Chanukah" else "Chanukah Day ${jc.dayOfChanukah} (on Shabbat)")
        if (sp == JewishCalendar.Parsha.SHKALIM) add(if (rc) "Shabbat Shekalim (on Rosh Chodesh)" else "Shabbat Shekalim")
        if (sp == JewishCalendar.Parsha.ZACHOR) add("Shabbat Zachor")
        if (sp == JewishCalendar.Parsha.PARA) add("Shabbat Parah")
        if (sp == JewishCalendar.Parsha.HACHODESH) add(if (rc) "Shabbat HaChodesh (on Rosh Chodesh)" else "Shabbat HaChodesh")
        if (sp == JewishCalendar.Parsha.HAGADOL) add("Shabbat HaGadol")
        // Jérusalem, Pourim triple : le Chabbat 15 Adar (Choul'han Aroukh O.H. 688:6).
        if (muk && jc.isPurim) add("Shushan Purim (on Shabbat)")
    }

    // --- Les lectures ----------------------------------------------------------------------------------

    private class Resolue(val titre: LocalizedText?, val alyot: List<List<String>>?, val haftara: List<List<String>>?)

    /** Les montées et la haftara d'une entrée pour un noussa'h, alias résolu. */
    private fun entree(d: Donnees, cle: String, nusah: String): Resolue {
        val e = d.lectures[cle] ?: error("lecture inconnue : $cle")
        val base = e.alias?.let { d.lectures.getValue(it) } ?: e
        fun champ(nom: String) = e.champs["${nom}_$nusah"] ?: e.champs[nom] ?: base.champs["${nom}_$nusah"] ?: base.champs[nom]
        return Resolue(e.titre ?: base.titre, champ("alyot"), champ("haftara"))
    }

    /** Le sixième et le septième réunis quand une lecture spéciale prend le septième (mergeAliyotWithSpecial). */
    private fun fusionne(alyot: List<List<String>>, special: List<List<String>>): List<List<String>> {
        val a = alyot.toMutableList()
        for (m in special) {
            when (m[0]) {
                "7" -> {
                    val i6 = a.indexOfFirst { it[0] == "6" }
                    val sept = a.first { it[0] == "7" }
                    a[i6] = a[i6].toMutableList().also { it[3] = sept[3] }
                    a.removeAll { it[0] == "7" }
                    a.add(i6 + 1, m)
                }
                "M" -> {
                    a.removeAll { it[0] == "M" }
                    a.add(m)
                }
                else -> error("montée spéciale inattendue : ${m[0]}")
            }
        }
        return a
    }

    private fun lecture(
        d: Donnees,
        cle: String,
        titre: LocalizedText,
        alyot: List<List<String>>,
        haftara: List<List<String>>?,
        raisons: List<LocalizedText> = emptyList(),
    ): Lecture {
        val trois = alyot.size == 3
        return Lecture(
            cle = cle,
            titre = titre,
            raisons = raisons,
            montees = alyot.map { (c, livre, debut, fin) ->
                Montee(c, d.montees.getValue(if (trois && c == "3") "3_israel" else c), livre, debut, fin)
            },
            haftara = haftara.orEmpty().map { (livre, debut, fin) -> Passage(livre, debut, fin) },
        )
    }

    private fun fete(d: Donnees, cle: String, nusah: String, maftir: List<String>? = null): Lecture {
        val e = entree(d, cle, nusah)
        var alyot = e.alyot.orEmpty()
        if (maftir != null) alyot = alyot + listOf(listOf("M") + maftir)
        return lecture(d, cle, e.titre ?: error("$cle sans titre"), alyot, e.haftara)
    }

    private fun semaine(d: Donnees, p: String): Lecture {
        val e = d.parachiot.getValue(p)
        return lecture(d, "semaine:$p", e.titre!!, e.champs.getValue("semaine"), emptyList())
    }

    private fun chabbat(d: Donnees, jc: JewishCalendar, date: LocalDate, p: String, il: Boolean, muk: Boolean, nusah: String): Lecture {
        val e = d.parachiot.getValue(p)
        var alyot = e.champs["alyot_$nusah"] ?: e.champs.getValue("alyot")
        var haftara = e.champs["haftara_$nusah"] ?: e.champs["haftara"]
        val m = jc.jewishMonth
        val jour = jc.jewishDayOfMonth
        val cles = speciales(jc, p, muk)
        val appliquees = cles.toMutableList()
        var haftaraSpeciale: String? = null
        fun applique(cle: String) {
            val s = entree(d, cle, nusah)
            if (s.haftara != null && haftaraSpeciale == null) haftaraSpeciale = cle
            if (s.haftara != null && haftaraSpeciale == cle) haftara = s.haftara
            if (s.alyot != null) alyot = fusionne(alyot, s.alyot)
        }
        cles.forEach { applique(it) }
        val demain = cal(date.plusDays(1), il, false).jewishDayOfMonth
        val ajout = entree(d, "Ajout Machar Chodesh", nusah).haftara
        if (haftaraSpeciale == null) {
            val cle = when {
                p == "PINCHAS" && jour > 17 -> "Pinchas occurring after 17 Tammuz"
                jour == 30 || jour == 1 -> when (p) {
                    "MASEI", "MATOS_MASEI" -> "Masei on Shabbat Rosh Chodesh"
                    "REEH" -> "Re'eh on Shabbat Rosh Chodesh"
                    else -> "Shabbat Rosh Chodesh"
                }
                p == "KI_SEITZEI" && jour == 14 -> "Ki Teitzei with 3rd Haftarah of Consolation"
                p == "KEDOSHIM" && (jour == 26 || jour == 28 || jour == 6) -> "Kedoshim following Special Shabbat"
                m != AV && (demain == 30 || demain == 1) -> "Shabbat Machar Chodesh"
                else -> null
            }
            if (cle != null) {
                appliquees += cle
                applique(cle)
            }
            // Edot : Roch 'Hodech Chabbat et dimanche, le premier et le dernier verset de « מחר חדש » après
            // « השמים כסאי » (Choul'han Aroukh O.H. 425:2).
            if (nusah == "edot" && cle == "Shabbat Rosh Chodesh" && jour == 30) haftara = haftara.orEmpty() + ajout.orEmpty()
        }
        // Edot : Chabbat Chekalim la veille d'un Roch 'Hodech dimanche, de même (Kitsour Yalkout Yossef, שקלים § 2).
        if (nusah == "edot" && haftaraSpeciale == "Shabbat Shekalim" && (demain == 30 || demain == 1)) haftara = haftara.orEmpty() + ajout.orEmpty()
        val raisons = appliquees.mapNotNull { d.lectures.getValue(it).titre }
        val cle = "parasha:$p" + if (appliquees.isEmpty()) "" else "+" + appliquees.joinToString("+")
        return lecture(d, cle, e.titre!!, alyot, haftara, raisons)
    }

    /**
     * Les lectures d'un office : vide s'il n'y en a pas. [date] : le jour civil de l'office (Cha'harit et
     * Min'ha) ; [office] : [CHAHARIT] ou [MINHA] ; [nusah] : « edot », « sefard » ou « ashkenaz » ;
     * [mukafChoma] : Jérusalem (Pourim le 15), en Israël seulement.
     */
    fun lectures(
        d: Donnees,
        date: LocalDate,
        office: String,
        enIsrael: Boolean,
        mukafChoma: Boolean = false,
        nusah: String = "edot",
    ): List<Lecture> {
        val il = enIsrael
        val muk = mukafChoma && enIsrael
        val jc = cal(date, il, muk)
        val jour = date.dayOfWeek
        if (office == MINHA) {
            if (jc.yomTovIndex == JewishCalendar.YOM_KIPPUR) return listOf(fete(d, "Yom Kippur (Mincha)", nusah))
            if (jc.isTaanis) return listOf(fete(d, "${cleFete(jc, date, il, muk)} (Mincha)", nusah))
            if (jour == DayOfWeek.SATURDAY) return listOf(semaine(d, parachaApres(date, il)))
            return emptyList()
        }
        if (office != CHAHARIT) return emptyList()
        if (jour == DayOfWeek.SATURDAY) {
            val p = jc.parshah
            if (p != JewishCalendar.Parsha.NONE) return listOf(chabbat(d, jc, date, p.name, il, muk, nusah))
            val cle = cleFete(jc, date, il, muk) ?: return emptyList()
            if (cle == "Sukkot Shabbat Chol ha-Moed") {
                val n = (jc.jewishDayOfMonth - (if (il) 15 else 16)).toString()
                val e = d.lectures.getValue(cle)
                return listOf(fete(d, cle, nusah, (if (il) e.maftirIsrael else e.maftir).getValue(n)))
            }
            return listOf(fete(d, cle, nusah))
        }
        val cle = cleFete(jc, date, il, muk)
        if (cle != null) return listOf(fete(d, cle, nusah))
        if (jour == DayOfWeek.MONDAY || jour == DayOfWeek.THURSDAY) return listOf(semaine(d, parachaDeLaSemaine(chabbatSuivant(date), il)))
        return emptyList()
    }

    // --- Le texte « Lecture de la Torah » (26/11, D1) -------------------------------------------------------

    /** L'identifiant du texte « Lecture de la Torah » de la liste du siddour (groupe « Pour certains moments »). */
    const val ID_TEXTE = "lecture_torah"

    /** Son titre, dans les trois langues des titres du siddour. */
    val TITRE = LocalizedText("קְרִיאַת הַתּוֹרָה", "Lecture de la Torah", "Torah reading")

    /**
     * Ce que montre le texte « Lecture de la Torah » : les lectures de [date] (Cha'harit, Min'ha), Chabbat et Yom tov
     * compris ; un jour sans lecture, la Cha'harit du prochain jour de lecture ([aujourdhui] faux, [date] ce jour-là),
     * le plus souvent le Chabbat qui vient : la lecture de lundi ou de jeudi, qui n'est que le début de sa paracha, est
     * passée ; une fête, Roch 'Hodech ou un jeûne qui tombe avant ne l'est pas.
     */
    data class Programme(val date: LocalDate, val aujourdhui: Boolean, val offices: List<Pair<String, List<Lecture>>>)

    fun programme(d: Donnees, date: LocalDate, enIsrael: Boolean, mukafChoma: Boolean = false, nusah: String = "edot"): Programme {
        val offices = OFFICES.map { it to lectures(d, date, it, enIsrael, mukafChoma, nusah) }.filter { it.second.isNotEmpty() }
        if (offices.isNotEmpty()) return Programme(date, true, offices)
        var j = date.plusDays(1)
        while (true) {
            val l = lectures(d, j, CHAHARIT, enIsrael, mukafChoma, nusah)
            if (l.isNotEmpty() && l.none { it.cle.startsWith("semaine:") }) return Programme(j, false, listOf(CHAHARIT to l))
            j = j.plusDays(1)
        }
    }

    // --- Le texte ---------------------------------------------------------------------------------------

    /** lecture_torah_texte.json : les versets lus, livre par livre. */
    class Texte(json: String) {
        private val o = JSONObject(json)
        private val livres = o.getJSONObject("livres")
        private val paragraphes = o.getJSONObject("paragraphes")

        fun versets(p: Passage): List<Verset> = versets(p.livre, p.debut, p.fin)

        fun versets(livre: String, debut: String, fin: String): List<Verset> {
            val (c1, v1) = debut.split(":").map { it.toInt() }
            val (c2, v2) = fin.split(":").map { it.toInt() }
            val chapitres = livres.getJSONObject(livre)
            val fins = paragraphes.optJSONObject(livre)
            return buildList {
                for (c in c1..c2) {
                    val chapitre = chapitres.optJSONArray(c.toString()) ?: error("$livre $c : chapitre absent")
                    val premier = if (c == c1) v1 else 1
                    val dernier = if (c == c2) v2 else chapitre.length()
                    for (v in premier..dernier) add(Verset(c, v, chapitre.getString(v - 1), fins?.let { Json.nullable(it, "$c:$v") }))
                }
            }
        }
    }

    // --- Les ressources ----------------------------------------------------------------------------------

    @Volatile
    private var donneesLues: Donnees? = null

    @Volatile
    private var texteLu: Texte? = null

    /** Les lectures (117 ko), lues une fois par processus. */
    fun donnees(context: Context): Donnees =
        donneesLues ?: synchronized(this) {
            donneesLues ?: parse(Json.readRaw(context.applicationContext, R.raw.lecture_torah)).also { donneesLues = it }
        }

    /** Le texte s'il est déjà lu, sans le lire : l'écran le demande hors du fil principal sinon. */
    fun texteEnMemoire(): Texte? = texteLu

    /** Le texte (2,2 Mo) : hors du fil principal, une fois par processus. */
    fun texte(context: Context): Texte =
        texteLu ?: synchronized(this) {
            texteLu ?: Texte(Json.readRaw(context.applicationContext, R.raw.lecture_torah_texte)).also { texteLu = it }
        }
}
