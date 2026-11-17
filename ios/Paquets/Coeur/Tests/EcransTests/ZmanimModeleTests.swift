import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le modèle de l'onglet Zmanim s'en tient à ce que rendent les règles de Coeur. C'est aussi la
/// preuve que les modèles d'écran (Observation, acteur principal) se construisent et se testent sous Linux.
@Suite("Modèle de l'onglet Zmanim")
@MainActor
struct ZmanimModeleTests {

    private let jerusalem = Zmanim.Lieu(nom: "Jérusalem", latitude: 31.76904, longitude: 35.21633, fuseau: "Asia/Jerusalem")

    @Test func sansLieuAucunHoraire() throws {
        let jour = try #require(JourCivil(iso: "2026-11-13"))
        let modele = ZmanimModele(lieu: nil, jour: jour, enIsrael: true)
        let horaires = modele.horaires
        #expect(horaires.isEmpty)
    }

    @Test func lesHorairesSontCeuxDeJourAffiche() throws {
        let vendredi = try #require(JourCivil(iso: "2026-11-13"))
        let modele = ZmanimModele(lieu: jerusalem, jour: vendredi, enIsrael: true)
        let obtenus = modele.horaires.map { $0.cle }
        let attendus = JourAffiche.horaires(lieu: jerusalem, date: vendredi, enIsrael: true,
                                            minutes: Zmanim.allumageDefaut).map { $0.cle }
        #expect(obtenus == attendus)
        // Un vendredi, l'allumage s'ajoute aux quinze zmanim du profil.
        let allumage = obtenus.contains("allumage")
        #expect(allumage)
        #expect(obtenus.count == Zmanim.profil.count + 1)
    }

    @Test func leJourAvanceEtRecule() throws {
        let jour = try #require(JourCivil(iso: "2026-12-31"))
        let modele = ZmanimModele(lieu: jerusalem, jour: jour, enIsrael: false)
        modele.jourSuivant()
        #expect(modele.jour.iso == "2027-01-01")
        modele.jourPrecedent()
        modele.jourPrecedent()
        #expect(modele.jour.iso == "2026-12-30")
        let hebreu = modele.jourHebreu
        #expect(hebreu.date == modele.jour)
    }

    // MARK: Du Magasin et de l'horloge

    private let paris = Zmanim.Lieu(nom: "Paris", latitude: 48.85341, longitude: 2.3488, fuseau: "Europe/Paris")

    /// Un magasin en mémoire, sa persistance, et un modèle dont l'horloge est arrêtée à `heure` du jour `iso`.
    private func fabriquer(_ reglages: Reglages, _ iso: String, heure: Int, fuseau: String)
        throws -> (ZmanimModele, Magasin, PersistanceEnMemoire) {
        let jour = try #require(JourCivil(iso: iso))
        let fuseauLu = try #require(Fuseau(fuseau))
        let persistance = PersistanceEnMemoire(Enregistrement(reglages: reglages))
        let magasin = Magasin(persistance: persistance, enregistrement: Enregistrement(reglages: reglages))
        let horloge = HorlogeFixe(DateHeure(jour, heure: heure), fuseau: fuseauLu)
        return (ZmanimModele(magasin: magasin, horloge: horloge), magasin, persistance)
    }

    @Test func leLieuLeJourEtLesReglagesViennentDuMagasinEtDeLHorloge() throws {
        var reglages = Reglages()
        reglages.setLieuZmanim(paris, ville: nil, maintenant: 0)
        reglages.setAllumage(30)
        let (modele, _, _) = try fabriquer(reglages, "2026-11-13", heure: 9, fuseau: "Europe/Paris")
        #expect(modele.jour.iso == "2026-11-13")
        #expect(modele.estAujourdhui)
        let lieu = modele.lieu
        #expect(lieu == paris)
        // Un lieu hors d'Israël règle la diaspora (Store.setLieuZmanim).
        #expect(!modele.enIsrael)
        #expect(modele.allumage == 30)
        let vendredi = modele.jour
        let obtenus = modele.horaires
        let attendus = JourAffiche.horaires(lieu: paris, date: vendredi, enIsrael: false, minutes: 30)
        #expect(obtenus == attendus)
    }

