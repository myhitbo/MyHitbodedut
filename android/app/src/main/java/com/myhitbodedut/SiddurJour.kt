package com.myhitbodedut

import org.json.JSONObject

/**
 * Ce que le jour change à la lecture du siddour (demande du 10/10) : les
 * ajouts du jour mis en évidence, les autres repliés derrière une flèche,
 * jamais retirés. Les annotations viennent de res/raw/siddur_annotations.json
 * (tools/siddur_annotations.py) ; les conditions, de CalendrierJuif.
 *
 * Pas d'Android ici : testable sur la machine virtuelle seule. Le même code
 * existe côté web (web/src/js/siddur-jour.js).
 */
object SiddurJour {

    /**
     * NOTE (audit du 16/11) : une note de l'application sous un bloc, quand sa condition vaut ;
     * jamais repliée, elle ne touche pas au texte du siddour (« ! » + une clé jamais du jour : toujours).
     */
    enum class Sorte { BLOC, SECTION, INDICE, RENVOI, SEUL, NOTE }

    data class Annotation(
        val sorte: Sorte,
        val section: Int,
        val bloc: Int?,
        /** Clé de CalendrierJuif.C ; « ! » devant : quand la clé est fausse. */
        val condition: String,
        /** Le début du texte annoté, pour vérifier qu'il n'a pas bougé. */
        val empreinte: String,
        /** Pour un indice : la variante à signaler (« המלך הקדוש »). */
        val texte: String? = null,
        /** Pour un bloc : son groupe, et la condition qui ouvre ou replie le groupe. */
        val groupe: Int? = null,
        val racine: String? = null,
        /** Un libellé propre (« ajout_anenou_officiant »), sinon celui de la condition. */
        val libelle: String? = null,
        /** Pour un renvoi : l'identifiant du texte à ouvrir (« hallel »). */
        val cible: String? = null,
        /** Pour une carte « seul » : la consigne qui précède son texte. */
        val consigne: String? = null,
        /** Pour un indice : le passage brut du bloc, replié hors du jour (« המלך הקדוש », 28/10). */
        val retire: String? = null,
        /**
         * Ce qui se dit presque tous les jours (12/11 : « שעשה לי כל צרכי », la fin du Kaddich après
         * le Hallel) : le jour dit, en clair sans étiquette ni mise en évidence ; les autres, replié.
         */
        val discret: Boolean = false,
        /**
         * La double annotation (audit du 16/11) : ce que ce bloc demande en plus de son groupe — « minyan »
         * (un Kaddich dans un ajout du jour), ou un jour (« !ticha_beav » : « תתקבל » d'un Kaddich). Faux, le
         * bloc se replie à part dans son groupe, sous [etLibelle] (sinon le libellé de la condition).
         */
        val et: String? = null,
        val etLibelle: String? = null,
    )

    /** Les annotations d'un nusah, par identifiant de texte. */
    fun parse(json: String, nusah: String): Map<String, List<Annotation>> {
        val racine = JSONObject(json).optJSONObject(nusah) ?: return emptyMap()
        return racine.keys().asSequence().associateWith { texte ->
            Json.array(racine.getJSONArray(texte)) { a ->
                Annotation(
                    sorte = when (a.getString("sorte")) {
                        "section" -> Sorte.SECTION
                        "indice" -> Sorte.INDICE
                        "renvoi" -> Sorte.RENVOI
                        "seul" -> Sorte.SEUL
                        "note" -> Sorte.NOTE
                        else -> Sorte.BLOC
                    },
                    section = a.getInt("s"),
                    bloc = if (a.has("b")) a.getInt("b") else null,
                    condition = a.getString("si"),
                    empreinte = a.getString("empreinte"),
                    texte = a.optString("texte", "").ifBlank { null },
                    groupe = if (a.has("g")) a.getInt("g") else null,
                    racine = a.optString("racine", "").ifBlank { null },
                    libelle = a.optString("libelle", "").ifBlank { null },
                    cible = a.optString("cible", "").ifBlank { null },
                    consigne = a.optString("consigne", "").ifBlank { null },
                    retire = a.optString("retire", "").ifBlank { null },
                    discret = a.optBoolean("discret", false),
                    et = a.optString("et", "").ifBlank { null },
                    etLibelle = a.optString("et_libelle", "").ifBlank { null },
                )
            }
        }
    }

