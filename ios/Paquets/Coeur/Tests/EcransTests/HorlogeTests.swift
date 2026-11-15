import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'horloge : l'instant en millisecondes Unix, et le jour qu'il est dans le fuseau du téléphone
/// (`LocalDate.now()` d'Android), qui n'est pas celui d'UTC autour de minuit.
@Suite("Horloge")
struct HorlogeTests {

    private func jerusalem() throws -> Fuseau {
        try #require(Fuseau("Asia/Jerusalem"))
    }

    @Test func lInstantEnMillisecondesUnix() throws {
        let jour = try #require(JourCivil(iso: "2026-11-13"))
        let horloge = HorlogeFixe(DateHeure(jour, heure: 22, minute: 30), fuseau: .utc)
        // 20 770 jours depuis le 1er janvier 1970, puis 22 h 30.
        #expect(horloge.maintenant == 1_794_609_000_000)
        let iso = horloge.dateHeure.description
        #expect(iso == "2026-11-13T22:30:00")
    }

    @Test func aujourdhuiEstLeJourDuFuseauDuTelephone() throws {
        let jour = try #require(JourCivil(iso: "2026-11-13"))
        let instant = Fuseau.utc.millis(DateHeure(jour, heure: 22, minute: 30))
        let fuseau = try jerusalem()
        // À 22 h 30 UTC, il est 0 h 30 le lendemain à Jérusalem (UTC+2 en novembre).
        let aJerusalem = HorlogeFixe(maintenant: instant, fuseau: fuseau).aujourdhui
        #expect(aJerusalem.iso == "2026-11-14")
        let enUTC = HorlogeFixe(maintenant: instant).aujourdhui
        #expect(enUTC.iso == "2026-11-13")
        let heure = HorlogeFixe(maintenant: instant, fuseau: fuseau).dateHeure.description
        #expect(heure == "2026-11-14T00:30:00")
    }

    @Test func uneHeureCivileDuFuseauDonneSonInstant() throws {
        let jour = try #require(JourCivil(iso: "2026-07-01"))
        let civile = DateHeure(jour, heure: 8, minute: 15)
        let fuseau = try jerusalem()
        let horloge = HorlogeFixe(civile, fuseau: fuseau)
        #expect(horloge.dateHeure == civile)
        // L'été, Jérusalem est à UTC+3.
        let utc = Fuseau.utc.dateHeure(millis: horloge.maintenant).description
        #expect(utc == "2026-07-01T05:15:00")
    }

    @Test func lHorlogeDuSystemeLitLaMachine() {
        let avant = Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
        let systeme = HorlogeSysteme()
        let lu = systeme.maintenant
        let apres = Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
        #expect(avant <= lu)
        #expect(lu <= apres)
        let fuseau = systeme.fuseau
        let attendu = Fuseau(TimeZone.current.identifier) ?? .utc
        #expect(fuseau == attendu)
    }

    @Test func uneHorlogeSInjecteParSonProtocole() throws {
        let jour = try #require(JourCivil(iso: "2027-03-26"))
        let fuseau = try jerusalem()
        let horloges: [any Horloge] = [HorlogeFixe(DateHeure(jour, heure: 12), fuseau: fuseau), HorlogeSysteme()]
        let premier = horloges[0].aujourdhui
        #expect(premier == jour)
    }
}
