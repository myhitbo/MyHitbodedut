import Foundation
import Testing
@testable import Coeur

/// Les aéroports (Aeroports.kt) : la part de VolTest que VolTests.swift laisse au portage d'Aeroports.kt
/// (`la recherche trouve le code, la ville sans accents, le nom`, et la lecture par `Aeroports.parse` de
/// `les aeroports sont complets et leurs fuseaux connus`), puis tout ce que `Tests/Vecteurs/vol_suite.json` en dit
/// (tools/vecteurs_ios/VecteursVolSuite.kt) : une empreinte par aéroport lu, avec et sans les noms de Wikidata,
/// dix-huit fiches entières, le pliage, la recherche, le nom exact, le nom local, la recherche par code.
@Suite("Aéroports")
struct AeroportsTests {

    /// Lus une fois pour toutes les fonctions de la suite : l'index plié d'Aeroports reconnaît ainsi le même tableau.
    private static let avecNoms: [Vol.Aeroport] = {
        guard let lignes = try? Depot.contenu("aeroports.json"), let noms = try? Depot.contenu("aeroports_noms.json") else { return [] }
        return (try? Aeroports.parse(String(decoding: lignes, as: UTF8.self), noms: String(decoding: noms, as: UTF8.self))) ?? []
    }()

    private static let sansNoms: [Vol.Aeroport] = {
        guard let lignes = try? Depot.contenu("aeroports.json") else { return [] }
        return (try? Aeroports.parse(String(decoding: lignes, as: UTF8.self))) ?? []
    }()

    private var aeroports: [Vol.Aeroport] { AeroportsTests.avecNoms }

    private func a(_ iata: String) throws -> Vol.Aeroport {
        let x = Aeroports.parIata(aeroports, iata)
        return try #require(x, "\(iata) absent")
    }

    private func iatas(_ liste: [Vol.Aeroport]) -> [String] {
        liste.map { $0.iata }
    }

    @Test func lesAeroportsLusParParseSontCompletsEtUniques() throws {
        let nombre = aeroports.count
        #expect(nombre > 3000)
        let distincts = Set(iatas(aeroports)).count
        #expect(distincts == nombre)
        let tlv = try a("TLV").fuseau
        #expect(tlv == "Asia/Jerusalem")
        let ool = try a("OOL").fuseau
        #expect(ool == "Australia/Brisbane")
        // Fuseau disputé : non proposé.
        let urc = Aeroports.parIata(aeroports, "URC")
        #expect(urc == nil)
    }

    @Test func laRechercheTrouveLeCodeLaVilleSansAccentsLeNom() throws {
        let tlv = Aeroports.chercher(aeroports, "tlv").first?.iata
        #expect(tlv == "TLV")
        let zurich = iatas(Aeroports.chercher(aeroports, "zurich")).contains("ZRH")
        #expect(zurich)
        let benGurion = iatas(Aeroports.chercher(aeroports, "Ben Gurion")).contains("TLV")
        #expect(benGurion)
        let blancs = Aeroports.chercher(aeroports, "  ").isEmpty
        #expect(blancs)
        // Wikidata : hébreu (avec ou sans tiret) et français.
        let telAviv = iatas(Aeroports.chercher(aeroports, "תל אביב")).contains("TLV")
        #expect(telAviv)
        let telAvivTiret = iatas(Aeroports.chercher(aeroports, "תל-אביב")).contains("TLV")
        #expect(telAvivTiret)
        let benGurionHebreu = iatas(Aeroports.chercher(aeroports, "בן גוריון")).contains("TLV")
        #expect(benGurionHebreu)
        let melbourne = iatas(Aeroports.chercher(aeroports, "מלבורן")).contains("MEL")
        #expect(melbourne)
        let londres = iatas(Aeroports.chercher(aeroports, "Londres")).contains("LHR")
        #expect(londres)
        let hebreu = Aeroports.nomLocal(try a("TLV"), "he")
        #expect(hebreu == "נמל התעופה בן-גוריון")
        let anglais = Aeroports.nomLocal(try a("TLV"), "en")
        let nom = try a("TLV").nom
        #expect(anglais == nom)
    }

    // MARK: Les vecteurs de la JVM

    private struct Fichier: Decodable {
        let aeroports: Lus
        let plier: [[String]]
        let chercher: [Recherche]
        let exact: [Paire]
        let nomLocal: [[String]]
        let parIata: [Paire]
    }

    private struct Lus: Decodable {
        struct SansNoms: Decodable {
            let nombre: Int
            let empreintes: [Int32]
        }

