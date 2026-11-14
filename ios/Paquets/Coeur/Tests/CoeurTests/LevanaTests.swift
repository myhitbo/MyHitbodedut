import Foundation
import Testing
@testable import Coeur

/// LevanaTest d'Android, porté : 'Hechvan 5787 du 18 au 25 octobre (ce qu'affiche CalJ pour Jérusalem), la
/// fenêtre passée, les trois usages, le motsaé Chabbat conseillé, Kippour et Tich'a beAv, la lune. Puis
/// `Tests/Vecteurs/levana.json`, écrit par la JVM (tools/vecteurs_ios/VecteursLevana.kt) : chaque mois hébreu
/// de 5784 à 5790 dans quatre fuseaux et pour chaque usage, les états et les parts autour des bornes, la carte
/// du jour jour après jour, le soir de 20 h, la phase de la lune. Le dessin de la lune et la jauge, des vues,
/// restent à Android.
@Suite("Birkat haLevana")
struct LevanaTests {

    private static func jerusalem() throws -> Fuseau {
        try #require(Fuseau("Asia/Jerusalem"), "fuseau Asia/Jerusalem inconnu")
    }

    /// Un instant écrit dans un test : `Instant.parse("…T12:00:00Z")`.
    private static func midiUTC(_ iso: String) -> Int64 {
        Fuseau.utc.millis(DateHeure(JourCivil.du(iso), heure: 12))
    }

    /// L'état écrit comme les vecteurs : Dans(n) → n, CeSoir → -1, DernierSoir → -2.
    private static func code(_ e: Levana.Etat) -> Int {
        switch e {
        case .dans(let jours): jours
        case .ceSoir: -1
        case .dernierSoir: -2
        }
    }

    // MARK: LevanaTest

    @Test func hechvan5787Du18Au25Octobre() throws {
        let zone = try Self.jerusalem()
        let f = Levana.fenetre(.du("2026-10-14"), fuseau: zone)
        let premier = f.premierSoir(zone)
        let attenduPremier = JourCivil.du("2026-10-18")
        #expect(premier == attenduPremier)
        let dernier = f.dernierSoir(zone)
        let attenduDernier = JourCivil.du("2026-10-25")
        #expect(dernier == attenduDernier)
        let avant = Levana.etat(f, .du("2026-10-14"), fuseau: zone)
        let dansQuatre = Levana.Etat.dans(jours: 4)
        #expect(avant == dansQuatre)
        let ouverture = Levana.etat(f, .du("2026-10-18"), fuseau: zone)
        let ceSoir = Levana.Etat.ceSoir
        #expect(ouverture == ceSoir)
        let cloture = Levana.etat(f, .du("2026-10-25"), fuseau: zone)
        let dernierSoir = Levana.Etat.dernierSoir
        #expect(cloture == dernierSoir)
        let partDebut = Levana.part(f, f.debut)
        let partFin = Levana.part(f, f.fin)
        #expect(partDebut < partFin)
    }

    @Test func laFenetrePasseeCelleDuMoisSuivant() throws {
        let zone = try Self.jerusalem()
        let f = Levana.fenetre(.du("2026-10-26"), fuseau: zone)
        let premier = f.premierSoir(zone)
        let limite = JourCivil.du("2026-11-01")
        #expect(premier > limite)
        let etat = Levana.etat(f, .du("2026-10-26"), fuseau: zone)
        let dans: Bool
        if case .dans = etat { dans = true } else { dans = false }
        #expect(dans)
    }

    // Revue du 14/10 sur le texte (Choulhan Aroukh O.H. 426 ; Michna Beroura 426), mêmes valeurs que le web.

    @Test func troisUsagesHechvan5787() throws {
        let zone = try Self.jerusalem()
        let trois = Levana.fenetre(.du("2026-10-14"), fuseau: zone, usage: .troisMiMois)
        let premierTrois = trois.premierSoir(zone)
        let attenduPremierTrois = JourCivil.du("2026-10-14")
        #expect(premierTrois == attenduPremierTrois)
        let dernierTrois = trois.dernierSoir(zone)
        let attenduDernierTrois = JourCivil.du("2026-10-25")
        #expect(dernierTrois == attenduDernierTrois)
        let quinze = Levana.fenetre(.du("2026-10-14"), fuseau: zone, usage: .septQuinze)
        let premierQuinze = quinze.premierSoir(zone)
        let attenduPremierQuinze = JourCivil.du("2026-10-18")
        #expect(premierQuinze == attenduPremierQuinze)
        // Quinze jours depuis le molad : plus tard que la mi-mois (14 j 18 h 22 min).
        let finQuinze = quinze.fin
        let finTrois = trois.fin
        #expect(finQuinze > finTrois)
        let duree = quinze.fin - quinze.molad
        let quinzeJours: Int64 = 15 * 86_400_000
        #expect(duree == quinzeJours)
    }

