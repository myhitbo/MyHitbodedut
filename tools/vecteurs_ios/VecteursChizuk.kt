// ChizukRules, ChizukBag et ChizukCard devant la JVM.
//
// Sur tout chizuk.json livré : ce que chaque moment a le droit de tirer, en debug et en release
// (ChizukRules.forMoment), ce que chaque compilation montre (visible), puis, texte par texte, la règle
// de publication, l'hébreu affiché (hebrew) et la traduction selon la langue (ChizukCard.translationOf),
// ces deux derniers par une empreinte (String.hashCode). Puis des recueils écrits à la main, lus par
// ChizukLoader et rendus en clair : statuts et relu, moments inconnus ou répétés, éditions avec ou sans
// nikkoud, he_sans_nikkoud absent, vide ou blanc, clés d'édition composées ou décomposées.
// Le sac sans remise (ChizukBag.next) : les cas du test d'Android, des tirages isolés et des suites de
// tirages, mélangés par l'identité, l'ordre inverse ou kotlin.random.Random(graine) ; une suite passe à
// chaque tirage le sac restant et le dernier sorti, comme Store.setChizukBag. La langue de l'interface
// (ChizukCard.language) lue d'un Context dont la configuration porte un Locale.
// ChizukPartage (ChizukActivity.kt) n'est pas compilé par l'oracle : il n'a pas de vecteurs ici.

import android.content.Context
import android.content.ContextWrapper
import android.content.res.Configuration
import android.content.res.Resources
import android.os.LocaleList
import com.myhitbodedut.Chizuk
import com.myhitbodedut.ChizukBag
import com.myhitbodedut.ChizukCard
import com.myhitbodedut.ChizukItem
import com.myhitbodedut.ChizukLoader
import com.myhitbodedut.ChizukRules
import com.myhitbodedut.Moment
import java.util.Locale
import kotlin.random.Random

object VecteursChizuk : Generateur {
    override val fichier = "chizuk.json"

    /** Le fichier livré, lu comme l'app le lit (res/raw/chizuk.json, par le Context de théâtre). */
    private val livre: Chizuk = ChizukLoader.load(Theatre().contexte)

    /** Les langues des traductions de chaque texte, dans cet ordre. */
    private val languesDesTextes = listOf("fr", "en", "he", "iw", "de")

    // --- Règles de publication et d'affichage -------------------------------------------------------

    /** Chaque moment, en debug puis en release : les identifiants qu'il a le droit de tirer. */
    private fun parMoment(c: Chizuk): List<Map<String, Any?>> = Moment.entries.flatMap { m ->
        listOf(true, false).map { debug ->
            linkedMapOf("moment" to m.key, "debug" to debug, "ids" to ChizukRules.forMoment(c, m, debug).map { it.id })
        }
    }

    private fun visibles(c: Chizuk): List<Map<String, Any?>> = listOf(true, false).map { debug ->
        linkedMapOf("debug" to debug, "ids" to ChizukRules.visible(c, debug).map { it.id })
    }

    /** Un texte du fichier livré : la règle en clair, l'hébreu et les traductions en empreintes. */
    private fun texteLivre(item: ChizukItem): Map<String, Any?> = linkedMapOf(
        "id" to item.id,
        "publiable" to ChizukRules.isPublishable(item),
        "aRelire" to ChizukRules.needsProofreading(item),
        "hebreu" to ChizukRules.hebrew(livre, item).hashCode(),
        "longueurHebreu" to ChizukRules.hebrew(livre, item).length,
        "traductions" to languesDesTextes.map { ChizukCard.translationOf(item, it).hashCode() },
    )

    /** Un texte d'un recueil écrit à la main : tout en clair. */
    private fun texte(c: Chizuk, item: ChizukItem): Map<String, Any?> = linkedMapOf(
        "id" to item.id,
        "publiable" to ChizukRules.isPublishable(item),
        "aRelire" to ChizukRules.needsProofreading(item),
        "hebreu" to ChizukRules.hebrew(c, item),
        "traductions" to languesDesTextes.map { ChizukCard.translationOf(item, it) },
    )

