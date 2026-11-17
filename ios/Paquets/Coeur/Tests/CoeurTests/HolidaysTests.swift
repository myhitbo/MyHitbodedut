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

/// Les petites règles pures d'Android du 13 au 16/11, recopiées sans écran.
@Suite("Règles du 13 au 16/11")
struct ReglesDuTreizeNovembreTests {

    /// Holidays.isYomKippur (FBARRIERE-13) : 10 Tichri 5787 le lundi 21 septembre 2026.
    @Test func yomKippour() {
        #expect(Holidays.isYomKippur(.du("2026-09-21"), inIsrael: false))
        #expect(Holidays.isYomKippur(.du("2026-09-21"), inIsrael: true))
        #expect(!Holidays.isYomKippur(.du("2026-09-20"), inIsrael: false))
        #expect(!Holidays.isYomKippur(.du("2026-09-12"), inIsrael: false))
    }

    /// DureeSeance.valide (FACCUEIL-15) : de 1 à 240, sans ramener en silence.
    @Test func laDureeSaisieEstValideOuRefusee() {
        #expect(DureeSeance.valide(" 25 ") == 25)
        #expect(DureeSeance.valide("1") == 1)
        #expect(DureeSeance.valide("240") == 240)
        #expect(DureeSeance.valide("0") == nil)
        #expect(DureeSeance.valide("241") == nil)
        #expect(DureeSeance.valide("999") == nil)
        #expect(DureeSeance.valide("") == nil)
        #expect(DureeSeance.valide("abc") == nil)
        #expect(DureeSeance.lire("999") == 240)
    }

    /// SessionRule.joueDuSon, autreMorceau, finSilencieuse (FBARRIERE-16, FSEANCE-06, FSEANCE-07).
    @Test func lesReglesDeLaSeance() {
        #expect(!SessionRule.joueDuSon(musique: false, ambiance: .silence))
        #expect(SessionRule.joueDuSon(musique: false, ambiance: .pluie))
        #expect(SessionRule.joueDuSon(musique: true, ambiance: .silence))
        #expect(SessionRule.autreMorceau(aleatoire: false, charge: true, retenu: "b", joue: "a"))
        #expect(!SessionRule.autreMorceau(aleatoire: true, charge: true, retenu: "b", joue: "a"))
        #expect(!SessionRule.autreMorceau(aleatoire: false, charge: false, retenu: "b", joue: "a"))
        #expect(!SessionRule.autreMorceau(aleatoire: false, charge: true, retenu: nil, joue: "a"))
        #expect(!SessionRule.autreMorceau(aleatoire: false, charge: true, retenu: "a", joue: "a"))
        #expect(SessionRule.finSilencieuse(avantTerme: true, masque: false, sonnerieAudible: false))
        #expect(SessionRule.finSilencieuse(avantTerme: false, masque: true, sonnerieAudible: true))
        #expect(!SessionRule.finSilencieuse(avantTerme: false, masque: true, sonnerieAudible: false))
        #expect(!SessionRule.finSilencieuse(avantTerme: false, masque: false, sonnerieAudible: true))
    }
}
