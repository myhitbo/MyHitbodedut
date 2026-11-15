import Foundation
import Testing
@testable import Coeur

/// Le cas de WidgetTest d'Android qui porte sur WidgetTaille (« la version suit la place donnée ») ; ce
/// qu'il lit du fichier de configuration de la vignette et de StreakWidget.kt reste à Android, et
/// reviendra avec le widget d'iOS. Rejoue aussi `interface_b.json` : les trois versions et la version
/// choisie pour chaque place d'une grille (bornes, NaN, infinis, zéro négatif).
@Suite("WidgetTaille")
struct WidgetTailleTests {

    private struct Fichier: Decodable {
        let widgetTailles: Tailles
    }

    private struct Tailles: Decodable {
        let entrees: [Entree]
        let pour: [Choix]
    }

    private struct Entree: Decodable {
        let nom: String
        let largeurMin: Double
        let hauteurMin: Double
        let largeurType: Double
        let hauteurType: Double
    }

    /// [bits de la largeur, bits de la hauteur, version].
    private struct Choix: Decodable {
        let largeur: Float
        let hauteur: Float
        let nom: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            let bitsLargeur = try c.decode(Int32.self)
            let bitsHauteur = try c.decode(Int32.self)
            largeur = Float(bitPattern: UInt32(bitPattern: bitsLargeur))
            hauteur = Float(bitPattern: UInt32(bitPattern: bitsHauteur))
            nom = try c.decode(String.self)
        }
    }

    private func nom(_ t: WidgetTaille) -> String { String(describing: t).uppercased() }

    /// Une case, la taille habituelle, une grande place (demande du 28/09).
    @Test func laVersionSuitLaPlaceDonnee() {
        let petite = WidgetTaille.pour(largeur: 70, hauteur: 70)
        #expect(petite == .petite)
        let moyenne = WidgetTaille.pour(largeur: 250, hauteur: 150)
        #expect(moyenne == .moyenne)
        let grande = WidgetTaille.pour(largeur: 320, hauteur: 300)
        #expect(grande == .grande)
        let rien = WidgetTaille.pour(largeur: 0, hauteur: 0)
        #expect(rien == .petite)
        // La place ordinaire de chaque version la redonne bien.
        for t in WidgetTaille.allCases {
            let redonnee = WidgetTaille.pour(largeur: t.largeurType, hauteur: t.hauteurType)
            #expect(redonnee == t, "\(t)")
        }
    }

    @Test func lesVersionsRepondentCommeAndroid() throws {
        let donnees = try Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_b.json")
        let v = try JSONDecoder().decode(Fichier.self, from: donnees).widgetTailles
        let toutes = WidgetTaille.allCases
        #expect(toutes.count == v.entrees.count)
        for (rang, e) in v.entrees.enumerated() where rang < toutes.count {
            let t = toutes[rang]
            #expect(nom(t) == e.nom, "rang \(rang)")
            #expect(t.largeurMin == Float(e.largeurMin), "\(e.nom)")
            #expect(t.hauteurMin == Float(e.hauteurMin), "\(e.nom)")
            #expect(t.largeurType == Float(e.largeurType), "\(e.nom)")
            #expect(t.hauteurType == Float(e.hauteurType), "\(e.nom)")
        }
        #expect(v.pour.count == 400)
        for c in v.pour {
            let t = WidgetTaille.pour(largeur: c.largeur, hauteur: c.hauteur)
            #expect(nom(t) == c.nom, "pour(\(c.largeur), \(c.hauteur))")
        }
    }
}
