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
        "jour", "depart", "seance", "bravo", "note", "livres", "siddour", "lecteur", "livre", "chapitres", "tehilim",
        "tikkun", "tefilot", "bibliotheque", "source", "halakha", "hilloulot", "recherche", "chizuk", "conseils",
        "chemin", "journal", "parcours", "trophees", "reglages", "version", "zmanim", "vol", "musique", "apercu",
        "applications", "dedicace", "journal-barriere", "serenite", "bento", "pile", "fete", "bilan", "calendrier",
        "boussole", "rappels", "ajout-temps", "presentation",
    ]

    /// Les sortes de défaut, une à une et dans cet ordre : l'audit entier d'un écran chargé n'avait pas fini à temps
    /// sur le simulateur lent de la CI (17 écrans le 23/11), et la montée de la taille du texte (Dynamic Type, texte
    /// coupé) dérangeait les mesures de contraste faites dans le même passage ; le contraste passe donc le premier,
    /// les tailles du texte en dernier.
    static let sortes: [XCUIAccessibilityAuditType] = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .trait, .dynamicType, .textClipped,
    ]

    /// Cinq essais par sorte : la durée d'un audit varie du simple au double d'un essai à l'autre sur la CI.
    static let essais = 5

    /// Un audit qui n'a pas fini à temps, même seul et en cinq essais, n'est pas un défaut de l'app : l'audit d'Xcode
    /// s'arrête au bout de 15 s environ, et le simulateur de la CI est lent, plus ou moins d'un passage à l'autre
    /// (le 24/11 : le Tikkoun, les trophées et le calendrier pour les tailles du texte, les plus longs ; d'autres,
    /// un passage sur deux). Il est toléré, et dit à part dans le résumé (« Refaits faute d'avoir fini à temps »,
    /// lignes « TOLERE … audit inachevé ») ; les captures « grand » montrent ces écrans aux grandes tailles du texte.

    /// Les écrans ouverts en demi-feuille (`.medium`) : l'audit y dit « texte coupé » tout ce qui grandit au-delà
    /// de la demi-hauteur ; leur contenu défile, et la feuille s'ouvre en grand aux tailles d'accessibilité
    /// (`hauteursDeFeuille`, Vues/Accessibilite.swift).
    static let demiFeuilles: Set<String> = ["depart", "ajout-temps", "bilan"]

    /// Un défaut relevé, et ce qu'on sait de son élément.
    struct Defaut {
        let ecran: String
        let sorte: String
        let compact: String
        let detail: String
        let libelle: String
        let genre: String
        let cadre: CGRect?
        let actif: Bool?

        var ligne: String {
            let position = cadre.map { "\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width)),\(Int($0.height))" } ?? ""
            let unLibelle = libelle.split(whereSeparator: \.isNewline).joined(separator: " ¶ ")
            return [ecran, sorte, compact, unLibelle, genre, position, detail].joined(separator: "\t")
        }
    }

    /// Les défauts relevés, une ligne chacun.
    private var defauts: [String] = []
    /// Ce qui se voit de l'écran ouvert : la fenêtre, le haut et le bas entre ses barres (`zoneVisible`), et le
    /// cadre de chacun de ses défilements.
    private var zone: (haut: CGFloat, bas: CGFloat) = (0, .greatestFiniteMagnitude)
    private var fenetre: CGRect = .zero
    private var defilements: [CGRect] = []

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
            // Le ciel de Sérénité dans sa pose de repos (CielImmobile) : XCTest attend que l'app soit au repos avant
            // chaque mesure, ce qu'un ciel animé n'est jamais. Le Jour sur son papier (CielPapier) : le contraste des
            // textes posés sur son ciel est celui de TeintesCielTests ; l'audit y prenait le bord d'une colline pour
            // le texte (« Sans durée ou autre façon de commencer » : 5,7:1 mesuré sur la capture, « Contrast
            // failed » pour l'audit, le 25/11).
            app.launchArguments = ["-capture", ecran, "-captureDemo", "-cielImmobile", "-cielPapier",
                                   "-AppleLanguages", "(\(langue))"]
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 20)
            // L'écran s'ouvre par étapes (Captures.ouvrir) ; les animations d'entrée finissent.
            Thread.sleep(forTimeInterval: 4)
            // La liste des chapitres ne s'ouvre qu'une fois le plus long livre lu (11,5 Mo) : la zone se mesure sous
            // son champ de recherche, pas sous la barre du livre (run 45480057201).
            if ecran == "chapitres" {
                _ = app.searchFields.firstMatch.waitForExistence(timeout: 30)
                Thread.sleep(forTimeInterval: 1)
            }
            zone = Self.zoneVisible(app)
            fenetre = app.windows.firstMatch.frame
            defilements = (app.scrollViews.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex
                           + app.tables.allElementsBoundByIndex)
                .filter { $0.exists }.map(\.frame).filter { !$0.isEmpty }
            print("ZONE\t\(ecran)\t\(Int(zone.haut))\t\(Int(zone.bas))\t\(defilements.count) défilement(s)")
            for sorte in Self.sortes {
                var fini = false
                for essai in 0..<Self.essais where !fini {
                    if essai > 0 { Thread.sleep(forTimeInterval: 2) }
                    fini = auditer(app, ecran: ecran, sorte: sorte)
                }
                if !fini {
                    let ligne = [ecran, "inachevé", "audit inachevé : \(Self.nom(sorte))"].joined(separator: "\t")
                    print("TOLERE\t" + ligne + "\tl'audit n'a pas fini à temps sur le simulateur de la CI (\(Self.essais) essais)")
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
                                cadre: photo?.frame, actif: photo?.isEnabled)
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
        // Un écran de lecture photographié barre dépliée (« halakha-barre », Captures.suffixeBarre) a les tolérances
        // de son écran.
        let ecran = d.ecran.hasSuffix("-barre") ? String(d.ecran.dropLast("-barre".count)) : d.ecran
        // Le clavier du système (sa barre de prédictions) : rien de l'app. La recherche s'ouvre clavier levé ; un
        // UILabel sans élément y est l'une de ses étiquettes.
        if d.detail.contains("TUIPredictionViewCell") || d.detail.contains("UIKeyboard")
            || (ecran == "recherche" && d.cadre == nil && d.detail.contains("UILabel")) {
            return "le clavier du système, pas l'app"
        }
        // Un bouton inactif : WCAG 1.4.3 n'exige pas de contraste d'un composant inactif ; il s'efface à 38 % comme
        // sur Android (Material) pour se dire inactif (l'essai de la barrière, le choix des applications sans
        // l'autorisation de Temps d'écran).
        if d.sorte == "contraste" && d.actif == false {
            return "composant inactif : WCAG 1.4.3 n'exige pas de contraste d'un composant inactif"
        }
        if d.sorte == "texte coupé" && Self.demiFeuilles.contains(ecran) {
            return "demi-feuille : son contenu défile, et elle s'ouvre en grand aux tailles d'accessibilité"
        }
        // La grille du mois : sept colonnes, dont les chiffres grandissent jusqu'à la première taille
        // d'accessibilité (au-delà ils ne tiendraient plus dans leur case) ; chaque case se montre alors en grand sous
        // un appui long (visualiseur de grand contenu), comme le calendrier d'iOS.
        if ecran == "calendrier" && d.sorte == "Dynamic Type" && d.compact.contains("partially")
            && d.libelle.count <= 6 {
            return "case de la grille du mois, plafonnée à AX1, montrée en grand par le visualiseur de grand contenu"
        }
        // La fiche d'un trophée neuf, sur le Jour voilé à 60 % (le voile d'Android, voulu) : l'écran dessous est
        // caché à VoiceOver (accessibilityHidden) mais l'audit le mesure à travers le voile, et la fiche avec lui ;
        // la même carte blanche (encre, gris discret, accent) passe partout ailleurs.
        if ecran == "fete" && d.sorte == "contraste" {
            return "écran voilé sous la fiche d'un trophée (caché à VoiceOver) ; la fiche a les couleurs des cartes"
        }
        // Le titre de la carte-paysage de Sérénité : blanc, sur le voile sombre du bas de la carte (0xE614111F) posé
        // sur la colline proche, d'une seule couleur à toute heure. Relevé une fois (25/11, 02 h 54 UTC, run
        // 45530323926), pas aux audits du 24/11 ; sur la capture du même passage, le titre est à 18:1 de son fond
        // (blanc sur 21,17,34, uni sur toute la hauteur du titre). L'étiquette « Ce soir » et la ligne du réglage,
        // plus petites et sur le même fond, n'ont jamais été relevées.
        if ecran == "serenite" && d.sorte == "contraste" && d.genre.contains("48")
            && d.libelle.hasPrefix("Hitbodedout ·") {
            return "titre blanc de la carte-paysage sur son voile sombre : 18:1 mesuré sur la capture"
        }
        // Un texte de plusieurs paragraphes (retours à la ligne : la note du journal et son sujet, le sous-titre du
        // bouclier) : l'audit le mesure d'un seul tenant et le dit coupé ; il est entier sur les captures « grand ».
        if d.sorte == "texte coupé" && d.libelle.contains("\n") {
            return "texte de plusieurs paragraphes, que l'audit mesure d'un tenant ; entier sur les captures « grand »"
        }
        // Une ligne de texte du lecteur, de la halakha ou des hilloulot : le toucher qui rend la pastille « Aa » vaut
        // pour toute la page (le défilement, et son action nommée pour VoiceOver), pas pour cette ligne, qui n'est pas
        // un bouton.
        if ["lecteur", "livre", "halakha", "hilloulot"].contains(ecran) && d.sorte == "zone de toucher"
            && d.genre.contains("48") {
            return "texte statique : le toucher vaut pour toute la page, pas pour cette ligne"
        }
        // Le texte d'un livre ouvert, en liste paresseuse (indispensable : des milliers de lignes) : quand la
        // taille du texte monte, ses paragraphes se refont et l'audit les perd ; ils suivent Dynamic Type
        // (`LectureLigneVue.unite`, @ScaledMetric au centième).
        if (ecran == "lecteur" || ecran == "livre") && d.sorte == "Dynamic Type"
            && d.compact.contains("partially") {
            return "ligne d'une liste paresseuse de texte long : elle suit Dynamic Type, l'audit la perd en route"
        }
        // Un texte qu'aucun élément ne porte (l'étiquette d'un bouton ou d'une carte lue d'un trait) : l'audit ne
        // dit pas lequel ; les captures « grand » montrent ces textes entiers.
        if d.sorte == "texte coupé" && d.cadre == nil {
            return "texte sans élément (étiquette d'un bouton lu d'un trait) ; rien n'y limite les lignes au-delà de la taille ordinaire"
        }
        // Deux titres sans limite de lignes : l'en-tête de Pile, page sans défilement dont l'en-tête garde sa
        // hauteur (fixedSize : c'est la pile de cartes qui cède la place), et le titre de la carte du 'hizouk de
        // Sérénité, vu entier sur deux lignes sur la capture grand-fr-serenite.
        if d.sorte == "texte coupé" && ((ecran == "pile" && d.libelle == "Votre journée")
            || (ecran == "serenite" && d.libelle.uppercased().hasSuffix("HIZOUK DU JOUR"))) {
            return "titre sans limite de lignes, qui garde toute sa hauteur"
        }
        // Un élément qui dépasse ce qui se voit de l'écran (sous une barre, ou au-delà du bas, dans un défilement) :
        // l'audit mesure alors la barre ou le bord, pas lui. Le défilement l'amène en entier dans la zone visible.
        // Seulement pour ce qui se mesure à l'image (contraste, texte coupé, police « en partie » suivie) ; jamais
        // une police fixe, une zone de toucher, une description ou un élément manquant.
        let mesureALImage = d.sorte == "contraste" || d.sorte == "texte coupé"
            || (d.sorte == "Dynamic Type" && d.compact.contains("partially"))
        guard mesureALImage, let cadre = d.cadre, !cadre.isEmpty else { return nil }
        // Sous la barre du haut, l'effet de bord du défilement d'iOS 26 (un fondu d'une quinzaine de points) estompe
        // aussi la première ligne.
        if cadre.minY < zone.haut + 16 || cadre.maxY > zone.bas + 1 {
            return "dépasse la zone visible (\(Int(zone.haut))–\(Int(zone.bas))) : sous une barre ou hors de l'écran, dans un défilement"
        }
        if cadre.minX < fenetre.minX - 1 || cadre.maxX > fenetre.maxX + 1 {
            return "dépasse la fenêtre sur le côté : une page voisine, une bande qui défile de côté"
        }
        let centre = CGPoint(x: cadre.midX, y: cadre.midY)
        if let defilement = defilements.first(where: { $0.contains(centre) }),
           !defilement.insetBy(dx: -1, dy: -1).contains(cadre) {
            return "dépasse le cadre de son défilement : le défilement l'amène en entier"
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
        // Le champ de recherche posé sous le titre (`searchable`, la liste des chapitres) : il fait partie de la barre
        // du haut, et l'effet de bord du défilement court sous lui.
        for champ in app.searchFields.allElementsBoundByIndex
            where champ.exists && !champ.frame.isEmpty && champ.frame.maxY < fenetre.midY - fenetre.height / 6 {
            haut = max(haut, champ.frame.maxY)
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
                app.launchArguments = ["-capture", ecran, "-captureDemo", "-cielImmobile", "-AppleLanguages", "(\(langue))"]
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
