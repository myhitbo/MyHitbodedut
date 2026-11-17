import Foundation
import Testing
@testable import Coeur

/// La hilloula du jour et l'illustration de la carte du jour (HilloulotTest.kt, 11/10) : tous ses cas
/// portés, rien ne reste à Android ; KosherJava, que le premier cas consulte, répond par les vecteurs. Puis
/// `Tests/Vecteurs/hilloulot.json`, écrit par le code d'Android (tools/vecteurs_ios/VecteursHilloulot.kt) :
/// la table lue, des fichiers d'essai, les clés de chaque mois, clesPour et duJour chaque jour de 5786 et
/// 5787, prochainJour, rangDansLAnnee, dateDe, embolismique, les liens, la recherche et les biographies.
@Suite("Hilloulot")
struct HilloulotTests {

    /// La table embarquée (1 Mo), lue une fois pour toute la suite.
    private static let lecture: Result<Hilloulot.Table, any Error> = Result {
        try Hilloulot.parse(Depot.contenu("hilloulot.json"))
    }

    /// La table et ses biographies, un fichier par mois (`hilloulot_bios/<mois>.json`), appliqués l'un après l'autre.
    private static let complete: Result<Hilloulot.Table, any Error> = Result {
        let table = try HilloulotTests.lecture.get()
        var avec = table
        for fichier in Set(table.keys.map(Hilloulot.fichierDesBios)).sorted() {
            guard let donnees = try Depot.lire(fichier) else { throw ErreurDeTest.absent(fichier) }
            avec = try Hilloulot.avecBios(avec, donnees)
        }
        return avec
    }

    private static let vecteurs: Result<Vecteurs, any Error> = Result {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/hilloulot.json"))
    }

    private func lireTable() throws -> Hilloulot.Table { try Self.lecture.get() }

    // MARK: HilloulotTest.kt

    @Test func leCycleDeMetonSuitKosherJava() throws {
        // KosherJava (JewishCalendar(a, TISHREI, 1).isJewishLeapYear) a répondu sur la JVM, de 5700 à 5900.
        let v = try Self.vecteurs.get()
        #expect(v.meton.kosherJava.count == 201)
        for c in v.meton.kosherJava {
            let e = Hilloulot.embolismique(c.annee)
            #expect(e == c.kosherJava, "\(c.annee)")
        }
    }

    @Test func adarSansPrecisionSeDitEnAdarIIUn30AbsentLe29() {
        let simple = Hilloulot.cles(12, 7, embolismique: false, dernierJour: false)
        #expect(simple == ["adar-7", "adar1-7", "adar2-7"])
        let adarI = Hilloulot.cles(12, 7, embolismique: true, dernierJour: false)
        #expect(adarI == ["adar1-7"])
        let adarII = Hilloulot.cles(13, 7, embolismique: true, dernierJour: false)
        #expect(adarII == ["adar-7", "adar2-7"])
        // Ashkénazes : « adar » en Adar I (Rema OH 568:7).
        let adarIAshkenaz = Hilloulot.cles(12, 7, embolismique: true, dernierJour: false, ashkenaz: true)
        #expect(adarIAshkenaz == ["adar-7", "adar1-7"])
        let adarIIAshkenaz = Hilloulot.cles(13, 7, embolismique: true, dernierJour: false, ashkenaz: true)
        #expect(adarIIAshkenaz == ["adar2-7"])
        let trente = Hilloulot.cles(8, 29, embolismique: false, dernierJour: true)
        #expect(trente == ["8-29", "8-30"])
    }

    @Test func chaqueJourDUneAnneeSimpleASaHilloula() throws {
        let table = try lireTable()
        var d = JourCivil.du("2025-09-23")
        let fin = JourCivil.du("2026-09-12")
        while d < fin {
            let n = Hilloulot.pour(table, date: d, enIsrael: false).count
            #expect(n > 0, "\(d)")
            d = d.plus(jours: 1)
        }
        // 30 Tichri 5787 : Rabbi Tsvi Hirsch Chajes (Wikipédia).
        let trenteTichri = Hilloulot.pour(table, date: JourCivil.du("2026-10-11"), enIsrael: false)
        let chajes = trenteTichri.contains { $0.he.contientUnites("צבי הירש חיות") }
        #expect(chajes)
        let forme = ExpressionReguliere("([0-9]{1,2}|adar[12]?)-[0-9]{1,2}")
        let malFormees = table.keys.filter { !forme.couvre($0) }
        #expect(malFormees.isEmpty, "\(malFormees)")
    }

