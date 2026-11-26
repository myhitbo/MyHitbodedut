package com.myhitbodedut

import com.kosherjava.zmanim.hebrewcalendar.HebrewDateFormatter
import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import com.kosherjava.zmanim.hebrewcalendar.JewishDate
import com.kosherjava.zmanim.hebrewcalendar.TefilaRules
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime

/**
 * Le jour hébraïque et ce qu'il change aux prières (demande du 10/10), hors
 * ligne, par KosherJava 2.5.0 : JewishCalendar pour la date et les fêtes,
 * TefilaRules pour les ajouts. Aucune règle n'est écrite ici : chaque
 * condition renvoie à une méthode de la bibliothèque, lue dans le jar et dans
 * ses sources (zmanim-2.5.0-sources.jar). Les coutumes de Ta'hanoun sont les
 * réglages par défaut de TefilaRules, les mêmes pour les trois nusah
 * (ZMANIM.md).
 *
 * Le même calcul existe côté web (web/src/js/tefila.js), vérifié jour par
 * jour contre ce fichier-ci par des vecteurs que KosherJava a produits
 * (web/test/vecteurs_kosherjava.json, tools/vecteurs_kosherjava).
 *
 * Pas d'Android ici : testable sur la machine virtuelle seule.
 */
object CalendrierJuif {

    /** Les clés de condition, communes à Android, au web et aux annotations du siddour. */
    object C {
        const val YAALE_VEYAVO = "yaale_veyavo"
        const val ROCH_HODECH = "roch_hodech"
        const val PESSAH = "pessah"
        const val SOUKKOT = "soukkot"
        const val CHAVOUOT = "chavouot"
        const val ROCH_HACHANA = "roch_hachana"
        const val CHEMINI_ATSERET = "chemini_atseret"
        const val KIPPOUR = "kippour"
        const val AL_HANISSIM = "al_hanissim"
        const val HANOUKA = "hanouka"
        const val POURIM = "pourim"
        const val MACHIV_HAROUAH = "machiv_harouah"
        const val MORID_HATAL = "morid_hatal"
        const val TAL_OUMATAR = "tal_oumatar"
        const val BERAKHA = "berakha"
        const val HALLEL = "hallel"
        const val HALLEL_COMPLET = "hallel_complet"
        const val TAHANOUN_CHAHARIT = "tahanoun_chaharit"
        const val TAHANOUN_MINHA = "tahanoun_minha"
        const val LUNDI_JEUDI = "lundi_jeudi"
        const val ASSERET_YEMEI_TECHOUVA = "asseret_yemei_techouva"
        const val JEUNE = "jeune"
        const val TICHA_BEAV = "ticha_beav"
        const val CHABBAT = "chabbat"
        const val MOTSAE_CHABBAT = "motsae_chabbat"
        const val OMER = "omer"
        /** Du 22 Tichri à la fin du mois : Ta'hanoun selon la coutume (SiddurJour.conditionsPour). */
        const val FIN_TICHRI = "fin_tichri"

        val TOUTES = listOf(
            YAALE_VEYAVO, ROCH_HODECH, PESSAH, SOUKKOT, CHAVOUOT, ROCH_HACHANA, CHEMINI_ATSERET, KIPPOUR, AL_HANISSIM, HANOUKA, POURIM,
            MACHIV_HAROUAH, MORID_HATAL, TAL_OUMATAR, BERAKHA, HALLEL, HALLEL_COMPLET,
            TAHANOUN_CHAHARIT, TAHANOUN_MINHA, LUNDI_JEUDI, ASSERET_YEMEI_TECHOUVA,
            JEUNE, TICHA_BEAV, CHABBAT, MOTSAE_CHABBAT, OMER, FIN_TICHRI,
        )

        /** Avinou malkénou (SiddurJour.conditionsPour) : déduite des conditions du jour, hors des vecteurs KosherJava. */
        const val AVINOU_MALKENOU = "avinou_malkenou"
        /** Avinou malkénou à Min'ha : le même jour, si Ta'hanoun s'y dit ou à Roch Hachana et Kippour, jamais le vendredi (TSIDDUR-09). */
        const val AVINOU_MALKENOU_MINHA = "avinou_malkenou_minha"
        /** Jour de lecture de la Torah (15/10) : déduite, hors des vecteurs KosherJava comme Avinou malkénou. */
        const val KRIAT_HATORAH = "kriat_hatorah"
        /**
         * Le psaume du jour (16/10) : « jour_1 » le dimanche … « jour_6 » le vendredi ; et les
         * jours où l'on en ajoute un (Edot) : le jeûne de Guedalia et le 10 Tévet, le lendemain
         * de Kippour, le jeûne d'Esther et Pourim, le 17 Tamouz. Déduites, hors des vecteurs.
         */
        val JOURS_SEMAINE = (1..6).map { "jour_$it" }
        const val TSOM_GUEDALIA_TEVET = "tsom_guedalia_tevet"
        const val LENDEMAIN_KIPPOUR = "lendemain_kippour"
        /** Le 9 Av ou Kippour (12/11) : « שעשה לי כל צרכי » ne se dit pas (Edot, Ben Ich 'Haï, Vayechev 9). */
        const val TICHA_BEAV_KIPPOUR = "ticha_beav_kippour"
        const val ESTHER_POURIM = "esther_pourim"
        /**
         * Le dimanche 16 Adar d'un Pourim triple, en Israël hors de Jérusalem (14/11) : l'Ashkenaz y omet
         * Ta'hanoun (Halikhot Chlomo 22:8 ; SiddurJour.conditionsPour), Edot et Sfard le disent (Yalkut Yosef).
         */
        const val POURIM_TRIPLE_HORS_JERUSALEM = "pourim_triple_hors_jerusalem"
        /** Le même dimanche à Jérusalem, jour du festin : « על הנסים » dans un « הרחמן » (Edot, Yalkut Yosef 688:6, § 15). */
        const val POURIM_TRIPLE_FESTIN = "pourim_triple_festin"
        const val CHIVA_ASSAR_TAMOUZ = "chiva_assar_tamouz"
        /**
         * Les deux jours de bascule (audit du 16/10) : le 22 Tichri, Cha'harit dit מוריד הטל et
         * Moussaf commence משיב הרוח ; le 15 Nissan, Cha'harit dit encore משיב הרוח et Moussaf
         * passe au טל (Choul'han Aroukh O.H. 114:1). Les deux formules valent ce jour-là.
         */
        const val BASCULE_PLUIE = "bascule_pluie"
        /** La veille de Kippour un vendredi (Kippour le Chabbat) : Avinou malkénou à Cha'harit (Rema O.H. 604:2). */
        const val EREV_KIPPOUR_VENDREDI = "erev_kippour_vendredi"
        /**
         * Relevé du 19/10, ce que le siddour annonce et qui restait ouvert : למנצח hors des jours que
         * le siddour Sfard énumère (Roch 'Hodech, 'Hanouka, Pourim, 14-15 Adar I, veilles de Pessa'h
         * et de Kippour, 9 Av) ; « לדוד ה׳ אורי » de Roch 'Hodech Eloul à Hochaana Rabba (consigne
         * du siddour) ; les dix jours et Hochaana Rabba ; Yom tov et 'Hol hamoed (« במועדים ») ;
         * les fêtes un Chabbat ; le motsaé Chabbat ou Yom tov. « beit_avel » et « oubli » ne sont
         * jamais du jour : la maison endeuillée et la bénédiction de qui a oublié restent repliées.
         */
        const val LAMNATSEAH = "lamnatseah"
        const val LEDAVID = "ledavid"
        const val TECHOUVA_HOCHAANA = "techouva_hochaana"
        const val YOM_TOV = "yom_tov"
        const val MOED = "moed"
        const val CHABBAT_ROCH_HODECH = "chabbat_roch_hodech"
        const val YOM_TOV_CHABBAT = "yom_tov_chabbat"
        const val ROCH_HACHANA_CHABBAT = "roch_hachana_chabbat"
        const val MOTSAE_CHABBAT_YT = "motsae_chabbat_yt"
        const val BEIT_AVEL = "beit_avel"
        const val OUBLI = "oubli"

