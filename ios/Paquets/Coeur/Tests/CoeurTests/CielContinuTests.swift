import Foundation
import KosherSwift
import Testing
@testable import Coeur

/// CielContinuTest d'Android, porté : les clés de couleurs (`CielContinu`) sans saut d'une minute à l'autre, sur des
/// journées entières simulées minute par minute (y compris là où le soleil reste bas à midi ou haut à minuit, au
/// nord), le matin et le soir et leur passage, les étapes du jour (nuit noire, bleu du crépuscule, rouges, jaunes,
/// heure dorée, bleu du jour, orange, violet), la lune du mois hébreu contre le molad et la lune vraie, et l'arc de
/// l'astre (`PlanCiel.arc`). Le soleil lui-même : SoleilTests.
@Suite("Ciel continu")
struct CielContinuTests {

    private func canal(_ c: UInt32, _ d: UInt32) -> Int { Int((c >> d) & 0xFF) }

    private func saut(_ a: UInt32, _ b: UInt32) -> Int {
        [0, 8, 16].map { abs(canal(a, UInt32($0)) - canal(b, UInt32($0))) }.max() ?? 0
    }

    @Test func aucuneMinuteNeSaute() {
        for matin in [true, false] {
            var avant = CielContinu.brutes(-30, matin: matin)
            var e = -30.0
            while e <= 70 {
                let c = CielContinu.brutes(e, matin: matin)
                for i in 0..<3 {
                    #expect(saut(avant[i], c[i]) <= 8,
                            "\(matin) \(e)° : \(CielContinu.hexa(avant[i])) → \(CielContinu.hexa(c[i]))")
                }
                avant = c
                e += 0.25
            }
        }
        // Un quart de degré, c'est une minute ou deux de soleil : les dosages aussi glissent (la lueur, la plus vive,
        // s'éteint en 3° : 0,125 par quart de degré au plus).
        let dosages: [(Double) -> Double] = [CielContinu.etoiles, CielContinu.nuages, CielContinu.rayons,
                                             CielContinu.soleilVisible, CielContinu.luneVisible,
                                             CielContinu.lueurVisible, CielContinu.chaleur]
        var e = -30.0
        while e <= 70 {
            for f in dosages { #expect(abs(f(e + 0.25) - f(e)) <= 0.13, "\(e)°") }
            e += 0.25
        }
    }

