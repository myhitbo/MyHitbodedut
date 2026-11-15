// L'icône de lancement suit le choix צדיק / צדקת et la couleur des boutons (IconeLanceur.kt, demande du
// 29/10) : le visage du hassid ou de la tsadeket (ic_launcher_face, ic_launcher_face_f), sur la plaque
// claire de l'accent. Sur Android chaque combinaison est une entrée du manifeste (activity-alias
// « Icone_m_vert »…), dont une seule est active ; ce fichier en garde les noms, les mêmes pour les
// icônes de rechange d'iOS. Changer d'icône (`appliquer`, PackageManager sur Android,
// `setAlternateIconName` sur iOS, sur geste explicite seulement : PORTAGE.md § 2.3) reste à l'app.

/// Les noms des icônes de lancement.
public enum IconeLanceur {

    private static let paquet = "com.myhitbodedut"

    /// L'entrée par défaut : le hassid sur le vert.
    public static let parDefaut = "\(paquet).Icone_m_vert"

    /// L'icône d'une adresse et d'un accent ; sans adresse choisie, le hassid.
    public static func alias(_ adresse: Adresse?, _ accent: Accent) -> String {
        let genre = adresse == .femme ? "f" : "m"
        return "\(paquet).Icone_\(genre)_\(accent.rawValue)"
    }

    /// Les douze icônes : le hassid avec chaque accent, puis la tsadeket.
    public static func tous() -> [String] {
        [Adresse.homme, Adresse.femme].flatMap { adresse in
            Accent.allCases.map { accent in alias(adresse, accent) }
        }
    }
}