    @Test func lesLiensDeLaCarteDuJour() {
        let hyomi = Hilloulot.lienHyomi(JourCivil.du("2026-10-11"))
        #expect(hyomi == "https://hyomi.org.il/day.php?month1=0&dd=11&mm=10&yy=2026")
        let he = Hilloulot.lienHalakha("iw")
        #expect(he == "https://halachayomit.co.il/he/default.aspx")
        let en = Hilloulot.lienHalakha("en")
        #expect(en == "https://halachayomit.co.il/en/default.aspx")
        let fr = Hilloulot.lienHalakha("fr")
        #expect(fr == "https://halachayomit.co.il/fr/default.aspx")
    }

    @Test func lIllustrationDuJourDeFeteOuDeChabbat() {
        let soukkot = JourAffiche.illustration(fetes: ["soukkot"], date: JourCivil.du("2026-09-26"))
        #expect(soukkot == "scene_sukkot")
        let pessah = JourAffiche.illustration(fetes: ["pessah"], date: JourCivil.du("2027-04-22"))
        #expect(pessah == "char_matsa")
        let chabbat = JourAffiche.illustration(fetes: [], date: JourCivil.du("2026-10-10"))
        #expect(chabbat == "char_shabbat")
        let rien = JourAffiche.illustration(fetes: [], date: JourCivil.du("2026-10-11"))
        #expect(rien == nil)
    }

    @Test func dateLisibleEtRechercheParNom() throws {
        let table = try lireTable()
        let trente = Hilloulot.dateDe("7-30")
        #expect(trente.egalUnites("ל׳ תשרי"))
        let adarII = Hilloulot.dateDe("adar2-7")
        #expect(adarII.egalUnites("ז׳ אדר ב׳"))
        let chajes = Hilloulot.recherche(table, texte: "צבי הירש חיות").contains { $0.cle == "7-30" }
        #expect(chajes)
        let uneLettre = Hilloulot.recherche(table, texte: "א").count
        #expect(uneLettre == 0)
        // En français et en anglais, avec ou sans accents (29/10).
        let chelah = Hilloulot.recherche(table, texte: "Chelah").count
        #expect(chelah > 0)
        let shelah = Hilloulot.recherche(table, texte: "Shelah").count
        #expect(shelah > 0)
        let avecAccent = Hilloulot.recherche(table, texte: "Moché").count
        let sansAccent = Hilloulot.recherche(table, texte: "moche").count
        #expect(avecAccent == sansAccent)
    }

    @Test func lesBiographiesDAutresSourcesAPartAvecLeurSource() throws {
        let table = try lireTable()
        let complete = try Self.complete.get()
        #expect(Set(table.keys) == Set(complete.keys))
        for (cle, liste) in table {
            let noms = liste.map { $0.he }
            let nomsComplets = complete[cle]?.map { $0.he } ?? []
            let memes = noms.count == nomsComplets.count && zip(noms, nomsComplets).allSatisfy { $0.egalUnites($1) }
            #expect(memes, "\(cle)")
        }
        let bios = complete.values.flatMap { $0 }.flatMap { $0.bios }
        #expect(bios.count > 2000)
        let sources = bios.allSatisfy { ($0.source == "m" || $0.source == "l") && !$0.texte.estBlanc }
        #expect(sources)
        // La source est dite : chaque biographie de MyTzadik ou de המאיר לארץ garde le lien vers sa page.
        let liens = bios.allSatisfy { $0.lien?.commenceParUnites("https://") == true }
        #expect(liens)
        let sansBios = table.values.flatMap { $0 }.allSatisfy { $0.bios.isEmpty }
        #expect(sansBios)
    }

