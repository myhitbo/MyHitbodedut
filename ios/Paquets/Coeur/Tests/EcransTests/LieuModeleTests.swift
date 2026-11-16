import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le choix du lieu (ChoixLieu.kt) : la position simulée devient « Ma position · près de … » en précision
/// approximative, avec le fuseau du téléphone et Israël d'après le territoire ; une ville de la liste ; la reprise
/// silencieuse, seulement si la localisation est déjà permise ; les messages brefs.
@Suite("Choix du lieu")
@MainActor
struct LieuModeleTests {

    /// Un modèle sur les villes du dépôt, l'horloge arrêtée à midi du 12 octobre 2026 dans `fuseau`.
    private func fabriquer(_ reglages: Reglages = Reglages(), reponse: ReponseLocalisation?, permise: Bool = true,
                           fuseau: String = "Asia/Jerusalem", langue: String = "fr", heure: Int = 12)
        throws -> (LieuModele, Magasin, FausseLocalisation?, ZmanimHorlogeMobile) {
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let telephone = try #require(Fuseau(fuseau))
        let horloge = ZmanimHorlogeMobile(DateHeure(jour, heure: heure), fuseau: telephone)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let localisation = reponse.map { FausseLocalisation($0) }
        let traducteur = try ZmanimEssais.traducteur(langue)
        let modele = LieuModele(magasin: magasin, contenus: ZmanimEssais.contenus, localisation: localisation,
                                autorisation: LieuAutorisationFausse(permise: permise), horloge: horloge,
                                traducteur: traducteur)
        return (modele, magasin, localisation, horloge)
    }

    // MARK: Ma position

    @Test func laPositionPresDeJerusalemPrendLeNomDeLaVille() async throws {
        let position = PositionApprochee(latitude: 31.78, longitude: 35.20)
        let (modele, magasin, localisation, horloge) = try fabriquer(reponse: .position(position))
        try await modele.maPosition()
        let lieu = try #require(magasin.reglages.lieuZmanim)
        #expect(lieu.nom == "Ma position · près de Jérusalem")
        #expect(lieu.latitude == 31.78)
        #expect(lieu.longitude == 35.20)
        // Le fuseau du téléphone, pas celui de la ville ; Israël d'après le territoire.
        #expect(lieu.fuseau == "Asia/Jerusalem")
        #expect(magasin.reglages.lieuVille == -1)
        #expect(magasin.reglages.inIsrael(fuseauTelephone: "Europe/Paris"))
        #expect(magasin.reglages.lieuDepuis == horloge.maintenant)
        #expect(modele.message == nil)
        #expect(!modele.enCours)
        let demandes = await localisation?.demandes
        #expect(demandes == 1)
        // L'onglet Zmanim le montre dans sa pastille : « Ma position · près de Jérusalem · Israël ».
        let zmanim = ZmanimModele(magasin: magasin, horloge: horloge)
        let fr = try ZmanimEssais.traducteur()
        let pastille = zmanim.lieuTexte.map { fr.texte($0) }
        #expect(pastille == "Ma position · près de Jérusalem · Israël")
    }

    @Test func enHebreuLeNomEstEcritEnHebreu() async throws {
        let position = PositionApprochee(latitude: 31.78, longitude: 35.20)
        let (modele, magasin, _, _) = try fabriquer(reponse: .position(position), langue: "he")
        try await modele.maPosition()
        let nom = magasin.reglages.lieuZmanim?.nom
        #expect(nom == "המיקום שלי · ליד ירושלים")
    }

    /// Un voyageur en Israël dont le téléphone est resté à l'heure de Paris : le fuseau du téléphone, mais Israël.
    @Test func leFuseauDuTelephoneEtIsraelDuTerritoire() async throws {
        let position = PositionApprochee(latitude: 32.08, longitude: 34.78)
        let (modele, magasin, _, _) = try fabriquer(reponse: .position(position), fuseau: "Europe/Paris")
        try await modele.maPosition()
        let lieu = try #require(magasin.reglages.lieuZmanim)
        #expect(lieu.nom == "Ma position · près de Tel Aviv")
        #expect(lieu.fuseau == "Europe/Paris")
        #expect(magasin.reglages.inIsrael(fuseauTelephone: "Europe/Paris"))
    }

    @Test func aParisLaDiaspora() async throws {
        let position = PositionApprochee(latitude: 48.86, longitude: 2.35)
        let (modele, magasin, _, _) = try fabriquer(reponse: .position(position), fuseau: "Europe/Paris")
        try await modele.maPosition()
        let nom = magasin.reglages.lieuZmanim?.nom
        #expect(nom == "Ma position · près de Paris")
        #expect(!magasin.reglages.inIsrael(fuseauTelephone: "Asia/Jerusalem"))
    }

