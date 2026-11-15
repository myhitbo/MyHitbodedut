import Foundation
import Synchronization

/// Les aéroports des zmanim en vol (Aeroports.kt, 28/10) : aeroports.json (OurAirports, domaine public ;
/// fuseaux par timezone-boundary-builder, ODbL), tiré par tools/aeroports_construction.py, une ligne par
/// aéroport, colonnes nommées dans `_meta`. Les noms en hébreu et en français (aeroports_noms.json,
/// Wikidata CC0, tools/aeroports_noms.py) s'y ajoutent pour la recherche.
///
/// Jugé par `Tests/Vecteurs/vol_suite.json` (tools/vecteurs_ios/VecteursVolSuite.kt), sections « aeroports »,
/// « plier », « chercher », « exact », « nomLocal », « parIata ».
public enum Aeroports {
    public static let source = "OurAirports (domaine public) ; fuseaux : timezone-boundary-builder (ODbL, © contributeurs OpenStreetMap) ; noms : Wikidata (CC0)"

    private static let langues = ["he", "fr"]

    /// Un fichier d'aéroports illisible : ce qu'Android signale par une `JSONException`.
    public struct Illisible: Error, Sendable, Hashable {
        public let raison: String

        public init(raison: String) {
            self.raison = raison
        }
    }

    /// Les aéroports de `json` (aeroports.json), avec les noms de `noms` (aeroports_noms.json) s'il est donné.
    /// Lève `Illisible` là où Android lève (`getJSONArray`, `getString`, `getDouble` d'org.json).
    public static func parse(_ json: String, noms: String? = nil) throws -> [Vol.Aeroport] {
        let racine = try lireObjet(json)
        guard let lignes = racine.tableau("aeroports") else { throw Illisible(raison: "aeroports absent") }
        var autres: ObjetJSON?
        if let noms {
            guard let n = try lireObjet(noms).objet("noms") else { throw Illisible(raison: "noms absent") }
            autres = n
        }
        var res: [Vol.Aeroport] = []
        res.reserveCapacity(lignes.count)
        for ligne in lignes {
            guard case .tableau(let a) = ligne else { throw Illisible(raison: "ligne qui n'est pas un tableau") }
            let iata = try chaine(a, 0)
            // [nom he, [villes he], nom fr, [villes fr]]
            var parLangue: [String: String] = [:]
            var alias: [String] = []
            if let n = autres?.tableau(iata) {
                for (k, langue) in langues.enumerated() {
                    let nomLangue = try chaine(n, 2 * k)
                    if !nomLangue.isEmpty {
                        parLangue[langue] = nomLangue
                        alias.append(nomLangue)
                    }
                    guard let villes = n.tableau(2 * k + 1) else { throw Illisible(raison: "villes de \(iata)") }
                    for j in villes.indices {
                        let lieu = try chaine(villes, j)
                        alias.append(lieu)
                    }
                }
            }
            let nom = try chaine(a, 1)
            let ville = try chaine(a, 2)
            let pays = try chaine(a, 3)
            let latitude = try nombre(a, 4)
            let longitude = try nombre(a, 5)
            let fuseau = try chaine(a, 6)
            res.append(Vol.Aeroport(iata: iata, nom: nom, ville: ville, pays: pays, latitude: latitude, longitude: longitude,
                                    fuseau: fuseau, noms: parLangue, alias: alias))
        }
        return res
    }

    private static func lireObjet(_ texte: String) throws -> ObjetJSON {
        do {
            return try ObjetJSON(texte: texte)
        } catch {
            throw Illisible(raison: "JSON illisible")
        }
    }

    /// `getString(rang)` de `JSONArray` : toute valeur présente, en texte (`null` rend « null »).
    private static func chaine(_ t: [JSON], _ rang: Int) throws -> String {
        guard rang >= 0 && rang < t.count else { throw Illisible(raison: "colonne \(rang) absente") }
        return t[rang].commeTexte
    }

    /// `getDouble(rang)` de `JSONArray` : un nombre, ou une chaîne qui se lit comme un nombre.
    private static func nombre(_ t: [JSON], _ rang: Int) throws -> Double {
        guard rang >= 0 && rang < t.count, let x = t[rang].commeDouble else { throw Illisible(raison: "colonne \(rang) non numérique") }
        return x
    }