    enum class Style { NORMAL, DU_JOUR, HORS }

    /**
     * Le libellé du texte ordinaire qu'une formule du jour remplace (audit du 12/11, TSIDDUR-06) :
     * « האל הקדוש » pendant les dix jours, « בונה ירושלים » à Min'ha du 9 Av. Sa condition est
     * niée (« !asseret_yemei_techouva ») : quand elle est vraie, c'est le texte de tous les
     * jours, affiché tel quel, sans étiquette ni surbrillance ; le jour où il est remplacé, il
     * se replie sous « Les autres jours ».
     */
    const val AUTRES_JOURS = "ajout_autres_jours"

    /** Une ligne de la lecture, le jour donné. */
    sealed class Ligne {
        data class Titre(val texte: String, val fr: String? = null, val en: String? = null) : Ligne()
        /**
         * [origine] : le paragraphe du texte, dont la place (section, paragraphe) sert aux marque-pages ;
         * [bloc] en est une copie quand une variante hors du jour en a été retirée (FLECTURE-08).
         */
        data class Bloc(val bloc: SiddurBloc, val style: Style, val origine: SiddurBloc = bloc) : Ligne()

        /** « Aujourd'hui · Ya'alé véyavo », au-dessus d'un ajout mis en évidence ; [libelle] : la clé de chaîne. */
        data class Etiquette(val condition: String, val libelle: String) : Ligne()

        /** « Aujourd'hui : המלך הקדוש », sous un bloc qui mêle une variante. */
        data class Indice(val texte: String) : Ligne()

        /** « Aujourd'hui · Hallel › » : le texte à dire ici ce jour-là, ouvert d'un geste ; [cible] : son identifiant. */
        data class Renvoi(val condition: String, val cible: String) : Ligne()

        /**
         * « Aujourd'hui · … » : ce que le jour change ici et que le siddour n'a pas, ou pas à cette place
         * (audit du 16/11 : le Moussaf de Chabbat Roch 'Hodech, celui de 'Hol hamoed, le demi-Kaddich avant
         * Moussaf) ; un renvoi sans texte cible, [libelle] : la clé de chaîne.
         */
        data class Rappel(val condition: String, val libelle: String) : Ligne()

        /** Qui prie seul (19/10) : la braïta à la place de Barekhou, ou où la dire ; [consigne] avant. */
        data class Seul(val texte: String, val consigne: String?, val note: Boolean = false) : Ligne()

        /** Un ajout hors du jour, replié ; [ouvert] quand on l'a déplié. */
        data class Replie(val cle: String, val condition: String, val ouvert: Boolean, val libelle: String) : Ligne()
    }

