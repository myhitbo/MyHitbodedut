// La liste des chapitres d'un long livre, filtrée par numéro ou par mot (Chapitres.kt, FLECTURE-03).

public enum Chapitres {

    /// Les rangs des `titres` qui répondent à `saisie` : un nombre cherche le chiffre dans le titre (« 282 »
    /// trouve « תורה 282 » comme « 282 »), un mot cherche sans voyelles ni casse (`RechercheGlobale.nu`) ; vide,
    /// tous.
    public static func filtrer(_ titres: [String], _ saisie: String) -> [Int] {
        let q = RechercheGlobale.nu(saisie)
        if q.isEmpty { return Array(titres.indices) }
        return titres.indices.filter { RechercheGlobale.nu(titres[$0]).contientUnites(q) }
    }
}
