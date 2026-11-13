import Foundation

// Le siddour et les livres (Siddur.kt, LivresBruts.kt) : un même format de recueil, lu par le même
// lecteur. Décodage tolérant comme SiddurLoader : `titre` de section, `source`, `fr` et `en` peuvent
// manquer ; `chapitres` vaut le nombre de sections quand il n'est pas donné.

/// Une prière (« t », vocalisée, avec sa traduction éventuelle) ou une consigne (« c »).
public struct SiddurBloc: Sendable, Equatable, Decodable {
    public let texte: String
    public let consigne: Bool
    public let fr: String?
    public let en: String?

    public init(texte: String, consigne: Bool, fr: String? = nil, en: String? = nil) {
        self.texte = texte
        self.consigne = consigne
        self.fr = fr
        self.en = en
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        if c.contains(Cle("c")) {
            self.init(texte: try c.decode(String.self, forKey: Cle("c")), consigne: true)
        } else {
            self.init(texte: try c.decode(String.self, forKey: Cle("t")), consigne: false,
                      fr: c.texteOuNil("fr"), en: c.texteOuNil("en"))
        }
    }
}

public struct SiddurSection: Sendable, Equatable, Decodable {
    public let titre: String
    public let blocs: [SiddurBloc]
    public let titreFr: String?
    public let titreEn: String?

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        titre = c.texte("titre")
        titreFr = c.texteOuNil("titre_fr")
        titreEn = c.texteOuNil("titre_en")
        blocs = try c.decode([SiddurBloc].self, forKey: Cle("blocs"))
    }
}

public struct SiddurTexte: Sendable, Equatable, Decodable {
    public let id: String
    public let groupe: String
    public let titre: TexteLocalise
    public let source: String
    public let sections: [SiddurSection]
    /// Le nusah d'où vient le texte, quand il manque à celui-ci et a été emprunté.
    public let emprunt: TexteLocalise?
    /// Le nombre de chapitres : celui de `sections`, ou celui d'un index de livres, qui n'a pas leur texte.
    public let chapitres: Int

    public init(id: String, groupe: String, titre: TexteLocalise, source: String,
                sections: [SiddurSection], emprunt: TexteLocalise? = nil, chapitres: Int? = nil) {
        self.id = id
        self.groupe = groupe
        self.titre = titre
        self.source = source
        self.sections = sections
        self.emprunt = emprunt
        self.chapitres = chapitres ?? sections.count
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        // L'index d'un livre découpé par l'export (livres/<id>/index.json) n'a pas de sections.
        let sections = try c.decodeIfPresent([SiddurSection].self, forKey: Cle("sections")) ?? []
        self.init(id: try c.decode(String.self, forKey: Cle("id")),
                  groupe: try c.decode(String.self, forKey: Cle("groupe")),
                  titre: try c.decode(TexteLocalise.self, forKey: Cle("titre")),
                  source: c.texte("source"),
                  sections: sections,
                  emprunt: try? c.decodeIfPresent(TexteLocalise.self, forKey: Cle("nusah")),
                  chapitres: try? c.decodeIfPresent(Int.self, forKey: Cle("chapitres")))
    }

    /// Le même texte avec ses chapitres, lus à part.
    func avec(sections: [SiddurSection]) -> SiddurTexte {
        SiddurTexte(id: id, groupe: groupe, titre: titre, source: source, sections: sections, emprunt: emprunt)
    }
}

public struct SiddurGroupe: Sendable, Equatable, Decodable {
    public let cle: String
    public let titre: TexteLocalise
}

/// Les trois nusah proposés, dans l'ordre du sélecteur.
public enum Nusah: String, Sendable, CaseIterable {
    case edot, sefard, ashkenaz

    public var fichier: String { "siddur_\(rawValue).json" }

    public static func de(_ cle: String?) -> Nusah { cle.flatMap(Nusah.init(rawValue:)) ?? .edot }
}

/// Un recueil : `siddur_<nusah>.json`, `livres_titres.json` ou un livre.
public struct Siddur: Sendable, Equatable, Decodable {
    public let groupes: [SiddurGroupe]
    public let textes: [SiddurTexte]
    public let nusah: TexteLocalise
    public let sources: [String]

    public init(groupes: [SiddurGroupe], textes: [SiddurTexte], nusah: TexteLocalise = .vide, sources: [String] = []) {
        self.groupes = groupes
        self.textes = textes
        self.nusah = nusah
        self.sources = sources
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        let meta = try? c.nestedContainer(keyedBy: Cle.self, forKey: Cle("_meta"))
        self.init(groupes: try c.decode([SiddurGroupe].self, forKey: Cle("groupes")),
                  textes: try c.decode([SiddurTexte].self, forKey: Cle("textes")),
                  nusah: (try? meta?.decodeIfPresent(TexteLocalise.self, forKey: Cle("nusah"))) ?? .vide,
                  sources: meta?.liste("sources") ?? [])
    }

