import Foundation
import Testing
@testable import Coeur

/// PaletteTest d'Android, porté sur `palettes.json`. Le choix est limité à des palettes pour une
/// raison que ce test tient : chaque fond combiné à chaque couleur de boutons reste lisible, de
/// jour comme de nuit. Les seuils sont ceux de la palette verte d'origine, qui les passe tous.
///
/// Ici, chaque combinaison est vérifiée telle que l'export l'a résolue, donc telle que l'app
/// l'affichera. Restent à Android : le thème de base, les attributs et les écrans qui figeraient
/// une couleur ; leur pendant SwiftUI viendra avec les composants (tâche 14, macOS).
@Suite("Palette")
struct PaletteTests {

    private func palettes() throws -> Palettes { try Palettes.lire(Depot.contenu("palettes.json")) }

    @Test func chaqueCombinaisonResteLisibleDeJourCommeDeNuit() throws {
        let toutes = try palettes()
        var fautes: [String] = []
        func exige(_ nom: String, _ encre: Couleur, _ fond: Couleur, _ seuil: Double) {
            let r = Couleur.contraste(encre, fond)
            if r < seuil { fautes.append("\(nom) : \((r * 100).rounded() / 100) < \(seuil)") }
        }
        for nuit in [false, true] {
            for fond in Fond.allCases {
                for accent in Accent.allCases {
                    let p = toutes.palette(fond: fond, accent: accent, nuit: nuit)
                    let nom = "\(fond.rawValue)/\(accent.rawValue) \(nuit ? "nuit" : "jour")"
                    exige("\(nom), bouton", p[.onBrand], p[.brand], 4.5)
                    exige("\(nom), plaque", p[.onPlate], p[.mint], 4.5)
                    exige("\(nom), plaque douce", p[.onPlate], p[.stageSoft], 4.5)
                    exige("\(nom), bandeau", p[.mint], p[.brandDark], 4.5)
                    exige("\(nom), blanc sur bandeau", .blanc, p[.brandDark], 4.5)
                    exige("\(nom), jour fait", .blanc, p[.dayDone], 4.5)
                    exige("\(nom), titre sur carte", p[.brand], p[.card], 4.5)
                    exige("\(nom), titre sur fond", p[.brand], p[.paper], 4.5)
                    for dessous in [Jeton.card, .paper, .dayTodo] {
                        exige("\(nom), encre sur \(dessous.rawValue)", p[.ink], p[dessous], 7.0)
                    }
                    // 4,5 : le seuil AA du texte courant. À 4,0, le gris de la palette verte
                    // passait à 4,03 (revue du 29/09).
                    for dessous in [Jeton.card, .paper] {
                        exige("\(nom), texte secondaire sur \(dessous.rawValue)", p[.muted], p[dessous], 4.5)
                    }
                }
            }
        }
        #expect(fautes.isEmpty, "contrastes insuffisants :\n\(fautes.joined(separator: "\n"))")
    }

    @Test func lesPlaquesClairesNeBasculentPasLaNuit() throws {
        let toutes = try palettes()
        for fond in Fond.allCases {
            for accent in Accent.allCases {
                let jour = toutes.palette(fond: fond, accent: accent, nuit: false)
                let nuit = toutes.palette(fond: fond, accent: accent, nuit: true)
                for jeton in Jeton.fixes {
                    #expect(jour[jeton] == nuit[jeton], "\(fond.rawValue)/\(accent.rawValue) : « \(jeton.rawValue) » change la nuit")
                }
            }
        }
    }

    /// L'accent ne touche qu'aux jetons de l'accent, le fond qu'aux siens : changer l'un ne
    /// déplace pas l'autre.
    @Test func lAccentEtLeFondNeSeMelentPas() throws {
        let toutes = try palettes()
        for nuit in [false, true] {
            for fond in Fond.allCases {
                for accent in Accent.allCases {
                    let p = toutes.palette(fond: fond, accent: accent, nuit: nuit)
                    let memeFond = toutes.palette(fond: fond, accent: .vert, nuit: nuit)
                    let memeAccent = toutes.palette(fond: .vert, accent: accent, nuit: nuit)
                    for jeton in Jeton.allCases {
                        let attendu = jeton.deLAccent ? memeAccent[jeton] : memeFond[jeton]
                        #expect(p[jeton] == attendu, "\(fond.rawValue)/\(accent.rawValue) : \(jeton.rawValue)")
                    }
                }
            }
        }
    }

    /// Une palette incomplète n'est pas lue : l'app n'a jamais à deviner une couleur.
    @Test func unFichierIncompletEstRefuse() throws {
        let brut = try JSONSerialization.jsonObject(with: Depot.contenu("palettes.json")) as? [String: Any]
        var fichier = try #require(brut)
        var modes = try #require(fichier["modes"] as? [String: Any])
        var jour = try #require(modes["jour"] as? [String: Any])
        jour.removeValue(forKey: "rose/ambre")
        modes["jour"] = jour
        fichier["modes"] = modes
        let tronque = try JSONSerialization.data(withJSONObject: fichier)
        #expect(throws: ErreurContenu.self) { try Palettes.lire(tronque) }
    }

    @Test func leContrasteEstCeluiDeWCAG() throws {
        #expect(abs(Couleur.contraste(.noir, .blanc) - 21) < 1e-9)
        #expect(Couleur.contraste(.blanc, .blanc) == 1)
        let vert = try #require(Couleur(hex: "#16775A"))
        #expect(Couleur(hex: "#FF16775A") == vert)
        #expect(vert.hex == "#16775A")
        #expect(abs(Couleur.contraste(.blanc, vert) - 5.50) < 0.01)
        #expect(Couleur(hex: "16775A") == nil && Couleur(hex: "#16775") == nil && Couleur(hex: "#16775G") == nil)
    }

    @Test func leChoixSeLitCommeSurAndroid() {
        #expect(Fond.de("sable") == Fond.sable)
        #expect(Fond.de("inconnu") == Fond.vert)
        #expect(Fond.de(nil) == Fond.vert)
        #expect(Accent.de("ambre") == Accent.ambre)
        #expect(Accent.de(nil) == Accent.vert)
        #expect(Jeton.allCases.filter(\.deLAccent).count == 7)
    }
}
