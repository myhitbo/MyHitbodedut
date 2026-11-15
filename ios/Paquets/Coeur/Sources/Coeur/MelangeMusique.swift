/// La lecture aléatoire (MelangeMusique.kt, demande du 28/09) : un morceau au hasard, puis un autre, et
/// aucun ne revient avant que tous aient été entendus. Au passage d'un tour au suivant, le dernier
/// morceau joué n'ouvre pas le nouveau tour : sinon on l'entendrait deux fois de suite.
///
/// Ne manipule que des identifiants. Le hasard est celui de `kotlin.random.Random` (`HasardKotlin`) :
/// d'une même graine, iOS joue les morceaux dans l'ordre où Android les joue. Les identifiants se
/// comparent unité par unité, comme en Kotlin. Jugée par `Tests/Vecteurs/melange_musique.json`
/// (tools/vecteurs_ios/VecteursMelangeMusique.kt).
public struct MelangeMusique: Sendable {

    private var hasard: HasardKotlin

    /// Les morceaux du tour en cours qui n'ont pas encore joué, dans l'ordre où ils joueront.
    private var sac: [String] = []

    /// Le dernier morceau rendu par `suivant`.
    public private(set) var dernier: String?

    public init(hasard: HasardKotlin) {
        self.hasard = hasard
    }

    /// Sans hasard donné, une graine tirée au hasard : `Random.Default` de Kotlin.
    public init() {
        self.init(hasard: HasardKotlin(graineLongue: Int64.random(in: Int64.min...Int64.max)))
    }

    /// Le prochain morceau parmi `ids`, ou `nil` s'il n'y en a aucun.
    public mutating func suivant(_ ids: [String]) -> String? {
        if ids.isEmpty { return nil }
        // Un morceau retiré entre-temps de la bibliothèque ne doit plus sortir.
        let presents = Set(ids.map { Array($0.utf16) })
        sac.removeAll { !presents.contains(Array($0.utf16)) }
        if sac.isEmpty {
            // `distinct()` : chaque morceau une fois, à sa première place.
            var vus = Set<[UInt16]>()
            var distincts: [String] = []
            for id in ids {
                if vus.insert(Array(id.utf16)).inserted {
                    distincts.append(id)
                }
            }
            var tour = hasard.melange(distincts)
            if tour.count > 1, let precedent = dernier, tour[0].egalUnites(precedent) {
                tour.swapAt(0, tour.count - 1)
            }
            sac.append(contentsOf: tour)
        }
        let morceau = sac.removeFirst()
        dernier = morceau
        return morceau
    }
}
