import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le texte de 'hizouk du grand widget de la série (StreakWidget.texteDuJour) : un par jour parmi ceux de l'ouverture,
/// le même toute la journée, le suivant le lendemain ; l'hébreu et sa référence dans la langue de l'app. Le dessin du
/// widget reste à l'appareil.
@Suite("Le texte du jour du grand widget")
struct WidgetTexteDuJourTests {

    static func chizuk() throws -> Chizuk {
        try JSONDecoder().decode(Chizuk.self, from: Data(contentsOf: Fichiers.contenu.appendingPathComponent("chizuk.json")))
    }

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    @Test func unTexteDeLOuvertureChoisiParLeNumeroDuJour() throws {
        let chizuk = try Self.chizuk()
        let textes = ChizukRules.forMoment(chizuk, .ouverture, debug: false)
        try #require(!textes.isEmpty)
        let jour = try Self.jour("2026-11-23")
        // 23 novembre 2026 : le jour 20 780 depuis le 1er janvier 1970 (LocalDate.toEpochDay).
        let attendu = textes[20_780 % textes.count]
        let texte = try #require(WidgetTexteDuJour.choisir(chizuk, jour: jour, langue: "fr", debug: false))
        #expect(texte.hebreu == ChizukRules.hebrew(chizuk, attendu))
        #expect(texte.reference == Reference.localise(attendu.ref, "fr"))
        #expect(!texte.hebreu.isEmpty)
        // Le même toute la journée, le suivant le lendemain (s'il y en a plus d'un).
        #expect(WidgetTexteDuJour.choisir(chizuk, jour: jour, langue: "fr", debug: false) == texte)
        if textes.count > 1 {
            let demain = try #require(WidgetTexteDuJour.choisir(chizuk, jour: jour.plus(jours: 1), langue: "fr",
                                                                debug: false))
            #expect(demain.hebreu == ChizukRules.hebrew(chizuk, textes[20_781 % textes.count]))
        }
    }

    @Test func laReferenceSuitLaLangueDeLApp() throws {
        let chizuk = try Self.chizuk()
        let jour = try Self.jour("2026-11-23")
        for langue in ["fr", "en", "he"] {
            let texte = try #require(WidgetTexteDuJour.choisir(chizuk, jour: jour, langue: langue, debug: false))
            let item = ChizukRules.forMoment(chizuk, .ouverture, debug: false)
            #expect(texte.reference == Reference.localise(item[20_780 % item.count].ref, langue))
        }
    }

    @Test func avant1970LeRangResteDansLaListe() throws {
        let chizuk = try Self.chizuk()
        #expect(WidgetTexteDuJour.choisir(chizuk, jour: try Self.jour("1969-12-31"), langue: "fr", debug: true) != nil)
    }
}
