import Foundation
import Testing
@testable import Coeur

/// SiddurJourTest d'Android, porté : les annotations du siddour désignent encore le bon bloc, leurs
/// conditions existent, chaque libellé est traduit (dans Localizable.xcstrings au lieu des strings.xml),
/// les ajouts principaux sont là dans chaque nusah, et la lecture du jour suit le calendrier. Puis la
/// lecture de chaque texte annoté, tous les jours de conditions neuves de 5787, devant la JVM
/// (Tests/Vecteurs/siddour_jour.json, tools/vecteurs_ios/VecteursSiddourJour.kt).
@Suite("Siddour du jour")
struct SiddurJourTests {

    private typealias C = CalendrierJuif.C
    private typealias L = SiddurJour.Ligne

    private static let charges: Result<[(Nusah, Siddur, SiddurJour.Annotations)], any Error> = Result {
        let json = try Depot.texte("siddur_annotations.json")
        return try Nusah.allCases.map { n in
            (n, try JSONDecoder().decode(Siddur.self, from: Depot.contenu(n.fichier)), try SiddurJour.parse(json, nusah: n))
        }
    }

    private func siddur(_ n: Nusah) throws -> Siddur {
        try #require(try Self.charges.get().first { $0.0 == n }?.1)
    }

    private func annotations(_ n: Nusah) throws -> SiddurJour.Annotations {
        try #require(try Self.charges.get().first { $0.0 == n }?.2)
    }

    private func conditions(_ iso: String, israel: Bool = false) -> Set<String> {
        CalendrierJuif.jour(.du(iso), enIsrael: israel).conditions
    }

    /// Les lignes d'un texte d'un nusah, le jour de `conditions`.
    private func lignes(_ n: Nusah, _ id: String, _ conditions: Set<String>, ouverts: Set<String> = [],
                        nusah: Nusah? = nil, enIsrael: Bool = false) throws -> [L] {
        let texte = try #require(try siddur(n).texte(id))
        let a = try #require(try annotations(n)[id])
        return SiddurJour.lignes(texte, a, conditions, ouverts: ouverts, nusah: nusah ?? n, enIsrael: enIsrael)
    }

    private func replie(_ lignes: [L], condition: String) -> Bool {
        lignes.contains { if case .replie(_, let c, let ouvert, _) = $0 { return c == condition && !ouvert } else { return false } }
    }

    private func blocs(_ lignes: [L]) -> [(SiddurBloc, SiddurJour.Style)] {
        lignes.compactMap { if case .bloc(let b, let s) = $0 { return (b, s) } else { return nil } }
    }

    private func etiquettes(_ lignes: [L]) -> [String] {
        lignes.compactMap { if case .etiquette(_, let l) = $0 { return l } else { return nil } }
    }

    @Test func chaqueAnnotationDesigneEncoreSonBloc() throws {
        for n in Nusah.allCases {
            let recueil = try siddur(n), toutes = try annotations(n)
            for id in toutes.textes {
                let texte = try #require(recueil.texte(id), "\(n.rawValue)/\(id)")
                for a in toutes[id] ?? [] {
                    try #require(texte.sections.indices.contains(a.section), "\(n.rawValue)/\(id) §\(a.section)")
                    let section = texte.sections[a.section]
                    let vu: String
                    if let b = a.bloc {
                        try #require(section.blocs.indices.contains(b), "\(n.rawValue)/\(id) §\(a.section)/\(b)")
                        vu = SiddurJour.empreinte(section.blocs[b].texte)
                    } else {
                        vu = SiddurJour.empreinte(section.titre)
                    }
                    #expect(a.empreinte.egalUnites(vu), "\(n.rawValue)/\(id) §\(a.section)/\(a.bloc.map(String.init) ?? "-")")
                }
            }
        }
    }

