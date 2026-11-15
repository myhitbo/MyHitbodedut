import Testing
@testable import Coeur

/// CheminTropheesTest d'Android, porté : le chemin des trophées (15/10), une seule liste, du plus facile au plus
/// dur, et le prochain. Rien ne reste à Android ; les vecteurs sont rejoués par TropheesTests.
@Suite("Chemin des trophées")
struct CheminTropheesTests {

    /// Kotlin : `serie` vaut par défaut le nombre de jours.
    private func pratique(_ jours: Int, minutes: Int = 15, notes: Int = 0, serie: Int? = nil) -> Trophees.Pratique {
        let debut = JourCivil.du("2026-09-01")
        var m: [JourCivil: Int] = [:]
        for i in 0..<max(jours, 0) { m[debut.plus(jours: i)] = minutes }
        return Trophees.Pratique(minutes: m, notes: notes, meilleureSerie: serie ?? jours)
    }

    @Test func tousLesNiveauxUneSeuleFoisDuPlusFacileAuPlusDur() {
        let c = Trophees.chemin
        var total = 0
        for f in Trophees.Famille.allCases { total += f.seuils.count }
        let nombre = c.count
        #expect(nombre == total)
        let distinctes = Set(c.map { $0.cle }).count
        #expect(distinctes == nombre)
        let premier = c[0]
        let premierPas = Trophees.Niveau(famille: .premierPas, rang: 1)
        #expect(premier == premierPas)
        let couts = c.map { Trophees.cout($0.famille, $0.seuil) }
        let tries = couts.sorted()
        #expect(tries == couts)
    }

    @Test func lesGagnesSontCeuxDesNiveauxEtLeProchainNEstPasGagne() throws {
        let p = pratique(11, notes: 15)
        let gagnes = Trophees.gagnes(p)
        var duChemin = Set<Trophees.Niveau>()
        for n in Trophees.chemin where Trophees.gagne(p, n) { duChemin.insert(n) }
        #expect(gagnes == duChemin)
        let n = try #require(Trophees.prochain(p))
        let gagne = Trophees.gagne(p, n)
        #expect(!gagne)
    }

    @Test func unMateriauParGrade() {
        let zero = Trophees.grade(0)
        #expect(zero == Trophees.Metal.bronze)
        let neuf = Trophees.grade(9)
        #expect(neuf == Trophees.Metal.bronze)
        let dix = Trophees.grade(10)
        #expect(dix == Trophees.Metal.argent)
        let vingtCinq = Trophees.grade(25)
        #expect(vingtCinq == Trophees.Metal.or)
        let soixante = Trophees.grade(60)
        #expect(soixante == Trophees.Metal.platine)
    }

    @Test func sansPratiqueLeProchainEstLaPremiereHitbodedout() {
        let prochain = Trophees.prochain(pratique(0))
        let premierPas = Trophees.Niveau(famille: .premierPas, rang: 1)
        #expect(prochain == premierPas)
    }

    @Test func leProchainEstLePlusProche() throws {
        // 11 jours d'affilée : la série de 15 est à 73 % ; 15 jours de pratique aussi, mais plus loin au chemin.
        let n = try #require(Trophees.prochain(pratique(11, notes: 0)))
        let fraction = Trophees.fraction(pratique(11), n)
        #expect(fraction >= 0.7)
    }
}
