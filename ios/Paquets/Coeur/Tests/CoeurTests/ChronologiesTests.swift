import Foundation
import Testing
@testable import Coeur

/// Les chronologies des vignettes pour WidgetKit (PORTAGE.md § 2.2.3) : une entrée par zman, une au changement de jour
/// hébreu à tsét, une à minuit ; et rien ne change entre deux entrées — la vue au milieu de l'intervalle est celle de
/// l'entrée qui l'ouvre, sur cinq lieux, un jour de changement d'heure, la nuit et le jour polaires.
@Suite("Chronologies")
struct ChronologiesTests {

    private func fuseau(_ l: Zmanim.Lieu) throws -> Fuseau { try #require(Fuseau(l.fuseau)) }

    /// Le contenu d'une vue, sans l'instant de l'entrée.
    private func contenu(_ v: ZmanimVignette.Vue) -> String {
        let journee = v.journee.map { "\($0.cle)@\($0.quand.millis)" }.joined(separator: ",")
        return "\(v.jourHebreu.iso)|\(v.priere ?? "-")|\(v.limite?.millis ?? -1)|\(v.debutJauge?.millis ?? -1)|\(journee)|\(v.prochain ?? -1)"
    }

    @Test func uneEntreeParZmanEtLaBasculeDuJourHebreuATset() throws {
        let l = Lieux.jerusalem
        let z = try fuseau(l)
        let d = JourCivil.du("2026-11-02")
        let minuit = DateHeureZonee(DateHeure(d), fuseau: z)
        let vues = ZmanimVignette.chronologie(depuis: minuit) { ZmanimVignette.horaires(l, $0) }
        let instants = Set(vues.map { $0.quand.millis })
        let horaires = ZmanimVignette.horaires(l, d)
        #expect(horaires.count == 15)
        for (cle, t) in horaires where t <= minuit.plus(heures: 24) {
            #expect(instants.contains(t.millis), "\(cle) sans entrée")
        }
        // Minuit du lendemain a son entrée : la date civile change, et avec elle les horaires du jour.
        #expect(instants.contains(DateHeureZonee(DateHeure(d.plus(jours: 1)), fuseau: z).millis))
        let tset = try #require(horaires["tset"])
        let avant = vues.filter { $0.quand < tset }
        let apres = vues.filter { !($0.quand < tset) && $0.quand.jour == d }
        #expect(!avant.isEmpty && !apres.isEmpty)
        let joursAvant = Set(avant.map { $0.jourHebreu })
        let joursApres = Set(apres.map { $0.jourHebreu })
        #expect(joursAvant == [d])
        #expect(joursApres == [d.plus(jours: 1)])
        let trouve = vues.first { $0.quand == tset }
        let aTset = try #require(trouve)
        #expect(aTset.jourHebreu == d.plus(jours: 1))
        // Les entrées sont dans l'ordre, sans doublon.
        let millis = vues.map { $0.quand.millis }
        #expect(millis == millis.sorted() && Set(millis).count == millis.count)
    }

    @Test func rienNeChangeEntreDeuxEntrees() throws {
        let cas: [(Zmanim.Lieu, String)] = [
            (Lieux.jerusalem, "2026-11-02"), (Lieux.paris, "2026-03-28"), (Lieux.newYork, "2026-11-01"),
            (Lieux.melbourne, "2026-04-04"), (Lieux.tromso, "2026-06-21"), (Lieux.tromso, "2026-12-21"),
        ]
        for (l, iso) in cas {
            let z = try fuseau(l)
            var memoire: [JourCivil: [String: DateHeureZonee]] = [:]
            func horaires(_ j: JourCivil) -> [String: DateHeureZonee] {
                if let h = memoire[j] { return h }
                let h = ZmanimVignette.horaires(l, j)
                memoire[j] = h
                return h
            }
            let depart = DateHeureZonee(DateHeure(JourCivil.du(iso), heure: 9, minute: 17), fuseau: z)
            let vues = ZmanimVignette.chronologie(depuis: depart, heures: 48) { horaires($0) }
            #expect(vues.count >= 3, "\(l.nom) \(iso) : \(vues.count)")
            for k in vues.indices.dropLast() {
                let milieu = DateHeureZonee(millis: (vues[k].quand.millis + vues[k + 1].quand.millis) / 2, fuseau: z)
                let ici = ZmanimVignette.vue(milieu, aujourdhui: horaires(milieu.jour), demain: horaires(milieu.jour.plus(jours: 1)))
                #expect(contenu(ici) == contenu(vues[k]), "\(l.nom) \(milieu)")
                let juste = DateHeureZonee(millis: vues[k + 1].quand.millis - 1, fuseau: z)
                let avantLaSuivante = ZmanimVignette.vue(juste, aujourdhui: horaires(juste.jour), demain: horaires(juste.jour.plus(jours: 1)))
                #expect(contenu(avantLaSuivante) == contenu(vues[k]), "\(l.nom) \(juste)")
            }
        }
    }

    @Test func laVueDeLaVignette() throws {
        let l = Lieux.jerusalem
        let d = JourCivil.du("2026-11-02")
        let h = ZmanimVignette.horaires(l, d)
        let demain = ZmanimVignette.horaires(l, d.plus(jours: 1))
        let szt = try #require(h["szt_gra"])
        let matin = ZmanimVignette.vue(szt.plus(minutes: -10), aujourdhui: h, demain: demain)
        #expect(matin.priere == "chaharit" && matin.limite == szt && matin.debutJauge == h["alot"])
        #expect(matin.journee.count == 9 && matin.journee[matin.prochain ?? 0].cle == "szt_gra")
        // La nuit tombée, la journée montrée est celle de demain.
        let tset = try #require(h["tset"])
        let soir = ZmanimVignette.vue(tset.plus(minutes: 5), aujourdhui: h, demain: demain)
        #expect(soir.priere == "arvit" && soir.jourHebreu == d.plus(jours: 1))
        #expect(soir.journee.first?.quand == demain["alot"] && soir.prochain == 0)
        #expect(ZmanimWidget.cle("minha") == "widget_zmanim_minha")
        // Sans lieu : la date du téléphone, qui change à minuit, même là où minuit n'existe pas.
        let santiago = try #require(Fuseau("America/Santiago"))
        let veille = DateHeureZonee(DateHeure(JourCivil.du("2026-09-05"), heure: 20), fuseau: santiago)
        let sansLieu = ZmanimVignette.chronologieSansLieu(depuis: veille)
        #expect(sansLieu.count == 2)
        #expect(sansLieu.last?.jourHebreu == JourCivil.du("2026-09-06"))
        #expect(sansLieu.last?.quand.civile == DateHeure(JourCivil.du("2026-09-06"), heure: 1))
        #expect(sansLieu.first?.priere == nil)
    }

    @Test func minuitDuTelephoneEtVignetteDeLaSerie() throws {
        let l = Lieux.jerusalem
        let z = try fuseau(l)
        let newYork = try #require(Fuseau("America/New_York"))
        let depart = DateHeureZonee(DateHeure(JourCivil.du("2026-11-02"), heure: 12), fuseau: z)
        let sans = ZmanimVignette.chronologie(depuis: depart) { ZmanimVignette.horaires(l, $0) }
        let avec = ZmanimVignette.chronologie(depuis: depart, fuseauTelephone: newYork) { ZmanimVignette.horaires(l, $0) }
        let minuitNY = DateHeureZonee(DateHeure(JourCivil.du("2026-11-03")), fuseau: newYork).millis
        let instantsSans = Set(sans.map { $0.quand.millis })
        let instantsAvec = Set(avec.map { $0.quand.millis })
        #expect(!instantsSans.contains(minuitNY))
        #expect(instantsAvec.contains(minuitNY))
        // La série : maintenant, la fin de la séance, chaque minuit.
        let paris = try #require(Fuseau("Europe/Paris"))
        let soir = DateHeureZonee(DateHeure(JourCivil.du("2026-11-16"), heure: 23, minute: 50), fuseau: paris)
        let serie = VignetteSerie.chronologie(depuis: soir, finSeance: soir.plus(minutes: 20).millis, heures: 20)
        let civiles = serie.map { $0.civile }
        #expect(civiles == [DateHeure(JourCivil.du("2026-11-16"), heure: 23, minute: 50),
                            DateHeure(JourCivil.du("2026-11-17")),
                            DateHeure(JourCivil.du("2026-11-17"), heure: 0, minute: 10)])
    }
}
