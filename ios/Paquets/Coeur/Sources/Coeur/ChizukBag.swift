/// La rotation des textes : un sac mélangé par moment (ChizukBag.kt).
///
/// Tirer au hasard à chaque fois redonne le même texte deux fois de suite une fois sur N. On tire
/// donc sans remise : le sac garde les textes qui n'ont pas encore servi, et ne se remplit à
/// nouveau, mélangé, que lorsqu'il est vide.
///
/// Seule la logique est ici : `next` est une fonction pure de l'état du sac, et le mélange y est
/// injecté pour que les tirages se rejouent. L'écriture du sac dans les préférences (`draw`, par
/// Store.chizukBag et Store.setChizukBag) est à part. Les identifiants se comparent unité UTF-16 par
/// unité, comme en Kotlin.
/// Jugée par `Tests/Vecteurs/chizuk.json` (tools/vecteurs_ios/VecteursChizuk.kt).
public enum ChizukBag {

    /// Ce qu'un tirage rend : le texte sorti, et le sac tel qu'il reste.
    public struct Draw: Sendable, Equatable {
        public let id: String?
        public let remaining: [String]

        public init(id: String?, remaining: [String]) {
            self.id = id
            self.remaining = remaining
        }
    }

    /// Tire le prochain identifiant.
    ///
    /// - Parameters:
    ///   - remaining: ce qu'il restait du sac, tel qu'il a été relu.
    ///   - pool: les identifiants actuellement affichables pour ce moment.
    ///   - last: le dernier identifiant sorti, pour ne pas le redonner aussitôt quand un cycle
    ///     recommence.
    ///   - shuffle: le mélange, injecté pour que les tests soient déterministes (`HasardKotlin.melange`
    ///     pour rejouer ceux d'Android).
    public static func next(
        remaining: [String],
        pool: [String],
        last: String? = nil,
        shuffle: ([String]) -> [String] = { $0.shuffled() }
    ) -> Draw {
        if pool.isEmpty { return Draw(id: nil, remaining: []) }

        // Un texte retiré des données, ou devenu non publiable, ne doit pas ressortir : le sac est
        // filtré sur le vivier avant d'être lu.
        let usable = remaining.filter { contient(pool, $0) }
        let bag = usable.isEmpty ? refill(pool, last: last, shuffle: shuffle) : usable
        // Un mélange qui perdrait tout le vivier ferait lever Kotlin (`first()`) : ici, rien ne sort.
        guard let premier = bag.first else { return Draw(id: nil, remaining: []) }
        return Draw(id: premier, remaining: Array(bag.dropFirst()))
    }

    /// Remplit un sac vide.
    ///
    /// Le tirage sans remise laisse passer une seule répétition immédiate : celle du dernier texte
    /// d'un cycle qui ouvrirait le suivant. On la retire en renvoyant ce texte en fin de sac.
    private static func refill(_ pool: [String], last: String?, shuffle: ([String]) -> [String]) -> [String] {
        let shuffled = shuffle(pool)
        if pool.count > 1, let tete = shuffled.first, let last, tete.egalUnites(last) {
            return Array(shuffled.dropFirst()) + [tete]
        }
        return shuffled
    }

    /// `id in pool` de Kotlin.
    private static func contient(_ liste: [String], _ id: String) -> Bool {
        liste.contains { $0.egalUnites(id) }
    }
}
