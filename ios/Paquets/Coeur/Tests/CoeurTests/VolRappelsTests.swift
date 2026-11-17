import Foundation
import Testing
@testable import Coeur

/// VolRappelsTest d'Android, porté : les rappels en vol (VolRappels) et le suivi OpenSky anonyme (SuiviVol), sur les
/// trajets déjà vérifiés (VolTests) : Melbourne → Los Angeles → Montréal et retour, Sydney → Queenstown, Tel Aviv →
/// Buenos Aires, Tel Aviv ↔ New York. Les bornes des prières sont celles de l'application ; ces tests vérifient
/// qu'elles sont appliquées aux zmanim de la route, pas une règle. Puis les dix-neuf vols de
/// `Tests/Vecteurs/vol_suite.json` (tools/vecteurs_ios/VecteursVolSuite.kt) : la prière ouverte sur un balayage et
/// les rappels, à partir des zmanim de la route que la JVM a trouvés.
///
/// Restent à Android, ou au portage de VolAlerte.kt (les notifications) : dans `un vol de moins de cinq minutes n a
/// pas de rappel, un rappel n est montre qu une fois`, la seconde moitié (`VolAlerte.dus`) ; ici, le vol trop court.
/// Le fournisseur `OpenSkyAnonyme` et le `Relais`, qui ouvrent le réseau, restent à l'app : `SuiviVol.fournisseur`
/// dit lequel prendre.
@Suite("Rappels en vol", .serialized)
struct VolRappelsTests {
    private let aeroports: [Vol.Aeroport]

    init() throws {
        aeroports = try Aeroports.parse(String(decoding: Depot.contenu("aeroports.json"), as: UTF8.self))
    }

    private func a(_ iata: String) throws -> Vol.Aeroport {
        let x = Aeroports.parIata(aeroports, iata)
        return try #require(x, "\(iata) absent")
    }

    /// « 2026-12-15T10:30 » : `LocalDateTime.parse`, à la minute.
    private func local(_ texte: String) -> DateHeure {
        let jour = JourCivil.du(String(texte.prefix(10)))
        let h = Int(texte.dropFirst(11).prefix(2)) ?? 0
        let m = Int(texte.dropFirst(14).prefix(2)) ?? 0
        return DateHeure(jour, heure: h, minute: m)
    }

    /// Les heures du billet, lues à l'heure de chaque aéroport.
    private func plan(_ de: String, _ vers: String, _ decollage: String, _ atterrissage: String) throws -> Vol.Plan {
        let d = try a(de)
        let v = try a(vers)
        let i0 = Vol.instant(local(decollage), d)
        let i1 = Vol.instant(local(atterrissage), v)
        let t0 = try #require(i0, "\(de) \(decollage)")
        let t1 = try #require(i1, "\(vers) \(atterrissage)")
        return Vol.Plan(numero: "TEST", depart: d, arrivee: v, decollage: t0, atterrissage: t1)
    }

    private func trajets() throws -> [Vol.Plan] {
        [
            try plan("MEL", "LAX", "2026-12-15T10:30", "2026-12-15T06:45"),
            try plan("LAX", "YUL", "2026-12-15T09:30", "2026-12-15T17:55"),
            try plan("YUL", "LAX", "2026-12-22T08:00", "2026-12-22T11:05"),
            try plan("LAX", "MEL", "2026-12-22T22:30", "2026-12-24T08:45"),
            try plan("SYD", "ZQN", "2026-12-18T09:00", "2026-12-18T14:15"),
            try plan("TLV", "EZE", "2026-11-10T23:00", "2026-11-11T09:20"),
            try plan("TLV", "JFK", "2026-11-10T12:30", "2026-11-10T17:45"),
            try plan("JFK", "TLV", "2026-11-10T23:00", "2026-11-11T16:40"),
        ]
    }

