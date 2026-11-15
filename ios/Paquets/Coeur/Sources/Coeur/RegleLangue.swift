import Foundation

/// Quelles langues un écran a le droit d'afficher (RegleLangue, Langue.kt).
///
/// La règle, donnée par le propriétaire le 22/09 : en hébreu, **rien que de l'hébreu** ; en anglais,
/// l'hébreu et l'anglais ; en français, l'hébreu et le français. Jamais les trois ensemble, et jamais
/// une langue qui n'est ni l'hébreu ni celle de l'interface. Il n'y a **plus de repli d'une langue sur
/// une autre** : un texte dont la langue n'est pas permise n'est pas montré.
///
/// `LangueApp`, du même fichier Kotlin, applique le choix de langue aux services d'Android : il reste
/// à Android. Les comparaisons se font unité UTF-16 par unité, comme `==` de Kotlin.
public enum RegleLangue {

    /// L'hébreu est toujours permis : c'est la langue des textes eux-mêmes.
    public static func permises(_ interfaceLangue: String) -> Set<String> {
        let langue = normalise(interfaceLangue)
        if langue.egalUnites("he") { return ["he"] }
        return ["he", langue]
    }

    public static func permet(_ interfaceLangue: String, _ langueDuTexte: String) -> Bool {
        let langue = normalise(langueDuTexte)
        return permises(interfaceLangue).contains { $0.egalUnites(langue) }
    }

    /// Montre-t-on une traduction à côté de l'hébreu ? Non, en hébreu.
    public static func traduit(_ interfaceLangue: String) -> Bool {
        !normalise(interfaceLangue).egalUnites("he")
    }

    /// Le texte à montrer parmi ceux qu'on a, ou nil. `textes` est indexé par langue ; on ne rend que
    /// celui de la langue de l'interface, s'il n'est pas blanc — pas de repli, c'est tout l'objet de la règle.
    public static func choisit(_ interfaceLangue: String, _ textes: [String: String?]) -> String? {
        let langue = normalise(interfaceLangue)
        for (cle, valeur) in textes where cle.egalUnites(langue) {
            guard let texte = valeur, !texte.estBlanc else { return nil }
            return texte
        }
        return nil
    }

    /// « iw » est l'ancien code d'Android pour l'hébreu, encore rendu. « en-US », « fr_CA » → « en », « fr ».
    public static func normalise(_ etiquette: String?) -> String {
        let brute = (etiquette ?? "").avantUnites("-").avantUnites("_").lowercased()
        return brute.egalUnites("iw") ? "he" : brute
    }
}
