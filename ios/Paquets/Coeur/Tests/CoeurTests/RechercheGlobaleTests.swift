import Foundation
import Testing
@testable import Coeur

/// La recherche dans toute l'application (RechercheGlobale.kt, 14/10). Android ne lui donne pas de fichier de
/// test à elle : son cas est « recherche, sans voyelles ni balises » de DixAmeliorationsTest.kt, porté ici
/// tel quel (les autres cas de ce fichier jugent LevanaAlerte, ZmanimWidget et JournalPlus, et vont avec
/// eux) ; rien ne reste à Android. Puis `Tests/Vecteurs/recherche.json`, écrit par le code d'Android
/// (tools/vecteurs_ios/VecteursRecherche.kt) : nu sur plus de deux cents chaînes et sur tout le corpus,
/// extrait, resultatHilloula, et chercher sur une quarantaine de requêtes et toutes les portées, avec le vrai
/// siddour (edot), les vrais livres, le Yalkut Yosef, le Ben Ish 'Haï et les hilloulot.
@Suite("RechercheGlobale")
struct RechercheGlobaleTests {

    /// Ce que la recherche parcourt, lu une fois pour toute la suite (les livres pèsent 28 Mo).
    private struct Sources: Sendable {
        let siddur: Siddur
        let livres: Siddur
        let yalkut: YalkutYosef.Livre
        let benIshHai: Halakha.Livre
        let hilloulot: Hilloulot.Table
    }

    private static let sources: Result<Sources, any Error> = Result {
        Sources(siddur: try JSONDecoder().decode(Siddur.self, from: Depot.contenu("siddur_edot.json")),
                livres: try Livres.tous(Depot.lire),
                yalkut: try YalkutYosef.parse(Depot.contenu("yalkut_yosef.json")),
                benIshHai: try Halakha.parse(Depot.contenu("ben_ish_hai.json")),
                hilloulot: try Hilloulot.parse(Depot.contenu("hilloulot.json")))
    }

    private static let vecteurs: Result<Vecteurs, any Error> = Result {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/recherche.json"))
    }

    // MARK: DixAmeliorationsTest.kt

    /// Le recueil du test d'Android : un texte, un bloc. SiddurSection ne se construit qu'en se décodant.
    private static let alenou = """
        {"groupes":[],"textes":[{"id":"t","groupe":"g","titre":{"he":"עלינו","fr":"Alénou","en":"Aleinu"},"source":"",\
        "sections":[{"titre":"","blocs":[{"t":"וַאֲנַחְנוּ כּוֹרְעִים"}]}]}]}
        """

    @Test func rechercheSansVoyellesNiBalises() throws {
        let baruch = RechercheGlobale.nu("<b>בָּרוּךְ</b> אַתָּה")
        #expect(baruch.egalUnites("ברוך אתה"), "\(baruch)")
        let s = try JSONDecoder().decode(Siddur.self, from: Data(Self.alenou.utf8))
        // Sans accents ni apostrophe typographique (29/10) : « alenou », « hachahar ».
        for requete in ["כורעים", "alénou", "Alenou"] {
            let ids = RechercheGlobale.dansRecueil(s, RechercheGlobale.nu(requete), .siddour, langue: "fr").map { $0.id }
            #expect(ids == ["t"], "« \(requete) »")
        }
        let birkot = RechercheGlobale.nu("Birkot hacha’har Prières")
        #expect(birkot.egalUnites("birkot hachahar prieres"), "\(birkot)")
        let chabbat = RechercheGlobale.dansRecueil(s, "שבת", .siddour, langue: "fr")
        #expect(chabbat.isEmpty)
    }

    // MARK: Les vecteurs de la JVM

    @Test func vecteursNu() throws {
        let v = try Self.vecteurs.get()
        #expect(v.nu.count >= 200)
        for paire in v.nu {
            let nu = RechercheGlobale.nu(paire[0])
            #expect(nu.egalUnites(paire[1]), "« \(paire[0]) » : « \(nu) » ≠ « \(paire[1]) »")
        }
    }

