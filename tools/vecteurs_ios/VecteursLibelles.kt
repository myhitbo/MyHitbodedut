// Les chaînes de l'interface mises en forme comme Android le fait (getString et getQuantityString),
// dans les cinq langues : le juge de Libelle (iOS) et de la conversion des marqueurs par l'export
// (%1$s → %1$@, %d → %lld, %2$02d → %2$02lld). Toutes les chaînes à marqueurs, tous les pluriels.

object VecteursLibelles : Generateur {
    override val fichier = "libelles.json"

    private val langues = listOf("fr", "en", "he", "es", "ar")

    // Les marqueurs de strings.xml : position éventuelle, largeur éventuelle, type.
    private val marqueur = Regex("""%(?:(\d+)\$)?(0?\d+)?([sd%])""")

    // Des valeurs qui montrent la largeur (5 sur deux chiffres donne « 05 ») et l'ordre des arguments.
    private val nombres = listOf(5, 12, 3, 42, 7, 2026)

    private fun valeur(rang: Int, type: Char): Any = if (type == 'd') nombres[(rang - 1) % nombres.size] else "«$rang»"

    /** Les arguments que demande un gabarit, dans l'ordre des positions ; un rang sauté reçoit un texte. */
    private fun arguments(gabarit: String, premier: Int? = null): List<Any> {
        val types = sortedMapOf<Int, Char>()
        var ordinaire = 0
        for (m in marqueur.findAll(gabarit)) {
            val type = m.groupValues[3][0]
            if (type == '%') continue
            val rang = m.groupValues[1].toIntOrNull() ?: ++ordinaire
            types[rang] = type
        }
        if (types.isEmpty()) return emptyList()
        return (1..types.lastKey()).map { rang ->
            val type = types[rang] ?: 's'
            if (rang == 1 && type == 'd' && premier != null) premier else valeur(rang, type)
        }
    }

    private fun ecrit(args: List<Any>) = args.map { if (it is Int) mapOf("entier" to it) else mapOf("texte" to it) }

    private val quantites = listOf(0, 1, 2, 3, 5, 11, 20, 100)

    override fun produire(): Map<String, Any?> {
        val fr = Chaines.de("fr")
        val theatres = langues.associateWith { Theatre(it) }
        val simples = fr.simples.filterValues { marqueur.containsMatchIn(it) }.keys.sorted()
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursLibelles.kt"),
            "simples" to simples.map { cle ->
                val args = arguments(fr.simples.getValue(cle))
                val id = Identifiants.id("string", cle)
                linkedMapOf(
                    "cle" to cle,
                    "arguments" to ecrit(args),
                    "textes" to langues.associateWith { l -> runCatching { theatres.getValue(l).chaine(id, args) }.getOrNull() },
                )
            },
            "pluriels" to fr.pluriels.keys.sorted().flatMap { cle ->
                val formes = fr.pluriels.getValue(cle)
                val id = Identifiants.id("plurals", cle)
                quantites.map { q ->
                    val args = arguments(formes["other"] ?: formes.values.first(), premier = q)
                    linkedMapOf(
                        "cle" to cle,
                        "quantite" to q,
                        "arguments" to ecrit(args),
                        "textes" to langues.associateWith { l ->
                            runCatching { theatres.getValue(l).ressources.getQuantityString(id, q, *args.toTypedArray()) }.getOrNull()
                        },
                    )
                }
            },
        )
    }
}