    /**
     * Les lignes d'un texte le jour où valent [conditions]. Un ajout du jour
     * est précédé de son étiquette ; un ajout hors du jour tient en une ligne
     * repliée, et ses blocs suivent si sa clé est dans [ouverts]. Dans un ajout
     * du jour, une variante d'un autre jour (« בחוה״מ פסח » un Roch 'Hodech)
     * reste lisible, estompée. Le texte ordinaire qu'une formule du jour
     * remplace ([AUTRES_JOURS]) reste tel quel, et se replie ce jour-là.
     */
    fun lignes(
        texte: SiddurTexte,
        annotations: List<Annotation>,
        conditionsDuJour: Set<String>,
        ouverts: Set<String> = emptySet(),
        nusah: String = "edot",
        enIsrael: Boolean = false,
        sansTahanounFinTichri: Boolean = nusah == "edot",
        sud: Boolean = false,
    ): List<Ligne> {
        val conditions = conditionsPour(nusah, enIsrael, conditionsDuJour, sansTahanounFinTichri, sud)
        fun nom(a: Annotation, condition: String) = libelleJour(a.libelle, condition, nusah, conditions)
        val sections = annotations.filter { it.sorte == Sorte.SECTION }.associateBy { it.section }
        val blocs = annotations.filter { it.sorte == Sorte.BLOC }.associateBy { it.section to it.bloc!! }
        val indices = annotations.filter { it.sorte == Sorte.INDICE }.groupBy { it.section to it.bloc!! }
        // Les renvois du jour seulement : hors du jour, rien (le texte renvoyé n'est pas d'ici).
        val renvois = annotations.filter { it.sorte == Sorte.RENVOI && (it.cible != null || it.libelle != null) && vrai(it.condition, conditions) }
            .groupBy { it.section to it.bloc }
        // Les notes de l'application (audit du 16/11) suivent leur bloc comme les cartes « seul ».
        val seuls = annotations.filter { (it.sorte == Sorte.SEUL || it.sorte == Sorte.NOTE) && it.texte != null && vrai(it.condition, conditions) }
            .groupBy { it.section to it.bloc }
        val sortie = mutableListOf<Ligne>()
        fun seul(si: Int, bi: Int) = seuls[si to bi].orEmpty().forEach { sortie += Ligne.Seul(it.texte!!, it.consigne, it.sorte == Sorte.NOTE) }
        fun renvoyer(si: Int, bi: Int?) = renvois[si to bi].orEmpty().forEach {
            sortie += if (it.cible != null) Ligne.Renvoi(it.condition, it.cible) else Ligne.Rappel(it.condition, it.libelle!!)
        }
        texte.sections.forEachIndexed { si, s ->
            // Une section seule porte déjà le nom du texte : pas de titre répété.
            if (texte.sections.size > 1 && s.titre.isNotBlank()) sortie += Ligne.Titre(s.titre, s.titreFr, s.titreEn)
            val section = sections[si]
            if (section != null) {
                if (vrai(section.condition, conditions)) {
                    sortie += Ligne.Etiquette(section.condition, nom(section, section.condition))
                    s.blocs.forEach { sortie += Ligne.Bloc(it, Style.DU_JOUR) }
                } else {
                    val cle = "§$si"
                    sortie += Ligne.Replie(cle, section.condition, cle in ouverts, nom(section, section.condition))
                    if (cle in ouverts) s.blocs.forEach { sortie += Ligne.Bloc(it, Style.HORS) }
                }
                renvoyer(si, null)
                return@forEachIndexed
            }
            var i = 0
            while (i < s.blocs.size) {
                val a = blocs[si to i]
                if (a == null) {
                    // Une variante enchâssée hors du jour (המלך הקדוש, מוריד הטל…) : retirée du
                    // bloc, et une ligne repliée la rend d'un geste (demande du 28/10).
                    val ind = indices[si to i].orEmpty()
                    val horsJour = ind.filter { it.retire != null && !vrai(it.condition, conditions) }
                    val cleVariante = "v$si:$i"
                    val ouverte = cleVariante in ouverts
                    var bloc = s.blocs[i]
                    // Sans variante hors du jour, le bloc reste lui-même (12/11) : une copie rognée de ses
                    // espaces n'était plus retrouvée par les marque-pages, qui le cherchent par identité.
                    if (!ouverte && horsJour.isNotEmpty()) {
                        val reduit = horsJour.fold(bloc.texte) { t, v -> t.replaceFirst(v.retire!!, "") }.trim()
                        if (reduit != bloc.texte) bloc = bloc.copy(texte = reduit)
                    }
                    sortie += Ligne.Bloc(bloc, Style.NORMAL, s.blocs[i])
                    // Le texte du jour se lit dans le bloc même ; l'ancien « Aujourd'hui : … » ne
                    // reste que pour les variantes qu'on ne sait pas replier.
                    // Une fois chacune : « מגדול » vaut le Chabbat comme Roch 'Hodech (12/11).
                    ind.filter { it.texte != null && it.retire == null && vrai(it.condition, conditions) }
                        .map { it.texte!! }.distinct().forEach { sortie += Ligne.Indice(it) }
                    if (horsJour.isNotEmpty() && (ouverte || bloc !== s.blocs[i])) {
                        val v = horsJour.first()
                        sortie += Ligne.Replie(cleVariante, v.condition, ouverte, nom(v, v.condition))
                    }
                    seul(si, i)
                    renvoyer(si, i)
                    i++
                    continue
                }
                val membres = mutableListOf<Pair<SiddurBloc, Annotation>>()
                while (i < s.blocs.size && blocs[si to i]?.groupe == a.groupe) {
                    membres += s.blocs[i] to blocs.getValue(si to i)
                    i++
                }
                val racine = a.racine ?: a.condition
                // Le texte ordinaire qu'une formule du jour remplace (TSIDDUR-06), ou un passage
                // « discret » (12/11) : le jour dit, tel quel, sans étiquette.
                // La double annotation (audit du 16/11) : dans le groupe, un bloc dont le « et » est faux (le
                // minyan, « תתקבל » le 9 Av) se replie à part, avec ses voisins de même « et » ; un groupe lu
                // garde aussi ses repères du jour (« Aujourd'hui : … »).
                fun membresLus(style: (Annotation) -> Style, reperes: Boolean) {
                    var k = 0
                    while (k < membres.size) {
                        val (b, m) = membres[k]
                        val et = m.et
                        if (et == null || vrai(et, conditions)) {
                            sortie += Ligne.Bloc(b, style(m))
                            if (reperes) indices[si to m.bloc!!].orEmpty()
                                .filter { it.texte != null && it.retire == null && vrai(it.condition, conditions) }
                                .map { it.texte!! }.distinct().forEach { sortie += Ligne.Indice(it) }
                            k++
                            continue
                        }
                        val suite = membres.drop(k).takeWhile { it.second.et == et }
                        val cle = "$si:${a.groupe}:${m.bloc}"
                        sortie += Ligne.Replie(cle, et, cle in ouverts, m.etLibelle ?: libelle(et))
                        if (cle in ouverts) suite.forEach { (sb, _) -> sortie += Ligne.Bloc(sb, Style.HORS) }
                        k += suite.size
                    }
                }
                if (vrai(racine, conditions) && (a.libelle == AUTRES_JOURS || a.discret)) {
                    membresLus({ Style.NORMAL }, true)
                } else if (vrai(racine, conditions)) {
                    sortie += Ligne.Etiquette(racine, nom(a, racine))
                    membresLus({ m -> if (vrai(m.condition, conditions)) Style.DU_JOUR else Style.HORS }, true)
                } else {
                    val cle = "$si:${a.groupe}"
                    sortie += Ligne.Replie(cle, racine, cle in ouverts, nom(a, racine))
                    // Ouvert, un groupe replié distingue ses membres comme le web (audit du 16/11 : dans les
                    // psaumes d'avant le Birkat, celui du jour se lit en clair, l'autre estompé).
                    if (cle in ouverts) membresLus({ m -> if (vrai(m.condition, conditions)) Style.NORMAL else Style.HORS }, false)
                }
                seul(si, i - 1)
            }
            renvoyer(si, null)
        }
        return sortie
    }

