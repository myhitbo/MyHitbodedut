import Foundation
import Testing
@testable import Coeur

/// SiddurJourTest d'Android, porté sur les contenus exportés (siddur_annotations.json et les trois
/// siddourim) : les annotations désignent encore leur bloc, leurs conditions existent et chaque
/// libellé est traduit (dans le catalogue d'iOS, pour les strings.xml d'Android), les ajouts
/// principaux sont annotés, et les lignes du jour (renvois, étiquettes, replis, styles) sont celles
/// d'Android, à la règle du 26/11 (un ajout du calendrier retiré hors de son jour, une occasion repliée).
/// Rien n'y reste à Android. Puis les vecteurs de la JVM (siddur_jour.json) : parse, les lignes de chaque
/// texte sur une quarantaine de jours (jour voisin et lecture de la Torah compris), celles de deux textes
/// écrits à la main, decision, dependDeLaRegion, vrai, libelle, libelleJour, empreinte, et l'illustration
/// de SiddurMoment.
@Suite("Siddour du jour")
struct SiddurJourTests {

    // MARK: Les contenus, lus une fois

    private struct Donnees: Sendable {
        let siddourim: [Nusah: Siddur]
        let annotations: [Nusah: [String: [SiddurJour.Annotation]]]
    }

    private static let charges: Result<Donnees, any Error> = Result {
        let brut = try Depot.contenu("siddur_annotations.json")
        let json = String(decoding: brut, as: UTF8.self)
        var siddourim: [Nusah: Siddur] = [:]
        var annotations: [Nusah: [String: [SiddurJour.Annotation]]] = [:]
        for n in Nusah.allCases {
            siddourim[n] = try JSONDecoder().decode(Siddur.self, from: Depot.contenu(n.fichier))
            annotations[n] = try SiddurJour.parse(json, n)
        }
        return Donnees(siddourim: siddourim, annotations: annotations)
    }

    private func donnees() throws -> Donnees { try Self.charges.get() }

    private func siddur(_ n: Nusah) throws -> Siddur {
        let d = try donnees()
        return try #require(d.siddourim[n], "\(n.rawValue)")
    }

    private func conditions(_ iso: String, israel: Bool = false) -> Set<String> {
        CalendrierJuif.jour(.du(iso), enIsrael: israel).conditions
    }

    /// `SiddurJour.lignes` d'un texte du siddour, avec ses annotations.
    private func lignes(_ n: Nusah, _ id: String, _ conditionsDuJour: Set<String>, ouverts: Set<String> = [],
                        enIsrael: Bool = false) throws -> [SiddurJour.Ligne] {
        let d = try donnees()
        let texte = try #require(d.siddourim[n]?.texte(id), "\(n.rawValue)/\(id)")
        let annotations = try #require(d.annotations[n]?[id], "\(n.rawValue)/\(id) sans annotations")
        return SiddurJour.lignes(texte, annotations, conditionsDuJour, ouverts: ouverts, nusah: n, enIsrael: enIsrael)
    }

    // MARK: Les lignes, par genre

    private struct Repli {
        let cle: String
        let condition: String
        let ouvert: Bool
        let libelle: String
        let pasAujourdhui: Bool
    }

    private func replis(_ l: [SiddurJour.Ligne]) -> [Repli] {
        var r: [Repli] = []
        for x in l {
            if case let .replie(cle, condition, ouvert, libelle, pasAujourdhui) = x {
                r.append(Repli(cle: cle, condition: condition, ouvert: ouvert, libelle: libelle, pasAujourdhui: pasAujourdhui))
            }
        }
        return r
    }

    /// Les clés que « tous » et « alternes » ouvrent : celles des replis et des lectures de la Torah.
    private func cles(_ l: [SiddurJour.Ligne]) -> [String] {
        var r: [String] = []
        for x in l {
            switch x {
            case let .replie(cle, _, _, _, _): r.append(cle)
            case let .lecture(cle, _, _): r.append(cle)
            default: break
            }
        }
        return r
    }

    /// Un repli du calendrier gardé replié (pas aujourd'hui), une occasion, ou l'Anénou du particulier (Q2).
    private func repliPermis(_ r: Repli) -> Bool {
        SiddurJour.occasions.contains(r.condition) || r.pasAujourdhui || r.libelle == "ajout_jeune_individuel"
    }

    private func blocs(_ l: [SiddurJour.Ligne]) -> [(bloc: SiddurBloc, style: SiddurJour.Style)] {
        var r: [(bloc: SiddurBloc, style: SiddurJour.Style)] = []
        for x in l {
            if case let .bloc(b, style, _) = x { r.append((bloc: b, style: style)) }
        }
        return r
    }

    /// Les libellés des étiquettes, dans l'ordre.
    private func etiquettes(_ l: [SiddurJour.Ligne]) -> [String] {
        var r: [String] = []
        for x in l {
            if case let .etiquette(_, libelle) = x { r.append(libelle) }
        }
        return r
    }

    /// Les cibles des renvois, dans l'ordre.
    private func cibles(_ l: [SiddurJour.Ligne]) -> [String] {
        var r: [String] = []
        for x in l {
            if case let .renvoi(_, cible) = x { r.append(cible) }
        }
        return r
    }

    private func sansNegation(_ condition: String) -> String {
        condition.commenceParUnites("!") ? condition.sansPremieresUnites(1) : condition
    }

    // MARK: SiddurJourTest

    @Test func chaqueAnnotationDesigneEncoreSonBloc() throws {
        let d = try donnees()
        for n in Nusah.allCases {
            let siddur = try #require(d.siddourim[n])
            let parTexte = (d.annotations[n] ?? [:]).sorted { $0.key < $1.key }
            for (id, annotations) in parTexte {
                let texte = try #require(siddur.texte(id), "\(n.rawValue)/\(id)")
                for a in annotations {
                    let rang = a.bloc.map { String($0) } ?? "null"
                    let lieu = "\(n.rawValue)/\(id) §\(a.section)/\(rang)"
                    guard texte.sections.indices.contains(a.section) else {
                        Issue.record("\(lieu) : pas de section")
                        continue
                    }
                    let section = texte.sections[a.section]
                    let vu: String
                    if let b = a.bloc {
                        guard section.blocs.indices.contains(b) else {
                            Issue.record("\(lieu) : pas de bloc")
                            continue
                        }
                        vu = SiddurJour.empreinte(section.blocs[b].texte)
                    } else {
                        vu = SiddurJour.empreinte(section.titre)
                    }
                    let egal = vu.egalUnites(a.empreinte)
                    #expect(egal, "\(lieu) : « \(vu) » au lieu de « \(a.empreinte) »")
                }
            }
        }
    }

