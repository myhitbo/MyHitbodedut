import Foundation
import Testing
@testable import Coeur

/// TeintesCielTest d'Android, porté : le ciel en fond du Jour (24/11, `TeintesCiel`, `PlanCiel`). Chaque texte de la
/// page garde les seuils de PaletteTests (l'encre 7:1, le texte secondaire, l'accent et les légendes des anneaux
/// 4,5:1) à toute heure, de jour comme de nuit, pour chaque combinaison de `palettes.json` (six fonds, six accents),
/// à toute hauteur du soleil ; lueur, nuages et collines compris. Les étoiles jamais sous un texte (l'arc de l'astre :
/// CielContinuTests). Lancer l'export avant les tests.
@Suite("Teintes du ciel")
struct TeintesCielTests {

    /// Une combinaison de palettes : son nom, le papier, et les encres du Jour avec leurs seuils.
    struct Cas {
        let nom: String
        let fond: Fond
        let accent: Accent
        let sombre: Bool
        let papier: UInt32
        let encres: [TeintesCiel.Encre]
    }

    static func cas() throws -> [Cas] {
        let palettes = try Palettes.lire(Depot.contenu("palettes.json"))
        return [false, true].flatMap { sombre in
            Fond.allCases.flatMap { fond in
                Accent.allCases.map { accent in
                    let p = palettes.palette(fond: fond, accent: accent, nuit: sombre)
                    return Cas(nom: "\(fond.rawValue)/\(accent.rawValue) \(sombre ? "sombre" : "clair")", fond: fond,
                               accent: accent, sombre: sombre, papier: TeintesCiel.argb(p[.paper]),
                               encres: TeintesCiel.encresDuJour(p, nuit: sombre))
                }
            }
        }
    }

    /// Les hauteurs du soleil parcourues : de la nuit noire (−20°) au plein jour (+60°), degré par degré ; et quelques
    /// quarts de degré autour du lever, où tout change vite.
    static let hauteurs = (-20...60).map(Double.init) + [-3.25, -2.75, -0.75, -0.25, 0.25, 0.75, 1.25, 2.75]

    /// Le matin, le soir, et leur passage autour de midi et de minuit (`CielContinu.partMatin`).
    static let matins = [1.0, 0.0, 0.5]

    @Test func chaqueTexteResteLisibleSurLeCielAToutHeureLueurNuagesEtCollinesCompris() throws {
        var fautes: Set<String> = []
        let tous = try Self.cas()
        #expect(tous.count == 2 * 6 * 6)
        for k in tous {
            // Le rapport de contraste de WCAG (TeintesCiel.contraste), la luminance de chaque encre lue une fois.
            let luminances = k.encres.map { TeintesCiel.luminance($0.couleur) }
            for e in Self.hauteurs {
                for matin in Self.matins {
                    let t = TeintesCiel.pourCiel(e, matin: matin, sombre: k.sombre, encres: k.encres, papier: k.papier)
                    // Tout le dégradé, et au-delà ; sous la lueur au plus fort, puis le bord et le corps des nuages.
                    var fonds: [UInt32] = [t.collineLoin, t.collinePres]
                    for i in 0...64 {
                        let fond = t.degrade(Float(i) / 50)
                        let sousLueur = TeintesCiel.melange(fond, t.lueur, Double(t.lueurAlpha))
                        for f in [fond, sousLueur] {
                            let bord = TeintesCiel.melange(f, t.bord, Double(t.bordAlpha))
                            fonds += [f, bord, TeintesCiel.melange(f, t.corps, Double(t.corpsAlpha)),
                                      TeintesCiel.melange(bord, t.corps, Double(t.corpsAlpha))]
                        }
                    }
                    for c in fonds {
                        let l = TeintesCiel.luminance(c)
                        for (en, le) in zip(k.encres, luminances) {
                            let r = (max(l, le) + 0.05) / (min(l, le) + 0.05)
                            if r < en.seuil {
                                fautes.insert("\(k.nom) \(e)° matin \(matin) : \(CielContinu.hexa(en.couleur)) sur \(CielContinu.hexa(c)) = \(r) < \(en.seuil)")
                            }
                        }
                    }
                }
            }
        }
        #expect(fautes.isEmpty, "contrastes insuffisants sur le ciel :\n\(fautes.sorted().prefix(40).joined(separator: "\n"))")
    }

    /// Les bornes elles-mêmes : la marge de 0,05 au-dessus de chaque seuil, et les seuils de PaletteTests.
    @Test func lesBornesSontCellesDePaletteTests() throws {
        #expect(TeintesCiel.marge == 0.05)
        let k = try #require(try Self.cas().first)
        #expect(k.encres.map(\.seuil) == [7, 4.5, 4.5, 4.5, 4.5])
        // Un fond tout juste lisible ne l'est plus un rien plus près de l'encre.
        let encre = TeintesCiel.Encre(couleur: 0xFF000000, seuil: 7)
        let borne = TeintesCiel.borne([encre], sombre: false)
        #expect(abs(borne - (7 * 0.05 - 0.05)) < 1e-12)
        #expect(!TeintesCiel.lisible(0xFF5A5A5A, [encre]))
        #expect(TeintesCiel.lisible(0xFFFFFFFF, [encre]))
    }

