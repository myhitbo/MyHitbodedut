import Foundation
import Testing
@testable import Coeur

/// VolRappelsTest d'Android, porté : les rappels de huit trajets vérifiés tombent dans le vol, aux bornes
/// de l'application ; le Omer ; un vol trop court ; OpenSky anonyme. Puis les rappels et la prière du
/// moment de neuf trajets devant la JVM (Tests/Vecteurs/geographie_vol.json), à deux secondes près.
@Suite("Rappels en vol")
struct VolRappelsTests {

    private func trajets() throws -> [Vol.Plan] {
        try [
            Trajets.plan("MEL", "LAX", "2026-12-15T10:30", "2026-12-15T06:45"),
            Trajets.plan("LAX", "YUL", "2026-12-15T09:30", "2026-12-15T17:55"),
            Trajets.plan("YUL", "LAX", "2026-12-22T08:00", "2026-12-22T11:05"),
            Trajets.plan("LAX", "MEL", "2026-12-22T22:30", "2026-12-24T08:45"),
            Trajets.plan("SYD", "ZQN", "2026-12-18T09:00", "2026-12-18T14:15"),
            Trajets.plan("TLV", "EZE", "2026-11-10T23:00", "2026-11-11T09:20"),
            Trajets.plan("TLV", "JFK", "2026-11-10T12:30", "2026-11-10T17:45"),
            Trajets.plan("JFK", "TLV", "2026-11-10T23:00", "2026-11-11T16:40"),
        ]
    }

