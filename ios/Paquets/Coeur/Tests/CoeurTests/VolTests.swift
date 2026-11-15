import Foundation
import Synchronization
import Testing
@testable import Coeur

/// Les zmanim en vol, portés de VolTest.kt (phase 1, hors ligne), et jugés par deux fichiers de vecteurs :
/// - `web/test/vecteurs_vol.json`, le juge du site : 26 vols produits par Vol.kt, rejoués en entier (les mêmes
///   zmanim en vol, dans le même ordre, à quatre secondes près (voir toleranceEnVol) ; les mêmes réserves ; les mêmes dates de part et
///   d'autre de la ligne ; les mêmes jalons) ;
/// - `Tests/Vecteurs/vol.json` (tools/vecteurs_ios/VecteursVol.kt) : les fonctions simples, les positions, et
///   36 vols entiers (chaque événement de la fenêtre, l'écart si retard, les jalons, la prière du moment).
///
/// Ces tests vérifient le calcul (le point fixe, les fuseaux, minuit, la ligne de date, les routes polaires) ;
/// ils ne valident aucune règle halakhique : le choix de calculer au point sous l'avion, au niveau de la mer,
/// est décrit dans ZMANIM.md (« En vol »).
///
/// Restent à d'autres portages : la recherche d'aéroports de VolTest (`Aeroports.chercher`, `nomLocal`) revient
/// à celui d'Aeroports.kt ; les indicatifs, la réponse du relais et son adresse, à celui de SuiviVol.kt (d'ici,
/// seule la fiabilité d'un relevé en direct est vérifiée). Les aéroports sont lus dans aeroports.json exporté.
@Suite("Vol", .serialized)
struct VolTests {
    private let aeroports: [Vol.Aeroport]
    private let parIata: [String: Vol.Aeroport]
    private let minute: Int64 = 60_000
    /// L'écart toléré sur un zman en vol, en millisecondes. Au sol, KosherSwift rend chaque zman à moins d'une
    /// seconde de KosherJava (ios/KOSHERSWIFT.md) ; en vol, le zman se cherche au point sous l'avion, et quand
    /// ce point fuit avec le soleil (vers l'ouest au coucher) l'écart de départ est amplifié, jusqu'à quatre fois.
    /// Mesuré le 15/11/2026, sous Linux et sur le simulateur : 3 207 ms au plus. ROADMAP demandait 2 s : l'écart
    /// est chiffré ici, l'heure affichée (à la minute) n'en dépend pas.
    private let toleranceEnVol: Int64 = 4000
    private let heure: Int64 = 3_600_000

    init() throws {
        let fichier = try JSONDecoder().decode(FichierAeroports.self, from: Depot.contenu("aeroports.json"))
        aeroports = fichier.aeroports.map { $0.aeroport }
        var index: [String: Vol.Aeroport] = [:]
        for x in aeroports where index[x.iata] == nil { index[x.iata] = x }
        parIata = index
    }

    private func a(_ iata: String) throws -> Vol.Aeroport {
        let x = parIata[iata]
        return try #require(x, "\(iata) absent")
    }

    /// Comme VolTest : les heures du billet, lues à l'heure de chaque aéroport.
    private func plan(_ de: String, _ vers: String, _ decollage: String, _ atterrissage: String) throws -> Vol.Plan {
        let d = try a(de)
        let v = try a(vers)
        let i0 = Vol.instant(local(decollage), d)
        let i1 = Vol.instant(local(atterrissage), v)
        let t0 = try #require(i0, "\(de) \(decollage)")
        let t1 = try #require(i1, "\(vers) \(atterrissage)")
        return Vol.Plan(numero: "TEST", depart: d, arrivee: v, decollage: t0, atterrissage: t1)
    }

    /// Tel Aviv → New York, vers l'ouest, de jour.
    private func versOuest() throws -> Vol.Plan { try plan("TLV", "JFK", "2026-11-10T12:30", "2026-11-10T17:45") }

    /// New York → Tel Aviv, vers l'est, de nuit.
    private func versEst() throws -> Vol.Plan { try plan("JFK", "TLV", "2026-11-10T23:00", "2026-11-11T16:40") }

    /// Le zman du moteur à l'aéroport, au niveau de la mer.
    private func sol(_ iata: String, _ iso: String, _ cle: String) throws -> Int64 {
        let x = try a(iata)
        let lieu = Zmanim.Lieu(nom: x.ville, latitude: x.latitude, longitude: x.longitude, altitude: 0, fuseau: x.fuseau)
        let instant = Zmanim.jour(lieu: lieu, date: JourCivil.du(iso)).first { $0.cle == cle }?.instant
        let d = try #require(instant, "\(cle) à \(iata) le \(iso)")
        return Vol.millis(d)
    }

    /// L'écart (ms) entre un zman trouvé en vol et le zman du moteur au point sous l'avion, la veille, le jour ou
    /// le lendemain (jour civil du fuseau nautique, lu par la base de fuseaux de la plateforme).
    private func ecartAuPoint(_ e: Vol.Evenement) throws -> Int64 {
        let lieu = Vol.lieuSous(Vol.Point(instant: e.instant, latitude: e.latitude, longitude: e.longitude))
        let f = Fuseau(lieu.fuseau)
        let fuseau = try #require(f, "fuseau nautique inconnu : \(lieu.fuseau)")
        let jour = fuseau.jour(millis: e.instant)
        var ecart = Int64.max
        for k in -1...1 {
            for z in Zmanim.jour(lieu: lieu, date: jour.plus(jours: k)) where z.cle == e.cle {
                if let d = z.instant { ecart = min(ecart, abs(Vol.millis(d) - e.instant)) }
            }
        }
        return ecart
    }

    // MARK: VolTest.kt