        /** Les Chéva bérakhot de la table, à la fin de Birkat haMazon (28/10) : jamais du jour, repliées. */
        const val CHEVA_BERAKHOT = "cheva_berakhot"

        /** Le zimoun de Birkat haMazon, à trois convives ou plus (29/10) : jamais du jour, replié. */
        const val ZIMUN = "zimun"

        /** Ce qui n'est pas obligatoire dans Birkat haMazon (03/11) : les psaumes d'avant (les הרחמן en clair depuis le 12/11). Jamais du jour, replié. */
        const val FACULTATIF = "facultatif"

        /** Roch 'Hodech d'une année embolismique ; avant Nissan (« וּלְכַפָּרַת פָּשַׁע », 28/10). */
        const val EMBOLISMIQUE = "embolismique"
        const val EMBOLISMIQUE_AVANT_NISSAN = "embolismique_avant_nissan"

        /** Ce qui ne se dit qu'avec un minyan (Kaddich, Barekhou, Kedoucha…) : jamais du jour, replié. */
        const val MINYAN = "minyan"

        /**
         * Audit du 16/11 (Ta'hanoun et ce qui en dépend) :
         *  - AVINOU_MALKENOU_JEUNE : les lignes des jeûnes d'Avinou malkénou (« ברך עלינו », « זכרנו »), un jeûne
         *    hors des dix jours ; à Tsom Guedalia, on dit celles des dix jours (Matté Efraïm 602:13) ;
         *  - KADDICH_COMPLET_HALLEL : la fin du Kaddich après le Hallel, sauf à 'Hanouka, mais à Roch 'Hodech Tévèt
         *    et le Chabbat de 'Hanouka, qui ont un Moussaf (Kitsour Yalkout Yossef 423:1 ; Kaf ha'Haïm 683:2) ;
         *  - VEILLE_PESSAH_CHENI : le 13 Iyar, sans Vidouï à Min'ha en Edot (Kitsour Yalkout Yossef 131:38) ;
         *  - EREV_KIPPOUR : le 9 Tichri, Vidouï et « על חטא » après l'Amida de Min'ha (Choul'han Aroukh O.H. 607:1).
         */
        const val AVINOU_MALKENOU_JEUNE = "avinou_malkenou_jeune"
        const val KADDICH_COMPLET_HALLEL = "kaddich_complet_hallel"
        const val VEILLE_PESSAH_CHENI = "veille_pessah_cheni"
        /** Le 14 Iyar : sans Ta'hanoun, usage que ni le Choul'han Aroukh ni le Michna Beroura ne citent (JourAffiche le dit en Ashkenaz). */
        const val JOUR_PESSAH_CHENI = "jour_pessah_cheni"
        /**
         * אל ארך אפים (Ashkenaz, Sfard) : les jours de למנצח, le lundi et le jeudi seulement (Michna Beroura 131:35 ;
         * Choul'han Aroukh haRav 429:12 ; Matté Efraïm 602:12), pas un jeûne d'un autre jour.
         */
        const val EL_EREKH_APAYIM = "el_erekh_apayim"
        const val EREV_KIPPOUR = "erev_kippour"

        /**
         * « Pas de Ta'hanoun aujourd'hui » (réglage ponctuel, audit du 16/11 ; Choul'han Aroukh O.H. 131:4) :
         * maison en deuil, brit mila, 'hatan. Jamais calculée : ajoutée par l'écran le jour choisi
         * (Store.sansTahanounAujourdhui), elle retire le Ta'hanoun (SiddurJour.conditionsPour).
         */
        const val SANS_TAHANOUN_PONCTUEL = "sans_tahanoun_ponctuel"

        /**
         * Hallel et Moussaf (audit du 16/11) :
         * - Roch 'Hodech en semaine : le Moussaf de l'application (« מקדש ישראל וראשי חדשים ») ; le
         *   Chabbat, c'est « אתה יצרת » (Kitsour Yalkut Yosef 423:10 ; Choul'han Aroukh O.H. 425:3) ;
         * - 'Hol hamoed, sans les jours de Yom tov : le Moussaf de la fête (Kitsour Yalkut Yosef 490:2) ;
         * - 'Hanouka sans Moussaf (ni Roch 'Hodech ni Chabbat) : demi-Kaddich après le Hallel ; les autres
         *   jours de Hallel, תתקבל (Kitsour Yalkut Yosef 423:1 ; Michna Beroura 423:1) ;
         * - 'Hanouka hors de Roch 'Hodech : le psaume de 'Hanouka dans le Chir chel yom ; à Roch 'Hodech
         *   Tévèt, après Moussaf et ברכי נפשי (Kitsour Yalkut Yosef 683:11) ;
         * - le soir du Séder (15 Nissan, et 16 en diaspora ; Arvit relève de ce jour-là) : Hallel complet
         *   après l'Amida d'Arvit chez les Séfarades (Kitsour Yalkut Yosef 487:5) ;
         * - Hallel partiel : Roch 'Hodech, fin de Pessa'h.
         */
        const val ROCH_HODECH_CHOL = "roch_hodech_chol"
        const val HOL_HAMOED = "hol_hamoed"
        const val HANOUKA_SANS_MOUSSAF = "hanouka_sans_moussaf"
        const val HANOUKA_HORS_ROCH_HODECH = "hanouka_hors_roch_hodech"
        const val LEIL_PESSAH = "leil_pessah"
        const val HALLEL_PARTIEL = "hallel_partiel"