    /// Ce que tout rappel doit respecter, quel que soit le trajet.
    private func verifier(_ c: Vol.Calcul, _ r: [VolRappels.Rappel]) throws {
        let p = c.plan
        let instants = r.map(\.instant)
        #expect(instants == instants.sorted())
        for x in r { #expect(x.instant >= p.decollage && x.instant <= p.atterrissage, "\(x) hors du vol") }
        let derekh = try #require(r.first)
        #expect(derekh.type == .tefilatHaderekh)
        #expect(derekh.instant == p.decollage + 5 * 60_000)
        let ouverte = VolRappels.ouverte(c, derekh.instant)
        #expect(ouverte?.priere == derekh.priere && ouverte?.limite == derekh.limite)
        let derekhs = r.filter { $0.type == .tefilatHaderekh }
        #expect(derekhs.count == 1)
        for x in r where x.type == .priere {
            let b = try #require(VolRappels.bornes.first { $0.priere == x.priere })
            let ouvre = c.enVol.contains { $0.cle == b.debut && $0.instant == x.instant }
            #expect(ouvre)
            let fin = c.evenements.first { $0.cle == b.fin && $0.instant > x.instant }?.instant
            #expect(fin == x.limite)
            #expect(VolRappels.ouverte(c, x.instant)?.priere == x.priere)
        }
        for x in r where x.type == .priereFin {
            #expect(x.priere != "arvit")
            let limite = try #require(x.limite)
            #expect(limite - x.instant == Int64(30 * 60_000))
            let o = VolRappels.ouverte(c, x.instant)
            #expect(o?.priere == x.priere && o?.limite == x.limite)
        }
        let omer = VolCalendrier.jalons(c, enIsrael: false, minutes: 0).filter { $0.type == .omer }.map { "\($0.instant):\($0.omer)" }
        let rappelsOmer = r.filter { $0.type == .omer }.map { "\($0.instant):\($0.omer)" }
        #expect(omer == rappelsOmer)
    }

    @Test func lesRappelsDesTrajetsVerifiesTombentDansLeVolAuxBornesDeLApplication() throws {
        let t = try trajets()
        for p in t {
            let c = Trajets.calcul(p)
            try verifier(c, VolRappels.rappels(c, enIsrael: false))
        }
        // Tel Aviv → New York de jour : Min'ha ouverte au décollage, sa limite dans l'avion, puis Arvit.
        let ouest = VolRappels.rappels(Trajets.calcul(t[6]), enIsrael: false)
        #expect(ouest.first?.priere == "minha")
        let finMinha = ouest.contains { $0.type == .priereFin && $0.priere == "minha" }
        let arvit = ouest.contains { $0.type == .priere && $0.priere == "arvit" }
        #expect(finMinha && arvit)
        // New York → Tel Aviv de nuit : Cha'harit commence dans l'avion, au lever du soleil sous lui.
        let chaharit = VolRappels.rappels(Trajets.calcul(t[7]), enIsrael: false).contains { $0.type == .priere && $0.priere == "chaharit" }
        #expect(chaharit)
    }

    @Test func leOmerEnVolASonRappelLeJourDuSoir() throws {
        var veille = JourCivil.du("2027-01-01")
        while CalendrierJuif.jour(veille.plus(jours: 1), enIsrael: false).omer != 4 { veille = veille.plus(jours: 1) }
        let c = Trajets.calcul(try Trajets.plan("TLV", "JFK", "\(veille.iso)T17:00", "\(veille.iso)T22:15"))
        let r = VolRappels.rappels(c, enIsrael: false)
        try verifier(c, r)
        let omers = r.filter { $0.type == .omer }
        let comptes = omers.map(\.omer)
        #expect(comptes == [4])
        // Le Omer tombe à la sortie des étoiles, avec Arvit : deux rappels à la même minute.
        let omer = try #require(omers.first)
        let ensemble = r.contains { $0.type == .priere && $0.priere == "arvit" && $0.instant == omer.instant }
        #expect(ensemble)
    }

    @Test func unVolDeMoinsDeCinqMinutesNAPasDeRappelUnRappelNEstMontreQuUneFois() throws {
        let debut = try #require(InstantISO.lire("2026-11-10T08:00:00Z"))
        let court = Vol.Plan(numero: "T", depart: try Trajets.a("TLV"), arrivee: try Trajets.a("ETM"), decollage: debut,
                             atterrissage: debut + 4 * 60_000)
        #expect(VolRappels.rappels(Trajets.calcul(court), enIsrael: false).isEmpty)
        let r = VolRappels.rappels(Trajets.calcul(try trajets()[6]), enIsrael: false)
        try #require(r.count > 1)
        let t = r[1].instant
        let dus = VolRappels.dus(r, vu: r[0].instant, maintenant: t).filter { $0 == r[1] }
        #expect(dus == [r[1]])
        let dejaVus = VolRappels.dus(r, vu: t, maintenant: t).filter { $0.instant <= t }
        #expect(dejaVus.isEmpty)
        // Trop tard (plus de 20 min) : passé, pas montré.
        let tard = VolRappels.dus(r, vu: 0, maintenant: t + 25 * 60_000).filter { $0 == r[1] }
        #expect(tard.isEmpty)
    }

    @Test func openSkyAnonymeLaReponseBruteLesCarresLAdresse() throws {
        let maintenant = try #require(InstantISO.lire("2026-11-10T18:35:00Z"))
        let t = try #require(InstantISO.lire("2026-11-10T18:30:00Z")) / 1000
        let json = """
            {"time":\(t),"states":[
            ["abc","AFR12   ","France",\(t),\(t),-20.0,51.0,11000,false,250,270,0,null,11200,"1",false,0],
            ["def","ELY001  ","Israel",\(t),\(t),-21.2,50.5,10900,false,250,270,0,null,11150,"2",false,0]]}
            """
        #expect(SuiviVol.lireEtats(json, "ELY1", maintenant: maintenant)
                == .trouve(Vol.Point(instant: t * 1000, latitude: 50.5, longitude: -21.2), altitudeMetres: 11150))
        // Au sol, ou sans position : ignoré.
        let sol = """
            {"time":\(t),"states":[["def","ELY1","Israel",\(t),\(t),34.9,32.0,null,true,0,0,0,null,null,"2",false,0],
            ["def","ELY1","Israel",null,\(t),null,null,null,false,0,0,0,null,null,"2",false,0]]}
            """
        #expect(SuiviVol.lireEtats(sol, "ELY1", maintenant: maintenant) == .introuvable)
        #expect(SuiviVol.lireEtats(#"{"time":0,"states":null}"#, "ELY1", maintenant: maintenant) == .introuvable)
        var erreur = false
        if case .erreur = SuiviVol.lireEtats("<html>", "ELY1", maintenant: maintenant) { erreur = true }
        #expect(erreur)
        // Le carré de ±5° (2 crédits), coupé en deux au méridien de 180°, comme le relais.
        #expect(SuiviVol.carres(50.1, -20.3) == [[45.1, -25.3, 55.1, -15.3]])
        #expect(SuiviVol.carres(10.0, 178.0) == [[5.0, 173.0, 15.0, 180.0], [5.0, -180.0, 15.0, -177.0]])
        #expect(SuiviVol.adresseEtats(SuiviVol.carres(50.1, -20.3)[0])
                == "https://opensky-network.org/api/states/all?lamin=45.1&lomin=-25.3&lamax=55.1&lomax=-15.3")
        // Sans relais configuré, l'édition interroge OpenSky en accès anonyme.
        let lecteur: LecteurAdresse = { _ in (200, "{}") }
        let horloge: @Sendable () -> Int64 = { 0 }
        let anonyme = SuiviVol.fournisseur("", lecteur: lecteur, horloge: horloge) is SuiviVol.OpenSkyAnonyme
        let relais = SuiviVol.fournisseur("https://r.test", lecteur: lecteur, horloge: horloge) is SuiviVol.Relais
        let clair = SuiviVol.fournisseur("http://r.test", lecteur: lecteur, horloge: horloge) is SuiviVol.Relais
        #expect(anonyme && relais && !clair)
    }

    // MARK: Devant la JVM

    /// « type|instant|prière|limite|omer » et « instant|prière|limite » : les noms à l'identique, les instants
    /// à deux secondes (KosherSwift et KosherJava s'écartent d'une seconde, la racine est cherchée à la
    /// demi-seconde des deux côtés).
    private func proches(_ rendu: [String], _ attendu: [String]) -> Bool {
        guard rendu.count == attendu.count else { return false }
        for (x, y) in zip(rendu, attendu) {
            let a = x.components(separatedBy: "|"), b = y.components(separatedBy: "|")
            guard a.count == b.count else { return false }
            for (u, v) in zip(a, b) where u != v {
                guard let i = Int64(u), let j = Int64(v), abs(i - j) <= 2000 else { return false }
            }
        }
        return true
    }

    @Test func lesRappelsEtLaPriereDuMomentDeNeufTrajetsSuiventLaJVM() throws {
        let cas = try Depot.vecteurs("geographie_vol.json").objets("trajets")
        #expect(cas.count == 9)
        for o in cas {
            let nom = o.texte("trajet").components(separatedBy: "-")
            let plans = try trajets() + [Trajets.plan("TLV", "JFK", "2027-03-29T17:00", "2027-03-29T22:15")]
            let p = try #require(plans.first {
                $0.depart.iata == nom[0] && $0.arrivee.iata == nom[1] && $0.decollage == o.long("decollage")
            })
            let c = Trajets.calcul(p)
            let rappels = VolRappels.rappels(c, enIsrael: false).map {
                "\($0.type.nom)|\($0.instant)|\($0.priere ?? "-")|\($0.limite.map { String($0) } ?? "-")|\($0.omer)"
            }
            let attendus = o.textes("rappels")
            #expect(proches(rappels, attendus), "\(o.texte("trajet")) : \(rappels) au lieu de \(attendus)")
            var prieres: [String] = []
            var t = p.decollage - 7 * 3_600_000
            while t <= p.atterrissage + 7 * 3_600_000 {
                let r = VolPriere.priere(c, t)
                prieres.append("\(t)|\(r?.priere ?? "-")|\(r?.limite.map { String($0) } ?? "-")")
                t += 20 * 60_000
            }
            #expect(proches(prieres, o.textes("prieres")), "\(o.texte("trajet"))")
        }
    }
}
