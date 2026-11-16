import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La recherche globale (RechercheActivity.kt) : l'index rend ce que rend `RechercheGlobale.chercher` d'Android,
/// requête par requête ; l'écran groupe les résultats par sorte, un par texte et trente par sorte, en moins de
/// 300 ms une fois l'index prêt (mesuré ici, ContinuousClock) ; chaque résultat ouvre son écran ; seule la
/// dernière recherche s'affiche.
///
/// En série : les tests partagent un index (des secondes à préparer), et un noussa'h changé par l'un ferait
/// réindexer le siddour pendant la mesure d'un autre.
@Suite("Modèle de la recherche globale", .serialized)
@MainActor
struct RechercheModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)
    private static let hilloulot = HilloulotContenus(dossier: Fichiers.contenu)
    private static let preparateur = RecherchePreparateur(contenus: RechercheModeleTests.contenus,
                                                          hilloulot: RechercheModeleTests.hilloulot, langue: "fr")

    /// L'index partagé, prêt.
    private static func index(_ nusah: Nusah = .edot) async throws -> RechercheIndex {
        let index = await preparateur.index(nusah)
        return try #require(index)
    }

    private static func fabriquer(_ nusah: Nusah = .edot) -> (RechercheModele, Magasin) {
        var reglages = Reglages()
        reglages.setSiddurNusah(nusah)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        return (RechercheModele(magasin: magasin, preparateur: preparateur), magasin)
    }

    private static func resultats(_ modele: RechercheModele) throws -> RechercheResultats {
        let r = modele.resultats
        return try #require(r)
    }

    // MARK: Le critère de la feuille de route

    @Test func uneRechercheRendSesResultatsGroupesEnMoinsDe300ms() async throws {
        let (modele, _) = Self.fabriquer()
        #expect(modele.etat == .preparation)
        await modele.charger()
        #expect(modele.etat == .pret)

        // La meilleure de cinq mesures : les autres suites tournent en même temps, sur le même acteur principal,
        // et une seule mesure jugerait leur charge plutôt que la recherche.
        let horloge = ContinuousClock()
        var meilleure = Duration.seconds(3600)
        for _ in 0..<5 {
            modele.chercher("")
            let debut = horloge.now
            modele.chercher("שלום")
            #expect(modele.enCours)
            await modele.attendre()
            let duree = horloge.now - debut
            if duree < meilleure { meilleure = duree }
            #expect(!modele.enCours)
        }
        #expect(meilleure < .milliseconds(300), "\(meilleure)")

        let r = try Self.resultats(modele)
        #expect(r.texte == "שלום")
        let total = r.groupes.reduce(0) { $0 + $1.lignes.count }
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(total)))
        // Les quatre sortes, dans l'ordre de RechercheGlobale.Sorte, sous les noms des filtres.
        let sortes = r.groupes.map { $0.sorte }
        #expect(sortes == [.siddour, .livre, .halakha, .hilloula])
        let titres = r.groupes.map { $0.titre }
        #expect(titres == [Libelle("recherche_tefilot"), Libelle("recherche_livres"), Libelle("recherche_halakhot"),
                           Libelle("hilloulot_title")])
        for g in r.groupes {
            // Trente par sorte ; la halakha : trente du Yalkut Yosef, puis trente du Ben Ish 'Haï.
            let plafond = g.sorte == .halakha ? 2 * RechercheGlobale.parSorte : RechercheGlobale.parSorte
            #expect(g.lignes.count <= plafond, "\(g.sorte)")
            #expect(!g.lignes.isEmpty, "\(g.sorte)")
        }
        // Un résultat par texte : une prière ou un livre n'y est qu'une fois.
        for g in r.groupes where g.sorte == .siddour || g.sorte == .livre {
            let routes = g.lignes.map { $0.route }
            #expect(Set(routes).count == routes.count, "\(g.sorte)")
        }
        let ids = r.groupes.flatMap { $0.lignes }.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test func uneRechercheFrequenteSArreteATrenteParSorte() async throws {
        let (modele, _) = Self.fabriquer()
        await modele.charger()
        // « ה » double : partout ; chaque sorte bute sur son plafond.
        modele.chercher("הה")
        await modele.attendre()
        let r = try Self.resultats(modele)
        let siddour = r.groupes.first(where: { $0.sorte == .siddour })?.lignes.count ?? 0
        let siddourEdot = try await Self.contenus.siddur(.edot).textes.count
        #expect(siddour <= min(RechercheGlobale.parSorte, siddourEdot))
        for g in r.groupes {
            let plafond = g.sorte == .halakha ? 2 * RechercheGlobale.parSorte : RechercheGlobale.parSorte
            #expect(g.lignes.count <= plafond, "\(g.sorte)")
        }
        // La halakha bute vraiment sur ses plafonds : trente du Yalkut Yosef au plus, trente du Ben Ish 'Haï au plus.
        let yalkut = try await Self.contenus.yalkutYosef()
        let benIshHai = try await Self.contenus.benIshHai()
        let yy = YalkutYosef.recherche(yalkut, texte: "הה").count
        let bih = Halakha.recherche(benIshHai, texte: "הה").count
        #expect(bih > RechercheGlobale.parSorte)
        let halakha = r.groupes.first(where: { $0.sorte == .halakha })?.lignes.count ?? 0
        #expect(halakha == min(yy, RechercheGlobale.parSorte) + min(bih, RechercheGlobale.parSorte))
    }

    // MARK: L'index rend ce que rend Android

    @Test(arguments: zip(["שלום", "hachahar", "נחמן", "שבת", "תהלים"],
                         [RechercheGlobale.Portee.tout, .tout, .tout, .halakhot, .sefarim]))
    func lIndexRendCeQueRendRechercheGlobale(_ texte: String, _ portee: RechercheGlobale.Portee) async throws {
        let lues = await RechercheSources.charger(contenus: Self.contenus, hilloulot: Self.hilloulot, nusah: .edot)
        let sources = try #require(lues)
        let index = try await Self.index()
        let obtenus = index.chercher(texte, portee: portee)
        let attendus = RechercheGlobale.chercher(texte, langue: "fr", siddur: sources.siddur, livres: sources.livres,
                                                 yalkut: sources.yalkut, benIshHai: sources.benIshHai,
                                                 hilloulot: sources.hilloulot, portee: portee)
        #expect(!attendus.isEmpty)
        #expect(obtenus.count == attendus.count)
        #expect(obtenus == attendus)
    }

    @Test func unTexteTropCourtNeTrouveRien() async throws {
        let index = try await Self.index()
        #expect(index.chercher("ש").isEmpty)
        #expect(index.chercher("  ש  ").isEmpty)
        // Deux guillemets : deux unités tapées, aucune une fois mises à nu.
        #expect(index.chercher("\"\"").isEmpty)
    }

    // MARK: L'écran

    @Test func moinsDeDeuxUnitesVidentLaListe() async throws {
        let (modele, _) = Self.fabriquer()
        await modele.charger()
        modele.chercher("שלום")
        await modele.attendre()
        #expect(modele.resultats != nil)
        modele.chercher(" ש ")
        #expect(modele.resultats == nil)
        #expect(!modele.enCours)
        // Deux unités qui ne se mettent pas à nu : « Résultats : 0 », sans groupe (afficher d'Android).
        modele.chercher("\"\"")
        await modele.attendre()
        let r = try Self.resultats(modele)
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(0)))
        #expect(r.groupes.isEmpty)
    }

    @Test func seuleLaDerniereRechercheSAffiche() async throws {
        let (modele, _) = Self.fabriquer()
        await modele.charger()
        modele.chercher("של")
        modele.chercher("שלו")
        modele.chercher("נחמן")
        await modele.attendre()
        let r = try Self.resultats(modele)
        #expect(r.texte == "נחמן")
        let index = try await Self.index()
        let attendus = index.chercher("נחמן").count
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(attendus)))
    }

    @Test func laPorteeRestreintLesSortesEtRelanceLaRecherche() async throws {
        let (modele, _) = Self.fabriquer()
        let puces = modele.portees.map { $0.portee }
        #expect(puces == [.tout, .tefilot, .halakhot, .sefarim, .hilloulot])
        let libelles = modele.portees.map { $0.libelle }
        #expect(libelles == [Libelle("recherche_tout"), Libelle("recherche_tefilot"), Libelle("recherche_halakhot"),
                             Libelle("recherche_sefarim"), Libelle("hilloulot_title")])
        let choisie = modele.portees.filter { $0.choisie }.map { $0.portee }
        #expect(choisie == [.tout])
        #expect(modele.indice == Libelle("recherche_indice"))

        await modele.charger()
        modele.chercher("שלום")
        await modele.attendre()
        modele.choisirPortee(.hilloulot)
        await modele.attendre()
        let r = try Self.resultats(modele)
        let sortes = r.groupes.map { $0.sorte }
        #expect(sortes == [.hilloula])
        let apres = modele.portees.filter { $0.choisie }.map { $0.portee }
        #expect(apres == [.hilloulot])
        // Une hilloula ouvre l'écran des hilloulot, son champ rempli de la recherche telle que tapée.
        let routes = Set(r.groupes.flatMap { $0.lignes }.map { $0.route })
        #expect(routes == [.hilloulot(recherche: "שלום")])
    }

    @Test func chaqueResultatOuvreSonEcran() async throws {
        let siddour = RechercheGlobale.Resultat(sorte: .siddour, id: "arvit", titre: "ערבית", extrait: "Arvit")
        let livre = RechercheGlobale.Resultat(sorte: .livre, id: "likoutei_moharan", titre: "ליקוטי מוהר״ן", extrait: "")
        let halakha = RechercheGlobale.Resultat(sorte: .halakha, id: " שבת ", titre: "ילקוט יוסף", extrait: "…")
        let hilloula = RechercheGlobale.Resultat(sorte: .hilloula, id: "נחמן", titre: "Rabbi Nahman", extrait: "")
        #expect(RechercheModele.route(siddour) == .siddour("arvit"))
        #expect(RechercheModele.route(livre) == .livre("likoutei_moharan"))
        #expect(RechercheModele.route(halakha) == .halakha(recherche: " שבת "))
        #expect(RechercheModele.route(hilloula) == .hilloulot(recherche: "נחמן"))

        // Un extrait blanc ne s'affiche pas.
        let (modele, _) = Self.fabriquer()
        await modele.charger()
        modele.chercher("שלום")
        await modele.attendre()
        let r = try Self.resultats(modele)
        let lignes = r.groupes.flatMap { $0.lignes }
        let blancs = lignes.filter { ($0.extrait ?? "x").estBlanc }.count
        #expect(blancs == 0)
    }

    @Test func leSiddourEstCeluiDuNoussahDesReglages() async throws {
        let (modele, _) = Self.fabriquer(.ashkenaz)
        await modele.charger()
        modele.chercher("שלום")
        await modele.attendre()
        let r = try Self.resultats(modele)
        let siddurAshkenaz = try await Self.contenus.siddur(.ashkenaz)
        let ashkenaz = Set(siddurAshkenaz.textes.map { $0.id })
        var ids: [String] = []
        for g in r.groupes where g.sorte == .siddour {
            for l in g.lignes {
                if case .siddour(let id) = l.route { ids.append(id) }
            }
        }
        #expect(!ids.isEmpty)
        #expect(Set(ids).isSubset(of: ashkenaz))
        // Les prières trouvées sont celles du siddour ashkénaze, dans son ordre (bien des ids sont communs aux
        // noussa'him : l'inclusion seule ne le prouverait pas).
        let attendus = RechercheGlobale.dansRecueil(siddurAshkenaz, RechercheGlobale.nu("שלום"), .siddour, langue: "fr")
            .map { $0.id }
        #expect(ids == attendus)
        // Le préparateur rend l'index de ce noussa'h ; revenir à l'edot réindexe le seul siddour.
        let index = try await Self.index(.ashkenaz)
        #expect(index.nusah == .ashkenaz)
        let edot = try await Self.index(.edot)
        #expect(edot.nusah == .edot)
    }

    @Test func sansSiddourLaRechercheNeTrouveRien() async throws {
        let vide = RecherchePreparateur(contenus: ContenusApp(lecteur: { _ in nil }),
                                        hilloulot: HilloulotContenus(lecteur: { _ in nil }), langue: "fr")
        let modele = RechercheModele(magasin: .enMemoire(), preparateur: vide)
        await modele.charger()
        #expect(modele.etat == .erreur)
        modele.chercher("שלום")
        await modele.attendre()
        let r = try Self.resultats(modele)
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(0)))
        #expect(r.groupes.isEmpty)
    }

    @Test func uneAttenteRetablieNeChangePasLeResultat() async throws {
        let magasin = Magasin.enMemoire()
        let modele = RechercheModele(magasin: magasin, preparateur: Self.preparateur, delai: .milliseconds(20))
        await modele.charger()
        modele.chercher("שלו")
        modele.chercher("שלום")
        await modele.attendre()
        let r = try Self.resultats(modele)
        #expect(r.texte == "שלום")
    }
}