    /// Loin de toute ville de la liste (plus de 60 km) : « Ma position », au niveau de la mer.
    @Test func loinDeToutePositionSansVille() async throws {
        let position = PositionApprochee(latitude: 0, longitude: -30)
        let (modele, magasin, _, _) = try fabriquer(reponse: .position(position), fuseau: "UTC")
        try await modele.maPosition()
        let lieu = try #require(magasin.reglages.lieuZmanim)
        #expect(lieu.nom == "Ma position")
        #expect(lieu.altitude == 0)
        let villes = try await ZmanimEssais.contenus.villes()
        let telephone = try #require(Fuseau("UTC"))
        let fr = try ZmanimEssais.traducteur()
        let direct = LieuModele.lieu(position, villes: villes, fuseauTelephone: telephone, traducteur: fr)
        #expect(direct == lieu)
    }

    @Test func unRefusLeDitEtNeChangeRien() async throws {
        let (modele, magasin, _, _) = try fabriquer(reponse: .refusee)
        try await modele.maPosition()
        #expect(modele.message == LieuMessage.refusee)
        #expect(magasin.reglages.lieuZmanim == nil)
        let message = try #require(modele.message)
        #expect(message.libelle == Libelle("zmanim_position_refusee"))
        #expect(message.long)
        modele.messageVu()
        #expect(modele.message == nil)
        let (sansReponse, _, _, _) = try fabriquer(reponse: .indisponible)
        try await sansReponse.maPosition()
        #expect(sansReponse.message == LieuMessage.refusee)
        // Sans service de localisation (un aperçu) : le même message.
        let (sansService, _, _, _) = try fabriquer(reponse: nil)
        try await sansService.maPosition()
        #expect(sansService.message == LieuMessage.refusee)
        #expect(LieuMessage.attente.libelle == Libelle("zmanim_position_attente"))
        #expect(!LieuMessage.attente.long)
        #expect(LieuMessage.ancienne.libelle == Libelle("zmanim_position_ancienne"))
    }

    // MARK: Une ville

    @Test func uneVilleDeLaListe() async throws {
        let (modele, magasin, localisation, horloge) = try fabriquer(reponse: .refusee)
        await modele.charger()
        let options = modele.options
        let villes = try await ZmanimEssais.contenus.villes()
        #expect(options.count == villes.count + 1)
        let premiere = try #require(options.first)
        #expect(premiere.id == "position")
        #expect(premiere.nom == LieuNom.libelle(Libelle("zmanim_position")))
        #expect(premiere.ville == nil)
        let trouvee = options.first { $0.id == String(ZmanimEssais.paris) }
        let paris = try #require(trouvee)
        #expect(paris.nom == LieuNom.texte("Paris"))
        modele.montrer()
        #expect(modele.dialogueOuvert)
        try await modele.choisir(paris)
        #expect(!modele.dialogueOuvert)
        let lieu = try #require(magasin.reglages.lieuZmanim)
        #expect(lieu.nom == "Paris")
        #expect(lieu.fuseau == "Europe/Paris")
        #expect(magasin.reglages.lieuVille == ZmanimEssais.paris)
        #expect(!magasin.reglages.inIsrael(fuseauTelephone: "Asia/Jerusalem"))
        #expect(magasin.reglages.lieuDepuis == horloge.maintenant)
        let demandes = await localisation?.demandes
        #expect(demandes == 0)
        #expect(modele.titre == Libelle("zmanim_choisir_lieu"))
    }

    @Test func lesNomsDesVillesDansLaLangueDeLApp() async throws {
        let (modele, magasin, _, _) = try fabriquer(reponse: nil, langue: "he")
        await modele.charger()
        let trouvee = modele.options.first { $0.id == String(ZmanimEssais.jerusalem) }
        let jerusalem = try #require(trouvee)
        #expect(jerusalem.nom == LieuNom.texte("ירושלים"))
        try await modele.choisir(jerusalem)
        let nom = magasin.reglages.lieuZmanim?.nom
        #expect(nom == "ירושלים")
        // Jérusalem, ville murée : Pourim le 15 Adar.
        #expect(magasin.reglages.mukafChoma)
        #expect(magasin.reglages.inIsrael(fuseauTelephone: "Europe/Paris"))
    }

    // MARK: La reprise silencieuse

