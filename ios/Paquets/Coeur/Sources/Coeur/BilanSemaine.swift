/// Le bilan de la semaine (BilanSemaine.kt, 16/10) : à la première ouverture de la semaine, ce que la
/// semaine écoulée (dimanche → samedi) a donné — minutes, jours, la semaine d'avant, un record, les trophées
/// gagnés. Une semaine vide ne fait pas de bilan : l'application ne rappelle pas une dette.
///
/// Les minutes sont des `Int` de Kotlin : leurs sommes tiennent sur 32 bits et débordent sans lever, comme
/// sur Android. Jugé par `Tests/Vecteurs/trophees.json` (tools/vecteurs_ios/VecteursTrophees.kt).
public enum BilanSemaine {

    public struct Bilan: Hashable, Sendable {
        /// Le dimanche de la semaine écoulée.
        public let debut: JourCivil
        public let minutes: Int
        public let jours: Int
        /// Les minutes de la semaine d'avant.
        public let precedente: Int
        /// La meilleure semaine jusque-là : seulement s'il y en avait une avant.
        public let record: Bool
        /// Dans l'ordre du chemin des trophées.
        public let trophees: [Trophees.Niveau]

        public init(debut: JourCivil, minutes: Int, jours: Int, precedente: Int, record: Bool,
                    trophees: [Trophees.Niveau]) {
            self.debut = debut
            self.minutes = minutes
            self.jours = jours
            self.precedente = precedente
            self.record = record
            self.trophees = trophees
        }

        /// Sur les 32 bits de Kotlin.
        public var ecart: Int {
            Int(Int32(truncatingIfNeeded: minutes) &- Int32(truncatingIfNeeded: precedente))
        }
    }

    /// Le dimanche de la semaine d'un jour (`jourDeSemaine` vaut 1 le dimanche).
    public static func debutSemaine(_ d: JourCivil) -> JourCivil { d.plus(jours: 1 - d.jourDeSemaine) }

    /// Le bilan de la semaine écoulée vue depuis `aujourdhui` ; nil si elle n'a rien compté. `dates` : le
    /// jour de gain de chaque niveau, par sa clé (`Trophees.datesGain`).
    public static func precedente(_ aujourdhui: JourCivil, minutes: [JourCivil: Int],
                                  dates: [String: JourCivil]) -> Bilan? {
        let debut = debutSemaine(aujourdhui).plus(jours: -7)
        let fin = debut.plus(jours: 6)
        let debutAvant = debut.plus(jours: -7)
        let finAvant = debut.plus(jours: -1)
        var total: Int32 = 0
        var jours = 0
        var semaineDAvant: Int32 = 0
        // Les minutes de chaque semaine d'avant celle-ci, par son dimanche.
        var avant: [JourCivil: Int32] = [:]
        for (jour, m) in minutes {
            let v = Int32(truncatingIfNeeded: m)
            if debut <= jour && jour <= fin {
                total = total &+ v
                jours += 1
            }
            if debutAvant <= jour && jour <= finAvant { semaineDAvant = semaineDAvant &+ v }
            if jour < debut { avant[debutSemaine(jour), default: 0] &+= v }
        }
        if total <= 0 { return nil }
        let meilleureAvant = avant.values.max() ?? 0
        var trophees: [Trophees.Niveau] = []
        for n in Trophees.chemin {
            if let d = dates[n.cle], debut <= d && d <= fin { trophees.append(n) }
        }
        return Bilan(debut: debut, minutes: Int(total), jours: jours, precedente: Int(semaineDAvant),
                     record: meilleureAvant > 0 && total > meilleureAvant, trophees: trophees)
    }
}