    public func texte(_ id: String) -> SiddurTexte? { textes.first { $0.id == id } }
    public func du(_ groupe: String) -> [SiddurTexte] { textes.filter { $0.groupe == groupe } }

    /// Les seules mentions que les licences imposent (CC-BY, CC-BY-SA), sans le nom de Sefaria
    /// (demande du 11/10) ; domaine public et CC0 n'en demandent aucune.
    public var mentions: [String] { Siddur.mentionsObligatoires(sources) }

    public static func mentionsObligatoires(_ sources: [String]) -> [String] {
        sources.filter { $0.contains("CC-BY") }
            .map { $0.replacingOccurrences(of: "Sefaria / ", with: "").replacingOccurrences(of: "Sefaria, ", with: "") }
    }
}

/// La bande de signets en tête de la lecture (demande du 10/10) : une section par signet, et celle
/// où l'on lit d'après ce qui est à l'écran. Débuts et bornes sont des positions croissantes.
public enum SignetsSiddur {
    /// L'indice du signet de la section en cours. En haut de la page : la dernière section commencée
    /// à la première ligne visible. Tout en bas, où la page ne peut plus monter, c'est la dernière
    /// commencée à l'écran ; avant le premier titre, le premier signet.
    public static func courant(_ debuts: [Int], premiere: Int, derniere: Int, enBas: Bool) -> Int {
        let borne = enBas ? derniere : premiere
        return debuts.lastIndex { $0 <= borne } ?? 0
    }
}

// MARK: Livres

/// Lit un contenu exporté par son chemin sous `Contenu/` ; nil s'il n'existe pas.
public typealias LecteurContenu = (String) throws -> Data?

public enum ErreurContenu: Error, Equatable, Sendable {
    case absent(String)
    case malForme(String)
}

/// Les livres de la bibliothèque (LivresBruts.kt) : `livres_titres.json` donne l'ordre, les groupes
/// et le nombre de chapitres, sans texte ; chaque livre est dans `livre_<id>.json` ou, au-delà de
/// 2 Mo, découpé par l'export en `livres/<id>/index.json` et un fichier par chapitre
/// (`<texte>-<chapitre>.json`, tools/export_contenu).
public enum Livres {
    public static let titres = "livres_titres.json"

    /// L'index : chaque livre avec son nombre de chapitres, sans leur texte.
    public static func index(_ lire: LecteurContenu) throws -> Siddur {
        try JSONDecoder().decode(Siddur.self, from: requis(titres, lire))
    }

    /// Un livre entier, chapitres compris.
    public static func livre(_ id: String, _ lire: LecteurContenu) throws -> SiddurTexte {
        let decodeur = JSONDecoder()
        if let donnees = try lire("livre_\(id).json") {
            let recueil = try decodeur.decode(Siddur.self, from: donnees)
            guard recueil.textes.count == 1, let texte = recueil.textes.first, texte.id == id else {
                throw ErreurContenu.malForme("livre_\(id).json")
            }
            return texte
        }
        let dossier = "livres/\(id)/"
        let index = try decodeur.decode(Siddur.self, from: requis(dossier + "index.json", lire))
        guard index.textes.count == 1, let entete = index.textes.first, entete.id == id else {
            throw ErreurContenu.malForme(dossier + "index.json")
        }
        let sections = try (0..<entete.chapitres).map { c in
            try decodeur.decode(SiddurSection.self, from: requis(dossier + chapitre(texte: 0, chapitre: c + 1), lire))
        }
        return entete.avec(sections: sections)
    }

    /// Tous les livres, dans l'ordre de l'index.
    public static func tous(_ lire: LecteurContenu) throws -> Siddur {
        let entetes = try index(lire)
        return Siddur(groupes: entetes.groupes, textes: try entetes.textes.map { try livre($0.id, lire) },
                      nusah: entetes.nusah, sources: entetes.sources)
    }

    /// `00-0001.json` : le rang du texte sur deux chiffres, celui du chapitre (dès 1) sur quatre.
    static func chapitre(texte: Int, chapitre: Int) -> String {
        func zeros(_ n: Int, _ largeur: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, largeur - s.count)) + s
        }
        return "\(zeros(texte, 2))-\(zeros(chapitre, 4)).json"
    }

    private static func requis(_ chemin: String, _ lire: LecteurContenu) throws -> Data {
        guard let donnees = try lire(chemin) else { throw ErreurContenu.absent(chemin) }
        return donnees
    }
}
