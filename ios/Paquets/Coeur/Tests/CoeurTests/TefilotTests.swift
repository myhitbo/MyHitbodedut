import Foundation
import Testing
@testable import Coeur

/// TefilotTest d'Android, porté en entier : les prières de Likoutei Tefilot, au moins deux par
/// sujet demandé, aucune vide, chacune renvoyant à sa prière et à sa leçon, et la règle de
/// vocalisation — l'édition 2021 n'a pas de licence déclarée, c'est la forme sans nikkoud qui
/// s'affiche. Puis tout `Tests/Vecteurs/tefilot.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursTefilot.kt), qui couvre aussi les règles que TefilotScreenTest éprouve
/// (ordre des titres, une ligne par prière, sujet sans prière, avertissement). TefilotScreenTest
/// lit les écrans, le manifeste et strings.xml : il reste à Android, hors les chaînes des titres,
/// vérifiées ici sur le catalogue exporté.
@Suite("Tefilot")
struct TefilotTests {

    private let sujets = [
        "hitbodedut", "simcha", "uman", "kdusha", "zera",
        "parnassa", "brit", "geula", "zivug", "refua",
    ]

    private func lireBibliotheque() throws -> Bibliotheque {
        try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
    }

    /// Les sources de la sous-section « tefilot-lt », lues comme le test Kotlin les lit, sans
    /// passer par TefilotRules.
    private func prieresDe(_ library: Bibliotheque) -> [SourceBibliotheque] {
        var sources: [SourceBibliotheque] = []
        for entree in library.sousSection("tefilot-lt")?.entrees ?? [] {
            if case .source(let source) = entree {
                sources.append(source)
            }
        }
        return sources
    }

    /// `LibraryRules.paragraphs` (LibraryRules.kt), que cette grappe ne porte pas : la forme que la
    /// licence de l'édition permet d'afficher. À remplacer par l'appel quand LibraryRules sera porté.
    private static func paragraphesAffiches(_ library: Bibliotheque, _ source: SourceBibliotheque) -> [String] {
        LibraryRules.paragraphs(library, source)
    }

    /// `==` de Kotlin entre un texte peut-être absent et un texte.
    private static func vaut(_ texte: String?, _ attendu: String) -> Bool {
        guard let texte else { return false }
        return texte.egalUnites(attendu)
    }

    private static func ecrit(_ texte: String?) -> String {
        texte ?? "nil"
    }

    @Test func lesDixSujetsDemandesOntChacunAuMoinsDeuxPrieres() throws {
        let tefilot = try prieresDe(lireBibliotheque())
        for sujet in sujets {
            let siennes = tefilot.filter { TefilotTests.vaut($0.sujet, sujet) }.count
            #expect(siennes >= 2, "« \(sujet) » : il faut au moins deux prières, il y en a \(siennes)")
            for id in ["src-lt-\(sujet)", "src-lt-\(sujet)-2"] {
                let presente = tefilot.contains { $0.id.egalUnites(id) }
                #expect(presente, "entrée manquante : \(id)")
            }
        }
        let rangees = tefilot.filter { t in sujets.contains { TefilotTests.vaut(t.sujet, $0) } }.count
        let total = tefilot.count
        #expect(total == rangees, "des prières traînent hors des dix sujets")
    }

    /// Deux prières sur le même sujet doivent être deux prières différentes. Sans ce test, dupliquer
    /// la première passerait inaperçu.
    @Test func lesPrieresDUnMemeSujetSontToutesDifferentes() throws {
        let tefilot = try prieresDe(lireBibliotheque())
        for sujet in sujets {
            let siennes = tefilot.filter { TefilotTests.vaut($0.sujet, sujet) }
            // Les textes comparés unité par unité, comme `distinct()` de Kotlin.
            let refs = Set(siennes.map { Array($0.ref.utf16) }).count
            #expect(refs == siennes.count, "« \(sujet) » : deux prières partagent une référence")
            let textes = Set(siennes.map { $0.paragraphes.map { Array($0.utf16) } }).count
            #expect(textes == siennes.count, "« \(sujet) » : deux prières partagent leur texte")
        }
    }

