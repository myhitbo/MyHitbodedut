import Foundation
import KosherSwift
import Testing
@testable import Coeur

/// Les zmanim, portés de ZmanimTest.kt, et jugés par les vecteurs d'Android.
///
/// - vecteurs : `web/test/vecteurs_kosherjava.json`, produits par le code Android lui-même
///   (KosherJava 2.5.0) : les quinze zmanim et l'allumage, à une seconde, `ABSENT` exact ;
/// - astronomie : la NOAA (2 s, 20 s pour 'hatsot) et PyEphem (60 s), comme sur Android ;
/// - structure : ordre de la journée, heures saisonnières, changement d'heure, cercle polaire.
@Suite("Zmanim")
struct ZmanimTests {

    // MARK: Vecteurs d'Android, à la seconde

    @Test func vecteursKosherJavaAUneSeconde() throws {
        let fichier = try JSONDecoder().decode(
            FichierVecteurs.self, from: Depot.donnees("web/test/vecteurs_kosherjava.json"))
        #expect(fichier.moteur == "KosherJava 2.5.0, NOAACalculator")
        #expect(fichier.zmanim.count == 35)
        var comparees = 0, absents = 0
        var pire = (ecart: 0.0, ou: "")
        for ligne in fichier.zmanim {
            let lieu = Zmanim.Lieu(nom: ligne.lieu, latitude: ligne.lat, longitude: ligne.lon, fuseau: ligne.fuseau)
            let date = try #require(JourCivil(iso: ligne.date))
            let calcules = Zmanim.jour(lieu: lieu, date: date) + [Zmanim.allumage(lieu: lieu, date: date, minutes: 18)]
            #expect(Set(calcules.map(\.cle)) == Set(ligne.valeurs.keys), "\(ligne.lieu) \(ligne.date)")
            for z in calcules {
                let ou = "\(ligne.lieu) \(ligne.date) \(z.cle)"
                let attendu = try #require(ligne.valeurs[z.cle], "\(ou) absent du fichier")
                if attendu == "ABSENT" {
                    #expect(z.statut == .absent, "\(ou) : attendu ABSENT, calculé \(z.statut)")
                    absents += 1
                    continue
                }
                let instantAttendu = try #require(instantISO(attendu), "\(ou) : « \(attendu) » illisible")
                guard z.statut == .ok, let instant = z.instant else {
                    Issue.record("\(ou) : attendu \(attendu), calculé \(z.statut)")
                    continue
                }
                let ecart = abs(instant.timeIntervalSince(instantAttendu))
                #expect(ecart <= 1, "\(ou) : \(instant) contre \(attendu), \(ecart) s")
                if ecart > pire.ecart { pire = (ecart, ou) }
                comparees += 1
            }
        }
        #expect(comparees + absents == 35 * 16)
        print("VecteursZmanim : \(comparees) instants et \(absents) ABSENT ; écart maximal "
              + "\(Int((pire.ecart * 1000).rounded())) ms (\(pire.ou))")
    }

    // MARK: Astronomie

    @Test func concordeAvecPyEphemAUneMinute() throws {
        let pire = try comparerAuxHeuresLocales("android/app/src/test/resources/zmanim_reference_pyephem.json",
                                                minimum: 20) { _ in 60 }
        print("PyEphem : écart maximal \(pire)")
    }

    @Test func concordeAvecLesFormulesDeLaNOAA() throws {
        let date = try #require(JourCivil(iso: "2026-10-10"))
        let c = try #require(Zmanim.calendrier(Lieux.paris, date))
        let noaa = try #require(c.getAstronomicalCalculator() as? NOAACalculator)
        #expect(noaa.getCalculatorName() == "US National Oceanic and Atmospheric Administration Algorithm")
        // 'Hatsot : KosherJava évalue l'équation du temps à JD − 0,5, la traduction Python
        // (tools/zmanim_reference_noaa.py) à l'heure de midi. Écart mesuré sur Android : 15 s au plus.
        let pire = try comparerAuxHeuresLocales("android/app/src/test/resources/zmanim_reference_noaa.json",
                                                minimum: 28) { $0 == "chatsot" ? 20 : 2 }
        print("NOAA : écart maximal \(pire)")
    }

    /// Compare netz, chkia, alot, misheyakir, tset et 'hatsot aux heures locales d'un fichier
    /// de référence, en secondes entières comme `Duration.between(...).seconds` d'Android.
    private func comparerAuxHeuresLocales(_ chemin: String, minimum: Int,
                                          tolerance: (String) -> Int) throws -> String {
        let reference = try JSONDecoder().decode([[String: String]].self, from: Depot.donnees(chemin))
        #expect(reference.count >= minimum)
        var pire = (ecart: 0.0, ou: "")
        for r in reference {
            let nom = try #require(r["lieu"]), iso = try #require(r["date"])
            let lieu = try #require(Lieux.parNom[nom], "lieu inconnu : \(nom)")
            let fuseau = try #require(TimeZone(identifier: lieu.fuseau))
            let date = try #require(JourCivil(iso: iso))
            let z = Dictionary(uniqueKeysWithValues: Zmanim.jour(lieu: lieu, date: date).map { ($0.cle, $0) })
            for cle in ["netz", "chkia", "alot", "misheyakir", "tset", "chatsot"] {
                let attendu = try #require(r[cle].flatMap(secondesDuJour), "\(nom) \(iso) \(cle)")
                let instant = try #require(z[cle]?.instant, "\(nom) \(iso) \(cle) absent")
                let ecart = abs(heureLocale(instant, fuseau) - attendu)
                let admis = tolerance(cle)
                #expect(Int(ecart) <= admis, "\(nom) \(iso) \(cle) : \(ecart) s")
                if ecart > pire.ecart { pire = (ecart, "\(nom) \(iso) \(cle)") }
            }
        }
        return "\(Int(pire.ecart.rounded())) s (\(pire.ou))"
    }

