package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate
import java.time.LocalTime

/**
 * Audit halakhique du 16/11, « Birkat haMazon et bénédictions » (AUDIT_HALAKHOT_2026-11-16.md) :
 * la Havdala du 9 Av et des sorties de fête, les formules d'oubli, les retouches du texte
 * (tools/siddur_audit_berakhot.py) et les notes de l'application (tools/siddur_annotations.py, NOTES).
 */
class BerakhotAuditTest {

    private val json = File("src/main/res/raw/siddur_annotations.json").readText()
    private val siddurs = Nusah.entries.associateWith { DataFiles.siddur(it) }
    private val annotations = Nusah.entries.associateWith { SiddurJour.parse(json, it.cle) }
    private val C = CalendrierJuif.C

    private fun plat(t: String) = t.replace(Regex("<[^>]+>"), "").replace(Regex("[\\u0591-\\u05C7\\s״׳\"'()]"), "")
    private fun c(date: String, israel: Boolean = false) = CalendrierJuif.jour(LocalDate.parse(date), israel).conditions
    private fun lignes(n: Nusah, id: String, conditions: Set<String>, ouverts: Set<String> = emptySet()) =
        SiddurJour.lignes(siddurs.getValue(n).texte(id)!!, annotations.getValue(n)[id].orEmpty(), conditions, ouverts, nusah = n.cle)
    private fun clair(l: List<SiddurJour.Ligne>, phrase: String) =
        l.any { it is SiddurJour.Ligne.Bloc && it.style != SiddurJour.Style.HORS && !it.bloc.consigne && plat(it.bloc.texte).contains(plat(phrase)) }
    private fun notes(l: List<SiddurJour.Ligne>) = l.filterIsInstance<SiddurJour.Ligne.Seul>().filter { it.note }.map { it.texte }
    private fun blocs(n: Nusah, id: String) = siddurs.getValue(n).texte(id)!!.sections.flatMap { it.blocs }

    /** Le samedi soir du 9 Av (2025-08-02, jeûne repoussé) : la flamme seule, sans coupe ni bessamim. */
    @Test
    fun `havdala - samedi soir du 9 Av, la flamme seule`() {
        val jour = CalendrierJuif.jourDeLaPriere("havdala", LocalDate.parse("2025-08-02"), LocalTime.of(21, 30), apresSortie = true)
        val conditions = CalendrierJuif.jour(jour, false).conditions
        assertTrue(C.TICHA_BEAV in conditions && C.MOTSAE_CHABBAT in conditions)
        for (n in Nusah.entries) {
            val l = lignes(n, "havdala", conditions)
            assertTrue(n.cle, clair(l, "בורא מאורי האש"))
            listOf("בורא פרי הגפן", "בשמים", "המבדיל בין קדש לחול").forEach { assertFalse("${n.cle} $it", clair(l, it)) }
            assertTrue(n.cle, notes(l).any { "בורא מאורי האש״ בלבד" in it })
        }
    }

    /** Le dimanche soir, sortie du jeûne (Havdala du lundi 2025-08-04) : la coupe, sans flamme ni bessamim. */
    @Test
    fun `havdala - sortie du 9 Av un dimanche, la coupe seule`() {
        val conditions = c("2025-08-04")
        assertTrue(C.LENDEMAIN_TICHA_BEAV_DIMANCHE in conditions)
        assertFalse(C.LENDEMAIN_TICHA_BEAV_DIMANCHE in c("2026-07-24")) // 9 Av un jeudi : sortie un jeudi soir
        for (n in Nusah.entries) {
            val l = lignes(n, "havdala", conditions)
            assertTrue(n.cle, clair(l, "המבדיל בין קדש לחול") && clair(l, "בורא פרי הגפן"))
            assertFalse(n.cle, clair(l, "בורא מאורי האש") || clair(l, "בשמים"))
            assertTrue(n.cle, notes(l).any { "על הכוס בלבד" in it })
        }
    }

