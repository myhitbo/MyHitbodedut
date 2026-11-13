import Testing
@testable import Coeur

/// Jours chômés de Tichri 5787, en septembre et octobre 2026 : HolidaysTest.kt, porté.
///
/// Attendu : 21/09 Yom Kippour, 26/09 premier jour de Souccot tombant un samedi, 27/09 deuxième
/// jour de fête en diaspora seulement, 03/10 Chemini Atseret un samedi, 04/10 Simhat Torah en
/// diaspora seulement, et 28/09 Hol Hamoed, jour ordinaire partout.
@Suite("Holidays")
struct HolidaysTests {

    private func d(_ mois: Int, _ jour: Int) throws -> JourCivil {
        try #require(JourCivil(annee: 2026, mois: mois, jour: jour))
    }

    @Test func diasporaCinqJoursSansPorte() throws {
        for jour in [try d(9, 21), try d(9, 26), try d(9, 27), try d(10, 3), try d(10, 4)] {
            #expect(Holidays.isRestDay(jour, inIsrael: false), "\(jour) devrait être chômé en diaspora")
        }
    }

    @Test func israelTroisJoursSansPorte() throws {
        for jour in [try d(9, 21), try d(9, 26), try d(10, 3)] {
            #expect(Holidays.isRestDay(jour, inIsrael: true), "\(jour) devrait être chômé en Israël")
        }
    }

    @Test func leDeuxiemeJourDeFeteNeVautQuEnDiaspora() throws {
        for jour in [try d(9, 27), try d(10, 4)] {
            #expect(!Holidays.isRestDay(jour, inIsrael: true), "\(jour) n'est pas chômé en Israël")
            #expect(Holidays.isRestDay(jour, inIsrael: false), "\(jour) est chômé en diaspora")
        }
    }

    @Test func le28SeptembreEstOrdinairePartout() throws {
        let jour = try d(9, 28)
        #expect(!Holidays.isRestDay(jour, inIsrael: true))
        #expect(!Holidays.isRestDay(jour, inIsrael: false))
    }

    @Test func unSamediOrdinaireResteChome() throws {
        let samedi19 = try d(9, 19), samedi10 = try d(10, 10)
        #expect(Holidays.isRestDay(samedi19, inIsrael: true))
        #expect(Holidays.isRestDay(samedi10, inIsrael: false))
        #expect(!Holidays.isYomTov(samedi10, inIsrael: false))
    }

    @Test func unJourDeSemaineOrdinaireNeLEstPas() throws {
        let jour = try d(9, 22)
        #expect(!Holidays.isRestDay(jour, inIsrael: true))
        #expect(!Holidays.isRestDay(jour, inIsrael: false))
    }

    @Test func yomKippourEstYomTov() throws {
        let jour = try d(9, 21)
        #expect(Holidays.isYomTov(jour, inIsrael: true))
        #expect(Holidays.isYomTov(jour, inIsrael: false))
    }

    @Test func laVeilleEstReconnue() throws {
        let v25 = try d(9, 25), v22 = try d(9, 22), v26 = try d(9, 26)
        #expect(Holidays.isEveOfRestDay(v25, inIsrael: true))
        #expect(!Holidays.isEveOfRestDay(v22, inIsrael: true))
        // Veille du deuxième jour de fête : vraie en diaspora seulement.
        #expect(Holidays.isEveOfRestDay(v26, inIsrael: false))
    }

    @Test func laRegionParDefautSuitLeFuseau() {
        #expect(Holidays.defaultInIsrael(timeZoneId: "Asia/Jerusalem"))
        #expect(!Holidays.defaultInIsrael(timeZoneId: "Europe/Paris"))
        #expect(!Holidays.defaultInIsrael(timeZoneId: "America/New_York"))
    }
}
