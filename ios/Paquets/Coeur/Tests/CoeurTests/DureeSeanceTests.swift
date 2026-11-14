import Foundation
import Testing
@testable import Coeur

/// DureeSeanceTest d'Android, porté : les durées proposées (28/09) et le temps saisi, puis toutes les
/// lectures de `Tests/Vecteurs/seance.json`, écrites par la JVM (tools/vecteurs_ios/VecteursSeance.kt).
/// Reste à Android `chaque choix de duree passe par la meme liste`, qui lit le code de trois écrans.
@Suite("Durée de séance")
struct DureeSeanceTests {

    @Test func lesDureesDemandeesParLeProprietaire() {
        let proposees = DureeSeance.proposees
        #expect(proposees == [5, 10, 15, 30, 60, 90])
    }

    @Test func leTempsSaisiEstBorneEntre1Et240Minutes() {
        let entreBlancs = DureeSeance.lire(" 25 ")
        #expect(entreBlancs == 25)
        let zero = DureeSeance.lire("0")
        #expect(zero == 1)
        let tropLong = DureeSeance.lire("600")
        #expect(tropLong == 240)
        let vide = DureeSeance.lire("")
        #expect(vide == nil)
        let enLettres = DureeSeance.lire("vingt")
        #expect(enLettres == nil)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let proposees: [Int]
            let min: Int
            let max: Int
        }
        /// Un texte saisi, en unités UTF-16 ; « ecrit » le donne comme on l'écrirait en Kotlin.
        struct Lecture: Decodable {
            let ecrit: String
            let unites: [UInt16]
            let lu: Int?
        }
        /// `lus[i]` : ce qu'Android lit de l'entier `premier + i` écrit par `toString`.
        struct Entiers: Decodable {
            let premier: Int
            let lus: [Int?]
        }

        let constantes: Constantes
        let lectures: [Lecture]
        let entiers: Entiers
        /// [unité, nombre lu] pour chaque unité du plan de base qui, après « 1 », laisse un nombre.
        let unitesApres: [[Int]]
        /// Les mêmes paires, l'unité étant mise devant « 1 ».
        let unitesAvant: [[Int]]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/seance.json"))
    }

    /// Le nombre lu, ou « nil », pour un message.
    private func ecrit(_ n: Int?) -> String {
        guard let n else { return "nil" }
        return String(n)
    }

    /// Les paires [unité, nombre lu], rangées par unité : nil pour une unité absente des vecteurs.
    private func parUnite(_ paires: [[Int]]) -> [Int?] {
        var lus = [Int?](repeating: nil, count: 0x10000)
        for paire in paires where paire.count == 2 && paire[0] >= 0 && paire[0] < 0x10000 {
            lus[paire[0]] = paire[1]
        }
        return lus
    }

    @Test func laListeEtLesBornesDAndroid() throws {
        let c = try vecteurs().constantes
        let proposees = DureeSeance.proposees
        #expect(proposees == c.proposees)
        let basse = DureeSeance.min
        #expect(basse == c.min)
        let haute = DureeSeance.max
        #expect(haute == c.max)
    }

    /// Chaque texte saisi, comme Android le lit : blancs de Kotlin rognés ou non, signes, zéros de tête,
    /// débordements d'un `Int` de Kotlin, chiffres des autres écritures, hébreu vocalisé.
    @Test func chaqueTexteSaisiSeLitCommeSurAndroid() throws {
        let lectures = try vecteurs().lectures
        let nombre = lectures.count
        #expect(nombre > 100)
        for l in lectures {
            let texte = Unites.texte(l.unites)
            let relues = Array(texte.utf16)
            #expect(relues == l.unites, "« \(l.ecrit) » : le texte doit garder ses unités")
            let lu = DureeSeance.lire(texte)
            #expect(lu == l.lu, "lire(« \(l.ecrit) ») : \(ecrit(lu)), Android \(ecrit(l.lu))")
        }
    }

    /// Chaque entier de −300 à 500, écrit comme le fait `toString`.
    @Test func chaqueEntierEcritSeLitCommeSurAndroid() throws {
        let entiers = try vecteurs().entiers
        let nombre = entiers.lus.count
        #expect(nombre > 0)
        for (rang, attendu) in entiers.lus.enumerated() {
            let n = entiers.premier + rang
            let lu = DureeSeance.lire(String(n))
            #expect(lu == attendu, "lire(« \(n) ») : \(ecrit(lu)), Android \(ecrit(attendu))")
        }
    }

    /// Chaque unité du plan de base d'Unicode, après puis avant le chiffre 1 : seuls un chiffre décimal
    /// d'une écriture quelconque, un blanc de Kotlin et, devant, un signe ASCII laissent un nombre. Les
    /// moitiés de paire seules (D800 à DFFF) sont passées : une chaîne de Swift ne les porte pas (le
    /// texte serait « 1 », lu 1) ; Android n'y lit rien, ce que le test vérifie.
    @Test func chaqueUniteAvantEtApresUnChiffre() throws {
        let v = try vecteurs()
        let apres = parUnite(v.unitesApres)
        let avant = parUnite(v.unitesAvant)
        var ecarts: [String] = []
        for code in 0...0xFFFF {
            if code >= 0xD800 && code <= 0xDFFF {
                if apres[code] != nil || avant[code] != nil {
                    ecarts.append("U+\(String(code, radix: 16, uppercase: true)) : Android lit une moitié de paire")
                }
                continue
            }
            let unite = UInt16(code)
            let unPuisUnite: [UInt16] = [0x31, unite]
            let luApres = DureeSeance.lire(Unites.texte(unPuisUnite))
            if luApres != apres[code] {
                ecarts.append("« 1 » puis U+\(String(code, radix: 16, uppercase: true)) : \(ecrit(luApres)), Android \(ecrit(apres[code]))")
            }
            let unitePuisUn: [UInt16] = [unite, 0x31]
            let luAvant = DureeSeance.lire(Unites.texte(unitePuisUn))
            if luAvant != avant[code] {
                ecarts.append("U+\(String(code, radix: 16, uppercase: true)) puis « 1 » : \(ecrit(luAvant)), Android \(ecrit(avant[code]))")
            }
        }
        let nombre = ecarts.count
        let premiers = ecarts.prefix(20).joined(separator: "\n")
        #expect(nombre == 0, "\(premiers)")
    }
}
