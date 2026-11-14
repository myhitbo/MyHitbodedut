import Foundation

// La hitbodedout guidée selon le sujet (GuideSujets.kt d'Android ; proposition 2 de la feuille de
// route, 19/10) : pour chaque sujet, une invitation par temps, sous l'invitation générale du temps
// (guide_sujets.json, livré tel quel dans ios/Ressources/Contenu). « Autre chose » et l'absence de
// sujet n'en ont pas : le guide reste celui de toujours.
//
// Android lit le fichier une fois et le garde ; ici l'appelant le lit (`lire`) et le garde, et
// `invitation` est la fonction pure, celle qu'Android vérifie sans appareil.

public enum GuideSujets {

    /// L'objet « sujets » du fichier, comme `JSONObject(texte).getJSONObject("sujets")` : un fichier
    /// illisible, ou sans objet « sujets », est refusé.
    public static func lire(_ donnees: Data) throws -> ObjetJSON {
        let racine = try ObjetJSON(texte: String(decoding: donnees, as: UTF8.self))
        guard let sujets = racine.objet("sujets") else {
            throw ErreurJSON(position: 0, raison: "guide_sujets.json : pas d'objet « sujets »")
        }
        return sujets
    }

    /// L'invitation du temps `cle` pour `theme`, dans `langue` ; nil sans elle. « iw », l'ancien code
    /// de l'hébreu qu'Android donne encore, se lit « he ». Comme `optString` d'Android, une valeur qui
    /// n'est pas une chaîne rend son texte (« 20 », « true », et « null » pour null) ; un texte blanc
    /// au sens de Kotlin (`isBlank`) rend nil.
    public static func invitation(_ sujets: ObjetJSON, theme: Theme?, cle: String, langue: String) -> String? {
        guard let theme, let temps = sujets.objet(theme.cle)?.objet(cle) else { return nil }
        let lue = (langue.egalUnites("he") || langue.egalUnites("iw")) ? "he" : langue
        let texte = temps.texte(lue, defaut: "")
        return texte.estBlanc ? nil : texte
    }
}
