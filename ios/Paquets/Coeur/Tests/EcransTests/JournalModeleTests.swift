import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le journal (JournalActivity.kt, JournalPlus.kt) et la note d'un jour (NoteDialog.kt) : ce que l'écran montre
/// pour un journal forgé, dans quel ordre et sous quelle forme ; ce que font ses actions. Le critère de la
/// feuille de route : une séance faite se retrouve au journal avec sa note. Les règles du journal elles-mêmes
/// (setNote, addSession, JournalPlus.resume) sont jugées dans CoeurTests.
///
/// Restent au test d'interface : la date écrite en entier dans la langue de l'app, le dessin du graphique (de
/// droite à gauche en hébreu), la fenêtre de la note qui ne se ferme pas d'un geste quand la note a changé, le
/// voile sur l'aperçu du sélecteur d'apps, l'ouverture de la séance depuis l'écran vide.
@Suite("Modèle du journal")
@MainActor
struct JournalModeleTests {

    // MARK: Un journal forgé

    /// Jeudi 12 novembre 2026, à midi, en UTC.
    static let aujourdhui = "2026-11-12"

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    static func horloge() throws -> HorlogeFixe {
        let date = try jour(aujourdhui)
        return HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc)
    }

    static func traducteur(_ langue: String = "fr") throws -> Traducteur {
        try Traducteur(catalogue: Fichiers.catalogue(), langue: langue)
    }

    private func fabriquer(_ journal: Journal = Journal(), langue: String = "fr")
        throws -> (JournalModele, Magasin, PersistanceEnMemoire) {
        let enregistrement = Enregistrement(journal: journal)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let horloge = try Self.horloge()
        let traducteur = try Self.traducteur(langue)
        let modele = JournalModele(magasin: magasin, horloge: horloge, traducteur: traducteur)
        return (modele, magasin, persistance)
    }

    // MARK: L'écran vide

    @Test func sansJourneeLEcranDitQuoiFaire() throws {
        let (modele, _, _) = try fabriquer()
        #expect(modele.vide)
        #expect(modele.lignes.isEmpty)
        #expect(modele.titre == Libelle("journal_title"))
        #expect(modele.texteVide == Libelle("journal_empty"))
        #expect(modele.boutonVide == Libelle("journal_empty_action"))
        #expect(modele.imageVide == "char_writing")
        #expect(modele.resume == Libelle.pluriel("journal_summary", quantite: 0, .entier(0),
                                                 .libelle(Libelle("duration_minutes", .entier(0)))))
        #expect(modele.capturesMasquees)
    }

    @Test func leBoutonDeLEcranVideOuvreLaSeance() throws {
        let (modele, _, _) = try fabriquer()
        #expect(modele.route == nil)
        modele.commencer()
        #expect(modele.route == .seance)
    }

    // MARK: Le critère : une séance faite se retrouve au journal avec sa note

    @Test func uneSeanceFaiteSeRetrouveAuJournalAvecSaNote() async throws {
        let (modele, magasin, persistance) = try fabriquer()
        let date = try Self.jour(Self.aujourdhui)
        let horloge = try Self.horloge()
        // La séance d'une minute se clôt, comme l'écran de la séance l'inscrit.
        try await magasin.modifierJournal { journal in
            var reglages = Reglages()
            Store.addSession(journal: &journal, reglages: &reglages, minutes: 1, millis: horloge.maintenant,
                             fuseau: horloge.fuseau)
        }
        #expect(!modele.vide)
        // La note du jour, écrite puis enregistrée.
        modele.ouvrirNote(date)
        let note = try #require(modele.note)
        #expect(note.date == date)
        #expect(note.note == "")
        note.modifierNote("  Merci Hachem  ")
        try await modele.enregistrerNote()
        #expect(!modele.noteOuverte)

        let lignes = modele.lignes
        #expect(lignes.count == 1)
        let ligne = try #require(lignes.first)
        #expect(ligne.date == date)
        #expect(ligne.duree == Libelle("duration_minutes", .entier(1)))
        #expect(ligne.note == "Merci Hachem")
        #expect(!ligne.noteSeule)
        let resume = try Self.traducteur().texte(modele.resume)
        #expect(resume == "1 jour de hitbodedout, 1 min au total")
        let ecritures = await persistance.ecrituresJournal
        #expect(ecritures == 2)
    }

    // MARK: Les lignes

    @Test func lesJourneesVontDeLaPlusRecenteALaPlusAncienne() throws {
        var journal = Journal()
        for iso in ["2026-11-01", "2026-11-12", "2026-10-30", "2026-11-05"] {
            try journal.addSession(minutes: 10, date: Self.jour(iso))
        }
        let (modele, _, _) = try fabriquer(journal)
        let dates = modele.lignes.map(\.date.iso)
        #expect(dates == ["2026-11-12", "2026-11-05", "2026-11-01", "2026-10-30"])
    }

    @Test func laDureeDitNoteSeuleLeTempsOuValideeSansMinuteur() throws {
        var journal = Journal()
        try journal.setNote(date: Self.jour("2026-11-10"), note: "Une idée")
        try journal.addSession(minutes: 0, date: Self.jour("2026-11-09"))
        try journal.addSession(minutes: 65, date: Self.jour("2026-11-08"))
        try journal.addSession(minutes: 120, date: Self.jour("2026-11-07"))
        let (modele, _, _) = try fabriquer(journal)
        let durees = modele.lignes.map(\.duree)
        #expect(durees == [
            Libelle("journal_note_only"),
            Libelle("today_declared"),
            Libelle("duration_hours_minutes", .entier(1), .entier(5)),
            Libelle("duration_hours", .entier(2)),
        ])
        let seules = modele.lignes.map(\.noteSeule)
        #expect(seules == [true, false, false, false])
        // Une note seule s'affiche, sans valider la journée.
        let premiere = try #require(modele.lignes.first)
        #expect(premiere.note == "Une idée")
    }

    @Test func leTexteDUneLigneRassembleNoteSujetsHumeurGratitudeEtTravail() throws {
        let date = try Self.jour("2026-11-11")
        var journal = Journal()
        // Un sujet en double et une clé inconnue : chaque sujet connu une fois, dans l'ordre.
        journal[date] = Journee(minutes: 30, note: "Merci", themes: ["gratitude", "famille", "gratitude", "inconnu"])
        journal.ecrirePlus(JournalPlus.Plus(avant: 2, apres: 4, gratitude: "la vie", travail: "patience"), pour: date)
        let (modele, _, _) = try fabriquer(journal)
        let ligne = try #require(modele.lignes.first)
        let attendu = "Merci\n"
            + "Sujet\u{00A0}: Gratitude \u{00B7} Famille\n"
            + "\u{2066}\u{1F641} \u{2192} \u{1F642}\u{2069}\n"
            + "Gratitude : la vie\n"
            + "\u{00C0} travailler : patience"
        #expect(ligne.note == attendu)
    }

    @Test func leTexteSuitLaLangueDeLApp() throws {
        let date = try Self.jour("2026-11-11")
        var journal = Journal()
        journal[date] = Journee(minutes: 30, note: "", themes: ["famille"])
        journal.ecrirePlus(JournalPlus.Plus(gratitude: "life"), pour: date)
        let (modele, _, _) = try fabriquer(journal, langue: "en")
        let ligne = try #require(modele.lignes.first)
        let traducteur = try Self.traducteur("en")
        let sujet = traducteur.texte(Libelle("journal_sujets", .texte(traducteur.texte(cle: "theme_famille"))))
        #expect(ligne.note == sujet + "\nGratitude : life")
    }

    @Test func uneLigneSansRienACacheSonTexte() throws {
        var journal = Journal()
        let date = try Self.jour("2026-11-11")
        journal[date] = Journee(minutes: 30, note: "   ", themes: ["inconnu"])
        let (modele, _, _) = try fabriquer(journal)
        let ligne = try #require(modele.lignes.first)
        #expect(ligne.note == nil)
    }

    // MARK: Le bandeau

    @Test func leResumeCompteLesJourneesFaitesEtToutLeTemps() throws {
        var journal = Journal()
        try journal.addSession(minutes: 30, date: Self.jour("2026-11-10"))
        try journal.addSession(minutes: 45, date: Self.jour("2026-11-11"))
        try journal.setNote(date: Self.jour("2026-11-12"), note: "Seule")
        let (modele, _, _) = try fabriquer(journal)
        #expect(modele.resume == Libelle.pluriel("journal_summary", quantite: 2, .entier(2),
                                                 .libelle(Libelle("duration_hours_minutes", .entier(1), .entier(15)))))
        let texte = try Self.traducteur().texte(modele.resume)
        #expect(texte == "2 jours de hitbodedout, 1 h 15 au total")
    }

    @Test func leGraphiqueMontreLeMoisEnCours() throws {
        var journal = Journal()
        try journal.addSession(minutes: 30, date: Self.jour("2026-11-02"))
        try journal.addSession(minutes: 60, date: Self.jour("2026-11-03"))
        try journal.setNote(date: Self.jour("2026-11-05"), note: "Seule")
        try journal.addSession(minutes: 90, date: Self.jour("2026-10-31"))
        let (modele, _, _) = try fabriquer(journal)
        let graphique = modele.graphique
        let premier = try Self.jour("2026-11-01")
        #expect(graphique.mois == premier)
        #expect(graphique.barres.count == 30)
        let minutes = graphique.barres.map(\.minutes)
        #expect(minutes[1] == 30)
        #expect(minutes[2] == 60)
        #expect(minutes[4] == 0)
        let parts = graphique.barres.map(\.part)
        #expect(parts[1] == 0.5)
        #expect(parts[2] == 1)
        #expect(parts[0] == 0)
        let aujourdhui = graphique.barres.filter(\.aujourdhui).map(\.jour)
        #expect(aujourdhui == [12])
        #expect(graphique.total == 90)
        #expect(graphique.joursAvecMinutes == 2)
        let haute = JournalGraphique.hauteurBarre(graphique.barres[2])
        #expect(haute == 64)
        let moitie = JournalGraphique.hauteurBarre(graphique.barres[1])
        #expect(moitie == 34)
        let vide = JournalGraphique.hauteurBarre(graphique.barres[0])
        #expect(vide == 3)
        #expect(graphique.accessibilite(moisNomme: "novembre 2026") == Libelle("journal_graphique", .texte("novembre 2026")))
    }

    @Test func unMoisSansMinutesGardeSesBarresBasses() throws {
        let (modele, _, _) = try fabriquer()
        let graphique = modele.graphique
        #expect(graphique.barres.count == 30)
        #expect(graphique.total == 0)
        let faites = graphique.barres.filter(\.faite).count
        #expect(faites == 0)
    }

    // MARK: La note d'un jour

    @Test func laNoteSOuvreAvecCeQueLeJourGarde() throws {
        let date = try Self.jour("2026-11-11")
        var journal = Journal()
        journal.addSession(minutes: 20, note: "Avant", date: date)
        journal.ecrirePlus(JournalPlus.Plus(avant: 2, apres: 5, gratitude: "g", travail: "t"), pour: date)
        let (modele, _, _) = try fabriquer(journal)
        modele.ouvrirNote(date)
        let note = try #require(modele.note)
        #expect(note.note == "Avant")
        #expect(note.avant == 2)
        #expect(note.apres == 5)
        #expect(note.gratitude == "g")
        #expect(note.travail == "t")
        #expect(note.avantChoisi(2))
        #expect(!note.avantChoisi(3))
        #expect(note.titre == Libelle("note_title"))
        #expect(note.image == "char_writing")
        modele.fermerNote()
        #expect(!modele.noteOuverte)
    }

    @Test func ceQuOnAEcritNeSePerdPasDUnGeste() throws {
        let date = try Self.jour("2026-11-11")
        var journal = Journal()
        journal.addSession(minutes: 20, note: "Avant", date: date)
        let (modele, _, _) = try fabriquer(journal)
        modele.ouvrirNote(date)
        let note = try #require(modele.note)
        #expect(!note.change)
        #expect(note.fermableParGeste)
        #expect(note.boutonRenoncer == Libelle("action_later"))
        note.modifierNote("Avant, et après")
        #expect(note.change)
        #expect(!note.fermableParGeste)
        #expect(note.boutonRenoncer == Libelle("note_discard"))
        // Les blancs des bouts ne comptent pas (`trim()`).
        note.modifierNote("  Avant \n")
        #expect(!note.change)
        // L'humeur et la gratitude ne changent pas le bouton, comme sur Android.
        note.toucherAvant(3)
        note.modifierGratitude("merci")
        #expect(!note.change)
    }

    @Test func toucherUneHumeurLaChoisitOuLaRetire() throws {
        let date = try Self.jour("2026-11-11")
        let (modele, _, _) = try fabriquer()
        modele.ouvrirNote(date)
        let note = try #require(modele.note)
        #expect(note.avant == 0)
        note.toucherAvant(3)
        #expect(note.avant == 3)
        note.toucherAvant(3)
        #expect(note.avant == 0)
        note.toucherApres(2)
        note.toucherApres(5)
        #expect(note.apres == 5)
        #expect(JournalNoteModele.humeurs.count == 5)
        let premiere = try #require(JournalNoteModele.humeurs.first)
        #expect(premiere.rang == 1)
        #expect(premiere.emoji == "\u{1F61E}")
        #expect(premiere.accessibilite == "1/5")
    }

    @Test func lesChampsGardentLeurLongueurMaximale() throws {
        let (modele, _, _) = try fabriquer()
        try modele.ouvrirNote(Self.jour("2026-11-11"))
        let note = try #require(modele.note)
        note.modifierNote(String(repeating: "a", count: 4100))
        #expect(note.note.utf16.count == 4000)
        note.modifierGratitude(String(repeating: "b", count: 250))
        #expect(note.gratitude.utf16.count == 200)
        note.modifierTravail(String(repeating: "c", count: 201))
        #expect(note.travail.utf16.count == 200)
    }

    @Test func enregistrerEcritLaNoteEtLeJournalEnrichi() async throws {
        let date = try Self.jour("2026-11-11")
        var journal = Journal()
        journal.addSession(minutes: 20, date: date)
        let (modele, magasin, persistance) = try fabriquer(journal)
        modele.ouvrirNote(date)
        let note = try #require(modele.note)
        note.modifierNote(" Une note ")
        note.toucherAvant(1)
        note.toucherApres(5)
        note.modifierGratitude("  merci  ")
        note.modifierTravail("la patience ")
        try await modele.enregistrerNote()
        #expect(!modele.noteOuverte)
        let gardee = magasin.journal.record(date)?.note
        #expect(gardee == "Une note")
        #expect(magasin.journal.lirePlus(date) == JournalPlus.Plus(avant: 1, apres: 5, gratitude: "merci", travail: "la patience"))
        // La note et le journal enrichi s'écrivent ensemble.
        let ecritures = await persistance.ecrituresJournal
        #expect(ecritures == 1)
        let ligne = try #require(modele.lignes.first)
        #expect(ligne.note == "Une note\n\u{2066}\u{1F61E} \u{2192} \u{1F604}\u{2069}\nGratitude : merci\n\u{00C0} travailler : la patience")
    }

    @Test func effacerUneNoteSeuleRetireLaLigne() async throws {
        let date = try Self.jour("2026-11-05")
        var journal = Journal()
        journal.setNote(date: date, note: "Une idée")
        let (modele, _, _) = try fabriquer(journal)
        #expect(modele.lignes.count == 1)
        modele.ouvrirNote(date)
        let note = try #require(modele.note)
        note.modifierNote("   ")
        try await modele.enregistrerNote()
        #expect(modele.lignes.isEmpty)
        #expect(modele.vide)
    }

    @Test func uneEcritureRefuseeLaisseLaNoteOuverte() async throws {
        let date = try Self.jour("2026-11-11")
        var journal = Journal()
        journal.addSession(minutes: 20, date: date)
        let (modele, _, persistance) = try fabriquer(journal)
        await persistance.faireEchouer(true)
        modele.ouvrirNote(date)
        let note = try #require(modele.note)
        note.modifierNote("Perdue ?")
        var refuse = false
        do {
            try await modele.enregistrerNote()
        } catch {
            refuse = true
        }
        #expect(refuse)
        #expect(modele.noteOuverte)
    }
}
