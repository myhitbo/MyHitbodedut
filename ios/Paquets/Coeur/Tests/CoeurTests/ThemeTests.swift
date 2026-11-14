import Foundation
import Testing
@testable import Coeur

/// ThemeTest d'Android, porté : le sujet d'une séance est facultatif, et « aucun » s'écrit par
/// l'absence de valeur. Puis la part de Theme.kt dans `Tests/Vecteurs/guidee.json`. Les libellés se
/// lisent dans le catalogue exporté. Reste à Android le test qui lit Store.kt et SessionService.kt
/// (la journée retient les sujets, l'export les emporte) : son pendant viendra avec le journal et la
/// sauvegarde d'iOS (tâche 7).
@Suite("Sujets")
struct ThemeTests {

    private struct Vecteurs: Decodable {
        struct ThemeLu: Decodable {
            let nom: String
            let cle: String
            let titre: String
        }
        struct Lecture: Decodable {
            let cle: String?
            let theme: String?
        }
        struct Compte: Decodable {
            struct Paire: Decodable {
                let theme: String
                let nombre: Int
            }
            let cles: [String]
            /// nil : la valeur par défaut de Kotlin.
            let max: Int?
            /// Kotlin lève une exception (plafond négatif) ; `resultat` est alors nil.
            let leve: Bool
            let resultat: [Paire]?
        }

        let themes: [ThemeLu]
        let themesLus: [Lecture]
        let frequents: [Compte]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/guidee.json"))
    }

    /// Une clé et ses points de code, pour qu'un blanc invisible se lise dans un message d'échec.
    private func codes(_ texte: String?) -> String {
        guard let texte else { return "nil" }
        let points = texte.unicodeScalars.map { String($0.value, radix: 16) }
        return "« \(texte) » [" + points.joined(separator: " ") + "]"
    }

    @Test func aucunSujetSEcritParLAbsenceDeValeur() {
        let vide = ThemeRules.parse("")
        let absent = ThemeRules.parse(nil)
        let blanc = ThemeRules.parse("   ")
        #expect(vide == nil, "une clé vide ne vaut aucun sujet")
        #expect(absent == nil)
        #expect(blanc == nil)
        // Aucun membre de la liste ne doit s'appeler « aucun » ou « none ».
        for theme in Theme.allCases {
            let interdite = ["aucun", "none", "", "vide"].contains(theme.cle)
            #expect(!interdite, "« \(theme.cle) » : la liste ne doit pas contenir de sujet « aucun »")
        }
    }

    /// « Autre » n'est pas « aucun » : c'est un sujet choisi, simplement absent de la liste.
    @Test func autreEstUnSujetPasUneAbsence() {
        let autre = ThemeRules.parse("autre")
        #expect(autre == Theme.autre)
    }

    /// Une clé inconnue rend nil au lieu de rompre : un journal exporté d'une version plus récente
    /// peut porter un sujet que celle-ci ignore.
    @Test func uneCleInconnueNeRomptPas() {
        let inconnue = ThemeRules.parse("teshouva_2031")
        let frequents = ThemeRules.frequents(["parnassa", "inconnu", ""])
        let attendus = [ThemeRules.Frequence(Theme.parnassa, 1)]
        #expect(inconnue == nil)
        #expect(frequents == attendus)
    }

    @Test func lesClesSontDistinctesEtStables() {
        let cles = Theme.allCases.map { $0.cle }
        let distinctes = Set(cles).count
        #expect(distinctes == cles.count)
        let simple = ExpressionReguliere("^[a-z_]+$")
        for cle in cles {
            let estSimple = simple.couvre(cle)
            #expect(estSimple, "« \(cle) » doit rester une clé simple")
        }
        // Les clés partent dans le journal : les renommer effacerait le passé.
        let attendues = ["emotions", "gratitude", "decisions", "famille", "zivoug",
                         "parnassa", "avoda", "difficultes", "croissance", "autre"]
        #expect(cles == attendues)
    }

    @Test func lesSujetsFrequentsSeComptentDuPlusAuMoins() {
        let journal = ["parnassa", "famille", "parnassa", "zivoug", "parnassa", "famille"]
        let frequents = ThemeRules.frequents(journal)
        let attendus = [ThemeRules.Frequence(Theme.parnassa, 3), ThemeRules.Frequence(Theme.famille, 2),
                        ThemeRules.Frequence(Theme.zivoug, 1)]
        let deux = ThemeRules.frequents(journal, max: 2).count
        let sansJournal = ThemeRules.frequents([]).isEmpty
        #expect(frequents == attendus)
        #expect(deux == 2)
        #expect(sansJournal, "sans journal, aucun sujet fréquent")
    }

    @Test func chaqueSujetASonLibelleDansLesTroisLangues() throws {
        let cles = Theme.allCases.map { "theme_\($0.cle)" } +
            ["session_theme_title", "session_theme_none", "session_theme_none_short", "session_theme_chosen"]
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                let presente = chaines[cle] != nil
                #expect(presente, "\(langue) : « \(cle) » manquant")
            }
        }
    }

    @Test func lesVecteursDeLaJVMSontRejoues() throws {
        let v = try vecteurs()
        let sujets = Theme.allCases
        let n = sujets.count
        let lus = v.themes.count
        #expect(n == lus, "nombre de sujets")
        for (theme, lu) in zip(sujets, v.themes) {
            #expect(theme.cle == lu.cle, "\(lu.nom) : clé")
            #expect(theme.titre == lu.titre, "\(lu.nom) : libellé")
        }

        for lecture in v.themesLus {
            let rendu = ThemeRules.parse(lecture.cle)?.cle
            let ou = codes(lecture.cle)
            #expect(rendu == lecture.theme, "parse(\(ou))")
        }

        for compte in v.frequents {
            let rendus: [ThemeRules.Frequence]
            if let plafond = compte.max {
                rendus = ThemeRules.frequents(compte.cles, max: plafond)
            } else {
                rendus = ThemeRules.frequents(compte.cles)
            }
            let ou = "frequents(\(compte.cles), max: \(compte.max.map { String($0) } ?? "défaut"))"
            let rendusLus = rendus.map { "\($0.theme.cle)=\($0.nombre)" }
            // Là où Kotlin lève une exception, Swift rend une liste vide.
            let attendus = (compte.resultat ?? []).map { "\($0.theme)=\($0.nombre)" }
            let leveSansResultat = compte.leve == (compte.resultat == nil)
            #expect(leveSansResultat, "\(ou) : vecteur incohérent")
            #expect(rendusLus == attendus, "\(ou)")
        }
    }
}
