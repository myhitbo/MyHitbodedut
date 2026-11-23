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
        /// « Autre réponse » : le bouclier se redessine avec « Je l'ai déjà faite » et « Plus tard » (la deuxième page
        /// du § 2.1.4, quand le sous-menu ne paraît pas).
        case autreReponse = "autre_reponse"
        /// L'app a inscrit les heures du mode auprès d'iOS (`DeviceActivityCenter.startMonitoring`) : un signe de vie
        /// de la surveillance, comme un réveil, pour l'état « Surveillance muette ».
        case inscrite
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

    /// Ce qui reste du fichier une fois ses `octets` premiers octets lus et versés : ce qu'une extension a ajouté
    /// entre la lecture et l'écriture de l'app n'est pas perdu. Un fichier plus court (vidé entre-temps) ne garde rien.
    public static func reste(_ donnees: Data, apres octets: Int) -> Data {
        guard octets >= 0, donnees.count > octets else { return Data() }
        return Data(donnees.suffix(from: donnees.startIndex + octets))
    }

    /// Retire de la boîte les `octets` déjà lus (`reste`).
    public static func retirer(_ octets: Int, de url: URL) throws {
        let donnees = (try? Data(contentsOf: url)) ?? Data()
        try reste(donnees, apres: octets).write(to: url, options: .atomic)
    }

    /// Le journal de la barrière (§ 2.1.8) : ce qu'il gardait, puis les événements neufs, les `garder` derniers dans
    /// l'ordre des instants (un ajout se fait toujours à la fin ; une horloge remise en arrière ne mélange rien d'autre
    /// que ses propres lignes).
    public static func historique(_ ancien: [Evenement], plus neufs: [Evenement], garder: Int = maximum) -> [Evenement] {
        let tous = (ancien + neufs).enumerated().sorted { a, b in
            a.element.quand.millis != b.element.quand.millis ? a.element.quand.millis < b.element.quand.millis : a.offset < b.offset
        }.map(\.element)
        return Array(tous.suffix(max(garder, 0)))
    }

    /// Le fichier d'un journal : une ligne par événement.
    public static func donnees(_ evenements: [Evenement]) -> Data {
        var donnees = Data()
        for evenement in evenements {
            donnees.append(ligne(evenement))
        }
        return donnees
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

    /// Le dernier signe de vie de la surveillance : son dernier réveil, ou la dernière inscription de ses heures par
    /// l'app (une surveillance qu'on vient d'inscrire n'a pas encore eu l'occasion de se réveiller) ; nil sans l'un ni
    /// l'autre.
    public static func dernierSigneDeVie(_ evenements: [Evenement]) -> Int64? {
        var dernier: Int64?
        for evenement in evenements {
            guard evenement.genre == Evenement.Genre.reveil.rawValue || evenement.genre == Evenement.Genre.inscrite.rawValue
            else { continue }
            if let deja = dernier, deja >= evenement.quand.millis { continue }
            dernier = evenement.quand.millis
        }
        return dernier
    }
}

/// Qui pose ou lève le bouclier : le détail des événements `armee` et `levee`.
public enum AgentBarriere: String, Sendable, CaseIterable {
    /// L'extension de surveillance, à un rendez-vous.
    case surveillance
    /// L'app, après un changement (une séance, un réglage, la journée validée).
    case app
    /// Un bouton du bouclier (l'extension d'action).
    case bouclier
    /// L'app, qui a trouvé le magasin en désaccord avec la règle (§ 2.1.8, « Bouclier désaccordé »).
    case correction
}
