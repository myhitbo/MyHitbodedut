import XCTest

/// Les libellés d'accessibilité de l'accueil, de la séance et d'un texte du siddour, dans chaque langue de l'app
/// (tâche 29 de ROADMAP.md : « chaque élément de l'accueil, de la séance et d'un texte du siddour porte un libellé
/// d'accessibilité dans les trois langues (vérifié par test) ») : fr, en et he, puis es et ar-TN. L'app s'ouvre sur
/// l'écran par « -capture <écran> -captureDemo » (App/Captures.swift), comme pour les captures et l'audit.
///
/// Chaque élément que VoiceOver lit doit porter :
/// - **un libellé** : l'audit d'Xcode (`sufficientElementDescription`), dans la langue, relève chaque élément que
///   VoiceOver atteint sans rien à en dire ; l'arbre relève en plus chaque bouton, lien, interrupteur, curseur,
///   onglet ou champ sans libellé (une cellule le prend de ses enfants, un champ de son indication) ;
/// - **un libellé résolu** : ni une clé du catalogue (« session_screen_title »), ni un gabarit (« %1$@ », « {0} »),
///   ni le nom d'un symbole (« chevron.right ») ou d'une image (« char_standing ») ;
/// - **un libellé traduit** : en anglais et en espagnol, pas le libellé français mot pour mot (le Traducteur
///   retombe sur le français, Android aussi, ce qu'une langue ne traduit pas) ; en hébreu et en arabe, aucun mot en
///   lettres latines. Les chiffres, les signes, l'hébreu des prières sont les mêmes partout et ne comptent pas.
///
/// L'arbre est lu d'une seule photographie (`snapshot`), en haut de l'écran puis après deux défilements (une liste
/// paresseuse ne tient que ce qui se voit). Il montre aussi ce que VoiceOver ne lit pas : ce qu'un élément porteur
/// d'un libellé (un bouton, un texte regroupé, une image dite) contient est lu par lui, pas à part (les images d'un
/// onglet, l'icône d'un bouton) ; ces éléments intérieurs ne sont pas jugés.
///
/// Chaque défaut s'écrit sur une ligne « DEFAUT », que la CI (ios-interface.yml) recopie dans son résumé, et le test
/// échoue s'il en reste (sauf `LIBELLES_RELEVE=1` : la liste sans l'échec). Un faux positif connu est toléré avec sa
/// raison (`tolerance`) : il s'écrit sur une ligne « TOLERE » et ne compte pas. Chaque élément lu s'écrit aussi sur
/// une ligne « LIBELLE » (le journal joint), avec sa profondeur et « intérieur » s'il est dans un porteur.
final class LibellesTests: XCTestCase {

    /// L'accueil, la séance (lancée), un texte du siddour (Cha'harit) : Captures.ouvrir.
    static let ecrans = ["jour", "seance", "lecteur"]
    /// Les trois langues du critère, puis les deux autres de l'app (Langues.toutes).
    static let langues = ["fr", "en", "he", "es", "ar-TN"]

    /// Les sortes d'élément qui se touchent ou se règlent : sans libellé, VoiceOver n'en dit que la sorte.
    static let interactifs: Set<XCUIElement.ElementType> = [
        .button, .link, .`switch`, .toggle, .slider, .stepper, .tab, .textField, .secureTextField, .searchField,
        .textView, .segmentedControl, .picker, .pickerWheel, .menuButton, .menuItem, .popUpButton, .radioButton,
        .checkBox, .datePicker,
    ]
    /// Les champs, qui se lisent aussi par leur indication ou leur valeur.
    static let champs: Set<XCUIElement.ElementType> = [.textField, .secureTextField, .searchField, .textView]
    /// Les sortes qui contiennent sans se lire d'un tenant : VoiceOver entre dedans, même quand elles ont un nom.
    static let contenants: Set<XCUIElement.ElementType> = [
        .application, .window, .scrollView, .collectionView, .table, .cell, .navigationBar, .tabBar, .toolbar,
        .group, .keyboard, .sheet, .alert, .webView,
    ]

    /// Un élément lu dans l'arbre d'accessibilité.
    struct Element: Hashable {
        let genre: XCUIElement.ElementType
        let libelle: String
        let identifiant: String
        let valeur: String
        let indication: String
        let profondeur: Int
        /// Dans un porteur : lu par lui, pas à part.
        let interieur: Bool
        /// Un descendant porte un libellé (une cellule se lit par ses enfants).
        let enfantLibelle: Bool

        var nomGenre: String { LibellesTests.nom(genre) }
    }

    /// Un défaut relevé.
    struct Defaut {
        let langue: String
        let ecran: String
        let sorte: String
        let genre: String
        let libelle: String
        let identifiant: String
        let detail: String

