import Foundation
import Testing
@testable import Coeur

/// CielDuJourTest d'Android, porté avec les mêmes cas : la phase d'après les zmanim, ou d'après l'heure sans lieu ;
/// une palette et une icône par ciel. Restent à Android les lectures de MainActivity.kt (le ciel dans la plaque,
/// les lanternes de la semaine) et l'existence de ses dessins.
@Suite("Ciel du jour")
struct CielDuJourTests {

    private static let zone = Fuseau("Asia/Jerusalem")!

    private static func a(_ h: Int, _ m: Int) -> DateHeureZonee {
        DateHeureZonee(DateHeure(JourCivil(iso: "2026-11-12")!, heure: h, minute: m), fuseau: zone)
    }

    // Un jour de novembre à Jérusalem, en chiffres ronds.
    private static let alot = a(5, 0).millis
    private static let lever = a(6, 20).millis
    private static let chkia = a(16, 40).millis
    private static let tset = a(17, 5).millis

    private func phase(_ h: Int, _ m: Int) -> CielDuJour.Phase {
        CielDuJour.phase(maintenant: Self.a(h, m), alot: Self.alot, lever: Self.lever, chkia: Self.chkia, tset: Self.tset)
    }

    @Test func lesZmanimBornentLesQuatreCiels() {
        let cas: [(Int, Int, CielDuJour.Phase)] = [
            (4, 59, .nuit), (5, 0, .aube), (7, 19, .aube), (7, 20, .jour), (15, 39, .jour), (15, 40, .coucher),
            (17, 4, .coucher), (17, 5, .nuit), (23, 59, .nuit),
        ]
        for (h, m, attendu) in cas {
            let rendu = phase(h, m)
            #expect(rendu == attendu, "\(h):\(m)")
        }
    }

    @Test func unJourTropCourtPasseDeLAubeAuCoucher() {
        let p = { (h: Int, m: Int) -> CielDuJour.Phase in
            CielDuJour.phase(maintenant: Self.a(h, m), alot: Self.a(8, 0).millis, lever: Self.a(9, 0).millis,
                             chkia: Self.a(10, 30).millis, tset: Self.a(11, 30).millis)
        }
        let aube = p(9, 59)
        #expect(aube == .aube)
        let coucher = p(10, 0)
        #expect(coucher == .coucher)
        let nuit = p(11, 30)
        #expect(nuit == .nuit)
    }

    @Test func sansZmanLHeureDecide() {
        let midi = CielDuJour.phase(maintenant: Self.a(12, 0), alot: nil, lever: Self.lever, chkia: Self.chkia,
                                    tset: Self.tset)
        #expect(midi == .jour)
        let soir = CielDuJour.phase(maintenant: Self.a(22, 0), alot: Self.alot, lever: Self.lever, chkia: Self.chkia,
                                    tset: nil)
        #expect(soir == .nuit)
        let cas: [(Int, Int, CielDuJour.Phase)] = [
            (4, 59, .nuit), (5, 0, .aube), (7, 59, .aube), (8, 0, .jour), (16, 59, .jour), (17, 0, .coucher),
            (19, 59, .coucher), (20, 0, .nuit),
        ]
        for (h, m, attendu) in cas {
            let rendu = CielDuJour.parHeure(heure: h, minute: m)
            #expect(rendu == attendu, "\(h):\(m)")
        }
    }

    @Test func chaqueCielASaPaletteEtSonIcone() {
        let icones = CielDuJour.Phase.allCases.map(CielDuJour.icone)
        #expect(icones == ["ic_ciel_aube", "ic_ciel_jour", "ic_ciel_coucher", "ic_ciel"])
        let palettes = Set(CielDuJour.Phase.allCases.map { CielDuJour.palette($0).voile })
        #expect(palettes.count == 4)
        let symboles = Set(CielDuJour.Phase.allCases.map(CielDuJour.symbole))
        #expect(symboles.count == 4)
    }

    /// Avec un lieu, les zmanim du lieu bornent les phases : à Jérusalem, midi est le plein jour, minuit la nuit.
    @Test func avecUnLieuLesZmanimDuLieu() {
        let lieu = Zmanim.Lieu(nom: "Jérusalem", latitude: 31.778, longitude: 35.2354, altitude: 754,
                               fuseau: "Asia/Jerusalem")
        let midi = CielDuJour.phase(maintenant: Self.a(12, 0), lieu: lieu)
        #expect(midi == .jour)
        let minuit = CielDuJour.phase(maintenant: Self.a(0, 30), lieu: lieu)
        #expect(minuit == .nuit)
        let sans = CielDuJour.phase(maintenant: Self.a(6, 0), lieu: nil)
        #expect(sans == .aube)
    }

    /// Le ciel continu (24/11, CielDuJour.etat) : au lieu, la hauteur du vrai soleil et le jour hébreu affiché, qui
    /// bascule à tsét ; sans lieu, le soleil moyen de l'heure et la pleine lune.
    @Test func leCielContinuSuitLeSoleilDuLieu() throws {
        let lieu = Zmanim.Lieu(nom: "Jérusalem", latitude: 31.778, longitude: 35.2354, altitude: 754,
                               fuseau: "Asia/Jerusalem")
        let zone = try #require(Fuseau("Asia/Jerusalem"))
        let jour = try #require(JourCivil(iso: "2026-11-24"))
        func a(_ h: Int, _ m: Int) -> DateHeureZonee { DateHeureZonee(DateHeure(jour, heure: h, minute: m), fuseau: zone) }
        let midi = CielDuJour.etat(maintenant: a(11, 33), lieu: lieu, enIsrael: true)
        #expect(midi.hauteur > 36 && midi.hauteur < 39 && midi.estSoleil)
        let p = Soleil.position(millis: a(11, 33).millis, latitude: lieu.latitude, longitude: lieu.longitude)
        #expect(midi == EtatCiel.de(p, jourHebreu: midi.jourHebreu))
        // Le 24/11/2026 est le 14 Kislev ; le soir, après tsét, le 15 : la pleine lune.
        #expect(midi.jourHebreu == 14)
        let soir = CielDuJour.etat(maintenant: a(21, 0), lieu: lieu, enIsrael: true)
        #expect(soir.jourHebreu == 15 && !soir.estSoleil && soir.hauteur < -30)
        // Sans lieu : le soleil moyen de l'heure du téléphone.
        let sans = CielDuJour.etat(maintenant: a(6, 30), lieu: nil, enIsrael: true)
        #expect(abs(sans.hauteur) < 1e-9 && sans.matin == 1)
        #expect(CielDuJour.etat(heure: 12.5) == EtatCiel.de(Soleil.parHeure(12.5), jourHebreu: 15))
    }
}
