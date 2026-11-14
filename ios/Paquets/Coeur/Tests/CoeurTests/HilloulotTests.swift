import Foundation
import Testing
@testable import Coeur

/// HilloulotTest d'Android, porté : la hilloula du jour, ses liens et l'illustration de la carte du jour
/// (11/10), la date lisible, la recherche, les biographies d'autres sources, lues ici dans les fichiers
/// par mois de l'export. Jour après jour devant la JVM : TextesDuJourTests.
@Suite("Hilloulot")
struct HilloulotTests {

    private func table() throws -> Hilloulot.Table { try Corpus.hilloulot.get() }

    /// KosherJava compte sur le cycle de Méton ; le calendrier hébreu de Foundation, d'un 1er Tichri au
    /// suivant : plus de 360 jours, l'année est embolismique (383 à 385 jours, 353 à 355 sinon).
    @Test func leCycleDeMetonSuitLeCalendrierHebreu() throws {
        var hebreu = Calendar(identifier: .hebrew)
        hebreu.timeZone = try #require(TimeZone(identifier: "UTC"))
        func roshHachana(_ a: Int) throws -> Date {
            try #require(hebreu.date(from: DateComponents(year: a, month: 1, day: 1, hour: 12)))
        }
        for a in 5700...5900 {
            let jours = Int(((try roshHachana(a + 1)).timeIntervalSince(try roshHachana(a)) / 86_400).rounded())
            #expect((jours > 360) == Hilloulot.embolismique(a), "\(a) : \(jours) jours")
        }
    }

    @Test func adarSansPrecisionSeDitEnAdarIIUn30AbsentLe29() {
        #expect(Hilloulot.cles(mois: 12, jour: 7, embolismique: false, dernierJour: false) == ["adar-7", "adar1-7", "adar2-7"])
        #expect(Hilloulot.cles(mois: 12, jour: 7, embolismique: true, dernierJour: false) == ["adar1-7"])
        #expect(Hilloulot.cles(mois: 13, jour: 7, embolismique: true, dernierJour: false) == ["adar-7", "adar2-7"])
        // Ashkénazes : « adar » en Adar I (Rema OH 568:7).
        #expect(Hilloulot.cles(mois: 12, jour: 7, embolismique: true, dernierJour: false, ashkenaz: true) == ["adar-7", "adar1-7"])
        #expect(Hilloulot.cles(mois: 13, jour: 7, embolismique: true, dernierJour: false, ashkenaz: true) == ["adar2-7"])
        #expect(Hilloulot.cles(mois: 8, jour: 29, embolismique: false, dernierJour: true) == ["8-29", "8-30"])
    }

    @Test func chaqueJourDUneAnneeSimpleASaHilloula() throws {
        let t = try table()
        for d in JourCivil.jours("2025-09-23", avant: "2026-09-12") {
            #expect(!Hilloulot.pour(t, d, enIsrael: false).isEmpty, "\(d)")
        }
        // 30 Tichri 5787 : Rabbi Tsvi Hirsch Chajes (Wikipédia).
        let ce = Hilloulot.pour(t, .du("2026-10-11"), enIsrael: false).filter { $0.he.contientUnites("צבי הירש חיות") }
        #expect(!ce.isEmpty)
        let forme = ExpressionReguliere("(\\d{1,2}|adar[12]?)-\\d{1,2}")
        let mal = t.cles.filter { !forme.couvre($0) }
        #expect(mal.isEmpty, "\(mal)")
    }

    @Test func lesLiensDeLaCarteDuJour() {
        #expect(Hilloulot.lienHyomi(.du("2026-10-11")) == "https://hyomi.org.il/day.php?month1=0&dd=11&mm=10&yy=2026")
        #expect(Hilloulot.lienHalakha("iw") == "https://halachayomit.co.il/he/default.aspx")
        #expect(Hilloulot.lienHalakha("en") == "https://halachayomit.co.il/en/default.aspx")
        #expect(Hilloulot.lienHalakha("fr") == "https://halachayomit.co.il/fr/default.aspx")
        // URLEncoder.encode de Java : l'hébreu en octets UTF-8, majuscules.
        #expect(Hilloulot.lienArticle("א ב") == "https://he.wikipedia.org/wiki/%D7%90_%D7%91")
    }

    @Test func lIllustrationDuJourDeFeteOuDeChabbat() {
        #expect(JourAffiche.illustration(fetes: ["soukkot"], date: .du("2026-09-26")) == "scene_sukkot")
        #expect(JourAffiche.illustration(fetes: ["pessah"], date: .du("2027-04-22")) == "char_matsa")
        #expect(JourAffiche.illustration(fetes: [], date: .du("2026-10-10")) == "char_shabbat")
        #expect(JourAffiche.illustration(fetes: [], date: .du("2026-10-11")) == nil)
    }

