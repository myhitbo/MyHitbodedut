import Foundation

/// `WeekDay` de `Store.kt` : une case de la bande hebdomadaire.
public struct CaseSemaine: Sendable, Equatable {
    public let date: JourCivil
    public let faite: Bool
    public let exemptee: Bool
    public let chabbat: Bool
    public let aVenir: Bool

    public init(date: JourCivil, faite: Bool, exemptee: Bool, chabbat: Bool, aVenir: Bool) {
        self.date = date
        self.faite = faite
        self.exemptee = exemptee
        self.chabbat = chabbat
        self.aVenir = aVenir
    }
}

/// `JaugeSemaine.kt` : les jours faits de la semaine, sur les jours dus. Un Chabbat ou un jour de pause n'est
/// pas dû ; une séance faite un jour exempté compte quand même.
public enum JaugeSemaine {

    public struct Progression: Sendable, Equatable {
        public let faits: Int
        public let dus: Int

        public init(faits: Int, dus: Int) {
            self.faits = faits
            self.dus = dus
        }

        /// De 0 à 1, en simple précision comme Kotlin ; une semaine sans jour dû reste vide plutôt que pleine.
        public var fraction: Float {
            dus == 0 ? 0 : min(max(Float(faits) / Float(dus), 0), 1)
        }
    }

    /// La durée d'un jour fait, pour la case de la bande (14/10) : « 25′ », « 1h », « 1h20 ».
    public static func dureeCourte(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)\u{2032}" }
        let reste = minutes % 60
        if reste == 0 { return "\(minutes / 60)h" }
        return "\(minutes / 60)h" + (reste < 10 ? "0\(reste)" : "\(reste)")
    }

    public static func progression(_ jours: [CaseSemaine]) -> Progression {
        Progression(faits: jours.filter { $0.faite }.count, dus: jours.filter { $0.faite || !$0.exemptee }.count)
    }
}

/// `Anneaux.kt` : les trois anneaux de l'accueil (demande du 01/10), de l'intérieur vers l'extérieur : le jour
/// (minutes sur l'objectif), la semaine (jours faits sur jours dus), la série (jours d'affilée sur le prochain
/// palier). Au-delà de l'objectif, un anneau repasse sur lui-même : la fraction brute le dit.
public enum Anneaux {

    /// Les paliers de la série ; au-delà du dernier, de 365 en 365.
    public static let paliers = [7, 14, 30, 60, 100, 180, 365]

    public enum Quel: String, Sendable, CaseIterable {
        case jour = "JOUR", semaine = "SEMAINE", serie = "SERIE"
    }

    public struct Anneau: Sendable, Equatable {
        public let quel: Quel
        public let fait: Int
        public let objectif: Int

        public init(quel: Quel, fait: Int, objectif: Int) {
            self.quel = quel
            self.fait = fait
            self.objectif = objectif
        }

        /// Peut dépasser 1 : c'est le second tour. Sans objectif, rien. En simple précision, comme Kotlin.
        public var fraction: Float { objectif <= 0 ? 0 : Float(fait) / Float(objectif) }

        /// Les tours complets déjà faits (`Float.toInt()`).
        public var tours: Int { Kotlin.versInt(Double(fraction)) }

        /// Ce qui dépasse les tours complets, de 0 à 1.
        public var reste: Float { fraction - Float(tours) }

        public var atteint: Bool { objectif > 0 && fait >= objectif }
    }

    public struct Etat: Sendable, Equatable {
        public let jour: Anneau
        public let semaine: Anneau
        public let serie: Anneau

        public init(jour: Anneau, semaine: Anneau, serie: Anneau) {
            self.jour = jour
            self.semaine = semaine
            self.serie = serie
        }

        /// Du centre vers l'extérieur : l'ordre de dessin.
        public var duCentre: [Anneau] { [jour, semaine, serie] }

        public func anneau(_ quel: Quel) -> Anneau {
            switch quel {
            case .jour: jour
            case .semaine: semaine
            case .serie: serie
            }
        }
    }

    /// Le palier que vise la série : le premier qui l'atteint ou la dépasse, pour que l'anneau soit plein le jour
    /// où l'on y arrive ; au-delà d'un an, le prochain multiple de 365.
    public static func palier(_ serie: Int) -> Int {
        if let p = paliers.first(where: { $0 >= serie }) { return p }
        return ((serie + 364) / 365) * 365
    }

