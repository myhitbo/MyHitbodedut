import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La démonstration des captures d'écran (Demonstration, sur le modèle de tools/promo_screenshots.sh d'Android) :
/// douze jours de suite jusqu'à hier, le Chabbat sauté sans casser la série, aujourd'hui à faire ; la présentation
/// vue ; la ville de la langue choisie dans la liste, Israël d'après son pays ; les notes dans la langue de l'app.
@Suite("Démonstration des captures")
@MainActor
struct DemonstrationTests {

    /// Un jeudi : la semaine tient déjà quatre jours faits.
    private let jeudi = JourCivil(annee: 2026, mois: 11, jour: 19)!

    private func demonstration(_ langue: String, fuseau: String = "Europe/Paris") async throws -> Enregistrement {
        let villes = try await ZmanimEssais.contenus.villes()
        return Demonstration.enregistrement(aujourdhui: jeudi, maintenant: 1_795_600_000_000, fuseau: fuseau,
                                            langue: langue, villes: villes)
    }

    @Test func douzeJoursDeSuiteJusquaHierEtAujourdhuiAFaire() async throws {
        let demo = try await demonstration("fr")
        #expect(!demo.journal.isDone(jeudi))
        #expect(demo.journal.isDone(jeudi.plus(jours: -1)))
        // Le samedi 14 n'est pas fait, et ne casse pas la série (jour de repos).
        #expect(!demo.journal.isDone(JourCivil(annee: 2026, mois: 11, jour: 14)!))
        let serie = Store.streak(journal: demo.journal, reglages: demo.reglages, aujourdhui: jeudi,
                                 fuseauTelephone: "Europe/Paris")
        #expect(serie == 12)
        // Douze jours récents et vingt-six plus anciens, moins leurs samedis.
        #expect(demo.journal.joursFaits.count > 30)
        #expect(demo.journal.record(jeudi.plus(jours: -1))?.minutes == 20)
        #expect(demo.journal.record(jeudi.plus(jours: -2))?.minutes == 35)
    }

    @Test func laPresentationEstVueEtLaSeanceReglee() async throws {
        let reglages = try await demonstration("en").reglages
        #expect(reglages.hasOnboarded)
        #expect(reglages.adresse == "m")
        #expect(reglages.targetMinutes == 20)
        #expect(reglages.reminderEnabled)
        #expect(reglages.reminderTimes == [405, 810, 1335])
        #expect(reglages.musicTrackId == "yanuka_nigoun_3")
    }

    @Test func laVilleDeLaLangueEstChoisieDansLaListe() async throws {
        let he = try await demonstration("he", fuseau: "Asia/Jerusalem").reglages
        #expect(he.lieuVille == 281_184)
        #expect(he.lieuZmanim?.nom == "ירושלים")
        #expect(he.inIsrael(fuseauTelephone: "Asia/Jerusalem"))
        let fr = try await demonstration("fr").reglages
        #expect(fr.lieuVille == 2_988_507)
        #expect(fr.lieuZmanim?.nom == "Paris")
        #expect(!fr.inIsrael(fuseauTelephone: "Europe/Paris"))
        // L'arabe de Tunisie a Paris, et le nom de la ville en hébreu, comme l'espagnol (TexteLocalise.pour).
        let ar = try await demonstration("ar").reglages
        #expect(ar.lieuVille == 2_988_507)
        let es = try await demonstration("es", fuseau: "America/Argentina/Buenos_Aires").reglages
        #expect(es.lieuVille == 3_435_910)
    }

    @Test func laFeteAuJourMontreUnSeulTropheeNeuf() async throws {
        let demo = Demonstration.avecTropheeNeuf(try await demonstration("fr"), aujourdhui: jeudi,
                                                 fuseau: "Europe/Paris")
        let magasin = Magasin.enMemoire(demo)
        let fete = TropheeFeteModele(magasin: magasin,
                                     horloge: HorlogeFixe(DateHeure(jeudi, heure: 9), fuseau: Fuseau("Europe/Paris")!))
        try await fete.passer()
        #expect(fete.fiches.count == 1)
        #expect(fete.palier == nil)
        // Fêté une fois : le passage suivant ne montre plus rien.
        let suivante = TropheeFeteModele(magasin: magasin,
                                         horloge: HorlogeFixe(DateHeure(jeudi, heure: 9), fuseau: Fuseau("Europe/Paris")!))
        try await suivante.passer()
        #expect(suivante.fiches.isEmpty)
    }

    @Test func lesNotesEtLePrenomSontDansLaLangueDeLApp() async throws {
        let hier = jeudi.plus(jours: -1)
        let fr = try await demonstration("fr").journal
        #expect(fr.record(hier)?.note.hasPrefix("Je L'ai remercié") == true)
        #expect(fr.record(hier)?.themes == ["gratitude"])
        #expect(fr.firstName == "David")
        let he = try await demonstration("he").journal
        #expect(he.firstName == "דוד")
        #expect(he.record(hier)?.note.hasPrefix("הודיתי") == true)
        let plus = JournalPlus.lire(he.plusBrut, date: hier.iso)
        #expect(plus.avant == 2 && plus.apres == 4)
        #expect(!plus.gratitude.isEmpty)
    }
}
