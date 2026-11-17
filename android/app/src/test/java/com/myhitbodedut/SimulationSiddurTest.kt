package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import com.kosherjava.zmanim.hebrewcalendar.JewishDate
import java.time.LocalDate

/**
 * La lecture du siddour simulée chaque jour des quatorze sortes d'années hébraïques (demandes du 12/11) :
 * 5779 à 5790 de suite, plus 5795, 5797 et 5812, les trois sortes qui manquent entre-temps ; chacune de
 * la veille de Roch Hachana au lendemain de Sim'hat Torah suivant. Embolismiques ou non, déficientes,
 * régulières ou pleines, Roch Hachana lundi, mardi, jeudi ou Chabbat ; avec les cas rares qui en
 * découlent : Pourim triple à Jérusalem, veille de Pessa'h un Chabbat, 9 Av reporté au dimanche,
 * Roch 'Hodech Tévèt d'un seul jour, jeûne de Tévèt un vendredi, Pourim Katan ;
 * en diaspora, en Israël, à Jérusalem (Pourim le 15) et, pour les Edot, dans l'hémisphère sud ;
 * dans les trois noussa'h.
 *
 * Deux vérifications :
 * - rien n'est jamais retiré : tous les replis ouverts, chaque bloc du texte revient ;
 * - chaque passage lié à un moment se lit en clair le jour où il se dit, et seulement ce
 *   jour-là (replié, ou estompé dans un ajout du jour), et ce qui se dit tous les jours
 *   n'est jamais replié (« הרחמן », la fin de Modim, « עושה שלום »).
 */
class SimulationSiddurTest {

    private val json = File("src/main/res/raw/siddur_annotations.json").readText()
    private val siddurs = Nusah.entries.associateWith { DataFiles.siddur(it) }
    private val annotations = Nusah.entries.associateWith { SiddurJour.parse(json, it.cle) }
    private fun rochHachana(annee: Int): LocalDate =
        com.kosherjava.zmanim.hebrewcalendar.JewishCalendar(annee, JewishDate.TISHREI, 1).localDate
    private val annees = (5779..5790) + listOf(5795, 5797, 5812)
    private val jours = annees.flatMap { a ->
        generateSequence(rochHachana(a).minusDays(1)) { it.plusDays(1) }.takeWhile { !it.isAfter(rochHachana(a + 1).plusDays(23)) }.toList()
    }.distinct().sorted()
    /** Un jour par lieu, calculé une fois pour tous les tests. */
    private val calendrier = HashMap<Triple<LocalDate, Boolean, Boolean>, CalendrierJuif.Jour>()
    private fun jour(date: LocalDate, israel: Boolean, muree: Boolean = false) =
        calendrier.getOrPut(Triple(date, israel, muree)) { CalendrierJuif.jour(date, israel, muree) }

    private class Lieu(val nom: String, val israel: Boolean, val muree: Boolean = false, val sud: Boolean = false)
    private val lieux = listOf(Lieu("diaspora", false), Lieu("Israël", true), Lieu("Jérusalem", true, muree = true), Lieu("sud", false, sud = true))

    /** Sans balises, voyelles, ponctuation de citation ni espaces : un passage se retrouve d'une édition à l'autre. */
    private fun plat(t: String) = t.replace(Regex("<[^>]+>"), "").replace(Regex("[\\u0591-\\u05C7\\s״׳\"'()]"), "")
    private val platDe = java.util.IdentityHashMap<SiddurBloc, String>()
    private fun platBloc(b: SiddurBloc) = platDe.getOrPut(b) { plat(b.texte) }

    private class Regle(val textes: Set<String>, val phrase: String, val quand: (Set<String>) -> Boolean, val nusah: Set<Nusah> = Nusah.entries.toSet())

    private val C = CalendrierJuif.C
    private val AMIDOT = setOf("chaharit", "minha", "arvit")
    private val TOUJOURS: (Set<String>) -> Boolean = { true }
    private fun si(cle: String): (Set<String>) -> Boolean = { cle in it }

