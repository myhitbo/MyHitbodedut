import Foundation

// Le Tikoun HaKlali (Tikkun.kt) : les dix psaumes de Rabbi Na'hman de Breslev, dans l'ordre établi
// 16, 32, 41, 42, 59, 77, 90, 105, 137, 150, et ce qui se dit avant et après. Le texte vient de
// l'édition « Tanach with Nikkud » (domaine public), la même que celle déjà citée par chizuk.json.
// `tikkun_haklali.json` est lu comme org.json d'Android le lit (`ObjetJSON`) : `getString`,
// `getInt`, `optString` et `Json.nullable`, conversions comprises.
// Jugé par `Tests/Vecteurs/tikkun.json` (tools/vecteurs_ios/VecteursTikkun.kt).

/// Une indication de lecture à l'intérieur d'un verset : là où il faut marquer un arrêt, et d'où
/// cette indication vient.
public struct Pause: Sendable, Equatable {
    public let avant: String
    public let note: String

    public init(avant: String, note: String) {
        self.avant = avant
        self.note = note
    }
}

public struct Verse: Sendable, Equatable {
    public let numero: Int
    public let he: String
    public let arret: Pause?
    public let fr: String?
    public let en: String?

    public init(numero: Int, he: String, arret: Pause? = nil, fr: String? = nil, en: String? = nil) {
        self.numero = numero
        self.he = he
        self.arret = arret
        self.fr = fr
        self.en = en
    }

    /// Le verset coupé là où l'arrêt se marque : ce qui précède le mot « avant » (sans ses blancs
    /// finaux), puis ce qui commence par lui. nil sans arrêt, si le mot n'est pas dans le verset
    /// (l'indication suit alors le verset entier), ou s'il l'ouvre. La recherche se fait unité par
    /// unité, comme `indexOf` de Kotlin : sans équivalence canonique.
    public func coupe() -> (debut: String, suite: String)? {
        guard let mot = arret?.avant, let i = he.positionUnites(de: mot), i > 0 else { return nil }
        return (Verse.sansBlancsFinaux(he.premieresUnites(i)), he.sansPremieresUnites(i))
    }

    /// `trimEnd()` de Kotlin : sans les blancs de `Kotlin.estEspace` à la fin.
    private static func sansBlancsFinaux(_ texte: String) -> String {
        let unites = Array(texte.utf16)
        var fin = unites.count
        while fin > 0 && Kotlin.estEspace(unites[fin - 1]) {
            fin -= 1
        }
        return fin == unites.count ? texte : Unites.texte(unites[..<fin])
    }
}

/// Une partie liturgique qui n'est pas un psaume : ce qui se dit avant, ce qui se dit après, la
/// kavana, la prière de Rabbi Natan.
public struct LiturgyBlock: Sendable, Equatable {
    public let cle: String
    public let titre: TexteLocalise
    public let note: TexteLocalise?
    public let formule: String?
    public let paragraphes: [String]
    /// Les traductions, paragraphe par paragraphe (04/11) ; vides sans traduction.
    public let paragraphesFr: [String]
    public let paragraphesEn: [String]

    public init(cle: String, titre: TexteLocalise, note: TexteLocalise?, formule: String?, paragraphes: [String],
                paragraphesFr: [String] = [], paragraphesEn: [String] = []) {
        self.cle = cle
        self.titre = titre
        self.note = note
        self.formule = formule
        self.paragraphes = paragraphes
        self.paragraphesFr = paragraphesFr
        self.paragraphesEn = paragraphesEn
    }
}

public struct Psalm: Sendable, Equatable {
    public let id: String
    public let numero: Int
    public let ref: String
    public let refSefaria: String?
    public let url: String?
    public let versets: [Verse]

    public init(id: String, numero: Int, ref: String, refSefaria: String?, url: String?, versets: [Verse]) {
        self.id = id
        self.numero = numero
        self.ref = ref
        self.refSefaria = refSefaria
        self.url = url
        self.versets = versets
    }
}

