import Foundation
import Testing
@testable import Coeur

/// LanguesTexteTest d'Android, porté en entier : six façons de lire, la traduction du domaine public
/// de Tehilim et du Tikoun, l'hébreu quand il n'y en a pas ; puis tout le chapitre « languesTexte » de
/// `Tests/Vecteurs/langues.json` (tools/vecteurs_ios/VecteursLangues.kt). Les vues d'une traduction
/// (`vueTraduction`, `vueMarquee`) et `mode(context)` restent à Android.
@Suite("LanguesTexte")
struct LanguesTexteTests {

    /// Les paires (langue, texte) en « langue=texte », pour les comparer d'un coup.
    private func paires(_ textes: [(langue: String, texte: String)]) -> [String] {
        var resultat: [String] = []
        for t in textes {
            resultat.append(t.langue + "=" + t.texte)
        }
        return resultat
    }

    @Test func parDefautLaRegleDAvant() {
        let he = LanguesTexte.defaut("he")
        #expect(he == .he)
        let iw = LanguesTexte.defaut("iw")
        #expect(iw == .he)
        let fr = LanguesTexte.defaut("fr")
        #expect(fr == .heFr)
        let en = LanguesTexte.defaut("en")
        #expect(en == .heEn)
    }

    @Test func lesTextesDansLOrdreDuModeLHebreuFauteDeTraduction() {
        let m = LanguesTexte.Mode.frEn
        let deux = paires(LanguesTexte.textes(m, "אחד", "un", "one"))
        #expect(deux == ["fr=un", "en=one"])
        let hebreu = paires(LanguesTexte.textes(.fr, "אחד", nil, "one"))
        #expect(hebreu == ["he=אחד"])
        let heEn = paires(LanguesTexte.textes(.heEn, "אחד", "un", "one"))
        #expect(heEn == ["he=אחד", "en=one"])
        let manqueHeFr = LanguesTexte.manque(.heFr, aTraduction: false)
        #expect(manqueHeFr)
        let manqueHe = LanguesTexte.manque(.he, aTraduction: false)
        #expect(!manqueHe)
    }

    @Test func tehilimTraduitVersetParVersetDomainePublic() throws {
        let json = try String(decoding: Depot.contenu("tehilim.json"), as: UTF8.self)
        let t = try TehilimLoader.parse(json)
        var manquants: [String] = []
        var lus = 0
        for n in 1...150 {
            let total = t.versets(n).count
            for l in ["fr", "en"] {
                for rang in 0..<total {
                    let v = rang + 1
                    let traduction = t.traduction(l, n, v)
                    if traduction?.estBlanc ?? true { manquants.append("\(l) \(n):\(v)") }
                    lus += 1
                }
                if t.traduction(l, n, total + 1) != nil { manquants.append("\(l) \(n):\(total + 1) de trop") }
            }
        }
        let aucun = manquants.isEmpty
        let detail = manquants.prefix(20).joined(separator: ", ")
        #expect(aucun, "\(detail)")
        let nombre = lus
        #expect(nombre > 4000, "aucun verset lu : la lecture est cassée")
        let fr = try #require(t.traduction("fr", 23, 1))
        let berger = fr.contientUnites("Éternel est mon berger")
        #expect(berger)
        let en = try #require(t.traduction("en", 23, 1))
        let shepherd = en.contientUnites("The LORD is my shepherd")
        #expect(shepherd)
        let racine = try ObjetJSON(texte: json)
        let meta = try #require(racine.objet("traductions"))
        for l in ["fr", "en"] {
            let edition = try #require(meta.objet(l)?.objet("edition"), "\(l) : pas d'édition")
            let licence = edition.texte("licence")
            #expect(licence == "Public Domain", "\(l)")
        }
    }

    @Test func leTikkunPorteLaMemeTraductionQueTehilim() throws {
        let t = try TehilimLoader.parse(String(decoding: Depot.contenu("tehilim.json"), as: UTF8.self))
        let tikkun = try ObjetJSON(texte: String(decoding: Depot.contenu("tikkun_haklali.json"), as: UTF8.self))
        let psaumes = try #require(tikkun.tableau("psaumes"))
        var ecarts: [String] = []
        var compares = 0
        for rang in 0..<psaumes.count {
            let p = try #require(psaumes.objet(rang))
            let numero = p.entier("numero")
            let versets = try #require(p.tableau("versets"))
            for k in 0..<versets.count {
                let v = try #require(versets.objet(k))
                let n = v.entier("n")
                // `getString` d'Android : la valeur doit être là ; « null » se lit « null ».
                let valeurFr = try #require(v["fr"], "Tehilim \(numero):\(n) sans « fr »")
                let valeurEn = try #require(v["en"], "Tehilim \(numero):\(n) sans « en »")
                let fr = valeurFr.commeTexte
                let en = valeurEn.commeTexte
                if !LanguesTexteTests.meme(t.traduction("fr", numero, n), fr) { ecarts.append("fr \(numero):\(n)") }
                if !LanguesTexteTests.meme(t.traduction("en", numero, n), en) { ecarts.append("en \(numero):\(n)") }
                compares += 1
            }
        }
        let aucun = ecarts.isEmpty
        let detail = ecarts.joined(separator: ", ")
        #expect(aucun, "\(detail)")
        let nombre = compares
        #expect(nombre > 100, "aucun verset du Tikoun lu : la lecture est cassée")
    }

