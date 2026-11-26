import Foundation
import Synchronization
import Testing
import Coeur
@testable import Ecrans

/// Les contenus de l'app, lus comme l'app les lira, dans le dossier exporté du dépôt (ios/Ressources/Contenu) :
/// chacun se charge et garde les comptes de la feuille de route (ROADMAP.md, tâche 5). Leurs règles sont
/// jugées dans CoeurTests ; ici, que l'acteur les sert, ne les lit qu'une fois et rend ses erreurs.
@Suite("Contenus de l'app")
struct ContenusAppTests {

    /// Un seul acteur pour la suite : chaque contenu n'est lu qu'une fois, quel que soit le test qui le demande.
    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    // MARK: Le siddour

    @Test func lesTroisSiddourimOntTrenteHuitTextes() async throws {
        for nusah in Nusah.allCases {
            let siddur = try await Self.contenus.siddur(nusah)
            let textes = siddur.textes.count
            #expect(textes == 38, "\(nusah.rawValue)")
            let groupes = siddur.groupes.count
            #expect(groupes == 4, "\(nusah.rawValue)")
            let nom = siddur.nusah.fr
            #expect(!nom.isEmpty, "\(nusah.rawValue) sans nom")
        }
        let edot = try await Self.contenus.siddur(.edot)
        let premier = edot.textes.first?.id
        #expect(premier == "birkot_hachahar")
    }

    @Test func lesAnnotationsDesignentDesTextesDuSiddour() async throws {
        for nusah in Nusah.allCases {
            let annotations = try await Self.contenus.annotations(nusah)
            #expect(!annotations.isEmpty, "\(nusah.rawValue) sans annotation")
            let siddur = try await Self.contenus.siddur(nusah)
            let inconnus = Set(annotations.keys).subtracting(siddur.textes.map(\.id))
            #expect(inconnus.isEmpty, "\(nusah.rawValue) : \(inconnus.sorted())")
        }
        // 22 textes annotés en Edot depuis les deux catégories du 26/11 ; 21 depuis l'audit du 16/11 d'Android (8 avant).
        let edot = try await Self.contenus.annotations(.edot).count
        #expect(edot == 22)
    }

    // MARK: Les textes

    @Test func tehilimACentCinquantePsaumes() async throws {
        let tehilim = try await Self.contenus.tehilim()
        let psaumes = tehilim.psaumes.count
        #expect(psaumes == Tehilim.nombreDePsaumes)
        #expect(psaumes == 150)
        let versets = tehilim.versetsTotal
        #expect(versets == 2527)
    }

    @Test func leTikounADixPsaumes() async throws {
        let tikkun = try await Self.contenus.tikkun()
        let numeros = tikkun.psaumes.map { $0.numero }
        #expect(numeros == [16, 32, 41, 42, 59, 77, 90, 105, 137, 150])
    }

    @Test func laBibliothequeEtLeChizuk() async throws {
        let bibliotheque = try await Self.contenus.bibliotheque()
        #expect(bibliotheque.version == "0.1")
        let entrees = bibliotheque.entrees.count
        #expect(entrees > 0)
        let sousSection = bibliotheque.sousSection("hitbodedut-ma-velama")?.titre.he
        #expect(sousSection == "התבודדות מה ולמה")
        let chizuk = try await Self.contenus.chizuk()
        let items = chizuk.items.count
        #expect(items == 171)
    }

    @Test func lesDeuxLivresDeLaHalakha() async throws {
        let benIshHai = try await Self.contenus.benIshHai()
        let annees = benIshHai.annees.keys.sorted()
        #expect(annees == ["1", "2"])
        var halakhot = benIshHai.hanouka?.halakhot.count ?? 0
        for annee in benIshHai.annees.values {
            for section in annee.values { halakhot += section.halakhot.count }
        }
        #expect(halakhot == 2002)
        let yalkut = try await Self.contenus.yalkutYosef()
        // 13 périodes : Chavouot a la sienne depuis l'audit du 12/11 d'Android.
        let periodes = yalkut.ordre.count
        #expect(periodes == 13)
        let premiere = yalkut.ordre.first
        #expect(premiere == "ordinaire")
        let ordinaire = yalkut.periodes["ordinaire"]?.isEmpty
        #expect(ordinaire == false)
    }

