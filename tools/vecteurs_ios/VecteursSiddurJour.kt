// SiddurJour.kt devant la JVM, pour SiddurJour.swift (tâche 11) :
// - parse sur le vrai fichier d'annotations (par noussa'h et par texte : le compte par sorte et une
//   empreinte de chaque champ), puis sur des fichiers écrits à la main (tolérances et fautes d'org.json) ;
// - lignes() de chaque texte des trois siddourim, une trentaine de jours choisis, replis fermés, tous
//   ouverts, ou un sur deux : le compte par genre et une empreinte de la suite des lignes ; puis sur un
//   texte et des annotations écrits à la main, pour les branches que les siddourim n'atteignent pas ;
// - vrai, libelle et libelleJour sur toutes les conditions, empreinte sur des textes écrits pour
//   l'occasion et sur chaque titre et chaque bloc des siddourim ;
// - SiddurMoment (Siddur.kt) : megila autour de Pourim, ilanot au nord et au sud, illustration.
// Les deux catégories du 26/11 (calendrier retiré hors du jour, occasion repliée) : le jour voisin du Birkat haMazon,
// la lecture de la Torah à sa place (LectureTorah, sur le vrai fichier de lectures), צדיק / צדקת, « Pas de Ta'hanoun
// aujourd'hui », la nuit ; decision et texteDuJour sur un texte écrit ; dependDeLaRegion sur les vrais textes.
//
// L'empreinte d'un texte est son hashCode de Java (Kotlin.hashCode en Swift), « ∅ » pour null.

import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.LectureTorah
import com.myhitbodedut.Nusah
import com.myhitbodedut.Siddur
import com.myhitbodedut.SiddurJour
import com.myhitbodedut.SiddurLoader
import com.myhitbodedut.SiddurMoment
import com.myhitbodedut.SiddurTexte
import java.io.File
import java.time.LocalDate

object VecteursSiddurJour : Generateur {
    override val fichier = "siddur_jour.json"

    private const val RIEN = "∅"

    private val json = File(RES, "raw/siddur_annotations.json").readText()
    private val lectures = LectureTorah.parse(File(RES, "raw/lecture_torah.json").readText())
    private val siddourim: List<Pair<Nusah, Siddur>> =
        Nusah.entries.map { it to SiddurLoader.parse(File(RES, "raw/siddur_${it.cle}.json").readText()) }

    /** L'empreinte d'un texte : son hashCode, « ∅ » pour null. */
    private fun h(s: String?): String = s?.hashCode()?.toString() ?: RIEN

    /** Des points de code écrits par leur numéro : les blancs et les marques invisibles se lisent ainsi dans le source. */
    private fun u(vararg points: Int): String = buildString { points.forEach { appendCodePoint(it) } }

    /** Un point de code échappé comme en JSON (barre oblique inverse, « u », quatre chiffres) : org.json le relit. */
    private fun e(point: Int): String = "\\u" + point.toString(16).padStart(4, '0')

    /** Un jour de lecture : la date, le lieu, et la coutume de la fin de Tichri (null : celle du noussa'h). */
    private data class Cas(
        val nom: String,
        val date: String,
        val israel: Boolean,
        val muree: Boolean = false,
        val sud: Boolean = false,
        val finTichri: Boolean? = null,
        val alternes: Boolean = false,
        /** Le jour voisin du Birkat haMazon et de Méèn chaloch (26/11, Q6), sinon null. */
        val voisin: String? = null,
        /** Le réglage צדיק / צדקת (« m », « f »), « Pas de Ta'hanoun aujourd'hui », la nuit (26/11). */
        val adresse: String? = null,
        val sansTahanoun: Boolean = false,
        val nuit: Boolean = false,
    )

    private val cas = listOf(
        Cas("mercredi ordinaire", "2026-10-14", false),
        Cas("lundi, lecture de la Torah", "2026-10-19", true),
        Cas("mardi ordinaire", "2026-10-20", true),
        Cas("Chabbat", "2026-10-17", false),
        Cas("Roch 'Hodech 'Hechvan, année embolismique", "2026-10-12", false, alternes = true),
        Cas("Roch 'Hodech Kislev, un mercredi", "2026-11-11", true),
        Cas("'Hanouka, un lundi", "2026-12-07", false, alternes = true),
        Cas("10 Tévèt", "2026-12-20", false, alternes = true),
        Cas("lundi ordinaire d'hiver", "2026-12-21", false),
        Cas("lundi d'hiver, hémisphère sud", "2026-12-21", false, sud = true),
        Cas("Pourim, ville ouverte", "2027-03-23", false),
        Cas("Pourim de Jérusalem, ville murée", "2027-03-24", true, muree = true),
        Cas("Chouchan Pourim, ville ouverte en Israël", "2027-03-24", true),
        Cas("Tich'a bèAv", "2027-08-12", false),
        Cas("Roch Hachana un Chabbat", "2026-09-12", false),
        Cas("jeûne de Guedalia", "2026-09-14", false),
        Cas("dix jours de pénitence", "2026-09-15", true, alternes = true),
        Cas("Kippour", "2026-09-21", false),
        Cas("'Hol hamoed Soukkot", "2026-09-29", false),
        Cas("Chemini Atseret, bascule de la pluie (Israël)", "2026-10-03", true),
        Cas("Sim'hat Torah (diaspora)", "2026-10-04", false),
        Cas("fin de Tichri, coutume du noussa'h", "2026-10-05", false),
        Cas("fin de Tichri, sans Ta'hanoun", "2026-10-05", false, finTichri = true),
        Cas("fin de Tichri, avec Ta'hanoun", "2026-10-05", false, finTichri = false),
        Cas("15 Nissan, bascule de la pluie (diaspora)", "2027-04-22", false),
        Cas("'Hol hamoed Pessa'h, omer (Israël)", "2027-04-25", true),
        Cas("été, diaspora", "2027-06-01", false),
        Cas("été, Israël", "2027-06-01", true),
        Cas("été, hémisphère sud", "2027-06-01", false, sud = true),
        // Les deux catégories du 26/11.
        Cas("vendredi soir, le Chabbat voisin", "2026-11-20", false, voisin = "2026-11-21", alternes = true),
        Cas("samedi soir, le Chabbat qui finit", "2026-11-22", false, voisin = "2026-11-21", nuit = true),
        Cas("jeudi, lecture de Vayichla'h", "2026-11-26", false, adresse = "m"),
        Cas("lundi, pas de Ta'hanoun aujourd'hui", "2026-11-16", true, sansTahanoun = true, adresse = "f"),
        Cas("30 Av, Ledavid", "2026-08-13", false),
        Cas("le soir du 8ᵉ jour de l'omer", "2027-04-30", false),
        Cas("mardi d'hiver, le voyageur", "2026-11-17", false, alternes = true),
        Cas("9 Av, lecture du matin et de Min'ha", "2026-07-23", false),
        Cas("Roch 'Hodech Tévèt, 'Hanouka", "2026-12-11", true, voisin = "2026-12-12"),
        Cas("'Hol hamoed Soukkot en Israël, lecture", "2026-09-27", true),
        Cas("22 Nissan, Isrou 'hag ou 8ᵉ jour", "2027-04-29", true),
    )

