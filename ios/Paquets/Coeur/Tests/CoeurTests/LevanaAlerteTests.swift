import Foundation
import Testing
@testable import Coeur

/// Le rappel de Birkat haLevana : le cas « rappel Levana, premier soir puis motsae Chabbat puis dernier » de
/// DixAmeliorationsTest d'Android, porté (les autres cas de ce fichier relèvent d'autres règles), puis
/// `Tests/Vecteurs/levana.json` (tools/vecteurs_ios/VecteursLevana.kt) : les soirs du rappel de chaque mois
/// hébreu de 5784 à 5790, puis depuis chaque jour autour des bornes de 5787, la suite des rappels sur deux ans
/// et le prochain rappel vu de chaque jour, l'heure du soir à 20 h. L'heure réelle (la sortie des étoiles au
/// lieu choisi), l'alarme et la notification restent à Android.
@Suite("Rappel de Birkat haLevana")
struct LevanaAlerteTests {

    /// L'heure du soir des vecteurs : 20 h, heure du fuseau.
    private static func vingtHeures(_ zone: Fuseau) -> (JourCivil) -> DateHeureZonee {
        return { d in DateHeureZonee(DateHeure(d, heure: 20), fuseau: zone) }
    }

    // MARK: DixAmeliorationsTest

    @Test func rappelLevanaPremierSoirPuisMotsaeChabbatPuisDernier() throws {
        let zone = try #require(Fuseau("Asia/Jerusalem"), "fuseau Asia/Jerusalem inconnu")
        let heure: (JourCivil) -> DateHeureZonee = { d in DateHeureZonee(DateHeure(d, heure: 19), fuseau: zone) }
        let depart = DateHeureZonee(DateHeure(.du("2026-10-14"), heure: 9), fuseau: zone)

        let p1 = LevanaAlerte.prochain(depart, usage: .troisMiMois, heure: heure)
        let r1 = try #require(p1)
        let jour1 = r1.quand.jour
        let attendu1 = JourCivil.du("2026-10-14")
        #expect(jour1 == attendu1)
        let soir1 = r1.soir
        let premier = LevanaAlerte.Soir.premier
        #expect(soir1 == premier)

        let p2 = LevanaAlerte.prochain(r1.quand.plus(minutes: 1), usage: .troisMiMois, heure: heure)
        let r2 = try #require(p2)
        let jour2 = r2.quand.jour
        let attendu2 = JourCivil.du("2026-10-17")
        #expect(jour2 == attendu2)
        let soir2 = r2.soir
        let motsae = LevanaAlerte.Soir.motsae
        #expect(soir2 == motsae)

        let p3 = LevanaAlerte.prochain(r2.quand.plus(minutes: 1), usage: .troisMiMois, heure: heure)
        let r3 = try #require(p3)
        let jour3 = r3.quand.jour
        let attendu3 = JourCivil.du("2026-10-25")
        #expect(jour3 == attendu3)
        let soir3 = r3.soir
        let dernier = LevanaAlerte.Soir.dernier
        #expect(soir3 == dernier)

        // Après le dernier soir : le premier soir du mois suivant.
        let p4 = LevanaAlerte.prochain(r3.quand.plus(minutes: 1), usage: .troisMiMois, heure: heure)
        let r4 = try #require(p4)
        let jour4 = r4.quand.jour
        let limite = JourCivil.du("2026-11-05")
        #expect(jour4 > limite)
        let soir4 = r4.soir
        #expect(soir4 == premier)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct SoirAndroid: Decodable {
            let nom: String
            let titre: String
        }
        /// Un mois hébreu ; voir LevanaTests et VecteursLevana.kt pour les sept chaînes d'une fenêtre.
        struct MoisHebreu: Decodable {
            let date: String
            let vues: [[[String]]]
        }
        /// Les noms des soirs du rappel depuis chaque jour, à partir de `depart` (voir LevanaTests pour le reste).
        struct Bornes: Decodable {
            let date: String
            let fuseau: String
            let usage: String
            let depart: String
            let soirs: [String]
        }
        struct SuiteDeRappels: Decodable {
            let fuseau: String
            let usage: String
            let rappels: [[String]]
        }
        struct Prochains: Decodable {
            let fuseau: String
            let usage: String
            let depart: String
            let heures: [Int]
            let reponses: [[String]?]
        }

