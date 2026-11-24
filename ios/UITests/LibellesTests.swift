import XCTest

/// Les libellés d'accessibilité de l'accueil, de la séance et d'un texte du siddour, dans chaque langue de l'app
/// (tâche 29 de ROADMAP.md : « chaque élément de l'accueil, de la séance et d'un texte du siddour porte un libellé
/// d'accessibilité dans les trois langues (vérifié par test) ») : fr, en et he, puis es et ar-TN. L'app s'ouvre sur
/// l'écran par « -capture <écran> -captureDemo » (App/Captures.swift), comme pour les captures et l'audit ; l'arbre
/// d'accessibilité est lu d'une seule photographie (`snapshot`), en haut de l'écran puis après deux défilements
/// (une liste paresseuse ne tient que ce qui se voit).
///
/// Chaque élément qui se lit ou se touche (bouton, lien, interrupteur, curseur, onglet, cellule, champ, image,
/// texte…) doit porter :
/// - **un libellé** : non vide (une cellule le prend de ses enfants, un champ de son indication) ;
/// - **un libellé résolu** : ni une clé du catalogue (« session_screen_title »), ni un gabarit (« %1$@ », « {0} »),
///   ni le nom d'un symbole (« chevron.right ») ou d'une image (« char_standing ») ;
/// - **un libellé traduit** : en anglais et en espagnol, pas le libellé français mot pour mot (le Traducteur
///   retombe sur le français, Android aussi, ce qu'une langue ne traduit pas) ; en hébreu et en arabe, aucun mot en
///   lettres latines. Les chiffres, les signes, l'hébreu des prières sont les mêmes partout et ne comptent pas.
///
/// Chaque défaut s'écrit sur une ligne « DEFAUT », que la CI (ios-interface.yml) recopie dans son résumé, et le test
/// échoue s'il en reste (sauf `LIBELLES_RELEVE=1` : la liste sans l'échec). Un faux positif connu est toléré avec sa
/// raison (`tolerance`) : il s'écrit sur une ligne « TOLERE » et ne compte pas. Chaque élément lu s'écrit aussi sur
/// une ligne « LIBELLE » (le journal joint).
final class LibellesTests: XCTestCase {

    /// L'accueil, la séance (lancée), un texte du siddour (Cha'harit) : Captures.ouvrir.
    static let ecrans = ["jour", "seance", "lecteur"]
    /// Les trois langues du critère, puis les deux autres de l'app (Langues.toutes).
    static let langues = ["fr", "en", "he", "es", "ar-TN"]

    /// Les sortes d'élément qui se lisent ou se touchent, et doivent porter un libellé.
    static let verifies: Set<XCUIElement.ElementType> = [
        .button, .link, .`switch`, .toggle, .slider, .stepper, .tab, .cell, .textField, .secureTextField, .searchField,
        .textView, .image, .icon, .segmentedControl, .picker, .pickerWheel, .menuButton, .menuItem, .popUpButton,
        .radioButton, .checkBox, .progressIndicator, .datePicker, .staticText,
    ]

    /// Un élément lu dans l'arbre d'accessibilité.
    struct Element: Hashable {
        let genre: XCUIElement.ElementType
        let libelle: String
        let identifiant: String
        let valeur: String
        let indication: String
        /// Un descendant porte un libellé (une cellule se lit par ses enfants).
        let enfantLibelle: Bool
        let feuille: Bool

        var nomGenre: String { LibellesTests.nom(genre) }
    }

    /// Un défaut relevé.
    struct Defaut {
        let langue: String
        let ecran: String
        let sorte: String
        let element: Element
        let detail: String

        var ligne: String {
            [langue, ecran, sorte, element.nomGenre, element.libelle, element.identifiant, detail]
                .joined(separator: "\t")
        }
    }

