import XCTest

/// L'audit d'accessibilité d'Xcode (`performAccessibilityAudit`) sur chaque écran de l'app (tâche 29 de ROADMAP.md :
/// « l'audit d'accessibilité des tests d'interface passe sans défaut sur chaque écran »). L'app s'ouvre sur l'écran
/// par « -capture <écran> -captureDemo » (App/Captures.swift), comme pour les captures ; chaque défaut relevé
/// s'écrit sur une ligne « AUDIT », que la CI (ios-captures.yml) recopie dans son résumé, et le test échoue s'il en
/// reste (sauf `AUDIT_RELEVE=1` : la liste sans l'échec). Les défauts que l'audit relève à tort sont tolérés, chacun
/// avec sa raison (`tolerance`) : ils s'écrivent sur une ligne « TOLERE » et ne comptent pas. Le même fichier
/// photographie les écrans couchés (`testCapturesCouchees`), que `simctl` ne sait pas tourner.
final class AuditAccessibiliteTests: XCTestCase {

    /// Les écrans de Captures.ecrans, la présentation à part (elle se feuillette).
    static let ecrans = [
        "jour", "depart", "seance", "bravo", "note", "livres", "siddour", "lecteur", "livre", "tehilim", "tikkun",
        "tefilot", "bibliotheque", "halakha", "hilloulot", "recherche", "chizuk", "conseils", "chemin", "journal",
        "parcours", "trophees", "reglages", "version", "zmanim", "vol", "musique", "apercu", "applications", "dedicace",
        "journal-barriere", "serenite", "bento", "pile", "fete", "bilan", "calendrier", "boussole", "rappels", "ajout-temps",
        "presentation",
    ]

