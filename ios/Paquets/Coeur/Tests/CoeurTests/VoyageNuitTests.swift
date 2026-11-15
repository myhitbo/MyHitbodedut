import Foundation
import Testing
@testable import Coeur

/// VoyageNuitTest d'Android, porté : les corrections du 02/11 — la fenêtre de nuit de la barrière, le prochain
/// changement des vignettes, la date hébraïque qui change à tsét, la boussole selon la carte au choix.
@Suite("VoyageNuit")
struct VoyageNuitTests {

    private let nuit = (debut: 21 * 60, fin: 2 * 60)  // 21:00–02:00
    private let d = JourCivil.du("2026-11-02")

    private func a(_ jour: JourCivil, _ h: Int, _ m: Int = 0) -> DateHeure { DateHeure(jour, heure: h, minute: m) }

    private func faite(_ maintenant: DateHeure, _ faitA: DateHeure?, _ joursFaits: Set<JourCivil> = []) -> Bool {
        Pratique.fenetreFaite(debut: nuit.debut, fin: nuit.fin, maintenant: maintenant, faitA: faitA) { joursFaits.contains($0) }
    }

    @Test func seanceDuSoirCouvreLaNuitApresMinuit() {
        // La séance de 21 h 30 : à 0 h 30, la barrière ne se réarme plus.
        let r = faite(a(d.plus(jours: 1), 0, 30), a(d, 21, 30), [d])
        #expect(r)
    }

    @Test func seanceApresMinuitCouvreLaNuitMaisPasLeSoirSuivant() {
        let seance = a(d.plus(jours: 1), 0, 30)
        let nuitMeme = faite(a(d.plus(jours: 1), 0, 40), seance, [d.plus(jours: 1)])
        #expect(nuitMeme)
        // Le soir suivant, la séance de 0 h 30 appartenait à la nuit d'avant.
        let soirSuivant = faite(a(d.plus(jours: 1), 21, 30), seance, [d.plus(jours: 1)])
        #expect(!soirSuivant)
    }

    @Test func seanceDuMatinCouvreLeSoir() {
        let r = faite(a(d, 21, 30), a(d, 10), [d])
        #expect(r)
    }

    @Test func rienDeFaitArme() {
        let r = faite(a(d, 23), a(d.plus(jours: -1), 21, 30), [d.plus(jours: -1)])
        #expect(!r)
    }

    @Test func sansHeureLeJourDeLaFenetreFaitFoi() {
        let veille = faite(a(d.plus(jours: 1), 1), nil, [d])
        #expect(veille)
        let jourCivil = faite(a(d.plus(jours: 1), 1), nil, [d.plus(jours: 1)])
        #expect(!jourCivil)
    }

    @Test func fenetreDeJourInchangee() {
        let jour = d
        let matin = Pratique.fenetreFaite(debut: 6 * 60, fin: 12 * 60, maintenant: a(d, 7), faitA: nil) { $0 == jour }
        #expect(matin)
        let rien = Pratique.fenetreFaite(debut: 6 * 60, fin: 12 * 60, maintenant: a(d, 7), faitA: a(d, 7)) { _ in false }
        #expect(!rien)
    }

    private func paris() throws -> Fuseau { try #require(Fuseau("Europe/Paris")) }

    @Test func vignetteChangeALaFinDeChaharit() throws {
        let z = try paris()
        let maintenant = DateHeureZonee(a(d, 9, 5), fuseau: z)
        let finChaharit = DateHeureZonee(a(d, 9, 12), fuseau: z)
        let prochain = ZmanimVignette.prochainChangement([finChaharit, nil, finChaharit.plus(heures: 5)], maintenant: maintenant)
        #expect(prochain == finChaharit)
    }

    @Test func vignetteAuPlusTardDansDixMinutes() throws {
        let z = try paris()
        let maintenant = DateHeureZonee(a(d, 13), fuseau: z)
        let prochain = ZmanimVignette.prochainChangement([maintenant.plus(heures: 3), maintenant.plus(heures: -1)],
                                                         maintenant: maintenant)
        #expect(prochain == maintenant.plus(minutes: 10))
    }

    @Test func vignetteAMinuitPourLaDate() throws {
        let z = try paris()
        let maintenant = DateHeureZonee(a(d, 23, 55), fuseau: z)
        let minuit = DateHeureZonee(DateHeure(d.plus(jours: 1)), fuseau: z)
        #expect(ZmanimVignette.prochainChangement([], maintenant: maintenant) == minuit)
    }

    @Test func dateHebraiqueChangeAuTset() throws {
        let z = try paris()
        let tset = DateHeureZonee(a(d, 17, 52), fuseau: z)
        #expect(ZmanimVignette.jourHebreuAffiche(tset.plus(minutes: -1), tset: tset) == d)
        #expect(ZmanimVignette.jourHebreuAffiche(tset, tset: tset) == d.plus(jours: 1))
        let onzeHeures = DateHeureZonee(a(d, 23), fuseau: z)
        #expect(ZmanimVignette.jourHebreuAffiche(onzeHeures, tset: tset) == d.plus(jours: 1))
        // Sans lieu, minuit.
        #expect(ZmanimVignette.jourHebreuAffiche(onzeHeures, tset: nil) == d)
    }

    @Test func boussoleSelonLaCarteAuChoix() {
        // New York : environ 54° par le grand cercle, 95° sur la carte de Mercator.
        let (gc, rh) = DirectionJerusalem.directions(40.7128, -74.0060)
        let (suivie, autre) = DirectionJerusalem.directions(40.7128, -74.0060, selonCarte: true)
        #expect(suivie == rh)
        #expect(autre == gc)
        #expect((50.0...58.0).contains(gc) && (92.0...98.0).contains(rh))
    }
}
