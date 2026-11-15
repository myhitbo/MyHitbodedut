// La normalisation de la recherche (RechercheGlobale.nu) devant la JVM : une liste de cas communs que
// tools/export_contenu/recherche.py (l'index recherche.sqlite) et RechercheGlobale.swift doivent rendre
// à l'identique (ROADMAP, tâche 6). Hébreu vocalisé et cantillé, maqaf et paseq, geresh et gershayim,
// balises, accents latins, blancs d'Unicode, casse.

import com.myhitbodedut.RechercheGlobale

object VecteursNormalisation : Generateur {
    override val fichier = "normalisation.json"

    private val cas = listOf(
        "בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים",
        "שִׁיר־הַמַּעֲלוֹת",
        "וַיֹּ֣אמֶר ׀ ה׳",
        "רש\"י ורמב״ם",
        "ר' נחמן מברסלב",
        "<b>אַשְׁרֵי</b> יוֹשְׁבֵי<br/>בֵיתֶךָ",
        "Likoutei Moharan II, 25",
        "Éléphant Ça Où Noël",
        "L’homme et l‘âme",
        "  plusieurs \t\n blancs  ",
        " insécable ",
        " cadratin　",
        "ŒUVRE Æther straße ẞ",
        "ΟΔΟΣ Σοφία",
        "İstanbul IJssel",
        "ﬁn ﬂeur",
        "x́ÿ",
        "Tehilim 119:1-96",
        "תְּהִלִּים קיט",
        "🙂 émoji",
        "",
        "   ",
        "שָׁלוֹםֽעֲלֵיכֶםׅׄ",
        "a<b",
        "<i>fin</i>",
        "Rabbi Na'hman 'Hizouk",
    )

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursNormalisation.kt"),
        "cas" to cas.map { listOf(it, RechercheGlobale.nu(it)) },
    )
}
