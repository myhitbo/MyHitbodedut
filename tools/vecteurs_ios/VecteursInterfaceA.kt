// Les tables et les règles pures de l'interface (grappe I) : le personnage au féminin (Personnage.kt),
// la présentation du premier lancement (Onboarding.kt), les dix conseils (Tips.kt), les polices des
// textes saints et leurs signes absents (PoliceHebraique.kt), les libellés nommés par clé (Libelles.kt)
// et les langues de l'application (Langues.kt). Une ressource s'écrit par son nom
// (Identifiants.entree) : c'est la clé des chaînes d'iOS et le nom de ses images.

import com.myhitbodedut.Adresse
import com.myhitbodedut.Langues
import com.myhitbodedut.Libelles
import com.myhitbodedut.Onboarding
import com.myhitbodedut.Personnage
import com.myhitbodedut.PoliceHebraique
import com.myhitbodedut.R
import com.myhitbodedut.Store
import com.myhitbodedut.Tips
import java.io.File

object VecteursInterfaceA : Generateur {
    override val fichier = "interface_a.json"

    /** Une table privée d'un objet Kotlin (son champ statique), lue telle que l'app la tient en mémoire. */
    private fun champ(classe: Class<*>, nom: String): Any? =
        classe.getDeclaredField(nom).apply { isAccessible = true }.get(null)

    /** Les ressources d'un type de R, triées par nom. */
    private fun ressources(type: Class<*>): List<Pair<String, Int>> =
        type.fields.map { it.name to it.getInt(null) }.sortedBy { it.first }

    private fun nom(id: Int): String = Identifiants.entree(id)

    // --- Personnage.kt ----------------------------------------------------------------------------

    private fun personnageTable(): List<Map<String, Any?>> {
        @Suppress("UNCHECKED_CAST")
        val table = champ(Personnage::class.java, "FEMININ") as Map<Int, Int>
        check(table.isNotEmpty()) { "Personnage.FEMININ vide" }
        return table.entries.map { (hassid, feminine) -> linkedMapOf("hassid" to nom(hassid), "feminine" to nom(feminine)) }
    }

    /** Chaque dessin de l'app, au féminin, puis par Personnage.pour sous chacune des adresses du vrai Store. */
    private fun personnageDessins(): List<Map<String, Any?>> {
        val mondes = listOf<Adresse?>(null, Adresse.HOMME, Adresse.FEMME).map { adresse ->
            Theatre().contexte.also { c -> if (adresse != null) Store.setAdresse(c, adresse) }
        }
        val (aucune, homme, femme) = mondes
        check(Store.adresse(femme) == Adresse.FEMME && Store.adresse(aucune) == null)
        return ressources(R.drawable::class.java).map { (dessin, id) ->
            linkedMapOf("dessin" to dessin, "feminin" to nom(Personnage.feminin(id)),
                "pourAucune" to nom(Personnage.pour(aucune, id)), "pourHomme" to nom(Personnage.pour(homme, id)),
                "pourFemme" to nom(Personnage.pour(femme, id)))
        }
    }

    // --- Onboarding.kt ----------------------------------------------------------------------------

    /** Les bornes du parcours, et celles d'un Int de Kotlin : index + 1 y déborde en silence. */
    private val indices: List<Int> = listOf(Int.MIN_VALUE, Int.MIN_VALUE + 1, -1000, -50, -9, -3, -2, -1) +
        (0..9).toList() + listOf(50, 1000, Int.MAX_VALUE - 1, Int.MAX_VALUE)

    private fun onboardingEcrans(): List<Map<String, Any?>> = Onboarding.ECRANS.map { e ->
        linkedMapOf("cle" to e.cle, "titre" to nom(e.titre), "corps" to nom(e.corps), "illustration" to nom(e.illustration),
            "choixAdresse" to e.choixAdresse, "choixDuree" to e.choixDuree, "choixRappel" to e.choixRappel)
    }

    private fun onboardingParcours(): List<Map<String, Any?>> = indices.map { i ->
        linkedMapOf("index" to i, "ecran" to Onboarding.ecran(i).cle, "suivant" to Onboarding.suivant(i),
            "precedent" to Onboarding.precedent(i), "estPremier" to Onboarding.estPremier(i), "estDernier" to Onboarding.estDernier(i))
    }

