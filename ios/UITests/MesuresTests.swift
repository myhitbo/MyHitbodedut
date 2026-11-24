import XCTest

/// Les mesures de la tâche 29 (ROADMAP.md : « premier écran en moins de 400 ms, défilement du plus long livre sans
/// image perdue »), lancées par la CI (ios-interface.yml) sur l'app compilée en Release pour le simulateur. Chaque
/// mesure s'écrit sur une ligne « MESURE » (nom, valeur, détail), que la CI recopie dans son résumé ; celles
/// d'XCTest (`measure`) sur les lignes « measured [ … ] » d'xcodebuild.
///
/// Le simulateur de la CI tourne sur un Mac Intel virtualisé, sans processeur graphique à lui : ses temps et ses
/// images perdues ne sont pas ceux d'un iPhone, et XCTest n'y rapporte du défilement que la durée (les accrocs ne
/// se mesurent que sur un appareil). Ces tests mesurent et rapportent ; ils n'échouent que si une mesure manque
/// (la chaîne de mesure cassée) : les seuils du critère se vérifient sur un iPhone (`MesuresTests` y tourne tel
/// quel, depuis Xcode).
///
/// - **premier écran** : l'app mesure elle-même (« -mesures », App/Mesures.swift) du démarrage de son processus à
///   la première image de l'accueil, puis à l'accueil prêt (contenus lus, anneaux posés), sur le journal de
///   démonstration ; `MESURES_LANCEMENTS` lancements, après un lancement à blanc. `XCTApplicationLaunchMetric`
///   mesure de son côté, du lancement demandé à l'app réactive.
/// - **défilement du plus long livre** (le Kitsour Yalkout Yossef, `Captures.plusLongLivre`) : l'app compte ses
///   images (« -mesuresImages », `CompteurImages`) pendant des défilements rapides ; XCTest mesure le même
///   défilement (`XCTOSSignpostMetric.scrollingAndDecelerationMetric`, `XCTHitchMetric`).
///
/// Les fichiers des mesures de l'app vont dans MESURES_DOSSIER (l'app et le test tournent dans le simulateur, qui
/// écrit dans les fichiers du Mac), sinon dans le dossier temporaire du test.
final class MesuresTests: XCTestCase {

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
        var premiers: [Int] = []
        var prets: [Int] = []
        for rang in 1...nombre {
            let fichier = "\(dossier)/lancement-\(rang).tsv"
            try? FileManager.default.removeItem(atPath: fichier)
            let app = XCUIApplication()
            app.launchArguments = ["-captureDemo", "-mesures", "-AppleLanguages", "(fr)"]
            app.launchEnvironment["MESURES_FICHIER"] = fichier
            app.launch()
            let lu = attendre(fichier, que: { $0.contains { $0.first == "accueil-pret" || $0.first == "erreur" } })
            app.terminate()
            for champs in lu where champs.first == "erreur" {
                XCTFail("lancement \(rang) : \(champs.dropFirst().joined(separator: " "))")
            }
            guard let premier = valeur(lu, "premier-ecran"), let pret = valeur(lu, "accueil-pret") else {
                XCTFail("lancement \(rang) : aucune mesure (\(fichier))")
                continue
            }
            print("MESURE\tlancement \(rang)\t\(premier) ms\taccueil prêt à \(pret) ms")
            premiers.append(premier)
            prets.append(pret)
        }
        guard !premiers.isEmpty else { return }
        print("MESURE\tpremier-ecran\t\(Self.mediane(premiers)) ms\t" + Self.etendue(premiers))
        print("MESURE\taccueil-pret\t\(Self.mediane(prets)) ms\t" + Self.etendue(prets))
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

    // MARK: Le défilement du plus long livre

