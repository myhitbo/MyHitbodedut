import Foundation

/// `ChizukRules.kt` : ce qu'une compilation a le droit d'afficher, et sous quelle forme. En publication, seul
/// passe un texte relevé de la source ET relu ; l'hébreu suit le nikkoud permis par l'édition. `debug` est passé
/// en argument plutôt que lu dans la construction.
public enum ChizukRules {

    public static let statutPubliable = "verifie_texte"

    /// La règle de publication, telle quelle.
    public static func publiable(_ item: ChizukItem) -> Bool { item.statutVerif == statutPubliable && item.relu }

    /// Un texte retenu en débogage mais que la publication refuserait porte un badge.
    public static func aRelire(_ item: ChizukItem) -> Bool { !publiable(item) }

    /// Ce qu'une compilation affiche : tout en débogage, le publiable en publication.
    public static func visibles(_ chizuk: Chizuk, debug: Bool) -> [ChizukItem] {
        debug ? chizuk.items : chizuk.items.filter(publiable)
    }

    /// Ce qu'un moment a le droit de tirer ; à la demande, tout ce qui est visible.
    public static func pourMoment(_ chizuk: Chizuk, _ moment: Moment, debug: Bool) -> [ChizukItem] {
        let liste = visibles(chizuk, debug: debug)
        return moment == .demande ? liste : liste.filter { $0.moments.contains(moment) }
    }

    /// L'hébreu à afficher : `he` si l'édition permet son nikkoud, sinon `he_sans_nikkoud` (et `he` s'il manquait).
    public static func hebreu(_ chizuk: Chizuk, _ item: ChizukItem) -> String {
        if chizuk.editions[item.edition]?.nikkoudOk ?? false { return item.he }
        guard let sans = item.heSansNikkoud, !sans.estBlanc else { return item.he }
        return sans
    }
}

/// `ChizukBag.kt` : la rotation des textes, un sac mélangé par moment, tiré sans remise. La logique est une
/// fonction pure de l'état du sac ; le mélange est injecté.
public enum ChizukBag {

    /// Ce qu'un tirage rend : le texte sorti, et le sac tel qu'il reste.
    public struct Tirage: Sendable, Equatable {
        public let id: String?
        public let reste: [String]
    }

    /// Tire le prochain identifiant. Un texte retiré des données ne ressort pas ; quand un cycle recommence, le
    /// dernier sorti ne l'ouvre pas (il repart en fin de sac).
    public static func suivant(_ reste: [String], vivier: [String], dernier: String? = nil,
                               melange: ([String]) -> [String]) -> Tirage {
        guard !vivier.isEmpty else { return Tirage(id: nil, reste: []) }
        let utilisables = reste.filter { vivier.contains($0) }
        var sac = utilisables
        if sac.isEmpty {
            let melanges = melange(vivier)
            if vivier.count > 1, let premier = melanges.first, premier == dernier {
                sac = Array(melanges.dropFirst()) + [premier]
            } else {
                sac = melanges
            }
        }
        return Tirage(id: sac.first, reste: Array(sac.dropFirst()))
    }
}

/// `ChizukCard.translationOf` : la traduction dans la langue de l'interface ; rien en hébreu (le texte est déjà
/// au-dessus) ; le français pour une langue que l'application ne parle pas.
public enum ChizukCarte {
    public static func traduction(_ item: ChizukItem, _ langue: String) -> String {
        switch langue {
        case "he", "iw": ""
        case "en": item.en
        default: item.fr
        }
    }
}

/// `ChizukPartage` (ChizukActivity.kt) : le texte partagé garde sa source et son lien (19/10).
public enum ChizukPartage {
    public static func texte(_ hebreu: String, _ traduction: String, _ source: String, _ lien: String) -> String {
        let t = traduction.rogne
        return ([hebreu.rogne] + (t.estBlanc ? [] : [t]) + ["— \(source)", lien]).joined(separator: "\n\n")
    }
}

