import Foundation
import Testing
@testable import Coeur

/// LevanaTest d'Android, porté : la fenêtre de 'Hechvan 5787, de sept jours après le molad jusqu'à la
/// mi-mois, est du 18 au 25 octobre 2026 au soir, ce qu'affiche CalJ pour Jérusalem ; les trois usages,
/// le motsaé Chabbat, Kippour et Tich'a beAv, la lune. Puis les mêmes calculs devant la JVM
/// (Tests/Vecteurs/levana.json, tools/vecteurs_ios/VecteursLevana.kt) : vingt ans de molad, une année
/// de soirs dans trois fuseaux.
@Suite("Levana")
struct LevanaTests {

    private let jour: Int64 = 86_400_000

    private func zone(_ id: String = "Asia/Jerusalem") throws -> Fuseau { try #require(Fuseau(id)) }

    @Test func hechvan5787Du18Au25Octobre() throws {
        let z = try zone()
        let f = Levana.fenetre(.du("2026-10-14"), z)
        #expect(f.premierSoir(z) == .du("2026-10-18"))
        #expect(f.dernierSoir(z) == .du("2026-10-25"))
        #expect(Levana.etat(f, .du("2026-10-14"), z) == .dans(4))
        #expect(Levana.etat(f, .du("2026-10-18"), z) == .ceSoir)
        #expect(Levana.etat(f, .du("2026-10-25"), z) == .dernierSoir)
        #expect(Levana.part(f, f.debut) < Levana.part(f, f.fin))
    }

    @Test func laFenetrePasseeCelleDuMoisSuivant() throws {
        let z = try zone()
        let f = Levana.fenetre(.du("2026-10-26"), z)
        #expect(f.premierSoir(z) > .du("2026-11-01"))
        let etat = Levana.etat(f, .du("2026-10-26"), z)
        var dans = false
        if case .dans = etat { dans = true }
        #expect(dans)
    }

    // Revue du 14/10 sur le texte (Choulhan Aroukh O.H. 426 ; Michna Beroura 426), mêmes valeurs que le web.

    @Test func troisUsagesHechvan5787() throws {
        let z = try zone()
        let trois = Levana.fenetre(.du("2026-10-14"), z, .troisMiMois)
        #expect(trois.premierSoir(z) == .du("2026-10-14"))
        #expect(trois.dernierSoir(z) == .du("2026-10-25"))
        let quinze = Levana.fenetre(.du("2026-10-14"), z, .septQuinze)
        #expect(quinze.premierSoir(z) == .du("2026-10-18"))
        // Quinze jours depuis le molad : plus tard que la mi-mois (14 j 18 h 22 min).
        #expect(quinze.fin > trois.fin)
        #expect(quinze.fin - quinze.molad == 15 * jour)
    }

    @Test func motsaeChabbatConseilleAvantLe10() throws {
        let z = try zone()
        let trois = Levana.fenetre(.du("2026-10-14"), z, .troisMiMois)
        // Samedi 17/10 : sa nuit est le 8 'Hechvan.
        #expect(Levana.motsaeChabbat(trois, .du("2026-10-14"), z) == .du("2026-10-17"))
        // Sept jours : le premier samedi (24/10) a sa nuit le 15, rien de conseillé.
        let sept = Levana.fenetre(.du("2026-10-14"), z, .septMiMois)
        #expect(Levana.motsaeChabbat(sept, .du("2026-10-14"), z) == nil)
    }

    @Test func pasAvantKippourNiTichaBeAv() throws {
        let z = try zone()
        let tichri = Levana.fenetre(.du("2026-09-15"), z, .troisMiMois)
        #expect(tichri.premierSoir(z) == .du("2026-09-21")) // Kippour 5787 : lundi 21/9
        #expect(tichri.restriction == .kippour)
        let av = Levana.fenetre(.du("2026-07-20"), z, .troisMiMois)
        #expect(av.premierSoir(z) == .du("2026-07-23")) // 9 Av 5786 : jeudi 23/7
        #expect(av.restriction == .tishaBeav)
    }

    @Test func laLuneNouvelleAuPremierQuartierPleine() {
        #expect(Levana.phase(millis: JourCivil.du("2026-10-10").millisUTC(heures: 12)).eclairage < 0.01)
        let quartier = Levana.phase(millis: JourCivil.du("2026-10-18").millisUTC(heures: 12))
        #expect(quartier.eclairage >= 0.4 && quartier.eclairage <= 0.6 && quartier.croissante)
        #expect(Levana.phase(millis: JourCivil.du("2026-10-26").millisUTC(heures: 12)).eclairage > 0.99)
    }

    @Test func lUsageParDefautDuNusah() {
        #expect(Levana.Usage.duNusah(.edot) == .septQuinze)
        #expect(Levana.Usage.duNusah(.sefard) == .septMiMois)
        #expect(Levana.Usage.duNusah(.ashkenaz) == .troisMiMois)
        #expect(Levana.Usage.troisMiMois.libelle == "levana_usage_trois_mi_mois")
    }

    // MARK: Devant la JVM

    private func vecteurs() throws -> ObjetJSON { try Depot.vecteurs("levana.json") }

    /// Vingt ans de mois : le molad de KosherJava à la milliseconde, ses quatre heures, et la fenêtre de
    /// chaque usage à Jérusalem, restriction comprise.
    @Test func lesMoisDesVecteursSontRendusALIdentique() throws {
        let z = try zone()
        let lignes = try vecteurs().tableau("mois") ?? []
        #expect(lignes.count > 250)
        for case .tableau(let r) in lignes {
            let date = JourCivil.du(r.texte(0))
            let hebreu = CalendrierJuif.dateJuive(date)
            #expect(hebreu.annee == r.entier(1) && hebreu.mois == r.entier(2), "\(date) : \(hebreu)")
            let molad = r.long(3)
            #expect(CalendrierJuif.molad(annee: r.entier(1), mois: r.entier(2)) == molad, "\(date)")
            #expect(r.long(4) == molad + 3 * jour && r.long(5) == molad + 7 * jour, "\(date)")
            for (k, usage) in Levana.Usage.allCases.enumerated() {
                let f = Levana.fenetre(date, z, usage)
                let restriction = r.estNul(9 + 2 * k) ? nil : r.texte(9 + 2 * k)
                #expect(f.molad == molad, "\(date) \(usage.cle)")
                #expect(f.debut == r.long(8 + 2 * k), "\(date) \(usage.cle) : début")
                #expect(f.fin == (usage.quinzeJours ? r.long(6) : r.long(7)), "\(date) \(usage.cle) : fin")
                #expect(f.restriction?.rawValue == restriction, "\(date) \(usage.cle) : restriction")
            }
        }
    }

    /// Une année de soirs : la fenêtre retenue, ses soirs, l'état du jour et le motsaé Chabbat, dans trois fuseaux.
    @Test func lesJoursDesVecteursSontRendusALIdentique() throws {
        let lignes = try vecteurs().textes("jours")
        #expect(lignes.count > 800)
        var fuseaux: [String: Fuseau] = [:]
        for ligne in lignes {
            let c = ligne.components(separatedBy: "|")
            try #require(c.count == 8, "\(ligne)")
            let usage = try #require(Levana.Usage(rawValue: c[1]))
            if fuseaux[c[2]] == nil { fuseaux[c[2]] = try zone(c[2]) }
            let z = try #require(fuseaux[c[2]])
            let date = JourCivil.du(c[0])
            let f = Levana.fenetre(date, z, usage)
            let etat = switch Levana.etat(f, date, z) {
            case .dans(let n): "D\(n)"
            case .ceSoir: "C"
            case .dernierSoir: "L"
            }
            let rendu = [c[0], c[1], c[2], f.restriction?.rawValue ?? "-", f.premierSoir(z).iso, f.dernierSoir(z).iso, etat,
                         Levana.motsaeChabbat(f, date, z)?.iso ?? "-"].joined(separator: "|")
            #expect(rendu == ligne)
        }
    }

    @Test func laLuneEtLaPlaceDansLeMoisSuiventLaJVM() throws {
        let v = try vecteurs()
        for case .tableau(let p) in v.tableau("phases") ?? [] {
            let lune = Levana.phase(millis: p.long(0))
            #expect(abs(lune.eclairage - p.double(1)) < 1e-9 && lune.croissante == p.booleen(2), "\(p.long(0))")
        }
        let f = Levana.fenetre(.du("2026-10-14"), try zone())
        let parts = v.tableau("parts") ?? []
        #expect(parts.count == 35)
        for case .tableau(let p) in parts {
            #expect(Double(Levana.part(f, p.long(0))) == p.double(1), "\(p.long(0))")
        }
    }
}
