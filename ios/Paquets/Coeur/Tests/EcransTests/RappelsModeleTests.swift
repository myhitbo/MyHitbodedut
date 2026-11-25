import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le banc de l'écran des rappels : sa persistance (qui garde ce qui est écrit), son magasin, un notificateur qui
/// accorde ou refuse, et des rappels qui retiennent chaque replanification.
@MainActor
private struct RappelsBanc {
    let persistance: PersistanceEnMemoire
    let magasin: Magasin
    let notificateur: FauxNotificateur
    let rappels: PresentationRappelsEnMemoire
    let modele: RappelsModele

    init(_ reglages: Reglages = Reglages(), accordee: Bool = true) {
        let enregistrement = Enregistrement(reglages: reglages)
        persistance = PersistanceEnMemoire(enregistrement)
        magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        notificateur = FauxNotificateur(accordee: accordee)
        rappels = PresentationRappelsEnMemoire()
        modele = RappelsModele(magasin: magasin, notificateur: notificateur, rappels: rappels)
    }

    /// Des réglages au rappel allumé, à ces heures.
    static func reglages(actif: Bool = true, heures: [Int]) -> Reglages {
        var r = Reglages()
        r.setReminderEnabled(actif)
        r.setReminderTimes(heures)
        return r
    }
}

/// Les règles de RemindersActivity.kt qui se vérifient par des valeurs : le résumé du bandeau, la liste des heures,
/// l'ajout, le changement et le retrait d'une heure, l'interrupteur général et l'autorisation des notifications, le
/// trophée tout proche, ce qui s'écrit sous les clés d'Android, et la replanification après chaque changement. La
/// normalisation des heures (Store.setReminderTimes) est jugée dans CoeurTests ; le layout reste à Android.
@Suite("Modèle des rappels")
@MainActor
struct RappelsModeleTests {

    // MARK: Le bandeau

    @Test func leResumeSuitLInterrupteurEtLesHeures() {
        let eteints = RappelsModele(apercu: RappelsBanc.reglages(actif: false, heures: [420]))
        #expect(eteints.resume == Libelle("reminders_off"))
        let sans = RappelsModele(apercu: RappelsBanc.reglages(heures: []))
        #expect(sans.resume == Libelle("reminders_none"))
        let deux = RappelsModele(apercu: RappelsBanc.reglages(heures: [1260, 420]))
        #expect(deux.resume == Libelle.pluriel("reminders_count", quantite: 2, .entier(2)))
    }

    @Test func uneInstallationNeuveAUnRappelEteintA7h() {
        let m = RappelsModele(apercu: Reglages())
        #expect(!m.actif)
        #expect(m.resume == Libelle("reminders_off"))
        let heures = m.heures
        #expect(heures == [RappelsHeure(rang: 0, minutes: 420, texte: "07:00")])
        #expect(m.tropheeProche)
        #expect(m.dialogue == nil)
        #expect(m.avertissement == nil)
        #expect(m.diagnosticVisible)
    }

    @Test func lIllustrationSuitLAdresse() {
        #expect(RappelsModele(apercu: Reglages()).illustration == "char_pointing")
        var r = Reglages()
        r.setAdresse(Adresse.femme.cle)
        #expect(RappelsModele(apercu: r).illustration == "char_f_pointing")
    }

    @Test func lesHeuresSontTrieesEtEcritesEn24Heures() {
        let m = RappelsModele(apercu: RappelsBanc.reglages(heures: [1260, 425, 0]))
        let textes = m.heures.map { $0.texte }
        #expect(textes == ["00:00", "07:05", "21:00"])
        let rangs = m.heures.map { $0.rang }
        #expect(rangs == [0, 1, 2])
    }

    // MARK: L'ajout

    @Test func lAjoutPartDeLaDerniereHeure() {
        let m = RappelsModele(apercu: RappelsBanc.reglages(heures: [420, 1290]))
        m.ouvrirAjout()
        #expect(m.dialogue == .ajout)
        #expect(m.heureDialogue == 21)
        #expect(m.minuteDialogue == 30)
    }