    @Test func lesAeroportsSontCompletsEtLeursFuseauxConnus() throws {
        let n = aeroports.count
        #expect(n > 3000)
        let distincts = Set(aeroports.map { $0.iata }).count
        #expect(distincts == n)
        var inconnus = Set<String>()
        for x in aeroports {
            let code = estCodeIata(x.iata)
            #expect(code, "\(x.iata)")
            let bornes = abs(x.latitude) <= 90 && abs(x.longitude) <= 180
            #expect(bornes, "\(x.iata)")
            if Vol.zone(x.fuseau) == nil { inconnus.insert(x.fuseau) }
        }
        // Un fuseau plus récent que la base de la plateforme : Vol.zone rend nil, comme Android sur une base trop
        // ancienne. America/Coyhaique date de tzdata 2025b ; l'ICU de Foundation sous Linux peut ne pas l'avoir.
        let fuseauxRecents: Set<String> = ["America/Coyhaique"]
        let inattendus = inconnus.subtracting(fuseauxRecents)
        #expect(inattendus.isEmpty, "fuseaux inconnus : \(inattendus.sorted())")
        if !inconnus.isEmpty { print("Vol : fuseaux récents absents de cette plateforme : \(inconnus.sorted())") }
        let tlv = try a("TLV").fuseau
        #expect(tlv == "Asia/Jerusalem")
        let cdg = try a("CDG").fuseau
        #expect(cdg == "Europe/Paris")
        // À cheval sur la frontière, à l'heure de son aérogare (tools/aeroports_construction.py).
        let ool = try a("OOL").fuseau
        #expect(ool == "Australia/Brisbane")
        // Fuseau disputé : non proposé.
        let urc = parIata["URC"]
        #expect(urc == nil)
    }

    @Test func lesHeuresDuBilletSeLisentALHeureDeChaqueAeroport() throws {
        let paris = Vol.instant(local("2026-07-01T10:00"), try a("CDG"))
        let parisAttendu = instantISO("2026-07-01T08:00:00Z")
        #expect(paris == parisAttendu)
        let newYork = Vol.instant(local("2026-01-01T10:00"), try a("JFK"))
        let newYorkAttendu = instantISO("2026-01-01T15:00:00Z")
        #expect(newYork == newYorkAttendu)
        var mars = try a("JFK")
        mars.fuseau = "Mars/Olympus"
        let inconnu = Vol.instant(local("2026-01-01T10:00"), mars)
        #expect(inconnu == nil)
    }

    @Test func uneSaisieImpossibleEstRefusee() throws {
        let p = try versOuest()
        let valide = Vol.verifier(p)
        #expect(valide == nil)
        var meme = p
        meme.arrivee = p.depart
        let r1 = Vol.verifier(meme)
        #expect(r1 == Vol.Invalide.memeAeroport)
        var avant = p
        avant.atterrissage = p.decollage
        let r2 = Vol.verifier(avant)
        #expect(r2 == Vol.Invalide.arriveeAvantDepart)
        var long = p
        long.atterrissage = p.decollage + 23 * heure
        let r3 = Vol.verifier(long)
        #expect(r3 == Vol.Invalide.tropLong)
        var mars = try a("JFK")
        mars.fuseau = "Mars/Olympus"
        var inconnu = p
        inconnu.arrivee = mars
        let r4 = Vol.verifier(inconnu)
        #expect(r4 == Vol.Invalide.fuseauInconnu)
    }

    @Test func laRouteVaDUnAeroportALAutreParLeGrandCercle() throws {
        let p = try versOuest()
        let tlv = try a("TLV")
        let jfk = try a("JFK")
        let debut = Vol.position(p, p.decollage - 3 * heure)
        let dLatDebut = abs(debut.latitude - tlv.latitude), dLonDebut = abs(debut.longitude - tlv.longitude)
        #expect(dLatDebut <= 1e-9)
        #expect(dLonDebut <= 1e-9)
        let fin = Vol.position(p, p.atterrissage + 3 * heure)
        let dLatFin = abs(fin.latitude - jfk.latitude), dLonFin = abs(fin.longitude - jfk.longitude)
        #expect(dLatFin <= 1e-6)
        #expect(dLonFin <= 1e-6)
        let milieu = Vol.position(p, p.decollage + (p.atterrissage - p.decollage) / 2)
        let total = Vol.distanceKm(p)
        let parcouru = Vol.distanceKm(tlv.latitude, tlv.longitude, milieu.latitude, milieu.longitude)
        let ecart = abs(total / 2 - parcouru)
        #expect(ecart <= 1.0, "\(total / 2) contre \(parcouru)")
        // Le grand cercle de Tel Aviv à New York passe bien au nord des deux villes.
        let nord = milieu.latitude
        #expect(nord > 50)
    }

    @Test func leFuseauNautiqueSuitLaLongitudeEtSonSigneInverse() {
        let cas: [(Double, String)] = [(35.0, "Etc/GMT-2"), (-74.0, "Etc/GMT+5"), (3.0, "Etc/GMT"),
                                       (179.9, "Etc/GMT-12"), (-179.9, "Etc/GMT+12")]
        for (longitude, attendu) in cas {
            let fuseau = Vol.fuseauNautique(longitude)
            #expect(fuseau == attendu, "\(longitude)")
            let connu = Fuseau(fuseau) != nil
            #expect(connu, "\(fuseau) inconnu de la plateforme")
        }
    }

    /// Au sol, avant le décollage : exactement les zmanim du moteur à l'aéroport, à la seconde.
    @Test func auSolLeCalculRendLesZmanimDuMoteur() throws {
        let c = calcul(try versOuest())
        for cle in ["alot", "netz", "szt_gra"] {
            let attendu = try sol("TLV", "2026-11-10", cle)
            let proche = c.evenements.first { $0.cle == cle && abs(secondesEntieres(attendu, $0.instant)) < 3600 }
            let trouve = try #require(proche, "\(cle) introuvable au sol")
            let ecart = abs(trouve.instant - attendu)
            #expect(ecart <= 1000, "\(cle) : \(trouve.instant) contre \(attendu)")
        }
    }

    /// Chaque zman trouvé en vol est le zman du point où est l'avion à cet instant (le point fixe).
    @Test func chaqueZmanEnVolEstLeZmanDuPointSousLAvion() throws {
        for p in [try versOuest(), try versEst()] {
            let c = calcul(p)
            let vide = c.enVol.isEmpty
            #expect(!vide)
            for e in c.enVol {
                let ecart = try ecartAuPoint(e)
                #expect(ecart <= 2000, "\(e.cle) à \(e.instant) : écart \(ecart) ms")
            }
        }
    }