    // Des recueils écrits à la main. Seules des valeurs du bon type : un nombre là où l'on attend une chaîne
    // (optString le lit, le décodage de Contenus.swift non) jugerait la lecture, pas ces règles.
    // Les \u de JSON sont lus par le lecteur JSON : « é » est é composé, « é » le même décomposé.
    private val recueils: List<Pair<String, String>> = listOf(
        "statuts" to """{"_meta":{"version":"t","editions":{"lm":{"titre":"L","licence":"Public Domain","nikkoud_ok":true}}},"items":[
            {"id":"verifie-relu","moments":["ouverture"],"edition":"lm","he":"א","fr":"a","en":"a","statut_verif":"verifie_texte","relu":true},
            {"id":"verifie-non-relu","moments":["ouverture"],"edition":"lm","he":"ב","fr":"b","en":"b","statut_verif":"verifie_texte","relu":false},
            {"id":"a-verifier-relu","moments":["ouverture"],"edition":"lm","he":"ג","statut_verif":"a_verifier","relu":true},
            {"id":"sans-statut-relu","moments":["blocage"],"edition":"lm","he":"ד","relu":true},
            {"id":"statut-vide","moments":["blocage"],"statut_verif":"","relu":true},
            {"id":"statut-majuscules","moments":["porte"],"statut_verif":"VERIFIE_TEXTE","relu":true},
            {"id":"statut-espace-apres","moments":["porte"],"statut_verif":"verifie_texte ","relu":true},
            {"id":"statut-espace-avant","moments":["relance"],"statut_verif":" verifie_texte","relu":true},
            {"id":"statut-accent","moments":["relance"],"statut_verif":"vérifié_texte","relu":true},
            {"id":"relu-absent","moments":["cloture"],"statut_verif":"verifie_texte"},
            {"id":"relu-nul","moments":["cloture"],"statut_verif":"verifie_texte","relu":null},
            {"id":"statut-nul","moments":["lieu"],"statut_verif":null,"relu":true},
            {"id":"non-verifie-non-relu","moments":["lieu"],"statut_verif":"a_verifier","relu":false},
            {"id":"verifie-relu-2","moments":["lieu","cloture"],"edition":"lm","he":"ה","statut_verif":"verifie_texte","relu":true}]}""",
        "moments" to """{"_meta":{"version":"m"},"items":[
            {"id":"sans-moment","moments":[],"statut_verif":"verifie_texte","relu":true},
            {"id":"moments-absents","statut_verif":"verifie_texte","relu":true},
            {"id":"moments-nuls","moments":null,"statut_verif":"verifie_texte","relu":true},
            {"id":"inconnu","moments":["inconnu"],"statut_verif":"verifie_texte","relu":true},
            {"id":"majuscules","moments":["OUVERTURE"],"statut_verif":"verifie_texte","relu":true},
            {"id":"espace","moments":[" ouverture"],"statut_verif":"verifie_texte","relu":true},
            {"id":"repete","moments":["porte","porte"],"statut_verif":"verifie_texte","relu":true},
            {"id":"demande","moments":["demande"],"statut_verif":"verifie_texte","relu":true},
            {"id":"plusieurs","moments":["blocage","inconnu","relance","cloture","lieu"],"statut_verif":"verifie_texte","relu":true},
            {"id":"ouverture-non-relue","moments":["ouverture"],"statut_verif":"verifie_texte","relu":false},
            {"id":"porte-a-verifier","moments":["porte","blocage"],"statut_verif":"a_verifier","relu":true},
            {"id":"tous","moments":["ouverture","blocage","porte","relance","cloture","lieu","demande"],"statut_verif":"verifie_texte","relu":true},
            {"id":"ouverture-2","moments":["lieu","ouverture"],"statut_verif":"verifie_texte","relu":true}]}""",
        "editions" to """{"_meta":{"version":"e","editions":{
            "voyelle":{"titre":"V","licence":"Public Domain","nikkoud_ok":true},
            "nue":{"titre":"N","licence":"non declaree","nikkoud_ok":false},
            "muette":{"titre":"M","licence":"?"},
            "nulle":{"nikkoud_ok":null},
            "é":{"nikkoud_ok":true}}},"items":[
            {"id":"voyelle-avec","edition":"voyelle","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי","statut_verif":"verifie_texte","relu":true},
            {"id":"voyelle-sans","edition":"voyelle","he":"אַשְׁרֵי","statut_verif":"verifie_texte","relu":true},
            {"id":"nue-avec","edition":"nue","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי","statut_verif":"verifie_texte","relu":true},
            {"id":"nue-sans","edition":"nue","he":"אַשְׁרֵי","statut_verif":"verifie_texte","relu":true},
            {"id":"nue-vide","edition":"nue","he":"אַשְׁרֵי","he_sans_nikkoud":"","statut_verif":"verifie_texte","relu":true},
            {"id":"nue-blanc","edition":"nue","he":"אַשְׁרֵי","he_sans_nikkoud":"  \t ","statut_verif":"verifie_texte","relu":true},
            {"id":"nue-nul","edition":"nue","he":"אַשְׁרֵי","he_sans_nikkoud":null,"statut_verif":"verifie_texte","relu":true},
            {"id":"nue-entoure","edition":"nue","he":"אַשְׁרֵי","he_sans_nikkoud":" אשרי ","statut_verif":"verifie_texte","relu":true},
            {"id":"muette","edition":"muette","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי"},
            {"id":"nulle","edition":"nulle","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי"},
            {"id":"inconnue","edition":"inconnue","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי"},
            {"id":"sans-edition","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי"},
            {"id":"casse","edition":"VOYELLE","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי"},
            {"id":"compose","edition":"é","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי"},
            {"id":"decompose","edition":"é","he":"אַשְׁרֵי","he_sans_nikkoud":"אשרי"},
            {"id":"he-vide","edition":"nue","he":"","statut_verif":"verifie_texte","relu":true},
            {"id":"voyelle-he-vide","edition":"voyelle","he":"","he_sans_nikkoud":"אשרי"},
            {"id":"tout-vide"}]}""",
        "traductions" to """{"_meta":{"version":"l"},"items":[
            {"id":"deux","fr":"Lève-toi","en":"Arise","he":"קוּם","statut_verif":"verifie_texte","relu":true},
            {"id":"fr-seul","fr":"Seul","he":"לבד"},
            {"id":"en-seul","en":"Alone","he":"לבד"},
            {"id":"blancs","fr":"  ","en":"\t","he":"א"},
            {"id":"entoures","fr":" un ","en":"\none\n","he":"א"},
            {"id":"hebreu-en-traduction","fr":"עִקַּר","en":"עיקר","he":"עִקַּר"},
            {"id":"aucune"}]}""",
        "vide" to """{"_meta":{},"items":[]}""",
        "sansEditions" to """{"_meta":{"version":"s","editions":null},"items":[
            {"id":"a","moments":["ouverture"],"he":"אַ","he_sans_nikkoud":"א","statut_verif":"verifie_texte","relu":true},
            {"id":"b","moments":["blocage"],"he":"בּ","statut_verif":"verifie_texte","relu":true}]}""",
    )