    @Test func dateLisibleEtRechercheParNom() throws {
        let t = try table()
        #expect(Hilloulot.dateDe("7-30") == "ל׳ תשרי")
        #expect(Hilloulot.dateDe("adar2-7") == "ז׳ אדר ב׳")
        let chajes = Hilloulot.recherche(t, "צבי הירש חיות").filter { $0.cle == "7-30" }
        #expect(!chajes.isEmpty)
        #expect(Hilloulot.recherche(t, "א").isEmpty)
        // En français et en anglais, avec ou sans accents (29/10).
        #expect(!Hilloulot.recherche(t, "Chelah").isEmpty)
        #expect(!Hilloulot.recherche(t, "Shelah").isEmpty)
        #expect(Hilloulot.recherche(t, "Moché").count == Hilloulot.recherche(t, "moche").count)
    }

    @Test func lesBiographiesDAutresSourcesAPartAvecLeurSource() throws {
        let t = try table()
        let complete = try Hilloulot.tableComplete(Depot.lire)
        #expect(complete.cles == t.cles)
        for cle in t.cles {
            let avant = (t[cle] ?? []).map(\.he), apres = (complete[cle] ?? []).map(\.he)
            #expect(avant == apres, "\(cle)")
        }
        let bios = complete.jours.paires.flatMap { $0.valeur.flatMap(\.bios) }
        #expect(bios.count > 2000)
        let malFaites = bios.filter { !["m", "l"].contains($0.source) || $0.texte.estBlanc }
        #expect(malFaites.isEmpty)
        // La source est dite : chaque biographie de MyTzadik ou de המאיר לארץ garde le lien vers sa page.
        let sansLien = bios.filter { !($0.lien?.hasPrefix("https://") ?? false) }
        #expect(sansLien.isEmpty)
        let dejaLa = t.jours.paires.flatMap { $0.valeur.flatMap(\.bios) }
        #expect(dejaLa.isEmpty)
    }

    @Test func unJourRangeLesMieuxConnusDAbordLesDatesDouteusesEnDernier() {
        func h(_ he: String, _ s: String, _ t: String?, _ d: String?) -> Hilloulot.Hilloula {
            Hilloulot.Hilloula(he: he, sources: s, doute: d, description: t)
        }
        let t = Hilloulot.Table(jours: TableOrdonnee([("8-23", [h("un", "m", nil, nil), h("doute", "wm", "x", "faux"),
                                                                 h("trois", "hwm", "x", nil), h("deux", "wm", nil, nil),
                                                                 h("deux-notice", "wm", "x", nil)])]))
        let ordre = Hilloulot.duJour(t, ["8-23"]).map(\.he)
        #expect(ordre == ["trois", "deux-notice", "deux", "un", "doute"])
    }

    @Test func laRechercheSuitLAnneeDeTichriAEloul() throws {
        #expect(Hilloulot.rangDansLAnnee("7-1") < Hilloulot.rangDansLAnnee("11-30"))
        #expect(Hilloulot.rangDansLAnnee("11-30") < Hilloulot.rangDansLAnnee("adar1-1"))
        #expect(Hilloulot.rangDansLAnnee("adar1-30") < Hilloulot.rangDansLAnnee("adar-1"))
        #expect(Hilloulot.rangDansLAnnee("adar-29") < Hilloulot.rangDansLAnnee("adar2-1"))
        #expect(Hilloulot.rangDansLAnnee("adar2-29") < Hilloulot.rangDansLAnnee("1-1"))
        #expect(Hilloulot.rangDansLAnnee("1-1") < Hilloulot.rangDansLAnnee("6-29"))
        let rangs = Hilloulot.recherche(try table(), "רבי").map { Hilloulot.rangDansLAnnee($0.cle) }
        #expect(rangs.count > 100)
        #expect(rangs.sorted() == rangs)
    }

    @Test func voirCeJourMeneAuProchainJourDeLaDate() throws {
        // 23 Hechvan 5787 : le 3 novembre 2026 ; depuis le 4, celui de 5788.
        #expect(Hilloulot.prochainJour("8-23", depuis: .du("2026-10-01"), enIsrael: false) == .du("2026-11-03"))
        let suivant = try #require(Hilloulot.prochainJour("8-23", depuis: .du("2026-11-04"), enIsrael: false))
        #expect(Hilloulot.clesPour(suivant, enIsrael: false).contains("8-23"))
        #expect(suivant > .du("2027-10-01") && suivant < .du("2027-12-01"))
        // Adar II n'existe que les années embolismiques : il se trouve quand même.
        #expect(Hilloulot.prochainJour("adar2-14", depuis: .du("2026-11-04"), enIsrael: false) != nil)
    }
}
