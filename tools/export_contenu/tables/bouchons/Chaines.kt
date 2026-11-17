// Les strings.xml de l'app, lus comme aapt les compile (tools/export_contenu/export.py fait de
// même pour iOS) : entités, guillemets, échappements, espaces ASCII ramenés à un seul.

import java.io.File

class Chaines(val simples: Map<String, String>, val pluriels: Map<String, Map<String, String>>, val tableaux: Map<String, List<String>>) {
    companion object {
        private val dossiers = mapOf("fr" to "values", "en" to "values-en", "he" to "values-iw", "es" to "values-es",
            "ar" to "values-ar-rTN")
        private val lues = HashMap<String, Chaines>()

        /** Les chaînes d'une langue ; ce qu'elle ne traduit pas retombe sur le français, le défaut d'Android. */
        fun de(langue: String): Chaines = lues.getOrPut(langue) {
            val defaut = lire(File(RES, "values/strings.xml"))
            if (langue == "fr") defaut else {
                val l = lire(File(RES, "${dossiers[langue] ?: error("langue inconnue : $langue")}/strings.xml"))
                Chaines(defaut.simples + l.simples, defaut.pluriels + l.pluriels, defaut.tableaux + l.tableaux)
            }
        }

        private val commentaire = Regex("<!--.*?-->", RegexOption.DOT_MATCHES_ALL)
        private val nomAttr = Regex("""name="([^"]*)"""")

        fun lire(fichier: File): Chaines {
            val xml = fichier.readText().replace(commentaire, "")
            fun nom(attrs: String) = nomAttr.find(attrs)!!.groupValues[1]
            val simples = LinkedHashMap<String, String>()
            Regex("""<string\b(?!-)([^>]*?)(?:/>|>(.*?)</string>)""", RegexOption.DOT_MATCHES_ALL).findAll(xml)
                .forEach { simples[nom(it.groupValues[1])] = valeur(it.groupValues[2]) }
            val pluriels = LinkedHashMap<String, Map<String, String>>()
            Regex("""<plurals\b([^>]*)>(.*?)</plurals>""", RegexOption.DOT_MATCHES_ALL).findAll(xml).forEach { p ->
                pluriels[nom(p.groupValues[1])] =
                    Regex("""<item\b[^>]*quantity="([^"]*)"[^>]*>(.*?)</item>""", RegexOption.DOT_MATCHES_ALL)
                        .findAll(p.groupValues[2]).associate { it.groupValues[1] to valeur(it.groupValues[2]) }
            }
            val tableaux = LinkedHashMap<String, List<String>>()
            Regex("""<string-array\b([^>]*)>(.*?)</string-array>""", RegexOption.DOT_MATCHES_ALL).findAll(xml).forEach { t ->
                tableaux[nom(t.groupValues[1])] = Regex("""<item\b[^>]*>(.*?)</item>""", RegexOption.DOT_MATCHES_ALL)
                    .findAll(t.groupValues[2]).map { valeur(it.groupValues[1]) }.toList()
            }
            return Chaines(simples, pluriels, tableaux)
        }

        private val entites = mapOf("amp" to "&", "lt" to "<", "gt" to ">", "quot" to "\"", "apos" to "'")

        /** Ce qu'aapt fait d'une valeur. */
        fun valeur(brute: String): String {
            val s = Regex("""&(#x[0-9a-fA-F]+|#\d+|\w+);""").replace(brute) { m ->
                val e = m.groupValues[1]
                when {
                    e.startsWith("#x") -> String(Character.toChars(e.substring(2).toInt(16)))
                    e.startsWith("#") -> String(Character.toChars(e.substring(1).toInt()))
                    else -> entites[e] ?: error("entité inconnue : ${m.value}")
                }
            }
            val sortie = ArrayList<Pair<Char, Boolean>>()  // (caractère, espace repliable)
            var entreGuillemets = false
            var i = 0
            while (i < s.length) {
                val c = s[i]
                when {
                    c == '\\' && i + 1 < s.length -> {
                        i++
                        sortie += when (val n = s[i]) { 'n' -> '\n'; 't' -> '\t'; else -> n } to false
                    }
                    c == '"' -> entreGuillemets = !entreGuillemets
                    c in " \t\n\r\u000C\u000B" && !entreGuillemets -> if (sortie.lastOrNull()?.second != true) sortie += ' ' to true
                    else -> sortie += c to false
                }
                i++
            }
            while (sortie.firstOrNull()?.second == true) sortie.removeAt(0)
            while (sortie.lastOrNull()?.second == true) sortie.removeAt(sortie.size - 1)
            return sortie.map { it.first }.joinToString("")
        }
    }
}
