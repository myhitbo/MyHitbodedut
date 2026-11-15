import Foundation
import Coeur

/// Le calcul des ambiances (AmbianceSynth d'Ambiance.kt, proposition 9, 19/10) : une boucle de 24 secondes,
/// bruit filtré, gouttes, vagues, oiseaux, crépitements, grillons, sans aucun fichier (l'audio livré est au
/// plafond, voir musique/README.md). Les mêmes échantillons qu'Android et que le site (web/src/js/ambiance.js) :
/// le générateur mulberry32 en arithmétique 32 bits à débordement, la graine 7, les mêmes opérations dans le
/// même ordre, les mêmes arrondis en simple précision (PORTAGE.md § 2.2.4).
///
/// Une règle, sans appareil : elle a sa place dans Coeur, où elle pourra descendre (voir le rapport de la
/// tâche 18). Le son lui-même (AmbiancePlayer, AudioTrack) est l'affaire de `MusiqueSortieAmbiance`.
public enum MusiqueAmbianceSynth {

    /// TAUX : les échantillons par seconde de la boucle jouée.
    public static let taux = 22_050
    /// SECONDES : la durée de la boucle.
    public static let secondes = 24
    /// La graine de toutes les ambiances, la même partout.
    public static let graine: Int32 = 7

    /// Le générateur pseudo-aléatoire du Kotlin (mulberry32), le même que sur le web : `Int` de Kotlin est un
    /// entier de 32 bits qui déborde en silence, d'où `&+`, `&*` et le décalage non signé de `UInt32`.
    private struct Hasard {
        private var a: UInt32

        init(graine: Int32) {
            a = UInt32(bitPattern: graine)
        }

        /// Un nombre de [0, 1[.
        mutating func suivant() -> Double {
            a = a &+ 0x6D2B_79F5
            var t = a
            t = (t ^ (t >> 15)) &* (t | 1)
            t = t ^ (t &+ ((t ^ (t >> 7)) &* (t | 61)))
            return Double(t ^ (t >> 14)) / 4_294_967_296.0
        }

        /// Un nombre de [−1, 1[.
        mutating func bruit() -> Double {
            suivant() * 2 - 1
        }
    }

    /// `AmbianceSynth.generer` : la boucle d'une ambiance, normalisée à un niveau doux (crête 0,6), avec un
    /// fondu de 50 ms aux deux bouts ; le silence rend des zéros. Là où le Kotlin lèverait (une boucle plus
    /// courte que ses fondus), rien ne plante ici : les fondus s'arrêtent au bout de la boucle.
    public static func generer(_ type: Ambiance, taux: Int = MusiqueAmbianceSynth.taux,
                               secondes: Int = MusiqueAmbianceSynth.secondes,
                               graine: Int32 = MusiqueAmbianceSynth.graine) -> [Float] {
        let n = max(0, taux * secondes)
        var s = [Float](repeating: 0, count: n)
        if type == .silence || n == 0 { return s }
        var h = Hasard(graine: graine)
        let tauxDouble = Double(taux)
        var bas = 0.0      // passe-bas
        var brun = 0.0     // bruit brun
        var goutte = 0.0   // enveloppe d'une goutte, d'un craquement
        var ton = 0.0      // phase d'un chant
        var chant = 0      // échantillons restants d'un chant
        var freq = 0.0
        for i in 0..<n {
            let t = Double(i) / tauxDouble
            let w = h.bruit()
            bas += 0.35 * (w - bas)
            brun = (brun + 0.02 * w) * 0.995
            let v: Double
            switch type {
            case .pluie:
                if h.suivant() < 0.0008 {
                    goutte = 0.25 + 0.35 * h.suivant()
                }
                goutte *= 0.985
                v = 0.22 * (w - bas) + 0.18 * bas + goutte * h.bruit()
            case .mer:
                // Une vague toutes les 8 secondes : 3 par boucle, sans couture.
                let vague = 0.5 - 0.5 * cos(2 * Double.pi * t / 8.0)
                v = (0.12 + 0.7 * vague * vague) * (1.6 * brun + 0.25 * bas)
            case .foret:
                let vent = 0.6 + 0.4 * sin(2 * Double.pi * t / 12.0)
                // `chant <= 0 && h.suivant() < …` du Kotlin : le tirage n'a lieu que hors d'un chant.
                if chant <= 0 {
                    if h.suivant() < 1.0 / (tauxDouble * 2.5) {
                        chant = Kotlin.versInt(0.1 * tauxDouble)
                        freq = 2_600 + 1_200 * h.suivant()
                    }
                }
                var oiseau = 0.0
                if chant > 0 {
                    let p = 1 - Double(chant) / (0.1 * tauxDouble)
                    ton += 2 * Double.pi * (freq + 900 * p) / tauxDouble
                    oiseau = 0.1 * sin(ton) * sin(Double.pi * p)
                    chant -= 1
                }
                v = 0.9 * vent * brun + 0.05 * bas + oiseau
            case .feu:
                if h.suivant() < 0.0025 {
                    goutte = 0.2 + 0.5 * h.suivant()
                }
                goutte *= 0.9
                v = 1.4 * brun + goutte * h.bruit()
            case .nuit:
                // Des grillons : trois impulsions de 4,5 kHz, à peu près chaque seconde. `%` du Kotlin sur un
                // Double est le reste tronqué.
                let cycle = t.truncatingRemainder(dividingBy: 1.0)
                let impulsion = cycle < 0.15 && Kotlin.versInt(cycle * 20) % 2 == 0
                let grillon = impulsion ? 0.05 * sin(2 * Double.pi * 4_500 * t) : 0.0
                v = 0.5 * brun + grillon
            case .silence:
                v = 0
            }
            s[i] = Float(v)
        }
        // Normalisé à un niveau doux, jamais saturé : le calcul est en simple précision, comme le Kotlin.
        var crete: Float = 0
        for x in s {
            crete = max(crete, abs(x))
        }
        crete = max(crete, 1e-6)
        let gain: Float = min(0.6 / crete, 4)
        for i in 0..<n {
            s[i] *= gain
        }
        // Fondu de 50 ms aux deux bouts : la boucle ne claque pas à la reprise.
        let f = taux / 20
        for i in 0..<min(max(f, 0), n) {
            let g = Float(i) / Float(f)
            s[i] *= g
            s[n - 1 - i] *= g
        }
        return s
    }

    /// `AmbianceSynth.rms` : la racine de la moyenne des carrés (chaque carré en simple précision, la somme en
    /// double, comme le Kotlin).
    public static func rms(_ s: [Float]) -> Double {
        var somme = 0.0
        for x in s {
            somme += Double(x * x)
        }
        return (somme / Double(max(1, s.count))).squareRoot()
    }

    /// Les échantillons de 16 bits qu'AmbiancePlayer écrit dans sa piste (PCM mono) :
    /// `(f * Short.MAX_VALUE).toInt().toShort()`.
    public static func pcm(_ s: [Float]) -> [Int16] {
        s.map { x in Int16(truncatingIfNeeded: Kotlin.versInt32(Double(x * 32_767))) }
    }
}