    @Test func leMatinEtLeSoirSeRejoignentAMidiEtAMinuit() {
        // Le matin, tout le matin ; le soir, tout le soir ; moitié-moitié au méridien.
        #expect(abs(CielContinu.partMatin(-90) - 1) < 1e-12)
        #expect(abs(CielContinu.partMatin(-15) - 1) < 1e-12)
        #expect(abs(CielContinu.partMatin(90)) < 1e-12)
        #expect(abs(CielContinu.partMatin(15)) < 1e-12)
        for h in [0.0, 180, -180] { #expect(abs(CielContinu.partMatin(h) - 0.5) < 1e-12) }
        #expect(abs(CielContinu.partMatin(-165) - 1) < 1e-12)
        #expect(abs(CielContinu.partMatin(165)) < 1e-12)
        // Sans saut de −180° à 180° (minuit), ni d'un dixième de degré à l'autre.
        var h = -180.0
        while h < 180 {
            #expect(abs(CielContinu.partMatin(h + 0.1) - CielContinu.partMatin(h)) < 0.01, "\(h)")
            h += 0.1
        }
        #expect(abs(CielContinu.partMatin(-179.99) - CielContinu.partMatin(179.99)) <= 2e-3)
        // Le mélange passe entre les deux suites ; aux bouts, ce sont elles.
        for e in [-10.0, -4, 0, 3, 7] {
            let m = CielContinu.brutes(e, matin: true)
            let s = CielContinu.brutes(e, matin: false)
            let mi = CielContinu.brutes(e, matin: 0.5)
            for i in 0..<3 {
                for d: UInt32 in [0, 8, 16] {
                    let bas = min(canal(m[i], d), canal(s[i], d))
                    let haut = max(canal(m[i], d), canal(s[i], d))
                    #expect((bas...haut).contains(canal(mi[i], d)))
                }
            }
            #expect(CielContinu.brutes(e, matin: 1.0) == m && CielContinu.brutes(e, matin: 0.0) == s)
        }
    }

    // MARK: Des journées entières, minute par minute

    struct Lieu {
        let nom: String
        let lat: Double
        let lon: Double
        let fuseau: String
    }

    static let lieux = [
        Lieu(nom: "Jérusalem", lat: 31.778, lon: 35.235, fuseau: "Asia/Jerusalem"),
        Lieu(nom: "Paris", lat: 48.857, lon: 2.352, fuseau: "Europe/Paris"),
        Lieu(nom: "New York", lat: 40.713, lon: -74.006, fuseau: "America/New_York"),
        Lieu(nom: "Sydney", lat: -33.869, lon: 151.209, fuseau: "Australia/Sydney"),
        // Au nord : le soleil de midi reste sous 12° l'hiver, celui de minuit au-dessus de −18° l'été.
        Lieu(nom: "Stockholm", lat: 59.33, lon: 18.07, fuseau: "Europe/Stockholm"),
        Lieu(nom: "Moscou", lat: 55.756, lon: 37.617, fuseau: "Europe/Moscow"),
        // Nuit polaire et jour polaire.
        Lieu(nom: "Tromsø", lat: 69.649, lon: 18.955, fuseau: "Europe/Oslo"),
    ]
    static let jours = ["2026-03-20", "2026-06-21", "2026-11-24", "2026-12-21"]

    /// Chaque minute d'un jour local, de minuit à minuit.
    static func journee(_ l: Lieu, _ jour: String) -> [EtatCiel] {
        guard let zone = Fuseau(l.fuseau), let j = JourCivil(iso: jour) else { return [] }
        let debut = DateHeureZonee(DateHeure(j, heure: 0, minute: 0), fuseau: zone).millis
        return (0...(24 * 60)).map {
            EtatCiel.de(Soleil.position(millis: debut + Int64($0) * 60_000, latitude: l.lat, longitude: l.lon),
                        jourHebreu: 15)
        }
    }

    @Test func desJourneesEntieresSansACoupAuNordCommeAuSud() {
        var fautes: [String] = []
        for l in Self.lieux {
            for jour in Self.jours {
                let etats = Self.journee(l, jour)
                #expect(etats.count == 1441)
                for m in 1..<etats.count {
                    let a = etats[m - 1]
                    let b = etats[m]
                    let ca = CielContinu.brutes(a.hauteur, matin: a.matin)
                    let cb = CielContinu.brutes(b.hauteur, matin: b.matin)
                    let s = (0..<3).map { saut(ca[$0], cb[$0]) }.max() ?? 0
                    if s > 8 {
                        fautes.append("\(l.nom) \(jour) \(m / 60) h \(m % 60) : \(a.hauteur)° → \(b.hauteur)°, saut de \(s)")
                    }
                    // L'astre paraît et s'efface en douceur, même au jour et à la nuit polaires.
                    if abs(a.astreVisible - b.astreVisible) > 0.13 || abs(a.lueurVisible - b.lueurVisible) > 0.13 {
                        fautes.append("\(l.nom) \(jour) \(m / 60) h \(m % 60) : l'astre \(a.astreVisible) → \(b.astreVisible)")
                    }
                }
            }
        }
        #expect(fautes.isEmpty, "à-coups :\n\(fautes.prefix(30).joined(separator: "\n"))")
    }

    // Le Pixel 6 de SoleilTest, en points : 411 de large, des anneaux de 260 centrés, 180 sous le haut.
    static let largeur = 411.0
    static let jauge = PlanCiel.Zone(gauche: 75.5, haut: 180, droite: 335.5, bas: 440)
    static let textes = [PlanCiel.Zone(gauche: 24, haut: 64, droite: 387, bas: 160),
                         PlanCiel.Zone(gauche: 24, haut: 444, droite: 387, bas: 520)]
    static let r = 14.0
    static let couronne = r * PlanCiel.couronne

    @Test func lAstreNeSautePasDUnBordALAutre() {
        // Sans texte à côté des anneaux : l'astre visible, hors du disque des anneaux, avance d'au plus 8 points par
        // minute ; plus vite seulement quand tout son arc dure une heure ou deux (Tromsø fin novembre), où il glisse
        // derrière les anneaux, vers midi, en quelques minutes : au plus 2 500 points par arc entier.
        var fautes: [String] = []
        let j = Self.jauge
        let cx = (j.gauche + j.droite) / 2
        let cy = (j.haut + j.bas) / 2
        let rayonAnneaux = j.largeur / 2
        func place(_ e: EtatCiel) -> (x: Double, y: Double)? {
            let soleil = e.estSoleil
            guard let p = PlanCiel.arc(progres: soleil ? e.progresJour : e.progresNuit,
                                       hauteur: CielContinu.elevationDessinee(soleil ? e.hauteur : -e.hauteur),
                                       jauge: j, largeur: Self.largeur, r: Self.r, couronne: Self.couronne,
                                       zones: Self.textes) else { return nil }
            // Caché derrière les anneaux, il peut passer vite : on ne le voit pas.
            return hypot(p.x - cx, p.y - cy) + Self.r < rayonAnneaux ? nil : p
        }
        for l in Self.lieux {
            for jour in Self.jours {
                let etats = Self.journee(l, jour)
                for m in 1..<etats.count {
                    let a = etats[m - 1]
                    let b = etats[m]
                    if a.astreVisible < 0.05 || b.astreVisible < 0.05 || a.estSoleil != b.estSoleil { continue }
                    guard let pa = place(a), let pb = place(b) else { continue }
                    let pas = hypot(pb.x - pa.x, pb.y - pa.y)
                    let arcEntier = a.estSoleil ? abs(b.progresJour - a.progresJour) : abs(b.progresNuit - a.progresNuit)
                    if pas > max(8, 2500 * arcEntier) {
                        fautes.append("\(l.nom) \(jour) \(m / 60) h \(m % 60) : \(a.estSoleil ? "le soleil" : "la lune") fait \(pas)")
                    }
                }
            }
        }
        #expect(fautes.isEmpty, "sauts de l'astre :\n\(fautes.prefix(30).joined(separator: "\n"))")
    }

    @Test func lesEtapesDuJour() {
        func lum(_ c: UInt32) -> Double { TeintesCiel.luminance(c) }
        // La nuit noire, sous −18°.
        #expect(CielContinu.brutes(-25, matin: true).allSatisfy { lum($0) < 0.03 })
        // Le lever et le coucher : l'horizon rouge-orangé, le soir plus orangé que le matin.
        for matin in [true, false] {
            let h = CielContinu.brutes(0, matin: matin)[2]
            #expect(canal(h, 16) > canal(h, 8) && canal(h, 8) > canal(h, 0))
        }
        #expect(canal(CielContinu.brutes(0, matin: false)[2], 8) < canal(CielContinu.brutes(0, matin: true)[2], 8))
        // Les jaunes du matin, l'heure dorée.
        let jaune = CielContinu.brutes(3, matin: true)[2]
        #expect(canal(jaune, 16) > 240 && canal(jaune, 8) > 200 && canal(jaune, 0) < 180)
        // Le bleu du jour.
        for c in CielContinu.brutes(40, matin: true) { #expect(canal(c, 0) > canal(c, 16)) }
        // Le violet du crépuscule le soir.
        let violet = CielContinu.brutes(-4, matin: false)[1]
        #expect(canal(violet, 0) > canal(violet, 8) && canal(violet, 16) > canal(violet, 8))
        // Les étoiles : aucune à −4°, toutes à −14° ; les rayons seulement à l'heure dorée.
        #expect(abs(CielContinu.etoiles(-4)) < 1e-9)
        #expect(abs(CielContinu.etoiles(-14) - 1) < 1e-9)
        #expect(abs(CielContinu.rayons(-2)) < 1e-9)
        #expect(abs(CielContinu.rayons(3) - 1) < 1e-9)
        #expect(abs(CielContinu.rayons(12)) < 1e-9)
        // Les nuages, presque rien la nuit ; blancs le jour, dorés bas.
        #expect(CielContinu.nuages(-20) < 0.2 && CielContinu.nuages(5) == 1)
        #expect(CielContinu.nuageCorps.a(30) == 0xFFFFFFFF)
        let dore = CielContinu.nuageBord.a(3)
        #expect(canal(dore, 16) > canal(dore, 0) + 80)
    }

    @Test func laLuneDuMoisHebreuEstCelleDuMoladEtAPeuPresLaVraie() throws {
        // Chaque soir de 2026 et 2027 à 21 h à Jérusalem : le jour hébreu affiché (celui qui a commencé à la tombée de
        // la nuit), l'âge que la lune en reçoit, l'âge depuis le molad du mois (KosherSwift, comme KosherJava) et celui
        // de la lune moyenne (nouvelle lune du 6/1/2000 à 18 h 14 UTC, lunaison de 29,530589 jours).
        let zone = try #require(Fuseau("Asia/Jerusalem"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        var jour = try #require(JourCivil(iso: "2026-01-01"))
        let fin = try #require(JourCivil(iso: "2028-01-01"))
        let mois = CielContinu.moisLunaire
        func ecart(_ x: Double, _ y: Double) -> Double {
            let d = abs(x - y)
            return min(d, mois - d)
        }
        while jour < fin {
            let soir = DateHeureZonee(DateHeure(jour, heure: 21, minute: 0), fuseau: zone).millis
            let hebreu = jour.plus(jours: 1)
            let l = CielContinu.lune(CalendrierJuif.jour(hebreu, enIsrael: true).jourHebreu)
            let midi = Date(timeIntervalSince1970: Double(hebreu.jourJulien - 2_440_588) * 86_400 + 43_200)
            let molad = JewishCalendar(workingDate: midi, timezone: utc, inIsrael: true).getMoladAsDate()
            let depuisMolad = (Double(soir) / 1000 - molad.timeIntervalSince1970) / 86_400
            let jd = Double(soir) / 86_400_000 + 2_440_587.5 - 2_451_550.26
            let vraie = (jd.truncatingRemainder(dividingBy: mois) + mois).truncatingRemainder(dividingBy: mois)
            // Roch 'Hodech tombe le jour du molad ou jusqu'à deux jours après ; la lune moyenne s'écarte de la vraie
            // d'une demi-journée environ : deux jours d'âge au plus.
            #expect(ecart(l.age, depuisMolad) <= 2.1, "\(jour.iso) : âge \(l.age) pour \(depuisMolad) jours depuis le molad")
            #expect(ecart(l.age, vraie) <= 2.1, "\(jour.iso) : âge \(l.age) pour une lune moyenne de \(vraie) jours")
            jour = jour.plus(jours: 1)
        }
        // La pleine lune du 24 novembre 2026 (vers 15 h UTC) : le soir, 15 Kislev, la lune est pleine.
        let ce = CalendrierJuif.jour(try #require(JourCivil(iso: "2026-11-25")), enIsrael: true)
        #expect(ce.jourHebreu == 15)
        #expect(CielContinu.lune(ce.jourHebreu).eclairee > 0.98)
    }

    @Test func laLuneSuitLeMoisHebreu() {
        #expect(CielContinu.lune(1).eclairee < 0.02 && CielContinu.lune(2).eclairee < 0.06 && CielContinu.lune(2).croissante)
        #expect(abs(CielContinu.lune(8).eclairee - 0.5) <= 0.08)
        #expect(CielContinu.lune(15).eclairee > 0.98)
        #expect(!CielContinu.lune(22).croissante)
        #expect(abs(CielContinu.lune(23).eclairee - 0.5) <= 0.1)
        #expect(CielContinu.lune(29).eclairee < 0.04)
        // Le terminateur : rien sous 2 %, bombé vers la lumière en croissant, vers l'ombre en lune gibbeuse.
        #expect(PlanCiel.terminateur(CielContinu.lune(1)) == nil)
        #expect(PlanCiel.terminateur(CielContinu.lune(4))?.versLumiere == true)
        #expect(PlanCiel.terminateur(CielContinu.lune(12))?.versLumiere == false)
    }

    // MARK: L'arc

    private func arc(_ p: Double, _ h: Double) -> (x: Double, y: Double)? {
        PlanCiel.arc(progres: p, hauteur: h, jauge: Self.jauge, largeur: Self.largeur, r: Self.r,
                     couronne: Self.couronne, zones: Self.textes)
    }

    @Test func leSoleilSeLeveAGaucheEtSeCoucheADroiteDerriereLesAnneauxAMidi() throws {
        let j = Self.jauge
        let lever = try #require(arc(0, 0))
        #expect(lever.x < j.gauche && lever.y <= j.bas - Self.couronne + 0.1)
        let coucher = try #require(arc(1, 0))
        #expect(coucher.x > j.droite)
        let midi = try #require(arc(0.5, 0.6))
        #expect(abs(midi.x - (j.gauche + j.droite) / 2) <= 0.5)
        // Il monte avec sa hauteur, sans jamais sortir de la hauteur des anneaux.
        var avant = Double.greatestFiniteMagnitude
        for k in 0...20 {
            let y = try #require(arc(0.2, Double(k) / 20)).y
            #expect(y <= avant && y - Self.couronne >= j.haut - 0.1 && y + Self.couronne <= j.bas + 0.1)
            avant = y
        }
        // Il s'attarde dans les marges : au premier quart du jour, encore à gauche des anneaux.
        #expect(try #require(arc(0.2, 0.3)).x < j.gauche + Self.r)
        // De gauche à droite, toujours.
        var x = -1.0
        for k in 0...40 {
            let n = try #require(arc(Double(k) / 40, 0.3)).x
            #expect(n >= x)
            x = n
        }
    }

    @Test func ilLongeLesAnneauxAuLieuDeSYCacherSaufVersMidi() throws {
        // Un jour sans lieu (levé à 6 h 30, couché à 18 h 30), minute par minute : le centre du soleil n'entre dans le
        // disque des anneaux qu'une heure et demie au plus, autour de midi ; à 10 h, 11 h 30, 13 h 30 et 15 h, on le
        // voit.
        let j = Self.jauge
        let cx = (j.gauche + j.droite) / 2
        let cy = (j.haut + j.bas) / 2
        let rayonAnneaux = j.largeur / 2
        func dehors(_ heure: Double) -> Bool {
            let p = Soleil.parHeure(heure)
            let rr = Double(CielContinu.rayonSoleil(p.hauteur))
            guard let a = PlanCiel.arc(progres: p.progresJour, hauteur: CielContinu.elevationDessinee(p.hauteur),
                                       jauge: j, largeur: Self.largeur, r: rr, couronne: rr * PlanCiel.couronne,
                                       zones: Self.textes) else { return false }
            return hypot(a.x - cx, a.y - cy) > rayonAnneaux
        }
        let minutes: [Int] = Array((6 * 60 + 35)...(18 * 60 + 25))
        let caches: [Int] = minutes.filter { m in !dehors(Double(m) / 60) }
        let autourDeMidi = caches.allSatisfy { m in abs(m - 750) <= 45 }
        #expect(caches.count <= 90 && autourDeMidi, "caché \(caches.count) minutes")
        #expect(dehors(10) && dehors(15) && dehors(11.5) && dehors(13.5))
    }

    @Test func surUnEcranEtroitLAstreSArreteAuBordAuLieuDeDisparaitre() throws {
        // 320 points de large, des anneaux de 290 : 15 de marge, moins que le disque.
        let etroit = PlanCiel.Zone(gauche: 15, haut: 180, droite: 305, bas: 440)
        var x = -1.0
        for k in 0...40 {
            let p = try #require(PlanCiel.arc(progres: Double(k) / 40, hauteur: 0.2, jauge: etroit, largeur: 320,
                                              r: Self.r, couronne: Self.couronne, zones: []), "progrès \(k)")
            #expect(p.x >= Self.r - 0.01 && p.x <= 320 - Self.r + 0.01 && p.x >= x)
            x = p.x
        }
        let lever = try #require(PlanCiel.arc(progres: 0, hauteur: 0, jauge: etroit, largeur: 320, r: Self.r,
                                              couronne: Self.couronne, zones: []))
        #expect(abs(lever.x - Self.r) <= 0.01)
    }

    @Test func jamaisSousUnTexte() {
        // Un texte posé à côté des anneaux : l'astre ne s'y montre pas.
        let gene = Self.textes + [PlanCiel.Zone(gauche: 0, haut: 300, droite: 70, bas: 340)]
        #expect(PlanCiel.arc(progres: 0, hauteur: 0.3, jauge: Self.jauge, largeur: Self.largeur, r: Self.r,
                             couronne: Self.couronne, zones: gene) == nil)
        #expect(PlanCiel.arc(progres: 1, hauteur: 0.3, jauge: Self.jauge, largeur: Self.largeur, r: Self.r,
                             couronne: Self.couronne, zones: gene) != nil)
    }
}