    @Test func motsaeChabbatConseilleAvantLe10() throws {
        let zone = try Self.jerusalem()
        let trois = Levana.fenetre(.du("2026-10-14"), fuseau: zone, usage: .troisMiMois)
        // Samedi 17/10 : sa nuit est le 8 'Hechvan.
        let conseille = Levana.motsaeChabbat(trois, .du("2026-10-14"), fuseau: zone)
        let samedi: JourCivil? = JourCivil.du("2026-10-17")
        #expect(conseille == samedi)
        // Sept jours : le premier samedi (24/10) a sa nuit le 15, rien de conseillé.
        let sept = Levana.fenetre(.du("2026-10-14"), fuseau: zone, usage: .septMiMois)
        let aucun = Levana.motsaeChabbat(sept, .du("2026-10-14"), fuseau: zone)
        #expect(aucun == nil)
    }

    @Test func pasAvantKippourNiTichaBeav() throws {
        let zone = try Self.jerusalem()
        let tichri = Levana.fenetre(.du("2026-09-15"), fuseau: zone, usage: .troisMiMois)
        let premierTichri = tichri.premierSoir(zone)
        let kippour = JourCivil.du("2026-09-21")  // Kippour 5787 : lundi 21/9
        #expect(premierTichri == kippour)
        let restrictionTichri = tichri.restriction
        let attendueTichri: Levana.Restriction? = Levana.Restriction.kippour
        #expect(restrictionTichri == attendueTichri)
        let av = Levana.fenetre(.du("2026-07-20"), fuseau: zone, usage: .troisMiMois)
        let premierAv = av.premierSoir(zone)
        let neufAv = JourCivil.du("2026-07-23")  // 9 Av 5786 : jeudi 23/7
        #expect(premierAv == neufAv)
        let restrictionAv = av.restriction
        let attendueAv: Levana.Restriction? = Levana.Restriction.tishaBeav
        #expect(restrictionAv == attendueAv)
    }

    @Test func laLuneNouvelleAuPremierQuartierPleine() {
        let nouvelle = Levana.phase(Self.midiUTC("2026-10-10")).eclairage
        #expect(nouvelle < 0.01)
        let quartier = Levana.phase(Self.midiUTC("2026-10-18"))
        let auQuartier = quartier.eclairage >= 0.4 && quartier.eclairage <= 0.6 && quartier.croissante
        #expect(auQuartier)
        let pleine = Levana.phase(Self.midiUTC("2026-10-26")).eclairage
        #expect(pleine > 0.99)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct UsageAndroid: Decodable {
            let nom: String
            let cle: String
            let libelle: String
            let troisJours: Bool
            let quinzeJours: Bool
        }
        /// Un mois hébreu : par fuseau (ordre de `fuseaux`), par usage (ordre de `usages`), sept chaînes :
        /// début, fin, restriction ou "", premier soir, dernier soir, motsaé Chabbat ou "", soirs du rappel.
        struct MoisHebreu: Decodable {
            let date: String
            let annee: Int
            let mois: Int
            let molad: Int64
            let vues: [[[String]]]
        }
        struct Bornes: Decodable {
            let date: String
            let fuseau: String
            let usage: String
            let depart: String
            let etats: [Int]
            let instants: [Int64]
            let parts: [Double]
        }
        struct Jours: Decodable {
            let fuseau: String
            let usage: String
            let depart: String
            let molads: [Int64]
            let etats: [Int]
            let motsae: [String?]
            let parts: [Double]
        }
        struct Phase: Decodable {
            let instants: [Int64]
            let eclairages: [Double]
            let croissantes: [Bool]
        }