    /** Un motsaé Chabbat ordinaire : tout en clair, sans étiquette ; une sortie de Yom tov en semaine : ni flamme ni bessamim. */
    @Test
    fun `havdala - motsae chabbat ordinaire et sortie de Yom tov`() {
        for (n in Nusah.entries) {
            val l = lignes(n, "havdala", c("2026-11-15"))
            listOf("בורא פרי הגפן", "בשמים", "בורא מאורי האש", "המבדיל בין קדש לחול").forEach { assertTrue("${n.cle} $it", clair(l, it)) }
            assertTrue(n.cle, l.none { it is SiddurJour.Ligne.Etiquette })
            assertTrue(n.cle, l.none { it is SiddurJour.Ligne.Replie && it.libelle.startsWith("ajout_havdala") })
            // Sans lieu, le samedi même : la Havdala reste entière.
            listOf("בשמים", "בורא מאורי האש").forEach { assertTrue("${n.cle} samedi $it", clair(lignes(n, "havdala", c("2026-11-14")), it)) }
            // Le lendemain du 8ᵉ jour de Pessa'h (jeudi 2026-04-09 en diaspora) : la coupe seule.
            val yt = lignes(n, "havdala", c("2026-04-10"))
            assertTrue(n.cle, clair(yt, "המבדיל בין קדש לחול"))
            assertFalse(n.cle, clair(yt, "בשמים") || clair(yt, "בורא מאורי האש"))
            // Au sortir de Kippour : la flamme, et la note sur les bessamim.
            val kippour = lignes(n, "havdala", c("2026-09-22"))
            assertTrue(n.cle, clair(kippour, "בורא מאורי האש"))
            assertTrue(n.cle, notes(kippour).any { "במוצאי יום הכפורים" in it })
        }
    }

    /** Edot : יעלה ויבוא de Kippour pour qui mange (Kitsour Yalkut Yosef 618:12), et seulement ce jour-là. */
    @Test
    fun `birkat edot - yaale veyavo de kippour`() {
        assertTrue(clair(lignes(Nusah.EDOT, "birkat_hamazon", c("2026-09-21")), "ביום סליחת העון הזה"))
        assertFalse(clair(lignes(Nusah.EDOT, "birkat_hamazon", c("2026-10-12")), "ביום סליחת העון הזה"))
    }

    /** Les formules d'oubli : Roch 'Hodech sans חתימה (Sfard), Roch haChana avec (Ashkenaz), 'Hol hamoed (les deux). */
    @Test
    fun `birkat - formules d oubli`() {
        val sfard = blocs(Nusah.SEFARD, "birkat_hamazon").map { plat(it.texte) }
        val rc = sfard[sfard.lastIndexOf(plat("בראש חודש:")) + 1]
        assertTrue(rc, rc.endsWith(plat("לעמו ישראל לזכרון:")))
        val ash = blocs(Nusah.ASHKENAZ, "birkat_hamazon").map { plat(it.texte) }
        assertTrue(ash.any { it.contains(plat("אשר נתן ימים טובים לעמו ישראל את יום הזכרון הזה: ברוך אתה יהוה מקדש ישראל ויום הזכרון")) })
        listOf(sfard, ash).forEach { b ->
            val k = b.indexOfFirst { it.contains(plat("אשר נתן מועדים לעמו ישראל לששון ולשמחה")) }
            assertTrue(k > b.indexOf(plat("דיני שכחה:")))
            assertFalse(b[k].contains(plat("ברוך אתה יהוה מקדש")))
        }
        // Ces formules restent sous « En cas d'oubli ».
        for (n in Nusah.entries) {
            val l = lignes(n, "birkat_hamazon", c("2026-04-05"))
            assertFalse(n.cle, clair(l, "אשר נתן מועדים לעמו ישראל"))
            assertFalse(n.cle, l.any { it is SiddurJour.Ligne.Bloc && plat(it.bloc.texte).startsWith(plat("הערה:")) })
        }
    }

    /** Edot : la fin d'על הנסים de Pourim au pluriel (Kitsour Yalkut Yosef 695:7), dans le Birkat. */
    @Test
    fun `birkat edot - nissim veniflaot`() {
        val b = blocs(Nusah.EDOT, "birkat_hamazon").filter { !it.consigne }.map { plat(it.texte) }
        assertTrue(b.none { it.contains(plat("נס ופלא")) })
        assertEquals(3, b.count { it.contains(plat("ועשית עמהם נסים ונפלאות ונודה")) }) // 'Hanouka, Pourim, le הרחמן du Pourim triple
    }

    /**
     * Edot : la fin d'על הנסים de Pourim au pluriel aussi dans l'Amida de Cha'harit, Min'ha et Arvit,
     * comme dans le Birkat (Kitsour Yalkut Yosef 695:7 ; tools/siddur_audit_berakhot.py, amida).
     */
    @Test
    fun `amida edot - nissim veniflaot`() {
        listOf("chaharit", "minha", "arvit").forEach { id ->
            val b = blocs(Nusah.EDOT, id).filter { !it.consigne }.map { plat(it.texte) }
            assertTrue(id, b.none { it.contains(plat("נס ופלא")) })
            assertEquals(id, 1, b.count { it.contains(plat("בימי מרדכי")) && it.contains(plat("ועשית עמהם נסים ונפלאות ונודה")) })
        }
    }

