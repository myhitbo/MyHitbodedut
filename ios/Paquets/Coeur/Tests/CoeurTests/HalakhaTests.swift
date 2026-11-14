import Foundation
import Testing
@testable import Coeur

/// La halakha du jour hors ligne : le Ben Ish 'Haï, par paracha (HalakhaTest.kt, 11/10), tous ses cas
/// portés ; rien ne reste à Android. Puis `Tests/Vecteurs/halakha.json`, écrit par le code d'Android
/// (tools/vecteurs_ios/VecteursHalakha.kt) : chaque jour des années 5786 à 5788 en Israël et hors
/// d'Israël, les sections de chaque paracha, part, anneeDuLivre, choix, la recherche et la source.
@Suite("Halakha")
struct HalakhaTests {

    /// Le livre embarqué (2 Mo), lu une fois pour toute la suite.
    private static let lecture: Result<Halakha.Livre, any Error> = Result {
        try Halakha.parse(Depot.contenu("ben_ish_hai.json"))
    }

    private func livre() throws -> Halakha.Livre { try Self.lecture.get() }

    // MARK: HalakhaTest.kt

    @Test func leLivreEmbarqueEstComplet() throws {
        let livre = try livre()
        var total = livre.hanouka?.halakhot.count ?? 0
        for annee in livre.annees.values {
            for section in annee.values { total += section.halakhot.count }
        }
        #expect(total == 2002)
        let bereshis = livre.annees["1"]?["BERESHIS"]?.he
        #expect(bereshis == "בראשית")
    }

    @Test func chaqueJourDeTroisAnneesASaHalakhaLaSemaineCouvreTouteLaSection() throws {
        let livre = try livre()
        var d = JourCivil.du("2025-09-01")
        let fin = JourCivil.du("2028-09-01")
        while d < fin {
            for il in [false, true] {
                let n = Halakha.pour(livre, date: d, enIsrael: il).count
                #expect(n > 0, "\(d) \(il)")
            }
            d = d.plus(jours: 1)
        }
        // Semaine de Lekh Lekha 5787 (dimanche 18 → Chabbat 24/10/2026), première année : les 21 halakhot, une fois chacune.
        let dimanche = JourCivil.du("2026-10-18")
        var semaine: [Halakha.Choisie] = []
        for i in 0...6 { semaine += Halakha.pour(livre, date: dimanche.plus(jours: i), enIsrael: false) }
        let numeros = semaine.map { $0.numero }
        #expect(numeros == Array(1...21))
        let lekhLekha = semaine.allSatisfy { $0.annee == 1 && $0.section.egalUnites("לך לך") }
        #expect(lekhLekha, "toute la semaine dans « לך לך », première année")
    }

    @Test func parachiotJointesOuSepareesHanouka() throws {
        let livre = try livre()
        let unOpt = livre.annees["1"]
        let un = try #require(unOpt)
        // Tazria lue seule : la première moitié de la section jointe de la première année.
        let tazriaOpt = Halakha.sections(un, parsha: "TAZRIA")
        let tazria = try #require(tazriaOpt)
        #expect(tazria.count == 1, "single()")
        let t = try #require(tazria.first)
        #expect(t.depart == 0)
        let metzoraOpt = Halakha.sections(un, parsha: "METZORA")
        let metzora = try #require(metzoraOpt)
        #expect(metzora.count == 1, "single()")
        let m = try #require(metzora.first)
        let moitie = t.halakhot.count
        #expect(m.depart == moitie)
        // Jointes, la deuxième année les a séparées : les deux à la suite.
        let deuxOpt = livre.annees["2"]
        let deux = try #require(deuxOpt)
        let jointes = Halakha.sections(deux, parsha: "TAZRIA_METZORA")?.count
        #expect(jointes == 2)
        // Le premier jour de 'Hanouka : la section de 'Hanouka.
        let h = Halakha.choix(livre, parsha: "VAYESHEV", jourSemaine: 0, anneeHebraique: 5787, jourHanouka: 1)
        let premiere = try #require(h.first)
        #expect(premiere.section == "הלכות חנוכה")
        #expect(premiere.numero == 1)
    }

    @Test func anneeDuLivreEtPartDuJour() {
        let impaire = Halakha.anneeDuLivre(5787)
        #expect(impaire == 1)
        let paire = Halakha.anneeDuLivre(5788)
        #expect(paire == 2)
        let troisieme = Halakha.part([1, 2, 3], jour: 2, parts: 7)
        #expect(troisieme == [3])
        let enBoucle = Halakha.part([1, 2, 3], jour: 3, parts: 7)
        #expect(enBoucle == [1])
        var semaine: [Int] = []
        for jour in 0..<7 { semaine += Halakha.part(Array(0..<14), jour: jour, parts: 7) }
        #expect(semaine == Array(0..<14))
    }

