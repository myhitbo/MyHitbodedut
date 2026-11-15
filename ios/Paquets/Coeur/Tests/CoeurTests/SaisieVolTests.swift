import Foundation
import Testing
@testable import Coeur

/// SaisieVolTest d'Android, porté : la saisie rapide d'un vol (04/11), des phrases comme on les dirait, et le code des
/// cartes d'embarquement ; les mêmes phrases, le même mercredi 4 novembre 2026. Puis tout ce que
/// `Tests/Vecteurs/vol_suite.json` dit de SaisieVol (tools/vecteurs_ios/VecteursVolSuite.kt) : la saisie de cent
/// quatre-vingts phrases (français, anglais, hébreu ; formats de date ; fautes ; blancs d'Unicode) à cinq dates, les
/// heures d'un billet, la durée estimée de quatorze trajets. Rien ne reste à Android.
@Suite("Saisie d'un vol")
struct SaisieVolTests {

    /// Lus une fois pour toutes les fonctions de la suite : l'index plié d'Aeroports reconnaît ainsi le même tableau.
    private static let aeroports: [Vol.Aeroport] = {
        guard let lignes = try? Depot.contenu("aeroports.json"), let noms = try? Depot.contenu("aeroports_noms.json") else { return [] }
        return (try? Aeroports.parse(String(decoding: lignes, as: UTF8.self), noms: String(decoding: noms, as: UTF8.self))) ?? []
    }()

    private let mercredi = JourCivil.du("2026-11-04")

    private func lire(_ t: String) -> SaisieVol.Proposition {
        SaisieVol.lire(t, SaisieVolTests.aeroports, mercredi)
    }

    @Test func laPhraseDuProprietaire() {
        let p = lire("je prends le vol elal Lyon tlv de demain a 11h")
        #expect(p.compagnie == "LY")
        #expect(p.depart?.iata == "LYS")
        #expect(p.arrivee?.iata == "TLV")
        #expect(p.date == JourCivil.du("2026-11-05"))
        #expect(p.heureDepart == SaisieVol.Heure(11, 0))
        #expect(p.numero == nil)
    }

    @Test func numeroVilleAPlusieursAeroportsDateChiffree() {
        let p = lire("LY 382 de Paris à Tel Aviv le 12/11 à 9h40")
        #expect(p.numero == "LY382")
        #expect(p.depart?.iata == "CDG")
        #expect(p.arrivee?.iata == "TLV")
        #expect(p.date == JourCivil.du("2026-11-12"))
        #expect(p.heureDepart == SaisieVol.Heure(9, 40))
    }

    @Test func enHebreuAvecLesPrefixesMemEtLamed() {
        let p = lire("מחר בשעה 11 טיסת אל על מליון לתל אביב")
        #expect(p.compagnie == "LY")
        #expect(p.depart?.iata == "LYS")
        #expect(p.arrivee?.iata == "TLV")
        #expect(p.date == JourCivil.du("2026-11-05"))
        #expect(p.heureDepart == SaisieVol.Heure(11, 0))
        let q = lire("טיסה לניו יורק מתל אביב ב-12.11 בשעה 23:45")
        #expect(q.depart?.iata == "TLV")
        #expect(q.arrivee?.iata == "JFK")
        #expect(q.date == JourCivil.du("2026-11-12"))
    }

    @Test func enAnglaisAvecPmEtLArrivee() {
        let p = lire("Flight LY81 Tel Aviv to Bangkok on Nov 12 at 11:30pm, arrives 15:10")
        #expect(p.numero == "LY81")
        #expect(p.depart?.iata == "TLV")
        #expect(p.arrivee?.iata == "BKK")
        #expect(p.date == JourCivil.du("2026-11-12"))
        #expect(p.heureDepart == SaisieVol.Heure(23, 30))
        #expect(p.heureArrivee == SaisieVol.Heure(15, 10))
    }

    @Test func lHeureDEmbarquementDUnBilletEstEcartee() {
        let p = lire("Boarding 10:20 Departure 11:00 LYS TLV 14 nov. 2026 Arrival 16:05")
        #expect(p.numero == nil, "« TLV 14 » n'est pas un numéro de vol")
        #expect(p.heureDepart == SaisieVol.Heure(11, 0))
        #expect(p.heureArrivee == SaisieVol.Heure(16, 5))
        #expect(p.date == JourCivil.du("2026-11-14"))
    }

    @Test func depuisEtUnJourDeLaSemaine() {
        let p = lire("aller à Marseille depuis Tel Aviv le 20 novembre à 8h")
        #expect(p.depart?.iata == "TLV")
        #expect(p.arrivee?.iata == "MRS")
        #expect(p.date == JourCivil.du("2026-11-20"))
        let mardi = lire("TO3461 TLV → LYS mardi 18:50").date
        #expect(mardi == JourCivil.du("2026-11-10"))
    }