    /// Ce que tout rappel doit respecter, quel que soit le trajet.
    private func verifier(_ c: Vol.Calcul, _ r: [VolRappels.Rappel]) throws {
        let p = c.plan
        var trie = true
        for i in r.indices.dropFirst() where r[i - 1].instant > r[i].instant { trie = false }
        #expect(trie, "rappels dans l'ordre des instants")
        for x in r {
            let dedans = x.instant >= p.decollage && x.instant <= p.atterrissage
            #expect(dedans, "\(x.type.rawValue) \(x.instant) hors du vol")
        }
        let premier = r.first
        let derekh = try #require(premier)
        #expect(derekh.type == VolRappels.Genre.tefilatHaderekh)
        #expect(derekh.instant == p.decollage + 5 * 60_000)
        let auDecollage = VolRappels.ouverte(c, derekh.instant)
        let priereOuverte = auDecollage?.priere
        let limiteOuverte = auDecollage?.limite
        #expect(priereOuverte == derekh.priere)
        #expect(limiteOuverte == derekh.limite)
        let derekhs = r.filter { $0.type == .tefilatHaderekh }.count
        #expect(derekhs == 1)
        for x in r where x.type == .priere {
            let trouvee = VolRappels.bornes.first { $0.priere == x.priere }
            let borne = try #require(trouvee, "borne de \(x.priere ?? "null")")
            let auDebut = c.enVol.contains { $0.cle == borne.debut && $0.instant == x.instant }
            #expect(auDebut, "\(borne.debut) à \(x.instant)")
            let limite = c.evenements.first { $0.cle == borne.fin && $0.instant > x.instant }?.instant
            #expect(limite == x.limite)
            let ouverte = VolRappels.ouverte(c, x.instant)?.priere
            #expect(ouverte == x.priere)
        }
        for x in r where x.type == .priereFin {
            #expect(x.priere != "arvit")
            let ecart = (x.limite ?? 0) - x.instant
            #expect(ecart == 30 * 60_000)
            let ouverte = VolRappels.ouverte(c, x.instant)
            let priere = ouverte?.priere
            let limite = ouverte?.limite
            #expect(priere == x.priere)
            #expect(limite == x.limite)
        }
        let omer = VolCalendrier.jalons(c, enIsrael: false, minutes: 0).filter { $0.type == .omer }.map { [$0.instant, Int64($0.omer)] }
        let rappelsOmer = r.filter { $0.type == .omer }.map { [$0.instant, Int64($0.omer)] }
        #expect(omer == rappelsOmer)
    }

    @Test func lesRappelsDesTrajetsVerifiesTombentDansLeVolAuxBornesDeLApplication() throws {
        let liste = try trajets()
        var rappels: [[VolRappels.Rappel]] = []
        for p in liste {
            let c = Vol.calculer(p)
            let r = VolRappels.rappels(c, enIsrael: false)
            try verifier(c, r)
            rappels.append(r)
        }
        // Tel Aviv → New York de jour : Min'ha ouverte au décollage, sa limite dans l'avion, puis Arvit.
        let ouest = rappels[6]
        let premiere = ouest.first?.priere
        #expect(premiere == "minha")
        let finMinha = ouest.contains { $0.type == .priereFin && $0.priere == "minha" }
        #expect(finMinha)
        let arvit = ouest.contains { $0.type == .priere && $0.priere == "arvit" }
        #expect(arvit)
        // New York → Tel Aviv de nuit : Cha'harit commence dans l'avion, au lever du soleil sous lui.
        let chaharit = rappels[7].contains { $0.type == .priere && $0.priere == "chaharit" }
        #expect(chaharit)
    }

    @Test func leOmerEnVolASonRappelLeJourDuSoir() throws {
        var veille = JourCivil.du("2027-01-01")
        var pas = 0
        while CalendrierJuif.jour(veille.plus(jours: 1), enIsrael: false).omer != 4 && pas < 400 {
            veille = veille.plus(jours: 1)
            pas += 1
        }
        #expect(pas < 400)
        let c = Vol.calculer(try plan("TLV", "JFK", veille.iso + "T17:00", veille.iso + "T22:15"))
        let r = VolRappels.rappels(c, enIsrael: false)
        try verifier(c, r)
        let omers = r.filter { $0.type == .omer }
        let comptes = omers.map { $0.omer }
        #expect(comptes == [4])
        // Le Omer tombe à la sortie des étoiles, avec Arvit : deux rappels à la même minute.
        let omer = try #require(omers.first)
        let avecArvit = r.contains { $0.type == .priere && $0.priere == "arvit" && $0.instant == omer.instant }
        #expect(avecArvit)
    }

