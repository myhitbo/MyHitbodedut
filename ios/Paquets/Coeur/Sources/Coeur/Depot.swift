import Foundation

// Le dépôt des fichiers d'iOS (PORTAGE.md § 3.1 et 3.2) : l'unique écrivain de journal.json et de
// reglages.json, dans un dossier donné à la construction (le conteneur de l'App Group dans l'app, un
// dossier temporaire dans les tests). C'est le pendant des deux fichiers de préférences d'Android :
// « myhitbodedut-journal » (les préférences days, journal_plus, first_name et days_corrompu) et
// « myhitbodedut » (les réglages, sous les noms de clés d'Android).
//
// Chaque écriture est atomique (le fichier est remplacé d'un coup, jamais à moitié écrit). La lecture est
// tolérante : un fichier absent est un dépôt neuf ; un fichier qui n'est pas un objet JSON en UTF-8 est
// copié sous un autre nom (journal.illisible.json, puis journal.illisible-2.json…) avant que la prochaine
// écriture ne le remplace, et la lecture repart de rien : il n'est jamais écrasé en silence, comme la
// préférence days_corrompu d'Android (Store.days). Une copie impossible fait échouer la lecture, et rien
// n'est alors écrit. Le journal est exclu de la sauvegarde iCloud, comme backup_rules.xml l'exclut de
// celle d'Android (décision D6) ; les réglages y restent.

/// Une faute du dépôt.
public enum ErreurDepot: Error, Sendable, Equatable {
    /// Un fichier illisible n'a pas trouvé de nom libre pour sa copie : il est laissé tel quel.
    case miseDeCoteImpossible(String)
}

