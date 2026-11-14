import Foundation
import Testing
@testable import Coeur

/// ChabbatAlerteTest d'Android, porté : « Chabbat dans 3 h » (13/10), trois heures avant l'allumage du
/// vendredi qui vient. Puis ce que `Tests/Vecteurs/rappels.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursRappels.kt), dit de `ChabbatAlerte.prochaine` : des semaines entières à pas
/// de 30 minutes, l'heure qui change, des allumages qui manquent, dans un autre fuseau, la nuit. Le message
/// se vérifie sur le catalogue exporté (values, values-en et values-iw y sont fr, en et he).
@Suite("Chabbat dans 3 h")
struct ChabbatAlerteTests {

    private static let jerusalem: Fuseau = {
        guard let fuseau = Fuseau("Asia/Jerusalem") else { preconditionFailure("le fuseau Asia/Jerusalem manque") }
        return fuseau
    }()

    private static func allumage(_ date: JourCivil) -> DateHeureZonee? {
        DateHeureZonee(DateHeure(date, heure: 17, minute: 45), fuseau: jerusalem)
    }

    private func le(_ jour: String, _ heure: Int, _ minute: Int) -> DateHeureZonee {
        DateHeureZonee(DateHeure(JourCivil.du(jour), heure: heure, minute: minute), fuseau: Self.jerusalem)
    }

    @Test func leMardiLAlerteEstVendrediTroisHeuresAvantLAllumage() {
        let alerte = ChabbatAlerte.prochaine(maintenant: le("2026-10-13", 9, 0), allumage: Self.allumage)
        let attendue = le("2026-10-16", 14, 45)
        #expect(alerte == attendue)
    }

    @Test func leVendrediAvantLAlerteCEstCeVendrediApresLeSuivant() {
        let avant = ChabbatAlerte.prochaine(maintenant: le("2026-10-16", 10, 0), allumage: Self.allumage)
        let ceVendredi = le("2026-10-16", 14, 45)
        #expect(avant == ceVendredi)
        let apres = ChabbatAlerte.prochaine(maintenant: le("2026-10-16", 15, 0), allumage: Self.allumage)
        let leSuivant = le("2026-10-23", 14, 45)
        #expect(apres == leSuivant)
    }

    @Test func sansHeureDAllumageRienNEstProgramme() {
        let alerte = ChabbatAlerte.prochaine(maintenant: le("2026-10-13", 9, 0)) { _ in nil }
        #expect(alerte == nil)
    }

