import Foundation
import Testing
@testable import Coeur

/// Ce que l'accueil d'Android tire de `Store.kt` et de `Character.kt` sans test qui lui soit propre : la série
/// (`Store.streak`), la meilleure série, les anneaux d'un journal, l'illustration du jour, l'ajout de temps.
@Suite("Accueil")
struct AccueilTests {

    private let jeudi = JourCivil.du("2026-10-08")

    private func jours(_ isos: String...) -> Set<JourCivil> { Set(isos.map { JourCivil.du($0) }) }

    @Test func laSerieCompteJusquAHierTantQueLeJourResteAFaire() {
        let faits = jours("2026-10-05", "2026-10-06", "2026-10-07")
        let aFaire = Pratique.serie(faits: faits, aujourdhui: jeudi) { _ in false }
        #expect(aFaire == 3)
        let fait = Pratique.serie(faits: faits.union([jeudi]), aujourdhui: jeudi) { _ in false }
        #expect(fait == 4)
        // Un jour manqué casse ; un jour exempté ne compte pas et ne casse pas.
        let trou = Pratique.serie(faits: jours("2026-10-05", "2026-10-07"), aujourdhui: jeudi) { _ in false }
        #expect(trou == 1)
        let exempte = JourCivil.du("2026-10-06")
        let pont = Pratique.serie(faits: jours("2026-10-05", "2026-10-07"), aujourdhui: jeudi) { $0 == exempte }
        #expect(pont == 2)
        // Aujourd'hui exempté et rien de fait : la série d'hier tient.
        let chabbat = JourCivil.du("2026-10-10")
        let samedi = Pratique.serie(faits: jours("2026-10-08", "2026-10-09"), aujourdhui: chabbat) { $0 == chabbat }
        #expect(samedi == 2)
        let vide = Pratique.serie(faits: [], aujourdhui: jeudi) { _ in false }
        #expect(vide == 0)
    }

    @Test func laMeilleureSerieEstAuMoinsLaSerieEnCours() {
        let faits = jours("2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-10-07")
        let meilleure = Pratique.meilleureSerie(faits: faits, aujourdhui: jeudi) { _ in false }
        #expect(meilleure == 4)
    }

    @Test func lesAnneauxDUnJournal() {
        var reglages = Reglages(enIsrael: false)
        reglages.duree = 20
        let journal = Journal(jours: [
            .du("2026-10-07"): Journee(minutes: 15),
            jeudi: Journee(minutes: 8),
            .du("2026-10-06"): Journee(minutes: 0, note: "une pensée", noteSeule: true),
        ])
        let e = Pratique.anneaux(Donnees(journal: journal, reglages: reglages), aujourdhui: jeudi) { $0.jourDeSemaine == 7 }
        #expect(e.jour == Anneaux.Anneau(quel: .jour, fait: 8, objectif: 20))
        // Dimanche 4 au samedi 10 : deux jours faits ; le samedi n'est pas dû.
        #expect(e.semaine == Anneaux.Anneau(quel: .semaine, fait: 2, objectif: 6))
        #expect(e.serie == Anneaux.Anneau(quel: .serie, fait: 2, objectif: 7))
        reglages.objectifJour = 30
        #expect(Pratique.objectifJour(reglages) == 30)
    }

    @Test func lIllustrationChangeChaqueJourEtExiste() throws {
        let images = ImagesDuPersonnage.appels + ImagesDuPersonnage.pendants + ImagesDuPersonnage.joies +
            [ImagesDuPersonnage.journal, ImagesDuPersonnage.etude, ImagesDuPersonnage.lecture, "char_welcome"]
        let dossier = Depot.racine.appendingPathComponent("ios/Ressources/Images")
        let fichiers = try FileManager.default.contentsOfDirectory(atPath: dossier.path)
        let presentes = Set(fichiers.map { $0.components(separatedBy: ".").first ?? $0 })
        for image in images { #expect(presentes.contains(image), "\(image) absente") }
        // Le 1er janvier 1970 plus une semaine (sel 1) : le premier appel ; le lendemain, le suivant.
        let origine = JourCivil.du("1970-01-01")
        #expect(ImagesDuPersonnage.appel(origine.plus(jours: -7)) == "char_praise")
        #expect(ImagesDuPersonnage.appel(origine.plus(jours: -6)) == "char_pointing")
        #expect(ImagesDuPersonnage.appel(origine.plus(jours: -8)) == "char_open_arms")
        #expect(ImagesDuPersonnage.accueil(faite: false, jour: jeudi) == "char_welcome")
        #expect(ImagesDuPersonnage.accueil(faite: true, jour: jeudi) == ImagesDuPersonnage.joie(jeudi))
    }

    @Test func leTempsSAjouteJusquAAujourdhuiJamaisAuLendemain() {
        #expect(AjoutTemps.possible(jeudi, aujourdhui: jeudi))
        #expect(AjoutTemps.possible(.du("2020-01-01"), aujourdhui: jeudi))
        #expect(!AjoutTemps.possible(jeudi.plus(jours: 1), aujourdhui: jeudi))
    }
}
