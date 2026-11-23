import XCTest

/// L'audit d'accessibilité d'Xcode (`performAccessibilityAudit`) sur chaque écran de l'app (tâche 29 de ROADMAP.md :
/// « l'audit d'accessibilité des tests d'interface passe sans défaut sur chaque écran »). L'app s'ouvre sur l'écran
/// par « -capture <écran> -captureDemo » (App/Captures.swift), comme pour les captures ; chaque défaut relevé
/// s'écrit sur une ligne « AUDIT », que la CI (ios-captures.yml) recopie dans son résumé. Le test échoue s'il en
/// reste, sauf `AUDIT_RELEVE=1` (la CI le pose pour avoir la liste entière d'un coup).
final class AuditAccessibiliteTests: XCTestCase {

    /// Les écrans de Captures.ecrans, la présentation à part (elle se feuillette).
    static let ecrans = [
        "jour", "depart", "seance", "bravo", "note", "livres", "siddour", "lecteur", "livre", "tehilim", "tikkun",
        "tefilot", "bibliotheque", "halakha", "hilloulot", "recherche", "chizuk", "conseils", "chemin", "journal",
        "parcours", "trophees", "reglages", "version", "zmanim", "vol", "musique", "presentation",
    ]

    @MainActor
    func testChaqueEcranPasseLAudit() throws {
        let environnement = ProcessInfo.processInfo.environment
        let langue = environnement["AUDIT_LANGUE"] ?? "fr"
        let releve = environnement["AUDIT_RELEVE"] == "1"
        let demandes = (environnement["AUDIT_ECRANS"] ?? "").split(separator: " ").map(String.init)
        let voulus = demandes.isEmpty ? Self.ecrans : demandes
        var defauts: [String] = []
        for ecran in voulus {
            let app = XCUIApplication()
            app.launchArguments = ["-capture", ecran, "-captureDemo", "-AppleLanguages", "(\(langue))"]
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 20)
            // L'écran s'ouvre par étapes (Captures.ouvrir) ; les animations d'entrée finissent.
            Thread.sleep(forTimeInterval: 4)
            do {
                try app.performAccessibilityAudit { probleme in
                    let element = probleme.element
                    let ligne = [ecran, Self.nom(probleme.auditType), probleme.compactDescription,
                                 element?.label ?? "", element.map { String(describing: $0.elementType) } ?? "",
                                 element.map { "\(Int($0.frame.minX)),\(Int($0.frame.minY))" } ?? ""]
                        .joined(separator: "\t")
                    print("AUDIT\t" + ligne)
                    defauts.append(ligne)
                    // Relevé, pas d'échec ici : la liste entière d'abord.
                    return true
                }
            } catch {
                print("AUDIT\t\(ecran)\terreur\t\(error)")
            }
            app.terminate()
        }
        if !releve {
            XCTAssertTrue(defauts.isEmpty, defauts.joined(separator: "\n"))
        }
    }

    /// Le nom d'une sorte de défaut, pour le résumé.
    private static func nom(_ type: XCUIAccessibilityAuditType) -> String {
        let noms: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contraste"), (.elementDetection, "élément"), (.hitRegion, "zone de toucher"),
            (.sufficientElementDescription, "description"), (.dynamicType, "Dynamic Type"),
            (.textClipped, "texte coupé"), (.trait, "trait"),
        ]
        return noms.filter { type.contains($0.0) }.map(\.1).joined(separator: ",")
    }
}
