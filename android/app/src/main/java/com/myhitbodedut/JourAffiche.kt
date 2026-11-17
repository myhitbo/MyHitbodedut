package com.myhitbodedut

import com.myhitbodedut.CalendrierJuif.C
import java.time.LocalDate
import java.time.YearMonth

/**
 * Ce que l'onglet Zmanim et le calendrier montrent d'un jour (10/10) : les
 * ajouts à nommer, les horaires avec l'entrée et la sortie de Chabbat ou de
 * fête, et la grille d'un mois. Pas d'Android ici : testable sur la machine
 * virtuelle seule. Le même code existe côté web (web/src/js/jour-affiche.js).
 */
object JourAffiche {

    /**
     * L'illustration d'un jour de fête ou de Chabbat (11/10), par son nom de
     * ressource ; null un jour ordinaire. La fête passe avant Chabbat.
     */
    fun illustration(fetes: List<String>, date: LocalDate): String? = when {
        fetes.any { it in setOf("erev_soukkot", "soukkot", "hol_hamoed_soukkot", "hochaana_rabba") } -> "scene_sukkot"
        fetes.any { it in setOf("erev_pessah", "pessah", "hol_hamoed_pessah") } -> "char_matsa"
        "hanouka" in fetes -> "scene_hanukkah"
        fetes.any { it in setOf("pourim", "chouchan_pourim", "pourim_ailleurs", "pourim_jerusalem") } -> "char_purim"
        date.dayOfWeek == java.time.DayOfWeek.SATURDAY -> "char_shabbat"
        else -> null
    }


    /**
     * Les ajouts du jour, dans l'ordre de l'Amida : des clés de libellé
     * (Libelles). Le nusah change trois choses (ZMANIM.md, « Différences de
     * nusah ») : Morid hatal hors d'Israël chez beaucoup d'Ashkénazes, la
     * bénédiction du Hallel partiel, et l'Anénou du particulier (Ashkenaz et
     * Sfard : à Min'ha seulement, Rema OC 565:3 ; Edot : à Cha'harit et à Min'ha,
     * et à Arvit le soir de Tich'a bèAv).
     */
    fun ajouts(
        c0: Set<String>,
        nusah: String = "edot",
        enIsrael: Boolean = false,
        sansTahanounFinTichri: Boolean = nusah == "edot",
        sud: Boolean = false,
    ): List<String> = buildList {
        val c = SiddurJour.conditionsPour(nusah, enIsrael, c0, sansTahanounFinTichri, sud)
        if (C.ASSERET_YEMEI_TECHOUVA in c) add("ajout_asseret_yemei_techouva")
        // Les jours de bascule, les deux formules (CalendrierJuif.C.BASCULE_PLUIE) ; sinon l'une ou l'autre.
        if (C.MACHIV_HAROUAH in c) add("ajout_machiv_harouah")
        if (C.MORID_HATAL in c && (C.MACHIV_HAROUAH !in c || C.BASCULE_PLUIE in c)) add("ajout_morid_hatal")
        // La 9ᵉ bénédiction (audit du 16/10) : les Edot changent de texte (ברך עלינו / ברכנו) ;
        // rien le Chabbat ni un Yom Tov, Kippour compris, où l'Amida n'a pas de bénédiction de semaine.
        if (C.CHABBAT !in c && C.YOM_TOV !in c) add(
            if (nusah == "edot") (if (C.TAL_OUMATAR in c) "ajout_barekh_alenou" else "ajout_barkhenou")
            else if (C.TAL_OUMATAR in c) "ajout_tal_oumatar" else "ajout_berakha"
        )
        if (C.JEUNE in c) {
            add("ajout_anenou_officiant")
            // Edot : à Tich'a bèAv, le jeûne commence la veille au soir, et
            // Arvit en est (Peninei Halakha, yeshiva.co/midrash/48403).
            add(when {
                nusah != "edot" -> "ajout_anenou_particulier_minha"
                C.TICHA_BEAV in c -> "ajout_anenou_particulier_trois"
                else -> "ajout_anenou_particulier_matin_minha"
            })
        }
        // Na'hem (audit du 16/11) : Edot à Arvit, Cha'harit et Min'ha (« וכן מנהג ירושלים לומר נחם בכל התפלות »,
        // Yalkut Yosef, Kitsour 557:1) ; Sfard et Ashkenaz à Min'ha seulement (Rema 557:1).
        if (C.TICHA_BEAV in c) add(if (nusah == "edot") "ajout_ticha_beav_trois" else "ajout_ticha_beav_minha")
        if (C.YAALE_VEYAVO in c) add("ajout_yaale_veyavo")
        if (C.AL_HANISSIM in c) add("ajout_al_hanissim")
        SiddurJour.libelleHallel(nusah, c)?.let { add(it) }
        // Le Chabbat et un Yom Tov (Kippour compris), il n'y a pas d'Amida de semaine où dire ou taire
        // Ta'hanoun (audit du 12/11, FCALENDRIER-12). Le dimanche d'un Pourim triple hors de Jérusalem,
        // l'Ashkenaz suit le Halikhot Chlomo contre le Michna Beroura (131:33) : le libellé le dit.
        if (C.CHABBAT !in c && C.YOM_TOV !in c) add(when {
            C.TAHANOUN_CHAHARIT in c -> "ajout_tahanoun"
            // Le réglage ponctuel (deuil, brit, 'hatan ; audit du 16/11) : on dit d'où vient l'absence.
            C.SANS_TAHANOUN_PONCTUEL in c -> "ajout_sans_tahanoun_ponctuel"
            nusah == "ashkenaz" && C.POURIM_TRIPLE_HORS_JERUSALEM in c -> "ajout_sans_tahanoun_halikhot_chlomo"
            // Pessa'h chéni : ni le Choul'han Aroukh ni le Michna Beroura n'en parlent ; l'ancien usage ashkénaze
            // disait Ta'hanoun (Chaarei Techouva 131:19 ; audit du 16/11).
            nusah == "ashkenaz" && C.JOUR_PESSAH_CHENI in c -> "ajout_sans_tahanoun_pessah_cheni"
            else -> "ajout_sans_tahanoun"
        })
        // La veille de Kippour : Vidouï et « על חטא » après l'Amida de Min'ha, que l'app n'a pas (ma'hzor) ;
        // Choul'han Aroukh O.H. 607:1 ; Kitsour Yalkout Yossef 607:1 (audit du 16/11).
        if (C.EREV_KIPPOUR in c) add("ajout_vidoui_erev_kippour")
    }

