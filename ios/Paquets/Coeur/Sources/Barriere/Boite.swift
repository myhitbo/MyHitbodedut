import Foundation

// barriere/boite.jsonl (PORTAGE.md § 3.2) : les extensions n'écrivent jamais le journal, elles ajoutent une
// ligne à la boîte (« déjà faite », « plus tard », réveils) ; l'app la lit, verse au journal ce qui doit
// l'être, garde les cinquante derniers événements pour l'écran « Journal de la barrière » (§ 2.1.8), puis la
// vide. Un seul écrivain par ligne, ajout seul : pas de verrou entre processus.

/// Un événement de la boîte, horodaté dans le fuseau du téléphone.
public struct Evenement: Codable, Sendable, Equatable {

    /// Les genres connus. Le genre est gardé en texte : une ligne d'un genre inconnu (écrite par une autre
    /// version) se lit quand même.
    public enum Genre: String, Sendable, CaseIterable {
        /// « Je l'ai déjà faite » : vaut une séance close à cet instant (`Store.addSession(context, 0)`).
        case dejaFaite = "deja_faite"
        /// « Plus tard » ; le détail donne la durée du report en minutes.
        case plusTard = "plus_tard"
        /// « Commencer » : l'app, en s'ouvrant, démarre la séance à la durée habituelle.
        case commencer
        /// L'extension de surveillance s'est réveillée ; le détail nomme l'activité (`fenetre`, `minuit`…).
        case reveil
        /// Le magasin `barriere` a été activé, ou désactivé ; le détail dit par qui.
        case armee
        case levee
        /// L'essai réel de deux minutes, ou sa fin.
        case essai
    }

    public var quand: Horodatage
    public var genre: String
    public var detail: String

    public init(quand: Horodatage, genre: String, detail: String = "") {
        self.quand = quand
        self.genre = genre
        self.detail = detail
    }

    public init(quand: Horodatage, genre: Genre, detail: String = "") {
        self.init(quand: quand, genre: genre.rawValue, detail: detail)
    }

    /// Le genre, s'il est de ceux que cette version connaît.
    public var genreConnu: Genre? { Genre(rawValue: genre) }

    private enum CodingKeys: String, CodingKey {
        case quand, genre, detail
    }

    /// Un instant et un genre sont exigés ; le détail est facultatif.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quand = try c.decode(Horodatage.self, forKey: .quand)
        genre = try c.decode(String.self, forKey: .genre)
        detail = (try? c.decodeIfPresent(String.self, forKey: .detail)) ?? ""
    }
}

/// Lire et écrire la boîte.
public enum Boite {

    public static let nomFichier = "boite.jsonl"
    /// Le journal de la barrière garde les cinquante derniers événements.
    public static let maximum = 50

    /// Une ligne du fichier : l'événement en JSON, clés triées, suivi d'un saut de ligne.
    public static func ligne(_ evenement: Evenement) -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]
        var donnees = (try? encodeur.encode(evenement)) ?? Data()
        donnees.append(0x0A)
        return donnees
    }

    /// Les événements du fichier, dans l'ordre où ils ont été ajoutés, les `garder` derniers seulement.
    /// Lecture tolérante : une ligne vide, tronquée (un ajout interrompu) ou illisible est sautée, les
    /// autres restent ; un retour chariot en fin de ligne est admis.
    public static func lire(_ donnees: Data, garder: Int = maximum) -> [Evenement] {
        let decodeur = JSONDecoder()
        var evenements: [Evenement] = []
        for morceau in donnees.split(separator: 0x0A, omittingEmptySubsequences: true) {
            if let evenement = try? decodeur.decode(Evenement.self, from: Data(morceau)) {
                evenements.append(evenement)
            }
        }
        return Array(evenements.suffix(max(garder, 0)))
    }

    /// Ajoute un événement à la fin du fichier, qui est créé s'il n'existe pas.
    public static func ajouter(_ evenement: Evenement, a url: URL) throws {
        let donnees = ligne(evenement)
        guard let poignee = try? FileHandle(forWritingTo: url) else {
            try donnees.write(to: url)
            return
        }
        defer { _ = try? poignee.close() }
        _ = try poignee.seekToEnd()
        try poignee.write(contentsOf: donnees)
    }

    /// Vide la boîte, une fois ses événements versés au journal par l'app.
    public static func vider(_ url: URL) throws {
        try Data().write(to: url)
    }

    /// Le dernier réveil de l'extension de surveillance, pour l'état « Surveillance muette » ; nil si la
    /// boîte n'en contient pas.
    public static func dernierReveil(_ evenements: [Evenement]) -> Int64? {
        var dernier: Int64?
        for evenement in evenements where evenement.genre == Evenement.Genre.reveil.rawValue {
            if let deja = dernier, deja >= evenement.quand.millis { continue }
            dernier = evenement.quand.millis
        }
        return dernier
    }
}