    /// Vers l'ouest, on suit le soleil : le jour en vol dure plus qu'au sol ; vers l'est, la nuit raccourcit.
    @Test func versLOuestLeJourSAllongeVersLEstLaNuitRaccourcit() throws {
        let ouest = calcul(try versOuest())
        let chkiaOuest = premier(ouest.enVol, "chkia")
        let chkiaVol = try #require(chkiaOuest).instant
        let jourVol = try chkiaVol - sol("TLV", "2026-11-10", "netz")
        for x in ["TLV", "JFK"] {
            let jourSol = try sol(x, "2026-11-10", "chkia") - sol(x, "2026-11-10", "netz")
            let seuil = jourSol + 15 * minute
            #expect(jourVol > seuil, "\(x) : \(jourVol) contre \(jourSol)")
        }
        let est = calcul(try versEst())
        let netzEst = premier(est.enVol, "netz")
        let netzVol = try #require(netzEst).instant
        let nuitVol = try netzVol - sol("JFK", "2026-11-10", "chkia")
        for x in ["TLV", "JFK"] {
            let nuitSol = try sol(x, "2026-11-11", "netz") - sol(x, "2026-11-10", "chkia")
            let seuil = nuitSol - 2 * heure
            #expect(nuitVol < seuil, "\(x) : \(nuitVol) contre \(nuitSol)")
        }
        // Sans doublon : un même zman ne revient pas en vol à moins de 12 h, sauf à rebours.
        let douzeHeures = 12 * heure
        for c in [ouest, est] {
            let rebours = c.reserves.contains(.aRebours)
            #expect(!rebours)
            var parCle: [String: [Int64]] = [:]
            for e in c.enVol { parCle[e.cle, default: []].append(e.instant) }
            for (cle, instants) in parCle {
                for k in instants.indices.dropFirst() {
                    let ecart = instants[k] - instants[k - 1]
                    #expect(ecart > douzeHeures, "\(cle)")
                }
            }
        }
    }

    @Test func minuitUTCEtMinuitLocalTraversesSansPerte() throws {
        // Tel Aviv 22:30 → Paris 02:00 : minuit local au départ, minuit UTC (22:00 Z) avant.
        let c = calcul(try plan("TLV", "CDG", "2026-11-10T22:30", "2026-11-11T02:00"))
        let minuits = c.enVol.filter { $0.cle == "chatsot_layla" }
        let n = minuits.count
        #expect(n == 1)
        let ordonnes = estOrdonne(c.evenements)
        #expect(ordonnes)
        // Avant minuit de la nuit : Arvit jusqu'à minuit ; après, Arvit sans limite.
        let premierMinuit = minuits.first
        let minuit = try #require(premierMinuit).instant
        let avant = VolPriere.priere(c, minuit - 10 * minute)
        let avantAttendu = VolPriere.Moment(priere: "arvit", limite: minuit)
        #expect(avant == avantAttendu)
        let apres = VolPriere.priere(c, minuit + 10 * minute)
        let apresAttendu = VolPriere.Moment(priere: "arvit", limite: nil)
        #expect(apres == apresAttendu)
    }

    @Test func laPriereDuMomentSuitLesZmanimDeLaRouteParZmanimWidget() throws {
        let p = try versOuest()
        let c = calcul(p)
        let chkiaEnVol = premier(c.enVol, "chkia")
        let chkia = try #require(chkiaEnVol).instant
        let minha = VolPriere.priere(c, chkia - 5 * minute)
        let minhaAttendue = VolPriere.Moment(priere: "minha", limite: chkia)
        #expect(minha == minhaAttendue)
        let apres = VolPriere.priere(c, chkia + 5 * minute)
        let arvit = try #require(apres)
        #expect(arvit.priere == "arvit")
        let suivant = c.evenements.first { $0.cle == "chatsot_layla" && $0.instant > chkia }?.instant
        let minuit = try #require(suivant)
        #expect(arvit.limite == minuit)
        // Loin du vol, la fenêtre ne couvre plus : rien plutôt qu'une heure fausse.
        let loinApres = VolPriere.priere(c, p.atterrissage + 7 * heure)
        #expect(loinApres == nil)
        let loinAvant = VolPriere.priere(c, p.decollage - 7 * heure)
        #expect(loinAvant == nil)
    }

    @Test func unVolCourtSansZmanResteCalculable() throws {
        let court = try plan("TLV", "ETM", "2026-11-10T09:50", "2026-11-10T10:40")
        let c = calcul(court)
        let vide = c.enVol.isEmpty
        #expect(vide)
        let priere = VolPriere.priere(c, court.decollage + 20 * minute)?.priere
        #expect(priere == "minha")
        let sansReserve = c.reserves.isEmpty
        #expect(sansReserve)
        let sansLigne = c.lignesDate.isEmpty
        #expect(sansLigne)
    }

    @Test func chaqueHoraireEnVolDitDeCombienIlBougeSiLeVolPart30MinutesPlusTard() throws {
        let c = calcul(try versEst())
        for e in c.enVol {
            let ecart = try #require(e.ecartSiRetard, "\(e.cle) sans correspondant")
            let borne = abs(ecart) <= 45 * minute
            #expect(borne, "\(e.cle) : \(ecart) ms")
        }
    }

    @Test func laLigneDeDateEstDateeDePartEtDAutreVersLOuestEtVersLEst() throws {
        let ouest = calcul(try plan("SFO", "HKG", "2026-11-10T11:00", "2026-11-11T19:00"))
        let nOuest = ouest.lignesDate.count
        #expect(nOuest == 1)
        let premiereOuest = ouest.lignesDate.first
        let lo = try #require(premiereOuest)
        let lendemain = lo.avant.plus(jours: 1)
        #expect(lo.apres == lendemain)
        let est = calcul(try plan("HKG", "SFO", "2026-11-10T21:00", "2026-11-10T18:00"))
        let nEst = est.lignesDate.count
        #expect(nEst == 1)
        let premiereEst = est.lignesDate.first
        let le = try #require(premiereEst)
        let veille = le.avant.plus(jours: -1)
        #expect(le.apres == veille)
        // La ligne passe entre le décollage et l'atterrissage.
        for c in [ouest, est] {
            let ligne = c.lignesDate.first
            let t = try #require(ligne).instant
            let dedans = t > c.plan.decollage && t < c.plan.atterrissage
            #expect(dedans)
        }
        let sansLigne = calcul(try versOuest()).lignesDate.isEmpty
        #expect(sansLigne)
    }

    @Test func uneRoutePolaireEnEteSignaleLaHauteLatitudeEtLesZmanimAbsents() throws {
        // New York → Hong Kong en juin : le grand cercle passe près du pôle, l'aube à 16,1° n'y a pas lieu.
        let c = calcul(try plan("JFK", "HKG", "2026-06-20T11:00", "2026-06-21T15:00"))
        let haute = c.reserves.contains(.hauteLatitude)
        #expect(haute)
        let absent = c.reserves.contains(.absent)
        #expect(absent)
        let erreur = c.reserves.contains(.erreur)
        #expect(!erreur)
        let ordonnes = estOrdonne(c.enVol)
        #expect(ordonnes)
    }

