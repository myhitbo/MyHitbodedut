import Foundation
import Testing
@testable import Coeur

/// ParcoursTest d'Android : « Mon parcours » (proposition 6, 19/10), les chiffres, les sujets fréquents, l'humeur.
/// « L'accueil ouvre la page, dans les deux orientations » lit activity_main.xml : il reste à Android.
@Suite("Parcours")
struct ParcoursTests {

    @Test func leBilanCompteLesJoursFaitsLeTempsEtLesSujets() {
        let jours = [
            Journee(minutes: 20, note: "", themes: ["famille", "parnassa"]),
            Journee(minutes: 10, note: "", themes: ["famille"]),
            Journee(minutes: 0, note: "une note", themes: [], noteSeule: true),
        ]
        let b = Parcours.bilan(jours)
        #expect(b.jours == 2)
        #expect(b.minutes == 30)
        #expect(b.moyenne == 15)
        #expect(b.sujets == [ThemeRules.Frequence(.famille, 2), ThemeRules.Frequence(.parnassa, 1)])
        let aucun: [Journee] = []
        #expect(Parcours.bilan(aucun).moyenne == 0)
    }

    @Test func lHumeurMoyenneNeCompteQueLesJoursNotesAvantEtApres() {
        #expect(Parcours.humeur([JournalPlus(avant: 2)]) == nil)
        let plus = [JournalPlus(avant: 2, apres: 4), JournalPlus(avant: 2, apres: 4), JournalPlus(apres: 5)]
        #expect(Parcours.humeur(plus) == Parcours.Humeur(avant: 2, apres: 4, jours: 2))
    }

    /// `Math.round` : les demis vont vers le haut, la moyenne comme l'humeur.
    @Test func lesMoyennesSArrondissentCommeAndroid() {
        let deux = [Journee(minutes: 2), Journee(minutes: 3)]
        #expect(Parcours.bilan(deux).moyenne == 3)
        let trois = [Journee(minutes: 1), Journee(minutes: 1), Journee(minutes: 2)]
        #expect(Parcours.bilan(trois).moyenne == 1)
        let plus = [JournalPlus(avant: 2, apres: 3), JournalPlus(avant: 3, apres: 4)]
        #expect(Parcours.humeur(plus) == Parcours.Humeur(avant: 3, apres: 4, jours: 2))
    }

    /// Les sujets se comptent sur toutes les journées, une note seule comprise ; cinq au plus, à égalité dans l'ordre
    /// des sujets ; une clé inconnue est ignorée.
    @Test func lesSujetsSontLesCinqPlusFrequents() {
        let jours = [
            Journee(minutes: 0, note: "", themes: ["autre", "gratitude"], noteSeule: true),
            Journee(minutes: 5, themes: ["croissance", "gratitude", "inconnu", "avoda", "emotions", "famille"]),
        ]
        let sujets = Parcours.bilan(jours).sujets
        let attendus = [ThemeRules.Frequence(.gratitude, 2), ThemeRules.Frequence(.emotions, 1),
                        ThemeRules.Frequence(.famille, 1), ThemeRules.Frequence(.avoda, 1),
                        ThemeRules.Frequence(.croissance, 1)]
        #expect(sujets == attendus)
    }

    /// Le journal entier, comme l'écran : l'humeur des seules journées inscrites.
    @Test func leJournalDonneLeBilanEtLHumeurDeSesJournees() {
        let premier = JourCivil.du("2026-10-01"), second = JourCivil.du("2026-10-02"), seul = JourCivil.du("2026-10-03")
        let journal = Journal(jours: [premier: Journee(minutes: 20), second: Journee(minutes: 10)],
                              plus: [premier: JournalPlus(avant: 1, apres: 5), seul: JournalPlus(avant: 5, apres: 5)])
        let b = Parcours.bilan(journal)
        #expect(b.jours == 2)
        #expect(b.minutes == 30)
        #expect(Parcours.humeur(journal) == Parcours.Humeur(avant: 1, apres: 5, jours: 1))
        #expect(Parcours.humeur(Journal()) == nil)
    }
}