    @Test func unePhraseSansVolNeProposeRien() {
        let vide = lire("bonjour").vide
        #expect(vide)
    }

    @Test func laCarteDEmbarquementBcbpSansGarderLeNom() throws {
        let lu = CarteEmbarquement.lire("M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100", mercredi)
        let t = try #require(lu)
        #expect(t.depart == "LYS")
        #expect(t.arrivee == "TLV")
        #expect(t.numero == "LY382")
        #expect(t.date == JourCivil.du("2026-11-12"))
        let adresse = CarteEmbarquement.lire("https://exemple.org", mercredi)
        #expect(adresse == nil)
    }

    @Test func laDureeEstimeeResteVraisemblable() throws {
        let lys = try #require(Aeroports.parIata(SaisieVolTests.aeroports, "LYS"))
        let tlv = try #require(Aeroports.parIata(SaisieVolTests.aeroports, "TLV"))
        let d = SaisieVol.dureeEstimee(lys, tlv)
        #expect(d >= 225 * 60_000 && d <= 270 * 60_000)
    }

    // MARK: Les vecteurs de la JVM

    private struct Fichier: Decodable {
        let saisie: [Phrase]
        let heures: [Heures]
        let durees: [Duree]
    }

    /// [numéro, compagnie, départ, arrivée, date, heure de départ, heure d'arrivée, date d'arrivée, vide].
    private struct PropositionEcrite: Decodable, Equatable {
        let champs: [String?]
        let vide: Bool

        init(champs: [String?], vide: Bool) {
            self.champs = champs
            self.vide = vide
        }

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            var lus: [String?] = []
            for _ in 0..<8 { lus.append(try c.decodeIfPresent(String.self)) }
            champs = lus
            vide = try c.decode(Bool.self)
        }
    }

    private struct Phrase: Decodable {
        let texte: String
        let jour: String
        let attendue: PropositionEcrite

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            texte = try c.decode(String.self)
            jour = try c.decode(String.self)
            attendue = try c.decode(PropositionEcrite.self)
        }
    }

    private struct Heures: Decodable {
        let texte: String
        let heures: [String]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            texte = try c.decode(String.self)
            heures = try c.decode([String].self)
        }
    }

    private struct Duree: Decodable {
        let depart: String
        let arrivee: String
        let minutes: Int64

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            depart = try c.decode(String.self)
            arrivee = try c.decode(String.self)
            minutes = try c.decode(Int64.self)
        }
    }

    private func ecrite(_ p: SaisieVol.Proposition) -> PropositionEcrite {
        PropositionEcrite(champs: [p.numero, p.compagnie, p.depart?.iata, p.arrivee?.iata, p.date?.iso, p.heureDepart?.description,
                                   p.heureArrivee?.description, p.dateArrivee?.iso], vide: p.vide)
    }

    private func vecteurs() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vol_suite.json"))
    }

    /// Le texte « léger » des heures, comme le générateur : sans marques (NFD), en minuscules.
    private static let marques = ExpressionReguliere("\\p{M}")

    @Test func lesPhrasesSontLuesCommeSurLaJvm() throws {
        let f = try vecteurs()
        #expect(f.saisie.count >= 180)
        for x in f.saisie {
            let obtenue = ecrite(SaisieVol.lire(x.texte, SaisieVolTests.aeroports, JourCivil.du(x.jour)))
            #expect(obtenue == x.attendue, "« \(x.texte) » le \(x.jour)")
        }
    }

    @Test func lesHeuresEtLesDureesSontCellesDeLaJvm() throws {
        let f = try vecteurs()
        #expect(f.heures.count >= 57)
        for x in f.heures {
            let leger = SaisieVolTests.marques.remplace(x.texte.formeNFD, par: "").lowercased()
            let obtenues = SaisieVol.heures(leger).map { $0.description }
            #expect(obtenues == x.heures, "heures de « \(x.texte) »")
        }
        #expect(f.durees.count >= 14)
        for x in f.durees {
            let depart = Aeroports.parIata(SaisieVolTests.aeroports, x.depart)
            let arrivee = Aeroports.parIata(SaisieVolTests.aeroports, x.arrivee)
            let de = try #require(depart, "\(x.depart)")
            let vers = try #require(arrivee, "\(x.arrivee)")
            let minutes = SaisieVol.dureeEstimee(de, vers) / 60_000
            #expect(minutes == x.minutes, "\(x.depart) → \(x.arrivee)")
        }
    }
}