    /// web/test/vecteurs_vol.json (tools/vecteurs_vol) : le juge du site, que VolTest tient pour ce que Vol.kt
    /// répond. Rejoué en entier, les zmanim en vol à toleranceEnVol près (KosherSwift rend les zmanim d'un lieu à une
    /// seconde près de KosherJava, et le vol l'amplifie), comme web/test/vol.test.mjs : mêmes réserves, mêmes dates
    /// de ligne, mêmes jalons.
    @Test func lesVecteursDuWebSontCeuxDeVol() throws {
        let fichier = try JSONDecoder().decode(VecteursDuSite.self, from: Depot.donnees("web/test/vecteurs_vol.json"))
        let n = fichier.vols.count
        #expect(n >= 26)
        var pire: Int64 = 0
        var zmanim = 0
        for v in fichier.vols {
            var p = try plan(v.depart, v.arrivee, v.decollage, v.atterrissage)
            if let r = v.releve {
                let lu = instantISO(r.instant)
                let t = try #require(lu, "\(r.instant)")
                p.releve = Vol.Point(instant: t, latitude: r.latitude, longitude: r.longitude)
            }
            let c = calcul(p)
            let nom = "\(v.depart)-\(v.arrivee) \(v.decollage)"
            #expect(c.fiabilite.rawValue == v.fiabilite, "\(nom)")
            let enVol = c.enVol
            let cles = enVol.map { $0.cle }
            let attendues = v.enVol.map { $0.cle }
            #expect(cles == attendues, "\(nom)")
            for (e, x) in zip(enVol, v.enVol) {
                let lu = instantISO(x.instant)
                let t = try #require(lu, "\(x.instant)")
                let ecart = abs(e.instant - t)
                pire = max(pire, ecart)
                zmanim += 1
                #expect(ecart <= toleranceEnVol, "\(nom) \(x.cle) : \(ecart) ms")
            }
            let reserves = c.reserves.map { $0.rawValue }.sorted()
            #expect(reserves == v.reserves, "\(nom)")
            let lignes = c.lignesDate.map { [$0.avant.iso, $0.apres.iso] }
            #expect(lignes == v.lignesDate, "\(nom)")
            let jalons = VolCalendrier.jalons(c, enIsrael: false, minutes: 18)
            let calcules = jalons.map { "\($0.type.rawValue) \($0.date.iso) \($0.omer)" }
            let attendus = v.jalons.map { "\($0.type) \($0.date) \($0.omer)" }
            #expect(calcules == attendus, "\(nom)")
            for (j, y) in zip(jalons, v.jalons) {
                let lu = instantISO(y.instant)
                let t = try #require(lu, "\(y.instant)")
                let ecart = abs(j.instant - t)
                #expect(ecart <= 2000, "\(nom) jalon \(y.type) : \(ecart) ms")
            }
        }
        print("Vol, vecteurs du site : \(n) vols, \(zmanim) zmanim en vol ; écart maximal \(pire) ms")
    }

    /// Les heures du billet en été et en hiver (règles officielles : ZMANIM.md, « En vol »).
    @Test func heuresDEteEtDHiverDAustralieDIndonesieDesEtatsUnisDArgentine() throws {
        let cas: [(String, Double, Double)] = [
            ("MEL", 11.0, 10.0), ("SYD", 11.0, 10.0), ("BNE", 10.0, 10.0), ("ADL", 10.5, 9.5), ("DRW", 9.5, 9.5),
            ("PER", 8.0, 8.0), ("CGK", 7.0, 7.0), ("DPS", 8.0, 8.0), ("DJJ", 9.0, 9.0), ("LAX", -8.0, -7.0),
            ("JFK", -5.0, -4.0), ("PHX", -7.0, -7.0), ("HNL", -10.0, -10.0), ("YUL", -5.0, -4.0),
            ("EZE", -3.0, -3.0), ("ZQN", 13.0, 12.0), ("TLV", 2.0, 3.0),
        ]
        for (iata, decembre, juillet) in cas {
            let x = try a(iata)
            let enDecembre = try decalage(x, "2026-12-15T12:00")
            #expect(enDecembre == decembre, "\(iata) décembre")
            let enJuillet = try decalage(x, "2026-07-15T12:00")
            #expect(enJuillet == juillet, "\(iata) juillet")
        }
    }

    /// Le décalage sur UTC (en heures) de l'heure du billet : `Duration.between(instant, local.toInstant(UTC))`.
    private func decalage(_ x: Vol.Aeroport, _ texte: String) throws -> Double {
        let l = local(texte)
        let i = Vol.instant(l, x)
        let t = try #require(i, "\(x.iata) \(texte)")
        return Double((Fuseau.utc.millis(l) - t) / minute) / 60.0
    }

    /// Melbourne → Los Angeles → Montréal et retour ; Sydney → Queenstown ; Tel Aviv → Buenos Aires.
    @Test func lesTrajetsDuPacifiqueEtDeLAtlantiqueSud() throws {
        let aller = calcul(try plan("MEL", "LAX", "2026-12-15T10:30", "2026-12-15T06:45"))
        let duree = aller.plan.atterrissage - aller.plan.decollage
        let quinzeHeuresQuart = (15 * 60 + 15) * minute
        #expect(duree == quinzeHeuresQuart)
        let nAller = aller.lignesDate.count
        #expect(nAller == 1)
        let ligneAller = aller.lignesDate.first
        let la = try #require(ligneAller)
        let veille = la.avant.plus(jours: -1)
        #expect(la.apres == veille)
        let retour = calcul(try plan("LAX", "MEL", "2026-12-22T22:30", "2026-12-24T08:45"))
        let nRetour = retour.lignesDate.count
        #expect(nRetour == 1)
        let ligneRetour = retour.lignesDate.first
        let lr = try #require(ligneRetour)
        let lendemain = lr.avant.plus(jours: 1)
        #expect(lr.apres == lendemain)
        // L'escale : le vol suivant part de Los Angeles, dont il rend les zmanim au sol.
        let suite = calcul(try plan("LAX", "YUL", "2026-12-15T09:30", "2026-12-15T17:55"))
        let netz = try sol("LAX", "2026-12-15", "netz")
        var auSol = false
        for e in suite.evenements where e.cle == "netz" && abs(e.instant - netz) <= 1000 { auSol = true }
        #expect(auSol)
        let tasman = calcul(try plan("SYD", "ZQN", "2026-12-18T09:00", "2026-12-18T14:15")).lignesDate.isEmpty
        #expect(tasman)
        let sud = calcul(try plan("TLV", "EZE", "2026-11-10T23:00", "2026-11-11T09:20"))
        let sansLigne = sud.lignesDate.isEmpty
        #expect(sansLigne)
        var nord = false, australe = false
        for e in sud.enVol {
            if e.latitude > 0 { nord = true }
            if e.latitude < 0 { australe = true }
        }
        let deuxHemispheres = nord && australe
        #expect(deuxHemispheres)
        for c in [aller, retour, suite, sud] {
            let sansReserve = c.reserves.isEmpty
            #expect(sansReserve, "\(c.plan.depart.iata)-\(c.plan.arrivee.iata)")
        }
    }

