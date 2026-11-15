import Foundation

// L'objet `Parcours` de ParcoursActivity.kt : ce qu'on peut dire d'un parcours, sans écran (proposition 6, 19/10).
// L'écran « Mon parcours » viendra avec les écrans (ROADMAP, tâche 16). Jugé par ParcoursTests (ParcoursTest
// d'Android) ; le web en calcule autant (regles.js, Parcours).

/// `Parcours` : les jours de hitbodedout, le temps, la moyenne, les sujets les plus fréquents, l'humeur avant et après.
public enum Parcours {

    /// `Bilan`.
    public struct Bilan: Sendable, Equatable {
        /// Les jours de hitbodedout (une note seule n'en fait pas un).
        public let jours: Int
        public let minutes: Int
        /// Les cinq sujets les plus fréquents, du plus au moins.
        public let sujets: [ThemeRules.Frequence]

        public init(jours: Int, minutes: Int, sujets: [ThemeRules.Frequence]) {
            self.jours = jours
            self.minutes = minutes
            self.sujets = sujets
        }

        /// Les minutes par jour de hitbodedout, arrondies (les demis vers le haut, `Math.round`) ; 0 sans aucun jour.
        public var moyenne: Int { jours == 0 ? 0 : Kotlin.arrondi(Double(minutes) / Double(jours)) }
    }

    /// `Triple(avant, après, jours)` : l'humeur moyenne avant et après (1 à 5), et le nombre de jours où les deux
    /// ont été notées.
    public struct Humeur: Sendable, Equatable {
        public let avant: Int
        public let apres: Int
        public let jours: Int

        public init(avant: Int, apres: Int, jours: Int) {
            self.avant = avant
            self.apres = apres
            self.jours = jours
        }
    }

    /// Les journées faites comptent pour les jours et le temps ; les sujets se comptent sur toutes, comme Android.
    public static func bilan<C: Collection>(_ jours: C) -> Bilan where C.Element == Journee {
        let faites = jours.filter { $0.faite }
        let minutes = faites.reduce(0) { $0 + $1.minutes }
        return Bilan(jours: faites.count, minutes: minutes, sujets: ThemeRules.frequents(jours.flatMap { $0.themes }, max: 5))
    }

    /// L'humeur moyenne avant et après, sur les jours où les deux sont notées ; nil s'il n'y en a aucun.
    public static func humeur<C: Collection>(_ plus: C) -> Humeur? where C.Element == JournalPlus {
        let notes = plus.filter { $0.avant > 0 && $0.apres > 0 }
        if notes.isEmpty { return nil }
        // `average()` de Kotlin : la somme en Double, divisée par le nombre.
        let n = Double(notes.count)
        let avant = notes.reduce(0) { $0 + $1.avant }
        let apres = notes.reduce(0) { $0 + $1.apres }
        return Humeur(avant: Kotlin.arrondi(Double(avant) / n), apres: Kotlin.arrondi(Double(apres) / n), jours: notes.count)
    }

    /// Le bilan du journal entier (`ParcoursActivity.onCreate` : `bilan(jours.values)`).
    public static func bilan(_ journal: Journal) -> Bilan { bilan(journal.jours.values) }

    /// L'humeur du journal entier (`ParcoursActivity.onCreate`) : le complément de chaque journée inscrite, et
    /// d'elles seules ; un complément sans journée ne compte pas.
    public static func humeur(_ journal: Journal) -> Humeur? {
        humeur(journal.jours.keys.map { journal.plus[$0] ?? JournalPlus() })
    }
}