    /// Les sources avant le doute depuis le 12/11 (THILLOULOT-03) : les plus célèbres ne sont plus relégués par
    /// une simple note.
    @Test func unJourRangeLesMieuxConnusDAbordLesSourcesAvantLeDoute() throws {
        func h(_ he: String, _ s: String, _ t: String?, _ d: String?) -> Hilloulot.Hilloula {
            Hilloulot.Hilloula(he: he, fr: nil, en: nil, annee: "", sources: s, doute: d, description: t)
        }
        let t: Hilloulot.Table = ["8-23": [h("un", "m", nil, nil), h("doute", "wm", "x", "faux"), h("trois", "hwm", "x", nil),
                                           h("deux", "wm", nil, nil), h("deux-notice", "wm", "x", nil)]]
        let ordre = Hilloulot.duJour(t, ["8-23"]).map { $0.he }
        #expect(ordre == ["trois", "deux-notice", "deux", "doute", "un"])
        let table = try lireTable()
        func cinq(_ cle: String) -> [String] { Array(Hilloulot.duJour(table, [cle]).prefix(5).map { $0.he }) }
        #expect(cinq("2-18").contains("רבי שמעון בר יוחאי"))
        #expect(cinq("10-20").contains { $0.contient("הרמב\"ם") })
    }

    /// Audit du 16/11 : le 30 Adar n'existe qu'en Adar I (Kitsour Yalkut Yosef 40:22 ; Michna Beroura 568:42).
    @Test func leTrenteAdar() {
        // Année embolismique : le 30 Adar I pour tous, jamais le 29 Adar II.
        #expect(Hilloulot.clesPour(.du("2027-03-09"), enIsrael: false).contains("adar-30"))
        #expect(!Hilloulot.clesPour(.du("2027-04-07"), enIsrael: false).contains("adar-30"))
        #expect(Hilloulot.clesPour(.du("2030-03-05"), enIsrael: false, ashkenaz: true).contains("adar-30"))
        #expect(!Hilloulot.clesPour(.du("2030-04-03"), enIsrael: false).contains("adar-30"))
        // Année simple : le 30 Chevat en Ashkenaz ; le 29 Adar en Edot et en Sfard.
        #expect(!Hilloulot.clesPour(.du("2026-03-18"), enIsrael: false, ashkenaz: true).contains("adar-30"))
        #expect(Hilloulot.clesPour(.du("2026-02-17"), enIsrael: false, ashkenaz: true).contains("adar-30"))
        #expect(Hilloulot.clesPour(.du("2026-02-17"), enIsrael: false, ashkenaz: true).contains("adar1-30"))
        #expect(Hilloulot.clesPour(.du("2026-03-18"), enIsrael: false).contains("adar-30"))
        #expect(!Hilloulot.clesPour(.du("2026-02-17"), enIsrael: false).contains("adar-30"))
    }

    @Test func laRechercheSuitLAnneeDeTichriAEloul() throws {
        let table = try lireTable()
        let paires = [("7-1", "11-30"), ("11-30", "adar1-1"), ("adar1-30", "adar-1"), ("adar-29", "adar2-1"),
                      ("adar2-29", "1-1"), ("1-1", "6-29")]
        for (avant, apres) in paires {
            let a = Hilloulot.rangDansLAnnee(avant)
            let b = Hilloulot.rangDansLAnnee(apres)
            #expect(a < b, "\(avant) < \(apres)")
        }
        let rangs = Hilloulot.recherche(table, texte: "רבי").map { Hilloulot.rangDansLAnnee($0.cle) }
        #expect(rangs.count > 100)
        let tries = rangs.sorted()
        #expect(tries == rangs)
    }

    @Test func voirCeJourMeneAuProchainJourDeLaDate() throws {
        // 23 Hechvan 5787 : le 3 novembre 2026 ; depuis le 4, celui de 5788.
        let premier = Hilloulot.prochainJour("8-23", depuis: JourCivil.du("2026-10-01"), enIsrael: false)
        #expect(premier == JourCivil.du("2026-11-03"))
        let suivantOpt = Hilloulot.prochainJour("8-23", depuis: JourCivil.du("2026-11-04"), enIsrael: false)
        let suivant = try #require(suivantOpt)
        let cles = Hilloulot.clesPour(suivant, enIsrael: false)
        let tombe = cles.contains("8-23")
        #expect(tombe)
        let dansLIntervalle = suivant > JourCivil.du("2027-10-01") && suivant < JourCivil.du("2027-12-01")
        #expect(dansLIntervalle, "\(suivant)")
        // Adar II n'existe que les années embolismiques : il se trouve quand même.
        let adarII = Hilloulot.prochainJour("adar2-14", depuis: JourCivil.du("2026-11-04"), enIsrael: false)
        #expect(adarII != nil)
    }