        /**
         * Audit du 16/11 (structure des offices). [MIZMOR_LETODA] : pas le Chabbat, le Yom tov, pendant
         * Pessa'h, la veille de Pessa'h ni la veille de Kippour (Rema O.H. 51:9 ; Michna Beroura 51:22, 604:4).
         * [HOL_HAMOED] (plus haut) : 'Hol hamoed seul, sans le Yom tov. [YOM_TOV_SEMAINE] : le dimanche, quand un Yom tov
         * ou 'Hol hamoed tombe du dimanche au vendredi (Michna Beroura 295:3). [LEIL_HASEDER] : la nuit du
         * Séder, deux en diaspora. [LENDEMAIN_ROCH_HODECH] : le jour qui suit Roch 'Hodech. [CHOME] : Chabbat
         * ou Yom tov (isAssurBemelacha), comme Jour.chome.
         */
        const val MIZMOR_LETODA = "mizmor_letoda"
        const val YOM_TOV_SEMAINE = "yom_tov_semaine"
        const val LEIL_HASEDER = "leil_haseder"
        const val LENDEMAIN_ROCH_HODECH = "lendemain_roch_hodech"
        const val CHOME = "chome"

        /**
         * Posées par SiddurJour.conditionsPour selon le noussa'h (audit du 16/11). [VIHI_NOAM] : ויהי נועם au
         * motsaé Chabbat ; [VEATA_KADOCH] : « ואתה קדוש » et la suite, ces soirs-là et le soir du 9 Av ;
         * [TEFILIN] : le jour où l'on met les téfilin ; [TEFILIN_SANS_BERAKHA] : 'Hol hamoed, Ashkenaz hors
         * d'Israël ; [VIDUI_COUCHER] : le Vidouï du Chema du coucher (Edot).
         */
        const val VIHI_NOAM = "vihi_noam"
        const val VEATA_KADOCH = "veata_kadoch"
        const val TEFILIN = "tefilin"
        const val TEFILIN_SANS_BERAKHA = "tefilin_sans_berakha"
        const val VIDUI_COUCHER = "vidui_coucher"
        /**
         * Le vendredi 14 Adar d'un Pourim triple, à Jérusalem (audit du 16/11) : la Méguila s'y lit, et la nuit
         * qui l'ouvre, avant Arvit, le psaume 22 (Kitsour Yalkut Yosef 693:1), sans que ce soit « pourim ».
         */
        const val POURIM_TRIPLE_VENDREDI = "pourim_triple_vendredi"
        /** La nuit (audit du 16/11, Méguila) : posée par la lecture d'après l'heure ([nuit]), jamais par le calendrier. */
        const val NUIT = "nuit"

        /**
         * Audit du 16/11, la Havdala (Choul'han Aroukh O.H. 556:1 et 624:3-5 ; Michna Beroura 556:1-5 ;
         * Kitsour Yalkut Yosef 556:6-8 et 624:4-6) : la flamme le Chabbat qui finit et au sortir de Kippour ;
         * les bessamim le Chabbat qui finit, sauf le samedi soir du 9 Av (le soir, avec le jour hébreu qui
         * commence, ou le samedi même quand l'app ne connaît pas le lieu) ; le lundi après un 9 Av du
         * dimanche, Havdala sur la coupe, sans flamme ni bessamim.
         */
        const val HAVDALA_NER = "havdala_ner"
        const val HAVDALA_BESSAMIM = "havdala_bessamim"
        const val LENDEMAIN_TICHA_BEAV_DIMANCHE = "lendemain_ticha_beav_dimanche"
        /**
         * Le jour hébreu qui suit un jour d'ajouts au Birkat haMazon (Chabbat, Roch 'Hodech, Yom tov,
         * 'Hol hamoed, 'Hanouka, Pourim), sauf le Chabbat : un repas commencé la veille s'y conclut avec
         * les ajouts de la veille (Choul'han Aroukh O.H. 188:10 ; Michna Beroura 188:32-34 ; Kitsour
         * Yalkut Yosef 188:16, 19 ; audit du 16/11).
         */
        const val LENDEMAIN_AJOUTS = "lendemain_ajouts"
        /** Du 17 Tamouz au 10 Av : שהחיינו évité (Choul'han Aroukh O.H. 551:17 ; Kitsour Yalkut Yosef 551:9 ; audit du 16/11). */
        const val BEIN_HAMETSARIM = "bein_hametsarim"

        /**
         * Tikoun Ra'hel (audit du 16/11) : pas à Roch 'Hodech, de Roch Hachana à Chemini Atseret, à 'Hanouka,
         * aux jours de Pourim, en Nissan, pendant l'omer (Kitsour Yalkut Yosef, דיני תיקון חצות §נה ; Ben Ich
         * 'Haï, Vayichla'h ה), ni en Israël l'année de chemita (§נז).
         */
        const val TIKOUN_RAHEL = "tikoun_rahel"

        /** Toujours vrai (audit du 16/11) : une indication fixe du siddour, sans condition du jour. */
        const val TOUJOURS = "toujours"

        /**
         * Les catégories du 26/11 (les ajouts du calendrier retirés hors de leur jour) :
         *  - [VOYAGEUR_TAL_OUMATAR] : Israël et la diaspora diffèrent pour « ותן טל ומטר » (du 7 'Hechvan au
         *    4 ou 5 décembre) ; la consigne du voyageur n'est repliée que ces jours-là, retirée les autres (Q3) ;
         *  - [RETSE_OU_YAALE] : Chabbat ou jour de « יעלה ויבוא », les bénédictions de qui a oublié רצה ou
         *    יעלה ויבוא au Birkat haMazon (Q5) ;
         *  - [YAMIM_NORAIM] : Roch Hachana ou Kippour (une ligne des Mi chébérakh) ;
         *  - [OMER_JOURS] : « omer_N », le compte du soir (Q12) ;
         *  - [ISRAEL] : posée par SiddurJour.conditionsPour en Israël (le psaume 121 d'Arvit, « בא״י קדישא ») ;
         *  - [MAGDOL] : « מגדול » à la fin du Birkat (SiddurJour.conditionsPour, selon le noussa'h) ;
         *  - [HOMME], [FEMME] : le réglage צדיק / צדקת (Store.conditionsDuJour) ; sans réglage, ni l'un ni l'autre.
         */
        const val VOYAGEUR_TAL_OUMATAR = "voyageur_tal_oumatar"
        const val RETSE_OU_YAALE = "retse_ou_yaale"
        const val YAMIM_NORAIM = "yamim_noraim"
        val OMER_JOURS = (1..49).map { "omer_$it" }
        const val ISRAEL = "israel"
        const val MAGDOL = "magdol"
        const val HOMME = "homme"
        const val FEMME = "femme"
        /** Les occasions du 26/11, jamais du jour (SiddurJour.OCCASIONS) : qui prie seul, un usage, une occasion. */
        const val SANS_MINYAN = "sans_minyan"
        const val USAGE = "usage"
        const val OCCASION = "occasion"
        val DERIVEES = listOf(AVINOU_MALKENOU, AVINOU_MALKENOU_MINHA, KRIAT_HATORAH) + JOURS_SEMAINE +
            listOf(TSOM_GUEDALIA_TEVET, LENDEMAIN_KIPPOUR, TICHA_BEAV_KIPPOUR, ESTHER_POURIM, CHIVA_ASSAR_TAMOUZ, BASCULE_PLUIE, EREV_KIPPOUR_VENDREDI,
                LAMNATSEAH, LEDAVID, TECHOUVA_HOCHAANA, YOM_TOV, MOED, CHABBAT_ROCH_HODECH, YOM_TOV_CHABBAT, ROCH_HACHANA_CHABBAT,
                MOTSAE_CHABBAT_YT, BEIT_AVEL, OUBLI, MINYAN, CHEVA_BERAKHOT, ZIMUN, FACULTATIF, EMBOLISMIQUE, EMBOLISMIQUE_AVANT_NISSAN,
                POURIM_TRIPLE_HORS_JERUSALEM, POURIM_TRIPLE_FESTIN, AVINOU_MALKENOU_JEUNE, KADDICH_COMPLET_HALLEL,
                VEILLE_PESSAH_CHENI, EREV_KIPPOUR, SANS_TAHANOUN_PONCTUEL, JOUR_PESSAH_CHENI, EL_EREKH_APAYIM,
                ROCH_HODECH_CHOL, HOL_HAMOED, HANOUKA_SANS_MOUSSAF, HANOUKA_HORS_ROCH_HODECH, LEIL_PESSAH, HALLEL_PARTIEL,
                MIZMOR_LETODA, YOM_TOV_SEMAINE, LEIL_HASEDER, LENDEMAIN_ROCH_HODECH, CHOME, VIHI_NOAM, VEATA_KADOCH, TEFILIN,
                TEFILIN_SANS_BERAKHA, VIDUI_COUCHER, NUIT, POURIM_TRIPLE_VENDREDI, HAVDALA_NER, HAVDALA_BESSAMIM,
                LENDEMAIN_TICHA_BEAV_DIMANCHE, LENDEMAIN_AJOUTS, BEIN_HAMETSARIM, TIKOUN_RAHEL, TOUJOURS,
                VOYAGEUR_TAL_OUMATAR, RETSE_OU_YAALE, YAMIM_NORAIM, ISRAEL, MAGDOL, HOMME, FEMME, SANS_MINYAN, USAGE, OCCASION) + OMER_JOURS
    }