    /** Les conditions d'un jour comme Store.conditionsDuJour, et la nuit comme SiddurLectureActivity. */
    private fun conditions(iso: String, c: Cas): Set<String> {
        val j = CalendrierJuif.jour(LocalDate.parse(iso), c.israel, c.muree)
        val avec = SiddurJour.avecAdresse(SiddurJour.avecSansTahanoun(j.conditions, c.sansTahanoun), c.adresse)
        return if (c.nuit) avec + CalendrierJuif.C.NUIT else avec
    }

    private val conditionsDuCas: List<Set<String>> = cas.map { conditions(it.date, it) }

    /** Celles du jour voisin, sans la nuit (SiddurLectureActivity.voisinPour) ; vides sans voisin. */
    private val voisinsDuCas: List<Set<String>> = cas.map { c ->
        c.voisin?.let { v -> conditions(v, c.copy(nuit = false)) } ?: emptySet()
    }

    /** La lecture de la Torah d'un office ce jour-là (LectureTorah.lecturesOffice), vide pour les autres textes. */
    private fun lecturesDe(t: SiddurTexte, ci: Int, n: Nusah): List<LectureTorah.Lecture> =
        if (t.id !in LectureTorah.OFFICES) emptyList()
        else LectureTorah.lecturesOffice(lectures, LocalDate.parse(cas[ci].date), t.id, cas[ci].israel, cas[ci].muree, n.cle)

    private fun finTichri(c: Cas, n: Nusah): Boolean = c.finTichri ?: (n == Nusah.EDOT)

    private fun signature(l: SiddurJour.Ligne): String = when (l) {
        is SiddurJour.Ligne.Titre -> "titre|${h(l.texte)}|${h(l.fr)}|${h(l.en)}"
        // L'origine (FLECTURE-08) : le paragraphe du texte, quand le bloc montré en est une copie rognée.
        is SiddurJour.Ligne.Bloc ->
            "bloc|${l.style.name}|${if (l.bloc.consigne) "c" else "t"}|${h(l.bloc.texte)}|${h(l.bloc.fr)}|${h(l.bloc.en)}" +
                if (l.origine !== l.bloc) "|${h(l.origine.texte)}" else ""
        is SiddurJour.Ligne.Etiquette -> "etiquette|${l.condition}|${l.libelle}"
        is SiddurJour.Ligne.Indice -> "indice|${h(l.texte)}|${l.fixe}"
        is SiddurJour.Ligne.Renvoi -> "renvoi|${l.condition}|${l.cible}"
        is SiddurJour.Ligne.Rappel -> "rappel|${l.condition}|${l.libelle}"
        is SiddurJour.Ligne.Seul -> "seul|${h(l.texte)}|${h(l.consigne)}|${l.note}"
        is SiddurJour.Ligne.Replie -> "replie|${l.cle}|${l.condition}|${l.ouvert}|${l.libelle}|${l.pasAujourdhui}"
        is SiddurJour.Ligne.Fin -> "fin|${l.cle}"
        is SiddurJour.Ligne.Lecture -> "lecture|${l.cle}|${l.lecture.cle}|${l.ouvert}|${h(l.lecture.titre.he)}|${l.lecture.montees.size}"
        is SiddurJour.Ligne.Passage -> "passage|${l.montee.cle}|${l.montee.livre}|${l.montee.debut}|${l.montee.fin}|${h(l.montee.libelle.fr)}"
    }

    /** Titres, blocs (normaux, du jour, hors du jour), étiquettes, indices, renvois, cartes « seul », replis, rappels,
     * fins, lectures, passages. */
    private fun genres(lignes: List<SiddurJour.Ligne>): List<Int> = listOf(
        lignes.count { it is SiddurJour.Ligne.Titre },
        lignes.count { it is SiddurJour.Ligne.Bloc && it.style == SiddurJour.Style.NORMAL },
        lignes.count { it is SiddurJour.Ligne.Bloc && it.style == SiddurJour.Style.DU_JOUR },
        lignes.count { it is SiddurJour.Ligne.Bloc && it.style == SiddurJour.Style.HORS },
        lignes.count { it is SiddurJour.Ligne.Etiquette },
        lignes.count { it is SiddurJour.Ligne.Indice },
        lignes.count { it is SiddurJour.Ligne.Renvoi },
        lignes.count { it is SiddurJour.Ligne.Seul },
        lignes.count { it is SiddurJour.Ligne.Replie },
        lignes.count { it is SiddurJour.Ligne.Rappel },
        lignes.count { it is SiddurJour.Ligne.Fin },
        lignes.count { it is SiddurJour.Ligne.Lecture },
        lignes.count { it is SiddurJour.Ligne.Passage },
    )

    private fun lignes(n: Nusah, t: SiddurTexte, a: List<SiddurJour.Annotation>, ci: Int, ouverts: Set<String>) =
        SiddurJour.lignes(t, a, conditionsDuCas[ci], ouverts, n.cle, cas[ci].israel, finTichri(cas[ci], n), cas[ci].sud,
            voisinsDuCas[ci], lecturesDe(t, ci, n))

    /** Les replis et les lectures d'une lecture fermée : ce que « tous » et « alternes » ouvrent. */
    private fun cles(l: List<SiddurJour.Ligne>): List<String> = l.mapNotNull {
        when (it) {
            is SiddurJour.Ligne.Replie -> it.cle
            is SiddurJour.Ligne.Lecture -> it.cle
            else -> null
        }
    }

    private fun releve(n: Nusah, t: SiddurTexte, ci: Int, mode: String, l: List<SiddurJour.Ligne>): Map<String, Any?> =
        linkedMapOf("n" to n.cle, "t" to t.id, "c" to ci, "o" to mode,
            "h" to l.joinToString("\n") { signature(it) }.hashCode(), "s" to genres(l),
            // Les lectures de la Torah de cet office ce jour-là (leurs clés), que le Swift calcule de son côté.
            "l" to lecturesDe(t, ci, n).map { it.cle },
            // Les places lues dans le panneau d'un repli déplié (SiddurJour.panneaux), en empreinte.
            "p" to SiddurJour.panneaux(l).sorted().hashCode())

    /** Chaque texte, chaque jour : replis fermés, tous ouverts, un sur deux (pour quelques jours). */
    private fun toutesLesLignes(): List<Map<String, Any?>> = siddourim.flatMap { (n, siddur) ->
        val parTexte = SiddurJour.parse(json, n.cle)
        siddur.textes.flatMap { t ->
            val a = parTexte[t.id].orEmpty()
            // Sans annotation, le jour n'y change rien : un relevé suffit.
            if (a.isEmpty()) listOf(releve(n, t, 0, "aucun", lignes(n, t, a, 0, emptySet())))
            else cas.indices.flatMap { ci ->
                val fermees = lignes(n, t, a, ci, emptySet())
                val cles = cles(fermees)
                val sortie = mutableListOf(releve(n, t, ci, "aucun", fermees),
                    releve(n, t, ci, "tous", lignes(n, t, a, ci, cles.toSet())))
                if (cas[ci].alternes) {
                    val alternes = cles.filterIndexed { i, _ -> i % 2 == 0 }.toSet()
                    sortie += releve(n, t, ci, "alternes", lignes(n, t, a, ci, alternes))
                }
                sortie
            }
        }
    }

