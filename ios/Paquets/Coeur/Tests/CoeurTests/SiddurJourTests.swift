import Foundation
import Testing
@testable import Coeur

/// SiddurJourTest d'Android, porté sur les contenus exportés (siddur_annotations.json et les trois
/// siddourim) : les annotations désignent encore leur bloc, leurs conditions existent et chaque
/// libellé est traduit (dans le catalogue d'iOS, pour les strings.xml d'Android), les ajouts
/// principaux sont annotés, et les lignes du jour (renvois, étiquettes, replis, styles) sont celles
/// d'Android. Rien n'y reste à Android. Puis les vecteurs de la JVM (siddur_jour.json) : parse, les
/// lignes de chaque texte sur une trentaine de jours et celles d'un texte écrit à la main, vrai, libelle,
/// libelleJour, empreinte, et l'illustration de SiddurMoment.
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
    }

    private func replis(_ l: [SiddurJour.Ligne]) -> [Repli] {
        var r: [Repli] = []
        for x in l {
            if case let .replie(cle, condition, ouvert, libelle) = x {
                r.append(Repli(cle: cle, condition: condition, ouvert: ouvert, libelle: libelle))
            }
        }
        return r
    }

    private func blocs(_ l: [SiddurJour.Ligne]) -> [(bloc: SiddurBloc, style: SiddurJour.Style)] {
        var r: [(bloc: SiddurBloc, style: SiddurJour.Style)] = []
        for x in l {
            if case let .bloc(b, style) = x { r.append((bloc: b, style: style)) }
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

    @Test func rochHodechYaaleVeyavoEnEvidenceAlHanissimRepliePuisOuvert() throws {
        let d = try donnees()
        let texte = try #require(d.siddourim[.edot]?.texte("chaharit"))
        let annotations = try #require(d.annotations[.edot]?["chaharit"])
        let rc = conditions("2026-10-12")
        let fermees = SiddurJour.lignes(texte, annotations, rc)
        let etiquette = fermees.contains(.etiquette(condition: "yaale_veyavo", libelle: "ajout_yaale_veyavo"))
        #expect(etiquette)
        let alHanissimReplie = replis(fermees).contains { $0.condition == "al_hanissim" && !$0.ouvert }
        #expect(alHanissimReplie)
        // Dans Ya'alé véyavo du jour, la variante de Pessa'h reste lisible, estompée.
        let pessah = blocs(fermees).first { SiddurJour.empreinte($0.bloc.texte).contientUnites("חג המצות הזה") }
        let style = try #require(pessah).style
        #expect(style == .hors)
        // Le repli d'Al hanissim, une fois ouvert, montre ses blocs.
        let premier = replis(fermees).first { $0.condition == "al_hanissim" }
        let cle = try #require(premier).cle
        let ouvert = SiddurJour.lignes(texte, annotations, rc, ouverts: [cle])
        let plus = ouvert.count > fermees.count
        #expect(plus)
        // Aucun bloc ne se perd : replié, il revient à l'ouverture de tous les groupes.
        let tous = Set(replis(fermees).map { $0.cle })
        let blocsTous = blocs(SiddurJour.lignes(texte, annotations, rc, ouverts: tous)).count
        let total = texte.sections.reduce(0) { $0 + $1.blocs.count }
        #expect(blocsTous == total)
    }

    @Test func anenouLOfficiantEtLeParticulierSelonLeNusah() throws {
        let jeune = conditions("2026-12-20") // 10 Tévèt
        let deux: Set<String> = ["ajout_anenou_officiant", "ajout_anenou_particulier"]
        // Edot : l'officiant et le particulier, à Cha'harit comme à Min'ha.
        let edotChaharit = deux.isSubset(of: etiquettes(try lignes(.edot, "chaharit", jeune)))
        #expect(edotChaharit)
        let edotMinha = deux.isSubset(of: etiquettes(try lignes(.edot, "minha", jeune)))
        #expect(edotMinha)
        // Ashkenaz et Sfard : à Cha'harit, l'officiant seul ; à Min'ha, les deux.
        for n in [Nusah.ashkenaz, .sefard] {
            let chaharit = etiquettes(try lignes(n, "chaharit", jeune)).filter { $0.commenceParUnites("ajout_anenou") }
            #expect(chaharit == ["ajout_anenou_officiant"], "\(n.rawValue)")
            let minha = deux.isSubset(of: etiquettes(try lignes(n, "minha", jeune)))
            #expect(minha, "\(n.rawValue)")
        }
        // Un jour ordinaire, tous les Anénou sont repliés.
        let ordinaire = conditions("2026-12-21")
        let replies = replis(try lignes(.sefard, "minha", ordinaire)).map { $0.libelle }
        let tousReplies = deux.isSubset(of: replies)
        #expect(tousReplies)
    }

    @Test func ashkenazHorsDIsraelMoridHatalReplieLEte() throws {
        let ete = conditions("2027-06-01")
        func etat(_ n: Nusah, _ israel: Bool) throws -> [SiddurJour.Ligne] { try lignes(n, "chaharit", ete, enIsrael: israel) }
        let replie = replis(try etat(.ashkenaz, false)).contains { $0.condition == "morid_hatal" }
        #expect(replie)
        let etiquette = SiddurJour.Ligne.etiquette(condition: "morid_hatal", libelle: "ajout_morid_hatal")
        let israel = try etat(.ashkenaz, true).contains(etiquette)
        #expect(israel)
        let sefard = try etat(.sefard, false).contains(etiquette)
        #expect(sefard)
    }

    /// Avinou malkénou (14/10) : replié un jour ordinaire, ouvert le 10 Tévèt et pendant les dix jours.
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
            let replie = replis(try duJour("2026-12-21")).contains { $0.condition == "avinou_malkenou" }
            #expect(replie, "\(n.rawValue)")
            let etiquette = SiddurJour.Ligne.etiquette(condition: "avinou_malkenou", libelle: "ajout_avinou_malkenou")
            let present = try duJour("2026-12-20").contains(etiquette)
            #expect(present, "\(n.rawValue)")
        }
    }

    /// La lecture de la Torah (15/10) : ouverte les jours de lecture, repliée un mardi ordinaire.
    @Test func kriatHatorahReplieeLesJoursSansLecture() throws {
        func c(_ d: String) -> Set<String> { conditions(d, israel: true) }
        for d in ["2026-10-19", "2026-10-15", "2026-10-17", "2026-11-11", "2026-12-20", "2026-09-29"] {
            #expect(c(d).contains(CalendrierJuif.C.kriatHatorah), "\(d)")
        }
        for d in ["2026-10-20", "2026-10-21", "2026-10-23"] { #expect(!c(d).contains(CalendrierJuif.C.kriatHatorah), "\(d)") }
        for n in Nusah.allCases {
            func duJour(_ d: String) throws -> [SiddurJour.Ligne] { try lignes(n, "chaharit", c(d), enIsrael: true) }
            let replie = replis(try duJour("2026-10-20")).contains { $0.condition == "kriat_hatorah" }
            #expect(replie, "\(n.rawValue)")
            let etiquette = SiddurJour.Ligne.etiquette(condition: "kriat_hatorah", libelle: "ajout_kriat_hatorah")
            let present = try duJour("2026-10-19").contains(etiquette)
            #expect(present, "\(n.rawValue)")
            // « אל ארך אפים » : dit un lundi ordinaire, estompé à Pourim (23/03/2027) et à 'Hanouka (07/12/2026), sans Ta'hanoun.
            func elArekh(_ d: String) throws -> SiddurJour.Style {
                let trouve = blocs(try duJour(d)).first { SiddurJour.empreinte($0.bloc.texte).commenceParUnites("אל ארך אפים") }
                return try #require(trouve, "\(n.rawValue) \(d)").style
            }
            let lundi = try elArekh("2026-10-19")
            #expect(lundi == .duJour, "\(n.rawValue)")
            let pourim = try elArekh("2027-03-23")
            #expect(pourim == .hors, "\(n.rawValue)")
            let hanouka = try elArekh("2026-12-07")
            #expect(hanouka == .hors, "\(n.rawValue)")
        }
        // Les « יהי רצון » (Sfard, Ashkenaz) : lundi et jeudi avec Ta'hanoun seulement ; pas à Roch 'Hodech (11/11/2026, mercredi).
        for n in [Nusah.sefard, .ashkenaz] {
            func yehiRatson(_ d: String) throws -> SiddurJour.Style {
                let l = try lignes(n, "chaharit", c(d), enIsrael: true)
                let trouve = blocs(l).first { SiddurJour.empreinte($0.bloc.texte).commenceParUnites("יהי רצון מלפני אבינו") }
                return try #require(trouve, "\(n.rawValue) \(d)").style
            }
            let lundi = try yehiRatson("2026-10-19")
            #expect(lundi == .duJour, "\(n.rawValue)")
            let rochHodech = try yehiRatson("2026-11-11")
            #expect(rochHodech == .hors, "\(n.rawValue)")
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
            let conditions: [String]
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

        let cas: [Cas]
        let lignes: [Releve]
        let details: [Detail]
        let ecrit: TexteEcrit
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

    private func signature(_ l: SiddurJour.Ligne) -> String {
        switch l {
        case let .titre(texte, fr, en):
            return "titre|\(h(texte))|\(h(fr))|\(h(en))"
        case let .bloc(b, style):
            let genre = b.consigne ? "c" : "t"
            return "bloc|\(nom(style))|\(genre)|\(h(b.texte))|\(h(b.fr))|\(h(b.en))"
        case let .etiquette(condition, libelle):
            return "etiquette|\(condition)|\(libelle)"
        case let .indice(texte):
            return "indice|\(h(texte))"
        case let .renvoi(condition, cible):
            return "renvoi|\(condition)|\(cible)"
        case let .seul(texte, consigne):
            return "seul|\(h(texte))|\(h(consigne))"
        case let .replie(cle, condition, ouvert, libelle):
            let etat = ouvert ? "true" : "false"
            return "replie|\(cle)|\(condition)|\(etat)|\(libelle)"
        }
    }

    /// Titres, blocs (normaux, du jour, hors du jour), étiquettes, indices, renvois, cartes « seul », replis.
    private func genres(_ l: [SiddurJour.Ligne]) -> [Int] {
        var g = [Int](repeating: 0, count: 9)
        for x in l {
            switch x {
            case .titre: g[0] += 1
            case let .bloc(_, style):
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
            }
        }
        return g
    }

    /// Les replis ouverts d'un relevé, d'après les replis de la lecture fermée.
    private func ouverts(_ mode: String, _ fermees: [SiddurJour.Ligne]) -> Set<String> {
        let cles = replis(fermees).map { $0.cle }
        switch mode {
        case "tous": return Set(cles)
        case "alternes": return Set(cles.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element })
        default: return []
        }
    }

    /// Les conditions de chaque cas selon CalendrierJuif d'iOS.
    private func conditionsDesCas(_ v: Vecteurs) -> [Set<String>] {
        v.cas.map { c in CalendrierJuif.jour(.du(c.date), enIsrael: c.israel, mukafChoma: c.muree).conditions }
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
        func lire(_ ouverts: Set<String>) -> [SiddurJour.Ligne] {
            SiddurJour.lignes(texte, annotations, jours[c], ouverts: ouverts, nusah: n, enIsrael: cas.israel,
                              sansTahanounFinTichri: cas.finTichri, sud: cas.sud)
        }
        let fermees = lire([])
        return o == "aucun" ? fermees : lire(ouverts(o, fermees))
    }

    @Test func lesConditionsDesCasSontCellesDAndroid() throws {
        let v = try vecteurs()
        let jours = conditionsDesCas(v)
        for (ci, c) in v.cas.enumerated() {
            let lues = Set(c.conditions)
            let enTrop = jours[ci].subtracting(lues).sorted(), manque = lues.subtracting(jours[ci]).sorted()
            #expect(jours[ci] == lues, "\(c.nom) : en trop \(enTrop), manque \(manque)")
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
        #expect(v.lignes.count == 1456)
        var ecarts: [String] = []
        for r in v.lignes {
            let n = try #require(Nusah(rawValue: r.n), "\(r.n)")
            let l = try lignesDuReleve(v, jours, d, n: n, t: r.t, c: r.c, o: r.o)
            let empreinte = Kotlin.hashCode(l.map { signature($0) }.joined(separator: "\n"))
            let compte = genres(l)
            if empreinte != r.h || compte != r.s {
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
            let l = try lignesDuReleve(v, jours, d, n: n, t: detail.t, c: detail.c, o: detail.o).map { signature($0) }
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
        #expect(e.lectures.count == 150)
        for (rang, lecture) in e.lectures.enumerated() {
            let n = try #require(Nusah(rawValue: lecture.nusah), "\(lecture.nusah)")
            let texte = try #require(siddur.texte(lecture.t), "\(lecture.t)")
            let l = SiddurJour.lignes(texte, parTexte[lecture.t] ?? [], Set(e.conditions[lecture.c]), ouverts: Set(lecture.ouverts),
                                      nusah: n, enIsrael: lecture.israel, sansTahanounFinTichri: lecture.finTichri, sud: lecture.sud)
            let signatures = l.map { signature($0) }
            let compte = genres(l)
            let egal = Kotlin.hashCode(signatures.joined(separator: "\n")) == lecture.h && compte == lecture.s
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
                                 a.consigne, a.retire]
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