    // --- PoliceHebraique.kt -----------------------------------------------------------------------

    /** Les signes que rend le Masque d'une police (getOriginal, getReplacement), en unités UTF-16. */
    private fun unites(masque: Any, methode: String): List<Int> =
        (masque.javaClass.getDeclaredMethod(methode).apply { isAccessible = true }.invoke(masque) as CharArray).map { it.code }

    private val masques: Map<PoliceHebraique.Police, Any> by lazy {
        @Suppress("UNCHECKED_CAST")
        val table = champ(PoliceHebraique::class.java, "ABSENTS") as Map<PoliceHebraique.Police, Any>
        check(table.isNotEmpty()) { "PoliceHebraique.ABSENTS vide" }
        table
    }

    private fun polices(): List<Map<String, Any?>> = PoliceHebraique.Police.entries.map { p ->
        val m = masques[p]
        linkedMapOf("nom" to p.name, "cle" to p.cle, "libelle" to nom(p.libelle),
            "absents" to m?.let { unites(it, "getOriginal") }, "remplacements" to m?.let { unites(it, "getReplacement") })
    }

    /**
     * ReplacementCharSequence.charAt d'AOSP (android.text.method), ce que fait ReplacementTransformationMethod
     * à l'affichage : chaque unité égale à original[j] devient replacement[j]. L'android.jar docile ne fait pas
     * ce travail du système ; il se refait ici, à l'identique, sur les tableaux que rend le vrai Masque.
     */
    private fun transforme(texte: String, original: List<Int>, remplacement: List<Int>): String =
        String(CharArray(texte.length) { i ->
            var c = texte[i]
            for (j in original.indices) if (c.code == original[j]) c = remplacement[j].toChar()
            c
        })

    /** Une fenêtre d'un vrai texte de res/raw autour de la première unité de [cibles]. */
    private fun fenetre(fichier: String, cibles: CharRange): String {
        val texte = File(RES, "raw/$fichier").readText()
        val i = texte.indexOfFirst { it in cibles }
        check(i >= 0) { "$fichier : aucun signe de $cibles" }
        return texte.substring(maxOf(0, i - 40), minOf(texte.length, i + 80))
    }

    private fun echantillons(): List<Pair<String, String>> = listOf(
        "bloc hébreu U+0590–U+05FF, entouré" to ("a " + (0x0590..0x05FF).map { it.toChar() }.joinToString("") + " ͏ z"),
        "vide" to "",
        "sans hébreu" to "Hitbodedout, 10 min — « שלום »",
        "paire de substitution et meteg" to "😀ֽאֽ",
        "te'amim, siddur_edot.json" to fenetre("siddur_edot.json", '֑'..'֯'),
        "meteg, siddur_edot.json" to fenetre("siddur_edot.json", 'ֽ'..'ֽ'),
        "te'amim, siddur_ashkenaz.json" to fenetre("siddur_ashkenaz.json", '֑'..'֯'),
        "rafé, hilloulot.json" to fenetre("hilloulot.json", 'ֿ'..'ֿ'),
    )

    private fun masquages(): List<Map<String, Any?>> = echantillons().map { (nom, texte) ->
        linkedMapOf("nom" to nom, "texte" to texte.map { it.code },
            "polices" to PoliceHebraique.Police.entries.associateTo(linkedMapOf()) { p ->
                val m = masques[p]
                p.cle to (if (m == null) texte else transforme(texte, unites(m, "getOriginal"), unites(m, "getReplacement"))).map { it.code }
            })
    }

    // --- Libelles.kt ------------------------------------------------------------------------------

    /** Les clés de la table, lues dans le source (« "clé" -> R.string.nom ») : arrêt si rien n'est trouvé. */
    private fun clesDuSource(): List<String> {
        val source = File(DEPOT, "android/app/src/main/java/com/myhitbodedut/Libelles.kt").readText()
        val cles = Regex("\"([a-z0-9_]+)\" -> R\\.string\\.").findAll(source).map { it.groupValues[1] }.toList()
        check(cles.size >= 100) { "Libelles.kt : ${cles.size} clés lues" }
        return cles
    }