    @Test func lesConditionsExistentEtChaqueLibelleEstTraduit() throws {
        let connues = Set(CalendrierJuif.C.toutes + CalendrierJuif.C.derivees)
        let catalogue = try Catalogue.lire()
        let chaines = Catalogue.langues.map { (langue: $0, simples: catalogue.simples($0)) }
        let d = try donnees()
        for n in Nusah.allCases {
            let parTexte = (d.annotations[n] ?? [:]).sorted { $0.key < $1.key }
            for (_, annotations) in parTexte {
                for a in annotations {
                    let connue = connues.contains(sansNegation(a.condition))
                    #expect(connue, "\(n.rawValue) : \(a.condition)")
                    let libelle = SiddurJour.libelle(a.condition)
                    for c in chaines {
                        let traduit = c.simples[libelle] != nil
                        #expect(traduit, "\(n.rawValue) : \(libelle) (\(c.langue))")
                    }
                    if a.sorte == .bloc {
                        let groupe = a.groupe != nil && a.racine != nil
                        #expect(groupe, "\(n.rawValue) : bloc §\(a.section) sans groupe ni racine")
                    }
                    if let propre = a.libelle {
                        for c in chaines {
                            let traduit = c.simples[propre] != nil
                            #expect(traduit, "\(n.rawValue) : \(propre) (\(c.langue))")
                        }
                    }
                }
            }
        }
    }

