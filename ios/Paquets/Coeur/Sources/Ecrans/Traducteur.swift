import Foundation
import Coeur

/// La résolution d'un `Libelle` dans la langue de l'app, depuis le catalogue exporté
/// (`ios/Ressources/Chaines/Localizable.xcstrings`, écrit par tools/export_contenu d'après les strings.xml
/// d'Android) : `getString` et `getQuantityString`, comme Android les résout.
///
/// - Ce qu'une langue ne traduit pas retombe sur le français, la langue de `values/strings.xml` d'Android.
/// - Un pluriel traduit dans la langue garde ses seules formes, et sa forme « other » à défaut de celle de la
///   quantité ; un pluriel qu'elle ne traduit pas prend les formes du français (comme LibelleTests).
/// - Rien ne se résout (clé absente, argument manquant) : la clé elle-même, pour ne jamais rien montrer de vide.
///
/// La mise en forme est celle de Coeur (`Libelle.texte(langue:chaine:pluriel:)`, `String.format` de Java).
public struct Traducteur: Sendable {

    /// Les langues de l'app : le français, l'anglais, l'hébreu, et depuis le 17/11 l'espagnol (`values-es`) et
    /// l'arabe tunisien (`values-ar-rTN`, « ar » dans le catalogue), qui ne traduisent que l'interface.
    public static let langues = ["fr", "en", "he", "es", "ar"]
    /// Où se replie ce que la langue ne traduit pas.
    public static let repli = "fr"

    /// « fr », « en », « he », « es » ou « ar ».
    public let langue: String

    /// Langue → clé → gabarit.
    private let simples: [String: [String: String]]
    /// Langue → clé → forme (« one », « two », « other ») → gabarit.
    private let pluriels: [String: [String: [String: String]]]

    /// Le catalogue lu depuis ses octets (le JSON de `Localizable.xcstrings`) ; `langue` est un code du catalogue
    /// (`langues`), pris tel quel, ou passe par `langueApp`.
    /// Lève si les octets ne sont pas un catalogue.
    public init(catalogue: Data, langue: String) throws {
        let fichier = try JSONDecoder().decode(Fichier.self, from: catalogue)
        var simples: [String: [String: String]] = [:]
        var pluriels: [String: [String: [String: String]]] = [:]
        for (cle, entree) in fichier.strings {
            for (code, traduction) in entree.localizations ?? [:] {
                // « iw », l'ancien code de l'hébreu qu'Android garde, se lit « he ».
                let ici = code == "iw" ? "he" : code
                if let valeur = traduction.stringUnit?.value {
                    simples[ici, default: [:]][cle] = valeur
                }
                var formes: [String: String] = [:]
                for (forme, variante) in traduction.variations?.plural ?? [:] {
                    if let valeur = variante.stringUnit?.value {
                        formes[forme] = valeur
                    }
                }
                if !formes.isEmpty {
                    pluriels[ici, default: [:]][cle] = formes
                }
            }
        }
        self.init(langue: langue, simples: simples, pluriels: pluriels)
    }

    /// Des gabarits déjà lus, pour un aperçu : langue → clé → gabarit, et langue → clé → forme → gabarit.
    public init(langue: String, simples: [String: [String: String]],
                pluriels: [String: [String: [String: String]]] = [:]) {
        // Un code du catalogue est déjà une langue de l'app : « ar » est l'arabe tunisien que le catalogue
        // porte (iOS ne rend en `preferredLocalizations` qu'une localisation livrée) ; le reste, un code du
        // téléphone, passe par la règle d'Android.
        self.langue = Traducteur.langues.contains(langue) ? langue : Traducteur.langueApp(langue)
        self.simples = simples
        self.pluriels = pluriels
    }

    /// La langue de l'app d'après un code de localisation (`Bundle.main.preferredLocalizations.first`) :
    /// « he » et « iw » (le code qu'Android garde) se lisent « he », « fr-CA » se lit « fr », « es-MX » se lit
    /// « es » ; l'arabe n'est livré qu'en Tunisie (« ar-TN », « ar_TN » se lisent « ar », LangueApp.livree) ;
    /// toute autre langue se lit « en », la région de développement (PORTAGE.md § 2.2.7, LangueApp d'Android).
    public static func langueApp(_ code: String?) -> String {
        guard let code else { return "en" }
        let parties = code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
        switch parties.first ?? "" {
        case "fr": return "fr"
        case "he", "iw": return "he"
        case "es": return "es"
        case "ar": return parties.dropFirst().contains("tn") ? "ar" : "en"
        default: return "en"
        }
    }

    /// Le texte du libellé dans la langue de l'app ; sa clé si rien ne se résout.
    public func texte(_ libelle: Libelle) -> String {
        let resolu = libelle.texte(langue: langue,
                                   chaine: { cle in gabarit(cle) },
                                   pluriel: { cle, forme in gabarit(cle, forme: forme) })
        return resolu ?? libelle.cle
    }

    /// Le texte d'une chaîne simple, sans argument (`getString(R.string.cle)`).
    public func texte(cle: String) -> String {
        texte(Libelle(cle))
    }

    /// Le gabarit d'une chaîne simple : celui de la langue, sinon celui du français.
    private func gabarit(_ cle: String) -> String? {
        simples[langue]?[cle] ?? simples[Traducteur.repli]?[cle]
    }

    /// Le gabarit d'une forme de pluriel : parmi les formes de la langue si elle traduit ce pluriel, sinon
    /// parmi celles du français.
    private func gabarit(_ cle: String, forme: String) -> String? {
        let formes = pluriels[langue]?[cle] ?? pluriels[Traducteur.repli]?[cle]
        return formes?[forme]
    }

    /// Ce que le catalogue écrit : `strings` → clé → `localizations` → langue → `stringUnit` ou
    /// `variations.plural` → forme → `stringUnit`. Le reste (`state`, `version`…) est ignoré.
    private struct Fichier: Decodable {
        struct Unite: Decodable {
            let value: String
        }
        struct Forme: Decodable {
            let stringUnit: Unite?
        }
        struct Variations: Decodable {
            let plural: [String: Forme]?
        }
        struct Traduction: Decodable {
            let stringUnit: Unite?
            let variations: Variations?
        }
        struct Entree: Decodable {
            let localizations: [String: Traduction]?
        }

        let strings: [String: Entree]
    }
}