    /**
     * Les conditions du jour, ajustées au nusah (demande du 10/10, « attention
     * aux différences ») : les Ashkénazes ne disent pas Morid hatal hors
     * d'Israël (Rema, OC 114:3), quand le nusah Sfard et les Séfarades le
     * disent ; les Edot ne disent pas Ta'hanoun jusqu'à la fin de Tichri.
     * À valider (ZMANIM.md, « Différences de noussa'h »).
     */
    fun conditionsPour(
        nusah: String,
        enIsrael: Boolean,
        conditions: Set<String>,
        sansTahanounFinTichri: Boolean = nusah == "edot",
        sud: Boolean = false,
    ): Set<String> {
        var c = conditions
        if (CalendrierJuif.C.BASCULE_PLUIE in c) c = c + CalendrierJuif.C.MACHIV_HAROUAH + CalendrierJuif.C.MORID_HATAL
        if (nusah == "ashkenaz" && !enIsrael) c = c - CalendrierJuif.C.MORID_HATAL
        // Hémisphère sud, Edot (14/10) : « מוריד הטל » toute l'année, jamais « מוריד הגשם » ;
        // ותן טל ומטר suit la diaspora. Yalkut Yosef, Kitsour Choulhan Aroukh, O.H. 117:20 (סעיף כ)
        // (Chéérit Yossef III p. 105 ; Yalkut Yosef Tefila II, 117 note כ, p. קא ; audit du 16/11) ; recoupé
        // le 16/10 avec Halakha Yomit (site de Rav Ovadia Yossef) : pas de « משיב הרוח » là-bas.
        if (sud && nusah == "edot" && CalendrierJuif.C.MACHIV_HAROUAH in c) c = c - CalendrierJuif.C.MACHIV_HAROUAH + CalendrierJuif.C.MORID_HATAL
        // Pas de Ta'hanoun du lendemain de Kippour jusqu'au 2 'Hechvan : la
        // coutume des Edot, au choix en Sfard (Store.sansTahanounFinTichri) ;
        // TefilaRules le fait reprendre après Isrou 'hag.
        if (sansTahanounFinTichri && CalendrierJuif.C.FIN_TICHRI in c) {
            c = c - setOf(CalendrierJuif.C.TAHANOUN_CHAHARIT, CalendrierJuif.C.TAHANOUN_MINHA, CalendrierJuif.C.LUNDI_JEUDI)
        }
        // Pourim triple, le dimanche 16 Adar en Israël hors de Jérusalem (14/11) : l'Ashkenaz suit le
        // Halikhot Chlomo (22:8), sans Ta'hanoun ; למנצח reste (Michna Beroura 131:35). Le Michna Beroura
        // ne l'omet que « les deux jours de Pourim » (131:33, 693:8) : JourAffiche le précise.
        if (nusah == "ashkenaz" && CalendrierJuif.C.POURIM_TRIPLE_HORS_JERUSALEM in c) {
            c = c - setOf(CalendrierJuif.C.TAHANOUN_CHAHARIT, CalendrierJuif.C.TAHANOUN_MINHA, CalendrierJuif.C.LUNDI_JEUDI)
        }
        // Edot : pas de Vidouï à Min'ha du 13 Iyar, veille de Pessa'h chéni (Kitsour Yalkout Yossef 131:38 ; audit du
        // 16/11) ; KosherJava le fait dire (« Halakha Beroura », dont l'auteur s'est rétracté).
        if (nusah == "edot" && CalendrierJuif.C.VEILLE_PESSAH_CHENI in c) c = c - CalendrierJuif.C.TAHANOUN_MINHA
        // « Pas de Ta'hanoun aujourd'hui » (réglage ponctuel, audit du 16/11) : maison en deuil, brit mila, 'hatan
        // (Choul'han Aroukh O.H. 131:4). למנצח et Avinou malkénou restent (Rema 602:1 pour la mila).
        if (CalendrierJuif.C.SANS_TAHANOUN_PONCTUEL in c) {
            c = c - setOf(CalendrierJuif.C.TAHANOUN_CHAHARIT, CalendrierJuif.C.TAHANOUN_MINHA, CalendrierJuif.C.LUNDI_JEUDI)
        }
        if (avinouMalkenou(conditions)) c = c + CalendrierJuif.C.AVINOU_MALKENOU
        // À Min'ha, il ne se dit que si Ta'hanoun s'y dit : pas le 13 Adar (veille de Pourim), pas le
        // vendredi après-midi, pas à Min'ha de la veille de Kippour un vendredi (TSIDDUR-09). Roch Hachana
        // et Kippour, sans Ta'hanoun, gardent leur Avinou malkénou de Min'ha, sauf un vendredi (relecture du 15/11).
        val minha = CalendrierJuif.C.TAHANOUN_MINHA in conditions ||
            CalendrierJuif.C.ROCH_HACHANA in conditions || CalendrierJuif.C.KIPPOUR in conditions
        val vendredi = CalendrierJuif.C.JOURS_SEMAINE[5] in conditions || CalendrierJuif.C.EREV_KIPPOUR_VENDREDI in conditions
        if (avinouMalkenou(conditions) && minha && !vendredi) {
            c = c + CalendrierJuif.C.AVINOU_MALKENOU_MINHA
        }
        return c + ajoutsOffices(nusah, enIsrael, c)
    }