    /**
     * Les horaires du jour, avec ceux de Chabbat et des fêtes, qui suivent
     * isAssurBemelacha de KosherJava :
     *  - la veille d'un jour chômé : l'allumage, [minutes] avant la chki'a ;
     *  - un jour chômé suivi d'un autre (deuxième jour de fête, Chabbat puis
     *    fête) : l'allumage, pas avant la sortie du jour, à tsét 8,5° ;
     *  - sauf un vendredi de fête (audit du 12/11, FCALENDRIER-01) : les
     *    bougies de Chabbat s'allument avant la chki'a, d'une flamme
     *    existante, et jamais à tsét, qui est déjà Chabbat ;
     *  - le dernier jour chômé : la sortie, à tsét 8,5° (et Rabbénou Tam reste
     *    dans la liste).
     * Le profil et ses limites : ZMANIM.md.
     *
     * Le profil suit le [nusah] (audit du 16/11, Zmanim.PROFIL_EDOT). Pour les Edot, la sortie de
     * Chabbat ou de fête est Rabbénou Tam en 72 min zmaniyot, que le Yalkut Yosef recommande
     * (Kitsour YY 293:3 et 293:7) ; la ligne tsét (Gueonim, 13,5 min zmaniyot) reste affichée.
     * L'allumage d'un deuxième jour de fête suit le tsét du rite ; après Chabbat, la sortie.
     *
     * Ajouts de l'audit du 16/11, à titre d'information :
     *  - un jeûne public : « Début du jeûne » à l'aube du rite, « Fin du jeûne » à son tsét ; la
     *    veille du 9 Av (Chabbat compris), « Début du jeûne » à la chki'a (Kitsour YY 550:2) ;
     *  - la veille de Pessa'h : fin de la consommation et du bi'our du 'hamets (Zmanim.hamets) ;
     *    quand elle tombe un Chabbat, le vendredi, la fin de la 5e heure pour brûler (CA 444:2).
     */
    fun horaires(
        lieu: Zmanim.Lieu, date: LocalDate, enIsrael: Boolean, minutes: Int, nusah: String = Zmanim.NUSAH_COMMUN,
    ): List<Zmanim.Zman> {
        val jourJ = CalendrierJuif.jour(date, enIsrael)
        val jourDemain = CalendrierJuif.jour(date.plusDays(1), enIsrael)
        val aujourdhui = jourJ.chome
        val demain = jourDemain.chome
        val veilleDeChabbat = date.dayOfWeek == java.time.DayOfWeek.FRIDAY
        val samedi = date.dayOfWeek == java.time.DayOfWeek.SATURDAY
        val edot = nusah == "edot"
        val base = Zmanim.jour(lieu, date, nusah)
        val tset = base.first { it.cle == "tset" }
        val fin = if (edot) base.first { it.cle == "tset_rt" } else tset
        val jeune = C.JEUNE in jourJ.conditions
        val veilleAv = C.TICHA_BEAV in jourDemain.conditions
        val hamets = when {
            "erev_pessah" in jourJ.fetes -> Zmanim.hamets(lieu, date, nusah)
            veilleDeChabbat && "erev_pessah" in jourDemain.fetes -> Zmanim.hamets(lieu, date, nusah).filter { it.cle == "hamets_biour" }
            else -> emptyList()
        }
        val sortie = mutableListOf<Zmanim.Zman>()
        base.forEach { z ->
            if (z.cle == "chkia" && demain && (!aujourdhui || veilleDeChabbat)) sortie += Zmanim.allumage(lieu, date, minutes)
            if (z.cle == "chkia" && veilleAv) sortie += z.copy(cle = "debut_jeune")
            sortie += z
            if (z.cle == "alot" && jeune && C.TICHA_BEAV !in jourJ.conditions) sortie += z.copy(cle = "debut_jeune")
            if (z.cle == "szt_gra") sortie += hamets
            if (z.cle == "tset" && jeune) sortie += z.copy(cle = "fin_jeune")
            if (z.cle == fin.cle && aujourdhui && !demain) sortie += fin.copy(cle = "sortie")
            val apres = if (samedi) fin else tset
            if (z.cle == apres.cle && aujourdhui && demain && !veilleDeChabbat) {
                sortie += apres.copy(cle = "allumage", methode = Zmanim.Methode(if (edot) "apres_sortie" else "apres_tset", ""))
            }
        }
        return sortie
    }

