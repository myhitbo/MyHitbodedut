/// L'aération d'un paragraphe de prière (Aeration.kt, 28/10) : « mieux séparer les textes en plusieurs
/// paragraphes, espacer, mettre le premier mot plus grand et plus gras ». Miroir de
/// web/src/js/aeration.js ; mêmes seuils, mêmes vecteurs de test.
///
/// À l'affichage seulement, sur le balisage du siddour (<b>, <small>, <br>) : les données, les
/// annotations et les marque-pages gardent leurs blocs tels quels.
/// - Un long paragraphe (plus de `long` lettres visibles) se coupe après une fin de phrase (« : » ou
///   « ׃ » suivi d'une espace, hors balise et hors <small>), quand le morceau en cours a au moins
///   `morceau` lettres et qu'il en reste au moins `reste` après.
/// - Le premier mot est mis en gras s'il ne l'est pas déjà (l'écran l'agrandit) ; un paragraphe qui
///   commence par <small> ou une parenthèse n'est pas touché.
/// - Un psaume ou un passage biblique n'est jamais coupé (03/11) : on le reconnaît à ses té'amim (au
///   moins un signe de cantillation, U+0591 à U+05AF, pour deux mots) ou à l'ouverture d'un psaume
///   (מזמור, למנצח, לדוד, שיר, תהלה לדוד, הללויה, הללו).
///
/// Les lettres se comptent en unités UTF-16, comme `String.length` de Kotlin : une lettre hébraïque et
/// ses voyelles en font plusieurs. Les blancs des expressions sont ceux de `\s` de la JVM (l'espace, la
/// tabulation, les sauts de ligne et de page), écrits en toutes lettres : ICU y ajouterait l'espace
/// insécable. Jugée par `Tests/Vecteurs/texte.json` (tools/vecteurs_ios/VecteursTexte.kt).
public enum Aeration {
    public static let long = 500
    public static let morceau = 250
    public static let reste = 150

    private static let balise = ExpressionReguliere("<[^>]+>")
    private static let teamim = ExpressionReguliere("[\\u0591-\\u05AF]")
    private static let signes = ExpressionReguliere("[\\u0591-\\u05C7]")
    private static let ouverture = ExpressionReguliere("^(מזמור|למנצח|לדוד|שיר|תהלה לדוד|הללויה|הללו)[ :]")
    /// `\s+` de la JVM.
    private static let blancs = ExpressionReguliere("[ \\u0009\\u000A\\u000B\\u000C\\u000D]+")
    /// Le premier mot : des lettres hébraïques (et leurs signes, guillemets, géresh, trait d'union), suivies
    /// d'un blanc de la JVM, d'une ponctuation ou de la fin.
    private static let mot = ExpressionReguliere(
        "^([\\u0590-\\u05FF\\uFB1D-\\uFB4F\"'\\u05F4\\u05F3\\-]+)(?=[ \\u0009\\u000A\\u000B\\u000C\\u000D,:;.]|$)")

    /// Le maqaf (U+05BE), que Kotlin change en espace après avoir retiré les signes.
    private static let maqaf = "\u{05BE}"

    // Les unités que la coupe reconnaît.
    private static let chevronOuvrant: UInt16 = 0x3C
    private static let chevronFermant: UInt16 = 0x3E
    private static let deuxPoints: UInt16 = 0x3A
    private static let sofPassouk: UInt16 = 0x05C3
    private static let espace: UInt16 = 0x20
    private static let ouvrantSmall = Array("<small".utf16)
    private static let fermantSmall = Array("</small".utf16)
    private static let saut = Array("<br><br>".utf16)

    public static func psaume(_ html: String) -> Bool {
        let texte = balise.remplace(html, par: "")
        var mots = 0
        for piece in blancs.decoupe(texte) where !piece.isEmpty {
            mots += 1
        }
        if mots < 1 { mots = 1 }
        let cantillation = teamim.toutes(texte).count
        if Double(cantillation) / Double(mots) >= 0.5 { return true }
        let nu = signes.remplace(texte, par: "").remplacantUnites(maqaf, par: " ").rogne
        return ouverture.presente(dans: nu)
    }

    public static func premierMot(_ html: String) -> String {
        if html.commenceParUnites("<b>") { return html }
        guard let correspondance = mot.trouve(html), correspondance.groupes.count > 1 else { return html }
        let premier = correspondance.groupes[1]
        let suite = html.sansPremieresUnites(premier.utf16.count)
        return "<b>\(premier)</b>\(suite)"
    }

    public static func couper(_ html: String) -> String {
        let total = balise.remplace(html, par: "").utf16.count
        if total <= long || psaume(html) { return html }
        let unites = Array(html.utf16)
        var sortie: [UInt16] = []
        sortie.reserveCapacity(unites.count + 64)
        var dansBalise = false
        var petit = 0
        var depuis = 0
        var vus = 0
        var i = 0
        while i < unites.count {
            let c = unites[i]
            if c == chevronOuvrant {
                dansBalise = true
                if commence(unites, par: ouvrantSmall, a: i) {
                    petit += 1
                } else if commence(unites, par: fermantSmall, a: i) {
                    petit = max(0, petit - 1)
                }
            }
            sortie.append(c)
            if dansBalise {
                if c == chevronFermant { dansBalise = false }
                i += 1
                continue
            }
            vus += 1
            depuis += 1
            let finDePhrase = c == deuxPoints || c == sofPassouk
            let suiviDUneEspace = i + 1 < unites.count && unites[i + 1] == espace
            if finDePhrase && petit == 0 && suiviDUneEspace && depuis >= morceau && total - vus >= reste {
                sortie.append(contentsOf: saut)
                // L'espace qui suivait.
                i += 1
                depuis = 0
            }
            i += 1
        }
        return Unites.texte(sortie)
    }

    public static func aerer(_ html: String) -> String {
        premierMot(couper(html))
    }

    /// `startsWith(prefixe, depuis)` de Kotlin, sur les unités.
    private static func commence(_ unites: [UInt16], par prefixe: [UInt16], a depuis: Int) -> Bool {
        if depuis + prefixe.count > unites.count { return false }
        for k in 0..<prefixe.count where unites[depuis + k] != prefixe[k] {
            return false
        }
        return true
    }
}