    /**
     * Audit du 16/11 (structure des offices) : ce qui dépend du noussa'h et de sa source.
     *  - ויהי נועם au motsaé Chabbat ([CalendrierJuif.C.VIHI_NOAM]) : pas le soir du 9 Av (Choul'han Aroukh
     *    O.H. 559:2 ; Kitsour Yalkut Yosef 556:3), ni un samedi soir qui est Yom tov ; en Sfard et en
     *    Ashkenaz, pas non plus quand un Yom tov ou 'Hol hamoed tombe dans la semaine (Rema O.H. 295:1 ;
     *    Michna Beroura 295:3 ; Choul'han Aroukh haRav 295:3) ; les Edot le disent (Kitsour Yalkut Yosef 294:7).
     *  - « ואתה קדוש » ([CalendrierJuif.C.VEATA_KADOCH]) : les mêmes soirs, et le soir du 9 Av après Ekha
     *    (Choul'han Aroukh O.H. 559:2).
     *  - Les téfilin ([CalendrierJuif.C.TEFILIN]) : pas le Chabbat ni le Yom tov ; pas à 'Hol hamoed chez les
     *    Edot (Kitsour Yalkut Yosef 31:6) ni en Israël (Choul'han Aroukh O.H. 31:2) ; pas le matin du 9 Av en
     *    Ashkenaz et en Sfard (Choul'han Aroukh O.H. 555:1). À 'Hol hamoed en diaspora, l'Ashkenaz les met
     *    sans bénédiction (Michna Beroura 31:8 : [CalendrierJuif.C.TEFILIN_SANS_BERAKHA]).
     *  - Le Vidouï du Chema du coucher ([CalendrierJuif.C.VIDUI_COUCHER]) : les nuits dont le jour a Ta'hanoun,
     *    hors motsaé Chabbat ou Yom tov et lendemain de Roch 'Hodech (consigne du siddour Edot ; Kitsour Yalkut
     *    Yosef, ק״ש שעל המטה בליל שבת §ב). Le motsaé Chabbat, il se dit après 'hatsot : l'app ne le sait pas.
     *  - « לדוד ה׳ אורי » ([CalendrierJuif.C.LEDAVID]) : en Ashkenaz hors d'Israël, jusqu'à Chemini Atséret
     *    inclus (Michna Beroura 581:2, « עד שמע״צ ועד בכלל »).
     */
    private fun ajoutsOffices(nusah: String, enIsrael: Boolean, c: Set<String>): Set<String> = buildSet {
        val k = CalendrierJuif.C
        val edot = nusah == "edot"
        val vihiNoam = k.MOTSAE_CHABBAT in c && k.TICHA_BEAV !in c && k.CHOME !in c && (edot || k.YOM_TOV_SEMAINE !in c)
        if (vihiNoam) add(k.VIHI_NOAM)
        if (vihiNoam || k.TICHA_BEAV in c) add(k.VEATA_KADOCH)
        val sansTefilin = k.CHABBAT in c || k.YOM_TOV in c || (k.HOL_HAMOED in c && (edot || enIsrael)) ||
            (k.TICHA_BEAV in c && !edot)
        if (!sansTefilin) add(k.TEFILIN)
        if (nusah == "ashkenaz" && !enIsrael && k.HOL_HAMOED in c) add(k.TEFILIN_SANS_BERAKHA)
        if (k.TAHANOUN_CHAHARIT in c && k.MOTSAE_CHABBAT_YT !in c && k.LENDEMAIN_ROCH_HODECH !in c) add(k.VIDUI_COUCHER)
        if (nusah == "ashkenaz" && !enIsrael && k.CHEMINI_ATSERET in c && k.BASCULE_PLUIE in c) add(k.LEDAVID)
    }

