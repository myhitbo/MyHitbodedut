import Foundation
import Testing
@testable import Coeur

/// SoleilTest d'Android, porté : le soleil du ciel continu (`Soleil`, 24/11) contre son témoin, NOAACalculator de
/// KosherJava 2.5.0 (le moteur des zmanim d'Android), dont les réponses sont dans Tests/Vecteurs/soleil.json
/// (tools/vecteurs_ios/VecteursSoleil.kt) : la hauteur à toute heure, le lever et le coucher, le passage au
/// méridien, à Jérusalem, Paris, New York, Montréal, Sydney et Buenos Aires ; près des pôles (nuit et jour
/// polaires, les pôles eux-mêmes, la ligne de changement de date), rien ne casse ; sans lieu, le soleil moyen de
/// l'heure du téléphone. Le getSolarElevation de KosherSwift n'est pas un témoin : il compte les minutes comme des
/// secondes, et lit son fuseau dans une variable partagée.
@Suite("Soleil")
struct SoleilTests {

    struct Journee: Decodable {
        let lieu: String
        let lat: Double
        let lon: Double
        let date: String
        let hauteurs: [Double]
        let lever: Int64?
        let coucher: Int64?
        let midi: Int64?
    }

    struct Vecteurs: Decodable {
        let journees: [Journee]
        let extremes: [Journee]
    }