    // MARK: Les vecteurs de la JVM

    @Test func vecteursLaTableLue() throws {
        let v = try Self.vecteurs.get().table
        let table = try lireTable()
        #expect(table.count == v.nombre)
        let total = table.values.reduce(0) { $0 + $1.count }
        #expect(total == v.hilloulot)
        for jour in v.jours {
            let liste = table[jour.cle] ?? []
            #expect(liste.count == jour.nombre, "\(jour.cle)")
            let e = empreinte(liste.map { ligne($0) })
            #expect(e == jour.empreinte, "\(jour.cle)")
        }
        let exemple = comparer(table.filter { $0.key == "7-30" }, v.exemple)
        #expect(exemple.isEmpty, "\(exemple)")
    }

    @Test func vecteursLecturesDEssai() throws {
        for cas in try Self.vecteurs.get().lectures {
            let lue = try? Hilloulot.parse(cas.json)
            if cas.exception {
                #expect(lue == nil, "« \(cas.json) » devait lever")
            } else {
                let t = try #require(lue, "« \(cas.json) »")
                let ecarts = comparer(t, cas.table ?? [])
                #expect(ecarts.isEmpty, "« \(cas.json) » : \(ecarts)")
            }
        }
    }

    @Test func vecteursLesClesDeChaqueMois() throws {
        let v = try Self.vecteurs.get()
        #expect(v.cles.count == 640)
        for c in v.cles {
            let cles = Hilloulot.cles(c.mois, c.jour, embolismique: c.embolismique, dernierJour: c.dernierJour, ashkenaz: c.ashkenaz)
            #expect(cles == c.cles, "\(c.mois) \(c.jour) \(c.embolismique) \(c.dernierJour) \(c.ashkenaz)")
        }
    }

    @Test func vecteursChaqueJourDe5786Et5787() throws {
        let v = try Self.vecteurs.get()
        let table = try lireTable()
        #expect(v.jours.count > 700)
        for j in v.jours {
            let d = try #require(JourCivil(iso: j.jour), "\(j.jour)")
            let cles = Hilloulot.clesPour(d, enIsrael: false)
            #expect(cles == j.cles, "\(j.jour)")
            // En Israël, les mêmes clés (le générateur le vérifie aussi).
            let israel = Hilloulot.clesPour(d, enIsrael: true)
            #expect(israel == j.cles, "\(j.jour) en Israël")
            let p = Hilloulot.pour(table, date: d, enIsrael: false)
            #expect(p.count == j.nombre, "\(j.jour)")
            let e = empreinte(p.map { ligne($0) })
            #expect(e == j.empreinte, "\(j.jour)")
            let clesAshkenaz = Hilloulot.clesPour(d, enIsrael: false, ashkenaz: true)
            if let a = j.ashkenaz {
                #expect(clesAshkenaz == a.cles, "\(j.jour) ashkenaz")
                let pa = Hilloulot.pour(table, date: d, enIsrael: false, ashkenaz: true)
                #expect(pa.count == a.nombre, "\(j.jour) ashkenaz")
                let ea = empreinte(pa.map { ligne($0) })
                #expect(ea == a.empreinte, "\(j.jour) ashkenaz")
            } else {
                #expect(clesAshkenaz == j.cles, "\(j.jour) ashkenaz")
            }
        }
    }

    @Test func vecteursLeClassementDUnJour() throws {
        let v = try Self.vecteurs.get().classements
        let t = try Hilloulot.parse(v.table)
        for c in v.cas {
            let ordre = Hilloulot.duJour(t, c.cles).map { $0.he }
            #expect(ordre == c.noms, "\(c.cles)")
        }
    }

    @Test func vecteursProchainJour() throws {
        for c in try Self.vecteurs.get().prochains {
            let depuis = try #require(JourCivil(iso: c.depuis), "\(c.depuis)")
            let d = Hilloulot.prochainJour(c.cle, depuis: depuis, enIsrael: c.enIsrael, ashkenaz: c.ashkenaz)
            #expect(d?.iso == c.resultat, "\(c.cle) depuis \(c.depuis)")
        }
    }

