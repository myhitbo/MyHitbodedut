import Foundation
import Testing
@testable import Coeur

/// SourceDuJourTest d'Android, porté ; seule sa dernière vérification (MainActivity.kt appelle
/// `SourceDuJour.carte(`) lit le code d'un écran et reste à Android. Puis tout
/// `Tests/Vecteurs/source_du_jour.json` (tools/vecteurs_ios/VecteursSourceDuJour.kt) : les candidats
/// de la bibliothèque livrée, le paragraphe de chaque jour de 2025 à 2027 et de jours lointains,
/// l'extrait de chaque candidat pour vingt-trois bornes, une bibliothèque écrite à la main, une
/// bibliothèque sans candidat, et des extraits de textes écrits à la main pour chaque borne.
@Suite("SourceDuJour")
struct SourceDuJourTests {

    /// Une source et l'indice du paragraphe choisi parmi ses paragraphes (`indexOf`, −1 s'il n'y est pas).
    private struct Ici: Equatable {
        let id: String
        let paragraphe: Int
    }

    private func lireBibliotheque() throws -> Bibliotheque {
        try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
    }

    /// `indexOf` de Kotlin : le premier paragraphe aux mêmes unités UTF-16.
    private func indice(_ texte: String, dans paragraphes: [String]) -> Int {
        for (i, paragraphe) in paragraphes.enumerated() where paragraphe.egalUnites(texte) {
            return i
        }
        return -1
    }

    /// L'indice d'une pensée parmi les candidats (la première de même source, de même texte et de même rang dans
    /// sa source, l'égalité de la data class depuis le 13/11), ou nil.
    private func indice(_ pensee: SourceDuJour.Pensee?, parmi candidats: [SourceDuJour.Pensee]) -> Int? {
        guard let pensee else { return nil }
        for (i, candidat) in candidats.enumerated()
        where candidat.source.id == pensee.source.id && candidat.texte.egalUnites(pensee.texte) && candidat.indice == pensee.indice {
            return i
        }
        return -1
    }

    private func ici(_ library: Bibliotheque, _ jour: String) throws -> Ici {
        let pensee: SourceDuJour.Pensee = try #require(SourceDuJour.choix(library, JourCivil.du(jour)), "aucun paragraphe le \(jour)")
        return Ici(id: pensee.source.id, paragraphe: indice(pensee.texte, dans: LibraryRules.paragraphs(library, pensee.source)))
    }

    // MARK: SourceDuJourTest

    @Test func leMemeParagrapheQueLeWebLeMemeJour() throws {
        let library = try lireBibliotheque()
        let premier = try ici(library, "2026-10-19")
        let attenduPremier = Ici(id: "src-lm2-25", paragraphe: 9)
        #expect(premier == attenduPremier)
        let deuxieme = try ici(library, "2026-10-20")
        let attenduDeuxieme = Ici(id: "src-lt-zera", paragraphe: 1)
        #expect(deuxieme == attenduDeuxieme)
        let troisieme = try ici(library, "2027-01-01")
        let attenduTroisieme = Ici(id: "src-lt-zera", paragraphe: 2)
        #expect(troisieme == attenduTroisieme)
    }

    @Test func seulesLesSourcesJamaisLesArticlesEtAssezLongues() throws {
        let library = try lireBibliotheque()
        let c = SourceDuJour.candidats(library)
        let nombre = c.count
        #expect(nombre > 50)
        for pensee in c {
            let longueur = pensee.texte.utf16.count
            #expect(longueur >= SourceDuJour.min, "\(pensee.source.id) : \(longueur) unités")
            // Ce que le nom du test promet : chaque candidat vient d'une entrée « source ».
            var estUneSource = false
            if let entree = library.entree(pensee.source.id), case .source = entree { estUneSource = true }
            #expect(estUneSource, "\(pensee.source.id) n'est pas une source")
        }
        let texte = String(repeating: "א", count: 10) + " " + String(repeating: "ב", count: 400)
        let extrait = SourceDuJour.extrait(texte)
        let finit = extrait.finitParUnites("…")
        #expect(finit)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        let min: Int
        let testsKotlin: TestsKotlin
        let livre: Livre
        let manuelle: Manuelle
        let vide: Manuelle
        let extraits: [ExtraitManuel]
    }

    private struct TestsKotlin: Decodable {
        let ici: [IciVecteur]
        let nombreDeCandidats: Int
        let tousAssezLongs: Bool
        let sources: Bool
    }