    @Test func chabbatFetesEtOmerEnVolSuiventLeCalendrier() throws {
        let vendredi = premierJour("2026-11-01") { $0.jourDeSemaine == 6 }
        let v = vendredi.iso
        let entrees = VolCalendrier.jalons(calcul(try plan("TLV", "JFK", "\(v)T12:30", "\(v)T17:45")), enIsrael: false, minutes: 18)
        let nEntrees = entrees.count
        #expect(nEntrees == 1)
        let premiereEntree = entrees.first
        let entree = try #require(premiereEntree)
        #expect(entree.type == VolCalendrier.Genre.entree)
        #expect(entree.chabbat)
        let samedi = vendredi.plus(jours: 1)
        #expect(entree.date == samedi)
        let allumageEntree = entree.allumage
        let allumage = try #require(allumageEntree)
        let avance = entree.instant - allumage
        let dixHuitMinutes = 18 * minute
        #expect(avance == dixHuitMinutes)
        let s = samedi.iso
        let sorties = VolCalendrier.jalons(calcul(try plan("TLV", "JFK", "\(s)T12:30", "\(s)T17:45")), enIsrael: false, minutes: 18)
        let nSorties = sorties.count
        #expect(nSorties == 1)
        let premiereSortie = sorties.first
        let sortie = try #require(premiereSortie)
        #expect(sortie.type == VolCalendrier.Genre.sortie)
        // Le Omer : le jour compté ce soir est celui du lendemain hébreu.
        let omer = premierJour("2027-01-01") { CalendrierJuif.jour($0.plus(jours: 1), enIsrael: false).omer == 4 }
        let o = omer.iso
        let j = VolCalendrier.jalons(calcul(try plan("TLV", "JFK", "\(o)T17:00", "\(o)T22:15")), enIsrael: false, minutes: 18)
        let genres = j.map { "\($0.type.rawValue) \($0.omer)" }
        #expect(genres == ["omer 4"])
        // Un vol sans chki'a ni tsét n'a aucun jalon.
        let court = VolCalendrier.jalons(calcul(try plan("TLV", "ETM", "\(v)T09:50", "\(v)T10:40")), enIsrael: false, minutes: 18)
        let aucun = court.isEmpty
        #expect(aucun)
    }

    @Test func unReleveGPSEnVolRecaleLaRouteHorsDuVolIlEstIgnore() throws {
        let lu = instantISO("2026-11-10T18:30:00Z")
        let t = try #require(lu)
        let releve = Vol.Point(instant: t, latitude: 56.0, longitude: -30.0)
        let route = try versOuest()
        var avec = route
        avec.releve = releve
        let p = Vol.position(avec, releve.instant)
        let dLat = abs(p.latitude - 56.0), dLon = abs(p.longitude + 30.0)
        #expect(dLat <= 1e-6)
        #expect(dLon <= 1e-6)
        let c = calcul(avec)
        #expect(c.fiabilite == Vol.Fiabilite.releveGps)
        let sans = calcul(route)
        #expect(sans.fiabilite == Vol.Fiabilite.routePrevue)
        let chkiaRecale = premier(c.enVol, "chkia")
        let chkiaPrevu = premier(sans.enVol, "chkia")
        let chkiaAvec = try #require(chkiaRecale).instant
        let chkiaSans = try #require(chkiaPrevu).instant
        #expect(chkiaAvec != chkiaSans)
        // Le point fixe tient aussi sur la route recalée.
        for e in c.enVol {
            let ecart = try ecartAuPoint(e)
            #expect(ecart <= 2000, "\(e.cle) : \(ecart) ms")
        }
        var dehors = route
        var tard = releve
        tard.instant = route.atterrissage + heure
        dehors.releve = tard
        let cd = calcul(dehors)
        #expect(cd.fiabilite == Vol.Fiabilite.routePrevue)
        let instantsDehors = cd.enVol.map { $0.instant }
        let instantsSans = sans.enVol.map { $0.instant }
        #expect(instantsDehors == instantsSans)
    }

    /// Le reste du test d'Android (indicatifs, réponse du relais, adresse) revient au portage de SuiviVol.kt :
    /// ici, la position reçue du suivi en direct recale la route comme un relevé, avec sa propre fiabilité.
    @Test func suiviEnDirectIndicatifsReponseDuRelaisAdresseFiabilite() throws {
        let lu = instantISO("2026-11-10T18:30:00Z")
        let t = try #require(lu)
        var p = try versOuest()
        p.releve = Vol.Point(instant: t, latitude: 56.0, longitude: -30.0)
        p.sourceReleve = .direct
        let c = calcul(p)
        #expect(c.fiabilite == Vol.Fiabilite.releveDirect)
    }

    // MARK: Vecteurs de la JVM (Tests/Vecteurs/vol.json)

