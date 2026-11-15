import Foundation
import Testing
@testable import Coeur

/// ParcoursTest d'Android, porté : « Mon parcours » (proposition 6, 19/10), les chiffres, les sujets
/// fréquents, l'humeur. Puis tout `Tests/Vecteurs/parcours.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursParcours.kt). Reste à Android le troisième cas, qui lit le layout de
/// l'accueil (le bouton qui ouvre la page, dans les deux orientations).
@Suite("Parcours")
struct ParcoursTests {

    @Test func leBilanCompteLesJoursFaitsLeTempsEtLesSujets() {
        let jours = [
            Journee(minutes: 20, note: "", themes: ["famille", "parnassa"]),
            Journee(minutes: 10, note: "", themes: ["famille"]),
            Journee(minutes: 0, note: "une note", themes: [], noteSeule: true),
        ]
        let b = Parcours.bilan(jours)
        let faits = b.jours
        #expect(faits == 2)
        let minutes = b.minutes
        #expect(minutes == 30)
        let moyenne = b.moyenne
        #expect(moyenne == 15)
        let sujets = b.sujets
        let attendus = [ThemeRules.Frequence(.famille, 2), ThemeRules.Frequence(.parnassa, 1)]
        #expect(sujets == attendus)
        let vide = Parcours.bilan([Journee]()).moyenne
        #expect(vide == 0)
    }

    @Test func lHumeurMoyenneNeCompteQueLesJoursNotesAvantEtApres() {
        let seul = Parcours.humeur([JournalPlus.Plus(avant: 2)])
        #expect(seul == nil)
        let h = Parcours.humeur([JournalPlus.Plus(avant: 2, apres: 4), JournalPlus.Plus(avant: 2, apres: 4),
                                 JournalPlus.Plus(apres: 5)])
        let attendue = Parcours.Humeur(avant: 2, apres: 4, jours: 2)
        #expect(h == attendue)
    }

    // MARK: Les vecteurs de la JVM

    /// [minutes, note seule, sujets]
    private struct JourneeV: Decodable {
        let minutes: Int
        let noteSeule: Bool
        let themes: [String]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            minutes = try c.decode(Int.self)
            noteSeule = try c.decode(Bool.self)
            themes = try c.decode([String].self)
        }
    }

    /// [clé du sujet, nombre]
    private struct SujetV: Decodable {
        let cle: String
        let nombre: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            cle = try c.decode(String.self)
            nombre = try c.decode(Int.self)
        }
    }

    private struct BilanV: Decodable {
        let nom: String
        let jours: [JourneeV]
        let faits: Int
        let minutes: Int
        let moyenne: Int
        let sujets: [SujetV]
    }

    private struct HumeurV: Decodable {
        let nom: String
        /// [avant, après] de chaque jour.
        let plus: [[Int]]
        /// [avant, après, jours], null quand aucun jour n'a ses deux humeurs.
        let humeur: [Int]?
    }

    private struct Vecteurs: Decodable {
        let bilans: [BilanV]
        let humeurs: [HumeurV]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/parcours.json"))
    }

    @Test func lesBilansCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.bilans.count
        #expect(nombre > 60)
        for cas in v.bilans {
            let jours = cas.jours.map { Journee(minutes: $0.minutes, note: "", themes: $0.themes, noteSeule: $0.noteSeule) }
            let b = Parcours.bilan(jours)
            let faits = b.jours
            #expect(faits == cas.faits, "\(cas.nom) : jours")
            let minutes = b.minutes
            #expect(minutes == cas.minutes, "\(cas.nom) : minutes")
            let moyenne = b.moyenne
            #expect(moyenne == cas.moyenne, "\(cas.nom) : moyenne")
            var attendus: [ThemeRules.Frequence] = []
            for s in cas.sujets {
                let theme = try #require(Theme(rawValue: s.cle), "\(cas.nom) : sujet inconnu \(s.cle)")
                attendus.append(ThemeRules.Frequence(theme, s.nombre))
            }
            let sujets = b.sujets
            #expect(sujets == attendus, "\(cas.nom) : sujets")
        }
    }

    @Test func lesHumeursCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.humeurs.count
        #expect(nombre > 40)
        for cas in v.humeurs {
            var plus: [JournalPlus.Plus] = []
            for paire in cas.plus {
                let complete = paire.count == 2
                #expect(complete, "\(cas.nom) : \(paire)")
                if complete { plus.append(JournalPlus.Plus(avant: paire[0], apres: paire[1])) }
            }
            let h = Parcours.humeur(plus)
            if let attendu = cas.humeur {
                let complet = attendu.count == 3
                #expect(complet, "\(cas.nom) : \(attendu)")
                if !complet { continue }
                let humeur = Parcours.Humeur(avant: attendu[0], apres: attendu[1], jours: attendu[2])
                #expect(h == humeur, "\(cas.nom)")
            } else {
                #expect(h == nil, "\(cas.nom)")
            }
        }
    }
}
