// SourceDuJour devant la JVM : les candidats de la bibliothèque livrée (une empreinte String.hashCode
// par paragraphe), le paragraphe choisi chaque jour de 2025 à 2027 et quelques jours lointains, puis
// l'extrait de chaque candidat pour des bornes de 0 à Int.MAX_VALUE ; ensuite une bibliothèque écrite à
// la main (seuils de MIN en unités UTF-16, vocalisation, doublons, aucune source assez longue) et
// l'extrait de textes écrits à la main pour chaque borne de 0 à leur longueur + 2.

import com.myhitbodedut.Library
import com.myhitbodedut.LibraryLoader
import com.myhitbodedut.LibraryRules
import com.myhitbodedut.SourceDuJour
import com.myhitbodedut.SourceEntry
import java.io.File
import java.time.LocalDate

object VecteursSourceDuJour : Generateur {
    override val fichier = "source_du_jour.json"

    private val livre: Library = LibraryLoader.parse(File(RES, "raw/bibliotheque.json").readText())

    /** Les trois années de « choix », jour après jour. */
    private val premierJour = LocalDate.parse("2025-01-01")
    private val dernierJour = LocalDate.parse("2027-12-31")

    /** Des jours loin de 1970 dans les deux sens, et ses voisins : le reste de floorMod change de signe. */
    private val joursLointains = listOf(
        "0001-01-01", "0999-12-31", "1600-02-29", "1899-12-31", "1900-01-01", "1969-12-30", "1969-12-31",
        "1970-01-01", "1970-01-02", "2000-02-29", "2026-10-19", "2026-10-20", "2026-11-15", "2027-01-01",
        "2100-03-01", "2400-02-29", "9999-12-31",
    )

    private val bornes = listOf(0, 1, 2, 10, 40, 79, 80, 81, 100, 160, 200, 280, 300, 319, 320, 321, 400, 500, 857,
        858, 859, 1000, Int.MAX_VALUE)

    /** L'indice d'une pensée parmi les candidats (égalité de data class : même source, même texte). */
    private fun indice(candidats: List<SourceDuJour.Pensee>, p: SourceDuJour.Pensee?): Int? =
        p?.let { candidats.indexOf(it) }

    private fun candidat(l: Library, p: SourceDuJour.Pensee): Map<String, Any?> = linkedMapOf(
        "id" to p.source.id,
        // indexOf, comme le test d'Android : le premier paragraphe égal.
        "paragraphe" to LibraryRules.paragraphs(l, p.source).indexOf(p.texte),
        "longueur" to p.texte.length,
        "empreinte" to p.texte.hashCode(),
    )

    private fun jours(): List<LocalDate> =
        generateSequence(premierJour) { it.plusDays(1) }.takeWhile { !it.isAfter(dernierJour) }.toList()

    private fun livreLivre(): Map<String, Any?> {
        val c = SourceDuJour.candidats(livre)
        return linkedMapOf(
            "candidats" to c.map { candidat(livre, it) },
            "premierJour" to premierJour.toString(),
            // Pour chaque jour depuis premierJour, l'indice du candidat choisi.
            "choix" to jours().map { indice(c, SourceDuJour.choix(livre, it)) },
            "lointains" to joursLointains.map { iso ->
                val jour = LocalDate.parse(iso)
                linkedMapOf("jour" to iso, "epoch" to jour.toEpochDay(), "indice" to indice(c, SourceDuJour.choix(livre, jour)))
            },
            "bornes" to bornes,
            // Pour chaque candidat : l'extrait par défaut, puis pour chaque borne, [longueur, empreinte].
            "extraits" to c.map { p ->
                val defaut = SourceDuJour.extrait(p.texte)
                linkedMapOf(
                    "defaut" to listOf(defaut.length, defaut.hashCode()),
                    "parBorne" to bornes.map { m -> SourceDuJour.extrait(p.texte, m).let { listOf(it.length, it.hashCode()) } },
                )
            },
            // Les extraits à 320 qui coupent, en clair.
            "coupes320" to c.filter { it.texte.length > 320 }.map { p ->
                linkedMapOf("indice" to c.indexOf(p), "extrait" to SourceDuJour.extrait(p.texte, 320))
            },
        )
    }

    // --- Une bibliothèque écrite à la main -------------------------------------------------------

    private fun repete(s: String, n: Int) = s.repeat(n)

    /** 79 et 80 unités en lettres latines, en hébreu vocalisé (40 caractères, 80 unités), en émojis (40 et 80 unités). */
    private val p79 = repete("a", 79)
    private val p80 = repete("b", 80)
    private val hebreu80 = repete("בְ", 40)
    private val hebreu78 = repete("שָ", 39)
    private val emoji80 = repete("🙂", 40)
    private val emoji78 = repete("🙂", 39)
    private val long = "מַה " + repete("טוֹב ", 30)
    private val sansNikkoudLong = "מה " + repete("טוב ", 30)

    /**
     * Les éditions vocalisables ou non, une édition inconnue ; des paragraphes à 79 et 80 unités ; un
     * paragraphe répété dans une même source et d'une source à l'autre ; un article qui ne compte pas.
     */
    private val document = """
        {"_meta": {"version": "essai", "editions": {
            "voc": {"titre": "vocalisée", "licence": "Public Domain", "nikkoud_ok": true},
            "nue": {"titre": "non déclarée", "licence": "?", "nikkoud_ok": false}}},
         "sections": [
          {"id": "s1", "sous_sections": [
            {"id": "ss1", "entrees": [
              {"id": "a1", "type": "article", "titre": "article", "autorisation": "accord", "texte_integral": "$p80$p80"},
              {"id": "s-seuils", "type": "source", "edition": "voc",
               "paragraphes": ["$p79", "$p80", "$hebreu80", "$hebreu78", "$emoji80", "$emoji78", "", "$p80"]},
              {"id": "s-nue", "type": "source", "edition": "nue",
               "paragraphes": ["$long", "$p80"], "paragraphes_sans_nikkoud": ["$sansNikkoudLong", "court"]},
              {"id": "s-nue-seule", "type": "source", "edition": "nue", "paragraphes": ["$long"]},
              {"id": "s-inconnue", "type": "source", "edition": "inconnue", "paragraphes": ["$long"],
               "paragraphes_sans_nikkoud": ["$p79"]}
            ]},
            {"id": "ss2", "entrees": [
              {"id": "s-double", "type": "source", "edition": "voc", "paragraphes": ["$p80", "$long"]}
            ]}
          ]}
         ]}
    """.trimIndent()