    /**
     * Avinou malkénou (Ashkenaz, Sfard ; 14/10) : les jeûnes publics sauf le 9 Av
     * et les dix jours de pénitence, Roch
     * Hachana et Kippour compris, jamais le Chabbat. Déduit, non vérifié ligne à
     * ligne : la veille de Kippour, sans Ta'hanoun, en est exclue ; à Min'ha, voir AVINOU_MALKENOU_MINHA.
     */
    fun avinouMalkenou(conditions: Set<String>): Boolean {
        val c = CalendrierJuif.C
        if (c.CHABBAT in conditions) return false
        if (c.EREV_KIPPOUR_VENDREDI in conditions) return true
        if (c.JEUNE in conditions && c.TICHA_BEAV !in conditions) return true
        return c.ASSERET_YEMEI_TECHOUVA in conditions &&
            (c.TAHANOUN_CHAHARIT in conditions || c.ROCH_HACHANA in conditions || c.KIPPOUR in conditions)
    }

    /**
     * Le libellé d'un ajout, un jour donné : celui de l'annotation s'il en a un ;
     * pour l'annonce du Hallel, complet ou partiel, et la bénédiction du
     * Hallel partiel selon le nusah (Choul'han Aroukh et Rema, OC 422:2).
     */
    fun libelleJour(libelleAnnotation: String?, condition: String, nusah: String, conditions: Set<String>): String = when {
        libelleAnnotation != null -> libelleAnnotation
        condition == CalendrierJuif.C.HALLEL -> libelleHallel(nusah, conditions) ?: libelle(condition)
        // Les Edot changent toute la 9ᵉ bénédiction, pas une formule (demande du 28/10) : ברך עלינו / ברכנו.
        nusah == "edot" && condition.removePrefix("!") == CalendrierJuif.C.TAL_OUMATAR ->
            if (condition.startsWith("!")) "ajout_barkhenou" else "ajout_barekh_alenou"
        nusah == "edot" && condition == "berakha" -> "ajout_barkhenou"
        else -> libelle(condition)
    }