        struct Noms: Decodable {
            let he: String?
            let fr: String?
        }

        struct Fiche: Decodable {
            let iata: String
            let nom: String
            let ville: String
            let pays: String
            let latitude: Double
            let longitude: Double
            let fuseau: String
            let noms: Noms
            let alias: [String]
        }

        let nombre: Int
        let empreintes: [Int32]
        let sansNoms: SansNoms
        let fiches: [Fiche]
    }

    /// [texte, max, [codes]] ; un max de -1 : la liste sans les noms de Wikidata, au max par défaut.
    private struct Recherche: Decodable {
        let texte: String
        let max: Int
        let codes: [String]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            texte = try c.decode(String.self)
            max = try c.decode(Int.self)
            codes = try c.decode([String].self)
        }
    }

    /// [texte, code ou null].
    private struct Paire: Decodable {
        let texte: String
        let code: String?

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            texte = try c.decode(String.self)
            code = try c.decodeIfPresent(String.self)
        }
    }

    private func vecteurs() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vol_suite.json"))
    }

    /// La fiche dont la JVM prend l'empreinte : `Double.toString` pour les coordonnées, « null » pour un nom absent.
    private func fiche(_ x: Vol.Aeroport) -> String {
        [x.iata, x.nom, x.ville, x.pays, Java.texte(x.latitude), Java.texte(x.longitude), x.fuseau, x.noms["he"] ?? "null",
         x.noms["fr"] ?? "null", x.alias.joined(separator: ";")].joined(separator: "|")
    }

    @Test func lesAeroportsLusSontCeuxDeLaJvm() throws {
        let f = try vecteurs()
        let nombre = aeroports.count
        #expect(nombre == f.aeroports.nombre)
        let empreintes = aeroports.map { Kotlin.hashCode(fiche($0)) }
        #expect(empreintes == f.aeroports.empreintes)
        let sans = AeroportsTests.sansNoms
        let nombreSans = sans.count
        #expect(nombreSans == f.aeroports.sansNoms.nombre)
        let empreintesSans = Array(sans.prefix(f.aeroports.sansNoms.empreintes.count).map { Kotlin.hashCode(fiche($0)) })
        #expect(empreintesSans == f.aeroports.sansNoms.empreintes)
        for attendue in f.aeroports.fiches {
            let x = try a(attendue.iata)
            #expect(x.nom == attendue.nom, "\(attendue.iata)")
            #expect(x.ville == attendue.ville, "\(attendue.iata)")
            #expect(x.pays == attendue.pays, "\(attendue.iata)")
            #expect(x.latitude == attendue.latitude, "\(attendue.iata)")
            #expect(x.longitude == attendue.longitude, "\(attendue.iata)")
            #expect(x.fuseau == attendue.fuseau, "\(attendue.iata)")
            let he = x.noms["he"]
            let fr = x.noms["fr"]
            #expect(he == attendue.noms.he, "\(attendue.iata)")
            #expect(fr == attendue.noms.fr, "\(attendue.iata)")
            #expect(x.alias == attendue.alias, "\(attendue.iata)")
        }
    }

    @Test func lePliageEtLaRechercheSontCeuxDeLaJvm() throws {
        let f = try vecteurs()
        #expect(f.plier.count >= 50)
        for p in f.plier where p.count == 2 {
            let plie = Aeroports.plier(p[0])
            let egal = plie.egalUnites(p[1])
            #expect(egal, "plier « \(p[0]) » : « \(plie) », attendu « \(p[1]) »")
        }
        #expect(f.chercher.count >= 90)
        for r in f.chercher {
            let codes: [String]
            if r.max < 0 {
                codes = iatas(Aeroports.chercher(AeroportsTests.sansNoms, r.texte))
            } else {
                codes = iatas(Aeroports.chercher(aeroports, r.texte, max: r.max))
            }
            #expect(codes == r.codes, "chercher « \(r.texte) », \(r.max)")
        }
        for p in f.exact {
            let code = Aeroports.exact(aeroports, p.texte)?.iata
            #expect(code == p.code, "exact « \(p.texte) »")
        }
        for n in f.nomLocal where n.count == 3 {
            let nom = Aeroports.nomLocal(try a(n[0]), n[1])
            let egal = nom.egalUnites(n[2])
            #expect(egal, "nomLocal \(n[0]) « \(n[1]) »")
        }
        for p in f.parIata {
            let code = Aeroports.parIata(aeroports, p.texte)?.iata
            #expect(code == p.code, "parIata « \(p.texte) »")
        }
    }
}
