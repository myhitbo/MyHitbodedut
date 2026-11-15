// « Mon parcours » (ParcoursActivity.kt, l'objet Parcours ; proposition 6, 19/10) : les chiffres de la
// pratique, les sujets les plus fréquents et l'humeur moyenne. La page elle-même (tuiles, barres du mois,
// séries) reviendra avec son écran.
//
// Les minutes sont des `Int` de Kotlin : leur somme tient sur 32 bits et déborde sans lever, comme sur
// Android. Les arrondis sont ceux de `Math.round` (les demis vers plus l'infini). Jugé par
// `Tests/Vecteurs/parcours.json` (tools/vecteurs_ios/VecteursParcours.kt, une recopie de l'objet
// comparée ligne à ligne au fichier d'Android).

/// Les chiffres de « Mon parcours ».
public enum Parcours {

    /// Les jours faits, leurs minutes, et les sujets les plus fréquents (cinq au plus).
    public struct Bilan: Sendable, Equatable {
        public let jours: Int
        public let minutes: Int
        public let sujets: [ThemeRules.Frequence]

        public init(jours: Int, minutes: Int, sujets: [ThemeRules.Frequence]) {
            self.jours = jours
            self.minutes = minutes
            self.sujets = sujets
        }

        /// Les minutes par jour de hitbodedout, arrondies ; 0 sans aucun jour.
        public var moyenne: Int {
            jours == 0 ? 0 : Kotlin.arrondi(Double(minutes) / Double(jours))
        }
    }

    /// Le bilan des journées : seules les journées faites comptent pour les jours et les minutes, mais les
    /// sujets de toutes les journées, notes seules comprises, comptent pour les sujets (comme sur Android).
    public static func bilan<S: Sequence>(_ jours: S) -> Bilan where S.Element == Journee {
        var faits = 0
        var total: Int32 = 0
        var cles: [String] = []
        for journee in jours {
            if journee.faite {
                faits += 1
                total = total &+ Int32(truncatingIfNeeded: journee.minutes)
            }
            cles.append(contentsOf: journee.themes)
        }
        return Bilan(jours: faits, minutes: Int(total), sujets: ThemeRules.frequents(cles, max: 5))
    }

    /// L'humeur moyenne avant et après (de 1 à 5), et le nombre de jours où les deux sont notées (le
    /// `Triple` de Kotlin).
    public struct Humeur: Sendable, Hashable {
        public let avant: Int
        public let apres: Int
        public let jours: Int

        public init(avant: Int, apres: Int, jours: Int) {
            self.avant = avant
            self.apres = apres
            self.jours = jours
        }
    }

    /// L'humeur moyenne, sur les jours où l'humeur avant et l'humeur après sont notées ; nil sinon. La
    /// moyenne se fait comme `average()` de Kotlin (une somme en `Double`, puis une division), puis s'arrondit.
    public static func humeur<S: Sequence>(_ plus: S) -> Humeur? where S.Element == JournalPlus.Plus {
        var sommeAvant = 0.0
        var sommeApres = 0.0
        var notes = 0
        for p in plus where p.avant > 0 && p.apres > 0 {
            sommeAvant += Double(p.avant)
            sommeApres += Double(p.apres)
            notes += 1
        }
        if notes == 0 { return nil }
        return Humeur(avant: Kotlin.arrondi(sommeAvant / Double(notes)),
                      apres: Kotlin.arrondi(sommeApres / Double(notes)),
                      jours: notes)
    }
}