    /** Hallel complet, ou partiel avec ou sans bénédiction selon le nusah ; null hors Hallel. */
    fun libelleHallel(nusah: String, conditions: Set<String>): String? = when {
        CalendrierJuif.C.HALLEL_COMPLET in conditions -> "ajout_hallel_complet"
        CalendrierJuif.C.HALLEL !in conditions -> null
        nusah == "edot" -> "ajout_hallel_partiel_sans_berakha"
        else -> "ajout_hallel_partiel_avec_berakha"
    }

    /** [conditions], avec le réglage ponctuel « Pas de Ta'hanoun aujourd'hui » quand [sansTahanoun] (audit du 16/11). */
    fun avecSansTahanoun(conditions: Set<String>, sansTahanoun: Boolean): Set<String> =
        if (sansTahanoun) conditions + CalendrierJuif.C.SANS_TAHANOUN_PONCTUEL else conditions

    fun vrai(condition: String, conditions: Set<String>): Boolean =
        if (condition.startsWith("!")) condition.drop(1) !in conditions else condition in conditions

    /** Le nom de la chaîne qui nomme une condition, dans les trois langues. */
    fun libelle(condition: String): String {
        val c = condition.removePrefix("!")
        return when {
            condition.startsWith("!tahanoun") -> "ajout_sans_tahanoun"
            c.startsWith("tahanoun") -> "ajout_tahanoun"
            c == "kippour" -> "fete_yom_kippour"
            c == "avinou_malkenou_minha" -> "ajout_avinou_malkenou"
            // Audit du 16/11 : des variantes, nommées comme ce qu'elles sont.
            c == CalendrierJuif.C.AVINOU_MALKENOU_JEUNE -> "ajout_jeune_public"
            c == CalendrierJuif.C.KADDICH_COMPLET_HALLEL -> "ajout_sauf_hanouka"
            c == CalendrierJuif.C.EL_EREKH_APAYIM -> "ajout_lundi_jeudi"
            // « אומרים כאן הלל » : le Hallel, complet ou non selon le jour.
            c == "hallel" -> "ajout_hallel_annonce"
            c.startsWith("embolismique") -> "ajout_embolismique"
            c in setOf("pessah", "soukkot", "chavouot", "roch_hachana", "chemini_atseret", "hanouka", "pourim") -> "fete_$c"
            else -> "ajout_$c"
        }
    }

    /** Comme tools/siddur_annotations.py : sans balises ni voyelles, quarante caractères. */
    fun empreinte(texte: String): String =
        texte.replace(Regex("<[^>]+>"), " ")
            .replace(Regex("[\\u0591-\\u05C7]"), "")
            // (?U) : les espaces Unicode (fine U+2009 du siddour Edot) comptent, comme \s de Python et de JS.
            .replace(Regex("(?U)\\s+"), " ")
            .trim()
            .take(40)
}