    private val regles = listOf(
        // Birkat haMazon.
        Regle(setOf("birkat_hamazon"), "רצה והחליצנו", si(C.CHABBAT)),
        Regle(setOf("birkat_hamazon"), "יעלה ויבא", si(C.YAALE_VEYAVO)),
        Regle(setOf("birkat_hamazon"), "שכלו שבת", si(C.CHABBAT)),
        Regle(setOf("birkat_hamazon"), "יחדש עלינו את החדש הזה", si(C.ROCH_HODECH)),
        Regle(setOf("birkat_hamazon"), "יחדש עלינו את השנה הזאת", si(C.ROCH_HACHANA)),
        Regle(setOf("birkat_hamazon"), "סכת דוד הנופלת", si(C.SOUKKOT)),
        Regle(setOf("birkat_hamazon"), "ינחילנו יום שכלו טוב", si(C.YOM_TOV)),
        Regle(setOf("birkat_hamazon"), "למועדים אחרים", si(C.MOED)),
        Regle(setOf("birkat_hamazon"), "הרחמן הוא יפרנסנו", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "הרחמן הוא ישתבח", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "הרחמן הוא ישלח לנו את אליהו", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "הרחמן הוא יברך", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "במרום ילמדו", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "ישועות מלכו", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "עשה שלום במרומיו", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "יראו את יהוה קדושיו", TOUJOURS),
        Regle(setOf("birkat_hamazon"), "בונה ברחמיו ירושלים", TOUJOURS),
        // Les Amidot, et le Moussaf de Roch 'Hodech.
        Regle(AMIDOT, "יעלה ויבא", si(C.YAALE_VEYAVO)),
        Regle(AMIDOT + "moussaf_rosh_hodech" + "birkat_hamazon", "בימי מתתיהו בן יוחנן", { C.HANOUKA in it && C.AL_HANISSIM in it }),
        Regle(AMIDOT, "בימי מרדכי ואסתר בשושן", { C.POURIM in it && C.AL_HANISSIM in it }),
        Regle(setOf("birkat_hamazon"), "בימי מרדכי ואסתר בשושן", { C.POURIM in it && C.AL_HANISSIM in it }, setOf(Nusah.SEFARD, Nusah.ASHKENAZ)),
        // Edot : aussi dans le « הרחמן » du festin du dimanche à Jérusalem, Pourim triple (Yalkut Yosef 688:6, § 15).
        Regle(setOf("birkat_hamazon"), "בימי מרדכי ואסתר בשושן", { (C.POURIM in it && C.AL_HANISSIM in it) || C.POURIM_TRIPLE_FESTIN in it }, setOf(Nusah.EDOT)),
        Regle(setOf("birkat_hamazon"), "הרחמן הוא יעשה לנו נסים ונפלאות", si(C.POURIM_TRIPLE_FESTIN), setOf(Nusah.EDOT)),
        Regle(AMIDOT + "moussaf_rosh_hodech", "ועל כלם", TOUJOURS),
        Regle(AMIDOT + "moussaf_rosh_hodech", "הטוב שמך ולך נאה להודות", TOUJOURS),
        Regle(AMIDOT, "המלך הקדוש", si(C.ASSERET_YEMEI_TECHOUVA)),
        Regle(AMIDOT + "moussaf_rosh_hodech", "משיב הרוח ומוריד הגשם", si(C.MACHIV_HAROUAH)),
        Regle(AMIDOT + "moussaf_rosh_hodech", "מוריד הטל", si(C.MORID_HATAL)),
        Regle(AMIDOT, "טל ומטר", si(C.TAL_OUMATAR)),
        Regle(AMIDOT, "ברכנו יהוה אלהינו בכל", si(C.BERAKHA)),
        Regle(setOf("arvit"), "אתה חוננתנו", si(C.MOTSAE_CHABBAT_YT)),
        // Na'hem : Edot aux trois offices (audit du 16/11 ; Yalkut Yosef, Kitsour 557:1), Sfard et Ashkenaz à Min'ha (Rema 557:1).
        Regle(AMIDOT, "נחם יהוה אלהינו", si(C.TICHA_BEAV), setOf(Nusah.EDOT)),
        Regle(setOf("minha"), "נחם יהוה אלהינו", si(C.TICHA_BEAV), setOf(Nusah.SEFARD, Nusah.ASHKENAZ)),
        Regle(AMIDOT, "מנחם ציון בבנין ירושלים", si(C.TICHA_BEAV), setOf(Nusah.EDOT)),
        // « שלום רב » d'un jeûne public (Ashkenaz, Min'ha : audit du 16/11 ; Rema 127:2).
        Regle(setOf("minha"), "שלום רב על ישראל עמך", { C.JEUNE !in it }, setOf(Nusah.ASHKENAZ)),
        Regle(setOf("chaharit"), "ויאמר דוד אל גד", si(C.TAHANOUN_CHAHARIT)),
        // Le retour du Sefer Torah, les seuls jours de lecture (12/11 : Edot et Sfard l'affichaient tous les jours).
        Regle(setOf("chaharit"), "ובנחה יאמר שובה יהוה", si(C.KRIAT_HATORAH)),
        // 12/11 : « שעשה לי כל צרכי » (Edot) pas le 9 Av ni à Kippour ; la fin du Kaddich après le Hallel pas à 'Hanouka.
        Regle(setOf("birkot_hachahar"), "שעשה לי כל צרכי", { C.TICHA_BEAV_KIPPOUR !in it }, setOf(Nusah.EDOT)),
        // Audit du 16/11 : sauf à Roch 'Hodech Tévèt et le Chabbat de 'Hanouka, jours de Moussaf (Kitsour Yalkout Yossef 423:1).
        Regle(setOf("hallel"), "תתקבל", { C.HANOUKA !in it || C.ROCH_HODECH in it || C.CHABBAT in it }),
        Regle(setOf("minha"), "ויאמר דוד אל גד", si(C.TAHANOUN_MINHA)),
        // Avinou malkénou (Ashkenaz, Sfard) ; à Min'ha, pas la veille de Chabbat (12/11 : jeûne de Tévèt un vendredi).
        Regle(setOf("chaharit"), "אבינו מלכנו חטאנו לפניך", si(C.AVINOU_MALKENOU), setOf(Nusah.ASHKENAZ, Nusah.SEFARD)),
        Regle(setOf("minha"), "אבינו מלכנו חטאנו לפניך", si(C.AVINOU_MALKENOU_MINHA), setOf(Nusah.ASHKENAZ, Nusah.SEFARD)),
        // Audit du 16/11 (Ta'hanoun et ce qui en dépend).
        // עלינו suit chacun des trois offices, sans lien avec le Ta'hanoun (Michna Beroura 132:7).
        Regle(setOf("minha"), "עלינו לשבח לאדון הכל", TOUJOURS),
        // אל ארך אפים suit למנצח (Michna Beroura 131:35 ; consigne Sfard, Dérekh ha'Haïm), le lundi et le jeudi (ShA haRav 429:12).
        Regle(setOf("chaharit"), "אל ארך אפים ומלא רחמים אל תסתר פניך ממנו", { C.LAMNATSEAH in it && (C.JOURS_SEMAINE[1] in it || C.JOURS_SEMAINE[4] in it) }, setOf(Nusah.SEFARD)),
        Regle(setOf("chaharit"), "אל ארך אפים ורב חסד ואמת אל באפך תוכיחנו", { C.LAMNATSEAH in it && (C.JOURS_SEMAINE[1] in it || C.JOURS_SEMAINE[4] in it) }, setOf(Nusah.ASHKENAZ)),
        // Le piyout du lundi et du jeudi (Aroukh haChoul'han 134:1-2), le Vidouï ashkénaze (Michna Beroura 134:1).
        Regle(setOf("chaharit"), "זרים אומרים אין תוחלת ותקוה", si(C.LUNDI_JEUDI), setOf(Nusah.ASHKENAZ, Nusah.SEFARD)),
        Regle(setOf("chaharit"), "אשמנו בגדנו גזלנו", si(C.LUNDI_JEUDI), setOf(Nusah.ASHKENAZ)),
        // Tsom Guedalia : les lignes des dix jours seulement (Matté Efraïm 602:13).
        Regle(setOf("chaharit"), "אבינו מלכנו ברך עלינו שנה טובה", { C.AVINOU_MALKENOU in it && C.ASSERET_YEMEI_TECHOUVA !in it && C.JEUNE in it },
            setOf(Nusah.ASHKENAZ, Nusah.SEFARD)),
        Regle(setOf("chaharit"), "אבינו מלכנו זכרנו לחיים טובים", { C.AVINOU_MALKENOU in it && C.ASSERET_YEMEI_TECHOUVA !in it && C.JEUNE in it },
            setOf(Nusah.ASHKENAZ, Nusah.SEFARD)),
        // Edot, le Chabbat des dix jours : sans les lignes de faute (Kitsour Yalkout Yossef 582/602:24).
        Regle(setOf("chaharit", "minha"), "אבינו מלכנו מחה והעבר פשעינו", { C.ASSERET_YEMEI_TECHOUVA in it && C.CHABBAT !in it }, setOf(Nusah.EDOT)),
        // Méèn chaloch.
        Regle(setOf("meen_chaloch"), "ורצה והחליצנו", si(C.CHABBAT)),
        Regle(setOf("meen_chaloch"), "ביום הזכרון הזה", si(C.ROCH_HACHANA)),
    )

