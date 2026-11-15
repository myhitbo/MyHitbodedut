/// La route d'un numéro de vol (RouteVol.kt, 28/10), édition complète seulement, au toucher de la loupe, qui
/// n'apparaît qu'une fois les services en ligne activés (même interrupteur que SuiviVol) : le numéro (« LY81 »
/// ou « ELY81 ») part vers api.adsbdb.com, gratuit, sans compte ni clé ; rien d'autre. La réponse donne la
/// compagnie, l'indicatif OACI (pour le suivi en direct) et les escales connues. Pas les heures : aucune source
/// gratuite ne les donne, elles restent à saisir. Même logique que vol.js (normaliserNumero, lireRoute,
/// chercherRoute).
///
/// Ici, la lecture des réponses et l'enchaînement des demandes ; le réseau reste à l'app, qui passe à `chercher`
/// ce qui lit une adresse (`Lecteur`, le `Reseau` de Kotlin : HTTPS seulement, sans redirection). Les réponses se
/// lisent par `ObjetJSON`, avec les tolérances d'org.json. Jugé par `Tests/Vecteurs/vol_suite.json`
/// (tools/vecteurs_ios/VecteursVolSuite.kt), sections « numeros », « routes », « recherches ».
public enum RouteVol {
    public static let adsbdb = "https://api.adsbdb.com/v0"

    public struct Numero: Sendable, Hashable {
        public var code: String
        public var chiffres: String
        public var suffixe: String

        public init(code: String, chiffres: String, suffixe: String) {
            self.code = code
            self.chiffres = chiffres
            self.suffixe = suffixe
        }
    }

    public enum Resultat: Sendable, Hashable {
        case trouve(indicatif: String?, compagnie: String, escales: [String], de: String, vers: String)
        /// Le vol connu ne part pas de l'aéroport choisi.
        case autreDepart(indicatif: String?, compagnie: String, escales: [String])
        case introuvable
        case invalide
        /// `raison` est un code de `SuiviVol.Raison`.
        case erreur(raison: String)
    }

    /// Ce que rend une adresse lue : le code HTTP et le corps (la paire de Kotlin).
    public struct Reponse: Sendable, Hashable {
        public var code: Int
        public var corps: String

        public init(code: Int, corps: String) {
            self.code = code
            self.corps = corps
        }
    }

    /// Ce qui lit une adresse : le réseau de l'app, ou des réponses enregistrées dans les tests. Une erreur levée
    /// est une connexion absente (`IOException` de Kotlin).
    public typealias Lecteur = (String) throws -> Reponse

    /// `\s+` de la JVM : espace, tabulation, fins de ligne, U+000B, U+000C (pas l'espace insécable).
    private static let blancs = ExpressionReguliere("[ \\t\\n\\x{0B}\\f\\r]+")
    private static let motifNumero = ExpressionReguliere("([A-Z]{3}|[A-Z][A-Z0-9]|[0-9][A-Z])([0-9]{1,4})([A-Z]?)")
    private static let motifEscale = ExpressionReguliere("[A-Z0-9]{3}")
    private static let motifIcao = ExpressionReguliere("[A-Z]{3}")

    /// « ly 81 » → LY / 81 ; « ELY081 » → ELY / 81 ; nil sinon.
    public static func normaliser(_ texte: String) -> Numero? {
        guard let m = motifNumero.entiere(blancs.remplace(texte.uppercased(), par: "")) else { return nil }
        let unites = Array(m.groupes[2].utf16)
        var i = 0
        while i < unites.count && unites[i] == 0x30 { i += 1 }
        let chiffres = i == unites.count ? "0" : Unites.texte(unites[i...])
        return Numero(code: m.groupes[1], chiffres: chiffres, suffixe: m.groupes[3])
    }

    /// `response.flightroute` d'adsbdb : le tronçon qui part de `depart` (IATA) s'il est donné, sinon le premier.
    public static func lire(_ json: String, _ depart: String?) -> Resultat {
        guard let racine = try? ObjetJSON(texte: json) else { return .erreur(raison: SuiviVol.Raison.illisible) }
        guard let r = racine.objet("response")?.objet("flightroute") else { return .introuvable }
        var escales: [String] = []
        for cle in ["origin", "midpoint", "destination"] {
            guard let o = r.objet(cle) else { continue }
            let iata = o.texte("iata_code")
            if motifEscale.couvre(iata) { escales.append(iata) }
        }
        let indicatif = SuiviVol.normaliser(r.texte("callsign_icao"))
        let compagnie = r.objet("airline")?.texte("name") ?? ""
        var i = 0
        if let depart { i = escales.firstIndex { $0.egalUnites(depart) } ?? -1 }
        if escales.count < 2 { return .introuvable }
        if i < 0 || i >= escales.count - 1 { return .autreDepart(indicatif: indicatif, compagnie: compagnie, escales: escales) }
        return .trouve(indicatif: indicatif, compagnie: compagnie, escales: escales, de: escales[i], vers: escales[i + 1])
    }

    /// Un refus du serveur, distinct d'une connexion absente ; une réponse de compagnies illisible.
    private enum Echec: Error {
        case http(Int)
        case illisible
    }

    /// Le numéro → la route. adsbdb refuse certains numéros IATA courts (« QF9 ») : on reprend alors avec
    /// l'indicatif OACI de chaque compagnie qui porte ce code (adsbdb /airline). Hors du fil de l'interface.
    /// Les chemins ne portent que des lettres capitales et des chiffres : l'encodage d'URL de Kotlin n'y change rien.
    public static func chercher(_ numero: String, _ depart: String?, lecteur: Lecteur) -> Resultat {
        guard let n = normaliser(numero) else { return .invalide }
        do {
            if let corps = try demande("callsign/" + n.code + n.chiffres + n.suffixe, lecteur) { return lire(corps, depart) }
            if n.code.utf16.count != 2 { return .introuvable }
            var compagnies: [JSON] = []
            if let corps = try demande("airline/" + n.code, lecteur) {
                guard let o = try? ObjetJSON(texte: corps) else { throw Echec.illisible }
                compagnies = o.tableau("response") ?? []
            }
            for rang in compagnies.indices {
                let icao = compagnies.objet(rang)?.texte("icao") ?? ""
                if !motifIcao.couvre(icao) { continue }
                if let corps = try demande("callsign/" + icao + n.chiffres + n.suffixe, lecteur) { return lire(corps, depart) }
            }
            return .introuvable
        } catch Echec.http(let code) {
            return .erreur(raison: SuiviVol.Raison.serveur(code))
        } catch Echec.illisible {
            return .erreur(raison: SuiviVol.Raison.illisible)
        } catch {
            return .erreur(raison: SuiviVol.Raison.horsLigne)
        }
    }

    /// Le corps de la réponse ; nil pour 404 et 400 (numéro inconnu ou refusé) ; un autre code hors de 2xx lève.
    private static func demande(_ chemin: String, _ lecteur: Lecteur) throws -> String? {
        let r = try lecteur(adsbdb + "/" + chemin)
        if r.code == 404 || r.code == 400 { return nil }
        if r.code < 200 || r.code > 299 { throw Echec.http(r.code) }
        return r.corps
    }
}
