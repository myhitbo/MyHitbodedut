import Foundation

/// Les fichiers du dépôt, lus là où ils sont (comme Tests/CoeurTests/Fichiers.swift) : rien n'est recopié.
enum Fichiers {
    /// …/ios/Paquets/Coeur/Tests/EcransTests/Fichiers.swift → la racine du dépôt.
    static let racine: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    /// Les contenus exportés par tools/export_contenu (ios/Ressources/Contenu) : lancer l'export avant les tests.
    static let contenu: URL = racine.appendingPathComponent("ios/Ressources/Contenu")

    static func donnees(_ chemin: String) throws -> Data {
        try Data(contentsOf: racine.appendingPathComponent(chemin))
    }

    /// ios/Ressources/Chaines/Localizable.xcstrings, écrit par l'export d'après les strings.xml d'Android.
    static func catalogue() throws -> Data {
        try donnees("ios/Ressources/Chaines/Localizable.xcstrings")
    }
}

/// Le catalogue de chaînes tel qu'il est écrit, langue par langue, sans aucun repli : de quoi juger le
/// Traducteur et les clés des écrans.
struct CatalogueBrut: Decodable {
    struct Unite: Decodable {
        let value: String
    }
    struct Forme: Decodable {
        let stringUnit: Unite?
    }
    struct Variations: Decodable {
        let plural: [String: Forme]?
    }
    struct Traduction: Decodable {
        let stringUnit: Unite?
        let variations: Variations?
    }
    struct Entree: Decodable {
        let localizations: [String: Traduction]?
    }

    let sourceLanguage: String
    let strings: [String: Entree]

    static func lire() throws -> CatalogueBrut {
        try JSONDecoder().decode(CatalogueBrut.self, from: Fichiers.catalogue())
    }

    /// La chaîne simple `cle` dans `langue`, telle qu'écrite ; nil si cette langue ne l'a pas.
    func valeur(_ cle: String, langue: String) -> String? {
        strings[cle]?.localizations?[langue]?.stringUnit?.value
    }

    /// La forme `forme` du pluriel `cle` dans `langue`, telle qu'écrite.
    func forme(_ cle: String, _ forme: String, langue: String) -> String? {
        strings[cle]?.localizations?[langue]?.variations?.plural?[forme]?.stringUnit?.value
    }
}
