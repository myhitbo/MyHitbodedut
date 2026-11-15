// La bibliothèque de morceaux (MusicLibrary.kt) : les morceaux livrés (MusiquePlay), puis ceux que
// l'utilisateur a ajoutés depuis ses fichiers ; les noms qu'il leur donne ; le morceau retenu.
//
// Store garde trois préférences, que les règles reçoivent ici en argument (`Etat`) : « music_names »,
// un objet JSON id → nom donné ; « music_user_tracks », un tableau JSON de {uri, title} ;
// « music_track », le morceau choisi. Une écriture rend l'état nouveau, que l'app recopie dans ses
// réglages. Le JSON se lit et s'écrit comme org.json d'Android (Socle/JSON.swift), et un texte
// illisible ne vaut rien, comme le `runCatching` du Kotlin : aucun nom, aucun morceau ajouté. Lire les
// fichiers, les importer et les jouer reste à l'app.

/// Les morceaux jouables pendant la séance.
public enum MusicLibrary {

    /// Le titre d'un morceau : un nom écrit tel quel, ou le titre livré, une chaîne de l'interface.
    public enum Titre: Sendable, Hashable {
        /// Le nom donné par l'utilisateur, ou celui d'un fichier ajouté.
        case nom(String)
        /// Le titre d'un morceau livré, tant qu'il n'est pas renommé (`getString(b.titleRes)`).
        case libelle(Libelle)

        /// Le texte dans `langue`, comme `Libelle.texte` ; un nom se rend tel quel.
        public func texte(langue: String, chaine: (String) -> String?, pluriel: (String, String) -> String?) -> String? {
            switch self {
            case .nom(let nom):
                return nom
            case .libelle(let libelle):
                return libelle.texte(langue: langue, chaine: chaine, pluriel: pluriel)
            }
        }
    }

    /// Un morceau jouable (Track de MusicLibrary.kt) : livré avec l'application (`rawRes`, le nom de son
    /// fichier), ou choisi par l'utilisateur (`uri`, l'adresse de son fichier, qui est aussi son id).
    public struct Track: Sendable, Hashable {
        public let id: String
        public let title: Titre
        public let rawRes: String?
        public let uri: String?

        public init(id: String, title: Titre, rawRes: String? = nil, uri: String? = nil) {
            self.id = id
            self.title = title
            self.rawRes = rawRes
            self.uri = uri
        }

        public var isBundled: Bool { rawRes != nil }
    }

    /// Ce que Store garde de la bibliothèque, avec ses valeurs par défaut.
    public struct Etat: Sendable, Equatable {
        /// « music_names » : « {} » par défaut.
        public var names: String
        /// « music_user_tracks » : « [] » par défaut.
        public var userTracks: String
        /// « music_track » : nil tant que rien n'est choisi.
        public var trackId: String?

        public init(names: String = "{}", userTracks: String = "[]", trackId: String? = nil) {
            self.names = names
            self.userTracks = userTracks
            self.trackId = trackId
        }
    }

    /// Les morceaux livrés : ceux de la version Play, les seuls qu'iOS livre (la liste « hors Play » est
    /// vide pour lui, PUBLICATION_PLAY_STORE.md § 3.2).
    private static let bundled = MusiquePlay.morceaux

    /// Les morceaux livrés, dans l'ordre de MusiquePlay, puis ceux qu'on a ajoutés, dans l'ordre d'ajout.
    public static func all(_ etat: Etat) -> [Track] {
        let noms = objet(etat.names)
        let livres = bundled.map { b -> Track in
            let titre: Titre
            if let nom = nameOf(noms, b.id) {
                titre = .nom(nom)
            } else {
                titre = .libelle(Libelle(b.titleRes))
            }
            return Track(id: b.id, title: titre, rawRes: b.rawRes)
        }
        return livres + userTracks(etat, noms)
    }