    @Test func vecteursRangDansLAnnee() throws {
        let v = try Self.vecteurs.get()
        #expect(v.rangs.count > 400)
        for r in v.rangs {
            let rang = Hilloulot.rangDansLAnnee(r.cle)
            #expect(rang == r.rang, "« \(r.cle) »")
        }
    }

    @Test func vecteursDateDe() throws {
        let v = try Self.vecteurs.get()
        // Une clé qui fait lever Kotlin (le jour n'est pas un nombre) n'a pas d'attendu.
        for d in v.dates {
            guard let attendu = d.texte else { continue }
            let texte = Hilloulot.dateDe(d.cle)
            #expect(texte.egalUnites(attendu), "« \(d.cle) » : \(texte) ≠ \(attendu)")
        }
    }

    @Test func vecteursEmbolismiqueAuxBornes() throws {
        for c in try Self.vecteurs.get().meton.bornes {
            let e = Hilloulot.embolismique(c.annee)
            #expect(e == c.embolismique, "\(c.annee)")
        }
    }

    @Test func vecteursLesLiens() throws {
        let v = try Self.vecteurs.get().liens
        for paire in v.hyomi {
            let d = try #require(JourCivil(iso: paire[0]), "\(paire[0])")
            let lien = Hilloulot.lienHyomi(d)
            #expect(lien == paire[1])
        }
        for paire in v.halakha {
            let lien = Hilloulot.lienHalakha(paire[0])
            #expect(lien == paire[1], "« \(paire[0]) »")
        }
        for paire in v.articles + v.table.premiers {
            let lien = Hilloulot.lienArticle(paire[0])
            #expect(lien == paire[1], "« \(paire[0]) »")
        }
        let articles = try lireTable().values.flatMap { $0 }.compactMap { $0.article }
        #expect(articles.count == v.table.nombre)
        // L'ordre du fichier n'est pas gardé par la table de Swift : l'empreinte se calcule dans l'ordre des jours des vecteurs.
        let parJour = try Self.vecteurs.get().table.jours.map { $0.cle }
        let table = try lireTable()
        let liens = parJour.flatMap { cle in (table[cle] ?? []).compactMap { $0.article } }.map(Hilloulot.lienArticle)
        let e = empreinte(liens)
        #expect(e == v.table.empreinte)
    }

    @Test func vecteursLaRechercheParNom() throws {
        let table = try lireTable()
        for r in try Self.vecteurs.get().recherches {
            let trouvees = Hilloulot.recherche(table, texte: r.q)
            #expect(trouvees.count == r.nombre, "« \(r.q) »")
            let e = empreinte(trouvees.map { $0.cle + "\u{1F}" + ligne($0.hilloula) })
            #expect(e == r.empreinte, "« \(r.q) »")
            let premiers = trouvees.prefix(5).map { [$0.cle, $0.hilloula.he] }
            #expect(premiers == r.premiers, "« \(r.q) »")
        }
    }

    @Test func vecteursLesBiographies() throws {
        let v = try Self.vecteurs.get().bios
        let complete = try Self.complete.get()
        let total = complete.values.flatMap { $0 }.reduce(0) { $0 + $1.bios.count }
        #expect(total == v.nombre)
        for jour in v.jours {
            let liste = complete[jour.cle] ?? []
            var lignes: [String] = []
            for (i, h) in liste.enumerated() {
                for b in h.bios { lignes.append("\(i)\u{1F}" + ligne(b)) }
            }
            #expect(lignes.count == jour.nombre, "\(jour.cle)")
            let e = empreinte(lignes)
            #expect(e == jour.empreinte, "\(jour.cle)")
        }
    }

    @Test func vecteursBiographiesDEssai() throws {
        let v = try Self.vecteurs.get().biosEssais
        let t = try Hilloulot.parse(v.table)
        for cas in v.cas {
            let lue = try? Hilloulot.avecBios(t, cas.json)
            if cas.exception {
                #expect(lue == nil, "« \(cas.json) » devait lever")
            } else {
                let complete = try #require(lue, "« \(cas.json) »")
                let ecarts = comparer(complete, cas.table ?? [])
                #expect(ecarts.isEmpty, "« \(cas.json) » : \(ecarts)")
            }
        }
    }