    /**
     * La note du Yom tov chéni pour un voyageur (audit du 16/11) : une clé de chaîne, ou null.
     * Le calendrier suit le statut ([statutIsrael], la résidence) ; la note dit ce qui change
     * quand le lieu ([lieuEnIsrael]) est de l'autre région un jour qui n'est chômé qu'en diaspora :
     *  - résident d'Israël en diaspora : jour de semaine pour lui, sans mélakha en public, tefillin
     *    en privé (Choul'han Aroukh 496:3 ; Kitsour Yalkut Yosef 31:3, « ויניח תפילין בביתו בצינעא ») ;
     *  - résident de diaspora en Israël : jour de fête pour lui (Michna Beroura 496:13) ; en
     *    Ashkenaz, la note rappelle l'avis du 'Hakham Tsvi (un seul jour), que l'application ne suit pas.
     */
    fun noteYomTovCheni(date: LocalDate, statutIsrael: Boolean, lieuEnIsrael: Boolean, nusah: String): String? {
        if (statutIsrael == lieuEnIsrael) return null
        if (!CalendrierJuif.jour(date, false).chome || CalendrierJuif.jour(date, true).chome) return null
        return when {
            statutIsrael -> "note_ytc_ben_israel"
            nusah == "ashkenaz" -> "note_ytc_ben_houl_ashkenaz"
            else -> "note_ytc_ben_houl"
        }
    }

    /**
     * Un lieu où la ligne de date halakhique est discutée (audit du 16/11) : à l'est de 125,2° E
     * (90° de Jérusalem, la ligne du 'Hazon Ich) ou à l'ouest de 150° O (Hawaï, Samoa, Tonga).
     * L'application suit le jour civil (Rav Frank) ; l'écran le dit, sans trancher.
     */
    fun ligneDateDiscutee(longitude: Double): Boolean = longitude >= 125.2 || longitude <= -150.0

    /** Les minutes d'allumage d'usage à Jérusalem, hors Edot (calendrier de Rav Toukatchinsky). */
    const val ALLUMAGE_JERUSALEM = 40

    /** Les minutes d'allumage que le Yalkut Yosef donne aux Edot, à Jérusalem comme ailleurs. */
    const val ALLUMAGE_EDOT = 20

