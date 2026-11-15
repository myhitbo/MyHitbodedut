import Foundation
import Testing
import Coeur
@testable import Ecrans

/// AmbianceTest d'Android, porté avec ses échantillons : chaque ambiance s'entend sans saturer, le silence se
/// tait, la boucle commence en fondu, le calcul est reproductible. Puis les échantillons eux-mêmes, que la JVM
/// a rendus pour le vrai AmbianceSynth d'Android (Ambiance.kt, graine 7) : au taux du test (8 000 par seconde)
/// et au taux joué (22 050), un échantillon tous les 6 007 (ou 33 083), sa valeur, son PCM de 16 bits, et la
/// moyenne quadratique de toute la boucle. Sous Linux, ils tombent à l'identique ; la tolérance (1e-6, un pas
/// de PCM) couvre un sinus d'Apple qui différerait d'une unité au dernier chiffre.
///
/// Le troisième cas d'AmbianceTest (aucun fichier d'ambiance n'est livré, une clé inconnue rend le silence)
/// est déjà porté dans CoeurTests/AmbianceTests.swift.
@Suite("Ambiances calculées (AmbianceTest)")
struct MusiqueAmbianceSynthTests {

    @Test func chaqueAmbianceSEntendSansSaturerEtLeSilenceSeTait() {
        for a in Ambiance.allCases {
            let s = MusiqueAmbianceSynth.generer(a, taux: 8_000, secondes: 24)
            #expect(s.count == 8_000 * 24, "\(a.cle)")
            var crete: Float = 0
            for x in s {
                crete = max(crete, abs(x))
            }
            if a == .silence {
                #expect(crete == 0)
            } else {
                let rms = MusiqueAmbianceSynth.rms(s)
                #expect(rms > 0.02, "\(a.cle) : trop faible")
                #expect(crete <= 0.61, "\(a.cle) : sature (\(crete))")
                let premier = s.first
                #expect(premier == 0, "\(a.cle) : la boucle doit commencer en fondu")
            }
        }
    }

    @Test func leCalculEstReproductible() {
        let premier = MusiqueAmbianceSynth.generer(.mer, taux: 8_000, secondes: 2)
        let second = MusiqueAmbianceSynth.generer(.mer, taux: 8_000, secondes: 2)
        #expect(premier == second)
        let longueur = premier.count
        #expect(longueur == 16_000)
    }

    @Test func lesEchantillonsSontCeuxDAndroid() {
        comparer(MusiqueEchantillonsAndroid.essai, taux: 8_000, pas: 6_007)
    }

    @Test func lesEchantillonsJouesSontCeuxDAndroid() {
        comparer(MusiqueEchantillonsAndroid.app, taux: MusiqueAmbianceSynth.taux, pas: 33_083)
    }

    @Test func laBoucleFinitAussiEnFonduEtLeSilenceNeRendQueDesZeros() {
        let s = MusiqueAmbianceSynth.generer(.pluie, taux: 8_000, secondes: 1)
        let dernier = s.last
        #expect(dernier == 0)
        let silence = MusiqueAmbianceSynth.generer(.silence, taux: 800, secondes: 1)
        let zeros = silence.allSatisfy { $0 == 0 }
        #expect(zeros)
        let pcm = MusiqueAmbianceSynth.pcm(silence)
        #expect(pcm.count == 800)
        // Une boucle plus courte que ses fondus ne plante pas.
        let vide = MusiqueAmbianceSynth.generer(.feu, taux: 8_000, secondes: 0)
        #expect(vide.isEmpty)
        let rms = MusiqueAmbianceSynth.rms(vide)
        #expect(rms == 0)
    }

    /// Chaque boucle d'Android, échantillon par échantillon.
    private func comparer(_ attendus: [MusiqueEchantillonsAndroid], taux: Int, pas: Int) {
        for attendu in attendus {
            let s = MusiqueAmbianceSynth.generer(attendu.ambiance, taux: taux, secondes: MusiqueAmbianceSynth.secondes)
            let pcm = MusiqueAmbianceSynth.pcm(s)
            let rms = MusiqueAmbianceSynth.rms(s)
            #expect(abs(rms - attendu.rms) <= 1e-9, "\(attendu.ambiance.cle) : rms \(rms)")
            let indices = Array(stride(from: 0, to: s.count, by: pas))
            #expect(indices.count == attendu.valeurs.count, "\(attendu.ambiance.cle)")
            #expect(indices.count == attendu.pcm.count, "\(attendu.ambiance.cle)")
            for (k, i) in indices.enumerated() where k < attendu.valeurs.count && k < attendu.pcm.count {
                let valeur = s[i]
                let ecart = abs(valeur - attendu.valeurs[k])
                #expect(ecart <= 1e-6, "\(attendu.ambiance.cle) [\(i)] : \(valeur) au lieu de \(attendu.valeurs[k])")
                let ecartPcm = abs(Int(pcm[i]) - Int(attendu.pcm[k]))
                #expect(ecartPcm <= 1, "\(attendu.ambiance.cle) [\(i)] : PCM \(pcm[i]) au lieu de \(attendu.pcm[k])")
            }
        }
    }
}