/// `LibraryRules.kt` : une source (domaine public) s'affiche en entier ; un article ne montre qu'une fiche tant
/// qu'aucune autorisation n'a été obtenue.
public enum LibraryRules {

    /// Le texte intégral d'un article, ou nil : c'est l'autorisation qui ouvre, pas la présence du texte.
    public static func texteIntegral(_ article: ArticleBibliotheque) -> String? {
        guard let a = article.autorisation, !a.estBlanc else { return nil }
        guard let t = article.texteIntegral, !t.estBlanc else { return nil }
        return t
    }

    /// Les paragraphes d'une source, dans la forme que la licence de son édition permet.
    public static func paragraphes(_ bibliotheque: Bibliotheque, _ source: SourceBibliotheque) -> [String] {
        if bibliotheque.editions[source.edition]?.nikkoudOk ?? false { return source.paragraphes }
        return source.paragraphesSansNikkoud.isEmpty ? source.paragraphes : source.paragraphesSansNikkoud
    }

    /// Le résumé dans la langue de l'interface, et seulement elle (RegleLangue : pas de repli).
    public static func resume(_ article: ArticleBibliotheque, _ langue: String) -> String? {
        RegleLangue.choisit(langue, article.resumes)
    }

    /// Les droits, dans la même langue et selon la même règle.
    public static func droits(_ article: ArticleBibliotheque, _ langue: String) -> String? {
        RegleLangue.choisit(langue, article.droits)
    }

    /// Les erreurs relevées, dans la langue de l'interface ; rien si aucune.
    public static func erreurs(_ article: ArticleBibliotheque, _ langue: String) -> [String] {
        article.erreursRelevees[RegleLangue.normalise(langue)] ?? []
    }

    /// Les sources d'abord : ce sont elles qu'on vient lire.
    public static func ordonnees(_ entrees: [EntreeBibliotheque]) -> [EntreeBibliotheque] {
        let sources = entrees.filter { if case .source = $0 { return true } else { return false } }
        let articles = entrees.filter { if case .article = $0 { return true } else { return false } }
        return sources + articles
    }
}

/// `RegleLangue` (Langue.kt, 22/09) : en hébreu, rien que de l'hébreu ; en anglais, l'hébreu et l'anglais ; en
/// français, l'hébreu et le français. Aucun repli d'une langue sur une autre.
public enum RegleLangue {

    /// L'hébreu est toujours permis : c'est la langue des textes eux-mêmes.
    public static func permises(_ interface: String) -> Set<String> {
        let l = normalise(interface)
        return l == "he" ? ["he"] : ["he", l]
    }

    public static func permet(_ interface: String, _ langueDuTexte: String) -> Bool {
        permises(interface).contains(normalise(langueDuTexte))
    }

    /// Montre-t-on une traduction à côté de l'hébreu ? Non, en hébreu.
    public static func traduit(_ interface: String) -> Bool { normalise(interface) != "he" }

    /// Le texte de la langue de l'interface parmi ceux qu'on a, ou nil ; pas de repli.
    public static func choisit(_ interface: String, _ textes: [String: String]) -> String? {
        guard let t = textes[normalise(interface)], !t.estBlanc else { return nil }
        return t
    }

    /// « iw » est l'ancien code d'Android pour l'hébreu ; « fr-FR » et « fr_FR » donnent « fr ».
    public static func normalise(_ etiquette: String?) -> String {
        let brute = (etiquette ?? "").avantUnites("-").avantUnites("_").minusculesJava
        return brute == "iw" ? "he" : brute
    }
}

/// `LangueApp.repli` (Langue.kt, 29/10) : un téléphone dont aucune langue n'est livrée passe l'application en
/// anglais ; nil si l'une de ses langues est livrée.
public enum LangueApp {
    public static func repli(_ systeme: [String]) -> String? {
        systeme.contains { ["fr", "en", "he"].contains(RegleLangue.normalise($0)) } ? nil : "en"
    }
}

