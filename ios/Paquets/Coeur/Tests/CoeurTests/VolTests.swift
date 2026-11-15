import Foundation
import Synchronization
import Testing
@testable import Coeur

/// Les aéroports et la table des villes, lus une fois ; les calculs de vol, faits une fois par trajet.
enum Trajets {
    static let aeroports: Result<[Vol.Aeroport], any Error> = Result {
        try Aeroports.parse(Depot.texte("aeroports.json"), noms: Depot.texte("aeroports_noms.json"))
    }

    static func a(_ iata: String) throws -> Vol.Aeroport { try #require(Aeroports.parIata(try aeroports.get(), iata), "\(iata) absent") }

    /// « 2026-11-10T12:30 » : `LocalDateTime.parse`.
    static func locale(_ texte: String) -> DateHeure {
        let parties = texte.components(separatedBy: "T")
        let hm = parties[1].components(separatedBy: ":").compactMap { Int($0) }
        return DateHeure(.du(parties[0]), heure: hm[0], minute: hm[1])
    }

    static func plan(_ de: String, _ vers: String, _ decollage: String, _ atterrissage: String) throws -> Vol.Plan {
        let d = try a(de), v = try a(vers)
        return Vol.Plan(numero: "TEST", depart: d, arrivee: v, decollage: try #require(Vol.instant(locale(decollage), d)),
                        atterrissage: try #require(Vol.instant(locale(atterrissage), v)))
    }

    private static let memoire = Mutex<[String: Vol.Calcul]>([:])

    /// `Vol.calculer`, gardé : plusieurs suites demandent les mêmes trajets.
    static func calcul(_ p: Vol.Plan) -> Vol.Calcul {
        let cle = "\(p.depart.iata)-\(p.arrivee.iata)-\(p.decollage)-\(p.atterrissage)-\(p.releve.map { "\($0)" } ?? "")-\(p.sourceReleve)"
            + "-\(p.depart.fuseau)-\(p.arrivee.fuseau)"
        if let c = memoire.withLock({ $0[cle] }) { return c }
        let c = Vol.calculer(p)
        memoire.withLock { $0[cle] = c }
        return c
    }

    /// Les zmanim du moteur au sol d'un aéroport, au niveau de la mer.
    static func sol(_ iata: String, _ iso: String, _ cle: String) throws -> Int64 {
        let x = try a(iata)
        let lieu = Zmanim.Lieu(nom: x.ville, latitude: x.latitude, longitude: x.longitude, altitude: 0, fuseau: x.fuseau)
        let z = try #require(Zmanim.jour(lieu: lieu, date: .du(iso)).first { $0.cle == cle }?.instant)
        return Vol.millis(z)
    }

    /// L'écart au zman du moteur au point sous l'avion (veille, jour, lendemain), en millisecondes.
    static func ecartAuPoint(_ e: Vol.Evenement) throws -> Int64 {
        let lieu = Vol.lieuSous(Vol.Point(instant: e.instant, latitude: e.latitude, longitude: e.longitude))
        let jour = try #require(Fuseau(lieu.fuseau)).jour(millis: e.instant)
        let instants = (-1...1).flatMap { Zmanim.jour(lieu: lieu, date: jour.plus(jours: $0)) }
            .filter { $0.cle == e.cle }.compactMap { $0.instant.map(Vol.millis) }
        return try #require(instants.map { abs($0 - e.instant) }.min())
    }
}

/// VolTest d'Android, porté : le calcul (le point fixe, les fuseaux, minuit, la ligne de date, les routes
/// polaires) ; aucune règle halakhique n'y est validée (ZMANIM.md, « En vol »). Les 26 vols de
/// web/test/vecteurs_vol.json (tools/vecteurs_vol), copiés par l'export, à une seconde.
@Suite("Vol")
struct VolTests {

    private func a(_ iata: String) throws -> Vol.Aeroport { try Trajets.a(iata) }
    private func plan(_ de: String, _ vers: String, _ d: String, _ v: String) throws -> Vol.Plan { try Trajets.plan(de, vers, d, v) }
    private func calcul(_ p: Vol.Plan) -> Vol.Calcul { Trajets.calcul(p) }
    private func instant(_ iso: String) throws -> Int64 { try #require(InstantISO.lire(iso), "\(iso)") }

    private let heure: Int64 = 3_600_000
    private let minute: Int64 = 60_000

    // Tel Aviv → New York, vers l'ouest, de jour ; New York → Tel Aviv, vers l'est, de nuit.
    private func versOuest() throws -> Vol.Plan { try plan("TLV", "JFK", "2026-11-10T12:30", "2026-11-10T17:45") }
    private func versEst() throws -> Vol.Plan { try plan("JFK", "TLV", "2026-11-10T23:00", "2026-11-11T16:40") }

    @Test func lesAeroportsSontCompletsEtLeursFuseauxConnus() throws {
        let tous = try Trajets.aeroports.get()
        #expect(tous.count > 3000)
        let codes = Set(tous.map(\.iata))
        #expect(codes.count == tous.count)
        let forme = ExpressionReguliere("[A-Z0-9]{3}")
        let fautifs = tous.filter { !forme.couvre($0.iata) || abs($0.latitude) > 90 || abs($0.longitude) > 180 || Vol.zone($0.fuseau) == nil }
        let nomsFautifs = fautifs.map(\.iata)
        #expect(nomsFautifs.isEmpty, "\(nomsFautifs)")
        #expect(try a("TLV").fuseau == "Asia/Jerusalem")
        #expect(try a("CDG").fuseau == "Europe/Paris")
        // À cheval sur la frontière, à l'heure de son aérogare (tools/aeroports_construction.py).
        #expect(try a("OOL").fuseau == "Australia/Brisbane")
        // Fuseau disputé : non proposé.
        #expect(Aeroports.parIata(tous, "URC") == nil)
    }

    @Test func laRechercheTrouveLeCodeLaVilleSansAccentsLeNom() throws {
        let tous = try Trajets.aeroports.get()
        func codes(_ q: String) -> [String] { Aeroports.chercher(tous, q).map(\.iata) }
        #expect(codes("tlv").first == "TLV")
        #expect(codes("zurich").contains("ZRH"))
        #expect(codes("Ben Gurion").contains("TLV"))
        #expect(codes("  ").isEmpty)
        // Wikidata : hébreu (avec ou sans tiret) et français.
        #expect(codes("תל אביב").contains("TLV"))
        #expect(codes("תל-אביב").contains("TLV"))
        #expect(codes("בן גוריון").contains("TLV"))
        #expect(codes("מלבורן").contains("MEL"))
        #expect(codes("Londres").contains("LHR"))
        #expect(Aeroports.nomLocal(try a("TLV"), "he") == "נמל התעופה בן-גוריון")
        #expect(Aeroports.nomLocal(try a("TLV"), "en") == (try a("TLV")).nom)
    }

    @Test func lesHeuresDuBilletSeLisentALHeureDeChaqueAeroport() throws {
        #expect(Vol.instant(Trajets.locale("2026-07-01T10:00"), try a("CDG")) == (try instant("2026-07-01T08:00:00Z")))
        #expect(Vol.instant(Trajets.locale("2026-01-01T10:00"), try a("JFK")) == (try instant("2026-01-01T15:00:00Z")))
        #expect(Vol.instant(Trajets.locale("2026-01-01T10:00"), try a("JFK").avec(fuseau: "Mars/Olympus")) == nil)
    }

    @Test func uneSaisieImpossibleEstRefusee() throws {
        let p = try versOuest()
        #expect(Vol.verifier(p) == nil)
        var x = p
        x.arrivee = p.depart
        #expect(Vol.verifier(x) == .memeAeroport)
        x = p
        x.atterrissage = p.decollage
        #expect(Vol.verifier(x) == .arriveeAvantDepart)
        x = p
        x.atterrissage = p.decollage + 23 * heure
        #expect(Vol.verifier(x) == .tropLong)
        x = p
        x.arrivee = try a("JFK").avec(fuseau: "Mars/Olympus")
        #expect(Vol.verifier(x) == .fuseauInconnu)
    }

    @Test func laRouteVaDUnAeroportALAutreParLeGrandCercle() throws {
        let p = try versOuest(), tlv = try a("TLV"), jfk = try a("JFK")
        let debut = Vol.position(p, p.decollage - 3 * heure)
        #expect(abs(debut.latitude - tlv.latitude) <= 1e-9 && abs(debut.longitude - tlv.longitude) <= 1e-9)
        let fin = Vol.position(p, p.atterrissage + 3 * heure)
        #expect(abs(fin.latitude - jfk.latitude) <= 1e-6 && abs(fin.longitude - jfk.longitude) <= 1e-6)
        let milieu = Vol.position(p, p.decollage + (p.atterrissage - p.decollage) / 2)
        let total = Vol.distanceKm(p)
        #expect(abs(total / 2 - Vol.distanceKm(tlv.latitude, tlv.longitude, milieu.latitude, milieu.longitude)) <= 1.0)
        // Le grand cercle de Tel Aviv à New York passe bien au nord des deux villes.
        #expect(milieu.latitude > 50)
    }

    @Test func leFuseauNautiqueSuitLaLongitudeEtSonSigneInverse() {
        #expect(Vol.fuseauNautique(35.0) == "Etc/GMT-2")
        #expect(Vol.fuseauNautique(-74.0) == "Etc/GMT+5")
        #expect(Vol.fuseauNautique(3.0) == "Etc/GMT")
        #expect(Vol.fuseauNautique(179.9) == "Etc/GMT-12")
        #expect(Vol.fuseauNautique(-179.9) == "Etc/GMT+12")
        for l in [35.0, -74.0, 3.0, 179.9, -179.9] { #expect(Fuseau(Vol.fuseauNautique(l)) != nil, "\(l)") }
    }

    /// Au sol, avant le décollage : exactement les zmanim du moteur à l'aéroport, à la seconde.
    @Test func auSolLeCalculRendLesZmanimDuMoteur() throws {
        let c = calcul(try versOuest())
        for cle in ["alot", "netz", "szt_gra"] {
            let attendu = try Trajets.sol("TLV", "2026-11-10", cle)
            let trouve = try #require(c.evenements.first { $0.cle == cle && abs($0.instant - attendu) < heure })
            #expect(abs(trouve.instant - attendu) <= 1000, "\(cle) : \(trouve.instant) contre \(attendu)")
        }
    }

    /// Chaque zman trouvé en vol est le zman du point où est l'avion à cet instant (le point fixe).
    @Test func chaqueZmanEnVolEstLeZmanDuPointSousLAvion() throws {
        for p in [try versOuest(), try versEst()] {
            let c = calcul(p)
            #expect(!c.enVol.isEmpty)
            for e in c.enVol {
                let ecart = try Trajets.ecartAuPoint(e)
                #expect(ecart <= 2000, "\(e.cle) à \(e.instant) : écart \(ecart) ms")
            }
        }
    }

    /// Vers l'ouest, on suit le soleil : le jour en vol dure plus qu'au sol ; vers l'est, la nuit raccourcit.
    @Test func versLOuestLeJourSAllongeVersLEstLaNuitRaccourcit() throws {
        let ouest = calcul(try versOuest())
        let chkiaVol = try #require(ouest.enVol.first { $0.cle == "chkia" }).instant
        let jourVol = chkiaVol - (try Trajets.sol("TLV", "2026-11-10", "netz"))
        for x in ["TLV", "JFK"] {
            let jourSol = (try Trajets.sol(x, "2026-11-10", "chkia")) - (try Trajets.sol(x, "2026-11-10", "netz"))
            #expect(jourVol > jourSol + 15 * minute, "\(x) : \(jourVol) contre \(jourSol)")
        }
        let est = calcul(try versEst())
        let netzVol = try #require(est.enVol.first { $0.cle == "netz" }).instant
        let nuitVol = netzVol - (try Trajets.sol("JFK", "2026-11-10", "chkia"))
        for x in ["TLV", "JFK"] {
            let nuitSol = (try Trajets.sol(x, "2026-11-11", "netz")) - (try Trajets.sol(x, "2026-11-10", "chkia"))
            #expect(nuitVol < nuitSol - 2 * heure, "\(x) : \(nuitVol) contre \(nuitSol)")
        }
        // Sans doublon : un même zman ne revient pas en vol à moins de 12 h, sauf à rebours.
        for c in [ouest, est] {
            #expect(!c.reserves.contains(.aRebours))
            let parCle = Dictionary(grouping: c.enVol, by: \.cle)
            for (cle, l) in parCle {
                for (x, y) in zip(l, l.dropFirst()) { #expect(y.instant - x.instant > 12 * heure, "\(cle)") }
            }
        }
    }

    @Test func minuitUTCEtMinuitLocalTraversesSansPerte() throws {
        // Tel Aviv 22:30 → Paris 02:00 : minuit local au départ, minuit UTC (22:00 Z) avant.
        let c = calcul(try plan("TLV", "CDG", "2026-11-10T22:30", "2026-11-11T02:00"))
        let minuits = c.enVol.filter { $0.cle == "chatsot_layla" }
        #expect(minuits.count == 1)
        let ordonne = zip(c.evenements, c.evenements.dropFirst()).allSatisfy { $0.instant <= $1.instant }
        #expect(ordonne)
        // Avant minuit de la nuit : Arvit jusqu'à minuit ; après, Arvit sans limite.
        let minuit = try #require(c.enVol.first { $0.cle == "chatsot_layla" }).instant
        let avant = try #require(VolPriere.priere(c, minuit - 10 * minute))
        #expect(avant.priere == "arvit" && avant.limite == minuit)
        let apres = try #require(VolPriere.priere(c, minuit + 10 * minute))
        #expect(apres.priere == "arvit" && apres.limite == nil)
    }

    @Test func laPriereDuMomentSuitLesZmanimDeLaRouteParZmanimWidget() throws {
        let p = try versOuest()
        let c = calcul(p)
        let chkia = try #require(c.enVol.first { $0.cle == "chkia" }).instant
        let minha = try #require(VolPriere.priere(c, chkia - 5 * minute))
        #expect(minha.priere == "minha" && minha.limite == chkia)
        let arvit = try #require(VolPriere.priere(c, chkia + 5 * minute))
        #expect(arvit.priere == "arvit")
        let minuit = c.evenements.first { $0.cle == "chatsot_layla" && $0.instant > chkia }?.instant
        #expect(arvit.limite == minuit)
        // Loin du vol, la fenêtre ne couvre plus : rien plutôt qu'une heure fausse.
        #expect(VolPriere.priere(c, p.atterrissage + 7 * heure) == nil)
        #expect(VolPriere.priere(c, p.decollage - 7 * heure) == nil)
    }

    @Test func unVolCourtSansZmanResteCalculable() throws {
        let court = try plan("TLV", "ETM", "2026-11-10T09:50", "2026-11-10T10:40")
        let c = calcul(court)
        #expect(c.enVol.isEmpty)
        #expect(VolPriere.priere(c, court.decollage + 20 * minute)?.priere == "minha")
        #expect(c.reserves.isEmpty)
        #expect(c.lignesDate.isEmpty)
    }

    @Test func chaqueHoraireEnVolDitDeCombienIlBougeSiLeVolPart30MinutesPlusTard() throws {
        for e in calcul(try versEst()).enVol {
            let ecart = try #require(e.ecartSiRetard, "\(e.cle) sans correspondant")
            #expect(abs(ecart) <= 45 * minute, "\(e.cle) : \(ecart)")
        }
    }

    @Test func laLigneDeDateEstDateeDePartEtDAutreVersLOuestEtVersLEst() throws {
        let ouest = calcul(try plan("SFO", "HKG", "2026-11-10T11:00", "2026-11-11T19:00"))
        #expect(ouest.lignesDate.count == 1)
        if let l = ouest.lignesDate.first { #expect(l.avant.plus(jours: 1) == l.apres) }
        let est = calcul(try plan("HKG", "SFO", "2026-11-10T21:00", "2026-11-10T18:00"))
        #expect(est.lignesDate.count == 1)
        if let l = est.lignesDate.first { #expect(l.avant.plus(jours: -1) == l.apres) }
        // La ligne passe entre le décollage et l'atterrissage.
        for c in [ouest, est] {
            let t = try #require(c.lignesDate.first).instant
            #expect(t > c.plan.decollage && t < c.plan.atterrissage)
        }
        #expect(calcul(try versOuest()).lignesDate.isEmpty)
    }

    @Test func uneRoutePolaireEnEteSignaleLaHauteLatitudeEtLesZmanimAbsents() throws {
        // New York → Hong Kong en juin : le grand cercle passe près du pôle, l'aube à 16,1° n'y a pas lieu.
        let c = calcul(try plan("JFK", "HKG", "2026-06-20T11:00", "2026-06-21T15:00"))
        #expect(c.reserves.contains(.hauteLatitude))
        #expect(c.reserves.contains(.absent))
        #expect(!c.reserves.contains(.erreur))
        let ordonne = zip(c.enVol, c.enVol.dropFirst()).allSatisfy { $0.instant <= $1.instant }
        #expect(ordonne)
    }

    /// web/test/vecteurs_vol.json (tools/vecteurs_vol) : ce que Vol.kt répond, à une seconde.
    @Test func lesVecteursDuWebSontCeuxDeVol() throws {
        let texte = String(decoding: try Depot.donnees("ios/Paquets/Coeur/Tests/Ressources/vecteurs_vol.json"), as: UTF8.self)
        let vols = try ObjetJSON(texte: texte).tableau("vols") ?? []
        #expect(vols.count >= 6)
        for case .objet(let v) in vols {
            var p = try plan(v.texte("depart"), v.texte("arrivee"), v.texte("decollage"), v.texte("atterrissage"))
            if let r = v.objet("releve") {
                p.releve = Vol.Point(instant: try instant(r.texte("instant")), latitude: r.double("latitude"), longitude: r.double("longitude"))
            }
            let c = calcul(p)
            let nom = "\(v.texte("depart"))-\(v.texte("arrivee"))"
            #expect(c.fiabilite.rawValue == v.texte("fiabilite"), "\(nom)")
            let attendus = v.tableau("enVol") ?? []
            let cles = c.enVol.map(\.cle)
            #expect(attendus.count == cles.count, "\(nom) : \(cles)")
            for (j, e) in c.enVol.enumerated() where j < attendus.count {
                let x = try #require(attendus.objet(j))
                #expect(x.texte("cle") == e.cle, "\(nom)")
                #expect(abs((try instant(x.texte("instant"))) - e.instant) <= 1000, "\(nom) \(e.cle)")
            }
            let reserves = (v.tableau("reserves") ?? []).indices.map { (v.tableau("reserves") ?? []).texte($0) }
            let rendues = c.reserves.map(\.rawValue).sorted()
            #expect(reserves == rendues, "\(nom)")
            #expect((v.tableau("lignesDate") ?? []).count == c.lignesDate.count, "\(nom)")
            let jalons = VolCalendrier.jalons(c, enIsrael: false, minutes: 18)
            let attendusJ = v.tableau("jalons") ?? []
            #expect(attendusJ.count == jalons.count, "\(nom)")
            for (j, x) in jalons.enumerated() where j < attendusJ.count {
                let y = try #require(attendusJ.objet(j))
                #expect(y.texte("type") == x.type.rawValue && y.texte("date") == x.date.iso && y.entier("omer") == x.omer, "\(nom)")
            }
        }
    }

    /// Les heures du billet en été et en hiver (règles officielles : ZMANIM.md, « En vol »).
    @Test func heuresDEteEtDHiverDAustralieDIndonesieDesEtatsUnisDArgentine() throws {
        func decalage(_ iata: String, _ local: String) throws -> Double {
            let l = Trajets.locale(local)
            let utc = Int64(l.jour.jourJulien - 2_440_588) * 86_400_000 + Int64(l.millisDuJour)
            return Double((utc - (try #require(Vol.instant(l, try a(iata))))) / 60_000) / 60
        }
        let attendus: [(String, Double, Double)] = [
            ("MEL", 11, 10), ("SYD", 11, 10), ("BNE", 10, 10), ("ADL", 10.5, 9.5), ("DRW", 9.5, 9.5),
            ("PER", 8, 8), ("CGK", 7, 7), ("DPS", 8, 8), ("DJJ", 9, 9), ("LAX", -8, -7),
            ("JFK", -5, -4), ("PHX", -7, -7), ("HNL", -10, -10), ("YUL", -5, -4),
            ("EZE", -3, -3), ("ZQN", 13, 12), ("TLV", 2, 3),
        ]
        for (iata, hiver, ete) in attendus {
            #expect(try decalage(iata, "2026-12-15T12:00") == hiver, "\(iata) décembre")
            #expect(try decalage(iata, "2026-07-15T12:00") == ete, "\(iata) juillet")
        }
    }

    /// Melbourne → Los Angeles → Montréal et retour ; Sydney → Queenstown ; Tel Aviv → Buenos Aires.
    @Test func lesTrajetsDuPacifiqueEtDeLAtlantiqueSud() throws {
        let aller = calcul(try plan("MEL", "LAX", "2026-12-15T10:30", "2026-12-15T06:45"))
        #expect(aller.plan.atterrissage - aller.plan.decollage == (15 * 60 + 15) * minute)
        let la = try #require(aller.lignesDate.first)
        #expect(aller.lignesDate.count == 1 && la.avant.plus(jours: -1) == la.apres)
        let retour = calcul(try plan("LAX", "MEL", "2026-12-22T22:30", "2026-12-24T08:45"))
        let lr = try #require(retour.lignesDate.first)
        #expect(retour.lignesDate.count == 1 && lr.avant.plus(jours: 1) == lr.apres)
        // L'escale : le vol suivant part de Los Angeles, dont il rend les zmanim au sol.
        let suite = calcul(try plan("LAX", "YUL", "2026-12-15T09:30", "2026-12-15T17:55"))
        let netz = try Trajets.sol("LAX", "2026-12-15", "netz")
        let auSol = suite.evenements.contains { $0.cle == "netz" && abs($0.instant - netz) <= 1000 }
        #expect(auSol)
        #expect(calcul(try plan("SYD", "ZQN", "2026-12-18T09:00", "2026-12-18T14:15")).lignesDate.isEmpty)
        let sud = calcul(try plan("TLV", "EZE", "2026-11-10T23:00", "2026-11-11T09:20"))
        #expect(sud.lignesDate.isEmpty)
        let nord = sud.enVol.contains { $0.latitude > 0 }, australe = sud.enVol.contains { $0.latitude < 0 }
        #expect(nord && australe)
        for c in [aller, retour, suite, sud] { #expect(c.reserves.isEmpty, "\(c.plan.depart.iata)-\(c.plan.arrivee.iata)") }
    }

    @Test func chabbatFetesEtOmerEnVolSuiventLeCalendrier() throws {
        func premier(_ depuis: String, _ ok: (JourCivil) -> Bool) -> JourCivil {
            var d = JourCivil.du(depuis)
            while !ok(d) { d = d.plus(jours: 1) }
            return d
        }
        let vendredi = premier("2026-11-01") { $0.jourDeSemaine == 6 }
        let entrees = VolCalendrier.jalons(calcul(try plan("TLV", "JFK", "\(vendredi.iso)T12:30", "\(vendredi.iso)T17:45")), enIsrael: false, minutes: 18)
        try #require(entrees.count == 1)
        let entree = entrees[0]
        #expect(entree.type == .entree)
        #expect(entree.chabbat)
        #expect(entree.date == vendredi.plus(jours: 1))
        #expect(entree.instant - (entree.allumage ?? 0) == 18 * minute)
        let samedi = vendredi.plus(jours: 1)
        let sorties = VolCalendrier.jalons(calcul(try plan("TLV", "JFK", "\(samedi.iso)T12:30", "\(samedi.iso)T17:45")), enIsrael: false, minutes: 18)
        #expect(sorties.count == 1 && sorties.first?.type == .sortie)
        // Le Omer : le jour compté ce soir est celui du lendemain hébreu.
        let omer = premier("2027-01-01") { CalendrierJuif.jour($0.plus(jours: 1), enIsrael: false).omer == 4 }
        let j = VolCalendrier.jalons(calcul(try plan("TLV", "JFK", "\(omer.iso)T17:00", "\(omer.iso)T22:15")), enIsrael: false, minutes: 18)
        let rendus = j.map { "\($0.type.rawValue):\($0.omer)" }
        #expect(rendus == ["omer:4"])
        // Un vol sans chki'a ni tsét n'a aucun jalon.
        #expect(VolCalendrier.jalons(calcul(try plan("TLV", "ETM", "\(vendredi.iso)T09:50", "\(vendredi.iso)T10:40")), enIsrael: false, minutes: 18).isEmpty)
    }

    @Test func unReleveGPSEnVolRecaleLaRouteHorsDuVolIlEstIgnore() throws {
        let base = try versOuest()
        let releve = Vol.Point(instant: try instant("2026-11-10T18:30:00Z"), latitude: 56.0, longitude: -30.0)
        var avec = base
        avec.releve = releve
        let p = Vol.position(avec, releve.instant)
        #expect(abs(p.latitude - 56) <= 1e-6 && abs(p.longitude + 30) <= 1e-6)
        let c = calcul(avec)
        #expect(c.fiabilite == .releveGps)
        let sans = calcul(base)
        #expect(sans.fiabilite == .routePrevue)
        let recalee = c.enVol.first { $0.cle == "chkia" }?.instant, prevue = sans.enVol.first { $0.cle == "chkia" }?.instant
        #expect(recalee != prevue)
        // Le point fixe tient aussi sur la route recalée.
        for e in c.enVol {
            let ecart = try Trajets.ecartAuPoint(e)
            #expect(ecart <= 2000, "\(e.cle) : \(ecart) ms")
        }
        var dehors = base
        dehors.releve = Vol.Point(instant: base.atterrissage + heure, latitude: 56, longitude: -30)
        let d = calcul(dehors)
        #expect(d.fiabilite == .routePrevue)
        let a1 = d.enVol.map(\.instant), a2 = sans.enVol.map(\.instant)
        #expect(a1 == a2)
    }

    @Test func suiviEnDirectIndicatifsReponseDuRelaisAdresseFiabilite() throws {
        #expect(SuiviVol.normaliser("ely 001") == "ELY001")
        #expect(SuiviVol.normaliser("LY001") == nil)
        #expect(SuiviVol.memeIndicatif("ELY001", "ELY1"))
        #expect(!SuiviVol.memeIndicatif("ELY1", "ELY11"))
        let maintenant = try instant("2026-11-10T18:35:00Z")
        let ok = SuiviVol.lire(#"{"trouve":true,"latitude":50.5,"longitude":-21.2,"altitude_geo":11200,"instant":"2026-11-10T18:30:00Z"}"#, maintenant: maintenant)
        #expect(ok == .trouve(Vol.Point(instant: try instant("2026-11-10T18:30:00Z"), latitude: 50.5, longitude: -21.2), altitudeMetres: 11200))
        #expect(SuiviVol.lire(#"{"trouve":true,"latitude":50,"longitude":-21,"instant":"2026-11-10T18:00:00Z"}"#, maintenant: maintenant) == .introuvable)
        #expect(SuiviVol.lire(#"{"trouve":false}"#, maintenant: maintenant) == .introuvable)
        var erreur = false
        if case .erreur = SuiviVol.lire(#"{"erreur":"x"}"#, maintenant: maintenant) { erreur = true }
        #expect(erreur)
        erreur = false
        if case .erreur = SuiviVol.lire("pas du json", maintenant: maintenant) { erreur = true }
        #expect(erreur)
        #expect(SuiviVol.adresse("https://r.test/", "ELY1", Vol.Point(instant: maintenant, latitude: 50.123, longitude: -20.36))
                == "https://r.test/position?indicatif=ELY1&lat=50.1&lon=-20.4")
        // Sans relais en HTTPS, aucune connexion.
        let zero = Vol.Point(instant: maintenant, latitude: 0, longitude: 0)
        #expect(SuiviVol.Relais("").position("ELY1", zero) == .erreur(SuiviVol.Raison.relaisAbsent))
        #expect(SuiviVol.Relais("http://r.test").position("ELY1", zero) == .erreur(SuiviVol.Raison.relaisAbsent))
        // Le fournisseur est interchangeable ; sa position recale la route comme un relevé.
        struct Faux: SuiviVol.FournisseurPosition {
            let point: Vol.Point
            func position(_ indicatif: String, _ estime: Vol.Point) -> SuiviVol.Resultat { .trouve(point, altitudeMetres: nil) }
        }
        let p = try versOuest()
        let r = Faux(point: Vol.Point(instant: try instant("2026-11-10T18:30:00Z"), latitude: 56, longitude: -30))
            .position("ELY1", Vol.position(p, maintenant))
        guard case .trouve(let point, _) = r else {
            Issue.record("introuvable")
            return
        }
        var direct = p
        direct.releve = point
        direct.sourceReleve = .direct
        #expect(calcul(direct).fiabilite == .releveDirect)
    }
}