    /** Quelques suites en entier, ligne à ligne, pour voir où un écart commence. */
    private fun details(): List<Map<String, Any?>> = listOf(
        Triple(Nusah.EDOT, "chaharit", 4), Triple(Nusah.ASHKENAZ, "minha", 7), Triple(Nusah.SEFARD, "arvit", 20),
    ).map { (n, id, ci) ->
        val siddur = siddourim.first { it.first == n }.second
        val t = siddur.texte(id)!!
        val l = lignes(n, t, SiddurJour.parse(json, n.cle).getValue(id), ci, emptySet())
        linkedMapOf("n" to n.cle, "t" to id, "c" to ci, "o" to "aucun", "lignes" to l.map(::signature))
    }

    // MARK: lignes, sur un texte écrit à la main

    // Ce que les siddourim n'atteignent pas : une variante du jour sans passage à retirer (Indice), un
    // passage absent du bloc (aucun repli, sauf ouvert), plusieurs variantes d'un même bloc (l'ordre
    // du retrait, la première nomme le repli), un passage répété (seul le premier part), un passage
    // canoniquement égal mais d'autres unités (rien ne part), des blancs que trim() garde (U+0085) ou
    // retire (U+2009), des annotations en double (la dernière l'emporte), des groupes voisins, un
    // groupe sans racine, un groupe sans numéro en fin de section (« 1:null »), des renvois et des
    // cartes « seul » qu'un groupe ou une section annotée tait, une section annotée suivie d'un renvoi,
    // des annotations hors du texte, un titre blanc, un texte d'une seule section.

    /** « שָׁלוֹם », le qamats avant le point du shin (l'ordre canonique), puis l'inverse. */
    private val chalom = e(0x05E9) + e(0x05B8) + e(0x05C1) + "לוֹם"
    private val chalomInverse = e(0x05E9) + e(0x05C1) + e(0x05B8) + "לוֹם"

    private val siddurEcrit = """{"groupes": [{"cle": "essai", "titre": {"he": "ניסיון", "fr": "Essai", "en": "Test"}}],""" +
        """ "textes": [{"id": "ecrit", "groupe": "essai", "titre": {"he": "כתוב", "fr": "Écrit", "en": "Written"}, "sections": [""" +
        """{"titre": "שַׁחֲרִית", "titre_fr": "Matin", "titre_en": " ", "blocs": [""" +
        """{"t": "בָּרוּךְ אַתָּה", "fr": "Béni sois-tu", "en": "Blessed"},""" +
        """ {"t": "אַתָּה גִּבּוֹר מוֹרִיד הַטָּל מְחַיֶּה מֵתִים", "fr": "Tu es puissant"},""" +
        """ {"t": "  הָאֵל הַקָּדוֹשׁ${e(0x2009)}"}, {"t": "$chalomInverse${e(0x85)}"}, {"c": "אומרים כאן"},""" +
        """ {"t": "אָמֵן אָמֵן"}]},""" +
        """ {"titre": "", "blocs": [{"t": "א0"}, {"t": "א1"}, {"t": "א2"}, {"t": "א3"}, {"t": "א4"}, {"t": "א5"},""" +
        """ {"t": "א6"}, {"t": "א7"}, {"t": "א8"}]},""" +
        """ {"titre": "מוּסָף", "titre_en": "Musaf", "blocs": [{"t": "תִּכַּנְתָּ שַׁבָּת"}, {"c": "ש״ץ"}]},""" +
        """ {"titre": "   ", "blocs": [{"t": "עָלֵינוּ"}]}]},""" +
        """ {"id": "unique", "groupe": "essai", "titre": {"he": "אחד"}, "sections": [""" +
        """{"titre": "כותרת", "blocs": [{"t": "א"}, {"t": "ב"}]}]},""" +
        // L'audit du 16/11 : le texte ordinaire qu'une formule du jour remplace, la double annotation (minyan, 9 Av),
        // un passage discret, une indication fixe répétée, une note de l'application, un rappel sans texte cible.
        """ {"id": "audit", "groupe": "essai", "titre": {"he": "ביקורת"}, "sections": [""" +
        """{"titre": "א", "blocs": [{"t": "ב0"}, {"t": "ב1"}, {"t": "ב2"}, {"t": "ב3"}, {"t": "ב4"}, {"t": "ב5"},""" +
        """ {"t": "ב6"}, {"t": "ב7"}, {"t": "ב8"}]}, {"titre": "ב", "blocs": [{"t": "ג0"}, {"t": "ג1"}]}]}]}"""