    private fun recueil(nom: String, json: String): Map<String, Any?> {
        val c = ChizukLoader.parse(json)
        return linkedMapOf(
            "nom" to nom, "json" to json,
            "visible" to visibles(c),
            "moments" to parMoment(c),
            "textes" to c.items.map { texte(c, it) },
        )
    }

    // --- La traduction et la langue de l'interface --------------------------------------------------

    /** Un texte écrit à la main, lu par ChizukLoader comme ceux du fichier. */
    private val gabaritJson =
        """{"id":"t","moments":["ouverture"],"edition":"lm","ref":"ref","he":"עִקַּר","fr":"Lève-toi","en":"Arise","duree_lecture_sec":5,"statut_verif":"verifie_texte","relu":true}"""
    private val gabarit: ChizukItem = ChizukLoader.parse("""{"_meta":{},"items":[$gabaritJson]}""").items.single()

    private val langues = listOf("fr", "en", "he", "iw", "de", "", "FR", "EN", "En", "HE", "IW", "Iw", "he-IL", "iw-IL",
        "en-US", "en_US", "fr-FR", "es", "ar", "yi", "ji", "ru", " en", "en ", "eng", "heb", "en​", "עב")

    /** Un Context dont la configuration ne porte que [locale] : ce que ChizukCard.language lit (comme Theatre). */
    private fun contexte(locale: Locale): Context {
        val configuration = object : Configuration() {
            override fun getLocales(): LocaleList = object : LocaleList() {
                override fun get(index: Int): Locale = locale
                override fun size(): Int = 1
                override fun isEmpty(): Boolean = false
                override fun toLanguageTags(): String = locale.toLanguageTag()
            }
        }
        val ressources = object : Resources(null, null, null) {
            override fun getConfiguration(): Configuration = configuration
        }
        return object : ContextWrapper(null) {
            override fun getResources(): Resources = ressources
            override fun getApplicationContext(): Context = this
        }
    }

