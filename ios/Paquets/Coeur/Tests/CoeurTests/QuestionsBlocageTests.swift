import Foundation
import Testing
@testable import Coeur

/// QuestionsBlocageTest d'Android, porté (« Je ne sais pas quoi dire » et « Commencer simplement »,
/// propositions 3 et 15, 19/10), puis la part de QuestionsBlocage.kt dans `Tests/Vecteurs/guidee.json`.
/// Les chaînes se lisent dans le catalogue exporté ; reste à Android la place des questions et des
/// quatre entrées dans les deux gabarits de l'écran de séance (layout et layout-land).
@Suite("Questions du blocage")
struct QuestionsBlocageTests {

    private struct Vecteurs: Decodable {
        struct Suivante: Decodable {
            let i: Int
            let suivante: Int
        }
        struct Debordement: Decodable {
            let fonction: String
            let entree: Int
            let kotlin: Int
        }

        let questions: [String]
        let suivantes: [Suivante]
        let debordements: [Debordement]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/guidee.json"))
    }

    @Test func dixQuestionsUneALaFoisPuisOnRecommence() {
        let n = QuestionsBlocage.questions.count
        let apresAucune = QuestionsBlocage.suivante(-1)
        let apresPremiere = QuestionsBlocage.suivante(0)
        let apresDerniere = QuestionsBlocage.suivante(9)
        #expect(n == 10)
        #expect(apresAucune == 0)
        #expect(apresPremiere == 1)
        #expect(apresDerniere == 0)
    }

    @Test func lesQuestionsEtLesQuatreEntreesExistentDansLesTroisLangues() throws {
        let cles = ["question_merci", "question_fin", "question_suivante", "question_rang",
                    "simplement_parler", "simplement_ecrire", "simplement_prier", "simplement_question"]
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles + QuestionsBlocage.questions {
                let presente = chaines[cle] != nil
                #expect(presente, "\(langue) : \(cle)")
            }
        }
    }

    /// Swift compte sur 64 bits et s'arrête au débordement : le plus grand de ses entiers rend encore
    /// une question, celle qui suit la question de l'entier d'avant.
    @Test func lePlusGrandEntierDeSwiftRendEncoreUneQuestion() {
        let n = QuestionsBlocage.questions.count
        let auBout = QuestionsBlocage.suivante(Int.max)
        let avant = QuestionsBlocage.suivante(Int.max - 1)
        let auPlusBas = QuestionsBlocage.suivante(Int.min)
        let dansLaListe = (0..<n).contains(auBout)
        let attendu = (avant + 1) % n
        #expect(dansLaListe)
        #expect(auBout == attendu)
        #expect(auPlusBas == 0)
    }

    @Test func lesVecteursDeLaJVMSontRejoues() throws {
        let v = try vecteurs()
        #expect(QuestionsBlocage.questions == v.questions)
        for s in v.suivantes {
            let rendu = QuestionsBlocage.suivante(s.i)
            #expect(rendu == s.suivante, "suivante(\(s.i))")
        }
        // Le seul écart voulu : (i + 1) % 10 déborde en Kotlin pour Int.MAX_VALUE (et rend −8, qui
        // n'est le rang d'aucune question) ; le même calcul, sur les 64 bits de Swift, ne déborde pas.
        let debordements = v.debordements.filter { $0.fonction == "QuestionsBlocage.suivante" }
        let nDebordements = debordements.count
        #expect(nDebordements == 1)
        let n = QuestionsBlocage.questions.count
        for d in debordements {
            let rendu = QuestionsBlocage.suivante(d.entree)
            let exact = (d.entree + 1) % n
            #expect(rendu == exact, "suivante(\(d.entree)) : Kotlin y déborde et rend \(d.kotlin)")
        }
    }
}
