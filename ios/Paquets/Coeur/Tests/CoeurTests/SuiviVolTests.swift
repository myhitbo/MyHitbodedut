import Foundation
import Testing
@testable import Coeur

/// Le suivi en direct (SuiviVol.kt) : la part de `suivi en direct - indicatifs, reponse du relais, adresse,
/// fiabilite` de VolTest que VolTests.swift lui laisse (les indicatifs, la réponse du relais, son adresse), puis tout
/// ce que `Tests/Vecteurs/vol_suite.json` dit de SuiviVol (tools/vecteurs_ios/VecteursVolSuite.kt). Le test
/// d'OpenSky anonyme est porté dans VolRappelsTests.swift, comme sur Android. Restent à l'app, avec le réseau :
/// `Relais("").position` et `Relais("http://…").position` (RELAIS_ABSENT sans connexion), et le fournisseur factice
/// qui recale la route (la fiabilité « relevé direct » est vérifiée par VolTests.swift).
@Suite("Suivi d'un vol")
struct SuiviVolTests {

    /// 2026-11-10T18:35:00Z.
    private let maintenant: Int64 = 1_794_335_700_000
    /// 2026-11-10T18:30:00Z.
    private let releve: Int64 = 1_794_335_400_000

    @Test func suiviEnDirectIndicatifsReponseDuRelaisAdresse() {
        let ely = SuiviVol.normaliser("ely 001")
        #expect(ely == "ELY001")
        let ly = SuiviVol.normaliser("LY001")
        #expect(ly == nil)
        let meme = SuiviVol.memeIndicatif("ELY001", "ELY1")
        #expect(meme)
        let autre = SuiviVol.memeIndicatif("ELY1", "ELY11")
        #expect(!autre)
        let ok = SuiviVol.lire("{\"trouve\":true,\"latitude\":50.5,\"longitude\":-21.2,\"altitude_geo\":11200,\"instant\":\"2026-11-10T18:30:00Z\"}",
                               maintenant)
        let attendu = SuiviVol.Resultat.trouve(point: Vol.Point(instant: releve, latitude: 50.5, longitude: -21.2), altitudeMetres: 11200.0)
        #expect(ok == attendu)
        let vieux = SuiviVol.lire("{\"trouve\":true,\"latitude\":50,\"longitude\":-21,\"instant\":\"2026-11-10T18:00:00Z\"}", maintenant)
        #expect(vieux == SuiviVol.Resultat.introuvable)
        let absent = SuiviVol.lire("{\"trouve\":false}", maintenant)
        #expect(absent == SuiviVol.Resultat.introuvable)
        let erreur = estErreur(SuiviVol.lire("{\"erreur\":\"x\"}", maintenant))
        #expect(erreur)
        let illisible = estErreur(SuiviVol.lire("pas du json", maintenant))
        #expect(illisible)
        let adresse = SuiviVol.adresse("https://r.test/", "ELY1", Vol.Point(instant: maintenant, latitude: 50.123, longitude: -20.36))
        #expect(adresse == "https://r.test/position?indicatif=ELY1&lat=50.1&lon=-20.4")
    }

    private func estErreur(_ r: SuiviVol.Resultat) -> Bool {
        if case .erreur = r { return true }
        return false
    }

    // MARK: Les vecteurs de la JVM

    private struct Fichier: Decodable {
        let indicatifs: [Indicatif]
        let memes: [Meme]
        let raisons: [RaisonEcrite]
        let releves: [Releve]
        let adresses: [AdresseEcrite]
        let carres: [Carre]
        let etats: [Etat]
    }