/// L'unique écrivain du journal et des réglages.
public actor Depot {

    /// Le journal : les journées, le journal enrichi, le prénom.
    public static let fichierJournal = "journal.json"
    /// Les réglages, sous les noms de clés d'Android.
    public static let fichierReglages = "reglages.json"

    private let dossier: URL
    private let journalHorsSauvegarde: Bool
    private var journalLu: Journal?
    private var reglagesLus: Reglages?

    /// Les copies des fichiers illisibles faites par ce dépôt, dans l'ordre.
    public private(set) var misDeCote: [URL] = []

    /// `journalHorsSauvegarde` : le journal est exclu de la sauvegarde iCloud (sans effet hors des
    /// systèmes d'Apple).
    public init(dossier: URL, journalHorsSauvegarde: Bool = true) {
        self.dossier = dossier
        self.journalHorsSauvegarde = journalHorsSauvegarde
    }

    // MARK: Lecture

    /// Le journal, lu une fois puis gardé en mémoire.
    public func journal() throws -> Journal {
        if let journalLu {
            return journalLu
        }
        let lu = try lireJournal()
        journalLu = lu
        return lu
    }

    /// Les réglages, lus une fois puis gardés en mémoire.
    public func reglages() throws -> Reglages {
        if let reglagesLus {
            return reglagesLus
        }
        var lus = Reglages()
        if let objet = try lireObjet(Depot.fichierReglages) {
            lus = Reglages(brut: objet)
        }
        reglagesLus = lus
        return lus
    }

    // MARK: Écriture

    /// Change le journal et l'écrit, s'il a changé.
    public func modifier(_ changement: @Sendable (inout Journal) -> Void) throws {
        let avant = try journal()
        var nouveau = avant
        changement(&nouveau)
        if nouveau != avant {
            try ecrireJournal(nouveau)
        }
    }

    /// Change les réglages et les écrit, s'ils ont changé.
    public func modifierReglages(_ changement: @Sendable (inout Reglages) -> Void) throws {
        let avant = try reglages()
        var nouveaux = avant
        changement(&nouveaux)
        if nouveaux != avant {
            try ecrireReglages(nouveaux)
        }
    }

    /// Importe une sauvegarde (Sauvegarde.importer) et écrit les deux fichiers. Rend le nombre de journées
    /// importées, ou nil si le fichier est invalide ou pèse plus de 2 Mo ; rien n'est alors écrit.
    public func importer(_ donnees: Data, aujourdhui: JourCivil, morceauxLivres: Set<String>,
                         fuseauTelephone: String = "UTC") throws -> Int? {
        guard donnees.count <= Sauvegarde.importMaxOctets else { return nil }
        var nouveauJournal = try journal()
        var nouveauxReglages = try reglages()
        // Comme `String(octets, UTF_8)` d'Android : une suite d'octets fautive devient U+FFFD.
        let texte = String(decoding: donnees, as: UTF8.self)
        guard let importees = Sauvegarde.importer(texte: texte, journal: &nouveauJournal, reglages: &nouveauxReglages,
                                                  aujourdhui: aujourdhui, morceauxLivres: morceauxLivres,
                                                  fuseauTelephone: fuseauTelephone) else { return nil }
        try ecrireJournal(nouveauJournal)
        try ecrireReglages(nouveauxReglages)
        return importees
    }

    /// La sauvegarde à exporter (Sauvegarde.exporter), en UTF-8 sans marque d'ordre des octets.
    public func exporter(maintenant: Int64, fuseauTelephone: String = "UTC") throws -> Data {
        let leJournal = try journal()
        let lesReglages = try reglages()
        let texte = Sauvegarde.exporter(journal: leJournal, reglages: lesReglages, maintenant: maintenant,
                                        fuseauTelephone: fuseauTelephone)
        return Data(texte.utf8)
    }

    // MARK: Le format de journal.json

    /// Le texte de journal.json : les préférences du fichier « myhitbodedut-journal », la préférence
    /// days en objet et non en texte.
    static func texteJournal(_ journal: Journal) -> String {
        var objet = ObjetJSON([
            ("days", .objet(journal.days)),
            ("journal_plus", .objet(journal.plusBrut)),
            ("first_name", .chaine(journal.prenom)),
        ])
        if let corrompu = journal.corrompu {
            objet["days_corrompu"] = .chaine(corrompu)
        }
        return objet.texte()
    }

    /// Le journal de journal.json. La préférence days peut y être un objet, ou le texte de la préférence
    /// d'Android ; un texte illisible y est gardé dans `corrompu`, comme days_corrompu.
    static func journalDe(_ objet: ObjetJSON) -> Journal {
        Journal(daysTexte: texte(objet["days"]), journalPlusTexte: texte(objet["journal_plus"]),
                prenom: chaine(objet["first_name"]) ?? "", corrompu: chaine(objet["days_corrompu"]))
    }

    // MARK: Fichiers

    private func lireJournal() throws -> Journal {
        guard let objet = try lireObjet(Depot.fichierJournal) else { return Journal() }
        // Des journées qui ne sont ni un objet ni un texte ne se lisent pas : le fichier est gardé à part
        // avant que la prochaine écriture ne les perde.
        if let days = objet["days"], Depot.texte(days) == nil {
            try mettreDeCote(Depot.fichierJournal)
        }
        return Depot.journalDe(objet)
    }

    /// L'objet d'un fichier du dossier ; nil s'il n'existe pas, ou s'il est illisible (il est alors mis de côté).
    private func lireObjet(_ nom: String) throws -> ObjetJSON? {
        let cible = dossier.appendingPathComponent(nom)
        guard FileManager.default.fileExists(atPath: cible.path) else { return nil }
        let donnees = try Data(contentsOf: cible)
        // De l'UTF-8 valable : relu, le texte rend les mêmes octets (une suite fautive deviendrait U+FFFD).
        let texte = String(decoding: donnees, as: UTF8.self)
        if texte.utf8.elementsEqual(donnees), let objet = try? ObjetJSON(texte: texte) {
            return objet
        }
        try mettreDeCote(nom)
        return nil
    }

    /// Copie le fichier `nom` sous un nom libre : « journal.illisible.json », puis « journal.illisible-2.json »…
    private func mettreDeCote(_ nom: String) throws {
        let source = dossier.appendingPathComponent(nom)
        let racine = nom.hasSuffix(".json") ? String(nom.dropLast(5)) : nom
        for rang in 1...999 {
            let suffixe = rang == 1 ? "" : "-" + String(rang)
            let copie = dossier.appendingPathComponent(racine + ".illisible" + suffixe + ".json")
            if FileManager.default.fileExists(atPath: copie.path) {
                continue
            }
            try FileManager.default.copyItem(at: source, to: copie)
            if nom == Depot.fichierJournal && journalHorsSauvegarde {
                try Depot.exclureDeLaSauvegarde(copie)
            }
            misDeCote.append(copie)
            return
        }
        throw ErreurDepot.miseDeCoteImpossible(nom)
    }

    private func ecrireJournal(_ journal: Journal) throws {
        try ecrire(Depot.texteJournal(journal), nom: Depot.fichierJournal, horsSauvegarde: journalHorsSauvegarde)
        journalLu = journal
    }

    private func ecrireReglages(_ reglages: Reglages) throws {
        try ecrire(reglages.texte(), nom: Depot.fichierReglages, horsSauvegarde: false)
        reglagesLus = reglages
    }

    private func ecrire(_ texte: String, nom: String, horsSauvegarde: Bool) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true, attributes: nil)
        let cible = dossier.appendingPathComponent(nom)
        try Data(texte.utf8).write(to: cible, options: .atomic)
        // Après chaque écriture : le remplacement atomique du fichier ne garde pas l'attribut.
        if horsSauvegarde {
            try Depot.exclureDeLaSauvegarde(cible)
        }
    }

    /// Exclut un fichier de la sauvegarde iCloud ; rien hors des systèmes d'Apple.
    private static func exclureDeLaSauvegarde(_ fichier: URL) throws {
        #if canImport(Darwin)
        var cible = fichier
        var valeurs = URLResourceValues()
        valeurs.isExcludedFromBackup = true
        try cible.setResourceValues(valeurs)
        #endif
    }

    /// Un objet s'écrit en texte ; une chaîne, le texte d'une préférence d'Android, se garde telle quelle.
    private static func texte(_ valeur: JSON?) -> String? {
        switch valeur {
        case .objet(let objet)?:
            return objet.texte()
        case .chaine(let texte)?:
            return texte
        default:
            return nil
        }
    }

    private static func chaine(_ valeur: JSON?) -> String? {
        if case .chaine(let texte)? = valeur {
            return texte
        }
        return nil
    }
}