    @Test func chaqueCleASonFichierDeBiographies() throws {
        let table = try lireTable()
        let fichiers = Set(table.keys.map(Hilloulot.fichierDesBios)).sorted()
        #expect(fichiers.count == 14)
        for f in fichiers {
            let present = try Depot.lire(f) != nil
            #expect(present, "\(f)")
        }
        let trente = Hilloulot.fichierDesBios("7-30")
        #expect(trente == "hilloulot_bios/7.json")
    }

    // MARK: Aides

    /// Une hilloula en une ligne, comme le générateur : ses champs séparés par U+001F, nil écrit U+0000.
    private func ligne(_ h: Hilloulot.Hilloula) -> String {
        let champs: [String?] = [h.he, h.fr, h.en, h.annee, h.sources, h.doute, h.description, h.article, h.hidabroot]
        return champs.map { $0 ?? "\u{0}" }.joined(separator: "\u{1F}")
    }

    private func ligne(_ b: Hilloulot.Bio) -> String {
        let champs: [String?] = [b.source, b.texte, b.lien]
        return champs.map { $0 ?? "\u{0}" }.joined(separator: "\u{1F}")
    }

    /// `joinToString("\n").hashCode()` de Kotlin.
    private func empreinte(_ lignes: [String]) -> Int {
        Int(Kotlin.hashCode(lignes.joined(separator: "\n")))
    }

    /// Les écarts entre une table et ce que la JVM en a écrit, champ par champ et unité par unité.
    private func comparer(_ table: Hilloulot.Table, _ ecrite: [JourEcrit]) -> [String] {
        var ecarts: [String] = []
        if table.count != ecrite.count { ecarts.append("\(table.count) jours au lieu de \(ecrite.count)") }
        for jour in ecrite {
            guard let liste = table[jour.cle] else {
                ecarts.append("\(jour.cle) absent")
                continue
            }
            if liste.count != jour.hilloulot.count {
                ecarts.append("\(jour.cle) : \(liste.count) hilloulot au lieu de \(jour.hilloulot.count)")
                continue
            }
            for (h, e) in zip(liste, jour.hilloulot) {
                let champs: [(String?, String?)] = [(h.he, e.he), (h.fr, e.fr), (h.en, e.en), (h.annee, e.annee),
                                                    (h.sources, e.sources), (h.doute, e.doute), (h.description, e.description),
                                                    (h.article, e.article), (h.hidabroot, e.hidabroot)]
                for (i, (a, b)) in champs.enumerated() where !egal(a, b) {
                    ecarts.append("\(jour.cle) « \(e.he) », champ \(i) : \(a ?? "nil") ≠ \(b ?? "nil")")
                }
                let bios = h.bios.map { b -> [String?] in [b.source, b.texte, b.lien] }
                let memes = bios.count == e.bios.count && zip(bios, e.bios).allSatisfy { x, y in
                    x.count == y.count && zip(x, y).allSatisfy { egal($0, $1) }
                }
                if !memes { ecarts.append("\(jour.cle) « \(e.he) » : biographies \(bios) ≠ \(e.bios)") }
            }
        }
        return ecarts
    }

    private func egal(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.egalUnites(y)
        default: return false
        }
    }
}

private enum ErreurDeTest: Error {
    case absent(String)
}

// MARK: Le fichier de vecteurs

private struct Vecteurs: Decodable, Sendable {
    let table: TableReelle
    let lectures: [Lecture]
    let cles: [CasCles]
    let jours: [CasJour]
    let classements: Classements
    let prochains: [CasProchain]
    let rangs: [CasRang]
    let dates: [CasDate]
    let meton: Meton
    let liens: Liens
    let recherches: [CasRecherche]
    let bios: Bios
    let biosEssais: BiosEssais
}

/// [clé, nombre, empreinte].
private struct JourCompte: Decodable {
    let cle: String
    let nombre: Int
    let empreinte: Int

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        cle = try c.decode(String.self)
        nombre = try c.decode(Int.self)
        empreinte = try c.decode(Int.self)
    }
}

private struct HilloulaEcrite: Decodable {
    let he: String
    let fr: String?
    let en: String?
    let annee: String
    let sources: String
    let doute: String?
    let description: String?
    let article: String?
    let hidabroot: String?
    let bios: [[String?]]
}

/// [clé, [hilloula…]].
private struct JourEcrit: Decodable {
    let cle: String
    let hilloulot: [HilloulaEcrite]

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        cle = try c.decode(String.self)
        hilloulot = try c.decode([HilloulaEcrite].self)
    }
}

