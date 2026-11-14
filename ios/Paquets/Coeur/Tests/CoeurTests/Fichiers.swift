import Foundation
@testable import Coeur

/// Les fichiers de référence du dépôt, lus là où ils sont : rien n'est recopié
/// (le juge reste le même fichier pour Android, le site et iOS).
enum Depot {
    /// …/ios/Paquets/Coeur/Tests/CoeurTests/Fichiers.swift → la racine du dépôt.
    static let racine: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    static func donnees(_ chemin: String) throws -> Data {
        try Data(contentsOf: racine.appendingPathComponent(chemin))
    }

    /// Un contenu exporté par tools/export_contenu (ios/Ressources/Contenu) : lancer l'export avant les tests.
    static func contenu(_ nom: String) throws -> Data {
        try donnees("ios/Ressources/Contenu/" + nom)
    }

    /// Un contenu exporté, en texte (UTF-8).
    static func texte(_ nom: String) throws -> String {
        String(decoding: try contenu(nom), as: UTF8.self)
    }

    /// Un fichier de vecteurs écrit par le code d'Android (tools/vecteurs_ios, Tests/Vecteurs).
    static func vecteurs(_ nom: String) throws -> ObjetJSON {
        try ObjetJSON(texte: String(decoding: donnees("ios/Paquets/Coeur/Tests/Vecteurs/" + nom), as: UTF8.self))
    }

    /// Le lecteur des contenus exportés (`LecteurContenu`) : nil pour un fichier absent.
    static func lire(_ chemin: String) throws -> Data? {
        let url = racine.appendingPathComponent("ios/Ressources/Contenu/" + chemin)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }
}

/// ios/Ressources/Chaines/Localizable.xcstrings, écrit par l'export d'après les strings.xml d'Android.
struct Catalogue: Decodable {
    struct Unite: Decodable { let value: String }
    struct Forme: Decodable { let stringUnit: Unite }
    struct Variations: Decodable { let plural: [String: Forme] }
    struct Localisation: Decodable {
        let stringUnit: Unite?
        let variations: Variations?
    }
    struct Entree: Decodable { let localizations: [String: Localisation] }

    let sourceLanguage: String
    let strings: [String: Entree]

    static let langues = ["fr", "en", "he"]

    static func lire() throws -> Catalogue {
        try JSONDecoder().decode(Catalogue.self, from: Depot.donnees("ios/Ressources/Chaines/Localizable.xcstrings"))
    }

    /// Les chaînes simples d'une langue : clé → valeur.
    func simples(_ langue: String) -> [String: String] {
        strings.compactMapValues { $0.localizations[langue]?.stringUnit?.value }
    }

    /// Les pluriels d'une langue : « clé[forme] » → valeur.
    func pluriels(_ langue: String) -> [String: String] {
        var resultat: [String: String] = [:]
        for (cle, entree) in strings {
            for (forme, valeur) in entree.localizations[langue]?.variations?.plural ?? [:] {
                resultat["\(cle)[\(forme)]"] = valeur.stringUnit.value
            }
        }
        return resultat
    }
}

/// Les lieux des tests d'Android (ZmanimTest.kt, tools/vecteurs_kosherjava/Vecteurs.kt).
enum Lieux {
    static let jerusalem = Zmanim.Lieu(nom: "Jérusalem", latitude: 31.76904, longitude: 35.21633, fuseau: "Asia/Jerusalem")
    static let paris = Zmanim.Lieu(nom: "Paris", latitude: 48.85341, longitude: 2.3488, fuseau: "Europe/Paris")
    static let newYork = Zmanim.Lieu(nom: "New York", latitude: 40.71427, longitude: -74.00597, fuseau: "America/New_York")
    static let melbourne = Zmanim.Lieu(nom: "Melbourne", latitude: -37.814, longitude: 144.96332, fuseau: "Australia/Melbourne")
    static let tromso = Zmanim.Lieu(nom: "Tromsø", latitude: 69.6492, longitude: 18.9553, fuseau: "Europe/Oslo")

    static let parNom: [String: Zmanim.Lieu] = [
        "Jérusalem": jerusalem, "Paris": paris, "New York": newYork, "Melbourne": melbourne,
    ]
}

extension JourCivil {
    /// Une date écrite dans un test : illisible, c'est une faute du test lui-même.
    static func du(_ iso: String) -> JourCivil {
        guard let date = JourCivil(iso: iso) else { preconditionFailure("date illisible : \(iso)") }
        return date
    }

    /// Les jours de `debut` inclus à `fin` exclu, comme `generateSequence { it.plusDays(1) }` des tests d'Android.
    static func jours(_ debut: String, avant fin: String) -> [JourCivil] {
        let a = du(debut), b = du(fin)
        return (0..<max(0, b.jourJulien - a.jourJulien)).map { a.plus(jours: $0) }
    }

    /// Minuit UTC de ce jour, en millisecondes Unix, plus `heures`.
    func millisUTC(heures: Int = 0) -> Int64 {
        Int64(jourJulien - 2_440_588) * 86_400_000 + Int64(heures) * 3_600_000
    }
}