/// `LanguesTexte.kt` (04/11) : les langues d'un texte à lire, hébreu seul, français seul, anglais seul, ou deux
/// langues l'une sous l'autre ; par défaut, la règle de la langue de l'application.
public enum LanguesTexte {

    public enum Mode: String, Sendable, CaseIterable {
        case he = "he", fr = "fr", en = "en", heFr = "he+fr", heEn = "he+en", frEn = "fr+en"

        public var cle: String { rawValue }

        public var langues: [String] { rawValue.components(separatedBy: "+") }

        /// La clé du libellé dans le catalogue.
        public var libelle: String { "langues_" + rawValue.replacingOccurrences(of: "+", with: "_") }
    }

    public static func defaut(_ langueApp: String) -> Mode {
        switch langueApp {
        case "he", "iw": .he
        case "en": .heEn
        default: .heFr
        }
    }

    /// Le mode enregistré s'il est connu, sinon celui de la langue de l'application.
    public static func mode(_ enregistre: String?, langueApp: String) -> Mode {
        enregistre.flatMap { Mode(rawValue: $0) } ?? defaut(langueApp)
    }

    /// Les textes à montrer, dans l'ordre du mode : (langue, texte). Une traduction absente est sautée ; s'il ne
    /// reste rien, l'hébreu seul.
    public static func textes(_ mode: Mode, he: String, fr: String?, en: String?) -> [Texte] {
        var tous: [Texte] = []
        for l in mode.langues {
            switch l {
            case "he": tous.append(Texte("he", he))
            case "fr": if let fr, !fr.estBlanc { tous.append(Texte("fr", fr)) }
            default: if let en, !en.estBlanc { tous.append(Texte("en", en)) }
            }
        }
        return tous.isEmpty ? [Texte("he", he)] : tous
    }

    /// Un texte et sa langue.
    public struct Texte: Sendable, Equatable {
        public let langue: String
        public let texte: String

        public init(_ langue: String, _ texte: String) {
            self.langue = langue
            self.texte = texte
        }
    }

    /// Le mode veut une traduction que ce texte n'a pas.
    public static func manque(_ mode: Mode, aTraduction: Bool) -> Bool {
        !aTraduction && mode.langues.contains { $0 != "he" }
    }
}

/// `MarquesPages.kt` (15/10) : une place précise dans un texte du siddour ou d'un livre, nommée par le texte, le
/// noussa'h, la section et le paragraphe, avec un aperçu des premiers mots.
public enum MarquesPages {

    public struct Marque: Sendable, Equatable {
        public let cle: String
        public let nusah: String
        public let section: Int
        public let bloc: Int
        public let apercu: String

        public init(_ cle: String, _ nusah: String, _ section: Int, _ bloc: Int, _ apercu: String) {
            self.cle = cle
            self.nusah = nusah
            self.section = section
            self.bloc = bloc
            self.apercu = apercu
        }

        /// Une même place, quel que soit l'aperçu.
        public func memePlace(_ m: Marque) -> Bool {
            cle == m.cle && nusah == m.nusah && section == m.section && bloc == m.bloc
        }

        public func avec(nusah: String? = nil, bloc: Int? = nil, apercu: String? = nil) -> Marque {
            Marque(cle, nusah ?? self.nusah, section, bloc ?? self.bloc, apercu ?? self.apercu)
        }
    }

    /// Au plus tant de marque-pages : les plus anciens tombent.
    public static let maximum = 60

    private static let balise = ExpressionReguliere("<[^>]+>")
    private static let separateurs = ExpressionReguliere("[־׀]")
    private static let signes = ExpressionReguliere("[\\u0591-\\u05C7]")
    private static let coupures = ExpressionReguliere("[|\\n\\t]")
    private static let blancs = ExpressionReguliere("[ \\t\\n\\x0B\\f\\r]+")

