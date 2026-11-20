import Foundation
import Testing
@testable import Coeur

/// VersionAppTest d'Android, porté : chaque version se retrouve par sa clé, Classique par défaut, son nom et sa
/// description existent dans toutes les langues du catalogue. Restent à Android ses lectures du manifeste, de
/// MainActivity.kt, des captures et des licences de ses polices ; sur iOS, seul Classique est porté.
@Suite("Versions de l'app")
struct VersionAppTests {

    @Test func chaqueVersionSeRetrouveParSaCle() {
        for v in VersionApp.allCases {
            let relue = VersionApp.parse(v.cle)
            #expect(relue == v)
        }
        let rien = VersionApp.parse(nil)
        #expect(rien == nil)
        let inconnue = VersionApp.parse("inconnue")
        #expect(inconnue == nil)
        let cles = VersionApp.allCases.map(\.cle)
        #expect(cles == ["classique", "serenite", "bento", "pile"])
    }

    @Test func leReglageEtLaVersionCourante() throws {
        var r = Reglages()
        #expect(r.versionApp == nil)
        #expect(VersionApp.courante(r) == .classique)
        r.setVersionApp(.bento)
        #expect(r.brut["version_app"] == .chaine("bento"))
        #expect(VersionApp.courante(r) == .bento)
        // L'accueil Bento n'est pas porté : l'app montre Classique, le choix reste retenu.
        #expect(VersionApp.accueil(r) == .classique)
        let futur = try Reglages(texte: #"{"version_app":"nouvelle"}"#)
        #expect(VersionApp.courante(futur) == .classique)
    }

    @Test func chaqueNomEtChaqueDescriptionSontTraduits() throws {
        let octets = try Depot.donnees("ios/Ressources/Chaines/Localizable.xcstrings")
        let catalogue = try JSONSerialization.jsonObject(with: octets) as? [String: Any]
        let chaines = try #require(catalogue?["strings"] as? [String: Any])
        let cles = ["settings_version", "version_choix_titre", "version_choix_detail", "version_choix_pied",
                    "version_choisie"] + VersionApp.allCases.flatMap { [$0.nom.cle, $0.description.cle] }
        for cle in cles {
            let entree = chaines[cle] as? [String: Any]
            let langues = (entree?["localizations"] as? [String: Any])?.keys.sorted() ?? []
            #expect(langues == ["ar", "en", "es", "fr", "he"], "\(cle)")
        }
        let apercus = VersionApp.allCases.map { $0.apercu.count }
        #expect(apercus == [3, 3, 3, 3])
    }
}