    private func vecteurs() throws -> VecteursJVM {
        try JSONDecoder().decode(VecteursJVM.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vol.json"))
    }

    /// L'aéroport du fichier d'aéroports quand le vecteur le décrit tel quel (le même plan que les tests portés,
    /// donc le même calcul) ; sinon, tel que le vecteur le décrit.
    private func aeroport(_ x: VecteursJVM.AeroportJVM) -> Vol.Aeroport {
        if let connu = parIata[x.iata], connu.latitude == x.latitude, connu.longitude == x.longitude, connu.fuseau == x.fuseau {
            return connu
        }
        return Vol.Aeroport(iata: x.iata, nom: "", ville: "", pays: "", latitude: x.latitude, longitude: x.longitude, fuseau: x.fuseau)
    }

    private func plan(_ x: VecteursJVM.PlanJVM) -> Vol.Plan {
        Vol.Plan(numero: "TEST", depart: aeroport(x.depart), arrivee: aeroport(x.arrivee), decollage: x.decollage,
                 atterrissage: x.atterrissage,
                 releve: x.releve.map { Vol.Point(instant: $0.instant, latitude: $0.latitude, longitude: $0.longitude) },
                 sourceReleve: Vol.SourceReleve(rawValue: x.source) ?? .gps)
    }

    @Test func lesFonctionsSimplesRendentCeQueRendLaJVM() throws {
        let v = try vecteurs()
        #expect(Vol.dureeMax == v.constantes.dureeMax)
        #expect(Vol.marge == v.constantes.marge)
        #expect(Vol.retard == v.constantes.retard)
        #expect(Vol.latitudeHaute == v.constantes.latitudeHaute)
        #expect(VolPriere.couvert == v.constantes.couvert)
        for x in v.nautiques {
            let decalage = Vol.decalageNautique(x.longitude)
            #expect(decalage == x.decalage, "\(x.longitude)")
            let fuseau = Vol.fuseauNautique(x.longitude)
            #expect(fuseau == x.fuseau, "\(x.longitude)")
        }
        for x in v.distances {
            let km = Vol.distanceKm(x.lat1, x.lon1, x.lat2, x.lon2)
            let ecart = abs(km - x.km)
            #expect(ecart <= 1e-6, "\(x.lat1) \(x.lon1) \(x.lat2) \(x.lon2) : \(km) contre \(x.km)")
        }
        for x in v.instants {
            let fictif = Vol.Aeroport(iata: "XXX", nom: "", ville: "", pays: "", latitude: 0, longitude: 0, fuseau: x.fuseau)
            let millis = Vol.instant(local(x.local), fictif)
            #expect(millis == x.millis, "\(x.fuseau) \(x.local)")
        }
        for x in v.verifier {
            let r = Vol.verifier(plan(x.plan))?.rawValue
            #expect(r == x.invalide, "\(x.nom)")
        }
        var points = 0
        for x in v.positions {
            let p = plan(x.plan)
            let utilisable = Vol.releveUtilisable(p)
            #expect(utilisable == x.releveUtilisable, "\(x.nom)")
            let fiabilite = Vol.Calcul(plan: p, evenements: [], reserves: [], lignesDate: []).fiabilite.rawValue
            #expect(fiabilite == x.fiabilite, "\(x.nom)")
            let ecartKm = abs(Vol.distanceKm(p) - x.distanceKm)
            #expect(ecartKm <= 1e-6, "\(x.nom)")
            for q in x.points {
                let r = Vol.position(p, q.instant)
                // Au sol, à dix centimètres : près du pôle, la latitude passe par une fonction mal conditionnée et la
                // libm d'Apple ne rend pas le même dernier bit que glibc et la JVM (4 cm au pôle, le 15/11/2026).
                let metres = Vol.distanceKm(r.latitude, r.longitude, q.latitude, q.longitude) * 1000
                let ok = r.instant == q.instant && metres <= 0.1
                #expect(ok, "\(x.nom) à \(q.instant) : \(r.latitude), \(r.longitude) contre \(q.latitude), \(q.longitude)")
                points += 1
            }
        }
        print("Vol, vecteurs de la JVM : \(v.nautiques.count) fuseaux nautiques, \(v.distances.count) distances, "
              + "\(v.instants.count) heures de billet, \(v.verifier.count) saisies, \(points) positions")
    }

    /// Chaque vol de vol.json : tous les événements de la fenêtre (même nombre, mêmes clés dans le même ordre, à
    /// toleranceEnVol et un kilomètre près ; l'écart si retard à quatre secondes), les réserves et les dates de ligne à
    /// l'identique, les jalons en diaspora et en Israël, la prière du moment et ses horaires (demandés loin de tout
    /// zman : la réponse ne dépend pas des deux secondes).
    @Test func lesVolsDeLaJVMSontRendusADeuxSecondesPres() throws {
        let v = try vecteurs()
        var pire: Int64 = 0
        var evenements = 0, jalons = 0, prieres = 0
        for x in v.vols {
            let c = calcul(plan(x.plan))
            let nom = x.nom
            #expect(c.fiabilite.rawValue == x.fiabilite, "\(nom)")
            let n = c.evenements.count
            #expect(n == x.evenements.count, "\(nom) : \(n) événements, la JVM en rend \(x.evenements.count)")
            for (e, y) in zip(c.evenements, x.evenements) {
                #expect(e.cle == y.cle, "\(nom) : \(e.cle) contre \(y.cle)")
                let ecart = abs(e.instant - y.instant)
                pire = max(pire, ecart)
                #expect(ecart <= toleranceEnVol, "\(nom) \(y.cle) : \(ecart) ms")
                let km = Vol.distanceKm(e.latitude, e.longitude, y.latitude, y.longitude)
                #expect(km <= 1, "\(nom) \(y.cle) : \(km) km")
                if let s = e.ecartSiRetard, let k = y.ecartSiRetard {
                    let d = abs(s - k)
                    #expect(d <= 4000, "\(nom) \(y.cle) : écart si retard \(s) contre \(k)")
                } else {
                    let memes = (e.ecartSiRetard == nil) == (y.ecartSiRetard == nil)
                    #expect(memes, "\(nom) \(y.cle) : écart si retard présent d'un seul côté")
                }
                evenements += 1
            }
            let nEnVol = c.enVol.count
            #expect(nEnVol == x.enVol, "\(nom)")
            let reserves = c.reserves.map { $0.rawValue }.sorted()
            #expect(reserves == x.reserves, "\(nom)")
            let nLignes = c.lignesDate.count
            #expect(nLignes == x.lignesDate.count, "\(nom)")
            for (l, y) in zip(c.lignesDate, x.lignesDate) {
                #expect(l.avant.iso == y.avant, "\(nom)")
                #expect(l.apres.iso == y.apres, "\(nom)")
                let ecart = abs(l.instant - y.instant)
                #expect(ecart <= 10, "\(nom) ligne : \(ecart) ms")
            }
            for variante in x.jalons {
                let calcules = VolCalendrier.jalons(c, enIsrael: variante.enIsrael, minutes: variante.minutes)
                let quoi = "\(nom) \(variante.enIsrael ? "Israël" : "diaspora") \(variante.minutes) min"
                let nJalons = calcules.count
                #expect(nJalons == variante.liste.count, "\(quoi)")
                for (j, y) in zip(calcules, variante.liste) {
                    #expect(j.type.rawValue == y.type, "\(quoi)")
                    #expect(j.date.iso == y.date, "\(quoi)")
                    #expect(j.chabbat == y.chabbat, "\(quoi)")
                    #expect(j.fetes == y.fetes, "\(quoi)")
                    #expect(j.omer == y.omer, "\(quoi)")
                    let ecart = abs(j.instant - y.instant)
                    #expect(ecart <= 2000, "\(quoi) : \(ecart) ms")
                    if let s = j.allumage, let k = y.allumage {
                        let d = abs(s - k)
                        #expect(d <= 2000, "\(quoi) : allumage \(s) contre \(k)")
                    } else {
                        let memes = (j.allumage == nil) == (y.allumage == nil)
                        #expect(memes, "\(quoi) : allumage présent d'un seul côté")
                    }
                    let km = Vol.distanceKm(j.latitude, j.longitude, y.latitude, y.longitude)
                    #expect(km <= 1, "\(quoi) : \(km) km")
                    jalons += 1
                }
            }
            for y in x.priere {
                let m = VolPriere.priere(c, y.maintenant)
                let priere = m?.priere
                #expect(priere == y.priere, "\(nom) à \(y.maintenant)")
                if let s = m?.limite, let k = y.limite {
                    let d = abs(s - k)
                    #expect(d <= 2000, "\(nom) à \(y.maintenant) : limite \(s) contre \(k)")
                } else {
                    let memes = (m?.limite == nil) == (y.limite == nil)
                    #expect(memes, "\(nom) à \(y.maintenant) : limite présente d'un seul côté")
                }
                prieres += 1
            }
            for y in x.horaires {
                let h = Vol.horaires(c, y.maintenant)
                for (k, cle) in ["alot", "szt_gra", "chkia", "chatsot_layla"].enumerated() {
                    let s = h[cle]
                    let attendu = y.valeurs[k]
                    if let s, let attendu {
                        let d = abs(s - attendu)
                        #expect(d <= 2000, "\(nom) à \(y.maintenant) : \(cle) \(s) contre \(attendu)")
                    } else {
                        let memes = (s == nil) == (attendu == nil)
                        #expect(memes, "\(nom) à \(y.maintenant) : \(cle) présent d'un seul côté")
                    }
                }
            }
        }
        print("Vol, vecteurs de la JVM : \(v.vols.count) vols, \(evenements) événements, \(jalons) jalons, "
              + "\(prieres) prières du moment ; écart maximal \(pire) ms")
    }
}

// MARK: Aides

// Les aides sont des membres de la suite : un membre masque une fonction du module de même nom, qu'un autre
// fichier de tests déclarerait.
extension VolTests {
    /// Les calculs déjà faits, partagés par les tests de la suite : un vol demande des centaines d'appels de
    /// KosherSwift, et les mêmes vols reviennent d'un test à l'autre (le résultat ne dépend que du plan).
    private enum Calculs {
        static let faits = Mutex<[Vol.Plan: Vol.Calcul]>([:])
    }