    @Test func unVolDeMoinsDeCinqMinutesNAPasDeRappel() throws {
        let jour = JourCivil.du("2026-11-10")
        let court = Vol.Plan(numero: "T", depart: try a("TLV"), arrivee: try a("ETM"),
                             decollage: Fuseau.utc.millis(DateHeure(jour, heure: 8)),
                             atterrissage: Fuseau.utc.millis(DateHeure(jour, heure: 8, minute: 4)))
        let r = VolRappels.rappels(Vol.calculer(court), enIsrael: false)
        #expect(r.isEmpty)
    }

    @Test func openSkyAnonymeLaReponseBruteLesCarresLAdresse() {
        let maintenant: Int64 = 1_794_335_700_000  // 2026-11-10T18:35:00Z
        let t = "1794335400"  // 2026-11-10T18:30:00Z, en secondes
        let json = "{\"time\":" + t + ",\"states\":[\n" +
            "    [\"abc\",\"AFR12   \",\"France\"," + t + "," + t + ",-20.0,51.0,11000,false,250,270,0,null,11200,\"1\",false,0],\n" +
            "    [\"def\",\"ELY001  \",\"Israel\"," + t + "," + t + ",-21.2,50.5,10900,false,250,270,0,null,11150,\"2\",false,0]]}"
        let trouve = SuiviVol.lireEtats(json, "ELY1", maintenant)
        let attendu = SuiviVol.Resultat.trouve(point: Vol.Point(instant: 1_794_335_400_000, latitude: 50.5, longitude: -21.2),
                                               altitudeMetres: 11150.0)
        #expect(trouve == attendu)
        // Au sol, ou sans position : ignoré.
        let sol = "{\"time\":" + t + ",\"states\":[[\"def\",\"ELY1\",\"Israel\"," + t + "," + t +
            ",34.9,32.0,null,true,0,0,0,null,null,\"2\",false,0],\n" +
            "    [\"def\",\"ELY1\",\"Israel\",null," + t + ",null,null,null,false,0,0,0,null,null,\"2\",false,0]]}"
        let auSol = SuiviVol.lireEtats(sol, "ELY1", maintenant)
        #expect(auSol == SuiviVol.Resultat.introuvable)
        let vide = SuiviVol.lireEtats("{\"time\":0,\"states\":null}", "ELY1", maintenant)
        #expect(vide == SuiviVol.Resultat.introuvable)
        let html = SuiviVol.lireEtats("<html>", "ELY1", maintenant)
        var erreur = false
        if case .erreur = html { erreur = true }
        #expect(erreur)
        // Le carré de ±5° (2 crédits), coupé en deux au méridien de 180°, comme le relais.
        let carre = SuiviVol.carres(50.1, -20.3)
        #expect(carre == [[45.1, -25.3, 55.1, -15.3]])
        let coupe = SuiviVol.carres(10.0, 178.0)
        #expect(coupe == [[5.0, 173.0, 15.0, 180.0], [5.0, -180.0, 15.0, -177.0]])
        let adresse = carre.count == 1 ? SuiviVol.adresseEtats(carre[0]) : ""
        #expect(adresse == "https://opensky-network.org/api/states/all?lamin=45.1&lomin=-25.3&lamax=55.1&lomax=-15.3")
        // Sans relais configuré, l'édition interroge OpenSky en accès anonyme.
        let sansRelais = SuiviVol.fournisseur("")
        #expect(sansRelais == SuiviVol.Fournisseur.openSkyAnonyme)
        let relais = SuiviVol.fournisseur("https://r.test")
        #expect(relais == SuiviVol.Fournisseur.relais("https://r.test"))
        let http = SuiviVol.fournisseur("http://r.test")
        // `fournisseur(…) as? Relais` vaut null : ce n'est un relais d'aucune adresse.
        #expect(http == SuiviVol.Fournisseur.openSkyAnonyme)
    }

    // MARK: Les vecteurs de la JVM

    private struct Fichier: Decodable {
        let vols: [VolEcrit]
    }

    private struct VolEcrit: Decodable {
        let plan: PlanEcrit
        let enIsrael: Bool
        let evenements: [EvenementEcrit]
        let ouvertes: [OuverteEcrite]
        let rappels: [RappelEcrit]
        let rappelsEdot: [RappelEcrit]
    }

