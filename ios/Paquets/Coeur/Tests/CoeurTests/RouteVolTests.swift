import Foundation
import Testing
@testable import Coeur

/// RouteVolTest d'Android, porté : la route d'un numéro de vol (adsbdb), les mêmes cas que vol.test.mjs. Le faux
/// adsbdb devient des réponses enregistrées, passées à `RouteVol.chercher` par son lecteur ; le réseau (`Reseau`)
/// reste à l'app. Puis tout ce que `Tests/Vecteurs/vol_suite.json` dit de RouteVol
/// (tools/vecteurs_ios/VecteursVolSuite.kt) : les numéros, une vingtaine de réponses lues depuis sept départs, et
/// vingt-cinq recherches contre des réponses enregistrées, adresses demandées comprises.
@Suite("Route d'un vol")
struct RouteVolTests {

    /// Une réponse d'adsbdb : `response.flightroute`, deux ou trois escales.
    private static func route(_ icao: String, _ escales: String...) -> String {
        func p(_ iata: String) -> String { "{\"iata_code\":\"" + iata + "\"}" }
        let milieu = escales.count == 3 ? ",\"midpoint\":" + p(escales[1]) : ""
        return "{\"response\":{\"flightroute\":{\"callsign_icao\":\"" + icao + "\",\"airline\":{\"name\":\"Cie\"}," +
            "\"origin\":" + p(escales[0]) + milieu + ",\"destination\":" + p(escales[escales.count - 1]) + "}}}"
    }

    /// Le faux adsbdb du test d'Android : il note chaque adresse demandée.
    private final class FauxAdsbdb {
        var demandes: [String] = []
        let table: [String: String] = [
            "callsign/LY81": RouteVolTests.route("ELY81", "TLV", "BKK"),
            "airline/QF": "{\"response\":[{\"icao\":\"QFA\"}]}",
            "callsign/QFA9": RouteVolTests.route("QFA9", "MEL", "PER", "LHR"),
        ]

        func lire(_ adresse: String) -> RouteVol.Reponse {
            demandes.append(adresse)
            let chemin = adresse.commenceParUnites(RouteVol.adsbdb + "/")
                ? adresse.sansPremieresUnites(RouteVol.adsbdb.utf16.count + 1) : adresse
            if let corps = table[chemin] { return RouteVol.Reponse(code: 200, corps: corps) }
            return RouteVol.Reponse(code: adresse.finitParUnites("/callsign/QF9") ? 400 : 404, corps: "{}")
        }
    }

    @Test func numerosIataEtOaci() {
        let ly = RouteVol.normaliser("ly 81")
        #expect(ly == RouteVol.Numero(code: "LY", chiffres: "81", suffixe: ""))
        let ely = RouteVol.normaliser("ELY081")
        #expect(ely == RouteVol.Numero(code: "ELY", chiffres: "81", suffixe: ""))
        let u2 = RouteVol.normaliser("U22148")?.code
        #expect(u2 == "U2")
        let rien = RouteVol.normaliser("bonjour")
        #expect(rien == nil)
    }

    @Test func tronconDepuisLeDepartRepliOaciErreurs() {
        let faux = FauxAdsbdb()
        let ly = RouteVol.chercher("LY81", "TLV", lecteur: faux.lire)
        #expect(ly == RouteVol.Resultat.trouve(indicatif: "ELY81", compagnie: "Cie", escales: ["TLV", "BKK"], de: "TLV", vers: "BKK"))
        let melbourne = RouteVol.chercher("LY81", "MEL", lecteur: faux.lire)
        let autreDepart = estAutreDepart(melbourne)
        #expect(autreDepart)
        let qf = troncon(RouteVol.chercher("QF9", "PER", lecteur: faux.lire))
        #expect(qf == ["PER", "LHR", "QFA9"])
        let qfSansDepart = troncon(RouteVol.chercher("QF9", nil, lecteur: faux.lire))
        let vers = qfSansDepart.count > 1 ? qfSansDepart[1] : ""
        #expect(vers == "PER")
        let inconnu = RouteVol.chercher("XX999", nil, lecteur: faux.lire)
        #expect(inconnu == RouteVol.Resultat.introuvable)
        let invalide = RouteVol.chercher("nimporte", nil, lecteur: faux.lire)
        #expect(invalide == RouteVol.Resultat.invalide)
        let panne = RouteVol.chercher("LY81", nil) { _ in RouteVol.Reponse(code: 503, corps: "") }
        #expect(panne == RouteVol.Resultat.erreur(raison: SuiviVol.Raison.serveur(503)))
        // Seul le numéro part : ni position, ni aéroport de départ dans l'adresse.
        let demandes = faux.demandes
        #expect(!demandes.isEmpty)
        for adresse in demandes {
            let propre = adresse.commenceParUnites(RouteVol.adsbdb + "/") && !adresse.contientUnites("?")
            #expect(propre, "\(adresse)")
        }
    }

