import Foundation
import Testing
@testable import Coeur

/// DanseMesureTest d'Android, porté : deux pas qui s'enchaînent sans à-coup. Puis tout
/// `Tests/Vecteurs/danse_mesure.json`, écrit par la JVM (tools/vecteurs_ios/VecteursDanseMesure.kt) :
/// le pas bit pour bit à chaque instant (la hauteur et la balance, qui passent par un sinus de la
/// bibliothèque mathématique, à un ulp près). Reste à Android « la scène porte les deux poses de
/// danse », qui lit le layout et le code de CelebrationActivity.
@Suite("Mesure de la danse")
struct DanseMesureTests {

    private let instants: [Float] = (0...400).map { Float($0) / 400 }

    private func dansBornes(_ x: Float, _ bas: Float, _ haut: Float) -> Bool {
        x >= bas && x <= haut
    }

    @Test func chaqueValeurResteDansSesBornes() {
        for t in instants {
            let pas = DanseMesure.pas(t)
            let hauteur = dansBornes(pas.hauteur, 0, 1)
            #expect(hauteur, "hauteur à \(t)")
            let flexion = dansBornes(pas.flexion, 0, 1)
            #expect(flexion, "flexion à \(t)")
            let balance = dansBornes(pas.balance, -1, 1)
            #expect(balance, "balance à \(t)")
            let poseB = dansBornes(pas.poseB, 0, 1)
            #expect(poseB, "pose à \(t)")
        }
    }

    /// Aucun saut d'image : la boucle, et le passage d'un temps à l'autre, sont continus.
    @Test func leMouvementEstContinuBoucleComprise() {
        let suite = instants + [1]
        for k in 1..<suite.count {
            let a = suite[k - 1]
            let x = DanseMesure.pas(a)
            let y = DanseMesure.pas(suite[k])
            let hauteur = abs(x.hauteur - y.hauteur)
            #expect(hauteur < 0.05, "hauteur à \(a)")
            let balance = abs(x.balance - y.balance)
            #expect(balance < 0.05, "balance à \(a)")
            // Le relais des poses est bref (un dixième de temps) : il reste continu, simplement plus raide.
            let pose = abs(x.poseB - y.poseB)
            #expect(pose < 0.3, "pose à \(a)")
        }
    }

    @Test func ilChangeDeJambeAChaqueTempsEtToucheLeSolEnChangeant() {
        let cas: [(attendu: Float, obtenu: Float, nom: String)] = [
            (0, DanseMesure.pas(0.2).poseB, "pose à 0,2"),
            (1, DanseMesure.pas(0.7).poseB, "pose à 0,7"),
            (0, DanseMesure.pas(0).hauteur, "hauteur à 0"),
            (0, DanseMesure.pas(0.5).hauteur, "hauteur à 0,5"),
            (1, DanseMesure.pas(0.25).hauteur, "hauteur à 0,25"),
            (1, DanseMesure.pas(0.5).flexion, "flexion à 0,5"),
        ]
        for c in cas {
            let ecart = abs(c.attendu - c.obtenu)
            #expect(ecart <= 0.001, "\(c.nom) : \(c.obtenu)")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        let tempsMs: Int64
        /// [t, hauteur, flexion, balance, poseB] : t par ses bits bruts, les champs par `floatToIntBits` (un NaN unique).
        let pas: [[Int32]]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/danse_mesure.json"))
    }

    /// `floatToIntBits` de Java : les bits du nombre, un seul NaN.
    private func bits(_ x: Float) -> Int32 {
        x.isNaN ? Int32(0x7FC0_0000) : Int32(bitPattern: x.bitPattern)
    }

    /// Les mêmes bits, ou deux flottants voisins (un ulp) : l'écart permis à un sinus d'une autre bibliothèque.
    private func voisins(_ a: Int32, _ b: Int32) -> Bool {
        abs(Int64(a) - Int64(b)) <= 1
    }

    @Test func leTempsEstCeluiDAndroid() throws {
        let v = try vecteurs()
        #expect(DanseMesure.tempsMs == v.tempsMs)
    }

    @Test func chaqueInstantDonneLePasDAndroid() throws {
        let v = try vecteurs()
        let nombre = v.pas.count
        #expect(nombre > 600)
        for ligne in v.pas {
            #expect(ligne.count == 5, "ligne mal formée : \(ligne)")
            if ligne.count != 5 { continue }
            let t = Float(bitPattern: UInt32(bitPattern: ligne[0]))
            let pas = DanseMesure.pas(t)
            let hauteur = voisins(bits(pas.hauteur), ligne[1])
            #expect(hauteur, "hauteur à \(t) : \(pas.hauteur)")
            let flexion = bits(pas.flexion)
            #expect(flexion == ligne[2], "flexion à \(t) : \(pas.flexion)")
            let balance = voisins(bits(pas.balance), ligne[3])
            #expect(balance, "balance à \(t) : \(pas.balance)")
            let poseB = bits(pas.poseB)
            #expect(poseB == ligne[4], "pose à \(t) : \(pas.poseB)")
        }
    }
}
