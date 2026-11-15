import Foundation
import Testing
@testable import Coeur

/// GuideSujetsTest d'Android, porté sur guide_sujets.json tel que l'export l'a livré
/// (ios/Ressources/Contenu, le même fichier que res/raw), puis la part de GuideSujets.kt dans
/// `Tests/Vecteurs/guidee.json` : le vrai fichier, par empreintes (longueur et hashCode de Java), et
/// un fichier abîmé, texte pour texte, pour la lecture tolérante d'Android (optString, isBlank).
@Suite("Guide selon le sujet")
struct GuideSujetsTests {

    private struct Vecteurs: Decodable {
        struct Empreinte: Decodable {
            let longueur: Int
            let empreinte: Int32
        }
        struct CasReel: Decodable {
            let theme: String?
            let cle: String
            /// Langue → empreinte de l'invitation ; une langue absente : Android rend null.
            let rendus: [String: Empreinte]
        }
        struct CasForge: Decodable {
            let theme: String?
            let cle: String
            /// Langue → invitation ; une langue absente : Android rend null.
            let rendus: [String: String]
        }

        let guideLangues: [String]
        let guideReel: [CasReel]
        let guideForgeTexte: String
        let guideForgeLangues: [String]
        let guideForge: [CasForge]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/guidee.json"))
    }

    private func sujets() throws -> ObjetJSON {
        try GuideSujets.lire(Depot.contenu("guide_sujets.json"))
    }

    /// Le sujet d'une clé des vecteurs ; nil : pas de sujet.
    private func themeDe(_ cle: String?) throws -> Theme? {
        guard let cle else { return nil }
        let theme: Theme = try #require(Theme(rawValue: cle), "sujet inconnu : \(cle)")
        return theme
    }

    @Test func chaqueSujetSaufAutreAUneInvitationParTempsDansLesTroisLangues() throws {
        let s = try sujets()
        for theme in Theme.allCases where theme != .autre {
            for m in Hitbodedut.mouvements {
                for langue in ["fr", "en", "he"] {
                    let texte = GuideSujets.invitation(s, theme: theme, cle: m.cle, langue: langue) ?? ""
                    let correcte = !texte.estBlanc && !texte.contientUnites("'")
                    #expect(correcte, "\(theme.cle) / \(m.cle) / \(langue)")
                }
            }
        }
        let n = s.count
        let attendu = Theme.allCases.count - 1
        #expect(n == attendu)
    }

    @Test func sansSujetOuAutreChoseLeGuideResteCeluiDeToujours() throws {
        let s = try sujets()
        let sansSujet = GuideSujets.invitation(s, theme: nil, cle: "sihah", langue: "fr")
        let autreChose = GuideSujets.invitation(s, theme: Theme.autre, cle: "sihah", langue: "fr")
        let he = GuideSujets.invitation(s, theme: Theme.famille, cle: "bakasha", langue: "he") ?? ""
        let iw = GuideSujets.invitation(s, theme: Theme.famille, cle: "bakasha", langue: "iw") ?? ""
        let memes = he.egalUnites(iw)
        let rempli = !he.isEmpty
        #expect(sansSujet == nil)
        #expect(autreChose == nil)
        #expect(memes)
        #expect(rempli)
    }

    /// Un fichier sans objet « sujets », ou illisible, est refusé, comme par getJSONObject d'Android.
    @Test func unFichierSansSujetsEstRefuse() {
        let sansSujets = try? GuideSujets.lire(Data(#"{"_meta": {}, "sujet": {}}"#.utf8))
        let sujetsEnTableau = try? GuideSujets.lire(Data(#"{"sujets": []}"#.utf8))
        let illisible = try? GuideSujets.lire(Data("pas du JSON".utf8))
        let vide = try? GuideSujets.lire(Data(#"{"sujets": {}}"#.utf8))
        let nombre = vide?.count ?? -1
        #expect(sansSujets == nil)
        #expect(sujetsEnTableau == nil)
        #expect(illisible == nil)
        #expect(nombre == 0)
    }

    @Test func leVraiFichierRendCeQueRendAndroid() throws {
        let v = try vecteurs()
        let s = try sujets()
        let langues = Set(v.guideLangues)
        var rendues = 0
        for c in v.guideReel {
            let theme = try themeDe(c.theme)
            let toutesConnues = Set(c.rendus.keys).isSubset(of: langues)
            #expect(toutesConnues, "\(c.theme ?? "nil") / « \(c.cle) » : langue hors de guideLangues")
            for langue in v.guideLangues {
                let ou = "\(c.theme ?? "nil") / « \(c.cle) » / « \(langue) »"
                let texte = GuideSujets.invitation(s, theme: theme, cle: c.cle, langue: langue)
                if let attendu = c.rendus[langue] {
                    let lu = texte ?? ""
                    let rendue = texte != nil
                    let longueur = lu.utf16.count
                    let empreinte = Kotlin.hashCode(lu)
                    #expect(rendue, "\(ou) : Android rend une invitation")
                    #expect(longueur == attendu.longueur, "\(ou) : longueur")
                    #expect(empreinte == attendu.empreinte, "\(ou) : empreinte")
                    rendues += 1
                } else {
                    #expect(texte == nil, "\(ou) : Android ne rend rien")
                }
            }
        }
        // Neuf sujets, cinq temps, et « he » comme « iw » à côté du français et de l'anglais.
        let attendues = (Theme.allCases.count - 1) * Hitbodedut.mouvements.count * 4
        #expect(rendues == attendues)
    }

    @Test func unFichierAbimeSeLitCommeSurAndroid() throws {
        let v = try vecteurs()
        let abime = try ObjetJSON(texte: v.guideForgeTexte)
        let langues = Set(v.guideForgeLangues)
        for c in v.guideForge {
            let theme = try themeDe(c.theme)
            let toutesConnues = Set(c.rendus.keys).isSubset(of: langues)
            #expect(toutesConnues, "\(c.theme ?? "nil") / « \(c.cle) » : langue hors de guideForgeLangues")
            for langue in v.guideForgeLangues {
                let ou = "\(c.theme ?? "nil") / « \(c.cle) » / « \(langue) »"
                let texte = GuideSujets.invitation(abime, theme: theme, cle: c.cle, langue: langue)
                let lu = texte ?? ""
                if let attendu = c.rendus[langue] {
                    let identique = texte != nil && lu.egalUnites(attendu)
                    #expect(identique, "\(ou) : « \(lu) » au lieu de « \(attendu) »")
                } else {
                    #expect(texte == nil, "\(ou) : Android ne rend rien, Swift rend « \(lu) »")
                }
            }
        }
    }
}