/// Une boucle d'Android : sa moyenne quadratique, puis un échantillon sur `pas`, en valeur et en PCM.
private struct MusiqueEchantillonsAndroid: Sendable {
    let ambiance: Ambiance
    let rms: Double
    let valeurs: [Float]
    let pcm: [Int16]

    /// Écrit par la JVM avec le vrai AmbianceSynth (AmbianceSynth.generer(a, 8000, 24, 7), un échantillon sur 6 007).
        static let essai: [MusiqueEchantillonsAndroid] = [
            MusiqueEchantillonsAndroid(
                ambiance: .pluie, rms: 0.10772950663060195,
                valeurs: [-0.0, 0.17721224, -0.07945124, -0.10201166, -0.08686873, -0.1542349,
                          0.06788674, -0.06596903, 0.04744715, 0.11069977, 0.11138626, 0.04620567,
                          -0.045723695, -0.066217296, -0.014368381, 0.009605447, -0.050888874, 0.124491714,
                          -0.1610879, -0.079204105, 0.16547346, -0.09676414, -0.14900568, -0.00940456,
                          0.0052721985, 0.08783322, -0.1161609, -0.04122601, -0.015724597, -0.116825536,
                          0.14254493, -0.14337413],
                pcm: [0, 5806, -2603, -3342, -2846, -5053, 2224, -2161, 1554, 3627, 3649, 1514,
                      -1498, -2169, -470, 314, -1667, 4079, -5278, -2595, 5422, -3170, -4882, -308,
                      172, 2878, -3806, -1350, -515, -3828, 4670, -4697]),
            MusiqueEchantillonsAndroid(
                ambiance: .mer, rms: 0.0728662552000721,
                valeurs: [-0.0, -0.015803449, 0.01293184, 0.09964175, -0.021125728, 0.028428193,
                          -0.10442123, 0.02298001, 0.037994016, -0.020930873, 0.012619963, -0.015190671,
                          -0.013641495, -0.0064466153, 0.14601746, 0.10500461, 0.08109169, 0.030781677,
                          -0.022592278, -0.0040080203, -0.011230208, 0.021145137, -0.010261738, 0.037520055,
                          0.00839771, -0.044255782, -0.27026597, -0.0022743822, -0.044670716, 0.023323445,
                          0.034698248, -0.005071746],
                pcm: [0, -517, 423, 3264, -692, 931, -3421, 752, 1244, -685, 413, -497,
                      -446, -211, 4784, 3440, 2657, 1008, -740, -131, -367, 692, -336, 1229,
                      275, -1450, -8855, -74, -1463, 764, 1136, -166]),
            MusiqueEchantillonsAndroid(
                ambiance: .foret, rms: 0.1042146234739467,
                valeurs: [-0.0, 0.16677514, 0.06323674, -0.109308764, 0.03219706, 0.14242941,
                          -0.14835905, 0.21444969, 0.104414575, -0.10119133, 0.089962825, -0.09023256,
                          -0.043143094, -0.019367725, 0.0012177945, 0.010637054, -0.013080824, -0.031642675,
                          0.16711128, -0.40562853, 0.10049231, 0.1319966, -0.28242603, -0.07559621,
                          -0.017356914, 0.065491445, 0.04475446, -0.08614196, 0.06602973, 0.06634457,
                          0.055877857, -0.029905874],
                pcm: [0, 5464, 2072, -3581, 1055, 4666, -4861, 7026, 3421, -3315, 2947, -2956,
                      -1413, -634, 39, 348, -428, -1036, 5475, -13291, 3292, 4325, -9254, -2477,
                      -568, 2145, 1466, -2822, 2163, 2173, 1830, -979]),
            MusiqueEchantillonsAndroid(
                ambiance: .feu, rms: 0.11448356481464453,
                valeurs: [-0.0, -0.024902936, 0.07673273, -0.12790799, 0.13623214, -0.07214744,
                          0.05006751, 0.15461996, 0.013763625, -0.009409413, 0.01130914, -0.012793349,
                          0.10181044, -0.1465891, 0.054646153, 0.03223323, -0.0039599636, -0.0487765,
                          -0.04822052, 0.010232751, -0.112607665, 0.016950503, -0.14898668, 0.046203323,
                          -0.174367, 0.06537333, 0.018356772, 0.16525912, -0.16940777, -0.10478304,
                          0.08697607, -0.03962904],
                pcm: [0, -815, 2514, -4191, 4463, -2364, 1640, 5066, 450, -308, 370, -419,
                      3336, -4803, 1790, 1056, -129, -1598, -1580, 335, -3689, 555, -4881, 1513,
                      -5713, 2142, 601, 5415, -5550, -3433, 2849, -1298]),
            MusiqueEchantillonsAndroid(
                ambiance: .nuit, rms: 0.13605479929766431,
                valeurs: [-0.0, -0.16040586, 0.032643918, 0.199017, -0.1051811, -0.030863676,
                          -0.17600138, 0.059847016, 0.10411188, -0.14942303, 0.09995766, -0.10174579,
                          0.088972785, -0.030978309, 0.23825498, 0.18106548, 0.0747881, -0.043030318,
                          -0.015947271, -0.028128162, -0.20000437, 0.15056968, -0.0317036, 0.18693846,
                          -0.016235156, -0.10886562, -0.3057079, 0.020310944, 0.03642025, 0.12961645,
                          0.15285766, 0.010357429],
                pcm: [0, -5256, 1069, 6521, -3446, -1011, -5767, 1961, 3411, -4896, 3275, -3333,
                      2915, -1015, 7806, 5932, 2450, -1409, -522, -921, -6553, 4933, -1038, 6125,
                      -531, -3567, -10017, 665, 1193, 4247, 5008, 339]),
        ]

