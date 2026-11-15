package com.myhitbodedut

/** La liste des chapitres d'un long livre, filtrée par numéro ou par mot (FLECTURE-03). */
object Chapitres {

    /**
     * Les rangs des [titres] qui répondent à [saisie] : un nombre cherche le chiffre dans le titre
     * (« 282 » trouve « תורה 282 » comme « 282 »), un mot cherche sans voyelles ni casse ; vide, tous.
     */
    fun filtrer(titres: List<String>, saisie: String): List<Int> {
        val q = RechercheGlobale.nu(saisie)
        if (q.isEmpty()) return titres.indices.toList()
        return titres.indices.filter { RechercheGlobale.nu(titres[it]).contains(q) }
    }
}
