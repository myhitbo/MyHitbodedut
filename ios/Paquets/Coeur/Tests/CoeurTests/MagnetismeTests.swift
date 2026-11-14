import Foundation
import Testing
@testable import Coeur

/// Le modèle magnétique WMM2025 du site (web/src/js/magnetisme.js), que la boussole d'iOS reprend
/// (PORTAGE.md § 2.2.5), devant son juge : les 100 valeurs de test officielles de la NOAA
/// (web/test/vecteurs_wmm2025.txt, WMM2025_TestValues.txt), à la tolérance du site
/// (web/test/boussole.test.mjs) : 0,01° pour la déclinaison et l'inclinaison, 0,1 nT pour X, Y et Z.
/// Les coefficients sont relus dans magnetisme.js : la recopie ne peut pas s'en écarter.
@Suite("Magnetisme")
struct MagnetismeTests {

    @Test func lesCentValeursDeTestDeLaNOAA() throws {
        let donnees = try Depot.donnees("web/test/vecteurs_wmm2025.txt")
        let texte = String(decoding: donnees, as: UTF8.self)
        var lignes = 0
        for ligne in texte.split(separator: "\n") where !ligne.hasPrefix("#") {
            let morceaux = ligne.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
            if morceaux.isEmpty { continue }
            let nombres = morceaux.compactMap { Double($0) }
            // Année, altitude (km), latitude, longitude, D, I, H, X, Y, Z, F, puis les variations annuelles.
            try #require(nombres.count == 18 && morceaux.count == 18, "ligne illisible : \(ligne)")
            lignes += 1
            let c = Magnetisme.champ(nombres[2], nombres[3], nombres[1], nombres[0])
            let ecartD = abs(c.declinaison - nombres[4])
            let ecartI = abs(c.inclinaison - nombres[5])
            let ecartX = abs(c.x - nombres[7])
            let ecartY = abs(c.y - nombres[8])
            let ecartZ = abs(c.z - nombres[9])
            #expect(ecartD <= 0.01, "D \(ligne) : \(c.declinaison)")
            #expect(ecartI <= 0.01, "I \(ligne) : \(c.inclinaison)")
            #expect(ecartX <= 0.1 && ecartY <= 0.1 && ecartZ <= 0.1, "XYZ \(ligne) : \(c.x) \(c.y) \(c.z)")
        }
        #expect(lignes == 100)
    }

    @Test func lesCoefficientsSontCeuxDuSite() throws {
        let donnees = try Depot.donnees("web/src/js/magnetisme.js")
        let js = String(decoding: donnees, as: UTF8.self)
        let rang = ExpressionReguliere("\\[(\\d+),(\\d+),(-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+),(-?[0-9.]+)\\]")
        let lus = rang.toutes(js).map { c in c.groupes.dropFirst().map { Double($0) ?? .nan } }
        #expect(lus.count == 90)
        let identiques = lus == Magnetisme.coefficients
        #expect(identiques)
        let epoque = ExpressionReguliere("EPOQUE = ([0-9.]+);").trouve(js, depuis: 0)?.groupes.last
        #expect(epoque == "2025.0")
        #expect(Magnetisme.epoque == 2025)
    }

    @Test func lAnneeDecimaleSeCompteEnUTC() {
        // 2026-01-01 à 0 h UTC, puis le 2 juillet à midi (182,5 jours sur 365).
        let debut = Magnetisme.anneeDecimale(millis: 1_767_225_600_000)
        #expect(debut == 2026)
        let milieu = Magnetisme.anneeDecimale(millis: 1_782_993_600_000)
        #expect(milieu == 2026.5)
        // Avant 1970 : 1969-07-02 à midi.
        let avant = Magnetisme.anneeDecimale(millis: -15_768_000_000)
        #expect(avant == 1969.5)
        // Une année bissextile : le 31 décembre 2028 est le 366e jour.
        let bissextile = Magnetisme.anneeDecimale(millis: 1_861_833_600_000)
        #expect(bissextile == 2028 + 365.0 / 366.0)
        let finDAnnee = Magnetisme.anneeDecimale(millis: 1_861_919_999_999)
        #expect(finDAnnee < 2029 && finDAnnee > 2028.999)
    }

    @Test func laDeclinaisonEstCelleDuNiveauDeLaMer() {
        let millis: Int64 = 1_782_993_600_000
        for (lat, lon) in [(31.7781, 35.2354), (40.7128, -74.0060), (48.8566, 2.3522), (-37.8136, 144.9631), (69.6492, 18.9553)] {
            let d = Magnetisme.declinaison(lat, lon, millis: millis)
            let attendue = Magnetisme.champ(lat, lon, 0, Magnetisme.anneeDecimale(millis: millis)).declinaison
            #expect(d == attendue, "(\(lat), \(lon))")
            #expect(abs(d) < 30, "(\(lat), \(lon)) : \(d)°")
        }
    }
}