    @MainActor
    func testLibellesDansChaqueLangue() throws {
        let environnement = ProcessInfo.processInfo.environment
        let releve = environnement["LIBELLES_RELEVE"] == "1"
        let langues = (environnement["LIBELLES_LANGUES"] ?? "").split(separator: " ").map(String.init)
        let voulues = langues.isEmpty ? Self.langues : langues
        // Un lancement à blanc : le tout premier, juste après l'installation, ne recevait pas ses arguments
        // (AuditAccessibiliteTests).
        let premier = XCUIApplication()
        premier.launchArguments = ["-capture", "jour", "-captureDemo"]
        premier.launch()
        Thread.sleep(forTimeInterval: 3)
        premier.terminate()

        // Langue → écran → éléments lus.
        var lus: [String: [String: [Element]]] = [:]
        for langue in voulues {
            for ecran in Self.ecrans {
                let elements = try lire(ecran: ecran, langue: langue)
                lus[langue, default: [:]][ecran] = elements
                let verifies = elements.filter { Self.verifies.contains($0.genre) }
                print("ELEMENTS\t\(langue)\t\(ecran)\t\(verifies.count)\t\(elements.count)")
                for e in elements {
                    print("LIBELLE\t" + [langue, ecran, e.nomGenre, Self.uneLigne(e.libelle), e.identifiant,
                                         Self.uneLigne(e.valeur)].joined(separator: "\t"))
                }
            }
        }

        var defauts: [String] = []
        for langue in voulues {
            for ecran in Self.ecrans {
                let francais = Set((lus["fr"]?[ecran] ?? []).map { Self.normal($0.libelle) })
                for element in lus[langue]?[ecran] ?? [] {
                    for defaut in examiner(element, langue: langue, ecran: ecran, francais: francais) {
                        if let raison = tolerance(defaut) {
                            print("TOLERE\t" + Self.uneLigne(defaut.ligne) + "\t" + raison)
                        } else {
                            print("DEFAUT\t" + Self.uneLigne(defaut.ligne))
                            defauts.append(defaut.ligne)
                        }
                    }
                }
            }
        }
        if !releve {
            XCTAssertTrue(defauts.isEmpty, "\(defauts.count) libellé(s) en défaut :\n" + defauts.joined(separator: "\n"))
        }
    }

    // MARK: La lecture de l'écran

