import Foundation
import Testing
@testable import Coeur

/// TefilotTest d'Android : les prières de Likoutei Tefilot, au moins deux par sujet demandé.
///
/// Ce que ce test garde : qu'elles soient toutes là, qu'aucune ne soit vide, que chacune renvoie à sa prière et à
/// sa leçon, et surtout que la règle de vocalisation s'applique : l'édition 2021 n'a pas de licence déclarée, donc
/// c'est la forme sans nikkoud qui doit s'afficher. Les lignes de l'écran (TefilotRules) sont rejouées devant la
/// JVM dans TextesVecteursTests.
@Suite("Tefilot")
struct TefilotTests {

    private let sujets = ["hitbodedut", "simcha", "uman", "kdusha", "zera", "parnassa", "brit", "geula", "zivug", "refua"]

    private func lireBibliotheque() throws -> Bibliotheque {
        try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
    }

    /// Les sources de la sous-section, lues ici sans passer par la règle.
    private func lues(_ bibliotheque: Bibliotheque) -> [SourceBibliotheque] {
        (bibliotheque.sousSection("tefilot-lt")?.entrees ?? []).compactMap { entree -> SourceBibliotheque? in
            if case .source(let s) = entree { return s }
            return nil
        }
    }

    private func du(_ sujet: String, _ tefilot: [SourceBibliotheque]) -> [SourceBibliotheque] {
        tefilot.filter { $0.sujet?.egalUnites(sujet) ?? false }
    }

