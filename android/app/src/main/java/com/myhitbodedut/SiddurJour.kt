package com.myhitbodedut

import org.json.JSONObject

/**
 * Ce que le jour change à la lecture du siddour (demande du 10/10) : les
 * ajouts du jour mis en évidence. Depuis le 26/11 (« les ajouts dépendant des
 * zmanim… enlevés complètement hormis lorsque nécessaire ; ceux d'une occasion,
 * repliés mais visibles »), deux catégories :
 *  - un ajout du calendrier, que l'application calcule (Chabbat, Roch 'Hodech,
 *    'Hanouka, Barekh alénou, Ta'hanoun…), ne s'affiche que le jour où il se dit ;
 *    les autres jours, il est retiré, sans bandeau replié ;
 *  - un ajout d'occasion, que l'application ne peut pas connaître (minyan, brit,
 *    invité, maison endeuillée, oubli…), reste replié, et se déplie d'un toucher.
 * Quelques exceptions, voulues par le propriétaire, restent repliées au lieu d'être
 * retirées : le soir, au Birkat haMazon, les ajouts du jour voisin (Q6) ; le Ledavid
 * des Edot hors d'Eloul (Q10) ; l'Anénou du particulier hors des jeûnes publics (Q2).
 * Les annotations viennent de res/raw/siddur_annotations.json
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
    /** LECTURE (26/11) : la place de la lecture de la Torah du jour, après le bloc (LectureTorah). */
    enum class Sorte { BLOC, SECTION, INDICE, RENVOI, SEUL, NOTE, LECTURE }

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
        /** Une indication fixe du siddour (audit du 16/11) : affichée telle quelle, sans « Aujourd'hui : ». */
        val fixe: Boolean = false,
        /**
         * La garde d'un ajout d'occasion (26/11) : fausse, il est retiré ; vraie, il reste replié. Les consignes
         * d'oubli (Q5 : « מוריד הגשם » l'hiver seulement), les usages datés (Q14), le voyageur (Q3).
         */
        val quand: String? = null,
        /** Un ajout du calendrier gardé replié hors de son jour au lieu d'être retiré (Q2, Q10, l'omer), sous [libelleHors]. */
        val replieHors: Boolean = false,
        val libelleHors: String? = null,
        /** Pour une variante enchâssée : ce qui remplace [retire] le jour où elle est fausse (« מגדול », « מוֹדָה »). */
        val par: String? = null,
        /** Pour la place d'une lecture (26/11) : son office, « chaharit » ou « minha ». */
        val office: String? = null,
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
                        "lecture" -> Sorte.LECTURE
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
                    fixe = a.optBoolean("fixe", false),
                    quand = a.optString("quand", "").ifBlank { null },
                    replieHors = a.optBoolean("replie_hors", false),
                    libelleHors = a.optString("libelle_hors", "").ifBlank { null },
                    par = if (a.has("par")) a.getString("par") else null,
                    office = a.optString("office", "").ifBlank { null },
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

    /**
     * Les conditions d'occasion (26/11), jamais vraies : ce qu'elles portent reste replié, dépliable. Les mêmes
     * que tools/siddur_annotations.py (OCCASIONS) et siddur-jour.js.
     */
    val OCCASIONS = setOf("minyan", "sans_minyan", "beit_avel", "oubli", "cheva_berakhot", "zimun", "facultatif", "usage", "occasion")

    /** Qui prie seul (Q4) : les cartes « seul » et « יחיד אומר », sous « Sans minyan ». */
    const val SANS_MINYAN = "sans_minyan"

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
        data class Indice(val texte: String, val fixe: Boolean = false) : Ligne()

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

        /**
         * Un ajout replié ; [ouvert] quand on l'a déplié. [pasAujourdhui] : un ajout du calendrier gardé replié
         * hors de son jour (« Pas aujourd'hui · toucher pour lire ») ; sinon une occasion (« Toucher pour lire »).
         */
        data class Replie(val cle: String, val condition: String, val ouvert: Boolean, val libelle: String,
                          val pasAujourdhui: Boolean = false) : Ligne()

        /**
         * La fin d'un repli déplié ([cle] : celle de son [Replie]), après tout ce qu'il contient, replis
         * imbriqués compris (une double annotation dans un groupe ouvert) : l'écran y met « Replier ».
         */
        data class Fin(val cle: String) : Ligne()

        /**
         * La lecture de la Torah du jour (26/11), repliée sous « Lecture : Vayétsé, 3 montées » ; [haftara] : le
         * bandeau de sa haftara, replié de même. Ouverte, ses passages suivent ([Passage]), puis la [Fin].
         */
        data class Lecture(val cle: String, val lecture: LectureTorah.Lecture, val ouvert: Boolean, val haftara: Boolean = false) : Ligne()

        /** Un passage d'une lecture ouverte : une montée ([montee], son libellé) ou un morceau de haftara (null). */
        data class Passage(val montee: LectureTorah.Montee?, val passage: LectureTorah.Passage) : Ligne()
    }

    /**
     * Les lignes de [lectures] (26/11) : pour chacune, son bandeau replié (clé « [prefixe]:k ») et, ouverte, ses
     * montées ; puis, si elle en a une, sa haftara repliée à part (« [prefixe]:k:h »). Dans la lecture de
     * Cha'harit, de Min'ha d'un jeûne, et dans le texte « Lecture de la Torah ».
     */
    fun lignesLecture(lectures: List<LectureTorah.Lecture>, prefixe: String, ouverts: Set<String>): List<Ligne> = buildList {
        lectures.forEachIndexed { k, l ->
            val cle = "$prefixe:$k"
            add(Ligne.Lecture(cle, l, cle in ouverts))
            if (cle in ouverts) {
                l.montees.forEach { m -> add(Ligne.Passage(m, LectureTorah.Passage(m.livre, m.debut, m.fin))) }
                add(Ligne.Fin(cle))
            }
            if (l.haftara.isNotEmpty()) {
                val h = "$cle:h"
                add(Ligne.Lecture(h, l, h in ouverts, haftara = true))
                if (h in ouverts) {
                    l.haftara.forEach { add(Ligne.Passage(null, it)) }
                    add(Ligne.Fin(h))
                }
            }
        }
    }

    /** L'état d'un ajout ce jour-là (26/11) : mis en évidence, tel quel, replié, ou retiré. */
    enum class Etat { DU_JOUR, ORDINAIRE, REPLIE, RETIRE }

    /** [etat], et pour un repli : « pas aujourd'hui » (un ajout du calendrier) ou une occasion, son libellé, tous ses membres. */
    data class Decision(val etat: Etat, val pasAujourdhui: Boolean = false, val libelle: String? = null, val tous: Boolean = false)

    /**
     * Ce qu'on fait d'un ajout ([a], la condition [racine] de son groupe) le jour où valent [conditions] ; [voisin] :
     * les conditions du jour voisin au Birkat haMazon le soir (Q6), vide sinon.
     *  - sa garde ([Annotation.quand]) fausse, ce jour et au voisin : retiré ;
     *  - une occasion : replié ;
     *  - du jour : mis en évidence, ou tel quel (texte ordinaire, passage « discret ») ;
     *  - du jour voisin : replié, « pas aujourd'hui » ;
     *  - [Annotation.replieHors] : replié, tous ses membres dépliables ;
     *  - sinon : retiré.
     */
    fun decision(a: Annotation, racine: String, conditions: Set<String>, voisin: Set<String> = emptySet()): Decision {
        fun voisinVrai(c: String) = voisin.isNotEmpty() && vrai(c, voisin)
        val q = a.quand
        if (q != null && !vrai(q, conditions) && !voisinVrai(q)) return Decision(Etat.RETIRE)
        if (racine in OCCASIONS) return Decision(Etat.REPLIE)
        if (vrai(racine, conditions)) return Decision(if (a.libelle == AUTRES_JOURS || a.discret) Etat.ORDINAIRE else Etat.DU_JOUR)
        if (voisinVrai(racine)) return Decision(Etat.REPLIE, pasAujourdhui = true)
        if (a.replieHors) return Decision(Etat.REPLIE, pasAujourdhui = a.libelleHors == null, libelle = a.libelleHors, tous = true)
        return Decision(Etat.RETIRE)
    }

    /**
     * Le texte d'un bloc ce jour-là (26/11, Q8) : chaque variante enchâssée fausse ([Annotation.retire]) en est
     * retirée, ou remplacée ([Annotation.par]) ; celle d'un jour voisin (Q6) reste. Sans changement, le bloc
     * lui-même (les marque-pages le cherchent par identité).
     */
    fun texteDuJour(bloc: SiddurBloc, indices: List<Annotation>, conditions: Set<String>, voisin: Set<String> = emptySet()): SiddurBloc {
        val faux = indices.filter { it.retire != null && !vrai(it.condition, conditions) && !(voisin.isNotEmpty() && vrai(it.condition, voisin)) }
        if (faux.isEmpty()) return bloc
        val reduit = faux.fold(bloc.texte) { t, v -> t.replaceFirst(v.retire!!, v.par ?: "") }.trim()
        return if (reduit != bloc.texte) bloc.copy(texte = reduit) else bloc
    }

    /**
     * Les lignes d'un texte le jour où valent [conditionsDuJour] (règle du 26/11, voir l'en-tête) : un ajout du
     * jour est précédé de son étiquette, et seules ses lignes du jour s'y lisent (« seule la bonne formule ») ;
     * un ajout du calendrier hors de son jour est retiré ; une occasion tient en une ligne repliée, et ses blocs
     * (ceux qui valent ce jour-là, Q11) suivent si sa clé est dans [ouverts]. [voisin] : les conditions du jour
     * voisin (CalendrierJuif.jourVoisin), dont les ajouts restent repliés au lieu d'être retirés (Q6).
     * Une section dont tout est retiré perd aussi son titre.
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
        voisin: Set<String> = emptySet(),
        lectures: List<LectureTorah.Lecture> = emptyList(),
    ): List<Ligne> {
        val conditions = conditionsPour(nusah, enIsrael, conditionsDuJour, sansTahanounFinTichri, sud)
        val autre = if (voisin.isEmpty()) emptySet() else conditionsPour(nusah, enIsrael, voisin, sansTahanounFinTichri, sud)
        fun voisinVrai(c: String) = autre.isNotEmpty() && vrai(c, autre)
        fun nom(a: Annotation, condition: String) = libelleJour(a.libelle, condition, nusah, conditions)
        val sections = annotations.filter { it.sorte == Sorte.SECTION }.associateBy { it.section }
        val blocs = annotations.filter { it.sorte == Sorte.BLOC }.associateBy { it.section to it.bloc!! }
        val indices = annotations.filter { it.sorte == Sorte.INDICE }.groupBy { it.section to it.bloc!! }
        // Les renvois du jour seulement : hors du jour, rien (le texte renvoyé n'est pas d'ici).
        val renvois = annotations.filter { it.sorte == Sorte.RENVOI && (it.cible != null || it.libelle != null) && vrai(it.condition, conditions) }
            .groupBy { it.section to it.bloc }
        // Les notes de l'application (audit du 16/11) suivent leur bloc ; les cartes « seul », repliées (Q4).
        val seuls = annotations.filter { it.texte != null && (it.sorte == Sorte.SEUL || (it.sorte == Sorte.NOTE && vrai(it.condition, conditions))) }
            .groupBy { it.section to it.bloc }
        // La place de la lecture du jour (26/11) : après son bloc, le jour où elle vaut, si l'office a une lecture.
        val places = annotations.filter { it.sorte == Sorte.LECTURE }.associateBy { it.section to it.bloc!! }
        val sortie = mutableListOf<Ligne>()
        fun lire(si: Int, bi: Int) = places[si to bi]?.takeIf { lectures.isNotEmpty() && vrai(it.condition, conditions) }
            ?.let { sortie += lignesLecture(lectures, "lecture:${it.office ?: "office"}", ouverts) }
        fun du(si: Int, bi: Int, b: SiddurBloc) = texteDuJour(b, indices[si to bi].orEmpty(), conditions, autre)
        fun reperes(si: Int, bi: Int) = indices[si to bi].orEmpty()
            .filter { it.texte != null && it.retire == null && vrai(it.condition, conditions) }
            .distinctBy { it.texte }.forEach { sortie += Ligne.Indice(it.texte!!, it.fixe) }
        fun seul(si: Int, bi: Int) = seuls[si to bi].orEmpty().forEachIndexed { k, it ->
            if (it.sorte == Sorte.NOTE) {
                sortie += Ligne.Seul(it.texte!!, it.consigne, true)
                return@forEachIndexed
            }
            // Qui prie seul (26/11, Q4) : la braïta, repliée sous « Sans minyan ».
            val cle = "seul:$si:$bi:$k"
            sortie += Ligne.Replie(cle, SANS_MINYAN, cle in ouverts, "ajout_sans_minyan")
            if (cle in ouverts) {
                sortie += Ligne.Seul(it.texte!!, it.consigne)
                sortie += Ligne.Fin(cle)
            }
        }
        fun renvoyer(si: Int, bi: Int?) = renvois[si to bi].orEmpty().forEach {
            sortie += if (it.cible != null) Ligne.Renvoi(it.condition, it.cible) else Ligne.Rappel(it.condition, it.libelle!!)
        }
        texte.sections.forEachIndexed { si, s ->
            // Une section seule porte déjà le nom du texte : pas de titre répété ; une section vide ce jour-là non plus.
            val debut = sortie.size
            val titre = s.titre.isNotBlank() && texte.sections.size > 1
            if (titre) sortie += Ligne.Titre(s.titre, s.titreFr, s.titreEn)
            val section = sections[si]
            if (section != null) {
                val d = decision(section, section.condition, conditions, autre)
                when (d.etat) {
                    Etat.DU_JOUR -> {
                        sortie += Ligne.Etiquette(section.condition, nom(section, section.condition))
                        s.blocs.forEachIndexed { bi, b -> sortie += Ligne.Bloc(du(si, bi, b), Style.DU_JOUR, b); lire(si, bi) }
                    }
                    Etat.ORDINAIRE -> s.blocs.forEachIndexed { bi, b -> sortie += Ligne.Bloc(du(si, bi, b), Style.NORMAL, b); lire(si, bi) }
                    Etat.REPLIE -> {
                        val cle = "§$si"
                        sortie += Ligne.Replie(cle, section.condition, cle in ouverts, d.libelle ?: nom(section, section.condition), d.pasAujourdhui)
                        if (cle in ouverts) {
                            s.blocs.forEachIndexed { bi, b -> sortie += Ligne.Bloc(du(si, bi, b), Style.HORS, b) }
                            sortie += Ligne.Fin(cle)
                        }
                    }
                    Etat.RETIRE -> Unit
                }
                renvoyer(si, null)
                if (titre && sortie.size == debut + 1) sortie.removeAt(debut)
                return@forEachIndexed
            }
            var i = 0
            while (i < s.blocs.size) {
                val a = blocs[si to i]
                if (a == null) {
                    // Une variante enchâssée hors du jour (המלך הקדוש, מוריד הטל…) : retirée du bloc, sans repli (Q8).
                    sortie += Ligne.Bloc(du(si, i, s.blocs[i]), Style.NORMAL, s.blocs[i])
                    // Le texte du jour se lit dans le bloc même ; « Aujourd'hui : … » ne reste que pour les variantes
                    // qu'on ne sait pas retirer. Une fois chacune : « מגדול » vaut le Chabbat comme Roch 'Hodech (12/11).
                    reperes(si, i)
                    lire(si, i)
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
                val d = decision(a, racine, conditions, autre)
                // Les membres qui se lisent ce jour-là (Q8, Q11) : ceux de la racine, et les variantes vraies (ou du
                // jour voisin) ; replié hors du jour (Q2, Q10), tous.
                val lus = membres.filter { (_, m) -> d.tous || m.condition == racine || vrai(m.condition, conditions) || voisinVrai(m.condition) }
                // La double annotation (audit du 16/11) : dans le groupe, un bloc dont le « et » est faux se replie à part
                // si c'est une occasion (le minyan, un Mi chébérakh) ou le jour voisin ; il est retiré sinon (« תתקבל » le
                // 9 Av). Un groupe lu garde ses repères du jour (« Aujourd'hui : … »).
                fun membresLus(style: Style, avecReperes: Boolean) {
                    var k = 0
                    while (k < lus.size) {
                        val (b, m) = lus[k]
                        val et = m.et
                        if (et == null || vrai(et, conditions)) {
                            sortie += Ligne.Bloc(du(si, m.bloc!!, b), style, b)
                            if (avecReperes) {
                                reperes(si, m.bloc)
                                lire(si, m.bloc)
                            }
                            k++
                            continue
                        }
                        val suite = lus.drop(k).takeWhile { it.second.et == et && it.second.etLibelle == m.etLibelle }
                        if (et in OCCASIONS || voisinVrai(et)) {
                            val cle = "$si:${a.groupe}:${m.bloc}"
                            sortie += Ligne.Replie(cle, et, cle in ouverts, m.etLibelle ?: libelle(et), et !in OCCASIONS)
                            if (cle in ouverts) {
                                suite.forEach { (sb, sm) -> sortie += Ligne.Bloc(du(si, sm.bloc!!, sb), Style.HORS, sb) }
                                sortie += Ligne.Fin(cle)
                            }
                        }
                        k += suite.size
                    }
                }
                when (d.etat) {
                    Etat.ORDINAIRE -> membresLus(Style.NORMAL, true)
                    Etat.DU_JOUR -> {
                        sortie += Ligne.Etiquette(racine, nom(a, racine))
                        membresLus(Style.DU_JOUR, true)
                    }
                    Etat.REPLIE -> if (lus.isNotEmpty()) {
                        val cle = "$si:${a.groupe}"
                        sortie += Ligne.Replie(cle, racine, cle in ouverts, d.libelle ?: nom(a, racine), d.pasAujourdhui)
                        if (cle in ouverts) {
                            membresLus(if (d.pasAujourdhui) Style.HORS else Style.NORMAL, false)
                            sortie += Ligne.Fin(cle)
                        }
                    }
                    Etat.RETIRE -> Unit
                }
                seul(si, i - 1)
            }
            renvoyer(si, null)
            if (titre && sortie.size == debut + 1) sortie.removeAt(debut)
        }
        return sortie
    }

    /**
     * Le texte dépend-il aujourd'hui du statut Israël ou diaspora (26/11, Q7) ? Ses lignes, calculées pour les
     * deux, diffèrent : deuxième jour de fête, Isrou 'hag, début de « ותן טל ומטר », מוריד הטל ashkénaze…
     * [israel], [diaspora] : les conditions du jour pour chacun (CalendrierJuif.jour).
     */
    fun dependDeLaRegion(
        texte: SiddurTexte, annotations: List<Annotation>, israel: Set<String>, diaspora: Set<String>,
        nusah: String, sansTahanounFinTichri: Boolean = nusah == "edot", sud: Boolean = false,
        voisinIsrael: Set<String> = emptySet(), voisinDiaspora: Set<String> = emptySet(),
        lecturesIsrael: List<LectureTorah.Lecture> = emptyList(), lecturesDiaspora: List<LectureTorah.Lecture> = emptyList(),
    ): Boolean = lignes(texte, annotations, israel, emptySet(), nusah, true, sansTahanounFinTichri, sud, voisinIsrael, lecturesIsrael) !=
        lignes(texte, annotations, diaspora, emptySet(), nusah, false, sansTahanounFinTichri, sud, voisinDiaspora, lecturesDiaspora)

    /**
     * Les places de [lignes] qui se lisent dans le panneau d'un repli déplié : entre un [Ligne.Replie]
     * ouvert et sa [Ligne.Fin], replis imbriqués compris (le pied d'un groupe ouvert vient après tous
     * ses membres, même quand un repli du minyan s'ouvre dedans). Ni le Replie ni la Fin n'y sont.
     */
    fun panneaux(lignes: List<Any?>): Set<Int> {
        val dedans = HashSet<Int>()
        val ouverts = ArrayDeque<String>()
        lignes.forEachIndexed { k, l ->
            if (l is Ligne.Fin) {
                ouverts.remove(l.cle)
                return@forEachIndexed
            }
            if (ouverts.isNotEmpty()) dedans += k
            if (l is Ligne.Replie && l.ouvert) ouverts.addLast(l.cle)
            if (l is Ligne.Lecture && l.ouvert) ouverts.addLast(l.cle)
        }
        return dedans
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
        // Le Ta'hanoun du calendrier et des coutumes, avant le réglage ponctuel (26/11, Q1) : ce que le siddour ne dit
        // pas sans Ta'hanoun (למנצח Edot, תפלה לדוד, « רבונו של עולם » Sfard) reste quand on choisit de l'omettre.
        if (CalendrierJuif.C.TAHANOUN_CHAHARIT in c) c = c + CalendrierJuif.C.TAHANOUN_CHAHARIT_CALENDRIER
        if (CalendrierJuif.C.TAHANOUN_MINHA in c) c = c + CalendrierJuif.C.TAHANOUN_MINHA_CALENDRIER
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
        // 26/11 : en Israël (le psaume 121 d'Arvit Sfard, « בא״י קדישא ») ; « מגדול » à la fin du Birkat (Q8) :
        // Edot, les jours de Moussaf, la nuit du motsaé Chabbat et Pourim (la consigne de leur siddour ; la brit mila,
        // occasion, garde la consigne) ; Sfard et Ashkenaz, Chabbat, Yom tov et Roch 'Hodech (Michna Beroura 189:5).
        val k = CalendrierJuif.C
        if (enIsrael) c = c + k.ISRAEL
        val magdol = if (nusah == "edot") listOf(k.CHABBAT, k.ROCH_HODECH, k.MOED, k.YOM_TOV, k.POURIM).any { it in c } ||
            (k.MOTSAE_CHABBAT in c && k.NUIT in c)
        else listOf(k.CHABBAT, k.YOM_TOV, k.ROCH_HODECH).any { it in c }
        if (magdol) c = c + k.MAGDOL
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

    /** [conditions], avec le réglage צדיק / צדקת ([adresse] : « m », « f » ou null ; 26/11, Q12). */
    fun avecAdresse(conditions: Set<String>, adresse: String?): Set<String> = when (adresse) {
        "m" -> conditions + CalendrierJuif.C.HOMME
        "f" -> conditions + CalendrierJuif.C.FEMME
        else -> conditions
    }

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
            // Le compte d'un soir de l'omer (26/11) : « Compte de l'omer ».
            c.startsWith("omer_") -> "ajout_omer"
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
