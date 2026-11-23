import XCTest

/// L'audit d'accessibilité d'Xcode (`performAccessibilityAudit`) sur chaque écran de l'app (tâche 29 de ROADMAP.md :
/// « l'audit d'accessibilité des tests d'interface passe sans défaut sur chaque écran »). L'app s'ouvre sur l'écran
/// par « -capture <écran> -captureDemo » (App/Captures.swift), comme pour les captures ; chaque défaut relevé
/// s'écrit sur une ligne « AUDIT », que la CI (ios-captures.yml) recopie dans son résumé. Le test échoue s'il en
/// reste, sauf `AUDIT_RELEVE=1` (la CI le pose pour avoir la liste entière d'un coup). Le même fichier photographie
/// les écrans couchés (`testCapturesCouchees`), que `simctl` ne sait pas tourner.
final class AuditAccessibiliteTests: XCTestCase {

    /// Les écrans de Captures.ecrans, la présentation à part (elle se feuillette).
    static let ecrans = [
        "jour", "depart", "seance", "bravo", "note", "livres", "siddour", "lecteur", "livre", "tehilim", "tikkun",
        "tefilot", "bibliotheque", "halakha", "hilloulot", "recherche", "chizuk", "conseils", "chemin", "journal",
        "parcours", "trophees", "reglages", "version", "zmanim", "vol", "musique", "apercu", "applications", "dedicace",
        "journal-barriere", "serenite", "bento", "pile", "fete", "bilan", "calendrier", "boussole", "rappels", "ajout-temps",
        "presentation",
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

    /// Les écrans couchés (tâche 29 : le Jour en deux colonnes, l'iPad en paysage) : `simctl` ne sait pas tourner le
    /// simulateur, `XCUIDevice` le peut. Chaque écran de CAPTURES_ECRANS, dans chaque langue de CAPTURES_LANGUES, est
    /// photographié couché ; l'image va dans le dossier CAPTURES_COUCHEES (le simulateur écrit dans les fichiers du
    /// Mac), nommée « <préfixe>-<langue>-<écran>.png ». Sans CAPTURES_COUCHEES, le test ne fait rien.
    @MainActor
    func testCapturesCouchees() throws {
        let environnement = ProcessInfo.processInfo.environment
        guard let dossier = environnement["CAPTURES_COUCHEES"], !dossier.isEmpty else {
            throw XCTSkip("CAPTURES_COUCHEES absent : rien à photographier")
        }
        let prefixe = environnement["CAPTURES_PREFIXE"] ?? "paysage"
        let langues = (environnement["CAPTURES_LANGUES"] ?? "fr he").split(separator: " ").map(String.init)
        let ecrans = (environnement["CAPTURES_ECRANS"] ?? "jour livres chemin zmanim lecteur reglages")
            .split(separator: " ").map(String.init)
        try FileManager.default.createDirectory(atPath: dossier, withIntermediateDirectories: true)
        for langue in langues {
            for ecran in ecrans {
                XCUIDevice.shared.orientation = .landscapeLeft
                let app = XCUIApplication()
                app.launchArguments = ["-capture", ecran, "-captureDemo", "-AppleLanguages", "(\(langue))"]
                app.launch()
                _ = app.wait(for: .runningForeground, timeout: 20)
                XCUIDevice.shared.orientation = .landscapeLeft
                Thread.sleep(forTimeInterval: 5)
                let image = XCUIScreen.main.screenshot().pngRepresentation
                let fichier = URL(fileURLWithPath: dossier).appendingPathComponent("\(prefixe)-\(langue)-\(ecran).png")
                try image.write(to: fichier)
                app.terminate()
            }
        }
        XCUIDevice.shared.orientation = .portrait
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