        var ligne: String {
            [langue, ecran, sorte, genre, LibellesTests.uneLigne(libelle), identifiant, detail].joined(separator: "\t")
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

        // Langue → écran → éléments lus ; et les défauts de l'audit.
        var lus: [String: [String: [Element]]] = [:]
        var trouves: [Defaut] = []
        for langue in voulues {
            for ecran in Self.ecrans {
                let (elements, audit) = try lire(ecran: ecran, langue: langue)
                lus[langue, default: [:]][ecran] = elements
                trouves += audit
                let juges = elements.filter { !$0.interieur && !Self.contenants.contains($0.genre) }
                print("ELEMENTS\t\(langue)\t\(ecran)\t\(juges.count)\t\(elements.count)")
                for e in elements {
                    print("LIBELLE\t" + [langue, ecran, String(e.profondeur), e.nomGenre, Self.uneLigne(e.libelle),
                                         e.identifiant, Self.uneLigne(e.valeur), e.interieur ? "intérieur" : ""]
                        .joined(separator: "\t"))
                }
            }
        }

        for langue in voulues {
            for ecran in Self.ecrans {
                let francais = Set((lus["fr"]?[ecran] ?? []).map { Self.normal($0.libelle) })
                for element in lus[langue]?[ecran] ?? [] where !element.interieur {
                    trouves += examiner(element, langue: langue, ecran: ecran, francais: francais)
                }
            }
        }
        var defauts: [String] = []
        for defaut in trouves {
            if let raison = tolerance(defaut) {
                print("TOLERE\t" + defaut.ligne + "\t" + raison)
            } else {
                print("DEFAUT\t" + defaut.ligne)
                defauts.append(defaut.ligne)
            }
        }
        if !releve {
            XCTAssertTrue(defauts.isEmpty, "\(defauts.count) libellé(s) en défaut :\n" + defauts.joined(separator: "\n"))
        }
    }

    // MARK: La lecture de l'écran

    /// Ouvre l'écran dans la langue, passe l'audit des descriptions, puis lit son arbre : en haut, puis après deux
    /// défilements vers le bas de son plus grand défilement. Un élément vu deux fois ne compte qu'une.
    @MainActor
    private func lire(ecran: String, langue: String) throws -> ([Element], [Defaut]) {
        let app = XCUIApplication()
        app.launchArguments = ["-capture", ecran, "-captureDemo", "-AppleLanguages", "(\(langue))"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 20)
        // L'écran s'ouvre par étapes (Captures.ouvrir) ; le texte du lecteur se lit.
        Thread.sleep(forTimeInterval: 4)
        let audit = auditer(app, ecran: ecran, langue: langue)
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
        return (vus, audit)
    }

    /// L'audit des descriptions d'Xcode (`sufficientElementDescription`) sur l'écran ouvert : chaque élément que
    /// VoiceOver atteint sans description. Trois essais si l'audit ne finit pas à temps (le simulateur de la CI est
    /// lent : AuditAccessibiliteTests) ; un audit inachevé se dit à part.
    @MainActor
    private func auditer(_ app: XCUIApplication, ecran: String, langue: String) -> [Defaut] {
        for essai in 0..<3 {
            if essai > 0 { Thread.sleep(forTimeInterval: 2) }
            var releves: [XCUIAccessibilityAuditIssue] = []
            do {
                try app.performAccessibilityAudit(for: .sufficientElementDescription) { probleme in
                    releves.append(probleme)
                    return true
                }
            } catch let erreur as NSError where erreur.domain == "com.apple.xcode.xctest.accessibilityAudit"
                        && erreur.code == -56 {
                print("LENT\t\(langue)\t\(ecran)\taudit des descriptions\t\(erreur.localizedDescription)")
                continue
            } catch {
                return [Defaut(langue: langue, ecran: ecran, sorte: "audit", genre: "", libelle: "", identifiant: "",
                               detail: "\(error)")]
            }
            return releves.map { probleme in
                let photo = try? probleme.element?.snapshot()
                let cadre = photo.map { "\(Int($0.frame.minX)),\(Int($0.frame.minY)),\(Int($0.frame.width)),\(Int($0.frame.height))" }
                return Defaut(langue: langue, ecran: ecran, sorte: "sans libellé (audit)",
                              genre: photo.map { Self.nom($0.elementType) } ?? "", libelle: photo?.label ?? "",
                              identifiant: photo?.identifier ?? "",
                              detail: probleme.compactDescription + (cadre.map { " @ " + $0 } ?? ""))
            }
        }
        return [Defaut(langue: langue, ecran: ecran, sorte: "audit inachevé", genre: "", libelle: "", identifiant: "",
                       detail: "l'audit des descriptions n'a pas fini à temps (3 essais)")]
    }

