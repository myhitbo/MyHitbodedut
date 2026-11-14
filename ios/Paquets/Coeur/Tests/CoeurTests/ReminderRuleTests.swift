import Foundation
import Testing
@testable import Coeur

/// ReminderRuleTest d'Android, porté : le calendrier raisonne en date civile, la fête commence au
/// coucher du soleil ; sans ville réglée, on ne calcule aucun coucher, et la veille d'un jour chômé plus
/// aucun rappel ne sonne après midi. Puis ce que `Tests/Vecteurs/rappels.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursRappels.kt), dit de `shouldNotify` et de `prochainDeclenchement`.
@Suite("Rappel : faut-il sonner")
struct ReminderRuleTests {

    private func h(_ heure: Int) -> Int { heure * 60 }

    @Test func jourOrdinaireLeRappelPasse() {
        let sonne = ReminderRule.shouldNotify(nowMinutes: h(19), doneToday: false, todayIsRestDay: false,
                                              tomorrowIsRestDay: false, sunsetMinutes: nil)
        #expect(sonne)
    }

    @Test func pratiqueDejaFaitePasDeRappel() {
        let sonne = ReminderRule.shouldNotify(nowMinutes: h(7), doneToday: true, todayIsRestDay: false,
                                              tomorrowIsRestDay: false, sunsetMinutes: nil)
        #expect(!sonne)
    }

    @Test func jourChomePasDeRappel() {
        let sonne = ReminderRule.shouldNotify(nowMinutes: h(7), doneToday: false, todayIsRestDay: true,
                                              tomorrowIsRestDay: false, sunsetMinutes: nil)
        #expect(!sonne)
    }

    @Test func veilleDeFeteSansVilleRienApresMidi() {
        let onzeHeures = ReminderRule.shouldNotify(nowMinutes: h(11), doneToday: false, todayIsRestDay: false,
                                                   tomorrowIsRestDay: true, sunsetMinutes: nil)
        #expect(onzeHeures)
        let midi = ReminderRule.shouldNotify(nowMinutes: h(12), doneToday: false, todayIsRestDay: false,
                                             tomorrowIsRestDay: true, sunsetMinutes: nil)
        #expect(!midi)
        let soir = ReminderRule.shouldNotify(nowMinutes: h(19), doneToday: false, todayIsRestDay: false,
                                             tomorrowIsRestDay: true, sunsetMinutes: nil)
        #expect(!soir)
    }

    @Test func veilleDeFeteAvecVilleLeCoucherDuSoleilFaitFoi() {
        let sunset = 18 * 60 + 40
        let avant = ReminderRule.shouldNotify(nowMinutes: h(17), doneToday: false, todayIsRestDay: false,
                                              tomorrowIsRestDay: true, sunsetMinutes: sunset)
        #expect(avant)
        let auCoucher = ReminderRule.shouldNotify(nowMinutes: sunset, doneToday: false, todayIsRestDay: false,
                                                  tomorrowIsRestDay: true, sunsetMinutes: sunset)
        #expect(!auCoucher)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let noSunsetCutoffMinutes: Int
            let minutesParJour: Int
        }
        struct Silence: Decodable {
            let doneToday: Bool
            let todayIsRestDay: Bool
            let tomorrowIsRestDay: Bool
            let sunsetMinutes: Int?
            let maintenants: [Int]
            let resultats: [Bool]
        }
        /// Des « maintenant » de `debut` (millisecondes Unix) en `nombre` pas de `pas` minutes, et pour
        /// chacun l'écart en minutes jusqu'au rappel rendu (nil : aucun).
        struct Balayage: Decodable {
            let fuseau: String
            let heures: [Int]
            let debut: Int64
            let pas: Int
            let nombre: Int
            let ecarts: [Int?]
        }
        struct Cas: Decodable {
            let fuseau: String
            let maintenant: Int64
            let heures: [Int]
            let resultat: Int64?
            let civile: String?
            let decalage: Int?
        }

