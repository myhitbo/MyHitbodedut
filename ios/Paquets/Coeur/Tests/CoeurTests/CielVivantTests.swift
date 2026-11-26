import Foundation
import Testing
@testable import Coeur

/// CielVivantTest d'Android, porté : les petites animations des ciels (24/11, `CielVivant`) — lentes, de faible
/// amplitude, jamais plus vives que le ciel immobile, et coupées quand l'appareil le demande. Les vues SwiftUI ne
/// compilent pas sous Linux : ce qui les arrête est relu dans leur source, comme Android relit les siennes.
@Suite("Ciel vivant")
struct CielVivantTests {

    /// Deux minutes, image par image (20 par seconde).
    private let secondes = (0...2400).map { Double($0) * 0.05 }

    @Test func leCielNeBougeQueSiLAppareilLePermet() {
        #expect(CielVivant.permis(reduireAnimations: false, economieDEnergie: false))
        #expect(!CielVivant.permis(reduireAnimations: true, economieDEnergie: false), "Réduire les animations")
        #expect(!CielVivant.permis(reduireAnimations: false, economieDEnergie: true), "Économie d'énergie")
        #expect(!CielVivant.permis(reduireAnimations: true, economieDEnergie: true))
        // Permis, il ne bouge encore que l'app active et l'écran devant.
        #expect(CielVivant.enMarche(permis: true, sceneActive: true, visible: true))
        #expect(!CielVivant.enMarche(permis: true, sceneActive: false, visible: true), "scène inactive")
        #expect(!CielVivant.enMarche(permis: true, sceneActive: true, visible: false), "écran hors de vue")
        #expect(!CielVivant.enMarche(permis: false, sceneActive: true, visible: true))
    }

    @Test func desMouvementsLentsEntre8Et40Secondes() {
        for cycle in [CielVivant.scintillementMinS, CielVivant.scintillementMaxS, CielVivant.deriveXS,
                      CielVivant.deriveYS, CielVivant.souffleS] {
            #expect((8.0...40.0).contains(cycle), "cycle de \(cycle) s")
        }
        // Les nuages traversent un écran de 400 points en plus de deux minutes.
        #expect(400 / CielVivant.nuageDpS > 120 && 400 / CielVivant.voileDpS > 120)
        // Au plus 20 images par seconde : 0,15 point par image au plus pour le plus rapide.
        #expect(CielVivant.imageMs >= 33)
        #expect(CielVivant.nuageDpS * Float(CielVivant.imageMs) / 1000 <= 0.2)
    }

    @Test func lesEtoilesScintillentSansJamaisDepasserLeurEclatImmobile() {
        let e = CielVivant.etoiles(40, graine: 29, rayonMin: 0.7, rayonMax: 1.7)
        for i in 0..<40 {
            let periode = Double(e[i * CielVivant.champs + 3])
            let phase = Double(e[i * CielVivant.champs + 4])
            #expect((CielVivant.scintillementMinS...CielVivant.scintillementMaxS).contains(periode))
            let eclats = secondes.map { CielVivant.scintillement($0, periode: periode, phase: phase) }
            #expect(eclats.allSatisfy { $0 <= 1 && $0 >= CielVivant.scintillementBas - 1e-4 })
            // Un vrai scintillement : il descend près du bas et remonte près du plein.
            #expect((eclats.min() ?? 1) < CielVivant.scintillementBas + 0.05 && (eclats.max() ?? 0) > 0.95)
            // Lent : d'une image à l'autre, moins de 3 % d'éclat.
            #expect(zip(eclats, eclats.dropFirst()).allSatisfy { abs($0 - $1) < 0.03 })
        }
        // Le même ciel d'une ouverture à l'autre.
        #expect(e == CielVivant.etoiles(40, graine: 29, rayonMin: 0.7, rayonMax: 1.7))
    }

    /// Les étoiles sont celles d'Android : java.util.Random, mêmes graines, mêmes tirages (relevés sur la JVM).
    @Test func leHasardEstCeluiDeJava() {
        var r = HasardJava(graine: 29)
        let premiers = (0..<5).map { _ in r.nextFloat() }
        #expect(premiers == [0.7312365, 0.024344325, 0.7319032, 0.20306146, 0.9265251])
        var s = HasardJava(graine: -7)
        #expect(s.nextInt() == 1_155_869_324)
        #expect(s.nextInt() == -423_064_701)
        let e = CielVivant.etoiles(1, graine: 29, rayonMin: 0.7, rayonMax: 1.7)
        #expect(e[0] == 0.7312365 && e[1] == 0.024344325)
    }

    @Test func leChampDEtoilesDeriveDeQuelquesPointsAuPlus() {
        for s in secondes {
            #expect(abs(CielVivant.deriveX(s)) <= CielVivant.deriveXDp + 1e-4)
            #expect(abs(CielVivant.deriveY(s)) <= CielVivant.deriveYDp + 1e-4)
        }
        #expect(abs(CielVivant.deriveX(0)) < 1e-6)
    }