    static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/soleil.json"))
    }

    static func minuitUtc(_ iso: String) -> Int64 {
        guard let jour = JourCivil(iso: iso) else { return 0 }
        return Int64(jour.jourJulien - 2_440_588) * 86_400_000
    }

    /// L'écart permis avec NOAACalculator.getSolarElevation à l'instant `t`. Celui-ci prend la déclinaison et
    /// l'équation du temps à 0 h UTC du jour ; `Soleil` les prend à l'instant. L'écart permis croît donc avec l'heure
    /// UTC, de la marche de la déclinaison : 0,4° par jour au plus, aux équinoxes. Plus le cent-millième des vecteurs.
    static func tolerance(_ t: Int64) -> Double {
        0.01 + 0.42 * Double(Kotlin.floorMod(Int(t), 86_400_000)) / 86_400_000 + 0.00001
    }

    @Test func laHauteurEstCelleDeNOAACalculatorAToutHeure() throws {
        let v = try Self.vecteurs()
        #expect(v.journees.count == 6 * 8)
        var pire = 0.0
        var fautes: [String] = []
        for j in v.journees {
            #expect(j.hauteurs.count == 72)
            for (k, attendu) in j.hauteurs.enumerated() {
                let t = Self.minuitUtc(j.date) + Int64(k) * 20 * 60_000 + 37_000
                let calcule = Soleil.position(millis: t, latitude: j.lat, longitude: j.lon).hauteur
                if k == 0 { pire = max(pire, abs(calcule - attendu)) }
                if abs(calcule - attendu) > Self.tolerance(t) {
                    fautes.append("\(j.lieu) \(j.date) +\(k * 20) min : \(calcule) au lieu de \(attendu)")
                }
            }
        }
        #expect(fautes.isEmpty, "\(fautes.prefix(20).joined(separator: "\n"))")
        // À 0 h UTC, là où NOAACalculator prend ses termes, les deux calculs se rejoignent.
        #expect(pire < 0.01, "écart à 0 h UTC : \(pire)")
    }

    @Test func auLeverEtAuCoucherDeNOAACalculatorLeSoleilEstALHorizon() throws {
        for j in try Self.vecteurs().journees {
            // Le lever et le coucher au niveau de la mer : le centre du soleil à 0,833° sous l'horizon.
            for (instant, lever) in [(j.lever, true), (j.coucher, false)] {
                let t = try #require(instant, "\(j.lieu) \(j.date)")
                let p = Soleil.position(millis: t, latitude: j.lat, longitude: j.lon)
                let ici = "\(j.lieu) \(j.date) \(lever ? "lever" : "coucher")"
                #expect(abs(p.hauteur + 0.833) <= 0.06, "\(ici) : \(p.hauteur)")
                #expect(abs(p.angleHoraire - (lever ? -p.angleLever : p.angleLever)) <= 0.25, "\(ici)")
                #expect(p.matin == lever, "\(ici)")
                #expect(abs(p.progresJour - (lever ? 0 : 1)) <= 0.002, "\(ici)")
                #expect(abs(p.progresNuit - (lever ? 1 : 0)) <= 0.002, "\(ici)")
            }
            // Au midi vrai, l'angle horaire est nul et le soleil à son plus haut.
            let t = try #require(j.midi)
            let p = Soleil.position(millis: t, latitude: j.lat, longitude: j.lon)
            #expect(abs(p.angleHoraire) <= 0.1, "\(j.lieu) \(j.date) midi")
            #expect(p.hauteur >= Soleil.position(millis: t - 1_800_000, latitude: j.lat, longitude: j.lon).hauteur
                && p.hauteur >= Soleil.position(millis: t + 1_800_000, latitude: j.lat, longitude: j.lon).hauteur)
            #expect(abs(p.progresJour - 0.5) <= 0.001)
        }
    }

    @Test func jerusalemLe24Novembre2026() throws {
        // UTC+2 : lever vers 6 h 20, midi vers 11 h 33 (37,6°), coucher vers 16 h 32.
        let zone = try #require(Fuseau("Asia/Jerusalem"))
        let jour = try #require(JourCivil(iso: "2026-11-24"))
        func a(_ h: Int, _ m: Int) -> Soleil.Position {
            Soleil.position(millis: DateHeureZonee(DateHeure(jour, heure: h, minute: m), fuseau: zone).millis,
                            latitude: 31.778, longitude: 35.235)
        }
        #expect(abs(a(6, 20).hauteur) < 1.5 && a(6, 20).matin && a(6, 20).progresJour < 0.03)
        #expect((36.0...39.0).contains(a(11, 33).hauteur) && abs(a(11, 33).progresJour - 0.5) < 0.02)
        #expect(abs(a(16, 32).hauteur) < 1.5 && !a(16, 32).matin && a(16, 32).progresJour > 0.97)
        #expect(a(23, 33).hauteur < -60 && !a(23, 33).jour && abs(a(23, 33).progresNuit - 0.5) < 0.03)
    }

    // MARK: Près des pôles

    private func valide(_ p: Soleil.Position, _ ici: String) {
        for x in [p.hauteur, p.angleHoraire, p.angleLever, p.progresJour, p.progresNuit] {
            #expect(x.isFinite, "\(ici) : \(p)")
        }
        #expect((-90.0...90.0).contains(p.hauteur) && (-180.0...180.0).contains(p.angleHoraire)
            && (0.0...180.0).contains(p.angleLever), "\(ici) : \(p)")
        #expect((0.0...1.0).contains(p.progresJour) && (0.0...1.0).contains(p.progresNuit), "\(ici) : \(p)")
    }

    @Test func presDesPolesRienNeCasse() throws {
        let v = try Self.vecteurs()
        let jauge = PlanCiel.Zone(gauche: 75, haut: 180, droite: 335, bas: 440)
        var fautes: [String] = []
        // NOAACalculator, toutes les demi-heures, sauf aux pôles mêmes.
        for j in v.extremes {
            for (k, attendu) in j.hauteurs.enumerated() {
                let t = Self.minuitUtc(j.date) + Int64(k) * 30 * 60_000
                let p = Soleil.position(millis: t, latitude: j.lat, longitude: j.lon)
                if abs(p.hauteur - attendu) > Self.tolerance(t) {
                    fautes.append("\(j.lieu) \(j.date) +\(k * 30) min : \(p.hauteur) au lieu de \(attendu)")
                }
            }
        }
        #expect(fautes.isEmpty, "\(fautes.prefix(20).joined(separator: "\n"))")
        // Toutes les dix minutes, les pôles compris : tout reste fini et borné, et le ciel qui en sort se calcule et
        // se place.
        let lieux: [(String, Double, Double)] = [
            ("Tromsø", 69.649, 18.955), ("Longyearbyen", 78.223, 15.647), ("Alert", 82.501, -62.348),
            ("pôle Nord", 90, 0), ("pôle Sud", -90, 0), ("McMurdo", -77.846, 166.676), ("Ushuaia", -54.802, -68.303),
            ("ligne de changement de date", 0, 180), ("et de l'autre côté", 0, -180),
        ]
        for (nom, lat, lon) in lieux {
            for date in ["2026-06-21", "2026-12-21", "2026-03-20", "1970-01-01", "2099-12-31"] {
                for k in 0..<(24 * 6) {
                    let t = Self.minuitUtc(date) + Int64(k) * 10 * 60_000
                    let p = Soleil.position(millis: t, latitude: lat, longitude: lon)
                    valide(p, "\(nom) \(date) +\(k * 10) min")
                    let etat = EtatCiel.de(p, jourHebreu: 15)
                    _ = CielContinu.brutes(etat.hauteur, matin: etat.matin)
                    _ = PlanCiel.arc(progres: etat.estSoleil ? etat.progresJour : etat.progresNuit,
                                     hauteur: CielContinu.elevationDessinee(etat.hauteur), jauge: jauge, largeur: 411,
                                     r: 14, couronne: 30, zones: [])
                }
            }
        }
        // Tromsø : la nuit polaire au solstice d'hiver (l'arc du jour est vide), le jour polaire en été.
        let hiver = Soleil.position(millis: Self.minuitUtc("2026-12-21") + 11 * 3_600_000, latitude: 69.649,
                                    longitude: 18.955)
        #expect(hiver.angleLever == 0)
        #expect(!hiver.jour && hiver.hauteur < 0 && hiver.progresJour == 0.5)
        let ete = Soleil.position(millis: Self.minuitUtc("2026-06-21") + 23 * 3_600_000, latitude: 69.649,
                                  longitude: 18.955)
        #expect(ete.angleLever == 180)
        #expect(ete.jour && ete.hauteur > 0 && ete.progresNuit == 0.5)
    }

    // MARK: Sans lieu

    @Test func sansLieuUnSoleilMoyenSurLesHeuresDAvant() {
        #expect(abs(Soleil.parHeure(6.5).hauteur) < 1e-9)
        #expect(abs(Soleil.parHeure(18.5).hauteur) < 1e-9)
        #expect(abs(Soleil.parHeure(12.5).hauteur - 50) < 1e-9)
        #expect(abs(Soleil.parHeure(0.5).hauteur + 50) < 1e-9)
        // L'aube commençait à 5 h et le coucher finissait à 20 h (CielDuJour.parHeure) : le soleil y est vers −19°.
        #expect(abs(Soleil.parHeure(5).hauteur + 19.1) < 0.2)
        #expect(abs(Soleil.parHeure(20).hauteur + 19.1) < 0.2)
        // Le plein jour commençait à 8 h et finissait à 17 h : vers +19°.
        #expect(abs(Soleil.parHeure(8).hauteur - 19.1) < 0.2)
        #expect(abs(Soleil.parHeure(17).hauteur - 19.1) < 0.2)
        #expect(Soleil.parHeure(9).matin && !Soleil.parHeure(15).matin && Soleil.parHeure(3).matin
            && !Soleil.parHeure(22).matin)
        #expect(abs(Soleil.parHeure(6.5).progresJour) < 1e-9)
        #expect(abs(Soleil.parHeure(12.5).progresJour - 0.5) < 1e-9)
        #expect(abs(Soleil.parHeure(18.5).progresJour - 1) < 1e-9)
        #expect(abs(Soleil.parHeure(0.5).progresNuit - 0.5) < 1e-9)
        // Minute par minute sur tout le jour, minuit compris : la hauteur glisse, d'un quart de degré au plus.
        var avant = Soleil.parHeure(23 + 59.0 / 60)
        for m in 0..<(24 * 60) {
            let p = Soleil.parHeure(Double(m) / 60)
            valide(p, "\(m) min")
            #expect(abs(p.hauteur - avant.hauteur) <= 0.25, "\(m) min")
            avant = p
        }
    }
}