    /// Le compte des images de l'app pendant douze défilements rapides vers la fin du livre, puis deux vers son début.
    @MainActor
    func testDefilementImagesPerdues() throws {
        let fichier = "\(dossier)/images.tsv"
        try? FileManager.default.removeItem(atPath: fichier)
        let (app, texte) = try ouvrirLePlusLongLivre(fichier: fichier)
        Thread.sleep(forTimeInterval: 1)
        let debut = Date().timeIntervalSince1970
        for _ in 0..<12 { texte.swipeUp(velocity: .fast) }
        for _ in 0..<2 { texte.swipeDown(velocity: .fast) }
        let fin = Date().timeIntervalSince1970
        Thread.sleep(forTimeInterval: 1)
        let comptes = Self.lire(fichier).filter { $0.first == "images" }.compactMap { champs -> [Double]? in
            let nombres = champs.dropFirst().compactMap(Double.init)
            return nombres.count == 5 ? nombres : nil
        }
        app.terminate()
        guard let avant = comptes.last(where: { $0[0] <= debut }) ?? comptes.first,
              let apres = comptes.first(where: { $0[0] >= fin }) ?? comptes.last, apres[0] > avant[0] else {
            XCTFail("aucun compte d'images (\(fichier))")
            return
        }
        let duree = apres[0] - avant[0]
        let images = Int(apres[1] - avant[1])
        let accrocs = Int(apres[2] - avant[2])
        let perdues = Int(apres[3] - avant[3])
        let tempsAccroc = apres[4] - avant[4]
        print("MESURE\tdefilement-images-perdues\t\(perdues)\t\(images) images en "
              + String(format: "%.1f s", duree) + ", \(accrocs) accrocs, "
              + String(format: "%.0f ms d'accroc, %.1f ms/s", tempsAccroc, tempsAccroc / duree))
    }

    /// `XCTOSSignpostMetric.scrollingAndDecelerationMetric` : un défilement rapide, cinq fois (au simulateur, la
    /// durée seule).
    @MainActor
    func testDefilementSignposts() throws {
        let (app, texte) = try ouvrirLePlusLongLivre(fichier: nil)
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = 5
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            texte.swipeUp(velocity: .fast)
            stopMeasuring()
        }
        app.terminate()
    }

    /// `XCTHitchMetric` (Xcode 26) : les accrocs du même défilement, vus du serveur de rendu.
    @MainActor
    func testDefilementAccrocs() throws {
        let (app, texte) = try ouvrirLePlusLongLivre(fichier: nil)
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        options.iterationCount = 5
        measure(metrics: [XCTHitchMetric(application: app)], options: options) {
            texte.swipeUp(velocity: .fast)
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

    /// Ouvre le plus long livre (« -capture plus-long-livre ») et attend que son texte paraisse ; rend l'app et le
    /// défilement du texte, le plus grand de l'écran. Avec `fichier`, l'app compte ses images.
    @MainActor
    private func ouvrirLePlusLongLivre(fichier: String?) throws -> (XCUIApplication, XCUIElement) {
        aBlanc()
        let app = XCUIApplication()
        app.launchArguments = ["-capture", "plus-long-livre", "-captureDemo", "-AppleLanguages", "(fr)"]
        if let fichier {
            app.launchArguments += ["-mesures", "-mesuresImages"]
            app.launchEnvironment["MESURES_FICHIER"] = fichier
        }
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 20)
        let debut = Date()
        var texte: XCUIElement?
        while texte == nil && Date().timeIntervalSince(debut) < 120 {
            let defilements = app.scrollViews.allElementsBoundByIndex.filter { $0.exists && !$0.frame.isEmpty }
            if let grand = defilements.max(by: { $0.frame.height < $1.frame.height }),
               grand.staticTexts.firstMatch.exists {
                texte = grand
            } else {
                Thread.sleep(forTimeInterval: 1)
            }
        }
        let ouvert = Date().timeIntervalSince(debut)
        guard let texte else {
            throw Manque(description: "le texte du plus long livre n'a pas paru en 120 s")
        }
        print("MESURE\touverture-plus-long-livre\t" + String(format: "%.1f s", ouvert)
              + "\tdu lancement au texte affiché, vu du test")
        // Le temps que les dernières lignes se posent.
        Thread.sleep(forTimeInterval: 2)
        return (app, texte)
    }

    /// Les lignes du fichier, une fois que `que` les accepte (30 s au plus).
    private func attendre(_ fichier: String, que: ([[String]]) -> Bool) -> [[String]] {
        let debut = Date()
        var lu = Self.lire(fichier)
        while !que(lu) && Date().timeIntervalSince(debut) < 30 {
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

    private func valeur(_ lignes: [[String]], _ nom: String) -> Int? {
        lignes.first { $0.first == nom }.flatMap { $0.count > 1 ? Int($0[1]) : nil }
    }

    /// La médiane, au demi près (rien n'est arrondi).
    static func mediane(_ valeurs: [Int]) -> String {
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

    /// « min … max, n lancements ; le premier : … ».
    static func etendue(_ valeurs: [Int]) -> String {
        "de \(valeurs.min() ?? 0) à \(valeurs.max() ?? 0) ms sur \(valeurs.count) lancements ; le premier : \(valeurs.first ?? 0) ms"
    }
}