    @Test func aujourdhuiEstLeJourDuFuseauDuTelephone() throws {
        // 23 h à Paris le jeudi 12 : déjà vendredi à Jérusalem, le fuseau du téléphone.
        let jour = try #require(JourCivil(iso: "2026-11-12"))
        let parisien = try #require(Fuseau("Europe/Paris"))
        let instant = parisien.millis(DateHeure(jour, heure: 23))
        let telephone = try #require(Fuseau("Asia/Jerusalem"))
        let modele = ZmanimModele(magasin: .enMemoire(), horloge: HorlogeFixe(maintenant: instant, fuseau: telephone))
        #expect(modele.jour.iso == "2026-11-13")
        // Sans réglage, Israël ou diaspora suit le fuseau du téléphone ; sans lieu, aucun horaire.
        #expect(modele.enIsrael)
        let horaires = modele.horaires
        #expect(horaires.isEmpty)
    }

    @Test func revenirAAujourdhui() throws {
        let (modele, _, _) = try fabriquer(Reglages(), "2026-11-13", heure: 12, fuseau: "Asia/Jerusalem")
        modele.jourSuivant()
        modele.jourSuivant()
        #expect(!modele.estAujourdhui)
        modele.revenirAujourdhui()
        #expect(modele.jour.iso == "2026-11-13")
        #expect(modele.estAujourdhui)
    }

    @Test func choisirLAllumageLEcritDansLeMagasin() async throws {
        let (modele, magasin, persistance) = try fabriquer(Reglages(), "2026-11-13", heure: 12, fuseau: "Asia/Jerusalem")
        #expect(modele.allumage == Zmanim.allumageDefaut)
        try await modele.choisirAllumage(40)
        #expect(modele.allumage == 40)
        #expect(magasin.reglages.allumage == 40)
        let ecrit = await persistance.enregistrement.reglages.allumage
        #expect(ecrit == 40)
    }

    @Test func choisirLeLieuRegleIsraelEtRetientLInstant() async throws {
        var reglages = Reglages()
        reglages.setLieuZmanim(paris, ville: nil, maintenant: 0)
        let (modele, magasin, persistance) = try fabriquer(reglages, "2026-11-13", heure: 12, fuseau: "Europe/Paris")
        #expect(!modele.enIsrael)
        try await modele.choisirLieu(jerusalem, ville: nil)
        let nom = modele.lieu?.nom
        #expect(nom == "Jérusalem")
        // Une position à Jérusalem, après un premier lieu : le statut suit la résidence et ne change pas ; le lieu
        // pose la question (audit du 16/11, TerritoireIsrael.decisionRegion).
        #expect(!modele.enIsrael)
        #expect(magasin.reglages.regionProposee == true)
        let fuseau = try #require(Fuseau("Europe/Paris"))
        let midi = fuseau.millis(DateHeure(modele.jour, heure: 12))
        #expect(magasin.reglages.lieuDepuis == midi)
        let ecrit = await persistance.enregistrement.reglages
        #expect(ecrit == magasin.reglages)
    }

    @Test func unLieuChoisiAilleursSeVoitIci() async throws {
        let (modele, magasin, _) = try fabriquer(Reglages(), "2026-11-13", heure: 12, fuseau: "Europe/Paris")
        #expect(modele.lieu == nil)
        try await magasin.modifierReglages { $0.setLieuZmanim(paris, ville: nil, maintenant: 0) }
        let nom = modele.lieu?.nom
        #expect(nom == "Paris")
        let horaires = modele.horaires
        #expect(!horaires.isEmpty)
    }
}