    private struct IciVecteur: Decodable {
        let jour: String
        let id: String
        let paragraphe: Int
    }

    private struct Livre: Decodable {
        let candidats: [Candidat]
        let premierJour: String
        let choix: [Int?]
        let lointains: [Lointain]
        let bornes: [Int]
        let extraits: [ExtraitsDuCandidat]
        let coupes320: [Coupe]
    }

    private struct Candidat: Decodable {
        let id: String
        let paragraphe: Int
        let longueur: Int
        let empreinte: Int
    }

    private struct Lointain: Decodable {
        let jour: String
        let epoch: Int
        let indice: Int?
    }

    /// [longueur en unités UTF-16, String.hashCode] de l'extrait.
    private struct ExtraitsDuCandidat: Decodable {
        let defaut: [Int]
        let parBorne: [[Int]]
    }

    private struct Coupe: Decodable {
        let indice: Int
        let extrait: String
    }

    private struct Manuelle: Decodable {
        let document: String
        let candidats: [CandidatManuel]
        let choix: [ChoixManuel]
    }

    private struct CandidatManuel: Decodable {
        let id: String
        let texte: String
    }

    private struct ChoixManuel: Decodable {
        let jour: String
        let indice: Int?
    }

    /// Deux formes : un texte et une borne (nil : la borne par défaut) avec son extrait ; ou un texte, son
    /// extrait par défaut et l'extrait pour chaque borne de 0 à sa longueur + 2 (nil là où la coupe
    /// tomberait au milieu d'une paire de substitution).
    private struct ExtraitManuel: Decodable {
        let texte: String
        let borne: Int?
        let extrait: String?
        let defaut: String?
        let parBorne: [String?]?
    }

