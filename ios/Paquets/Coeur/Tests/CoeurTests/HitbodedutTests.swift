import Foundation
import Testing
@testable import Coeur

/// HitbodedutTest d'Android, porté : les cinq temps, leur parcours, et le fait qu'ils sont bien ceux
/// de leurs sources ; puis `Tests/Vecteurs/guidee.json` (tools/vecteurs_ios/VecteursGuidee.kt) rejoué
/// pour la part de Hitbodedut.kt. Restent à Android les trois tests qui lisent ses gabarits (les vues
/// de la carte, l'hébreu posé de droite à gauche, la carte et son réglage dans les écrans), et les
/// quatre lectures de `Reference.localise`, qui reviendront avec le portage de Reference.kt.
@Suite("Hitbodedut")
struct HitbodedutTests {

    private static let chemin = "ios/Paquets/Coeur/Tests/Vecteurs/guidee.json"

    private struct Vecteurs: Decodable {
        struct MouvementLu: Decodable {
            let cle: String
            let he: String
            let titre: String
            let invite: String
            let illustration: String
            let source: String
        }
        struct Sources: Decodable {
            let likoutei: String
            let rambam: String
        }
        struct Pas: Decodable {
            let index: Int
            let mouvement: String
            /// nil là où Kotlin, sur 32 bits, déborde (section « debordements »).
            let suivant: Int?
            let precedent: Int?
            let estPremier: Bool
            let estDernier: Bool
        }
        struct Debordement: Decodable {
            let fonction: String
            let entree: Int
            let kotlin: Int
        }