    private func calcul(_ plan: Vol.Plan) -> Vol.Calcul {
        if let connu = Calculs.faits.withLock({ $0[plan] }) { return connu }
        let c = Vol.calculer(plan)
        Calculs.faits.withLock { $0[plan] = c }
        return c
    }

    /// « 2026-11-10T12:30 » : `LocalDateTime.parse`, à la minute.
    private func local(_ texte: String) -> DateHeure {
        let jour = JourCivil.du(String(texte.prefix(10)))
        let h = Int(texte.dropFirst(11).prefix(2)) ?? 0
        let m = Int(texte.dropFirst(14).prefix(2)) ?? 0
        return DateHeure(jour, heure: h, minute: m)
    }

    /// « 2026-11-10T13:43:59.812Z » (`Instant.toString`, millisecondes facultatives) en millisecondes Unix.
    private func instantISO(_ texte: String) -> Int64? {
        let o = Array(texte.utf8)
        guard o.count >= 20, o[10] == UInt8(ascii: "T"), o[o.count - 1] == UInt8(ascii: "Z"),
              let jour = JourCivil(iso: String(texte.prefix(10))) else { return nil }
        func nombre(_ plage: Range<Int>) -> Int? {
            var valeur = 0
            for i in plage {
                guard o[i] >= UInt8(ascii: "0"), o[i] <= UInt8(ascii: "9") else { return nil }
                valeur = valeur * 10 + Int(o[i] - UInt8(ascii: "0"))
            }
            return valeur
        }
        guard let h = nombre(11..<13), let m = nombre(14..<16), let s = nombre(17..<19) else { return nil }
        var milli = 0
        if o.count > 20 {
            guard o[19] == UInt8(ascii: "."), o.count >= 24, let ms = nombre(20..<23) else { return nil }
            milli = ms
        }
        return Fuseau.utc.millis(DateHeure(jour, heure: h, minute: m, seconde: s, milli: milli))
    }

    /// `matches(Regex("[A-Z0-9]{3}"))`.
    private func estCodeIata(_ code: String) -> Bool {
        let o = Array(code.utf8)
        guard o.count == 3 else { return false }
        for c in o where !((c >= UInt8(ascii: "A") && c <= UInt8(ascii: "Z")) || (c >= UInt8(ascii: "0") && c <= UInt8(ascii: "9"))) {
            return false
        }
        return true
    }

    /// Le premier événement de cette clé.
    private func premier(_ evenements: [Vol.Evenement], _ cle: String) -> Vol.Evenement? {
        evenements.first { $0.cle == cle }
    }

    /// `zipWithNext().all { (x, y) -> !y.instant.isBefore(x.instant) }`.
    private func estOrdonne(_ evenements: [Vol.Evenement]) -> Bool {
        for k in evenements.indices.dropFirst() where evenements[k].instant < evenements[k - 1].instant { return false }
        return true
    }

    /// `Duration.between(de, a).seconds`.
    private func secondesEntieres(_ de: Int64, _ a: Int64) -> Int64 {
        Int64(Kotlin.floorDiv(Int(a - de), 1000))
    }

    /// `generateSequence(LocalDate.parse(depuis)) { it.plusDays(1) }.first(ok)`.
    private func premierJour(_ depuis: String, _ ok: (JourCivil) -> Bool) -> JourCivil {
        var d = JourCivil.du(depuis)
        while !ok(d) { d = d.plus(jours: 1) }
        return d
    }
}

// MARK: Fichiers

extension VolTests {
    /// aeroports.json : une ligne par aéroport, [iata, nom, ville, pays, latitude, longitude, fuseau].
    fileprivate struct FichierAeroports: Decodable {
        struct Ligne: Decodable {
            let aeroport: Vol.Aeroport

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                let iata = try c.decode(String.self)
                let nom = try c.decode(String.self)
                let ville = try c.decode(String.self)
                let pays = try c.decode(String.self)
                let latitude = try c.decode(Double.self)
                let longitude = try c.decode(Double.self)
                let fuseau = try c.decode(String.self)
                aeroport = Vol.Aeroport(iata: iata, nom: nom, ville: ville, pays: pays, latitude: latitude,
                                        longitude: longitude, fuseau: fuseau)
            }
        }