    @Test
    fun `chaque jour, chaque passage du moment se lit le jour dit et rien ne se perd`() {
        val ecarts = sortedMapOf<String, MutableList<LocalDate>>()
        var verifications = 0
        // Les jours de mêmes conditions se lisent pareil : une lecture par lieu et jeu de conditions.
        val lus = HashMap<Pair<String, Set<String>>, Pair<List<String>, Int>>()
        for (lieu in lieux) for (date in jours) {
            val conditions = jour(date, lieu.israel, lieu.muree).conditions
            val (trouves, faites) = lus.getOrPut(lieu.nom to conditions) { lire(lieu, conditions) }
            trouves.forEach { ecarts.getOrPut(it) { mutableListOf() } += date }
            verifications += faites
        }
        val rapport = ecarts.entries.joinToString("\n") { (k, v) -> "$k : ${v.size} jour(s), dont ${v.take(4).joinToString()}" }
        assertTrue("Écarts :\n$rapport", ecarts.isEmpty())
        assertTrue("la simulation a tourné ($verifications)", verifications > 1_000_000)
    }

    /** Les écarts d'un lieu pour un jeu de conditions, et le nombre de vérifications faites. */
    private fun lire(lieu: Lieu, conditions: Set<String>): Pair<List<String>, Int> {
        val ecarts = mutableListOf<String>()
        var verifications = 0
        val textes = setOf("chaharit", "minha", "arvit", "birkat_hamazon", "meen_chaloch", "moussaf_rosh_hodech", "hallel", "birkot_hachahar")
        // Les consignes d'oubli (12/11) : toujours repliées, jamais en clair.
        val oubli = Regex("^\\(?(טעה|שכח|אם שכח|אם טעה|ואם טעה|אם לא אמר|ואם לא אמר)(?=\\s|:|$)|^בכל השנה אם אמר המלך המשפט")
        for (n in Nusah.entries) {
            if (lieu.sud && n != Nusah.EDOT) continue
            val c = SiddurJour.conditionsPour(n.cle, lieu.israel, conditions, sud = lieu.sud)
            for (id in textes) {
                val texte = siddurs.getValue(n).texte(id) ?: continue
                val ann = annotations.getValue(n)[id].orEmpty()
                val lignes = SiddurJour.lignes(texte, ann, conditions, nusah = n.cle, enIsrael = lieu.israel, sud = lieu.sud)
                // Rien n'est retiré : tous les replis ouverts, chaque bloc revient, une fois.
                val cles = lignes.filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }.toSet()
                val tout = SiddurJour.lignes(texte, ann, conditions, cles, n.cle, lieu.israel, sud = lieu.sud)
                val vus = tout.filterIsInstance<SiddurJour.Ligne.Bloc>().map { it.bloc }
                if (vus.size != texte.sections.sumOf { it.blocs.size } ||
                    texte.sections.any { s -> s.blocs.any { b -> vus.none { it === b } } }) {
                    ecarts += "${n.cle} $id ${lieu.nom} : un bloc manque, replis ouverts"
                }
                if (lignes.any { it is SiddurJour.Ligne.Bloc && it.bloc.consigne && oubli.containsMatchIn(SiddurJour.empreinte(it.bloc.texte)) }) {
                    ecarts += "${n.cle} $id ${lieu.nom} : consigne d'oubli en clair"
                }
                // Les passages du moment.
                for (r in regles) {
                    if (id !in r.textes || n !in r.nusah) continue
                    val p = plat(r.phrase)
                    if (texte.sections.none { s -> s.blocs.any { !it.consigne && platBloc(it).contains(p) } }) continue
                    val clair = lignes.any {
                        it is SiddurJour.Ligne.Bloc && it.style != SiddurJour.Style.HORS && !it.bloc.consigne &&
                            (if (it.bloc.texte.length == 0) false else (platDe[it.bloc] ?: plat(it.bloc.texte)).contains(p))
                    }
                    verifications++
                    val attendu = r.quand(c)
                    if (clair != attendu) {
                        ecarts += "${n.cle} $id ${lieu.nom} « ${r.phrase} » ${if (attendu) "replié le jour dit" else "en clair hors du jour"}"
                    }
                }
            }
        }
        return ecarts to verifications
    }

    /** « מגדול » à la fin du Birkat (12/11) : les jours de Moussaf en Edot, Chabbat et Yom tov en Ashkenaz et en Sfard ; une fois. */
    @Test
    fun `migdol les jours dits, une seule fois`() {
        val jours = mapOf(Nusah.EDOT to setOf(C.CHABBAT, C.ROCH_HODECH, C.MOED, C.YOM_TOV), Nusah.ASHKENAZ to setOf(C.CHABBAT, C.YOM_TOV), Nusah.SEFARD to setOf(C.CHABBAT, C.YOM_TOV))
        for ((n, cles) in jours) for (date in this.jours) for (israel in listOf(false, true)) {
            val c = jour(date, israel).conditions
            val l = SiddurJour.lignes(siddurs.getValue(n).texte("birkat_hamazon")!!, annotations.getValue(n).getValue("birkat_hamazon"), c, nusah = n.cle, enIsrael = israel)
            val migdol = l.count { it is SiddurJour.Ligne.Indice && plat(it.texte) == "מגדול" }
            assertEquals("${n.cle} $date ${if (israel) "Israël" else "diaspora"}", if (cles.any { it in c }) 1 else 0, migdol)
        }
    }

    /** Motsaé Chabbat : l'Arvit du samedi soir est celle de dimanche, « אתה חוננתנו » et « ויהי נועם » en clair. */
    @Test
    fun `motsae chabbat - arvit du samedi soir`() {
        val samedi = LocalDate.parse("2026-11-14")
        val jour = CalendrierJuif.jourDeLaPriere("arvit", samedi, java.time.LocalTime.of(20, 0))
        assertEquals(samedi.plusDays(1), jour)
        val c = CalendrierJuif.jour(jour, false).conditions
        for (n in Nusah.entries) {
            val texte = siddurs.getValue(n).texte("arvit")!!
            val l = SiddurJour.lignes(texte, annotations.getValue(n).getValue("arvit"), c, nusah = n.cle)
            fun clair(p: String) = l.any { it is SiddurJour.Ligne.Bloc && it.style != SiddurJour.Style.HORS && plat(it.bloc.texte).contains(plat(p)) }
            assertTrue("${n.cle} : אתה חוננתנו", clair("אתה חוננתנו"))
            assertTrue("${n.cle} : ויהי נעם", clair("ויהי נעם"))
            // Le samedi après-midi, Min'ha reste de Chabbat ; le dimanche soir, plus de motsaé Chabbat.
            val lundi = CalendrierJuif.jour(CalendrierJuif.jourDeLaPriere("arvit", samedi.plusDays(1), java.time.LocalTime.of(20, 0)), false).conditions
            val l2 = SiddurJour.lignes(texte, annotations.getValue(n).getValue("arvit"), lundi, nusah = n.cle)
            assertTrue("${n.cle} : dimanche soir", l2.none { it is SiddurJour.Ligne.Bloc && it.style != SiddurJour.Style.HORS && plat(it.bloc.texte).contains(plat("אתה חוננתנו")) })
        }
    }

    /** Le Birkat Sfard complété (12/11) : les הרחמן des jours et la fin, du Metsudah 1981, après « בַּמָּרוֹם ». */
    @Test
    fun `birkat sefard - harahaman des jours et fin presents`() {
        val blocs = siddurs.getValue(Nusah.SEFARD).texte("birkat_hamazon")!!.sections[0].blocs.map { plat(it.texte) }
        val bamarom = blocs.indexOfFirst { it.startsWith(plat("במרום ילמדו")) }
        listOf("שכלו שבת", "יחדש עלינו את החדש הזה", "ינחילנו יום שכלו טוב", "יחדש עלינו את השנה הזאת",
            "סכת דוד הנופלת", "עשה שלום במרומיו", "יראו את יהוה קדושיו").forEach { p ->
            val k = blocs.indexOfFirst { it.contains(plat(p)) }
            assertTrue(p, k > bamarom && k < blocs.indexOfFirst { it.contains(plat("שהכל ברא לכבודו")) })
        }
    }

    /**
     * Aucun repli figé : chaque condition d'annotation est vraie certains jours de la période et fausse
     * d'autres, sauf celles qui ne sont jamais du jour par construction (minyan, oubli, zimoun…).
     */
    @Test
    fun `chaque condition de repli change avec les jours`() {
        val jamais = setOf(C.MINYAN, C.OUBLI, C.CHEVA_BERAKHOT, C.ZIMUN, C.FACULTATIF, C.BEIT_AVEL)
        val vues = mutableMapOf<String, MutableSet<Boolean>>()
        for (lieu in lieux) for (date in jours) {
            val jour = jour(date, lieu.israel, lieu.muree)
            for (n in Nusah.entries) {
                if (lieu.sud && n != Nusah.EDOT) continue
                val c = SiddurJour.conditionsPour(n.cle, lieu.israel, jour.conditions, sud = lieu.sud)
                annotations.getValue(n).values.flatten().forEach { a ->
                    listOfNotNull(a.condition, a.racine).forEach { k -> vues.getOrPut("${n.cle} $k") { mutableSetOf() } += SiddurJour.vrai(k, c) }
                }
            }
        }
        val figees = vues.filter { (k, v) -> v.size < 2 && k.substringAfter(' ').removePrefix("!") !in jamais }
        assertTrue("Conditions figées : $figees", figees.isEmpty())
    }

    /** « Discret » (12/11) : « שעשה לי כל צרכי » en clair sans étiquette d'ordinaire, replié le 9 Av. */
    @Test
    fun `discret - en clair sans etiquette, replie le jour sans`() {
        val texte = siddurs.getValue(Nusah.EDOT).texte("birkot_hachahar")!!
        val ann = annotations.getValue(Nusah.EDOT).getValue("birkot_hachahar")
        val ordinaire = SiddurJour.lignes(texte, ann, CalendrierJuif.jour(LocalDate.parse("2026-11-12"), false).conditions)
        assertTrue(ordinaire.none { it is SiddurJour.Ligne.Etiquette })
        assertTrue(ordinaire.any { it is SiddurJour.Ligne.Bloc && it.style == SiddurJour.Style.NORMAL && plat(it.bloc.texte).contains(plat("שעשה לי כל צרכי")) })
        val av = SiddurJour.lignes(texte, ann, CalendrierJuif.jour(LocalDate.parse("2026-07-23"), false).conditions)
        assertTrue(av.any { it is SiddurJour.Ligne.Replie && it.libelle == "ajout_sauf_ticha_beav_kippour" })
        assertTrue(av.none { it is SiddurJour.Ligne.Bloc && plat(it.bloc.texte).contains(plat("שעשה לי כל צרכי")) })
    }

    /** Les situations demandées, nommées : Roch 'Hodech, motsaé Chabbat, fêtes, jeûnes, Hanouka, Pourim, dix jours. */
    @Test
    fun `les situations nommees existent dans la periode simulee`() {
        fun a(cle: String, israel: Boolean = false) = jours.count { cle in jour(it, israel).conditions }
        listOf(C.ROCH_HODECH, C.MOTSAE_CHABBAT, C.MOTSAE_CHABBAT_YT, C.CHABBAT, C.CHABBAT_ROCH_HODECH, C.YOM_TOV, C.YOM_TOV_CHABBAT,
            C.PESSAH, C.SOUKKOT, C.CHAVOUOT, C.ROCH_HACHANA, C.KIPPOUR, C.CHEMINI_ATSERET, C.HANOUKA, C.POURIM, C.JEUNE, C.TICHA_BEAV,
            C.ASSERET_YEMEI_TECHOUVA, C.OMER, C.EMBOLISMIQUE, C.BASCULE_PLUIE)
            .forEach { assertTrue(it, a(it) > 0) }
        // Roch 'Hodech de deux jours, et Hanouka qui le traverse (Tévèt).
        assertTrue(jours.any { C.ROCH_HODECH in CalendrierJuif.jour(it, false).conditions && C.HANOUKA in CalendrierJuif.jour(it, false).conditions })
        assertEquals("quinze années complètes", true, jours.size > 5_500)
    }

    /**
     * Les quatorze sortes d'années (קביעות) et leurs cas rares (12/11) : présents dans la période, et
     * le calendrier les traite comme le siddour l'attend.
     */
    @Test
    fun `les quatorze sortes d'annees et leurs cas rares`() {
        val sortes = annees.map { a -> rochHachana(a).dayOfWeek to java.time.temporal.ChronoUnit.DAYS.between(rochHachana(a), rochHachana(a + 1)) }
        assertEquals("$sortes", 14, sortes.toSet().size)
        fun heb(d: LocalDate) = com.kosherjava.zmanim.hebrewcalendar.JewishCalendar(d)
        fun c(d: LocalDate, israel: Boolean = false, muree: Boolean = false) = jour(d, israel, muree).conditions

        val samedi = java.time.DayOfWeek.SATURDAY

        // Pourim triple : le 15 Adar un Chabbat. À Jérusalem, Al hanissim ce Chabbat-là, pas le vendredi
        // (Choul'han Aroukh 688:6) ; ailleurs, Pourim le vendredi 14.
        val triples = jours.filter { it.dayOfWeek == samedi && heb(it).jewishDayOfMonth == 15 && heb(it).jewishMonth == (if (heb(it).isJewishLeapYear) JewishDate.ADAR_II else JewishDate.ADAR) }
        assertTrue("Pourim triple", triples.size >= 2)
        triples.forEach { d ->
            assertTrue("$d Jérusalem", C.AL_HANISSIM in c(d, true, true) && C.POURIM in c(d, true, true))
            assertTrue("${d.minusDays(1)} Jérusalem", C.AL_HANISSIM !in c(d.minusDays(1), true, true))
            assertTrue("${d.minusDays(1)} ailleurs", C.AL_HANISSIM in c(d.minusDays(1), true) && C.AL_HANISSIM in c(d.minusDays(1), false))
            assertTrue("${d.minusDays(1)} pas de Ta'hanoun", C.TAHANOUN_CHAHARIT !in c(d.minusDays(1), true, true))
            // Le dimanche 16, jour du festin à Jérusalem : ni Ta'hanoun ni למנצח ; ailleurs, un jour ordinaire.
            val festin = d.plusDays(1)
            listOf(C.TAHANOUN_CHAHARIT, C.TAHANOUN_MINHA, C.LAMNATSEAH).forEach { k ->
                assertTrue("$festin Jérusalem $k", k !in c(festin, true, true))
                assertTrue("$festin ailleurs $k", k in c(festin, true) && k in c(festin, false))
            }
            // Ailleurs en Israël, l'Ashkenaz suit le Halikhot Chlomo (sans Ta'hanoun, למנצח gardé) ; Edot et
            // Sfard, le Yalkut Yosef ; en diaspora, Ta'hanoun partout.
            val israel = c(festin, true)
            assertTrue("$festin", C.POURIM_TRIPLE_HORS_JERUSALEM in israel && C.POURIM_TRIPLE_HORS_JERUSALEM !in c(festin, false) &&
                C.POURIM_TRIPLE_HORS_JERUSALEM !in c(festin, true, true))
            val ashkenaz = SiddurJour.conditionsPour("ashkenaz", true, israel)
            assertTrue("$festin Ashkenaz", C.TAHANOUN_CHAHARIT !in ashkenaz && C.TAHANOUN_MINHA !in ashkenaz && C.LAMNATSEAH in ashkenaz)
            listOf("edot", "sefard").forEach { assertTrue("$festin $it", C.TAHANOUN_CHAHARIT in SiddurJour.conditionsPour(it, true, israel)) }
            assertTrue("$festin Ashkenaz diaspora", C.TAHANOUN_CHAHARIT in SiddurJour.conditionsPour("ashkenaz", false, c(festin, false)))
        }

        // 9 Av un Chabbat : le jeûne passe au dimanche, « נחם » et le reste avec lui.
        val reportes = jours.filter { it.dayOfWeek == samedi && heb(it).jewishMonth == JewishDate.AV && heb(it).jewishDayOfMonth == 9 }
        assertTrue("9 Av reporté", reportes.size >= 3)
        reportes.forEach { d ->
            assertTrue("$d", C.TICHA_BEAV !in c(d) && C.JEUNE !in c(d))
            assertTrue("${d.plusDays(1)}", C.TICHA_BEAV in c(d.plusDays(1)) && C.MOTSAE_CHABBAT_YT in c(d.plusDays(1)) && C.TICHA_BEAV_KIPPOUR in c(d.plusDays(1)))
        }

        // La veille de Pessa'h un Chabbat (5781, 5785).
        assertTrue(jours.any { it.dayOfWeek == samedi && heb(it).jewishMonth == JewishDate.NISSAN && heb(it).jewishDayOfMonth == 14 })

        // Kislev de 29 jours : Roch 'Hodech Tévèt d'un seul jour, au milieu de 'Hanouka ; Al hanissim et יעלה ויבא.
        val unJour = jours.filter { C.HANOUKA in c(it) && C.ROCH_HODECH in c(it) && C.ROCH_HODECH !in c(it.minusDays(1)) && C.ROCH_HODECH !in c(it.plusDays(1)) }
        assertTrue("Roch 'Hodech Tévèt d'un jour", unJour.isNotEmpty())
        unJour.forEach { assertTrue("$it", C.AL_HANISSIM in c(it) && C.YAALE_VEYAVO in c(it) && C.HALLEL_COMPLET in c(it)) }

        // Le 10 Tévèt un vendredi : jeûne quand même ; Avinou malkénou à Cha'harit, pas à Min'ha (12/11).
        val tevet = jours.filter { it.dayOfWeek == java.time.DayOfWeek.FRIDAY && C.TSOM_GUEDALIA_TEVET in c(it) && C.JEUNE in c(it) }
        assertTrue(tevet.size >= 3)
        tevet.forEach {
            val pour = SiddurJour.conditionsPour("ashkenaz", false, c(it))
            assertTrue("$it", C.AVINOU_MALKENOU in pour && C.AVINOU_MALKENOU_MINHA !in pour)
        }

        // Pourim Katan (14 et 15 Adar I) : pas de Ta'hanoun, mais ni Pourim ni Al hanissim.
        val katan = jours.filter { heb(it).isJewishLeapYear && heb(it).jewishMonth == JewishDate.ADAR && heb(it).jewishDayOfMonth in 14..15 }
        assertTrue(katan.size >= 8)
        katan.forEach { assertTrue("$it", C.TAHANOUN_CHAHARIT !in c(it) && C.POURIM !in c(it) && C.AL_HANISSIM !in c(it)) }

        // Roch Hachana un Chabbat, Kippour un Chabbat.
        assertTrue(jours.any { C.ROCH_HACHANA_CHABBAT in c(it) })
        assertTrue(jours.any { it.dayOfWeek == samedi && C.KIPPOUR in c(it) })
    }
}
