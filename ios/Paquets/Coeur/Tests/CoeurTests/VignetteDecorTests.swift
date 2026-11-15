import Foundation
import Testing
@testable import Coeur

/// Les cas de WidgetTest d'Android qui portent sur VignetteDecor. Les couleurs lues dans colors.xml et
/// palettes.xml deviennent les jetons de `palettes.json` (day_done, brand_dark, mint) ; ce que le test
/// lit du voile (bg_widget_voile.xml) et de StreakWidget.kt reste à Android, et reviendra avec le widget
/// d'iOS. Rejoue aussi `interface_b.json` : les constantes, le mélange, l'opacité, le dégradé et le pire
/// fond de chaque palette, et la taille de l'image de fond.
@Suite("VignetteDecor")
struct VignetteDecorTests {

    private struct Fichier: Decodable {
        let vignette: Vignette
    }

    private struct Vignette: Decodable {
        let constantes: Constantes
        let melange: [[Int64]]
        let opacite: [[Int64]]
        let degrade: [Degrade]
        let pixels: [[Int64]]
    }

    private struct Constantes: Decodable {
        let departJour, departNuit, noirNuit, arcExterieur, arcInterieur: Double
        let halo, lisere, voilePanneau, voileBadge, voileAnneaux: Double
        let coteMax: Int
        let blanc, noir: UInt32
    }

