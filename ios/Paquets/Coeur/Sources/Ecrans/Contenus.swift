import Foundation
import Coeur

/// Les contenus exportés d'Android (`ios/Ressources/Contenu`, écrits par tools/export_contenu), lus à la
/// première demande puis gardés en mémoire. L'app les lit dans son paquet, les tests dans le dépôt, un aperçu
/// dans ce qu'on lui donne : tout passe par le lecteur reçu à la construction, jamais par `Bundle.main`.
///
/// Chaque lecture est celle de Coeur (`Siddur`, `SiddurJour.parse`, `TehilimLoader`, `TikkunLoader`,
/// `Villes.lire`, `Halakha.parse`, `YalkutYosef.parse`, `GuideSujets.lire`, `Morceau.lire`, `Livres`,
/// `Palettes.lire`). Une erreur de lecture se rend (`throws`), jamais de plantage ; un contenu qui n'a pu être
/// lu n'est pas gardé, il sera relu à la demande suivante.
///
/// Un acteur : les écrans le partagent, et ses lectures ne s'interrompent pas (aucune ne suspend), si bien que
/// deux demandes du même contenu n'en font qu'une lecture.
///
/// Les hilloulot n'y sont pas encore : Hilloulot.swift est en chantier dans Coeur (`enChantierSources` de
/// Package.swift), sa lecture viendra avec son intégration.
public actor ContenusApp {

    /// Lit un contenu par son chemin sous `Contenu/` (« siddur_edot.json », « livres/<id>/index.json ») ;
    /// nil s'il n'existe pas. Le `LecteurContenu` de Coeur, partageable entre fils d'exécution.
    public typealias Lecteur = @Sendable (String) throws -> Data?

    private let lire: Lecteur

    private var siddourim: [Nusah: Siddur] = [:]
    private var annotationsParNusah: [Nusah: [String: [SiddurJour.Annotation]]] = [:]
    private var tehilimLu: Tehilim?
    private var tikkunLu: Tikkun?
    private var bibliothequeLue: Bibliotheque?
    private var chizukLu: Chizuk?
    private var villesLues: [Ville]?
    private var benIshHaiLu: Halakha.Livre?
    private var yalkutYosefLu: YalkutYosef.Livre?
    private var guideSujetsLu: ObjetJSON?
    private var morceauxLus: [Morceau]?
    private var indexLivres: Siddur?
    private var livresLus: [String: SiddurTexte] = [:]
    private var palettesLues: Palettes?

    public init(lecteur: @escaping Lecteur) {
        lire = lecteur
    }

    /// Les contenus d'un dossier : `Contenu/` du paquet de l'app, ou `ios/Ressources/Contenu` du dépôt.
    public init(dossier: URL) {
        lire = ContenusApp.lecteur(dossier: dossier)
    }

    /// Le lecteur des fichiers d'un dossier : nil pour un fichier absent, l'erreur de lecture sinon.
    public static func lecteur(dossier: URL) -> Lecteur {
        { chemin in
            let fichier = dossier.appendingPathComponent(chemin)
            guard FileManager.default.fileExists(atPath: fichier.path) else { return nil }
            return try Data(contentsOf: fichier)
        }
    }

    /// Oublie tout ce qui a été lu (mémoire basse) : chaque contenu sera relu à sa prochaine demande.
    public func oublier() {
        siddourim = [:]
        annotationsParNusah = [:]
        tehilimLu = nil
        tikkunLu = nil
        bibliothequeLue = nil
        chizukLu = nil
        villesLues = nil
        benIshHaiLu = nil
        yalkutYosefLu = nil
        guideSujetsLu = nil
        morceauxLus = nil
        indexLivres = nil
        livresLus = [:]
        palettesLues = nil
    }

    // MARK: Le siddour

    /// Le siddour d'un nusah (`siddur_<nusah>.json`, SiddurLoader) : ses groupes et ses textes.
    public func siddur(_ nusah: Nusah) throws -> Siddur {
        if let lu = siddourim[nusah] { return lu }
        let donnees = try requis(nusah.fichier)
        let lu = try JSONDecoder().decode(Siddur.self, from: donnees)
        siddourim[nusah] = lu
        return lu
    }

    /// Les annotations du siddour d'un nusah (`siddur_annotations.json`), par identifiant de texte.
    public func annotations(_ nusah: Nusah) throws -> [String: [SiddurJour.Annotation]] {
        if let lues = annotationsParNusah[nusah] { return lues }
        let donnees = try requis("siddur_annotations.json")
        let lues = try SiddurJour.parse(String(decoding: donnees, as: UTF8.self), nusah)
        annotationsParNusah[nusah] = lues
        return lues
    }

    // MARK: Les textes

    /// Le livre de Tehilim (`tehilim.json`, TehilimLoader).
    public func tehilim() throws -> Tehilim {
        if let tehilimLu { return tehilimLu }
        let lu = try TehilimLoader.load(lire)
        tehilimLu = lu
        return lu
    }

    /// Le Tikoun HaKlali (`tikkun_haklali.json`, TikkunLoader).
    public func tikkun() throws -> Tikkun {
        if let tikkunLu { return tikkunLu }
        let lu = try TikkunLoader.load(lire)
        tikkunLu = lu
        return lu
    }

    /// La bibliothèque (`bibliotheque.json`, Library.kt).
    public func bibliotheque() throws -> Bibliotheque {
        if let bibliothequeLue { return bibliothequeLue }
        let donnees = try requis("bibliotheque.json")
        let lue = try JSONDecoder().decode(Bibliotheque.self, from: donnees)
        bibliothequeLue = lue
        return lue
    }

    /// Les textes de 'hizouk (`chizuk.json`, Chizuk.kt).
    public func chizuk() throws -> Chizuk {
        if let chizukLu { return chizukLu }
        let donnees = try requis("chizuk.json")
        let lu = try JSONDecoder().decode(Chizuk.self, from: donnees)
        chizukLu = lu
        return lu
    }

    /// Le Ben Ish 'Haï, la halakha du jour par paracha (`ben_ish_hai.json`, Halakha.kt).
    public func benIshHai() throws -> Halakha.Livre {
        if let benIshHaiLu { return benIshHaiLu }
        let lu = try Halakha.parse(requis("ben_ish_hai.json"))
        benIshHaiLu = lu
        return lu
    }

    /// La sélection du Yalkout Yossef, par période (`yalkut_yosef.json`, YalkutYosef.kt).
    public func yalkutYosef() throws -> YalkutYosef.Livre {
        if let yalkutYosefLu { return yalkutYosefLu }
        let lu = try YalkutYosef.parse(requis("yalkut_yosef.json"))
        yalkutYosefLu = lu
        return lu
    }

    /// L'objet « sujets » du guide de la hitbodedout (`guide_sujets.json`), que lit `GuideSujets.invitation`.
    public func guideSujets() throws -> ObjetJSON {
        if let guideSujetsLu { return guideSujetsLu }
        let lu = try GuideSujets.lire(requis("guide_sujets.json"))
        guideSujetsLu = lu
        return lu
    }

    // MARK: Les livres

    /// L'index des livres (`livres_titres.json`) : l'ordre, les groupes et le nombre de chapitres, sans texte.
    public func livres() throws -> Siddur {
        if let indexLivres { return indexLivres }
        let lu = try Livres.index(lire)
        indexLivres = lu
        return lu
    }

    /// Un livre entier, chapitres compris : `livre_<id>.json`, ou découpé sous `livres/<id>/`.
    public func livre(_ id: String) throws -> SiddurTexte {
        if let lu = livresLus[id] { return lu }
        let lu = try Livres.livre(id, lire)
        livresLus[id] = lu
        return lu
    }

    // MARK: Le reste

    /// Les villes du choix du lieu (`villes.json`, GeoNames, Villes.kt).
    public func villes() throws -> [Ville] {
        if let villesLues { return villesLues }
        let lues = try Villes.lire(requis("villes.json"))
        villesLues = lues
        return lues
    }

    /// Les morceaux livrés (`musique.json`), dans l'ordre de MusiquePlay.kt.
    public func musique() throws -> [Morceau] {
        if let morceauxLus { return morceauxLus }
        let lus = try Morceau.lire(requis("musique.json"))
        morceauxLus = lus
        return lus
    }

    /// Les palettes de l'apparence (`palettes.json`) : chaque fond avec chaque accent, de jour et de nuit.
    public func palettes() throws -> Palettes {
        if let palettesLues { return palettesLues }
        let lues = try Palettes.lire(requis("palettes.json"))
        palettesLues = lues
        return lues
    }

    /// Les octets d'un contenu qui doit exister : son absence est une erreur (`ErreurContenu.absent`).
    private func requis(_ chemin: String) throws -> Data {
        guard let donnees = try lire(chemin) else { throw ErreurContenu.absent(chemin) }
        return donnees
    }
}
