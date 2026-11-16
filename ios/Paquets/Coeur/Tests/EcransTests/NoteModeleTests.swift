import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La note de la hitbodedout (NoteDialog) : la note du jour reprise, ce qu'on écrit qui ne se perd plus d'un geste
/// (« Ne pas enregistrer », la feuille qui ne se ferme plus d'un glissement), les humeurs qui se choisissent et
/// se retirent, les longueurs bornées, l'enregistrement rogné dans le journal et le journal enrichi, la note
/// seule qui ne valide pas la journée.
///
/// Restent au test d'interface : le clavier, la feuille réellement retenue, le défilement sur un petit écran.
@Suite("Modèle de la note")
@MainActor
struct NoteModeleTests {

    @Test func laNoteDuJourEstReprise() throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var journal = Journal()
        journal.addSession(minutes: 10, note: "Déjà là", date: jour)
        journal.ecrirePlus(JournalPlus.Plus(avant: 2, apres: 4, gratitude: "G", travail: "T"), pour: jour)
        let note = NoteModele(date: jour, magasin: Magasin.enMemoire(Enregistrement(journal: journal)))
        #expect(note.texte == "Déjà là")
        #expect(note.initiale == "Déjà là")
        #expect(note.avant == 2)
        #expect(note.apres == 4)
        #expect(note.gratitude == "G")
        #expect(note.travail == "T")
        #expect(note.titre == Libelle("note_title"))
        #expect(note.image == "char_writing")
        #expect(note.humeurs == JournalPlus.humeurs)
        #expect(note.indicationNote == Libelle("note_hint"))
        #expect(note.titreAvant == Libelle("journal_humeur_avant"))
        #expect(note.titreApres == Libelle("journal_humeur_apres"))
        #expect(note.indicationGratitude == Libelle("journal_gratitude_hint"))
        #expect(note.indicationTravail == Libelle("journal_travail_hint"))
        #expect(note.libelleEnregistrer == Libelle("action_save"))
    }

    @Test func ceQuOnAEcritNeSePerdPasDUnGeste() throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let note = NoteModele(date: jour, magasin: Magasin.enMemoire())
        #expect(!note.modifiee)
        #expect(note.fermableParGeste)
        #expect(note.libelleFermer == Libelle("action_later"))
        note.ecrire("   ")
        // Des blancs seuls ne changent rien.
        #expect(!note.modifiee)
        note.ecrire("Une pensée")
        #expect(note.modifiee)
        #expect(!note.fermableParGeste)
        #expect(note.libelleFermer == Libelle("note_discard"))
        note.ecrire("")
        #expect(!note.modifiee)
        // L'humeur seule ne retient pas la feuille, comme sur Android.
        note.choisirAvant(1)
        #expect(note.fermableParGeste)
    }

    @Test func lesHumeursSeChoisissentEtSeRetirent() throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let note = NoteModele(date: jour, magasin: Magasin.enMemoire())
        #expect(note.avant == 0)
        note.choisirAvant(2)
        #expect(note.avant == 3)
        #expect(NoteModele.opacite(humeur: note.avant, rang: 2) == 1)
        #expect(NoteModele.opacite(humeur: note.avant, rang: 0) == 0.35)
        note.choisirAvant(4)
        #expect(note.avant == 5)
        note.choisirAvant(4)
        #expect(note.avant == 0)
        note.choisirApres(0)
        #expect(note.apres == 1)
        #expect(NoteModele.etiquette(rang: 2) == "3/5")
    }

    @Test func lesLongueursSontBornees() throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let note = NoteModele(date: jour, magasin: Magasin.enMemoire())
        note.ecrire(String(repeating: "a", count: Journal.noteMax + 10))
        #expect(note.texte.utf16.count == Journal.noteMax)
        note.ecrireGratitude(String(repeating: "b", count: 300))
        #expect(note.gratitude.utf16.count == JournalPlus.gratitudeMax)
        note.ecrireTravail(String(repeating: "c", count: 300))
        #expect(note.travail.utf16.count == JournalPlus.gratitudeMax)
    }

    @Test func enregistrerEcritLaNoteEtLeJournalEnrichiRognes() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var journal = Journal()
        journal.addSession(minutes: 15, date: jour)
        let persistance = PersistanceEnMemoire(Enregistrement(journal: journal))
        let magasin = Magasin(persistance: persistance, enregistrement: Enregistrement(journal: journal))
        let note = NoteModele(date: jour, magasin: magasin)
        note.ecrire("\n  Ce qui est monté  \n")
        note.choisirAvant(1)
        note.choisirApres(4)
        note.ecrireGratitude("  la famille ")
        note.ecrireTravail(" la patience")
        try await note.enregistrer()

        let journee = try #require(magasin.journal.record(jour))
        #expect(journee.note == "Ce qui est monté")
        #expect(journee.minutes == 15)
        #expect(journee.faite)
        let plus = magasin.journal.lirePlus(jour)
        #expect(plus == JournalPlus.Plus(avant: 2, apres: 5, gratitude: "la famille", travail: "la patience"))
        let ecrit = await persistance.enregistrement
        #expect(ecrit.journal.record(jour)?.note == "Ce qui est monté")
        let ecritures = await persistance.ecrituresJournal
        #expect(ecritures == 1)
    }

    @Test func uneNoteSurUnJourSansHitbodedoutNeLeValidePas() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let magasin = Magasin.enMemoire()
        let note = NoteModele(date: jour, magasin: magasin)
        note.ecrire("Rien fait, mais pensé")
        try await note.enregistrer()
        let journee = try #require(magasin.journal.record(jour))
        #expect(journee.noteSeule)
        #expect(!magasin.journal.isDone(jour))

        // La note seule effacée retire la ligne.
        let effacer = NoteModele(date: jour, magasin: magasin)
        effacer.ecrire("  ")
        try await effacer.enregistrer()
        #expect(magasin.journal.record(jour) == nil)
    }

    @Test func plusTardNEcritRien() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        let note = NoteModele(date: jour, magasin: magasin)
        note.ecrire("Brouillon")
        // La feuille fermée sans enregistrer : le modèle est simplement abandonné.
        #expect(magasin.journal.record(jour) == nil)
        let ecritures = await persistance.ecrituresJournal
        #expect(ecritures == 0)
    }

    @Test func laNoteAuFemininMontreLaPlumeFeminine() throws {
        var reglages = Reglages()
        reglages.setAdresse("f")
        let jour = try SeanceOutils.jour("2026-11-16")
        let note = NoteModele(date: jour, magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)))
        #expect(note.image == "char_f_writing")
    }
}
