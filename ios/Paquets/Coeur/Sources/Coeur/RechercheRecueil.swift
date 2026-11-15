import Foundation

/// La recherche dans un recueil (`RechercheGlobale.dansRecueil`, 14/10) : le siddour ou les livres, titre d'abord,
/// puis le premier paragraphe qui contient la recherche, avec un extrait autour de la trouvaille. Le reste de la
/// recherche (halakha, hilloulot, portées, `chercher`) vient avec son écran (tâche 23).
extension RechercheGlobale {

    public enum Sorte: String, Sendable, CaseIterable {
        case siddour = "SIDDOUR", livre = "LIVRE", halakha = "HALAKHA", hilloula = "HILLOULA"
    }

    public struct Resultat: Sendable, Equatable {
        public let sorte: Sorte
        public let id: String
        public let titre: String
        public let extrait: String
    }

    /// `PAR_SORTE` : trente résultats au plus par sorte.
    public static let parSorte = 30

    /// `extrait` : une quarantaine de caractères autour de la trouvaille, dans le texte sans voyelles (unités UTF-16,
    /// comme `substring` de Kotlin) ; « … » de part et d'autre quand le texte continue.
    public static func extrait(_ texte: String, _ q: String) -> String {
        let t = nu(texte)
        let longueur = t.utf16.count
        let q16 = q.utf16.count
        let i = max(t.positionUnites(de: q) ?? 0, 0)
        let debut = max(i - 30, 0)
        let fin = min(i + q16 + 50, longueur)
        return (debut > 0 ? "…" : "") + t.unites(debut, fin).rogne + (i + q16 + 50 < longueur ? "…" : "")
    }

    /// `dansRecueil` : `q` est déjà nu (`nu`). Un titre trouvé (en hébreu ou dans la langue) rend la traduction du
    /// titre en extrait ; sinon le premier bloc de prière (pas une consigne) qui contient `q`.
    public static func dansRecueil(_ recueil: Siddur, _ q: String, sorte: Sorte, langue: String) -> [Resultat] {
        var resultats: [Resultat] = []
        for t in recueil.textes {
            let titre = t.titre.he
            let traduit = t.titre.pour(langue)
            if nu(titre).contientUnites(q) || nu(traduit).contientUnites(q) {
                resultats.append(Resultat(sorte: sorte, id: t.id, titre: titre, extrait: traduit.egalUnites(titre) ? "" : traduit))
            } else if let bloc = t.sections.lazy.flatMap({ $0.blocs }).first(where: { !$0.consigne && nu($0.texte).contientUnites(q) }) {
                resultats.append(Resultat(sorte: sorte, id: t.id, titre: titre, extrait: extrait(bloc.texte, q)))
            }
        }
        return Array(resultats.prefix(parSorte))
    }
}
