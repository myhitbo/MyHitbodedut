import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le bravo de fin de séance (CelebrationActivity) : le titre selon l'adresse, les minutes, la pose du jour (la
/// danse, la guitare, le pouce levé) et sa forme féminine, « ’Hazak » après un abandon et son mot de relance,
/// « Continuer » qui propose la note, le partage et la série, le bravo en attente pris une seule fois.
///
/// Restent au test d'interface : la danse elle-même (sauts, poses qui se relaient, notes qui montent) et son
/// absence sous « Réduire les animations », la scène réduite des petits écrans, la feuille de partage.
@Suite("Modèle du bravo")
@MainActor
struct CelebrationModeleTests {

    private static func modele(_ demande: CelebrationDemande, jour: JourCivil, reglages: Reglages = Reglages(),
                               journal: Journal = Journal(), json: String = SeanceModeleTests.petit)
        -> CelebrationModele {
        let magasin = Magasin.enMemoire(Enregistrement(journal: journal, reglages: reglages))
        return CelebrationModele(demande: demande, magasin: magasin, contenus: SeanceModeleTests.contenus(json),
                                 horloge: HorlogeFixe(DateHeure(jour, heure: 10), fuseau: .utc), langue: "fr",
                                 debug: false, melange: { $0 })
    }

    @Test func leTitreSuitLAdresse() throws {
        let jour = try SeanceOutils.jour("2026-11-18")
        let demande = CelebrationDemande(minutes: 20, dateNote: jour)
        #expect(Self.modele(demande, jour: jour).titre == Libelle("celebration_neutral"))
        var homme = Reglages()
        homme.setAdresse("m")
        #expect(Self.modele(demande, jour: jour, reglages: homme).titre == Libelle("celebration_tsadik"))
        var femme = Reglages()
        femme.setAdresse("f")
        #expect(Self.modele(demande, jour: jour, reglages: femme).titre == Libelle("celebration_tsadeket"))
        #expect(Self.modele(.annulation, jour: jour).titre == Libelle("annulation_neutral"))
        #expect(Self.modele(.annulation, jour: jour, reglages: homme).titre == Libelle("annulation_hazak"))
        #expect(Self.modele(.annulation, jour: jour, reglages: femme).titre == Libelle("annulation_hizki"))
    }

    @Test func lesMinutesSeDisentAuPlurielEtZeroLesCache() throws {
        let jour = try SeanceOutils.jour("2026-11-18")
        let vingt = Self.modele(CelebrationDemande(minutes: 20, dateNote: jour), jour: jour)
        #expect(vingt.sousTitre == Libelle.pluriel("celebration_minutes", quantite: 20, .entier(20)))
        #expect(vingt.partageVisible)
        let zero = Self.modele(CelebrationDemande(minutes: 0, dateNote: jour), jour: jour)
        #expect(zero.sousTitre == nil)
        #expect(!zero.partageVisible)
        #expect(zero.danse)
    }

    /// `floorMod(toEpochDay(), 3)` : le 18/11/2026 (20 775) la danse, le 16 (20 773) la guitare, le 17 le pouce.
    @Test func laPoseChangeDUnJourALAutre() throws {
        let demande = CelebrationDemande(minutes: 5, dateNote: nil)
        let le18 = try SeanceOutils.jour("2026-11-18")
        let le16 = try SeanceOutils.jour("2026-11-16")
        let le17 = try SeanceOutils.jour("2026-11-17")
        let danse = Self.modele(demande, jour: le18)
        #expect(danse.poseA == "char_dancing")
        #expect(danse.poseB == "char_dancing_joy")
        let guitare = Self.modele(demande, jour: le16)
        #expect(guitare.poseA == "char_guitar")
        #expect(guitare.poseB == "char_guitar")
        let pouce = Self.modele(demande, jour: le17)
        #expect(pouce.poseA == "char_thumbs_up")
        #expect(pouce.poseB == "char_thumbs_up")
        var femme = Reglages()
        femme.setAdresse("f")
        let dansante = Self.modele(demande, jour: le18, reglages: femme)
        #expect(dansante.poseA == "char_f_dancing")
        #expect(dansante.poseB == "char_f_joy")
        let marcheuse = Self.modele(.annulation, jour: le18, reglages: femme)
        #expect(marcheuse.poseA == "char_f_walking")
        #expect(marcheuse.poseB == nil)
    }