    @Test func laPositionSeReprendSansBruitSiElleEstPermise() async throws {
        var reglages = Reglages()
        let ancienne = Zmanim.Lieu(nom: "Ma position", latitude: 48.86, longitude: 2.35, fuseau: "Europe/Paris")
        reglages.setLieuZmanim(ancienne, ville: nil, maintenant: 0)
        let position = PositionApprochee(latitude: 31.78, longitude: 35.20)
        let (modele, magasin, localisation, _) = try fabriquer(reglages, reponse: .position(position))
        try await modele.rafraichir()
        #expect(modele.message == nil)
        let nom = magasin.reglages.lieuZmanim?.nom
        #expect(nom == "Ma position · près de Jérusalem")
        let demandes = await localisation?.demandes
        #expect(demandes == 1)
        // Un échec silencieux ne dit rien.
        let (muet, _, _, _) = try fabriquer(reglages, reponse: .indisponible)
        try await muet.rafraichir()
        #expect(muet.message == nil)
    }

    @Test func rienNEstDemandeSansPermissionNiPourUneVille() async throws {
        var reglages = Reglages()
        let ancienne = Zmanim.Lieu(nom: "Ma position", latitude: 48.86, longitude: 2.35, fuseau: "Europe/Paris")
        reglages.setLieuZmanim(ancienne, ville: nil, maintenant: 0)
        let position = PositionApprochee(latitude: 31.78, longitude: 35.20)
        let (nonPermise, _, localisation, _) = try fabriquer(reglages, reponse: .position(position), permise: false)
        try await nonPermise.rafraichir()
        let demandes = await localisation?.demandes
        #expect(demandes == 0)
        // Une ville choisie ne se reprend pas.
        let paris = try await ZmanimEssais.ville(ZmanimEssais.paris)
        let (ville, magasin, localisationVille, _) = try fabriquer(ZmanimEssais.reglages(paris), reponse: .position(position))
        try await ville.rafraichir()
        let demandesVille = await localisationVille?.demandes
        #expect(demandesVille == 0)
        let nom = magasin.reglages.lieuZmanim?.nom
        #expect(nom == "Paris")
        // Sans lieu non plus.
        let (vide, _, localisationVide, _) = try fabriquer(reponse: .position(position))
        try await vide.rafraichir()
        let demandesVide = await localisationVide?.demandes
        #expect(demandesVide == 0)
    }

    /// Au retour sur l'accueil : seulement une position vieille de six heures, ou prise dans un autre fuseau.
    @Test func auRetourSurLAccueilSeulementSiPerimeeOuVieille() async throws {
        let position = PositionApprochee(latitude: 31.78, longitude: 35.20)
        let (modele, _, localisation, horloge) = try fabriquer(reponse: .position(position))
        try await modele.maPosition()
        horloge.avancer(heures: 5)
        try await modele.rafraichirSiBesoin()
        let apresCinq = await localisation?.demandes
        #expect(apresCinq == 1)
        horloge.avancer(heures: 1)
        try await modele.rafraichirSiBesoin()
        let apresSix = await localisation?.demandes
        #expect(apresSix == 2)
        // Une position prise dans un autre fuseau que celui du téléphone : périmée, reprise tout de suite.
        var reglages = Reglages()
        let quittee = Zmanim.Lieu(nom: "Ma position", latitude: 48.86, longitude: 2.35, fuseau: "Europe/Paris")
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let telephone = try #require(Fuseau("Asia/Jerusalem"))
        reglages.setLieuZmanim(quittee, ville: nil, maintenant: telephone.millis(DateHeure(jour, heure: 11)))
        let (voyage, _, localisationVoyage, _) = try fabriquer(reglages, reponse: .position(position))
        try await voyage.rafraichirSiBesoin()
        let demandesVoyage = await localisationVoyage?.demandes
        #expect(demandesVoyage == 1)
    }

    /// L'onglet Zmanim reprend la position à son apparition.
    @Test func lOngletZmanimReprendLaPositionALApparition() async throws {
        var reglages = Reglages()
        let ancienne = Zmanim.Lieu(nom: "Ma position", latitude: 48.86, longitude: 2.35, fuseau: "Europe/Paris")
        reglages.setLieuZmanim(ancienne, ville: nil, maintenant: 0)
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let telephone = try #require(Fuseau("Asia/Jerusalem"))
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let localisation = FausseLocalisation(.position(PositionApprochee(latitude: 31.78, longitude: 35.20)))
        let fr = try ZmanimEssais.traducteur()
        let modele = ZmanimModele(magasin: magasin, horloge: HorlogeFixe(DateHeure(jour, heure: 9), fuseau: telephone),
                                  contenus: ZmanimEssais.contenus, localisation: localisation,
                                  autorisation: LieuAutorisationFausse(permise: true), traducteur: fr)
        await modele.apparaitre()
        let nom = modele.lieu?.nom
        #expect(nom == "Ma position · près de Jérusalem")
        #expect(modele.enIsrael)
    }
}