    @Test func vecteursNuSurToutLeCorpus() throws {
        let v = try Self.vecteurs.get().corpus
        let sources = try Self.sources.get()
        for (recueil, attendus, nom) in [(sources.siddur, v.siddour, "siddour"), (sources.livres, v.livres, "livres")] {
            #expect(recueil.textes.count == attendus.count, "\(nom)")
            for (t, attendu) in zip(recueil.textes, attendus) {
                #expect(t.id == attendu.id, "\(nom)")
                let blocs = t.sections.flatMap { $0.blocs }
                #expect(blocs.count == attendu.nombre, "\(t.id)")
                let e = empreinte(blocs.map { RechercheGlobale.nu($0.texte) })
                #expect(e == attendu.empreinte, "\(t.id)")
            }
        }
        // Les noms des hilloulot, dans l'ordre des jours de hilloulot.json (celui des vecteurs de Hilloulot).
        let hilloulot = try JSONDecoder().decode(OrdreDesJours.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/hilloulot.json"))
        let toutes = hilloulot.table.jours.flatMap { sources.hilloulot[$0.cle] ?? [] }
        let champs: [[String]] = [toutes.map { $0.he }, toutes.compactMap { $0.fr }, toutes.compactMap { $0.en }]
        #expect(v.hilloulot.count == 3)
        for (noms, attendu) in zip(champs, v.hilloulot) {
            #expect(noms.count == attendu.nombre)
            let e = empreinte(noms.map { RechercheGlobale.nu($0) })
            #expect(e == attendu.empreinte)
        }
    }

    @Test func vecteursExtrait() throws {
        let v = try Self.vecteurs.get().extraits
        #expect(v.cas.count > 100)
        for c in v.cas {
            let texte = v.textes[c.texte]
            let extrait = RechercheGlobale.extrait(texte, c.q)
            #expect(extrait.egalUnites(c.extrait), "texte \(c.texte), « \(c.q) » : « \(extrait) » ≠ « \(c.extrait) »")
        }
    }

    @Test func vecteursResultatHilloula() throws {
        for c in try Self.vecteurs.get().resultatsHilloula {
            let x = Hilloulot.Hilloula(he: c.hilloula[0] ?? "", fr: c.hilloula[1], en: c.hilloula[2], annee: c.hilloula[3] ?? "",
                                       sources: "w", doute: nil)
            let r = RechercheGlobale.resultatHilloula("q", x, langue: c.langue)
            let ecrit = [r.sorte.rawValue, r.id, r.titre, r.extrait]
            let memes = ecrit.count == c.resultat.count && zip(ecrit, c.resultat).allSatisfy { $0.egalUnites($1) }
            #expect(memes, "« \(x.he) » en « \(c.langue) » : \(ecrit) ≠ \(c.resultat)")
        }
    }

    @Test func vecteursChercherSurToutesLesPortees() throws {
        let v = try Self.vecteurs.get()
        let s = try Self.sources.get()
        #expect(v.parSorte == RechercheGlobale.parSorte)
        #expect(v.recherches.count > 40)
        for c in v.recherches {
            for portee in RechercheGlobale.Portee.allCases {
                let attendu = try #require(c.portees[portee.rawValue], "« \(c.q) » \(portee.rawValue)")
                let r: [RechercheGlobale.Resultat]
                switch c.sources {
                case "complet":
                    r = RechercheGlobale.chercher(c.q, langue: c.langue, siddur: s.siddur, livres: s.livres, yalkut: s.yalkut,
                                                  benIshHai: s.benIshHai, hilloulot: s.hilloulot, portee: portee)
                case "sansLivres":
                    r = RechercheGlobale.chercher(c.q, langue: c.langue, siddur: s.siddur, livres: nil, yalkut: s.yalkut,
                                                  benIshHai: s.benIshHai, hilloulot: s.hilloulot, portee: portee)
                default:
                    r = RechercheGlobale.chercher(c.q, langue: c.langue, siddur: s.siddur, livres: nil, yalkut: nil,
                                                  benIshHai: nil, hilloulot: nil, portee: portee)
                }
                let contexte = "« \(c.q) » \(c.langue) \(c.sources) \(portee.rawValue)"
                let parSorte = RechercheGlobale.Sorte.allCases.map { sorte in r.filter { $0.sorte == sorte } }
                // Les résultats viennent par sorte, dans l'ordre de Sorte.
                let enOrdre = parSorte.flatMap { $0 } == r
                #expect(enOrdre, "\(contexte) : sortes mêlées")
                let nombres = parSorte.map { $0.count }
                #expect(nombres == attendu.nombres, "\(contexte)")
                let empreintes = parSorte.map { l in empreinte(l.map { ligne($0) }) }
                #expect(empreintes == attendu.empreintes, "\(contexte)")
                if let premiers = attendu.premiers {
                    let ecrits = parSorte.flatMap { l in l.prefix(2).map { [$0.sorte.rawValue, $0.id, $0.titre, $0.extrait] } }
                    let memes = ecrits.count == premiers.count && zip(ecrits, premiers).allSatisfy { x, y in
                        x.count == y.count && zip(x, y).allSatisfy { $0.egalUnites($1) }
                    }
                    #expect(memes, "\(contexte) : \(ecrits) ≠ \(premiers)")
                }
            }
        }
    }

    @Test func lesPorteesEtLeursSortes() {
        let tout = RechercheGlobale.Portee.tout.sortes
        #expect(tout == Set(RechercheGlobale.Sorte.allCases))
        let tefilot = RechercheGlobale.Portee.tefilot.sortes
        #expect(tefilot == [.siddour])
        let halakhot = RechercheGlobale.Portee.halakhot.sortes
        #expect(halakhot == [.halakha])
        let sefarim = RechercheGlobale.Portee.sefarim.sortes
        #expect(sefarim == [.livre])
        let hilloulot = RechercheGlobale.Portee.hilloulot.sortes
        #expect(hilloulot == [.hilloula])
    }

    // MARK: Aides

    /// Un résultat en une ligne, comme le générateur : sorte, id, titre, extrait, séparés par U+001F.
    private func ligne(_ r: RechercheGlobale.Resultat) -> String {
        [r.sorte.rawValue, r.id, r.titre, r.extrait].joined(separator: "\u{1F}")
    }

    /// `joinToString("\n").hashCode()` de Kotlin.
    private func empreinte(_ lignes: [String]) -> Int {
        Int(Kotlin.hashCode(lignes.joined(separator: "\n")))
    }
}

// MARK: Le fichier de vecteurs

private struct Vecteurs: Decodable {
    let parSorte: Int
    let nu: [[String]]
    let corpus: Corpus
    let extraits: Extraits
    let resultatsHilloula: [CasHilloula]
    let recherches: [CasRecherche]
}

/// [id, nombre de blocs, empreinte].
private struct TexteCompte: Decodable {
    let id: String
    let nombre: Int
    let empreinte: Int

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        id = try c.decode(String.self)
        nombre = try c.decode(Int.self)
        empreinte = try c.decode(Int.self)
    }
}