        let usages: [UsageAndroid]
        let duNusah: [[String]]
        let restrictions: [String]
        let mois: Int64
        let fuseaux: [String]
        let fenetres: [MoisHebreu]
        let bornes: [Bornes]
        let jours: [Jours]
        let soirs20h: [[String]]
        let phase: Phase
    }

    private static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/levana.json"))
    }

    @Test func usagesRestrictionsEtMoisLunaireCommeAndroid() throws {
        let v = try Self.vecteurs()
        let cles = Levana.Usage.allCases.map { $0.cle }
        let clesAndroid = v.usages.map { $0.cle }
        #expect(cles == clesAndroid, "les usages, dans l'ordre d'Android")
        let catalogue = try Catalogue.lire()
        for u in v.usages {
            let usage = try #require(Levana.Usage(rawValue: u.cle), "usage « \(u.cle) » inconnu")
            let libelle = usage.libelle
            #expect(libelle == u.libelle, "\(u.nom) : le libellé")
            let troisJours = usage.troisJours
            #expect(troisJours == u.troisJours, "\(u.nom) : trois jours")
            let quinzeJours = usage.quinzeJours
            #expect(quinzeJours == u.quinzeJours, "\(u.nom) : quinze jours")
            for langue in Catalogue.langues {
                let present = catalogue.simples(langue)[libelle] != nil
                #expect(present, "\(langue) : la chaîne \(libelle)")
            }
        }
        for paire in v.duNusah {
            try #require(paire.count == 2)
            let nusah = try #require(Nusah(rawValue: paire[0]), "noussa'h « \(paire[0]) » inconnu")
            let cle = Levana.Usage.duNusah(nusah).cle
            let attendue = paire[1]
            #expect(cle == attendue, "duNusah(\(paire[0]))")
        }
        let restrictions = [Levana.Restriction.kippour.rawValue, Levana.Restriction.tishaBeav.rawValue]
        #expect(restrictions == v.restrictions)
        let zone = try Self.jerusalem()
        let f = Levana.fenetre(.du("2026-10-14"), fuseau: zone)
        let mois = f.prochainMolad - f.molad
        #expect(mois == v.mois, "le mois lunaire moyen")
    }

    /// La fenêtre du 1 de chaque mois hébreu : molad, début, fin, restriction, premier et dernier soir,
    /// motsaé Chabbat conseillé, à la milliseconde de KosherJava.
    @Test func chaqueMoisDe5784A5790DansQuatreFuseaux() throws {
        let v = try Self.vecteurs()
        let usages = Levana.Usage.allCases
        var restrictions = 0
        var conseilles = 0
        for ligne in v.fenetres {
            let date = JourCivil.du(ligne.date)
            try #require(ligne.vues.count == v.fuseaux.count)
            for (i, id) in v.fuseaux.enumerated() {
                let zone = try #require(Fuseau(id), "fuseau « \(id) » inconnu")
                try #require(ligne.vues[i].count == usages.count)
                for (j, usage) in usages.enumerated() {
                    let attendu = ligne.vues[i][j]
                    try #require(attendu.count == 7)
                    let ou = "\(ligne.date) (\(ligne.mois)/\(ligne.annee)), \(id), \(usage.cle)"
                    let f = Levana.fenetre(date, fuseau: zone, usage: usage)
                    let molad = f.molad
                    #expect(molad == ligne.molad, "\(ou) : le molad")
                    let debut = String(f.debut)
                    #expect(debut == attendu[0], "\(ou) : le début")
                    let fin = String(f.fin)
                    #expect(fin == attendu[1], "\(ou) : la fin")
                    let restriction = f.restriction?.rawValue ?? ""
                    #expect(restriction == attendu[2], "\(ou) : la restriction")
                    let premier = f.premierSoir(zone)
                    let premierIso = premier.iso
                    #expect(premierIso == attendu[3], "\(ou) : le premier soir")
                    let dernier = f.dernierSoir(zone).iso
                    #expect(dernier == attendu[4], "\(ou) : le dernier soir")
                    let conseille = Levana.motsaeChabbat(f, premier, fuseau: zone)?.iso ?? ""
                    #expect(conseille == attendu[5], "\(ou) : le motsaé Chabbat conseillé")
                    if !restriction.isEmpty { restrictions += 1 }
                    if !conseille.isEmpty { conseilles += 1 }
                }
            }
        }
        // Sept années hébraïques, dont trois embolismiques ; Kippour et Tich'a beAv chaque année.
        let moisVus = v.fenetres.count
        #expect(moisVus == 87)
        let auMoins = 7 * 2 * v.fuseaux.count
        #expect(restrictions >= auMoins, "des fenêtres repoussées après Kippour et Tich'a beAv")
        #expect(conseilles > 0, "des motsaé Chabbat conseillés")
    }

    /// Levana.etat du troisième jour avant le premier soir au deuxième après le dernier, et Levana.part
    /// autour du molad, des bornes, des soirs et du molad suivant.
    @Test func lEtatEtLaPartAutourDesBornes() throws {
        let v = try Self.vecteurs()
        for b in v.bornes {
            let zone = try #require(Fuseau(b.fuseau), "fuseau « \(b.fuseau) » inconnu")
            let usage = try #require(Levana.Usage(rawValue: b.usage), "usage « \(b.usage) » inconnu")
            let f = Levana.fenetre(.du(b.date), fuseau: zone, usage: usage)
            let depart = JourCivil.du(b.depart)
            let ou = "\(b.date), \(b.fuseau), \(b.usage)"
            for (k, attendu) in b.etats.enumerated() {
                let jour = depart.plus(jours: k)
                let etat = Self.code(Levana.etat(f, jour, fuseau: zone))
                #expect(etat == attendu, "\(ou) : l'état du \(jour.iso)")
            }
            try #require(b.instants.count == b.parts.count)
            for (k, t) in b.instants.enumerated() {
                let part = Double(Levana.part(f, t))
                let attendue = b.parts[k]
                #expect(part == attendue, "\(ou) : la part à \(t)")
            }
        }
    }

    /// Ce que montre la carte du jour : la fenêtre du soir (son molad), son état, le motsaé Chabbat conseillé
    /// à partir de ce jour, la place du soir sur la jauge.
    @Test func laCarteDuJourJourApresJour() throws {
        let v = try Self.vecteurs()
        for ligne in v.jours {
            let zone = try #require(Fuseau(ligne.fuseau), "fuseau « \(ligne.fuseau) » inconnu")
            let usage = try #require(Levana.Usage(rawValue: ligne.usage), "usage « \(ligne.usage) » inconnu")
            let depart = JourCivil.du(ligne.depart)
            let n = ligne.molads.count
            try #require(ligne.etats.count == n && ligne.motsae.count == n && ligne.parts.count == n)
            for k in 0..<n {
                let jour = depart.plus(jours: k)
                let ou = "\(ligne.fuseau), \(ligne.usage), \(jour.iso)"
                let f = Levana.fenetre(jour, fuseau: zone, usage: usage)
                let molad = f.molad
                let attenduMolad = ligne.molads[k]
                #expect(molad == attenduMolad, "\(ou) : le molad de la fenêtre")
                let etat = Self.code(Levana.etat(f, jour, fuseau: zone))
                let attenduEtat = ligne.etats[k]
                #expect(etat == attenduEtat, "\(ou) : l'état")
                let conseille = Levana.motsaeChabbat(f, jour, fuseau: zone)?.iso
                let attenduConseille = ligne.motsae[k]
                #expect(conseille == attenduConseille, "\(ou) : le motsaé Chabbat conseillé")
                let part = Double(Levana.part(f, Levana.soir(jour, fuseau: zone)))
                let attenduePart = ligne.parts[k]
                #expect(part == attenduePart, "\(ou) : la place du soir sur la jauge")
            }
        }
    }

    @Test func leSoirDeVingtHeures() throws {
        let v = try Self.vecteurs()
        for ligne in v.soirs20h {
            try #require(ligne.count == 3)
            let zone = try #require(Fuseau(ligne[1]), "fuseau « \(ligne[1]) » inconnu")
            let soir = String(Levana.soir(.du(ligne[0]), fuseau: zone))
            let attendu = ligne[2]
            #expect(soir == attendu, "\(ligne[0]), \(ligne[1])")
        }
    }

    /// L'éclairage à 1e-12 près : le sinus de la JVM et celui de la libc peuvent différer d'une unité du
    /// dernier rang (la libc de Linux contre la JVM : 1,1e-16 au plus sur ces instants). La croissance,
    /// calculée sans trigonométrie, est exacte.
    @Test func laPhaseDeLaLuneSurVingtMois() throws {
        let p = try Self.vecteurs().phase
        try #require(p.instants.count == p.eclairages.count && p.instants.count == p.croissantes.count)
        for (k, t) in p.instants.enumerated() {
            let lune = Levana.phase(t)
            let ecart = abs(lune.eclairage - p.eclairages[k])
            #expect(ecart <= 1e-12, "l'éclairage à \(t)")
            let croissante = lune.croissante
            let attendue = p.croissantes[k]
            #expect(croissante == attendue, "la croissance à \(t)")
        }
    }
}
