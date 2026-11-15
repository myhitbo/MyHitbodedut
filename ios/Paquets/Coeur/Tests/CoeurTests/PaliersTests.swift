import Foundation
import Testing
@testable import Coeur

/// PaliersTest d'Android, porté : les paliers d'objectifs (11/10), après chaque palier le suivant. Puis tout
/// `Tests/Vecteurs/paliers.json`, écrit par la JVM (tools/vecteurs_ios/VecteursPaliers.kt). Rien ne reste à
/// Android.
@Suite("Paliers")
struct PaliersTests {

    @Test func apresSeptJoursDAffileeLePalierSuivantEstQuatorze() {
        let e = Paliers.etat(.serie, valeur: 7)
        let atteint = e.atteint
        #expect(atteint == 7)
        let prochain = e.prochain
        #expect(prochain == 14)
        let reste = e.reste
        #expect(reste == 7)
        let rang = e.rang
        #expect(rang == 2)  // 3 et 7
        let depart = Paliers.etat(.serie, valeur: 0).prochain
        #expect(depart == 3)
    }

    @Test func auDelaDeLEchelleLePasContinue() {
        let serie = Paliers.etat(.serie, valeur: 400).prochain
        #expect(serie == 730)
        let cumul = Paliers.etat(.cumul, valeur: 61000).prochain
        #expect(cumul == 72000)
    }

    @Test func lObjectifQuotidienEstUnPalierDuJour() {
        let echelle = Paliers.echelle(.jour, jusqua: 0, objectifJour: 25)
        let contient = echelle.contains(25)
        #expect(contient)
        let prochain = Paliers.etat(.jour, valeur: 21, objectifJour: 25).prochain
        #expect(prochain == 25)
    }

    @Test func lesPeriodesRepartentEtLeMoisEstLeMoisHebreu() {
        let aujourdhui = JourCivil.du("2026-10-14")  // mercredi, 3 'Hechvan 5787
        let minutes: [JourCivil: Int] = [
            JourCivil.du("2026-10-10"): 20,  // samedi précédent : hors semaine, en Tichri
            JourCivil.du("2026-10-12"): 30,  // 1 'Hechvan
            JourCivil.du("2026-10-14"): 15,
        ]
        let b = Paliers.Bilan(aujourdhui: aujourdhui, minutes: minutes, serie: 2,
                              debutMoisHebreu: JourCivil.du("2026-10-12"), objectifJour: 20)
        let etats = Paliers.etats(b)
        var parPiste: [Paliers.Piste: Int] = [:]
        for e in etats { parPiste[e.piste] = e.valeur }
        let jour = parPiste[Paliers.Piste.jour]
        #expect(jour == 15)
        let semaine = parPiste[Paliers.Piste.semaine]
        #expect(semaine == 45)
        let mois = parPiste[Paliers.Piste.mois]
        #expect(mois == 45)
        let cumul = parPiste[Paliers.Piste.cumul]
        #expect(cumul == 65)
        let jours = parPiste[Paliers.Piste.jours]
        #expect(jours == 3)
        // Le jour se fête par date, la série une fois pour toutes.
        let m = Paliers.marques(etats, b)
        let duJour = m.contains("jour:2026-10-14:15")
        #expect(duJour)
        var deLaSerie = 0
        for marque in m where marque.commenceParUnites("serie") { deLaSerie += 1 }
        #expect(deLaSerie == 0)  // 2 jours : pas encore 3
        let nouvelles = Set(Paliers.nouveaux(etats, b, vus: []).map { $0.piste })
        let attendues: Set<Paliers.Piste> = [.jour, .semaine, .cumul, .jours]
        #expect(nouvelles == attendues)
        let rien = Paliers.nouveaux(etats, b, vus: m)
        let aucune = rien.isEmpty
        #expect(aucune)
    }

