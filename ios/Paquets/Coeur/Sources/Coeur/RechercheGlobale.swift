import Foundation

/// La recherche dans toute l'application (RechercheGlobale.kt, 14/10) : le siddour, les livres, la halakha
/// (Yalkut Yosef, Ben Ish 'Haï) et les hilloulot, d'un seul champ. Sans voyelles, cantillation, guillemets
/// ni balises, et sans tenir compte de la casse. Le même calcul que rechercheGlobale() du web.
///
/// Tout se compte en unités UTF-16, comme Kotlin : la trouvaille (`contientUnites`) et l'extrait (des
/// positions dans le texte mis à nu). Swift comparerait des caractères entiers, et une lettre hébraïque
/// et ses voyelles n'y font qu'un.
///
/// Le juge : `Tests/Vecteurs/recherche.json`, écrit par le code d'Android (tools/vecteurs_ios/VecteursRecherche.kt).
public enum RechercheGlobale {

    /// D'où vient un résultat. La valeur est le nom de l'énumération de Kotlin.
    public enum Sorte: String, Sendable, CaseIterable {
        case siddour = "SIDDOUR"
        case livre = "LIVRE"
        case halakha = "HALAKHA"
        case hilloula = "HILLOULA"
    }

    /// Un résultat : sa sorte, ce qu'il ouvre (l'id d'un texte, ou la recherche elle-même pour la halakha et
    /// les hilloulot), son titre et un extrait.
    public struct Resultat: Sendable, Equatable {
        public let sorte: Sorte
        public let id: String
        public let titre: String
        public let extrait: String

        public init(sorte: Sorte, id: String, titre: String, extrait: String) {
            self.sorte = sorte
            self.id = id
            self.titre = titre
            self.extrait = extrait
        }
    }

    /// Au plus tant de résultats de chaque source (`PAR_SORTE`).
    public static let parSorte = 30

    // MARK: Le texte mis à nu

    /// Les accents latins et l'apostrophe typographique tombent aussi : « priere » trouve « Prières »,
    /// « hachahar » trouve « Birkot hacha’har » (vérification du 29/10). Les étapes de Kotlin, dans son ordre :
    /// NFD, sans U+0300 à U+036F ni ’ ‘ ; chaque balise `<[^>]+>` en une espace ; le maqaf et le paseq en
    /// espace ; sans les voyelles et les te'amim (U+0591 à U+05C7), les guillemets droits, le guéresh et le
    /// guershayim ; chaque suite de blancs `\s+` en une espace (`\s` de la JVM : espace, U+0009 à U+000D) ;
    /// rogné (`trim`) ; en minuscules.
    public static func nu(_ t: String) -> String {
        // NFD, sans les diacritiques latins ni les apostrophes typographiques. NFD ne change rien à un texte
        // fait d'unités avant U+00C0 et de l'hébreu (U+0590 à U+05FF) : aucune n'a de décomposition canonique,
        // et il n'y range que les points hébreux entre eux, qui tombent tous ensuite. Le siddour et les
        // livres s'épargnent ainsi la normalisation de Foundation.
        let simple = t.utf16.allSatisfy { $0 < 0x00C0 || ($0 >= 0x0590 && $0 <= 0x05FF) }
        let decompose = simple ? t : t.formeNFD
        var a: [UInt16] = []
        a.reserveCapacity(decompose.utf16.count)
        for u in decompose.utf16 {
            switch u {
            case 0x0300...0x036F, 0x2018, 0x2019: continue
            default: a.append(u)
            }
        }
        // `<[^>]+>` : un « < », au moins une unité autre que « > », puis le premier « > » qui suit.
        var b: [UInt16] = []
        b.reserveCapacity(a.count)
        var suivant = -1
        var i = 0
        while i < a.count {
            if a[i] == 0x3C && i + 1 < a.count && a[i + 1] != 0x3E {
                if suivant <= i {
                    suivant = i + 1
                    while suivant < a.count && a[suivant] != 0x3E { suivant += 1 }
                }
                if suivant < a.count {
                    b.append(0x20)
                    i = suivant + 1
                    continue
                }
            }
            b.append(a[i])
            i += 1
        }
        // Le maqaf et le paseq en espace, puis sans voyelles, te'amim ni guillemets ; les blancs réduits.
        var c: [UInt16] = []
        c.reserveCapacity(b.count)
        var dansBlanc = false
        for u in b {
            let v: UInt16
            switch u {
            case 0x05BE, 0x05C0: v = 0x20
            case 0x0591...0x05C7, 0x22, 0x27, 0x05F3, 0x05F4: continue
            default: v = u
            }
            if v == 0x20 || (v >= 0x09 && v <= 0x0D) {
                if !dansBlanc { c.append(0x20) }
                dansBlanc = true
            } else {
                c.append(v)
                dansBlanc = false
            }
        }
        return Unites.texte(c).rogne.lowercased()
    }

    /// Un extrait d'une quarantaine de caractères autour de la trouvaille, dans le texte sans voyelles : trente
    /// unités avant, cinquante après ; « … » là où le texte continue. Sans trouvaille, le début du texte.
    public static func extrait(_ texte: String, _ q: String) -> String {
        let t = Array(nu(texte).utf16)
        let motif = Array(q.utf16)
        let i = Unites.position(de: motif, dans: t) ?? 0
        let debut = max(i - 30, 0)
        let fin = min(i + motif.count + 50, t.count)
        let milieu = Unites.texte(t[debut..<fin]).rogne
        let avant = debut > 0 ? "…" : ""
        let apres = i + motif.count + 50 < t.count ? "…" : ""
        return avant + milieu + apres
    }

