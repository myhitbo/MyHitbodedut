import Foundation

/// Le journal enrichi tel que l'écran du journal le résume (`JournalPlus.kt`) : la ligne d'une journée et les
/// minutes du mois. Le graphique viendra avec l'écran (tâche 16).
extension JournalPlus {

    /// `HUMEURS` : les cinq humeurs, de la plus lourde à la plus légère.
    public static let humeurs = ["😞", "🙁", "😐", "🙂", "😄"]

    /// `resume` : les sujets, puis « 🙁 → 🙂 » (isolé de gauche à droite, U+2066…U+2069, pour que la flèche ne
    /// s'inverse pas en hébreu), puis « Gratitude : … » et « À travailler : … » ; une ligne chacun, vide s'il n'y a
    /// rien. `gratitude` et `travail` sont les libellés.
    public static func resume(_ plus: JournalPlus, gratitude: String, travail: String = "", sujets: String = "") -> String {
        func humeur(_ n: Int) -> String { n >= 1 && n <= humeurs.count ? humeurs[n - 1] : "·" }
        var lignes: [String] = []
        if !sujets.estBlanc { lignes.append(sujets) }
        if plus.avant > 0 || plus.apres > 0 { lignes.append("\u{2066}\(humeur(plus.avant)) → \(humeur(plus.apres))\u{2069}") }
        if !plus.gratitude.estBlanc { lignes.append("\(gratitude) : \(plus.gratitude)") }
        if !plus.travail.estBlanc { lignes.append("\(travail) : \(plus.travail)") }
        return lignes.joined(separator: "\n")
    }

    /// `minutesDuMois` : les minutes de chaque jour du mois, du 1er au dernier ; 0 sans hitbodedout (une note seule
    /// ne compte pas).
    public static func minutesDuMois(_ jours: [JourCivil: Journee], annee: Int, mois: Int) -> [Int] {
        (1...JourCivil.joursDansLeMois(mois, annee: annee)).map { j in
            guard let jour = JourCivil(annee: annee, mois: mois, jour: j), let e = jours[jour], e.faite else { return 0 }
            return e.minutes
        }
    }
}