    /**
     * Les fêtes par l'index de JewishCalendar.getYomTovIndex() (constantes
     * lues dans JewishCalendar.java, 2.5.0). La clé donne le libellé
     * « fete_<clé> » dans strings.xml.
     */
    val FETES = mapOf(
        JewishCalendar.EREV_PESACH to "erev_pessah",
        JewishCalendar.PESACH to "pessah",
        JewishCalendar.CHOL_HAMOED_PESACH to "hol_hamoed_pessah",
        JewishCalendar.PESACH_SHENI to "pessah_cheni",
        JewishCalendar.EREV_SHAVUOS to "erev_chavouot",
        JewishCalendar.SHAVUOS to "chavouot",
        JewishCalendar.SEVENTEEN_OF_TAMMUZ to "tamouz_17",
        JewishCalendar.TISHA_BEAV to "ticha_beav",
        JewishCalendar.TU_BEAV to "tou_beav",
        JewishCalendar.EREV_ROSH_HASHANA to "erev_roch_hachana",
        JewishCalendar.ROSH_HASHANA to "roch_hachana",
        JewishCalendar.FAST_OF_GEDALYAH to "jeune_guedalia",
        JewishCalendar.EREV_YOM_KIPPUR to "erev_yom_kippour",
        JewishCalendar.YOM_KIPPUR to "yom_kippour",
        JewishCalendar.EREV_SUCCOS to "erev_soukkot",
        JewishCalendar.SUCCOS to "soukkot",
        JewishCalendar.CHOL_HAMOED_SUCCOS to "hol_hamoed_soukkot",
        JewishCalendar.HOSHANA_RABBA to "hochaana_rabba",
        JewishCalendar.SHEMINI_ATZERES to "chemini_atseret",
        JewishCalendar.SIMCHAS_TORAH to "simhat_torah",
        JewishCalendar.CHANUKAH to "hanouka",
        JewishCalendar.TENTH_OF_TEVES to "tevet_10",
        JewishCalendar.TU_BESHVAT to "tou_bichvat",
        JewishCalendar.FAST_OF_ESTHER to "jeune_esther",
        JewishCalendar.PURIM to "pourim",
        JewishCalendar.SHUSHAN_PURIM to "chouchan_pourim",
        JewishCalendar.PURIM_KATAN to "pourim_katan",
        JewishCalendar.ROSH_CHODESH to "roch_hodech",
        JewishCalendar.YOM_HASHOAH to "yom_hachoah",
        JewishCalendar.YOM_HAZIKARON to "yom_hazikaron",
        JewishCalendar.YOM_HAATZMAUT to "yom_haatsmaout",
        JewishCalendar.YOM_YERUSHALAYIM to "yom_yerouchalayim",
        JewishCalendar.LAG_BAOMER to "lag_baomer",
        JewishCalendar.SHUSHAN_PURIM_KATAN to "chouchan_pourim_katan",
        JewishCalendar.ISRU_CHAG to "isrou_hag",
    )

    data class Jour(
        val date: LocalDate,
        val enIsrael: Boolean,
        /** « כ״ט תשרי תשפ״ז », par HebrewDateFormatter. */
        val dateHebraique: String,
        /** Le quantième en lettres, « כ״ט », pour la grille du calendrier. */
        val jourEnLettres: String,
        val jourHebreu: Int,
        /** Le mois hébreu, constante de JewishDate (NISSAN = 1 … ADAR_II = 13). */
        val moisHebreu: Int,
        val anneeHebraique: Int,
        /** « תשרי תשפ״ז » : le titre d'un mois du calendrier. */
        val moisEtAnnee: String,
        /** Clés « fete_<clé> » du jour, sans doublon. */
        val fetes: List<String>,
        /** Le jour de l'omer compté le soir qui ouvre ce jour hébreu, 0 hors omer. */
        val omer: Int,
        /** La paracha lue ce Chabbat, en hébreu ; null en semaine ou un Chabbat de fête. */
        val paracha: String?,
        /** Chabbat ou Yom Tov : jour où le travail est interdit (isAssurBemelacha). */
        val chome: Boolean,
        val conditions: Set<String>,
        /** Le Chabbat spécial (Chekalim, Zakhor, Para, ha'Hodech…), en hébreu ; null les autres jours (audit du 16/11). */
        val parachaSpeciale: String? = null,
    )

    private val formatHebreu = HebrewDateFormatter().apply { isHebrewFormat = true }

    /** Jérusalem, ville murée depuis Josué : Pourim y est le 15 Adar (Chouchan Pourim). */
    const val JERUSALEM_GEONAMES = 281184L

