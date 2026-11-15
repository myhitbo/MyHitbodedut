import Testing
@testable import Coeur

/// Les corrections du 02/11 (VoyageNuitTest.kt) : la fenêtre de nuit de la barrière (Store.fenetreFaite),
/// avec les mêmes heures. Les autres cas du fichier sont portés avec leurs règles : le prochain changement
/// de la vignette et la date hébraïque au tset (ZmanimVignetteTests), la boussole selon la carte
/// (DirectionJerusalemTests).
@Suite("Voyage et nuit")
struct VoyageNuitTests {

    /// 21:00–02:00.
    private let debutNuit = 21 * 60
    private let finNuit = 2 * 60
    private let d = JourCivil.du("2026-11-02")

    private func a(_ jour: JourCivil, _ heure: Int, _ minute: Int) -> DateHeure {
        DateHeure(jour, heure: heure, minute: minute)
    }

    private func faite(_ maintenant: DateHeure, _ faitA: DateHeure?, _ joursFaits: Set<JourCivil> = []) -> Bool {
        Store.fenetreFaite(start: debutNuit, end: finNuit, maintenant: maintenant, faitA: faitA) { joursFaits.contains($0) }
    }

    @Test func seanceDuSoirCouvreLaNuitApresMinuit() {
        // La séance de 21 h 30 : à 0 h 30, la barrière ne se réarme plus.
        let couverte = faite(a(d.plus(jours: 1), 0, 30), a(d, 21, 30), [d])
        #expect(couverte)
    }

    @Test func seanceApresMinuitCouvreLaNuitMaisPasLeSoirSuivant() {
        let lendemain = d.plus(jours: 1)
        let seance = a(lendemain, 0, 30)
        let nuit = faite(a(lendemain, 0, 40), seance, [lendemain])
        #expect(nuit)
        // Le soir suivant, la séance de 0 h 30 appartenait à la nuit d'avant.
        let soirSuivant = faite(a(lendemain, 21, 30), seance, [lendemain])
        #expect(!soirSuivant)
    }

    @Test func seanceDuMatinCouvreLeSoir() {
        let soir = faite(a(d, 21, 30), a(d, 10, 0), [d])
        #expect(soir)
    }

    @Test func riendeFaitArme() {
        let veille = d.plus(jours: -1)
        let couverte = faite(a(d, 23, 0), a(veille, 21, 30), [veille])
        #expect(!couverte)
    }

    @Test func sansHeureLeJourDeLaFenetreFaitFoi() {
        let lendemain = d.plus(jours: 1)
        let parLeSoir = faite(a(lendemain, 1, 0), nil, [d])
        #expect(parLeSoir)
        let parLeJourCivil = faite(a(lendemain, 1, 0), nil, [lendemain])
        #expect(!parLeJourCivil)
    }

    @Test func fenetreDeJourInchangee() {
        let jour = d
        let matin = Store.fenetreFaite(start: 6 * 60, end: 12 * 60, maintenant: a(d, 7, 0), faitA: nil) { $0 == jour }
        #expect(matin)
        let rien = Store.fenetreFaite(start: 6 * 60, end: 12 * 60, maintenant: a(d, 7, 0), faitA: a(d, 7, 0)) { _ in false }
        #expect(!rien)
    }
}
