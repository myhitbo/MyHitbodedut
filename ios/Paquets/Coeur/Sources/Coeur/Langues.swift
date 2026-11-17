// Les langues que l'application parle (Langues.kt d'Android). Le bouton des réglages et l'application du
// choix (SettingsActivity, AppCompatDelegate) restent à Android : sur iOS, la langue de l'app se choisit
// dans les Réglages du système (PORTAGE.md § 2.2.7). Ces règles ramènent une étiquette de langue, quelle que
// soit sa forme, à l'une des cinq, et la nomment.

/// Les langues que l'application parle, et celle qu'on a choisie.
///
/// Jusqu'ici la langue était celle du téléphone, sans recours : un appareil réglé en anglais ne pouvait pas
/// afficher l'hébreu, alors que les trois traductions sont livrées. Le choix est maintenant explicite.
public enum Langues {

    /// Une langue offerte. L'étiquette est celle du dossier de ressources d'Android, pas celle du BCP-47
    /// moderne : l'hébreu est livré dans `values-iw`, l'ancien code qu'Android emploie toujours (le
    /// catalogue d'iOS, lui, le nomme « he »).
    public struct Langue: Sendable, Hashable {
        public let etiquette: String
        /// Le nom de la langue, dans sa propre langue.
        public let nom: String

        public init(etiquette: String, nom: String) {
            self.etiquette = etiquette
            self.nom = nom
        }
    }

    /// Dans l'ordre demandé : עברית, English, Français ; puis l'espagnol d'Amérique latine (`values-es`) et
    /// l'arabe tunisien (`values-ar-rTN`, le 17/11). L'interface seule est traduite : les textes y restent
    /// en hébreu (RegleLangue). Recopiées par programme de Langues.kt.
    public static let toutes: [Langue] = [
        Langue(etiquette: "iw", nom: "עברית"),
        Langue(etiquette: "en", nom: "English"),
        Langue(etiquette: "fr", nom: "Français"),
        Langue(etiquette: "es", nom: "Español"),
        Langue(etiquette: "ar-TN", nom: "تونسي"),
    ]

    /// Le français est la langue de `values/`. Un téléphone dont aucune langue n'est livrée passe pourtant en
    /// anglais (LangueApp.repli sur Android, au lancement, 29/10 ; sur iOS, la région de développement).
    public static let defaut = "fr"

    /// Ramène une étiquette de langue, quelle que soit sa forme (« he-IL », « iw_IL », « EN-us », nil), à
    /// l'une des nôtres ; le français pour une langue qui n'est pas livrée.
    public static func normalise(_ etiquette: String?) -> String {
        let brute = (etiquette ?? "").avantUnites("-").avantUnites("_").lowercased()
        // « he » est le code actuel de l'hébreu, « iw » celui qu'Android rend encore. Les deux désignent la
        // même langue et le même dossier.
        let code = brute.egalUnites("he") ? "iw" : brute
        // « ar-TN » se trouve par « ar » : la langue, sans la région.
        return toutes.first { $0.etiquette.avantUnites("-").egalUnites(code) }?.etiquette ?? defaut
    }

    /// Le nom de la langue, dans sa propre langue : « Hébreu » écrit en français ne se lit pas par qui
    /// cherche l'hébreu.
    public static func nomDe(_ etiquette: String?) -> String {
        let code = normalise(etiquette)
        // `normalise` ne rend qu'une étiquette de `toutes` : la recherche trouve toujours.
        return toutes.first { $0.etiquette.egalUnites(code) }?.nom ?? code
    }

    /// Le rang de la langue courante dans `toutes`, pour cocher la bonne ligne ; jamais hors de la liste.
    public static func indexDe(_ etiquette: String?) -> Int {
        let code = normalise(etiquette)
        return toutes.firstIndex { $0.etiquette.egalUnites(code) } ?? -1
    }
}
