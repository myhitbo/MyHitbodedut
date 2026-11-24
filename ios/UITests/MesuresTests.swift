import XCTest

/// Les mesures de la tâche 29 (ROADMAP.md : « premier écran en moins de 400 ms, défilement du plus long livre sans
/// image perdue »), lancées par la CI (ios-interface.yml) sur l'app compilée en Release pour le simulateur. Chaque
/// mesure s'écrit sur une ligne « MESURE » (nom, valeur, détail), que la CI recopie dans son résumé ; celles
/// d'XCTest (`measure`) vont dans le paquet de résultats (.xcresult), que la CI lit avec xcresulttool.
///
/// Le simulateur de la CI tourne sur un Mac Intel virtualisé, sans processeur graphique à lui : ses temps et ses
/// images perdues ne sont pas ceux d'un iPhone, et XCTest n'y rapporte du défilement que la durée (les accrocs ne
/// se mesurent que sur un appareil). Ces tests mesurent et rapportent ; ils n'échouent que si une mesure manque
/// (la chaîne de mesure cassée) : les seuils du critère se vérifient sur un iPhone (`MesuresTests` y tourne tel
/// quel, depuis Xcode).
///
/// - **premier écran** : l'app mesure elle-même (« -mesures », App/Mesures.swift) chaque étape de son lancement
///   depuis le démarrage de son processus, jusqu'à la première image de l'accueil puis à l'accueil prêt (contenus
///   lus, anneaux posés), sur le journal de démonstration ; `MESURES_LANCEMENTS` lancements, après un lancement à
///   blanc. `XCTApplicationLaunchMetric` mesure de son côté, du lancement demandé à l'app réactive.
/// - **le plus long livre** (le Kitsour Yalkout Yossef, `Captures.plusLongLivre`) : son ouverture (lecture du texte,
///   construction des lignes, première image ; `LectureModele.mesure`), puis son défilement, que l'app fait
///   elle-même et dont elle compte les images (« -mesuresDefilement », `DefilementMesure`) : le test ne fait que
///   lire le fichier des mesures. Chaque geste d'un test d'interface fait d'abord photographier tout l'arbre
///   d'accessibilité de l'app, sur son fil principal : quinze à trente secondes par geste sur ce livre, au simulateur
///   de la CI (run 45410886554), qui faussaient tout compte. Les mesures d'XCTest au doigt
///   (`XCTOSSignpostMetric.scrollingAndDecelerationMetric`, `XCTHitchMetric`) restent pour un iPhone, depuis Xcode :
///   la CI les saute (ios-interface.yml), le simulateur n'en rapportant que la durée.
///
/// Les fichiers des mesures de l'app vont dans MESURES_DOSSIER (l'app et le test tournent dans le simulateur, qui
/// écrit dans les fichiers du Mac), sinon dans le dossier temporaire du test.
final class MesuresTests: XCTestCase {

    /// Les étapes du lancement que l'app écrit (Mesures.etape), dans l'ordre.
    static let etapes = ["main", "init", "modeles", "premier-ecran", "accueil-pret"]

    private var dossier: String {
        ProcessInfo.processInfo.environment["MESURES_DOSSIER"] ?? NSTemporaryDirectory()
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(atPath: dossier, withIntermediateDirectories: true)
    }

    // MARK: Le premier écran

