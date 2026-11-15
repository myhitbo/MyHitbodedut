import Foundation
import Testing
@testable import Coeur

/// AerationTest d'Android, porté avec les mêmes cas (ceux de web/test/aeration.test.mjs). Puis tout
/// `Tests/Vecteurs/texte.json` pour l'aération, écrit par la JVM (tools/vecteurs_ios/VecteursTexte.kt) :
/// les cas du test, les fins du premier mot, les psaumes, les seuils de la coupe à la lettre près, des
/// paragraphes entiers du siddour et des livres, et une empreinte de chaque paragraphe du siddour Edot
/// HaMizra'h et de deux livres. Rien ne reste à Android.
@Suite("Aération des paragraphes")
struct AerationTests {

    private static let balise = ExpressionReguliere("<[^>]+>")
    private static let saut = ExpressionReguliere("<br><br>")

    /// `split("<br><br>").size` de Kotlin.
    private func morceaux(_ s: String) -> Int {
        Self.saut.decoupe(s).count
    }

    @Test func premierMot() {
        let cas: [(attendu: String, entree: String)] = [
            ("<b>בָּרוּךְ</b> אַתָּה", "בָּרוּךְ אַתָּה"),
            ("<b>מוֹדֶה אֲנִי</b> לְפָנֶיךָ", "<b>מוֹדֶה אֲנִי</b> לְפָנֶיךָ"),
            ("<small>בשבת:</small> רְצֵה", "<small>בשבת:</small> רְצֵה"),
            ("(בעשי״ת) זָכְרֵנוּ", "(בעשי״ת) זָכְרֵנוּ"),
        ]
        for (attendu, entree) in cas {
            let obtenu = Aeration.premierMot(entree)
            let egal = obtenu.egalUnites(attendu)
            #expect(egal, "« \(entree) » donne « \(obtenu) »")
        }
    }

    @Test func courtResteEntier() {
        let court = String(repeating: "א", count: 300) + ": " + String(repeating: "ב", count: 100)
        let r = Aeration.couper(court)
        let entier = r.egalUnites(court)
        #expect(entier)
    }

    @Test func longCoupeHorsSmall() {
        let phrase = String(repeating: "אבגד ", count: 60).rogne
        let he = String(repeating: "ה", count: 260)
        let vav = String(repeating: "ו", count: 20)
        let long = "\(phrase): \(phrase): <small>\(he): \(vav)</small> \(phrase)"
        let r = Aeration.couper(long)
        let n = morceaux(r)
        #expect(n == 3)
        let coupeDansSmall = ExpressionReguliere("<small>[^<]*<br><br>").presente(dans: r)
        #expect(!coupeDansSmall)
        let recousu = r.remplacantUnites("<br><br>", par: " ")
        let rien = recousu.egalUnites(long)
        #expect(rien, "seuls les sauts ont été ajoutés")
    }

    @Test func psaumeJamaisCoupe() {
        let verset = String(repeating: "אֱֽלֹהִ֗ים יְחׇנֵּ֥נוּ וִיבָרְכֵ֑נוּ ", count: 12).rogne
        let avecTeamim = "<b>לַמְנַצֵּ֥חַ</b> \(verset)׃ \(verset)׃ \(verset)׃"
        let visibles = Self.balise.remplace(avecTeamim, par: "").utf16.count
        #expect(visibles > Aeration.long)
        let estPsaume = Aeration.psaume(avecTeamim)
        #expect(estPsaume)
        let coupe = Aeration.couper(avecTeamim)
        let entier = coupe.egalUnites(avecTeamim)
        #expect(entier)
        let phrase = String(repeating: "אבגד ", count: 60).rogne
        let sansTeamim = "<b>מִזְמוֹר</b> לְדָוִד: \(phrase): \(phrase)"
        let ouverture = Aeration.psaume(sansTeamim)
        #expect(ouverture)
        let coupeSans = Aeration.couper(sansTeamim)
        let entierSans = coupeSans.egalUnites(sansTeamim)
        #expect(entierSans)
        let prose = Aeration.psaume("\(phrase): \(phrase)")
        #expect(!prose)
    }