    private val annotationsEcrites = """{"edot": {"ecrit": [""" +
        // Section 0, bloc 1 : quatre variantes à retirer, une à signaler.
        """{"sorte": "indice", "s": 0, "b": 1, "si": "morid_hatal", "empreinte": "e", "retire": "מוֹרִיד הַטָּל "},""" +
        """ {"sorte": "indice", "s": 0, "b": 1, "si": "machiv_harouah", "empreinte": "e", "texte": "מַשִּׁיב הָרוּחַ"},""" +
        """ {"sorte": "indice", "s": 0, "b": 1, "si": "kippour", "empreinte": "e", "texte": "X", "retire": "מְחַיֶּה",""" +
        """ "libelle": "ajout_propre"},""" +
        """ {"sorte": "indice", "s": 0, "b": 1, "si": "!chabbat", "empreinte": "e", "retire": " מֵתִים"},""" +
        // Ce passage chevauche le premier : l'ordre du retrait décide de ce qui reste.
        """ {"sorte": "indice", "s": 0, "b": 1, "si": "!kippour", "empreinte": "e", "retire": "גִּבּוֹר מוֹרִיד"},""" +
        """ {"sorte": "renvoi", "s": 0, "b": 1, "si": "!chabbat", "empreinte": "e", "cible": "x"},""" +
        // Bloc 2 : le passage manque, mais trim() ôte les blancs ; bloc 3 : le passage n'a pas les mêmes unités.
        """ {"sorte": "indice", "s": 0, "b": 2, "si": "asseret_yemei_techouva", "empreinte": "e", "retire": "הַמֶּלֶךְ"},""" +
        """ {"sorte": "indice", "s": 0, "b": 3, "si": "chabbat", "empreinte": "e", "retire": "$chalom"},""" +
        // Bloc 4 : les cartes « seul », dans l'ordre ; une sans texte, une hors du jour.
        """ {"sorte": "seul", "s": 0, "b": 4, "si": "!minyan", "empreinte": "e", "texte": "בָּרְכוּ", "consigne": "אומרים"},""" +
        """ {"sorte": "seul", "s": 0, "b": 4, "si": "chabbat", "empreinte": "e", "texte": "ב"},""" +
        """ {"sorte": "seul", "s": 0, "b": 4, "si": "!minyan", "empreinte": "e", "texte": "  "},""" +
        """ {"sorte": "seul", "s": 0, "b": 4, "si": "kippour", "empreinte": "e", "texte": "ק"},""" +
        // Bloc 5 : un passage répété ; un renvoi du jour, un sans cible.
        """ {"sorte": "indice", "s": 0, "b": 5, "si": "!roch_hodech", "empreinte": "e", "retire": "אָמֵן"},""" +
        """ {"sorte": "renvoi", "s": 0, "b": 5, "si": "hallel", "empreinte": "e", "cible": "hallel"},""" +
        """ {"sorte": "renvoi", "s": 0, "b": 5, "si": "hallel", "empreinte": "e", "cible": "  "},""" +
        """ {"sorte": "renvoi", "s": 0, "si": "roch_hodech", "empreinte": "e", "cible": "moussaf_rosh_hodech"},""" +
        // Section 1 : des groupes.
        """ {"sorte": "bloc", "s": 1, "b": 0, "g": 1, "si": "yaale_veyavo", "racine": "yaale_veyavo", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 1, "g": 1, "si": "pessah", "racine": "zzz", "empreinte": "e"},""" +
        """ {"sorte": "seul", "s": 1, "b": 0, "si": "!minyan", "empreinte": "e", "texte": "tu"},""" +
        """ {"sorte": "seul", "s": 1, "b": 1, "si": "!minyan", "empreinte": "e", "texte": "dit"},""" +
        """ {"sorte": "indice", "s": 1, "b": 0, "si": "!minyan", "empreinte": "e", "texte": "tu"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 2, "g": 2, "si": "!tahanoun_chaharit", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 3, "g": 2, "si": "tahanoun_chaharit", "racine": "jeune", "empreinte": "e"},""" +
        """ {"sorte": "renvoi", "s": 1, "b": 3, "si": "!minyan", "empreinte": "e", "cible": "tu"},""" +
        """ {"sorte": "indice", "s": 1, "b": 4, "si": "!chabbat", "empreinte": "e", "texte": "שבוע"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 5, "g": 3, "si": "kippour", "racine": "kippour", "libelle": "ajout_x", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 5, "g": 3, "si": "jeune", "racine": "jeune", "libelle": "ajout_anenou_officiant",""" +
        """ "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 6, "g": 4, "si": "hallel", "racine": "hallel", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 7, "g": 5, "si": "tal_oumatar", "racine": "!tal_oumatar", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 8, "si": "berakha", "racine": "berakha", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 1, "b": 20, "g": 9, "si": "chabbat", "racine": "chabbat", "empreinte": "e"},""" +
        // Section 2 : annotée deux fois, un renvoi après elle ; ce qui vise ses blocs se tait.
        """ {"sorte": "section", "s": 2, "si": "chabbat", "empreinte": "e"},""" +
        """ {"sorte": "section", "s": 2, "si": "roch_hodech", "empreinte": "e"},""" +
        """ {"sorte": "renvoi", "s": 2, "si": "hallel", "empreinte": "e", "cible": "hallel"},""" +
        """ {"sorte": "renvoi", "s": 2, "b": 0, "si": "!minyan", "empreinte": "e", "cible": "tu"},""" +
        """ {"sorte": "seul", "s": 2, "b": 0, "si": "!minyan", "empreinte": "e", "texte": "tu"},""" +
        // Section 3 et au-delà.
        """ {"sorte": "renvoi", "s": 3, "si": "!kippour", "empreinte": "e", "cible": "fin"},""" +
        """ {"sorte": "seul", "s": 3, "si": "!minyan", "empreinte": "e", "texte": "tu"},""" +
        """ {"sorte": "section", "s": 9, "si": "!minyan", "empreinte": "e"},""" +
        """ {"sorte": "indice", "s": 9, "b": 0, "si": "!minyan", "empreinte": "e", "texte": "tu"}],""" +
        """ "unique": [{"sorte": "bloc", "s": 0, "b": 1, "g": 7, "si": "omer", "racine": "omer", "empreinte": "e"},""" +
        """ {"sorte": "renvoi", "s": 0, "si": "omer", "empreinte": "e", "cible": "sefirat_haomer"}],""" +
        """ "audit": [""" +
        """{"sorte": "bloc", "s": 0, "b": 0, "g": 1, "si": "!asseret_yemei_techouva", "racine": "!asseret_yemei_techouva",""" +
        """ "libelle": "ajout_autres_jours", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 1, "g": 2, "si": "hallel", "racine": "hallel", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 2, "g": 2, "si": "hallel", "racine": "hallel", "et": "minyan", "et_libelle": "ajout_minyan",""" +
        """ "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 3, "g": 2, "si": "hallel", "racine": "hallel", "et": "minyan", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 4, "g": 2, "si": "hallel_complet", "racine": "hallel", "et": "!ticha_beav", "empreinte": "e"},""" +
        """ {"sorte": "indice", "s": 0, "b": 1, "si": "rosh_hodech", "empreinte": "e", "texte": "יום"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 5, "g": 3, "si": "chabbat", "racine": "chabbat", "discret": true, "empreinte": "e"},""" +
        """ {"sorte": "indice", "s": 0, "b": 6, "si": "toujours", "empreinte": "e", "texte": "קבוע", "fixe": true},""" +
        """ {"sorte": "indice", "s": 0, "b": 6, "si": "chabbat", "empreinte": "e", "texte": "קבוע"},""" +
        """ {"sorte": "note", "s": 0, "b": 6, "si": "!zzz", "empreinte": "e", "texte": "הערה", "consigne": "c"},""" +
        """ {"sorte": "note", "s": 0, "b": 6, "si": "chabbat", "empreinte": "e", "texte": "שבת"},""" +
        """ {"sorte": "renvoi", "s": 0, "b": 7, "si": "roch_hodech", "empreinte": "e", "libelle": "ajout_minyan"},""" +
        """ {"sorte": "renvoi", "s": 0, "b": 7, "si": "chabbat", "empreinte": "e", "cible": "x", "libelle": "ajout_minyan"},""" +
        """ {"sorte": "indice", "s": 0, "b": 8, "si": "!kippour", "empreinte": "e", "retire": "8"},""" +
        """ {"sorte": "section", "s": 1, "si": "minyan", "empreinte": "e"}]}}"""

    private val conditionsEcrites: List<Set<String>> = listOf(
        emptySet(),
        setOf("morid_hatal", "machiv_harouah", "yaale_veyavo", "roch_hodech", "hallel", "chabbat", "tahanoun_chaharit", "berakha"),
        setOf("asseret_yemei_techouva", "jeune", "tal_oumatar", "hallel", "hallel_complet", "pessah", "yaale_veyavo", "kippour",
            "minyan"),
        setOf("bascule_pluie", "fin_tichri", "tahanoun_chaharit", "lundi_jeudi", "jeune", "omer"),
        setOf("chabbat", "roch_hodech", "kippour", "asseret_yemei_techouva", "machiv_harouah"),
        setOf("hallel", "hallel_complet", "minyan", "toujours", "rosh_hodech"),
        setOf("hallel", "ticha_beav", "toujours", "asseret_yemei_techouva", "chabbat"),
    )

    /** Noussa'h, Israël, coutume de la fin de Tichri (null : celle du noussa'h), hémisphère sud. */
    private data class Reglage(val nusah: Nusah, val israel: Boolean, val finTichri: Boolean?, val sud: Boolean)