    private func estAutreDepart(_ r: RouteVol.Resultat) -> Bool {
        if case .autreDepart = r { return true }
        return false
    }

    /// [de, vers, indicatif] d'un tronçon trouvé ; vide sinon.
    private func troncon(_ r: RouteVol.Resultat) -> [String] {
        if case .trouve(let indicatif, _, _, let de, let vers) = r { return [de, vers, indicatif ?? "null"] }
        return []
    }

    // MARK: Les vecteurs de la JVM

    private struct Fichier: Decodable {
        let numeros: [NumeroEcrit]
        let routes: [RouteEcrite]
        let recherches: [Recherche]
    }

    /// ["trouve", indicatif, compagnie, escales, de, vers], ["autre_depart", indicatif, compagnie, escales],
    /// ["introuvable"], ["invalide"], ["erreur", raison].
    private struct ResultatEcrit: Decodable {
        let valeur: RouteVol.Resultat

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            let genre = try c.decode(String.self)
            switch genre {
            case "trouve":
                let indicatif = try c.decodeIfPresent(String.self)
                let compagnie = try c.decode(String.self)
                let escales = try c.decode([String].self)
                let de = try c.decode(String.self)
                let vers = try c.decode(String.self)
                valeur = .trouve(indicatif: indicatif, compagnie: compagnie, escales: escales, de: de, vers: vers)
            case "autre_depart":
                let indicatif = try c.decodeIfPresent(String.self)
                let compagnie = try c.decode(String.self)
                let escales = try c.decode([String].self)
                valeur = .autreDepart(indicatif: indicatif, compagnie: compagnie, escales: escales)
            case "introuvable":
                valeur = .introuvable
            case "invalide":
                valeur = .invalide
            default:
                valeur = .erreur(raison: try c.decode(String.self))
            }
        }
    }

    private struct NumeroEcrit: Decodable {
        let texte: String
        let attendu: RouteVol.Numero?

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            texte = try c.decode(String.self)
            if let parties = try c.decodeIfPresent([String].self), parties.count == 3 {
                attendu = RouteVol.Numero(code: parties[0], chiffres: parties[1], suffixe: parties[2])
            } else {
                attendu = nil
            }
        }
    }

    private struct RouteEcrite: Decodable {
        let corps: String
        let depart: String?
        let resultat: ResultatEcrit

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            corps = try c.decode(String.self)
            depart = try c.decodeIfPresent(String.self)
            resultat = try c.decode(ResultatEcrit.self)
        }
    }

    /// [chemin, code, corps] ; le chemin « * » répond à toute adresse.
    private struct ReponseEnregistree: Decodable {
        let chemin: String
        let code: Int
        let corps: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            chemin = try c.decode(String.self)
            code = try c.decode(Int.self)
            corps = try c.decode(String.self)
        }
    }

    private struct Recherche: Decodable {
        let numero: String
        let depart: String?
        let reponses: [ReponseEnregistree]
        let horsLigne: [String]
        let resultat: ResultatEcrit
        let demandes: [String]
    }

    /// Une adresse « hors ligne » : le lecteur lève, comme une connexion absente.
    private struct HorsLigne: Error {}

    private func vecteurs() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vol_suite.json"))
    }

    @Test func lesNumerosEtLesReponsesSontLusCommeSurLaJvm() throws {
        let f = try vecteurs()
        #expect(f.numeros.count >= 26)
        for x in f.numeros {
            let obtenu = RouteVol.normaliser(x.texte)
            #expect(obtenu == x.attendu, "normaliser « \(x.texte) »")
        }
        #expect(f.routes.count >= 161)
        for x in f.routes {
            let obtenu = RouteVol.lire(x.corps, x.depart)
            #expect(obtenu == x.resultat.valeur, "lire \(x.corps) depuis \(x.depart ?? "null")")
        }
    }

    @Test func lesRecherchesDemandentEtRendentCeQueDitLaJvm() throws {
        let f = try vecteurs()
        #expect(f.recherches.count >= 25)
        for x in f.recherches {
            var table: [String: RouteVol.Reponse] = [:]
            for r in x.reponses { table[r.chemin] = RouteVol.Reponse(code: r.code, corps: r.corps) }
            let horsLigne = Set(x.horsLigne)
            var demandes: [String] = []
            let obtenu = RouteVol.chercher(x.numero, x.depart) { adresse in
                demandes.append(adresse)
                if let toujours = table["*"] { return toujours }
                let chemin = adresse.sansPremieresUnites(RouteVol.adsbdb.utf16.count + 1)
                if horsLigne.contains(chemin) { throw HorsLigne() }
                return table[chemin] ?? RouteVol.Reponse(code: 404, corps: "{}")
            }
            #expect(obtenu == x.resultat.valeur, "chercher « \(x.numero) » depuis \(x.depart ?? "null")")
            #expect(demandes == x.demandes, "adresses de « \(x.numero) »")
        }
    }
}
