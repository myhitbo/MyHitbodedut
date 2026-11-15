import Foundation
import Testing
@testable import Coeur

/// AnneauxTest d'Android, porté : ce que mesurent les trois anneaux (demande du 01/10), le second tour au-delà de
/// l'objectif, les paliers de la série, et les anneaux fermés fêtés une fois (04/10). Les deux tests qui lisent le
/// code des écrans d'Android (dessin partagé, animation de l'accueil) y restent ; les libellés des anneaux sont
/// cherchés dans le catalogue exporté.
@Suite("Anneaux")
struct AnneauxTests {

    private let semaine = JaugeSemaine.Progression(faits: 4, dus: 6)

    private func proche(_ a: Float, _ b: Float) -> Bool { abs(a - b) <= 1e-6 }

    @Test func leJourMesureLesMinutesSurLObjectif() {
        let e = Anneaux.etat(minutesJour: 8, objectifJour: 15, semaine: semaine, serie: 4)
        #expect(e.jour.fait == 8)
        #expect(e.jour.objectif == 15)
        #expect(proche(e.jour.fraction, Float(8) / Float(15)))
        #expect(!e.jour.atteint)
        #expect(e.jour.tours == 0)
    }

    /// Comme chez Apple : l'anneau ne se ferme pas, il repasse sur lui-même.
    @Test func auDelaDeLObjectifLAnneauFaitUnSecondTour() {
        let e = Anneaux.etat(minutesJour: 23, objectifJour: 15, semaine: semaine, serie: 4)
        #expect(e.jour.atteint)
        #expect(e.jour.tours == 1)
        #expect(proche(e.jour.reste, Float(8) / Float(15)))
        let double = Anneaux.etat(minutesJour: 30, objectifJour: 15, semaine: semaine, serie: 4)
        #expect(double.jour.tours == 2)
        #expect(proche(double.jour.reste, 0))
    }