    /// Les premiers mots d'un paragraphe, sans balises ni voyelles.
    public static func apercu(_ texte: String, mots: Int = 6) -> String {
        var t = balise.remplace(texte, par: " ")
        t = separateurs.remplace(t, par: " ")
        t = signes.remplace(t, par: "")
        t = coupures.remplace(t, par: " ").rogne
        return blancs.decoupe(t).prefix(max(mots, 0)).joined(separator: " ")
    }

    public static func encoder(_ l: [Marque]) -> String {
        l.map { "\($0.cle)\t\($0.nusah)\t\($0.section)\t\($0.bloc)\t\($0.apercu)" }.joined(separator: "\n")
    }

    public static func decoder(_ s: String?) -> [Marque] {
        (s ?? "").components(separatedBy: "\n").compactMap { ligne in
            let c = ligne.components(separatedBy: "\t")
            guard c.count >= 5, let section = Kotlin.versIntOuNil(c[2]), let bloc = Kotlin.versIntOuNil(c[3]) else { return nil }
            return Marque(c[0], c[1], section, bloc, c[4])
        }
    }

    /// Pose la marque, ou la retire si elle y est ; la plus récente en tête.
    public static func basculer(_ l: [Marque], _ m: Marque) -> [Marque] {
        if l.contains(where: { $0.memePlace(m) }) { return l.filter { !$0.memePlace(m) } }
        return Array(([m] + l).prefix(maximum))
    }

    /// Celles d'un texte, dans l'ordre du texte.
    public static func duTexte(_ l: [Marque], cle: String, nusah: String) -> [Marque] {
        l.enumerated().filter { $0.element.cle == cle && $0.element.nusah == nusah }
            .sorted { ($0.element.section, $0.element.bloc, $0.offset) < ($1.element.section, $1.element.bloc, $1.offset) }
            .map { $0.element }
    }
}

/// `Aeration.kt` (28/10), miroir de `web/src/js/aeration.js` : un long paragraphe de prière se coupe après une fin
/// de phrase, le premier mot passe en gras ; un psaume n'est jamais coupé. Les longueurs se comptent en unités
/// UTF-16, comme `String.length`.
public enum Aeration {

    public static let long = 500
    public static let morceau = 250
    public static let reste = 150

    private static let balise = ExpressionReguliere("<[^>]+>")
    private static let teamim = ExpressionReguliere("[\\u0591-\\u05AF]")
    private static let signes = ExpressionReguliere("[\\u0591-\\u05C7]")
    private static let ouverture = ExpressionReguliere("^(מזמור|למנצח|לדוד|שיר|תהלה לדוד|הללויה|הללו)[ :]")
    private static let blancs = ExpressionReguliere("[ \\t\\n\\x0B\\f\\r]+")
    private static let mot = ExpressionReguliere("^([\\u0590-\\u05FF\\uFB1D-\\uFB4F\"'״׳-]+)(?=[ \\t\\n\\x0B\\f\\r,:;.]|$)")

    /// Un psaume ou un passage biblique : des té'amim (au moins un pour deux mots) ou l'ouverture d'un psaume.
    public static func psaume(_ html: String) -> Bool {
        let texte = balise.remplace(html, par: "")
        let mots = max(blancs.decoupe(texte).filter { !$0.isEmpty }.count, 1)
        if Double(teamim.toutes(texte).count) / Double(mots) >= 0.5 { return true }
        return ouverture.presente(dans: signes.remplace(texte, par: "").remplacantUnites("־", par: " ").rogne)
    }

    public static func premierMot(_ html: String) -> String {
        if html.commenceParUnites("<b>") { return html }
        guard let m = mot.trouve(html) else { return html }
        let premier = m.groupes[1]
        return "<b>\(premier)</b>" + html.sansPremieresUnites(premier.utf16.count)
    }