    // MARK: Structure

    @Test func laJourneeEstDansLOrdrePartoutEtEnToutesSaisons() throws {
        let ordre = ["alot", "misheyakir", "netz", "szks_mga", "szks_gra", "szt_mga", "szt_gra",
                     "chatsot", "minha_gedola", "minha_ketana", "plag", "chkia", "tset", "tset_rt", "chatsot_layla"]
        #expect(Zmanim.profil.map(\.cle) == ordre)
        for lieu in [Lieux.jerusalem, Lieux.paris, Lieux.newYork, Lieux.melbourne] {
            let fuseau = try #require(TimeZone(identifier: lieu.fuseau))
            for iso in ["2026-03-29", "2026-06-21", "2026-10-25", "2026-12-21"] {
                let date = try #require(JourCivil(iso: iso))
                let z = Zmanim.jour(lieu: lieu, date: date)
                #expect(z.allSatisfy { $0.statut == .ok }, "\(lieu.nom) \(iso)")
                let instants = z.compactMap(\.instant)
                #expect(instants == instants.sorted(), "\(lieu.nom) \(iso)")
                let netz = try #require(z.first { $0.cle == "netz" }?.instant)
                #expect(jourLocal(netz, fuseau) == date, "\(lieu.nom) \(iso)")
                // 'Hatsot de la nuit tombe entre la chki'a et le lever du lendemain.
                let nuit = try #require(z.first { $0.cle == "chatsot_layla" }?.instant)
                let chkia = try #require(z.first { $0.cle == "chkia" }?.instant)
                let demain = Zmanim.jour(lieu: lieu, date: date.plus(jours: 1))
                let lever = try #require(demain.first { $0.cle == "netz" }?.instant)
                #expect(nuit > chkia && nuit < lever, "\(lieu.nom) \(iso)")
            }
        }
    }

    @Test func heuresSaisonnieresDuGraEtDuMGA() throws {
        let z = try zmanim(Lieux.paris, "2026-10-10")
        let netz = try #require(z["netz"]?.instant), chkia = try #require(z["chkia"]?.instant)
        let gra = netz.addingTimeInterval(chkia.timeIntervalSince(netz) / 4)
        let szksGra = try #require(z["szks_gra"]?.instant)
        #expect(abs(szksGra.timeIntervalSince(gra)) <= 1)
        // MGA : de l'aube 72 minutes avant le lever à 72 minutes après le coucher.
        let aube = netz.addingTimeInterval(-72 * 60), nuit = chkia.addingTimeInterval(72 * 60)
        let mga = aube.addingTimeInterval(nuit.timeIntervalSince(aube) / 4)
        let szksMga = try #require(z["szks_mga"]?.instant)
        #expect(abs(szksMga.timeIntervalSince(mga)) <= 1)
    }

    @Test func changementDHeureLeLeverResteASaPlace() throws {
        // Paris, 25/10/2026 : on recule d'une heure dans la nuit.
        let paris = try #require(TimeZone(identifier: "Europe/Paris"))
        let z24 = try zmanim(Lieux.paris, "2026-10-24"), z25 = try zmanim(Lieux.paris, "2026-10-25")
        let samedi = try #require(z24["netz"]?.instant)
        let dimanche = try #require(z25["netz"]?.instant)
        #expect(paris.secondsFromGMT(for: samedi) == 2 * 3600)
        #expect(paris.secondsFromGMT(for: dimanche) == 1 * 3600)
        let minutes = Int((heureLocale(dimanche, paris) - heureLocale(samedi, paris)) / 60)
        #expect((-60 ... -55).contains(minutes), "\(samedi) → \(dimanche)")
    }

    @Test func soleilDeMinuitEtNuitPolaireAbsentJamaisEnErreur() throws {
        let ete = try zmanim(Lieux.tromso, "2026-06-21")
        for cle in ["netz", "chkia", "szks_gra", "plag"] {
            #expect(ete[cle]?.statut == .absent, "\(cle)")
        }
        let hiver = try zmanim(Lieux.tromso, "2026-12-21")
        #expect(hiver["netz"]?.statut == .absent)
        // L'aube à 16,1° existe en décembre à Tromsø : le soleil passe sous l'horizon sans remonter.
        #expect(hiver["alot"]?.statut == .ok)
        for z in Array(ete.values) + Array(hiver.values) {
            #expect(z.statut != .erreur, "\(z.cle)")
        }
    }

