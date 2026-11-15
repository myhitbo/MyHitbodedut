// Le personnage au féminin (Personnage.kt d'Android). PersonnageImageView et PersonnageViewInflater, qui
// font passer chaque image des écrans d'Android par la table, restent à l'app : sur iOS, la vue qui montre
// le personnage passe son nom d'image par `Personnage.pour`.
// Les images portent les noms d'Android : R.drawable.x devient « x » (ios/Ressources/Images).

/// Le personnage au féminin (audit 1.390, point 8) : qui a choisi צדקת voit, à la place de chaque pose du
/// hassid, la plus proche de la planche féminine du 29/10 et de sa seconde planche
/// (tools/personnage_feminin.py). Sans choix, ou צדיק, rien ne change.
///
/// Sans tefillin, matsa ni costume de Pourim, ces poses prennent la plus proche : la prière, la lecture (la
/// Haggada), le livre contre soi (la Meguila) ; l'ouverture, debout, la prière de dos bras levés. La même
/// table vit côté site (web/src/js/personnage.js).
public enum Personnage {

    /// La pose du hassid, puis sa pose féminine, dans l'ordre d'Android (FEMININ). Recopiée par programme de
    /// Personnage.kt ; les tests la comparent entrée par entrée à `interface_a.json`.
    static let feminins: [(hassid: String, feminine: String)] = [
        ("char_welcome", "char_f_welcome"),
        ("char_open_arms", "char_f_arms_up"),
        ("char_debout", "char_f_back_arms"),
        ("char_thumbs_up", "char_f_thumbs_up"),
        ("char_tehilim", "char_f_tehilim"),
        ("char_praise", "char_f_praise"),
        ("char_dancing_joy", "char_f_joy"),
        ("char_writing", "char_f_writing"),
        ("char_thinking", "char_f_thinking"),
        ("char_pointing", "char_f_pointing"),
        ("char_walking", "char_f_walking"),
        ("char_praying", "char_f_praying"),
        ("char_tefillin", "char_f_praying"),
        ("char_dancing", "char_f_dancing"),
        ("char_guitar", "char_f_guitar"),
        ("char_purim", "char_f_book_side"),
        ("char_shabbat", "char_f_tehilim_hug"),
        ("char_matsa", "char_f_reading"),
        ("char_offering", "char_f_offering"),
        ("char_torah", "char_f_kneel_reading"),
        ("char_standing_back", "char_f_standing_back"),
    ]

    private static let parHassid: [String: String] =
        Dictionary(uniqueKeysWithValues: feminins.map { ($0.hassid, $0.feminine) })

    /// La pose féminine d'une pose du hassid. Toute autre image, et une pose déjà féminine, passe telle
    /// quelle : la table ne touche qu'au personnage et ne s'applique qu'une fois.
    public static func feminin(_ id: String) -> String {
        parHassid[id] ?? id
    }

    /// L'image à montrer à qui a choisi cette adresse (`Store.adresse` sur Android) : la pose féminine pour
    /// צדקת, l'image elle-même sans choix ou pour צדיק.
    public static func pour(_ adresse: Adresse?, _ id: String) -> String {
        adresse == .femme ? feminin(id) : id
    }
}
