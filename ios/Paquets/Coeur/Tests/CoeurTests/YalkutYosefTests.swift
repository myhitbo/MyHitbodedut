import Foundation
import Testing
@testable import Coeur

/// La halakha courte du jour (YalkutYosefTest.kt, 13/10, tools/yalkut_yosef_construction.py) : une
/// sélection du Yalkut Yosef, jamais le livre entier, deux se'ifim par jour selon la période ; tous les
/// cas d'Android portés, rien ne reste à Android. Puis `Tests/Vecteurs/yalkut_yosef.json`, écrit par le
/// code d'Android (tools/vecteurs_ios/VecteursYalkutYosef.kt) : chaque jour des années 5786 à 5788,
/// la fenêtre de chaque jour de chaque mois, du, la recherche, la source et la carte.
@Suite("Yalkut Yosef")
struct YalkutYosefTests {

    /// Le livre embarqué, lu une fois pour toute la suite.
    private static let lecture: Result<YalkutYosef.Livre, any Error> = Result {
        try YalkutYosef.parse(Depot.contenu("yalkut_yosef.json"))
    }

    private func livre() throws -> YalkutYosef.Livre { try Self.lecture.get() }

    // MARK: YalkutYosefTest.kt

    @Test func uneSelectionDeHalakhotCourtes() throws {
        let livre = try livre()
        let attendues: Set<String> = ["ordinaire", "chabbat", "roch_hodech", "pessah", "omer", "chavouot", "bein_hametsarim", "eloul",
                                      "kippour", "soukkot", "hanouka", "tou_bichvat", "pourim"]
        let periodes = Set(livre.periodes.keys)
        #expect(periodes == attendues)
        for p in livre.ordre {
            let seifs = livre.periodes[p] ?? []
            #expect(seifs.count >= 4, "\(p)")
            for s in seifs {
                let court = !s.texte.estBlanc && s.texte.utf16.count <= 420 && !s.siman.estBlanc
                #expect(court, "\(p) \(s.siman) \(s.lettre)")
            }
        }
    }

    @Test func chaqueJourDeTroisAnneesASesDeuxHalakhotEtEllesChangent() throws {
        let livre = try livre()
        var avant: String?
        var d = JourCivil.du("2025-09-01")
        let fin = JourCivil.du("2028-09-01")
        while d < fin {
            for il in [false, true] {
                let n = YalkutYosef.pour(livre, date: d, israel: il).count
                #expect(n == YalkutYosef.parJour, "\(d) \(il)")
            }
            let ici = YalkutYosef.pour(livre, date: d, israel: false).map { YalkutYosef.source($0) }.joined(separator: "|")
            let change = !(avant?.egalUnites(ici) ?? false)
            #expect(change, "\(d) : les mêmes halakhot que la veille")
            avant = ici
            d = d.plus(jours: 1)
        }
    }

