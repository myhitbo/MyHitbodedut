import Foundation

/// Un `LinkedHashMap` de Kotlin aux clés de texte : les valeurs par clé, et les clés dans l'ordre où
/// elles ont été lues, celui du fichier JSON, que le org.json d'Android garde. Un `Dictionary` de Swift
/// se parcourt dans un ordre qui change d'un lancement à l'autre (Coeur/PORTER.md).
public struct TableOrdonnee<Valeur: Sendable>: Sendable {
    public let cles: [String]
    public let valeurs: [String: Valeur]

    /// Les paires dans l'ordre ; une clé répétée garde sa première place et prend la dernière valeur.
    public init(_ paires: [(String, Valeur)]) {
        var cles: [String] = []
        var valeurs: [String: Valeur] = [:]
        for (cle, valeur) in paires {
            if valeurs.updateValue(valeur, forKey: cle) == nil { cles.append(cle) }
        }
        self.cles = cles
        self.valeurs = valeurs
    }

    public subscript(cle: String) -> Valeur? { valeurs[cle] }

    public var count: Int { cles.count }

    /// Les paires, dans l'ordre des clés.
    public var paires: [(cle: String, valeur: Valeur)] {
        cles.compactMap { cle in valeurs[cle].map { (cle: cle, valeur: $0) } }
    }

    /// `mapValues` de Kotlin : mêmes clés, dans le même ordre.
    public func transforme<Autre: Sendable>(_ f: (String, Valeur) throws -> Autre) rethrows -> TableOrdonnee<Autre> {
        TableOrdonnee<Autre>(try paires.map { ($0.cle, try f($0.cle, $0.valeur)) })
    }
}

extension TableOrdonnee: Equatable where Valeur: Equatable {
    public static func == (gauche: TableOrdonnee, droite: TableOrdonnee) -> Bool {
        gauche.cles == droite.cles && gauche.valeurs == droite.valeurs
    }
}

extension ObjetJSON {
    /// Les objets d'un tableau (`JSONArray.getJSONObject` à chaque rang), ce qui n'en est pas laissé de côté.
    func objets(_ cle: String) -> [ObjetJSON] {
        guard let liste = tableau(cle) else { return [] }
        return liste.indices.compactMap { liste.objet($0) }
    }

    /// `Json.nullable` d'Android : nil si la clé manque, vaut `null` ou un texte blanc.
    func texteOuNil(_ cle: String) -> String? {
        if estNul(cle) { return nil }
        let t = texte(cle)
        return t.estBlanc ? nil : t
    }

    /// `Json.strings` d'Android : les textes d'un tableau.
    func textes(_ cle: String) -> [String] {
        guard let liste = tableau(cle) else { return [] }
        return liste.indices.map { liste.texte($0) }
    }
}
