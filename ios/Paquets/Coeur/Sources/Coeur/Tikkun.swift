import Foundation

// Tikkun.kt : le Tikoun HaKlali, les dix psaumes de Rabbi Na'hman de Breslev dans l'ordre établi (16, 32, 41,
// 42, 59, 77, 90, 105, 137, 150), et les parties liturgiques qui les entourent (tikkun_haklali.json). Le texte
// vient de l'édition « Tanach with Nikkud » (domaine public) ; le qere est retenu. Jugé par TikkunTests
// (TikkunTest d'Android) et par la section « coupes » de `Tests/Vecteurs/textes.json`.

/// `Pause` : une indication de lecture à l'intérieur d'un verset, là où il faut marquer un arrêt, et d'où
/// cette indication vient.
public struct Arret: Sendable, Equatable {
    /// Le mot devant lequel l'arrêt se marque.
    public let avant: String
    public let note: String

    public init(avant: String, note: String) {
        self.avant = avant
        self.note = note
    }
}

/// `Verse` : un verset du Tikoun, son arrêt éventuel et ses traductions du domaine public (04/11).
public struct Verset: Sendable, Equatable, Decodable {
    public let numero: Int
    public let he: String
    public let arret: Arret?
    public let fr: String?
    public let en: String?

    /// Le verset coupé là où l'arrêt se marque : ce qui précède le mot, puis ce qui commence par lui.
    public struct Coupe: Sendable, Equatable {
        public let avant: String
        public let apres: String
    }

    public init(numero: Int, he: String, arret: Arret? = nil, fr: String? = nil, en: String? = nil) {
        self.numero = numero
        self.he = he
        self.arret = arret
        self.fr = fr
        self.en = en
    }

    /// `TikkunLoader.psaume` : « n » exigé, le reste facultatif ; une traduction blanche vaut nil.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        numero = try c.decode(Int.self, forKey: Cle("n"))
        he = c.texte("he")
        if let a = try? c.nestedContainer(keyedBy: Cle.self, forKey: Cle("arret")) {
            arret = Arret(avant: a.texte("avant"), note: a.texte("note"))
        } else {
            arret = nil
        }
        let francais = c.texte("fr"), anglais = c.texte("en")
        fr = francais.estBlanc ? nil : francais
        en = anglais.estBlanc ? nil : anglais
    }

    /// `coupe()` : nil sans arrêt, ou si le mot n'est pas dans le verset après son début (l'indication suit alors
    /// le verset entier). La recherche se fait en unités UTF-16, comme `indexOf` : « מ » se trouve dans « מָה ».
    public func coupe() -> Coupe? {
        guard let mot = arret?.avant, let i = he.positionUnites(de: mot), i > 0 else { return nil }
        return Coupe(avant: Verset.sansBlancsFinaux(he.premieresUnites(i)), apres: he.sansPremieresUnites(i))
    }

    /// `trimEnd()` de Kotlin : sans les blancs de `Kotlin.estEspace` à la fin.
    private static func sansBlancsFinaux(_ texte: String) -> String {
        var unites = Array(texte.utf16)
        let longueur = unites.count
        while let derniere = unites.last, Kotlin.estEspace(derniere) { unites.removeLast() }
        return unites.count == longueur ? texte : Unites.texte(unites)
    }
}

/// `LiturgyBlock` : une partie liturgique qui n'est pas un psaume : ce qui se dit avant, ce qui se dit après,
/// la kavana, la prière de Rabbi Natan.
public struct BlocLiturgique: Sendable, Equatable {
    public let cle: String
    public let titre: TexteLocalise
    public let note: TexteLocalise?
    public let formule: String?
    public let paragraphes: [String]
    /// Les traductions, paragraphe par paragraphe (04/11) ; vides sans traduction.
    public let paragraphesFr: [String]
    public let paragraphesEn: [String]

    public init(cle: String, titre: TexteLocalise, note: TexteLocalise? = nil, formule: String? = nil,
                paragraphes: [String], paragraphesFr: [String] = [], paragraphesEn: [String] = []) {
        self.cle = cle
        self.titre = titre
        self.note = note
        self.formule = formule
        self.paragraphes = paragraphes
        self.paragraphesFr = paragraphesFr
        self.paragraphesEn = paragraphesEn
    }
}

/// `Psalm` : un des dix psaumes, avec ses renvois.
public struct Psaume: Sendable, Equatable, Decodable {
    public let id: String
    public let numero: Int
    public let ref: String
    public let refSefaria: String?
    public let url: String?
    public let versets: [Verset]