    @Test func lesFenetresDeFete() throws {
        typealias M = CalendrierJuif.Mois
        let pourim = YalkutYosef.fenetre(mois: M.adar, jour: 14, embolismique: false)
        #expect(pourim == "pourim")
        let pourimII = YalkutYosef.fenetre(mois: M.adarII, jour: 14, embolismique: true)
        #expect(pourimII == "pourim")
        let adarI = YalkutYosef.fenetre(mois: M.adar, jour: 14, embolismique: true)
        #expect(adarI == nil)
        let pessah = YalkutYosef.fenetre(mois: M.nissan, jour: 15, embolismique: false)
        #expect(pessah == "pessah")
        // Chavouot a sa fenêtre depuis l'audit du 12/11 d'Android (avec l'omer avant).
        let omer = YalkutYosef.fenetre(mois: M.iyar, jour: 29, embolismique: false)
        #expect(omer == "omer")
        let chavouot = YalkutYosef.fenetre(mois: M.sivan, jour: 6, embolismique: false)
        #expect(chavouot == "chavouot")
        let beinHametsarim = YalkutYosef.fenetre(mois: M.av, jour: 9, embolismique: false)
        #expect(beinHametsarim == "bein_hametsarim")
        let eloul = YalkutYosef.fenetre(mois: M.tichri, jour: 1, embolismique: false)
        #expect(eloul == "eloul")
        let kippour = YalkutYosef.fenetre(mois: M.tichri, jour: 10, embolismique: false)
        #expect(kippour == "kippour")
        let soukkot = YalkutYosef.fenetre(mois: M.tichri, jour: 15, embolismique: false)
        #expect(soukkot == "soukkot")
        let hanouka = YalkutYosef.fenetre(mois: M.tevet, jour: 2, embolismique: false)
        #expect(hanouka == "hanouka")
        let touBichvat = YalkutYosef.fenetre(mois: M.chevat, jour: 15, embolismique: false)
        #expect(touBichvat == "tou_bichvat")
        let hechvan = YalkutYosef.fenetre(mois: M.hechvan, jour: 10, embolismique: false)
        #expect(hechvan == nil)
        let lendemainDePourim = YalkutYosef.periode(JourCivil.du("2027-03-25"), israel: false)  // 16 Adar II 5787
        #expect(lendemainDePourim.periode == "pessah")
        #expect(lendemainDePourim.rang == 0)
        let veille = YalkutYosef.periode(JourCivil.du("2027-03-24"), israel: false).periode
        #expect(veille == "pourim")
        let rochHodech = YalkutYosef.periode(JourCivil.du("2026-10-12"), israel: false).periode
        #expect(rochHodech == "roch_hodech")
        let vendredi = YalkutYosef.periode(JourCivil.du("2026-10-23"), israel: false).periode
        #expect(vendredi == "chabbat")
        let mercredi = YalkutYosef.periode(JourCivil.du("2026-10-21"), israel: false).periode
        #expect(mercredi == "ordinaire")
        // Audit du 16/11 : le jeûne repoussé au dimanche 10 Av n'est pas un jour ordinaire (Kitsour YY 554:13).
        #expect(YalkutYosef.periode(JourCivil.du("2029-07-22"), israel: false).periode == "bein_hametsarim")
        #expect(YalkutYosef.periode(JourCivil.du("2015-07-26"), israel: true).periode == "bein_hametsarim")
        // Le vendredi 10 Av : le jeûne était la veille.
        #expect(YalkutYosef.periode(JourCivil.du("2026-07-24"), israel: false).periode == "chabbat")
        let livre = try livre()
        let tsitsit = YalkutYosef.recherche(livre, texte: "ציצית").isEmpty
        #expect(!tsitsit)
    }