    /// « Zurich », « zur », « ZRH », « תל אביב », « Londres » : sans accents, points-voyelles, casse ni
    /// ponctuation ; le code IATA exact d'abord, puis la ville, puis le nom et les autres noms.
    /// Un `max` négatif rend une liste vide (Kotlin lève).
    public static func chercher(_ aeroports: [Vol.Aeroport], _ texte: String, max: Int = 20) -> [Vol.Aeroport] {
        let q = Array(plier(texte).utf16)
        if q.isEmpty { return [] }
        // Les noms pliés une fois pour toutes (04/11) : avant, chaque lettre tapée repliait les 3 226
        // aéroports et leurs alias sur le fil de l'interface — la saisie ramait.
        let idx = index(aeroports)
        var exact: [Int] = []
        var ville: [Int] = []
        var nom: [Int] = []
        for i in idx.indices {
            let p = idx[i]
            if p.iata == q {
                exact.append(i)
            } else if p.ville.starts(with: q) || p.alias.contains(where: { $0.starts(with: q) }) {
                ville.append(i)
            } else if contient(p.nom, q) || contient(p.ville, q) || p.alias.contains(where: { contient($0, q) }) {
                nom.append(i)
            }
        }
        let nombre = max < 0 ? 0 : max
        return (exact + ville + nom).prefix(nombre).map { aeroports[$0] }
    }

    /// `contains` de Kotlin, sur des unités UTF-16.
    private static func contient(_ texte: [UInt16], _ motif: [UInt16]) -> Bool {
        Unites.position(de: motif, dans: texte) != nil
    }

    /// Les champs d'un aéroport, déjà pliés, en unités UTF-16 (les comparaisons de Kotlin).
    private struct Plie: Sendable {
        let iata: [UInt16]
        let ville: [UInt16]
        let nom: [UInt16]
        let alias: [[UInt16]]
    }

    /// La liste pliée et celle dont elle vient : le `cache` de Kotlin, qui compare la liste par identité.
    /// Ici, l'égalité des tableaux (immédiate quand c'est le même tableau, élément par élément sinon).
    private struct Index: Sendable {
        let liste: [Vol.Aeroport]
        let plies: [Plie]
    }

    private static let cache = Mutex<Index?>(nil)

    private static func index(_ aeroports: [Vol.Aeroport]) -> [Plie] {
        if let deja = cache.withLock({ $0 }), deja.liste == aeroports {
            // La même liste dans un autre tableau : on garde celui-ci, que les appels suivants reconnaîtront d'emblée
            // (l'égalité de deux tableaux qui partagent leur mémoire est immédiate).
            let reconnu = Index(liste: aeroports, plies: deja.plies)
            cache.withLock { $0 = reconnu }
            return deja.plies
        }
        let plies = aeroports.map { a in
            Plie(iata: Array(plier(a.iata).utf16), ville: Array(plier(a.ville).utf16), nom: Array(plier(a.nom).utf16),
                 alias: a.alias.map { Array(plier($0).utf16) })
        }
        let nouveau = Index(liste: aeroports, plies: plies)
        cache.withLock { $0 = nouveau }
        return plies
    }

    /// L'aéroport dont la ville (ou un autre nom) est exactement `texte`, déjà plié ; nil sinon.
    public static func exact(_ aeroports: [Vol.Aeroport], _ texte: String) -> Vol.Aeroport? {
        let t = Array(texte.utf16)
        let idx = index(aeroports)
        for i in idx.indices where idx[i].ville == t || idx[i].alias.contains(t) {
            return aeroports[i]
        }
        return nil
    }

    /// Prépare l'index hors du fil de l'interface, pour que la première lettre réponde aussitôt.
    public static func preparer(_ aeroports: [Vol.Aeroport]) {
        _ = index(aeroports)
    }

    /// Les marques (accents, nikoud) ôtées ; tiret, maqaf, apostrophe, guillemets, géresh et points deviennent
    /// des espaces ; les blancs de la JVM (`\s` : espace, tabulation, fins de ligne, U+000B, U+000C) réduits à un.
    static func plier(_ s: String) -> String {
        let sansMarques = marques.remplace(s.formeNFD, par: "").lowercased()
        return blancs.remplace(ponctuation.remplace(sansMarques, par: " "), par: " ").rogne
    }

    private static let marques = ExpressionReguliere("\\p{M}")
    private static let ponctuation = ExpressionReguliere("[-\u{05BE}'\u{2019}\"\u{05F3}\u{05F4}.]")
    private static let blancs = ExpressionReguliere("[ \\t\\n\\x{0B}\\f\\r]+")

    /// Le nom dans la langue de l'application s'il existe, sinon celui d'OurAirports (en anglais).
    public static func nomLocal(_ a: Vol.Aeroport, _ langue: String) -> String {
        a.noms[langue == "iw" ? "he" : langue] ?? a.nom
    }

    public static func parIata(_ aeroports: [Vol.Aeroport], _ iata: String) -> Vol.Aeroport? {
        aeroports.first { $0.iata.egalUnites(iata) }
    }
}
