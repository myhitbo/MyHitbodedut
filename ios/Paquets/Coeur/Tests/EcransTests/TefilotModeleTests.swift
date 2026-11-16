import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran Tfilot (TefilotActivity.kt) : le bandeau, les dix sujets dans l'ordre demandé, chacun suivi de ses
/// prières, la référence dans la langue de l'app, la mise en garde quand la leçon citée traite d'un autre sujet,
/// et l'entrée de la bibliothèque qu'ouvre chaque prière. Sur la bibliothèque exportée du dépôt, et sur une petite
/// bibliothèque écrite ici (un sujet sans prière, un article, un sujet inconnu).
///
/// Restent au test d'interface : la liste à l'écran, l'ouverture de l'entrée (BibliothequeEntreeModele) et sa
/// règle de vocalisation.
@Suite("Modèle de l'écran Tfilot")
@MainActor
struct TefilotModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private static func modele(langue: String = "fr", reglages: Reglages = Reglages(),
                               contenus: ContenusApp? = nil) async -> TefilotModele {
        let modele = TefilotModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                                   contenus: contenus ?? Self.contenus, langue: langue)
        await modele.charger()
        return modele
    }

    /// Trois prières : la guérison (leçon sur un autre sujet), la joie, une prière sans sujet connu ; un article ;
    /// rien pour l'hitbodedout.
    private static let petite = """
    {"_meta": {"version": "t", "editions": {"pd": {"titre": "PD", "licence": "Public Domain", "nikkoud_ok": true}}},
     "sections": [{"id": "tefilot", "titre": {"he": "תפילות", "fr": "Prières", "en": "Prayers"}, "sous_sections": [
       {"id": "tefilot-lt", "titre": {"he": "ליקוטי תפילות", "fr": "", "en": ""}, "entrees": [
         {"type": "source", "id": "r1", "titre_he": "רפואה", "ref": "Likoutei Tefilot I, 136", "edition": "pd",
          "paragraphes": ["א"], "sujet": "refua", "lecon_sur_le_sujet": "non"},
         {"type": "article", "id": "a1", "titre": "מאמר", "sujet": "simcha"},
         {"type": "source", "id": "s1", "titre_he": "שמחה", "ref": "Likoutei Tefilot II, 21", "edition": "pd",
          "paragraphes": ["ב"], "sujet": "simcha", "lecon_sur_le_sujet": "oui"},
         {"type": "source", "id": "x1", "titre_he": "אחר", "ref": "", "edition": "pd",
          "paragraphes": ["ג"], "sujet": "autre"}
       ]}]}]}
    """

    private static func contenusEcrits(_ json: String) -> ContenusApp {
        let donnees = Data(json.utf8)
        return ContenusApp(lecteur: { chemin in chemin == "bibliotheque.json" ? donnees : nil })
    }

    // MARK: Le bandeau

    @Test func leBandeauDitLesDixSujets() async {
        let modele = await Self.modele()
        #expect(modele.titre == Libelle("tefilot_title"))
        #expect(modele.sousTitre == Libelle("tefilot_hint"))
        #expect(modele.image == "char_torah")
        var reglages = Reglages()
        reglages.setAdresse("f")
        let femme = await Self.modele(reglages: reglages)
        #expect(femme.image == Personnage.feminin("char_torah"))
    }

    // MARK: La liste

    @Test func lesDixSujetsDansLOrdreChacunSuiviDeSesPrieres() async throws {
        let modele = await Self.modele()
        #expect(modele.etat == .pret)
        let lignes = modele.lignes
        let sujets = lignes.filter { $0.sorte == .sujet }.map { $0.id }
        #expect(sujets == SujetTefila.allCases.map { "sujet:" + $0.cle })
        let prieres = lignes.filter { $0.sorte == .priere }
        #expect(prieres.count == 21)
        #expect(lignes.count == 31)

        let premieres = lignes.prefix(4).map { $0.id }
        #expect(premieres == ["sujet:hitbodedut", "priere:src-lt-hitbodedut", "priere:src-lt-hitbodedut-2", "sujet:simcha"])

        // Le compte d'un sujet est celui des prières qui le suivent.
        var rang = 0
        while rang < lignes.count {
            let sujet = lignes[rang]
            var suivantes = 0
            var k = rang + 1
            while k < lignes.count && lignes[k].sorte == .priere {
                suivantes += 1
                k += 1
            }
            #expect(sujet.sorte == .sujet)
            #expect(sujet.compte == Libelle("tefilot_count", .entier(suivantes)))
            #expect(sujet.route == nil)
            #expect(sujet.image == nil)
            rang = k
        }
        let zivug = try #require(lignes.first { $0.id == "sujet:zivug" })
        #expect(zivug.compte == Libelle("tefilot_count", .entier(3)))
        #expect(zivug.sujet == Libelle("tefila_zivug"))
        let compte = try #require(zivug.compte)
        let texte = try Traducteur(catalogue: Fichiers.catalogue(), langue: "fr").texte(compte)
        #expect(texte == "3 prières")
    }

    @Test func chaquePriereOuvreSonEntreeDeLaBibliotheque() async throws {
        let modele = await Self.modele()
        let ligne = try #require(modele.lignes.first { $0.id == "priere:src-lt-hitbodedut" })
        #expect(ligne.sorte == .priere)
        #expect(ligne.sujet == Libelle("tefila_hitbodedut"))
        let bibliotheque = try await Self.contenus.bibliotheque()
        let source = try #require(TefilotRules.prieres(bibliotheque).first { $0.id == "src-lt-hitbodedut" })
        #expect(ligne.titre == source.titreHe)
        #expect(ligne.reference == "Likoutei Tefilot II, 22")
        #expect(ligne.avertissement == nil)
        #expect(ligne.image == "char_torah")
        #expect(ligne.route == .entree("src-lt-hitbodedut"))
        #expect(ligne.compte == nil)
    }

    @Test func laMiseEnGardeQuandLaLeconTraiteDUnAutreSujet() async throws {
        let modele = await Self.modele()
        let prieres = modele.lignes.filter { $0.sorte == .priere }
        let prevenues = prieres.filter { $0.avertissement != nil }.map { $0.id }
        #expect(prevenues == ["priere:src-lt-brit", "priere:src-lt-geula", "priere:src-lt-geula-2", "priere:src-lt-zivug-2",
                              "priere:src-lt-refua", "priere:src-lt-refua-2"])
        let refua = try #require(prieres.first { $0.id == "priere:src-lt-refua" })
        #expect(refua.avertissement == Libelle("tefilot_warning"))
    }

    @Test func laReferenceSuitLaLangueDeLApp() async throws {
        let hebreu = await Self.modele(langue: "he")
        let he = try #require(hebreu.lignes.first { $0.id == "priere:src-lt-hitbodedut" })
        #expect(he.reference == "ליקוטי תפילות ב, " + Reference.lettres(22))
        let anglais = await Self.modele(langue: "en")
        let en = try #require(anglais.lignes.first { $0.id == "priere:src-lt-hitbodedut" })
        #expect(en.reference == "Likutei Tefilot II, 22")
    }

    @Test func unSujetSansPriereNAucuneLigneEtUnArticleNEstPasUnePriere() async {
        let modele = await Self.modele(contenus: Self.contenusEcrits(Self.petite))
        #expect(modele.etat == .pret)
        let ids = modele.lignes.map { $0.id }
        // La joie avant la guérison, l'ordre des sujets ; l'article et la prière au sujet inconnu n'y sont pas.
        #expect(ids == ["sujet:simcha", "priere:s1", "sujet:refua", "priere:r1"])
        let avertis = modele.lignes.map { $0.avertissement }
        #expect(avertis == [nil, nil, nil, Libelle("tefilot_warning")])
    }

    @Test func uneBibliothequeIllisibleNeMontreRien() async {
        let modele = await Self.modele(contenus: ContenusApp(lecteur: { _ in nil }))
        #expect(modele.etat == .erreur)
        #expect(modele.lignes.isEmpty)
    }
}