    /// Une fenêtre est répartie sur toute sa liste, les lois de la fête à la fin (THILLOULOT-02).
    @Test func uneFenetreEstRepartieSurToutesaListeLesLoisDeLaFeteALaFin() throws {
        let livre = try livre()
        func siman(_ iso: String) -> [String] { YalkutYosef.pour(livre, date: .du(iso), israel: false).map { $0.siman } }
        // Soukkot 5787 : 15 Tichri (26/09/2026), la soukka ; Hochaana Rabba (02/10), le loulav.
        #expect(YalkutYosef.longueur(.du("2026-10-02"), israel: false) == 13)
        #expect(siman("2026-09-26").allSatisfy { $0.contient("תרכט") })
        #expect(siman("2026-10-02").allSatisfy { $0.contient("תרנא") })
        // 6 Sivan 5787 (11/06/2027) : Chavouot, plus la sefirat haomer.
        #expect(siman("2027-06-11").allSatisfy { $0.contient("תצד") })
        // 22 Nissan 5787 (29/04/2027) : les quatre coupes, plus la bedikat 'hamets.
        #expect(siman("2027-04-29").allSatisfy { $0.contient("תעב") })
        #expect(siman("2027-03-25").allSatisfy { $0.contient("תלג") })
        // Chaque se'if de chaque fenêtre sort au moins une fois en trois ans, sauf si la liste dépasse deux fois la fenêtre.
        var vus = Set<String>()
        var d = JourCivil.du("2025-09-01")
        while d < JourCivil.du("2028-09-01") {
            for s in YalkutYosef.pour(livre, date: d, israel: false) { vus.insert("\(s.siman)|\(s.lettre)|\(s.texte.premieresUnites(20))") }
            d = d.plus(jours: 1)
        }
        for p in ["soukkot", "chavouot"] {
            let n = (livre.periodes[p] ?? []).filter { vus.contains("\($0.siman)|\($0.lettre)|\($0.texte.premieresUnites(20))") }.count
            #expect(n >= 8, "\(p)")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Periode: Decodable {
            let periode: String
            let nombre: Int
            let empreinte: Int32
        }
        struct Israel: Decodable {
            let periode: String
            let rang: Int
            let seifs: [Int32]
        }
        struct Jour: Decodable {
            let jour: String
            let periode: String
            let rang: Int
            let seifs: [Int32]
            let titre: Int32
            let carte: Int32
            let israel: Israel?
        }
        struct PeriodeDuJour: Decodable {
            let jour: String
            let periode: String
            let rang: Int
        }
        struct Fenetre: Decodable {
            let mois: Int
            let embolismique: Bool
            let jours: [String?]
        }
        struct Du: Decodable {
            let n: Int
            let rang: Int
            let indices: [Int]
        }
        struct Recherche: Decodable {
            let requete: String
            let nombre: Int
            let empreinte: Int32
            let premiers: [Int32]
        }
        struct SeifLu: Decodable {
            let siman: String
            let lettre: String
            let texte: String
        }
        struct Carte: Decodable {
            let seifs: [SeifLu]
            let sources: [String]
            let titre: String
            let texte: String
        }

        let parJour: Int
        let periodes: [Periode]
        let pour: [Jour]
        let periode: [PeriodeDuJour]
        let fenetre: [Fenetre]
        let du: [Du]
        let recherche: [Recherche]
        let sources: [Int32]
        let cartes: [Carte]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/yalkut_yosef.json"))
    }

    /// L'empreinte d'un se'if : siman, lettre et texte joints par « | », puis `String.hashCode()`.
    private func empreinte(_ s: YalkutYosef.Seif) -> Int32 {
        Kotlin.hashCode("\(s.siman)|\(s.lettre)|\(s.texte)")
    }

    /// L'empreinte d'une suite de se'ifim : leurs empreintes jointes par des virgules.
    private func empreinte(_ seifs: [YalkutYosef.Seif]) -> Int32 {
        Kotlin.hashCode(seifs.map { String(empreinte($0)) }.joined(separator: ","))
    }