private struct TableReelle: Decodable {
    let nombre: Int
    let hilloulot: Int
    let jours: [JourCompte]
    let exemple: [JourEcrit]
}

private struct Lecture: Decodable {
    let json: String
    let exception: Bool
    let table: [JourEcrit]?
}

/// [mois, jour, embolismique, dernierJour, ashkenaz, clés].
private struct CasCles: Decodable {
    let mois: Int
    let jour: Int
    let embolismique: Bool
    let dernierJour: Bool
    let ashkenaz: Bool
    let cles: [String]

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        mois = try c.decode(Int.self)
        jour = try c.decode(Int.self)
        embolismique = try c.decode(Bool.self)
        dernierJour = try c.decode(Bool.self)
        ashkenaz = try c.decode(Bool.self)
        cles = try c.decode([String].self)
    }
}

/// [jour, clés, nombre, empreinte] et, quand les clés ashkénazes diffèrent, [clés, nombre, empreinte] de plus.
private struct CasJour: Decodable {
    struct Partie {
        let cles: [String]
        let nombre: Int
        let empreinte: Int
    }

    let jour: String
    let cles: [String]
    let nombre: Int
    let empreinte: Int
    let ashkenaz: Partie?

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        jour = try c.decode(String.self)
        cles = try c.decode([String].self)
        nombre = try c.decode(Int.self)
        empreinte = try c.decode(Int.self)
        if c.isAtEnd {
            ashkenaz = nil
        } else {
            let ca = try c.decode([String].self)
            let na = try c.decode(Int.self)
            let ea = try c.decode(Int.self)
            ashkenaz = Partie(cles: ca, nombre: na, empreinte: ea)
        }
    }
}

private struct Classements: Decodable {
    struct Cas: Decodable {
        let cles: [String]
        let noms: [String]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            cles = try c.decode([String].self)
            noms = try c.decode([String].self)
        }
    }

    let table: String
    let cas: [Cas]
}

/// [clé, depuis, enIsrael, ashkenaz, résultat ou null].
private struct CasProchain: Decodable {
    let cle: String
    let depuis: String
    let enIsrael: Bool
    let ashkenaz: Bool
    let resultat: String?

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        cle = try c.decode(String.self)
        depuis = try c.decode(String.self)
        enIsrael = try c.decode(Bool.self)
        ashkenaz = try c.decode(Bool.self)
        if try c.decodeNil() {
            resultat = nil
        } else {
            resultat = try c.decode(String.self)
        }
    }
}

/// [clé, rang].
private struct CasRang: Decodable {
    let cle: String
    let rang: Int

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        cle = try c.decode(String.self)
        rang = try c.decode(Int.self)
    }
}

/// [clé, texte ou null].
private struct CasDate: Decodable {
    let cle: String
    let texte: String?

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        cle = try c.decode(String.self)
        if try c.decodeNil() {
            texte = nil
        } else {
            texte = try c.decode(String.self)
        }
    }
}

private struct Meton: Decodable {
    /// [année, embolismique, KosherJava].
    struct Annee: Decodable {
        let annee: Int
        let embolismique: Bool
        let kosherJava: Bool

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            annee = try c.decode(Int.self)
            embolismique = try c.decode(Bool.self)
            kosherJava = try c.decode(Bool.self)
        }
    }

    /// [année, embolismique].
    struct Borne: Decodable {
        let annee: Int
        let embolismique: Bool

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            annee = try c.decode(Int.self)
            embolismique = try c.decode(Bool.self)
        }
    }

    let kosherJava: [Annee]
    let bornes: [Borne]
}

private struct Liens: Decodable {
    struct Table: Decodable {
        let nombre: Int
        let empreinte: Int
        let premiers: [[String]]
    }

    let hyomi: [[String]]
    let halakha: [[String]]
    let articles: [[String]]
    let table: Table
}

private struct CasRecherche: Decodable {
    let q: String
    let nombre: Int
    let empreinte: Int
    let premiers: [[String]]
}

private struct Bios: Decodable {
    let nombre: Int
    let jours: [JourCompte]
}

private struct BiosEssais: Decodable {
    let table: String
    let cas: [Lecture]
}
