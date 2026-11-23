import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les aéroports et le catalogue du dépôt, lus une fois.
private enum BilletDepot {
    static let aeroports: [Vol.Aeroport] = {
        guard let lignes = try? Fichiers.donnees("ios/Ressources/Contenu/aeroports.json"),
              let noms = try? Fichiers.donnees("ios/Ressources/Contenu/aeroports_noms.json") else { return [] }
        // Sans `Aeroports.preparer` : le billet ne cherche que par le code IATA (parIata), et l'index plié reste à la
        // liste de VolModeleTests.
        return (try? Aeroports.parse(String(decoding: lignes, as: UTF8.self),
                                     noms: String(decoding: noms, as: UTF8.self))) ?? []
    }()

    static let traducteur: Traducteur? = {
        guard let catalogue = try? Fichiers.catalogue() else { return nil }
        return try? Traducteur(catalogue: catalogue, langue: "fr")
    }()
}

/// Le billet du vol lu par l'appareil photo (VisionKit, propre à iOS) : le code-barres scanné suit le même chemin que
/// celui d'un billet importé (LecteurBillet.kt puis CarteEmbarquement.kt, VolActivity.lireBillet) — la route, le
/// numéro et la date remplis, l'heure demandée ; un code qui n'est pas une carte d'embarquement le dit. La caméra
/// elle-même ne se teste que sur un téléphone.
@Suite("Le billet scanné")
@MainActor
struct VolBilletTests {

    private func modele(_ iso: String, heure: Int) throws -> VolModele {
        let jour = try #require(JourCivil(iso: iso))
        let paris = try #require(Fuseau("Europe/Paris"))
        let notifications = FauxVolNotifications()
        let traducteur = try #require(BilletDepot.traducteur)
        return VolModele(magasin: Magasin.enMemoire(), horloge: HorlogeFixe(DateHeure(jour, heure: heure), fuseau: paris),
                         aeroports: { BilletDepot.aeroports }, notificateur: notifications, retrait: notifications,
                         lecteurBillet: FauxVolLecteurBillet(nil), traducteur: traducteur)
    }

    @Test func leCodeScanneRemplitLeVol() async throws {
        let m = try modele("2026-11-04", heure: 9)
        await m.apparaitre()
        await m.lireCodeBillet("M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100")
        let jeudi = try #require(JourCivil(iso: "2026-11-12"))
        #expect(m.numeroSaisi == "LY382")
        #expect(m.depart?.iata == "LYS")
        #expect(m.arrivee?.iata == "TLV")
        #expect(m.dateSeule == jeudi)
        #expect(m.rapide?.first == Libelle("vol_rapide_billet_lu"))
        // Le code ne porte pas l'heure : elle se choisit, sur le jour du billet.
        #expect(m.dialogue == .heure(.saisieRapide, initiale: DateHeure(jeudi, heure: 12)))
    }

    @Test func unAutreCodeNEstPasUneCarte() async throws {
        let m = try modele("2026-11-04", heure: 9)
        await m.apparaitre()
        await m.lireCodeBillet("https://exemple.org/billet")
        #expect(m.rapide == [Libelle("vol_rapide_billet_illisible")])
        #expect(m.depart == nil)
    }

    /// Une carte d'embarquement en Aztec ou en QR porte le même texte BCBP : le jour de l'année le plus proche
    /// d'aujourd'hui, même d'une année à l'autre.
    @Test func leJourDeLAnneeLePlusProche() throws {
        let fin = try #require(JourCivil(iso: "2026-12-30"))
        let troncon = try #require(CarteEmbarquement.lire("M1COHEN/SARAH         EXYZ987 CDGTLVAF 1620 003Y021C0042 100",
                                                          fin))
        #expect(troncon.depart == "CDG")
        #expect(troncon.arrivee == "TLV")
        #expect(troncon.numero == "AF1620")
        #expect(troncon.date == JourCivil(iso: "2027-01-03"))
    }
}