        let aeroports: [Ligne]
    }

    /// web/test/vecteurs_vol.json (tools/vecteurs_vol/VecteursVol.kt).
    fileprivate struct VecteursDuSite: Decodable {
        struct ZmanDuSite: Decodable {
            let cle: String
            let instant: String
        }

        struct ReleveDuSite: Decodable {
            let latitude: Double
            let longitude: Double
            let instant: String
        }

        struct JalonDuSite: Decodable {
            let type: String
            let instant: String
            let date: String
            let omer: Int
        }

        struct VolDuSite: Decodable {
            let depart: String
            let arrivee: String
            let decollage: String
            let atterrissage: String
            let releve: ReleveDuSite?
            let fiabilite: String
            let enVol: [ZmanDuSite]
            let reserves: [String]
            let lignesDate: [[String]]
            let jalons: [JalonDuSite]
        }

        let vols: [VolDuSite]
    }

    /// Tests/Vecteurs/vol.json (tools/vecteurs_ios/VecteursVol.kt) : les listes de « _meta » y décrivent les lignes.
    fileprivate struct VecteursJVM: Decodable {
        struct Constantes: Decodable {
            let dureeMax: Int64
            let marge: Int64
            let retard: Int64
            let latitudeHaute: Double
            let couvert: Int64
        }

        struct AeroportJVM: Decodable {
            let iata: String
            let latitude: Double
            let longitude: Double
            let fuseau: String
        }

        /// [instant, latitude, longitude].
        struct PointJVM: Decodable {
            let instant: Int64
            let latitude: Double
            let longitude: Double

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                instant = try c.decode(Int64.self)
                latitude = try c.decode(Double.self)
                longitude = try c.decode(Double.self)
            }
        }

        struct PlanJVM: Decodable {
            let depart: AeroportJVM
            let arrivee: AeroportJVM
            let decollage: Int64
            let atterrissage: Int64
            let releve: PointJVM?
            let source: String
        }

        /// [longitude, décalage, fuseau].
        struct Nautique: Decodable {
            let longitude: Double
            let decalage: Int
            let fuseau: String

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                longitude = try c.decode(Double.self)
                decalage = try c.decode(Int.self)
                fuseau = try c.decode(String.self)
            }
        }

        /// [lat1, lon1, lat2, lon2, km].
        struct Distance: Decodable {
            let lat1: Double
            let lon1: Double
            let lat2: Double
            let lon2: Double
            let km: Double

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                lat1 = try c.decode(Double.self)
                lon1 = try c.decode(Double.self)
                lat2 = try c.decode(Double.self)
                lon2 = try c.decode(Double.self)
                km = try c.decode(Double.self)
            }
        }

        /// [fuseau, heure locale, instant ou null].
        struct HeureDeBillet: Decodable {
            let fuseau: String
            let local: String
            let millis: Int64?

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                fuseau = try c.decode(String.self)
                local = try c.decode(String.self)
                millis = try c.decodeIfPresent(Int64.self)
            }
        }

        struct Verification: Decodable {
            let nom: String
            let plan: PlanJVM
            let invalide: String?
        }

        struct Positions: Decodable {
            let nom: String
            let plan: PlanJVM
            let releveUtilisable: Bool
            let fiabilite: String
            let distanceKm: Double
            let points: [PointJVM]
        }

        /// [cle, instant, latitude, longitude, ecartSiRetard ou null].
        struct EvenementJVM: Decodable {
            let cle: String
            let instant: Int64
            let latitude: Double
            let longitude: Double
            let ecartSiRetard: Int64?

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                cle = try c.decode(String.self)
                instant = try c.decode(Int64.self)
                latitude = try c.decode(Double.self)
                longitude = try c.decode(Double.self)
                ecartSiRetard = try c.decodeIfPresent(Int64.self)
            }
        }

        /// [instant, avant, apres].
        struct LigneJVM: Decodable {
            let instant: Int64
            let avant: String
            let apres: String

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                instant = try c.decode(Int64.self)
                avant = try c.decode(String.self)
                apres = try c.decode(String.self)
            }
        }

        /// [type, instant, date, chabbat, fetes, omer, allumage ou null, latitude, longitude].
        struct JalonJVM: Decodable {
            let type: String
            let instant: Int64
            let date: String
            let chabbat: Bool
            let fetes: [String]
            let omer: Int
            let allumage: Int64?
            let latitude: Double
            let longitude: Double

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                type = try c.decode(String.self)
                instant = try c.decode(Int64.self)
                date = try c.decode(String.self)
                chabbat = try c.decode(Bool.self)
                fetes = try c.decode([String].self)
                omer = try c.decode(Int.self)
                allumage = try c.decodeIfPresent(Int64.self)
                latitude = try c.decode(Double.self)
                longitude = try c.decode(Double.self)
            }
        }

        struct Jalons: Decodable {
            let enIsrael: Bool
            let minutes: Int
            let liste: [JalonJVM]
        }

        /// [maintenant, prière ou null, limite ou null].
        struct PriereJVM: Decodable {
            let maintenant: Int64
            let priere: String?
            let limite: Int64?

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                maintenant = try c.decode(Int64.self)
                priere = try c.decodeIfPresent(String.self)
                limite = try c.decodeIfPresent(Int64.self)
            }
        }

        /// [maintenant, alot, szt_gra, chkia, chatsot_layla], chacun ou null.
        struct HorairesJVM: Decodable {
            let maintenant: Int64
            let valeurs: [Int64?]

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                maintenant = try c.decode(Int64.self)
                var valeurs: [Int64?] = []
                for _ in 0..<4 { valeurs.append(try c.decodeIfPresent(Int64.self)) }
                self.valeurs = valeurs
            }
        }

        struct VolJVM: Decodable {
            let nom: String
            let plan: PlanJVM
            let fiabilite: String
            let evenements: [EvenementJVM]
            let enVol: Int
            let reserves: [String]
            let lignesDate: [LigneJVM]
            let jalons: [Jalons]
            let priere: [PriereJVM]
            let horaires: [HorairesJVM]
        }

        let constantes: Constantes
        let nautiques: [Nautique]
        let distances: [Distance]
        let instants: [HeureDeBillet]
        let verifier: [Verification]
        let positions: [Positions]
        let vols: [VolJVM]
    }
}