    /// Le constat honnête : la leçon annoncée porte-t-elle sur le sujet ? Trois réponses seulement,
    /// et aucune entrée n'a le droit de se taire.
    @Test func chaquePriereDitSiSaLeconPorteSurLeSujet() throws {
        let tefilot = try prieresDe(lireBibliotheque())
        let assez = tefilot.count >= sujets.count * 2
        #expect(assez, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            let constat = ["oui", "partiel", "non"].contains { TefilotTests.vaut(t.leconSurLeSujet, $0) }
            #expect(constat, "\(t.id) : constat manquant ou hors barème (« \(TefilotTests.ecrit(t.leconSurLeSujet)) »)")
        }
        let unNon = tefilot.contains { TefilotTests.vaut($0.leconSurLeSujet, "non") }
        #expect(unNon, "aucune entrée ne dit « non » : le constat ne distingue plus rien")
    }

    @Test func aucunePriereNEstVideNiTronquee() throws {
        let tefilot = try prieresDe(lireBibliotheque())
        let assez = tefilot.count >= sujets.count * 2
        #expect(assez, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            let vide = t.paragraphes.isEmpty
            #expect(!vide, "\(t.id) : aucun paragraphe")
            for (i, p) in t.paragraphes.enumerated() {
                let blanc = p.estBlanc
                #expect(!blanc, "\(t.id) paragraphe \(i) vide")
                let balise = p.contientUnites("<")
                #expect(!balise, "\(t.id) paragraphe \(i) : balise HTML restée")
                let entete = p.contientUnites("[")
                #expect(!entete, "\(t.id) paragraphe \(i) : en-tête d'éditeur restée")
            }
        }
    }

    @Test func chaquePriereDitDOuElleVient() throws {
        let tefilot = try prieresDe(lireBibliotheque())
        let assez = tefilot.count >= sujets.count * 2
        #expect(assez, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            let sansTitre = t.titreHe.estBlanc
            #expect(!sansTitre, "\(t.id) : titre hébreu manquant")
            let likoutei = t.ref.commenceParUnites("Likoutei Tefilot ")
            #expect(likoutei, "\(t.id) : la référence doit nommer Likoutei Tefilot, pas « \(t.ref) »")
            let edition = t.edition.egalUnites("lt")
            #expect(edition, "\(t.id) : mauvaise édition")
            let verifie = t.statutVerif.egalUnites("verifie_texte")
            #expect(verifie, "\(t.id) : texte non vérifié")
        }
    }

    /// Le cœur : la licence de l'édition 2021 n'est pas déclarée, donc sa vocalisation ne se reprend
    /// pas. Si quelqu'un passe `lt` à nikkoud_ok = true, ce test tombe.
    @Test func cEstLeTexteLivreSansNikkoudQuiSAffiche() throws {
        let library = try lireBibliotheque()
        let edition = try #require(library.editions["lt"], "l'édition lt est absente du fichier")
        let nikkoud = edition.nikkoudOk
        #expect(!nikkoud, "licence non déclarée : nikkoud_ok ne peut pas valoir vrai")
        let tefilot = prieresDe(library)
        let assez = tefilot.count >= sujets.count * 2
        #expect(assez, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            // Le fichier livre déjà le texte sans vocalisation (audit du 12/11) : c'est lui qui sort.
            let affiches = TefilotTests.paragraphesAffiches(library, t)
            let memes = TefilotTests.memesTextes(affiches, t.paragraphes)
            #expect(memes, "\(t.id) : c'est le texte livré qui doit sortir")
            for p in affiches {
                var signe = false
                for u in p.utf16 where (0x0591...0x05BD).contains(u) || (0x05BF...0x05C2).contains(u) || (0x05C4...0x05C7).contains(u) {
                    signe = true
                }
                #expect(!signe, "\(t.id) : un signe de vocalisation a survécu dans « \(p.premieresUnites(40)) »")
            }
        }
    }

    /// Le maqqef (U+05BE) est à l'intérieur de la plage des signes hébreux mais n'est pas un signe de
    /// vocalisation : le retirer soude les mots. L'erreur a déjà été commise une fois, elle ne se
    /// refera pas en silence.
    @Test func leMaqqefSurvitAuRetraitDuNikkoud() throws {
        let tefilot = try prieresDe(lireBibliotheque())
        // Le relevé vocalisé d'origine vit hors de res/raw (livres/editions_vocalisees.json), comme sur Android.
        let releves = try #require(try ObjetJSON(texte: String(decoding: Depot.donnees(
            "android/app/src/main/livres/editions_vocalisees.json"), as: UTF8.self)).objet("bibliotheque"))
        var avec = 0, sans = 0
        for t in tefilot {
            guard let origine = releves.objet(t.id)?.tableau("paragraphes") else { continue }
            for i in origine.indices {
                for unite in origine.texte(i).utf16 where unite == 0x05BE { avec += 1 }
            }
            for p in t.paragraphes {
                for unite in p.utf16 where unite == 0x05BE { sans += 1 }
            }
        }
        let present = avec > 0
        #expect(present, "aucun maqqef dans le corpus : le test ne prouve rien")
        let totalAvec = avec, totalSans = sans
        #expect(totalAvec == totalSans, "des maqqef ont été perdus en retirant le nikkoud")
    }

    /// Le titre de chaque sujet (`SujetTefila.titre`) est une chaîne du catalogue, dans les trois
    /// langues (TefilotScreenTest, `l ecran a ses chaines dans les trois langues`).
    @Test func lesTitresDesSujetsSontDansLeCatalogue() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for sujet in SujetTefila.allCases {
                let present = simples[sujet.titre] != nil
                #expect(present, "\(langue) : chaîne « \(sujet.titre) » manquante")
            }
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Sujet: Decodable {
            let cle: String
            let titre: String
        }
        struct Priere: Decodable {
            let id: String
            let sujet: String?
            let lecon: String?
            let prevenir: Bool
        }
        /// « titre » : un sujet et son nombre de prières ; « priere » : une prière sous ce sujet.
        struct Ligne: Decodable {
            let genre: String
            let sujet: String
            let nombre: Int?
            let id: String?
        }
        /// Les textes d'une prière livrée, en empreintes (`String.hashCode` des paragraphes joints
        /// par un saut de ligne) ; « affiches » : ce que LibraryRules.paragraphs en affiche.
        struct Textes: Decodable {
            let id: String
            let ref: String
            let edition: String
            let statutVerif: String
            let titreHe: Int32
            let paragraphes: Int
            let avec: Int32
            let affiches: Int32
        }
        struct Livree: Decodable {
            let prieres: [Priere]
            let parSujet: [[String]]
            let lignes: [Ligne]
            let editionLt: Bool?
            let textes: [Textes]
        }
        struct Document: Decodable {
            let nom: String
            let json: String
            let prieres: [Priere]
            let parSujet: [[String]]
            let lignes: [Ligne]
        }

        let sousSection: String
        let sujets: [Sujet]
        let bibliotheque: Livree
        let documents: [Document]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/tefilot.json"))
    }

    private static func empreinte(_ textes: [String]) -> Int32 {
        Kotlin.hashCode(textes.joined(separator: "\n"))
    }

    private static func memesTextes(_ a: [String], _ b: [String]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) where !x.egalUnites(y) {
            return false
        }
        return true
    }

    private static func memeTexte(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.egalUnites(y)
        default: return false
        }
    }

    /// Une ligne de l'écran, écrite comme le générateur l'écrit.
    private static func decrite(_ ligne: TefilotRules.Ligne) -> String {
        switch ligne {
        case .titre(let sujet, let nombre): return "titre \(sujet.cle) \(nombre)"
        case .priere(let sujet, let entree): return "priere \(sujet.cle) \(entree.id)"
        }
    }

    private static func decrite(_ ligne: Vecteurs.Ligne) -> String {
        switch ligne.genre {
        case "titre": return "titre \(ligne.sujet) \(ligne.nombre ?? -1)"
        default: return "\(ligne.genre) \(ligne.sujet) \(ecrit(ligne.id))"
        }
    }

    /// Tout ce que TefilotRules répond d'une bibliothèque, comparé à ce qu'Android en répond.
    private static func compare(_ library: Bibliotheque, _ nom: String,
                                prieres: [Vecteurs.Priere], parSujet: [[String]], lignes: [Vecteurs.Ligne]) {
        let lues = TefilotRules.prieres(library)
        #expect(lues.count == prieres.count, "\(nom) : prières")
        for (p, attendue) in zip(lues, prieres) {
            let id = p.id.egalUnites(attendue.id)
            #expect(id, "\(nom) : prière « \(attendue.id) »")
            let champs = memeTexte(p.sujet, attendue.sujet) && memeTexte(p.leconSurLeSujet, attendue.lecon)
            #expect(champs, "\(nom) : « \(attendue.id) » : sujet \(ecrit(p.sujet)), leçon \(ecrit(p.leconSurLeSujet))")
            let prevenir = TefilotRules.prevenir(p)
            #expect(prevenir == attendue.prevenir, "\(nom) : prevenir(« \(attendue.id) »)")
        }
        #expect(parSujet.count == SujetTefila.allCases.count, "\(nom) : parSujet")
        for (sujet, ids) in zip(SujetTefila.allCases, parSujet) {
            let calcules = TefilotRules.parSujet(library, sujet).map { $0.id }
            #expect(calcules == ids, "\(nom) : parSujet(\(sujet.cle))")
        }
        let calculees = TefilotRules.lignes(library).map { decrite($0) }
        let attendues = lignes.map { decrite($0) }
        #expect(calculees == attendues, "\(nom) : lignes")
    }

    @Test func lesSujetsEtLaBibliothequeLivreeCommeSurAndroid() throws {
        let v = try vecteurs()
        let sousSection = TefilotRules.sousSection
        #expect(sousSection == v.sousSection)
        let cles = SujetTefila.allCases.map { $0.cle }, titres = SujetTefila.allCases.map { $0.titre }
        let clesAndroid = v.sujets.map { $0.cle }, titresAndroid = v.sujets.map { $0.titre }
        #expect(cles == clesAndroid, "l'ordre ou les clés des sujets")
        #expect(titres == titresAndroid, "les chaînes des titres")
        let ordreDemande = sujets
        #expect(cles == ordreDemande)

        let library = try lireBibliotheque()
        let b = v.bibliotheque
        TefilotTests.compare(library, "bibliothèque livrée", prieres: b.prieres, parSujet: b.parSujet, lignes: b.lignes)
        let editionLt = library.editions["lt"]?.nikkoudOk
        #expect(editionLt == b.editionLt)
        let prieres = TefilotRules.prieres(library)
        #expect(prieres.count == b.textes.count)
        for (p, t) in zip(prieres, b.textes) {
            let entete = p.id.egalUnites(t.id) && p.ref.egalUnites(t.ref) && p.edition.egalUnites(t.edition)
                && p.statutVerif.egalUnites(t.statutVerif)
            #expect(entete, "\(t.id) : id, ref, édition, statut")
            let titre = Kotlin.hashCode(p.titreHe)
            #expect(titre == t.titreHe, "\(t.id) : titre hébreu")
            #expect(p.paragraphes.count == t.paragraphes, "\(t.id) : nombre de paragraphes")
            let avec = TefilotTests.empreinte(p.paragraphes)
            #expect(avec == t.avec, "\(t.id) : paragraphes")
            let affiches = TefilotTests.empreinte(TefilotTests.paragraphesAffiches(library, p))
            #expect(affiches == t.affiches, "\(t.id) : forme affichée")
        }
    }

    /// Des bibliothèques écrites à la main : sous-section vide, absente ou sans entrées, articles mêlés
    /// aux sources, sujets inconnus ou mal écrits, constats « non » mal écrits, deux sous-sections du
    /// même nom (la première l'emporte), ordre du fichier gardé sous chaque sujet.
    @Test func lesBibliothequesEcritesALaMainCommeSurAndroid() throws {
        let documents = try vecteurs().documents
        #expect(documents.count >= 10)
        for doc in documents {
            let library = try JSONDecoder().decode(Bibliotheque.self, from: Data(doc.json.utf8))
            TefilotTests.compare(library, doc.nom, prieres: doc.prieres, parSujet: doc.parSujet, lignes: doc.lignes)
        }
    }
}
