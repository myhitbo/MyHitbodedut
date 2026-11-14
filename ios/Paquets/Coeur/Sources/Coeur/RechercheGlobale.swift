import Foundation

/// La recherche dans tous les textes (RechercheGlobale.kt). Ici, la forme sans voyelles qu'elle compare,
/// dont la recherche des hilloulot a besoin (tâche 11) ; la recherche elle-même viendra avec son index
/// (tâche 6).
public enum RechercheGlobale {

    private static let diacritiques = ExpressionReguliere("[\\u0300-\\u036F’‘]")
    private static let balises = ExpressionReguliere("<[^>]+>")
    private static let separateurs = ExpressionReguliere("[\\u05BE\\u05C0]")
    private static let voyelles = ExpressionReguliere("[\\u0591-\\u05C7\"'\\u05F4\\u05F3]")
    /// `\s` de Java, sans drapeau : les six blancs ASCII seulement.
    private static let blancs = ExpressionReguliere("[ \\t\\n\\u000B\\f\\r]+")

    /// Sans accents (« Moché » trouve « moche »), sans balises, sans voyelles ni signes de cantillation, le
    /// maqaf et le paseq pris pour des espaces, sans guillemets ni apostrophes, les blancs ramenés à une
    /// espace, en minuscules : « Prières », « hachahar » trouve « Birkot hacha’har ».
    public static func nu(_ t: String) -> String {
        var s = diacritiques.remplace(t.formeNFD, par: "")
        s = balises.remplace(s, par: " ")
        s = separateurs.remplace(s, par: " ")
        s = voyelles.remplace(s, par: "")
        s = blancs.remplace(s, par: " ")
        return s.rogne.lowercased()
    }
}