    @MainActor
    func testPremierEcran() throws {
        let nombre = Int(ProcessInfo.processInfo.environment["MESURES_LANCEMENTS"] ?? "") ?? 8
        aBlanc()
        // Étape → millisecondes depuis le démarrage, un lancement après l'autre ; et le temps de calcul.
        var valeurs: [String: [Int]] = [:]
        var calculs: [String: [Int]] = [:]
        for rang in 1...nombre {
            let fichier = "\(dossier)/lancement-\(rang).tsv"
            try? FileManager.default.removeItem(atPath: fichier)
            let app = XCUIApplication()
            app.launchArguments = ["-captureDemo", "-mesures", "-AppleLanguages", "(fr)"]
            app.launchEnvironment["MESURES_FICHIER"] = fichier
            app.launch()
            let lu = attendre(fichier, secondes: 60) { lignes in
                lignes.contains { $0.first == "accueil-pret" || $0.first == "erreur" }
            }
            app.terminate()
            for champs in lu where champs.first == "erreur" {
                XCTFail("lancement \(rang) : \(champs.dropFirst().joined(separator: " "))")
            }
            var detail: [String] = []
            for etape in Self.etapes {
                guard let champs = lu.first(where: { $0.first == etape }), champs.count >= 3,
                      let ms = Int(champs[1]), let cpu = Int(champs[2]) else { continue }
                valeurs[etape, default: []].append(ms)
                calculs[etape, default: []].append(cpu)
                detail.append("\(etape) \(ms) ms (calcul \(cpu) ms)")
            }
            print("MESURE\tlancement \(rang)\t" + detail.joined(separator: ", "))
            if !lu.contains(where: { $0.first == "accueil-pret" }) {
                XCTFail("lancement \(rang) : l'accueil prêt n'a pas été mesuré (\(fichier))")
            }
        }
        for etape in Self.etapes {
            guard let ms = valeurs[etape], !ms.isEmpty else { continue }
            print("MESURE\t\(etape)\t\(Self.mediane(ms)) ms\tmédiane de \(ms.count) lancements, de \(ms.min() ?? 0) à "
                  + "\(ms.max() ?? 0) ms ; le premier : \(ms[0]) ms ; temps de calcul médian : "
                  + "\(Self.mediane(calculs[etape] ?? [])) ms")
        }
    }