    /**
     * Une position dans Jérusalem (13/10) : à 10 km au plus de la Vieille Ville
     * (31,7767 N ; 35,2345 E). Le rayon est un choix de l'application, qui
     * approche l'agglomération ; ce n'est pas une limite halakhique.
     * Hors de la ville (audit du 16/10) : à l'est de 35,258 E (Abou Dis, Ma'alé Adoumim),
     * au sud de 31,72 N (Bethléem, Beit Jala), et Mevasseret (ouest de 35,165 E au nord
     * de 31,785 N) — Ramot, Gilo, Ein Kerem, Har Homa et Pisgat Zeev restent dedans.
     */
    fun aJerusalem(latitude: Double, longitude: Double): Boolean {
        if (longitude > 35.258 || latitude < 31.72 || (longitude < 35.165 && latitude > 31.785)) return false
        val r = 6371.0
        val dLat = Math.toRadians(latitude - 31.7767)
        val dLon = Math.toRadians(longitude - 35.2345)
        val a = Math.sin(dLat / 2).let { it * it } +
            Math.cos(Math.toRadians(31.7767)) * Math.cos(Math.toRadians(latitude)) * Math.sin(dLon / 2).let { it * it }
        return 2 * r * Math.asin(Math.sqrt(a)) <= 10.0
    }

    /** Les noms de Pourim dans une ville murée (libellés « fete_<clé> »). */
    private val MUREE = mapOf("pourim" to "pourim_ailleurs", "chouchan_pourim" to "pourim_jerusalem")

