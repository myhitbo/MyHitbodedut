import Foundation

/// `SessionRule.kt` : l'arithmétique d'une séance, en millisecondes Unix passées en argument.
///
/// Une séance a une durée choisie, ou pas de durée du tout. La séance ouverte n'a pas de fin inscrite : c'est
/// la durée nulle qui la désigne. Sa durée réelle est mesurée comme celle des autres, pour que la série et le
/// total continuent de compter. Les soustractions et les conversions sont celles des `Long` de Kotlin.
/// Jugé par `Tests/Vecteurs/pratique.json`.
public enum SessionRule {

    /// La durée d'une séance sans durée.
    public static let ouverte = 0

    /// La plus longue séance qu'on puisse choisir ; une séance ouverte s'y arrête aussi.
    public static let plafondOuverte = 240

    /// Ce que le compteur d'une séance en cours a le droit de dire.
    public enum Compteur: String, Sendable, CaseIterable {
        /// Le temps restant, pour une séance minutée.
        case reste = "RESTE"
        /// Le temps déjà passé, pour une séance ouverte.
        case ecoule = "ECOULE"
        /// Rien : le compteur est masqué jusqu'au signal de fin.
        case masque = "MASQUE"
    }

    /// Le choix est fait une fois ici pour les trois endroits qui affichent un compteur (l'écran de séance,
    /// la notification ou l'activité en cours, le bouclier) : le masquage l'emporte sur le reste.
    public static func compteur(ouverte: Bool, masque: Bool) -> Compteur {
        if masque { return .masque }
        return ouverte ? .ecoule : .reste
    }

    public static func estOuverte(debut: Int64, duree: Int) -> Bool {
        debut > 0 && duree == ouverte
    }

    /// Une séance ouverte court tant qu'elle n'a pas été close à la main ; une séance minutée, jusqu'à son terme.
    public static func enCours(debut: Int64, fin: Int64, duree: Int, maintenant: Int64) -> Bool {
        estOuverte(debut: debut, duree: duree) ? true : fin > maintenant
    }

    /// Les minutes pleines écoulées depuis le début ; jamais négatives (horloge qui recule).
    public static func minutesEcoulees(debut: Int64, maintenant: Int64) -> Int {
        guard debut > 0 else { return 0 }
        return max(Kotlin.versInt(long: (maintenant &- debut) / 60_000), 0)
    }

    /// Les minutes à inscrire au journal quand la séance se clôt. Une séance minutée ne compte jamais plus que sa
    /// durée (sa fin peut n'être constatée que bien plus tard) ; arrêtée avant son terme, le temps passé. Une
    /// séance ouverte compte le temps passé, borné à `plafondOuverte` minutes.
    public static func minutesAInscrire(debut: Int64, fin: Int64, maintenant: Int64) -> Int {
        guard debut > 0 else { return 0 }
        let borne = fin > 0 ? min(maintenant, fin) : maintenant
        let minutes = max(Kotlin.versInt(long: (borne &- debut) / 60_000), 0)
        return fin > 0 ? minutes : min(minutes, plafondOuverte)
    }

    /// Une séance inscrite dont personne ne s'occupe plus est-elle terminée ? Minutée : son terme est passé.
    /// Ouverte : elle a atteint le plafond.
    public static func estEchue(debut: Int64, fin: Int64, duree: Int, maintenant: Int64) -> Bool {
        guard debut > 0 else { return false }
        if estOuverte(debut: debut, duree: duree) {
            return maintenant &- debut >= Int64(plafondOuverte) * 60_000
        }
        return fin <= maintenant
    }

    /// Les minutes restantes, arrondies au supérieur : « 1 min » s'affiche jusqu'à la toute fin.
    public static func minutesRestantes(fin: Int64, maintenant: Int64) -> Int {
        let reste = fin &- maintenant
        guard reste > 0 else { return 0 }
        return Kotlin.versInt(long: (reste &+ 59_999) / 60_000)
    }
}

/// `DureeSeance.kt` : les durées proposées (5, 10, 15, 30 minutes, 1 h, 1 h 30, demande du 28/09) et la durée
/// réglable. Le dialogue reviendra avec l'écran (tâche 15) ; la liste et la lecture du nombre sont ici.
public enum DureeSeance {

    public static let proposees = [5, 10, 15, 30, 60, 90]

    public static let minimum = 1
    public static let maximum = 240

    /// Le nombre saisi, ramené entre 1 et 240 minutes ; nil si ce n'est pas un nombre (`trim().toIntOrNull()`).
    public static func lire(_ texte: String) -> Int? {
        Kotlin.versIntOuNil(texte.rogne).map { min(max($0, minimum), maximum) }
    }
}