        let soirsAlerte: [SoirAndroid]
        let fuseaux: [String]
        let fenetres: [MoisHebreu]
        let bornes: [Bornes]
        let suites: [SuiteDeRappels]
        let prochains: [Prochains]
    }

    private static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/levana.json"))
    }

    @Test func lesSoirsEtLeursTitres() throws {
        let v = try Self.vecteurs()
        let noms = LevanaAlerte.Soir.allCases.map { $0.rawValue }
        let nomsAndroid = v.soirsAlerte.map { $0.nom }
        #expect(noms == nomsAndroid, "les soirs, dans l'ordre d'Android")
        let catalogue = try Catalogue.lire()
        for s in v.soirsAlerte {
            let soir = try #require(LevanaAlerte.Soir(rawValue: s.nom), "soir « \(s.nom) » inconnu")
            let titre = soir.titre
            #expect(titre == s.titre, "\(s.nom) : le titre")
            for langue in Catalogue.langues {
                let present = catalogue.simples(langue)[titre] != nil
                #expect(present, "\(langue) : la chaîne \(titre)")
            }
        }
    }

    /// LevanaAlerte.soirs depuis le 1 de chaque mois : les noms dans l'ordre, et la date de chacun (celle du
    /// premier soir possible, du motsaé Chabbat conseillé ou du dernier soir, que LevanaTests vérifie).
    @Test func lesSoirsDuRappelDeChaqueMois() throws {
        let v = try Self.vecteurs()
        let usages = Levana.Usage.allCases
        var rappelsMotsae = 0
        for ligne in v.fenetres {
            let date = JourCivil.du(ligne.date)
            try #require(ligne.vues.count == v.fuseaux.count)
            for (i, id) in v.fuseaux.enumerated() {
                let zone = try #require(Fuseau(id), "fuseau « \(id) » inconnu")
                try #require(ligne.vues[i].count == usages.count)
                for (j, usage) in usages.enumerated() {
                    let attendu = ligne.vues[i][j]
                    try #require(attendu.count == 8)
                    let ou = "\(ligne.date), \(id), \(usage.cle)"
                    let f = Levana.fenetre(date, fuseau: zone, usage: usage)
                    // Les vecteurs : Israël à Jérusalem seule (VecteursLevana.israel), le Yom tov chéni ailleurs.
                    let soirs = LevanaAlerte.soirs(f, depuis: date, fuseau: zone, enIsrael: id == "Asia/Jerusalem")
                    let noms = soirs.map { $0.soir.rawValue }.joined(separator: " ")
                    #expect(noms == attendu[6], "\(ou) : les soirs du rappel")
                    for rappel in soirs {
                        let jour = rappel.jour.iso
                        let attendue: String
                        switch rappel.soir {
                        // Le premier soir rappelé n'est ni Chabbat ni Yom tov depuis le 16/11 (MB 426:12) : le
                        // premier soir possible, plus le premier soir de la fenêtre.
                        case .premier: attendue = attendu[7]
                        case .motsae: attendue = attendu[5]
                        case .dernier: attendue = attendu[4]
                        }
                        #expect(jour == attendue, "\(ou) : le soir \(rappel.soir.rawValue)")
                        if rappel.soir == .motsae { rappelsMotsae += 1 }
                    }
                }
            }
        }
        #expect(rappelsMotsae > 0, "des motsaé Chabbat rappelés")
    }

    /// LevanaAlerte.soirs depuis chaque jour, du troisième avant le premier soir au deuxième après le dernier :
    /// le soir de `depuis` est gardé, ceux d'avant non, et la liste est vide après le dernier soir.
    @Test func lesSoirsDuRappelDepuisChaqueJour() throws {
        let v = try Self.vecteurs()
        var vides = 0
        for b in v.bornes {
            let zone = try #require(Fuseau(b.fuseau), "fuseau « \(b.fuseau) » inconnu")
            let usage = try #require(Levana.Usage(rawValue: b.usage), "usage « \(b.usage) » inconnu")
            let f = Levana.fenetre(.du(b.date), fuseau: zone, usage: usage)
            let depart = JourCivil.du(b.depart)
            for (k, attendus) in b.soirs.enumerated() {
                let depuis = depart.plus(jours: k)
                let noms = LevanaAlerte.soirs(f, depuis: depuis, fuseau: zone, enIsrael: b.fuseau == "Asia/Jerusalem").map { $0.soir.rawValue }.joined(separator: " ")
                #expect(noms == attendus, "\(b.date), \(b.fuseau), \(b.usage) : les soirs depuis le \(depuis.iso)")
                if attendus.isEmpty { vides += 1 }
            }
        }
        #expect(vides > 0, "des listes vides après le dernier soir")
    }

    /// Chaque rappel trouvé depuis le 1er janvier 2026, puis le suivant cherché une minute après, jusqu'en 2028.
    @Test func laSuiteDesRappelsSurDeuxAns() throws {
        let v = try Self.vecteurs()
        for suite in v.suites {
            let zone = try #require(Fuseau(suite.fuseau), "fuseau « \(suite.fuseau) » inconnu")
            let usage = try #require(Levana.Usage(rawValue: suite.usage), "usage « \(suite.usage) » inconnu")
            let heure = Self.vingtHeures(zone)
            let fin = DateHeureZonee(DateHeure(.du("2028-01-01")), fuseau: zone)
            var maintenant = DateHeureZonee(DateHeure(.du("2026-01-01")), fuseau: zone)
            var rappels: [[String]] = []
            while let r = LevanaAlerte.prochain(maintenant, usage: usage, heure: heure), r.quand <= fin {
                rappels.append([r.quand.jour.iso, r.soir.rawValue])
                maintenant = r.quand.plus(minutes: 1)
            }
            let attendus = suite.rappels
            #expect(rappels == attendus, "\(suite.fuseau), \(suite.usage)")
        }
    }

    /// Le prochain rappel vu de chaque jour, à midi et à 21 h : avant et après l'heure du soir.
    @Test func leProchainRappelVuDeChaqueJour() throws {
        let v = try Self.vecteurs()
        for ligne in v.prochains {
            let zone = try #require(Fuseau(ligne.fuseau), "fuseau « \(ligne.fuseau) » inconnu")
            let usage = try #require(Levana.Usage(rawValue: ligne.usage), "usage « \(ligne.usage) » inconnu")
            let heure = Self.vingtHeures(zone)
            let depart = JourCivil.du(ligne.depart)
            try #require(!ligne.heures.isEmpty && ligne.reponses.count % ligne.heures.count == 0)
            var rang = 0
            for k in 0..<(ligne.reponses.count / ligne.heures.count) {
                let jour = depart.plus(jours: k)
                for h in ligne.heures {
                    let maintenant = DateHeureZonee(DateHeure(jour, heure: h), fuseau: zone)
                    let r = LevanaAlerte.prochain(maintenant, usage: usage, heure: heure)
                    let obtenu: [String]? = r.map { [$0.quand.jour.iso, $0.soir.rawValue] }
                    let attendu = ligne.reponses[rang]
                    #expect(obtenu == attendu, "\(ligne.fuseau), \(ligne.usage), le \(jour.iso) à \(h) h")
                    rang += 1
                }
            }
        }
    }
}
