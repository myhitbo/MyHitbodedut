/// Les marque-pages (MarquesPages.kt, 15/10, « possibilité de mettre des marque-pages dans les
/// lectures ») : une place précise dans un texte du siddour ou d'un livre, posée d'un appui long sur un
/// paragraphe. Une place se nomme par le texte (« s:id » ou « l:id », comme les favoris), le noussa'h
/// (les paragraphes diffèrent d'un noussa'h à l'autre ; vide pour un livre), la section et le
/// paragraphe, avec un aperçu des premiers mots pour la liste.
///
/// Le texte enregistré (préférence « marques_pages ») est celui d'Android : une ligne par marque,
/// cinq champs séparés par des tabulations. Les chaînes se comparent unité par unité, comme en Kotlin.
/// Jugée par `Tests/Vecteurs/texte.json` (tools/vecteurs_ios/VecteursTexte.kt).
public enum MarquesPages {

    public struct Marque: Hashable, Sendable {
        public let cle: String
        public let nusah: String
        public let section: Int
        public let bloc: Int
        public let apercu: String

        public init(cle: String, nusah: String, section: Int, bloc: Int, apercu: String) {
            self.cle = cle
            self.nusah = nusah
            self.section = section
            self.bloc = bloc
            self.apercu = apercu
        }

        /// Une même place, quel que soit l'aperçu.
        public func memePlace(_ m: Marque) -> Bool {
            cle.egalUnites(m.cle) && nusah.egalUnites(m.nusah) && section == m.section && bloc == m.bloc
        }

        /// L'égalité d'une data class de Kotlin : champ par champ, les chaînes unité par unité (celle de
        /// Swift tiendrait « é » et « e » + accent pour égaux). Le hachage de Swift reste cohérent : deux
        /// chaînes égales unité par unité le sont aussi pour lui.
        public static func == (a: Marque, b: Marque) -> Bool {
            a.memePlace(b) && a.apercu.egalUnites(b.apercu)
        }
    }

    /// Au plus tant de marque-pages : les plus anciens tombent.
    public static let max = 60

    private static let balise = ExpressionReguliere("<[^>]+>")
    /// Le maqaf (U+05BE) et le paseq (U+05C0) séparent des mots.
    private static let separateurs = ExpressionReguliere("[\\u05BE\\u05C0]")
    private static let signes = ExpressionReguliere("[\\u0591-\\u05C7]")
    private static let coupures = ExpressionReguliere("[|\\n\\t]")
    /// `\s+` de la JVM : l'espace, la tabulation, les sauts de ligne et de page.
    private static let blancs = ExpressionReguliere("[ \\u0009\\u000A\\u000B\\u000C\\u000D]+")

    private static let sautDeLigne: UInt16 = 0x0A
    private static let tabulation: UInt16 = 0x09

    /// Les premiers mots d'un paragraphe, sans balises ni voyelles. Kotlin refuse un nombre de mots
    /// négatif (`take`) ; ici, il n'en rend aucun.
    public static func apercu(_ texte: String, mots: Int = 6) -> String {
        let sansBalises = balise.remplace(texte, par: " ")
        let sansSeparateurs = separateurs.remplace(sansBalises, par: " ")
        let sansSignes = signes.remplace(sansSeparateurs, par: "")
        let nu = coupures.remplace(sansSignes, par: " ").rogne
        let pieces = blancs.decoupe(nu)
        return pieces.prefix(Swift.max(0, mots)).joined(separator: " ")
    }

    public static func encoder(_ l: [Marque]) -> String {
        var lignes: [String] = []
        for m in l {
            lignes.append("\(m.cle)\t\(m.nusah)\t\(m.section)\t\(m.bloc)\t\(m.apercu)")
        }
        return lignes.joined(separator: "\n")
    }

