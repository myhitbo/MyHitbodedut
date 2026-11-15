import Foundation
import Testing
@testable import Coeur

/// TropheesTest d'Android, porté : les trophées à niveaux (12/10), valeurs, rangs, métaux, progression,
/// nouveautés. Puis tout `Tests/Vecteurs/trophees.json`, écrit par la JVM (tools/vecteurs_ios/VecteursTrophees.kt) :
/// les familles, le chemin, les grades, des pratiques, et des historiques jour par jour avec leurs dates de gain
/// et le bilan de la semaine (BilanSemaine). Rien ne reste à Android.
@Suite("Trophées")
struct TropheesTests {

    private let dimanche = JourCivil.du("2026-10-04")

    private func jours(_ n: Int, pas: Int = 1, minutes: Int = 20) -> [JourCivil: Int] {
        var m: [JourCivil: Int] = [:]
        for i in 0..<max(n, 0) { m[dimanche.plus(jours: i * pas)] = minutes }
        return m
    }

    @Test func rienSansPratiqueLePremierPasDesLePremierJour() {
        let rien = Trophees.gagnes(Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0))
        let vide = rien.isEmpty
        #expect(vide)
        let un = Trophees.gagnes(Trophees.Pratique(minutes: jours(1), notes: 0, meilleureSerie: 1))
        let premierPas = un.contains(Trophees.Niveau(famille: .premierPas, rang: 1))
        #expect(premierPas)
    }

    @Test func chaqueNiveauAtteintEstGagneEtLesRangsSuiventLesSeuils() {
        var m = jours(41)
        m[dimanche.plus(jours: 60)] = 130
        let p = Trophees.Pratique(minutes: m, notes: 26, meilleureSerie: 41)
        let rangJours = Trophees.rang(p, .jours)
        #expect(rangJours == 7)  // 42 jours : 7, 10, 15, 18, 20, 30, 40
        let rangSerie = Trophees.rang(p, .serie)
        #expect(rangSerie == 9)  // 41 : 3, 5, 7, 10, 15, 18, 20, 30, 40
        let rangSeance = Trophees.rang(p, .seanceLongue)
        #expect(rangSeance == 12)  // 130 min : de 10 à 120
        let rangPlume = Trophees.rang(p, .plume)
        #expect(rangPlume == 3)  // 26 notes : 1, 10, 25
        let rangRetour = Trophees.rang(p, .retour)
        #expect(rangRetour == 1)
        let semaines = Trophees.semainesPleines(Set(jours(41).keys))
        #expect(semaines == 6)  // du 4/10 au vendredi 13/11
        let g = Trophees.gagnes(p)
        for r in 1...7 {
            let gagne = g.contains(Trophees.Niveau(famille: .jours, rang: r))
            #expect(gagne, "jours:\(r)")
        }
        let rangPremierPas = Trophees.rang(p, .premierPas)
        #expect(rangPremierPas == 5)  // 42 jours : les cinq premiers
    }

    @Test func lesMetauxMontentDeBronzeAPlatineSansSauter() {
        for f in Trophees.Famille.allCases where f.seuils.count > 1 {
            var m: [Trophees.Metal] = []
            for r in 1...f.seuils.count { m.append(Trophees.metal(f, r)) }
            let premier = m[0]
            #expect(premier == Trophees.Metal.bronze, "\(f.rawValue)")
            let dernier = m[m.count - 1]
            #expect(dernier == Trophees.Metal.platine, "\(f.rawValue)")
            for i in 1..<m.count {
                let saut = m[i].ordinal - m[i - 1].ordinal
                let sansSauter = saut >= 0 && saut <= 1
                #expect(sansSauter, "\(f.rawValue) : rang \(i + 1)")
            }
            let seuils = f.seuils
            for i in 1..<seuils.count {
                let croissant = seuils[i] > seuils[i - 1]
                #expect(croissant, "\(f.rawValue) : seuil \(i + 1)")
            }
        }
        let bronze = Trophees.metal(.premierPas, 1)
        #expect(bronze == Trophees.Metal.bronze)
    }

    @Test func laProgressionViseLeNiveauSuivantEtLeSommetResteAuDernierSeuil() {
        let pratiques = [
            Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0),
            Trophees.Pratique(minutes: jours(6, minutes: 70), notes: 12, meilleureSerie: 6),
            Trophees.Pratique(minutes: jours(700, pas: 1, minutes: 200), notes: 200, meilleureSerie: 700),
        ]
        for p in pratiques {
            for f in Trophees.Famille.allCases {
                let r = Trophees.rang(p, f)
                let pr = Trophees.progres(p, f)
                let seuils = f.seuils
                let cible = pr.cible
                if r < seuils.count {
                    #expect(cible == seuils[r], "\(f.rawValue)")
                    let enDessous = pr.valeur < pr.cible
                    #expect(enDessous, "\(f.rawValue)")
                } else {
                    #expect(cible == seuils[seuils.count - 1], "\(f.rawValue)")
                }
                let fraction = pr.fraction
                let bornee = fraction >= 0 && fraction <= 1
                #expect(bornee, "\(f.rawValue)")
            }
        }
    }

    @Test func lesNouveautesLePlusHautDeChaqueFamilleRienLaPremiereFoisNiDepuisLAncienFormat() {
        let g = Trophees.gagnes(Trophees.Pratique(minutes: jours(20), notes: 0, meilleureSerie: 20))
        let premiereFois = Trophees.nouveaux(g, vus: nil)
        let rienLaPremiereFois = premiereFois.isEmpty
        #expect(rienLaPremiereFois)
        let ancien = Trophees.nouveaux(g, vus: ["chai", "premier_pas"])
        let rienDepuisLAncien = ancien.isEmpty
        #expect(rienDepuisLAncien)
        let n = Trophees.nouveaux(g, vus: ["premier_pas:1"])
        let familles = Set(n.map { $0.famille }).count
        let nombre = n.count
        #expect(familles == nombre)
        let joursCinq = n.contains(Trophees.Niveau(famille: .jours, rang: 5))
        #expect(joursCinq)
    }

    // MARK: Les vecteurs de la JVM

    private struct FormeV: Decodable {
        let nom: String
        let cle: String
    }

    private struct FamilleV: Decodable {
        let nom: String
        let cle: String
        let icone: String
        let seuils: [Int]
        let forme: String
    }

    /// [famille, un entier, un texte] : [famille, rang, métal].
    private struct MetalV: Decodable {
        let famille: String
        let rang: Int
        let metal: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            famille = try c.decode(String.self)
            rang = try c.decode(Int.self)
            metal = try c.decode(String.self)
        }
    }

    /// [famille, seuil, moitié haute des bits du coût, moitié basse].
    private struct CoutV: Decodable {
        let famille: String
        let seuil: Int
        let haute: Int
        let basse: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            famille = try c.decode(String.self)
            seuil = try c.decode(Int.self)
            haute = try c.decode(Int.self)
            basse = try c.decode(Int.self)
        }

        var bits: UInt64 {
            UInt64(UInt32(truncatingIfNeeded: haute)) << 32 | UInt64(UInt32(truncatingIfNeeded: basse))
        }
    }

    /// [compte, métal]
    private struct GradeV: Decodable {
        let compte: Int
        let metal: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            compte = try c.decode(Int.self)
            metal = try c.decode(String.self)
        }
    }

    private struct SuiteV: Decodable {
        let nom: String
        let debut: String?
        let jours: [Int]
        let plusLongueSuite: Int
        let semainesPleines: Int
        let retours: Int
    }

    /// [famille, cible, valeur, rang, cible de la progression, bits de sa fraction]
    private struct SeuilV: Decodable {
        let famille: String
        let nombres: [Int]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            famille = try c.decode(String.self)
            var lus: [Int] = []
            while !c.isAtEnd {
                let n = try c.decode(Int.self)
                lus.append(n)
            }
            nombres = lus
        }
    }

    /// Une pratique écrite depuis « debut » : minutes jour par jour, plages [décalage, nombre, pas, minutes]
    /// posées par-dessus, notes, meilleure série, Tikoun en décalages et en plages [décalage, nombre, pas].
    /// Un champ vide est omis.
    private struct PratiqueV: Decodable {
        let debut: String
        let parJour: [Int?]?
        let plages: [[Int]]?
        let notes: Int?
        let meilleureSerie: Int?
        let tikkun: [Int]?
        let plagesTikkun: [[Int]]?
    }

    /// Ce que la JVM a répondu d'une pratique.
    private struct Analyse: Decodable {
        struct NouveauxV: Decodable {
            /// « nul » : aucune visite ; « ajoutes » : vus = la liste ; « sauf » : vus = les gagnés moins la liste.
            let type: String
            let liste: [String]
            let rendus: [String]
        }

        let valeurs: [Int]
        let rangs: [Int]
        let gagnes: Int
        /// [valeur, cible, bits de la fraction], famille par famille.
        let progres: [[Int]]
        let prochain: String?
        let proche: String?
        /// Pour k = 0, 1, 2, 3, 10.
        let plusProches: [[String]]
        let plusProchesParDefaut: [String]
        let nouveaux: [NouveauxV]
        /// La fraction vers chaque étape du chemin, pour les cas des tests.
        let fractions: [Int]?
    }

    private struct CasPratique: Decodable {
        let nom: String
        let pratique: PratiqueV
        let analyse: Analyse

        private enum CodingKeys: String, CodingKey {
            case nom, pratique
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            nom = try c.decode(String.self, forKey: .nom)
            pratique = try c.decode(PratiqueV.self, forKey: .pratique)
            analyse = try Analyse(from: decoder)
        }
    }

    /// [aujourd'hui, null] ou [aujourd'hui, début, minutes, jours, précédente, écart, record, trophées],
    /// en décalages depuis le début de la pratique.
    private struct BilanV: Decodable {
        struct Attendu {
            let debut: Int
            let minutes: Int
            let jours: Int
            let precedente: Int
            let ecart: Int
            let record: Bool
            let trophees: [String]
        }

        let aujourdhui: Int
        let attendu: Attendu?

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            aujourdhui = try c.decode(Int.self)
            if try c.decodeNil() {
                attendu = nil
                return
            }
            let debut = try c.decode(Int.self)
            let minutes = try c.decode(Int.self)
            let jours = try c.decode(Int.self)
            let precedente = try c.decode(Int.self)
            let ecart = try c.decode(Int.self)
            let record = try c.decode(Bool.self)
            let trophees = try c.decode([String].self)
            attendu = Attendu(debut: debut, minutes: minutes, jours: jours, precedente: precedente, ecart: ecart,
                              record: record, trophees: trophees)
        }
    }

    private struct Historique: Decodable {
        let nom: String
        let pratique: PratiqueV
        let jourNotes: [Int]
        let samedis: Bool
        let exemptes: [Int]
        let meilleureSerie: Int
        /// La date de gain de chaque étape du chemin, en décalage depuis le début ; null : pas gagnée.
        let dates: [Int?]
        /// Combien de fois la règle a demandé si un jour était exempté.
        let demandes: Int
        let datesDesBilans: Bool
        let bilans: [BilanV]
        let analyse: Analyse

        private enum CodingKeys: String, CodingKey {
            case nom, pratique, jourNotes, samedis, exemptes, meilleureSerie, dates, demandes, datesDesBilans, bilans
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            nom = try c.decode(String.self, forKey: .nom)
            pratique = try c.decode(PratiqueV.self, forKey: .pratique)
            jourNotes = try c.decode([Int].self, forKey: .jourNotes)
            samedis = try c.decode(Bool.self, forKey: .samedis)
            exemptes = try c.decode([Int].self, forKey: .exemptes)
            meilleureSerie = try c.decode(Int.self, forKey: .meilleureSerie)
            dates = try c.decode([Int?].self, forKey: .dates)
            demandes = try c.decode(Int.self, forKey: .demandes)
            datesDesBilans = try c.decode(Bool.self, forKey: .datesDesBilans)
            bilans = try c.decode([BilanV].self, forKey: .bilans)
            analyse = try Analyse(from: decoder)
        }
    }

    private struct Vecteurs: Decodable {
        let metaux: [String]
        let formes: [FormeV]
        let familles: [FamilleV]
        let metal: [MetalV]
        let couts: [CoutV]
        let chemin: [String]
        let seuilsGrades: [Int]
        let grades: [GradeV]
        /// [valeur, cible, bits de la fraction]
        let progres: [[Int]]
        let suites: [SuiteV]
        let seuils: [SeuilV]
        let pratiques: [CasPratique]
        let historiques: [Historique]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/trophees.json"))
    }

    private func famille(_ nom: String) throws -> Trophees.Famille {
        try #require(Trophees.Famille(rawValue: nom), "famille inconnue : \(nom)")
    }

    private func jour(_ texte: String) throws -> JourCivil {
        try #require(JourCivil(iso: texte), "date illisible : \(texte)")
    }

    private func bits(_ f: Float) -> Int { Int(Int32(bitPattern: f.bitPattern)) }

    /// Une pratique lue comme VecteursTrophees.Ecrite la bâtit.
    private struct Lue {
        let debut: JourCivil
        let minutes: [JourCivil: Int]
        let notes: Int
        let meilleureSerie: Int
        let tikkun: Set<JourCivil>
    }

    private func lire(_ v: PratiqueV) throws -> Lue {
        let debut = try jour(v.debut)
        var minutes: [JourCivil: Int] = [:]
        for (i, m) in (v.parJour ?? []).enumerated() {
            if let m { minutes[debut.plus(jours: i)] = m }
        }
        for plage in v.plages ?? [] {
            let complete = plage.count == 4
            #expect(complete, "plage : \(plage)")
            if !complete { continue }
            for k in 0..<max(plage[1], 0) { minutes[debut.plus(jours: plage[0] + k * plage[2])] = plage[3] }
        }
        var tikkun = Set<JourCivil>()
        for o in v.tikkun ?? [] { tikkun.insert(debut.plus(jours: o)) }
        for plage in v.plagesTikkun ?? [] {
            let complete = plage.count == 3
            #expect(complete, "plage du Tikoun : \(plage)")
            if !complete { continue }
            for k in 0..<max(plage[1], 0) { tikkun.insert(debut.plus(jours: plage[0] + k * plage[2])) }
        }
        return Lue(debut: debut, minutes: minutes, notes: v.notes ?? 0, meilleureSerie: v.meilleureSerie ?? 0,
                   tikkun: tikkun)
    }

    @Test func lesFamillesLesFormesEtLesMetauxDAndroid() throws {
        let v = try vecteurs()
        let metaux = Trophees.Metal.allCases.map { $0.rawValue }
        #expect(metaux == v.metaux)
        let formes = Trophees.Forme.allCases.map { $0.rawValue }
        let formesAttendues = v.formes.map { $0.nom }
        #expect(formes == formesAttendues)
        for fv in v.formes {
            let forme = try #require(Trophees.Forme(rawValue: fv.nom), "forme inconnue : \(fv.nom)")
            let cle = forme.cle
            #expect(cle == fv.cle, "\(fv.nom)")
        }
        let familles = Trophees.Famille.allCases.map { $0.rawValue }
        let famillesAttendues = v.familles.map { $0.nom }
        #expect(familles == famillesAttendues)
        for fv in v.familles {
            let f = try famille(fv.nom)
            let cle = f.cle
            #expect(cle == fv.cle, "\(fv.nom)")
            let icone = f.icone
            #expect(icone == fv.icone, "\(fv.nom)")
            let seuils = f.seuils
            #expect(seuils == fv.seuils, "\(fv.nom)")
            let forme = f.forme.rawValue
            #expect(forme == fv.forme, "\(fv.nom)")
        }
        let nombre = v.metal.count
        #expect(nombre > 250)
        for m in v.metal {
            let f = try famille(m.famille)
            let metal = Trophees.metal(f, m.rang).rawValue
            #expect(metal == m.metal, "metal(\(m.famille), \(m.rang))")
            if m.rang >= 1 && m.rang <= f.seuils.count {
                let duNiveau = Trophees.Niveau(famille: f, rang: m.rang).metal.rawValue
                #expect(duNiveau == m.metal, "Niveau(\(m.famille), \(m.rang)).metal")
            }
        }
    }

    @Test func leCheminLesCoutsEtLesGradesDAndroid() throws {
        let v = try vecteurs()
        for c in v.couts {
            let f = try famille(c.famille)
            let cout = Trophees.cout(f, c.seuil).bitPattern
            #expect(cout == c.bits, "cout(\(c.famille), \(c.seuil))")
        }
        let chemin = Trophees.chemin.map { $0.cle }
        #expect(chemin == v.chemin)
        let seuilsGrades = Trophees.seuilsGrades
        #expect(seuilsGrades == v.seuilsGrades)
        for g in v.grades {
            let grade = Trophees.grade(g.compte).rawValue
            #expect(grade == g.metal, "grade(\(g.compte))")
        }
        let nombre = v.progres.count
        #expect(nombre > 100)
        for cas in v.progres {
            let complet = cas.count == 3
            #expect(complet, "\(cas)")
            if !complet { continue }
            let fraction = bits(Trophees.Progres(valeur: cas[0], cible: cas[1]).fraction)
            #expect(fraction == cas[2], "Progres(\(cas[0]), \(cas[1]))")
        }
    }

    @Test func lesSuitesLesSemainesPleinesEtLesRetoursDAndroid() throws {
        let v = try vecteurs()
        for s in v.suites {
            var jours = Set<JourCivil>()
            if let texte = s.debut {
                let debut = try jour(texte)
                for o in s.jours { jours.insert(debut.plus(jours: o)) }
            }
            let suite = Trophees.plusLongueSuite(jours)
            #expect(suite == s.plusLongueSuite, "\(s.nom) : plus longue suite")
            let pleines = Trophees.semainesPleines(jours)
            #expect(pleines == s.semainesPleines, "\(s.nom) : semaines pleines")
            let retours = Trophees.retours(jours)
            #expect(retours == s.retours, "\(s.nom) : retours")
        }
    }

    /// La pratique minimale de VecteursTrophees.pourValeur, depuis le dimanche 4/10/2026 : la famille y vaut `v`.
    private func pourValeur(_ f: Trophees.Famille, _ v: Int) -> Trophees.Pratique {
        let n = max(v, 0)
        var minutes: [JourCivil: Int] = [:]
        var notes = 0
        var serie = 0
        var tikkun = Set<JourCivil>()
        switch f {
        case .premierPas, .jours:
            for k in 0..<n { minutes[dimanche.plus(jours: k)] = 1 }
        case .seanceLongue:
            minutes[dimanche] = v
        case .serie:
            serie = v
        case .heures:
            minutes[dimanche] = v * 60
        case .semaines:
            for w in 0..<n {
                for k in 0..<6 { minutes[dimanche.plus(jours: 7 * w + k)] = 15 }
            }
        case .erevChabbat:
            for k in 0..<n { minutes[dimanche.plus(jours: 5 + 7 * k)] = 15 }
        case .retour:
            for k in 0...n { minutes[dimanche.plus(jours: 8 * k)] = 15 }
        case .plume:
            notes = v
        case .tikkun:
            for k in 0..<n { tikkun.insert(dimanche.plus(jours: 2 * k)) }
        case .tikkunSerie:
            for k in 0..<n { tikkun.insert(dimanche.plus(jours: k)) }
        }
        return Trophees.Pratique(minutes: minutes, notes: notes, meilleureSerie: serie, tikkun: tikkun)
    }

    /// Chaque seuil de chaque famille : juste sous, dessus, et au-delà du dernier.
    @Test func chaqueSeuilCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.seuils.count
        #expect(nombre > 250)
        for s in v.seuils {
            let complet = s.nombres.count == 5
            #expect(complet, "\(s.famille) \(s.nombres)")
            if !complet { continue }
            let f = try famille(s.famille)
            let p = pourValeur(f, s.nombres[0])
            let pr = Trophees.progres(p, f)
            let rendus = [Trophees.valeur(p, f), Trophees.rang(p, f), pr.cible, bits(pr.fraction)]
            let attendus = Array(s.nombres[1..<5])
            #expect(rendus == attendus, "\(s.famille) à \(s.nombres[0])")
        }
    }

    /// Valeurs, rangs, gagnés, progression, prochain, proche, plus proches, nouveautés et fractions.
    private func verifie(_ a: Analyse, _ p: Trophees.Pratique, _ nom: String) {
        let familles = Trophees.Famille.allCases
        let valeurs = familles.map { Trophees.valeur(p, $0) }
        #expect(valeurs == a.valeurs, "\(nom) : valeurs")
        let rangs = familles.map { Trophees.rang(p, $0) }
        #expect(rangs == a.rangs, "\(nom) : rangs")
        let gagnes = Trophees.gagnes(p)
        let nombre = gagnes.count
        #expect(nombre == a.gagnes, "\(nom) : gagnés")
        // Les gagnés sont tous les rangs, de 1 à celui de chaque famille.
        var attendus = Set<Trophees.Niveau>()
        for (f, r) in zip(familles, a.rangs) where r >= 1 {
            for i in 1...r { attendus.insert(Trophees.Niveau(famille: f, rang: i)) }
        }
        #expect(gagnes == attendus, "\(nom) : les niveaux gagnés")
        let nombreProgres = a.progres.count
        #expect(nombreProgres == familles.count, "\(nom) : progression")
        for (f, ligne) in zip(familles, a.progres) {
            let complete = ligne.count == 3
            #expect(complete, "\(nom) : \(ligne)")
            if !complete { continue }
            let pr = Trophees.progres(p, f)
            let rendus = [pr.valeur, pr.cible, bits(pr.fraction)]
            #expect(rendus == ligne, "\(nom) : progres(\(f.rawValue))")
        }
        let prochain = Trophees.prochain(p)?.cle
        #expect(prochain == a.prochain, "\(nom) : prochain")
        let proche = Trophees.proche(p)?.cle
        #expect(proche == a.proche, "\(nom) : proche")
        let ks = [0, 1, 2, 3, 10]
        let nombreK = a.plusProches.count
        #expect(nombreK == ks.count, "\(nom) : plus proches")
        for (k, attendu) in zip(ks, a.plusProches) {
            let rendus = Trophees.plusProches(p, k: k).map { $0.cle }
            #expect(rendus == attendu, "\(nom) : plusProches(\(k))")
        }
        let parDefaut = Trophees.plusProches(p).map { $0.cle }
        #expect(parDefaut == a.plusProchesParDefaut, "\(nom) : plusProches()")
        let cles = Set(gagnes.map { $0.cle })
        for n in a.nouveaux {
            let vus: Set<String>?
            switch n.type {
            case "nul": vus = nil
            case "ajoutes": vus = Set(n.liste)
            default: vus = cles.subtracting(n.liste)
            }
            let rendus = Trophees.nouveaux(gagnes, vus: vus).map { $0.cle }
            #expect(rendus == n.rendus, "\(nom) : nouveaux, \(n.type) \(n.liste)")
        }
        if let fractions = a.fractions {
            let calculees = Trophees.chemin.map { bits(Trophees.fraction(p, $0)) }
            #expect(calculees == fractions, "\(nom) : fractions du chemin")
            var gagnesDuChemin = Set<Trophees.Niveau>()
            for n in Trophees.chemin where Trophees.gagne(p, n) { gagnesDuChemin.insert(n) }
            #expect(gagnesDuChemin == gagnes, "\(nom) : gagne() sur le chemin")
        }
    }

    @Test func chaquePratiqueCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.pratiques.count
        #expect(nombre > 30)
        for cas in v.pratiques {
            let lue = try lire(cas.pratique)
            let p = Trophees.Pratique(minutes: lue.minutes, notes: lue.notes, meilleureSerie: lue.meilleureSerie,
                                      tikkun: lue.tikkun)
            verifie(cas.analyse, p, cas.nom)
        }
    }

    /// Les dates de gain (rejeu jour après jour, jours exemptés compris, avec le compte des demandes), la
    /// meilleure série de Plaque, tout ce que regarde `verifie`, puis le bilan de la semaine écoulée vu de
    /// plusieurs jours.
    @Test func chaqueHistoriqueCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.historiques.count
        #expect(nombre > 40)
        let chemin = Trophees.chemin
        for h in v.historiques {
            let lue = try lire(h.pratique)
            var notes = Set<JourCivil>()
            for o in h.jourNotes { notes.insert(lue.debut.plus(jours: o)) }
            var exemptes = Set<JourCivil>()
            for o in h.exemptes { exemptes.insert(lue.debut.plus(jours: o)) }
            let samedis = h.samedis
            var demandes = 0
            let dates = Trophees.datesGain(lue.minutes, notes, tikkun: lue.tikkun) { j in
                demandes += 1
                return exemptes.contains(j) || (samedis && j.jourDeSemaine == 7)
            }
            #expect(demandes == h.demandes, "\(h.nom) : demandes d'exemption")
            let nombreDates = h.dates.count
            #expect(nombreDates == chemin.count, "\(h.nom) : dates")
            var attendues: [String: JourCivil] = [:]
            for (n, o) in zip(chemin, h.dates) {
                if let o { attendues[n.cle] = lue.debut.plus(jours: o) }
            }
            #expect(dates == attendues, "\(h.nom) : dates de gain")
            let serie = Plaque.meilleureSerie(Set(lue.minutes.keys)) { j in
                exemptes.contains(j) || (samedis && j.jourDeSemaine == 7)
            }
            #expect(serie == h.meilleureSerie, "\(h.nom) : meilleure série")
            let p = Trophees.Pratique(minutes: lue.minutes, notes: notes.count, meilleureSerie: serie, tikkun: lue.tikkun)
            verifie(h.analyse, p, h.nom)
            let datesDesBilans = h.datesDesBilans ? attendues : [:]
            for b in h.bilans {
                let rendu = BilanSemaine.precedente(lue.debut.plus(jours: b.aujourdhui), minutes: lue.minutes,
                                                    dates: datesDesBilans)
                let contexte = "\(h.nom) : bilan vu du jour \(b.aujourdhui)"
                guard let attendu = b.attendu else {
                    #expect(rendu == nil, "\(contexte)")
                    continue
                }
                let bilan = try #require(rendu, "\(contexte)")
                let debut = bilan.debut.jourJulien - lue.debut.jourJulien
                let rendus = [debut, bilan.minutes, bilan.jours, bilan.precedente, bilan.ecart]
                let nombres = [attendu.debut, attendu.minutes, attendu.jours, attendu.precedente, attendu.ecart]
                #expect(rendus == nombres, "\(contexte)")
                let record = bilan.record
                #expect(record == attendu.record, "\(contexte) : record")
                let trophees = bilan.trophees.map { $0.cle }
                #expect(trophees == attendu.trophees, "\(contexte) : trophées")
            }
        }
    }
}
