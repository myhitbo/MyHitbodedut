import Foundation

/// Le ciel du Jour (CielDuJour.kt, étape 3 de la refonte d'Android, 14/11) : l'aube, le plein jour, le coucher ou la
/// nuit. D'après les zmanim du lieu quand on le connaît, sinon d'après l'heure du téléphone.
///
/// L'aube va d'alot hacha'har à une heure après le lever ; le coucher, d'une heure avant la chkia à tsét hakokhavim ;
/// la nuit, de tsét à alot. Un zman qui manque (nuit ou jour polaire, calcul impossible) renvoie aux heures fixes.
/// Les dessins (le dégradé de la plaque, le voile du haut de page) restent aux vues ; la règle et les couleurs sont
/// ici.
public enum CielDuJour {

    public enum Phase: String, Sendable, CaseIterable {
        case aube, jour, coucher, nuit
    }

    /// Ce que l'aube garde après le lever, et ce que le coucher prend avant la chkia (une heure).
    public static let margeMillis: Int64 = 60 * 60 * 1000

    /// Sans lieu : un matin et un soir moyens (`parHeure`).
    public static func parHeure(heure: Int, minute: Int) -> Phase {
        let m = heure * 60 + minute
        if m < 5 * 60 { return .nuit }
        if m < 8 * 60 { return .aube }
        if m < 17 * 60 { return .jour }
        if m < 20 * 60 { return .coucher }
        return .nuit
    }

    /// Avec les zmanim du jour, en millisecondes Unix : alot hacha'har, le lever (netz), la chkia et tsét. Un jour
    /// trop court pour un plein jour (l'aube finit après le début du coucher) passe de l'aube au coucher. Un zman
    /// absent : l'heure civile de `maintenant` décide.
    public static func phase(maintenant: DateHeureZonee, alot: Int64?, lever: Int64?, chkia: Int64?,
                             tset: Int64?) -> Phase {
        guard let alot, let lever, let chkia, let tset else {
            let civile = maintenant.civile
            return parHeure(heure: civile.heure, minute: civile.minute)
        }
        let t = maintenant.millis
        if t < alot { return .nuit }
        if t < lever + margeMillis { return .aube }
        if t < chkia - margeMillis { return .jour }
        if t < tset { return .coucher }
        return .nuit
    }

    /// Le ciel de `maintenant` au `lieu` (ses zmanim du jour civil du lieu) ; sans lieu, l'heure de `maintenant`
    /// (`CielDuJour.maintenant`). `maintenant` est déjà dans le fuseau du lieu quand il y en a un.
    public static func phase(maintenant: DateHeureZonee, lieu: Zmanim.Lieu?) -> Phase {
        guard let lieu else { return phase(maintenant: maintenant, alot: nil, lever: nil, chkia: nil, tset: nil) }
        var z: [String: Int64] = [:]
        for zman in Zmanim.jour(lieu: lieu, date: maintenant.jour) {
            if let instant = zman.instant {
                z[zman.cle] = Kotlin.versLong((instant.timeIntervalSince1970 * 1000).rounded())
            }
        }
        return phase(maintenant: maintenant, alot: z["alot"], lever: z["netz"], chkia: z["chkia"], tset: z["tset"])
    }

    /// Les couleurs d'un ciel (ARGB) : le dégradé (haut, milieu, horizon), la colline, l'astre et sa lueur, et le
    /// voile que prend le haut de l'écran. Celles du ciel, pas du thème : les mêmes de jour comme de nuit.
    public struct Palette: Sendable, Equatable {
        public let haut: UInt32
        public let milieu: UInt32
        public let horizon: UInt32
        public let colline: UInt32
        public let astre: UInt32
        public let lueur: UInt32
        public let voile: UInt32
    }

    public static func palette(_ phase: Phase) -> Palette {
        switch phase {
        case .aube: Palette(haut: 0xFF7B88C9, milieu: 0xFFE3A3BE, horizon: 0xFFFFD6AE, colline: 0xFF7E9F86,
                            astre: 0xFFFFE7B8, lueur: 0xFFFFE0A8, voile: 0xFFE8A0B4)
        case .jour: Palette(haut: 0xFF5FB1EA, milieu: 0xFFA8DAF6, horizon: 0xFFE6F6FC, colline: 0xFF7CC293,
                            astre: 0xFFFFE97A, lueur: 0xFFFFF6C8, voile: 0xFF6FB8EA)
        case .coucher: Palette(haut: 0xFF8A64B0, milieu: 0xFFE58397, horizon: 0xFFFDBA6E, colline: 0xFF6C5A80,
                               astre: 0xFFFFC46A, lueur: 0xFFFFAA5A, voile: 0xFFF08A5D)
        case .nuit: Palette(haut: 0xFF101B3D, milieu: 0xFF1F2F63, horizon: 0xFF33477F, colline: 0xFF1D2A4C,
                            astre: 0xFFF6F0D6, lueur: 0xFFF6F0D6, voile: 0xFF2C3E7A)
        }
    }

    /// L'icône devant la date hébraïque, en tête du Jour : le nom du dessin d'Android.
    public static func icone(_ phase: Phase) -> String {
        switch phase {
        case .aube: "ic_ciel_aube"
        case .jour: "ic_ciel_jour"
        case .coucher: "ic_ciel_coucher"
        case .nuit: "ic_ciel"
        }
    }

    /// Le symbole SF qui tient lieu de l'icône d'Android (les dessins `ic_ciel_*` ne sont pas exportés).
    public static func symbole(_ phase: Phase) -> String {
        switch phase {
        case .aube: "sunrise"
        case .jour: "sun.max"
        case .coucher: "sunset"
        case .nuit: "moon.stars"
        }
    }
}
