import Testing
@testable import Coeur

/// HistoriqueReglageTest d'Android, porté : un réglage qui pèse sur le passé est daté (FDONNEES-05).
/// Le dernier cas d'Android, qui lit Store.kt, est tenu ici par les vecteurs de la sauvegarde
/// (SauvegardeTests : l'import date les deux réglages comme Store.setShabbatMode et setInIsrael).
@Suite("Historique d'un réglage")
struct HistoriqueReglageTests {
    private typealias H = HistoriqueReglage

    @Test func sansHistoriqueLaValeurDuMomentVautPourTousLesJours() {
        #expect(H.valeurLe([], .du("2026-01-01"), actuelle: true))
        #expect(!H.valeurLe([], .du("2026-01-01"), actuelle: false))
    }

    @Test func unChangementNeTouchePasLePasse() {
        let h = H.apresChangement([], .du("2026-11-05"), ancienne: false, nouvelle: true)
        #expect(!H.valeurLe(h, .du("2026-11-04"), actuelle: true))
        #expect(!H.valeurLe(h, .du("2026-08-03"), actuelle: true))
        #expect(H.valeurLe(h, .du("2026-11-05"), actuelle: true))
        #expect(H.valeurLe(h, .du("2026-12-01"), actuelle: true))
    }

    @Test func changerPuisRevenirLeMemeJourNeLaisseRienDePlus() {
        let aller = H.apresChangement([], .du("2026-11-05"), ancienne: false, nouvelle: true)
        let retour = H.apresChangement(aller, .du("2026-11-05"), ancienne: true, nouvelle: false)
        #expect(!H.valeurLe(retour, .du("2026-11-05"), actuelle: false))
        #expect(!H.valeurLe(retour, .du("2026-10-01"), actuelle: false))
        #expect(H.encoder(retour) == "2000-01-01=0")
    }

    @Test func unVoyageAllerRetourGardeLaDiasporaPourLesJoursPasses() {
        var h = H.apresChangement([], .du("2026-10-01"), ancienne: false, nouvelle: true)  // arrivée
        h = H.apresChangement(h, .du("2026-10-20"), ancienne: true, nouvelle: false)       // retour
        #expect(!H.valeurLe(h, .du("2026-09-20"), actuelle: false))
        #expect(H.valeurLe(h, .du("2026-10-10"), actuelle: false))
        #expect(!H.valeurLe(h, .du("2026-10-25"), actuelle: false))
    }

    @Test func lEncodageFaitLAllerRetourEtIgnoreCeQuiEstIllisible() {
        let h = H.apresChangement([], .du("2026-11-05"), ancienne: false, nouvelle: true)
        #expect(H.encoder(h) == "2000-01-01=0,2026-11-05=1")
        #expect(H.decoder(H.encoder(h)) == h)
        #expect(H.decoder("n'importe quoi,2026-13-45=1,2026-11-05=x,2000-01-01=0,2026-11-05=1") == h)
        #expect(H.decoder(nil).isEmpty)
        #expect(H.decoder("  ").isEmpty)
    }

    @Test func unChangementDuFuturEstEcarteEtLaListeResteBornee() {
        let futur = H.decoder("2000-01-01=0,2099-01-01=1")
        let h = H.apresChangement(futur, .du("2026-11-05"), ancienne: false, nouvelle: true)
        #expect(H.encoder(h) == "2000-01-01=0,2026-11-05=1")
        var long: [H.Entree] = []
        var v = false
        var jour = JourCivil.du("2020-01-01")
        for _ in 0..<(H.max + 50) {
            long = H.apresChangement(long, jour, ancienne: v, nouvelle: !v)
            v.toggle()
            jour = jour.plus(jours: 1)
        }
        #expect(long.count <= H.max)
        #expect(long.first?.depuis == H.origine)
    }
}
