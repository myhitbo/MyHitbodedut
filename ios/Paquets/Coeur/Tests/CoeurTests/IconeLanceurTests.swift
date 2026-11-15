import Foundation
import Testing
@testable import Coeur

/// IconeLanceurTest d'Android. Ce qui lit le manifeste (les entrées activity-alias, la seule active, les
/// portes LAUNCHER), les gabarits mipmap-anydpi, Store.kt et MyHitbodedutApp.kt reste à Android ; ici, les
/// noms des douze icônes et celle par défaut, le visage de chaque genre dans ce qu'iOS livre, et la plaque
/// claire de chaque accent (icone_fond_<accent> de colors.xml, lue par VecteursInterfaceB.kt), qui est son
/// « mint » dans palettes.json. Rejoue aussi `interface_b.json`.
@Suite("IconeLanceur")
struct IconeLanceurTests {

    private struct Fichier: Decodable {
        let icones: Icones
    }

    private struct Icones: Decodable {
        let parDefaut: String
        let tous: [String]
        let alias: [Alias]
        let plaques: [Plaque]
    }

    /// [clé de l'adresse ou null, clé de l'accent, nom de l'icône].
    private struct Alias: Decodable {
        let adresse: String?
        let accent: String
        let nom: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            adresse = try c.decodeNil() ? nil : c.decode(String.self)
            accent = try c.decode(String.self)
            nom = try c.decode(String.self)
        }
    }

    /// [clé de l'accent, « #RRGGBB » de sa plaque].
    private struct Plaque: Decodable {
        let accent: String
        let hex: String

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            accent = try c.decode(String.self)
            hex = try c.decode(String.self)
        }
    }

    private func vecteurs() throws -> Icones {
        let donnees = try Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_b.json")
        return try JSONDecoder().decode(Fichier.self, from: donnees).icones
    }

    @Test func uneEntreeParCombinaisonLeHassidSurLeVertParDefaut() {
        let tous = IconeLanceur.tous()
        #expect(tous.count == Adresse.allCases.count * Accent.allCases.count)
        let distincts = Set(tous)
        #expect(distincts.count == tous.count, "deux combinaisons sous un même nom")
        let defaut = IconeLanceur.parDefaut
        #expect(defaut == "com.myhitbodedut.Icone_m_vert")
        let defautParmiTous = tous.contains(defaut)
        #expect(defautParmiTous)
        let tsadeket = IconeLanceur.alias(.femme, .bordeaux)
        #expect(tsadeket == "com.myhitbodedut.Icone_f_bordeaux")
        let sansAdresse = IconeLanceur.alias(nil, .bleu)
        #expect(sansAdresse == "com.myhitbodedut.Icone_m_bleu")
        // Chaque nom a la forme des entrées du manifeste : « Icone_<genre>_<accent> ».
        for nom in tous {
            let court = nom.apresUnites("com.myhitbodedut.")
            let morceaux = court.split(separator: "_").map(String.init)
            #expect(morceaux.count == 3 && morceaux.first == "Icone", "\(nom)")
        }
    }

    @Test func chaqueIconeASonVisageEtLaPlaqueClaireDeSaPalette() throws {
        // Le visage du hassid et celui de la tsadeket (drawable-nodpi d'Android) sont dans ce qu'iOS livre.
        for visage in ["ic_launcher_face", "ic_launcher_face_f"] {
            let chemin = Depot.racine.appendingPathComponent("ios/Ressources/Images/\(visage).webp").path
            let existe = FileManager.default.fileExists(atPath: chemin)
            #expect(existe, "\(visage).webp absent")
        }
        // La plaque de chaque accent est son « mint », sur chaque fond, de jour comme de nuit, et elle est claire.
        let v = try vecteurs()
        let palettes = try Palettes.lire(Depot.contenu("palettes.json"))
        #expect(v.plaques.count == Accent.allCases.count)
        for plaque in v.plaques {
            let accent: Accent = try #require(Accent(rawValue: plaque.accent), "accent \(plaque.accent)")
            let couleur: Couleur = try #require(Couleur(hex: plaque.hex), "plaque \(plaque.hex)")
            for nuit in [false, true] {
                for fond in Fond.allCases {
                    let mint = palettes.palette(fond: fond, accent: accent, nuit: nuit)[.mint]
                    #expect(mint == couleur, "\(fond)/\(accent) \(nuit ? "nuit" : "jour") : \(mint.hex) au lieu de \(plaque.hex)")
                }
            }
            let clarte = (Int(couleur.rouge) + Int(couleur.vert) + Int(couleur.bleu)) / 3
            #expect(clarte >= 200, "icone_fond_\(accent) : fond trop sombre")
        }
    }

    @Test func lesIconesSontCellesDAndroid() throws {
        let v = try vecteurs()
        let defaut = IconeLanceur.parDefaut
        #expect(defaut == v.parDefaut)
        let tous = IconeLanceur.tous()
        #expect(tous == v.tous)
        #expect(v.alias.count == (Adresse.allCases.count + 1) * Accent.allCases.count)
        for a in v.alias {
            var adresse: Adresse? = nil
            if let cle = a.adresse {
                let trouvee: Adresse = try #require(Adresse(rawValue: cle), "adresse \(cle)")
                adresse = trouvee
            }
            let accent: Accent = try #require(Accent(rawValue: a.accent), "accent \(a.accent)")
            let nom = IconeLanceur.alias(adresse, accent)
            #expect(nom == a.nom, "alias(\(a.adresse ?? "null"), \(a.accent))")
        }
    }
}
