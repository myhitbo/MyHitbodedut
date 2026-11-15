import Foundation
import Testing
@testable import Coeur

/// LibraryRulesTest d'Android, porté en entier. Point 5 : test bloquant — aucun texte intégral
/// affiché si l'autorisation est nulle. Puis tout le chapitre « libraryRules » de
/// `Tests/Vecteurs/langues.json` (tools/vecteurs_ios/VecteursLangues.kt) : la bibliothèque livrée,
/// entrée par entrée et langue par langue, et une bibliothèque écrite à la main que Swift décode ici.
@Suite("LibraryRules")
struct LibraryRulesTests {

    private func lireBibliotheque() throws -> Bibliotheque {
        try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
    }

    private func articles(_ library: Bibliotheque) -> [ArticleBibliotheque] {
        var resultat: [ArticleBibliotheque] = []
        for entree in library.entrees {
            if case .article(let article) = entree { resultat.append(article) }
        }
        return resultat
    }

    private func sources(_ library: Bibliotheque) -> [SourceBibliotheque] {
        var resultat: [SourceBibliotheque] = []
        for entree in library.entrees {
            if case .source(let source) = entree { resultat.append(source) }
        }
        return resultat
    }

    private static func estSource(_ entree: EntreeBibliotheque) -> Bool {
        if case .source = entree { return true }
        return false
    }

    private func gabarit(autorisation: String?, texte: String?) -> ArticleBibliotheque {
        ArticleBibliotheque(id: "t", titre: "titre", auteur: nil, site: nil, date: nil, url: nil,
                            resumes: ["fr": "résumé"], droits: [:], autorisation: autorisation,
                            texteIntegral: texte, sourcesCitees: [], erreursRelevees: [:])
    }

    @Test func aucunArticleLivreNeMontreSonTexteIntegral() throws {
        let library = try lireBibliotheque()
        let tous = articles(library)
        let nombre = tous.count
        #expect(nombre > 0, "aucun article lu : la lecture est cassée")
        for article in tous {
            let texte = LibraryRules.fullText(article)
            #expect(texte == nil, "\(article.id) : texte intégral affiché alors que autorisation vaut « \(article.autorisation ?? "null") »")
        }
    }

    @Test func sansAutorisationLeTexteResteCacheMemeSIlEstPresent() {
        let article = gabarit(autorisation: nil, texte: "le texte complet de l'article")
        let texte = LibraryRules.fullText(article)
        #expect(texte == nil)
    }

    @Test func uneAutorisationVideNeVautPasAutorisation() {
        let vide = LibraryRules.fullText(gabarit(autorisation: "", texte: "texte"))
        #expect(vide == nil)
        let blanche = LibraryRules.fullText(gabarit(autorisation: "   ", texte: "texte"))
        #expect(blanche == nil)
    }

    @Test func avecAutorisationLeTexteSAffiche() {
        let article = gabarit(autorisation: "accord écrit de l'auteur, 20/09/2026", texte: "texte")
        let texte = LibraryRules.fullText(article)
        #expect(texte == "texte")
    }

    @Test func uneAutorisationSansTexteNeFabriqueRien() {
        let texte = LibraryRules.fullText(gabarit(autorisation: "accord", texte: nil))
        #expect(texte == nil)
    }

    @Test func lesParagraphesSuiventLeNikkoudDeLEdition() throws {
        let library = try lireBibliotheque()
        let toutes = sources(library)
        let nombre = toutes.count
        #expect(nombre > 0, "aucune source lue : la lecture est cassée")
        for source in toutes {
            let affiches = LibraryRules.paragraphs(library, source)
            // `getValue` d'Android : une édition absente de `_meta.editions` est une faute des données.
            let edition = try #require(library.editions[source.edition], "\(source.id) : édition « \(source.edition) » absente")
            if edition.nikkoudOk {
                #expect(affiches == source.paragraphes, "\(source.id)")
            } else {
                let sansNikkoud = !source.paragraphesSansNikkoud.isEmpty
                #expect(sansNikkoud, "\(source.id) : édition non vocalisable sans paragraphes_sans_nikkoud")
                #expect(affiches == source.paragraphesSansNikkoud, "\(source.id)")
            }
            let nonVide = !affiches.isEmpty
            #expect(nonVide, "\(source.id) : aucun paragraphe à afficher")
        }
    }