    /**
     * [mukafChoma] : une ville murée depuis Josué, où Pourim et Al hanissim
     * sont le 15 Adar (JewishCalendar.setIsMukafChoma). Seule Jérusalem l'est
     * avec certitude parmi les villes proposées ; les villes en doute (Tibériade,
     * Safed…) gardent le 14, comme le calendrier commun.
     */
    fun jour(date: LocalDate, enIsrael: Boolean, mukafChoma: Boolean = false): Jour {
        // Deux calendriers : les fêtes modernes s'affichent, mais n'entrent pas
        // dans les règles de prière, où leur coutume varie (TefilaRules les
        // compte si isUseModernHolidays est vrai).
        val regles = calendrier(date, enIsrael, modernes = false).apply { setIsMukafChoma(mukafChoma) }
        val affiche = calendrier(date, enIsrael, modernes = true).apply { setIsMukafChoma(mukafChoma) }
        val tefila = TefilaRules()
        val semaine = date.dayOfWeek

        val conditions = buildSet {
            if (tefila.isYaalehVeyavoRecited(regles)) add(C.YAALE_VEYAVO)
            if (regles.isRoshChodesh) add(C.ROCH_HODECH)
            if (regles.isPesach) add(C.PESSAH)
            if (regles.isSuccos) add(C.SOUKKOT)
            // Les variantes de Ya'alé véyavo du Birkat hamazone, une par fête.
            if (regles.isShavuos) add(C.CHAVOUOT)
            if (regles.isRoshHashana) add(C.ROCH_HACHANA)
            if (regles.isShminiAtzeres || regles.isSimchasTorah) add(C.CHEMINI_ATSERET)
            if (regles.isYomKippur) add(C.KIPPOUR)
            if (tefila.isAlHanissimRecited(regles)) add(C.AL_HANISSIM)
            if (regles.isChanukah) add(C.HANOUKA)
            if (regles.isPurim) add(C.POURIM)
            if (tefila.isMashivHaruachRecited(regles)) add(C.MACHIV_HAROUAH)
            if (tefila.isMoridHatalRecited(regles)) add(C.MORID_HATAL)
            if (tefila.isVeseinTalUmatarRecited(regles)) add(C.TAL_OUMATAR)
            if (tefila.isVeseinBerachaRecited(regles)) add(C.BERAKHA)
            if (tefila.isHallelRecited(regles)) add(C.HALLEL)
            if (tefila.isHallelShalemRecited(regles)) add(C.HALLEL_COMPLET)
            // La veille de Roch Hachana, pas de Ta'hanoun à la prière (Choul'han
            // Aroukh, OC 581:3), que TefilaRules 2.5.0 fait dire.
            // Pourim triple (15 Adar un Chabbat) : à Jérusalem, le dimanche 16 est le jour du festin, sans
            // Ta'hanoun ni למנצח (Kitsour Yalkout Yossef 688:6, § 14 ; Piskei techouvot 693:7), ce que TefilaRules
            // ignore. Ailleurs en Israël, Ta'hanoun lekhat'hila (Rav Its'hak Yossef, chiour 488, 5785), sauf en
            // Ashkenaz (C.POURIM_TRIPLE_HORS_JERUSALEM).
            val dimanchePourimTriple = semaine == DayOfWeek.SUNDAY && regles.jewishDayOfMonth == 16 &&
                regles.jewishMonth == (if (regles.isJewishLeapYear) JewishDate.ADAR_II else JewishDate.ADAR)
            val festinJerusalem = mukafChoma && dimanchePourimTriple
            if (festinJerusalem) add(C.POURIM_TRIPLE_FESTIN)
            if (enIsrael && !mukafChoma && dimanchePourimTriple) add(C.POURIM_TRIPLE_HORS_JERUSALEM)
            val tahanoun = tefila.isTachanunRecitedShacharis(regles) &&
                regles.yomTovIndex != JewishCalendar.EREV_ROSH_HASHANA && !festinJerusalem
            if (tahanoun) add(C.TAHANOUN_CHAHARIT)
            if (tefila.isTachanunRecitedMincha(regles) && !festinJerusalem) add(C.TAHANOUN_MINHA)
            // « לשני וחמישי » : le titre de la section du siddour le dit ; les
            // jours sans Ta'hanoun, la section ne se dit pas non plus.
            if (tahanoun && (semaine == DayOfWeek.MONDAY || semaine == DayOfWeek.THURSDAY)) add(C.LUNDI_JEUDI)
            if (regles.isAseresYemeiTeshuva) add(C.ASSERET_YEMEI_TECHOUVA)
            if (regles.isTaanis && !regles.isYomKippur) add(C.JEUNE)
            if (regles.isTishaBav) add(C.TICHA_BEAV)
            if (semaine == DayOfWeek.SATURDAY) add(C.CHABBAT)
            if (semaine == DayOfWeek.SUNDAY) add(C.MOTSAE_CHABBAT)
            if (regles.dayOfOmer > 0) add(C.OMER)
            if (regles.jewishMonth == JewishDate.TISHREI && regles.jewishDayOfMonth >= 22) add(C.FIN_TICHRI)
            // La lecture de la Torah à Cha'harit (15/10) : lundi et jeudi, Chabbat et fêtes,
            // Roch 'Hodech, 'Hol hamoed, 'Hanouka, Pourim, jeûnes publics (9 Av compris).
            if (semaine == DayOfWeek.MONDAY || semaine == DayOfWeek.THURSDAY ||
                listOf(C.CHABBAT, C.ROCH_HODECH, C.PESSAH, C.SOUKKOT, C.CHAVOUOT, C.ROCH_HACHANA, C.KIPPOUR,
                    C.CHEMINI_ATSERET, C.HANOUKA, C.POURIM, C.JEUNE, C.TICHA_BEAV).any { it in this }) add(C.KRIAT_HATORAH)
            // Le psaume du jour et les jours qui en ajoutent un (16/10).
            if (semaine != DayOfWeek.SATURDAY) add("jour_${semaine.value % 7 + 1}")
            val index = regles.yomTovIndex
            if (index == JewishCalendar.FAST_OF_GEDALYAH || index == JewishCalendar.TENTH_OF_TEVES) add(C.TSOM_GUEDALIA_TEVET)
            if (regles.jewishMonth == JewishDate.TISHREI && regles.jewishDayOfMonth == 11) add(C.LENDEMAIN_KIPPOUR)
            if (regles.isTishaBav || regles.isYomKippur) add(C.TICHA_BEAV_KIPPOUR)
            if (index == JewishCalendar.FAST_OF_ESTHER || C.POURIM in this) add(C.ESTHER_POURIM)
            if (index == JewishCalendar.SEVENTEEN_OF_TAMMUZ) add(C.CHIVA_ASSAR_TAMOUZ)
            if ((regles.jewishMonth == JewishDate.TISHREI && regles.jewishDayOfMonth == 22) ||
                (regles.jewishMonth == JewishDate.NISSAN && regles.jewishDayOfMonth == 15)) add(C.BASCULE_PLUIE)
            if (regles.jewishMonth == JewishDate.TISHREI && regles.jewishDayOfMonth == 9 && semaine == DayOfWeek.FRIDAY) add(C.EREV_KIPPOUR_VENDREDI)
            // Relevé du 19/10 (C.LAMNATSEAH…).
            val mois = regles.jewishMonth
            val quantieme = regles.jewishDayOfMonth
            val adar1415 = (mois == JewishDate.ADAR || mois == JewishDate.ADAR_II) && quantieme in 14..15
            if (!(regles.isRoshChodesh || regles.isChanukah || adar1415 || festinJerusalem || regles.isTishaBav || regles.isAssurBemelacha || regles.isCholHamoed ||
                    index == JewishCalendar.EREV_PESACH || index == JewishCalendar.EREV_YOM_KIPPUR)) add(C.LAMNATSEAH)
            // Dès le 30 Av, premier jour de Roch 'Hodech Eloul (26/11, Q13 : « מראש חודש אלול », Kitsour Yalkut Yosef 581 ;
            // Michna Beroura 581:2).
            if (mois == JewishDate.ELUL || (mois == JewishDate.AV && quantieme == 30) || (mois == JewishDate.TISHREI && quantieme <= 21)) add(C.LEDAVID)
            if (regles.isAseresYemeiTeshuva || (mois == JewishDate.TISHREI && quantieme == 21)) add(C.TECHOUVA_HOCHAANA)
            val yomTov = regles.isYomTovAssurBemelacha
            if (yomTov) add(C.YOM_TOV)
            if (listOf(C.PESSAH, C.SOUKKOT, C.CHAVOUOT, C.CHEMINI_ATSERET).any { it in this }) add(C.MOED)
            if (C.CHABBAT in this && regles.isRoshChodesh) add(C.CHABBAT_ROCH_HODECH)
            // Hallel et Moussaf (audit du 16/11 ; C.ROCH_HODECH_CHOL…).
            if (C.CHABBAT !in this && regles.isRoshChodesh) add(C.ROCH_HODECH_CHOL)
            if (regles.isCholHamoed) add(C.HOL_HAMOED)
            if (regles.isChanukah && !regles.isRoshChodesh && C.CHABBAT !in this) add(C.HANOUKA_SANS_MOUSSAF)
            if (regles.isChanukah && !regles.isRoshChodesh) add(C.HANOUKA_HORS_ROCH_HODECH)
            if (index == JewishCalendar.PESACH && mois == JewishDate.NISSAN && quantieme <= 16) add(C.LEIL_PESSAH)
            if (C.HALLEL in this && C.HALLEL_COMPLET !in this) add(C.HALLEL_PARTIEL)
            // « וּלְכַפָּרַת פָּשַׁע » au Moussaf de Roch 'Hodech d'une année embolismique (28/10) : jusqu'à
            // Roch 'Hodech Adar II inclus, plus à partir de Nissan (« עד חודש ניסן », Sfard et Ashkenaz ; pour
            // les Edot, Kitsour Yalkut Yosef 423:14, audit du 16/11 : la consigne de leur siddour, « בשנה
            // מעוברת », le dit toute l'année comme le Ben Ich 'Haï et le Kaf ha'Haïm 423:18). Michna Beroura
            // 423:6 rapporte trois usages : tous les mois, l'année embolismique, ou celle-ci jusqu'à la fin
            // d'Adar II. Le 30 inaugure le mois suivant.
            if (regles.isRoshChodesh && regles.isJewishLeapYear) {
                val inaugure = if (quantieme == 30) when (mois) {
                    JewishDate.ADAR -> JewishDate.ADAR_II
                    JewishDate.ADAR_II -> JewishDate.NISSAN
                    else -> mois + 1
                } else mois
                add(C.EMBOLISMIQUE)
                if (inaugure >= JewishDate.TISHREI) add(C.EMBOLISMIQUE_AVANT_NISSAN)
            }
            if (C.CHABBAT in this && yomTov) add(C.YOM_TOV_CHABBAT)
            if (C.CHABBAT in this && regles.isRoshHashana) add(C.ROCH_HACHANA_CHABBAT)
            // Audit du 16/11 (C.AVINOU_MALKENOU_JEUNE…).
            if (C.JEUNE in this && C.ASSERET_YEMEI_TECHOUVA !in this) add(C.AVINOU_MALKENOU_JEUNE)
            if (!regles.isChanukah || regles.isRoshChodesh || C.CHABBAT in this) add(C.KADDICH_COMPLET_HALLEL)
            if (mois == JewishDate.IYAR && quantieme == 13) add(C.VEILLE_PESSAH_CHENI)
            if (mois == JewishDate.IYAR && quantieme == 14) add(C.JOUR_PESSAH_CHENI)
            if (C.LAMNATSEAH in this && (semaine == DayOfWeek.MONDAY || semaine == DayOfWeek.THURSDAY)) add(C.EL_EREKH_APAYIM)
            if (index == JewishCalendar.EREV_YOM_KIPPUR) add(C.EREV_KIPPOUR)
            val hier = calendrier(date.minusDays(1), enIsrael, modernes = false)
            // Un samedi soir qui est Yom tov n'est pas un soir ouvrable : ni אתה חוננתנו ni ajouts du motsaé Chabbat
            // (Choul'han Aroukh O.H. 491:2, « ותודיענו » ; audit du 16/11).
            if ((C.MOTSAE_CHABBAT in this || hier.isYomTovAssurBemelacha) && !regles.isAssurBemelacha) add(C.MOTSAE_CHABBAT_YT)
            // Audit du 16/11 (C.MIZMOR_LETODA…). (C.HOL_HAMOED est posé plus haut.)
            if (regles.isAssurBemelacha) add(C.CHOME)
            if (!(C.CHABBAT in this || yomTov || regles.isPesach || index == JewishCalendar.EREV_PESACH ||
                    index == JewishCalendar.EREV_YOM_KIPPUR)) add(C.MIZMOR_LETODA)
            if (semaine == DayOfWeek.SUNDAY && (0L..5L).any { k ->
                    calendrier(date.plusDays(k), enIsrael, modernes = false).let { it.isYomTovAssurBemelacha || it.isCholHamoed }
                }) add(C.YOM_TOV_SEMAINE)
            if (mois == JewishDate.NISSAN && (quantieme == 15 || (quantieme == 16 && !enIsrael))) add(C.LEIL_HASEDER)
            if (hier.isRoshChodesh && !regles.isRoshChodesh) add(C.LENDEMAIN_ROCH_HODECH)
            if (mukafChoma && semaine == DayOfWeek.FRIDAY && quantieme == 14 &&
                mois == (if (regles.isJewishLeapYear) JewishDate.ADAR_II else JewishDate.ADAR)) add(C.POURIM_TRIPLE_VENDREDI)
            // La Havdala et le lendemain d'un jour d'ajouts (audit du 16/11, C.HAVDALA_NER…).
            val veille = calendrier(date.minusDays(1), enIsrael, modernes = false).apply { setIsMukafChoma(mukafChoma) }
            val kippour = C.KIPPOUR in this || C.LENDEMAIN_KIPPOUR in this
            if (C.CHABBAT in this || C.MOTSAE_CHABBAT in this || kippour) add(C.HAVDALA_NER)
            if (C.CHABBAT in this || (C.MOTSAE_CHABBAT in this && C.TICHA_BEAV !in this) || kippour) add(C.HAVDALA_BESSAMIM)
            if (semaine == DayOfWeek.MONDAY && veille.isTishaBav) add(C.LENDEMAIN_TICHA_BEAV_DIMANCHE)
            if (semaine != DayOfWeek.SATURDAY && (semaine == DayOfWeek.SUNDAY || veille.isRoshChodesh || veille.isYomTovAssurBemelacha ||
                    veille.isCholHamoed || veille.isChanukah || veille.isPurim)) add(C.LENDEMAIN_AJOUTS)
            if ((mois == JewishDate.TAMMUZ && quantieme >= 17) || (mois == JewishDate.AV && quantieme <= 10)) add(C.BEIN_HAMETSARIM)
            // Tikoun Ra'hel (audit du 16/11, C.TIKOUN_RAHEL).
            if (!(regles.isRoshChodesh || (mois == JewishDate.TISHREI && quantieme <= (if (enIsrael) 22 else 23)) || regles.isChanukah || adar1415 ||
                    mois == JewishDate.NISSAN || regles.dayOfOmer > 0 || (enIsrael && regles.jewishYear % 7 == 0))) add(C.TIKOUN_RAHEL)
            add(C.TOUJOURS)
            // Les catégories du 26/11 (C.VOYAGEUR_TAL_OUMATAR…).
            val enIsraelCal = calendrier(date, true, modernes = false)
            val enDiasporaCal = calendrier(date, false, modernes = false)
            if (tefila.isVeseinTalUmatarRecited(enIsraelCal) != tefila.isVeseinTalUmatarRecited(enDiasporaCal)) add(C.VOYAGEUR_TAL_OUMATAR)
            if (C.CHABBAT in this || C.YAALE_VEYAVO in this) add(C.RETSE_OU_YAALE)
            if (regles.isRoshHashana || regles.isYomKippur) add(C.YAMIM_NORAIM)
            if (regles.dayOfOmer > 0) add("omer_${regles.dayOfOmer}")
        }

        val fetes = buildList {
            // Dans une ville murée, le 15 Adar est Pourim ; le 14 ne l'est qu'ailleurs.
            FETES[affiche.yomTovIndex]?.let { add(if (mukafChoma) MUREE[it] ?: it else it) }
            if (affiche.isRoshChodesh && "roch_hodech" !in this) add("roch_hodech")
        }
        val paracha = if (semaine == DayOfWeek.SATURDAY && regles.parshah != JewishCalendar.Parsha.NONE)
            formatHebreu.formatParsha(regles) else null

        return Jour(
            date = date,
            enIsrael = enIsrael,
            dateHebraique = formatHebreu.format(regles),
            jourEnLettres = formatHebreu.formatHebrewNumber(regles.jewishDayOfMonth),
            jourHebreu = regles.jewishDayOfMonth,
            moisHebreu = regles.jewishMonth,
            anneeHebraique = regles.jewishYear,
            moisEtAnnee = formatHebreu.formatMonth(regles) + " " + formatHebreu.formatHebrewNumber(regles.jewishYear),
            fetes = fetes,
            omer = regles.dayOfOmer.coerceAtLeast(0),
            paracha = paracha?.takeIf { it.isNotBlank() },
            chome = regles.isAssurBemelacha,
            conditions = conditions,
            parachaSpeciale = parachaSpeciale(regles, mukafChoma),
        )
    }

