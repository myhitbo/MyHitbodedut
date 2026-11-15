import Foundation
import Testing
@testable import Coeur

/// Le cas « widget, la priere du moment et sa limite » de DixAmeliorationsTest d'Android, porté ; puis ce
/// que `Tests/Vecteurs/vignettes.json`, écrit par la JVM (tools/vecteurs_ios/VecteursVignettes.kt), dit de
/// `ZmanimWidget.prochaine` : des semaines entières à pas de 30 minutes dans quatre fuseaux, et des cas à la
/// milliseconde, dans l'heure qui double. Les autres cas de DixAmeliorationsTest sont ceux d'autres règles
/// (Levana, la recherche, le journal).
@Suite("Vignette : la prière du moment")
struct ZmanimWidgetTests {

    private static let jerusalem: Fuseau = {
        guard let fuseau = Fuseau("Asia/Jerusalem") else { preconditionFailure("le fuseau Asia/Jerusalem manque") }
        return fuseau
    }()

    private let j = JourCivil.du("2026-10-14")

    private func t(_ heure: Int, _ minute: Int) -> DateHeureZonee {
        DateHeureZonee(DateHeure(j, heure: heure, minute: minute), fuseau: Self.jerusalem)
    }

    @Test func widgetLaPriereDuMomentEtSaLimite() {
        let finChaharit = t(10, 30), chkia = t(17, 50), milieuDeLaNuit = t(23, 40)
        let horaires = ["szt_gra": finChaharit, "chkia": chkia, "chatsot_layla": milieuDeLaNuit]
        let matin = ZmanimWidget.prochaine(horaires: horaires, maintenant: t(7, 0))
        let matinPriere = matin.priere, matinLimite = matin.limite
        #expect(matinPriere == "chaharit")
        #expect(matinLimite == finChaharit)
        let apresMidi = ZmanimWidget.prochaine(horaires: horaires, maintenant: t(13, 0))
        let apresMidiPriere = apresMidi.priere, apresMidiLimite = apresMidi.limite
        #expect(apresMidiPriere == "minha")
        #expect(apresMidiLimite == chkia)
        let soir = ZmanimWidget.prochaine(horaires: horaires, maintenant: t(19, 0))
        let soirPriere = soir.priere, soirLimite = soir.limite
        #expect(soirPriere == "arvit")
        #expect(soirLimite == milieuDeLaNuit)
        let tard = ZmanimWidget.prochaine(horaires: horaires, maintenant: t(23, 50))
        let tardPriere = tard.priere, tardLimite = tard.limite
        #expect(tardPriere == "arvit")
        #expect(tardLimite == nil)
        // Après minuit, avant l'aube : encore Arvit (jusqu'au milieu de la nuit d'hier s'il n'est pas passé).
        let nuit = ["alot": t(5, 20), "szt_gra": finChaharit, "chkia": chkia, "chatsot_layla": milieuDeLaNuit.plus(minutes: 70)]
        let apresMinuit = ZmanimWidget.prochaine(horaires: nuit, maintenant: t(0, 20))
        let apresMinuitPriere = apresMinuit.priere, apresMinuitLimite = apresMinuit.limite
        let minuitCinquante = t(0, 50)
        #expect(apresMinuitPriere == "arvit")
        #expect(apresMinuitLimite == minuitCinquante)
        let deuxHeures = ZmanimWidget.prochaine(horaires: nuit, maintenant: t(2, 0))
        let deuxHeuresPriere = deuxHeures.priere, deuxHeuresLimite = deuxHeures.limite
        #expect(deuxHeuresPriere == "arvit")
        #expect(deuxHeuresLimite == nil)
        let aube = ZmanimWidget.prochaine(horaires: nuit, maintenant: t(6, 0))
        let aubePriere = aube.priere, aubeLimite = aube.limite
        #expect(aubePriere == "chaharit")
        #expect(aubeLimite == finChaharit)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// Les horaires d'un jour civil (millisecondes Unix, une clé absente : pas de zman), et `veille`,
        /// le milieu de la nuit moins un jour tel que java.time le calcule (`minusDays(1)`).
        struct Jour: Decodable {
            let jour: String
            let horaires: [String: Int64]
            let veille: Int64?
        }
        /// Des « maintenant » de `debut` en `nombre` pas de `pas` minutes ; chaque réponse est
        /// [prière, clé de la limite] : « szt_gra », « chkia », « chatsot_layla », « veille » ou nil.
        struct Balayage: Decodable {
            let fuseau: String
            let debut: Int64
            let pas: Int
            let nombre: Int
            let jours: [Jour]
            let reponses: [[String?]]
        }
        struct Cas: Decodable {
            let fuseau: String
            let horaires: [String: Int64]
            let fuseauMaintenant: String
            let maintenant: Int64
            let priere: String
            let limite: Int64?
            let fuseauLimite: String?
            let civile: String?
        }
        let prochaine: [Balayage]
        let prochaineCas: [Cas]
    }

