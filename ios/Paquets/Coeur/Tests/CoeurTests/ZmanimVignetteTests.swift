import Foundation
import Testing
@testable import Coeur

/// Les quatre cas des vignettes de VoyageNuitTest d'Android (02/11), portés : le prochain changement des
/// vignettes et la date hébraïque qui change au tsét. Puis ce que `Tests/Vecteurs/vignettes.json`, écrit par
/// la JVM (tools/vecteurs_ios/VecteursVignettes.kt), dit de ZmanimVignette : le prochain changement autour du
/// tsét et de minuit (le téléphone ailleurs, les nuits où l'heure change, un minuit qui manque), le jour
/// hébreu affiché, le début de la fenêtre et sa part écoulée. Les autres cas de VoyageNuitTest sont ceux de
/// la barrière et de la boussole.
@Suite("Vignette : le prochain changement et le jour hébreu")
struct ZmanimVignetteTests {

    private static let paris: Fuseau = {
        guard let fuseau = Fuseau("Europe/Paris") else { preconditionFailure("le fuseau Europe/Paris manque") }
        return fuseau
    }()

    private let d = JourCivil.du("2026-11-02")

    private func le(_ jour: JourCivil, _ heure: Int, _ minute: Int) -> DateHeureZonee {
        DateHeureZonee(DateHeure(jour, heure: heure, minute: minute), fuseau: Self.paris)
    }

    @Test func vignetteChangeALaFinDeChaharit() {
        let maintenant = le(d, 9, 5)
        let finChaharit = le(d, 9, 12)
        let changement = ZmanimVignette.prochainChangement(horaires: [finChaharit, nil, finChaharit.plus(heures: 5)],
                                                           maintenant: maintenant)
        #expect(changement == finChaharit)
    }

    @Test func vignetteAuPlusTardDansDixMinutes() {
        let maintenant = le(d, 13, 0)
        let changement = ZmanimVignette.prochainChangement(horaires: [maintenant.plus(heures: 3), maintenant.plus(heures: -1)],
                                                           maintenant: maintenant)
        let dansDixMinutes = maintenant.plus(minutes: 10)
        #expect(changement == dansDixMinutes)
    }

    @Test func vignetteAMinuitPourLaDate() {
        let maintenant = le(d, 23, 55)
        let changement = ZmanimVignette.prochainChangement(horaires: [], maintenant: maintenant)
        let minuit = DateHeureZonee(DateHeure(d.plus(jours: 1)), fuseau: Self.paris)
        #expect(changement == minuit)
    }

    @Test func dateHebraiqueChangeAuTset() {
        let tset = le(d, 17, 52)
        let lendemain = d.plus(jours: 1)
        let justeAvant = ZmanimVignette.jourHebreuAffiche(maintenant: tset.plus(minutes: -1), tset: tset)
        #expect(justeAvant == d)
        let auTset = ZmanimVignette.jourHebreuAffiche(maintenant: tset, tset: tset)
        #expect(auTset == lendemain)
        let soir = ZmanimVignette.jourHebreuAffiche(maintenant: le(d, 23, 0), tset: tset)
        #expect(soir == lendemain)
        // Sans lieu, minuit.
        let sansLieu = ZmanimVignette.jourHebreuAffiche(maintenant: le(d, 23, 0), tset: nil)
        #expect(sansLieu == d)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// Un instant écrit [millisecondes Unix, fuseau].
        struct Ecrit: Decodable {
            let millis: Int64
            let fuseau: String

            init(from decoder: any Decoder) throws {
                var paire = try decoder.unkeyedContainer()
                millis = try paire.decode(Int64.self)
                fuseau = try paire.decode(String.self)
            }
        }
        /// Un résultat écrit [écart en millisecondes jusqu'au changement, son fuseau].
        struct Resultat: Decodable {
            let ecart: Int64
            let fuseau: String

            init(from decoder: any Decoder) throws {
                var paire = try decoder.unkeyedContainer()
                ecart = try paire.decode(Int64.self)
                fuseau = try paire.decode(String.self)
            }
        }
        /// Des « maintenant » de `debut` en `nombre` pas de `pas` millisecondes, vus de `fuseau`.
        struct Changement: Decodable {
            let fuseau: String
            let fuseauHoraires: String
            let horaires: [Int64?]
            let telephone: Int64?
            let fuseauTelephone: String?
            let debut: Int64
            let pas: Int64
            let nombre: Int
            let resultats: [Resultat]
        }
        struct CasChangement: Decodable {
            let fuseau: String
            let horaires: [Ecrit?]
            let telephone: Int64?
            let fuseauTelephone: String?
            let maintenant: Int64
            let resultat: Int64
            let fuseauResultat: String
            let civile: String
        }
        struct JourAffiche: Decodable {
            let fuseau: String
            let tset: Int64?
            let fuseauTset: String?
            let debut: Int64
            let pas: Int64
            let nombre: Int
            let jours: [String]
        }
        struct Debut: Decodable {
            let priere: String
            let horaires: [String: Int64]
            let resultat: Int64?
        }
        struct Ecoule: Decodable {
            struct Cas: Decodable {
                let debut: Int64?
                let fin: Int64?
                let maintenant: Int64
                let resultat: Int
            }
            struct Balayage: Decodable {
                let debut: Int64
                let fin: Int64
                let premier: Int64
                let pas: Int64
                let nombre: Int
                let resultats: [Int]
            }
            let cas: [Cas]
            let balayage: Balayage
        }

        let journee: [String]
        let prochainChangement: [Changement]
        let prochainChangementCas: [CasChangement]
        let jourHebreuAffiche: [JourAffiche]
        let debut: [Debut]
        let ecoule: Ecoule
    }

