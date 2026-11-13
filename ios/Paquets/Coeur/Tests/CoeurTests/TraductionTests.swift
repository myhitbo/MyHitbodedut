import Foundation
import Testing
@testable import Coeur

/// TraductionTest d'Android, porté sur ce qu'iOS livre : `Localizable.xcstrings`, que l'export
/// écrit d'après les trois strings.xml (français, anglais, hébreu). Ce qui se vérifie n'est pas
/// « le fichier existe » mais « aucun texte ne peut échapper à la traduction ».
///
/// Restent à Android : « aucun texte écrit en dur dans un layout ni dans le code », qui lit ses
/// layouts et son Kotlin ; l'équivalent pour SwiftUI viendra avec les premiers écrans (tâche 14).
@Suite("Traduction")
struct TraductionTests {

    private let langues = Catalogue.langues

    /// Les marqueurs d'Android (`%1$s`, `%s`, `%d`, `%%`) tels que l'export les écrit pour iOS.
    private func marqueurs(_ motif: Motif, _ s: String) -> [String] { motif.groupes(s).sorted() }

    @Test func lesTroisLanguesPortentLeMemeJeuDeCles() throws {
        let c = try Catalogue.lire()
        #expect(c.sourceLanguage == "fr")
        #expect(c.strings.count > 200, "aucune chaîne lue : la lecture est cassée")
        for (cle, entree) in c.strings {
            #expect(Set(entree.localizations.keys) == Set(langues), "\(cle) : langues \(entree.localizations.keys.sorted())")
            let natures = Set(entree.localizations.values.map { $0.variations != nil })
            #expect(natures.count == 1, "\(cle) : simple dans une langue, pluriel dans une autre")
        }
        let reference = Set(c.simples("fr").keys)
        for langue in langues.dropFirst() {
            let autres = Set(c.simples(langue).keys)
            #expect(reference.subtracting(autres).sorted() == [], "\(langue) : clés manquantes")
            #expect(autres.subtracting(reference).sorted() == [], "\(langue) : clés en trop")
        }
        // Sans les chaînes propres à Android (divulgations Play, batterie, superposition).
        let propres = c.strings.keys.filter {
            $0.hasPrefix("divulgation_") || $0.hasPrefix("permission_battery") || $0.hasPrefix("permission_overlay")
        }
        #expect(propres.isEmpty, "\(propres.sorted())")
    }

    @Test func chaquePlurielASesFormesDansChaqueLangue() throws {
        // L'hébreu porte en plus la forme duelle « two », que le français et l'anglais n'ont pas :
        // « one » et « other » doivent être là, les listes n'ont pas à être identiques.
        let c = try Catalogue.lire()
        let attendus = Set(c.pluriels("fr").keys)
        #expect(!attendus.isEmpty)
        for langue in langues {
            let siens = Set(c.pluriels(langue).keys)
            #expect(attendus.isSubset(of: siens), "\(langue) : formes de pluriel manquantes \(attendus.subtracting(siens).sorted())")
        }
    }

    @Test func aucuneTraductionNEstVide() throws {
        let c = try Catalogue.lire()
        for langue in langues {
            for (cle, valeur) in c.simples(langue).merging(c.pluriels(langue), uniquingKeysWith: { a, _ in a }) {
                #expect(!valeur.blanc, "\(langue)/\(cle) est vide")
            }
        }
    }