    /// [jour fait, brand dark, nuit, clair, foncé, pire fond].
    private struct Degrade: Decodable {
        let jourFait, brandDark: UInt32
        let nuit: Bool
        let clair, fonce, pire: UInt32

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            jourFait = try c.decode(UInt32.self)
            brandDark = try c.decode(UInt32.self)
            nuit = try c.decode(Bool.self)
            clair = try c.decode(UInt32.self)
            fonce = try c.decode(UInt32.self)
            pire = try c.decode(UInt32.self)
        }
    }

    private func vecteurs() throws -> Vignette {
        let donnees = try Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_b.json")
        return try JSONDecoder().decode(Fichier.self, from: donnees).vignette
    }

    /// Un Float écrit par ses bits (floatToRawIntBits).
    private func flottant(_ bits: Int64) -> Float {
        Float(bitPattern: UInt32(truncatingIfNeeded: bits))
    }

    /// Une couleur ARGB écrite en entier non signé.
    private func couleur(_ n: Int64) -> UInt32 {
        UInt32(truncatingIfNeeded: n)
    }

    private func hex(_ c: UInt32) -> String {
        let s = String(c, radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, 8 - s.count)) + s
    }

    /// Le fond n'est plus une carte unie : un dégradé et deux arcs pâles. Le blanc des chiffres et le
    /// « mint » des libellés doivent s'y lire partout, pour chaque couleur des boutons (et chaque fond,
    /// qui ne change pas ces jetons), de jour comme de nuit, au seuil AA du texte courant.
    @Test func leTexteResteLisibleSurToutLeDegrade() throws {
        let palettes = try Palettes.lire(Depot.contenu("palettes.json"))
        var fautes: [String] = []
        for nuit in [false, true] {
            for fond in Fond.allCases {
                for accent in Accent.allCases {
                    let p = palettes.palette(fond: fond, accent: accent, nuit: nuit)
                    let bouts = VignetteDecor.degrade(p, nuit: nuit)
                    let pire = VignetteDecor.pireFond(p, nuit: nuit)
                    for dessous in [bouts.clair, bouts.fonce, pire] {
                        for (encre, e) in [("blanc", Couleur.blanc), ("mint", p[.mint])] {
                            let r = Couleur.contraste(e, dessous)
                            if r < 4.5 {
                                fautes.append("\(fond)/\(accent) \(nuit ? "nuit" : "jour"), \(encre) : \(Java.format(r, decimales: 2))")
                            }
                        }
                    }
                }
            }
        }
        #expect(fautes.isEmpty, "contrastes insuffisants :\n\(fautes.joined(separator: "\n"))")
    }

    /// Une image trop grande ferait refuser la vignette entière.
    @Test func leFondRestePetitEtGardeSesProportions() {
        for densite: Float in [1, 2.625, 3.5, 4] {
            for t in WidgetTaille.allCases {
                let (l, h) = VignetteDecor.pixels(largeurDp: t.largeurType, hauteurDp: t.hauteurType, densite: densite)
                #expect(l <= VignetteDecor.coteMax && h <= VignetteDecor.coteMax, "\(t) × \(densite) : \(l) × \(h)")
                let ecart = abs(t.largeurType / t.hauteurType - Float(l) / Float(h))
                #expect(ecart <= 0.02, "\(t) × \(densite) : \(l) × \(h)")
            }
        }
        let (l, h) = VignetteDecor.pixels(largeurDp: 150, hauteurDp: 75, densite: 1)
        #expect(l == 150 && h == 75)
        let blanc = VignetteDecor.melange(VignetteDecor.noir, VignetteDecor.blanc, 1)
        #expect(blanc == VignetteDecor.blanc)
        let noir = VignetteDecor.melange(VignetteDecor.noir, VignetteDecor.blanc, 0)
        #expect(noir == VignetteDecor.noir)
        let voile = VignetteDecor.opacite(VignetteDecor.blanc, Float(128) / 255)
        #expect(voile == 0x80FF_FFFF)
    }

    @Test func lesConstantesSontCellesDAndroid() throws {
        let c = try vecteurs().constantes
        #expect(VignetteDecor.departJour == Float(c.departJour))
        #expect(VignetteDecor.departNuit == Float(c.departNuit))
        #expect(VignetteDecor.noirNuit == Float(c.noirNuit))
        #expect(VignetteDecor.arcExterieur == Float(c.arcExterieur))
        #expect(VignetteDecor.arcInterieur == Float(c.arcInterieur))
        #expect(VignetteDecor.halo == Float(c.halo))
        #expect(VignetteDecor.lisere == Float(c.lisere))
        #expect(VignetteDecor.voilePanneau == Float(c.voilePanneau))
        #expect(VignetteDecor.voileBadge == Float(c.voileBadge))
        #expect(VignetteDecor.voileAnneaux == Float(c.voileAnneaux))
        #expect(VignetteDecor.coteMax == c.coteMax)
        #expect(VignetteDecor.blanc == c.blanc)
        #expect(VignetteDecor.noir == c.noir)
    }

    @Test func lesMelangesEtLesOpacitesSontCeuxDAndroid() throws {
        let v = try vecteurs()
        #expect(v.melange.count > 700)
        for cas in v.melange where cas.count == 4 {
            let (a, b, t) = (couleur(cas[0]), couleur(cas[1]), flottant(cas[2]))
            let rendu = VignetteDecor.melange(a, b, t)
            #expect(rendu == couleur(cas[3]), "melange(\(hex(a)), \(hex(b)), \(t)) : \(hex(rendu))")
        }
        #expect(v.opacite.count > 100)
        for cas in v.opacite where cas.count == 3 {
            let (c, alpha) = (couleur(cas[0]), flottant(cas[1]))
            let rendu = VignetteDecor.opacite(c, alpha)
            #expect(rendu == couleur(cas[2]), "opacite(\(hex(c)), \(alpha)) : \(hex(rendu))")
        }
    }

    @Test func lesDegradesSontCeuxDAndroid() throws {
        let v = try vecteurs()
        #expect(v.degrade.count > 90)
        for d in v.degrade {
            let bouts = VignetteDecor.degrade(jourFait: d.jourFait, brandDark: d.brandDark, nuit: d.nuit)
            let pire = VignetteDecor.pireFond(jourFait: d.jourFait, brandDark: d.brandDark, nuit: d.nuit)
            let contexte = "\(hex(d.jourFait)) → \(hex(d.brandDark)), nuit : \(d.nuit)"
            #expect(bouts.clair == d.clair, "clair, \(contexte)")
            #expect(bouts.fonce == d.fonce, "foncé, \(contexte)")
            #expect(pire == d.pire, "pire fond, \(contexte)")
        }
    }

    @Test func lesTaillesDImageSontCellesDAndroid() throws {
        let v = try vecteurs()
        #expect(v.pixels.count > 700)
        for cas in v.pixels where cas.count == 6 {
            let (l, h, d) = (flottant(cas[0]), flottant(cas[1]), flottant(cas[2]))
            let taille = VignetteDecor.pixels(largeurDp: l, hauteurDp: h, densite: d, max: Int(cas[3]))
            let attendue = (Int(cas[4]), Int(cas[5]))
            #expect(taille.largeur == attendue.0 && taille.hauteur == attendue.1,
                    "pixels(\(l), \(h), \(d), \(cas[3])) : \(taille.largeur) × \(taille.hauteur)")
        }
    }
}
