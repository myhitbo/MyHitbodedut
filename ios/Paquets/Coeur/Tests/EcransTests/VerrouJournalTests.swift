import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le verrou du journal (VerrouJournal.kt, VerrouJournalTest.kt d'Android) : tout ce qui montre ou emporte le texte du
/// journal demande le code, et le verrou ne se coupe pas sans lui. L'écran du journal se referme à l'arrière-plan et
/// redemande le code au retour ; la fenêtre de note déjà remplie, ouverte hors du journal, l'attend ; l'export
/// l'attend ; les accueils des versions taisent les notes. Sans code sur le téléphone, rien n'est demandé.
///
/// Restent à l'appareil : la vraie demande de LocalAuthentication (Face ID, Touch ID, le code), la couverture posée
/// sur l'écran pendant qu'elle est à l'écran.
@Suite("Le verrou du journal")
@MainActor
struct VerrouJournalTests {

    struct Banc {
        let verrou: VerrouJournal
        let code: FauxCodeDuTelephone
        let magasin: Magasin
    }

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    func banc(demande: Bool = true, ecranProtege: Bool = true, reponse: Bool = true,
              journal: Journal = Journal()) -> Banc {
        var reglages = Reglages()
        reglages.setJournalVerrou(demande)
        let magasin = Magasin.enMemoire(Enregistrement(journal: journal, reglages: reglages))
        let code = FauxCodeDuTelephone(ecranProtege: ecranProtege, reponse: reponse)
        return Banc(verrou: VerrouJournal(magasin: magasin, code: code), code: code, magasin: magasin)
    }

    // MARK: Actif, et exiger

    @Test func leVerrouNEstActifQueDemandeEtTenuParUnCode() {
        #expect(Reglages().journalVerrou == false)
        #expect(banc().verrou.actif)
        #expect(!banc(demande: false).verrou.actif)
        // Un téléphone sans verrouillage d'écran n'a rien pour le tenir (isDeviceSecure).
        #expect(!banc(ecranProtege: false).verrou.actif)
    }

    @Test func exigerNeDemandeRienQuandLeVerrouNEstPasActif() async {
        let b = banc(demande: false)
        #expect(await b.verrou.exiger())
        #expect(b.code.demandes == 0)
        let sansCode = banc(ecranProtege: false, reponse: false)
        #expect(await sansCode.verrou.exiger())
        #expect(sansCode.code.demandes == 0)
    }

    @Test func exigerDemandeLeCodeSousLeTitreDuJournal() async {
        let b = banc()
        #expect(await b.verrou.exiger())
        #expect(b.code.demandes == 1)
        #expect(b.code.raisons == [Libelle("journal_verrou_titre")])
        b.code.reponse = false
        #expect(await b.verrou.exiger() == false)
        #expect(b.code.demandes == 2)
    }

    // MARK: L'interrupteur des réglages (renderVerrou)

    @Test func lAllumerSansCodeSurLeTelephoneLeLaisseEteint() async throws {
        let b = banc(demande: false, ecranProtege: false)
        let message = try await b.verrou.basculer(true)
        #expect(message == Libelle("journal_verrou_sans_code"))
        #expect(!b.magasin.reglages.journalVerrou)
        #expect(!b.verrou.actif)
    }

    @Test func lAllumerAvecUnCodeNeDemandeRien() async throws {
        let b = banc(demande: false)
        #expect(try await b.verrou.basculer(true) == nil)
        #expect(b.magasin.reglages.journalVerrou)
        #expect(b.verrou.actif)
        #expect(b.code.demandes == 0)
    }

    @Test func leCouperDemandeLeCode() async throws {
        let b = banc(reponse: false)
        #expect(try await b.verrou.basculer(false) == nil)
        // Refusé : il reste allumé.
        #expect(b.magasin.reglages.journalVerrou)
        #expect(b.code.demandes == 1)
        b.code.reponse = true
        try await b.verrou.basculer(false)
        #expect(!b.magasin.reglages.journalVerrou)
        #expect(b.code.demandes == 2)
    }

    @Test func leCouperSansCodeSurLeTelephoneNeDemandeRien() async throws {
        // Demandé, mais le code du téléphone a été retiré : il n'était plus actif.
        let b = banc(ecranProtege: false)
        try await b.verrou.basculer(false)
        #expect(!b.magasin.reglages.journalVerrou)
        #expect(b.code.demandes == 0)
    }

    // MARK: L'écran du journal (JournalActivity)

    @Test func sansVerrouLeJournalSOuvreSansRienDemander() async {
        let b = banc(demande: false)
        let ecran = JournalVerrouille(verrou: b.verrou)
        #expect(ecran.ouvert)
        await ecran.apparaitre()
        ecran.arrierePlan()
        await ecran.premierPlan()
        #expect(ecran.ouvert)
        #expect(b.code.demandes == 0)
    }

    @Test func leJournalNeSeMontreQuApresLeCode() async {
        let b = banc()
        let ecran = JournalVerrouille(verrou: b.verrou)
        #expect(!ecran.ouvert)
        await ecran.apparaitre()
        #expect(ecran.ouvert)
        #expect(!ecran.refuse)
        #expect(b.code.demandes == 1)
        // Déjà ouvert : rien à redemander en revenant sur l'écran.
        await ecran.apparaitre()
        #expect(b.code.demandes == 1)
    }

    @Test func renoncerAuCodeFermeLeJournal() async {
        let b = banc(reponse: false)
        let ecran = JournalVerrouille(verrou: b.verrou)
        await ecran.apparaitre()
        #expect(!ecran.ouvert)
        #expect(ecran.refuse)
    }

    @Test func leJournalSeRefermeALArrierePlanEtRedemandeLeCode() async {
        let b = banc()
        let ecran = JournalVerrouille(verrou: b.verrou)
        await ecran.apparaitre()
        ecran.arrierePlan()
        #expect(!ecran.ouvert)
        await ecran.premierPlan()
        #expect(ecran.ouvert)
        #expect(b.code.demandes == 2)
        // Un retour sans départ (l'écran seulement inactif) ne redemande rien.
        await ecran.premierPlan()
        #expect(b.code.demandes == 2)
        // Refusé au retour : l'écran se ferme.
        ecran.arrierePlan()
        b.code.reponse = false
        await ecran.premierPlan()
        #expect(!ecran.ouvert)
        #expect(ecran.refuse)
    }

    @Test func leCodeRetireEntreTempsRouvreLeJournalSansRienDemander() async {
        let b = banc()
        let ecran = JournalVerrouille(verrou: b.verrou)
        await ecran.apparaitre()
        ecran.arrierePlan()
        b.code.ecranProtege = false
        await ecran.premierPlan()
        #expect(ecran.ouvert)
        #expect(b.code.demandes == 1)
    }

    // MARK: La fenêtre de note déjà remplie (NoteDialog.show)

    @Test func laNoteDejaEcriteAttendLeCodeHorsDuJournal() async throws {
        let jour = try Self.jour("2026-11-16")
        var journal = Journal()
        journal.setNote(date: jour, note: "Une ligne")
        let b = banc(journal: journal)
        let note = JournalNoteModele(magasin: b.magasin, date: jour, verrou: b.verrou)
        #expect(note.verrouillee)
        b.code.reponse = false
        #expect(await note.deverrouiller() == false)
        #expect(note.verrouillee)
        b.code.reponse = true
        #expect(await note.deverrouiller())
        #expect(!note.verrouillee)
        // Déverrouillée : rien de plus à demander.
        #expect(await note.deverrouiller())
        #expect(b.code.demandes == 2)
    }

    @Test func unJourSansRienDEcritNAttendRien() async throws {
        let jour = try Self.jour("2026-11-16")
        var journal = Journal()
        journal.addSession(minutes: 10, date: jour)
        let b = banc(journal: journal)
        let note = JournalNoteModele(magasin: b.magasin, date: jour, verrou: b.verrou)
        #expect(!note.verrouillee)
        #expect(await note.deverrouiller())
        #expect(b.code.demandes == 0)
    }

    @Test func uneHumeurOuUneGratitudeSuffisentAFermerLaNote() throws {
        let jour = try Self.jour("2026-11-16")
        var humeur = Journal()
        humeur.ecrirePlus(JournalPlus.Plus(avant: 3), pour: jour)
        let b = banc(journal: humeur)
        #expect(JournalNoteModele(magasin: b.magasin, date: jour, verrou: b.verrou).verrouillee)
        var gratitude = Journal()
        gratitude.ecrirePlus(JournalPlus.Plus(gratitude: "Merci"), pour: jour)
        let g = banc(journal: gratitude)
        #expect(JournalNoteModele(magasin: g.magasin, date: jour, verrou: g.verrou).verrouillee)
    }

    @Test func depuisLeJournalOuSansVerrouLaNoteSOuvre() throws {
        let jour = try Self.jour("2026-11-16")
        var journal = Journal()
        journal.setNote(date: jour, note: "Une ligne")
        let b = banc(journal: journal)
        // Le journal a déjà demandé le code : il ouvre ses notes sans verrou.
        #expect(!JournalNoteModele(magasin: b.magasin, date: jour).verrouillee)
        let inactif = banc(demande: false, journal: journal)
        #expect(!JournalNoteModele(magasin: inactif.magasin, date: jour, verrou: inactif.verrou).verrouillee)
    }

    // MARK: Les accueils des versions (AccueilVersion.kt, SereniteActivity.semaine)

    @Test func lesAccueilsTaisentLesNotesQuandLeVerrouEstActif() throws {
        let jour = try Self.jour("2026-11-16")
        var journal = Journal()
        journal.addSession(minutes: 12, date: jour)
        journal.setNote(date: jour, note: "Une ligne")
        let b = banc(journal: journal)
        let horloge = HorlogeFixe(DateHeure(jour, heure: 10), fuseau: .utc)
        let accueil = AccueilVersionModele(magasin: b.magasin, contenus: ContenusApp(lecteur: { _ in nil }),
                                           horloge: horloge, langue: "fr")
        #expect(accueil.donnees.derniereNote?.texte == "Une ligne")
        #expect(accueil.serenite.jours.first?.note == "Une ligne")
        accueil.verrou = b.verrou
        let note = try #require(accueil.donnees.derniereNote)
        #expect(note.texte == nil)
        #expect(note.minutes == 12)
        #expect(accueil.serenite.jours.first?.note == nil)
        b.code.ecranProtege = false
        #expect(accueil.donnees.derniereNote?.texte == "Une ligne")
    }

    // MARK: L'export et l'interrupteur des réglages

    @Test func lExportDemandeLeCode() async {
        let b = banc(reponse: false)
        let reglages = ReglagesModele(apercu: Enregistrement(reglages: b.magasin.reglages))
        #expect(await reglages.exportAutorise())
        reglages.verrouJournal = b.verrou
        #expect(await reglages.exportAutorise() == false)
        #expect(b.code.demandes == 1)
        b.code.reponse = true
        #expect(await reglages.exportAutorise())
    }

    @Test func lInterrupteurDitPourquoiIlResteEteint() async {
        let b = banc(demande: false, ecranProtege: false)
        let reglages = ReglagesModele(apercu: Enregistrement())
        reglages.verrouJournal = b.verrou
        await reglages.poserVerrouJournal(true)
        #expect(reglages.message == Libelle("journal_verrou_sans_code"))
        #expect(!b.magasin.reglages.journalVerrou)
    }

    @Test func lesChainesDuVerrouSontCellesDAndroid() throws {
        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: "fr")
        for cle in ["journal_verrou", "journal_verrou_hint", "journal_verrou_titre", "journal_verrou_sans_code"] {
            #expect(traducteur.texte(Libelle(cle)) != cle, "\(cle)")
        }
    }
}