public struct Tikkun: Sendable, Equatable {

    /// `OUVERTURE`, `CLOTURE`, `KAVANA`, `PRIERE` de Kotlin : les clés des quatre blocs.
    public static let ouverture = "ouverture"
    public static let cloture = "cloture"
    public static let kavana = "kavana"
    public static let priere = "priere_rabbi_nathan"

    /// `ORDRE` de Kotlin : les dix psaumes, dans l'ordre établi (le journal du Tikoun, 04/11, sans
    /// relire le JSON).
    public static let ordre = [16, 32, 41, 42, 59, 77, 90, 105, 137, 150]

    public let version: String
    public let titre: TexteLocalise
    public let edition: Edition
    public let continuite: TexteLocalise
    public let psaumes: [Psalm]
    /// Clé → bloc, pour les seules clés de `ouverture`, `cloture`, `kavana`, `priere`.
    public let blocs: [String: LiturgyBlock]

    public init(version: String, titre: TexteLocalise, edition: Edition, continuite: TexteLocalise,
                psaumes: [Psalm], blocs: [String: LiturgyBlock]) {
        self.version = version
        self.titre = titre
        self.edition = edition
        self.continuite = continuite
        self.psaumes = psaumes
        self.blocs = blocs
    }

    public var versets: Int {
        var total = 0
        for psaume in psaumes {
            total += psaume.versets.count
        }
        return total
    }

    public func byNumero(_ numero: Int) -> Psalm? {
        psaumes.first { $0.numero == numero }
    }

    public func bloc(_ cle: String) -> LiturgyBlock? {
        blocs[cle]
    }

    /// Ce qui se dit avant les psaumes, dans l'ordre.
    public var avant: [LiturgyBlock] {
        [blocs[Tikkun.ouverture]].compactMap { $0 }
    }

    /// Ce qui se dit après, dans l'ordre.
    public var apres: [LiturgyBlock] {
        [blocs[Tikkun.cloture], blocs[Tikkun.kavana], blocs[Tikkun.priere]].compactMap { $0 }
    }
}

/// La lecture de `tikkun_haklali.json` (TikkunLoader).
public enum TikkunLoader {

    /// Lève, comme org.json d'Android, si `_meta`, `_meta.edition` ou `psaumes` manque ou n'a pas
    /// sa forme, si un psaume n'a pas d'`id` ou de `numero` lisible comme un entier, ou si un verset
    /// n'a pas de `n` lisible.
    public static func parse(_ json: String) throws -> Tikkun {
        let racine = try ObjetJSON(texte: json)
        let meta = try objetRequis(racine, "_meta")
        let ed = try objetRequis(meta, "edition")
        let edition = Edition(cle: ed.texte("cle"), titre: ed.texte("titre"), licence: ed.texte("licence"),
                              nikkoudOk: ed.booleen("nikkoud_ok"))
        var psaumes: [Psalm] = []
        let tableau = try tableauRequis(racine, "psaumes")
        for element in tableau {
            let o = try objetDe(element)
            let lu = try psaume(o)
            psaumes.append(lu)
        }
        var blocs: [String: LiturgyBlock] = [:]
        for cle in [Tikkun.ouverture, Tikkun.cloture, Tikkun.kavana, Tikkun.priere] {
            if let o = racine.objet(cle) {
                blocs[cle] = bloc(cle, o)
            }
        }
        return Tikkun(version: meta.texte("version"), titre: localise(meta.objet("titre")), edition: edition,
                      continuite: localise(meta.objet("continuite")), psaumes: psaumes, blocs: blocs)
    }

    /// `load(context)` : `res/raw/tikkun_haklali.json`, exporté sous `Contenu/`.
    public static func load(_ lire: LecteurContenu) throws -> Tikkun {
        guard let donnees = try lire("tikkun_haklali.json") else { throw ErreurContenu.absent("tikkun_haklali.json") }
        return try parse(String(decoding: donnees, as: UTF8.self))
    }

