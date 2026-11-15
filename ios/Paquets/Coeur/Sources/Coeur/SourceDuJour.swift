import Foundation

/// La source du jour (SourceDuJour.kt, proposition 10 de la feuille de route, 19/10) : un paragraphe
/// des sources de la bibliothèque, le même toute la journée et pour tous, distinct du 'hizouk.
///
/// Seules les sources libres y entrent (les entrées « source » de bibliotheque.json, dans la forme que
/// leur licence permet : `LibraryRules.paragraphs`) ; jamais les articles. Le site choisit le même
/// paragraphe le même jour (web/src/js/regles.js, SourceDuJour). La carte de l'accueil (`carte`) reste
/// à l'écran : il lit le jour qu'il est et le passe à `choix`.
public enum SourceDuJour {

    /// Un paragraphe et la source d'où il vient.
    public struct Pensee: Sendable, Equatable {
        public let source: SourceBibliotheque
        public let texte: String

        public init(source: SourceBibliotheque, texte: String) {
            self.source = source
            self.texte = texte
        }
    }

    /// Un paragraphe plus court n'a pas assez à dire seul. En unités UTF-16, comme `length` de Kotlin :
    /// une lettre hébraïque et sa voyelle en font deux.
    public static let min = 80

    /// Le pas entre deux jours : premier, il fait passer d'une source à l'autre plutôt que de
    /// paragraphe en paragraphe.
    private static let pas = 37

    /// Le 1er janvier 1970 en jour julien : `toEpochDay()` de Java vaut `jourJulien` moins ce nombre.
    private static let jourJulien1970 = 2_440_588

    /// Ce que `trimEnd(',', ' ', ':', ';')` retire au bout d'un extrait, et rien d'autre (ni tabulation,
    /// ni espace insécable, ni retour à la ligne).
    private static let finales: Set<UInt16> = [0x2C, 0x20, 0x3A, 0x3B]

    /// L'espace ordinaire, où un extrait se coupe (`substringBeforeLast(' ')`).
    private static let espace: UInt16 = 0x20

    /// Tous les paragraphes assez longs des sources, dans l'ordre de la bibliothèque.
    public static func candidats(_ library: Bibliotheque) -> [Pensee] {
        var resultat: [Pensee] = []
        for entree in library.entrees {
            guard case .source(let source) = entree else { continue }
            for paragraphe in LibraryRules.paragraphs(library, source) where paragraphe.utf16.count >= SourceDuJour.min {
                resultat.append(Pensee(source: source, texte: paragraphe))
            }
        }
        return resultat
    }

    /// Le paragraphe du jour, ou nil si aucune source n'en a d'assez long :
    /// `floorMod(jour.toEpochDay() * 37, nombre de candidats)`.
    public static func choix(_ library: Bibliotheque, _ jour: JourCivil) -> Pensee? {
        let c = candidats(library)
        if c.isEmpty { return nil }
        let joursDepuis1970 = jour.jourJulien - jourJulien1970
        return c[Kotlin.floorMod(joursDepuis1970 * pas, c.count)]
    }

    /// Un extrait qui tient sur l'accueil : coupé à un mot, jamais au milieu. Les `max` premières unités
    /// UTF-16 (`take`), jusqu'à leur dernier espace s'il y en a un (`substringBeforeLast(' ')`), sans les
    /// virgules, espaces, deux-points et points-virgules de la fin, puis « … ».
    ///
    /// Une borne négative fait lever Kotlin (`take`) ; ici elle vaut zéro. Une coupe qui tombe au milieu
    /// d'une paire de substitution perd la moitié restée seule (`Unites.texte`), que Kotlin garderait.
    public static func extrait(_ texte: String, max: Int = 320) -> String {
        let unites = Array(texte.utf16)
        if unites.count <= max { return texte }
        let borne = max < 0 ? 0 : max
        var coupe = Array(unites.prefix(borne))
        if let position = coupe.lastIndex(of: espace) {
            coupe.removeSubrange(position...)
        }
        while let derniere = coupe.last, finales.contains(derniere) {
            coupe.removeLast()
        }
        return Unites.texte(coupe) + "…"
    }
}