    /// Le morceau de cet id, le premier s'il y en a deux ; nil pour un id absent.
    public static func byId(_ etat: Etat, _ id: String?) -> Track? {
        guard let id else { return nil }
        return all(etat).first { $0.id.egalUnites(id) }
    }

    /// Le morceau retenu pour les séances, ou le premier disponible.
    public static func selected(_ etat: Etat) -> Track? {
        byId(etat, etat.trackId) ?? all(etat).first
    }

    // MARK: Morceaux ajoutés par l'utilisateur

    /// Une entrée sans adresse (absente ou blanche) est sautée ; sans titre, l'adresse en tient lieu.
    private static func userTracks(_ etat: Etat, _ noms: ObjetJSON?) -> [Track] {
        guard let entrees = tableau(etat.userTracks) else { return [] }
        var out: [Track] = []
        for rang in entrees.indices {
            guard let entree = entrees.objet(rang) else { continue }
            let id = entree.texte("uri")
            if id.estBlanc { continue }
            let stored = entree.texte("title")
            let titre = nameOf(noms, id) ?? (stored.estBlanc ? id : stored)
            out.append(Track(id: id, title: .nom(titre), uri: id))
        }
        return out
    }

    /// Ajoute un fichier, s'il n'y est pas déjà : la liste reste telle quelle sinon. Une liste illisible
    /// est remplacée par une liste neuve.
    public static func addUserTrack(_ etat: inout Etat, uri: String, title: String) {
        var entrees = tableau(etat.userTracks) ?? []
        let deja = entrees.indices.contains { rang in
            entrees.objet(rang)?.texte("uri").egalUnites(uri) ?? false
        }
        if deja { return }
        entrees.append(.objet(ObjetJSON([("uri", .chaine(uri)), ("title", .chaine(title))])))
        etat.userTracks = JSON.tableau(entrees).texte()
    }

    /// Retire un fichier (et toute entrée qui n'est pas un objet) ; s'il était le morceau choisi, plus
    /// rien ne l'est. Une liste illisible n'est pas touchée.
    public static func removeUserTrack(_ etat: inout Etat, id: String) {
        guard let entrees = tableau(etat.userTracks) else { return }
        var kept: [JSON] = []
        for rang in entrees.indices {
            guard let entree = entrees.objet(rang) else { continue }
            if !entree.texte("uri").egalUnites(id) { kept.append(.objet(entree)) }
        }
        etat.userTracks = JSON.tableau(kept).texte()
        if let choisi = etat.trackId, choisi.egalUnites(id) { etat.trackId = nil }
    }

    // MARK: Renommage

    /// Le nom donné par l'utilisateur, ou nil s'il porte encore son titre livré.
    public static func customName(_ etat: Etat, id: String) -> String? {
        nameOf(objet(etat.names), id)
    }

    /// Donne un nom ; un nom blanc retire l'entrée, et le morceau reprend son titre d'origine.
    public static func rename(_ etat: inout Etat, id: String, title: String) {
        var noms = objet(etat.names) ?? ObjetJSON()
        if title.estBlanc {
            noms[id] = nil
        } else {
            noms[id] = .chaine(title)
        }
        etat.names = noms.texte()
    }

    // MARK: Lecture

    /// `optString(id)` des noms, nil s'il est blanc. Comme sur Android, un `null` écrit vaut « null ».
    private static func nameOf(_ noms: ObjetJSON?, _ id: String) -> String? {
        guard let noms else { return nil }
        let valeur = noms.texte(id)
        return valeur.estBlanc ? nil : valeur
    }

    /// `JSONObject(texte)` d'Android, ou nil.
    private static func objet(_ texte: String) -> ObjetJSON? {
        try? ObjetJSON(texte: texte)
    }

    /// `JSONArray(texte)` d'Android, ou nil : la racine doit être un tableau ; ce qui le suit est ignoré.
    private static func tableau(_ texte: String) -> [JSON]? {
        var lecteur = LecteurJSON(texte)
        guard case .tableau(let valeurs)? = try? lecteur.valeur(0) else { return nil }
        return valeurs
    }
}
