import Foundation

// Les contenus exportés d'Android (tools/export_contenu, ios/Ressources/Contenu), en types Swift.
// Décodage tolérant, comme org.json et ses opt* sur Android : un champ absent ou null prend la
// valeur vide, une chaîne vide vaut nil là où Android rend null (Json.nullable).

/// Un titre en hébreu, français et anglais ; l'hébreu sert de repli (LocalizedText).
public struct TexteLocalise: Sendable, Equatable, Decodable {
    public let he: String, fr: String, en: String

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        he = c.texte("he")
        fr = c.texte("fr")
        en = c.texte("en")
    }

    public init(he: String, fr: String, en: String) {
        self.he = he
        self.fr = fr
        self.en = en
    }

    public static let vide = TexteLocalise(he: "", fr: "", en: "")

    /// Trois langues, et l'hébreu en dernier recours, seul champ sûrement rempli (forLanguage).
    /// Une langue que ce `switch` ne nomme pas serait servie en hébreu sans que rien ne le signale.
    public func pour(_ langue: String) -> String {
        switch langue {
        case "fr": fr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? he : fr
        case "en": en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? he : en
        default: he
        }
    }
}

/// Une édition déclarée dans `_meta.editions` (Json.editions).
public struct Edition: Sendable, Equatable {
    public let cle: String
    public let titre: String
    public let licence: String
    /// Faux : le texte est livré sans la vocalisation de l'éditeur (LicencesEditionsTest).
    public let nikkoudOk: Bool
}

/// Les moments où un texte de 'hizouk peut paraître (Chizuk.kt).
public enum Moment: String, Sendable, CaseIterable {
    case ouverture, blocage, porte, relance, cloture, lieu, demande
}

public struct ChizukItem: Sendable, Equatable, Decodable {
    public let id: String
    /// Les clés inconnues sont ignorées, comme Moment.of.
    public let moments: [Moment]
    public let theme: String?
    public let edition: String
    public let ref: String
    public let he: String
    public let heSansNikkoud: String?
    public let fr: String
    public let en: String
    public let note: String?
    public let dureeLectureSec: Int
    public let statutVerif: String
    public let relu: Bool

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        id = try c.decode(String.self, forKey: Cle("id"))
        moments = c.liste("moments").compactMap(Moment.init(rawValue:))
        theme = c.texteOuNil("theme")
        edition = c.texte("edition")
        ref = c.texte("ref")
        he = c.texte("he")
        heSansNikkoud = c.texteOuNil("he_sans_nikkoud")
        fr = c.texte("fr")
        en = c.texte("en")
        note = c.texteOuNil("note")
        dureeLectureSec = c.entier("duree_lecture_sec")
        statutVerif = c.texte("statut_verif")
        relu = c.booleen("relu")
    }
}

/// `chizuk.json`.
public struct Chizuk: Sendable, Decodable {
    public let version: String
    public let editions: [String: Edition]
    public let items: [ChizukItem]

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        let meta = try c.nestedContainer(keyedBy: Cle.self, forKey: Cle("_meta"))
        version = meta.texte("version")
        editions = meta.editions()
        items = try c.decode([ChizukItem].self, forKey: Cle("items"))
    }

    public func item(_ id: String) -> ChizukItem? { items.first { $0.id == id } }
}

// MARK: Bibliothèque

public struct SourceBibliotheque: Sendable, Equatable {
    public let id: String
    public let titreHe: String
    public let ref: String
    public let url: String?
    public let edition: String
    public let paragraphes: [String]
    public let paragraphesSansNikkoud: [String]
    public let liensChizuk: [String]
    public let paragraphesFr: [String]
    public let paragraphesEn: [String]
    public let statutVerif: String
    public let sujet: String?
    public let leconSurLeSujet: String?
}

public struct ArticleBibliotheque: Sendable, Equatable {
    public let id: String
    public let titre: String
    public let auteur: String?
    public let site: String?
    public let date: String?
    public let url: String?
    /// Langue → résumé (clés `resume_<langue>`).
    public let resumes: [String: String]
    /// Langue → mention des droits (clés `droits_<langue>`).
    public let droits: [String: String]
    public let autorisation: String?
    /// Absent pour un article en fiche seulement.
    public let texteIntegral: String?
    public let sourcesCitees: [String]
}