        let mouvements: [MouvementLu]
        let sources: Sources
        let dernier: Int
        let parcours: [Pas]
        let debordements: [Debordement]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees(Self.chemin))
    }

    private func temps(_ cle: String) -> Mouvement? {
        Hitbodedut.mouvements.first { $0.cle == cle }
    }

    @Test func lesCinqTempsSontDistinctsEtComplets() {
        let mouvements = Hitbodedut.mouvements
        let n = mouvements.count
        let cles = Set(mouvements.map { $0.cle }).count
        // Comme toSet() de Kotlin : unité UTF-16 par unité, sans l'équivalence canonique de Swift.
        let hebreux = Set(mouvements.map { Array($0.he.utf16) }).count
        let titres = Set(mouvements.map { $0.titre }).count
        let invites = Set(mouvements.map { $0.invite }).count
        let illustrations = Set(mouvements.map { $0.illustration }).count
        #expect(n == 5)
        #expect(cles == n)
        #expect(hebreux == n)
        #expect(titres == n)
        #expect(invites == n)
        for m in mouvements {
            let sansHebreu = m.he.estBlanc
            let sansImage = m.illustration.isEmpty
            let sansSource = m.source.estBlanc
            #expect(!sansHebreu, "« \(m.cle) » n'a pas d'hébreu")
            #expect(!sansImage, "« \(m.cle) » n'a pas d'illustration")
            #expect(!sansSource, "« \(m.cle) » n'a pas de source")
        }
        #expect(illustrations == n)
    }

    /// Les cinq intitulés hébreux sont tirés de leur source, mot pour mot, points-voyelles compris.
    /// Ce test les fige : une reformulation qui garderait la référence sous une phrase inventée
    /// passerait sinon inaperçue. Les attendus sont recopiés de HitbodedutTest.kt par programme.
    @Test func lesIntitulesSontCeuxDeLeursSources() {
        let attendus: [(cle: String, he: String)] = [
            ("sihah", "לְפָרֵשׁ שִׂיחָתוֹ"),
            ("harata", "חֲרָטָה וּתְשׁוּבָה עַל הֶעָבָר"),
            ("bakasha", "בַּקָּשַׁת תַחֲנוּנִים"),
            ("torah", "לַעֲשׂוֹת מֵהַתּוֹרָה תְּפִלָּה"),
            ("hodaa", "נוֹתֵן שֶׁבַח וְהוֹדָיָה"),
        ]
        let cles = Hitbodedut.mouvements.map { $0.cle }
        let clesAttendues = attendus.map { $0.cle }
        #expect(cles == clesAttendues)
        for (cle, he) in attendus {
            let ecrit = temps(cle)?.he ?? ""
            let identique = ecrit.egalUnites(he)
            #expect(identique, "« \(cle) » : « \(ecrit) »")
        }
    }

    /// L'action de grâce n'est pas dans Likoutei Moharan II, 25 : elle ne doit donc pas s'en
    /// réclamer. Les quatre autres en viennent, et doivent s'en réclamer.
    @Test func chaqueTempsSeReclameDeLaSourceDontIlVient() {
        for cle in ["sihah", "harata", "bakasha", "torah"] {
            let source = temps(cle)?.source ?? ""
            #expect(source == Hitbodedut.sourceLikoutei, "« \(cle) » vient du chapitre")
        }
        let hodaa = temps("hodaa")?.source ?? ""
        #expect(hodaa == Hitbodedut.sourceRambam)
    }

    /// Le Rambam place l'action de grâce après la demande, pas avant : l'ordre affiché doit le
    /// suivre, sinon la référence ne tient plus.
    @Test func lActionDeGraceVientApresLaDemande() throws {
        let cles = Hitbodedut.mouvements.map { $0.cle }
        let hodaa = try #require(cles.firstIndex(of: "hodaa"))
        let bakasha = try #require(cles.firstIndex(of: "bakasha"))
        let enDernier = Hitbodedut.estDernier(hodaa)
        #expect(hodaa > bakasha)
        #expect(enDernier)
    }

    /// On avance, on recule, et on ne sort jamais des cinq.
    @Test func leParcoursResteDansSesBornes() {
        let dernier = Hitbodedut.dernier
        #expect(dernier == 4)
        let suivants: [(index: Int, attendu: Int)] = [(0, 1), (3, 4), (4, 4), (99, 4)]
        for (index, attendu) in suivants {
            let rendu = Hitbodedut.suivant(index)
            #expect(rendu == attendu, "suivant(\(index))")
        }
        let precedents: [(index: Int, attendu: Int)] = [(1, 0), (0, 0), (-5, 0)]
        for (index, attendu) in precedents {
            let rendu = Hitbodedut.precedent(index)
            #expect(rendu == attendu, "precedent(\(index))")
        }
        let premier0 = Hitbodedut.estPremier(0)
        let premier1 = Hitbodedut.estPremier(1)
        let dernier4 = Hitbodedut.estDernier(4)
        let dernier3 = Hitbodedut.estDernier(3)
        #expect(premier0)
        #expect(!premier1)
        #expect(dernier4)
        #expect(!dernier3)
    }

    /// Un indice aberrant rend un temps, jamais une exception.
    @Test func unIndiceHorsBornesNeRomptPas() throws {
        let avant = Hitbodedut.mouvement(-1)
        let apres = Hitbodedut.mouvement(400)
        let premier = try #require(Hitbodedut.mouvements.first)
        let dernier = try #require(Hitbodedut.mouvements.last)
        #expect(avant == premier)
        #expect(apres == dernier)
    }

    /// Swift compte sur 64 bits et s'arrête au débordement, là où Kotlin déborde en silence : les
    /// bornes de son Int ne rompent pas davantage.
    @Test func lesBornesDeLEntierDeSwiftNeRompentPas() {
        let suivantMax = Hitbodedut.suivant(Int.max)
        let suivantMin = Hitbodedut.suivant(Int.min)
        let precedentMax = Hitbodedut.precedent(Int.max)
        let precedentMin = Hitbodedut.precedent(Int.min)
        let loin = Hitbodedut.mouvement(Int.max).cle
        let avant = Hitbodedut.mouvement(Int.min).cle
        #expect(suivantMax == Hitbodedut.dernier)
        #expect(suivantMin == 0)
        #expect(precedentMax == Hitbodedut.dernier)
        #expect(precedentMin == 0)
        #expect(loin == "hodaa")
        #expect(avant == "sihah")
    }

    @Test func lesLibellesExistentDansLesTroisLangues() throws {
        let cles = [
            "settings_hitbodedut", "settings_hitbodedut_hint", "hitbodedut_step",
            "hitbodedut_previous", "hitbodedut_next",
            "hitbodedut_sihah", "hitbodedut_sihah_invite",
            "hitbodedut_harata", "hitbodedut_harata_invite",
            "hitbodedut_bakasha", "hitbodedut_bakasha_invite",
            "hitbodedut_torah", "hitbodedut_torah_invite",
            "hitbodedut_hodaa", "hitbodedut_hodaa_invite",
        ]
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                let presente = chaines[cle] != nil
                #expect(presente, "\(langue) : « \(cle) » manquant")
            }
        }
        // Et ce que les temps nomment est bien ce que le test vient de trouver.
        let nommees = Hitbodedut.mouvements.flatMap { [$0.titre, $0.invite] }
        for cle in nommees {
            let connue = cles.contains(cle)
            #expect(connue, "« \(cle) » n'est pas parmi les libellés vérifiés")
        }
    }

    /// Chaque illustration est livrée à iOS sous le nom qu'Android lui donne.
    @Test func chaqueIllustrationEstLivree() {
        for m in Hitbodedut.mouvements {
            let chemin = Depot.racine.appendingPathComponent("ios/Ressources/Images/\(m.illustration).webp").path
            let livree = FileManager.default.fileExists(atPath: chemin)
            #expect(livree, "« \(m.cle) » : \(m.illustration).webp manque")
        }
    }

    @Test func lesVecteursDeLaJVMSontRejoues() throws {
        let v = try vecteurs()
        let n = Hitbodedut.mouvements.count
        let lus = v.mouvements.count
        #expect(n == lus, "nombre de temps")
        for (m, lu) in zip(Hitbodedut.mouvements, v.mouvements) {
            let memeHebreu = m.he.egalUnites(lu.he)
            #expect(m.cle == lu.cle)
            #expect(memeHebreu, "« \(lu.cle) » : l'hébreu n'est pas celui du Kotlin")
            #expect(m.titre == lu.titre, "« \(lu.cle) » : titre")
            #expect(m.invite == lu.invite, "« \(lu.cle) » : invitation")
            #expect(m.illustration == lu.illustration, "« \(lu.cle) » : illustration")
            #expect(m.source == lu.source, "« \(lu.cle) » : source")
        }
        #expect(Hitbodedut.sourceLikoutei == v.sources.likoutei)
        #expect(Hitbodedut.sourceRambam == v.sources.rambam)
        #expect(Hitbodedut.dernier == v.dernier)

        for p in v.parcours {
            let ou = "indice \(p.index)"
            let cle = Hitbodedut.mouvement(p.index).cle
            let suivant = Hitbodedut.suivant(p.index)
            let precedent = Hitbodedut.precedent(p.index)
            let estPremier = Hitbodedut.estPremier(p.index)
            let estDernier = Hitbodedut.estDernier(p.index)
            // Là où Kotlin déborde, l'indice est hors des bornes : Swift y rend la borne.
            let suivantAttendu = p.suivant ?? Hitbodedut.dernier
            let precedentAttendu = p.precedent ?? 0
            #expect(cle == p.mouvement, "\(ou) : mouvement")
            #expect(suivant == suivantAttendu, "\(ou) : suivant")
            #expect(precedent == precedentAttendu, "\(ou) : precedent")
            #expect(estPremier == p.estPremier, "\(ou) : estPremier")
            #expect(estDernier == p.estDernier, "\(ou) : estDernier")
        }

        // Les deux seuls écarts voulus : Kotlin y déborde (0 pour le suivant du plus grand indice,
        // le dernier pour le précédent du plus petit), Swift rend le résultat exact.
        let debordements = v.debordements.filter { $0.fonction.hasPrefix("Hitbodedut.") }
        let nDebordements = debordements.count
        #expect(nDebordements == 2)
        for d in debordements {
            let estSuivant = d.fonction == "Hitbodedut.suivant"
            let rendu = estSuivant ? Hitbodedut.suivant(d.entree) : Hitbodedut.precedent(d.entree)
            let exact = estSuivant ? Hitbodedut.dernier : 0
            #expect(rendu == exact, "\(d.fonction)(\(d.entree)) : Kotlin y déborde et rend \(d.kotlin)")
        }
    }

    /// Chaque section de guidee.json est rejouée par l'un des fichiers de la grappe (Hitbodedut,
    /// QuestionsBlocage, Theme, Adresse, Salutation, GuideSujets, Poses) : une section ajoutée au
    /// générateur sans son pendant en Swift se voit ici.
    @Test func chaqueSectionDesVecteursEstRejouee() throws {
        let brut = try JSONSerialization.jsonObject(with: Depot.donnees(Self.chemin)) as? [String: Any]
        let racine = try #require(brut)
        let sections = Set(racine.keys)
        let rejouees: Set<String> = [
            "_meta",
            "mouvements", "sources", "dernier", "parcours", "debordements",
            "questions", "suivantes",
            "themes", "themesLus", "frequents",
            "adresses", "adresseNeutre", "adressesLues",
            "heures",
            "guideLangues", "guideReel", "guideForgeTexte", "guideForgeLangues", "guideForge",
            "poses", "posesMoments", "posesJours",
        ]
        #expect(sections == rejouees)
    }
}