    // MARK: Les vecteurs de la JVM

    /// `==` de Kotlin sur deux chaînes peut-être nulles : les mêmes unités UTF-16.
    private static func meme(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (let x?, let y?): return x.egalUnites(y)
        default: return false
        }
    }

    private struct Vecteurs: Decodable {
        let languesTexte: Chapitre
    }

    /// `textes[i].resultats` : pour chaque hébreu, chaque français et chaque anglais, l'anglais variant
    /// le plus vite, les paires [langue, texte] rendues.
    private struct Chapitre: Decodable {
        let modes: [ModeAttendu]
        let defaut: [Defaut]
        let hebreux: [String]
        let francais: [String?]
        let anglais: [String?]
        let textes: [Textes]
        let manque: [Manque]
    }

    private struct ModeAttendu: Decodable {
        let nom: String
        let cle: String
        let langues: [String]
        let libelle: String
    }

    private struct Defaut: Decodable {
        let langue: String
        let mode: String
    }

    private struct Textes: Decodable {
        let mode: String
        let resultats: [[[String]]]
    }

    private struct Manque: Decodable {
        let mode: String
        let sansTraduction: Bool
        let avecTraduction: Bool
    }

    /// Les noms des cas d'Android.
    private static let parNom: [String: LanguesTexte.Mode] = [
        "HE": .he, "FR": .fr, "EN": .en, "HE_FR": .heFr, "HE_EN": .heEn, "FR_EN": .frEn,
    ]

    private static func memesPaires(_ rendues: [(langue: String, texte: String)], _ attendues: [[String]]) -> Bool {
        guard rendues.count == attendues.count else { return false }
        for (rendue, attendue) in zip(rendues, attendues) {
            guard attendue.count == 2, rendue.langue.egalUnites(attendue[0]), rendue.texte.egalUnites(attendue[1]) else {
                return false
            }
        }
        return true
    }

    @Test func lesVecteursDeLaJVM() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/langues.json"))
        let c = v.languesTexte
        var cles: [String] = []
        for mode in LanguesTexte.Mode.allCases {
            cles.append(mode.cle)
        }
        var attendues: [String] = []
        for m in c.modes {
            attendues.append(m.cle)
        }
        #expect(cles == attendues, "les modes, dans l'ordre d'Android")
        for m in c.modes {
            let mode = try #require(LanguesTexte.Mode(rawValue: m.cle), "mode « \(m.cle) »")
            let nomme = LanguesTexteTests.parNom[m.nom]
            #expect(nomme == mode, "\(m.nom)")
            let langues = mode.langues
            #expect(langues == m.langues, "\(m.cle) : langues")
            let libelle = mode.libelle
            #expect(libelle == m.libelle, "\(m.cle) : libellé")
        }
        for d in c.defaut {
            let mode = LanguesTexte.defaut(d.langue)
            #expect(mode.cle == d.mode, "defaut(« \(d.langue) »)")
        }
        let parMode = c.hebreux.count * c.francais.count * c.anglais.count
        for t in c.textes {
            let mode = try #require(LanguesTexte.Mode(rawValue: t.mode))
            let nombre = t.resultats.count
            #expect(nombre == parMode, "\(t.mode) : vecteur incomplet")
            var k = 0
            for he in c.hebreux {
                for fr in c.francais {
                    for en in c.anglais where k < t.resultats.count {
                        let rendues = LanguesTexte.textes(mode, he, fr, en)
                        let ok = LanguesTexteTests.memesPaires(rendues, t.resultats[k])
                        let vues = paires(rendues)
                        #expect(ok, "textes(\(t.mode), « \(he) », « \(fr ?? "nil") », « \(en ?? "nil") ») = \(vues)")
                        k += 1
                    }
                }
            }
        }
        for m in c.manque {
            let mode = try #require(LanguesTexte.Mode(rawValue: m.mode))
            let sans = LanguesTexte.manque(mode, aTraduction: false)
            #expect(sans == m.sansTraduction, "manque(\(m.mode), false)")
            let avec = LanguesTexte.manque(mode, aTraduction: true)
            #expect(avec == m.avecTraduction, "manque(\(m.mode), true)")
        }
    }
}