    private val sondesLibelles = listOf("", " ", "ajout", "ajout_", "fete_", "zman_", "ZMAN_ALOT", "Zman_alot", " zman_alot",
        "zman_alot ", "zman_alot\n", "zman_alot\u0000", "zman_alot​", "zman-alot", "zman_alot_", "fete_pessah_", "fete_pessa",
        "fête_pessah", "fête_pessah", "ajout_jour_0", "ajout_jour_7", "ajout_embolismique_avant", "R.string.zman_alot",
        "זמן", "tip_1_title", "police_serif")

    /** Chaque clé de la table, puis chaque chaîne de l'app, puis des clés voisines : ce que rend Libelles.res. */
    private fun libelles(): List<Map<String, Any?>> {
        val cles = LinkedHashSet<String>()
        cles.addAll(clesDuSource())
        cles.addAll(ressources(R.string::class.java).map { it.first })
        cles.addAll(sondesLibelles)
        return cles.map { cle -> linkedMapOf("cle" to cle, "res" to Libelles.res(cle)?.let(::nom)) }
    }

    // --- Langues.kt -------------------------------------------------------------------------------

    private val etiquettes = listOf<String?>(null, "", "he", "iw", "he-IL", "iw_IL", "fr-CA", "en-US", "de", "fr", "en", "es-ES",
        "FR", "EN-us", "He", "IW", "HE-il", "iW", "hE", "-fr", "_en", "fr-", "en_", "-", "_", "-_", "_-", "he_IL-x", "iw-IL_y",
        "zh-Hant-TW", "pt_BR", "x", "iw-", "hebrew", "heb", "ivrit", " he", "he ", "fr\u0000", "fr,en", "fr-FR,en", "he,fr",
        "en-GB", "en_US_POSIX", "fra", "eng", "Fr_fr", "fR-Latn", "İW", "ıw", "ＦＲ", "ｈｅ",
        "eń", "én", "עברית", "English", "Français", "Ken", "Σ", "iw​")

    private fun langues(): List<Map<String, Any?>> = etiquettes.map { e ->
        linkedMapOf("etiquette" to e, "normalise" to Langues.normalise(e), "nomDe" to Langues.nomDe(e), "indexDe" to Langues.indexDe(e))
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to linkedMapOf("source" to "tools/vecteurs_ios/VecteursInterfaceA.kt",
            "personnageTable" to "Personnage.FEMININ, dans son ordre (champ privé lu par réflexion)",
            "personnageDessins" to "chaque R.drawable : Personnage.feminin, puis Personnage.pour sans adresse, en צדיק, en צדקת (Store.setAdresse)",
            "masquages" to "ReplacementCharSequence.charAt d'AOSP refait sur les tableaux du vrai Masque (getOriginal, getReplacement) ; SANS : sans masque",
            "libelles" to "Libelles.res de chaque clé du source, de chaque R.string, puis de clés voisines ; null : hors table"),
        "personnageTable" to personnageTable(),
        "personnageDessins" to personnageDessins(),
        "onboarding" to linkedMapOf("version" to Onboarding.VERSION, "durees" to Onboarding.DUREES.toList(), "dernier" to Onboarding.DERNIER),
        "onboardingEcrans" to onboardingEcrans(),
        "onboardingParcours" to onboardingParcours(),
        "tips" to Tips.ALL.map { t ->
            linkedMapOf("number" to t.number, "titleRes" to nom(t.titleRes), "bodyRes" to nom(t.bodyRes), "art" to nom(t.art))
        },
        "polices" to polices(),
        "teamim" to (champ(PoliceHebraique::class.java, "TEAMIM") as String).map { it.code },
        "masquages" to masquages(),
        "libelles" to libelles(),
        "languesToutes" to Langues.TOUTES.map { linkedMapOf("etiquette" to it.etiquette, "nom" to it.nom) },
        "languesDefaut" to Langues.DEFAUT,
        "langues" to langues(),
    )
}