    @Test func recordsEtPalierALaUne() throws {
        let minutes: [JourCivil: Int] = [
            JourCivil.du("2026-10-04"): 30, JourCivil.du("2026-10-05"): 40, JourCivil.du("2026-10-12"): 20,
        ]
        let coupure = JourCivil.du("2026-10-12")
        let r = Paliers.records(minutes) { $0 < coupure ? "tichri" : "hechvan" }
        let attendu = Paliers.Records(jour: 40, semaine: 70, mois: 70)
        #expect(r == attendu)
        let etats = [Paliers.etat(.serie, valeur: 6), Paliers.etat(.jour, valeur: 5)]
        let une = try #require(Paliers.aLaUne(etats))
        let piste = une.piste
        #expect(piste == Paliers.Piste.serie)  // 6 sur 3→7 : 75 %, contre 5/10 : 50 %
    }

    // MARK: Les vecteurs de la JVM

    private struct PisteV: Decodable {
        let nom: String
        let cle: String
        let base: [Int]
        let pas: Int
    }

    /// [piste, jusqua, objectif du jour, échelle]
    private struct EchelleV: Decodable {
        let piste: String
        let jusqua: Int
        let objectif: Int
        let liste: [Int]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            piste = try c.decode(String.self)
            jusqua = try c.decode(Int.self)
            objectif = try c.decode(Int.self)
            liste = try c.decode([Int].self)
        }
    }

    /// [piste, valeur donnée, objectif, valeur, atteint, prochain, rang, reste, bits de l'avancée]
    private struct EtatV: Decodable {
        let piste: String
        let nombres: [Int]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            piste = try c.decode(String.self)
            var lus: [Int] = []
            while !c.isAtEnd {
                let n = try c.decode(Int.self)
                lus.append(n)
            }
            nombres = lus
        }
    }

    /// [début, fin (null : aujourd'hui), somme]
    private struct EntreV: Decodable {
        let debut: String
        let fin: String?
        let somme: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            debut = try c.decode(String.self)
            if try c.decodeNil() {
                fin = nil
            } else {
                fin = try c.decode(String.self)
            }
            somme = try c.decode(Int.self)
        }
    }

    /// [jour, minutes]
    private struct MinutesV: Decodable {
        let jour: String
        let minutes: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            jour = try c.decode(String.self)
            minutes = try c.decode(Int.self)
        }
    }

    private struct BilanV: Decodable {
        struct NouveauxV: Decodable {
            let base: Bool
            let retires: [String]
            let ajoutes: [String]
            let pistes: [String]
        }

        let nom: String
        let aujourdhui: String
        let minutes: [MinutesV]
        let serie: Int
        let debutMoisHebreu: String
        let objectifJour: Int
        let debutSemaine: String
        let entre: [EntreV]
        /// [piste, valeur, atteint, prochain, rang, bits de l'avancée]
        let etats: [EtatV]
        let aLaUne: String
        let marques: [String]
        let nouveaux: [NouveauxV]
    }

    /// [piste, valeur, objectif] (ou [piste, valeur, prochain] pour un état bâti à la main)
    private struct TripletV: Decodable {
        let piste: String
        let a: Int
        let b: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            piste = try c.decode(String.self)
            a = try c.decode(Int.self)
            b = try c.decode(Int.self)
        }
    }

    private struct ALaUneV: Decodable {
        let etats: [TripletV]
        let indice: Int?
    }

    private struct RecordsV: Decodable {
        let minutes: [MinutesV]
        let coupures: [String]
        let records: [Int]
    }

    private struct Vecteurs: Decodable {
        let pistes: [PisteV]
        let echelles: [EchelleV]
        let etats: [EtatV]
        /// [valeur, prochain, reste, bits de l'avancée]
        let avancees: [[Int]]
        let bilans: [BilanV]
        let aLaUne: [ALaUneV]
        let aLaUneMain: [ALaUneV]
        let records: [RecordsV]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/paliers.json"))
    }

    private func piste(_ nom: String) throws -> Paliers.Piste {
        try #require(Paliers.Piste(rawValue: nom), "piste inconnue : \(nom)")
    }

    private func jour(_ texte: String) throws -> JourCivil {
        try #require(JourCivil(iso: texte), "date illisible : \(texte)")
    }

    private func lireMinutes(_ lignes: [MinutesV]) throws -> [JourCivil: Int] {
        var minutes: [JourCivil: Int] = [:]
        for m in lignes {
            let j = try jour(m.jour)
            minutes[j] = m.minutes
        }
        return minutes
    }

    /// Les bits d'une avancée attendue : NaN se compare par sa nature (ses bits dépendent du processeur).
    private func memeFlottant(_ calcule: Float, _ bits: Int) -> Bool {
        let attendu = Float(bitPattern: UInt32(truncatingIfNeeded: bits))
        if attendu.isNaN { return calcule.isNaN }
        return calcule.bitPattern == attendu.bitPattern
    }

    @Test func lesEchellesCommeSurAndroid() throws {
        let v = try vecteurs()
        let noms = Paliers.Piste.allCases.map { $0.rawValue }
        let attendus = v.pistes.map { $0.nom }
        #expect(noms == attendus)
        for p in v.pistes {
            let quelle = try piste(p.nom)
            let cle = quelle.cle
            #expect(cle == p.cle, "\(p.nom)")
            // Rien à couvrir : l'échelle de base ; à son dernier palier : un pas de plus.
            let base = Paliers.echelle(quelle, jusqua: -1)
            #expect(base == p.base, "\(p.nom) : base")
            let dernier = p.base.isEmpty ? 0 : p.base[p.base.count - 1]
            let unPas = Paliers.echelle(quelle, jusqua: dernier)
            let attenduUnPas = p.base + [dernier + p.pas]
            #expect(unPas == attenduUnPas, "\(p.nom) : pas")
        }
        let nombre = v.echelles.count
        #expect(nombre > 300)
        for e in v.echelles {
            let quelle = try piste(e.piste)
            let liste = Paliers.echelle(quelle, jusqua: e.jusqua, objectifJour: e.objectif)
            #expect(liste == e.liste, "echelle(\(e.piste), \(e.jusqua), \(e.objectif))")
        }
    }

    @Test func chaqueEtatCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.etats.count
        #expect(nombre > 1000)
        for cas in v.etats {
            let complet = cas.nombres.count == 8
            #expect(complet, "\(cas.piste) \(cas.nombres)")
            if !complet { continue }
            let n = cas.nombres
            let quelle = try piste(cas.piste)
            let e = Paliers.etat(quelle, valeur: n[0], objectifJour: n[1])
            let contexte = "etat(\(cas.piste), \(n[0]), \(n[1]))"
            let valeur = e.valeur
            #expect(valeur == n[2], "\(contexte) : valeur")
            let atteint = e.atteint
            #expect(atteint == n[3], "\(contexte) : atteint")
            let prochain = e.prochain
            #expect(prochain == n[4], "\(contexte) : prochain")
            let rang = e.rang
            #expect(rang == n[5], "\(contexte) : rang")
            let reste = e.reste
            #expect(reste == n[6], "\(contexte) : reste")
            let avancee = memeFlottant(e.avancee, n[7])
            #expect(avancee, "\(contexte) : avancée")
        }
    }

    /// Un état bâti à la main : prochain nul ou négatif (l'infini, NaN, le zéro négatif), reste qui déborde.
    @Test func chaqueAvanceeCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.avancees.count
        #expect(nombre > 100)
        for cas in v.avancees {
            let complet = cas.count == 4
            #expect(complet, "\(cas)")
            if !complet { continue }
            let e = Paliers.Etat(piste: .serie, valeur: cas[0], atteint: 0, prochain: cas[1], rang: 0)
            let reste = e.reste
            #expect(reste == cas[2], "reste(\(cas[0]), \(cas[1]))")
            let avancee = memeFlottant(e.avancee, cas[3])
            #expect(avancee, "avancee(\(cas[0]), \(cas[1]))")
        }
    }

    @Test func chaqueBilanCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.bilans.count
        #expect(nombre > 40)
        for cas in v.bilans {
            let minutes = try lireMinutes(cas.minutes)
            let aujourdhui = try jour(cas.aujourdhui)
            let debutMois = try jour(cas.debutMoisHebreu)
            let b = Paliers.Bilan(aujourdhui: aujourdhui, minutes: minutes, serie: cas.serie,
                                  debutMoisHebreu: debutMois, objectifJour: cas.objectifJour)
            let debutSemaine = b.debutSemaine.iso
            #expect(debutSemaine == cas.debutSemaine, "\(cas.nom)")
            for e in cas.entre {
                let debut = try jour(e.debut)
                let somme: Int
                if let texte = e.fin {
                    let fin = try jour(texte)
                    somme = b.entre(debut, fin)
                } else {
                    somme = b.entre(debut)
                }
                #expect(somme == e.somme, "\(cas.nom) : entre(\(e.debut), \(e.fin ?? "aujourd'hui"))")
            }
            let etats = Paliers.etats(b)
            let nombreEtats = etats.count
            #expect(nombreEtats == cas.etats.count, "\(cas.nom)")
            for (e, attendu) in zip(etats, cas.etats) {
                let pisteRendue = e.piste.rawValue
                #expect(pisteRendue == attendu.piste, "\(cas.nom)")
                let complet = attendu.nombres.count == 5
                #expect(complet, "\(cas.nom) : \(attendu.nombres)")
                if !complet { continue }
                let n = attendu.nombres
                let rendus = [e.valeur, e.atteint, e.prochain, e.rang]
                let attendus = Array(n[0..<4])
                #expect(rendus == attendus, "\(cas.nom) : \(attendu.piste)")
                let avancee = memeFlottant(e.avancee, n[4])
                #expect(avancee, "\(cas.nom) : avancée de \(attendu.piste)")
            }
            let une = Paliers.aLaUne(etats)?.piste.rawValue
            #expect(une == cas.aLaUne, "\(cas.nom) : à la une")
            let marques = Paliers.marques(etats, b)
            let triees = marques.sorted()
            #expect(triees == cas.marques, "\(cas.nom) : marques")
            for n in cas.nouveaux {
                let vus = (n.base ? marques : Set<String>()).subtracting(n.retires).union(n.ajoutes)
                let pistes = Paliers.nouveaux(etats, b, vus: vus).map { $0.piste.rawValue }
                #expect(pistes == n.pistes, "\(cas.nom) : nouveaux, retirés \(n.retires), ajoutés \(n.ajoutes)")
            }
        }
    }

    @Test func chaquePalierALaUneCommeSurAndroid() throws {
        let v = try vecteurs()
        for cas in v.aLaUne {
            var etats: [Paliers.Etat] = []
            for t in cas.etats {
                let quelle = try piste(t.piste)
                etats.append(Paliers.etat(quelle, valeur: t.a, objectifJour: t.b))
            }
            try verifieALaUne(etats, cas.indice, decrire(cas.etats))
        }
        // Bâtis à la main : NaN dépasse tout, -0,0 passe sous 0,0, comme compareTo sur la JVM.
        for cas in v.aLaUneMain {
            var etats: [Paliers.Etat] = []
            for t in cas.etats {
                let quelle = try piste(t.piste)
                etats.append(Paliers.Etat(piste: quelle, valeur: t.a, atteint: 0, prochain: t.b, rang: 0))
            }
            try verifieALaUne(etats, cas.indice, "à la main : " + decrire(cas.etats))
        }
    }

    private func decrire(_ triplets: [TripletV]) -> String {
        var parties: [String] = []
        for t in triplets { parties.append(t.piste + " " + String(t.a) + " " + String(t.b)) }
        return parties.joined(separator: ", ")
    }

    /// Le palier rendu est celui du rang attendu (nil si Kotlin lève) ; à égalité, le premier de la liste.
    private func verifieALaUne(_ etats: [Paliers.Etat], _ indice: Int?, _ contexte: String) throws {
        let rendu = Paliers.aLaUne(etats)
        guard let indice else {
            #expect(rendu == nil, "\(contexte)")
            return
        }
        let une = try #require(rendu, "\(contexte)")
        var premier: Int?
        for (i, e) in etats.enumerated() where e == une {
            premier = i
            break
        }
        #expect(premier == indice, "\(contexte)")
    }

    @Test func chaqueRecordCommeSurAndroid() throws {
        let v = try vecteurs()
        for cas in v.records {
            let minutes = try lireMinutes(cas.minutes)
            var coupures: [JourCivil] = []
            for texte in cas.coupures {
                let coupure = try jour(texte)
                coupures.append(coupure)
            }
            let r = Paliers.records(minutes) { d in
                var n = 0
                for c in coupures where !(d < c) { n += 1 }
                return "m\(n)"
            }
            let rendus = [r.jour, r.semaine, r.mois]
            #expect(rendus == cas.records, "records de \(cas.minutes.count) jours")
        }
    }
}
