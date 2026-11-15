import Foundation
import Testing
@testable import Coeur

/// QuestionsBlocageTest d'Android : « Je ne sais pas quoi dire » et « Commencer simplement » (propositions 3 et 15,
/// 19/10). Les deux orientations de activity_session.xml restent à Android ; les chaînes se vérifient ici dans le
/// catalogue exporté.
@Suite("QuestionsBlocage")
struct QuestionsBlocageTests {

    @Test func dixQuestionsUneALaFoisPuisOnRecommence() {
        #expect(QuestionsBlocage.questions.count == 10)
        #expect(QuestionsBlocage.suivante(-1) == 0)
        #expect(QuestionsBlocage.suivante(0) == 1)
        #expect(QuestionsBlocage.suivante(9) == 0)
    }

    @Test func lesQuestionsEtLesQuatreEntreesExistentDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let cles = ["question_merci", "question_fin", "question_suivante", "question_rang",
                    "simplement_parler", "simplement_ecrire", "simplement_prier", "simplement_question"]
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            // Les questions sont nommées par leur clé : chacune doit être dans le catalogue.
            for cle in cles + QuestionsBlocage.questions {
                let present = !(chaines[cle] ?? "").estBlanc
                #expect(present, "\(langue) : \(cle)")
            }
        }
    }
}
