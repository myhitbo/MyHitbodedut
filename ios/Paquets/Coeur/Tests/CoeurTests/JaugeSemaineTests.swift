import Foundation
import Testing
@testable import Coeur

/// JaugeSemaineTest d'Android, porté : les jours faits de la semaine, sur les jours dus. Puis tout
/// `Tests/Vecteurs/jauge_semaine.json`, écrit par la JVM (tools/vecteurs_ios/VecteursJaugeSemaine.kt) :
/// les bandes, la fraction de la jauge bit pour bit, et la durée courte de DureeCourteTest
/// (DureeCourteTests.swift en porte les cas). Rien ne reste à Android.
@Suite("Jauge de la semaine")
struct JaugeSemaineTests {

    private let dimanche = JourCivil.du("2026-09-27")

    // Les lettres d'une case, comme dans JaugeSemaineTest : faite, exemptée, à venir, et le Chabbat.
    private static let faite: Character = "f"
    private static let exemptee: Character = "x"
    private static let aVenir: Character = "a"
    private static let chabbat: Character = "s"

    /// Le `semaine(vararg etats)` du test Kotlin : un jour par état depuis le dimanche, le septième est le Chabbat.
    private func semaine(_ etats: String...) -> [CaseSemaine] {
        var jours: [CaseSemaine] = []
        for (i, e) in etats.enumerated() {
            jours.append(CaseSemaine(date: dimanche.plus(jours: i), done: e.contains(Self.faite),
                                     exempt: e.contains(Self.exemptee), shabbat: i == 6, future: e.contains(Self.aVenir)))
        }
        return jours
    }

    @Test func leChabbatChomeNeComptePasParmiLesJoursDus() {
        let p = JaugeSemaine.progression(semaine("f", "f", "", "a", "a", "a", "x"))
        let faits = p.faits
        #expect(faits == 2)
        let dus = p.dus
        #expect(dus == 6)
        let ecart = abs(Float(2) / Float(6) - p.fraction)
        #expect(ecart <= 0.0001, "fraction : \(p.fraction)")
    }

    @Test func uneSeanceFaiteUnJourExempteCompteQuandMeme() {
        let p = JaugeSemaine.progression(semaine("f", "f", "f", "f", "f", "f", "fx"))
        let faits = p.faits
        #expect(faits == 7)
        let dus = p.dus
        #expect(dus == 7)
        let ecart = abs(1 - p.fraction)
        #expect(ecart <= 0.0001, "fraction : \(p.fraction)")
    }

    @Test func uneSemaineSansJourDuResteVide() {
        let p = JaugeSemaine.progression(semaine("x", "x", "x", "x", "x", "x", "x"))
        let fraction = p.fraction
        #expect(fraction == 0)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// Une bande : ses cases écrites en lettres, la première au jour « debut ».
        struct Bande: Decodable {
            let debut: String
            let cases: [String]
            let faits: Int
            let dus: Int
            let fraction: Double
            let bitsFraction: Int32
        }
        /// La fraction d'une progression ; ses bits (`floatToRawIntBits`) disent aussi le signe d'un zéro.
        struct Fraction: Decodable {
            let faits: Int
            let dus: Int
            let fraction: Double
            let bitsFraction: Int32
        }
        struct Duree: Decodable {
            let minutes: Int
            let texte: String
        }
        /// `textes[i]` : la durée courte de `premier + i` minutes.
        struct Suivies: Decodable {
            let premier: Int
            let textes: [String]
        }

        let semaines: [Bande]
        let fractions: [Fraction]
        let dureesCourtes: [Duree]
        let dureesSuivies: Suivies
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/jauge_semaine.json"))
    }

    private func bits(_ x: Float) -> Int32 {
        Int32(bitPattern: x.bitPattern)
    }

    @Test func chaqueBandeSeCompteCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.semaines.count
        #expect(nombre > 250)
        for b in v.semaines {
            let debut = try #require(JourCivil(iso: b.debut), "jour illisible : \(b.debut)")
            var jours: [CaseSemaine] = []
            for (i, e) in b.cases.enumerated() {
                jours.append(CaseSemaine(date: debut.plus(jours: i), done: e.contains(Self.faite), exempt: e.contains(Self.exemptee),
                                         shabbat: e.contains(Self.chabbat), future: e.contains(Self.aVenir)))
            }
            let p = JaugeSemaine.progression(jours)
            let contexte = "\(b.debut) \(b.cases)"
            let faits = p.faits
            #expect(faits == b.faits, "\(contexte)")
            let dus = p.dus
            #expect(dus == b.dus, "\(contexte)")
            let bitsFraction = bits(p.fraction)
            #expect(bitsFraction == b.bitsFraction, "\(contexte) : \(p.fraction), Android \(b.fraction)")
        }
    }

    /// Simple précision, bornée à [0, 1] ; le zéro négatif (0 sur des jours dus négatifs) reste négatif.
    @Test func chaqueFractionCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.fractions.count
        #expect(nombre > 150)
        for cas in v.fractions {
            let p = JaugeSemaine.Progression(faits: cas.faits, dus: cas.dus)
            let bitsFraction = bits(p.fraction)
            #expect(bitsFraction == cas.bitsFraction, "\(cas.faits) sur \(cas.dus) : \(p.fraction), Android \(cas.fraction)")
        }
    }

    @Test func chaqueDureeCourteCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.dureesCourtes.count
        #expect(nombre > 30)
        for cas in v.dureesCourtes {
            let texte = JaugeSemaine.dureeCourte(cas.minutes)
            #expect(texte == cas.texte, "dureeCourte(\(cas.minutes))")
            let unites = Array(texte.utf16)
            let attendues = Array(cas.texte.utf16)
            #expect(unites == attendues, "dureeCourte(\(cas.minutes)), unité par unité")
        }
        let suivies = v.dureesSuivies
        let suiviesNombre = suivies.textes.count
        #expect(suiviesNombre > 1000)
        for (rang, attendu) in suivies.textes.enumerated() {
            let minutes = suivies.premier + rang
            let texte = JaugeSemaine.dureeCourte(minutes)
            let unites = Array(texte.utf16)
            let attendues = Array(attendu.utf16)
            #expect(unites == attendues, "dureeCourte(\(minutes)) : « \(texte) », Android « \(attendu) »")
        }
    }
}