    @Test func chaqueArticleAUnResumeDansLesTroisLangues() throws {
        let library = try lireBibliotheque()
        for article in articles(library) {
            for langue in ["fr", "en", "he"] {
                let resume = LibraryRules.summary(article, langue)
                #expect(resume != nil, "\(article.id) : pas de résumé en \(langue)")
            }
        }
    }

    @Test func chaqueArticleASesDroitsDansLesTroisLangues() throws {
        let library = try lireBibliotheque()
        for article in articles(library) {
            for langue in ["fr", "en", "he"] {
                let droits = LibraryRules.rights(article, langue)
                #expect(droits != nil, "\(article.id) : pas de droits en \(langue)")
            }
        }
    }

    @Test func lArticleAvecDesErreursReleveesLesPorteDansLesTroisLangues() throws {
        let library = try lireBibliotheque()
        let avecErreurs = articles(library).filter { article in
            article.erreursRelevees.values.contains { !$0.isEmpty }
        }
        let present = !avecErreurs.isEmpty
        #expect(present, "aucun article ne porte d'erreurs relevées : la lecture est cassée")
        for article in avecErreurs {
            let tailleFr = LibraryRules.errors(article, "fr").count
            #expect(tailleFr > 0, "\(article.id) : liste française vide")
            for langue in ["en", "he"] {
                let taille = LibraryRules.errors(article, langue).count
                #expect(taille == tailleFr, "\(article.id) : \(langue) n'a pas le même nombre d'erreurs que le français")
            }
        }
    }

    @Test func unResumeDansUneLangueAbsenteNeRetombePlusSurLeFrancais() {
        // La règle : un texte manquant dans la langue en cours n'est pas remplacé par le français.
        // Vérifié directement sur la règle, pas sur les données — les données, elles, ont les trois langues.
        let article = gabarit(autorisation: nil, texte: nil)
        let anglais = LibraryRules.summary(article, "en")
        #expect(anglais == nil, "l'anglais retombait sur le résumé français")
        let francais = LibraryRules.summary(article, "fr")
        #expect(francais == "résumé")
    }

    @Test func lesSourcesPassentAvantLesArticles() throws {
        let library = try lireBibliotheque()
        let sousSection = try #require(library.sousSection("hitbodedut-ma-velama"))
        let ordre = LibraryRules.ordered(sousSection.entrees)
        let dernierSource = ordre.lastIndex(where: LibraryRulesTests.estSource) ?? -1
        let premierArticle = ordre.firstIndex { !LibraryRulesTests.estSource($0) } ?? -1
        #expect(dernierSource < premierArticle, "les deux natures se mélangent")
        let taille = ordre.count
        #expect(taille == sousSection.entrees.count)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        let libraryRules: Chapitre
    }

    /// `resumes`, `droits`, `erreurs` : une valeur par langue de `languesArticle`. `texteIntegral` :
    /// pour chaque autorisation, le texte rendu pour chacun des `integraux`.
    private struct Chapitre: Decodable {
        let languesArticle: [String]
        let livre: Rendu
        let document: String
        let manuelle: Rendu
        let manuelleEnClair: [EnClair]
        let autorisations: [String?]
        let integraux: [String?]
        let texteIntegral: [[String?]]
        let resumeDuGabarit: [String?]
    }

    /// Ce que la règle rend d'une bibliothèque, les textes en empreintes (`String.hashCode`).
    private struct Rendu: Decodable {
        let articles: [ArticleRendu]
        let sources: [SourceRendue]
        let ordres: [Ordre]
    }

    private struct ArticleRendu: Decodable {
        let id: String
        let texteIntegral: Int32?
        let resumes: [Int32?]
        let droits: [Int32?]
        let erreurs: [[Int32]]
    }