    public static func couper(_ html: String) -> String {
        let total = balise.remplace(html, par: "").utf16.count
        if total <= long || psaume(html) { return html }
        let u = Array(html.utf16)
        var sortie: [UInt16] = []
        sortie.reserveCapacity(u.count + 64)
        let petitOuvrant = Array("<small".utf16), petitFermant = Array("</small".utf16)
        func commencePar(_ motif: [UInt16], _ i: Int) -> Bool {
            i + motif.count <= u.count && Array(u[i..<(i + motif.count)]) == motif
        }
        let chevronOuvrant = UInt16(UInt8(ascii: "<")), chevronFermant = UInt16(UInt8(ascii: ">"))
        let deuxPoints = UInt16(UInt8(ascii: ":")), sofPassouq: UInt16 = 0x05C3, espace = UInt16(UInt8(ascii: " "))
        var dansBalise = false
        var petit = 0
        var depuis = 0
        var vus = 0
        var i = 0
        while i < u.count {
            let c = u[i]
            if c == chevronOuvrant {
                dansBalise = true
                if commencePar(petitOuvrant, i) {
                    petit += 1
                } else if commencePar(petitFermant, i) {
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
            if (c == deuxPoints || c == sofPassouq) && petit == 0 && i + 1 < u.count && u[i + 1] == espace
                && depuis >= morceau && total - vus >= reste {
                sortie.append(contentsOf: Array("<br><br>".utf16))
                i += 1  // l'espace qui suivait
                depuis = 0
            }
            i += 1
        }
        return String(decoding: sortie, as: UTF16.self)
    }

    public static func aerer(_ html: String) -> String { premierMot(couper(html)) }
}

/// `MelangeMusique.kt` (28/09) : un morceau au hasard, puis un autre, aucun ne revient avant que tous aient été
/// entendus ; le dernier d'un tour n'ouvre pas le suivant. Le hasard est celui de Kotlin, pour une même graine.
public struct MelangeMusique: Sendable {
    private var hasard: HasardKotlin
    private var sac: [String] = []
    public private(set) var dernier: String?

    public init(hasard: HasardKotlin) {
        self.hasard = hasard
    }

    public init() {
        self.init(hasard: HasardKotlin(graineLongue: Int64.random(in: Int64.min...Int64.max)))
    }

    /// Le prochain morceau parmi `ids`, ou nil s'il n'y en a aucun.
    public mutating func suivant(_ ids: [String]) -> String? {
        guard !ids.isEmpty else { return nil }
        // Un morceau retiré entre-temps de la bibliothèque ne sort plus.
        sac.removeAll { !ids.contains($0) }
        if sac.isEmpty {
            var vus = Set<String>()
            var tour = hasard.melange(ids.filter { vus.insert($0).inserted })
            if tour.count > 1, tour.first == dernier { tour.swapAt(0, tour.count - 1) }
            sac = tour
        }
        let morceau = sac.removeFirst()
        dernier = morceau
        return morceau
    }
}

/// `DanseMesure.kt` : où en est le danseur du bravo à l'instant `t` d'une mesure de deux temps, en simple
/// précision comme Kotlin.
public enum DanseMesure {

    /// Un temps : un peu plus de deux pas par seconde.
    public static let tempsMillis: Int64 = 480

    private static let relais: Float = 0.1
    private static let flexion: Float = 0.14

    public struct Pas: Sendable, Equatable {
        /// 0 au sol, 1 en haut du saut.
        public let hauteur: Float
        /// 1 à la réception, 0 jambes tendues.
        public let flexion: Float
        /// -1 penché d'un côté, 1 de l'autre.
        public let balance: Float
        /// Visibilité de la pose B ; celle de la pose A est son complément.
        public let poseB: Float
    }

    public static func pas(_ t: Float) -> Pas {
        let mesure = t - t.rounded(.down)
        let temps = mesure * 2
        let second = temps >= 1
        let p = temps - temps.rounded(.down)
        let r = min(p / relais, 1)
        return Pas(hauteur: max(Float(sin(Double.pi * Double(p))), 0),
                   flexion: max(1 - p / flexion, 0),
                   balance: Float(sin(2 * Double.pi * Double(mesure))),
                   poseB: second ? r : 1 - r)
    }
}