    /**
     * Le Chabbat spécial (audit du 16/11) : Chekalim, Zakhor, Para, ha'Hodech… (formatSpecialParsha) ; à
     * Jérusalem, le Chabbat 15 Adar d'un Pourim triple, le maftir « ויבא עמלק » lu dans un second Séfer
     * (Choul'han Aroukh O.H. 688:6), que getSpecialShabbos ne connaît pas.
     */
    private fun parachaSpeciale(regles: JewishCalendar, mukafChoma: Boolean): String? {
        if (regles.dayOfWeek != 7) return null
        if (regles.specialShabbos != JewishCalendar.Parsha.NONE) return formatHebreu.formatSpecialParsha(regles).takeIf { it.isNotBlank() }
        val adar = if (regles.isJewishLeapYear) JewishDate.ADAR_II else JewishDate.ADAR
        return if (mukafChoma && regles.jewishMonth == adar && regles.jewishDayOfMonth == 15) "מפטיר ויבא עמלק" else null
    }

    /**
     * Les repères du jour qui ne changent pas le texte de la prière (audit du 16/11), en clés de chaîne :
     *  - Seli'hot : Edot dès le 2 Eloul (Kitsour Yalkut Yosef 581:1) ; Ashkenaz et Sfard dès le dimanche
     *    avant Roch Hachana, une semaine plus tôt s'il tombe un lundi ou un mardi (Rema 581:1 ; pour le
     *    Sfard, l'usage courant) ; jusqu'à la veille de Kippour, sauf Chabbat et Roch Hachana (usage général) ;
     *  - le chofar après Cha'harit, du 1er au 28 Eloul sauf Chabbat, en Ashkenaz (Rema 581:1) et en Sfard
     *    (usage courant) ; pas de chofar le 29 Eloul, pour tous (Rema 581:3 ; YY, ערב ראש השנה ה) ;
     *  - lundi-jeudi-lundi (בה״ב) en Ashkenaz et en Sfard (Rema 492:1 ; MB 492:3 et 566:10 ; Choul'han
     *    Aroukh haRav 492), et le « מי שבירך » du Chabbat qui précède ; rien pour les Edot ;
     *  - Yom Kippour katan, pour qui en a l'usage (MB 417:4 ; YY 417:5) ;
     *  - l'érouv tavchilin, la veille d'une fête qui mène à Chabbat (Choul'han Aroukh O.H. 527:1).
     */
    fun reperes(date: LocalDate, enIsrael: Boolean, nusah: String): List<String> = buildList {
        val c = calendrier(date, enIsrael, modernes = false)
        val mois = c.jewishMonth
        val j = c.jewishDayOfMonth
        val chabbat = date.dayOfWeek == DayOfWeek.SATURDAY
        val edot = nusah == "edot"
        if (selihot(date, enIsrael, edot)) add("repere_selihot")
        if (!edot && mois == JewishDate.ELUL && j <= 28 && !chabbat) add("repere_chofar")
        if (mois == JewishDate.ELUL && j == 29) add("repere_pas_de_chofar")
        if (!edot && c.isBeHaB) add("repere_behab")
        if (!edot && chabbat && calendrier(date.plusDays(2), enIsrael, false).isBeHaB && calendrier(date.plusDays(5), enIsrael, false).isBeHaB) {
            add("repere_behab_mi_cheberakh")
        }
        if (c.isYomKippurKatan) add("repere_yom_kippour_katan")
        if (erouvTavchilin(date, enIsrael)) add("repere_erouv_tavchilin")
    }