    /** Que des articles, et des sources trop courtes : aucun candidat. */
    private val documentVide = """
        {"_meta": {"version": "vide", "editions": {"voc": {"titre": "v", "nikkoud_ok": true}}},
         "sections": [
          {"id": "s1", "sous_sections": [
            {"id": "ss1", "entrees": [
              {"id": "a1", "type": "article", "titre": "article", "autorisation": "accord", "texte_integral": "$p80$p80"},
              {"id": "s-courte", "type": "source", "edition": "voc", "paragraphes": ["$p79", "$hebreu78", "$emoji78"]},
              {"id": "s-vide", "type": "source", "edition": "voc", "paragraphes": []}
            ]}
          ]},
          {"id": "s2", "sous_sections": []}
         ]}
    """.trimIndent()

    private val joursManuels: List<LocalDate> =
        generateSequence(LocalDate.parse("1969-12-20")) { it.plusDays(1) }.take(25).toList() +
            joursLointains.map { LocalDate.parse(it) }

    private fun manuelle(texte: String): Map<String, Any?> {
        val l = LibraryLoader.parse(texte)
        val c = SourceDuJour.candidats(l)
        return linkedMapOf(
            "document" to texte,
            "candidats" to c.map { linkedMapOf("id" to it.source.id, "texte" to it.texte) },
            "choix" to joursManuels.map { jour ->
                linkedMapOf("jour" to jour.toString(), "indice" to indice(c, SourceDuJour.choix(l, jour)))
            },
        )
    }

    // --- Des extraits écrits à la main -----------------------------------------------------------

    private val textes = listOf(
        "",
        " ",
        "   abc",
        "abc",
        "abcd efgh",
        "abc def ghi",
        "abc, def; ghi: jkl",
        "abc ;: , def",
        "abc ,,, ;;; ::: def ghi",
        "abcdefghijkl",
        "abc\tdef ghi",
        "abc\t def",
        "abc\ndef ghi",
        "abc def ghi",
        "abc def ghi",
        "a  b  c  d",
        "fin. … suite",
        "café crème, été brûlant",
        "בְּרֵאשִׁית בָּרָא אֱלֹהִים, אֵת הַשָּׁמַיִם; וְאֵת הָאָרֶץ",
        "אַשְׁרֵי הָאִישׁ: אֲשֶׁר לֹא הָלַךְ",
        "שלום עולם, ומה שלומך היום",
        "🙂 abc 🙂🙂 d",
    )

    /** Une borne qui couperait une paire de substitution laisserait une moitié seule, que Swift ne porte pas. */
    private fun coupeUnePaire(texte: String, borne: Int): Boolean =
        borne in 1 until texte.length && Character.isHighSurrogate(texte[borne - 1])

    private fun extraitsManuels(): List<Any?> {
        val test = "א".repeat(10) + " " + "ב".repeat(400)
        val cas = mutableListOf<Any?>(
            linkedMapOf("texte" to test, "borne" to null, "extrait" to SourceDuJour.extrait(test)),
            linkedMapOf("texte" to test, "borne" to 11, "extrait" to SourceDuJour.extrait(test, 11)),
            linkedMapOf("texte" to test, "borne" to 410, "extrait" to SourceDuJour.extrait(test, 410)),
            linkedMapOf("texte" to test, "borne" to 411, "extrait" to SourceDuJour.extrait(test, 411)),
        )
        for (t in textes) {
            // Une ligne par texte : l'extrait pour chaque borne de 0 à la longueur + 2 (null là où la coupe tomberait dans une paire).
            cas.add(linkedMapOf("texte" to t, "defaut" to SourceDuJour.extrait(t),
                "parBorne" to (0..t.length + 2).map { m -> if (coupeUnePaire(t, m)) null else SourceDuJour.extrait(t, m) }))
        }
        return cas
    }

    override fun produire(): Map<String, Any?> {
        val c = SourceDuJour.candidats(livre)
        fun ici(jour: String): Map<String, Any?> {
            val p = SourceDuJour.choix(livre, LocalDate.parse(jour))!!
            return linkedMapOf("jour" to jour, "id" to p.source.id, "paragraphe" to LibraryRules.paragraphs(livre, p.source).indexOf(p.texte))
        }
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursSourceDuJour.kt"),
            "min" to SourceDuJour.MIN,
            // Les cas de SourceDuJourTest, tels que le code d'Android les rend.
            "testsKotlin" to linkedMapOf(
                "ici" to listOf("2026-10-19", "2026-10-20", "2027-01-01").map { ici(it) },
                "nombreDeCandidats" to c.size,
                "tousAssezLongs" to c.all { it.texte.length >= SourceDuJour.MIN },
                "sources" to c.all { livre.entry(it.source.id) is SourceEntry },
            ),
            "livre" to livreLivre(),
            "manuelle" to manuelle(document),
            "vide" to manuelle(documentVide),
            "extraits" to extraitsManuels(),
        )
    }
}