    @Test func lesConditionsExistentEtChaqueLibelleEstTraduit() throws {
        let connues = Set(C.toutes + C.derivees)
        let catalogue = try Catalogue.lire()
        let langues = Catalogue.langues.map { Set(catalogue.simples($0).keys) }
        for n in Nusah.allCases {
            let toutes = try annotations(n)
            for a in toutes.textes.flatMap({ toutes[$0] ?? [] }) {
                let cle = a.condition.hasPrefix("!") ? String(a.condition.dropFirst()) : a.condition
                #expect(connues.contains(cle), "\(n.rawValue) : \(a.condition)")
                let libelle = SiddurJour.libelle(a.condition)
                for cles in langues { #expect(cles.contains(libelle), "\(n.rawValue) : \(libelle)") }
                if a.sorte == .bloc { #expect(a.groupe != nil && a.racine != nil, "\(n.rawValue) : \(a.empreinte)") }
                if let l = a.libelle {
                    for cles in langues { #expect(cles.contains(l), "\(n.rawValue) : \(l)") }
                }
            }
        }
    }

    @Test func lesAjoutsPrincipauxSontAnnotesDansLesTroisNusah() throws {
        for n in Nusah.allCases {
            let toutes = try annotations(n)
            func conditionsDe(_ id: String) -> Set<String> { Set((toutes[id] ?? []).map(\.condition)) }
            let chaharit = conditionsDe("chaharit")
            for c in ["yaale_veyavo", "al_hanissim", "hanouka", "pourim", "tal_oumatar", "berakha", "asseret_yemei_techouva"] {
                #expect(chaharit.contains(c), "\(n.rawValue) : \(c)")
            }
            // Été / hiver dans les trois offices (14/10 : l'Arvit ashkénaze n'était pas marqué).
            for o in ["chaharit", "minha", "arvit"] {
                let ici = conditionsDe(o)
                for c in ["tal_oumatar", "berakha"] { #expect(ici.contains(c), "\(n.rawValue) \(o) : \(c)") }
            }
            let repas = conditionsDe("birkat_hamazon")
            for c in ["yaale_veyavo", "al_hanissim", "chabbat"] { #expect(repas.contains(c), "\(n.rawValue) repas : \(c)") }
        }
    }

    /// Roch 'Hodech (12/10) : dans Cha'harit, « Aujourd'hui · Hallel › » puis « Moussaf › » ; un jour ordinaire, rien.
    @Test func rochHodechChaharitRenvoieAuHallelPuisAuMoussaf() throws {
        let rc = conditions("2026-10-12"), ordinaire = conditions("2026-10-14")
        for n in Nusah.allCases {
            let cibles = try lignes(n, "chaharit", rc).compactMap { l -> String? in
                if case .renvoi(_, let cible) = l { return cible } else { return nil }
            }
            #expect(cibles == ["hallel", "moussaf_rosh_hodech"], "\(n.rawValue)")
            for cible in cibles { #expect(try siddur(n).texte(cible) != nil, "\(n.rawValue) : \(cible)") }
            let aucun = try lignes(n, "chaharit", ordinaire).allSatisfy { if case .renvoi = $0 { return false } else { return true } }
            #expect(aucun, "\(n.rawValue)")
        }
    }

    @Test func rochHodechYaaleVeyavoEnEvidenceAlHanissimRepliePuisOuvert() throws {
        let texte = try #require(try siddur(.edot).texte("chaharit"))
        let a = try #require(try annotations(.edot)["chaharit"])
        let rc = conditions("2026-10-12")
        let lignes = SiddurJour.lignes(texte, a, rc)
        #expect(lignes.contains(.etiquette(condition: "yaale_veyavo", libelle: "ajout_yaale_veyavo")))
        #expect(replie(lignes, condition: "al_hanissim"))
        // Dans Ya'alé véyavo du jour, la variante de Pessa'h reste lisible, estompée.
        let trouve = blocs(lignes).first { SiddurJour.empreinte($0.0.texte).contientUnites("חג המצות הזה") }
        let pessah = try #require(trouve)
        #expect(pessah.1 == .hors)
        // Le repli d'Al hanissim, une fois ouvert, montre ses blocs.
        let cles = lignes.compactMap { l -> String? in
            if case .replie(let cle, "al_hanissim", _, _) = l { return cle } else { return nil }
        }
        let cle = try #require(cles.first)
        let ouvert = SiddurJour.lignes(texte, a, rc, ouverts: [cle])
        #expect(ouvert.count > lignes.count)
        // Aucun bloc ne se perd : replié, il revient à l'ouverture de tous les groupes.
        let tous = Set(lignes.compactMap { l -> String? in if case .replie(let cle, _, _, _) = l { return cle } else { return nil } })
        let blocsTous = blocs(SiddurJour.lignes(texte, a, rc, ouverts: tous)).count
        let attendus = texte.sections.reduce(0) { $0 + $1.blocs.count }
        #expect(blocsTous == attendus)
    }

    @Test func anenouLOfficiantEtLeParticulierSelonLeNusah() throws {
        let jeune = conditions("2026-12-20") // 10 Tevet
        func etiquettesDu(_ n: Nusah, _ id: String) throws -> [String] { etiquettes(try lignes(n, id, jeune)) }
        let deux = ["ajout_anenou_officiant", "ajout_anenou_particulier"]
        // Edot : l'officiant et le particulier, à Cha'harit comme à Min'ha.
        #expect(Set(try etiquettesDu(.edot, "chaharit")).isSuperset(of: deux))
        #expect(Set(try etiquettesDu(.edot, "minha")).isSuperset(of: deux))
        // Ashkenaz et Sfard : à Cha'harit, l'officiant seul ; à Min'ha, les deux.
        for n in [Nusah.ashkenaz, .sefard] {
            let anenou = try etiquettesDu(n, "chaharit").filter { $0.hasPrefix("ajout_anenou") }
            #expect(anenou == ["ajout_anenou_officiant"], "\(n.rawValue)")
            #expect(Set(try etiquettesDu(n, "minha")).isSuperset(of: deux), "\(n.rawValue)")
        }
        // Un jour ordinaire, tous les Anénou sont repliés.
        let replis = try lignes(.sefard, "minha", conditions("2026-12-21")).compactMap { l -> String? in
            if case .replie(_, _, _, let libelle) = l { return libelle } else { return nil }
        }
        #expect(Set(replis).isSuperset(of: deux))
    }

    @Test func ashkenazHorsDIsraelMoridHatalReplieLEte() throws {
        let ete = conditions("2027-06-01")
        func etat(_ n: Nusah, _ israel: Bool) throws -> [L] { try lignes(n, "chaharit", ete, enIsrael: israel) }
        let etiquette = L.etiquette(condition: "morid_hatal", libelle: "ajout_morid_hatal")
        #expect(replie(try etat(.ashkenaz, false), condition: "morid_hatal"))
        #expect(try etat(.ashkenaz, true).contains(etiquette))
        #expect(try etat(.sefard, false).contains(etiquette))
    }

    /// Avinou malkénou (14/10) : replié un jour ordinaire, ouvert le 10 Tévèt et pendant les dix jours.
    @Test func avinouMalkenouJeunesEtDixJoursSeulement() throws {
        func am(_ d: String) -> Bool {
            SiddurJour.conditionsPour(.ashkenaz, enIsrael: true, conditions(d, israel: true)).contains(C.avinouMalkenou)
        }
        for d in ["2026-12-20", "2026-09-15", "2026-09-13", "2026-09-14"] { #expect(am(d), "\(d)") }
        for d in ["2026-12-21", "2026-09-12", "2026-09-19", "2026-09-20", "2027-08-12"] { #expect(!am(d), "\(d)") }
        for n in [Nusah.ashkenaz, .sefard] {
            func du(_ d: String) throws -> [L] { try lignes(n, "chaharit", conditions(d, israel: true), enIsrael: true) }
            #expect(replie(try du("2026-12-21"), condition: "avinou_malkenou"), "\(n.rawValue)")
            #expect(try du("2026-12-20").contains(.etiquette(condition: "avinou_malkenou", libelle: "ajout_avinou_malkenou")), "\(n.rawValue)")
        }
    }

    /// La lecture de la Torah (15/10) : ouverte les jours de lecture, repliée un mardi ordinaire.
    @Test func kriatHatorahRepileeLesJoursSansLecture() throws {
        func c(_ d: String) -> Set<String> { conditions(d, israel: true) }
        for d in ["2026-10-19", "2026-10-15", "2026-10-17", "2026-11-11", "2026-12-20", "2026-09-29"] {
            #expect(c(d).contains(C.kriatHatorah), "\(d)")
        }
        for d in ["2026-10-20", "2026-10-21", "2026-10-23"] { #expect(!c(d).contains(C.kriatHatorah), "\(d)") }
        for n in Nusah.allCases {
            func du(_ d: String) throws -> [L] { try lignes(n, "chaharit", c(d), enIsrael: true) }
            #expect(replie(try du("2026-10-20"), condition: "kriat_hatorah"), "\(n.rawValue)")
            #expect(try du("2026-10-19").contains(.etiquette(condition: "kriat_hatorah", libelle: "ajout_kriat_hatorah")), "\(n.rawValue)")
            // « אל ארך אפים » : dit un lundi ordinaire, estompé à Pourim (23/03/2027) et à 'Hanouka (07/12/2026), sans Ta'hanoun.
            func elArekh(_ d: String) throws -> SiddurJour.Style {
                let trouve = blocs(try du(d)).first { SiddurJour.empreinte($0.0.texte).commenceParUnites("אל ארך אפים") }
                return try #require(trouve).1
            }
            #expect(try elArekh("2026-10-19") == .duJour, "\(n.rawValue)")
            #expect(try elArekh("2027-03-23") == .hors, "\(n.rawValue)")
            #expect(try elArekh("2026-12-07") == .hors, "\(n.rawValue)")
        }
        // Les « יהי רצון » (Sfard, Ashkenaz) : lundi et jeudi avec Ta'hanoun seulement ; pas à Roch 'Hodech (11/11/2026, mercredi).
        for n in [Nusah.sefard, .ashkenaz] {
            func yehiRatson(_ d: String) throws -> SiddurJour.Style {
                let trouve = blocs(try lignes(n, "chaharit", c(d), enIsrael: true))
                    .first { SiddurJour.empreinte($0.0.texte).commenceParUnites("יהי רצון מלפני אבינו") }
                return try #require(trouve).1
            }
            #expect(try yehiRatson("2026-10-19") == .duJour, "\(n.rawValue)")
            #expect(try yehiRatson("2026-11-11") == .hors, "\(n.rawValue)")
        }
    }

    @Test func uneConditionNieeSAppliqueQuandLaCleManque() {
        #expect(SiddurJour.vrai("!tahanoun_minha", ["chabbat"]))
        #expect(!SiddurJour.vrai("!tahanoun_minha", ["tahanoun_minha"]))
        #expect(SiddurJour.vrai("roch_hodech", ["roch_hodech"]))
        #expect(SiddurJour.libelle("!tahanoun_chaharit") == "ajout_sans_tahanoun")
        #expect(SiddurJour.libelle("kippour") == "fete_yom_kippour")
    }

    // MARK: Devant la JVM

    /// Une ligne en quelques signes, comme VecteursSiddourJour.code : un texte par sa longueur en unités UTF-16.
    private static func code(_ l: L) -> String {
        switch l {
        case .titre: "T"
        case .bloc(let b, let style): "B\(style.rawValue):\(b.texte.utf16.count)"
        case .etiquette(let condition, let libelle): "E:\(condition):\(libelle)"
        case .indice(let texte): "I:\(texte.utf16.count)"
        case .renvoi(let condition, let cible): "R:\(condition):\(cible)"
        case .seul(let texte, let consigne): "S:\(texte.utf16.count):\(consigne.map { $0.utf16.count } ?? -1)"
        case .replie(let cle, let condition, let ouvert, let libelle): "P:\(cle):\(condition):\(ouvert ? 1 : 0):\(libelle)"
        }
    }

    /// Chaque jour de conditions neuves, chaque texte annoté, replié puis tout ouvert : mêmes lignes que sur
    /// Android. Un nusah par cas, pour que les trois tournent ensemble.
    @Test(arguments: Nusah.allCases)
    func lesLecturesDesVecteursSontRenduesALIdentique(_ n: Nusah) throws {
        let recueil = try siddur(n), toutes = try annotations(n)
        let cas = try Depot.vecteurs("siddour_jour.json").textes("cas").map { $0.components(separatedBy: "|") }
            .filter { $0.count == 8 && $0[2] == n.rawValue }
        #expect(cas.count > 100)
        var signale = false
        for c in cas {
            let israel = c[1] == "1"
            let conditions = CalendrierJuif.jour(.du(c[0]), enIsrael: israel).conditions
            let sansTahanoun: Bool? = c[3] == "-" ? nil : true
            var fermes: [String] = [], ouverts: [String] = []
            var n1 = 0, n2 = 0
            for id in toutes.textes {
                let texte = try #require(recueil.texte(id))
                let liste = toutes[id] ?? []
                func lire(_ cles: Set<String>) -> [L] {
                    SiddurJour.lignes(texte, liste, conditions, ouverts: cles, nusah: n, enIsrael: israel,
                                      sansTahanounFinTichri: sansTahanoun, sud: c[3] == "sud")
                }
                let ferme = lire([])
                let cles = Set(ferme.compactMap { l -> String? in if case .replie(let cle, _, _, _) = l { return cle } else { return nil } })
                let ouvert = lire(cles)
                fermes.append(id + "=" + ferme.map(Self.code).joined(separator: ";"))
                ouverts.append(id + "=" + ouvert.map(Self.code).joined(separator: ";"))
                n1 += ferme.count
                n2 += ouvert.count
            }
            let rendu = [String(n1), String(Kotlin.hashCode(fermes.joined(separator: "#"))),
                         String(n2), String(Kotlin.hashCode(ouverts.joined(separator: "#")))]
            let ok = rendu == Array(c[4...7])
            #expect(ok, "\(c[0...3].joined(separator: "|")) : \(rendu.joined(separator: "|")) au lieu de \(c[4...7].joined(separator: "|"))")
            if !ok && !signale {
                // De quoi comparer, texte par texte, avec ce que rend la JVM (VecteursSiddourJour.code).
                signale = true
                for f in fermes { Issue.record("\(c[0...3].joined(separator: "|")) \(f.prefix(3000))") }
            }
        }
    }
}
