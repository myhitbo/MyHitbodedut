import Foundation

// Le dossier barriere/ du conteneur partagé (PORTAGE.md § 3.2) : l'instantané (etat.json, écrit par l'app seule), la
// boîte (boite.jsonl, où les extensions ajoutent leurs lignes), le journal de la barrière (historique.jsonl, l'app
// seule), la sélection de Temps d'écran (selection.json, l'app seule, des jetons que seul FamilyControls lit) et les
// images du personnage que le bouclier montre. Un seul écrivain par fichier, écriture atomique, sauf la boîte, où
// chacun ajoute à la fin. Foundation seule : l'app et les trois extensions s'en servent.

/// Les fichiers de la barrière, sous un dossier donné (le conteneur du groupe d'apps ; un dossier temporaire dans les
/// tests).
public struct FichiersBarriere: Sendable {

    /// Le groupe d'apps de l'app, des widgets et des extensions.
    public static let groupe = "group.com.myhitbodedut"

    /// <racine>/barriere.
    public let dossier: URL

    public init(racine: URL) {
        dossier = racine.appendingPathComponent("barriere", isDirectory: true)
    }

    /// Le conteneur du groupe d'apps ; nil sans la signature qui le donne (un simulateur sans équipe).
    public static func duGroupe() -> FichiersBarriere? {
        #if canImport(Darwin)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupe).map { FichiersBarriere(racine: $0) }
        #else
        nil
        #endif
    }

    public var etat: URL { dossier.appendingPathComponent(Etat.nomFichier) }
    public var boite: URL { dossier.appendingPathComponent(Boite.nomFichier) }
    public var historique: URL { dossier.appendingPathComponent("historique.jsonl") }
    public var selection: URL { dossier.appendingPathComponent("selection.json") }

    /// Une image du personnage copiée par l'app (« char_praise.webp »).
    public func image(_ nom: String) -> URL {
        dossier.appendingPathComponent(nom)
    }

    /// Le dossier, créé s'il manque, hors de la sauvegarde iCloud (les jetons ne servent que sur cet appareil).
    public func preparer() throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        #if canImport(Darwin)
        var url = dossier
        var valeurs = URLResourceValues()
        valeurs.isExcludedFromBackup = true
        try? url.setResourceValues(valeurs)
        #endif
    }

    // MARK: L'instantané

    public func lireEtat() -> Etat? {
        (try? Data(contentsOf: etat)).flatMap(Etat.lire)
    }

    /// Écrit l'instantané d'un coup ; rend vrai s'il a changé (deux écritures du même état donnent les mêmes octets).
    @discardableResult
    public func ecrire(_ nouveau: Etat) throws -> Bool {
        try preparer()
        let donnees = try nouveau.donnees()
        if let ancien = try? Data(contentsOf: etat), ancien == donnees { return false }
        try donnees.write(to: etat, options: .atomic)
        return true
    }

    // MARK: La boîte

    /// Les événements de la boîte, et le nombre d'octets lus (pour `retirerLu`).
    public func lireBoite() -> (evenements: [Evenement], octets: Int) {
        let donnees = (try? Data(contentsOf: boite)) ?? Data()
        return (Boite.lire(donnees, garder: Int.max), donnees.count)
    }

    /// Ajoute une ligne à la boîte (les extensions ; l'app ne s'y écrit pas).
    public func ajouter(_ evenement: Evenement) throws {
        try preparer()
        try Boite.ajouter(evenement, a: boite)
    }

    /// Retire de la boîte ce que l'app vient de lire et de verser au journal.
    public func retirerLu(octets: Int) throws {
        guard octets > 0 else { return }
        try Boite.retirer(octets, de: boite)
    }

    // MARK: Le journal de la barrière

    public func lireHistorique() -> [Evenement] {
        Boite.lire((try? Data(contentsOf: historique)) ?? Data())
    }

    /// Ajoute des événements au journal de la barrière, qui garde les cinquante derniers.
    public func journaliser(_ neufs: [Evenement]) throws {
        guard !neufs.isEmpty else { return }
        try preparer()
        let tous = Boite.historique(lireHistorique(), plus: neufs)
        try Boite.donnees(tous).write(to: historique, options: .atomic)
    }

    /// Ce que l'écran « Journal de la barrière » montre : le journal, puis ce que la boîte n'a pas encore versé.
    public func journal() -> [Evenement] {
        Boite.historique(lireHistorique(), plus: lireBoite().evenements)
    }

    // MARK: La sélection

    /// La sélection telle que FamilyControls l'a encodée, avec l'appareil où elle a été faite.
    public func lireSelection() -> SelectionEnregistree? {
        (try? Data(contentsOf: selection)).flatMap { try? JSONDecoder().decode(SelectionEnregistree.self, from: $0) }
    }

    public func ecrire(_ enregistree: SelectionEnregistree) throws {
        try preparer()
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]
        try encodeur.encode(enregistree).write(to: selection, options: .atomic)
    }
}

/// La sélection de Temps d'écran (`FamilyActivitySelection`, encodée par FamilyControls) et l'appareil où elle a été
/// faite : les jetons ne valent que sur l'iPhone qui les a donnés (§ 2.1.3), si bien qu'une sélection venue d'un autre
/// appareil (une restauration, un nouvel iPhone) est « à refaire » (§ 2.1.8).
public struct SelectionEnregistree: Codable, Sendable, Equatable {
    /// `FamilyActivitySelection` encodée en JSON.
    public var jetons: Data
    /// `UIDevice.identifierForVendor` au moment du choix ; vide s'il n'était pas connu.
    public var appareil: String
    /// Les applications, les catégories et les sites retenus.
    public var applications: Int
    public var categories: Int
    public var sites: Int

    public init(jetons: Data, appareil: String, applications: Int, categories: Int, sites: Int) {
        self.jetons = jetons
        self.appareil = appareil
        self.applications = applications
        self.categories = categories
        self.sites = sites
    }

    /// Ce que l'instantané compte : une application, une catégorie ou un site vaut un.
    public var nombreDeJetons: Int { max(applications, 0) + max(categories, 0) + max(sites, 0) }

    /// Faite sur cet appareil-ci ? Un identifiant inconnu d'un côté ou de l'autre ne fait pas refuser la sélection.
    public func valable(sur appareil: String) -> Bool {
        self.appareil.isEmpty || appareil.isEmpty || self.appareil == appareil
    }
}