    @Test func laRechercheTrouveSansVoyelles() throws {
        let livre = try livre()
        let tsitsit = Halakha.recherche(livre, texte: "ציצית").count
        #expect(tsitsit > 10)
        let uneLettre = Halakha.recherche(livre, texte: "צ").isEmpty
        #expect(uneLettre)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct SectionLue: Decodable {
            let paracha: String
            let section: String
            let nombre: Int
            let empreinte: Int32
        }
        struct Annee: Decodable {
            let annee: String
            let sections: [SectionLue]
        }
        struct Hanouka: Decodable {
            let section: String
            let nombre: Int
            let empreinte: Int32
        }
        struct Israel: Decodable {
            let parsha: String
            let choix: [[Int]]
            let texte: Int32
        }
        struct Jour: Decodable {
            let jour: String
            let parsha: String
            let choix: [[Int]]
            let texte: Int32
            let israel: Israel?
        }
        struct PartLue: Decodable {
            let section: String
            let depart: Int
            let nombre: Int
            let empreinte: Int32
        }
        struct Sections: Decodable {
            let annee: String
            let parsha: String
            let parts: [PartLue]?
        }
        struct SectionEssai: Decodable {
            let paracha: String
            let section: String
            let halakhot: [String]
        }
        struct Resultat: Decodable {
            let parsha: String
            let parts: [PartLue]?
        }
        struct Essai: Decodable {
            let livre: [SectionEssai]
            let resultats: [Resultat]
        }
        struct PartDuJour: Decodable {
            let n: Int
            let parts: Int
            let jours: [[Int]]
        }
        struct Choix: Decodable {
            let parsha: String
            let jour: Int
            let annee: Int
            let hanouka: Int
            let choix: [[Int]]
            let texte: Int32
        }
        struct Recherche: Decodable {
            let requete: String
            let nombre: Int
            let empreinte: Int32
            let premiers: [[Int]]
        }
        struct Source: Decodable {
            let annee: Int
            let section: String
            let numero: Int
            let source: String
        }