    @Test func leLivreSeLitCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        #expect(YalkutYosef.parJour == v.parJour)
        let ordre = v.periodes.map { $0.periode }
        #expect(livre.ordre == ordre, "les périodes dans l'ordre du fichier")
        for p in v.periodes {
            let seifs = livre.periodes[p.periode] ?? []
            #expect(seifs.count == p.nombre, "\(p.periode) : le nombre de se'ifim")
            let lue = empreinte(seifs)
            #expect(lue == p.empreinte, "\(p.periode) : les se'ifim")
        }
        var sources: [Int32] = []
        for p in livre.ordre {
            for s in livre.periodes[p] ?? [] { sources.append(Kotlin.hashCode(YalkutYosef.source(s))) }
        }
        #expect(sources == v.sources, "la source de chaque se'if")
    }

    @Test func chaqueJourCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        for j in v.pour {
            let date = JourCivil.du(j.jour)
            for israel in [false, true] {
                let ou = "\(j.jour)\(israel ? " en Israël" : "")"
                let periode = j.israel.map { israel ? $0.periode : j.periode } ?? j.periode
                let rang = j.israel.map { israel ? $0.rang : j.rang } ?? j.rang
                let seifs = j.israel.map { israel ? $0.seifs : j.seifs } ?? j.seifs
                let p = YalkutYosef.periode(date, israel: israel)
                #expect(p.periode == periode, "\(ou) : la période")
                #expect(p.rang == rang, "\(ou) : le rang")
                let du = YalkutYosef.pour(livre, date: date, israel: israel)
                let empreintes = du.map { empreinte($0) }
                #expect(empreintes == seifs, "\(ou) : les se'ifim (\(periode), rang \(rang))")
                if !israel {
                    let titre = Kotlin.hashCode(YalkutYosef.titreCarte(du))
                    #expect(titre == j.titre, "\(ou) : le titre de la carte")
                    let carte = Kotlin.hashCode(YalkutYosef.texteCarte(du))
                    #expect(carte == j.carte, "\(ou) : le texte de la carte")
                }
            }
        }
        #expect(v.pour.count >= 1090, "trois années hébraïques")
    }

    @Test func laPeriodeEtLaFenetreCommeSurAndroid() throws {
        let v = try vecteurs()
        for c in v.periode {
            let p = YalkutYosef.periode(JourCivil.du(c.jour), israel: false)
            #expect(p.periode == c.periode, "\(c.jour) : la période")
            #expect(p.rang == c.rang, "\(c.jour) : le rang")
        }
        for f in v.fenetre {
            for (i, attendue) in f.jours.enumerated() {
                let jour = i - 1  // les jours vont de −1 à 32
                let rendue = YalkutYosef.fenetre(mois: f.mois, jour: jour, embolismique: f.embolismique)
                #expect(rendue == attendue, "fenetre(\(f.mois), \(jour), \(f.embolismique))")
            }
        }
    }

    @Test func duCommeSurAndroid() throws {
        let v = try vecteurs()
        for c in v.du {
            let seifs = (0..<c.n).map { YalkutYosef.Seif(siman: "s\($0)", lettre: "l\($0)", texte: "t\($0)") }
            let rendus = YalkutYosef.du(seifs, rang: c.rang)
            var indices: [Int] = []
            for s in rendus { indices.append(seifs.firstIndex(of: s) ?? -1) }
            #expect(indices == c.indices, "du(\(c.n) se'ifim, rang \(c.rang))")
        }
    }

    @Test func laRechercheCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        for r in v.recherche {
            let trouves = YalkutYosef.recherche(livre, texte: r.requete)
            let nombre = trouves.count
            #expect(nombre == r.nombre, "recherche « \(r.requete) » : le nombre")
            let suite = empreinte(trouves)
            #expect(suite == r.empreinte, "recherche « \(r.requete) » : les se'ifim et leur ordre")
            let premiers = trouves.prefix(3).map { empreinte($0) }
            #expect(premiers == r.premiers, "recherche « \(r.requete) » : les trois premiers")
        }
    }

    @Test func laCarteCommeSurAndroid() throws {
        let v = try vecteurs()
        for c in v.cartes {
            let seifs = c.seifs.map { YalkutYosef.Seif(siman: $0.siman, lettre: $0.lettre, texte: $0.texte) }
            let ou = "carte de \(seifs.count) se'if(s) : \(seifs.map { $0.siman })"
            let sources = seifs.map { YalkutYosef.source($0) }
            let memesSources = sources.count == c.sources.count && zip(sources, c.sources).allSatisfy { $0.egalUnites($1) }
            #expect(memesSources, "\(ou) : les sources \(sources), attendues \(c.sources)")
            let titre = YalkutYosef.titreCarte(seifs)
            let memeTitre = titre.egalUnites(c.titre)
            #expect(memeTitre, "\(ou) : le titre « \(titre) », attendu « \(c.titre) »")
            let texte = YalkutYosef.texteCarte(seifs)
            let memeTexte = texte.egalUnites(c.texte)
            #expect(memeTexte, "\(ou) : le texte « \(texte) », attendu « \(c.texte) »")
        }
    }
}