    /**
     * La proposition sous le réglage d'allumage, à Jérusalem seulement ([mukafChoma]) : une clé de
     * chaîne, ou null. Audit du 16/11 : les 40 min, « coutume de Jérusalem », pour Sfard et
     * Ashkenaz ; pour les Edot, environ 20 min, à Jérusalem aussi (Kitsour Yalkut Yosef 263:47 :
     * « להדליק את הנר ארבעים דקות קודם השקיעה. שאין לזה כל יסוד בהלכה »).
     */
    fun propositionAllumage(nusah: String, mukafChoma: Boolean, minutes: Int): String? = when {
        !mukafChoma -> null
        nusah == "edot" -> if (minutes != ALLUMAGE_EDOT) "reglage_allumage_proposition_edot" else null
        minutes != ALLUMAGE_JERUSALEM -> "reglage_allumage_proposition"
        else -> null
    }

    /** Le libellé « · coutume de Jérusalem » : 40 min, à Jérusalem, hors Edot (audit du 16/11). */
    fun coutumeJerusalem(nusah: String, mukafChoma: Boolean, minutes: Int): Boolean =
        mukafChoma && nusah != "edot" && minutes == ALLUMAGE_JERUSALEM

    /**
     * Le texte du siddour que suggère l'instant [maintenant], d'après les
     * zmanim du [lieu] (demande du 10/10) : Tikoun 'hatsot de 'hatsot de la
     * nuit à l'aube ; Birkot hacha'har de l'aube à michéyakir ; Cha'harit
     * jusqu'à 'hatsot ; Min'ha de min'ha guedola à la chki'a ; Arvit dès tsét,
     * puis le Chema du coucher après 22 h 30 (repère d'usage, pas un zman).
     * null dans les deux creux, de 'hatsot à min'ha guedola et de la chki'a
     * à tsét : aucune de ces prières n'y a sa place à priori. Sans les
     * zmanim du jour (soleil de minuit), les heures fixes de SiddurMoment.
     */
    /** Les offices de semaine du siddour (audit du 16/11). */
    val OFFICES = setOf("chaharit", "minha", "arvit")

    /**
     * Audit du 16/11 (structure des offices) : le siddour n'a que les offices de semaine. La carte « Pour
     * cette heure » ne propose pas Cha'harit, Min'ha ni Arvit quand la prière relève d'un Chabbat ou d'un
     * Yom tov (le vendredi soir, le samedi, la fête) ; [moment] sinon.
     */
    fun momentOuvrable(moment: String?, date: LocalDate, heure: java.time.LocalTime, enIsrael: Boolean): String? =
        if (moment != null && moment in OFFICES &&
            CalendrierJuif.jour(CalendrierJuif.jourDeLaPriere(moment, date, heure), enIsrael).chome) null else moment

    /**
     * [enIsrael] : pour le Tikoun 'hatsot de la nuit (sansTikounHatsot) ; [nusah] : le profil des zmanim
     * (Zmanim.jour, audit du 16/11, horaires) et le Tikoun Ra'hel de midi (tikounRahelDeMidi).
     */
    fun momentDuSiddour(lieu: Zmanim.Lieu, maintenant: java.time.Instant, enIsrael: Boolean = true, nusah: String = Zmanim.NUSAH_COMMUN): String? {
        val zone = java.time.ZoneId.of(lieu.fuseau)
        val local = maintenant.atZone(zone)
        val date = local.toLocalDate()
        // La nuit appartient au jour hébreu civil après minuit, au lendemain avant minuit (audit du 16/11).
        val nuit = if (local.toLocalTime() < java.time.LocalTime.NOON) date else date.plusDays(1)
        val tikoun = if (sansTikounHatsot(nuit, enIsrael)) "chema_coucher" else "tikoun_hatsot"
        fun instants(d: LocalDate) = Zmanim.jour(lieu, d, nusah).associate { it.cle to it.instant }
        // Aube absente autour du solstice (Londres, Berlin, Moscou…, FCALENDRIER-08) : michéyakir, puis
        // le lever du soleil, en tiennent lieu ; les heures fixes ne servent que si chki'a ou tsét manquent.
        val z = instants(date).toMutableMap().also {
            if (it["alot"] == null) it["alot"] = it["misheyakir"] ?: it["netz"]
            if (it["misheyakir"] == null) it["misheyakir"] = it["netz"]
        }
        val hier = instants(date.minusDays(1))
        val cles = listOf("alot", "misheyakir", "chatsot", "minha_gedola", "chkia", "tset", "chatsot_layla")
        if (cles.any { z[it] == null } || hier["chatsot_layla"] == null) return SiddurMoment.suggestion(local.toLocalTime(), sansTikounHatsot(nuit, enIsrael))
        fun avant(cle: String) = maintenant < z.getValue(cle)!!
        val soir = if (local.toLocalTime() < java.time.LocalTime.of(22, 30) && local.toLocalTime() > java.time.LocalTime.NOON) "arvit" else "chema_coucher"
        return when {
            avant("alot") -> if (maintenant >= hier.getValue("chatsot_layla")!!) tikoun else "chema_coucher"
            avant("misheyakir") -> "birkot_hachahar"
            avant("chatsot") -> "chaharit"
            avant("minha_gedola") -> if (tikounRahelDeMidi(date, nusah)) "tikoun_hatsot" else null
            avant("chkia") -> "minha"
            avant("tset") -> null
            avant("chatsot_layla") -> soir
            else -> tikoun
        }
    }