    /// Ouvre l'écran dans la langue et lit son arbre : en haut, puis après deux défilements vers le bas de son plus
    /// grand défilement. Un élément vu deux fois ne compte qu'une.
    @MainActor
    private func lire(ecran: String, langue: String) throws -> [Element] {
        let app = XCUIApplication()
        app.launchArguments = ["-capture", ecran, "-captureDemo", "-AppleLanguages", "(\(langue))"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 20)
        // L'écran s'ouvre par étapes (Captures.ouvrir) ; le texte du lecteur se lit.
        Thread.sleep(forTimeInterval: 4)
        var vus: [Element] = []
        var deja = Set<Element>()
        func ajouter(_ photo: XCUIElementSnapshot) {
            for e in Self.elements(photo) where !deja.contains(e) {
                deja.insert(e)
                vus.append(e)
            }
        }
        ajouter(try app.snapshot())
        let defilements = (app.scrollViews.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex)
            .filter { $0.exists && $0.isHittable }
        if let principal = defilements.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) {
            for _ in 0..<2 {
                principal.swipeUp()
                Thread.sleep(forTimeInterval: 1)
                ajouter(try app.snapshot())
            }
        }
        app.terminate()
        return vus
    }

    /// Les éléments d'une photographie de l'arbre, dans l'ordre.
    static func elements(_ racine: XCUIElementSnapshot) -> [Element] {
        var sortie: [Element] = []
        func parcourir(_ noeud: XCUIElementSnapshot) -> Bool {
            var enfantLibelle = false
            for enfant in noeud.children where parcourir(enfant) {
                enfantLibelle = true
            }
            let libelle = noeud.label
            let element = Element(genre: noeud.elementType, libelle: libelle, identifiant: noeud.identifier,
                                  valeur: (noeud.value as? String) ?? (noeud.value.map { "\($0)" } ?? ""),
                                  indication: noeud.placeholderValue ?? "", enfantLibelle: enfantLibelle,
                                  feuille: noeud.children.isEmpty)
            // La fenêtre, l'app, les barres et les défilements contiennent ; le reste se lit.
            if noeud.elementType != .application && noeud.elementType != .window {
                sortie.append(element)
            }
            return enfantLibelle || !normal(libelle).isEmpty
        }
        _ = parcourir(racine)
        return sortie
    }

    // MARK: Les règles

    /// Les défauts d'un élément.
    private func examiner(_ e: Element, langue: String, ecran: String, francais: Set<String>) -> [Defaut] {
        var defauts: [Defaut] = []
        func defaut(_ sorte: String, _ detail: String) {
            defauts.append(Defaut(langue: langue, ecran: ecran, sorte: sorte, element: e, detail: detail))
        }
        let libelle = Self.normal(e.libelle)
        if Self.verifies.contains(e.genre) {
            let champ: Set<XCUIElement.ElementType> = [.textField, .secureTextField, .searchField, .textView]
            let porte = !libelle.isEmpty || (e.genre == .cell && e.enfantLibelle)
                || (champ.contains(e.genre) && !(Self.normal(e.indication).isEmpty && Self.normal(e.valeur).isEmpty))
            if !porte { defaut("sans libellé", "valeur « \(e.valeur) »") }
        } else if e.genre == .other && e.feuille && libelle.isEmpty && !Self.normal(e.valeur).isEmpty {
            // Un élément sans sorte qui porte une valeur (un réglable, une jauge) se lit par sa valeur seule.
            defaut("sans libellé", "valeur « \(e.valeur) » sans libellé")
        }
        guard !libelle.isEmpty else { return defauts }
        if let brut = Self.brut(libelle) {
            defaut("non résolu", brut)
        }
        switch langue {
        case "en", "es":
            if francais.contains(libelle) && Self.motLatin(libelle) != nil {
                defaut("non traduit", "le même qu'en français")
            }
        case "he", "ar-TN":
            if let mot = Self.motLatin(libelle) {
                defaut("non traduit", "mot en lettres latines : « \(mot) »")
            }
        default:
            break
        }
        return defauts
    }

    /// Ce qui trahit un libellé non résolu : une clé du catalogue (ou le nom d'une image), un gabarit, le nom d'un
    /// symbole ; nil sinon.
    static func brut(_ libelle: String) -> String? {
        let regles: [(String, String)] = [
            // Une clé d'Android (« session_screen_title ») ou un nom de fichier d'image (« char_standing »).
            (#"(?<![\p{L}\p{N}@./-])[a-z][a-z0-9]*(?:_[a-z0-9]+)+(?![\p{L}\p{N}@])"#, "clé"),
            // Un gabarit de String.format (« %1$s », « %@ », « %lld »), un « %% » resté tel quel.
            (#"%(?:\d+\$)?(?:ll|l|h)?[@dfsuxX]|%%"#, "gabarit"),
            // Un gabarit de MessageFormat ou nommé (« {0} », « {nom} »).
            (#"\{[0-9a-z_]+\}"#, "gabarit"),
            // Le nom d'un symbole SF (« chevron.right », « play.fill »), seul.
            (#"^[a-z]+(?:\.[a-z0-9]+)+$"#, "symbole"),
        ]
        for (motif, nom) in regles {
            if let trouve = libelle.range(of: motif, options: .regularExpression) {
                return "\(nom) : « \(libelle[trouve]) »"
            }
        }
        return nil
    }

    /// Le premier mot de trois lettres latines au moins (les lettres accentuées du français comprises), ou nil.
    static func motLatin(_ libelle: String) -> String? {
        guard let trouve = libelle.range(of: #"[A-Za-zÀ-ÖØ-öø-ÿŒœ]{3,}"#, options: .regularExpression) else {
            return nil
        }
        return String(libelle[trouve])
    }

    /// Le libellé sans les marques de direction (U+200E, U+200F, U+2066…U+2069, U+202A…U+202E, U+061C) ni les
    /// blancs de bord.
    static func normal(_ libelle: String) -> String {
        let marques: Set<Unicode.Scalar> = ["\u{200E}", "\u{200F}", "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}",
                                            "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}", "\u{061C}"]
        var scalaires = String.UnicodeScalarView()
        scalaires.append(contentsOf: libelle.unicodeScalars.filter { !marques.contains($0) })
        return String(scalaires).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func uneLigne(_ texte: String) -> String {
        texte.split(whereSeparator: \.isNewline).joined(separator: " ¶ ")
    }

    // MARK: Les faux positifs

    /// La raison pour laquelle ce défaut n'en est pas un, ou nil. Chaque règle est étroite : un défaut qu'elle ne
    /// décrit pas exactement compte.
    private func tolerance(_ d: Defaut) -> String? {
        let libelle = Self.normal(d.element.libelle)
        // Le nom de l'app, le même dans toutes les langues (app_name d'Android, CFBundleDisplayName).
        if d.sorte == "non traduit" && libelle == "MyHitbodedut" {
            return "le nom de l'app, le même dans toutes les langues"
        }
        return nil
    }

    /// Le nom d'une sorte d'élément, pour le journal.
    static func nom(_ genre: XCUIElement.ElementType) -> String {
        let noms: [XCUIElement.ElementType: String] = [
            .other: "autre", .button: "bouton", .link: "lien", .`switch`: "interrupteur", .toggle: "bascule",
            .slider: "curseur", .stepper: "pas à pas", .tab: "onglet", .tabBar: "barre d'onglets", .cell: "cellule",
            .textField: "champ", .secureTextField: "champ secret", .searchField: "recherche", .textView: "zone de texte",
            .image: "image", .icon: "icône", .segmentedControl: "segments", .picker: "sélecteur",
            .pickerWheel: "roue", .menuButton: "bouton de menu", .menuItem: "article de menu",
            .popUpButton: "bouton déroulant", .radioButton: "bouton radio", .checkBox: "case",
            .progressIndicator: "jauge", .activityIndicator: "attente", .datePicker: "date",
            .staticText: "texte", .scrollView: "défilement", .collectionView: "collection", .table: "table",
            .navigationBar: "barre de navigation", .toolbar: "barre d'outils", .group: "groupe", .key: "touche",
            .keyboard: "clavier", .sheet: "feuille", .alert: "alerte", .webView: "page web", .map: "carte",
            .statusBar: "barre d'état", .scrollBar: "barre de défilement",
        ]
        return noms[genre] ?? "sorte \(genre.rawValue)"
    }
}