    /// [départ, arrivée, décollage, atterrissage].
    private struct PlanEcrit: Decodable {
        let depart: String
        let arrivee: String
        let decollage: Int64
        let atterrissage: Int64

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            depart = try c.decode(String.self)
            arrivee = try c.decode(String.self)
            decollage = try c.decode(Int64.self)
            atterrissage = try c.decode(Int64.self)
        }
    }

    /// [clé, instant, latitude, longitude].
    private struct EvenementEcrit: Decodable {
        let evenement: Vol.Evenement

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            let cle = try c.decode(String.self)
            let instant = try c.decode(Int64.self)
            let latitude = try c.decode(Double.self)
            let longitude = try c.decode(Double.self)
            evenement = Vol.Evenement(cle: cle, instant: instant, latitude: latitude, longitude: longitude)
        }
    }

    /// [instant, prière ou null, limite ou null].
    private struct OuverteEcrite: Decodable {
        let instant: Int64
        let ouverte: VolRappels.Ouverte?

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            instant = try c.decode(Int64.self)
            let priere = try c.decodeIfPresent(String.self)
            let limite = try c.decodeIfPresent(Int64.self)
            if let priere, let limite {
                ouverte = VolRappels.Ouverte(priere: priere, limite: limite)
            } else {
                ouverte = nil
            }
        }
    }

    /// [TYPE, instant, prière ou null, limite ou null, omer, chema ou null, chemaCle ou null, chemaAutre ou null] ;
    /// le type est le nom de Kotlin.
    private struct RappelEcrit: Decodable {
        let rappel: VolRappels.Rappel?
        let nom: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            nom = try c.decode(String.self)
            let instant = try c.decode(Int64.self)
            let priere = try c.decodeIfPresent(String.self)
            let limite = try c.decodeIfPresent(Int64.self)
            let omer = try c.decode(Int.self)
            let chema = try c.decodeIfPresent(Int64.self)
            let chemaCle = try c.decodeIfPresent(String.self)
            let chemaAutre = try c.decodeIfPresent(Int64.self)
            rappel = VolRappels.Genre(rawValue: nom.lowercased()).map {
                VolRappels.Rappel(type: $0, instant: instant, priere: priere, limite: limite, omer: omer, chema: chema,
                                  chemaCle: chemaCle, chemaAutre: chemaAutre)
            }
        }
    }

    @Test func lesVolsTypesOuvrentEtRappellentCommeSurLaJvm() throws {
        let f = try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vol_suite.json"))
        #expect(f.vols.count >= 19)
        var sondes = 0
        var rappels = 0
        for v in f.vols {
            let plan = Vol.Plan(numero: "TEST", depart: try a(v.plan.depart), arrivee: try a(v.plan.arrivee),
                                decollage: v.plan.decollage, atterrissage: v.plan.atterrissage)
            let calcul = Vol.Calcul(plan: plan, evenements: v.evenements.map { $0.evenement }, reserves: [], lignesDate: [])
            let nom = "\(v.plan.depart)→\(v.plan.arrivee) \(v.plan.decollage)"
            for o in v.ouvertes {
                let obtenue = VolRappels.ouverte(calcul, o.instant)
                #expect(obtenue == o.ouverte, "\(nom) : ouverte à \(o.instant)")
                sondes += 1
            }
            let attendus = v.rappels.compactMap { $0.rappel }
            #expect(attendus.count == v.rappels.count, "\(nom) : types de rappel connus")
            let obtenus = VolRappels.rappels(calcul, enIsrael: v.enIsrael)
            #expect(obtenus == attendus, "\(nom) : rappels")
            rappels += attendus.count
            // Le Chema du Maguen Avraham pour les Edot (audit du 16/11).
            let attendusEdot = v.rappelsEdot.compactMap { $0.rappel }
            #expect(attendusEdot.count == v.rappelsEdot.count, "\(nom) : types de rappel connus (edot)")
            let obtenusEdot = VolRappels.rappels(calcul, enIsrael: v.enIsrael, nusah: .edot)
            #expect(obtenusEdot == attendusEdot, "\(nom) : rappels (edot)")
        }
        #expect(sondes >= 1000)
        #expect(rappels >= 50)
    }
}