    private struct SourceRendue: Decodable {
        let id: String
        let edition: String
        let nikkoudOk: Bool?
        let affiches: [Int32]
        let sontLesParagraphes: Bool
    }

    private struct Ordre: Decodable {
        let sousSection: String
        let ids: [String]
        let natures: [String]
    }

    /// Une entrée de la bibliothèque écrite à la main, en clair : `affiches` pour une source, le reste
    /// pour un article.
    private struct EnClair: Decodable {
        let id: String
        let affiches: [String]?
        let texteIntegral: String?
        let resumes: [String?]?
        let droits: [String?]?
        let erreurs: [[String]]?
    }

    private static func empreinte(_ texte: String?) -> Int32? {
        guard let texte else { return nil }
        return Kotlin.hashCode(texte)
    }

    private static func empreintes(_ textes: [String]) -> [Int32] {
        var resultat: [Int32] = []
        for texte in textes {
            resultat.append(Kotlin.hashCode(texte))
        }
        return resultat
    }

    /// `==` de Kotlin sur deux chaînes peut-être nulles : les mêmes unités UTF-16.
    private static func meme(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case (let x?, let y?): x.egalUnites(y)
        default: false
        }
    }

    private static func memes(_ a: [String?], _ b: [String?]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) where !meme(x, y) {
            return false
        }
        return true
    }

    /// La règle appliquée à `library`, comparée à ce qu'Android a rendu pour la même bibliothèque.
    private func compare(_ library: Bibliotheque, _ attendu: Rendu, _ langues: [String], _ nom: String) {
        let tousArticles = articles(library)
        let toutesSources = sources(library)
        let nombreArticles = tousArticles.count
        #expect(nombreArticles == attendu.articles.count, "\(nom) : nombre d'articles")
        let nombreSources = toutesSources.count
        #expect(nombreSources == attendu.sources.count, "\(nom) : nombre de sources")
        for (article, a) in zip(tousArticles, attendu.articles) {
            #expect(article.id == a.id, "\(nom) : article \(a.id)")
            let texte = LibraryRulesTests.empreinte(LibraryRules.fullText(article))
            #expect(texte == a.texteIntegral, "\(nom) : fullText(\(a.id))")
            var resumes: [Int32?] = []
            var droits: [Int32?] = []
            var erreurs: [[Int32]] = []
            for langue in langues {
                resumes.append(LibraryRulesTests.empreinte(LibraryRules.summary(article, langue)))
                droits.append(LibraryRulesTests.empreinte(LibraryRules.rights(article, langue)))
                erreurs.append(LibraryRulesTests.empreintes(LibraryRules.errors(article, langue)))
            }
            #expect(resumes == a.resumes, "\(nom) : summary(\(a.id))")
            #expect(droits == a.droits, "\(nom) : rights(\(a.id))")
            #expect(erreurs == a.erreurs, "\(nom) : errors(\(a.id))")
        }
        for (source, s) in zip(toutesSources, attendu.sources) {
            #expect(source.id == s.id, "\(nom) : source \(s.id)")
            #expect(source.edition == s.edition, "\(nom) : édition de \(s.id)")
            let nikkoudOk = library.editions[source.edition]?.nikkoudOk
            #expect(nikkoudOk == s.nikkoudOk, "\(nom) : nikkoud_ok de \(s.id)")
            let affiches = LibraryRules.paragraphs(library, source)
            let empreintes = LibraryRulesTests.empreintes(affiches)
            #expect(empreintes == s.affiches, "\(nom) : paragraphs(\(s.id))")
            let sontLesParagraphes = affiches == source.paragraphes
            #expect(sontLesParagraphes == s.sontLesParagraphes, "\(nom) : paragraphs(\(s.id)) == paragraphes")
        }
        var sousSections: [SousSection] = []
        for section in library.sections {
            sousSections.append(contentsOf: section.sousSections)
        }
        let nombreSousSections = sousSections.count
        #expect(nombreSousSections == attendu.ordres.count, "\(nom) : nombre de sous-sections")
        for (sousSection, o) in zip(sousSections, attendu.ordres) {
            #expect(sousSection.id == o.sousSection, "\(nom) : sous-section \(o.sousSection)")
            var ids: [String] = []
            var natures: [String] = []
            for entree in LibraryRules.ordered(sousSection.entrees) {
                ids.append(entree.id)
                natures.append(LibraryRulesTests.estSource(entree) ? "source" : "article")
            }
            #expect(ids == o.ids, "\(nom) : ordered(\(o.sousSection))")
            #expect(natures == o.natures, "\(nom) : natures de \(o.sousSection)")
        }
    }

    @Test func lesVecteursDeLaJVM() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/langues.json"))
        let c = v.libraryRules
        let langues = c.languesArticle

        compare(try lireBibliotheque(), c.livre, langues, "livrée")

        let manuelle = try JSONDecoder().decode(Bibliotheque.self, from: Data(c.document.utf8))
        compare(manuelle, c.manuelle, langues, "à la main")
        let entrees = manuelle.entrees
        let nombre = entrees.count
        #expect(nombre == c.manuelleEnClair.count, "à la main : nombre d'entrées")
        for (entree, clair) in zip(entrees, c.manuelleEnClair) {
            #expect(entree.id == clair.id, "à la main : \(clair.id)")
            switch entree {
            case .source(let source):
                let affiches = LibraryRules.paragraphs(manuelle, source)
                let attendus = try #require(clair.affiches, "\(clair.id) : source sans « affiches »")
                let ok = LibraryRulesTests.memes(affiches, attendus)
                #expect(ok, "paragraphs(\(clair.id)) = \(affiches)")
            case .article(let article):
                let texte = LibraryRules.fullText(article)
                let texteOk = LibraryRulesTests.meme(texte, clair.texteIntegral)
                #expect(texteOk, "fullText(\(clair.id)) = « \(texte ?? "nil") »")
                let resumesAttendus = try #require(clair.resumes, "\(clair.id) : article sans « resumes »")
                let droitsAttendus = try #require(clair.droits, "\(clair.id) : article sans « droits »")
                let erreursAttendues = try #require(clair.erreurs, "\(clair.id) : article sans « erreurs »")
                var resumes: [String?] = []
                var droits: [String?] = []
                var erreursOk = erreursAttendues.count == langues.count
                for (rang, langue) in langues.enumerated() {
                    resumes.append(LibraryRules.summary(article, langue))
                    droits.append(LibraryRules.rights(article, langue))
                    if rang < erreursAttendues.count {
                        let erreurs = LibraryRules.errors(article, langue)
                        if !LibraryRulesTests.memes(erreurs, erreursAttendues[rang]) { erreursOk = false }
                    }
                }
                let resumesOk = LibraryRulesTests.memes(resumes, resumesAttendus)
                #expect(resumesOk, "summary(\(clair.id))")
                let droitsOk = LibraryRulesTests.memes(droits, droitsAttendus)
                #expect(droitsOk, "rights(\(clair.id))")
                #expect(erreursOk, "errors(\(clair.id))")
            }
        }

        let lignes = c.texteIntegral.count
        #expect(lignes == c.autorisations.count, "fullText : vecteur incomplet")
        for (autorisation, ligne) in zip(c.autorisations, c.texteIntegral) {
            for (texte, attendu) in zip(c.integraux, ligne) {
                let rendu = LibraryRules.fullText(gabarit(autorisation: autorisation, texte: texte))
                let ok = LibraryRulesTests.meme(rendu, attendu)
                #expect(ok, "fullText(autorisation « \(autorisation ?? "null") », texte « \(texte ?? "null") »)")
            }
        }
        let article = gabarit(autorisation: nil, texte: nil)
        var resumes: [String?] = []
        for langue in langues {
            resumes.append(LibraryRules.summary(article, langue))
        }
        let resumesOk = LibraryRulesTests.memes(resumes, c.resumeDuGabarit)
        #expect(resumesOk, "summary du gabarit")
    }
}
