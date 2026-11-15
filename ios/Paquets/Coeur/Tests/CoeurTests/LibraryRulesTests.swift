import Foundation
import Testing
@testable import Coeur

/// LibraryRulesTest d'Android, porté : test bloquant — aucun texte intégral affiché sans autorisation ; les
/// paragraphes suivent le nikkoud de l'édition ; résumé, droits et erreurs dans la langue, sans repli.
@Suite("LibraryRules")
struct LibraryRulesTests {

    private func bibliotheque() throws -> Bibliotheque {
        try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
    }

    private func articles() throws -> [ArticleBibliotheque] {
        try bibliotheque().entrees.compactMap { e -> ArticleBibliotheque? in
            if case .article(let a) = e { return a }
            return nil
        }
    }

    private func gabarit(autorisation: String?, texte: String?) -> ArticleBibliotheque {
        ArticleBibliotheque(id: "t", titre: "titre", auteur: nil, site: nil, date: nil, url: nil, resumes: ["fr": "résumé"],
                            droits: [:], autorisation: autorisation, texteIntegral: texte, sourcesCitees: [],
                            erreursRelevees: [:])
    }

    @Test func aucunArticleLivreNeMontreSonTexteIntegral() throws {
        for article in try articles() {
            #expect(LibraryRules.texteIntegral(article) == nil, "\(article.id) : autorisation « \(article.autorisation ?? "") »")
        }
    }

    @Test func sansAutorisationLeTexteResteCacheMemeSIlEstPresent() {
        #expect(LibraryRules.texteIntegral(gabarit(autorisation: nil, texte: "le texte complet de l'article")) == nil)
    }

    @Test func uneAutorisationVideNeVautPasAutorisation() {
        #expect(LibraryRules.texteIntegral(gabarit(autorisation: "", texte: "texte")) == nil)
        #expect(LibraryRules.texteIntegral(gabarit(autorisation: "   ", texte: "texte")) == nil)
    }

    @Test func avecAutorisationLeTexteSAffiche() {
        #expect(LibraryRules.texteIntegral(gabarit(autorisation: "accord écrit de l'auteur, 20/09/2026", texte: "texte")) == "texte")
    }

    @Test func uneAutorisationSansTexteNeFabriqueRien() {
        #expect(LibraryRules.texteIntegral(gabarit(autorisation: "accord", texte: nil)) == nil)
    }

    @Test func lesParagraphesSuiventLeNikkoudDeLEdition() throws {
        let b = try bibliotheque()
        for case .source(let source) in b.entrees {
            let affiches = LibraryRules.paragraphes(b, source)
            let edition = try #require(b.editions[source.edition], "\(source.id)")
            if edition.nikkoudOk {
                #expect(affiches == source.paragraphes, "\(source.id)")
            } else {
                #expect(!source.paragraphesSansNikkoud.isEmpty, "\(source.id) : sans paragraphes_sans_nikkoud")
                #expect(affiches == source.paragraphesSansNikkoud, "\(source.id)")
            }
            #expect(!affiches.isEmpty, "\(source.id) : aucun paragraphe à afficher")
        }
    }

    @Test func chaqueArticleAUnResumeDansLesTroisLangues() throws {
        for article in try articles() {
            for langue in ["fr", "en", "he"] {
                #expect(LibraryRules.resume(article, langue) != nil, "\(article.id) : pas de résumé en \(langue)")
            }
        }
    }

    @Test func chaqueArticleASesDroitsDansLesTroisLangues() throws {
        for article in try articles() {
            for langue in ["fr", "en", "he"] {
                #expect(LibraryRules.droits(article, langue) != nil, "\(article.id) : pas de droits en \(langue)")
            }
        }
    }

    @Test func lArticleAvecDesErreursReleveesLesPorteDansLesTroisLangues() throws {
        let avecErreurs = try articles().filter { a in a.erreursRelevees.values.contains { !$0.isEmpty } }
        #expect(!avecErreurs.isEmpty, "aucun article ne porte d'erreurs relevées : la lecture est cassée")
        for article in avecErreurs {
            let tailleFr = LibraryRules.erreurs(article, "fr").count
            #expect(tailleFr > 0, "\(article.id) : liste française vide")
            for langue in ["en", "he"] {
                #expect(LibraryRules.erreurs(article, langue).count == tailleFr, "\(article.id) : \(langue)")
            }
        }
    }

    @Test func unResumeDansUneLangueAbsenteNeRetombePlusSurLeFrancais() {
        let article = gabarit(autorisation: nil, texte: nil)
        #expect(LibraryRules.resume(article, "en") == nil, "l'anglais retombait sur le résumé français")
        #expect(LibraryRules.resume(article, "fr") == "résumé")
    }

    @Test func lesSourcesPassentAvantLesArticles() throws {
        let entrees = try #require(try bibliotheque().sousSection("hitbodedut-ma-velama")).entrees
        let ordre = LibraryRules.ordonnees(entrees)
        let natures = ordre.map { e -> Int in
            if case .source = e { return 0 }
            return 1
        }
        #expect(natures == natures.sorted(), "les deux natures se mélangent")
        #expect(ordre.count == entrees.count)
        #expect(natures.contains(0) && natures.contains(1))
    }
}
