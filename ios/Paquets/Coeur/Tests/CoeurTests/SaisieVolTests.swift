import Foundation
import Testing
@testable import Coeur

/// SaisieVolTest et RouteVolTest d'Android, portés : la phrase du propriétaire, les numéros, l'hébreu,
/// l'anglais, l'heure d'embarquement écartée, la carte d'embarquement, la durée estimée ; la route d'un
/// numéro avec un faux réseau. Puis vingt phrases, sept cartes et la recherche des aéroports devant la JVM.
@Suite("Saisie du vol")
struct SaisieVolTests {

    private let mercredi = JourCivil.du("2026-11-04")

    private func lire(_ t: String) throws -> SaisieVol.Proposition {
        SaisieVol.lire(t, aeroports: try Trajets.aeroports.get(), aujourdhui: mercredi)
    }

    @Test func laPhraseDuProprietaire() throws {
        let p = try lire("je prends le vol elal Lyon tlv de demain a 11h")
        #expect(p.compagnie == "LY")
        #expect(p.depart?.iata == "LYS" && p.arrivee?.iata == "TLV")
        #expect(p.date == .du("2026-11-05"))
        #expect(p.heureDepart == HeureMinute(11, 0))
        #expect(p.numero == nil)
    }

    @Test func numeroVilleAPlusieursAeroportsDateChiffree() throws {
        let p = try lire("LY 382 de Paris à Tel Aviv le 12/11 à 9h40")
        #expect(p.numero == "LY382")
        #expect(p.depart?.iata == "CDG" && p.arrivee?.iata == "TLV")
        #expect(p.date == .du("2026-11-12"))
        #expect(p.heureDepart == HeureMinute(9, 40))
    }

    @Test func enHebreuAvecLesPrefixesMemEtLamed() throws {
        let p = try lire("מחר בשעה 11 טיסת אל על מליון לתל אביב")
        #expect(p.compagnie == "LY")
        #expect(p.depart?.iata == "LYS" && p.arrivee?.iata == "TLV")
        #expect(p.date == .du("2026-11-05"))
        #expect(p.heureDepart == HeureMinute(11, 0))
        let q = try lire("טיסה לניו יורק מתל אביב ב-12.11 בשעה 23:45")
        #expect(q.depart?.iata == "TLV" && q.arrivee?.iata == "JFK")
        #expect(q.date == .du("2026-11-12"))
    }

    @Test func enAnglaisAvecPmEtLArrivee() throws {
        let p = try lire("Flight LY81 Tel Aviv to Bangkok on Nov 12 at 11:30pm, arrives 15:10")
        #expect(p.numero == "LY81")
        #expect(p.depart?.iata == "TLV" && p.arrivee?.iata == "BKK")
        #expect(p.date == .du("2026-11-12"))
        #expect(p.heureDepart == HeureMinute(23, 30))
        #expect(p.heureArrivee == HeureMinute(15, 10))
    }

    @Test func lHeureDEmbarquementDUnBilletEstEcartee() throws {
        let p = try lire("Boarding 10:20 Departure 11:00 LYS TLV 14 nov. 2026 Arrival 16:05")
        #expect(p.numero == nil, "« TLV 14 » n'est pas un numéro de vol")
        #expect(p.heureDepart == HeureMinute(11, 0))
        #expect(p.heureArrivee == HeureMinute(16, 5))
        #expect(p.date == .du("2026-11-14"))
    }

    @Test func depuisEtUnJourDeLaSemaine() throws {
        let p = try lire("aller à Marseille depuis Tel Aviv le 20 novembre à 8h")
        #expect(p.depart?.iata == "TLV" && p.arrivee?.iata == "MRS")
        #expect(p.date == .du("2026-11-20"))
        #expect(try lire("TO3461 TLV → LYS mardi 18:50").date == .du("2026-11-10"))
    }

    @Test func unePhraseSansVolNeProposeRien() throws {
        #expect(try lire("bonjour").vide)
    }

    @Test func laCarteDEmbarquementBCBPSansGarderLeNom() throws {
        let t = try #require(CarteEmbarquement.lire("M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100", aujourdhui: mercredi))
        #expect(t.depart == "LYS" && t.arrivee == "TLV" && t.numero == "LY382")
        #expect(t.date == .du("2026-11-12"))
        #expect(CarteEmbarquement.lire("https://exemple.org", aujourdhui: mercredi) == nil)
    }

    @Test func laDureeEstimeeResteVraisemblable() throws {
        let d = SaisieVol.dureeEstimee(try Trajets.a("LYS"), try Trajets.a("TLV"))
        #expect(d >= 225 && d <= 270)
    }

    // MARK: RouteVolTest