/// Une entrée : une source (texte livré) ou un article (fiche).
public enum EntreeBibliotheque: Sendable, Equatable, Decodable {
    case source(SourceBibliotheque)
    case article(ArticleBibliotheque)

    public var id: String {
        switch self {
        case .source(let s): s.id
        case .article(let a): a.id
        }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        let id = try c.decode(String.self, forKey: Cle("id"))
        if c.texte("type") == "source" {
            self = .source(SourceBibliotheque(
                id: id, titreHe: c.texte("titre_he"), ref: c.texte("ref"), url: c.texteOuNil("url"),
                edition: c.texte("edition"), paragraphes: c.liste("paragraphes"),
                paragraphesSansNikkoud: c.liste("paragraphes_sans_nikkoud"),
                liensChizuk: c.liste("liens_chizuk"), paragraphesFr: c.liste("paragraphes_fr"),
                paragraphesEn: c.liste("paragraphes_en"), statutVerif: c.texte("statut_verif"),
                sujet: c.texteOuNil("sujet"), leconSurLeSujet: c.texteOuNil("lecon_sur_le_sujet")))
        } else {
            self = .article(ArticleBibliotheque(
                id: id, titre: c.texte("titre"), auteur: c.texteOuNil("auteur"), site: c.texteOuNil("site"),
                date: c.texteOuNil("date"), url: c.texteOuNil("url"),
                resumes: c.parLangue("resume_"), droits: c.parLangue("droits_"),
                autorisation: c.texteOuNil("autorisation"), texteIntegral: c.texteOuNil("texte_integral"),
                sourcesCitees: c.liste("sources_citees")))
        }
    }
}

public struct SousSection: Sendable, Equatable, Decodable {
    public let id: String
    public let titre: TexteLocalise
    public let entrees: [EntreeBibliotheque]

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        id = try c.decode(String.self, forKey: Cle("id"))
        titre = (try? c.decodeIfPresent(TexteLocalise.self, forKey: Cle("titre"))) ?? .vide
        entrees = (try c.decodeIfPresent([EntreeBibliotheque].self, forKey: Cle("entrees"))) ?? []
    }
}

public struct SectionBibliotheque: Sendable, Equatable, Decodable {
    public let id: String
    public let titre: TexteLocalise
    public let sousSections: [SousSection]

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        id = try c.decode(String.self, forKey: Cle("id"))
        titre = (try? c.decodeIfPresent(TexteLocalise.self, forKey: Cle("titre"))) ?? .vide
        sousSections = (try c.decodeIfPresent([SousSection].self, forKey: Cle("sous_sections"))) ?? []
    }
}

/// `bibliotheque.json` (Library.kt).
public struct Bibliotheque: Sendable, Decodable {
    public let version: String
    public let editions: [String: Edition]
    public let sections: [SectionBibliotheque]

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        let meta = try c.nestedContainer(keyedBy: Cle.self, forKey: Cle("_meta"))
        version = meta.texte("version")
        editions = meta.editions()
        sections = try c.decode([SectionBibliotheque].self, forKey: Cle("sections"))
    }

    public var entrees: [EntreeBibliotheque] { sections.flatMap { $0.sousSections.flatMap(\.entrees) } }

    public func sousSection(_ id: String) -> SousSection? {
        for section in sections {
            if let trouvee = section.sousSections.first(where: { $0.id == id }) { return trouvee }
        }
        return nil
    }

    public func entree(_ id: String) -> EntreeBibliotheque? { entrees.first { $0.id == id } }
}

// MARK: Villes

/// `villes.json` : GeoNames, CC-BY 4.0 (Villes.kt).
public struct Ville: Sendable, Equatable, Decodable {
    public let id: Int64
    public let nom: TexteLocalise
    public let pays: String
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let fuseau: String

    public var enIsrael: Bool { pays == "IL" }