    /// Un résultat écrit par le générateur : ["trouve", instant, latitude, longitude, altitude], ["introuvable"],
    /// ["erreur", raison].
    private struct ResultatEcrit: Decodable {
        let valeur: SuiviVol.Resultat

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            let genre = try c.decode(String.self)
            switch genre {
            case "trouve":
                let instant = try c.decode(Int64.self)
                let latitude = try c.decode(Double.self)
                let longitude = try c.decode(Double.self)
                let altitude = try c.decodeIfPresent(Double.self)
                valeur = .trouve(point: Vol.Point(instant: instant, latitude: latitude, longitude: longitude), altitudeMetres: altitude)
            case "introuvable":
                valeur = .introuvable
            default:
                valeur = .erreur(raison: try c.decode(String.self))
            }
        }
    }

    private struct Indicatif: Decodable {
        let texte: String
        let attendu: String?

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            texte = try c.decode(String.self)
            attendu = try c.decodeIfPresent(String.self)
        }
    }

    private struct Meme: Decodable {
        let a: String
        let b: String
        let attendu: Bool

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            a = try c.decode(String.self)
            b = try c.decode(String.self)
            attendu = try c.decode(Bool.self)
        }
    }

    /// ["constantes", [...]], ["serveur", code, raison], ["codeServeur", raison, code ou null],
    /// ["duRelais", message, raison ou null].
    private struct RaisonEcrite: Decodable {
        let genre: String
        let constantes: [String]
        let code: Int?
        let texte: String
        let raison: String?

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            genre = try c.decode(String.self)
            switch genre {
            case "constantes":
                constantes = try c.decode([String].self)
                code = nil
                texte = ""
                raison = nil
            case "serveur":
                constantes = []
                code = try c.decode(Int.self)
                texte = ""
                raison = try c.decode(String.self)
            case "codeServeur":
                constantes = []
                texte = try c.decode(String.self)
                code = try c.decodeIfPresent(Int.self)
                raison = nil
            default:
                constantes = []
                code = nil
                texte = try c.decode(String.self)
                raison = try c.decodeIfPresent(String.self)
            }
        }
    }

    private struct Releve: Decodable {
        let corps: String
        let maintenant: Int64
        let resultat: ResultatEcrit

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            corps = try c.decode(String.self)
            maintenant = try c.decode(Int64.self)
            resultat = try c.decode(ResultatEcrit.self)
        }
    }

    private struct AdresseEcrite: Decodable {
        let relais: String
        let indicatif: String
        let latitude: Double
        let longitude: Double
        let attendue: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            relais = try c.decode(String.self)
            indicatif = try c.decode(String.self)
            latitude = try c.decode(Double.self)
            longitude = try c.decode(Double.self)
            attendue = try c.decode(String.self)
        }
    }

    private struct Carre: Decodable {
        let latitude: Double
        let longitude: Double
        let carres: [[Double]]
        let adresses: [String]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            latitude = try c.decode(Double.self)
            longitude = try c.decode(Double.self)
            carres = try c.decode([[Double]].self)
            adresses = try c.decode([String].self)
        }
    }

    private struct Etat: Decodable {
        let corps: String
        let indicatif: String
        let maintenant: Int64
        let resultat: ResultatEcrit

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            corps = try c.decode(String.self)
            indicatif = try c.decode(String.self)
            maintenant = try c.decode(Int64.self)
            resultat = try c.decode(ResultatEcrit.self)
        }
    }

    private func vecteurs() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vol_suite.json"))
    }

    @Test func lesIndicatifsEtLesRaisonsSontCeuxDeLaJvm() throws {
        let f = try vecteurs()
        #expect(f.indicatifs.count >= 18)
        for x in f.indicatifs {
            let obtenu = SuiviVol.normaliser(x.texte)
            #expect(obtenu == x.attendu, "normaliser « \(x.texte) »")
        }
        for x in f.memes {
            let obtenu = SuiviVol.memeIndicatif(x.a, x.b)
            #expect(obtenu == x.attendu, "memeIndicatif « \(x.a) », « \(x.b) »")
        }
        let constantes = [SuiviVol.Raison.horsLigne, SuiviVol.Raison.quota, SuiviVol.Raison.illisible,
                          SuiviVol.Raison.positionInvalide, SuiviVol.Raison.relaisAbsent, SuiviVol.Raison.service]
        var vus = 0
        for x in f.raisons {
            switch x.genre {
            case "constantes":
                #expect(constantes == x.constantes)
            case "serveur":
                let obtenu = SuiviVol.Raison.serveur(x.code ?? 0)
                #expect(obtenu == x.raison, "serveur \(x.code ?? 0)")
            case "codeServeur":
                let obtenu = SuiviVol.Raison.codeServeur(x.texte)
                #expect(obtenu == x.code, "codeServeur « \(x.texte) »")
            default:
                let obtenu = SuiviVol.Raison.duRelais(x.texte)
                #expect(obtenu == x.raison, "duRelais « \(x.texte) »")
            }
            vus += 1
        }
        #expect(vus >= 32)
    }

    @Test func lesReponsesDuRelaisSontLuesCommeSurLaJvm() throws {
        let f = try vecteurs()
        #expect(f.releves.count >= 48)
        for x in f.releves {
            let obtenu = SuiviVol.lire(x.corps, x.maintenant)
            #expect(obtenu == x.resultat.valeur, "relais \(x.corps)")
        }
    }

    @Test func lesAdressesEtLesCarresSontCeuxDeLaJvm() throws {
        let f = try vecteurs()
        for x in f.adresses {
            let obtenue = SuiviVol.adresse(x.relais, x.indicatif, Vol.Point(instant: maintenant, latitude: x.latitude, longitude: x.longitude))
            #expect(obtenue == x.attendue, "adresse \(x.relais) \(x.indicatif)")
        }
        // Le dernier carré est demandé avec un demi-côté de 1°, les autres avec celui de l'application.
        #expect(f.carres.count >= 2)
        for (rang, x) in f.carres.enumerated() {
            let demi = rang == f.carres.count - 1 ? 1.0 : SuiviVol.demiCote
            let carres = SuiviVol.carres(x.latitude, x.longitude, demi)
            #expect(carres == x.carres, "carrés \(x.latitude) \(x.longitude)")
            let adresses = carres.map { SuiviVol.adresseEtats($0) }
            #expect(adresses == x.adresses, "adresses \(x.latitude) \(x.longitude)")
        }
    }

    @Test func lesEtatsDOpenSkySontLusCommeSurLaJvm() throws {
        let f = try vecteurs()
        #expect(f.etats.count >= 104)
        for x in f.etats {
            let obtenu = SuiviVol.lireEtats(x.corps, x.indicatif, x.maintenant)
            #expect(obtenu == x.resultat.valeur, "états \(x.indicatif) \(x.corps)")
        }
    }

    @Test func leFournisseurEstLeRelaisEnHttpsSinonOpenSky() {
        let vide = SuiviVol.fournisseur("")
        #expect(vide == SuiviVol.Fournisseur.openSkyAnonyme)
        let https = SuiviVol.fournisseur("https://r.test")
        #expect(https == SuiviVol.Fournisseur.relais("https://r.test"))
        let http = SuiviVol.fournisseur("http://r.test")
        #expect(http == SuiviVol.Fournisseur.openSkyAnonyme)
    }
}
