import Testing
@testable import Coeur

/// YalkutYosefTest d'Android, porté : la halakha courte du jour (13/10, tools/yalkut_yosef_construction.py),
/// une sélection du Yalkut Yosef, jamais le livre entier, deux se'ifim par jour selon la période. Les
/// mêmes vecteurs que web/test/yalkut.test.mjs ; jour après jour devant la JVM : TextesDuJourTests.
@Suite("Yalkout Yossef")
struct YalkutYosefTests {

    private typealias M = CalendrierJuif.Mois

    private func livre() throws -> YalkutYosef.Livre { try Corpus.yalkut.get() }

    @Test func uneSelectionDeHalakhotCourtes() throws {
        let l = try livre()
        let attendues: Set<String> = ["ordinaire", "chabbat", "roch_hodech", "pessah", "omer", "bein_hametsarim", "eloul",
                                      "kippour", "soukkot", "hanouka", "tou_bichvat", "pourim"]
        #expect(Set(l.periodes.cles) == attendues)
        for (p, seifs) in l.periodes.paires {
            #expect(seifs.count >= 4, "\(p)")
            for s in seifs {
                #expect(!s.texte.estBlanc && s.texte.utf16.count <= 420 && !s.siman.estBlanc, "\(p) \(s.siman) \(s.lettre)")
            }
        }
    }

    @Test func chaqueJourDeTroisAnneesASesDeuxHalakhotEtEllesChangent() throws {
        let l = try livre()
        var avant: String?
        for d in JourCivil.jours("2025-09-01", avant: "2028-09-01") {
            for israel in [false, true] {
                let n = YalkutYosef.pour(l, d, israel: israel).count
                #expect(n == YalkutYosef.parJour, "\(d) \(israel)")
            }
            let ici = YalkutYosef.pour(l, d, israel: false).map(YalkutYosef.source).joined(separator: "|")
            #expect(ici != avant, "\(d)")
            avant = ici
        }
    }

    @Test func lesFenetresDeFete() throws {
        #expect(YalkutYosef.fenetre(mois: M.adar, jour: 14, embolismique: false) == "pourim")
        #expect(YalkutYosef.fenetre(mois: M.adarII, jour: 14, embolismique: true) == "pourim")
        #expect(YalkutYosef.fenetre(mois: M.adar, jour: 14, embolismique: true) == nil)
        #expect(YalkutYosef.fenetre(mois: M.nissan, jour: 15, embolismique: false) == "pessah")
        #expect(YalkutYosef.fenetre(mois: M.sivan, jour: 6, embolismique: false) == "omer")
        #expect(YalkutYosef.fenetre(mois: M.av, jour: 9, embolismique: false) == "bein_hametsarim")
        #expect(YalkutYosef.fenetre(mois: M.tichri, jour: 1, embolismique: false) == "eloul")
        #expect(YalkutYosef.fenetre(mois: M.tichri, jour: 10, embolismique: false) == "kippour")
        #expect(YalkutYosef.fenetre(mois: M.tichri, jour: 15, embolismique: false) == "soukkot")
        #expect(YalkutYosef.fenetre(mois: M.tevet, jour: 2, embolismique: false) == "hanouka")
        #expect(YalkutYosef.fenetre(mois: M.chevat, jour: 15, embolismique: false) == "tou_bichvat")
        #expect(YalkutYosef.fenetre(mois: M.hechvan, jour: 10, embolismique: false) == nil)
        let pessah = YalkutYosef.periode(.du("2027-03-25"), israel: false) // 16 Adar II 5787
        #expect(pessah.periode == "pessah" && pessah.rang == 0)
        #expect(YalkutYosef.periode(.du("2027-03-24"), israel: false).periode == "pourim")
        #expect(YalkutYosef.periode(.du("2026-10-12"), israel: false).periode == "roch_hodech")
        #expect(YalkutYosef.periode(.du("2026-10-23"), israel: false).periode == "chabbat")
        #expect(YalkutYosef.periode(.du("2026-10-21"), israel: false).periode == "ordinaire")
        #expect(!YalkutYosef.recherche(try livre(), "ציצית").isEmpty)
    }

    @Test func laSourceEtLaCarteDuJour() {
        let a = YalkutYosef.Seif(siman: "סימן א", lettre: "ב", texte: "x")
        let b = YalkutYosef.Seif(siman: "סימן א", lettre: "ג", texte: "y")
        let c = YalkutYosef.Seif(siman: "סימן ב", lettre: "", texte: "z")
        #expect(YalkutYosef.source(a) == "ילקוט יוסף · סימן א · סעיף ב")
        #expect(YalkutYosef.source(c) == "ילקוט יוסף · סימן ב")
        #expect(YalkutYosef.titreCarte([a, b]) == "ילקוט יוסף · סימן א")
        #expect(YalkutYosef.titreCarte([a, c]) == "ילקוט יוסף")
        #expect(YalkutYosef.texteCarte([a, b]) == "ב. x\n\nג. y")
        #expect(YalkutYosef.texteCarte([a, c]) == "סימן א\nב. x\n\nסימן ב\nz")
    }
}