    public static func etat(minutesJour: Int, objectifJour: Int, semaine: JaugeSemaine.Progression, serie: Int) -> Etat {
        let s = max(serie, 0)
        return Etat(jour: Anneau(quel: .jour, fait: max(minutesJour, 0), objectif: max(objectifJour, 0)),
                    semaine: Anneau(quel: .semaine, fait: semaine.faits, objectif: semaine.dus),
                    serie: Anneau(quel: .serie, fait: s, objectif: palier(s)))
    }

    /// Ce qui rend « nouveau » un anneau fermé : la date pour le jour, le dimanche de la semaine pour la semaine,
    /// le palier pour la série. Un anneau se fête une fois par marque (demande du 04/10).
    public static func marque(_ anneau: Anneau, aujourdhui: JourCivil) -> String? {
        guard anneau.atteint else { return nil }
        switch anneau.quel {
        case .jour: return "jour:\(aujourdhui.iso)"
        case .semaine: return "semaine:\(aujourdhui.plus(jours: 1 - aujourdhui.jourDeSemaine).iso)"
        case .serie: return "serie:\(anneau.objectif)"
        }
    }

    /// Les marques des anneaux fermés en ce moment : ce qu'on garde une fois la fête faite.
    public static func marques(_ etat: Etat, aujourdhui: JourCivil) -> Set<String> {
        Set(etat.duCentre.compactMap { marque($0, aujourdhui: aujourdhui) })
    }

    /// Les anneaux fermés qui n'ont pas encore été fêtés, du centre vers l'extérieur.
    public static func aFeter(_ etat: Etat, aujourdhui: JourCivil, dejaFetes: Set<String>) -> [Quel] {
        etat.duCentre.filter { a in marque(a, aujourdhui: aujourdhui).map { !dejaFetes.contains($0) } ?? false }.map(\.quel)
    }

    /// L'objectif quotidien effectif : celui qui est réglé, sinon la durée habituelle (au moins une minute).
    public static func objectifEffectif(regle: Int, dureeHabituelle: Int) -> Int {
        regle > 0 ? regle : max(dureeHabituelle, 1)
    }
}

/// `Plaque.kt` : les faces du centre des anneaux (demande du 04/10), le hassid puis vos chiffres, une face par
/// toucher ; la moyenne d'un jour de pratique et la meilleure série.
public enum Plaque {

    public enum Face: String, Sendable, CaseIterable {
        case hassid = "HASSID", jour = "JOUR", semaine = "SEMAINE", serie = "SERIE", meilleure = "MEILLEURE"
        case total = "TOTAL", jours = "JOURS", moyenne = "MOYENNE"

        /// L'anneau dont la face parle, et qu'elle met en avant.
        public var anneau: Anneaux.Quel? {
            switch self {
            case .jour: Anneaux.Quel.jour
            case .semaine: Anneaux.Quel.semaine
            case .serie, .meilleure: Anneaux.Quel.serie
            case .hassid, .total, .jours, .moyenne: nil
            }
        }
    }

    /// Le temps sans toucher après lequel le hassid revient.
    public static let retourMillis: Int64 = 8_000

    public static func suivante(_ face: Face) -> Face {
        let faces = Face.allCases
        let rang = faces.firstIndex(of: face) ?? 0
        return faces[(rang + 1) % faces.count]
    }

    /// La face qui parle de cet anneau : la première dans l'ordre.
    public static func pour(_ quel: Anneaux.Quel) -> Face {
        Face.allCases.first { $0.anneau == quel } ?? .hassid
    }

    /// Les minutes moyennes d'un jour de pratique, arrondies (`Math.round` d'un `Float`) ; 0 sans pratique.
    public static func moyenne(totalMinutes: Int, jours: Int) -> Int {
        jours <= 0 ? 0 : Kotlin.arrondiFlottant(Float(totalMinutes) / Float(jours))
    }

    /// La plus longue suite de jours faits ; un jour exempté (Chabbat, fête, pause) ne compte pas et ne casse pas.
    public static func meilleureSerie(_ faits: Set<JourCivil>, exempte: (JourCivil) -> Bool) -> Int {
        guard let premier = faits.min(), let dernier = faits.max() else { return 0 }
        var jour = premier
        var courante = 0
        var meilleure = 0
        while jour <= dernier {
            if faits.contains(jour) {
                courante += 1
                meilleure = max(meilleure, courante)
            } else if !exempte(jour) {
                courante = 0
            }
            jour = jour.plus(jours: 1)
        }
        return meilleure
    }
}