    /// Les sortes de défaut, une à une et dans cet ordre : l'audit entier d'un écran chargé n'avait pas fini à temps
    /// sur le simulateur lent de la CI (17 écrans le 23/11), et la montée de la taille du texte (Dynamic Type, texte
    /// coupé) dérangeait les mesures de contraste faites dans le même passage ; le contraste passe donc le premier,
    /// les tailles du texte en dernier.
    static let sortes: [XCUIAccessibilityAuditType] = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .trait, .dynamicType, .textClipped,
    ]

    /// Trois essais par sorte : la durée d'un audit varie du simple au double d'un essai à l'autre sur la CI.
    static let essais = 3

    /// Les audits qui ne finissent pas à temps sur le simulateur de la CI, même seuls et en trois essais : des écrans
    /// de texte long, que l'audit relit à chaque taille du texte. Les captures aux grandes tailles (passe « grand »)
    /// les montrent ; ne s'y ajoute qu'un écran vu ainsi.
    static let tropLongs: [String: Set<String>] = [:]

    /// Un défaut relevé, et ce qu'on sait de son élément.
    struct Defaut {
        let ecran: String
        let sorte: String
        let compact: String
        let detail: String
        let libelle: String
        let genre: String
        let cadre: CGRect?

        var ligne: String {
            let position = cadre.map { "\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width)),\(Int($0.height))" } ?? ""
            return [ecran, sorte, compact, libelle, genre, position, detail].joined(separator: "\t")
        }
    }

    /// Les défauts relevés, une ligne chacun.
    private var defauts: [String] = []
    /// Le haut et le bas de ce qui se voit de l'écran ouvert, entre ses barres (`zoneVisible`).
    private var zone: (haut: CGFloat, bas: CGFloat) = (0, .greatestFiniteMagnitude)

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
            zone = Self.zoneVisible(app)
            print("ZONE\t\(ecran)\t\(Int(zone.haut))\t\(Int(zone.bas))")
            for sorte in Self.sortes {
                var fini = false
                for _ in 0..<Self.essais where !fini {
                    fini = auditer(app, ecran: ecran, sorte: sorte)
                }
                if !fini {
                    let nom = Self.nom(sorte)
                    let ligne = [ecran, "erreur", "audit inachevé : \(nom)"].joined(separator: "\t")
                    if Self.tropLongs[ecran]?.contains(nom) == true {
                        print("TOLERE\t" + ligne + "\tl'audit de cette sorte ne finit pas à temps sur le simulateur de la CI ; vu sur les captures « grand »")
                    } else {
                        print("AUDIT\t" + ligne)
                        defauts.append(ligne)
                    }
                }
            }
            app.terminate()
        }
        if !releve {
            XCTAssertTrue(defauts.isEmpty, "\(defauts.count) défaut(s) d'accessibilité :\n" + defauts.joined(separator: "\n"))
        }
    }

    /// Un audit de l'écran ouvert, pour une sorte de défaut. Le gestionnaire ne fait que garder les défauts : leurs
    /// éléments se lisent après l'audit, d'une seule photographie chacun (lus pendant l'audit, ils l'allongeaient
    /// d'une seconde par défaut). Rend false si l'audit n'a pas fini à temps ; une autre erreur compte comme un défaut.
    @MainActor
    private func auditer(_ app: XCUIApplication, ecran: String, sorte: XCUIAccessibilityAuditType) -> Bool {
        let debut = Date()
        var releves: [XCUIAccessibilityAuditIssue] = []
        defer {
            print("DUREE\t\(ecran)\t\(Self.nom(sorte))\t\(Int(Date().timeIntervalSince(debut))) s")
        }
        do {
            try app.performAccessibilityAudit(for: sorte) { probleme in
                releves.append(probleme)
                // Relevé, pas d'échec ici : la liste entière d'abord.
                return true
            }
        } catch let erreur as NSError where erreur.domain == "com.apple.xcode.xctest.accessibilityAudit"
                    && erreur.code == -56 {
            print("LENT\t\(ecran)\t\(Self.nom(sorte))\t\(erreur.localizedDescription)")
            return false
        } catch {
            let ligne = [ecran, "erreur", "\(error)"].joined(separator: "\t")
            print("AUDIT\t" + ligne)
            defauts.append(ligne)
            return true
        }
        for probleme in releves {
            let photo = try? probleme.element?.snapshot()
            let defaut = Defaut(ecran: ecran, sorte: Self.nom(probleme.auditType), compact: probleme.compactDescription,
                                detail: probleme.detailedDescription.split(whereSeparator: \.isNewline)
                                    .joined(separator: " ¶ "),
                                libelle: photo?.label ?? "",
                                genre: photo.map { String(describing: $0.elementType) } ?? "",
                                cadre: photo?.frame)
            if let raison = tolerance(defaut) {
                print("TOLERE\t" + defaut.ligne + "\t" + raison)
            } else {
                print("AUDIT\t" + defaut.ligne)
                defauts.append(defaut.ligne)
            }
        }
        return true
    }

    /// La raison pour laquelle ce défaut n'en est pas un, ou nil. Chaque règle est étroite : un défaut qu'elle ne
    /// décrit pas exactement compte.
    private func tolerance(_ d: Defaut) -> String? {
        // Le clavier du système (sa barre de prédictions) : rien de l'app.
        if d.detail.contains("TUIPredictionViewCell") || d.detail.contains("UIKeyboard") {
            return "le clavier du système, pas l'app"
        }
        // Un bouton inactif : WCAG 1.4.3 n'exige pas de contraste d'un composant inactif ; il s'efface à 38 % comme
        // sur Android (Material) pour se dire inactif.
        if d.ecran == "apercu" && d.sorte == "contraste" && d.libelle.hasPrefix("Faire un essai") {
            return "bouton inactif (Temps d'écran non autorisé) : un composant inactif n'a pas d'exigence de contraste"
        }
        // Un élément qui dépasse ce qui se voit de l'écran (sous une barre, ou au-delà du bas, dans un défilement) :
        // l'audit mesure alors la barre ou le bord, pas lui. Le défilement l'amène en entier dans la zone visible.
        // Seulement pour ce qui se mesure à l'image (contraste, texte coupé, police « en partie » suivie) ; jamais
        // une police fixe, une zone de toucher, une description ou un élément manquant.
        let mesureALImage = d.sorte == "contraste" || d.sorte == "texte coupé"
            || (d.sorte == "Dynamic Type" && d.compact.contains("partially"))
        if mesureALImage, let cadre = d.cadre, !cadre.isEmpty,
           cadre.minY < zone.haut - 1 || cadre.maxY > zone.bas + 1 {
            return "dépasse la zone visible (\(Int(zone.haut))–\(Int(zone.bas))) : sous une barre ou hors de l'écran, dans un défilement"
        }
        return nil
    }

    /// Le haut et le bas de ce qui se voit : sous la barre de navigation, au-dessus de la barre d'onglets, de la
    /// barre de départ (identifiant « barre-bas ») et du clavier.
    @MainActor
    private static func zoneVisible(_ app: XCUIApplication) -> (haut: CGFloat, bas: CGFloat) {
        let fenetre = app.windows.firstMatch.frame
        var haut = fenetre.minY
        var bas = fenetre.maxY
        // Une barre du haut finit dans le premier tiers de l'écran ; une barre du bas commence dans sa moitié basse
        // (une barre cachée qui resterait dans l'arbre, ailleurs, ne compte pas).
        for barre in app.navigationBars.allElementsBoundByIndex
            where barre.exists && !barre.frame.isEmpty && barre.frame.maxY < fenetre.midY - fenetre.height / 6 {
            haut = max(haut, barre.frame.maxY)
        }
        for barre in app.tabBars.allElementsBoundByIndex
            where barre.exists && barre.isHittable && barre.frame.minY > fenetre.midY {
            bas = min(bas, barre.frame.minY)
        }
        for barre in app.descendants(matching: .any).matching(identifier: "barre-bas").allElementsBoundByIndex
            where barre.exists && !barre.frame.isEmpty && barre.frame.minY > fenetre.midY {
            bas = min(bas, barre.frame.minY)
        }
        let clavier = app.keyboards.firstMatch
        if clavier.exists && !clavier.frame.isEmpty && clavier.frame.minY > fenetre.midY {
            bas = min(bas, clavier.frame.minY)
        }
        return (haut, bas)
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