    /** Ashkenaz : Na'hem pour qui mange le 9 Av (Rema 557:1), replié les autres jours. */
    @Test
    fun `birkat ashkenaz - nahem le 9 Av`() {
        val av = lignes(Nusah.ASHKENAZ, "birkat_hamazon", c("2026-07-23"))
        assertTrue(av.any { it is SiddurJour.Ligne.Etiquette && it.condition == C.TICHA_BEAV })
        assertTrue(av.any { it is SiddurJour.Ligne.Bloc && plat(it.bloc.texte).startsWith(plat("מי שאוכל בתשעה באב")) })
        assertFalse(lignes(Nusah.ASHKENAZ, "birkat_hamazon", c("2026-11-16")).any {
            it is SiddurJour.Ligne.Bloc && plat(it.bloc.texte).startsWith(plat("מי שאוכל בתשעה באב"))
        })
    }

    /** Ashkenaz : le psaume d'avant le Birkat suit Ta'hanoun (Michna Beroura 1:11) ; Yom tov, שיר המעלות. */
    @Test
    fun `birkat ashkenaz - le psaume du jour`() {
        val pessah = c("2026-04-02")
        val replis = lignes(Nusah.ASHKENAZ, "birkat_hamazon", pessah).filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }.toSet()
        val ouvert = lignes(Nusah.ASHKENAZ, "birkat_hamazon", pessah, replis)
        fun style(p: String) = ouvert.filterIsInstance<SiddurJour.Ligne.Bloc>().firstOrNull { plat(it.bloc.texte).contains(plat(p)) }?.style
        assertEquals(SiddurJour.Style.NORMAL, style("שיר המעלות בשוב"))
        // 26/11, Q11 : dans le repli déplié, le seul psaume du jour ; celui des jours de Ta'hanoun n'y est pas.
        assertEquals(null, style("על נהרות בבל"))
        assertTrue(notes(ouvert).any { "״שיר המעלות בשוב״" in it })
        assertTrue(notes(lignes(Nusah.ASHKENAZ, "birkat_hamazon", c("2026-11-16"))).any { "״על נהרות בבל״" in it })
    }

    /**
     * « מגדול » à Roch 'Hodech en Ashkenaz et en Sfard (Michna Beroura 189:5 ; Choul'han Aroukh haRav 189:7) : depuis
     * le 26/11 (Q8), dans le texte même, à la place de « מגדיל » ; un jour ordinaire, « מגדיל » seul.
     */
    @Test
    fun `birkat - migdol a roch hodech`() {
        for (n in listOf(Nusah.ASHKENAZ, Nusah.SEFARD)) {
            val l = lignes(n, "birkat_hamazon", c("2026-12-10"))
            val blocs = l.filterIsInstance<SiddurJour.Ligne.Bloc>().map { plat(it.bloc.texte) }
            assertTrue(n.cle, blocs.any { "מגדולישועות" in it } && blocs.none { "מגדילישועות" in it })
            assertTrue(n.cle, notes(l).any { "מגדול" in it })
            val ordinaire = lignes(n, "birkat_hamazon", c("2026-11-17")).filterIsInstance<SiddurJour.Ligne.Bloc>().map { plat(it.bloc.texte) }
            assertTrue(n.cle, ordinaire.any { "מגדילישועות" in it } && ordinaire.none { "מגדולישועות" in it })
        }
    }

    /** Le soir qui suit un jour d'ajouts : une note sous les consignes d'oubli ; pas un mardi ordinaire, ni le Chabbat. */
    @Test
    fun `birkat - repas commence la veille`() {
        assertTrue(C.LENDEMAIN_AJOUTS in c("2026-11-15"))
        assertFalse(C.LENDEMAIN_AJOUTS in c("2026-11-14") || C.LENDEMAIN_AJOUTS in c("2026-11-17"))
        assertTrue(C.LENDEMAIN_AJOUTS in c("2026-12-11")) // vendredi, lendemain de Roch 'Hodech Tévèt et de 'Hanouka
        for (n in Nusah.entries) {
            assertTrue(n.cle, notes(lignes(n, "birkat_hamazon", c("2026-11-15"))).any { "ונמשכה אחר צאת הכוכבים" in it })
            assertTrue(n.cle, notes(lignes(n, "birkat_hamazon", c("2026-11-17"))).none { "ונמשכה אחר צאת הכוכבים" in it })
        }
    }

    /** Bein hamétsarim, du 17 Tamouz au 10 Av : une note près de שהחיינו. */
    @Test
    fun `nehenin - shehehiyanou bein hametsarim`() {
        assertTrue(C.BEIN_HAMETSARIM in c("2026-07-02") && C.BEIN_HAMETSARIM in c("2026-07-24"))
        assertFalse(C.BEIN_HAMETSARIM in c("2026-07-01") || C.BEIN_HAMETSARIM in c("2026-07-25"))
        for (n in Nusah.entries) {
            assertTrue(n.cle, notes(lignes(n, "nehenin", c("2026-07-10"))).any { "שהחיינו" in it })
            assertTrue(n.cle, notes(lignes(n, "nehenin", c("2026-11-16"))).none { "שהחיינו" in it })
        }
    }

    /** Les bénédictions des occasions : texte retouché (Edot) et notes de l'application. */
    @Test
    fun `occasions - textes et notes`() {
        val toujours = c("2026-11-16")
        // Edot : bénir avant d'allumer selon le Yalkut Yosef ; les bougies de Kippour.
        assertTrue(notes(lignes(Nusah.EDOT, "nerot_chabbat", toujours)).any { "רסג" in it && "קודם ההדלקה" in it })
        assertTrue(blocs(Nusah.EDOT, "nerot_chabbat").any { plat(it.texte).contains(plat("להדליק נר של אם חל בשבת תוסיף: שבת ויום הכפרים")) })
        // Edot : la mer sans Chem ni Malkhout, les éclairs avec.
        val yam = blocs(Nusah.EDOT, "yam")
        assertTrue(plat(yam[0].texte).contains(plat("בלי שם ומלכות")))
        assertTrue(yam[1].texte.contains("(אַתָּה יְהֹוָה אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם)"))
        assertTrue(blocs(Nusah.EDOT, "barakim").none { !it.consigne && it.texte.contains("(") })
        assertTrue(plat(blocs(Nusah.EDOT, "barakim")[0].texte).startsWith(plat("מברכים בשם ומלכות")))
        // Edot : Acher yatsar, 72 minutes, aux deux endroits.
        listOf("acher_yatsar", "birkot_hachahar").forEach { id -> assertTrue(id, blocs(Nusah.EDOT, id).any { it.consigne && "72 דקות" in it.texte }) }
        // Ashkenaz : la 'hala sans le Rav Ovadia.
        assertTrue(blocs(Nusah.ASHKENAZ, "hala").none { "חזו״ע" in it.texte } && blocs(Nusah.ASHKENAZ, "hala").any { "1.666" in it.texte })
        // המוציא partout ; מזונות et הגפן en Sfard et en Ashkenaz.
        for (n in Nusah.entries) {
            val b = blocs(n, "nehenin").map { plat(it.texte) }
            listOf("המוציא לחם מן הארץ", "בורא מיני מזונות", "בורא פרי הגפן", "על נטילת ידים").forEach { assertTrue("${n.cle} $it", b.any { x -> x.contains(plat(it)) }) }
        }
        // Edot : 7 minutes et demie (Kitsour Yalkut Yosef 207).
        listOf("nehenin", "bore_nefachot").forEach { assertTrue(it, notes(lignes(Nusah.EDOT, it, toujours)).any { n -> "7.5" in n }) }
        // Les notes n'ont pas de date : chaque texte annoté les montre.
        for ((n, id) in listOf(Nusah.EDOT to "chema_coucher", Nusah.EDOT to "loulav", Nusah.EDOT to "soukka", Nusah.EDOT to "hagomel",
            Nusah.ASHKENAZ to "hagomel", Nusah.ASHKENAZ to "keshet", Nusah.SEFARD to "yam", Nusah.ASHKENAZ to "nerot_chabbat",
            Nusah.EDOT to "birkat_hailanot", Nusah.ASHKENAZ to "nerot_hanouka")) {
            assertTrue("${n.cle} $id", notes(lignes(n, id, toujours)).isNotEmpty())
        }
        // Birkat haIlanot le Chabbat (Edot) : une note de plus.
        assertTrue(notes(lignes(Nusah.EDOT, "birkat_hailanot", c("2027-04-10"))).any { "בשבת" in it })
    }

    /** Birkat haIlanot en Iyar : Edot et Ashkenaz, pas le Sfard ; Nissan inchangé. */
    @Test
    fun `ilanot - Iyar en Edot et en Ashkenaz`() {
        val iyar = LocalDate.parse("2026-04-25")
        assertTrue(SiddurMoment.ilanot(iyar, 31.78, "edot") && SiddurMoment.ilanot(iyar, 48.85, "ashkenaz"))
        assertFalse(SiddurMoment.ilanot(iyar, 31.78, "sefard") || SiddurMoment.ilanot(iyar, 31.78))
        assertTrue(SiddurMoment.ilanot(LocalDate.parse("2026-04-01"), 31.78, "sefard"))
        assertFalse(SiddurMoment.ilanot(LocalDate.parse("2026-05-20"), 31.78, "edot")) // Sivan
    }
}