    /// `==` de deux listes de Kotlin : unité par unité.
    private func memes(_ a: [String], _ b: [String]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0.egalUnites($1) }
    }

    @Test func lesSujetsSontCeuxDeLEcran() {
        let cles = SujetTefila.allCases.map(\.cle)
        #expect(cles == sujets)
    }

    @Test func lesDixSujetsDemandesOntChacunAuMoinsDeuxPrieres() throws {
        let tefilot = try lues(lireBibliotheque())
        for sujet in sujets {
            let nombre = du(sujet, tefilot).count
            #expect(nombre >= 2, "« \(sujet) » : il faut au moins deux prières, il y en a \(nombre)")
            for id in ["src-lt-\(sujet)", "src-lt-\(sujet)-2"] {
                let presente = tefilot.contains { $0.id == id }
                #expect(presente, "entrée manquante : \(id)")
            }
        }
        let rangees = tefilot.filter { t in sujets.contains { t.sujet?.egalUnites($0) ?? false } }.count
        #expect(tefilot.count == rangees, "des prières traînent hors des dix sujets")
    }

    /// Deux prières sur le même sujet doivent être deux prières différentes. Sans ce test, dupliquer la première
    /// passerait inaperçu.
    @Test func lesPrieresDUnMemeSujetSontToutesDifferentes() throws {
        let tefilot = try lues(lireBibliotheque())
        for sujet in sujets {
            let siennes = du(sujet, tefilot)
            let refs = Set(siennes.map { Array($0.ref.utf16) })
            let textes = Set(siennes.map { $0.paragraphes.map { Array($0.utf16) } })
            #expect(siennes.count == refs.count, "« \(sujet) » : deux prières partagent une référence")
            #expect(siennes.count == textes.count, "« \(sujet) » : deux prières partagent leur texte")
        }
    }

    /// Le constat honnête : la leçon annoncée porte-t-elle sur le sujet ? Trois réponses seulement, et aucune entrée
    /// n'a le droit de se taire.
    @Test func chaquePriereDitSiSaLeconPorteSurLeSujet() throws {
        let tefilot = try lues(lireBibliotheque())
        #expect(tefilot.count >= sujets.count * 2, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            let constat = t.leconSurLeSujet ?? "null"
            let connu = ["oui", "partiel", "non"].contains { constat.egalUnites($0) }
            #expect(connu, "\(t.id) : constat manquant ou hors barème (« \(constat) »)")
        }
        let unNon = tefilot.contains { TefilotRules.prevenir($0) }
        #expect(unNon, "aucune entrée ne dit « non » : le constat ne distingue plus rien")
    }

    @Test func aucunePriereNEstVideNiTronquee() throws {
        let tefilot = try lues(lireBibliotheque())
        #expect(tefilot.count >= sujets.count * 2, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            #expect(!t.paragraphes.isEmpty, "\(t.id) : aucun paragraphe")
            for (i, p) in t.paragraphes.enumerated() {
                #expect(!p.estBlanc, "\(t.id) paragraphe \(i) vide")
                #expect(!p.utf16.contains(0x3C), "\(t.id) paragraphe \(i) : balise HTML restée")
                #expect(!p.utf16.contains(0x5B), "\(t.id) paragraphe \(i) : en-tête d'éditeur restée")
            }
        }
    }

    @Test func chaquePriereDitDOuElleVient() throws {
        let tefilot = try lues(lireBibliotheque())
        #expect(tefilot.count >= sujets.count * 2, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            #expect(!t.titreHe.estBlanc, "\(t.id) : titre hébreu manquant")
            #expect(t.ref.commenceParUnites("Likoutei Tefilot "),
                    "\(t.id) : la référence doit nommer Likoutei Tefilot, pas « \(t.ref) »")
            #expect(t.edition == "lt", "\(t.id) : mauvaise édition")
            #expect(t.statutVerif == "verifie_texte", "\(t.id) : texte non vérifié")
        }
    }

    /// Le cœur : la licence de l'édition 2021 n'est pas déclarée, donc sa vocalisation ne se reprend pas. Si
    /// quelqu'un passe `lt` à nikkoud_ok = true, ce test tombe.
    @Test func cEstLaFormeSansNikkoudQuiSAffiche() throws {
        let bibliotheque = try lireBibliotheque()
        let edition = try #require(bibliotheque.editions["lt"], "l'édition lt est absente du fichier")
        #expect(!edition.nikkoudOk, "licence non déclarée : nikkoud_ok ne peut pas valoir vrai")
        let tefilot = lues(bibliotheque)
        #expect(tefilot.count >= sujets.count * 2, "rien à vérifier : la sous-section est vide")
        for t in tefilot {
            #expect(t.paragraphes.count == t.paragraphesSansNikkoud.count,
                    "\(t.id) : il faut autant de paragraphes dans les deux formes")
            let affiches = LibraryRules.paragraphes(bibliotheque, t)
            let sansNikkoud = memes(affiches, t.paragraphesSansNikkoud)
            #expect(sansNikkoud, "\(t.id) : c'est la forme sans nikkoud qui doit sortir")
            for p in affiches {
                let vocalise = p.utf16.contains { (0x0591...0x05BD).contains($0) || (0x05BF...0x05C7).contains($0) }
                #expect(!vocalise, "\(t.id) : un signe de vocalisation a survécu dans « \(p.premieresUnites(40)) »")
            }
        }
    }

    /// Le maqqef (U+05BE) est à l'intérieur de la plage des signes hébreux mais n'est pas un signe de vocalisation :
    /// le retirer soude les mots. L'erreur a déjà été commise une fois, elle ne se refera pas en silence.
    @Test func leMaqqefSurvitAuRetraitDuNikkoud() throws {
        let tefilot = try lues(lireBibliotheque())
        func maqqefs(_ paragraphes: [String]) -> Int {
            paragraphes.reduce(0) { somme, p in somme + p.utf16.filter { $0 == 0x05BE }.count }
        }
        let avec = tefilot.reduce(0) { $0 + maqqefs($1.paragraphes) }
        let sans = tefilot.reduce(0) { $0 + maqqefs($1.paragraphesSansNikkoud) }
        #expect(avec > 0, "aucun maqqef dans le corpus : le test ne prouve rien")
        #expect(avec == sans, "des maqqef ont été perdus en retirant le nikkoud")
    }
}