    @Test func laMesureDeLaDanseSeRepeteToutesLesDeuxTemps() {
        #expect(CelebrationModele.pas(0) == DanseMesure.pas(0))
        #expect(CelebrationModele.pas(480) == DanseMesure.pas(0.5))
        #expect(CelebrationModele.pas(960) == DanseMesure.pas(0))
        #expect(CelebrationModele.pas(1_200) == DanseMesure.pas(0.25))
        #expect(CelebrationModele.intervalleNotes == 660)
        #expect(CelebrationModele.signes.count == 4)
    }

    @Test func continuerProposeLaNoteDuJourDeLaSeance() throws {
        let jour = try SeanceOutils.jour("2026-11-18")
        let veille = try SeanceOutils.jour("2026-11-17")
        let bravo = Self.modele(CelebrationDemande(minutes: 5, dateNote: veille), jour: jour)
        #expect(bravo.continuer() == .note(veille))
        #expect(bravo.libelleContinuer == Libelle("celebration_continue"))
        let sansNote = Self.modele(CelebrationDemande(minutes: 5, dateNote: nil), jour: jour)
        #expect(sansNote.continuer() == .fermer)
        #expect(Self.modele(.annulation, jour: jour).continuer() == .fermer)
    }

    @Test func apresUnAbandonUnMotDeRelance() async throws {
        let jour = try SeanceOutils.jour("2026-11-18")
        let hazak = Self.modele(.annulation, jour: jour)
        #expect(hazak.carte == nil)
        await hazak.charger()
        let carte = try #require(hazak.carte)
        #expect(carte.moment == .relance)
        #expect(carte.titre == Libelle("moment_relance"))
        #expect(carte.image == "char_thinking")
        #expect(!hazak.danse)
        // Un bravo n'a pas de carte.
        let bravo = Self.modele(CelebrationDemande(minutes: 5, dateNote: jour), jour: jour)
        await bravo.charger()
        #expect(bravo.carte == nil)
    }

    @Test func sansTexteDeRelanceLaCarteSeCache() async throws {
        let jour = try SeanceOutils.jour("2026-11-18")
        let hazak = Self.modele(.annulation, jour: jour, json: SeanceModeleTests.sansBlocage)
        await hazak.charger()
        #expect(hazak.carte == nil)
    }

    @Test func lePartageDitLaSeanceLaSerieEtLeLien() throws {
        let jour = try SeanceOutils.jour("2026-11-18")
        let seul = Self.modele(CelebrationDemande(minutes: 20, dateNote: jour), jour: jour)
        let lien = Libelle("partage_lien", .texte("https://hil123.github.io/myhitbodedut-web/"))
        let texte = Libelle("partage_texte", .libelle(Libelle.pluriel("partage_minutes", quantite: 20, .entier(20))))
        #expect(seul.lignesPartage == [texte, lien])

        var journal = Journal()
        journal.addSession(minutes: 10, date: jour.plus(jours: -2))
        journal.addSession(minutes: 10, date: jour.plus(jours: -1))
        journal.addSession(minutes: 20, date: jour)
        let serie = Self.modele(CelebrationDemande(minutes: 20, dateNote: jour), jour: jour, journal: journal)
        #expect(serie.lignesPartage == [texte, Libelle("partage_serie", .entier(3)), lien])
        #expect(serie.titrePartage == Libelle("partage_choix"))
        #expect(serie.libellePartager == Libelle("partage_action"))

        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: "fr")
        let ecrit = serie.textePartage { traducteur.texte($0) }
        let lignes = ecrit.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lignes.count == 3)
        #expect(ecrit.hasSuffix("https://hil123.github.io/myhitbodedut-web/"))
    }

    @Test func leBravoEnAttenteSePrendUneSeuleFois() async throws {
        var reglages = Reglages()
        reglages.setPendingCelebration(minutes: 7, dateNote: "2026-11-17")
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let veille = try SeanceOutils.jour("2026-11-17")
        let pris = await CelebrationDemande.prendre(magasin)
        #expect(pris == CelebrationDemande(minutes: 7, dateNote: veille))
        #expect(pris?.annulee == false)
        #expect(!magasin.reglages.hasPendingCelebration)
        let encore = await CelebrationDemande.prendre(magasin)
        #expect(encore == nil)
    }

    @Test func uneDateDeNoteIllisibleNeProposePasDeNote() {
        let demande = CelebrationDemande(Reglages.Celebration(minutes: 3, dateNote: "hier"))
        #expect(demande.dateNote == nil)
        #expect(demande.minutes == 3)
        let sansDate = CelebrationDemande(Reglages.Celebration(minutes: 3, dateNote: nil))
        #expect(sansDate.dateNote == nil)
        #expect(CelebrationDemande.annulation.annulee)
        #expect(CelebrationDemande.annulation.minutes == 0)
    }
}
