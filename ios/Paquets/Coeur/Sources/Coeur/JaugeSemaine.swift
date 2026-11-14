/// Une case de la bande hebdomadaire de l'accueil (`WeekDay` de Store.kt).
public struct CaseSemaine: Hashable, Sendable {
    public let date: JourCivil
    public let done: Bool
    public let exempt: Bool
    public let shabbat: Bool
    public let future: Bool

    public init(date: JourCivil, done: Bool, exempt: Bool, shabbat: Bool, future: Bool) {
        self.date = date
        self.done = done
        self.exempt = exempt
        self.shabbat = shabbat
        self.future = future
    }
}

/// La jauge de l'accueil : les jours faits de la semaine, sur les jours dus (JaugeSemaine.kt).
///
/// Un Chabbat ou un jour de pause n'est pas dû : il ne creuse pas la jauge. Une séance faite un jour
/// exempté compte quand même — on ne retire pas à quelqu'un ce qu'il a fait. Jugée par
/// `Tests/Vecteurs/jauge_semaine.json` (tools/vecteurs_ios/VecteursJaugeSemaine.kt).
public enum JaugeSemaine {

    public struct Progression: Hashable, Sendable {
        public let faits: Int
        public let dus: Int

        public init(faits: Int, dus: Int) {
            self.faits = faits
            self.dus = dus
        }

        /// De 0 à 1 ; une semaine sans jour dû reste vide plutôt que pleine. Le quotient est en simple
        /// précision, comme le `Float` de Kotlin, puis borné comme par `coerceIn(0f, 1f)`, qui laisse un
        /// zéro négatif tel quel (0 sur un nombre de jours dus négatif) : `max` de Swift en ferait un
        /// zéro positif.
        public var fraction: Float {
            if dus == 0 { return 0 }
            let quotient = Float(faits) / Float(dus)
            if quotient < 0 { return 0 }
            if quotient > 1 { return 1 }
            return quotient
        }
    }

    /// La durée d'un jour fait, assez courte pour la case de la bande (14/10, « le temps à la place du
    /// ✓ ») : « 25′ », « 1h », « 1h20 ». Le signe des minutes est le prime (U+2032), celui d'Android.
    public static func dureeCourte(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)\u{2032}" }
        let heures = minutes / 60
        let reste = minutes % 60
        if reste == 0 { return "\(heures)h" }
        // « %02d » de Kotlin : le reste va de 1 à 59 ici.
        return reste < 10 ? "\(heures)h0\(reste)" : "\(heures)h\(reste)"
    }

    public static func progression(_ jours: [CaseSemaine]) -> Progression {
        var faits = 0
        var dus = 0
        for jour in jours {
            if jour.done { faits += 1 }
            if jour.done || !jour.exempt { dus += 1 }
        }
        return Progression(faits: faits, dus: dus)
    }
}