        let noms: [String]
        let annees: [Annee]
        let hanouka: Hanouka?
        let pour: [Jour]
        let sections: [Sections]
        let sectionsEssai: [Essai]
        let part: [PartDuJour]
        let anneeDuLivre: [[Int]]
        let choix: [Choix]
        let recherche: [Recherche]
        let source: [Source]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/halakha.json"))
    }

    /// Le rang d'un nom de section dans la table des vecteurs, unité pour unité ; −1 s'il n'y est pas.
    private func rang(_ section: String, _ noms: [String]) -> Int {
        noms.firstIndex { $0.egalUnites(section) } ?? -1
    }

    /// Des halakhot choisies devant leurs vecteurs : [numéro, rang du nom de la section, année] chacune,
    /// puis l'empreinte de leurs textes joints par un saut de ligne.
    private func verifie(_ choisies: [Halakha.Choisie], _ choix: [[Int]], _ texte: Int32, _ noms: [String], _ ou: String) {
        var lues: [[Int]] = []
        for c in choisies { lues.append([c.numero, rang(c.section, noms), c.annee]) }
        #expect(lues == choix, "\(ou) : numéro, section, année")
        let empreinte = Kotlin.hashCode(choisies.map { $0.texte }.joined(separator: "\n"))
        #expect(empreinte == texte, "\(ou) : les textes")
    }

    /// Ce que rend `Halakha.sections` devant ce qu'a rendu Kotlin.
    private func compare(_ parts: [Halakha.Part]?, _ attendues: [Vecteurs.PartLue]?, _ ou: String) {
        guard let attendues else {
            let rien = parts == nil
            #expect(rien, "\(ou) : nil attendu")
            return
        }
        guard let parts else {
            Issue.record("\(ou) : \(attendues.count) part(s) attendue(s), nil rendu")
            return
        }
        let nombreDeParts = parts.count
        #expect(nombreDeParts == attendues.count, "\(ou) : le nombre de parts")
        for (p, a) in zip(parts, attendues) {
            let titre = p.section.he.egalUnites(a.section)
            #expect(titre, "\(ou) : la section « \(p.section.he) », attendue « \(a.section) »")
            let depart = p.depart
            #expect(depart == a.depart, "\(ou) : l'indice de départ")
            let nombre = p.halakhot.count
            #expect(nombre == a.nombre, "\(ou) : le nombre de halakhot")
            let empreinte = Kotlin.hashCode(p.halakhot.joined(separator: "\n"))
            #expect(empreinte == a.empreinte, "\(ou) : les halakhot")
        }
    }

    @Test func leLivreSeLitCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        let nombreDAnnees = livre.annees.count
        #expect(nombreDAnnees == v.annees.count)
        var noms: [String] = []
        for a in v.annees {
            let parachiot = livre.parachiot[a.annee] ?? []
            let attendues = a.sections.map { $0.paracha }
            #expect(parachiot == attendues, "année \(a.annee) : les parachiot dans l'ordre du fichier")
            for s in a.sections {
                let lueOpt = livre.annees[a.annee]?[s.paracha]
                let lue = try #require(lueOpt, "année \(a.annee) : \(s.paracha) absente")
                let titre = lue.he.egalUnites(s.section)
                #expect(titre, "\(a.annee) \(s.paracha) : le titre")
                let nombre = lue.halakhot.count
                #expect(nombre == s.nombre, "\(a.annee) \(s.paracha) : le nombre de halakhot")
                let empreinte = Kotlin.hashCode(lue.halakhot.joined(separator: "\n"))
                #expect(empreinte == s.empreinte, "\(a.annee) \(s.paracha) : les halakhot")
                if !noms.contains(where: { $0.egalUnites(lue.he) }) { noms.append(lue.he) }
            }
        }
        let attendue = try #require(v.hanouka)
        let hanouka = try #require(livre.hanouka)
        let titre = hanouka.he.egalUnites(attendue.section)
        #expect(titre, "'Hanouka : le titre")
        let nombre = hanouka.halakhot.count
        #expect(nombre == attendue.nombre, "'Hanouka : le nombre de halakhot")
        let empreinte = Kotlin.hashCode(hanouka.halakhot.joined(separator: "\n"))
        #expect(empreinte == attendue.empreinte, "'Hanouka : les halakhot")
        if !noms.contains(where: { $0.egalUnites(hanouka.he) }) { noms.append(hanouka.he) }
        #expect(noms == v.noms, "les noms des sections, dans l'ordre du livre")
    }

    @Test func chaqueJourCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        var differents = 0
        for j in v.pour {
            let date = JourCivil.du(j.jour)
            verifie(Halakha.pour(livre, date: date, enIsrael: false), j.choix, j.texte, v.noms,
                    "\(j.jour) hors d'Israël (\(j.parsha))")
            let israel = Halakha.pour(livre, date: date, enIsrael: true)
            if let i = j.israel {
                differents += 1
                verifie(israel, i.choix, i.texte, v.noms, "\(j.jour) en Israël (\(i.parsha))")
            } else {
                verifie(israel, j.choix, j.texte, v.noms, "\(j.jour) en Israël (\(j.parsha))")
            }
        }
        #expect(v.pour.count >= 1090, "trois années hébraïques")
        #expect(differents > 0, "les vecteurs doivent couvrir des semaines où Israël a un Chabbat d'avance")
    }

    @Test func lesSectionsCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        for s in v.sections {
            let annee = livre.annees[s.annee] ?? [:]
            compare(Halakha.sections(annee, parsha: s.parsha), s.parts, "année \(s.annee), \(s.parsha)")
        }
        for essai in v.sectionsEssai {
            var annee: [String: Halakha.Section] = [:]
            for s in essai.livre { annee[s.paracha] = Halakha.Section(he: s.section, halakhot: s.halakhot) }
            let nom = essai.livre.map { "\($0.paracha) (\($0.halakhot.count))" }.joined(separator: ", ")
            for r in essai.resultats {
                compare(Halakha.sections(annee, parsha: r.parsha), r.parts, "essai [\(nom)], \(r.parsha)")
            }
        }
    }

    @Test func partEtAnneeDuLivreCommeSurAndroid() throws {
        let v = try vecteurs()
        for c in v.part {
            let items = Array(0..<c.n)
            for (jour, attendue) in c.jours.enumerated() {
                let rendue = Halakha.part(items, jour: jour, parts: c.parts)
                #expect(rendue == attendue, "part(\(c.n) éléments, jour \(jour), \(c.parts) parts)")
            }
        }
        for c in v.anneeDuLivre {
            let rendue = Halakha.anneeDuLivre(c[0])
            #expect(rendue == c[1], "anneeDuLivre(\(c[0]))")
        }
    }

    @Test func leChoixCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        for c in v.choix {
            let rendu = Halakha.choix(livre, parsha: c.parsha, jourSemaine: c.jour, anneeHebraique: c.annee,
                                      jourHanouka: c.hanouka)
            verifie(rendu, c.choix, c.texte, v.noms, "choix(« \(c.parsha) », jour \(c.jour), \(c.annee), 'Hanouka \(c.hanouka))")
        }
    }

    @Test func laRechercheCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try livre()
        for r in v.recherche {
            let trouvees = Halakha.recherche(livre, texte: r.requete)
            let nombre = trouvees.count
            #expect(nombre == r.nombre, "recherche « \(r.requete) » : le nombre")
            let suite = trouvees.map { "\($0.annee)|\($0.section)|\($0.numero)|\(Kotlin.hashCode($0.texte))" }
            let empreinte = Kotlin.hashCode(suite.joined(separator: "\n"))
            #expect(empreinte == r.empreinte, "recherche « \(r.requete) » : les halakhot et leur ordre")
            var premiers: [[Int]] = []
            for c in trouvees.prefix(3) { premiers.append([c.numero, rang(c.section, v.noms), c.annee]) }
            #expect(premiers == r.premiers, "recherche « \(r.requete) » : les trois premières")
        }
    }

    @Test func laSourceCommeSurAndroid() throws {
        let v = try vecteurs()
        for s in v.source {
            let rendue = Halakha.source(Halakha.Choisie(texte: "…", numero: s.numero, section: s.section, annee: s.annee))
            let egale = rendue.egalUnites(s.source)
            #expect(egale, "source(\(s.annee), « \(s.section) », \(s.numero)) : « \(rendue) », attendue « \(s.source) »")
        }
    }
}
