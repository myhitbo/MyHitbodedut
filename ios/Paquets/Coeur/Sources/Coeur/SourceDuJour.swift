import Foundation

/// La source du jour (SourceDuJour.kt, proposition 10 de la feuille de route, 19/10) : un paragraphe des
/// sources de la bibliothèque, le même toute la journée et pour tous, distinct du 'hizouk, avec deux
/// sorties : commencer, ou lire la suite. Seules les sources libres y entrent (les entrées « source » de
/// bibliotheque.json, dans la forme que leur licence permet) ; jamais les articles sans autorisation. Le
/// web choisit le même paragraphe le même jour (regles.js). La carte elle-même viendra avec l'accueil
/// (ROADMAP, tâche 15).
public enum SourceDuJour {

    public struct Pensee: Sendable, Equatable {
        public let source: SourceBibliotheque
        public let texte: String
    }

    /// Un paragraphe plus court n'a pas assez à dire seul (en unités UTF-16, comme `length`).
    public static let min = 80

    /// Le pas entre deux jours : premier, il fait passer d'une source à l'autre plutôt que de paragraphe en paragraphe.
    private static let pas = 37

    public static func candidats(_ bibliotheque: Bibliotheque) -> [Pensee] {
        bibliotheque.entrees.flatMap { entree -> [Pensee] in
            guard case .source(let s) = entree else { return [] }
            return bibliotheque.paragraphes(de: s).filter { $0.utf16.count >= min }.map { Pensee(source: s, texte: $0) }
        }
    }

    public static func choix(_ bibliotheque: Bibliotheque, _ jour: JourCivil) -> Pensee? {
        let c = candidats(bibliotheque)
        if c.isEmpty { return nil }
        return c[Kotlin.floorMod((jour.jourJulien - 2_440_588) * pas, c.count)]
    }

    /// `trimEnd(',', ' ', ':', ';')` : la virgule, l'espace, les deux-points, le point-virgule.
    private static let finales: Set<UInt16> = [0x2C, 0x20, 0x3A, 0x3B]

    /// Un extrait qui tient sur l'accueil : coupé à un mot, jamais au milieu.
    public static func extrait(_ texte: String, max: Int = 320) -> String {
        if texte.utf16.count <= max { return texte }
        let debut = texte.premieresUnites(max)
        // substringBeforeLast(' ') : tout le texte s'il n'y a pas d'espace.
        var unites = Array((debut.dernierePositionUnites(de: " ").map { debut.premieresUnites($0) } ?? debut).utf16)
        while let derniere = unites.last, finales.contains(derniere) { unites.removeLast() }
        return Unites.texte(unites) + "…"
    }
}

extension Bibliotheque {
    /// `LibraryRules.paragraphs` : les paragraphes vocalisés si l'édition le permet, sinon ceux sans
    /// nikkoud, à défaut les vocalisés.
    public func paragraphes(de source: SourceBibliotheque) -> [String] {
        if editions[source.edition]?.nikkoudOk ?? false { return source.paragraphes }
        return source.paragraphesSansNikkoud.isEmpty ? source.paragraphes : source.paragraphesSansNikkoud
    }
}
