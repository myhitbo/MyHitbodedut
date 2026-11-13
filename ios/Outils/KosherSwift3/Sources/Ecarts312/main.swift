// Les quinze zmanim du profil et l'allumage par KosherSwift 3.1.2, sous les noms de l'ère 3.x
// (PORTAGE.md § 5.1), comparés à web/test/vecteurs_kosherjava.json (KosherJava 2.5.0).
// Usage : swift run Ecarts312 <chemin du fichier de vecteurs>

import Foundation
import KosherSwift

struct Cle: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

struct Ligne: Decodable {
    let lieu: String, lat: Double, lon: Double, fuseau: String, date: String
    let valeurs: [String: String]

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        lieu = try c.decode(String.self, forKey: Cle(stringValue: "lieu"))
        lat = try c.decode(Double.self, forKey: Cle(stringValue: "lat"))
        lon = try c.decode(Double.self, forKey: Cle(stringValue: "lon"))
        fuseau = try c.decode(String.self, forKey: Cle(stringValue: "fuseau"))
        date = try c.decode(String.self, forKey: Cle(stringValue: "date"))
        var v: [String: String] = [:]
        for k in c.allKeys where !["lieu", "lat", "lon", "fuseau", "date"].contains(k.stringValue) {
            v[k.stringValue] = try c.decode(String.self, forKey: k)
        }
        valeurs = v
    }
}

struct Fichier: Decodable { let zmanim: [Ligne] }

func calendrier(_ l: Ligne) -> ComprehensiveZmanimCalendar {
    let fuseau = TimeZone(identifier: l.fuseau)!
    let geo = GeoLocation(locationName: l.lieu, latitude: l.lat, longitude: l.lon, elevation: 0, timeZone: fuseau)
    let c = ComprehensiveZmanimCalendar(geoLocation: geo)
    let p = l.date.split(separator: "-").map { Int($0)! }
    c.localDate = LocalDate(year: p[0], month: p[1], day: p[2])
    c.useElevation = false
    c.useAstronomicalChatzos = true
    c.astronomicalCalculator = NOAACalculator()
    c.candleLightingOffset = 18
    return c
}

func valeur(_ c: ComprehensiveZmanimCalendar, _ cle: String) -> Date? {
    switch cle {
    case "alot": return c.getAlos16Point1Degrees()
    case "misheyakir": return c.getMisheyakir11Point5Degrees()
    case "netz": return c.getSeaLevelSunrise()
    case "szks_mga": return c.getSofZmanShmaMGA72Minutes()
    case "szks_gra": return c.getSofZmanShmaGRA()
    case "szt_mga": return c.getSofZmanTfilaMGA72Minutes()
    case "szt_gra": return c.getSofZmanTfilaGRA()
    case "chatsot": return c.getChatzosHayom()
    case "minha_gedola": return c.getMinchaGedolaGRA()
    case "minha_ketana": return c.getMinchaKetanaGRA()
    case "plag": return c.getPlagHaminchaGRA()
    case "chkia": return c.getSeaLevelSunset()
    case "tset": return c.getTzaisGeonim8Point5Degrees()
    case "tset_rt": return c.getTzais72Minutes()
    case "chatsot_layla": return c.getSolarMidnight()
    case "allumage": return c.getCandleLighting()
    default: return nil
    }
}

let chemin = CommandLine.arguments.dropFirst().first ?? "web/test/vecteurs_kosherjava.json"
let fichier = try JSONDecoder().decode(Fichier.self, from: Data(contentsOf: URL(fileURLWithPath: chemin)))
let lecteur = ISO8601DateFormatter()
lecteur.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

var parCle: [String: (max: Double, au: String, horsTolerance: Int)] = [:]
var desaccordsAbsent: [String] = []
var total = 0
for l in fichier.zmanim {
    let c = calendrier(l)
    for (cle, attendu) in l.valeurs.sorted(by: { $0.key < $1.key }) {
        total += 1
        let calcule = valeur(c, cle)
        let ou = "\(l.lieu) \(l.date) \(cle)"
        if attendu == "ABSENT" || calcule == nil {
            if (attendu == "ABSENT") != (calcule == nil) {
                desaccordsAbsent.append("\(ou) : attendu \(attendu), calculé \(calcule.map { "\($0)" } ?? "ABSENT")")
            }
            continue
        }
        let ecart = abs(calcule!.timeIntervalSince(lecteur.date(from: attendu)!))
        var s = parCle[cle] ?? (0, "", 0)
        if ecart > s.max { s.max = ecart; s.au = "\(l.lieu) \(l.date)" }
        if ecart > 1 { s.horsTolerance += 1 }
        parCle[cle] = s
    }
}

print("KosherSwift 3.1.2 contre KosherJava 2.5.0 : \(fichier.zmanim.count) lignes, \(total) valeurs")
print("| zman | écart maximal | où | au-delà d'une seconde |")
print("| --- | --- | --- | --- |")
for (cle, s) in parCle.sorted(by: { $0.key < $1.key }) {
    print("| \(cle) | \(String(format: "%.3f", s.max)) s | \(s.au) | \(s.horsTolerance) |")
}
print("Désaccords sur ABSENT : \(desaccordsAbsent.count)")
desaccordsAbsent.forEach { print("- \($0)") }