    public init(id: Int64, nom: TexteLocalise, pays: String, latitude: Double, longitude: Double, altitude: Double = 0,
                fuseau: String) {
        self.id = id
        self.nom = nom
        self.pays = pays
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.fuseau = fuseau
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        id = try c.decode(Int64.self, forKey: Cle("id"))
        nom = try c.decode(TexteLocalise.self, forKey: Cle("nom"))
        pays = try c.decode(String.self, forKey: Cle("pays"))
        latitude = try c.decode(Double.self, forKey: Cle("latitude"))
        longitude = try c.decode(Double.self, forKey: Cle("longitude"))
        altitude = (try? c.decodeIfPresent(Double.self, forKey: Cle("altitude"))) ?? 0
        fuseau = try c.decode(String.self, forKey: Cle("fuseau"))
    }

    /// Le lieu des zmanim de cette ville.
    public var lieu: Zmanim.Lieu {
        Zmanim.Lieu(nom: nom.fr, latitude: latitude, longitude: longitude, altitude: altitude, fuseau: fuseau)
    }
}

public enum Villes {
    public static let source = "GeoNames (CC-BY 4.0)"

    private struct Fichier: Decodable { let villes: [Ville] }

    public static func lire(_ donnees: Data) throws -> [Ville] {
        try JSONDecoder().decode(Fichier.self, from: donnees).villes
    }
}

// MARK: Musique

/// Un morceau livré (`musique.json`, dans l'ordre de MusiquePlay.kt) : jamais ceux de
/// `src/musique_hors_play`, que seule la version GitHub d'Android livre.
public struct Morceau: Sendable, Equatable, Decodable {
    public let id: String
    /// La clé de son titre dans les chaînes (`track_<id>`).
    public let titre: String
    /// Son chemin sous `ios/Ressources` (`Musique/<id>.m4a`).
    public let fichier: String
    public let octets: Int

    public static func lire(_ donnees: Data) throws -> [Morceau] {
        try JSONDecoder().decode([Morceau].self, from: donnees)
    }
}

// MARK: Décodage tolérant

struct Cle: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ valeur: String) { stringValue = valeur }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where Key == Cle {
    /// optString(clé, "")
    func texte(_ cle: String) -> String {
        (try? decodeIfPresent(String.self, forKey: Cle(cle))) ?? ""
    }

    /// Json.nullable : absent, null ou blanc → nil.
    func texteOuNil(_ cle: String) -> String? {
        let valeur = texte(cle)
        return valeur.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : valeur
    }

    /// Json.strings : absent → liste vide.
    func liste(_ cle: String) -> [String] {
        (try? decodeIfPresent([String].self, forKey: Cle(cle))) ?? []
    }

    func entier(_ cle: String) -> Int {
        (try? decodeIfPresent(Int.self, forKey: Cle(cle))) ?? 0
    }

    func booleen(_ cle: String) -> Bool {
        (try? decodeIfPresent(Bool.self, forKey: Cle(cle))) ?? false
    }

    /// Les clés `<préfixe><langue>` → [langue: texte], les vides écartées.
    func parLangue(_ prefixe: String) -> [String: String] {
        var resultat: [String: String] = [:]
        for cle in allKeys where cle.stringValue.hasPrefix(prefixe) {
            if let valeur = texteOuNil(cle.stringValue) {
                resultat[String(cle.stringValue.dropFirst(prefixe.count))] = valeur
            }
        }
        return resultat
    }

    /// `_meta.editions` : { clé: { titre, licence, nikkoud_ok } }.
    func editions() -> [String: Edition] {
        guard let e = try? nestedContainer(keyedBy: Cle.self, forKey: Cle("editions")) else { return [:] }
        var resultat: [String: Edition] = [:]
        for cle in e.allKeys {
            guard let d = try? e.nestedContainer(keyedBy: Cle.self, forKey: cle) else { continue }
            resultat[cle.stringValue] = Edition(cle: cle.stringValue, titre: d.texte("titre"),
                                                licence: d.texte("licence"), nikkoudOk: d.booleen("nikkoud_ok"))
        }
        return resultat
    }
}