    @Test func leHaloRespireSansJamaisGrandirNiSEclaircir() {
        for s in secondes {
            let taille = CielVivant.tailleHalo(s)
            let eclat = CielVivant.eclatHalo(s)
            #expect(taille >= 1 - CielVivant.souffleTaille - 1e-4 && taille <= 1)
            #expect(eclat >= 1 - CielVivant.souffleEclat - 1e-4 && eclat <= 1)
        }
        // Au repos (t = 0), le halo du ciel immobile ; au creux, six secondes plus tard.
        #expect(abs(CielVivant.tailleHalo(0) - 1) < 1e-6)
        #expect(abs(CielVivant.tailleHalo(CielVivant.souffleS / 2) - (1 - CielVivant.souffleTaille)) < 1e-4)
        #expect(abs(CielVivant.eclatHalo(CielVivant.souffleS) - 1) < 1e-4)
    }

    @Test func unNuageSortiADroiteRevientParLaGauche() {
        let l = 400.0
        let n = 120.0
        #expect(abs(CielVivant.nuageX(depart: 50, vitesse: 3, secondes: 0, largeurCiel: l, largeurNuage: n) - 50) < 1e-3)
        #expect(abs(CielVivant.nuageX(depart: 50, vitesse: 3, secondes: 10, largeurCiel: l, largeurNuage: n) - 80) < 1e-3)
        for s in secondes {
            let x = CielVivant.nuageX(depart: 50, vitesse: 3, secondes: s * 3, largeurCiel: l, largeurNuage: n)
            #expect(x >= -n - 1e-3 && x < l)
        }
        // Juste sorti à droite (bord gauche au bord du ciel) : il réapparaît entièrement caché à gauche.
        #expect(abs(CielVivant.nuageX(depart: -n, vitesse: 4, secondes: 130, largeurCiel: l, largeurNuage: n) + n) < 1e-2)
        #expect(abs(CielVivant.nuageX(depart: -n, vitesse: 4, secondes: 129, largeurCiel: l, largeurNuage: n) - (l - 4)) < 1e-2)
    }

    // MARK: Les vues, relues

    private func source(_ nom: String) throws -> String {
        String(decoding: try Depot.donnees("ios/Paquets/Coeur/Sources/Vues/\(nom).swift"), as: UTF8.self)
    }

    /// Ce qui arrête le battement : « Réduire les animations », le mode Économie d'énergie, la scène qui n'est plus
    /// active, l'écran qui n'est plus devant ; au plus 20 images par seconde ; immobile, le ciel reste dessiné.
    @Test func lHorlogeSArreteHorsDeLEcranEtSansAnimations() throws {
        let code = try source("CielVivantVue")
        for attendu in ["accessibilityReduceMotion", "isLowPowerModeEnabled", "NSProcessInfoPowerStateDidChange",
                        "scenePhase", ".onAppear", ".onDisappear",
                        "CielVivant.enMarche(permis: CielVivant.permis(reduireAnimations: reduire, economieDEnergie: economie)",
                        "TimelineView(.animation(minimumInterval: Double(CielVivant.imageMs) / 1000, paused: !enMarche))"] {
            #expect(code.contains(attendu), "CielVivantVue ne contient plus « \(attendu) »")
        }
        // Les deux ciels animés passent par lui, et restent décoratifs pour VoiceOver.
        for nom in ["CielPageVue", "SereniteVue"] {
            let vue = try source(nom)
            #expect(vue.contains("CielVivantHorloge"), "\(nom) n'anime plus son ciel par CielVivantHorloge")
            #expect(vue.contains(".accessibilityHidden(true)"), "\(nom) : le ciel doit rester caché à VoiceOver")
        }
    }

    /// Les écrans de lecture et la séance ne reçoivent aucun ciel animé.
    @Test func rienNeBougeDerriereUnTexteQuOnLit() throws {
        let dossier = Depot.racine.appendingPathComponent("ios/Paquets/Coeur/Sources/Vues")
        let fichiers = try FileManager.default.contentsOfDirectory(atPath: dossier.path).filter { $0.hasSuffix(".swift") }
        var avecCiel: Set<String> = []
        for f in fichiers {
            let texte = String(decoding: try Data(contentsOf: dossier.appendingPathComponent(f)), as: UTF8.self)
            if ["CielPageVue", "SereniteCiel", "CielVivantHorloge"].contains(where: texte.contains) {
                avecCiel.insert(String(f.dropLast(".swift".count)))
            }
        }
        // L'accueil Instant pose le paysage de Sérénité sous sa carte du ciel (InstantActivity, 17/11) : un accueil,
        // pas un texte qu'on lit.
        #expect(avecCiel == ["CielPageVue", "CielVivantVue", "AccueilVue", "SereniteVue", "InstantVue"])
    }
}