    @Test func lAjoutSansHeurePartDe7h() {
        let m = RappelsModele(apercu: RappelsBanc.reglages(heures: []))
        m.ouvrirAjout()
        #expect(m.heureDialogue == 7)
        #expect(m.minuteDialogue == 0)
    }

    /// Une heure d'une ancienne version, hors du jour, se ramène dans le jour comme Android la donne au sélecteur ;
    /// une négative aussi, au lieu de le faire planter.
    @Test func uneHeureHorsDuJourSeRameneDansLeJour() throws {
        let m = RappelsModele(apercu: try Reglages(texte: #"{"reminder_minutes":-30}"#))
        m.ouvrirAjout()
        #expect(m.heureDialogue == 23)
        #expect(m.minuteDialogue == 30)
        let tard = RappelsModele(apercu: try Reglages(texte: #"{"reminder_minutes":1500}"#))
        tard.ouvrirAjout()
        #expect(tard.heureDialogue == 1)
        #expect(tard.minuteDialogue == 0)
    }

    @Test func ajouterUneHeureLEcritSousLesClesDAndroidEtReplanifie() async throws {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        banc.modele.ouvrirAjout()
        await banc.modele.choisir(heure: 21, minute: 30)
        #expect(banc.modele.dialogue == nil)
        #expect(banc.magasin.reglages.reminderTimes == [420, 1290])
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.brut["reminder_times"] == .chaine("420,1290"))
        #expect(ecrits.brut["reminder_minutes"] == .entier(420))
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
        let derniere = try #require(replanifications.last)
        #expect(derniere.reminderTimes == [420, 1290])
        #expect(banc.modele.resume == Libelle.pluriel("reminders_count", quantite: 2, .entier(2)))
    }

    /// Ajouter une heure n'allume pas le rappel, comme sur Android.
    @Test func ajouterNAllumePasLeRappel() async {
        let banc = RappelsBanc(RappelsBanc.reglages(actif: false, heures: [420]))
        banc.modele.ouvrirAjout()
        await banc.modele.choisir(heure: 12, minute: 0)
        #expect(!banc.modele.actif)
        #expect(banc.magasin.reglages.reminderTimes == [420, 720])
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
    }

    @Test func uneHeureDejaRegleeNeSeDoublePas() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        banc.modele.ouvrirAjout()
        await banc.modele.choisir(heure: 7, minute: 0)
        #expect(banc.magasin.reglages.reminderTimes == [420])
    }

    @Test func choisirSansFenetreOuverteNeFaitRien() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        await banc.modele.choisir(heure: 9, minute: 0)
        #expect(banc.magasin.reglages.reminderTimes == [420])
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.isEmpty)
    }

