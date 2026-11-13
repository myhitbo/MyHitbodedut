import Foundation
import Testing
@testable import Coeur

/// Le jour écrit, ou l'échec du test s'il n'existe pas.
private func j(_ iso: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> JourCivil {
    try #require(JourCivil(iso: iso), "« \(iso) » refusé", sourceLocation: sourceLocation)
}

@Suite("JourCivil")
struct JourCivilTests {

    // MARK: Lecture stricte, comme Store.dateValide

    @Test("refuse ce que Store.dateValide refuse", arguments: [
        "2026-02-30", "2026-9-5", "2026-09-5", "2026-9-05", "2025-02-29", "1900-02-29", "2100-02-29",
        "2026-04-31", "2026-13-01", "2026-00-10", "2026-11-00", "2026-11-32",
        "", "2026", "2026-11", " 2026-11-04", "2026-11-04 ", "2026/11/04", "2026-11-04T00:00",
        "+2026-11-04", "-026-11-04", "20261104", "2026-1a-04", "２０２６-11-04", "2026–11–04",
    ])
    func refuse(_ texte: String) {
        #expect(JourCivil(iso: texte) == nil)
    }

    @Test("accepte et relit à l'identique", arguments: [
        "2026-11-04", "2024-02-29", "2000-02-29", "1970-01-01", "2026-12-31", "0999-12-31", "0000-01-01", "9999-12-31",
    ])
    func accepte(_ texte: String) throws {
        let jour = try #require(JourCivil(iso: texte))
        #expect(jour.iso == texte)
        #expect(jour.description == texte)
    }

    @Test func champs() throws {
        let jour = try #require(JourCivil(iso: "2026-11-04"))
        #expect(jour.annee == 2026)
        #expect(jour.mois == 11)
        #expect(jour.jour == 4)
        #expect(JourCivil(annee: 2026, mois: 11, jour: 4) == jour)
        #expect(JourCivil(annee: 2026, mois: 2, jour: 30) == nil)
    }

    // MARK: Arithmétique

    @Test func changementsDAnneeEt29Fevrier() throws {
        let cas: [(String, Int, String)] = [
            ("2026-12-31", 1, "2027-01-01"),
            ("2027-01-01", -1, "2026-12-31"),
            ("2026-11-04", 0, "2026-11-04"),
            ("2026-11-04", 58, "2027-01-01"),
            ("2024-02-28", 1, "2024-02-29"),
            ("2024-02-29", 1, "2024-03-01"),
            ("2024-03-01", -1, "2024-02-29"),
            ("2023-02-28", 1, "2023-03-01"),
            ("2024-02-29", 365, "2025-02-28"),
            ("2024-02-29", 366, "2025-03-01"),
            ("2024-02-29", 1461, "2028-02-29"),
            ("2000-02-28", 1, "2000-02-29"),
            ("1900-02-28", 1, "1900-03-01"),
            ("2100-02-28", 1, "2100-03-01"),
            ("1999-12-31", 1, "2000-01-01"),
            ("2026-01-01", 365, "2027-01-01"),
            ("2028-01-01", 366, "2029-01-01"),
            ("2026-11-04", 146_097, "2426-11-04"),  // 400 ans grégoriens, jour pour jour
            ("0000-03-01", -1, "0000-02-29"),       // l'an 0 est bissextile, comme dans java.time
        ]
        for (depart, jours, arrivee) in cas {
            let jour = try j(depart)
            #expect(jour.plus(jours: jours).iso == arrivee, "\(depart) + \(jours)")
            #expect(jour.plus(jours: jours).plus(jours: -jours) == jour)
        }
    }

    @Test func joursJuliensConnus() throws {
        let a = try j("1970-01-01")
        let b = try j("2000-01-01")
        let c = try j("1900-01-01")
        #expect(a.jourJulien == 2_440_588)
        #expect(b.jourJulien == 2_451_545)
        #expect(c.jourJulien == 2_415_021)
        #expect(JourCivil(jourJulien: 2_451_545).iso == "2000-01-01")
    }

    @Test func jourDeSemaine() throws {
        let cas: [(String, Int)] = [
            ("2026-11-08", 1),  // dimanche
            ("2026-11-13", 6),  // vendredi
            ("2026-11-14", 7),  // samedi
            ("1970-01-01", 5),  // jeudi
            ("2000-01-01", 7),  // samedi
        ]
        for (iso, attendu) in cas {
            #expect(try j(iso).jourDeSemaine == attendu, "\(iso)")
        }
    }

    @Test func ordre() throws {
        let jours = try ["2027-01-01", "2026-11-04", "2026-12-31", "2026-02-28", "2025-12-31"].map { try j($0) }
        #expect(jours.sorted().map(\.iso) == ["2025-12-31", "2026-02-28", "2026-11-04", "2026-12-31", "2027-01-01"])
        let a = try j("2026-11-04")
        #expect(a < a.plus(jours: 1))
        #expect(!(a < a))
    }

    @Test func horsDesQuatreChiffres() {
        #expect(JourCivil(jourJulien: 2_440_588 - 719_529).iso == "-0001-12-31")
        #expect(JourCivil(annee: 10_000, mois: 1, jour: 1)?.iso == "+10000-01-01")
        #expect(JourCivil(iso: "+10000-01-01") == nil)
    }

    // MARK: Codable

    @Test func codable() throws {
        let jour = try #require(JourCivil(iso: "2026-11-04"))
        let donnees = try JSONEncoder().encode([jour])
        #expect(String(decoding: donnees, as: UTF8.self) == #"["2026-11-04"]"#)
        #expect(try JSONDecoder().decode([JourCivil].self, from: donnees) == [jour])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([JourCivil].self, from: Data(#"["2026-02-30"]"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([JourCivil].self, from: Data(#"["2026-9-5"]"#.utf8))
        }
    }

    // MARK: Contre le calendrier grégorien de Foundation, jour par jour

    /// Tous les jours de 1900 à 2100 : date, jour de semaine, aller-retour ISO, pas de un jour.
    /// Foundation ne sert ici que d'arbitre ; le paquet ne s'en sert pas.
    @Test func concordeAvecFoundationDe1900A2100() throws {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = try #require(TimeZone(identifier: "UTC"))
        let debut = try #require(calendrier.date(from: DateComponents(year: 1900, month: 1, day: 1)))
        let fin = try #require(JourCivil(iso: "2100-12-31"))
        var jour = try #require(JourCivil(iso: "1900-01-01"))
        var n = 0
        while jour <= fin {
            let c = calendrier.dateComponents(
                [.year, .month, .day, .weekday], from: debut.addingTimeInterval(Double(n) * 86_400))
            let suivant = jour.plus(jours: 1)
            guard c.year == jour.annee, c.month == jour.mois, c.day == jour.jour,
                  c.weekday == jour.jourDeSemaine,
                  JourCivil(iso: jour.iso) == jour,
                  suivant.jourJulien == jour.jourJulien + 1, jour < suivant
            else {
                Issue.record("écart au \(jour.iso) : Foundation donne \(c)")
                return
            }
            jour = suivant
            n += 1
        }
        #expect(n == 73_414)  // 201 ans, dont 49 bissextiles (ni 1900 ni 2100)
    }
}