    /// Les éléments d'une photographie de l'arbre, de haut en bas (un parent avant ses enfants).
    static func elements(_ racine: XCUIElementSnapshot) -> [Element] {
        var sortie: [Element] = []
        /// Rend vrai si le nœud ou l'un de ses descendants porte un libellé.
        func parcourir(_ noeud: XCUIElementSnapshot, profondeur: Int, interieur: Bool) -> Bool {
            let libelle = normal(noeud.label)
            let porteur = !interieur && !libelle.isEmpty && !contenants.contains(noeud.elementType)
            let rang = sortie.count
            let garde = noeud.elementType != .application && noeud.elementType != .window
            if garde {
                sortie.append(Element(genre: noeud.elementType, libelle: noeud.label, identifiant: noeud.identifier,
                                      valeur: (noeud.value as? String) ?? (noeud.value.map { "\($0)" } ?? ""),
                                      indication: noeud.placeholderValue ?? "", profondeur: profondeur,
                                      interieur: interieur, enfantLibelle: false))
            }
            var enfantLibelle = false
            for enfant in noeud.children
                where parcourir(enfant, profondeur: profondeur + 1, interieur: interieur || porteur) {
                enfantLibelle = true
            }
            if enfantLibelle && garde {
                let e = sortie[rang]
                sortie[rang] = Element(genre: e.genre, libelle: e.libelle, identifiant: e.identifiant, valeur: e.valeur,
                                       indication: e.indication, profondeur: e.profondeur, interieur: e.interieur,
                                       enfantLibelle: true)
            }
            return enfantLibelle || !libelle.isEmpty
        }
        _ = parcourir(racine, profondeur: 0, interieur: false)
        return sortie
    }

    // MARK: Les règles

    /// Les défauts d'un élément que VoiceOver lit.
    private func examiner(_ e: Element, langue: String, ecran: String, francais: Set<String>) -> [Defaut] {
        var defauts: [Defaut] = []
        func defaut(_ sorte: String, _ detail: String) {
            defauts.append(Defaut(langue: langue, ecran: ecran, sorte: sorte, genre: e.nomGenre, libelle: e.libelle,
                                  identifiant: e.identifiant, detail: detail))
        }
        let libelle = Self.normal(e.libelle)
        if libelle.isEmpty {
            let lu = (e.genre == .cell && e.enfantLibelle)
                || (Self.champs.contains(e.genre) && !(Self.normal(e.indication).isEmpty && Self.normal(e.valeur).isEmpty))
            if (Self.interactifs.contains(e.genre) || e.genre == .cell) && !lu {
                defaut("sans libellé", "valeur « \(e.valeur) »")
            }
            return defauts
        }
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

    /// La référence d'une source, translittérée (« Likoutei Moharan II, 25 », « Yechayahou 65:24 », « Likoutei
    /// Etsot, Hitbodedout 16 ») : des mots latins à majuscule, un numéro de livre en chiffres romains, un chapitre.
    static let reference = #"[A-Z][\p{L}'’]+(?: [A-Z][\p{L}'’]+)*(?: [IVX]+)?(?:, [A-Z][\p{L}'’]+)?,? \d+(?::\d+)?"#

    /// La raison pour laquelle ce défaut n'en est pas un, ou nil. Chaque règle est étroite : un défaut qu'elle ne
    /// décrit pas exactement compte.
    private func tolerance(_ d: Defaut) -> String? {
        let libelle = Self.normal(d.libelle)
        // Le nom de l'app, le même dans toutes les langues (app_name d'Android, CFBundleDisplayName).
        if d.sorte == "non traduit" && libelle == "MyHitbodedut" {
            return "le nom de l'app, le même dans toutes les langues"
        }
        // « Sections » (siddur_signets, la bande des signets du lecteur) : le même mot en français et en anglais,
        // comme dans values et values-en d'Android.
        if d.sorte == "non traduit" && d.langue == "en" && libelle == "Sections" {
            return "le même mot en français et en anglais (siddur_signets d'Android)"
        }
        // La référence d'une source en espagnol et en arabe : Reference.localise ne la rend qu'en anglais et en
        // hébreu, comme Android (Reference.kt) ; l'espagnol et l'arabe ne traduisent que l'interface, les textes
        // restent en hébreu (Texte.pour), leur référence telle qu'écrite.
        if d.sorte == "non traduit" && (d.langue == "es" || d.langue == "ar-TN") {
            let sansReferences = libelle.replacingOccurrences(of: Self.reference, with: "", options: .regularExpression)
            if Self.motLatin(sansReferences) == nil {
                return "référence d'une source, que l'espagnol et l'arabe gardent telle qu'écrite (Reference.localise, comme Android)"
            }
        }
        // Un audit des descriptions qui n'a pas fini à temps n'est pas un défaut de l'app (AuditAccessibiliteTests).
        if d.sorte == "audit inachevé" {
            return "l'audit n'a pas fini à temps sur le simulateur de la CI (3 essais)"
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