    /// Les teintes adaptées au thème glissent elles aussi d'une minute à l'autre : des journées entières, minute par
    /// minute, aux couleurs d'origine et à celles du téléphone du propriétaire (fond bleu, boutons turquoise), dans
    /// les deux thèmes.
    @Test func lesTeintesGlissentMinuteParMinuteDansLesDeuxThemes() throws {
        let k = try Self.cas().filter {
            ($0.fond == .vert && $0.accent == .vert) || ($0.fond == .bleu && $0.accent == .turquoise)
        }
        #expect(k.count == 4)
        func saut(_ a: UInt32, _ b: UInt32) -> Int {
            [16, 8, 0].map { d -> Int in abs(Int((a >> UInt32(d)) & 0xFF) - Int((b >> UInt32(d)) & 0xFF)) }.max() ?? 0
        }
        var fautes: [String] = []
        let jours: [(String, Double, Double, String)] = [
            ("Jérusalem", 31.778, 35.235, "2026-11-24"), ("Paris", 48.857, 2.352, "2026-06-21"),
            ("Stockholm", 59.33, 18.07, "2026-12-21"), ("Tromsø", 69.649, 18.955, "2026-06-21"),
        ]
        for (nom, lat, lon, jour) in jours {
            let debut = SoleilTests.minuitUtc(jour)
            let etats = (0...(24 * 60)).map {
                EtatCiel.de(Soleil.position(millis: debut + Int64($0) * 60_000, latitude: lat, longitude: lon),
                            jourHebreu: 15)
            }
            for c in k {
                var avant: TeintesCiel.Page? = nil
                for (m, e) in etats.enumerated() {
                    let t = TeintesCiel.pourCiel(e.hauteur, matin: e.matin, sombre: c.sombre, encres: c.encres,
                                                 papier: c.papier)
                    if let a = avant {
                        let s = [saut(a.haut, t.haut), saut(a.milieu, t.milieu), saut(a.bas, t.bas),
                                 saut(a.collineLoin, t.collineLoin), saut(a.collinePres, t.collinePres)].max() ?? 0
                        if s > 12 { fautes.append("\(nom) \(jour) \(c.nom) \(m / 60) h \(m % 60) UTC, \(e.hauteur)° : saut de \(s)") }
                        let o = max(abs(a.lueurAlpha - t.lueurAlpha), abs(a.bordAlpha - t.bordAlpha),
                                    abs(a.corpsAlpha - t.corpsAlpha))
                        if o > 0.1 { fautes.append("\(nom) \(jour) \(c.nom) \(m / 60) h \(m % 60) UTC : opacités sautent de \(o)") }
                    }
                    avant = t
                }
            }
        }
        #expect(fautes.isEmpty, "à-coups des teintes :\n\(fautes.prefix(30).joined(separator: "\n"))")
    }

