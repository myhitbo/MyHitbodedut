import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La minuterie système (tâche 17, PORTAGE.md § 2.2.1) : le réglage propre à iOS, son interrupteur qui demande
/// l'autorisation des alarmes, et l'alarme que la séance pose à son heure de fin, retire quand on la termine ou
/// l'abandonne, et laisse sonner seule à son terme (un seul son, SessionService.finishSession).
///
/// Restent à l'appareil : l'alarme réelle d'AlarmKit, qui sonne téléphone en silencieux.
@Suite("La minuterie système")
@MainActor
struct MinuterieSeanceTests {

    private struct Banc {
        let seance: SeanceEnCours
        let magasin: Magasin
        let horloge: SeanceHorlogeReglable
        let minuterie: FausseMinuterie
        let son: FauxLecteurSon
    }

    private static func banc(minuterieAllumee: Bool = true, masque: Bool = false,
                             autorisation: EtatMinuterie = .accordee) throws -> Banc {
        var reglages = Reglages()
        MinuterieReglage.poser(minuterieAllumee, dans: &reglages)
        reglages.setHideCountdown(masque)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let horloge = SeanceHorlogeReglable(DateHeure(try SeanceOutils.jour("2026-11-16"), heure: 10))
        let minuterie = FausseMinuterie(autorisation: autorisation)
        let son = FauxLecteurSon()
        let seance = SeanceEnCours(magasin: magasin, horloge: horloge, son: son, minuterie: minuterie)
        return Banc(seance: seance, magasin: magasin, horloge: horloge, minuterie: minuterie, son: son)
    }

    // MARK: Le réglage

    @Test func leReglageEstEteintDOrigineEtGardeLesAutresCles() {
        var reglages = Reglages()
        #expect(!MinuterieReglage.lire(reglages))
        reglages.setHideCountdown(true)
        MinuterieReglage.poser(true, dans: &reglages)
        #expect(MinuterieReglage.lire(reglages))
        #expect(reglages.hideCountdown)
        MinuterieReglage.poser(false, dans: &reglages)
        #expect(!MinuterieReglage.lire(reglages))
        // Hors de l'export d'Android : la clé n'y est pas.
        #expect(!Sauvegarde.exporter(journal: Journal(), reglages: reglages, maintenant: 0)
            .contains(MinuterieReglage.cle))
    }

    @Test func lInterrupteurDemandeLAutorisationDesAlarmes() async throws {
        let magasin = Magasin.enMemoire()
        let systeme = FausseMinuterie(autorisation: .aDemander, reponse: true)
        let modele = MinuterieModele(magasin: magasin, systeme: systeme)
        #expect(!modele.actif)
        #expect(try await modele.basculer(true) == nil)
        #expect(await systeme.demandes == 1)
        #expect(MinuterieReglage.lire(magasin.reglages))
        #expect(modele.actif)
        // L'éteindre retire l'alarme d'une séance en cours.
        try await modele.basculer(false)
        #expect(!MinuterieReglage.lire(magasin.reglages))
        #expect(await systeme.retraits == 1)
        #expect(!modele.actif)
    }

    @Test func refuseeLInterrupteurResteEteintEtLeDit() async throws {
        let magasin = Magasin.enMemoire()
        let systeme = FausseMinuterie(autorisation: .aDemander, reponse: false)
        let modele = MinuterieModele(magasin: magasin, systeme: systeme)
        #expect(try await modele.basculer(true) == Libelle("reglages_minuterie_refusee"))
        #expect(!MinuterieReglage.lire(magasin.reglages))
        #expect(modele.etat == .refusee)
        // Déjà refusée : iOS ne repose pas la question.
        #expect(try await modele.basculer(true) == Libelle("reglages_minuterie_refusee"))
        #expect(await systeme.demandes == 1)
    }

    @Test func retireeDansLesReglagesDIOSLInterrupteurSEteint() async throws {
        var reglages = Reglages()
        MinuterieReglage.poser(true, dans: &reglages)
        let systeme = FausseMinuterie(autorisation: .refusee)
        let modele = MinuterieModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)), systeme: systeme)
        await modele.rafraichir()
        #expect(!modele.actif)
    }

    // MARK: L'alarme de la séance

    @Test func uneSeanceMinuteePoseLAlarmeASonHeureDeFin() async throws {
        let b = try Self.banc()
        try await b.seance.commencer(minutes: 20)
        #expect(await b.minuterie.posee == b.seance.fin)
        #expect(await b.minuterie.titre == Libelle("session_done_title"))
        #expect(b.seance.alarmePosee)
    }

    @Test func terminerOuAbandonnerRetireLAlarme() async throws {
        let b = try Self.banc()
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(minutes: 5)
        try await b.seance.terminer()
        #expect(await b.minuterie.posee == nil)
        #expect(!b.seance.alarmePosee)
        try await b.seance.commencer(minutes: 20)
        #expect(await b.minuterie.posee != nil)
        try await b.seance.abandonner()
        #expect(await b.minuterie.posee == nil)
    }

    @Test func auTermeLAlarmeSonneSeule() async throws {
        let b = try Self.banc(masque: true)
        try await b.seance.commencer(minutes: 1)
        b.horloge.avancer(minutes: 1, secondes: 1)
        try await b.seance.actualiser()
        // Ni retirée (elle sonne), ni doublée du son de l'app.
        #expect(await b.minuterie.posee != nil)
        #expect(await b.son.joues.isEmpty)
        #expect(!b.seance.alarmePosee)
    }

    @Test func sansLeReglageNiLAutorisationRienNEstPose() async throws {
        let eteinte = try Self.banc(minuterieAllumee: false, masque: true)
        try await eteinte.seance.commencer(minutes: 1)
        #expect(await eteinte.minuterie.poses == 0)
        eteinte.horloge.avancer(minutes: 1, secondes: 1)
        try await eteinte.seance.actualiser()
        // Le son de fin d'un décompte masqué, comme avant.
        #expect(await eteinte.son.joues == [SeanceEnCours.sonDeFin])

        let refusee = try Self.banc(masque: true, autorisation: .refusee)
        try await refusee.seance.commencer(minutes: 1)
        #expect(!refusee.seance.alarmePosee)
        refusee.horloge.avancer(minutes: 1, secondes: 1)
        try await refusee.seance.actualiser()
        #expect(await refusee.son.joues == [SeanceEnCours.sonDeFin])
    }

    @Test func uneSeanceSansDureeNaPasDAlarme() async throws {
        let b = try Self.banc()
        try await b.seance.commencer(minutes: SessionRule.ouverte)
        #expect(await b.minuterie.poses == 0)
        #expect(!b.seance.alarmePosee)
    }

    @Test func uneNouvelleSeanceRemplaceLAlarmeDeLaPrecedente() async throws {
        let b = try Self.banc()
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(minutes: 2)
        try await b.seance.commencer(minutes: 30)
        #expect(await b.minuterie.posee == b.seance.fin)
        #expect(await b.minuterie.retraits == 1)
        #expect(await b.minuterie.poses == 2)
    }

    @Test func lesChainesDeLaMinuterieSontDansLeCatalogueDIOS() throws {
        let android = try Fichiers.catalogue()
        let ios = try Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings")
        for langue in Traducteur.langues {
            let traducteur = try Traducteur(catalogues: [android, ios], langue: langue)
            for cle in ["reglages_minuterie_systeme", "reglages_minuterie_systeme_indication", "reglages_minuterie_refusee",
                        "session_done_title"] {
                #expect(traducteur.texte(cle: cle) != cle, "\(cle) en \(langue)")
            }
        }
    }
}
