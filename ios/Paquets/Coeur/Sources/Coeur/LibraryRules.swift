import Foundation

/// Ce que la bibliothèque a le droit d'afficher (LibraryRules.kt).
///
/// La règle tient en une phrase, tirée de `_meta.regle` : une « source » est une œuvre du domaine
/// public, ses paragraphes s'affichent en entier ; un « article » est un texte moderne qui appartient
/// à son auteur, on n'en montre qu'une fiche tant qu'aucune autorisation n'a été obtenue.
///
/// Reproduire un article sans autorisation n'abîme pas l'application : cela expose celui qui la
/// publie. D'où le test bloquant qui accompagne ce fichier (LibraryRulesTests).
public enum LibraryRules {

    /// Le texte intégral d'un article, ou nil. Nil tant que `autorisation` est vide ou blanche, même si
    /// `texteIntegral` est rempli : c'est l'autorisation qui ouvre, pas la présence du texte.
    public static func fullText(_ article: ArticleBibliotheque) -> String? {
        guard let autorisation = article.autorisation, !autorisation.estBlanc else { return nil }
        guard let texte = article.texteIntegral, !texte.estBlanc else { return nil }
        return texte
    }

    /// Les paragraphes d'une source. Même règle que pour le 'hizouk : la vocalisation d'une édition dont la
    /// licence n'est pas déclarée est un travail éditorial qu'on ne reprend pas ; le fichier livre donc déjà ces
    /// paragraphes sans vocalisation (LicencesEditionsTest d'Android l'impose).
    public static func paragraphs(_ library: Bibliotheque, _ source: SourceBibliotheque) -> [String] {
        source.paragraphes
    }

    /// Le résumé dans la langue de l'interface — et seulement elle (RegleLangue : pas de repli).
    public static func summary(_ article: ArticleBibliotheque, _ language: String) -> String? {
        RegleLangue.choisit(language, article.resumes.mapValues { Optional($0) })
    }

    /// Les droits, dans la même langue et selon la même règle que le résumé.
    public static func rights(_ article: ArticleBibliotheque, _ language: String) -> String? {
        RegleLangue.choisit(language, article.droits.mapValues { Optional($0) })
    }

    /// Les erreurs relevées, dans la langue de l'interface ; rien si aucune.
    public static func errors(_ article: ArticleBibliotheque, _ language: String) -> [String] {
        let langue = RegleLangue.normalise(language)
        for (cle, erreurs) in article.erreursRelevees where cle.egalUnites(langue) {
            return erreurs
        }
        return []
    }

    /// Les sources d'abord : ce sont elles qu'on vient lire. L'ordre de chaque nature est gardé.
    public static func ordered(_ entrees: [EntreeBibliotheque]) -> [EntreeBibliotheque] {
        var sources: [EntreeBibliotheque] = []
        var articles: [EntreeBibliotheque] = []
        for entree in entrees {
            switch entree {
            case .source: sources.append(entree)
            case .article: articles.append(entree)
            }
        }
        return sources + articles
    }
}