    private fun selihot(date: LocalDate, enIsrael: Boolean, edot: Boolean): Boolean {
        val c = calendrier(date, enIsrael, false)
        if (date.dayOfWeek == DayOfWeek.SATURDAY || c.isRoshHashana) return false
        if (c.jewishMonth == JewishDate.TISHREI) return c.jewishDayOfMonth <= 9
        if (c.jewishMonth != JewishDate.ELUL) return false
        if (edot) return c.jewishDayOfMonth >= 2
        // Le dimanche avant Roch Hachana ; s'il reste moins de quatre jours, celui d'avant.
        val rh = date.plusDays((30 - c.jewishDayOfMonth).toLong())
        var debut = rh.minusDays(((rh.dayOfWeek.value % 7)).toLong())
        if (java.time.temporal.ChronoUnit.DAYS.between(debut, rh) < 4) debut = debut.minusDays(7)
        return !date.isBefore(debut)
    }

    /**
     * La période où l'on évite d'écouter des chants avec instruments, même enregistrés (audit du 16/11) :
     * « omer » (sauf Lag baOmer ; Kitsour Yalkut Yosef 493:8), « bein_hametsarim » du 17 Tamouz au 9 Av,
     * le jeûne repoussé compris (YY 551:6 ; Michna Beroura 551:16) ; null sinon. Un rappel, jamais une
     * coupure : la joie d'une mitsva en excepte, et elle dépend de l'utilisateur.
     */
    fun periodeSansMusique(date: LocalDate): String? {
        val c = calendrier(date, false, false)
        return when {
            c.dayOfOmer > 0 && c.dayOfOmer != 33 -> "omer"
            (c.jewishMonth == JewishDate.TAMMUZ && c.jewishDayOfMonth >= 17) || (c.jewishMonth == JewishDate.AV && c.jewishDayOfMonth <= 9) ||
                c.yomTovIndex == JewishCalendar.TISHA_BEAV -> "bein_hametsarim"
            else -> null
        }
    }

    /** La veille d'un Yom tov dont les jours chômés mènent jusqu'à Chabbat (un vendredi de fête). */
    private fun erouvTavchilin(date: LocalDate, enIsrael: Boolean): Boolean {
        if (calendrier(date, enIsrael, false).isAssurBemelacha) return false
        var d = date.plusDays(1)
        while (calendrier(d, enIsrael, false).isYomTovAssurBemelacha) {
            if (d.dayOfWeek == DayOfWeek.FRIDAY) return true
            d = d.plusDays(1)
        }
        return false
    }

    /**
     * Le jour hébreu dont relève une prière dite à [heure] le jour civil
     * [date]. Arvit et le Chema du coucher se disent le soir, qui ouvre déjà
     * le jour hébreu suivant : l'après-midi, c'est le lendemain ; après
     * minuit, c'est encore le jour civil, que la nuit a ouvert la veille.
     * Midi sert de borne parce qu'aucun Arvit ne se dit le matin.
     * Les autres textes (bénédictions du repas, Havdala…) passent au jour
     * suivant à la sortie des étoiles du lieu, quand on le connaît
     * ([apresSortie]) : samedi soir, Birkat haMazon n'a plus רצה en évidence
     * (demande du 28/10) ; il reste ouvrable à la main pour qui a commencé
     * son repas pendant Chabbat. Min'ha garde le jour civil. Sans lieu, le
     * jour civil.
     */
    fun jourDeLaPriere(texte: String, date: LocalDate, heure: LocalTime, apresSortie: Boolean = false): LocalDate = when (texte) {
        // Le compte de l'omer se fait le soir, avec Arvit (26/11, Q12 : le compte du soir).
        "arvit", "chema_coucher", "sefirat_haomer" -> if (heure >= LocalTime.NOON) date.plusDays(1) else date
        // Tikoun 'hatsot avant minuit : la nuit du lendemain ; à midi (Bein hamétsarim), le jour même (audit du 16/11).
        "tikoun_hatsot" -> if (heure >= LocalTime.of(18, 0)) date.plusDays(1) else date
        "minha" -> date
        else -> if (apresSortie) date.plusDays(1) else date
    }

    /**
     * Le jour voisin du Birkat haMazon et de Méèn chaloch (26/11, Q6) : entre le coucher du soleil et la
     * sortie des étoiles, le jour qui commence ; après la sortie des étoiles et jusqu'à minuit, le jour qui
     * finit (« le soir qui suit ») ; sans lieu ([apresCoucher] et [apresSortie] null), de 16 h à minuit, le
     * jour qui commence. Ses ajouts (רצה, יעלה ויבוא, על הנסים…) restent repliés au lieu d'être retirés : un
     * repas commencé avant la sortie des étoiles se conclut avec eux. null hors de ces heures et des deux textes.
     */
    fun jourVoisin(texte: String, date: LocalDate, heure: LocalTime, apresCoucher: Boolean?, apresSortie: Boolean?): LocalDate? {
        if (texte != "birkat_hamazon" && texte != "meen_chaloch") return null
        return when {
            apresSortie == true -> date
            apresCoucher == true -> date.plusDays(1)
            apresCoucher == null && apresSortie == null && heure.hour >= 16 -> date.plusDays(1)
            else -> null
        }
    }

    /**
     * La nuit, pour la lecture (audit du 16/11 : שהחיינו de la Méguila chez les Edot, « אשר הניא » en Sfard et
     * en Ashkenaz) : après la sortie des étoiles ou avant l'aube du lieu ; sans lieu ([apresSortie],
     * [avantAube] null), de 19 h à 6 h.
     */
    fun nuit(heure: LocalTime, apresSortie: Boolean?, avantAube: Boolean?): Boolean =
        (apresSortie ?: (heure.hour >= 19)) || (avantAube ?: (heure.hour < 6))

    private fun calendrier(date: LocalDate, enIsrael: Boolean, modernes: Boolean) =
        JewishCalendar(date).apply {
            setInIsrael(enIsrael)
            isUseModernHolidays = modernes
        }
}