    /// Une ligne de moins de cinq champs, ou dont la section ou le paragraphe ne se lit pas comme un
    /// entier, est laissée de côté ; un champ de trop est ignoré.
    public static func decoder(_ s: String?) -> [Marque] {
        var marques: [Marque] = []
        for ligne in decoupe(s ?? "", sur: sautDeLigne) {
            let c = decoupe(ligne, sur: tabulation)
            if c.count < 5 { continue }
            guard let section = entier(c[2]), let bloc = entier(c[3]) else { continue }
            marques.append(Marque(cle: c[0], nusah: c[1], section: section, bloc: bloc, apercu: c[4]))
        }
        return marques
    }

    /// Pose la marque, ou la retire si elle y est ; la plus récente en tête.
    public static func basculer(_ l: [Marque], _ m: Marque) -> [Marque] {
        if l.contains(where: { $0.memePlace(m) }) {
            return l.filter { !$0.memePlace(m) }
        }
        var nouvelles = [m]
        nouvelles.append(contentsOf: l)
        return Array(nouvelles.prefix(max))
    }

    /// Celles d'un texte, dans l'ordre du texte (section, puis paragraphe ; à égalité, l'ordre de la liste).
    public static func duTexte(_ l: [Marque], cle: String, nusah: String) -> [Marque] {
        var retenues: [(rang: Int, marque: Marque)] = []
        for (rang, m) in l.enumerated() where m.cle.egalUnites(cle) && m.nusah.egalUnites(nusah) {
            retenues.append((rang: rang, marque: m))
        }
        retenues.sort { a, b in
            if a.marque.section != b.marque.section { return a.marque.section < b.marque.section }
            if a.marque.bloc != b.marque.bloc { return a.marque.bloc < b.marque.bloc }
            return a.rang < b.rang
        }
        var triees: [Marque] = []
        for r in retenues {
            triees.append(r.marque)
        }
        return triees
    }

    /// `split(caractere)` de Kotlin : sur une unité UTF-16, les morceaux vides compris. Celui de Swift
    /// coupe sur des caractères entiers (« \r\n » en est un seul) et omet les morceaux vides.
    private static func decoupe(_ texte: String, sur separateur: UInt16) -> [String] {
        var morceaux: [String] = []
        var courant: [UInt16] = []
        for unite in texte.utf16 {
            if unite == separateur {
                morceaux.append(Unites.texte(courant))
                courant.removeAll(keepingCapacity: true)
            } else {
                courant.append(unite)
            }
        }
        morceaux.append(Unites.texte(courant))
        return morceaux
    }

    /// `toIntOrNull()` de Kotlin : un signe facultatif puis au moins un chiffre décimal, dans les bornes
    /// d'un `Int` de 32 bits. Les chiffres sont ceux de `Character.digit` de Java : tout chiffre décimal
    /// d'Unicode (« ٣ », « ३ », « ３ »), pas « ① » ni « ½ ».
    private static func entier(_ texte: String) -> Int? {
        let unites = Array(texte.utf16)
        if unites.isEmpty { return nil }
        var debut = 0
        var negatif = false
        if unites[0] < 0x30 {
            if unites.count == 1 { return nil }
            if unites[0] == 0x2D {
                negatif = true
            } else if unites[0] != 0x2B {
                return nil
            }
            debut = 1
        }
        var valeur = 0
        for unite in unites[debut...] {
            guard let c = chiffre(unite) else { return nil }
            valeur = valeur * 10 + c
            if valeur > 2_147_483_648 { return nil }
        }
        if negatif { return -valeur }
        return valeur > 2_147_483_647 ? nil : valeur
    }

    /// La valeur d'un chiffre décimal d'Unicode (catégorie Nd), comme `Character.digit(c, 10)`.
    private static func chiffre(_ unite: UInt16) -> Int? {
        if unite >= 0x30 && unite <= 0x39 { return Int(unite - 0x30) }
        guard let scalaire = Unicode.Scalar(unite) else { return nil }
        let proprietes = scalaire.properties
        guard proprietes.numericType == .decimal, let valeur = proprietes.numericValue else { return nil }
        return Int(valeur)
    }
}