    @Test func lesAjoutsPrincipauxSontAnnotesDansLesTroisNusah() throws {
        let d = try donnees()
        for n in Nusah.allCases {
            let parTexte = try #require(d.annotations[n])
            func annotees(_ id: String) -> Set<String> { Set((parTexte[id] ?? []).map { $0.condition }) }
            let chaharit = annotees("chaharit")
            for c in ["yaale_veyavo", "al_hanissim", "hanouka", "pourim", "tal_oumatar", "berakha", "asseret_yemei_techouva"] {
                #expect(chaharit.contains(c), "\(n.rawValue) : \(c)")
            }
            // Été / hiver dans les trois offices (14/10 : l'Arvit ashkénaze n'était pas marqué).
            for office in ["chaharit", "minha", "arvit"] {
                let c = annotees(office)
                for saison in ["tal_oumatar", "berakha"] { #expect(c.contains(saison), "\(n.rawValue) \(office) : \(saison)") }
            }
            let repas = annotees("birkat_hamazon")
            for c in ["yaale_veyavo", "al_hanissim", "chabbat"] { #expect(repas.contains(c), "\(n.rawValue) repas : \(c)") }
        }
    }

    /// Roch 'Hodech (12/10) : dans Cha'harit, « Aujourd'hui · Hallel › » puis « Moussaf › » ; un jour ordinaire, rien.
    @Test func rochHodechChaharitRenvoieAuHallelPuisAuMoussaf() throws {
        let rc = conditions("2026-10-12")
        let ordinaire = conditions("2026-10-14")
        for n in Nusah.allCases {
            let s = try siddur(n)
            let renvois = cibles(try lignes(n, "chaharit", rc))
            #expect(renvois == ["hallel", "moussaf_rosh_hodech"], "\(n.rawValue)")
            for cible in renvois {
                let existe = s.texte(cible) != nil
                #expect(existe, "\(n.rawValue) : \(cible)")
            }
            let aucun = cibles(try lignes(n, "chaharit", ordinaire)).isEmpty
            #expect(aucun, "\(n.rawValue)")
        }
    }

    /// Règle du 26/11 : à Roch 'Hodech, Ya'alé véyavo en évidence avec sa seule ligne du jour (la variante de Pessa'h est
    /// retirée, Q8) ; Al hanissim, du calendrier, est retiré, sans bandeau replié. À 'Hanouka, il revient, avec la ligne
    /// de 'Hanouka seule.
    @Test func rochHodechYaaleVeyavoEnEvidenceAlHanissimRetire() throws {
        let d = try donnees()
        let texte = try #require(d.siddourim[.edot]?.texte("chaharit"))
        let annotations = try #require(d.annotations[.edot]?["chaharit"])
        let lignes = SiddurJour.lignes(texte, annotations, conditions("2026-10-12"))
        let etiquette = lignes.contains(.etiquette(condition: "yaale_veyavo", libelle: "ajout_yaale_veyavo"))
        #expect(etiquette)
        let replieAlHanissim = replis(lignes).contains { $0.condition == "al_hanissim" }
        #expect(!replieAlHanissim)
        let etiquetteAlHanissim = lignes.contains { if case .etiquette("al_hanissim", _) = $0 { true } else { false } }
        #expect(!etiquetteAlHanissim)
        let empreintes = blocs(lignes).map { SiddurJour.empreinte($0.bloc.texte) }
        let rochHodech = empreintes.contains { $0.contientUnites("ראש חדש הזה") }
        #expect(rochHodech)
        let pessah = empreintes.contains { $0.contientUnites("חג המצות הזה") }
        #expect(!pessah)
        let alHanissim = empreintes.contains { $0.commenceParUnites("ועל הנסים") }
        #expect(!alHanissim)
        // 'Hanouka (27 Kislev) : Al hanissim en évidence, « בימי מתתיה », sans « בימי מרדכי ».
        let hanouka = SiddurJour.lignes(texte, annotations, conditions("2026-12-07"))
        let etiquetteHanouka = hanouka.contains(.etiquette(condition: "al_hanissim", libelle: "ajout_al_hanissim"))
        #expect(etiquetteHanouka)
        let h = blocs(hanouka).map { SiddurJour.empreinte($0.bloc.texte) }
        let matityahou = h.contains { $0.contientUnites("בימי מתתיה") }
        #expect(matityahou)
        let mordekhai = h.contains { $0.contientUnites("בימי מרדכי") }
        #expect(!mordekhai)
        // Aucun repli du calendrier dans Cha'harit un jour ordinaire : seuls ceux des occasions restent.
        let ordinaire = SiddurJour.lignes(texte, annotations, conditions("2026-11-17"))
        for r in replis(ordinaire) { #expect(repliPermis(r), "\(r.condition)") }
    }

    @Test func anenouLOfficiantEtLeParticulierSelonLeNusah() throws {
        let jeune = conditions("2026-12-20") // 10 Tévèt
        func tout(_ n: Nusah, _ id: String, _ c: Set<String>) throws -> [SiddurJour.Ligne] {
            let fermees = try lignes(n, id, c)
            return try lignes(n, id, c, ouverts: Set(replis(fermees).map { $0.cle }))
        }
        func officiant(_ l: [SiddurJour.Ligne]) -> Bool {
            blocs(l).contains {
                let e = SiddurJour.empreinte($0.bloc.texte)
                return e.contientUnites("השליח ציבור אומר בחזרה") || e.contientUnites("אומר כאן הש״ץ עננו")
            }
        }
        // 26/11, Q2 : le particulier en évidence les jours de jeûne public ; Edot, à Cha'harit comme à Min'ha ; Ashkenaz
        // et Sfard, à Min'ha seulement.
        let edotChaharit = etiquettes(try lignes(.edot, "chaharit", jeune)).contains("ajout_anenou_particulier")
        #expect(edotChaharit)
        let edotMinha = etiquettes(try lignes(.edot, "minha", jeune)).contains("ajout_anenou_particulier")
        #expect(edotMinha)
        for n in [Nusah.ashkenaz, .sefard] {
            let chaharit = etiquettes(try lignes(n, "chaharit", jeune)).contains { $0.commenceParUnites("ajout_anenou") }
            #expect(!chaharit, "\(n.rawValue)")
            let minha = etiquettes(try lignes(n, "minha", jeune)).contains("ajout_anenou_particulier")
            #expect(minha, "\(n.rawValue)")
        }
        // L'officiant, ces jours-là, replié sous « Avec minyan » (pas d'étiquette) ; son texte se lit une fois déplié.
        for n in Nusah.allCases {
            let l = try lignes(n, "minha", jeune)
            let etiquette = etiquettes(l).contains("ajout_anenou_officiant")
            #expect(!etiquette, "\(n.rawValue)")
            let deplie = officiant(try tout(n, "minha", jeune))
            #expect(deplie, "\(n.rawValue)")
            for r in replis(l) { #expect(repliPermis(r), "\(n.rawValue) : \(r.condition)") }
        }
        // Un jour ordinaire : l'officiant retiré, même tout déplié ; le particulier replié sous « Jeûne individuel ».
        let ordinaire = conditions("2026-12-21")
        for n in Nusah.allCases {
            let l = try tout(n, "minha", ordinaire)
            let retire = !officiant(l)
            #expect(retire, "\(n.rawValue)")
            let individuel = replis(l).contains { $0.libelle == "ajout_jeune_individuel" && !$0.pasAujourdhui }
            #expect(individuel, "\(n.rawValue)")
        }
    }

    @Test func ashkenazHorsDIsraelMoridHatalRetireLEte() throws {
        let ete = conditions("2027-06-01")
        func etat(_ n: Nusah, _ israel: Bool) throws -> [SiddurJour.Ligne] { try lignes(n, "chaharit", ete, enIsrael: israel) }
        // 26/11 : ni replié ni en évidence, retiré.
        let diaspora = try etat(.ashkenaz, false)
        let replie = replis(diaspora).contains { $0.condition == "morid_hatal" }
        #expect(!replie)
        let enEvidence = diaspora.contains { if case .etiquette("morid_hatal", _) = $0 { true } else { false } }
        #expect(!enEvidence)
        let etiquette = SiddurJour.Ligne.etiquette(condition: "morid_hatal", libelle: "ajout_morid_hatal")
        let israel = try etat(.ashkenaz, true).contains(etiquette)
        #expect(israel)
        let sefard = try etat(.sefard, false).contains(etiquette)
        #expect(sefard)
    }

    /// Avinou malkénou (14/10) : retiré un jour ordinaire (26/11), en évidence le 10 Tévèt et pendant les dix jours.
    @Test func avinouMalkenouJeunesEtDixJoursSeulement() throws {
        func am(_ d: String) -> Bool {
            SiddurJour.conditionsPour(.ashkenaz, enIsrael: true, conditions(d, israel: true)).contains(CalendrierJuif.C.avinouMalkenou)
        }
        for d in ["2026-12-20", "2026-09-15", "2026-09-13", "2026-09-14"] { #expect(am(d), "\(d)") }
        for d in ["2026-12-21", "2026-09-12", "2026-09-19", "2026-09-20", "2027-08-12"] { #expect(!am(d), "\(d)") }
        for n in [Nusah.ashkenaz, .sefard] {
            func duJour(_ d: String) throws -> [SiddurJour.Ligne] {
                try lignes(n, "chaharit", conditions(d, israel: true), enIsrael: true)
            }
            let ordinaire = try duJour("2026-12-21")
            let present = replis(ordinaire).contains { $0.condition == "avinou_malkenou" }
                || ordinaire.contains { if case .etiquette("avinou_malkenou", _) = $0 { true } else { false } }
            #expect(!present, "\(n.rawValue)")
            let etiquette = SiddurJour.Ligne.etiquette(condition: "avinou_malkenou", libelle: "ajout_avinou_malkenou")
            let jeune = try duJour("2026-12-20").contains(etiquette)
            #expect(jeune, "\(n.rawValue)")
        }
    }

    /// La lecture de la Torah (15/10) : ouverte les jours de lecture, retirée un mardi ordinaire (26/11).
    @Test func kriatHatorahRetireeLesJoursSansLecture() throws {
        func c(_ d: String) -> Set<String> { conditions(d, israel: true) }
        for d in ["2026-10-19", "2026-10-15", "2026-10-17", "2026-11-11", "2026-12-20", "2026-09-29"] {
            #expect(c(d).contains(CalendrierJuif.C.kriatHatorah), "\(d)")
        }
        for d in ["2026-10-20", "2026-10-21", "2026-10-23"] { #expect(!c(d).contains(CalendrierJuif.C.kriatHatorah), "\(d)") }
        for n in Nusah.allCases {
            func duJour(_ d: String) throws -> [SiddurJour.Ligne] { try lignes(n, "chaharit", c(d), enIsrael: true) }
            let mardi = try duJour("2026-10-20")
            let present = replis(mardi).contains { $0.condition == "kriat_hatorah" }
                || mardi.contains { if case .etiquette("kriat_hatorah", _) = $0 { true } else { false } }
            #expect(!present, "\(n.rawValue)")
            let etiquette = SiddurJour.Ligne.etiquette(condition: "kriat_hatorah", libelle: "ajout_kriat_hatorah")
            let lundiLecture = try duJour("2026-10-19").contains(etiquette)
            #expect(lundiLecture, "\(n.rawValue)")
            // « אל ארך אפים » : dit un lundi ordinaire, retiré à Pourim (23/03/2027) et à 'Hanouka (07/12/2026), sans Ta'hanoun.
            func elArekh(_ d: String) throws -> SiddurJour.Style? {
                blocs(try duJour(d)).first { SiddurJour.empreinte($0.bloc.texte).commenceParUnites("אל ארך אפים") }?.style
            }
            let lundi = try elArekh("2026-10-19")
            #expect(lundi == .duJour, "\(n.rawValue)")
            let pourim = try elArekh("2027-03-23")
            #expect(pourim == nil, "\(n.rawValue)")
            let hanouka = try elArekh("2026-12-07")
            #expect(hanouka == nil, "\(n.rawValue)")
        }
        // Les « יהי רצון » (Sfard, Ashkenaz) : lundi et jeudi avec Ta'hanoun seulement ; pas à Roch 'Hodech (11/11/2026, mercredi).
        for n in [Nusah.sefard, .ashkenaz] {
            func yehiRatson(_ d: String) throws -> SiddurJour.Style? {
                let l = try lignes(n, "chaharit", c(d), enIsrael: true)
                return blocs(l).first { SiddurJour.empreinte($0.bloc.texte).commenceParUnites("יהי רצון מלפני אבינו") }?.style
            }
            let lundi = try yehiRatson("2026-10-19")
            #expect(lundi == .duJour, "\(n.rawValue)")
            let rochHodech = try yehiRatson("2026-11-11")
            #expect(rochHodech == nil, "\(n.rawValue)")
        }
    }

    @Test func uneConditionNieeSAppliqueQuandLaCleManque() {
        #expect(SiddurJour.vrai("!tahanoun_minha", ["chabbat"]))
        #expect(!SiddurJour.vrai("!tahanoun_minha", ["tahanoun_minha"]))
        #expect(SiddurJour.vrai("roch_hodech", ["roch_hodech"]))
        #expect(SiddurJour.libelle("!tahanoun_chaharit") == "ajout_sans_tahanoun")
        #expect(SiddurJour.libelle("kippour") == "fete_yom_kippour")
    }

    // MARK: Les vecteurs de la JVM (tools/vecteurs_ios/VecteursSiddurJour.kt)

    private struct Vecteurs: Decodable {
        struct Cas: Decodable {
            let nom: String
            let date: String
            let israel: Bool
            let muree: Bool
            let sud: Bool
            let finTichri: Bool?
            /// Le jour voisin (26/11, Q6), צדיק / צדקת, « Pas de Ta'hanoun aujourd'hui », la nuit.
            let voisin: String?
            let adresse: String?
            let sansTahanoun: Bool
            let nuit: Bool
            let conditions: [String]
            let conditionsVoisin: [String]
            /// conditionsPour pour Edot, Sefard, Ashkenaz.
            let pour: [[String]]
        }

        /// Un texte, un cas, des replis (« aucun », « tous », « alternes ») : l'empreinte de la suite des
        /// lignes et leur compte par genre.
        struct Releve: Decodable {
            let n: String
            let t: String
            let c: Int
            let o: String
            let h: Int32
            let s: [Int]
            /// Les clés des lectures de la Torah de cet office ce jour-là.
            let l: [String]
            /// Les places lues dans le panneau d'un repli déplié, en empreinte (`List.hashCode`).
            let p: Int32
        }

        struct Detail: Decodable {
            let n: String
            let t: String
            let c: Int
            let o: String
            let lignes: [String]
        }

        /// Un texte et des annotations écrits à la main : les branches que les siddourim n'atteignent pas.
        struct TexteEcrit: Decodable {
            struct Lecture: Decodable {
                let t: String
                let c: Int
                let nusah: String
                let israel: Bool
                let finTichri: Bool?
                let sud: Bool
                let ouverts: [String]
                let h: Int32
                let s: [Int]
                /// La suite entière, pour quelques lectures.
                let lignes: [String]?
                /// Les places lues dans le panneau d'un repli déplié.
                let panneaux: [Int]
            }

            let siddur: String
            let annotations: String
            let conditions: [[String]]
            let lectures: [Lecture]
        }

        struct Parse: Decodable {
            struct Fichier: Decodable {
                let n: String
                let t: String
                let nombre: Int
                let parSorte: [Int]
                let h: Int32
            }

            struct Texte: Decodable {
                let texte: String
                let annotations: [String]
            }

            /// Ce que parse rend d'un fichier écrit à la main : une faute, ou les annotations par texte.
            enum Lu: Decodable {
                case erreur
                case textes([Texte])

                init(from decoder: any Decoder) throws {
                    let c = try decoder.singleValueContainer()
                    if let mot = try? c.decode(String.self) {
                        guard mot == "erreur" else {
                            throw DecodingError.dataCorruptedError(in: c, debugDescription: "réponse inconnue : \(mot)")
                        }
                        self = .erreur
                    } else {
                        self = .textes(try c.decode([Texte].self))
                    }
                }
            }

            struct Ecrit: Decodable {
                let json: String
                let edot: Lu
                let sefard: Lu
                let ashkenaz: Lu
            }

            let fichier: [Fichier]
            let ecrits: [Ecrit]
        }

        struct Libelles: Decodable {
            struct Vrai: Decodable {
                let c: String
                let r: [Bool]
            }

            struct Jour: Decodable {
                let c: String
                let e: Int
                let r: [String]
            }

            struct Propre: Decodable {
                let propre: String
                let c: String
                let r: [String]
            }

            let libelle: [[String]]
            let jourReel: [String]
            let vrai: [Vrai]
            let ensemblesHallel: [[String]]
            let libelleJour: [Jour]
            let libelleJourPropre: [Propre]
        }

        struct Empreinte: Decodable {
            struct Siddour: Decodable {
                let n: String
                let t: String
                let nombre: Int
                let h: Int32
            }

            let textes: [[String]]
            let siddourim: [Siddour]
        }

        struct Moment: Decodable {
            let illustration: [[String]]
        }

        /// Le texte écrit des deux catégories du 26/11 : chaque jour, chaque voisin, chaque jeu de lectures, trois
        /// réglages, trois façons d'ouvrir ; puis decision sur chaque annotation.
        struct Categories: Decodable {
            struct Releve: Decodable {
                let c: Int
                let v: Int
                let l: Int
                let r: Int
                let o: String
                let ouverts: [String]
                let h: Int32
                let s: [Int]
                let panneaux: [Int]
                let lignes: [String]?
            }

            let siddur: String
            let annotations: String
            let conditions: [[String]]
            let voisins: [[String]]
            let lectures: [[String]]
            let releves: [Releve]
            /// [section, bloc ou nil, jour, voisin, état, pas aujourd'hui, libellé ou nil, tous].
            let decisions: [[Valeur]]
        }

        /// Une valeur d'un tableau mêlé.
        enum Valeur: Decodable, Equatable {
            case entier(Int)
            case texte(String)
            case booleen(Bool)
            case nul

            init(from decoder: any Decoder) throws {
                let c = try decoder.singleValueContainer()
                if c.decodeNil() {
                    self = .nul
                } else if let b = try? c.decode(Bool.self) {
                    self = .booleen(b)
                } else if let n = try? c.decode(Int.self) {
                    self = .entier(n)
                } else {
                    self = .texte(try c.decode(String.self))
                }
            }
        }

        struct Region: Decodable {
            let n: String
            let t: String
            let date: String
            let voisin: Bool
            let r: Bool
        }

        let cas: [Cas]
        let lignes: [Releve]
        let details: [Detail]
        let ecrit: TexteEcrit
        let categories: Categories
        let region: [Region]
        let parse: Parse
        let libelles: Libelles
        let empreinte: Empreinte
        let moment: Moment
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/siddur_jour.json"))
    }

    /// Les noms de Kotlin, pour lire les vecteurs.
    private func nom(_ style: SiddurJour.Style) -> String {
        switch style {
        case .normal: return "NORMAL"
        case .duJour: return "DU_JOUR"
        case .hors: return "HORS"
        }
    }

    /// L'empreinte d'un texte dans les vecteurs : son hashCode de Java, « ∅ » pour nil.
    private func h(_ s: String?) -> String {
        guard let s else { return "\u{2205}" }
        return String(Kotlin.hashCode(s))
    }

    /// `texte` : celui des lignes, pour l'origine d'un bloc rogné (FLECTURE-08), que la signature d'Android
    /// ajoute quand le bloc montré en est une copie.
    private func signature(_ l: SiddurJour.Ligne, _ texte: SiddurTexte) -> String {
        switch l {
        case let .titre(texte, fr, en):
            return "titre|\(h(texte))|\(h(fr))|\(h(en))"
        case let .bloc(b, style, origine):
            let genre = b.consigne ? "c" : "t"
            let original = texte.sections[origine.section].blocs[origine.bloc]
            let copie = original == b ? "" : "|\(h(original.texte))"
            return "bloc|\(nom(style))|\(genre)|\(h(b.texte))|\(h(b.fr))|\(h(b.en))" + copie
        case let .etiquette(condition, libelle):
            return "etiquette|\(condition)|\(libelle)"
        case let .indice(texte, fixe):
            return "indice|\(h(texte))|\(fixe)"
        case let .renvoi(condition, cible):
            return "renvoi|\(condition)|\(cible)"
        case let .rappel(condition, libelle):
            return "rappel|\(condition)|\(libelle)"
        case let .seul(texte, consigne, note):
            return "seul|\(h(texte))|\(h(consigne))|\(note)"
        case let .replie(cle, condition, ouvert, libelle, pasAujourdhui):
            return "replie|\(cle)|\(condition)|\(ouvert)|\(libelle)|\(pasAujourdhui)"
        case let .fin(cle):
            return "fin|\(cle)"
        case let .lecture(cle, lecture, ouvert):
            return "lecture|\(cle)|\(lecture.cle)|\(ouvert)|\(h(lecture.titre.he))|\(lecture.montees.count)"
        case let .passage(m):
            return "passage|\(m.cle)|\(m.livre)|\(m.debut)|\(m.fin)|\(h(m.libelle.fr))"
        }
    }

    /// `List<Int>.hashCode()` de Kotlin.
    private func hashListe(_ l: [Int]) -> Int32 {
        var h: Int32 = 1
        for e in l { h = h &* 31 &+ Int32(truncatingIfNeeded: e) }
        return h
    }

    /// Titres, blocs (normaux, du jour, hors du jour), étiquettes, indices, renvois, cartes « seul », replis,
    /// rappels, fins de replis, lectures de la Torah, montées.
    private func genres(_ l: [SiddurJour.Ligne]) -> [Int] {
        var g = [Int](repeating: 0, count: 13)
        for x in l {
            switch x {
            case .titre: g[0] += 1
            case let .bloc(_, style, _):
                switch style {
                case .normal: g[1] += 1
                case .duJour: g[2] += 1
                case .hors: g[3] += 1
                }
            case .etiquette: g[4] += 1
            case .indice: g[5] += 1
            case .renvoi: g[6] += 1
            case .seul: g[7] += 1
            case .replie: g[8] += 1
            case .rappel: g[9] += 1
            case .fin: g[10] += 1
            case .lecture: g[11] += 1
            case .passage: g[12] += 1
            }
        }
        return g
    }

    /// Les replis ouverts d'un relevé, d'après les replis de la lecture fermée.
    private func ouverts(_ mode: String, _ fermees: [SiddurJour.Ligne]) -> Set<String> {
        let cles = cles(fermees)
        switch mode {
        case "tous": return Set(cles)
        case "alternes": return Set(cles.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element })
        default: return []
        }
    }

    /// Les conditions d'un jour comme Store.conditionsDuJour (צדיק / צדקת, « Pas de Ta'hanoun aujourd'hui »), et la nuit.
    private func conditionsDuCas(_ iso: String, _ c: Vecteurs.Cas, nuit: Bool) -> Set<String> {
        let j = CalendrierJuif.jour(.du(iso), enIsrael: c.israel, mukafChoma: c.muree)
        let avec = SiddurJour.avecAdresse(SiddurJour.avecSansTahanoun(j.conditions, c.sansTahanoun), c.adresse)
        return nuit ? avec.union([CalendrierJuif.C.nuit]) : avec
    }

    /// Les conditions de chaque cas selon CalendrierJuif d'iOS.
    private func conditionsDesCas(_ v: Vecteurs) -> [Set<String>] {
        v.cas.map { c in conditionsDuCas(c.date, c, nuit: c.nuit) }
    }

    /// Les conditions de chaque cas selon Android : les lignes se jugent à part du calendrier.
    private func conditionsLues(_ v: Vecteurs) -> [Set<String>] {
        v.cas.map { Set($0.conditions) }
    }

    private func lignesDuReleve(_ v: Vecteurs, _ jours: [Set<String>], _ d: Donnees, n: Nusah, t: String, c: Int,
                                o: String) throws -> [SiddurJour.Ligne] {
        let texte = try #require(d.siddourim[n]?.texte(t), "\(n.rawValue)/\(t)")
        let annotations = d.annotations[n]?[t] ?? []
        let cas = v.cas[c]
        let lectures = try lecturesDuCas(cas, t, n)
        func lire(_ ouverts: Set<String>) -> [SiddurJour.Ligne] {
            SiddurJour.lignes(texte, annotations, jours[c], ouverts: ouverts, nusah: n, enIsrael: cas.israel,
                              sansTahanounFinTichri: cas.finTichri, sud: cas.sud, voisin: Set(cas.conditionsVoisin),
                              lectures: lectures)
        }
        let fermees = lire([])
        return o == "aucun" ? fermees : lire(ouverts(o, fermees))
    }

    /// La lecture de la Torah d'un office (LectureTorah.lecturesOffice d'iOS), vide pour les autres textes.
    private func lecturesDuCas(_ c: Vecteurs.Cas, _ t: String, _ n: Nusah) throws -> [LectureTorah.Lecture] {
        guard LectureTorah.offices.contains(t) else { return [] }
        return try LectureTorah.lecturesOffice(try Self.lectureTorah.get(), date: .du(c.date), office: t, enIsrael: c.israel,
                                               mukafChoma: c.muree, nusah: n.rawValue)
    }

    private static let lectureTorah: Result<LectureTorah.Donnees, any Error> = Result {
        try LectureTorah.parse(String(decoding: Depot.contenu("lecture_torah.json"), as: UTF8.self))
    }

    @Test func lesConditionsDesCasSontCellesDAndroid() throws {
        let v = try vecteurs()
        let jours = conditionsDesCas(v)
        for (ci, c) in v.cas.enumerated() {
            let lues = Set(c.conditions)
            let enTrop = jours[ci].subtracting(lues).sorted(), manque = lues.subtracting(jours[ci]).sorted()
            #expect(jours[ci] == lues, "\(c.nom) : en trop \(enTrop), manque \(manque)")
            let voisin = c.voisin.map { conditionsDuCas($0, c, nuit: false) } ?? []
            #expect(voisin == Set(c.conditionsVoisin), "\(c.nom) : le jour voisin")
            for (rang, n) in Nusah.allCases.enumerated() {
                let pour = SiddurJour.conditionsPour(n, enIsrael: c.israel, jours[ci], sansTahanounFinTichri: c.finTichri, sud: c.sud)
                let attendu = Set(c.pour[rang])
                let plus = pour.subtracting(attendu).sorted(), moins = attendu.subtracting(pour).sorted()
                #expect(pour == attendu, "\(c.nom), \(n.rawValue) : en trop \(plus), manque \(moins)")
            }
        }
    }

    /// Chaque texte des trois siddourim, chaque jour, replis fermés, tous ouverts, un sur deux.
    @Test func lesLignesDeChaqueTexteSontCellesDAndroid() throws {
        let v = try vecteurs()
        let d = try donnees()
        let jours = conditionsLues(v)
        #expect(v.lignes.count == 5979)
        var ecarts: [String] = []
        for r in v.lignes {
            let n = try #require(Nusah(rawValue: r.n), "\(r.n)")
            let texte = try #require(d.siddourim[n]?.texte(r.t), "\(r.n)/\(r.t)")
            let lectures = try lecturesDuCas(v.cas[r.c], r.t, n).map { $0.cle }
            #expect(lectures == r.l, "\(r.n)/\(r.t), \(v.cas[r.c].nom) : lectures \(lectures) au lieu de \(r.l)")
            let l = try lignesDuReleve(v, jours, d, n: n, t: r.t, c: r.c, o: r.o)
            let empreinte = Kotlin.hashCode(l.map { signature($0, texte) }.joined(separator: "\n"))
            let compte = genres(l)
            let panneaux = hashListe(SiddurJour.panneaux(l).sorted())
            if empreinte != r.h || compte != r.s || panneaux != r.p {
                ecarts.append("\(r.n)/\(r.t), \(v.cas[r.c].nom), \(r.o) : \(compte) au lieu de \(r.s)")
            }
        }
        let rapport = ecarts.prefix(20).joined(separator: "\n    ")
        #expect(ecarts.isEmpty, "\(ecarts.count) relevés diffèrent, dont\n    \(rapport)")
    }

    /// Trois suites en entier : la première ligne qui diffère.
    @Test func troisLecturesLigneALigne() throws {
        let v = try vecteurs()
        let d = try donnees()
        let jours = conditionsLues(v)
        for detail in v.details {
            let n = try #require(Nusah(rawValue: detail.n), "\(detail.n)")
            let texte = try #require(d.siddourim[n]?.texte(detail.t), "\(detail.n)/\(detail.t)")
            let l = try lignesDuReleve(v, jours, d, n: n, t: detail.t, c: detail.c, o: detail.o).map { signature($0, texte) }
            #expect(l.count == detail.lignes.count, "\(detail.n)/\(detail.t) : \(l.count) lignes au lieu de \(detail.lignes.count)")
            let premiere = zip(l, detail.lignes).enumerated().first { $0.element.0 != $0.element.1 }
            if let p = premiere {
                Issue.record("\(detail.n)/\(detail.t), ligne \(p.offset) : « \(p.element.0) » au lieu de « \(p.element.1) »")
            }
        }
    }

    /// Le texte écrit à la main, chaque jeu de conditions, sept réglages, replis fermés, tous ouverts (et des
    /// clés sans repli), un sur deux.
    @Test func lesLignesDUnTexteEcritSontCellesDAndroid() throws {
        let e = try vecteurs().ecrit
        let siddur = try JSONDecoder().decode(Siddur.self, from: Data(e.siddur.utf8))
        let parTexte = try SiddurJour.parse(e.annotations, .edot)
        #expect(e.lectures.count == 315)
        for (rang, lecture) in e.lectures.enumerated() {
            let n = try #require(Nusah(rawValue: lecture.nusah), "\(lecture.nusah)")
            let texte = try #require(siddur.texte(lecture.t), "\(lecture.t)")
            let l = SiddurJour.lignes(texte, parTexte[lecture.t] ?? [], Set(e.conditions[lecture.c]), ouverts: Set(lecture.ouverts),
                                      nusah: n, enIsrael: lecture.israel, sansTahanounFinTichri: lecture.finTichri, sud: lecture.sud)
            let signatures = l.map { signature($0, texte) }
            let compte = genres(l)
            let egal = Kotlin.hashCode(signatures.joined(separator: "\n")) == lecture.h && compte == lecture.s
                && SiddurJour.panneaux(l).sorted() == lecture.panneaux
            #expect(egal, "lecture \(rang) (\(lecture.t), \(n.rawValue), conditions \(lecture.c)) : \(compte) au lieu de \(lecture.s)")
            if let attendues = lecture.lignes {
                let premiere = zip(signatures, attendues).enumerated().first { $0.element.0 != $0.element.1 }
                #expect(signatures.count == attendues.count, "lecture \(rang) : \(signatures.count) lignes au lieu de \(attendues.count)")
                if let p = premiere {
                    Issue.record("lecture \(rang), ligne \(p.offset) : « \(p.element.0) » au lieu de « \(p.element.1) »")
                }
            }
        }
    }

    private func decrit(_ a: SiddurJour.Annotation) -> String {
        let champs: [String?] = [a.sorte.rawValue.uppercased(), String(a.section), a.bloc.map { String($0) }, a.condition,
                                 a.empreinte, a.texte, a.groupe.map { String($0) }, a.racine, a.libelle, a.cible,
                                 a.consigne, a.retire, String(a.discret), a.et, a.etLibelle, String(a.fixe),
                                 a.quand, String(a.replieHors), a.libelleHors, a.par, a.office]
        return champs.map { $0 ?? "\u{2205}" }.joined(separator: "|")
    }

    @Test func parseLitLeFichierCommeAndroid() throws {
        let v = try vecteurs()
        let d = try donnees()
        for n in Nusah.allCases {
            let attendus = v.parse.fichier.filter { $0.n == n.rawValue }
            let lus = d.annotations[n] ?? [:]
            #expect(lus.count == attendus.count, "\(n.rawValue) : \(lus.count) textes au lieu de \(attendus.count)")
            for f in attendus {
                let a = try #require(lus[f.t], "\(n.rawValue)/\(f.t)")
                let parSorte = SiddurJour.Sorte.allCases.map { s in a.filter { $0.sorte == s }.count }
                let empreinte = Kotlin.hashCode(a.map { decrit($0) }.joined(separator: "\n"))
                #expect(a.count == f.nombre, "\(n.rawValue)/\(f.t)")
                #expect(parSorte == f.parSorte, "\(n.rawValue)/\(f.t) : \(parSorte) au lieu de \(f.parSorte)")
                #expect(empreinte == f.h, "\(n.rawValue)/\(f.t) : un champ diffère")
            }
        }
    }

    @Test func parseToleranceEtFautesDOrgJson() throws {
        let v = try vecteurs()
        for e in v.parse.ecrits {
            let reponses: [(Nusah, Vecteurs.Parse.Lu)] = [(Nusah.edot, e.edot), (Nusah.sefard, e.sefard), (Nusah.ashkenaz, e.ashkenaz)]
            for (n, attendu) in reponses {
                let lu = try? SiddurJour.parse(e.json, n)
                switch attendu {
                case .erreur:
                    #expect(lu == nil, "\(e.json) (\(n.rawValue)) : devait lever")
                case .textes(let textes):
                    let resultat = try #require(lu, "\(e.json) (\(n.rawValue)) : a levé")
                    #expect(resultat.count == textes.count, "\(e.json) (\(n.rawValue))")
                    for t in textes {
                        let decrites = (resultat[t.texte] ?? []).map { decrit($0) }
                        let egales = decrites.count == t.annotations.count
                            && zip(decrites, t.annotations).allSatisfy { $0.0.egalUnites($0.1) }
                        #expect(egales, "\(e.json) (\(n.rawValue)) : \(decrites) au lieu de \(t.annotations)")
                    }
                }
            }
        }
    }

    @Test func vraiLibelleEtLibelleJourSurToutesLesConditions() throws {
        let l = try vecteurs().libelles
        for paire in l.libelle {
            let attendu = try #require(paire.last), condition = try #require(paire.first)
            let lu = SiddurJour.libelle(condition)
            #expect(lu.egalUnites(attendu), "libelle(« \(condition) ») : \(lu) au lieu de \(attendu)")
        }
        let jourReel = Set(l.jourReel)
        for ligne in l.vrai {
            let c = ligne.c
            let r = [SiddurJour.vrai(c, []), SiddurJour.vrai(c, [sansNegation(c)]), SiddurJour.vrai(c, [c]), SiddurJour.vrai(c, jourReel)]
            #expect(r == ligne.r, "vrai(« \(c) ») : \(r) au lieu de \(ligne.r)")
        }
        let ensembles = l.ensemblesHallel.map { Set($0) }
        for ligne in l.libelleJour {
            let r = Nusah.allCases.map { SiddurJour.libelleJour(nil, ligne.c, $0, ensembles[ligne.e]) }
            #expect(r == ligne.r, "libelleJour(« \(ligne.c) », ensemble \(ligne.e)) : \(r) au lieu de \(ligne.r)")
        }
        for ligne in l.libelleJourPropre {
            let r = Nusah.allCases.map { SiddurJour.libelleJour(ligne.propre, ligne.c, $0, ensembles[2]) }
            #expect(r == ligne.r, "libelleJour(« \(ligne.propre) », « \(ligne.c) ») : \(r) au lieu de \(ligne.r)")
        }
    }

    @Test func empreinteDesTextesEcritsEtDeChaqueBloc() throws {
        let v = try vecteurs()
        for paire in v.empreinte.textes {
            let texte = try #require(paire.first), attendu = try #require(paire.last)
            let lu = SiddurJour.empreinte(texte)
            let egal = lu.egalUnites(attendu)
            let codesTexte = texte.unicodeScalars.map { String($0.value, radix: 16) }
            let codesLu = lu.unicodeScalars.map { String($0.value, radix: 16) }
            let codesAttendus = attendu.unicodeScalars.map { String($0.value, radix: 16) }
            #expect(egal, "empreinte(\(codesTexte)) : \(codesLu) au lieu de \(codesAttendus)")
        }
        let d = try donnees()
        for s in v.empreinte.siddourim {
            let n = try #require(Nusah(rawValue: s.n), "\(s.n)")
            let texte = try #require(d.siddourim[n]?.texte(s.t), "\(s.n)/\(s.t)")
            var vus: [String] = []
            for section in texte.sections {
                vus.append(section.titre)
                for b in section.blocs { vus.append(b.texte) }
            }
            let empreinte = Kotlin.hashCode(vus.map { SiddurJour.empreinte($0) }.joined(separator: "\n"))
            #expect(vus.count == s.nombre, "\(s.n)/\(s.t) : \(vus.count) textes au lieu de \(s.nombre)")
            #expect(empreinte == s.h, "\(s.n)/\(s.t) : une empreinte diffère")
        }
    }

    // MARK: Les deux catégories du 26/11, sur un texte écrit (VecteursSiddurJour.categories)

    /// Les lectures de la Torah du texte écrit, refaites par LectureTorah d'iOS sur le vrai fichier des lectures.
    private func lecturesCategories() throws -> [[LectureTorah.Lecture]] {
        let d = try Self.lectureTorah.get()
        let jeudi = try LectureTorah.lectures(d, date: .du("2026-11-26"), office: LectureTorah.chaharit, enIsrael: false)
        let rochHodech = try LectureTorah.lectures(d, date: .du("2026-11-10"), office: LectureTorah.chaharit, enIsrael: false,
                                                   nusah: "ashkenaz")
        return [[], jeudi, jeudi + rochHodech]
    }

    @Test func lesDeuxCategoriesSurUnTexteEcritCommeAndroid() throws {
        let c = try vecteurs().categories
        let siddur = try JSONDecoder().decode(Siddur.self, from: Data(c.siddur.utf8))
        let texte = try #require(siddur.texte("cat"))
        let annotations = try #require(try SiddurJour.parse(c.annotations, .edot)["cat"])
        let lectures = try lecturesCategories()
        let cles = lectures.map { $0.map { $0.cle } }
        #expect(cles == c.lectures)
        let reglages: [(Nusah, Bool)] = [(.edot, false), (.sefard, true), (.ashkenaz, false)]
        #expect(c.releves.count == 324)
        for r in c.releves {
            let (n, israel) = reglages[r.r]
            let l = SiddurJour.lignes(texte, annotations, Set(c.conditions[r.c]), ouverts: Set(r.ouverts), nusah: n,
                                      enIsrael: israel, voisin: Set(c.voisins[r.v]), lectures: lectures[r.l])
            let signatures = l.map { signature($0, texte) }
            let compte = genres(l)
            let panneaux = SiddurJour.panneaux(l).sorted()
            let egal = Kotlin.hashCode(signatures.joined(separator: "\n")) == r.h && compte == r.s && panneaux == r.panneaux
            #expect(egal, "jour \(r.c), voisin \(r.v), lectures \(r.l), \(n.rawValue), \(r.o) : \(compte) au lieu de \(r.s)")
            if let attendues = r.lignes {
                #expect(signatures.count == attendues.count, "jour \(r.c), \(r.o) : \(signatures.count) lignes au lieu de \(attendues.count)")
                if let p = zip(signatures, attendues).enumerated().first(where: { $0.element.0 != $0.element.1 }) {
                    Issue.record("jour \(r.c), \(r.o), ligne \(p.offset) : « \(p.element.0) » au lieu de « \(p.element.1) »")
                }
            }
        }
    }

    @Test func decisionSurChaqueAnnotationCommeAndroid() throws {
        let c = try vecteurs().categories
        let annotations = try #require(try SiddurJour.parse(c.annotations, .edot)["cat"])
        let parPlace = annotations.filter { $0.sorte == .bloc || $0.sorte == .section }
        #expect(c.decisions.count == parPlace.count * c.conditions.count * c.voisins.count)
        var k = 0
        for a in parPlace {
            for ci in c.conditions.indices {
                for vi in c.voisins.indices {
                    let d = SiddurJour.decision(a, racine: a.racine ?? a.condition, Set(c.conditions[ci]), voisin: Set(c.voisins[vi]))
                    let etat: String
                    switch d.etat {
                    case .duJour: etat = "DU_JOUR"
                    case .ordinaire: etat = "ORDINAIRE"
                    case .replie: etat = "REPLIE"
                    case .retire: etat = "RETIRE"
                    }
                    let rendu: [Vecteurs.Valeur] = [
                        .entier(a.section), a.bloc.map { .entier($0) } ?? .nul, .entier(ci), .entier(vi), .texte(etat),
                        .booleen(d.pasAujourdhui), d.libelle.map { .texte($0) } ?? .nul, .booleen(d.tous),
                    ]
                    #expect(rendu == c.decisions[k], "§\(a.section)/\(a.bloc.map { String($0) } ?? "∅"), jour \(ci), voisin \(vi)")
                    k += 1
                }
            }
        }
    }

    /// dependDeLaRegion (26/11, Q7) sur les vrais textes : le jour voisin au Birkat haMazon, la lecture aux offices.
    @Test func leTexteDependDeLaRegionCommeSurAndroid() throws {
        let v = try vecteurs()
        let d = try donnees()
        let lectures = try Self.lectureTorah.get()
        #expect(v.region.count == 84)
        for r in v.region {
            let n = try #require(Nusah(rawValue: r.n))
            let texte = try #require(d.siddourim[n]?.texte(r.t))
            let annotations = try #require(d.annotations[n]?[r.t])
            let date = JourCivil.du(r.date)
            func c(_ il: Bool) -> Set<String> { CalendrierJuif.jour(date, enIsrael: il).conditions }
            func voisin(_ il: Bool) -> Set<String> { r.voisin ? CalendrierJuif.jour(date.plus(jours: 1), enIsrael: il).conditions : [] }
            func lu(_ il: Bool) throws -> [LectureTorah.Lecture] {
                guard LectureTorah.offices.contains(r.t) else { return [] }
                return try LectureTorah.lecturesOffice(lectures, date: date, office: r.t, enIsrael: il, nusah: r.n)
            }
            let depend = SiddurJour.dependDeLaRegion(texte, annotations, israel: c(true), diaspora: c(false), nusah: n,
                                                     voisinIsrael: voisin(true), voisinDiaspora: voisin(false),
                                                     lecturesIsrael: try lu(true), lecturesDiaspora: try lu(false))
            #expect(depend == r.r, "\(r.n)/\(r.t) \(r.date)")
        }
    }

    // MARK: SiddurMoment.illustration (Siddur.kt)

    @Test func lIllustrationDeChaqueTexte() throws {
        let v = try vecteurs()
        for paire in v.moment.illustration {
            let id = try #require(paire.first), attendu = try #require(paire.last)
            let lu = SiddurMoment.illustration(id)
            #expect(lu == attendu, "« \(id) »")
        }
    }
}
