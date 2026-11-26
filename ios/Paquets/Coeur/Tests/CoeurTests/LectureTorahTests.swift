import Foundation
import Testing
@testable import Coeur

/// LectureTorahTest et LectureSiddurTest d'Android (26/11), portés : la lecture de la Torah des offices de semaine.
/// Le juge est `web/test/vecteurs_lecture_torah.json`, que le site écrit en comparant son calcul à @hebcal/leyning
/// jour par jour et qu'Android relit aussi : chaque jour (septembre 2025 à décembre 2031), en diaspora, en Israël et à
/// Jérusalem, aux deux offices et dans les trois noussa'h, la même réponse. Puis quelques jours, le texte, et la
/// lecture à sa place dans le siddour. Restent à Android : la recherche de « BSD-2-hebcal-leyning.txt » dans
/// SettingsActivity.kt (iOS n'a pas encore d'écran des licences ; la licence est dans le `_meta` des lectures).
@Suite("Lecture de la Torah")
struct LectureTorahTests {

    private static let charges: Result<LectureTorah.Donnees, any Error> = Result {
        try LectureTorah.parse(String(decoding: Depot.contenu("lecture_torah.json"), as: UTF8.self))
    }

    private static let texteCharge: Result<LectureTorah.Texte, any Error> = Result {
        try LectureTorah.Texte(Depot.contenu("lecture_torah_texte.json"))
    }

    private func d() throws -> LectureTorah.Donnees { try Self.charges.get() }

    /// La même ligne que resume() de web/tools/lecture-torah.mjs.
    private func resume(_ l: LectureTorah.Lecture) -> String {
        l.cle + "|" + l.montees.map { "\($0.cle):\($0.livre) \($0.debut)-\($0.fin)" }.joined(separator: ",")
    }

    private func une(_ iso: String, il: Bool = false, nusah: String = "ashkenaz", office: String = LectureTorah.chaharit,
                     muk: Bool = false) throws -> LectureTorah.Lecture {
        let l = try LectureTorah.lectures(d(), date: .du(iso), office: office, enIsrael: il, mukafChoma: muk, nusah: nusah)
        #expect(l.count == 1, "\(iso) \(office) \(nusah)")
        return try #require(l.first)
    }

    // MARK: Les vecteurs du site

    private struct Vecteurs: Decodable {
        let debut: String
        let fin: String
        /// « 2026-11-26/dia » → office → noussa'h (ou « * ») → les lectures résumées.
        let jours: [String: [String: [String: [String]]]]
    }

