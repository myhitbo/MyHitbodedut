import Foundation
import Testing
@testable import Coeur

/// SourceDuJourTest d'Android, porté : un paragraphe des sources libres, le même toute la journée, et le
/// même que le web (web/test/regles.test.mjs). Reste à Android la vérification que MainActivity pose la
/// carte : elle lit le code d'un écran, et reviendra avec l'accueil (ROADMAP, tâche 15).
@Suite("Source du jour")
struct SourceDuJourTests {

    private func bibliotheque() throws -> Bibliotheque { try Corpus.bibliotheque.get() }

    private func ici(_ jour: String) throws -> (String, Int?) {
        let b = try bibliotheque()
        let p = try #require(SourceDuJour.choix(b, .du(jour)))
        return (p.source.id, b.paragraphes(de: p.source).firstIndex { $0.egalUnites(p.texte) })
    }

    @Test func leMemeParagrapheQueLeWebLeMemeJour() throws {
        let a = try ici("2026-10-19"), b = try ici("2026-10-20"), c = try ici("2027-01-01")
        #expect(a.0 == "src-lm2-25" && a.1 == 9)
        #expect(b.0 == "src-lt-zera" && b.1 == 1)
        #expect(c.0 == "src-lt-zera" && c.1 == 2)
    }

    @Test func seulesLesSourcesJamaisLesArticlesEtAssezLongues() throws {
        let c = SourceDuJour.candidats(try bibliotheque())
        #expect(c.count > 50)
        let courts = c.filter { $0.texte.utf16.count < SourceDuJour.min }
        #expect(courts.isEmpty)
        let e = SourceDuJour.extrait(String(repeating: "א", count: 10) + " " + String(repeating: "ב", count: 400))
        #expect(e.hasSuffix("…"))
    }
}
