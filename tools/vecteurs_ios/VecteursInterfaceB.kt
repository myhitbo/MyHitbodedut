// L'interface (II) devant la JVM : la musique livrée (MusiquePlay), la bibliothèque de morceaux
// (MusicLibrary : noms donnés, renommage, morceaux ajoutés et retirés, ordre, choix), les ambiances
// (clés et libellés ; le son reste à l'app), les tailles de la vignette (WidgetTaille), son décor
// (VignetteDecor), les autorisations (Autorisation, PermissionRules) et l'icône de lancement
// (IconeLanceur). MusiquePlayTests, MusicLibraryTests, AmbianceTests, WidgetTailleTests,
// VignetteDecorTests, AutorisationTests et IconeLanceurTests de Coeur les rejouent.
//
// Les couleurs s'écrivent en entiers ARGB non signés ; un Float d'entrée par ses bits
// (floatToRawIntBits), pour garder NaN, l'infini et le zéro négatif ; un Float rendu, en nombre.
// MusicLibrary tourne sur un Theatre neuf par cas et par opération. Un morceau ajouté demande un
// android.net.Uri, que le jar docile ne sait pas faire (Uri.parse rend null) : UriTexte en est une
// sous-classe minimale, définie dans le paquet android.net, dont toString() rend le texte donné —
// c'est tout ce qu'addUserTrack en lit.

import android.net.Uri
import com.myhitbodedut.Adresse
import com.myhitbodedut.Ambiance
import com.myhitbodedut.Apparence
import com.myhitbodedut.Autorisation
import com.myhitbodedut.IconeLanceur
import com.myhitbodedut.MusicLibrary
import com.myhitbodedut.MusiquePlay
import com.myhitbodedut.PermissionRules
import com.myhitbodedut.Store
import com.myhitbodedut.VignetteDecor
import com.myhitbodedut.WidgetTaille
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import java.lang.invoke.MethodHandles
import kotlin.random.Random
import org.json.JSONObject