        let constantes: Constantes
        let shouldNotify: [Silence]
        let prochainDeclenchement: [Balayage]
        let prochainDeclenchementCas: [Cas]
    }

    private static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/rappels.json"))
    }

    private static func ecrit(_ valeur: Int?) -> String {
        valeur.map { String($0) } ?? "nil"
    }

    @Test func lesConstantesSontCellesDAndroid() throws {
        let c = try Self.vecteurs().constantes
        let midi = ReminderRule.noSunsetCutoffMinutes
        #expect(midi == c.noSunsetCutoffMinutes)
        let jour = ReminderRule.minutesParJour
        #expect(jour == c.minutesParJour)
    }

    /// Toutes les combinaisons des trois booléens, dix couchers du soleil (ou aucun), seize minutes
    /// autour de midi et du coucher.
    @Test func shouldNotifyRepondCommeAndroid() throws {
        var cas = 0
        for s in try Self.vecteurs().shouldNotify {
            let nombre = s.resultats.count
            #expect(nombre == s.maintenants.count)
            for (rang, maintenant) in s.maintenants.enumerated() where rang < nombre {
                let sonne = ReminderRule.shouldNotify(nowMinutes: maintenant, doneToday: s.doneToday,
                                                      todayIsRestDay: s.todayIsRestDay,
                                                      tomorrowIsRestDay: s.tomorrowIsRestDay,
                                                      sunsetMinutes: s.sunsetMinutes)
                let attendu = s.resultats[rang]
                let coucher = Self.ecrit(s.sunsetMinutes)
                #expect(sonne == attendu,
                        "fait \(s.doneToday), repos \(s.todayIsRestDay), veille \(s.tomorrowIsRestDay), coucher \(coucher), à \(maintenant)")
                cas += 1
            }
        }
        #expect(cas == 8 * 10 * 16)
    }

    /// Deux ans de « maintenant » à grands pas dans quatre fuseaux, et chaque nuit où l'heure y change,
    /// à pas de 10 minutes : l'instant rendu, à la minute, et son fuseau.
    @Test func prochainDeclenchementRepondCommeAndroid() throws {
        var fautes: [String] = []
        var cas = 0
        var nuits = 0
        for b in try Self.vecteurs().prochainDeclenchement {
            let fuseau = try #require(Fuseau(b.fuseau), "fuseau « \(b.fuseau) » inconnu")
            guard b.ecarts.count == b.nombre else {
                fautes.append("\(b.fuseau) \(b.heures) : \(b.ecarts.count) écarts pour \(b.nombre) instants")
                continue
            }
            if b.pas == 10 { nuits += 1 }
            for k in 0..<b.nombre {
                let maintenant = DateHeureZonee(millis: b.debut + Int64(k) * Int64(b.pas) * 60_000, fuseau: fuseau)
                let rappel = ReminderRule.prochainDeclenchement(maintenant: maintenant, heures: b.heures)
                cas += 1
                var ecart: Int?
                if let rappel {
                    let ms = rappel.millis - maintenant.millis
                    if ms % 60_000 != 0 || rappel.fuseau != fuseau {
                        fautes.append("\(maintenant) \(b.heures) : \(rappel) ne tombe pas sur la minute ou change de fuseau")
                    }
                    ecart = Int(ms / 60_000)
                }
                if ecart != b.ecarts[k] {
                    fautes.append("\(maintenant) \(b.heures) : \(Self.ecrit(ecart)) min au lieu de \(Self.ecrit(b.ecarts[k]))")
                }
            }
        }
        let resume = fautes.prefix(20).joined(separator: " ; ")
        let aucune = fautes.isEmpty
        #expect(aucune, "\(fautes.count) écarts : \(resume)")
        #expect(cas > 10_000)
        #expect(nuits >= 100, "les vecteurs doivent couvrir les nuits où l'heure change")
    }

    /// FiabiliteTest, puis à la milliseconde près, dans l'heure qui manque et dans celle qui double.
    @Test func lesCasALaMillisecondeRepondentCommeAndroid() throws {
        for c in try Self.vecteurs().prochainDeclenchementCas {
            let fuseau = try #require(Fuseau(c.fuseau), "fuseau « \(c.fuseau) » inconnu")
            let maintenant = DateHeureZonee(millis: c.maintenant, fuseau: fuseau)
            let ou = "\(maintenant), heures \(c.heures)"
            let rappel = ReminderRule.prochainDeclenchement(maintenant: maintenant, heures: c.heures)
            let millis = rappel?.millis
            #expect(millis == c.resultat, "\(ou) : l'instant")
            let civile = rappel?.civile.description
            #expect(civile == c.civile, "\(ou) : l'heure civile")
            let decalage = rappel.map { fuseau.decalage(millis: $0.millis) }
            #expect(decalage == c.decalage, "\(ou) : le décalage")
            let memeFuseau = rappel.map { $0.fuseau == fuseau } ?? true
            #expect(memeFuseau, "\(ou) : le fuseau")
        }
    }
}