    @Test func laSemaineReprendLaJaugeExistante() {
        let e = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semaine, serie: 0)
        #expect(e.semaine.fait == 4)
        #expect(e.semaine.objectif == 6)
        #expect(proche(e.semaine.fraction, semaine.fraction))
    }

    @Test func laSerieViseLePremierPalierQuiLAtteint() {
        let cas = [(0, 7), (1, 7), (7, 7), (8, 14), (14, 14), (15, 30), (30, 30), (31, 60),
                   (100, 100), (101, 180), (365, 365), (366, 730), (730, 730), (731, 1095)]
        for (serie, palier) in cas {
            #expect(Anneaux.palier(serie) == palier, "série \(serie)")
        }
    }

    @Test func leJourDuPalierLAnneauDeLaSerieEstPlein() {
        let e = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semaine, serie: 7)
        #expect(e.serie.atteint)
        #expect(proche(e.serie.fraction, 1))
        // Le lendemain, le palier suivant commence.
        let lendemain = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semaine, serie: 8)
        #expect(!lendemain.serie.atteint)
        #expect(proche(lendemain.serie.fraction, Float(8) / Float(14)))
    }

    @Test func sansObjectifRienNeSeRemplitEtRienNePlante() {
        let e = Anneaux.etat(minutesJour: 10, objectifJour: 0, semaine: JaugeSemaine.Progression(faits: 0, dus: 0), serie: 0)
        #expect(proche(e.jour.fraction, 0))
        #expect(proche(e.semaine.fraction, 0))
        #expect(proche(e.serie.fraction, 0))
        #expect(!e.jour.atteint)
        // Des valeurs négatives (horloge reculée) sont ramenées à zéro.
        let recule = Anneaux.etat(minutesJour: -5, objectifJour: 15, semaine: semaine, serie: -2)
        #expect(recule.jour.fait == 0)
    }

    @Test func lObjectifQuotidienRetombeSurLaDureeHabituelle() {
        #expect(Anneaux.objectifEffectif(regle: 0, dureeHabituelle: 15) == 15)
        #expect(Anneaux.objectifEffectif(regle: 20, dureeHabituelle: 15) == 20)
        #expect(Anneaux.objectifEffectif(regle: 0, dureeHabituelle: 0) == 1)
    }

    @Test func duCentreVersLExterieurJourSemaineSerie() {
        let e = Anneaux.etat(minutesJour: 8, objectifJour: 15, semaine: semaine, serie: 4)
        let ordre = e.duCentre.map { $0.quel }
        #expect(ordre == [.jour, .semaine, .serie])
        #expect(e.anneau(.semaine) == e.semaine)
    }

    /// Les libellés des anneaux, dans les trois langues (la partie de « l accueil la vignette et les notifications
    /// dessinent les mêmes anneaux » qui ne lit pas de code d'Android).
    @Test func lesLibellesDesAnneauxExistentDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in ["settings_daily_goal", "ring_day_detail", "rings_description"] {
                #expect(chaines[cle] != nil, "\(langue) : \(cle)")
            }
            // Pluriels sur main : « %d jour » / « %d jours ».
            let pluriels = catalogue.pluriels(langue)
            for cle in ["ring_streak_detail", "ring_week_detail"] {
                #expect(pluriels[cle + "[other]"] != nil, "\(langue) : \(cle)")
            }
        }
    }

    // MARK: Animations automatiques (demande du 04/10)

    private let mercredi = JourCivil.du("2026-10-07")

    @Test func unAnneauFermeSeFeteUneFoisPuisPlus() {
        let plein = Anneaux.etat(minutesJour: 15, objectifJour: 15, semaine: semaine, serie: 4)
        #expect(Anneaux.aFeter(plein, aujourdhui: mercredi, dejaFetes: []) == [.jour])
        let deja = Anneaux.marques(plein, aujourdhui: mercredi)
        #expect(Anneaux.aFeter(plein, aujourdhui: mercredi, dejaFetes: deja).isEmpty)
        // Le lendemain, l'anneau du jour refermé se fête de nouveau.
        #expect(Anneaux.aFeter(plein, aujourdhui: mercredi.plus(jours: 1), dejaFetes: deja) == [.jour])
    }

    @Test func rienAFeterTantQuAucunAnneauNEstFerme() {
        let e = Anneaux.etat(minutesJour: 8, objectifJour: 15, semaine: semaine, serie: 4)
        #expect(Anneaux.aFeter(e, aujourdhui: mercredi, dejaFetes: []).isEmpty)
        #expect(Anneaux.marques(e, aujourdhui: mercredi).isEmpty)
    }

    @Test func laSemaineSeFeteUneFoisParSemaineEtLaSerieUneFoisParPalier() {
        let semainePleine = JaugeSemaine.Progression(faits: 6, dus: 6)
        let e = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semainePleine, serie: 7)
        #expect(Anneaux.aFeter(e, aujourdhui: mercredi, dejaFetes: []) == [.semaine, .serie])
        let deja = Anneaux.marques(e, aujourdhui: mercredi)
        // Jeudi, même semaine : rien de neuf pour la semaine.
        let jeudi = Anneaux.aFeter(e, aujourdhui: mercredi.plus(jours: 1), dejaFetes: deja)
        #expect(!jeudi.contains(.semaine))
        // Dimanche suivant : une autre semaine.
        let dimanche = Anneaux.aFeter(e, aujourdhui: .du("2026-10-11"), dejaFetes: deja)
        #expect(dimanche.contains(.semaine))
        // Le palier suivant de la série (14) se fête à son tour.
        let quatorze = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: JaugeSemaine.Progression(faits: 0, dus: 0), serie: 14)
        #expect(Anneaux.aFeter(quatorze, aujourdhui: mercredi, dejaFetes: deja) == [.serie])
    }

    /// La semaine se marque par son dimanche, comme `aujourdhui.minusDays(dayOfWeek % 7)`.
    @Test func laMarqueDeLaSemaineEstSonDimanche() {
        let pleine = Anneaux.Anneau(quel: .semaine, fait: 6, objectif: 6)
        for (jour, dimanche) in [("2026-10-04", "2026-10-04"), ("2026-10-07", "2026-10-04"), ("2026-10-10", "2026-10-04"),
                                 ("2026-10-11", "2026-10-11"), ("2027-01-01", "2026-12-27")] {
            #expect(Anneaux.marque(pleine, aujourdhui: .du(jour)) == "semaine:\(dimanche)")
        }
    }
}
