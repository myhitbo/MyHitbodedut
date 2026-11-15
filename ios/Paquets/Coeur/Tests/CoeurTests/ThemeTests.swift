import Foundation
import Testing
@testable import Coeur

/// ThemeTest d'Android, porté : le sujet d'une séance est FACULTATIF, « aucun » s'écrit par l'absence de valeur,
/// AUTRE est un sujet, une clé inconnue ne rompt pas, les clés sont stables. Ce que le test d'Android cherchait
/// dans le code de `Store.kt` (la journée porte ses sujets, l'import les réunit) est jugé ici par le modèle
/// lui-même (`Journee`, `Sauvegarde.importer`) ; l'ordre des appels dans `SessionService.kt` reviendra avec la
/// séance d'iOS (tâche 16). Les libellés sont cherchés dans le catalogue exporté.
@Suite("Theme")
struct ThemeTests {

    @Test func aucunSujetSEcritParLAbsenceDeValeur() {
        #expect(ThemeRules.parse("") == nil, "une clé vide ne vaut aucun sujet")
        #expect(ThemeRules.parse(nil) == nil)
        #expect(ThemeRules.parse("   ") == nil)
        // Aucun membre de la liste ne doit s'appeler « aucun » ou « none ».
        for theme in Theme.allCases {
            #expect(!["aucun", "none", "", "vide"].contains(theme.cle),
                    "« \(theme.cle) » : la liste ne doit pas contenir de sujet « aucun »")
        }
    }

    /// « Autre » n'est pas « aucun » : c'est un sujet choisi, simplement absent de la liste.
    @Test func autreEstUnSujetPasUneAbsence() {
        #expect(ThemeRules.parse("autre") == .autre)
    }

    /// Une clé inconnue rend nil au lieu de rompre : un journal exporté d'une version plus récente peut porter un
    /// sujet que celle-ci ignore.
    @Test func uneCleInconnueNeRomptPas() {
        #expect(ThemeRules.parse("teshouva_2031") == nil)
        #expect(ThemeRules.frequents(["parnassa", "inconnu", ""]) == [ThemeRules.Frequence(.parnassa, 1)])
    }

    @Test func lesClesSontDistinctesEtStables() throws {
        let cles = Theme.allCases.map { $0.cle }
        #expect(Set(cles).count == cles.count)
        let simple = try Motif("^[a-z_]+$")
        for cle in cles {
            #expect(simple.present(dans: cle), "« \(cle) » doit rester une clé simple")
        }
        // Les clés partent dans le journal : les renommer effacerait le passé.
        #expect(cles == ["emotions", "gratitude", "decisions", "famille", "zivoug",
                         "parnassa", "avoda", "difficultes", "croissance", "autre"])
    }

    @Test func lesSujetsFrequentsSeComptentDuPlusAuMoins() {
        let journal = ["parnassa", "famille", "parnassa", "zivoug", "parnassa", "famille"]
        #expect(ThemeRules.frequents(journal) == [ThemeRules.Frequence(.parnassa, 3), ThemeRules.Frequence(.famille, 2),
                                                  ThemeRules.Frequence(.zivoug, 1)])
        #expect(ThemeRules.frequents(journal, max: 2).count == 2)
        #expect(ThemeRules.frequents([]).isEmpty, "sans journal, aucun sujet fréquent")
    }

    /// La journée retient les sujets, et l'import les réunit plutôt que d'en perdre.
    @Test func laJourneeRetientLesSujetsEtLExportLesEmporte() throws {
        let jour = JourCivil.du("2026-10-07")
        var d = Donnees(journal: Journal(jours: [jour: Journee(minutes: 20, themes: ["famille"])]),
                        reglages: Reglages(enIsrael: false))
        let fichier = #"{"format":"myhitbodedut","version":1,"days":{"2026-10-07":{"minutes":15,"note":"","themes":["parnassa","famille"]}}}"#
        let lues = Sauvegarde.importer(fichier, dans: &d, aujourdhui: jour)
        #expect(lues == 1)
        let themes = try #require(d.journal.jours[jour]).themes
        #expect(themes == ["famille", "parnassa"])
        let exporte = Sauvegarde.exporter(d, maintenant: 0)
        #expect(exporte.contains("\"parnassa\""))
    }

    @Test func chaqueSujetASonLibelleDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let cles = Theme.allCases.map { $0.titre } +
            ["session_theme_title", "session_theme_none", "session_theme_none_short", "session_theme_chosen"]
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles { #expect(chaines[cle] != nil, "\(langue) : « \(cle) » manquant") }
        }
    }
}