object VecteursInterfaceB : Generateur {
    override val fichier = "interface_b.json"

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursInterfaceB.kt"),
        "musique" to musique(),
        "bibliotheque" to bibliotheque(),
        "ambiances" to ambiances(),
        "widgetTailles" to widgetTailles(),
        "vignette" to vignette(),
        "autorisations" to autorisations(),
        "icones" to icones(),
    )

    private fun bits(f: Float): Int = java.lang.Float.floatToRawIntBits(f)
    private fun argb(c: Int): Long = c.toLong() and 0xFFFFFFFFL

    // --- MusiquePlay -------------------------------------------------------------------------

    private fun musique(): List<Any?> = MusiquePlay.MORCEAUX.map {
        linkedMapOf("id" to it.id, "rawRes" to Identifiants.entree(it.rawRes), "titleRes" to Identifiants.entree(it.titleRes))
    }

    // --- MusicLibrary ------------------------------------------------------------------------

    /** Un état des préférences : null laisse la valeur par défaut de Store. */
    private class Etat(val names: String? = null, val userTracks: String? = null, val trackId: String? = null)

    private val ajoutesA = """[{"uri":"content://media/1","title":"Morceau A"},{"uri":"content://media/2","title":""},""" +
        """{"uri":"","title":"vide"},{"title":"sans uri"},{"uri":"   ","title":"blanc"},5,null,"texte",[1],""" +
        """{"uri":"content://media/3"},{"uri":null,"title":"nul"},{"uri":7,"title":"sept"},{"uri":"content://media/4","title":null}]"""

    private val etats: List<Etat> = listOf(
        Etat(),
        Etat(names = """{"hamelech_basade":"Mon niggoun"}"""),
        Etat(names = """{"hamelech_basade":"   ","shpayer_beyond":""}"""),
        Etat(names = """{"hamelech_basade":null,"shpayer_beyond":5,"ianir_hello":2.5,"ianir_mirage":true,""" +
            """"shpayer_pnima":{"a":1},"shpayer_kenout":[1]}"""),
        Etat(names = "pas du json"),
        Etat(names = """["hamelech_basade"]"""),
        Etat(names = ""),
        Etat(names = """{"hamelech_basade":"Premier"} reste"""),
        Etat(names = """{"hamelech_basade":"a","shpayer_beyond":"b","hamelech_basade":"c"}"""),
        Etat(names = """{"yanuka_nigoun_3":"נִגּוּן שֶׁל הַיָּנוּקָא","shpayer_afilou":"a\/b é \"q\" \\ fin"}"""),
        Etat(names = """  { "ianir_bessarabie" : "Espacé" , "content://media/1" : "Nommé" }  """),
        Etat(userTracks = ajoutesA),
        Etat(names = """{"content://media/1":"  ","content://media/3":"Trois"}""", userTracks = ajoutesA, trackId = "content://media/3"),
        Etat(names = """{"content://a":"Renommé"}""", userTracks = """[{"uri":"content://a","title":"A"}]""", trackId = "content://a"),
        Etat(userTracks = """[{"uri":"hamelech_basade","title":"Doublon"}]""", trackId = "hamelech_basade"),
        Etat(userTracks = "{}"),
        Etat(userTracks = "garbage"),
        Etat(userTracks = ""),
        Etat(userTracks = """[{"uri":"content://x","title":"X"}] reste""", trackId = "content://x"),
        Etat(trackId = "shpayer_pnima"),
        Etat(trackId = "inconnu"),
        Etat(trackId = ""),
        Etat(userTracks = """[{"uri":"content://b","title":"B"}]""", trackId = "content://b"),
        Etat(userTracks = """[{"uri":"content://b","title":"B"},{"uri":"content://b","title":"B2"}]""", trackId = "null"),
        Etat(names = """{"content://מוזיקה/1":"שִׁיר 🎵"}""",
            userTracks = """[{"uri":"content://מוזיקה/1","title":"ניגון"},{"uri":"content://é","title":"é décomposé"}]"""),
        Etat(names = "{}", userTracks = "  [ ]  ", trackId = "ianir_bessarabie"),
        Etat(userTracks = """[{"uri":"null","title":"Le mot null"}]""", trackId = "null"),
        // Une liste illisible : un retrait n'y touche pas, et le morceau choisi le reste.
        Etat(userTracks = "garbage", trackId = "content://a"),
    )

    // « content://é » composé (U+00E9) et décomposé (e, U+0301) : pour Kotlin deux adresses, que l'égalité
    // canonique de Swift confondrait (le cas des deux formes figure plus haut, parmi les morceaux ajoutés).
    private val eCompose = "content://\u00e9"
    private val eDecompose = "content://e\u0301"

    private val renommages = listOf(
        "hamelech_basade" to "Nouveau", "hamelech_basade" to "", "hamelech_basade" to "  ", "shpayer_beyond" to "X/Y \"z\"",
        "content://a" to "Renommé 2", "nouveau_id" to "נִגּוּן", "content://media/1" to "\t\n",
    )
    private val ajouts = listOf(
        "content://media/1" to "Encore", "content://new" to "Nouveau", "content://new" to "", "null" to "n", "7" to "sept",
        "content://b" to "B3", eCompose to "composé", eDecompose to "décomposé",
    )
    private val retraits = listOf("content://media/1", "content://a", "absent", "null", "content://b", "hamelech_basade", "7", "",
        eCompose, eDecompose)
    private val recherches = listOf(null, "", "hamelech_basade", "content://a", "content://media/3", "inconnu", "null", "7",
        eCompose, eDecompose)
    private val noms = listOf("hamelech_basade", "shpayer_beyond", "ianir_hello", "shpayer_pnima", "content://media/1", "content://a", "inconnu")

    private fun theatre(e: Etat): Theatre {
        val t = Theatre()
        val ctx = t.contexte
        e.names?.let { Store.setMusicNames(ctx, it) }
        e.userTracks?.let { Store.setMusicUserTracks(ctx, it) }
        e.trackId?.let { Store.setMusicTrackId(ctx, it) }
        return t
    }

    /** Un morceau livré sans nom donné : son id seul ; tout autre : [id, titre, livré]. */
    private fun morceau(t: Theatre, m: com.myhitbodedut.Track): Any =
        if (m.isBundled && MusicLibrary.customName(t.contexte, m.id) == null) m.id else listOf(m.id, m.title, m.isBundled)

    private fun bibliotheque(): Map<String, Any?> {
        val premier = theatre(Etat())
        val cas = etats.map { e ->
            val t = theatre(e)
            val ctx = t.contexte
            linkedMapOf(
                "names" to Store.musicNames(ctx),
                "userTracks" to Store.musicUserTracks(ctx),
                "trackId" to Store.musicTrackId(ctx),
                "tous" to MusicLibrary.all(ctx).map { morceau(t, it) },
                "selected" to MusicLibrary.selected(ctx)?.id,
                "byId" to recherches.map { r -> MusicLibrary.byId(ctx, r).let { listOf(r, it?.id, it?.title) } },
                "customName" to noms.map { listOf(it, MusicLibrary.customName(ctx, it)) },
                "rename" to renommages.map { (id, titre) ->
                    val u = theatre(e)
                    MusicLibrary.rename(u.contexte, id, titre)
                    listOf(id, titre, Store.musicNames(u.contexte))
                },
                "addUserTrack" to ajouts.map { (adresse, titre) ->
                    val u = theatre(e)
                    MusicLibrary.addUserTrack(u.contexte, uri(adresse), titre)
                    listOf(adresse, titre, Store.musicUserTracks(u.contexte))
                },
                "removeUserTrack" to retraits.map { id ->
                    val u = theatre(e)
                    MusicLibrary.removeUserTrack(u.contexte, id)
                    listOf(id, Store.musicUserTracks(u.contexte), Store.musicTrackId(u.contexte))
                },
            )
        }
        return linkedMapOf(
            // Les titres livrés, en français, tels que les rend getString.
            "titresLivres" to MusicLibrary.all(premier.contexte).map { listOf(it.id, it.title) },
            "cas" to cas,
        )
    }

    /** android.net.UriTexte : une sous-classe d'Uri dont toString() rend le texte donné. */
    private val classeUri: Class<*> by lazy {
        val octets = ByteArrayOutputStream()
        DataOutputStream(octets).run {
            fun utf8(s: String) { writeByte(1); writeUTF(s) }
            writeInt(0xCAFEBABE.toInt()); writeShort(0); writeShort(52)
            writeShort(17)
            utf8("android/net/UriTexte")                    // 1
            writeByte(7); writeShort(1)                     // 2 : la classe
            utf8("android/net/Uri")                         // 3
            writeByte(7); writeShort(3)                     // 4 : Uri
            utf8("s")                                       // 5
            utf8("Ljava/lang/String;")                      // 6
            utf8("<init>")                                  // 7
            utf8("(Ljava/lang/String;)V")                   // 8
            utf8("()V")                                     // 9
            writeByte(12); writeShort(7); writeShort(9)     // 10 : <init> ()V
            writeByte(10); writeShort(4); writeShort(10)    // 11 : Uri.<init>()V
            writeByte(12); writeShort(5); writeShort(6)     // 12 : s String
            writeByte(9); writeShort(2); writeShort(12)     // 13 : UriTexte.s
            utf8("Code")                                    // 14
            utf8("toString")                                // 15
            utf8("()Ljava/lang/String;")                    // 16
            writeShort(0x0031); writeShort(2); writeShort(4)
            writeShort(0)
            writeShort(1); writeShort(0x0012); writeShort(5); writeShort(6); writeShort(0)
            writeShort(2)
            writeShort(0x0001); writeShort(7); writeShort(8); writeShort(1)
            writeShort(14); writeInt(22); writeShort(2); writeShort(2); writeInt(10)
            write(byteArrayOf(0x2A, 0xB7.toByte(), 0, 11, 0x2A, 0x2B, 0xB5.toByte(), 0, 13, 0xB1.toByte()))
            writeShort(0); writeShort(0)
            writeShort(0x0001); writeShort(15); writeShort(16); writeShort(1)
            writeShort(14); writeInt(17); writeShort(1); writeShort(1); writeInt(5)
            write(byteArrayOf(0x2A, 0xB4.toByte(), 0, 13, 0xB0.toByte()))
            writeShort(0); writeShort(0)
            writeShort(0)
        }
        // Lookup.defineClass n'est pas dans android.jar, contre lequel on compile : on l'appelle par réflexion.
        val acces = MethodHandles.privateLookupIn(Uri::class.java, MethodHandles.lookup())
        MethodHandles.Lookup::class.java.getMethod("defineClass", ByteArray::class.java).invoke(acces, octets.toByteArray()) as Class<*>
    }

    private fun uri(texte: String): Uri = classeUri.getConstructor(String::class.java).newInstance(texte) as Uri

    // --- Ambiance ----------------------------------------------------------------------------

    private fun ambiances(): Map<String, Any?> = linkedMapOf(
        "entrees" to Ambiance.entries.map { linkedMapOf("nom" to it.name, "cle" to it.cle, "titre" to Identifiants.entree(it.titre)) },
        "of" to listOf(null, "", "silence", "pluie", "mer", "foret", "feu", "nuit", "orage", "PLUIE", " pluie", "pluie ",
            "forêt", "Silence", "nuit\u0000", "mer\n", "pluie​").map { listOf(it, Ambiance.of(it).name) },
    )

    // --- WidgetTaille ------------------------------------------------------------------------

    private fun widgetTailles(): Map<String, Any?> {
        val valeurs = listOf(-1f, -0f, 0f, 39.99f, 40f, 40.01f, 70f, 109.99f, 110f, 150f, 159.99f, 160f, 249.99f, 250f,
            300f, 320f, 1000f, Float.NaN, Float.POSITIVE_INFINITY, Float.NEGATIVE_INFINITY)
        return linkedMapOf(
            "entrees" to WidgetTaille.entries.map {
                linkedMapOf("nom" to it.name, "largeurMin" to it.largeurMin, "hauteurMin" to it.hauteurMin,
                    "largeurType" to it.largeurType, "hauteurType" to it.hauteurType)
            },
            "pour" to valeurs.flatMap { l -> valeurs.map { h -> listOf(bits(l), bits(h), WidgetTaille.pour(l, h).name) } },
        )
    }

    // --- VignetteDecor -----------------------------------------------------------------------

    private fun vignette(): Map<String, Any?> {
        val couleurs = listOf(0x00000000, 0xFFFFFFFF.toInt(), 0xFF000000.toInt(), 0x80FFFFFF.toInt(), 0xFF16775A.toInt(),
            0xFF173C32.toInt(), 0x7F123456, 0x01FEFDFC)
        val parts = listOf(0f, 1f, 0.5f, 0.2f, 0.45f, 0.35f, 0.05f, -0.5f, 1.5f, 1f / 3, Float.POSITIVE_INFINITY, -0f)
        val hasard = Random(20261115)
        val melanges = couleurs.flatMap { a -> couleurs.flatMap { b -> parts.map { t -> Triple(a, b, t) } } } +
            (1..150).map { Triple(hasard.nextInt(), hasard.nextInt(), hasard.nextFloat() * 1.4f - 0.2f) }
        val alphas = listOf(0f, 1f, 0.5f, 128 / 255f, 127.5f / 255f, 1 / 255f, 0.05f, 0.18f, 0.24f, -1f, 2f,
            Float.POSITIVE_INFINITY, Float.NEGATIVE_INFINITY, 0.999f)
        // Les bouts de dégradé des palettes de l'app (day_done, brand_dark), puis des couleurs au hasard.
        val palettes = JSONObject(File(DEPOT, "ios/Ressources/Contenu/palettes.json").readText()).getJSONObject("modes")
        fun hex(s: String): Int = (0xFF shl 24) or s.removePrefix("#").toInt(16)
        val paires = Apparence.Accent.values().map { a ->
            val p = palettes.getJSONObject("jour").getJSONObject("vert/${a.cle}")
            hex(p.getString("day_done")) to hex(p.getString("brand_dark"))
        } + (1..40).map { hasard.nextInt() to hasard.nextInt() }
        val cotes = listOf(-5f, 0f, 0.5f, 1f, 40f, 75f, 150f, 320f, 1000f, 5000f)
        val densites = listOf(-1f, 0f, 0.5f, 1f, 2.625f, 3.5f, 4f)
        val pixels = cotes.flatMap { l -> cotes.flatMap { h -> densites.map { d -> listOf(l, h, d, VignetteDecor.COTE_MAX) } } } +
            listOf(0, 1, 100, -5, 1000).flatMap { m -> listOf(150f to 75f, 320f to 320f, 1f to 5000f).map { (l, h) -> listOf(l, h, 2f, m) } } +
            WidgetTaille.entries.flatMap { t -> listOf(1f, 2.625f, 3.5f, 4f).map { listOf(t.largeurType, t.hauteurType, it, VignetteDecor.COTE_MAX) } }
        return linkedMapOf(
            "constantes" to linkedMapOf(
                "departJour" to VignetteDecor.DEPART_JOUR, "departNuit" to VignetteDecor.DEPART_NUIT,
                "noirNuit" to VignetteDecor.NOIR_NUIT, "arcExterieur" to VignetteDecor.ARC_EXTERIEUR,
                "arcInterieur" to VignetteDecor.ARC_INTERIEUR, "halo" to VignetteDecor.HALO, "lisere" to VignetteDecor.LISERE,
                "voilePanneau" to VignetteDecor.VOILE_PANNEAU, "voileBadge" to VignetteDecor.VOILE_BADGE,
                "voileAnneaux" to VignetteDecor.VOILE_ANNEAUX, "coteMax" to VignetteDecor.COTE_MAX,
                "blanc" to argb(VignetteDecor.BLANC), "noir" to argb(VignetteDecor.NOIR),
            ),
            "melange" to melanges.map { (a, b, t) -> listOf(argb(a), argb(b), bits(t), argb(VignetteDecor.melange(a, b, t))) },
            "opacite" to couleurs.flatMap { c -> alphas.map { a -> listOf(argb(c), bits(a), argb(VignetteDecor.opacite(c, a))) } },
            "degrade" to paires.flatMap { (j, b) ->
                listOf(false, true).map { nuit ->
                    val (clair, fonce) = VignetteDecor.degrade(j, b, nuit)
                    listOf(argb(j), argb(b), nuit, argb(clair), argb(fonce), argb(VignetteDecor.pireFond(j, b, nuit)))
                }
            },
            // Une entrée dont le calcul lèverait (NaN arrondi) n'est pas écrite : il n'y en a pas ici.
            "pixels" to pixels.map { c ->
                val (l, h, d) = c.map { (it as Number).toFloat() }
                val m = c[3] as Int
                val (pl, ph) = VignetteDecor.pixels(l, h, d, m)
                listOf(bits(l), bits(h), bits(d), m, pl, ph)
            },
        )
    }

    // --- Autorisation ------------------------------------------------------------------------

    private fun autorisations(): Map<String, Any?> {
        val toutes = Autorisation.values().toList()
        return linkedMapOf(
            "entrees" to toutes.map {
                linkedMapOf("nom" to it.name, "cle" to it.cle, "titre" to Identifiants.entree(it.titre),
                    "pourquoi" to Identifiants.entree(it.pourquoi), "barriere" to it.barriere)
            },
            "demandees" to listOf(true, false).map { avec -> listOf(avec, PermissionRules.demandees(avec).map { it.name }) },
            // Les accordées par un masque : le bit i pour la i-ième autorisation.
            "manquantes" to listOf(true, false).flatMap { avec ->
                (0 until (1 shl toutes.size)).map { masque ->
                    listOf(avec, masque, PermissionRules.manquantes(avec) { masque and (1 shl it.ordinal) != 0 }.map { it.name })
                }
            },
        )
    }

    // --- IconeLanceur ------------------------------------------------------------------------

    private fun icones(): Map<String, Any?> {
        val couleurs = File(RES, "values/colors.xml").readText()
        return linkedMapOf(
            "parDefaut" to IconeLanceur.PAR_DEFAUT,
            "tous" to IconeLanceur.tous(),
            "alias" to listOf(null, Adresse.HOMME, Adresse.FEMME).flatMap { ad ->
                Apparence.Accent.values().map { a -> listOf(ad?.cle, a.cle, IconeLanceur.alias(ad, a)) }
            },
            // La plaque de chaque icône (res/values/colors.xml, icone_fond_<accent>), comme la lit IconeLanceurTest.
            "plaques" to Apparence.Accent.values().map { a ->
                val hex = Regex("""<color name="icone_fond_${a.cle}">#([0-9A-Fa-f]{6})</color>""").find(couleurs)!!.groupValues[1]
                listOf(a.cle, "#" + hex.uppercase())
            },
        )
    }
}