    // Les étiquettes passent par Locale.forLanguageTag : la JVM (17 et après) y rend déjà « he » pour « iw »,
    // « yi » pour « ji », « id » pour « in », et met la langue en minuscules. « iw » n'atteint donc jamais
    // ChizukCard.language ici ; sur un téléphone, Locale le rend encore.
    private val etiquettes = listOf("fr", "en", "he", "iw", "de", "es", "ar", "yi", "ji", "in", "id", "ru", "FR", "EN-us",
        "he-IL", "iw-IL", "fr-CA", "zh-Hant-TW", "und", "", "x-prive", "sr-Latn-RS", "es-419")

    // --- Le sac -------------------------------------------------------------------------------------

    /** Le mélange nommé : l'identité, l'ordre inverse, ou kotlin.random.Random(graine), un seul par suite. */
    private fun melange(nom: String, graine: Int?): (List<String>) -> List<String> {
        val identite: (List<String>) -> List<String> = { l -> l }
        val inverse: (List<String>) -> List<String> = { l -> l.reversed() }
        return when (nom) {
            "identite" -> identite
            "inverse" -> inverse
            "graine" -> {
                val r = Random(graine ?: error("mélange semé sans graine"))
                val f: (List<String>) -> List<String> = { l -> l.shuffled(r) }
                f
            }
            else -> error("mélange inconnu : $nom")
        }
    }

    private data class Tirage(val remaining: List<String>, val pool: List<String>, val last: String?, val melange: String, val graine: Int? = null)

    private val quatre = listOf("a", "b", "c", "d")
    private val dix = listOf("un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix")