    public init(id: String, numero: Int, ref: String, refSefaria: String? = nil, url: String? = nil, versets: [Verset]) {
        self.id = id
        self.numero = numero
        self.ref = ref
        self.refSefaria = refSefaria
        self.url = url
        self.versets = versets
    }

    /// `TikkunLoader.psaume` : « id » et « numero » exigés.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        id = try c.decode(String.self, forKey: Cle("id"))
        numero = try c.decode(Int.self, forKey: Cle("numero"))
        ref = c.texte("ref")
        refSefaria = c.texteOuNil("ref_sefaria")
        url = c.texteOuNil("url")
        versets = (try c.decodeIfPresent([Verset].self, forKey: Cle("versets"))) ?? []
    }
}

/// `Tikkun` : le Tikoun HaKlali entier.
public struct Tikkun: Sendable, Equatable, Decodable {
    public let version: String
    public let titre: TexteLocalise
    public let edition: Edition
    /// La consigne de lecture d'un trait, sans s'arrêter entre les psaumes.
    public let continuite: TexteLocalise
    public let psaumes: [Psaume]
    /// Les parties liturgiques présentes, dans l'ordre ouverture, clôture, kavana, prière (`blocs` d'Android,
    /// une table : un tableau ici, pour garder l'ordre).
    public let blocs: [BlocLiturgique]

    public static let ouverture = "ouverture"
    public static let cloture = "cloture"
    public static let kavana = "kavana"
    public static let priere = "priere_rabbi_nathan"

    /// `ORDRE` : les dix psaumes, dans l'ordre établi (le journal du Tikoun, 04/11, sans relire le JSON).
    public static let ordre = [16, 32, 41, 42, 59, 77, 90, 105, 137, 150]

    public init(version: String, titre: TexteLocalise, edition: Edition, continuite: TexteLocalise, psaumes: [Psaume],
                blocs: [BlocLiturgique]) {
        self.version = version
        self.titre = titre
        self.edition = edition
        self.continuite = continuite
        self.psaumes = psaumes
        self.blocs = blocs
    }

    /// `TikkunLoader.parse` : `_meta`, son « edition » et « psaumes » exigés ; chaque bloc facultatif.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        let meta = try c.nestedContainer(keyedBy: Cle.self, forKey: Cle("_meta"))
        let ed = try meta.nestedContainer(keyedBy: Cle.self, forKey: Cle("edition"))
        version = meta.texte("version")
        titre = (try? meta.decodeIfPresent(TexteLocalise.self, forKey: Cle("titre"))) ?? .vide
        continuite = (try? meta.decodeIfPresent(TexteLocalise.self, forKey: Cle("continuite"))) ?? .vide
        edition = Edition(cle: ed.texte("cle"), titre: ed.texte("titre"), licence: ed.texte("licence"),
                          nikkoudOk: ed.booleen("nikkoud_ok"))
        psaumes = try c.decode([Psaume].self, forKey: Cle("psaumes"))
        var lus: [BlocLiturgique] = []
        for cle in [Tikkun.ouverture, Tikkun.cloture, Tikkun.kavana, Tikkun.priere] {
            guard let o = try? c.nestedContainer(keyedBy: Cle.self, forKey: Cle(cle)) else { continue }
            lus.append(BlocLiturgique(
                cle: cle,
                titre: (try? o.decodeIfPresent(TexteLocalise.self, forKey: Cle("titre"))) ?? .vide,
                note: try? o.decodeIfPresent(TexteLocalise.self, forKey: Cle("note")),
                formule: o.texteOuNil("formule"),
                paragraphes: o.liste("paragraphes"),
                paragraphesFr: o.liste("paragraphes_fr"),
                paragraphesEn: o.liste("paragraphes_en")))
        }
        blocs = lus
    }

    /// `TikkunLoader.parse`, sur le contenu de tikkun_haklali.json.
    public static func lire(_ donnees: Data) throws -> Tikkun {
        try JSONDecoder().decode(Tikkun.self, from: donnees)
    }

    /// Le nombre de versets des dix psaumes.
    public var versets: Int { psaumes.reduce(0) { $0 + $1.versets.count } }

    /// `byNumero`.
    public func psaume(_ numero: Int) -> Psaume? { psaumes.first { $0.numero == numero } }

    public func bloc(_ cle: String) -> BlocLiturgique? { blocs.first { $0.cle.egalUnites(cle) } }

    /// Ce qui se dit avant les psaumes, dans l'ordre.
    public var avant: [BlocLiturgique] { [bloc(Tikkun.ouverture)].compactMap { $0 } }

    /// Ce qui se dit après, dans l'ordre.
    public var apres: [BlocLiturgique] { [bloc(Tikkun.cloture), bloc(Tikkun.kavana), bloc(Tikkun.priere)].compactMap { $0 } }
}