    private static func bloc(_ cle: String, _ o: ObjetJSON) -> LiturgyBlock {
        let note: TexteLocalise? = o.objet("note").map { localise($0) }
        return LiturgyBlock(cle: cle, titre: localise(o.objet("titre")), note: note, formule: nullable(o, "formule"),
                            paragraphes: textes(o.tableau("paragraphes")), paragraphesFr: textes(o.tableau("paragraphes_fr")),
                            paragraphesEn: textes(o.tableau("paragraphes_en")))
    }

    private static func psaume(_ o: ObjetJSON) throws -> Psalm {
        let id = try texteRequis(o, "id")
        let numero = try entierRequis(o, "numero")
        var versets: [Verse] = []
        for element in o.tableau("versets") ?? [] {
            let v = try objetDe(element)
            let n = try entierRequis(v, "n")
            let arret: Pause? = v.objet("arret").map { Pause(avant: $0.texte("avant"), note: $0.texte("note")) }
            // Les traductions du domaine public (04/11, tools/traductions_tanakh.py).
            let fr = v.texte("fr"), en = v.texte("en")
            versets.append(Verse(numero: n, he: v.texte("he"), arret: arret,
                                 fr: fr.estBlanc ? nil : fr, en: en.estBlanc ? nil : en))
        }
        return Psalm(id: id, numero: numero, ref: o.texte("ref"), refSefaria: nullable(o, "ref_sefaria"),
                     url: nullable(o, "url"), versets: versets)
    }

    // MARK: org.json d'Android

    /// `LocalizedText.parse` : un objet absent donne trois textes vides.
    private static func localise(_ o: ObjetJSON?) -> TexteLocalise {
        guard let o else { return TexteLocalise.vide }
        return TexteLocalise(he: o.texte("he"), fr: o.texte("fr"), en: o.texte("en"))
    }

    /// `Json.nullable` : absent, `null` ou blanc → nil ; sinon le texte de la valeur.
    private static func nullable(_ o: ObjetJSON, _ cle: String) -> String? {
        if o.estNul(cle) { return nil }
        let valeur = o.texte(cle)
        return valeur.estBlanc ? nil : valeur
    }

    /// `Json.strings` : un tableau absent donne une liste vide ; chaque valeur, son texte.
    private static func textes(_ tableau: [JSON]?) -> [String] {
        var resultat: [String] = []
        for valeur in tableau ?? [] {
            resultat.append(valeur.commeTexte)
        }
        return resultat
    }

    private static func manque(_ cle: String) -> ErreurJSON {
        ErreurJSON(position: 0, raison: "« \(cle) » absent ou mal formé")
    }

    /// `getJSONObject(cle)`.
    private static func objetRequis(_ o: ObjetJSON, _ cle: String) throws -> ObjetJSON {
        guard let valeur = o.objet(cle) else { throw manque(cle) }
        return valeur
    }

    /// `getJSONArray(cle)`.
    private static func tableauRequis(_ o: ObjetJSON, _ cle: String) throws -> [JSON] {
        guard let valeur = o.tableau(cle) else { throw manque(cle) }
        return valeur
    }

    /// `getJSONObject(i)` d'un tableau.
    private static func objetDe(_ valeur: JSON) throws -> ObjetJSON {
        guard case .objet(let o) = valeur else { throw manque("objet") }
        return o
    }

    /// `getString(cle)` : lève si la clé manque ; le texte de toute autre valeur, « null » compris.
    private static func texteRequis(_ o: ObjetJSON, _ cle: String) throws -> String {
        guard let valeur = o[cle] else { throw manque(cle) }
        return valeur.commeTexte
    }

    /// `getInt(cle)` : un nombre (tronqué, ramené à 32 bits), ou une chaîne qui se lit comme un nombre.
    private static func entierRequis(_ o: ObjetJSON, _ cle: String) throws -> Int {
        guard let valeur = o[cle]?.commeEntier else { throw manque(cle) }
        return Int(valeur)
    }
}
