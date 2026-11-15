// Les fichiers de vecteurs : du JSON écrit toujours de la même façon (ordre des clés gardé, un cas
// par ligne), pour que deux passes donnent les mêmes octets et que git montre ce qui a bougé.

import java.io.File

/** Un générateur de vecteurs : un fichier de tools/vecteurs_ios, un objet du même nom. */
interface Generateur {
    /** Le nom du fichier produit, sans dossier : « socle.json ». */
    val fichier: String

    /** Le contenu : des Map (ordre d'insertion gardé), List, String, nombres, Boolean et null. */
    fun produire(): Map<String, Any?>
}

object Ecrit {
    /** Les clés de la racine une par ligne ; les éléments d'une liste de premier niveau aussi. */
    fun fichier(cible: File, racine: Map<String, Any?>) {
        val sb = StringBuilder("{\n")
        racine.entries.forEachIndexed { i, (cle, valeur) ->
            chaine(sb, cle)
            sb.append(": ")
            if (valeur is List<*> && valeur.isNotEmpty()) {
                sb.append("[\n")
                valeur.forEachIndexed { j, element ->
                    json(sb, element)
                    sb.append(if (j < valeur.size - 1) ",\n" else "\n")
                }
                sb.append("]")
            } else json(sb, valeur)
            sb.append(if (i < racine.size - 1) ",\n" else "\n")
        }
        sb.append("}\n")
        cible.parentFile.mkdirs()
        cible.writeText(sb.toString(), Charsets.UTF_8)
    }

    fun json(sb: StringBuilder, v: Any?) {
        when (v) {
            null -> sb.append("null")
            is String -> chaine(sb, v)
            is Boolean -> sb.append(v)
            is Int, is Long, is Short, is Byte -> sb.append(v)
            is Float -> nombre(sb, v.toDouble())
            is Double -> nombre(sb, v)
            is Map<*, *> -> {
                sb.append('{')
                var premier = true
                for ((cle, valeur) in v) {
                    if (!premier) sb.append(", ")
                    premier = false
                    chaine(sb, cle as String)
                    sb.append(": ")
                    json(sb, valeur)
                }
                sb.append('}')
            }
            is Iterable<*> -> {
                sb.append('[')
                var premier = true
                for (e in v) {
                    if (!premier) sb.append(", ")
                    premier = false
                    json(sb, e)
                }
                sb.append(']')
            }
            is Array<*> -> json(sb, v.toList())
            is IntArray -> json(sb, v.toList())
            is LongArray -> json(sb, v.toList())
            is DoubleArray -> json(sb, v.toList())
            is Char -> chaine(sb, v.toString())
            is Enum<*> -> chaine(sb, v.name)
            else -> error("valeur non écrite en JSON : ${v::class} ($v)")
        }
    }

    private fun nombre(sb: StringBuilder, d: Double) {
        check(d.isFinite()) { "nombre non fini dans un vecteur : $d" }
        // Un entier exact s'écrit sans « .0 » ni exposant ; sinon la forme de Java, relue à l'identique.
        // Le zéro négatif garde son signe.
        if (d == 0.0 && 1.0 / d < 0) sb.append("-0.0")
        else if (d == Math.rint(d) && Math.abs(d) < 1e15) sb.append(d.toLong()) else sb.append(d)
    }

    private fun chaine(sb: StringBuilder, s: String) {
        sb.append('"')
        for (c in s) {
            when {
                c == '"' -> sb.append("\\\"")
                c == '\\' -> sb.append("\\\\")
                c == '\n' -> sb.append("\\n")
                c == '\r' -> sb.append("\\r")
                c == '\t' -> sb.append("\\t")
                c < ' ' || c == '\u007f' || c == ' ' || c == ' ' || Character.isSurrogate(c) && false ->
                    sb.append("\\u").append("%04x".format(c.code))
                else -> sb.append(c)
            }
        }
        sb.append('"')
    }
}
