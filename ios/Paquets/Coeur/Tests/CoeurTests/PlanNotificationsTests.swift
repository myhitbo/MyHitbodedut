import Foundation
import Testing
@testable import Coeur

/// Le planificateur unique des notifications (PORTAGE.md § 2.2.2) : jamais plus de 64 en attente quels que soient les
/// réglages ; aucun rappel un jour de repos ni la veille après midi ; les rappels du jour disparaissent quand la
/// journée est faite, et pendant la séance ; « Chabbat dans 3 h », Birkat haLevana et le vol dans leur part.
@Suite("PlanNotifications")
struct PlanNotificationsTests {

    private func paris() throws -> Fuseau { try #require(Fuseau("Europe/Paris")) }

    private func a(_ iso: String, _ h: Int, _ m: Int = 0, _ fuseau: Fuseau) -> DateHeureZonee {
        DateHeureZonee(DateHeure(JourCivil.du(iso), heure: h, minute: m), fuseau: fuseau)
    }

    private func reglages(_ heures: [Int]) -> Reglages {
        var r = Reglages(enIsrael: false)
        r.rappelActif = true
        r.changerRappels(heures)
        return r
    }

    private func rappels(_ plan: [PlanNotifications.Prevue]) -> [PlanNotifications.Prevue] {
        plan.filter { $0.sorte == .rappel || $0.sorte == .rappelReporte }
    }

    /// Un générateur congruentiel, pour des réglages au hasard mais toujours les mêmes.
    private struct Hasard {
        var etat: UInt64
        mutating func entier(_ n: Int) -> Int {
            etat = etat &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((etat >> 33) % UInt64(n))
        }
    }

    @Test func jamaisPlusDeSoixanteQuatre() throws {
        let z = try paris()
        var h = Hasard(etat: 12)
        let debut = a("2026-09-01", 0, 0, z)
        for k in 0..<200 {
            let maintenant = debut.plus(minutes: h.entier(60 * 24 * 400))
            var r = reglages((0..<h.entier(k % 3 == 0 ? 1500 : 12)).map { _ in h.entier(1440) })
            r.rappelActif = h.entier(5) != 0
            r.pauseShabbat = h.entier(2) == 0
            r.rappelReporteJusqua = maintenant.millis + Int64(h.entier(600)) * 60_000
            let vol = (0..<h.entier(80)).map { i in
                VolRappels.Rappel(type: .priere, instant: maintenant.millis + Int64(h.entier(20_000) - 2000) * 60_000 + Int64(i))
            }
            let seance = PlanNotifications.Seance(debut: maintenant.millis, fin: maintenant.millis + 20 * 60_000, duree: 20)
            let e = PlanNotifications.Entree(maintenant: maintenant, reglages: r, seance: h.entier(2) == 0 ? seance : nil,
                                             lieuAlertes: Lieux.paris, vol: vol)
            // Un allumage et une sortie des étoiles forgés, pour le nombre : chaque jour à 16 h 30 et 18 h 15.
            let plan = PlanNotifications.planifier(e, fuseauLevana: z,
                                                   allumage: { DateHeureZonee(DateHeure($0, heure: 16, minute: 30), fuseau: z) },
                                                   soirLevana: { DateHeureZonee(DateHeure($0, heure: 18, minute: 15), fuseau: z) },
                                                   exempte: { $0.jourDeSemaine == 7 }, veilleDeRepos: { $0.jourDeSemaine == 6 })
            #expect(plan.count <= PlanNotifications.limite - PlanNotifications.marge, "\(k) : \(plan.count)")
            for sorte in PlanNotifications.Sorte.allCases {
                let n = plan.filter { $0.sorte == sorte }.count
                #expect(n <= sorte.part, "\(k) \(sorte) : \(n)")
            }
            let futurs = plan.filter { $0.quand > maintenant }
            #expect(futurs.count == plan.count)
            let instants = plan.map { $0.quand.millis }
            #expect(instants == instants.sorted())
            let ids = Set(plan.map { $0.identifiant })
            #expect(ids.count == plan.count)
        }
        // Sur les vrais zmanim, toutes les sortes à la fois, une heure par minute de la journée.
        var r = reglages(Array(0..<1440))
        r.rappelReporteJusqua = debut.millis + 600_000
        let vol = (1...40).map { VolRappels.Rappel(type: .priere, instant: debut.millis + Int64($0) * 3_600_000) }
        let seance = PlanNotifications.Seance(debut: debut.millis, fin: debut.millis + 30 * 60_000, duree: 30)
        let plan = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: debut, reglages: r, seance: seance,
                                                                        lieuAlertes: Lieux.jerusalem, vol: vol))
        #expect(plan.count <= PlanNotifications.limite)
        let parSorte = PlanNotifications.Sorte.allCases.map { s in plan.filter { $0.sorte == s }.count }
        #expect(parSorte == [30, 0, 1, 4, 6, 14], "\(parSorte)")
    }

    /// Deux mois de fêtes (Roch Hachana, Kippour, Souccot, Chemini Atseret, Sim'hat Torah, Chabbat) : un plan chaque
    /// matin ; aucun rappel un jour chômé, aucun la veille à midi ou après.
    @Test func aucunRappelUnJourDeReposNiLaVeilleApresMidi() throws {
        let z = try paris()
        let r = reglages([7 * 60, 11 * 60 + 30, 13 * 60, 21 * 60])
        var veillesAvantMidi = 0
        var ordinaires = 0
        for k in 0..<61 {
            let maintenant = a("2026-09-01", 6, 0, z).plus(jours: k)
            let plan = rappels(PlanNotifications.planifier(PlanNotifications.Entree(maintenant: maintenant, reglages: r)))
            #expect(!plan.isEmpty)
            for p in plan {
                let jour = p.quand.jour
                #expect(!Pratique.exempte(jour, r), "\(p.quand) un jour chômé")
                let veille = Holidays.isEveOfRestDay(jour, inIsrael: false)
                #expect(!(veille && p.quand.minutesDuJour >= 12 * 60), "\(p.quand) la veille après midi")
                if veille { veillesAvantMidi += 1 } else { ordinaires += 1 }
            }
        }
        #expect(veillesAvantMidi > 0 && ordinaires > 0)
        // Sans Chabbat ni Yom Tov chômés, le samedi sonne.
        var sansRepos = r
        sansRepos.pauseShabbat = false
        let samedi = rappels(PlanNotifications.planifier(PlanNotifications.Entree(maintenant: a("2026-11-14", 6, 0, z), reglages: sansRepos)))
        let duJour = samedi.filter { $0.quand.jour == JourCivil.du("2026-11-14") }
        #expect(duJour.count == 4)
        // Un jour mis en pause se tait même sans Chabbat chômé, mais sa veille sonne.
        sansRepos.joursPause = ["2026-11-18"]
        let pause = rappels(PlanNotifications.planifier(PlanNotifications.Entree(maintenant: a("2026-11-16", 6, 0, z), reglages: sansRepos)))
        let jours = pause.map { $0.quand.jour }
        #expect(!jours.contains(JourCivil.du("2026-11-18")))
        let veille = pause.filter { $0.quand.jour == JourCivil.du("2026-11-17") }
        #expect(veille.count == 4)
    }

    @Test func lesRappelsDuJourDisparaissentQuandLaJourneeEstFaite() throws {
        let z = try paris()
        let r = reglages([7 * 60, 13 * 60, 21 * 60])
        let lundi = a("2026-11-16", 8, 0, z)
        let avant = rappels(PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: r)))
        let aujourdhui = avant.filter { $0.quand.jour == lundi.jour }.map { $0.quand.minutesDuJour }
        #expect(aujourdhui == [13 * 60, 21 * 60])
        // La séance de 8 h 10 est inscrite : le plan repasse.
        var d = Donnees(reglages: r)
        let seance = lundi.plus(minutes: 10)
        Pratique.inscrire(&d, minutes: 15, jour: seance.jour, maintenant: seance)
        let faits = Pratique.joursFaits(d.journal)
        let apres = rappels(PlanNotifications.planifier(PlanNotifications.Entree(maintenant: seance, reglages: d.reglages, joursFaits: faits)))
        let restants = apres.filter { $0.quand.jour == lundi.jour }
        #expect(restants.isEmpty)
        let demain = apres.filter { $0.quand.jour == lundi.jour.plus(jours: 1) }
        #expect(demain.count == 3)
        // Dix jours au plus : trois heures par jour, trente rappels.
        let tous = rappels(PlanNotifications.planifier(PlanNotifications.Entree(maintenant: a("2026-11-16", 0, 0, z), reglages: r)))
        let derniers = Set(tous.map { $0.quand.jour })
        #expect(derniers.max() == JourCivil.du("2026-11-25"))
    }

    @Test func pendantLaSeancePasDeRappelEtLaFinSonne() throws {
        let z = try paris()
        let r = reglages([13 * 60, 21 * 60])
        let lundi = a("2026-11-16", 12, 50, z)
        let seance = PlanNotifications.Seance(debut: lundi.millis, fin: lundi.plus(minutes: 30).millis, duree: 30)
        let plan = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: r, seance: seance))
        let duJour = rappels(plan).filter { $0.quand.jour == lundi.jour }.map { $0.quand.minutesDuJour }
        #expect(duJour == [21 * 60])
        let fins = plan.filter { $0.sorte == .finSeance }.map { $0.quand }
        #expect(fins == [lundi.plus(minutes: 30)])
        // Une séance ouverte, sans durée : aucun rappel tant qu'elle n'est pas close, et pas de fin à sonner.
        let ouverte = PlanNotifications.Seance(debut: lundi.millis, fin: 0, duree: SessionRule.ouverte)
        let planOuvert = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: r, seance: ouverte))
        let sortes = Set(planOuvert.map { $0.sorte })
        #expect(!sortes.contains(.rappel) && !sortes.contains(.finSeance))
    }

    @Test func leRappelReporteDUneDemiHeure() throws {
        let z = try paris()
        var r = reglages([7 * 60, 13 * 60])
        let lundi = a("2026-11-16", 7, 0, z)
        PlanNotifications.reporterRappel(&r, maintenant: lundi.millis)
        #expect(r.rappelReporteJusqua == lundi.plus(minutes: 30).millis)
        let plan = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: r))
        let reportes = plan.filter { $0.sorte == .rappelReporte }.map { $0.quand }
        #expect(reportes == [lundi.plus(minutes: 30)])
        // Un report qui tomberait après le prochain rappel réglé est consommé par lui, comme sur Android.
        r.rappelReporteJusqua = a("2026-11-16", 13, 30, z).millis
        let tard = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi.plus(minutes: 1), reglages: r))
        let tardReporte = tard.contains { $0.sorte == .rappelReporte }
        #expect(!tardReporte)
        // La veille de Chabbat après midi, le report se tait lui aussi.
        r.rappelReporteJusqua = a("2026-11-20", 12, 30, z).millis
        let vendredi = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: a("2026-11-20", 12, 0, z), reglages: r))
        let vendrediReporte = vendredi.contains { $0.sorte == .rappelReporte }
        #expect(!vendrediReporte)
        // Rappels coupés : rien, report compris.
        r.rappelActif = false
        r.rappelReporteJusqua = lundi.plus(minutes: 30).millis
        let coupe = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: r))
        #expect(rappels(coupe).isEmpty)
    }

    @Test func chabbatLevanaEtVolDansLeurPart() throws {
        let z = try paris()
        let r = reglages([])
        let lundi = a("2026-11-16", 8, 0, z)
        let plan = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: r, lieuAlertes: Lieux.paris))
        let chabbat = plan.filter { $0.sorte == .chabbat }
        #expect(chabbat.count == 4)
        for p in chabbat {
            let jour = p.quand.jour
            #expect(jour.jourDeSemaine == 6)
            let allumage = ChabbatAlerte.allumage(Lieux.paris, jour, minutes: 18)
            #expect(p.quand == allumage?.plus(heures: -3))
        }
        let levana = plan.filter { $0.sorte == .levana }
        #expect(levana.count == 6)
        let soirs = levana.compactMap { $0.soir }
        #expect(soirs.count == 6)
        // Sans lieu : pas d'allumage connu, pas d'alerte de Chabbat ; Birkat haLevana à 20 h.
        let sansLieu = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: r))
        let chabbatSansLieu = sansLieu.contains { $0.sorte == .chabbat }
        #expect(!chabbatSansLieu)
        let heures = Set(sansLieu.filter { $0.sorte == .levana }.map { $0.quand.minutesDuJour })
        #expect(heures == [20 * 60])
        var sansLevana = r
        sansLevana.levanaRappel = false
        let rien = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: sansLevana))
        #expect(rien.isEmpty)
        // Le vol : les quatorze premiers à venir, pas ceux déjà montrés.
        var avecVol = r
        avecVol.volRappelVu = lundi.plus(heures: 2).millis
        let vol = (0..<30).map { VolRappels.Rappel(type: .priereFin, instant: lundi.plus(heures: $0 - 3).millis) }
        let planVol = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: avecVol, vol: vol))
        let instantsVol = planVol.filter { $0.sorte == .vol }.map { $0.quand }
        let attendus = (3..<17).map { lundi.plus(heures: $0) }
        #expect(instantsVol == attendus)
        avecVol.volRappelsActifs = false
        let sansVol = PlanNotifications.planifier(PlanNotifications.Entree(maintenant: lundi, reglages: avecVol, vol: vol))
        let volCoupe = sansVol.contains { $0.sorte == .vol }
        #expect(!volCoupe)
    }
}