    private static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/vignettes.json"))
    }

    private static func ecrit(_ valeur: Int64?) -> String {
        valeur.map { String($0) } ?? "nil"
    }

    @Test func chaqueDemiHeureDesSemainesRepondCommeAndroid() throws {
        var fautes: [String] = []
        var cas = 0
        var veilles = 0
        for b in try Self.vecteurs().prochaine {
            let fuseau = try #require(Fuseau(b.fuseau), "fuseau « \(b.fuseau) » inconnu")
            var parJour: [JourCivil: Vecteurs.Jour] = [:]
            for jour in b.jours { parJour[JourCivil.du(jour.jour)] = jour }
            guard b.reponses.count == b.nombre else {
                fautes.append("\(b.fuseau) : \(b.reponses.count) réponses pour \(b.nombre) instants")
                continue
            }
            for k in 0..<b.nombre {
                let maintenant = DateHeureZonee(millis: b.debut + Int64(k) * Int64(b.pas) * 60_000, fuseau: fuseau)
                guard let jour = parJour[maintenant.jour] else {
                    fautes.append("\(maintenant) : aucun horaire pour le \(maintenant.jour)")
                    continue
                }
                let attendue = b.reponses[k]
                guard attendue.count == 2, let priere = attendue[0] else {
                    fautes.append("\(maintenant) : réponse illisible")
                    continue
                }
                var limiteAttendue: Int64?
                if let cle = attendue[1] {
                    limiteAttendue = cle == "veille" ? jour.veille : jour.horaires[cle]
                    if limiteAttendue == nil { fautes.append("\(maintenant) : la clé « \(cle) » manque au vecteur") }
                    if cle == "veille" { veilles += 1 }
                }
                let horaires = jour.horaires.mapValues { DateHeureZonee(millis: $0, fuseau: fuseau) }
                let reponse = ZmanimWidget.prochaine(horaires: horaires, maintenant: maintenant)
                cas += 1
                let limite = reponse.limite?.millis
                let memeFuseau = reponse.limite.map { $0.fuseau == fuseau } ?? true
                if reponse.priere != priere || limite != limiteAttendue || !memeFuseau {
                    let rendue = "\(reponse.priere) jusqu'à \(Self.ecrit(limite))"
                    fautes.append("\(maintenant) : \(rendue) au lieu de \(priere) jusqu'à \(Self.ecrit(limiteAttendue))")
                }
            }
        }
        let resume = fautes.prefix(20).joined(separator: " ; ")
        let aucune = fautes.isEmpty
        #expect(aucune, "\(fautes.count) écarts : \(resume)")
        #expect(cas == 35 * 48)
        #expect(veilles > 0, "les vecteurs doivent passer par la nuit d'hier")
    }

    @Test func lesCasALaMillisecondeRepondentCommeAndroid() throws {
        for c in try Self.vecteurs().prochaineCas {
            let fuseau = try #require(Fuseau(c.fuseau), "fuseau « \(c.fuseau) » inconnu")
            let fuseauMaintenant = try #require(Fuseau(c.fuseauMaintenant), "fuseau « \(c.fuseauMaintenant) » inconnu")
            let horaires = c.horaires.mapValues { DateHeureZonee(millis: $0, fuseau: fuseau) }
            let maintenant = DateHeureZonee(millis: c.maintenant, fuseau: fuseauMaintenant)
            let ou = "\(maintenant), horaires \(c.horaires.keys.sorted())"
            let reponse = ZmanimWidget.prochaine(horaires: horaires, maintenant: maintenant)
            let priere = reponse.priere
            #expect(priere == c.priere, "\(ou) : la prière")
            let millis = reponse.limite?.millis
            #expect(millis == c.limite, "\(ou) : la limite")
            let fuseauLimite = reponse.limite?.fuseau.identifiant
            #expect(fuseauLimite == c.fuseauLimite, "\(ou) : le fuseau de la limite")
            let civile = reponse.limite?.civile.description
            #expect(civile == c.civile, "\(ou) : l'heure civile de la limite")
        }
    }
}