    @Test func lesMarqueursDeFormatSontLesMemesPartout() throws {
        let c = try Catalogue.lire()
        let motif = try Motif(#"%\d+\$(?:@|lld)|%(?:@|lld)|%%"#)
        let fr = c.simples("fr")
        for langue in langues.dropFirst() {
            for (cle, valeur) in c.simples(langue) {
                guard let reference = fr[cle] else { continue }
                #expect(marqueurs(motif, valeur) == marqueurs(motif, reference),
                        "\(langue)/\(cle) : « \(valeur) » n'a pas les mêmes marqueurs que « \(reference) »")
            }
            // Pour les pluriels, « other » de la même langue fait foi : « הוגדרה שעה אחת » se passe
            // légitimement du chiffre au singulier.
            let pluriels = c.pluriels(langue)
            for (forme, valeur) in pluriels {
                let nom = forme.prefix(while: { $0 != "[" })
                guard let other = pluriels["\(nom)[other]"] else { continue }
                let permis = marqueurs(motif, other)
                #expect(marqueurs(motif, valeur).allSatisfy { permis.contains($0) },
                        "\(langue)/\(forme) : « \(valeur) » invente un marqueur absent de « \(other) »")
            }
        }
    }

    /// Ce qu'on a appris en ajoutant puis retirant l'espagnol (22/09) : une quatrième langue posée
    /// dans les chaînes sans être nommée par `TexteLocalise.pour` verrait les titres des contenus
    /// en hébreu, sans que rien ne le signale. Le test garde la trace de ce qu'il faudra toucher.
    @Test func uneLangueAjouteeSansEtreNommeeSeraitServieEnHebreu() throws {
        let c = try Catalogue.lire()
        let posees = Set(c.strings.values.flatMap(\.localizations.keys))
        #expect(posees.contains("en"), "aucune langue trouvée : la lecture est cassée")
        let temoin = TexteLocalise(he: "he", fr: "fr", en: "en")
        for langue in posees.sorted() {
            #expect(temoin.pour(langue) == langue, "« \(langue) » est dans les chaînes, TexteLocalise.pour ne la nomme pas")
        }
        // Un titre sans traduction prend l'hébreu, seul champ sûrement rempli.
        let seul = TexteLocalise(he: "שם", fr: " ", en: "")
        #expect(seul.pour("fr") == "שם" && seul.pour("en") == "שם")
    }

    /// Les dix conseils ont été fournis en hébreu, qui dit « השם » : les traductions écrivaient
    /// « Dieu » et « God », quand les textes de 'hizouk disaient déjà « Hachem ».
    @Test func leNomDivinNEstPasTraduit() throws {
        let c = try Catalogue.lire()
        let fr = c.simples("fr"), en = c.simples("en"), he = c.simples("he")
        // « השם המקורי » veut dire « le nom d'origine » : ce n'est pas Lui.
        let nom = try Motif("השם(?! המקורי)|ה׳"), dieu = try Motif(#"\bDieu\b"#), god = try Motif(#"\bGod\b"#)
        var vus = 0
        for (cle, source) in he where fr[cle] != nil && nom.present(dans: source) {
            vus += 1
            #expect(!dieu.present(dans: fr[cle] ?? ""), "\(cle) : la source dit « השם », le français dit « Dieu »")
            #expect(!god.present(dans: en[cle] ?? ""), "\(cle) : la source dit « השם », l'anglais dit « God »")
        }
        #expect(vus >= 5, "aucune source hébraïque portant le Nom : la lecture est cassée")
    }

    /// « Parnassa » d'un côté et « Gagner sa vie » de l'autre désignaient la même chose sur deux
    /// écrans de la même application.
    @Test func lesTermesHebreuxDesSujetsDePriereNeSontPasTraduits() throws {
        let attendus = [
            ("tefila_simcha", "Sim’ha", "Simcha"),
            ("tefila_kdusha", "Kedoucha", "Kedusha"),
            ("tefila_parnassa", "Parnassa", "Parnassa"),
            ("tefila_geula", "Guéoula", "Geula"),
            ("tefila_zivug", "Zivoug", "Zivug"),
            ("tefila_refua", "Refoua chelema", "Refua shelema"),
            ("tefila_brit", "Chmirat habrit", "Shmirat habrit"),
            ("tefila_zera", "Zéra chel kayama", "Zera shel kayama"),
        ]
        let c = try Catalogue.lire()
        let fr = c.simples("fr"), en = c.simples("en")
        for (cle, francais, anglais) in attendus {
            #expect(fr[cle] == francais, "\(cle) en français")
            #expect(en[cle] == anglais, "\(cle) en anglais")
        }
    }

    @Test func lesTitresDeLaBibliothequeExistentDansLesTroisLangues() throws {
        let b = try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
        var vus = 0
        for section in b.sections {
            for (id, titre) in [(section.id, section.titre)] + section.sousSections.map({ ($0.id, $0.titre) }) {
                for (langue, valeur) in [("he", titre.he), ("fr", titre.fr), ("en", titre.en)] {
                    #expect(!valeur.blanc, "\(id) n'a pas de titre en « \(langue) »")
                }
                vus += 1
            }
        }
        #expect(vus >= 4, "aucun titre lu : la lecture est cassée")
    }
}