    private func route(_ icao: String, _ escales: String...) -> String {
        func p(_ iata: String) -> String { #"{"iata_code":"\#(iata)"}"# }
        let milieu = escales.count == 3 ? #","midpoint":\#(p(escales[1]))"# : ""
        return #"{"response":{"flightroute":{"callsign_icao":"\#(icao)","airline":{"name":"Cie"},"#
            + #""origin":\#(p(escales[0]))\#(milieu),"destination":\#(p(escales[escales.count - 1]))}}}"#
    }

    @Test func numerosIATAEtOACI() {
        #expect(RouteVol.normaliser("ly 81") == RouteVol.Numero("LY", "81", ""))
        #expect(RouteVol.normaliser("ELY081") == RouteVol.Numero("ELY", "81", ""))
        #expect(RouteVol.normaliser("U22148")?.code == "U2")
        #expect(RouteVol.normaliser("bonjour") == nil)
    }

    @Test func tronconDepuisLeDepartRepliOACIErreurs() throws {
        let table = [
            "callsign/LY81": route("ELY81", "TLV", "BKK"),
            "airline/QF": #"{"response":[{"icao":"QFA"}]}"#,
            "callsign/QFA9": route("QFA9", "MEL", "PER", "LHR"),
        ]
        final class Journal: @unchecked Sendable { var adresses: [String] = [] }
        let journal = Journal()
        let faux: LecteurAdresse = { adresse in
            journal.adresses.append(adresse)
            if let corps = table[adresse.sansPremieresUnites(RouteVol.adsbdb.utf16.count + 1)] { return (200, corps) }
            return (adresse.hasSuffix("/callsign/QF9") ? 400 : 404, "{}")
        }
        #expect(RouteVol.chercher("LY81", "TLV", lecteur: faux)
                == .trouve(indicatif: "ELY81", compagnie: "Cie", escales: ["TLV", "BKK"], de: "TLV", vers: "BKK"))
        var autre = false
        if case .autreDepart = RouteVol.chercher("LY81", "MEL", lecteur: faux) { autre = true }
        #expect(autre)
        guard case .trouve(let indicatif, _, _, let de, let vers) = RouteVol.chercher("QF9", "PER", lecteur: faux) else {
            Issue.record("QF9 introuvable")
            return
        }
        #expect([de, vers, indicatif ?? ""] == ["PER", "LHR", "QFA9"])
        guard case .trouve(_, _, _, _, let suivant) = RouteVol.chercher("QF9", nil, lecteur: faux) else {
            Issue.record("QF9 sans départ introuvable")
            return
        }
        #expect(suivant == "PER")
        #expect(RouteVol.chercher("XX999", nil, lecteur: faux) == .introuvable)
        #expect(RouteVol.chercher("nimporte", nil, lecteur: faux) == .invalide)
        let refus = RouteVol.chercher("LY81", nil) { _ in (503, "") }
        #expect(refus == .erreur(SuiviVol.Raison.serveur(503)))
        // Seul le numéro part : ni position, ni aéroport de départ dans l'adresse.
        let fuites = journal.adresses.filter { !$0.hasPrefix(RouteVol.adsbdb + "/") || $0.contains("?") }
        #expect(fuites.isEmpty)
    }

    // MARK: Devant la JVM

    private func vecteurs() throws -> ObjetJSON { try Depot.vecteurs("geographie_vol.json") }

    /// `null` des vecteurs : nil.
    private func texte(_ r: [JSON], _ i: Int) -> String? { r.estNul(i) ? nil : r.texte(i) }

    @Test func vingtPhrasesSeLisentCommeSurAndroid() throws {
        let tous = try Trajets.aeroports.get()
        for case .tableau(let r) in try vecteurs().tableau("saisie") ?? [] {
            let p = SaisieVol.lire(r.texte(0), aeroports: tous, aujourdhui: mercredi)
            let rendu = [p.numero, p.compagnie, p.depart?.iata, p.arrivee?.iata, p.date?.iso, p.heureDepart?.description,
                         p.heureArrivee?.description, p.dateArrivee?.iso]
            let attendu = (1...8).map { texte(r, $0) }
            #expect(rendu == attendu, "« \(r.texte(0)) »")
        }
    }

    @Test func septCartesEtQuatreDurees() throws {
        let v = try vecteurs()
        for case .tableau(let r) in v.tableau("cartes") ?? [] {
            let t = CarteEmbarquement.lire(r.texte(0), aujourdhui: mercredi)
            let rendu = [t?.depart, t?.arrivee, t?.compagnie, t?.numero, t?.date?.iso]
            let attendu = (1...5).map { texte(r, $0) }
            #expect(rendu == attendu, "« \(r.texte(0)) »")
        }
        for case .tableau(let r) in v.tableau("durees") ?? [] {
            #expect(SaisieVol.dureeEstimee(try Trajets.a(r.texte(0)), try Trajets.a(r.texte(1))) == r.entier(2), "\(r.texte(0))-\(r.texte(1))")
        }
    }

    @Test func laRechercheDesAeroportsCommeSurAndroid() throws {
        let tous = try Trajets.aeroports.get()
        let o = try #require(try vecteurs().objet("aeroports"))
        #expect(tous.count == o.entier("nombre"))
        for case .tableau(let r) in o.tableau("recherches") ?? [] {
            let rendu = Aeroports.chercher(tous, r.texte(0)).map(\.iata).joined(separator: ",")
            #expect(rendu == r.texte(1), "« \(r.texte(0)) »")
        }
        for case .tableau(let r) in o.tableau("noms") ?? [] {
            let a = try Trajets.a(r.texte(0))
            let rendu = [Aeroports.nomLocal(a, "he"), Aeroports.nomLocal(a, "fr"), Aeroports.nomLocal(a, "en")]
            #expect(rendu == [r.texte(1), r.texte(2), r.texte(3)], "\(r.texte(0))")
        }
        for case .tableau(let r) in o.tableau("plier") ?? [] {
            let rendu = Aeroports.plier(r.texte(0))
            #expect(rendu.egalUnites(r.texte(1)), "« \(r.texte(0)) » : « \(rendu) »")
        }
    }
}