    private val tirages: List<Tirage> = buildList {
        // Les cas de ChizukBagTest.
        add(Tirage(emptyList(), quatre, "a", "identite"))
        add(Tirage(emptyList(), listOf("a"), "a", "identite"))
        add(Tirage(listOf("a"), emptyList(), null, "identite"))
        add(Tirage(listOf("z", "b"), quatre, null, "identite"))
        add(Tirage(emptyList(), quatre, null, "identite"))
        add(Tirage(listOf("b", "c", "d"), quatre, "a", "identite"))
        // Le sac garde son ordre, ses doublons, et ce que le vivier ne connaît plus en est retiré.
        add(Tirage(listOf("c", "a"), quatre, "d", "identite"))
        add(Tirage(listOf("a", "a", "b"), quatre, null, "identite"))
        add(Tirage(listOf("x", "y"), quatre, "a", "identite"))
        add(Tirage(listOf("x", "y"), quatre, null, "inverse"))
        add(Tirage(listOf("x"), listOf("x"), "x", "identite"))
        add(Tirage(listOf("b", "a"), quatre, "b", "identite"))
        add(Tirage(emptyList(), emptyList(), null, "identite"))
        add(Tirage(emptyList(), emptyList(), "a", "graine", 1))
        add(Tirage(listOf("a", "b"), emptyList(), "a", "inverse"))
        // Le remplissage : le dernier sorti ne rouvre pas le cycle, sauf seul dans le vivier.
        add(Tirage(emptyList(), listOf("a", "a"), "a", "identite"))
        add(Tirage(emptyList(), listOf("a", "b"), "a", "identite"))
        add(Tirage(emptyList(), listOf("a", "b"), "b", "identite"))
        add(Tirage(emptyList(), listOf("a", "b"), "a", "inverse"))
        add(Tirage(emptyList(), listOf("a", "b"), "b", "inverse"))
        add(Tirage(emptyList(), listOf("a", "b", "c"), "x", "identite"))
        add(Tirage(emptyList(), listOf("a", "b", "c"), "a", "identite"))
        add(Tirage(emptyList(), quatre, null, "inverse"))
        add(Tirage(emptyList(), quatre, "d", "inverse"))
        add(Tirage(emptyList(), listOf("a"), null, "inverse"))
        add(Tirage(emptyList(), listOf("a"), "b", "identite"))
        add(Tirage(listOf(""), listOf("", "a"), null, "identite"))
        add(Tirage(emptyList(), listOf("", "a"), "", "identite"))
        add(Tirage(emptyList(), listOf("", "a"), null, "identite"))
        // Kotlin compare les unités UTF-16 : é composé n'est pas é décomposé, ni deux ordres des mêmes signes.
        add(Tirage(emptyList(), listOf("é", "b"), "é", "identite"))
        add(Tirage(emptyList(), listOf("é", "b"), "é", "identite"))
        add(Tirage(listOf("é", "b"), listOf("é", "b"), null, "identite"))
        add(Tirage(listOf("é", "b"), listOf("é", "b"), null, "identite"))
        add(Tirage(emptyList(), listOf("אַשְׁרֵי", "אשרי"), "אַשְׁרֵי", "identite"))
        add(Tirage(emptyList(), listOf("בַּ", "ג"), "בַּ", "identite"))
        add(Tirage(emptyList(), listOf("בַּ", "ג"), "בַּ", "identite"))
        add(Tirage(listOf("בַּ", "ג"), listOf("בַּ", "ג"), null, "identite"))
        // Le mélange semé : sans dernier, puis avec, pour le dernier égal à la tête du mélange (renvoyé en fin).
        for (graine in listOf(0, 1, -1, 7, 42, 2026, Int.MIN_VALUE, Int.MAX_VALUE)) {
            for (pool in listOf(listOf("a", "b"), quatre, dix)) {
                val tete = pool.shuffled(Random(graine)).first()
                add(Tirage(emptyList(), pool, null, "graine", graine))
                add(Tirage(emptyList(), pool, tete, "graine", graine))
                add(Tirage(listOf("x", "y"), pool, tete, "graine", graine))
                add(Tirage(pool.drop(1).reversed() + "x", pool, tete, "graine", graine))
            }
        }
    }

    private fun tirage(t: Tirage): Map<String, Any?> {
        val d = ChizukBag.next(t.remaining, t.pool, t.last, melange(t.melange, t.graine))
        return linkedMapOf("remaining" to t.remaining, "pool" to t.pool, "last" to t.last, "melange" to t.melange,
            "graine" to t.graine, "id" to d.id, "reste" to d.remaining)
    }

    /** Une suite : des phases (un vivier, un nombre de tirages), un seul mélange, le sac et le dernier repassés. */
    private data class Suite(val nom: String, val melange: String, val graine: Int?, val phases: List<Pair<List<String>, Int>>)

