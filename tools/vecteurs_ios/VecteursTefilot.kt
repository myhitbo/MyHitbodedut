// Tefilot.kt devant la JVM : les dix sujets de l'écran Tfilot (SujetTefila, clé et nom de la chaîne
// du titre), puis ce que TefilotRules tire de la bibliothèque livrée (prieres, parSujet, lignes,
// prevenir, et la forme que LibraryRules.paragraphs en affiche), et de bibliothèques écrites à la
// main : sous-section vide ou absente, articles mêlés aux sources, sujets inconnus ou mal écrits,
// constats « non » mal écrits, deux sous-sections du même nom, ordre du fichier.

import com.myhitbodedut.Library
import com.myhitbodedut.LibraryLoader
import com.myhitbodedut.LibraryRules
import com.myhitbodedut.SujetTefila
import com.myhitbodedut.TefilotRules
import java.io.File

object VecteursTefilot : Generateur {
    override val fichier = "tefilot.json"

    private val bibliotheque: Library = LibraryLoader.parse(File(RES, "raw/bibliotheque.json").readText())

    /** Une empreinte pour une liste de textes : joints par un saut de ligne. */
    private fun empreinte(textes: List<String>): Int = textes.joinToString("\n").hashCode()

    private fun ligne(l: TefilotRules.Ligne): Map<String, Any?> = when (l) {
        is TefilotRules.Ligne.Titre -> linkedMapOf("genre" to "titre", "sujet" to l.sujet.cle, "nombre" to l.nombre)
        is TefilotRules.Ligne.Priere -> linkedMapOf("genre" to "priere", "sujet" to l.sujet.cle, "id" to l.entree.id)
    }

    /** Tout ce que TefilotRules répond d'une bibliothèque. */
    private fun regles(b: Library): Map<String, Any?> = linkedMapOf(
        "prieres" to TefilotRules.prieres(b).map { p ->
            linkedMapOf("id" to p.id, "sujet" to p.sujet, "lecon" to p.leconSurLeSujet, "prevenir" to TefilotRules.prevenir(p))
        },
        "parSujet" to SujetTefila.values().map { s -> TefilotRules.parSujet(b, s).map { it.id } },
        "lignes" to TefilotRules.lignes(b).map(::ligne),
    )

    private fun source(id: String, sujet: String?, lecon: String? = null, type: String? = "source"): String {
        val champs = mutableListOf(""""id":"$id"""")
        if (type != null) champs += """"type":"$type""""
        if (sujet != null) champs += """"sujet":$sujet"""
        if (lecon != null) champs += """"lecon_sur_le_sujet":$lecon"""
        return champs.joinToString(",", "{", "}")
    }

    private fun sousSection(id: String, vararg entrees: String): String =
        """{"id":"$id","titre":{},"entrees":[${entrees.joinToString(",")}]}"""

    private fun document(vararg sections: Pair<String, List<String>>): String =
        """{"_meta":{"version":"x"},"sections":[""" +
            sections.joinToString(",") { (id, liste) -> """{"id":"$id","titre":{},"sous_sections":[${liste.joinToString(",")}]}""" } +
            "]}"

    private val sous = TefilotRules.SOUS_SECTION

    private val documents: List<Pair<String, String>> = listOf(
        // TefilotScreenTest, `un sujet sans priere ne produit aucune ligne`.
        "vide" to """{"_meta":{"version":"x"},"sections":[{"id":"tefilot","titre":{},
               "sous_sections":[{"id":"tefilot-lt","titre":{},"entrees":[]}]}]}""",
        "sansSections" to """{"_meta":{},"sections":[]}""",
        "sansSousSection" to document("s" to listOf(sousSection("autre", source("a", "\"simcha\"")))),
        "sansEntrees" to """{"_meta":{},"sections":[{"id":"s","sous_sections":[{"id":"$sous"}]}]}""",
        "melee" to document("tefilot" to listOf(sousSection(sous,
            source("r1", "\"refua\"", "\"non\""),
            source("art", "\"hitbodedut\"", "\"non\"", type = "article"),
            source("h1", "\"hitbodedut\"", "\"oui\""),
            source("s1", "\"simcha\"", "\"partiel\""),
            source("h2", "\"hitbodedut\""),
            source("x1", "\"autre\"", "\"non\""),
            source("x2", null, "\"non\""),
            source("x3", "\"HITBODEDUT\""),
            source("x4", "\" simcha\""),
            source("x5", "null"),
            source("x6", "\"\""),
            source("z1", "\"zivug\"", "\"NON\""),
            source("z2", "\"zivug\"", "\" non\""),
            source("z3", "\"zivug\"", "\"non \""),
            source("z4", "\"zivug\"", "\"non\""),
            source("g1", "\"geula\"", "null"),
            source("t1", "\"uman\"", type = null),
            source("t2", "\"uman\"", type = "Source"),
            source("k1", "\"kdusha\"", "\"oui\""),
        ))),
        "deuxSousSections" to document(
            "a" to listOf(sousSection(sous, source("g1", "\"geula\"", "\"non\""))),
            "b" to listOf(sousSection(sous, source("b1", "\"brit\"", "\"oui\""))),
        ),
        "plusLoin" to document(
            "a" to listOf(sousSection("autre", source("p1", "\"parnassa\""))),
            "b" to listOf(sousSection("encore"), sousSection(sous, source("b1", "\"brit\""), source("b2", "\"brit\"", "\"non\""),
                source("z1", "\"zera\""))),
        ),
        "toutLOrdreALEnvers" to document("t" to listOf(sousSection(sous,
            *SujetTefila.values().reversed().map { s -> source("e-${s.cle}", "\"${s.cle}\"", "\"oui\"") }.toTypedArray()))),
        "articlesSeulement" to document("t" to listOf(sousSection(sous,
            source("a1", "\"simcha\"", type = "article"), source("a2", "\"refua\"", type = "")))),
        "idDouble" to document("t" to listOf(sousSection(sous, source("d", "\"brit\""), source("d", "\"brit\"", "\"non\"")))),
    )

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursTefilot.kt"),
        "sousSection" to TefilotRules.SOUS_SECTION,
        "sujets" to SujetTefila.values().map { s -> linkedMapOf("cle" to s.cle, "titre" to Identifiants.entree(s.titre)) },
        // La bibliothèque livrée : chaque prière, ses textes en empreinte, et la forme que sa licence affiche.
        "bibliotheque" to regles(bibliotheque) + linkedMapOf(
            "editionLt" to bibliotheque.editions["lt"]?.nikkoudOk,
            "textes" to TefilotRules.prieres(bibliotheque).map { p ->
                linkedMapOf(
                    "id" to p.id, "ref" to p.ref, "edition" to p.edition, "statutVerif" to p.statutVerif,
                    "titreHe" to p.titreHe.hashCode(),
                    "paragraphes" to p.paragraphes.size, "paragraphesSansNikkoud" to p.paragraphesSansNikkoud.size,
                    "avec" to empreinte(p.paragraphes), "sans" to empreinte(p.paragraphesSansNikkoud),
                    "affiches" to empreinte(LibraryRules.paragraphs(bibliotheque, p)),
                )
            },
        ),
        "documents" to documents.map { (nom, json) ->
            linkedMapOf<String, Any?>("nom" to nom, "json" to json) + regles(LibraryLoader.parse(json))
        },
    )
}