    /// `XCTApplicationLaunchMetric` : du lancement demandé à l'app réactive (le fil principal libre), cinq fois.
    @MainActor
    func testLancementXCTest() throws {
        aBlanc()
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-captureDemo", "-AppleLanguages", "(fr)"]
            app.launch()
        }
    }

    // MARK: Le plus long livre

    /// L'ouverture du plus long livre, puis son défilement par l'app elle-même (DefilementMesure : dix secondes vers
    /// la fin à 3 000 points par seconde, trois vers le début) et les images qu'elle y perd.
    @MainActor
    func testDefilementDuPlusLongLivre() throws {
        let fichier = "\(dossier)/defilement.tsv"
        let app = try ouvrirLePlusLongLivre(fichier: fichier, defilement: true)
        let lu = attendre(fichier, secondes: 120) { lignes in
            lignes.contains { $0.first == "defilement" || $0.first == "erreur" }
        }
        app.terminate()
        for champs in lu where champs.first == "erreur" {
            XCTFail("défilement : \(champs.dropFirst().joined(separator: " "))")
        }
        guard let d = lu.first(where: { $0.first == "defilement" && $0.count >= 8 }) else {
            XCTFail("le défilement n'a pas été mesuré (\(fichier))")
            return
        }
        let duree = Double(d[6]) ?? 0
        let tempsAccroc = Double(d[4]) ?? 0
        print("MESURE\tdefilement-plus-long-livre\t\(d[3]) images perdues\t\(d[1]) images en \(d[6]) s sur \(d[7]) points, "
              + "\(d[2]) accrocs, \(d[4]) ms d'accroc (" + String(format: "%.1f", duree > 0 ? tempsAccroc / duree : 0)
              + " ms/s), le plus long \(d[5]) ms")
    }

    /// `XCTOSSignpostMetric.scrollingAndDecelerationMetric` : un défilement rapide, cinq fois (au simulateur, la
    /// durée seule).
    @MainActor
    func testDefilementSignposts() throws {
        let app = try ouvrirLePlusLongLivre(fichier: "\(dossier)/signposts.tsv", defilement: false)
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = 5
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            glisser(app, versLeHaut: true)
            stopMeasuring()
        }
        app.terminate()
    }

    /// `XCTHitchMetric` (Xcode 26) : les accrocs du même défilement, vus du serveur de rendu.
    @MainActor
    func testDefilementAccrocs() throws {
        let app = try ouvrirLePlusLongLivre(fichier: "\(dossier)/accrocs.tsv", defilement: false)
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = 5
        measure(metrics: [XCTHitchMetric(application: app)], options: options) {
            glisser(app, versLeHaut: true)
            stopMeasuring()
        }
        app.terminate()
    }

    // MARK: Les outils

    /// Un lancement à blanc : le tout premier, juste après l'installation, ne recevait pas ses arguments
    /// (AuditAccessibiliteTests).
    @MainActor
    private func aBlanc() {
        let app = XCUIApplication()
        app.launchArguments = ["-captureDemo"]
        app.launch()
        Thread.sleep(forTimeInterval: 3)
        app.terminate()
    }

    /// Ouvre le plus long livre (« -capture plus-long-livre ») et attend que l'app dise son texte affiché
    /// (« lecteur-affiche », lu dans le fichier des mesures, sans interroger l'arbre d'accessibilité) ; écrit ce que
    /// l'ouverture a pris. Avec `defilement`, l'app fait ensuite défiler le livre et compte ses images.
    @MainActor
    private func ouvrirLePlusLongLivre(fichier: String, defilement: Bool) throws -> XCUIApplication {
        try? FileManager.default.removeItem(atPath: fichier)
        aBlanc()
        let app = XCUIApplication()
        app.launchArguments = ["-capture", "plus-long-livre", "-captureDemo", "-mesures", "-AppleLanguages", "(fr)"]
        if defilement { app.launchArguments.append("-mesuresDefilement") }
        app.launchEnvironment["MESURES_FICHIER"] = fichier
        let lance = Date()
        app.launch()
        let lu = attendre(fichier, secondes: 300) { lignes in lignes.contains { $0.first == "lecteur-affiche" } }
        guard let pret = lu.first(where: { $0.first == "lecteur-pret" && $0.count >= 5 }),
              let affiche = lu.first(where: { $0.first == "lecteur-affiche" && $0.count >= 3 }) else {
            throw Manque(description: "le plus long livre n'a pas été affiché en 300 s (\(fichier))")
        }
        print("MESURE\touverture-plus-long-livre\t\(pret[2]) lignes\tlecture du texte \(pret[3]) ms, construction "
              + "des lignes \(pret[4]) ms, première image \(affiche[2]) ms après ; "
              + String(format: "%.1f s", Date().timeIntervalSince(lance)) + " du lancement à l'affichage, vu du test")
        // Le temps que les dernières lignes se posent.
        Thread.sleep(forTimeInterval: 3)
        return app
    }

    /// Un défilement rapide du doigt, au milieu de l'écran, vers le haut (on descend dans le texte) ou vers le bas.
    @MainActor
    private func glisser(_ app: XCUIApplication, versLeHaut: Bool) {
        let bas = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let haut = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let (depart, arrivee) = versLeHaut ? (bas, haut) : (haut, bas)
        depart.press(forDuration: 0.05, thenDragTo: arrivee, withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// Les lignes du fichier, une fois que `que` les accepte (`secondes` au plus).
    private func attendre(_ fichier: String, secondes: TimeInterval, que: ([[String]]) -> Bool) -> [[String]] {
        let debut = Date()
        var lu = Self.lire(fichier)
        while !que(lu) && Date().timeIntervalSince(debut) < secondes {
            Thread.sleep(forTimeInterval: 0.2)
            lu = Self.lire(fichier)
        }
        return lu
    }

    /// Les lignes d'un fichier de mesures, en champs.
    static func lire(_ fichier: String) -> [[String]] {
        guard let texte = try? String(contentsOfFile: fichier, encoding: .utf8) else { return [] }
        return texte.split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
    }

    /// La médiane, au demi près (rien n'est arrondi).
    static func mediane(_ valeurs: [Int]) -> String {
        guard !valeurs.isEmpty else { return "?" }
        let triees = valeurs.sorted()
        let milieu = triees.count / 2
        if triees.count % 2 == 1 { return String(triees[milieu]) }
        let somme = triees[milieu - 1] + triees[milieu]
        return somme % 2 == 0 ? String(somme / 2) : String(format: "%.1f", Double(somme) / 2)
    }

    /// Une mesure qui manque : la chaîne de mesure est cassée, le test échoue.
    struct Manque: Error, CustomStringConvertible {
        let description: String
    }
}