    @Test func lesDeuxEnsemble() {
        let phrase = String(repeating: "אבגד ", count: 60).rogne
        let r = Aeration.aerer("\(phrase): \(phrase)")
        let gras = r.commenceParUnites("<b>אבגד</b>")
        #expect(gras)
        let coupe = r.contientUnites(":<br><br>אבגד")
        #expect(coupe)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let long: Int
            let morceau: Int
            let reste: Int
        }
        /// Un texte rendu : sa longueur en unités UTF-16, son `hashCode`, et le texte s'il est court.
        struct Rendu: Decodable {
            let n: Int
            let h: Int32
            let t: String?
        }
        struct Cas: Decodable {
            let html: String
            let visibles: Int
            let psaume: Bool
            let premierMot: Rendu
            let couper: Rendu
            let morceaux: Int
            let aerer: Rendu
        }
        /// Une empreinte par paragraphe : [hashCode, longueur, morceaux, longueur aérée, hashCode aéré, psaume].
        struct Corpus: Decodable {
            let fichier: String
            let empreintes: [[Int]]
        }

        let constantes: Constantes
        let casDuTest: [Cas]
        let premiersMots: [Cas]
        let psaumes: [Cas]
        let seuils: [Cas]
        let paragraphes: [Cas]
        let corpus: [Corpus]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/texte.json"))
    }

    /// Les blocs d'un fichier de textes (siddour ou livre), tels que VecteursTexte les lit.
    private struct Livre: Decodable {
        struct Bloc: Decodable {
            let t: String?
        }
        struct Section: Decodable {
            let blocs: [Bloc]
        }
        struct Texte: Decodable {
            let sections: [Section]
        }
        let textes: [Texte]
    }

    /// Les paragraphes d'un fichier exporté : le champ « t » de chaque bloc, dans l'ordre du fichier.
    private func paragraphes(_ fichier: String) throws -> [String] {
        let livre = try JSONDecoder().decode(Livre.self, from: Depot.contenu(fichier))
        var sortie: [String] = []
        for texte in livre.textes {
            for section in texte.sections {
                for bloc in section.blocs {
                    if let t = bloc.t { sortie.append(t) }
                }
            }
        }
        return sortie
    }

    private func compare(_ obtenu: String, _ attendu: Vecteurs.Rendu, _ contexte: String) {
        let n = obtenu.utf16.count
        #expect(n == attendu.n, "\(contexte) : longueur")
        let h = Kotlin.hashCode(obtenu)
        #expect(h == attendu.h, "\(contexte) : empreinte de « \(obtenu) »")
        if let t = attendu.t {
            let egal = obtenu.egalUnites(t)
            #expect(egal, "\(contexte) : « \(obtenu) » au lieu de « \(t) »")
        }
    }

    @Test func lesSeuilsSontCeuxDAndroid() throws {
        let c = try vecteurs().constantes
        #expect(Aeration.long == c.long)
        #expect(Aeration.morceau == c.morceau)
        #expect(Aeration.reste == c.reste)
    }

    @Test func chaqueCasSAereCommeSurAndroid() throws {
        let v = try vecteurs()
        let tous = v.casDuTest + v.premiersMots + v.psaumes + v.seuils + v.paragraphes
        let nombre = tous.count
        #expect(nombre > 150)
        let entiers = v.paragraphes.count
        #expect(entiers >= 20)
        for cas in tous {
            let contexte = "« \(cas.html.premieresUnites(60)) »"
            let visibles = Self.balise.remplace(cas.html, par: "").utf16.count
            #expect(visibles == cas.visibles, "\(contexte) : lettres visibles")
            let psaume = Aeration.psaume(cas.html)
            #expect(psaume == cas.psaume, "\(contexte) : psaume")
            compare(Aeration.premierMot(cas.html), cas.premierMot, "\(contexte) premierMot")
            let coupe = Aeration.couper(cas.html)
            compare(coupe, cas.couper, "\(contexte) couper")
            let n = morceaux(coupe)
            #expect(n == cas.morceaux, "\(contexte) : morceaux")
            compare(Aeration.aerer(cas.html), cas.aerer, "\(contexte) aerer")
        }
    }

    @Test func toutLeSiddourEtDeuxLivresSAerentCommeSurAndroid() throws {
        let v = try vecteurs()
        let fichiers = v.corpus.count
        #expect(fichiers == 3)
        for corpus in v.corpus {
            let liste = try paragraphes(corpus.fichier)
            let nombre = liste.count
            #expect(nombre == corpus.empreintes.count, "\(corpus.fichier) : nombre de paragraphes")
            for (p, attendue) in zip(liste, corpus.empreintes) {
                let aere = Aeration.aerer(p)
                let obtenue: [Int] = [Int(Kotlin.hashCode(p)), p.utf16.count, morceaux(Aeration.couper(p)), aere.utf16.count,
                                      Int(Kotlin.hashCode(aere)), Aeration.psaume(p) ? 1 : 0]
                #expect(obtenue == attendue, "\(corpus.fichier) : « \(p.premieresUnites(60)) »")
            }
        }
    }
}