    @Test func leMessageEstDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in ["chabbat_alerte_titre", "chabbat_alerte_texte"] {
                let present = chaines[cle] != nil
                #expect(present, "\(langue) : \(cle)")
            }
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable { let avanceHeures: Int }
        /// `allumages` : l'heure d'allumage (millisecondes Unix, dans `fuseauAllumage`) de chaque jour à
        /// partir de `premierJour`, nil quand il n'y en a pas ; `ecarts` : pour chaque « maintenant », de
        /// `debut` en `nombre` pas de `pas` minutes, l'écart en minutes jusqu'à l'alerte (nil : aucune).
        struct Scenario: Decodable {
            let nom: String
            let fuseauMaintenant: String
            let fuseauAllumage: String
            let premierJour: String
            let allumages: [Int64?]
            let debut: Int64
            let pas: Int
            let nombre: Int
            let ecarts: [Int?]
        }
        struct Cas: Decodable {
            let scenario: String
            let fuseauMaintenant: String
            let maintenant: Int64
            let resultat: Int64?
            let civile: String?
        }
        let constantes: Constantes
        let chabbatAlerte: [Scenario]
        let chabbatAlerteCas: [Cas]
    }

    private static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/rappels.json"))
    }

    /// Les heures d'allumage d'un scénario, jour par jour, dans `fuseau` ; un jour absent n'a pas d'allumage.
    private static func table(_ s: Vecteurs.Scenario, fuseau: Fuseau) -> [JourCivil: DateHeureZonee] {
        let premier = JourCivil.du(s.premierJour)
        var table: [JourCivil: DateHeureZonee] = [:]
        for (rang, millis) in s.allumages.enumerated() {
            if let millis { table[premier.plus(jours: rang)] = DateHeureZonee(millis: millis, fuseau: fuseau) }
        }
        return table
    }

    private static func ecrit(_ valeur: Int?) -> String {
        valeur.map { String($0) } ?? "nil"
    }

    @Test func lAvanceEstCelleDAndroid() throws {
        let avance = ChabbatAlerte.avanceHeures
        let attendue = try Self.vecteurs().constantes.avanceHeures
        #expect(avance == attendue)
    }

    @Test func chaqueDemiHeureDesSemainesRepondCommeAndroid() throws {
        var fautes: [String] = []
        var cas = 0
        var alertes = 0
        for s in try Self.vecteurs().chabbatAlerte {
            let fuseau = try #require(Fuseau(s.fuseauMaintenant), "fuseau « \(s.fuseauMaintenant) » inconnu")
            let fuseauAllumage = try #require(Fuseau(s.fuseauAllumage), "fuseau « \(s.fuseauAllumage) » inconnu")
            let table = Self.table(s, fuseau: fuseauAllumage)
            guard s.ecarts.count == s.nombre else {
                fautes.append("\(s.nom) : \(s.ecarts.count) écarts pour \(s.nombre) instants")
                continue
            }
            for k in 0..<s.nombre {
                let maintenant = DateHeureZonee(millis: s.debut + Int64(k) * Int64(s.pas) * 60_000, fuseau: fuseau)
                let alerte = ChabbatAlerte.prochaine(maintenant: maintenant) { table[$0] }
                cas += 1
                var ecart: Int?
                if let alerte {
                    alertes += 1
                    let ms = alerte.millis - maintenant.millis
                    if ms % 60_000 != 0 || alerte.fuseau.identifiant != s.fuseauAllumage {
                        fautes.append("\(s.nom), \(maintenant) : \(alerte) ne tombe pas sur la minute ou n'est pas dans \(s.fuseauAllumage)")
                    }
                    ecart = Int(ms / 60_000)
                }
                if ecart != s.ecarts[k] {
                    fautes.append("\(s.nom), \(maintenant) : \(Self.ecrit(ecart)) min au lieu de \(Self.ecrit(s.ecarts[k]))")
                }
            }
        }
        let resume = fautes.prefix(20).joined(separator: " ; ")
        let aucune = fautes.isEmpty
        #expect(aucune, "\(fautes.count) écarts : \(resume)")
        #expect(cas == 154 * 48)
        #expect(alertes > 0)
    }

    /// ChabbatAlerteTest, puis l'alerte à la milliseconde près : à l'instant même, c'est la semaine suivante.
    @Test func lesCasALaMillisecondeRepondentCommeAndroid() throws {
        let v = try Self.vecteurs()
        var tables: [String: [JourCivil: DateHeureZonee]] = [:]
        for s in v.chabbatAlerte {
            let fuseauAllumage = try #require(Fuseau(s.fuseauAllumage), "fuseau « \(s.fuseauAllumage) » inconnu")
            tables[s.nom] = Self.table(s, fuseau: fuseauAllumage)
        }
        for c in v.chabbatAlerteCas {
            let fuseau = try #require(Fuseau(c.fuseauMaintenant), "fuseau « \(c.fuseauMaintenant) » inconnu")
            let table = try #require(tables[c.scenario], "scénario « \(c.scenario) » inconnu")
            let maintenant = DateHeureZonee(millis: c.maintenant, fuseau: fuseau)
            let alerte = ChabbatAlerte.prochaine(maintenant: maintenant) { table[$0] }
            let millis = alerte?.millis
            #expect(millis == c.resultat, "\(c.scenario), \(maintenant) : l'instant")
            let civile = alerte?.civile.description
            #expect(civile == c.civile, "\(c.scenario), \(maintenant) : l'heure civile")
        }
    }
}
