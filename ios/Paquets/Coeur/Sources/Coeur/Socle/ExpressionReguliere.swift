import Foundation

/// Une expression régulière, avec les gestes de `Regex` de Kotlin.
///
/// Le moteur est celui d'ICU (`NSRegularExpression`), le même que sur un téléphone Android : il
/// travaille sur les unités UTF-16, connaît les regards en arrière et `\p{M}`. Deux précautions,
/// reprises des sources d'Android : hors ASCII, `\s`, `\w`, `\b` et `\d` n'ont pas la même étendue
/// d'un moteur à l'autre (ICU y compte l'espace insécable et les lettres accentuées, la JVM des tests
/// non) ; une règle qui en dépend écrit sa classe en toutes lettres.
/// Jugée par `Tests/Vecteurs/socle.json`, section « expressions ».
public struct ExpressionReguliere: @unchecked Sendable {
    // NSRegularExpression est immuable et sûre entre fils d'exécution (documentation de Foundation) ;
    // elle n'est pas déclarée Sendable sur toutes les plateformes.
    private let moteur: NSRegularExpression
    /// Le même motif, tenu de couvrir tout le texte : `matches` de Kotlin.
    private let moteurEntier: NSRegularExpression

    public let motif: String

    /// `RegexOption` de Kotlin.
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// `IGNORE_CASE`.
        public static let sansCasse = Options(rawValue: 1)
        /// `MULTILINE` : `^` et `$` à chaque ligne.
        public static let multiligne = Options(rawValue: 2)
        /// `DOT_MATCHES_ALL` : le point prend aussi les fins de ligne.
        public static let pointPartout = Options(rawValue: 4)
    }

    /// Une correspondance : `MatchResult` de Kotlin.
    public struct Correspondance: Sendable, Equatable {
        /// Le texte trouvé.
        public let valeur: String
        /// Sa place, en unités UTF-16 : `range.first ..< range.last + 1`.
        public let plage: Range<Int>
        /// `groupValues` : le texte entier, puis celui de chaque groupe ; vide pour un groupe qui n'a rien pris.
        public let groupes: [String]
        /// La place de chaque groupe ; `nil` pour un groupe qui n'a rien pris.
        public let plages: [Range<Int>?]
    }

    /// Un motif fautif est une faute de programme : la construction s'arrête.
    public init(_ motif: String, _ options: Options = []) {
        var reglages: NSRegularExpression.Options = []
        if options.contains(.sansCasse) { reglages.insert(.caseInsensitive) }
        if options.contains(.multiligne) { reglages.insert(.anchorsMatchLines) }
        if options.contains(.pointPartout) { reglages.insert(.dotMatchesLineSeparators) }
        do {
            moteur = try NSRegularExpression(pattern: motif, options: reglages)
            moteurEntier = try NSRegularExpression(pattern: "(?:" + motif + ")\\z", options: reglages)
        } catch {
            fatalError("expression régulière invalide « \(motif) » : \(error)")
        }
        self.motif = motif
    }

    private func correspondance(_ resultat: NSTextCheckingResult, _ unites: [UInt16]) -> Correspondance {
        var groupes: [String] = []
        var plages: [Range<Int>?] = []
        for rang in 0..<resultat.numberOfRanges {
            let etendue = resultat.range(at: rang)
            if etendue.location == NSNotFound {
                groupes.append("")
                plages.append(nil)
            } else {
                let plage = etendue.location..<(etendue.location + etendue.length)
                groupes.append(Unites.texte(unites[plage]))
                plages.append(plage)
            }
        }
        let entiere = resultat.range
        return Correspondance(valeur: groupes.first ?? "", plage: entiere.location..<(entiere.location + entiere.length),
                              groupes: groupes, plages: plages)
    }

    /// `find(texte, depuis)` : la première correspondance à partir de l'unité `depuis`. Comme sous Kotlin,
    /// le motif voit tout le texte : un regard en arrière peut porter avant `depuis`, `^` ne vaut qu'au début.
    public func trouve(_ texte: String, depuis: Int = 0) -> Correspondance? {
        let unites = Array(texte.utf16)
        if depuis < 0 || depuis > unites.count { return nil }
        let etendue = NSRange(location: depuis, length: unites.count - depuis)
        guard let resultat = moteur.firstMatch(in: texte, options: [.withTransparentBounds, .withoutAnchoringBounds],
                                               range: etendue) else { return nil }
        return correspondance(resultat, unites)
    }

    /// `findAll(texte)`.
    public func toutes(_ texte: String) -> [Correspondance] {
        let unites = Array(texte.utf16)
        let resultats = moteur.matches(in: texte, options: [], range: NSRange(location: 0, length: unites.count))
        return resultats.map { correspondance($0, unites) }
    }

    /// `containsMatchIn(texte)`.
    public func presente(dans texte: String) -> Bool {
        moteur.firstMatch(in: texte, options: [], range: NSRange(location: 0, length: texte.utf16.count)) != nil
    }

    /// `matchEntire(texte)` : la correspondance si le motif couvre tout le texte.
    public func entiere(_ texte: String) -> Correspondance? {
        let unites = Array(texte.utf16)
        guard let resultat = moteurEntier.firstMatch(in: texte, options: [.anchored],
                                                     range: NSRange(location: 0, length: unites.count)) else { return nil }
        return correspondance(resultat, unites)
    }

    /// `matches(texte)` : vrai si le motif couvre tout le texte.
    public func couvre(_ texte: String) -> Bool {
        entiere(texte) != nil
    }

    /// `replace(texte, "…")` avec un remplacement pris à la lettre (ni `$1` ni `\$`).
    public func remplace(_ texte: String, par remplacement: String) -> String {
        remplace(texte, gabarit: NSRegularExpression.escapedTemplate(for: remplacement))
    }

    /// `replace(texte, gabarit)` : `$1` rend le premier groupe, `\$` un dollar, comme sous Kotlin.
    public func remplace(_ texte: String, gabarit: String) -> String {
        moteur.stringByReplacingMatches(in: texte, options: [], range: NSRange(location: 0, length: texte.utf16.count),
                                        withTemplate: gabarit)
    }

    /// `replace(texte) { … }` : chaque correspondance remplacée par ce que rend `transforme`.
    /// Comme Kotlin, s'arrête une fois la fin du texte atteinte : une correspondance vide qui y resterait est laissée.
    public func remplace(_ texte: String, _ transforme: (Correspondance) -> String) -> String {
        let unites = Array(texte.utf16)
        let resultats = moteur.matches(in: texte, options: [], range: NSRange(location: 0, length: unites.count))
        if resultats.isEmpty { return texte }
        var sortie: [UInt16] = []
        var position = 0
        for (rang, resultat) in resultats.enumerated() {
            if rang > 0 && position >= unites.count { break }
            let trouvee = correspondance(resultat, unites)
            sortie.append(contentsOf: unites[position..<trouvee.plage.lowerBound])
            sortie.append(contentsOf: transforme(trouvee).utf16)
            position = trouvee.plage.upperBound
        }
        sortie.append(contentsOf: unites[position...])
        return Unites.texte(sortie)
    }

    /// `split(texte)` de Kotlin : les morceaux entre les correspondances, vides compris, y compris en fin.
    public func decoupe(_ texte: String) -> [String] {
        let unites = Array(texte.utf16)
        let resultats = moteur.matches(in: texte, options: [], range: NSRange(location: 0, length: unites.count))
        if resultats.isEmpty { return [texte] }
        var morceaux: [String] = []
        var position = 0
        for resultat in resultats {
            let etendue = resultat.range
            morceaux.append(Unites.texte(unites[position..<etendue.location]))
            position = etendue.location + etendue.length
        }
        morceaux.append(Unites.texte(unites[position...]))
        return morceaux
    }
}
