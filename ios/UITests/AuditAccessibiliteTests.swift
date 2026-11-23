import XCTest

/// L'audit d'accessibilité d'Xcode (`performAccessibilityAudit`) sur chaque écran de l'app (tâche 29 de ROADMAP.md :
/// « l'audit d'accessibilité des tests d'interface passe sans défaut sur chaque écran »). L'app s'ouvre sur l'écran
/// par « -capture <écran> -captureDemo » (App/Captures.swift), comme pour les captures ; chaque défaut relevé
/// s'écrit sur une ligne « AUDIT », que la CI (ios-captures.yml) recopie dans son résumé, et le test échoue s'il en
/// reste (sauf `AUDIT_RELEVE=1` : la liste sans l'échec). Les défauts que l'audit relève à tort sont dans `toleres`,
/// chacun avec sa raison : ils s'écrivent sur une ligne « TOLERE » et ne comptent pas. Le même fichier photographie
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

    /// Les sortes de défaut, une à une : sur le simulateur lent de la CI, l'audit entier d'un écran chargé n'a pas
    /// fini à temps (« Audit failed to complete in time », 17 écrans le 23/11) ; chaque sorte seule, si.
    static let sortes: [XCUIAccessibilityAuditType] = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .dynamicType, .textClipped, .trait,
    ]

    /// Un défaut relevé à tort : l'écran (nil : tous), la sorte (son nom dans le résumé), le début du libellé de
    /// l'élément (nil : tout élément), et pourquoi ce n'en est pas un.
    struct Tolere {
        let ecran: String?
        let sorte: String
        let libelle: String?
        let raison: String
    }

    /// Les faux positifs, chacun justifié ; la liste reste courte, et chaque ligne dit ce qu'elle couvre.
    static let toleres: [Tolere] = []

    /// Les défauts relevés, une ligne chacun.
    private var defauts: [String] = []

    @MainActor
    func testChaqueEcranPasseLAudit() throws {
        let environnement = ProcessInfo.processInfo.environment
        let langue = environnement["AUDIT_LANGUE"] ?? "fr"
        let releve = environnement["AUDIT_RELEVE"] == "1"
        let demandes = (environnement["AUDIT_ECRANS"] ?? "").split(separator: " ").map(String.init)
        let voulus = demandes.isEmpty ? Self.ecrans : demandes
        defauts = []
        // Un lancement à blanc : le tout premier, juste après l'installation, ne recevait pas ses arguments (l'audit
        // du « jour » voyait la présentation, en anglais).
        let premier = XCUIApplication()
        premier.launchArguments = ["-capture", "jour", "-captureDemo"]
        premier.launch()
        Thread.sleep(forTimeInterval: 3)
        premier.terminate()
        for ecran in voulus {
            let app = XCUIApplication()
            app.launchArguments = ["-capture", ecran, "-captureDemo", "-AppleLanguages", "(\(langue))"]
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 20)
            // L'écran s'ouvre par étapes (Captures.ouvrir) ; les animations d'entrée finissent.
            Thread.sleep(forTimeInterval: 4)
            if !auditer(app, ecran: ecran, sortes: .all) {
                // Trop long d'un coup : sorte par sorte, chacune deux fois au plus.
                for sorte in Self.sortes {
                    if auditer(app, ecran: ecran, sortes: sorte) { continue }
                    if auditer(app, ecran: ecran, sortes: sorte) { continue }
                    let ligne = [ecran, "erreur", "audit inachevé : \(Self.nom(sorte))"].joined(separator: "\t")
                    print("AUDIT\t" + ligne)
                    defauts.append(ligne)
                }
            }
            app.terminate()
        }
        if !releve {
            XCTAssertTrue(defauts.isEmpty, "\(defauts.count) défaut(s) d'accessibilité :\n" + defauts.joined(separator: "\n"))
        }
    }

    /// Un audit de l'écran ouvert, pour ces sortes de défaut : chaque défaut va dans `defauts` (ou, s'il est
    /// toléré, sur une ligne « TOLERE »). Rend false si l'audit n'a pas fini à temps, pour le refaire par sorte ;
    /// une autre erreur compte comme un défaut.
    @MainActor
    private func auditer(_ app: XCUIApplication, ecran: String, sortes: XCUIAccessibilityAuditType) -> Bool {
        let debut = Date()
        defer {
            print("DUREE\t\(ecran)\t\(Self.nom(sortes))\t\(Int(Date().timeIntervalSince(debut))) s")
        }
        do {
            try app.performAccessibilityAudit(for: sortes) { [unowned self] probleme in
                let element = probleme.element
                let libelle = element?.label ?? ""
                let sorte = Self.nom(probleme.auditType)
                let ligne = [ecran, sorte, probleme.compactDescription, libelle,
                             element.map { String(describing: $0.elementType) } ?? "",
                             element.map { "\(Int($0.frame.minX)),\(Int($0.frame.minY))" } ?? ""]
                    .joined(separator: "\t")
                if let tolere = Self.tolere(ecran: ecran, sorte: sorte, libelle: libelle) {
                    print("TOLERE\t" + ligne + "\t" + tolere.raison)
                } else {
                    print("AUDIT\t" + ligne)
                    defauts.append(ligne)
                }
                // Relevé, pas d'échec ici : la liste entière d'abord.
                return true
            }
            return true
        } catch let erreur as NSError where erreur.domain == "com.apple.xcode.xctest.accessibilityAudit"
                    && erreur.code == -56 {
            print("LENT\t\(ecran)\t\(Self.nom(sortes))\t\(erreur.localizedDescription)")
            return false
        } catch {
            let ligne = [ecran, "erreur", "\(error)"].joined(separator: "\t")
            print("AUDIT\t" + ligne)
            defauts.append(ligne)
            return true
        }
    }

    /// Le faux positif connu qui couvre ce défaut, s'il y en a un.
    static func tolere(ecran: String, sorte: String, libelle: String) -> Tolere? {
        toleres.first { t in
            (t.ecran == nil || t.ecran == ecran) && sorte.contains(t.sorte)
                && (t.libelle.map { libelle.hasPrefix($0) } ?? true)
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
    static func nom(_ type: XCUIAccessibilityAuditType) -> String {
        if type == .all { return "tout" }
        let noms: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contraste"), (.elementDetection, "élément"), (.hitRegion, "zone de toucher"),
            (.sufficientElementDescription, "description"), (.dynamicType, "Dynamic Type"),
            (.textClipped, "texte coupé"), (.trait, "trait"),
        ]
        return noms.filter { type.contains($0.0) }.map(\.1).joined(separator: ",")
    }
}
