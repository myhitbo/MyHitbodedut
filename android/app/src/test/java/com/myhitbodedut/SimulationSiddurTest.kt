package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * La lecture du siddour simulée chaque jour de deux années hébraïques (demande du 12/11) :
 * 5786, ordinaire, et 5787, embolismique, de la veille de Roch Hachana à Souccot suivant ;
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
    private val jours = generateSequence(LocalDate.parse("2025-09-20")) { it.plusDays(1) }
        .takeWhile { !it.isAfter(LocalDate.parse("2027-10-05")) }.toList()

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
        Regle(AMIDOT + "birkat_hamazon", "בימי מרדכי ואסתר בשושן", { C.POURIM in it && C.AL_HANISSIM in it }),
        Regle(AMIDOT + "moussaf_rosh_hodech", "ועל כלם", TOUJOURS),
        Regle(AMIDOT + "moussaf_rosh_hodech", "הטוב שמך ולך נאה להודות", TOUJOURS),
        Regle(AMIDOT, "המלך הקדוש", si(C.ASSERET_YEMEI_TECHOUVA)),
        Regle(AMIDOT + "moussaf_rosh_hodech", "משיב הרוח ומוריד הגשם", si(C.MACHIV_HAROUAH)),
        Regle(AMIDOT + "moussaf_rosh_hodech", "מוריד הטל", si(C.MORID_HATAL)),
        Regle(AMIDOT, "טל ומטר", si(C.TAL_OUMATAR)),
        Regle(AMIDOT, "ברכנו יהוה אלהינו בכל", si(C.BERAKHA)),
        Regle(setOf("arvit"), "אתה חוננתנו", si(C.MOTSAE_CHABBAT_YT)),
        Regle(setOf("minha"), "נחם יהוה אלהינו", si(C.TICHA_BEAV)),
        Regle(setOf("chaharit"), "ויאמר דוד אל גד", si(C.TAHANOUN_CHAHARIT)),
        // Le retour du Sefer Torah, les seuls jours de lecture (12/11 : Edot et Sfard l'affichaient tous les jours).
        Regle(setOf("chaharit"), "ובנחה יאמר שובה יהוה", si(C.KRIAT_HATORAH)),
        // 12/11 : « שעשה לי כל צרכי » (Edot) pas le 9 Av ni à Kippour ; la fin du Kaddich après le Hallel pas à 'Hanouka.
        Regle(setOf("birkot_hachahar"), "שעשה לי כל צרכי", { C.TICHA_BEAV_KIPPOUR !in it }, setOf(Nusah.EDOT)),
        Regle(setOf("hallel"), "תתקבל", { C.HANOUKA !in it }),
        Regle(setOf("minha"), "ויאמר דוד אל גד", si(C.TAHANOUN_MINHA)),
        // Méèn chaloch.
        Regle(setOf("meen_chaloch"), "ורצה והחליצנו", si(C.CHABBAT)),
        Regle(setOf("meen_chaloch"), "ביום הזכרון הזה", si(C.ROCH_HACHANA)),
    )

    @Test
    fun `chaque jour, chaque passage du moment se lit le jour dit et rien ne se perd`() {
        val ecarts = sortedMapOf<String, MutableList<LocalDate>>()
        var verifications = 0
        val textes = setOf("chaharit", "minha", "arvit", "birkat_hamazon", "meen_chaloch", "moussaf_rosh_hodech", "hallel", "birkot_hachahar")
        // Les consignes d'oubli (12/11) : toujours repliées, jamais en clair.
        val oubli = Regex("^\\(?(טעה|שכח|אם שכח|אם טעה|ואם טעה|אם לא אמר|ואם לא אמר)(?=\\s|:|$)|^בכל השנה אם אמר המלך המשפט")
        for (lieu in lieux) for (date in jours) {
            val jour = CalendrierJuif.jour(date, lieu.israel, lieu.muree)
            for (n in Nusah.entries) {
                if (lieu.sud && n != Nusah.EDOT) continue
                val c = SiddurJour.conditionsPour(n.cle, lieu.israel, jour.conditions, sud = lieu.sud)
                for (id in textes) {
                    val texte = siddurs.getValue(n).texte(id) ?: continue
                    val ann = annotations.getValue(n)[id].orEmpty()
                    val lignes = SiddurJour.lignes(texte, ann, jour.conditions, nusah = n.cle, enIsrael = lieu.israel, sud = lieu.sud)
                    // Rien n'est retiré : tous les replis ouverts, chaque bloc revient, une fois.
                    val cles = lignes.filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }.toSet()
                    val tout = SiddurJour.lignes(texte, ann, jour.conditions, cles, n.cle, lieu.israel, sud = lieu.sud)
                    val vus = tout.filterIsInstance<SiddurJour.Ligne.Bloc>().map { it.bloc }
                    if (vus.size != texte.sections.sumOf { it.blocs.size } ||
                        texte.sections.any { s -> s.blocs.any { b -> vus.none { it === b } } }) {
                        ecarts.getOrPut("${n.cle} $id ${lieu.nom} : un bloc manque, replis ouverts") { mutableListOf() } += date
                    }
                    if (lignes.any { it is SiddurJour.Ligne.Bloc && it.bloc.consigne && oubli.containsMatchIn(SiddurJour.empreinte(it.bloc.texte)) }) {
                        ecarts.getOrPut("${n.cle} $id ${lieu.nom} : consigne d'oubli en clair") { mutableListOf() } += date
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
                            ecarts.getOrPut("${n.cle} $id ${lieu.nom} « ${r.phrase} » ${if (attendu) "replié le jour dit" else "en clair hors du jour"}") { mutableListOf() } += date
                        }
                    }
                }
            }
        }
        val rapport = ecarts.entries.joinToString("\n") { (k, v) -> "$k : ${v.size} jour(s), dont ${v.take(4).joinToString()}" }
        assertTrue("Écarts :\n$rapport", ecarts.isEmpty())
        assertTrue("la simulation a tourné ($verifications)", verifications > 100_000)
    }

    /** « מגדול » à la fin du Birkat (12/11) : les jours de Moussaf en Edot, Chabbat et Yom tov en Ashkenaz et en Sfard ; une fois. */
    @Test
    fun `migdol les jours dits, une seule fois`() {
        val jours = mapOf(Nusah.EDOT to setOf(C.CHABBAT, C.ROCH_HODECH, C.MOED, C.YOM_TOV), Nusah.ASHKENAZ to setOf(C.CHABBAT, C.YOM_TOV), Nusah.SEFARD to setOf(C.CHABBAT, C.YOM_TOV))
        for ((n, cles) in jours) for (date in this.jours) for (israel in listOf(false, true)) {
            val c = CalendrierJuif.jour(date, israel).conditions
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
            val jour = CalendrierJuif.jour(date, lieu.israel, lieu.muree)
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
        fun a(cle: String, israel: Boolean = false) = jours.count { cle in CalendrierJuif.jour(it, israel).conditions }
        listOf(C.ROCH_HODECH, C.MOTSAE_CHABBAT, C.MOTSAE_CHABBAT_YT, C.CHABBAT, C.CHABBAT_ROCH_HODECH, C.YOM_TOV, C.YOM_TOV_CHABBAT,
            C.PESSAH, C.SOUKKOT, C.CHAVOUOT, C.ROCH_HACHANA, C.KIPPOUR, C.CHEMINI_ATSERET, C.HANOUKA, C.POURIM, C.JEUNE, C.TICHA_BEAV,
            C.ASSERET_YEMEI_TECHOUVA, C.OMER, C.EMBOLISMIQUE, C.BASCULE_PLUIE)
            .forEach { assertTrue(it, a(it) > 0) }
        // Roch 'Hodech de deux jours, et Hanouka qui le traverse (Tévèt).
        assertTrue(jours.any { C.ROCH_HODECH in CalendrierJuif.jour(it, false).conditions && C.HANOUKA in CalendrierJuif.jour(it, false).conditions })
        assertEquals("deux années complètes", true, jours.size > 700)
    }
}