/// [nombre, empreinte].
private struct Compte: Decodable {
    let nombre: Int
    let empreinte: Int

    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        nombre = try c.decode(Int.self)
        empreinte = try c.decode(Int.self)
    }
}

private struct Corpus: Decodable {
    let siddour: [TexteCompte]
    let livres: [TexteCompte]
    let hilloulot: [Compte]
}

private struct Extraits: Decodable {
    /// [rang du texte, recherche, extrait].
    struct Cas: Decodable {
        let texte: Int
        let q: String
        let extrait: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            texte = try c.decode(Int.self)
            q = try c.decode(String.self)
            extrait = try c.decode(String.self)
        }
    }

    let textes: [String]
    let cas: [Cas]
}

private struct CasHilloula: Decodable {
    /// [he, fr, en, année].
    let hilloula: [String?]
    let langue: String
    let resultat: [String]
}

private struct CasRecherche: Decodable {
    struct Portee: Decodable {
        let nombres: [Int]
        let empreintes: [Int]
        let premiers: [[String]]?
    }

    let q: String
    let langue: String
    let sources: String
    let portees: [String: Portee]
}

/// L'ordre des jours de hilloulot.json, tel que la JVM l'a lu (`table.jours` de hilloulot.json).
private struct OrdreDesJours: Decodable {
    struct Table: Decodable {
        let jours: [Jour]
    }

    /// [clé, nombre, empreinte] : la clé seule sert ici.
    struct Jour: Decodable {
        let cle: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            cle = try c.decode(String.self)
        }
    }

    let table: Table
}