    @Test func allumageDixHuitMinutesAvantLaChkia() throws {
        let date = try #require(JourCivil(iso: "2026-10-16"))
        let jour = Zmanim.jour(lieu: Lieux.jerusalem, date: date)
        let chkia = try #require(jour.first { $0.cle == "chkia" }?.instant)
        let allumage = Zmanim.allumage(lieu: Lieux.jerusalem, date: date, minutes: 18)
        let instant = try #require(allumage.instant)
        #expect(abs(chkia.timeIntervalSince(instant) - 18 * 60) < 0.001)
        #expect(allumage.methode.parametres == "18")
        #expect(Zmanim.allumages.contains(Zmanim.allumageDefaut))
    }

    @Test func unFuseauInconnuEstUneErreurPasUnAbsent() throws {
        let lieu = Zmanim.Lieu(nom: "Nulle part", latitude: 0, longitude: 0, fuseau: "Mars/Olympus_Mons")
        let date = try #require(JourCivil(iso: "2026-10-16"))
        #expect(Zmanim.jour(lieu: lieu, date: date).allSatisfy { $0.statut == .erreur })
        #expect(Zmanim.allumage(lieu: lieu, date: date, minutes: 18).statut == .erreur)
    }

    // MARK: Outils

    private func zmanim(_ lieu: Zmanim.Lieu, _ iso: String) throws -> [String: Zmanim.Zman] {
        let date = try #require(JourCivil(iso: iso))
        return Dictionary(uniqueKeysWithValues: Zmanim.jour(lieu: lieu, date: date).map { ($0.cle, $0) })
    }
}

/// L'heure locale d'un instant, en secondes depuis minuit (fractions comprises).
private func heureLocale(_ instant: Date, _ fuseau: TimeZone) -> Double {
    var gregorien = Calendar(identifier: .gregorian)
    gregorien.timeZone = fuseau
    let c = gregorien.dateComponents([.hour, .minute, .second, .nanosecond], from: instant)
    let h: Int = c.hour ?? 0, m: Int = c.minute ?? 0, s: Int = c.second ?? 0, ns: Int = c.nanosecond ?? 0
    let entieres: Int = h * 3600 + m * 60 + s
    return Double(entieres) + Double(ns) / 1e9
}

private func jourLocal(_ instant: Date, _ fuseau: TimeZone) -> JourCivil? {
    var gregorien = Calendar(identifier: .gregorian)
    gregorien.timeZone = fuseau
    let c = gregorien.dateComponents([.year, .month, .day], from: instant)
    return JourCivil(annee: c.year ?? 0, mois: c.month ?? 0, jour: c.day ?? 0)
}

/// « 2026-01-15T03:23:04.722Z » → l'instant. Écrit à la main : sous Linux,
/// ISO8601DateFormatter ne lit pas les fractions de seconde.
private func instantISO(_ texte: String) -> Date? {
    guard texte.hasSuffix("Z"), let t = texte.firstIndex(of: "T"),
          let jour = JourCivil(iso: String(texte[..<t])) else { return nil }
    let p = texte[texte.index(after: t)..<texte.index(before: texte.endIndex)].split(separator: ":")
    guard p.count == 3, let h = Int(p[0]), let m = Int(p[1]), let s = Double(p[2]) else { return nil }
    return Date(timeIntervalSince1970: Double(jour.jourJulien - 2_440_588) * 86_400 + Double(h * 3600 + m * 60) + s)
}

/// « 06:39:29 » → 23 969.
private func secondesDuJour(_ texte: String) -> Double? {
    let parties = texte.split(separator: ":").compactMap { Int($0) }
    guard parties.count == 3 else { return nil }
    return Double(parties[0] * 3600 + parties[1] * 60 + parties[2])
}

/// `web/test/vecteurs_kosherjava.json` : seule la partie « zmanim » est lue ici.
private struct FichierVecteurs: Decodable {
    let moteur: String
    let zmanim: [LigneVecteur]
}

private struct LigneVecteur: Decodable {
    let lieu: String, lat: Double, lon: Double, fuseau: String, date: String
    /// Clé du zman → instant ISO ou « ABSENT ».
    let valeurs: [String: String]

    private struct Cle: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        lieu = try c.decode(String.self, forKey: Cle(stringValue: "lieu"))
        lat = try c.decode(Double.self, forKey: Cle(stringValue: "lat"))
        lon = try c.decode(Double.self, forKey: Cle(stringValue: "lon"))
        fuseau = try c.decode(String.self, forKey: Cle(stringValue: "fuseau"))
        date = try c.decode(String.self, forKey: Cle(stringValue: "date"))
        let meta: Set<String> = ["lieu", "lat", "lon", "fuseau", "date"]
        var v: [String: String] = [:]
        for cle in c.allKeys where !meta.contains(cle.stringValue) {
            v[cle.stringValue] = try c.decode(String.self, forKey: cle)
        }
        valeurs = v
    }
}
