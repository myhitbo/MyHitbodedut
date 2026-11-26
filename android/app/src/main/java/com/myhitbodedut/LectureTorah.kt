package com.myhitbodedut

import android.content.Context
import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import org.json.JSONArray
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate

/**
 * La lecture de la Torah des offices de semaine (demande du 26/11 : « le texte de la paracha concordant le jour de
 * lecture de la Torah ») : à Cha'harit le lundi et le jeudi, à Roch 'Hodech, à 'Hol hamoèd, à 'Hanouka, à Pourim et
 * aux jeûnes publics (9 Av compris), à Min'ha des jeûnes publics ; jamais Chabbat ni Yom tov, dont le siddour n'a pas
 * l'office. Ses montées selon Israël ou la diaspora, Jérusalem (Pourim le 15) et le noussa'h.
 *
 * Les données (res/raw/lecture_torah.json, tools/lecture_torah_construction.py) viennent de
 * @hebcal/leyning 10.1.0 (BSD-2-Clause) et des écarts sourcés des Edot ; le calcul suit celui
 * d'hebcal (getLeyningOnDate), sur KosherJava comme le reste du calendrier (CalendrierJuif.kt).
 * Le jumeau web est web/src/js/lecture-torah.js : web/test/lecture-torah.test.mjs le compare jour
 * par jour à hebcal et écrit web/test/vecteurs_lecture_torah.json, que LectureTorahTest relit ici —
 * les deux réponses sont identiques.
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

    /** Une lecture : [cle] « semaine:VAYETZEI » (lundi et jeudi) ou la clé d'hebcal d'un jour (« Rosh Chodesh »…). */
    data class Lecture(val cle: String, val titre: LocalizedText, val montees: List<Montee>)

    /** « Berèchit 32:4–13 » : un passage dans la langue [langue] (les livres de [d]). */
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

    /** Une entrée de lecture_torah.json : listes [montée, livre, début, fin]. */
    class Entree(
        val titre: LocalizedText?,
        val alias: String?,
        val champs: Map<String, List<List<String>>>,
    )

    class Donnees(
        val parachiot: Map<String, Entree>,
        val lectures: Map<String, Entree>,
        val montees: Map<String, LocalizedText>,
        /** Les noms des livres (« Genesis » → בראשית, Berèchit, Bereshit), pour nommer un passage. */
        val livres: Map<String, LocalizedText> = emptyMap(),
    )

    fun parse(json: String): Donnees {
        val o = JSONObject(json)
        fun listes(a: JSONArray) = (0 until a.length()).map { i -> a.getJSONArray(i).let { x -> (0 until x.length()).map { x.getString(it) } } }
        fun entree(e: JSONObject): Entree {
            val champs = mutableMapOf<String, List<List<String>>>()
            e.keys().forEach { k -> if (k.startsWith("alyot") || k == "semaine") champs[k] = listes(e.getJSONArray(k)) }
            return Entree(
                titre = e.optJSONObject("titre")?.let { LocalizedText.parse(it) },
                alias = Json.nullable(e, "alias"),
                champs = champs,
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

    private fun chabbatSuivant(date: LocalDate): LocalDate =
        date.plusDays(((DayOfWeek.SATURDAY.value - date.dayOfWeek.value + 7) % 7).toLong())

    /**
     * La clé de la lecture d'un jour de semaine qui n'est pas un lundi ou un jeudi ordinaire (holiday-readings.json
     * d'hebcal) : Roch 'Hodech, 'Hol hamoèd, 'Hanouka, Pourim, jeûnes ; null sinon. [jc] n'est ni Chabbat ni Yom tov.
     */
    fun cleFete(jc: JewishCalendar, date: LocalDate, il: Boolean, muk: Boolean): String? {
        val m = jc.jewishMonth
        val d = jc.jewishDayOfMonth
        val yt = jc.yomTovIndex
        if (m == TISHREI) {
            if (d >= (if (il) 16 else 17) && d <= 20) {
                val n = d - (if (il) 15 else 16)
                return if (il) "Sukkot Chol ha-Moed Day $n (Israel)" else "Sukkot Chol ha-Moed Day $n"
            }
            if (d == 21) return if (il) "Sukkot Final Day (Hoshana Raba) (Israel)" else "Sukkot Final Day (Hoshana Raba)"
        }
        if (yt == JewishCalendar.FAST_OF_GEDALYAH) return "Tzom Gedaliah"
        if (jc.isChanukah) {
            val j = jc.dayOfChanukah
            val rc = jc.isRoshChodesh
            if (rc && j == 7) return "Chanukah Day 7 (on Rosh Chodesh)"
            if (rc) return "Chanukah Day 6"
            return "Chanukah Day $j"
        }
        if (yt == JewishCalendar.TENTH_OF_TEVES) return "Asara B'Tevet"
        if (yt == JewishCalendar.FAST_OF_ESTHER) return "Ta'anit Esther"
        if (yt == JewishCalendar.SEVENTEEN_OF_TAMMUZ) return "Tzom Tammuz"
        if (yt == JewishCalendar.TISHA_BEAV) return "Tish'a B'Av"
        // Pourim : le 14, ou le 15 dans une ville murée (Jérusalem), où il est « Chouchan Pourim ».
        if (jc.isPurim) return if (muk) "Shushan Purim" else "Purim"
        if (m == NISSAN) {
            if (d == 16) return "Pesach II (CH''M)" // en Israël ; en diaspora, Yom tov
            if (d in 17..20) {
                // Pessa'h un jeudi : « ראה אתה » (פסל) le Chabbat 17, puis קדש, בכספא, במדברא du dimanche au
                // mardi (Choul'han Aroukh O.H. 490:5 ; Kitsour Yalkout Yossef 488:12, pour Israël aussi : hebcal
                // y relit פסל le lundi et omet קדש, écart voulu).
                val jeudi = date.minusDays((d - 15).toLong()).dayOfWeek == DayOfWeek.THURSDAY
                val n = if (jeudi) mapOf(18 to 1, 19 to 2, 20 to 4).getValue(d) else d - 16
                return "Pesach Chol ha-Moed Day $n"
            }
        }
        if (jc.isRoshChodesh) return "Rosh Chodesh"
        return null
    }

    // --- Les lectures ----------------------------------------------------------------------------------

    /** Les montées d'une entrée pour un noussa'h, alias résolu. */
    private fun fete(d: Donnees, cle: String, nusah: String): Lecture {
        val e = d.lectures[cle] ?: error("lecture inconnue : $cle")
        val base = e.alias?.let { d.lectures.getValue(it) } ?: e
        val alyot = e.champs["alyot_$nusah"] ?: e.champs["alyot"] ?: base.champs["alyot_$nusah"] ?: base.champs.getValue("alyot")
        return lecture(d, cle, e.titre ?: base.titre ?: error("$cle sans titre"), alyot)
    }

    private fun lecture(d: Donnees, cle: String, titre: LocalizedText, alyot: List<List<String>>): Lecture {
        val trois = alyot.size == 3
        return Lecture(cle, titre, alyot.map { (c, livre, debut, fin) ->
            Montee(c, d.montees.getValue(if (trois && c == "3") "3_israel" else c), livre, debut, fin)
        })
    }

    private fun semaine(d: Donnees, p: String): Lecture {
        val e = d.parachiot.getValue(p)
        return lecture(d, "semaine:$p", e.titre!!, e.champs.getValue("semaine"))
    }

    /**
     * Les lectures d'un office de semaine : vide s'il n'y en a pas, et toujours un Chabbat ou un Yom tov. [date] : le
     * jour civil de l'office ; [office] : [CHAHARIT] ou [MINHA] ; [nusah] : « edot », « sefard » ou « ashkenaz » ;
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
        if (jc.isAssurBemelacha) return emptyList()
        if (office == MINHA) return if (jc.isTaanis) listOf(fete(d, "${cleFete(jc, date, il, muk)} (Mincha)", nusah)) else emptyList()
        if (office != CHAHARIT) return emptyList()
        val cle = cleFete(jc, date, il, muk)
        if (cle != null) return listOf(fete(d, cle, nusah))
        val jour = date.dayOfWeek
        if (jour == DayOfWeek.MONDAY || jour == DayOfWeek.THURSDAY) return listOf(semaine(d, parachaDeLaSemaine(chabbatSuivant(date), il)))
        return emptyList()
    }

    /**
     * La lecture d'un office de semaine du siddour, à sa place (26/11) : à Cha'harit les jours où l'on lit
     * ([CalendrierJuif.C.KRIAT_HATORAH] : lundi, jeudi, Roch 'Hodech, 'Hol hamoed, 'Hanouka, Pourim, jeûnes), à Min'ha
     * les jours de jeûne ; jamais un Chabbat ni un Yom tov (le siddour n'en a pas l'office : « Pas de Yom Tov »).
     */
    fun lecturesOffice(d: Donnees, date: LocalDate, office: String, enIsrael: Boolean, mukafChoma: Boolean = false, nusah: String = "edot"): List<Lecture> =
        if (litDansLOffice(CalendrierJuif.jour(date, enIsrael, mukafChoma), office)) lectures(d, date, office, enIsrael, mukafChoma, nusah) else emptyList()

    /** Le jour [j] a-t-il une lecture à l'office de semaine [office] (sans lire les données) ? */
    fun litDansLOffice(j: CalendrierJuif.Jour, office: String): Boolean = !j.chome && when (office) {
        CHAHARIT -> CalendrierJuif.C.KRIAT_HATORAH in j.conditions
        MINHA -> CalendrierJuif.C.JEUNE in j.conditions
        else -> false
    }

    // --- Le texte ---------------------------------------------------------------------------------------

    /** lecture_torah_texte.json : les chapitres lus, livre par livre, et les fins de paragraphe. */
    class Texte(json: String) {
        private val o = JSONObject(json)
        private val livres = o.getJSONObject("livres")
        private val paragraphes = o.optJSONObject("paragraphes") ?: JSONObject()

        fun versets(m: Montee): List<Verset> = versets(m.livre, m.debut, m.fin)

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

    /** Les lectures (43 ko), lues une fois par processus. */
    fun donnees(context: Context): Donnees =
        donneesLues ?: synchronized(this) {
            donneesLues ?: parse(Json.readRaw(context.applicationContext, R.raw.lecture_torah)).also { donneesLues = it }
        }

    /** Le texte s'il est déjà lu, sans le lire : l'écran le demande hors du fil principal sinon. */
    fun texteEnMemoire(): Texte? = texteLu

    /** Le texte (0,6 Mo) : hors du fil principal, une fois par processus. */
    fun texte(context: Context): Texte =
        texteLu ?: synchronized(this) {
            texteLu ?: Texte(Json.readRaw(context.applicationContext, R.raw.lecture_torah_texte)).also { texteLu = it }
        }
}
