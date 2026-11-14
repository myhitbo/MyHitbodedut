import Foundation

/// Israël ou diaspora d'après la position (TerritoireIsrael.kt, 16/10) : un point dans le territoire,
/// l'État d'Israël avec Jérusalem, la Judée-Samarie et le Golan, de la frontière libanaise à Eilat,
/// du Jourdain et de la Arava à la mer. Avant, seul le fuseau du téléphone en décidait.
///
/// Contour simplifié (une quarantaine de points relevés sur la carte, précision de l'ordre de 2 à
/// 3 km) : suffisant pour savoir si l'on est en Israël, pas pour arbitrer à quelques centaines de
/// mètres d'une frontière ; le réglage « Israël / diaspora » reste là pour ça. La question
/// halakhique des limites de la Terre d'Israël n'est pas tranchée ici. La bande de Gaza est dans le
/// contour, qui suit la côte depuis Rafia'h : choix géographique, sans prise de position sur son
/// statut pour le deuxième jour de fête.
///
/// Le tracé de rayon n'est que de l'arithmétique : `geo.json` (VecteursGeo.kt) le vérifie à
/// l'identique sur une grille autour d'Israël et sur le bord.
public enum TerritoireIsrael {

    /// (latitude, longitude), dans l'ordre : la côte vers le nord, le Liban, le Golan, le Jourdain, la
    /// Arava, l'Égypte. Recopié du Kotlin par programme ; interne, pour que le test le compare au
    /// contour que la JVM lit dans TerritoireIsrael.kt.
    static let contour: [[Double]] = [
        [31.23, 34.21], [31.36, 34.24], [31.55, 34.40], [31.72, 34.50],
        [31.95, 34.66], [32.10, 34.72], [32.33, 34.80], [32.55, 34.86],
        [32.75, 34.92], [32.84, 34.93], [32.93, 35.03], [33.09, 35.08],
        // La frontière libanaise, de Roch Hanikra à Metoula, puis l'Hermon.
        [33.10, 35.20], [33.09, 35.33], [33.08, 35.45], [33.11, 35.52],
        [33.20, 35.55], [33.28, 35.57], [33.31, 35.63], [33.33, 35.79],
        // Le Golan, à l'est, jusqu'à 'Hamat Gader ; la ligne passe entre Ein Zivan et Kuneitra (audit du 16/10).
        [33.22, 35.82], [33.13, 35.815], [33.05, 35.86], [32.93, 35.87], [32.78, 35.80],
        [32.70, 35.72], [32.66, 35.62],
        // Le Jourdain et la mer Morte.
        [32.45, 35.57], [32.20, 35.56], [31.95, 35.55], [31.76, 35.56],
        [31.45, 35.50], [31.15, 35.45],
        // La Arava, jusqu'à Eilat et Taba.
        [30.85, 35.36], [30.50, 35.22], [30.15, 35.14], [29.90, 35.09], [29.70, 35.03],
        [29.55, 34.98], [29.49, 34.90],
        // La frontière égyptienne, jusqu'à Kerem Chalom et Rafia'h.
        [29.80, 34.76], [30.20, 34.60], [30.60, 34.50], [30.95, 34.37],
        [31.22, 34.26],
    ]

    /// Le point est-il dans le contour (tracé de rayon) ?
    public static func contient(_ latitude: Double, _ longitude: Double) -> Bool {
        var dedans = false
        var j = contour.count - 1
        for i in contour.indices {
            let yi = contour[i][0]
            let xi = contour[i][1]
            let yj = contour[j][0]
            let xj = contour[j][1]
            if (yi > latitude) != (yj > latitude) && longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi {
                dedans.toggle()
            }
            j = i
        }
        return dedans
    }
}