    /// La palette d'origine, vert : le ciel s'y voit bien, et chaque moment a sa couleur.
    @Test func unVraiCielDansLesDeuxThemes() throws {
        let k = try Self.cas()
        for sombre in [false, true] {
            let origine = try #require(k.first { $0.fond == .vert && $0.accent == .vert && $0.sombre == sombre })
            func ciel(_ e: Double, _ matin: Bool) -> TeintesCiel.Page {
                TeintesCiel.pourCiel(e, matin: matin, sombre: sombre, encres: origine.encres, papier: origine.papier)
            }
            let nuit = ciel(-24, true)
            let jour = ciel(30, true)
            let coucher = ciel(0, false)
            for t in [nuit, jour, coucher, ciel(0, true)] {
                #expect(t.haut != origine.papier || t.bas != origine.papier, "le ciel est resté le papier")
                if sombre {
                    #expect(TeintesCiel.luminance(t.haut) < 0.06, "un ciel sombre")
                } else {
                    #expect(TeintesCiel.luminance(t.haut) > 0.8, "un ciel pâle")
                }
            }
            // Le jour est bleu, le coucher rosé ou orangé à l'horizon, la nuit la plus sombre en thème sombre.
            #expect((jour.haut & 0xFF) > ((jour.haut >> 16) & 0xFF), "le jour n'est pas bleu")
            #expect(((coucher.bas >> 16) & 0xFF) > (coucher.bas & 0xFF), "le coucher n'est pas chaud")
            if sombre {
                #expect(TeintesCiel.luminance(nuit.haut) <= TeintesCiel.luminance(jour.haut))
                // En thème sombre, le corps des nuages est une silhouette plus sombre que le ciel.
                #expect(TeintesCiel.luminance(jour.corps) < TeintesCiel.luminance(jour.haut))
                for e in -20...60 {
                    // Le bord des nuages vifs, assombri, ne s'avive pas (le blanc crème du plein jour devenait kaki).
                    let brut = CielContinu.nuageBord.a(Double(e))
                    let t = ciel(Double(e), true)
                    #expect(TeintesCiel.chroma(t.bordVif) <= TeintesCiel.chroma(brut) + 2 / 255.0,
                            "bord avivé à \(e)° : \(CielContinu.hexa(brut)) → \(CielContinu.hexa(t.bordVif))")
                    #expect(TeintesCiel.luminance(t.bordVif) <= 0.36, "\(e)°")
                    // Le corps, à contre-jour, prend la couleur du haut du ciel sans s'aviver : plus de tache brune.
                    let corps = CielContinu.nuageCorps.a(Double(e))
                    #expect(TeintesCiel.chroma(t.corpsVif)
                        <= max(TeintesCiel.chroma(corps), TeintesCiel.chroma(t.haut)) + 2 / 255.0,
                            "corps avivé à \(e)° : \(CielContinu.hexa(t.corpsVif))")
                    #expect(TeintesCiel.luminance(t.corpsVif) <= 0.11, "\(e)°")
                }
                // Et jamais de kaki : l'horizon assombri de +6° à +12° virait au vert-de-gris.
                for e in -20...60 {
                    for matin in [true, false] {
                        let t = ciel(Double(e), matin)
                        for c in [t.haut, t.milieu, t.bas, t.collineLoin, t.collinePres] {
                            let hsl = TeintesCiel.hsl(c)
                            let h = hsl[0] * 360
                            #expect(!(60.0...170.0).contains(h) || hsl[1] <= 0.04,
                                    "kaki à \(e)° \(matin ? "le matin" : "le soir") : \(CielContinu.hexa(c))")
                        }
                    }
                }
            }
        }
    }

    @Test func desEncresImpossiblesLaissentLePapier() {
        // Un gris moyen ne tient 7:1 sur aucun ciel : le papier reste, sans lueur ni nuage.
        let papier: UInt32 = 0xFF101A16
        let t = TeintesCiel.pourCiel(30, matin: true, sombre: true,
                                     encres: [TeintesCiel.Encre(couleur: 0xFF777777, seuil: 7)], papier: papier)
        #expect(t.haut == papier)
        #expect(t.bas == papier)
        #expect(t.lueurAlpha == 0)
        #expect(t.bordAlpha == 0)
    }

    @Test func assombrirOuEclaircirGardeLaTeinte() {
        let bleu: UInt32 = 0xFF5FB1EA
        let sombre = TeintesCiel.aLuminance(bleu, 0.03)
        #expect(TeintesCiel.luminance(sombre) <= 0.03)
        #expect(abs(TeintesCiel.hsl(bleu)[0] - TeintesCiel.hsl(sombre)[0]) <= 0.02)
        let pale = TeintesCiel.aLuminance(bleu, 0.86)
        #expect(TeintesCiel.luminance(pale) >= 0.86)
        #expect(abs(TeintesCiel.hsl(bleu)[0] - TeintesCiel.hsl(pale)[0]) <= 0.02)
    }

    // MARK: Le plan

    /// Un Pixel 6 debout, en points : 411 de large, des anneaux de 260 centrés, 180 sous le haut.
    static let largeur = 411.0
    static let jauge = PlanCiel.Zone(gauche: 75.5, haut: 180, droite: 335.5, bas: 440)
    static let textes = [
        PlanCiel.Zone(gauche: 24, haut: 8, droite: 200, bas: 56),     // la date hébraïque
        PlanCiel.Zone(gauche: 24, haut: 64, droite: 387, bas: 160),   // le salut et les lignes d'état
        PlanCiel.Zone(gauche: 24, haut: 444, droite: 387, bas: 520),  // la légende et le palier
    ]

    @Test func aucuneEtoileSousUnTexteNiSurLesAnneaux() {
        let etoiles = CielVivant.etoiles(60, graine: 29, rayonMin: 0.7, rayonMax: 1.7)
        let hauteur = 700 * 0.78
        let zones = Self.textes + [Self.jauge]
        let libres = PlanCiel.libres(etoiles, largeur: Self.largeur, hauteur: hauteur, zones: zones)
        #expect(libres.filter { $0 }.count >= 15, "trop d'étoiles écartées")
        let ecart = PlanCiel.margeEtoile + Double(CielVivant.deriveXDp)
        for (i, libre) in libres.enumerated() where libre {
            let x = Double(etoiles[i * CielVivant.champs]) * Self.largeur
            let y = Double(etoiles[i * CielVivant.champs + 1]) * hauteur
            #expect(!zones.contains { $0.touche(x, y, ecart) }, "étoile \(i) sous un texte")
        }
        // De 24 à 72 étoiles selon la taille de l'écran (elles s'allument avec le crépuscule, CielContinu.etoiles).
        #expect(PlanCiel.etoiles(largeur: 320, hauteur: 300).nombre == 24)
        #expect(PlanCiel.etoiles(largeur: 1280, hauteur: 800).nombre == 72)
    }
}
