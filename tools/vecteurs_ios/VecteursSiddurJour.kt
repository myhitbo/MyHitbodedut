// SiddurJour.kt devant la JVM, pour SiddurJour.swift (tâche 11) :
// - parse sur le vrai fichier d'annotations (par noussa'h et par texte : le compte par sorte et une
//   empreinte de chaque champ), puis sur des fichiers écrits à la main (tolérances et fautes d'org.json) ;
// - lignes() de chaque texte des trois siddourim, une trentaine de jours choisis, replis fermés, tous
//   ouverts, ou un sur deux : le compte par genre et une empreinte de la suite des lignes ;
// - vrai, libelle et libelleJour sur toutes les conditions, empreinte sur des textes écrits pour
//   l'occasion et sur chaque titre et chaque bloc des siddourim ;
// - SiddurMoment (Siddur.kt) : megila autour de Pourim, ilanot au nord et au sud, illustration.
//
// L'empreinte d'un texte est son hashCode de Java (Kotlin.hashCode en Swift), « ∅ » pour null.

import com.myhitbodedut.CalendrierJuif
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
    )

    private val conditionsDuCas: List<Set<String>> =
        cas.map { CalendrierJuif.jour(LocalDate.parse(it.date), it.israel, it.muree).conditions }

    private fun finTichri(c: Cas, n: Nusah): Boolean = c.finTichri ?: (n == Nusah.EDOT)

    private fun signature(l: SiddurJour.Ligne): String = when (l) {
        is SiddurJour.Ligne.Titre -> "titre|${h(l.texte)}|${h(l.fr)}|${h(l.en)}"
        is SiddurJour.Ligne.Bloc ->
            "bloc|${l.style.name}|${if (l.bloc.consigne) "c" else "t"}|${h(l.bloc.texte)}|${h(l.bloc.fr)}|${h(l.bloc.en)}"
        is SiddurJour.Ligne.Etiquette -> "etiquette|${l.condition}|${l.libelle}"
        is SiddurJour.Ligne.Indice -> "indice|${h(l.texte)}"
        is SiddurJour.Ligne.Renvoi -> "renvoi|${l.condition}|${l.cible}"
        is SiddurJour.Ligne.Seul -> "seul|${h(l.texte)}|${h(l.consigne)}"
        is SiddurJour.Ligne.Replie -> "replie|${l.cle}|${l.condition}|${l.ouvert}|${l.libelle}"
    }

    /** Titres, blocs (normaux, du jour, hors du jour), étiquettes, indices, renvois, cartes « seul », replis. */
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
    )

    private fun lignes(n: Nusah, t: SiddurTexte, a: List<SiddurJour.Annotation>, ci: Int, ouverts: Set<String>) =
        SiddurJour.lignes(t, a, conditionsDuCas[ci], ouverts, n.cle, cas[ci].israel, finTichri(cas[ci], n), cas[ci].sud)

    private fun releve(n: Nusah, t: SiddurTexte, ci: Int, mode: String, l: List<SiddurJour.Ligne>): Map<String, Any?> =
        linkedMapOf("n" to n.cle, "t" to t.id, "c" to ci, "o" to mode,
            "h" to l.joinToString("\n") { signature(it) }.hashCode(), "s" to genres(l))

    /** Chaque texte, chaque jour : replis fermés, tous ouverts, un sur deux (pour quelques jours). */
    private fun toutesLesLignes(): List<Map<String, Any?>> = siddourim.flatMap { (n, siddur) ->
        val parTexte = SiddurJour.parse(json, n.cle)
        siddur.textes.flatMap { t ->
            val a = parTexte[t.id].orEmpty()
            // Sans annotation, le jour n'y change rien : un relevé suffit.
            if (a.isEmpty()) listOf(releve(n, t, 0, "aucun", lignes(n, t, a, 0, emptySet())))
            else cas.indices.flatMap { ci ->
                val fermees = lignes(n, t, a, ci, emptySet())
                val cles = fermees.filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }
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

    // MARK: parse

    private fun decrit(a: SiddurJour.Annotation): String = listOf(
        a.sorte.name, a.section.toString(), a.bloc?.toString(), a.condition, a.empreinte, a.texte, a.groupe?.toString(),
        a.racine, a.libelle, a.cible, a.consigne, a.retire,
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

    /** Autour du 14 Adar de six années, dont deux de Pourim mechoulach (5781, 5785). */
    private val autourDePourim = listOf("2021-02-23", "2025-03-11", "2026-03-01", "2027-03-20", "2028-03-09", "2029-02-26")
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
                "finTichri" to c.finTichri, "conditions" to conditionsDuCas[ci].sorted(),
                "pour" to Nusah.entries.map { n ->
                    SiddurJour.conditionsPour(n.cle, c.israel, conditionsDuCas[ci], finTichri(c, n), c.sud).sorted()
                })
        },
        "lignes" to toutesLesLignes(),
        "details" to details(),
        "parse" to parse(),
        "libelles" to libelles(),
        "empreinte" to empreintes(),
        "moment" to moment(),
    )
}
