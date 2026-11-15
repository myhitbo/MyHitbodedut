package com.myhitbodedut

/**
 * La recherche dans toute l'application (14/10) : le siddour, les livres, la
 * halakha (Yalkut Yosef, Ben Ish 'Haï) et les hilloulot, d'un seul champ. Sans
 * voyelles, cantillation, guillemets ni balises, et sans tenir compte de la casse.
 * Le même calcul que rechercheGlobale() du web.
 */
object RechercheGlobale {

    enum class Sorte { SIDDOUR, LIVRE, HALAKHA, HILLOULA }

    data class Resultat(val sorte: Sorte, val id: String, val titre: String, val extrait: String,
        /** Le paragraphe trouvé (rang de section, rang de bloc) : le toucher y conduit ; -1 pour un titre. */
        val section: Int = -1, val bloc: Int = -1)

    const val PAR_SORTE = 30

    /** Les paragraphes rendus pour un même texte (un livre en compte des milliers), et au plus par sorte (FLECTURE-02). */
    const val PAR_TEXTE = 5
    const val PAR_RECUEIL = 50

    /**
     * Les accents latins et l'apostrophe typographique tombent aussi : « priere » trouve
     * « Prières », « hachahar » trouve « Birkot hacha’har » (vérification du 29/10).
     */
    fun nu(t: String): String = java.text.Normalizer.normalize(t, java.text.Normalizer.Form.NFD).replace(ACCENTS, "").replace(BALISES, " ").replace(TIRETS, " ").replace(VOYELLES, "").replace(BLANCS, " ").trim().lowercase()

    // Compilées une fois (FLECTURE-07) : nu() passe sur des dizaines de milliers de paragraphes par requête.
    private val ACCENTS = Regex("[\u0300-\u036F’‘]")
    private val BALISES = Regex("<[^>]+>")
    private val TIRETS = Regex("[־׀]")
    private val VOYELLES = Regex("[֑-ׇ\"'״׳]")
    private val BLANCS = Regex("\\s+")

    /** Un extrait d'une quarantaine de caractères autour de la trouvaille, dans le texte sans voyelles. */
    fun extrait(texte: String, q: String): String {
        val t = nu(texte)
        val i = t.indexOf(q).coerceAtLeast(0)
        val debut = (i - 30).coerceAtLeast(0)
        return (if (debut > 0) "…" else "") + t.substring(debut, (i + q.length + 50).coerceAtMost(t.length)).trim() + (if (i + q.length + 50 < t.length) "…" else "")
    }

    /** Les textes d'un recueil (siddour ou livres) : titre d'abord, puis le premier paragraphe qui contient la recherche. */
    fun dansRecueil(recueil: Siddur, q: String, sorte: Sorte, langue: String, annule: () -> Boolean = { false }): List<Resultat> = recueil.textes.flatMap { t ->
        // Une requête dépassée par la frappe suivante s'abandonne en route (FLECTURE-07).
        if (annule()) return@flatMap emptyList<Resultat>()
        val titre = t.titre.he
        val trouves = ArrayList<Resultat>()
        if (nu(titre).contains(q) || nu(t.titre.forLanguage(langue)).contains(q)) trouves += Resultat(sorte, t.id, titre, t.titre.forLanguage(langue).takeIf { it != titre }.orEmpty())
        // Chaque paragraphe trouvé (cinq au plus par texte), avec sa place : le toucher y conduit (FLECTURE-02).
        run paragraphes@{
            t.sections.forEachIndexed { si, sec ->
                sec.blocs.forEachIndexed { bi, b ->
                    if (!b.consigne && nu(b.texte).contains(q)) {
                        val chapitre = sec.titre.takeIf { it.isNotBlank() }?.let { "$it · " }.orEmpty()
                        trouves += Resultat(sorte, t.id, titre, chapitre + extrait(b.texte, q), si, bi)
                        if (trouves.size >= PAR_TEXTE) return@paragraphes
                    }
                }
            }
        }
        trouves
    }.take(PAR_RECUEIL)

    /** Où chercher (19/10) : tout, ou seulement les prières, les halakhot, les livres ou les hilloulot. */
    enum class Portee(val sortes: Set<Sorte>) {
        TOUT(Sorte.values().toSet()), TEFILOT(setOf(Sorte.SIDDOUR)), HALAKHOT(setOf(Sorte.HALAKHA)), SEFARIM(setOf(Sorte.LIVRE)),
        HILLOULOT(setOf(Sorte.HILLOULA)),
    }

    /**
     * Une hilloula trouvée : le nom dans la langue de l'interface quand il existe, sinon l'hébreu
     * (audit 1.390 : l'hébreu s'affichait même quand le nom français existait). L'hébreu, isolé
     * (FSI … PDI), passe alors sous le nom, avec l'année.
     */
    fun resultatHilloula(texte: String, x: Hilloulot.Hilloula, langue: String): Resultat {
        val traduit = (if (langue.startsWith("en")) x.en else if (langue.startsWith("fr")) x.fr else null)?.takeIf { it.isNotBlank() }
        val extrait = listOfNotNull(traduit?.let { "\u2068${x.he}\u2069" }, x.annee.takeIf { it.isNotBlank() }).joinToString(" · ")
        return Resultat(Sorte.HILLOULA, texte, traduit ?: x.he, extrait)
    }

    fun chercher(
        texte: String, langue: String, siddur: Siddur, livres: Siddur?,
        yalkut: YalkutYosef.Livre?, benIshHai: Halakha.Livre?, hilloulot: Map<String, List<Hilloulot.Hilloula>>?,
        portee: Portee = Portee.TOUT, annule: () -> Boolean = { false },
    ): List<Resultat> {
        val q = nu(texte.trim())
        if (q.length < 2) return emptyList()
        val s = portee.sortes
        return buildList {
            if (Sorte.SIDDOUR in s) addAll(dansRecueil(siddur, q, Sorte.SIDDOUR, langue, annule))
            if (annule()) return@buildList
            if (Sorte.LIVRE in s) livres?.let { addAll(dansRecueil(it, q, Sorte.LIVRE, langue, annule)) }
            if (annule()) return@buildList
            if (Sorte.HALAKHA in s) yalkut?.let { y -> addAll(YalkutYosef.recherche(y, texte).take(PAR_SORTE).map { Resultat(Sorte.HALAKHA, texte, YalkutYosef.source(it), extrait(it.texte, q)) }) }
            if (Sorte.HALAKHA in s) benIshHai?.let { b -> addAll(Halakha.recherche(b, texte).take(PAR_SORTE).map { Resultat(Sorte.HALAKHA, texte, HalakhaActivity.source(it), extrait(it.texte, q)) }) }
            if (Sorte.HILLOULA in s) hilloulot?.let { h -> addAll(Hilloulot.recherche(h, texte).take(PAR_SORTE).map { (_, x) -> resultatHilloula(texte, x, langue) }) }
        }
    }
}
