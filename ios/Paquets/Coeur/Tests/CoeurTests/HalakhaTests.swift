import Testing
@testable import Coeur

/// HalakhaTest d'Android, porté : la halakha du jour hors ligne, le Ben Ish 'Haï par paracha (11/10).
/// Le même livre, jour après jour, devant la JVM : TextesDuJourTests.
@Suite("Halakha")
struct HalakhaTests {

    private func livre() throws -> Halakha.Livre { try Corpus.halakha.get() }

    @Test func leLivreEmbarqueEstComplet() throws {
        let l = try livre()
        let total = l.annees.paires.reduce(0) { $0 + $1.valeur.paires.reduce(0) { $0 + $1.valeur.halakhot.count } }
        #expect(total + (l.hanouka?.halakhot.count ?? 0) == 2002)
        #expect(l.annees["1"]?["BERESHIS"]?.he == "בראשית")
    }

    @Test func chaqueJourDeTroisAnneesASaHalakhaLaSemaineCouvreTouteLaSection() throws {
        let l = try livre()
        for d in JourCivil.jours("2025-09-01", avant: "2028-09-01") {
            for israel in [false, true] {
                let ici = Halakha.pour(l, d, enIsrael: israel)
                #expect(!ici.isEmpty, "\(d) \(israel)")
            }
        }
        // Semaine de Lekh Lekha 5787 (dimanche 18 → Chabbat 24/10/2026), première année : les 21 halakhot, une fois chacune.
        let semaine = JourCivil.jours("2026-10-18", avant: "2026-10-25").flatMap { Halakha.pour(l, $0, enIsrael: false) }
        let numeros = semaine.map(\.numero)
        #expect(numeros == Array(1...21))
        let bonnes = semaine.filter { $0.annee == 1 && $0.section == "לך לך" }
        #expect(bonnes.count == semaine.count)
    }

    @Test func parachiotJointesOuSepareesHanouka() throws {
        let l = try livre()
        let un = try #require(l.annees["1"])
        // Tazria lue seule : la première moitié de la section jointe de la première année.
        let tazria = try #require(Halakha.sections(un, "TAZRIA"))
        let metzora = try #require(Halakha.sections(un, "METZORA"))
        try #require(tazria.count == 1 && metzora.count == 1)
        #expect(tazria[0].depart == 0)
        #expect(tazria[0].halakhot.count == metzora[0].depart)
        // Jointes, la deuxième année les a séparées : les deux à la suite.
        let deux = try #require(l.annees["2"])
        #expect(Halakha.sections(deux, "TAZRIA_METZORA")?.count == 2)
        // Le premier jour de 'Hanouka : la section de 'Hanouka.
        let h = Halakha.choix(l, parsha: "VAYESHEV", jourSemaine: 0, anneeHebraique: 5787, jourHanouka: 1)
        #expect(h.first?.section == "הלכות חנוכה")
        #expect(h.first?.numero == 1)
    }

    @Test func anneeDuLivreEtPartDuJour() {
        #expect(Halakha.anneeDuLivre(5787) == 1)
        #expect(Halakha.anneeDuLivre(5788) == 2)
        #expect(Halakha.part([1, 2, 3], 2, 7) == [3])
        #expect(Halakha.part([1, 2, 3], 3, 7) == [1])
        let semaine = (0..<7).flatMap { Halakha.part(Array(0..<14), $0, 7) }
        #expect(semaine == Array(0..<14))
    }

    @Test func laRechercheTrouveSansVoyelles() throws {
        let l = try livre()
        #expect(Halakha.recherche(l, "ציצית").count > 10)
        #expect(Halakha.recherche(l, "צ").isEmpty)
    }
}