    private static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vignettes.json"))
    }

    @Test func laJourneeEstCelleDAndroid() throws {
        let journee = ZmanimVignette.journee
        let attendue = try Self.vecteurs().journee
        #expect(journee == attendue)
    }

    @Test func leProchainChangementRepondCommeAndroid() throws {
        var fautes: [String] = []
        var cas = 0
        var auTelephone = 0
        for b in try Self.vecteurs().prochainChangement {
            let lieu = try #require(Fuseau(b.fuseau), "fuseau « \(b.fuseau) » inconnu")
            let fuseauHoraires = try #require(Fuseau(b.fuseauHoraires), "fuseau « \(b.fuseauHoraires) » inconnu")
            let horaires: [DateHeureZonee?] = b.horaires.map { ms in ms.map { DateHeureZonee(millis: $0, fuseau: fuseauHoraires) } }
            var telephone: DateHeureZonee?
            if let ms = b.telephone, let id = b.fuseauTelephone {
                let fuseau = try #require(Fuseau(id), "fuseau « \(id) » inconnu")
                telephone = DateHeureZonee(millis: ms, fuseau: fuseau)
            }
            guard b.resultats.count == b.nombre else {
                fautes.append("\(b.fuseau) : \(b.resultats.count) résultats pour \(b.nombre) instants")
                continue
            }
            for k in 0..<b.nombre {
                let maintenant = DateHeureZonee(millis: b.debut + Int64(k) * b.pas, fuseau: lieu)
                let changement = ZmanimVignette.prochainChangement(horaires: horaires, maintenant: maintenant,
                                                                   minuitTelephone: telephone)
                let attendu = b.resultats[k]
                let ecart = changement.millis - maintenant.millis
                cas += 1
                if attendu.fuseau == b.fuseauTelephone && attendu.fuseau != b.fuseau { auTelephone += 1 }
                if ecart != attendu.ecart || changement.fuseau.identifiant != attendu.fuseau {
                    fautes.append("\(maintenant) : \(changement) au lieu de +\(attendu.ecart) ms [\(attendu.fuseau)]")
                }
            }
        }
        let resume = fautes.prefix(20).joined(separator: " ; ")
        let aucune = fautes.isEmpty
        #expect(aucune, "\(fautes.count) écarts : \(resume)")
        #expect(cas > 800)
        #expect(auTelephone > 0, "les vecteurs doivent faire gagner minuit du téléphone")
    }

    /// VoyageNuitTest, puis les égalités : un horaire à l'instant même, à une milliseconde, aux dix minutes,
    /// minuit du téléphone au même instant que celui du lieu (le premier l'emporte, avec son fuseau).
    @Test func lesCasDuProchainChangementRepondentCommeAndroid() throws {
        for c in try Self.vecteurs().prochainChangementCas {
            let fuseau = try #require(Fuseau(c.fuseau), "fuseau « \(c.fuseau) » inconnu")
            var horaires: [DateHeureZonee?] = []
            for h in c.horaires {
                if let h {
                    let fuseauHoraire = try #require(Fuseau(h.fuseau), "fuseau « \(h.fuseau) » inconnu")
                    horaires.append(DateHeureZonee(millis: h.millis, fuseau: fuseauHoraire))
                } else {
                    horaires.append(nil)
                }
            }
            var telephone: DateHeureZonee?
            if let ms = c.telephone, let id = c.fuseauTelephone {
                let fuseauTelephone = try #require(Fuseau(id), "fuseau « \(id) » inconnu")
                telephone = DateHeureZonee(millis: ms, fuseau: fuseauTelephone)
            }
            let maintenant = DateHeureZonee(millis: c.maintenant, fuseau: fuseau)
            let changement = ZmanimVignette.prochainChangement(horaires: horaires, maintenant: maintenant, minuitTelephone: telephone)
            let ou = "\(maintenant), \(horaires.count) horaires"
            let millis = changement.millis
            #expect(millis == c.resultat, "\(ou) : l'instant")
            let fuseauResultat = changement.fuseau.identifiant
            #expect(fuseauResultat == c.fuseauResultat, "\(ou) : le fuseau")
            let civile = changement.civile.description
            #expect(civile == c.civile, "\(ou) : l'heure civile")
        }
    }

    @Test func leJourHebreuAfficheRepondCommeAndroid() throws {
        var cas = 0
        for b in try Self.vecteurs().jourHebreuAffiche {
            let lieu = try #require(Fuseau(b.fuseau), "fuseau « \(b.fuseau) » inconnu")
            var tset: DateHeureZonee?
            if let ms = b.tset, let id = b.fuseauTset {
                let fuseauTset = try #require(Fuseau(id), "fuseau « \(id) » inconnu")
                tset = DateHeureZonee(millis: ms, fuseau: fuseauTset)
            }
            let tsetEcrit = tset?.description ?? "aucun"
            let nombre = b.jours.count
            #expect(nombre == b.nombre)
            for k in 0..<min(nombre, b.nombre) {
                let maintenant = DateHeureZonee(millis: b.debut + Int64(k) * b.pas, fuseau: lieu)
                let jour = ZmanimVignette.jourHebreuAffiche(maintenant: maintenant, tset: tset).iso
                let attendu = b.jours[k]
                #expect(jour == attendu, "\(maintenant), tsét \(tsetEcrit)")
                cas += 1
            }
        }
        #expect(cas > 300)
    }

    @Test func leDebutDeLaFenetreRepondCommeAndroid() throws {
        for c in try Self.vecteurs().debut {
            let horaires = c.horaires.mapValues { DateHeureZonee(millis: $0, fuseau: Self.paris) }
            let debut = ZmanimVignette.debut(priere: c.priere, horaires: horaires)?.millis
            #expect(debut == c.resultat, "« \(c.priere) », horaires \(c.horaires.keys.sorted())")
        }
    }

    @Test func laPartEcouleeRepondCommeAndroid() throws {
        let ecoule = try Self.vecteurs().ecoule
        func instant(_ ms: Int64) -> DateHeureZonee { DateHeureZonee(millis: ms, fuseau: Self.paris) }
        for c in ecoule.cas {
            let part = ZmanimVignette.ecoule(debut: c.debut.map(instant), fin: c.fin.map(instant), maintenant: instant(c.maintenant))
            let ou = "début \(c.debut.map { String($0) } ?? "nil"), fin \(c.fin.map { String($0) } ?? "nil"), maintenant \(c.maintenant)"
            #expect(part == c.resultat, "\(ou)")
        }
        let b = ecoule.balayage
        let nombre = b.resultats.count
        #expect(nombre == b.nombre)
        for k in 0..<min(nombre, b.nombre) {
            let maintenant = instant(b.premier + Int64(k) * b.pas)
            let part = ZmanimVignette.ecoule(debut: instant(b.debut), fin: instant(b.fin), maintenant: maintenant)
            let attendue = b.resultats[k]
            #expect(part == attendue, "\(maintenant)")
        }
    }
}
