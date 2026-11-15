import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les faux des services, que les tests des écrans recevront : ils font ce que leur protocole promet.
@Suite("Services")
struct ServicesTests {

    private func rappel(_ identifiant: String, _ instant: Int64) -> NotificationPrevue {
        NotificationPrevue(identifiant: identifiant, instant: instant,
                           titre: Libelle("reminder_title"), corps: Libelle("reminder_text"))
    }

    @Test func leNotificateurRemplaceCeQuiAMemeIdentifiant() async throws {
        let faux = FauxNotificateur()
        let service: any Notificateur = faux
        let accordee = await service.demanderAutorisation()
        #expect(accordee)
        try await service.programmer([rappel("rappel_1", 1000), rappel("rappel_2", 2000)])
        try await service.programmer([rappel("rappel_1", 3000)])
        let prevues = await faux.prevues
        let lues = prevues.map { "\($0.identifiant)@\($0.instant)" }
        #expect(lues == ["rappel_2@2000", "rappel_1@3000"])
        await service.annulerTout()
        let restantes = await faux.prevues
        #expect(restantes.isEmpty)
        let annulations = await faux.annulations
        #expect(annulations == 1)
    }

    @Test func unNotificateurRefuse() async {
        let service: any Notificateur = FauxNotificateur(accordee: false)
        let accordee = await service.demanderAutorisation()
        #expect(!accordee)
        let etat = await service.autorisation()
        #expect(!etat)
    }

    @Test func laLocalisationRendSaReponseAChaqueDemande() async {
        let paris = PositionApprochee(latitude: 48.85, longitude: 2.35)
        let faux = FausseLocalisation(.position(paris))
        let service: any Localisation = faux
        let reponse = await service.positionApprochee()
        #expect(reponse == .position(paris))
        let demandes = await faux.demandes
        #expect(demandes == 1)
        let refusee = await FausseLocalisation(.refusee).positionApprochee()
        #expect(refusee == .refusee)
    }

    @Test func leSonLaBarriereEtLActiviteEnDirect() async throws {
        let son = FauxLecteurSon()
        let lecteur: any LecteurSon = son
        try await lecteur.jouer(fichier: "Musique/hamelech_basade.m4a", volume: 60)
        let enCours = await son.enCours
        #expect(enCours == "Musique/hamelech_basade.m4a")
        await son.arreter()
        let arrete = await son.enCours
        #expect(arrete == nil)

        let barriere = FauxTempsEcran()
        let autorisee = await barriere.demanderAutorisation()
        #expect(autorisee)
        await barriere.leverBoucliers()
        let levees = await barriere.levees
        #expect(levees == 1)

        let activite = FausseActiviteEnDirect()
        let direct: any ActiviteEnDirect = activite
        try await direct.commencer(debut: 1000, fin: 61000)
        let fin = await activite.seance?.fin
        #expect(fin == 61000)
        await activite.terminer()
        let finie = await activite.seance == nil
        #expect(finie)
    }
}