    @Test func leGuideDesSujets() async throws {
        let sujets = try await Self.contenus.guideSujets()
        let cles = sujets.cles
        #expect(cles == ["emotions", "gratitude", "decisions", "famille", "zivoug", "parnassa", "avoda",
                         "difficultes", "croissance"])
        let invitation = GuideSujets.invitation(sujets, theme: .gratitude, cle: "sihah", langue: "fr")
        #expect(invitation != nil)
        let autre = GuideSujets.invitation(sujets, theme: .autre, cle: "sihah", langue: "fr")
        #expect(autre == nil)
    }

    // MARK: Les livres

    @Test func lIndexDesLivresEtUnLivreDeChaqueSorte() async throws {
        let index = try await Self.contenus.livres()
        let ids = index.textes.map(\.id)
        #expect(ids == [
            "guide_hitbodedut", "likoutei_etsot", "sefer_hamidot", "likoutei_moharan", "hichtapkhout", "kokhvei_or",
            "tefila_lishlomo", "meguilat_esther", "chir_hachirim", "nichmat", "perek_chira", "yalkut_yosef_kitsour",
        ])
        let sansTexte = index.textes.allSatisfy { $0.sections.isEmpty }
        #expect(sansTexte)
        // Découpé par l'export (livres/likoutei_etsot/) : tous ses chapitres sont lus.
        let etsot = try await Self.contenus.livre("likoutei_etsot")
        let chapitres = etsot.sections.count
        #expect(chapitres == 55)
        let annonces = index.texte("likoutei_etsot")?.chapitres
        #expect(annonces == chapitres)
        // D'un seul fichier (livre_nichmat.json).
        let nichmat = try await Self.contenus.livre("nichmat")
        let sections = nichmat.sections.count
        #expect(sections == 1)
        #expect(nichmat.id == "nichmat")
    }

    // MARK: Le reste

    @Test func lesVillesLaMusiqueEtLesPalettes() async throws {
        let villes = try await Self.contenus.villes()
        #expect(villes.count == 51)
        let premiere = villes.first?.nom.fr
        #expect(premiere == "Jérusalem")
        let morceaux = try await Self.contenus.musique()
        #expect(morceaux.count == 23)  // trois retirés le 16/11 sur Android, sans accord écrit ; MusiquePlay.horsIOS (26/11)
        let premier = morceaux.first?.id
        #expect(premier == "hamelech_basade")
        let palettes = try await Self.contenus.palettes()
        let jour = palettes.palette(fond: .vert, accent: .vert, nuit: false)
        let nuit = palettes.palette(fond: .vert, accent: .vert, nuit: true)
        let marque = jour[.brand].hex
        #expect(marque == "#16775A")
        #expect(jour != nuit)
    }

    // MARK: Mémoire et erreurs

    /// Les chemins demandés au lecteur, dans l'ordre.
    private final class Demandes: Sendable {
        let chemins = Mutex<[String]>([])

        func noter(_ chemin: String) {
            chemins.withLock { $0.append(chemin) }
        }

        var liste: [String] {
            chemins.withLock { $0 }
        }
    }

    @Test func unContenuNEstLuQuUneFoisPuisOubliable() async throws {
        let demandes = Demandes()
        let dossier = ContenusApp.lecteur(dossier: Fichiers.contenu)
        let contenus = ContenusApp(lecteur: { chemin in
            demandes.noter(chemin)
            return try dossier(chemin)
        })
        let premieres = try await contenus.villes()
        let secondes = try await contenus.villes()
        #expect(premieres == secondes)
        _ = try await contenus.annotations(.edot)
        _ = try await contenus.annotations(.edot)
        let lus = demandes.liste
        #expect(lus == ["villes.json", "siddur_annotations.json"])
        await contenus.oublier()
        _ = try await contenus.villes()
        let relus = demandes.liste
        #expect(relus == ["villes.json", "siddur_annotations.json", "villes.json"])
    }

    @Test func unContenuAbsentSeRendEnErreur() async throws {
        let contenus = ContenusApp(lecteur: { _ in nil })
        var absent: ErreurContenu?
        do {
            _ = try await contenus.villes()
        } catch let erreur as ErreurContenu {
            absent = erreur
        }
        #expect(absent == ErreurContenu.absent("villes.json"))
        // Les lecteurs de Coeur (TehilimLoader, Livres) disent aussi ce qui manque.
        var tehilim: ErreurContenu?
        do {
            _ = try await contenus.tehilim()
        } catch let erreur as ErreurContenu {
            tehilim = erreur
        }
        #expect(tehilim == ErreurContenu.absent("tehilim.json"))
        var livres: ErreurContenu?
        do {
            _ = try await contenus.livre("nichmat")
        } catch let erreur as ErreurContenu {
            livres = erreur
        }
        #expect(livres == ErreurContenu.absent("livres/nichmat/index.json"))
    }

    @Test func unContenuIlisibleSeRendEnErreurEtSeraRelu() async throws {
        let demandes = Demandes()
        let contenus = ContenusApp(lecteur: { chemin in
            demandes.noter(chemin)
            return Data("{ pas du JSON".utf8)
        })
        var echecs = 0
        for _ in 0..<2 {
            do {
                _ = try await contenus.siddur(.edot)
            } catch {
                echecs += 1
            }
        }
        #expect(echecs == 2)
        // Rien n'est gardé d'une lecture manquée : la seconde demande relit le fichier.
        let lus = demandes.liste
        #expect(lus == ["siddur_edot.json", "siddur_edot.json"])
    }
}