    /**
     * Pas de Tikoun 'hatsot la nuit du jour hébreu [nuit] : Chabbat, Yom tov (le second jour en diaspora),
     * 'Hol hamoed Pessa'h (audit du 16/11 : consigne du texte tikoun_hatsot ; Kitsour Yalkut Yosef, דיני
     * תיקון חצות, se'if נה).
     */
    fun sansTikounHatsot(nuit: LocalDate, enIsrael: Boolean): Boolean {
        val c = com.kosherjava.zmanim.hebrewcalendar.JewishCalendar(nuit).apply { inIsrael = enIsrael }
        return nuit.dayOfWeek == java.time.DayOfWeek.SATURDAY || c.isYomTovAssurBemelacha ||
            c.yomTovIndex == com.kosherjava.zmanim.hebrewcalendar.JewishCalendar.CHOL_HAMOED_PESACH
    }

    /**
     * Bein hamétsarim, du 17 Tamouz au 8 Av, sauf Chabbat et Roch 'Hodech Av : beaucoup disent le Tikoun
     * Ra'hel après 'hatsot du jour (audit du 16/11 : Kitsour Yalkut Yosef, דיני תיקון חצות, se'ifim מה et
     * נז) ; usage des Edot et du Sfard, pas de l'Ashkenaz (Michna Beroura 1:9).
     */
    fun tikounRahelDeMidi(date: LocalDate, nusah: String): Boolean {
        if (nusah == "ashkenaz" || date.dayOfWeek == java.time.DayOfWeek.SATURDAY) return false
        val c = com.kosherjava.zmanim.hebrewcalendar.JewishCalendar(date)
        val j = c.jewishDayOfMonth
        return (c.jewishMonth == com.kosherjava.zmanim.hebrewcalendar.JewishDate.TAMMUZ && j >= 17) ||
            (c.jewishMonth == com.kosherjava.zmanim.hebrewcalendar.JewishDate.AV && j in 2..8)
    }

    /**
     * Les semaines d'un mois civil, du dimanche au samedi comme le calendrier
     * juif ; null hors du mois.
     */
    fun semaines(mois: YearMonth): List<List<LocalDate?>> = grille((1..mois.lengthOfMonth()).map { mois.atDay(it) })

    /** Le premier jour (1er) du mois hébreu qui contient [date]. Le mois ne dépend pas du lieu. */
    fun debutMoisHebreu(date: LocalDate): LocalDate =
        date.minusDays((CalendrierJuif.jour(date, false).jourHebreu - 1).toLong())

    /** Les 29 ou 30 jours du mois hébreu qui contient [date]. */
    fun joursMoisHebreu(date: LocalDate): List<LocalDate> {
        val debut = debutMoisHebreu(date)
        val mois = CalendrierJuif.jour(debut, false).moisHebreu
        return generateSequence(debut) { it.plusDays(1) }
            .takeWhile { CalendrierJuif.jour(it, false).moisHebreu == mois }.toList()
    }

    /** Les semaines du mois hébreu qui contient [date], du dimanche au samedi ; null hors du mois. */
    fun semainesHebreu(date: LocalDate): List<List<LocalDate?>> = grille(joursMoisHebreu(date))

    /** Le 1er du mois hébreu suivant ([sens] = 1) ou précédent ([sens] = -1). */
    fun moisHebreuVoisin(date: LocalDate, sens: Int): LocalDate =
        if (sens > 0) joursMoisHebreu(date).last().plusDays(1)
        else debutMoisHebreu(debutMoisHebreu(date).minusDays(1))

    private fun grille(jours: List<LocalDate>): List<List<LocalDate?>> {
        val decalage = jours.first().dayOfWeek.value % 7 // dimanche = 0
        val cases = List(decalage) { null } + jours
        return cases.chunked(7).map { it + List(7 - it.size) { null } }
    }
}
