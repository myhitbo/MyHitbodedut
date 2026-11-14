import Foundation
import Testing
@testable import Coeur

/// CalendrierJuifTest d'Android, porté, et le juge de la tâche 10 : les 3 896 jours de
/// `web/test/vecteurs_kosherjava.json` (du 01/09/2025 au 31/12/2030, Israël et diaspora), que le code
/// Android a produits sur KosherJava 2.5.0, rendus à l'identique par KosherSwift 1.10.11.
@Suite("Calendrier juif")
struct CalendrierJuifTests {

    private typealias C = CalendrierJuif.C

    /// Des dates écrites dans le test : une date illisible est une faute du test lui-même.
    private func jour(_ iso: String, israel: Bool = false, muree: Bool = false) -> CalendrierJuif.Jour {
        guard let date = JourCivil(iso: iso) else { preconditionFailure("date illisible : \(iso)") }
        return CalendrierJuif.jour(date, enIsrael: israel, mukafChoma: muree)
    }

    private func civil(_ iso: String) throws -> JourCivil { try #require(JourCivil(iso: iso), "\(iso)") }

    // MARK: Les vecteurs

    private struct Vecteurs: Decodable {
        struct Jour: Decodable {
            let h: [Int]
            let t: String
            let f: [String]
            let o: Int
            let p: String?
            let x: Bool
            let c: [String]
        }
        let jours: [String: Jour]
    }

    /// Chaque champ, chaque jour ; en cas d'écart, le nombre par champ et les premiers exemples.
    @Test func lesJoursDesVecteursSontRendusALIdentique() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("web/test/vecteurs_kosherjava.json"))
        #expect(v.jours.count == 3896)
        var ecarts: [String: [String]] = [:]
        for (cle, attendu) in v.jours.sorted(by: { $0.key < $1.key }) {
            guard let date = JourCivil(iso: String(cle.prefix(10))) else {
                Issue.record("date illisible : \(cle)")
                continue
            }
            let j = CalendrierJuif.jour(date, enIsrael: cle.hasSuffix("/il"))
            func note(_ champ: String, _ egal: Bool, _ detail: @autoclosure () -> String) {
                if !egal { ecarts[champ, default: []].append("\(cle) : \(detail())") }
            }
            let h = [j.jourHebreu, j.moisHebreu, j.anneeHebraique]
            note("h (date)", h == attendu.h, "\(h) au lieu de \(attendu.h)")
            note("t (texte)", j.dateHebraique == attendu.t, "« \(j.dateHebraique) » au lieu de « \(attendu.t) »")
            note("f (fêtes)", j.fetes == attendu.f, "\(j.fetes) au lieu de \(attendu.f)")
            note("o (omer)", j.omer == attendu.o, "\(j.omer) au lieu de \(attendu.o)")
            note("p (paracha)", j.paracha == attendu.p, "\(j.paracha ?? "nil") au lieu de \(attendu.p ?? "nil")")
            note("x (chômé)", j.chome == attendu.x, "\(j.chome) au lieu de \(attendu.x)")
            let c = C.toutes.filter { j.conditions.contains($0) }
            note("c (conditions)", c == attendu.c,
                 "en trop \(Set(c).subtracting(attendu.c).sorted()), manque \(Set(attendu.c).subtracting(c).sorted())")
        }
        let rapport = ecarts.keys.sorted().map { champ in
            let liste = ecarts[champ] ?? []
            return "\(champ) : \(liste.count) écarts, dont\n    " + liste.prefix(12).joined(separator: "\n    ")
        }.joined(separator: "\n")
        #expect(ecarts.isEmpty, "vecteurs KosherJava :\n\(rapport)")
    }

    // MARK: CalendrierJuifTest

    /// Dates relevées sur @hebcal/core 6.14.1 et sur ICU, qui concordent.
    @Test func lesDatesHebraiquesDe5787ConcordentAvecHebcalEtICU() throws {
        let cas: [(String, [Int])] = [
            ("2026-09-12", [1, 7, 5787]),   // 1 Tichri, Roch Hachana
            ("2026-10-11", [30, 7, 5787]),  // 30 Tichri
            ("2026-10-12", [1, 8, 5787]),   // 1 Hechvan
            ("2026-12-05", [25, 9, 5787]),  // 25 Kislev
            ("2027-03-23", [14, 13, 5787]), // 14 Adar II (année embolismique)
            ("2027-04-22", [15, 1, 5787]),  // 15 Nissan
            ("2027-08-12", [9, 5, 5787]),   // 9 Av
        ]
        for (iso, attendu) in cas {
            let j = jour(iso)
            #expect([j.jourHebreu, j.moisHebreu, j.anneeHebraique] == attendu, "\(iso)")
        }
        #expect(jour("2026-10-10").dateHebraique == "כ״ט תשרי תשפ״ז")
    }

    @Test func rochHodechDonneYaaleVeyavoEtLeHallelPartielSansTahanoun() throws {
        for iso in ["2026-10-11", "2026-10-12"] {
            let j = jour(iso)
            #expect(j.conditions.isSuperset(of: [C.yaaleVeyavo, C.rochHodech, C.hallel]), "\(iso)")
            #expect(j.conditions.isDisjoint(with: [C.hallelComplet, C.tahanounChaharit, C.tahanounMinha]), "\(iso)")
            #expect(j.fetes.contains("roch_hodech"), "\(iso)")
        }
    }

    @Test func hanoukaDonneAlHanissimEtLeHallelComplet() throws {
        let j = jour("2026-12-06") // 26 Kislev, dimanche
        #expect(j.conditions.isSuperset(of: [C.alHanissim, C.hanouka, C.hallelComplet]))
        #expect(!j.conditions.contains(C.tahanounChaharit))
        #expect(j.fetes == ["hanouka"])
    }

    @Test func machivHarouahDesCheminiAtseretTalOumatarSelonLeLieu() throws {
        #expect(jour("2026-10-02").conditions.contains(C.moridHatal))       // 21 Tichri
        #expect(!jour("2026-10-02").conditions.contains(C.machivHarouah))
        #expect(jour("2026-10-04").conditions.contains(C.machivHarouah))    // 23 Tichri
        #expect(!jour("2026-10-04").conditions.contains(C.moridHatal))
        // En Israël, la demande de pluie commence le 7 Hechvan.
        #expect(!jour("2026-10-17", israel: true).conditions.contains(C.talOumatar))
        #expect(jour("2026-10-18", israel: true).conditions.contains(C.talOumatar))
        // En diaspora, le soir du 4 décembre 2026 : le jour hébreu du 5.
        #expect(jour("2026-12-04").conditions.contains(C.berakha))
        #expect(jour("2026-12-05").conditions.contains(C.talOumatar))
        // 2027 précède une année civile bissextile : un jour plus tard.
        #expect(jour("2027-12-05").conditions.contains(C.berakha))
        #expect(jour("2027-12-06").conditions.contains(C.talOumatar))
    }

    @Test func jeunesDixJoursEtNeufAv() throws {
        #expect(jour("2026-09-15").conditions.contains(C.asseretYemeiTechouva))
        #expect(jour("2026-09-14").conditions.contains(C.jeune))   // Guedalia, 3 Tichri
        #expect(jour("2026-12-20").conditions.contains(C.jeune))   // 10 Tevet
        #expect(!jour("2026-09-21").conditions.contains(C.jeune))  // Kippour n'est pas un « jeûne » d'Anénou
        let av = jour("2027-08-12").conditions
        #expect(av.isSuperset(of: [C.jeune, C.tichaBeav]))
        #expect(!av.contains(C.tahanounChaharit))
    }

    @Test func lundiEtJeudiQuandLeTahanounSeDit() throws {
        let lundi = jour("2026-10-19").conditions // 8 Hechvan
        #expect(lundi.isSuperset(of: [C.tahanounChaharit, C.lundiJeudi]))
        #expect(!jour("2026-10-20").conditions.contains(C.lundiJeudi)) // mardi
        #expect(!jour("2026-10-12").conditions.contains(C.lundiJeudi)) // lundi de Roch 'Hodech
    }

    @Test func chabbatParachaOmerEtPourim() throws {
        let chabbat = jour("2026-10-10")
        #expect(chabbat.conditions.contains(C.chabbat) && chabbat.chome)
        #expect(chabbat.paracha == "בראשית")
        #expect(jour("2027-04-23").omer == 1) // 16 Nissan
        #expect(jour("2027-04-22").omer == 0)
        #expect(jour("2027-03-23").conditions.isSuperset(of: [C.pourim, C.alHanissim]))
    }

    /// 29 Eloul 5786 = 11/09/2026 (O.H. 581:3).
    @Test func veilleDeRochHachanaPasDeTahanounLeMatinTahanounLaVeilleAMinha() throws {
        for israel in [true, false] {
            let erev = jour("2026-09-11", israel: israel).conditions
            #expect(erev.isDisjoint(with: [C.tahanounChaharit, C.tahanounMinha]))
            #expect(jour("2026-09-10", israel: israel).conditions.contains(C.tahanounMinha))
        }
    }

    @Test func finDeTichriTahanounSelonLeNusah() throws {
        // 25 Tichri 5787 = lundi 05/10/2026.
        let c = jour("2026-10-05", israel: true).conditions
        #expect(c.isSuperset(of: [C.finTichri, C.tahanounChaharit]))
        #expect(!SiddurJour.conditionsPour(.edot, enIsrael: true, c).contains(C.tahanounChaharit))
        #expect(!SiddurJour.conditionsPour(.edot, enIsrael: true, c).contains(C.lundiJeudi))
        #expect(SiddurJour.conditionsPour(.ashkenaz, enIsrael: true, c).contains(C.tahanounChaharit))
        #expect(SiddurJour.conditionsPour(.sefard, enIsrael: false, c).contains(C.tahanounChaharit))
        // Sfard : au choix de l'utilisateur.
        #expect(!SiddurJour.conditionsPour(.sefard, enIsrael: false, c, sansTahanounFinTichri: true).contains(C.tahanounChaharit))
        #expect(!JourAffiche.ajouts(c, nusah: .sefard, enIsrael: true, sansTahanounFinTichri: true).contains("ajout_tahanoun"))
        // 3 'Hechvan (13/10/2026) : de nouveau Ta'hanoun pour tous.
        let apres = jour("2026-10-13", israel: true).conditions
        #expect(SiddurJour.conditionsPour(.edot, enIsrael: true, apres).contains(C.tahanounChaharit))
    }

    /// 14 Adar II 5787 = 23/03/2027, 15 Adar II = 24/03/2027.
    @Test func jerusalemPourimEtAlHanissimLe15Adar() throws {
        let c14 = jour("2027-03-23", israel: true, muree: true).conditions
        let c15 = jour("2027-03-24", israel: true, muree: true).conditions
        #expect(c14.isDisjoint(with: [C.pourim, C.alHanissim]))
        #expect(c15.isSuperset(of: [C.pourim, C.alHanissim]))
        #expect(jour("2027-03-23", israel: true, muree: true).fetes == ["pourim_ailleurs"])
        #expect(jour("2027-03-24", israel: true, muree: true).fetes == ["pourim_jerusalem"])
        // Ailleurs, le 14.
        #expect(jour("2027-03-23", israel: true).conditions.contains(C.alHanissim))
        #expect(!jour("2027-03-24", israel: true).conditions.contains(C.alHanissim))
        // Pas de Ta'hanoun les deux jours, partout.
        for iso in ["2027-03-23", "2027-03-24"] {
            #expect(!jour(iso, israel: true, muree: true).conditions.contains(C.tahanounChaharit), "\(iso)")
        }
    }

    @Test func arvitReleveDuJourHebreuSuivantDesLApresMidi() throws {
        let date = try civil("2026-10-10"), lendemain = try civil("2026-10-11")
        #expect(CalendrierJuif.jourDeLaPriere("arvit", date: date, heure: 19) == lendemain)
        #expect(CalendrierJuif.jourDeLaPriere("chema_coucher", date: date, heure: 23) == lendemain)
        #expect(CalendrierJuif.jourDeLaPriere("arvit", date: date, heure: 0) == date)
        #expect(CalendrierJuif.jourDeLaPriere("chaharit", date: date, heure: 19) == date)
        #expect(CalendrierJuif.jourDeLaPriere("minha", date: date, heure: 17) == date)
        // Après la sortie des étoiles : Birkat haMazon relève de demain ; Min'ha non.
        #expect(CalendrierJuif.jourDeLaPriere("birkat_hamazon", date: date, heure: 19, apresSortie: true) == lendemain)
        #expect(CalendrierJuif.jourDeLaPriere("birkat_hamazon", date: date, heure: 17) == date)
        #expect(CalendrierJuif.jourDeLaPriere("minha", date: date, heure: 19, apresSortie: true) == date)
        // Samedi soir : Arvit relève du dimanche, d'où la section de motsaé Chabbat.
        #expect(CalendrierJuif.jour(lendemain, enIsrael: false).conditions.contains(C.motsaeChabbat))
    }

    @Test func chaqueFeteASonLibelleDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for fete in CalendrierJuif.fetes.values.sorted() {
                #expect(chaines["fete_\(fete)"] != nil, "\(langue) : fete_\(fete)")
            }
        }
        #expect(CalendrierJuif.fetes.count == 35)
    }

    /// « וּלְכַפָּרַת פֶּשַׁע » : mêmes dates que web/test/calendrier.test.mjs.
    @Test func rochHodechEmbolismique() throws {
        for iso in ["2026-11-10", "2026-11-11"] {
            #expect(jour(iso).conditions.isSuperset(of: [C.embolismique, C.embolismiqueAvantNissan]), "\(iso)")
        }
        #expect(jour("2027-04-08").conditions.contains(C.embolismique))
        #expect(!jour("2027-04-08").conditions.contains(C.embolismiqueAvantNissan))
        #expect(!jour("2026-01-19").conditions.contains(C.embolismique))
        #expect(!jour("2026-11-12").conditions.contains(C.embolismique))
    }

    /// Le mois de Foundation dans la numérotation de KosherJava, années simples et embolismiques.
    @Test func lesMoisSontNumerotesCommeKosherJava() {
        #expect(CalendrierJuif.moisKosherJava(1, embolismique: false) == CalendrierJuif.Mois.tichri)
        #expect(CalendrierJuif.moisKosherJava(8, embolismique: true) == CalendrierJuif.Mois.nissan)
        #expect(CalendrierJuif.moisKosherJava(13, embolismique: false) == CalendrierJuif.Mois.eloul)
        #expect(CalendrierJuif.moisKosherJava(7, embolismique: false) == CalendrierJuif.Mois.adar)
        #expect(CalendrierJuif.moisKosherJava(6, embolismique: true) == CalendrierJuif.Mois.adar)
        #expect(CalendrierJuif.moisKosherJava(7, embolismique: true) == CalendrierJuif.Mois.adarII)
    }
}
