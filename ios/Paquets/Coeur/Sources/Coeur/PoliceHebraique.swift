// La police des textes saints en hébreu (PoliceHebraique.kt d'Android) : les sept polices au choix, leurs
// libellés, et les signes absents de chacune. Le chargement des polices et leur pose sur une vue
// (`appliquer`) restent à l'app. Android masque les signes absents à l'affichage (une
// ReplacementTransformationMethod sur la vue) ; iOS n'a rien de tel, il masque le texte avant de le
// montrer (`masque`, PORTAGE.md : « masquage par prétraitement »).

/// La police des textes saints en hébreu (demande du 04/10) : psaumes, prières, chizuk, sources de la
/// bibliothèque, halakha, hilloulot. L'interface, boutons et menus, garde la police du téléphone.
///
/// Au choix depuis le 12/10 (bouton « Aa », pour tous les écrans) : la police hébraïque à empattements de
/// l'application, celle du téléphone sans empattements, ou l'arrondie de l'application. Toutes sont dans
/// l'application ou le téléphone : rien ne se télécharge.
public enum PoliceHebraique {

    /// Les polices, dans l'ordre d'Android. La valeur brute est la clé enregistrée
    /// (`Reglages.lecturePolice`, `Reglages.polices`).
    public enum Police: String, Sendable, CaseIterable {
        case serif
        case sans
        case arrondie
        // Quatre polices hébraïques libres (OFL, Google Fonts), toutes avec le nikkoud (14/10).
        case frank
        case david
        case rachi
        case miriam

        public var cle: String {
            rawValue
        }

        /// La clé de la chaîne qui nomme la police (R.string.police_…).
        public var libelle: String {
            switch self {
            case .serif: return "police_serif"
            case .sans: return "police_sans"
            case .arrondie: return "police_arrondie"
            case .frank: return "police_frank"
            case .david: return "police_david"
            case .rachi: return "police_rachi"
            case .miriam: return "police_miriam"
            }
        }
    }

    /// U+034F (combining grapheme joiner) : invisible, sans chasse, sans coupure de ligne ni de mot, et de
    /// même longueur, donc les décalages (signets, recherche, liens) ne bougent pas.
    private static let joint: UInt16 = 0x034F

    /// Les טעמים (U+0591–U+05AF), absents des quatre polices ci-dessous.
    static let teamim = Unites.texte(UInt16(0x0591)...UInt16(0x05AF))

    /// Les signes absents de la police (ABSENTS d'Android). Le système les emprunte à une autre police et les
    /// pose sans ancrage : ils flottent hors des lettres (capture du 28/10, Tikkun Ra'hel en Frank Ruhl).
    ///
    /// Mesuré sur les fichiers de res/font avec fontTools (28/10) : Noto Serif Hebrew et Noto Rashi ont les
    /// 31 טעמים et les 24 points ; les autres non. La police du téléphone (SANS) varie selon l'appareil :
    /// laissée telle quelle, nil.
    ///
    /// Le meteg (U+05BD) est masqué aussi dans Noto Serif Hebrew et Noto Rashi : il s'y pose au même point
    /// que la voyelle, un patah devient un faux qamats et un segol se brouille (capture du 29/10, עָלֶֽיהָ
    /// dans Méèn chaloch). Recopié par programme de PoliceHebraique.kt ; les tests le comparent signe par
    /// signe à `interface_a.json`.
    public static func absents(_ police: Police) -> String? {
        switch police {
        case .serif: return "\u{05BD}"
        case .rachi: return "\u{05BD}"
        case .frank: return teamim + "\u{05C4}\u{05C5}"
        case .david: return teamim + "\u{05BD}"
        case .miriam: return teamim + "\u{05BD}\u{05BF}\u{05C4}\u{05C5}"
        case .arrondie: return teamim + "\u{05BD}\u{05BF}\u{05C4}\u{05C5}"
        case .sans: return nil
        }
    }

    /// Le texte tel que la vue d'Android l'affiche dans cette police : chaque signe absent devient U+034F,
    /// unité UTF-16 par unité (le Masque d'Android, une ReplacementTransformationMethod). Le texte garde sa
    /// longueur et ses positions ; seule la vue change, le texte enregistré reste le même.
    public static func masque(_ texte: String, police: Police) -> String {
        guard let signesAbsents = absents(police) else { return texte }
        let signes = Set(signesAbsents.utf16)
        return Unites.texte(texte.utf16.map { signes.contains($0) ? joint : $0 })
    }
}