/// Les quatre cas du rappel de FiabiliteTest d'Android (revue du 29/09) : l'heure du prochain rappel se
/// calcule en heure murale, jour par jour, et non en minutes ajoutées à l'instant présent. Les autres cas
/// de FiabiliteTest sont ceux d'autres règles (la séance, la journée) ou lisent le code d'Android.
@Suite("Rappel : l'heure du prochain")
struct FiabiliteRappelsTests {

    private static let paris: Fuseau = {
        guard let fuseau = Fuseau("Europe/Paris") else { preconditionFailure("le fuseau Europe/Paris manque") }
        return fuseau
    }()

    private func a(_ jour: String, _ heure: Int, _ minute: Int = 0) -> DateHeureZonee {
        DateHeureZonee(DateHeure(JourCivil.du(jour), heure: heure, minute: minute), fuseau: Self.paris)
    }

    @Test func leProchainRappelUnJourOrdinaire() {
        let maintenant = a("2026-09-29", 6, 30)
        let rappel = ReminderRule.prochainDeclenchement(maintenant: maintenant, heures: [7 * 60])
        let septHeures = a("2026-09-29", 7)
        #expect(rappel == septHeures)
        // Toutes passées : la première du lendemain.
        let soir = a("2026-09-29", 21)
        let lendemain = ReminderRule.prochainDeclenchement(maintenant: soir, heures: [7 * 60, 20 * 60])
        let septHeuresDemain = a("2026-09-30", 7)
        #expect(lendemain == septHeuresDemain)
        let aucun = ReminderRule.prochainDeclenchement(maintenant: maintenant, heures: [])
        #expect(aucun == nil)
    }

    /// Passage à l'heure d'été (29/03/2026 à Paris) : la nuit dure une heure de moins. Ajouter 9 heures
    /// de minutes à 22 h faisait sonner à 8 h.
    @Test func leRappelGardeSonHeureAuPassageALHeureDEte() throws {
        let veille = a("2026-03-28", 22)
        let calcule = ReminderRule.prochainDeclenchement(maintenant: veille, heures: [7 * 60])
        let rappel = try #require(calcule)
        let heure = rappel.civile.heure
        #expect(heure == 7)
        let jour = rappel.civile.jour.jour
        #expect(jour == 29)
        let duree = rappel.millis - veille.millis
        #expect(duree == 8 * 3_600_000)
    }

    /// Retour à l'heure d'hiver (25/10/2026) : la nuit dure une heure de plus.
    @Test func leRappelGardeSonHeureAuRetourALHeureDHiver() throws {
        let veille = a("2026-10-24", 22)
        let calcule = ReminderRule.prochainDeclenchement(maintenant: veille, heures: [7 * 60])
        let rappel = try #require(calcule)
        let heure = rappel.civile.heure
        #expect(heure == 7)
        let duree = rappel.millis - veille.millis
        #expect(duree == 10 * 3_600_000)
    }

    @Test func uneHeureQuiNExistePasCeJourLaEstRepoussee() throws {
        let calcule = ReminderRule.prochainDeclenchement(maintenant: a("2026-03-28", 22), heures: [2 * 60 + 30])
        let rappel = try #require(calcule)
        let jour = rappel.civile.jour.jour
        #expect(jour == 29)
        let heure = rappel.civile.heure
        #expect(heure == 3)
        let minute = rappel.civile.minute
        #expect(minute == 30)
    }
}