    /// Au taux joué : AmbianceSynth.generer(a, 22050, 24, 7), un échantillon sur 33 083.
        static let app: [MusiqueEchantillonsAndroid] = [
            MusiqueEchantillonsAndroid(
                ambiance: .pluie, rms: 0.0983159747133716,
                valeurs: [-0.0, 0.01429791, 0.044362586, -0.09839132, -0.10411749, 0.14346437,
                          -0.12245394, 0.0642801, -0.07632307, 0.046431065, 0.11760541, 0.15371288,
                          0.11455221, -0.007193685, -0.109927356, -0.13449483],
                pcm: [0, 468, 1453, -3223, -3411, 4700, -4012, 2106, -2500, 1521, 3853, 5036,
                      3753, -235, -3601, -4406]),
            MusiqueEchantillonsAndroid(
                ambiance: .mer, rms: 0.07484869988420764,
                valeurs: [-0.0, 0.007424258, -0.07532253, -0.067008, -0.008915682, 0.020206338,
                          -0.013945575, 0.037452247, 0.2443007, -0.025431246, 0.030120347, -0.0068148626,
                          0.0014554623, -0.122339316, -0.04862804, -0.0076160445],
                pcm: [0, 243, -2468, -2195, -292, 662, -456, 1227, 8005, -833, 986, -223,
                      47, -4008, -1593, -249]),
            MusiqueEchantillonsAndroid(
                ambiance: .foret, rms: 0.09567001939858445,
                valeurs: [-0.0, -0.18510845, -0.0057062595, -0.22773871, 0.05771429, -0.037598494,
                          -0.025888303, -0.0048583695, -0.02606887, -0.058703523, 0.19517381, -0.057235394,
                          0.0709941, -0.043317404, -0.039440017, 0.03185932],
                pcm: [0, -6065, -186, -7462, 1891, -1231, -848, -159, -854, -1923, 6395, -1875,
                      2326, -1419, -1292, 1043]),
            MusiqueEchantillonsAndroid(
                ambiance: .feu, rms: 0.11532658033031776,
                valeurs: [-0.0, -0.18287618, 0.11582369, 0.034713138, -0.051464014, -0.02533939,
                          -0.021618174, -0.07259353, -0.18534034, -0.16257557, -0.061569385, -0.028218983,
                          -0.054624423, 0.118649796, 0.20931415, 0.029736064],
                pcm: [0, -5992, 3795, 1137, -1686, -830, -708, -2378, -6073, -5327, -2017, -924,
                      -1789, 3887, 6858, 974]),
            MusiqueEchantillonsAndroid(
                ambiance: .nuit, rms: 0.12792991449828678,
                valeurs: [-0.0, -0.03793249, 0.025099527, -0.120611496, -0.089853086, 0.20553726,
                          -0.150773, 0.110457174, 0.2867158, 0.025185594, 0.29262134, -0.060408235,
                          -0.032650884, -0.1629671, -0.16069068, 0.0328625],
                pcm: [0, -1242, 822, -3952, -2944, 6734, -4940, 3619, 9394, 825, 9588, -1979,
                      -1069, -5339, -5265, 1076]),
        ]
}