    @Test func fermerLeChoixNeChangeRien() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        banc.modele.ouvrirAjout()
        banc.modele.fermerDialogue()
        #expect(banc.modele.dialogue == nil)
        #expect(banc.magasin.reglages.reminderTimes == [420])
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.isEmpty)
    }

    // MARK: Le changement

    @Test func toucherUneLigneOuvreSonHeure() {
        let m = RappelsModele(apercu: RappelsBanc.reglages(heures: [420, 1260]))
        m.ouvrirModification(1)
        #expect(m.dialogue == .modification(1))
        #expect(m.heureDialogue == 21)
        #expect(m.minuteDialogue == 0)
    }

    @Test func uneLigneHorsDeLaListeNOuvreRien() {
        let m = RappelsModele(apercu: RappelsBanc.reglages(heures: [420]))
        m.ouvrirModification(1)
        #expect(m.dialogue == nil)
        m.ouvrirModification(-1)
        #expect(m.dialogue == nil)
    }

    @Test func changerUneHeureLaRemplaceEtRetrie() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420, 1260]))
        banc.modele.ouvrirModification(1)
        await banc.modele.choisir(heure: 6, minute: 15)
        #expect(banc.magasin.reglages.reminderTimes == [375, 420])
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.brut["reminder_times"] == .chaine("375,420"))
        // L'ancienne clé suit la première heure, pour l'export.
        #expect(ecrits.brut["reminder_minutes"] == .entier(375))
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
    }

    @Test func changerUneHeurePourUneAutreDejaRegleeLesFond() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420, 1260]))
        banc.modele.ouvrirModification(1)
        await banc.modele.choisir(heure: 7, minute: 0)
        #expect(banc.magasin.reglages.reminderTimes == [420])
    }

    // MARK: Le retrait

    @Test func retirerUneHeure() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420, 1260]))
        await banc.modele.retirer(0)
        #expect(banc.magasin.reglages.reminderTimes == [1260])
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.brut["reminder_times"] == .chaine("1260"))
        #expect(ecrits.brut["reminder_minutes"] == .entier(1260))
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
    }

    /// Sans heure, la liste écrite est vide et l'ancienne clé revient à 7 h (Store.setReminderTimes) ; le rappel
    /// allumé n'a plus rien à faire sonner.
    @Test func retirerLaDerniereHeureLaisseUneListeVide() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [1260]))
        await banc.modele.retirer(0)
        #expect(banc.magasin.reglages.reminderTimes.isEmpty)
        #expect(banc.modele.heures.isEmpty)
        #expect(banc.modele.resume == Libelle("reminders_none"))
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.brut["reminder_times"] == .chaine(""))
        #expect(ecrits.brut["reminder_minutes"] == .entier(420))
    }

    @Test func retirerHorsDeLaListeNeFaitRien() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        await banc.modele.retirer(3)
        #expect(banc.magasin.reglages.reminderTimes == [420])
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.isEmpty)
    }

    // MARK: L'interrupteur général

    @Test func allumerAvecLAutorisationReplanifieSansRienDemander() async {
        let banc = RappelsBanc(RappelsBanc.reglages(actif: false, heures: [420]))
        let route = await banc.modele.basculer(true)
        #expect(route == nil)
        #expect(banc.modele.actif)
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.brut["reminder_on"] == .booleen(true))
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
        let actifs = replanifications.map { $0.reminderEnabled }
        #expect(actifs == [true])
        #expect(banc.modele.avertissement == nil)
    }

    @Test func eteindreReplanifieSansRienDemander() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]), accordee: false)
        let route = await banc.modele.basculer(false)
        #expect(route == nil)
        #expect(!banc.modele.actif)
        #expect(banc.modele.resume == Libelle("reminders_off"))
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 0)
        let replanifications = await banc.rappels.replanifications
        let actifs = replanifications.map { $0.reminderEnabled }
        #expect(actifs == [false])
    }

    @Test func unInterrupteurRemisASaPlaceNeFaitRien() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        let route = await banc.modele.basculer(true)
        #expect(route == nil)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.isEmpty)
    }

    /// demandeNotificationsSiBesoin : la question d'iOS la première fois ; refusée, l'avertissement le dit, et la
    /// suite passe par les Réglages d'iOS, qui ne reposent jamais la question.
    @Test func allumerSansAutorisationPoseLaQuestionPuisMeneAuxReglages() async {
        let banc = RappelsBanc(RappelsBanc.reglages(actif: false, heures: [420]), accordee: false)
        let premiere = await banc.modele.basculer(true)
        #expect(premiere == nil)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 1)
        // Le rappel reste allumé et replanifié : sans autorisation, il est posé et ne s'affiche pas.
        #expect(banc.modele.actif)
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
        #expect(banc.modele.avertissement == Libelle("reminders_permission_missing"))
        let toucher = await banc.modele.toucherAvertissement()
        #expect(toucher == .reglagesNotifications)
        _ = await banc.modele.basculer(false)
        let rallumer = await banc.modele.basculer(true)
        #expect(rallumer == .reglagesNotifications)
        let toujours = await banc.notificateur.demandes
        #expect(toujours == 1)
    }

    @Test func lAvertissementAttendLaLectureDuSysteme() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]), accordee: false)
        #expect(banc.modele.avertissement == nil)
        await banc.modele.rafraichir()
        #expect(banc.modele.systemeLu)
        #expect(!banc.modele.notificationsAccordees)
        #expect(banc.modele.avertissement == Libelle("reminders_permission_missing"))
    }

    @Test func pasDAvertissementRappelEteintOuAutorise() async {
        let eteint = RappelsBanc(RappelsBanc.reglages(actif: false, heures: [420]), accordee: false)
        await eteint.modele.rafraichir()
        #expect(eteint.modele.avertissement == nil)
        let autorise = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        await autorise.modele.rafraichir()
        #expect(autorise.modele.notificationsAccordees)
        #expect(autorise.modele.avertissement == nil)
    }

    @Test func toucherLAvertissementPoseDAbordLaQuestion() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]), accordee: false)
        await banc.modele.rafraichir()
        let route = await banc.modele.toucherAvertissement()
        #expect(route == nil)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 1)
    }

    // MARK: Le trophée tout proche

    /// Sur iOS la phrase du trophée s'écrit à la programmation : l'interrupteur fait replanifier.
    @Test func leTropheeToutProcheSEcritEtReplanifie() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        await banc.modele.basculerTropheeProche(false)
        #expect(!banc.modele.tropheeProche)
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.brut["rappel_trophee_proche"] == .booleen(false))
        let replanifications = await banc.rappels.replanifications
        #expect(replanifications.count == 1)
        let trophees = replanifications.map { $0.rappelTropheeProche }
        #expect(trophees == [false])
        await banc.modele.basculerTropheeProche(false)
        let encore = await banc.rappels.replanifications
        #expect(encore.count == 1)
    }

    // MARK: Une écriture refusée

    /// Comme Store sur Android, une écriture refusée ne dit rien : le changement reste en mémoire, et la
    /// replanification le suit.
    @Test func uneEcritureRefuseeResteEnMemoireEtReplanifie() async {
        let banc = RappelsBanc(RappelsBanc.reglages(heures: [420]))
        await banc.persistance.faireEchouer(true)
        banc.modele.ouvrirAjout()
        await banc.modele.choisir(heure: 20, minute: 0)
        #expect(banc.magasin.reglages.reminderTimes == [420, 1200])
        let ecrits = await banc.persistance.enregistrement.reglages
        #expect(ecrits.reminderTimes == [420])
        let replanifications = await banc.rappels.replanifications
        let heures = replanifications.map { $0.reminderTimes }
        #expect(heures == [[420, 1200]])
    }

    // MARK: Les chaînes

    /// Les textes de l'écran sont les chaînes d'Android, en trois langues ; celle du diagnostic est propre à iOS.
    @Test func chaqueCleEstAuCatalogueEnTroisLangues() throws {
        let android = try CatalogueBrut.lire()
        let ios = try JSONDecoder().decode(CatalogueBrut.self,
                                           from: Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings"))
        let m = RappelsModele(apercu: Reglages())
        let deAndroid = [m.titre.cle, m.libelleInterrupteur.cle, m.indicationInterrupteur.cle,
                         m.libelleTropheeProche.cle, m.titreHeures.cle, m.indicationHeures.cle, m.indicationJours.cle,
                         m.libelleAjouter.cle, m.libelleRetirer.cle, "reminders_off", "reminders_none",
                         "reminders_permission_missing"]
        for cle in deAndroid {
            for langue in Traducteur.langues {
                let valeur = android.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue)")
            }
        }
        for langue in Traducteur.langues {
            let autre = android.forme("reminders_count", "other", langue: langue) ?? ""
            #expect(!autre.isEmpty, "« reminders_count » manque en \(langue)")
        }
        let neuve = m.libelleDiagnostic.cle
        let chezAndroid = android.strings[neuve] != nil
        #expect(!chezAndroid)
        for langue in Traducteur.langues {
            let valeur = ios.valeur(neuve, langue: langue) ?? ""
            #expect(!valeur.isEmpty, "« \(neuve) » manque en \(langue)")
        }
    }
}