    private func lireVecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/source_du_jour.json"))
    }

    /// [longueur, empreinte] d'un texte, comme le générateur les écrit.
    private func mesure(_ texte: String) -> [Int] {
        [texte.utf16.count, Int(Kotlin.hashCode(texte))]
    }

    @Test func lesCasDuTestKotlinTelsQueLaJvmLesRend() throws {
        let v = try lireVecteurs()
        let library = try lireBibliotheque()
        let seuil = SourceDuJour.min
        #expect(seuil == v.min)
        for cas in v.testsKotlin.ici {
            let obtenu = try ici(library, cas.jour)
            let attendu = Ici(id: cas.id, paragraphe: cas.paragraphe)
            #expect(obtenu == attendu, "\(cas.jour)")
        }
        let c = SourceDuJour.candidats(library)
        let nombre = c.count
        #expect(nombre == v.testsKotlin.nombreDeCandidats)
        #expect(v.testsKotlin.tousAssezLongs)
        #expect(v.testsKotlin.sources)
    }

    @Test func lesCandidatsDeLaBibliothequeLivree() throws {
        let v = try lireVecteurs()
        let library = try lireBibliotheque()
        let c = SourceDuJour.candidats(library)
        let nombre = c.count
        #expect(nombre == v.livre.candidats.count)
        for (i, attendu) in v.livre.candidats.enumerated() where i < c.count {
            let pensee = c[i]
            let id = pensee.source.id
            #expect(id == attendu.id, "candidat \(i)")
            let paragraphe = indice(pensee.texte, dans: LibraryRules.paragraphs(library, pensee.source))
            #expect(paragraphe == attendu.paragraphe, "candidat \(i) (\(id))")
            let obtenue = mesure(pensee.texte)
            let attendue = [attendu.longueur, attendu.empreinte]
            #expect(obtenue == attendue, "candidat \(i) (\(id))")
        }
    }

    @Test func leParagrapheDeChaqueJourDeTroisAnnees() throws {
        let v = try lireVecteurs()
        let library = try lireBibliotheque()
        let c = SourceDuJour.candidats(library)
        let depart = JourCivil.du(v.livre.premierJour)
        for (i, attendu) in v.livre.choix.enumerated() {
            let jour = depart.plus(jours: i)
            let obtenu = indice(SourceDuJour.choix(library, jour), parmi: c)
            #expect(obtenu == attendu, "\(jour.iso)")
        }
        for cas in v.livre.lointains {
            let jour = JourCivil.du(cas.jour)
            let epoch = jour.jourJulien - 2_440_588
            #expect(epoch == cas.epoch, "toEpochDay() du \(cas.jour)")
            let obtenu = indice(SourceDuJour.choix(library, jour), parmi: c)
            #expect(obtenu == cas.indice, "\(cas.jour)")
        }
    }

    @Test func lExtraitDeChaqueCandidatPourChaqueBorne() throws {
        let v = try lireVecteurs()
        let library = try lireBibliotheque()
        let c = SourceDuJour.candidats(library)
        let nombre = c.count
        #expect(nombre == v.livre.extraits.count)
        for (i, attendus) in v.livre.extraits.enumerated() where i < c.count {
            let texte = c[i].texte
            let defaut = mesure(SourceDuJour.extrait(texte))
            #expect(defaut == attendus.defaut, "candidat \(i), borne par défaut")
            let lignes = attendus.parBorne.count
            #expect(lignes == v.livre.bornes.count, "candidat \(i)")
            for (j, borne) in v.livre.bornes.enumerated() where j < attendus.parBorne.count {
                let obtenu = mesure(SourceDuJour.extrait(texte, max: borne))
                let attendu = attendus.parBorne[j]
                #expect(obtenu == attendu, "candidat \(i), borne \(borne)")
            }
        }
        for coupe in v.livre.coupes320 {
            let present = coupe.indice < c.count
            #expect(present, "candidat \(coupe.indice) absent")
            guard present else { continue }
            let obtenu = SourceDuJour.extrait(c[coupe.indice].texte, max: 320)
            let egal = obtenu.egalUnites(coupe.extrait)
            #expect(egal, "candidat \(coupe.indice) : « \(obtenu) » au lieu de « \(coupe.extrait) »")
        }
    }

    /// Une bibliothèque écrite à la main, décodée par Swift telle que LibraryLoader l'a lue.
    private func rejoue(_ manuelle: Manuelle, _ nom: String) throws {
        let library = try JSONDecoder().decode(Bibliotheque.self, from: Data(manuelle.document.utf8))
        let c = SourceDuJour.candidats(library)
        let nombre = c.count
        #expect(nombre == manuelle.candidats.count, "\(nom) : nombre de candidats")
        for (i, attendu) in manuelle.candidats.enumerated() where i < c.count {
            let id = c[i].source.id
            #expect(id == attendu.id, "\(nom), candidat \(i)")
            let egal = c[i].texte.egalUnites(attendu.texte)
            #expect(egal, "\(nom), candidat \(i) (\(id))")
        }
        for cas in manuelle.choix {
            let obtenu = indice(SourceDuJour.choix(library, JourCivil.du(cas.jour)), parmi: c)
            #expect(obtenu == cas.indice, "\(nom), \(cas.jour)")
        }
    }

    @Test func uneBibliothequeEcriteALaMain() throws {
        let v = try lireVecteurs()
        try rejoue(v.manuelle, "manuelle")
        try rejoue(v.vide, "vide")
        let vide = try JSONDecoder().decode(Bibliotheque.self, from: Data(v.vide.document.utf8))
        let aucun = SourceDuJour.choix(vide, JourCivil.du("2026-10-19"))
        #expect(aucun == nil)
    }

    @Test func desExtraitsEcritsALaMain() throws {
        let v = try lireVecteurs()
        let nombre = v.extraits.count
        #expect(nombre > 4)
        for cas in v.extraits {
            if let parBorne = cas.parBorne {
                let defaut = SourceDuJour.extrait(cas.texte)
                let attenduParDefaut = try #require(cas.defaut, "« \(cas.texte) » : extrait par défaut absent")
                let egalParDefaut = defaut.egalUnites(attenduParDefaut)
                #expect(egalParDefaut, "« \(cas.texte) », borne par défaut : « \(defaut) »")
                for (borne, attendu) in parBorne.enumerated() {
                    guard let attendu else { continue }
                    let obtenu = SourceDuJour.extrait(cas.texte, max: borne)
                    let egal = obtenu.egalUnites(attendu)
                    #expect(egal, "« \(cas.texte) », borne \(borne) : « \(obtenu) » au lieu de « \(attendu) »")
                }
            } else {
                let attendu = try #require(cas.extrait, "« \(cas.texte) » : extrait absent")
                let obtenu = cas.borne.map { SourceDuJour.extrait(cas.texte, max: $0) } ?? SourceDuJour.extrait(cas.texte)
                let egal = obtenu.egalUnites(attendu)
                let nomBorne = cas.borne.map { "\($0)" } ?? "par défaut"
                #expect(egal, "borne \(nomBorne) : « \(obtenu) » au lieu de « \(attendu) »")
            }
        }
    }
}