    private val suites: List<Suite> = listOf(
        // ChizukBagTest : un cycle sort chaque texte une fois et une seule.
        Suite("cycle", "identite", null, listOf(quatre to 4)),
        Suite("troisCycles", "identite", null, listOf(quatre to 13)),
        Suite("inverse", "inverse", null, listOf(listOf("a", "b", "c") to 10)),
        Suite("seul", "graine", 3, listOf(listOf("a") to 4)),
        Suite("deux", "graine", -3, listOf(listOf("a", "b") to 12)),
        Suite("cinq", "graine", 7, listOf(listOf("a", "b", "c", "d", "e") to 16)),
        Suite("dix", "graine", 42, listOf(dix to 31)),
        // Le vivier change en route : des textes retirés, d'autres ajoutés, puis vidé, puis rendu.
        Suite("vivierQuiChange", "graine", 2026, listOf(
            listOf("a", "b", "c", "d", "e", "f") to 4,
            listOf("c", "d", "e", "f", "g", "h") to 10,
            listOf("h") to 3,
            emptyList<String>() to 2,
            listOf("a", "b", "c", "d", "e", "f") to 7,
        )),
        Suite("vivierQuiChangeIdentite", "identite", null, listOf(
            quatre to 2,
            listOf("d", "c", "b", "a") to 5,
            listOf("e") to 2,
            quatre to 3,
        )),
    )

    /** Rejoue une suite : chaque tirage reçoit le sac restant du précédent et son identifiant comme dernier. */
    private fun rejoue(melange: (List<String>) -> List<String>, phases: List<Pair<List<String>, Int>>): List<ChizukBag.Draw> {
        val sortis = mutableListOf<ChizukBag.Draw>()
        var reste = emptyList<String>()
        var dernier: String? = null
        for ((pool, n) in phases) {
            repeat(n) {
                val d = ChizukBag.next(reste, pool, dernier, melange)
                sortis += d
                reste = d.remaining
                dernier = d.id
            }
        }
        return sortis
    }

    private fun suite(s: Suite): Map<String, Any?> {
        val sortis = rejoue(melange(s.melange, s.graine), s.phases)
        return linkedMapOf("nom" to s.nom, "melange" to s.melange, "graine" to s.graine,
            "phases" to s.phases.map { (pool, n) -> linkedMapOf("pool" to pool, "tirages" to n) },
            "ids" to sortis.map { it.id }, "restes" to sortis.map { it.remaining })
    }

    /** Sur le fichier livré : deux cycles et un tirage par moment, en release, mélangés par Random(100 + rang). */
    private fun suiteDuLivre(m: Moment): Map<String, Any?> {
        val pool = ChizukRules.forMoment(livre, m, false).map { it.id }
        val graine = 100 + m.ordinal
        val sortis = rejoue(melange("graine", graine), listOf(pool to 2 * pool.size + 1))
        return linkedMapOf("moment" to m.key, "debug" to false, "graine" to graine, "tirages" to sortis.size,
            "ids" to sortis.map { it.id }, "tailles" to sortis.map { it.remaining.size })
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursChizuk.kt"),
        "constantes" to linkedMapOf("statutPubliable" to ChizukRules.STATUT_PUBLIABLE),
        "languesDesTextes" to languesDesTextes,
        "livre" to linkedMapOf("version" to livre.version, "items" to livre.items.size),
        "visibles" to visibles(livre),
        "moments" to parMoment(livre),
        "textes" to livre.items.map(::texteLivre),
        "recueils" to recueils.map { (nom, json) -> recueil(nom, json) },
        "gabarit" to gabaritJson,
        "traductions" to langues.map { l -> linkedMapOf("langue" to l, "traduction" to ChizukCard.translationOf(gabarit, l)) },
        "languesDuContexte" to etiquettes.map { e ->
            val locale = Locale.forLanguageTag(e)
            linkedMapOf("etiquette" to e, "langueDuLocale" to locale.language, "langue" to ChizukCard.language(contexte(locale)))
        },
        "tirages" to tirages.map(::tirage),
        "suites" to suites.map(::suite),
        "suitesDuLivre" to Moment.entries.map(::suiteDuLivre),
    )
}