    // MARK: Les sources

    /// Les textes d'un recueil (siddour ou livres) : le titre d'abord, puis le premier paragraphe qui contient
    /// la recherche (`q`, déjà mise à nu) ; trente textes au plus.
    public static func dansRecueil(_ recueil: Siddur, _ q: String, _ sorte: Sorte, langue: String) -> [Resultat] {
        let motif = Array(q.utf16)
        var resultats: [Resultat] = []
        for t in recueil.textes {
            // take(PAR_SORTE) : ce qui suit le trentième ne changerait rien.
            if resultats.count >= parSorte { break }
            let titre = t.titre.he
            let traduit = t.titre.pour(langue)
            if contient(nu(titre), motif) || contient(nu(traduit), motif) {
                resultats.append(Resultat(sorte: sorte, id: t.id, titre: titre, extrait: traduit.egalUnites(titre) ? "" : traduit))
                continue
            }
            blocs: for section in t.sections {
                for bloc in section.blocs where !bloc.consigne && contient(nu(bloc.texte), motif) {
                    resultats.append(Resultat(sorte: sorte, id: t.id, titre: titre, extrait: extrait(bloc.texte, q)))
                    break blocs
                }
            }
        }
        return resultats
    }

    private static func contient(_ texte: String, _ motif: [UInt16]) -> Bool {
        Unites.position(de: motif, dans: Array(texte.utf16)) != nil
    }

    /// Où chercher (19/10) : tout, ou seulement les prières, les halakhot, les livres ou les hilloulot. La
    /// valeur est le nom de l'énumération de Kotlin.
    public enum Portee: String, Sendable, CaseIterable {
        case tout = "TOUT"
        case tefilot = "TEFILOT"
        case halakhot = "HALAKHOT"
        case sefarim = "SEFARIM"
        case hilloulot = "HILLOULOT"

        public var sortes: Set<Sorte> {
            switch self {
            case .tout: return Set(Sorte.allCases)
            case .tefilot: return [.siddour]
            case .halakhot: return [.halakha]
            case .sefarim: return [.livre]
            case .hilloulot: return [.hilloula]
            }
        }
    }

    /// Une hilloula trouvée : le nom dans la langue de l'interface quand il existe, sinon l'hébreu (audit
    /// 1.390 : l'hébreu s'affichait même quand le nom français existait). L'hébreu, isolé (FSI … PDI),
    /// passe alors sous le nom, avec l'année.
    public static func resultatHilloula(_ texte: String, _ x: Hilloulot.Hilloula, langue: String) -> Resultat {
        let nom: String?
        if langue.commenceParUnites("en") {
            nom = x.en
        } else if langue.commenceParUnites("fr") {
            nom = x.fr
        } else {
            nom = nil
        }
        let traduit = nom.flatMap { n -> String? in n.estBlanc ? nil : n }
        var parties: [String] = []
        if traduit != nil { parties.append("\u{2068}\(x.he)\u{2069}") }
        if !x.annee.estBlanc { parties.append(x.annee) }
        return Resultat(sorte: .hilloula, id: texte, titre: traduit ?? x.he, extrait: parties.joined(separator: " · "))
    }

    /// La recherche : moins de deux unités une fois mise à nu, rien ; sinon chaque source de la portée, dans
    /// l'ordre de `Sorte`, trente résultats au plus chacune (la halakha : trente du Yalkut Yosef, puis trente
    /// du Ben Ish 'Haï). Une source absente (nil) est passée.
    public static func chercher(_ texte: String, langue: String, siddur: Siddur, livres: Siddur?,
                                yalkut: YalkutYosef.Livre?, benIshHai: Halakha.Livre?, hilloulot: Hilloulot.Table?,
                                portee: Portee = .tout) -> [Resultat] {
        let q = nu(texte.rogne)
        if q.utf16.count < 2 { return [] }
        let s = portee.sortes
        var resultats: [Resultat] = []
        if s.contains(.siddour) {
            resultats += dansRecueil(siddur, q, .siddour, langue: langue)
        }
        if s.contains(.livre), let livres {
            resultats += dansRecueil(livres, q, .livre, langue: langue)
        }
        if s.contains(.halakha), let yalkut {
            for seif in YalkutYosef.recherche(yalkut, texte: texte).prefix(parSorte) {
                resultats.append(Resultat(sorte: .halakha, id: texte, titre: YalkutYosef.source(seif), extrait: extrait(seif.texte, q)))
            }
        }
        if s.contains(.halakha), let benIshHai {
            for h in Halakha.recherche(benIshHai, texte: texte).prefix(parSorte) {
                resultats.append(Resultat(sorte: .halakha, id: texte, titre: Halakha.source(h), extrait: extrait(h.texte, q)))
            }
        }
        if s.contains(.hilloula), let hilloulot {
            for trouvee in Hilloulot.recherche(hilloulot, texte: texte).prefix(parSorte) {
                resultats.append(resultatHilloula(texte, trouvee.hilloula, langue: langue))
            }
        }
        return resultats
    }
}