    @Test func chaqueJourDesVecteursDuSiteLaMemeReponse() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("web/test/vecteurs_lecture_torah.json"))
        let donnees = try d()
        let lieux: [(String, Bool, Bool)] = [("dia", false, false), ("il", true, false), ("jer", true, true)]
        var date = JourCivil.du(v.debut)
        let fin = JourCivil.du(v.fin)
        var lectures = 0
        var ecarts: [String] = []
        while !(fin < date) {
            for (lieu, il, muk) in lieux {
                // Jérusalem n'est écrite que là où elle diffère d'Israël.
                let entree = v.jours["\(date.iso)/\(lieu)"] ?? (lieu == "jer" ? v.jours["\(date.iso)/il"] : nil)
                for office in LectureTorah.offices {
                    let attendu = entree?[office]
                    for nusah in LectureTorah.nusah {
                        let ici = try LectureTorah.lectures(donnees, date: date, office: office, enIsrael: il, mukafChoma: muk,
                                                            nusah: nusah).map { resume($0) }
                        let att = attendu.map { $0[nusah] ?? $0["*"] ?? [] } ?? []
                        if ici != att { ecarts.append("\(date.iso) \(lieu) \(office) \(nusah) : \(ici) au lieu de \(att)") }
                        lectures += ici.count
                    }
                }
            }
            date = date.plus(jours: 1)
        }
        #expect(ecarts.isEmpty, "\(ecarts.count) écarts, dont \(ecarts.prefix(10))")
        // 2 313 jours, trois lieux, deux offices, trois noussa'h : 7 428 lectures, des seuls jours de semaine.
        #expect(lectures == 7_428)
    }

    // MARK: Quelques jours (LectureTorahTest)

    @Test func quelquesJoursCommeLeSite() throws {
        // Jeudi 26/11/2026 : Vayichla'h, trois montées, le troisième « Israël ».
        let l = try une("2026-11-26")
        #expect(l.cle == "semaine:VAYISHLACH")
        #expect(l.titre.fr == "Vayichla\u{2019}h")
        #expect(l.montees.map { $0.libelle.fr } == ["Cohen", "Lévi", "Israël"])
        // Chabbat et Yom tov : rien, à aucun office.
        for iso in ["2026-11-28", "2026-04-02", "2026-10-03", "2026-09-21"] {
            for office in LectureTorah.offices {
                let rien = try LectureTorah.lectures(d(), date: .du(iso), office: office, enIsrael: false).isEmpty
                #expect(rien, "\(iso) \(office)")
            }
        }
        // 'Hanouka, premier jour en semaine : Edot depuis la bénédiction des cohanim (Kitsour Yalkout Yossef 684:1).
        let edot = try une("2025-12-15", nusah: "edot").montees.map { "\($0.debut)-\($0.fin)" }
        #expect(edot == ["6:22-7:3", "7:4-7:11", "7:12-7:17"])
        let ashkenaz = try une("2025-12-15").montees.map { "\($0.debut)-\($0.fin)" }
        #expect(ashkenaz == ["7:1-7:11", "7:12-7:14", "7:15-7:17"])
        // Min'ha d'un jeûne : le troisième maftir chez Ashkenaz ; chez les Edot « Israël », sauf le 9 Av.
        #expect(try une("2026-12-20", office: LectureTorah.minha).montees[2].libelle.fr == "Maftir")
        #expect(try une("2026-12-20", nusah: "edot", office: LectureTorah.minha).montees[2].libelle.fr == "Israël")
        #expect(try une("2026-07-23", nusah: "edot", office: LectureTorah.minha).montees[2].libelle.fr == "Maftir")
        // 9 Av au matin : maftir dans les trois rites (Choul'han Aroukh O.H. 559:4).
        for nusah in LectureTorah.nusah {
            #expect(try une("2026-07-23", nusah: nusah).montees[2].libelle.fr == "Maftir", "\(nusah)")
        }
        // Pourim à Jérusalem le 15, ailleurs le 14.
        #expect(try une("2027-03-24", il: true, muk: true).cle == "Shushan Purim")
        let jerusalem14 = try LectureTorah.lectures(d(), date: .du("2027-03-23"), office: LectureTorah.chaharit, enIsrael: true,
                                                    mukafChoma: true, nusah: "edot")
        #expect(jerusalem14.isEmpty)
        // 'Hol hamoèd Souccot en Israël : les quatre lisent le sacrifice du jour (Kitsour Yalkout Yossef 662:1).
        let souccot = Set(try une("2026-09-28", il: true).montees.map { "\($0.debut)-\($0.fin)" })
        #expect(souccot == ["29:20-29:22"])
    }

    @Test func leTexteDesLecturesLesSeulsChapitresLusLaTorahSeule() throws {
        let texte = try Self.texteCharge.get()
        // Le qere (ketiv גיים), la numérotation d'hebcal (Bamidbar 25:19).
        let qere = try texte.versets(livre: "Genesis", debut: "25:23", fin: "25:23")
        #expect(qere.count == 1)
        #expect(qere.first?.texte.contientUnites("שְׁנֵ֤י גוֹיִם֙") == true)
        let bamidbar = try texte.versets(livre: "Numbers", debut: "25:19", fin: "25:19")
        #expect(bamidbar.map { $0.texte } == ["וַיְהִ֖י אַחֲרֵ֣י הַמַּגֵּפָ֑ה"])
        // La lecture de ce jeudi : trois montées, des versets vocalisés avec leurs teamim.
        let l = try une("2026-11-26")
        let versets = try l.montees.flatMap { try texte.versets($0) }
        #expect(versets.first?.chapitre == 32)
        for v in versets {
            let teamim = v.texte.unicodeScalars.contains { (0x0591...0x05AF).contains($0.value) }
            let voyelles = v.texte.unicodeScalars.contains { (0x05B0...0x05BC).contains($0.value) }
            #expect(teamim && voyelles, "\(v.chapitre):\(v.verset)")
        }
        // Les cinq livres, et rien d'autre ; les seules lectures des jours de semaine.
        let brut = try JSONSerialization.jsonObject(with: Depot.contenu("lecture_torah_texte.json")) as? [String: Any]
        let livres = Set((brut?["livres"] as? [String: Any] ?? [:]).keys)
        #expect(livres == ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"])
        #expect(Set(try d().montees.keys) == ["1", "2", "3", "3_israel", "4", "M"])
        #expect(Set(try d().livres.keys) == livres)
        // Un passage sur deux chapitres (le 16 Nissan en Israël), et la fin de paragraphe « פ » (Berèchit 1:5).
        let deux = try texte.versets(livre: "Leviticus", debut: "22:32", fin: "23:2")
        #expect(deux.map { "\($0.chapitre):\($0.verset)" } == ["22:32", "22:33", "23:1", "23:2"])
        let premier = try texte.versets(livre: "Genesis", debut: "1:4", fin: "1:6")
        #expect(premier.map { $0.fin } == [nil, "\u{05E4}", nil])
    }

    // MARK: La lecture dans le siddour (LectureSiddurTest)

    private struct Siddourim: Sendable {
        let siddourim: [Nusah: Siddur]
        let annotations: [Nusah: [String: [SiddurJour.Annotation]]]
    }

    private static let siddourim: Result<Siddourim, any Error> = Result {
        let json = String(decoding: try Depot.contenu("siddur_annotations.json"), as: UTF8.self)
        var s: [Nusah: Siddur] = [:]
        var a: [Nusah: [String: [SiddurJour.Annotation]]] = [:]
        for n in Nusah.allCases {
            s[n] = try JSONDecoder().decode(Siddur.self, from: Depot.contenu(n.fichier))
            a[n] = try SiddurJour.parse(json, n)
        }
        return Siddourim(siddourim: s, annotations: a)
    }

    private func lignes(_ nusah: String, _ office: String, _ iso: String, il: Bool = false,
                        ouverts: Set<String> = []) throws -> [SiddurJour.Ligne] {
        let n = try #require(Nusah(rawValue: nusah))
        let s = try Self.siddourim.get()
        let texte = try #require(s.siddourim[n]?.texte(office))
        let annotations = try #require(s.annotations[n]?[office])
        let date = JourCivil.du(iso)
        let lectures = try LectureTorah.lecturesOffice(d(), date: date, office: office, enIsrael: il, nusah: nusah)
        return SiddurJour.lignes(texte, annotations, CalendrierJuif.jour(date, enIsrael: il).conditions, ouverts: ouverts,
                                 nusah: n, enIsrael: il, lectures: lectures)
    }

    private func lecturesDe(_ l: [SiddurJour.Ligne]) -> [(cle: String, lecture: LectureTorah.Lecture, ouvert: Bool, rang: Int)] {
        var r: [(cle: String, lecture: LectureTorah.Lecture, ouvert: Bool, rang: Int)] = []
        for (k, x) in l.enumerated() {
            if case let .lecture(cle, lecture, ouvert) = x { r.append((cle: cle, lecture: lecture, ouvert: ouvert, rang: k)) }
        }
        return r
    }

    @Test func unLundiLaLectureReplieeApresLaBenedictionAvantLesMiCheberakh() throws {
        let d = try self.d()
        for nusah in LectureTorah.nusah {
            let l = try lignes(nusah, "chaharit", "2026-11-23")
            let lectures = lecturesDe(l)
            #expect(lectures.count == 1, "\(nusah)")
            let lecture = try #require(lectures.first)
            #expect(lecture.lecture.cle == "semaine:VAYISHLACH")
            #expect(lecture.lecture.montees.count == 3)
            #expect(!lecture.ouvert)
            // Juste après la bénédiction « אשר נתן לנו תורת אמת ».
            guard case let .bloc(avant, _, _) = l[lecture.rang - 1] else {
                Issue.record("\(nusah) : la ligne d'avant n'est pas un bloc")
                continue
            }
            let empreinte = SiddurJour.empreinte(avant.texte)
            #expect(empreinte.commenceParUnites("ברוך אתה יהוה") && empreinte.contientUnites("אשר נתן"), "\(nusah)")
            // Les Mi chébérakh (Sfard, Ashkenaz) viennent après, repliés à part.
            if nusah != "edot" {
                let mi = l.firstIndex { if case .replie(_, _, _, "ajout_mi_cheberakh_oleh", _) = $0 { true } else { false } }
                #expect((mi ?? -1) > lecture.rang, "\(nusah)")
            }
            // Dépliée : trois montées (Cohen, Lévi, Israël), puis la fin du repli.
            let ouverte = try lignes(nusah, "chaharit", "2026-11-23", ouverts: ["lecture:chaharit:0"])
            let i = try #require(lecturesDe(ouverte).first).rang
            var montees: [LectureTorah.Montee] = []
            for x in ouverte[(i + 1)...(i + 3)] {
                if case let .passage(m) = x { montees.append(m) }
            }
            #expect(montees.map { $0.libelle.fr } == ["Cohen", "Lévi", "Israël"])
            #expect(ouverte[i + 4] == .fin(cle: "lecture:chaharit:0"))
            let panneaux = SiddurJour.panneaux(ouverte)
            #expect(panneaux.isSuperset(of: [i + 1, i + 2, i + 3]))
            // « Berèchit 32:4–6 », le nom hébreu du livre écrit à la manière de chaque langue.
            let m = try #require(montees.first)
            #expect(LectureTorah.reference(d, livre: m.livre, debut: m.debut, fin: m.fin, langue: "fr") == "Berèchit 32:4\u{2013}6")
            #expect(LectureTorah.reference(d, livre: m.livre, debut: m.debut, fin: m.fin, langue: "en") == "Bereshit 32:4\u{2013}6")
            #expect(LectureTorah.reference(d, livre: m.livre, debut: m.debut, fin: m.fin, langue: "es") == "בראשית 32:4\u{2013}6")
        }
    }

    @Test func unMardiSansLectureNiLectureNiSection() throws {
        for nusah in LectureTorah.nusah {
            let rien = lecturesDe(try lignes(nusah, "chaharit", "2026-11-24")).isEmpty
            #expect(rien, "\(nusah)")
        }
    }

    @Test func rochHodechEtHanoukaARochHodechTevetQuatreMontees() throws {
        for nusah in LectureTorah.nusah {
            let rc = try #require(lecturesDe(try lignes(nusah, "chaharit", "2026-11-10")).first).lecture
            #expect(rc.cle == "Rosh Chodesh")
            #expect(rc.montees.count == 4)
            let tevet = try #require(lecturesDe(try lignes(nusah, "chaharit", "2026-12-11")).first).lecture
            #expect(tevet.cle == "Chanukah Day 7 (on Rosh Chodesh)")
            #expect(tevet.montees.map { $0.debut } == ["28:1", "28:6", "28:11", "7:48"])
        }
    }

    @Test func neufAvLeMatinEtAMinhaUneSeuleLectureSansLesReperesQuiLaDecrivaient() throws {
        for nusah in LectureTorah.nusah {
            let matins = lecturesDe(try lignes(nusah, "chaharit", "2026-07-23"))
            #expect(matins.count == 1, "\(nusah)")
            let matin = try #require(matins.first)
            #expect(matin.lecture.cle == "Tish'a B'Av")
            #expect(matin.lecture.montees.map { $0.debut } == ["4:25", "4:30", "4:36"])
            #expect(matin.lecture.montees[2].libelle.fr == "Maftir", "\(nusah)")
            let minha = try lignes(nusah, "minha", "2026-07-23")
            let l = lecturesDe(minha)
            #expect(l.count == 1, "\(nusah)")
            let apresMidi = try #require(l.first)
            #expect(apresMidi.lecture.cle == "Tish'a B'Av (Mincha)")
            #expect(apresMidi.cle.commenceParUnites("lecture:minha:"))
            #expect(apresMidi.lecture.montees[2].libelle.fr == "Maftir", "\(nusah)")
            let reperes = minha.contains {
                if case let .indice(t, _) = $0 { t.contientUnites("ויחל") || t.contientUnites("שובה ישראל") } else { false }
            }
            #expect(!reperes, "\(nusah)")
        }
    }

    @Test func unJeunePublicAMinhaLeTroisiemeSelonLeRite() throws {
        for nusah in LectureTorah.nusah {
            let l = try #require(lecturesDe(try lignes(nusah, "minha", "2026-12-20")).first).lecture
            #expect(l.cle == "Asara B'Tevet (Mincha)")
            #expect(l.montees[2].libelle.fr == (nusah == "edot" ? "Israël" : "Maftir"), "\(nusah)")
            let rien = lecturesDe(try lignes(nusah, "minha", "2026-12-21")).isEmpty
            #expect(rien, "\(nusah)")
        }
    }

    @Test func niYomTovNiChabbatDansLesOfficesDeSemaine() throws {
        for nusah in LectureTorah.nusah {
            for iso in ["2026-11-28", "2026-04-02", "2026-10-03"] {
                let rien = lecturesDe(try lignes(nusah, "chaharit", iso)).isEmpty
                #expect(rien, "\(nusah) \(iso)")
            }
            let kippour = lecturesDe(try lignes(nusah, "minha", "2026-09-21")).isEmpty
            #expect(kippour, "\(nusah)")
            // 'Hol hamoed, 'Hanouka : la lecture reste.
            #expect(lecturesDe(try lignes(nusah, "chaharit", "2026-04-05")).first?.lecture.cle == "Pesach Chol ha-Moed Day 1")
            #expect(lecturesDe(try lignes(nusah, "chaharit", "2026-12-07")).first?.lecture.cle == "Chanukah Day 3")
        }
        let jour = CalendrierJuif.jour(.du("2026-11-28"), enIsrael: false)
        #expect(jour.conditions.contains(CalendrierJuif.C.kriatHatorah))
        #expect(!LectureTorah.litDansLOffice(jour, office: LectureTorah.chaharit))
    }

    @Test func leCalendrierEtLeCalculSAccordentCinqAnsDurant() throws {
        let donnees = try d()
        var j = JourCivil.du("2025-09-01")
        let fin = JourCivil.du("2030-09-01")
        var ecarts: [String] = []
        while j < fin {
            for il in [false, true] {
                let jour = CalendrierJuif.jour(j, enIsrael: il)
                for office in LectureTorah.offices {
                    let lit = LectureTorah.litDansLOffice(jour, office: office)
                    let lectures = try !LectureTorah.lectures(donnees, date: j, office: office, enIsrael: il).isEmpty
                    if lit != lectures { ecarts.append("\(j.iso) \(il) \(office)") }
                }
            }
            j = j.plus(jours: 1)
        }
        #expect(ecarts.isEmpty, "\(ecarts.prefix(10))")
    }

    @Test func laQuestionIsraelOuDiasporaTientCompteDeLaLecture() throws {
        // Dimanche 27/09/2026 (16 Tichri) : 'Hol hamoed en Israël, sa lecture ; second jour de Souccot en diaspora (Yom tov,
        // rien dans l'office de semaine).
        let donnees = try d()
        let date = JourCivil.du("2026-09-27")
        let israel = try LectureTorah.lecturesOffice(donnees, date: date, office: "chaharit", enIsrael: true)
        #expect(israel.map { $0.cle } == ["Sukkot Chol ha-Moed Day 1 (Israel)"])
        let diaspora = try LectureTorah.lecturesOffice(donnees, date: date, office: "chaharit", enIsrael: false)
        #expect(diaspora.isEmpty)
        let s = try Self.siddourim.get()
        let texte = try #require(s.siddourim[.edot]?.texte("chaharit"))
        let annotations = try #require(s.annotations[.edot]?["chaharit"])
        let depend = SiddurJour.dependDeLaRegion(texte, annotations,
                                                 israel: CalendrierJuif.jour(date, enIsrael: true).conditions,
                                                 diaspora: CalendrierJuif.jour(date, enIsrael: false).conditions, nusah: .edot,
                                                 lecturesIsrael: israel, lecturesDiaspora: diaspora)
        #expect(depend)
    }

    /// Les chaînes de la lecture dans les cinq langues du catalogue, et la mention d'hebcal dans les sources.
    @Test func lesChainesDeLaLectureDansLesCinqLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for cle in ["lecture_titre", "lecture_chargement", "lecture_tahanoun_oui", "lecture_tahanoun_non",
                        "siddur_region_question", "siddur_region_titre"] {
                #expect(simples[cle] != nil, "\(langue) \(cle)")
            }
            let licences = simples["licences_texte"] ?? ""
            #expect(licences.contientUnites("@hebcal/leyning") && licences.contientUnites("BSD"), "\(langue)")
        }
        // La licence BSD d'hebcal voyage avec les lectures, que l'app embarque.
        let lectures = String(decoding: try Depot.contenu("lecture_torah.json"), as: UTF8.self)
        #expect(lectures.contientUnites("Copyright (c) 2020, hebcal"))
    }
}