    private val reglagesEcrits = listOf(
        Reglage(Nusah.EDOT, false, null, false), Reglage(Nusah.SEFARD, false, null, false),
        Reglage(Nusah.ASHKENAZ, false, null, false), Reglage(Nusah.ASHKENAZ, true, null, false),
        Reglage(Nusah.EDOT, false, null, true), Reglage(Nusah.SEFARD, false, true, false), Reglage(Nusah.EDOT, false, false, false),
    )

    /** Des clés ouvertes sans repli à ouvrir : une variante qui ne se replie pas, un bloc sans variante, une clé hors du texte. */
    private val ouvertsEnPlus = setOf("v0:3", "v0:0", "§3", "1:null", "9:9")

    private fun ecrit(): Map<String, Any?> {
        val siddur = SiddurLoader.parse(siddurEcrit)
        val parTexte = SiddurJour.parse(annotationsEcrites, "edot")
        val lectures = mutableListOf<Map<String, Any?>>()
        fun lire(t: SiddurTexte, ci: Int, r: Reglage, ouverts: Set<String>, complet: Boolean): List<SiddurJour.Ligne> {
            val l = SiddurJour.lignes(t, parTexte[t.id].orEmpty(), conditionsEcrites[ci], ouverts, r.nusah.cle, r.israel,
                r.finTichri ?: (r.nusah == Nusah.EDOT), r.sud)
            lectures += linkedMapOf("t" to t.id, "c" to ci, "nusah" to r.nusah.cle, "israel" to r.israel, "finTichri" to r.finTichri,
                "sud" to r.sud, "ouverts" to ouverts.sorted(), "h" to l.joinToString("\n") { signature(it) }.hashCode(),
                "s" to genres(l), "lignes" to if (complet) l.map(::signature) else null,
                "panneaux" to SiddurJour.panneaux(l).sorted())
            return l
        }
        siddur.textes.forEach { t ->
            conditionsEcrites.indices.forEach { ci ->
                reglagesEcrits.forEachIndexed { ri, r ->
                    val fermees = lire(t, ci, r, emptySet(), ri == 0)
                    val cles = fermees.filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }
                    lire(t, ci, r, cles.toSet() + ouvertsEnPlus, ri == 0)
                    if (ri == 0) lire(t, ci, r, cles.filterIndexed { i, _ -> i % 2 == 0 }.toSet(), false)
                }
            }
        }
        return linkedMapOf("siddur" to siddurEcrit, "annotations" to annotationsEcrites, "conditions" to conditionsEcrites.map { it.sorted() },
            "lectures" to lectures)
    }


    // MARK: les deux catégories du 26/11, sur un texte écrit à la main

    // Ce que les vrais siddourim n'atteignent pas tout à fait : la garde d'une occasion (quand), un ajout du calendrier
    // gardé replié (replie_hors, avec ou sans libelle_hors), une variante remplacée (par, vide ou non), une occasion
    // mêlée de lignes d'un jour (Q11), les « et » d'occasion et les autres, par suites de même libellé, le jour voisin,
    // la place des lectures (avec ou sans office), les cartes « seul » repliées, une section vidée qui perd son titre.

    private val siddurCategories = """{"groupes": [{"cle": "essai", "titre": {"he": "ניסיון"}}],""" +
        """ "textes": [{"id": "cat", "groupe": "essai", "titre": {"he": "קטגוריות"}, "sections": [""" +
        """{"titre": "א", "blocs": [{"t": "ד0"}, {"t": "ד1"}, {"t": "ד2"}, {"t": "ד3"}, {"t": "ד4"}, {"t": "ד5"}, {"t": "ד6"},""" +
        """ {"t": "ד7"}, {"t": "ד8"}, {"t": "ד9"}, {"t": "ד10"}, {"t": "ד11"}]},""" +
        """ {"titre": "ב", "blocs": [{"t": "ה0 XX ה ZZ סוף"}, {"t": "ה1"}, {"t": "ה2"}, {"t": "ה3 QQ"}]},""" +
        """ {"titre": "ג", "blocs": [{"t": "ו0"}, {"t": "ו1"}]},""" +
        """ {"titre": "ד", "blocs": [{"t": "ז0"}]},""" +
        """ {"titre": "ה", "blocs": [{"t": "ח0"}]},""" +
        """ {"titre": "ו", "blocs": [{"t": "ט0"}, {"t": "ט1"}]}]}]}"""

    private val annotationsCategories = """{"edot": {"cat": [""" +
        // Section 0 : un ajout du calendrier et sa variante, une occasion mêlée, deux replie_hors, une garde, des « et ».
        """{"sorte": "bloc", "s": 0, "b": 0, "g": 1, "si": "chabbat", "racine": "chabbat", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 1, "g": 1, "si": "roch_hodech", "racine": "chabbat", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 2, "g": 2, "si": "zimun", "racine": "zimun", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 3, "g": 2, "si": "chabbat", "racine": "zimun", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 4, "g": 3, "si": "ledavid", "racine": "ledavid", "replie_hors": true, "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 5, "g": 4, "si": "jeune", "racine": "jeune", "replie_hors": true,""" +
        """ "libelle_hors": "ajout_jeune_individuel", "libelle": "ajout_anenou_particulier", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 6, "g": 5, "si": "oubli", "racine": "oubli", "quand": "retse_ou_yaale", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 7, "g": 6, "si": "hallel", "racine": "hallel", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 8, "g": 6, "si": "hallel", "racine": "hallel", "et": "minyan", "et_libelle": "ajout_minyan",""" +
        """ "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 9, "g": 6, "si": "hallel", "racine": "hallel", "et": "minyan", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 10, "g": 6, "si": "hallel", "racine": "hallel", "et": "!ticha_beav", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 0, "b": 11, "g": 7, "si": "!asseret_yemei_techouva", "racine": "!asseret_yemei_techouva",""" +
        """ "libelle": "ajout_autres_jours", "quand": "!chabbat", "empreinte": "e"},""" +
        """ {"sorte": "seul", "s": 0, "b": 11, "si": "!minyan", "empreinte": "e", "texte": "יחיד", "consigne": "c"},""" +
        // Section 1 : des variantes remplacées ou retirées, deux places de lecture, des cartes « seul » et une note.
        """ {"sorte": "indice", "s": 1, "b": 0, "si": "magdol", "empreinte": "e", "retire": "XX", "par": "YY"},""" +
        """ {"sorte": "indice", "s": 1, "b": 0, "si": "!chabbat", "empreinte": "e", "retire": "ZZ ", "par": ""},""" +
        """ {"sorte": "indice", "s": 1, "b": 0, "si": "roch_hodech", "empreinte": "e", "texte": "יום"},""" +
        """ {"sorte": "lecture", "s": 1, "b": 0, "si": "kriat_hatorah", "office": "chaharit", "empreinte": "e"},""" +
        """ {"sorte": "seul", "s": 1, "b": 1, "si": "!minyan", "empreinte": "e", "texte": "בָּרְכוּ", "consigne": "אומרים"},""" +
        """ {"sorte": "note", "s": 1, "b": 1, "si": "chabbat", "empreinte": "e", "texte": "הערה"},""" +
        """ {"sorte": "seul", "s": 1, "b": 1, "si": "chabbat", "empreinte": "e", "texte": "שני"},""" +
        """ {"sorte": "lecture", "s": 1, "b": 2, "si": "!chabbat", "empreinte": "e"},""" +
        """ {"sorte": "indice", "s": 1, "b": 3, "si": "chabbat", "empreinte": "e", "retire": "QQ"},""" +
        // Section 2 : une section d'occasion ; 3 : un ajout du calendrier gardé replié, gardé lui-même ; 4 : retirée,
        // son titre aussi ; 5 : un passage discret.
        """ {"sorte": "section", "s": 2, "si": "usage", "empreinte": "e"},""" +
        """ {"sorte": "section", "s": 3, "si": "omer", "replie_hors": true, "quand": "!kippour", "empreinte": "e"},""" +
        """ {"sorte": "section", "s": 4, "si": "roch_hodech", "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 5, "b": 0, "g": 8, "si": "chabbat", "racine": "chabbat", "discret": true, "empreinte": "e"},""" +
        """ {"sorte": "bloc", "s": 5, "b": 1, "g": 8, "si": "magdol", "racine": "chabbat", "empreinte": "e"}]}}"""

    private val conditionsCategories: List<Set<String>> = listOf(
        emptySet(),
        setOf("chabbat", "retse_ou_yaale", "kriat_hatorah", "omer"),
        setOf("roch_hodech", "yaale_veyavo", "retse_ou_yaale", "hallel", "ticha_beav", "jeune", "kriat_hatorah", "kippour"),
        setOf("ledavid", "jeune", "omer", "hallel", "asseret_yemei_techouva", "magdol"),
    )

    private val voisinsCategories: List<Set<String>> = listOf(
        emptySet(), setOf("chabbat", "retse_ou_yaale"), setOf("roch_hodech", "yaale_veyavo", "ticha_beav", "jeune"),
    )

    /** Aucune lecture ; celle du jeudi 26/11/2026 ; celle-là et celle de Roch 'Hodech Kislev (10/11/2026). */
    private val lecturesCategories: List<List<LectureTorah.Lecture>> = listOf(
        emptyList(),
        LectureTorah.lectures(lectures, LocalDate.parse("2026-11-26"), LectureTorah.CHAHARIT, false),
        LectureTorah.lectures(lectures, LocalDate.parse("2026-11-26"), LectureTorah.CHAHARIT, false) +
            LectureTorah.lectures(lectures, LocalDate.parse("2026-11-10"), LectureTorah.CHAHARIT, false, nusah = "ashkenaz"),
    )

    private fun categories(): Map<String, Any?> {
        val t = SiddurLoader.parse(siddurCategories).texte("cat")!!
        val a = SiddurJour.parse(annotationsCategories, "edot").getValue("cat")
        val sortie = mutableListOf<Map<String, Any?>>()
        val reglages = listOf(Nusah.EDOT to false, Nusah.SEFARD to true, Nusah.ASHKENAZ to false)
        for (ci in conditionsCategories.indices) for (vi in voisinsCategories.indices) for (li in lecturesCategories.indices) {
            for ((ri, r) in reglages.withIndex()) {
                fun lire(ouverts: Set<String>) = SiddurJour.lignes(t, a, conditionsCategories[ci], ouverts, r.first.cle, r.second,
                    voisin = voisinsCategories[vi], lectures = lecturesCategories[li])
                val fermees = lire(emptySet())
                // Tous les replis ouverts, jusqu'aux replis imbriqués.
                var tous = emptySet<String>()
                while (true) {
                    val plus = tous + cles(lire(tous))
                    if (plus == tous) break
                    tous = plus
                }
                val alternes = cles(fermees).filterIndexed { i, _ -> i % 2 == 0 }.toSet()
                for ((mode, ouverts) in listOf("aucun" to emptySet(), "tous" to tous, "alternes" to alternes)) {
                    val l = lire(ouverts)
                    sortie += linkedMapOf("c" to ci, "v" to vi, "l" to li, "r" to ri, "o" to mode, "ouverts" to ouverts.sorted(),
                        "h" to l.joinToString("\n") { signature(it) }.hashCode(), "s" to genres(l),
                        "panneaux" to SiddurJour.panneaux(l).sorted(),
                        "lignes" to if (vi == 0 && li == 0 && ri == 0) l.map(::signature) else null)
                }
            }
        }
        // decision, sur chaque annotation de bloc ou de section, chaque jour, chaque voisin.
        val decisions = a.filter { it.sorte == SiddurJour.Sorte.BLOC || it.sorte == SiddurJour.Sorte.SECTION }.flatMap { x ->
            conditionsCategories.indices.flatMap { ci ->
                voisinsCategories.indices.map { vi ->
                    val d = SiddurJour.decision(x, x.racine ?: x.condition, conditionsCategories[ci], voisinsCategories[vi])
                    listOf(x.section, x.bloc, ci, vi, d.etat.name, d.pasAujourdhui, d.libelle, d.tous)
                }
            }
        }
        return linkedMapOf("siddur" to siddurCategories, "annotations" to annotationsCategories,
            "conditions" to conditionsCategories.map { it.sorted() }, "voisins" to voisinsCategories.map { it.sorted() },
            "lectures" to lecturesCategories.map { l -> l.map { it.cle } }, "releves" to sortie, "decisions" to decisions)
    }

    // MARK: dependDeLaRegion, sur les vrais textes

    private fun region(): List<Map<String, Any?>> {
        val dates = listOf("2027-04-29", "2027-01-19", "2026-11-17", "2027-06-01", "2026-09-27", "2026-11-20", "2026-11-26")
        return siddourim.flatMap { (n, siddur) ->
            val parTexte = SiddurJour.parse(json, n.cle)
            listOf("chaharit", "minha", "arvit", "birkat_hamazon").mapNotNull { id -> siddur.texte(id)?.let { id to it } }.flatMap { (id, t) ->
                dates.map { iso ->
                    val d = LocalDate.parse(iso)
                    fun c(il: Boolean) = CalendrierJuif.jour(d, il).conditions
                    fun v(il: Boolean) = if (id == "birkat_hamazon") CalendrierJuif.jour(d.plusDays(1), il).conditions else emptySet()
                    fun l(il: Boolean) = if (id in LectureTorah.OFFICES) LectureTorah.lecturesOffice(lectures, d, id, il, false, n.cle) else emptyList()
                    linkedMapOf("n" to n.cle, "t" to id, "date" to iso, "voisin" to (id == "birkat_hamazon"),
                        "r" to SiddurJour.dependDeLaRegion(t, parTexte.getValue(id), c(true), c(false), n.cle,
                            voisinIsrael = v(true), voisinDiaspora = v(false), lecturesIsrael = l(true), lecturesDiaspora = l(false)))
                }
            }
        }
    }

    // MARK: parse

    private fun decrit(a: SiddurJour.Annotation): String = listOf(
        a.sorte.name, a.section.toString(), a.bloc?.toString(), a.condition, a.empreinte, a.texte, a.groupe?.toString(),
        a.racine, a.libelle, a.cible, a.consigne, a.retire, a.discret.toString(), a.et, a.etLibelle, a.fixe.toString(),
        a.quand, a.replieHors.toString(), a.libelleHors, a.par, a.office,
    ).joinToString("|") { it ?: RIEN }

    private fun parSorte(a: List<SiddurJour.Annotation>): List<Int> =
        SiddurJour.Sorte.entries.map { s -> a.count { it.sorte == s } }

    private fun lu(doc: String, nusah: String): Any? = try {
        SiddurJour.parse(doc, nusah).map { (id, a) -> linkedMapOf("texte" to id, "annotations" to a.map(::decrit)) }
    } catch (e: Exception) {
        "erreur"
    }

    /** Des fichiers écrits à la main : ce qu'org.json tolère, et ce qui le fait lever. */
    private val ecrits = listOf(
        """{"edot": {"x": [{"sorte": "inconnue", "s": 2.7, "si": "chabbat", "empreinte": "e", "texte": "  ", "b": "3", "g": "1",""" +
            """ "racine": "", "libelle": null, "cible": "c", "consigne": "${e(0xa0)}", "retire": "r"}], "y": []}, "sefard": {}}""",
        """{"edot": {"x": [{"sorte": "indice", "s": 1, "si": "!hallel", "empreinte": 5, "texte": 12, "racine": "${e(0x2009)}"},""" +
            """ {"sorte": "section", "s": "4", "si": "kippour", "empreinte": "", "g": 3000000000}]}}""",
        """{"edot": {"x": [{"sorte": "seul", "s": 0, "si": true, "empreinte": "z", "texte": "שָׁלוֹם", "consigne": "${e(0x200f)}"}]}}""",
        """{"edot": {"x": [{"sorte": "bloc"}]}}""",
        """{"edot": {"x": [{"sorte": "bloc", "s": "abc", "si": "c", "empreinte": "e"}]}}""",
        """{"edot": {"x": [{"sorte": "bloc", "s": 1, "si": "c", "empreinte": "e", "b": null}]}}""",
        """{"edot": {"x": [{"sorte": "bloc", "s": true, "si": "c", "empreinte": "e"}]}}""",
        """{"edot": {"x": {}}}""",
        """{"edot": {"x": [1]}}""",
        """{"edot": []}""",
        """{"edot": {}}""",
        """{}""",
        """[]""",
        """{""",
        """{"edot": {"x": [{"s": 1, "si": "c", "empreinte": "e"}]}}""",
        // getString d'une valeur null, d'un tableau, d'un objet ; un nombre écrit entre blancs ; une clé répétée.
        """{"edot": {"x": [{"sorte": null, "s": "  7 ", "si": null, "empreinte": [1, "a"], "texte": {"k": "v"}, "b": 2.9,""" +
            """ "g": -1.5, "racine": "r", "si": "dup"}]}}""",
        // La sorte se lit à la lettre ; un décimal hors des 32 bits, un entier qui en déborde, NaN, un exposant.
        """{"edot": {"x": [{"sorte": "SECTION", "s": 1e10, "si": "a", "empreinte": "e", "b": "NaN"},""" +
            """ {"sorte": " section", "s": -2147483649, "si": "a", "empreinte": "e", "g": "1e2"}]}}""",
        """{"edot": {"x": [{"sorte": "seul", "s": "", "si": "a", "empreinte": "e"}]}}""",
        """{"edot": {"x": null}}""",
        """{"edot": null, "sefard": "texte", "ashkenaz": {"x": [], "x": [{"sorte": "renvoi", "s": 0, "si": "a", "empreinte": "e"}]}}""",
        """{"edot": {}} ]""",
        // Les champs du 26/11 : par vide, nul, absent ; replie_hors écrit en chaîne ; une lecture, son office blanc.
        """{"edot": {"x": [{"sorte": "indice", "s": 0, "b": 1, "si": "magdol", "empreinte": "e", "retire": "r", "par": ""},""" +
            """ {"sorte": "indice", "s": 0, "b": 1, "si": "a", "empreinte": "e", "retire": "r", "par": null},""" +
            """ {"sorte": "bloc", "s": 0, "b": 2, "g": 1, "si": "ledavid", "empreinte": "e", "replie_hors": "true", "libelle_hors": " ",""" +
            """ "quand": "!chabbat"},""" +
            """ {"sorte": "lecture", "s": 0, "b": 3, "si": "kriat_hatorah", "empreinte": "e", "office": "  "},""" +
            """ {"sorte": "LECTURE", "s": 0, "b": 3, "si": "kriat_hatorah", "empreinte": "e", "office": "minha", "par": 5}]}}""",
    )

    private fun parse(): Map<String, Any?> = linkedMapOf(
        "fichier" to siddourim.flatMap { (n, _) ->
            SiddurJour.parse(json, n.cle).map { (id, a) ->
                linkedMapOf("n" to n.cle, "t" to id, "nombre" to a.size, "parSorte" to parSorte(a),
                    "h" to a.joinToString("\n", transform = ::decrit).hashCode())
            }
        },
        "ecrits" to ecrits.map { doc ->
            linkedMapOf("json" to doc, "edot" to lu(doc, "edot"), "sefard" to lu(doc, "sefard"), "ashkenaz" to lu(doc, "ashkenaz"))
        },
    )

    // MARK: vrai, libelle, libelleJour

    private val connues: List<String> = (CalendrierJuif.C.TOUTES + CalendrierJuif.C.DERIVEES +
        Nusah.entries.flatMap { n -> SiddurJour.parse(json, n.cle).values.flatten().flatMap { listOfNotNull(it.condition, it.racine) } })
        .map { it.removePrefix("!") }.distinct()

    private val bizarres = listOf("", "!", "!!chabbat", "tahanoun", "!tahanoun", "tahanounX", "!tahanounX", "tahanoun_",
        "embolismiqueX", "fete", "hol_hamoed", "Kippour", "kippour ", " kippour", "חג", "hallel_", "berakha_", "!berakha",
        "talOumatar", "! tal_oumatar", "!!tal_oumatar", "!pessah", "!hanouka", "!kippour", "!embolismique")

    private val toutes: List<String> = (connues + connues.map { "!$it" } + bizarres).distinct()

    /** Les conditions de Roch 'Hodech 'Hechvan (cas 4) : un jour réel pour vrai(). */
    private val jourReel: Set<String> get() = conditionsDuCas[4]

    private val ensemblesHallel: List<Set<String>> = listOf(
        emptySet(), setOf(CalendrierJuif.C.HALLEL), setOf(CalendrierJuif.C.HALLEL, CalendrierJuif.C.HALLEL_COMPLET),
        setOf(CalendrierJuif.C.HALLEL_COMPLET),
    )

    private fun libelles(): Map<String, Any?> = linkedMapOf(
        "libelle" to toutes.map { listOf(it, SiddurJour.libelle(it)) },
        "jourReel" to jourReel.sorted(),
        // vrai(c, ∅), vrai(c, {c sans « ! »}), vrai(c, {c}), vrai(c, jourReel).
        "vrai" to toutes.map { c ->
            linkedMapOf("c" to c, "r" to listOf(SiddurJour.vrai(c, emptySet()), SiddurJour.vrai(c, setOf(c.removePrefix("!"))),
                SiddurJour.vrai(c, setOf(c)), SiddurJour.vrai(c, jourReel)))
        },
        "ensemblesHallel" to ensemblesHallel.map { it.toList() },
        // Edot, Sefard, Ashkenaz : chaque ensemble pour le Hallel, le premier (vide) pour les autres conditions.
        "libelleJour" to toutes.flatMap { c ->
            val rangs = if (c.removePrefix("!").startsWith("hallel")) ensemblesHallel.indices.toList() else listOf(0)
            rangs.map { rang ->
                linkedMapOf("c" to c, "e" to rang,
                    "r" to Nusah.entries.map { n -> SiddurJour.libelleJour(null, c, n.cle, ensemblesHallel[rang]) })
            }
        },
        "libelleJourPropre" to listOf("tal_oumatar", "!tal_oumatar", "hallel", "berakha", "kippour").flatMap { c ->
            listOf("ajout_anenou_officiant", "", "null").map { propre ->
                linkedMapOf("propre" to propre, "c" to c,
                    "r" to Nusah.entries.map { n -> SiddurJour.libelleJour(propre, c, n.cle, ensemblesHallel[2]) })
            }
        },
    )

    // MARK: empreinte

    private val textes = listOf(
        "", " ", "   \t\n ", "שָׁלוֹם", "<b>שָׁלוֹם</b> עֲלֵיכֶם", "א<br>ב", "א<br/>ב", "<>", "a <b c", "<<b>>", "<a>>b",
        "<span\nclass='x'>טקסט</span>", "<i>  </i>", "<b>א</b><i>ב</i>", "בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים", "וַיְכֻלּ֥וּ הַשָּׁמַ֛יִם וְהָאָ֖רֶץ׃",
        "כָּל־הַנְּשָׁמָה",
        // Les bornes de la plage retirée (U+0591 à U+05C7) et leurs voisines.
        u(0x0590, 0x0591, 0x05AF, 0x05BD, 0x05BE, 0x05BF, 0x05C0, 0x05C3, 0x05C6, 0x05C7, 0x05C8, 0x05D0),
        // Les blancs d'Unicode ((?U)\s), et ceux que trim() retire sans que \s les prenne (U+001C à U+001F).
        "א" + u(0x2009) + "ב", "א" + u(0xA0) + "ב", "א" + u(0x3000) + "ב", "א" + u(0x85) + "ב", "א" + u(0x1C) + "ב",
        u(0x1C) + "א" + u(0x1F), "א" + u(0x200B) + "ב", u(0xFEFF) + "א", "א" + u(0x180E) + "ב", "א" + u(0x2028) + "ב" + u(0x2029) + "ג",
        "א" + u(0x202F) + "ב" + u(0x205F) + "ג" + u(0x1680) + "ד", "\t\n\r א  \t ב \n", "א" + u(0x0B) + "ב" + u(0x0C) + "ג",
        u(0xA0, 0xA0) + "א" + u(0xA0, 0xA0), u(0x2007) + "א" + u(0x2007),
        "אבגדהוזחטיכלמנסעפצקרשתאבגדהוזחטיכלמנסעפצקרשת", "אַבְגַּד הַוְזַח טִיכַל מְנַסַע פְּצַקְרַשְׁתְּ אַבְגַּד הַוְזַח טִיכַל מְנַסַע",
        "0123456789012345678901234567890123456789", "01234567890123456789012345678901234567890", "                                        x",
        "<b>" + "א".repeat(45) + "</b>", u(0xE9), "e" + u(0x0301), "a" + u(0x1D11E) + "b", "&nbsp;א", "יְהֹוָה", "ה׳ אֱלֹהֵינוּ", "\"שמע\"",
    )

    private fun empreintes(): Map<String, Any?> = linkedMapOf(
        "textes" to textes.map { listOf(it, SiddurJour.empreinte(it)) },
        // Chaque titre de section et chaque bloc des siddourim : leur nombre, et l'empreinte de leurs empreintes.
        "siddourim" to siddourim.flatMap { (n, siddur) ->
            siddur.textes.map { t ->
                val vus = t.sections.flatMap { s -> listOf(s.titre) + s.blocs.map { it.texte } }
                linkedMapOf("n" to n.cle, "t" to t.id, "nombre" to vus.size,
                    "h" to vus.joinToString("\n") { SiddurJour.empreinte(it) }.hashCode())
            }
        },
    )

    // MARK: SiddurMoment

    private val moments = listOf("chaharit", "arvit", "minha", null, "", "Chaharit")

    /** Autour du 14 Adar de six années, dont deux de Pourim mechoulach (5781, 5785), et du Pourim katan de 5787 (14 Adar I). */
    private val autourDePourim = listOf("2021-02-23", "2025-03-11", "2026-03-01", "2027-02-18", "2027-03-20", "2028-03-09", "2029-02-26")
        .flatMap { debut -> (0L until 7L).map { LocalDate.parse(debut).plusDays(it) } }

    private fun moment(): Map<String, Any?> = linkedMapOf(
        "moments" to moments,
        // Pour chaque jour : chaque moment, puis Israël (faux, vrai), puis ville murée (faux, vrai).
        "megila" to autourDePourim.map { d ->
            linkedMapOf("date" to d.toString(), "reponses" to moments.flatMap { m ->
                listOf(false, true).flatMap { israel -> listOf(false, true).map { muree -> SiddurMoment.megila(m, d, israel, muree) } }
            })
        },
        "latitudes" to listOf(31.77, null, -37.81, 0.0, -0.0, -0.0001, -90.0, 90.0),
        // Un jour sur deux, deux années : la réponse pour chaque latitude, « V » ou « F ».
        "ilanot" to (0L until 365L).map { LocalDate.parse("2026-01-01").plusDays(2 * it) }.map { d ->
            listOf(d.toString(), listOf(31.77, null, -37.81, 0.0, -0.0, -0.0001, -90.0, 90.0)
                .joinToString("") { if (SiddurMoment.ilanot(d, it)) "V" else "F" })
        },
        "moisIlanotSud" to (0..14).map { SiddurMoment.moisIlanotSud(it) },
        "illustration" to (siddourim.flatMap { (_, s) -> s.textes.map { it.id } }.distinct() + listOf("tefilat_haderekh", "", "inconnu"))
            .distinct().map { listOf(it, Identifiants.entree(SiddurMoment.illustration(it))) },
    )

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursSiddurJour.kt"),
        "cas" to cas.mapIndexed { ci, c ->
            linkedMapOf("nom" to c.nom, "date" to c.date, "israel" to c.israel, "muree" to c.muree, "sud" to c.sud,
                "finTichri" to c.finTichri, "voisin" to c.voisin, "adresse" to c.adresse, "sansTahanoun" to c.sansTahanoun,
                "nuit" to c.nuit, "conditions" to conditionsDuCas[ci].sorted(), "conditionsVoisin" to voisinsDuCas[ci].sorted(),
                "pour" to Nusah.entries.map { n ->
                    SiddurJour.conditionsPour(n.cle, c.israel, conditionsDuCas[ci], finTichri(c, n), c.sud).sorted()
                })
        },
        "lignes" to toutesLesLignes(),
        "details" to details(),
        "ecrit" to ecrit(),
        "categories" to categories(),
        "region" to region(),
        "parse" to parse(),
        "libelles" to libelles(),
        "empreinte" to empreintes(),
        "moment" to moment(),
    )
}
