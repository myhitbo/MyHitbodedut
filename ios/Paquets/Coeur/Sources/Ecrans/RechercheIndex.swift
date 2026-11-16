import Foundation
import Coeur

// L'index de la recherche globale (PORTAGE.md § 2.2.10). Android relit et remet à nu tout le corpus à chaque
// frappe (RechercheGlobale.chercher, 28 Mo) ; ici chaque texte n'est mis à nu qu'une fois, à la préparation, et
// une recherche ne fait plus que parcourir des octets. Les règles de résultat sont celles de Coeur, à l'identique
// (RechercheIndexTests le vérifie contre `RechercheGlobale.chercher`, requête par requête) : un résultat par
// prière ou par livre, trente par source, le même titre, le même extrait, le même ordre.
//
// En attendant l'index construit à l'export (une base SQLite lue en place, § 2.2.10), celui-ci se construit en
// mémoire, hors du fil principal, à l'ouverture de l'écran de recherche.

/// Ce que la recherche parcourt, lu une fois : le siddour du noussa'h choisi, les livres entiers, le Yalkut
/// Yosef, le Ben Ish 'Haï et les hilloulot (sans leurs biographies). Une source absente (nil) est passée, comme
/// dans `RechercheGlobale.chercher`.
public struct RechercheSources: Sendable {
    public let nusah: Nusah
    public let siddur: Siddur
    public let livres: Siddur?
    public let yalkut: YalkutYosef.Livre?
    public let benIshHai: Halakha.Livre?
    public let hilloulot: Hilloulot.Table?

    public init(nusah: Nusah, siddur: Siddur, livres: Siddur?, yalkut: YalkutYosef.Livre?,
                benIshHai: Halakha.Livre?, hilloulot: Hilloulot.Table?) {
        self.nusah = nusah
        self.siddur = siddur
        self.livres = livres
        self.yalkut = yalkut
        self.benIshHai = benIshHai
        self.hilloulot = hilloulot
    }

    /// Les sources lues dans les contenus de l'app. Les livres entiers, dans l'ordre de l'index (`Data.livres`
    /// d'Android : un livre illisible est passé) ; une autre source illisible vaut nil. Sans siddour, nil : la
    /// recherche ne rend rien (Android : `runCatching { … }.getOrDefault(emptyList())`).
    public static func charger(contenus: ContenusApp, hilloulot: HilloulotContenus, nusah: Nusah) async -> RechercheSources? {
        guard let siddur = try? await contenus.siddur(nusah) else { return nil }
        var livres: Siddur?
        if let index = try? await contenus.livres() {
            var textes: [SiddurTexte] = []
            for entree in index.textes {
                if let livre = try? await contenus.livre(entree.id) { textes.append(livre) }
            }
            livres = Siddur(groupes: index.groupes, textes: textes, nusah: index.nusah, sources: index.sources)
        }
        let yalkut = try? await contenus.yalkutYosef()
        let benIshHai = try? await contenus.benIshHai()
        let table = try? await hilloulot.table()
        return RechercheSources(nusah: nusah, siddur: siddur, livres: livres, yalkut: yalkut, benIshHai: benIshHai,
                                hilloulot: table)
    }
}

/// L'index : chaque source déjà mise à nu, de quoi rendre en quelques millisecondes ce que rend
/// `RechercheGlobale.chercher` sur les mêmes sources.
public struct RechercheIndex: Sendable {

    /// Le noussa'h du siddour indexé : un autre choisi dans les réglages, le siddour se réindexe (`avec`).
    public let nusah: Nusah
    /// La langue de l'app (« fr », « en », « he ») : celle des titres traduits et des noms des hilloulot.
    public let langue: String

    private let siddour: RechercheRecueil
    private let livres: RechercheRecueil?
    private let yalkut: RechercheListe<YalkutYosef.Seif>?
    private let benIshHai: RechercheListe<Halakha.Choisie>?
    private let hilloulot: RechercheListe<Hilloulot.Hilloula>?

    /// Met chaque source à nu : des secondes sur un téléphone ancien, à faire hors du fil principal.
    public init(_ sources: RechercheSources, langue: String) {
        nusah = sources.nusah
        self.langue = langue
        siddour = RechercheRecueil(sources.siddur, sorte: .siddour, langue: langue)
        livres = sources.livres.map { RechercheRecueil($0, sorte: .livre, langue: langue) }
        yalkut = sources.yalkut.map(RechercheIndex.listeSeifs)
        benIshHai = sources.benIshHai.map(RechercheIndex.listeHalakhot)
        hilloulot = sources.hilloulot.map(RechercheIndex.listeHilloulot)
    }

    private init(nusah: Nusah, langue: String, siddour: RechercheRecueil, autres: RechercheIndex) {
        self.nusah = nusah
        self.langue = langue
        self.siddour = siddour
        livres = autres.livres
        yalkut = autres.yalkut
        benIshHai = autres.benIshHai
        hilloulot = autres.hilloulot
    }

    /// Le même index sur le siddour d'un autre noussa'h : les livres, la halakha et les hilloulot restent.
    public func avec(siddur: Siddur, nusah: Nusah) -> RechercheIndex {
        RechercheIndex(nusah: nusah, langue: langue,
                       siddour: RechercheRecueil(siddur, sorte: .siddour, langue: langue), autres: self)
    }

    /// `RechercheGlobale.chercher(texte, langue, …, portee)` : moins de deux unités une fois mise à nu, rien ;
    /// sinon chaque source de la portée, dans l'ordre de `Sorte`, trente résultats au plus chacune (la halakha :
    /// trente du Yalkut Yosef, puis trente du Ben Ish 'Haï).
    public func chercher(_ texte: String, portee: RechercheGlobale.Portee = .tout) -> [RechercheGlobale.Resultat] {
        let q = RechercheGlobale.nu(texte.rogne)
        if q.utf16.count < 2 { return [] }
        let motif = Data(q.utf8)
        let s = portee.sortes
        var resultats: [RechercheGlobale.Resultat] = []
        if s.contains(.siddour) {
            resultats += siddour.chercher(q, motif: motif)
        }
        if s.contains(.livre), let livres {
            resultats += livres.chercher(q, motif: motif)
        }
        if s.contains(.halakha) {
            // YalkutYosef.recherche et Halakha.recherche mettent la requête à nu à leur façon : sans casse ni
            // blancs touchés, sans balises ôtées ; moins de deux unités, rien.
            let h = RechercheIndex.nuHalakha(texte.rogne)
            if h.count >= 2 {
                let motifHalakha = Data(String(decoding: h, as: UTF16.self).utf8)
                for seif in yalkut?.trouves(motifHalakha) ?? [] {
                    resultats.append(RechercheGlobale.Resultat(sorte: .halakha, id: texte, titre: YalkutYosef.source(seif),
                                                               extrait: RechercheGlobale.extrait(seif.texte, q)))
                }
                for choisie in benIshHai?.trouves(motifHalakha) ?? [] {
                    resultats.append(RechercheGlobale.Resultat(sorte: .halakha, id: texte, titre: Halakha.source(choisie),
                                                               extrait: RechercheGlobale.extrait(choisie.texte, q)))
                }
            }
        }
        if s.contains(.hilloula), let hilloulot {
            for h in hilloulot.trouves(motif) {
                resultats.append(RechercheGlobale.resultatHilloula(texte, h, langue: langue))
            }
        }
        return resultats
    }

    // MARK: La halakha et les hilloulot, dans l'ordre de leur recherche

    /// Les se'ifim de `YalkutYosef.recherche` : chacun une fois (le premier, égal unité pour unité), dans
    /// l'ordre des périodes ; trouvé si son texte ou son siman contient la requête.
    private static func listeSeifs(_ livre: YalkutYosef.Livre) -> RechercheListe<YalkutYosef.Seif> {
        var vus = Set<[[UInt16]]>()
        var elements: [YalkutYosef.Seif] = []
        var textes: [[String]] = []
        for p in livre.ordre {
            for s in livre.periodes[p] ?? [] {
                guard vus.insert([Array(s.siman.utf16), Array(s.lettre.utf16), Array(s.texte.utf16)]).inserted else {
                    continue
                }
                elements.append(s)
                textes.append([nuHalakhaTexte(s.texte), nuHalakhaTexte(s.siman)])
            }
        }
        return RechercheListe(elements: elements, textes: textes)
    }

    /// Les halakhot de `Halakha.recherche` : les années dans l'ordre de leur nom, chacune dans l'ordre du
    /// fichier, puis 'Hanouka.
    private static func listeHalakhot(_ livre: Halakha.Livre) -> RechercheListe<Halakha.Choisie> {
        var elements: [Halakha.Choisie] = []
        for a in livre.annees.keys.sorted(by: { $0.utf16.lexicographicallyPrecedes($1.utf16) }) {
            guard let sections = livre.annees[a] else { continue }
            let annee = Int(a) ?? 0
            for p in livre.parachiot[a] ?? [] {
                guard let section = sections[p] else { continue }
                for (i, t) in section.halakhot.enumerated() {
                    elements.append(Halakha.Choisie(texte: t, numero: i + 1, section: section.he, annee: annee))
                }
            }
        }
        if let h = livre.hanouka {
            for (i, t) in h.halakhot.enumerated() {
                elements.append(Halakha.Choisie(texte: t, numero: i + 1, section: h.he, annee: 1))
            }
        }
        return RechercheListe(elements: elements, textes: elements.map { [nuHalakhaTexte($0.texte)] })
    }

    /// Les hilloulot de `Hilloulot.recherche` : par rang dans l'année, de Tichri à Eloul, puis par clé, puis dans
    /// l'ordre du fichier ; trouvée si le nom hébreu, français ou anglais contient la requête.
    private static func listeHilloulot(_ table: Hilloulot.Table) -> RechercheListe<Hilloulot.Hilloula> {
        var rangees: [(rang: Int, cle: String, indice: Int, hilloula: Hilloulot.Hilloula)] = []
        for (cle, liste) in table {
            let rang = Hilloulot.rangDansLAnnee(cle)
            for (i, h) in liste.enumerated() {
                rangees.append((rang: rang, cle: cle, indice: i, hilloula: h))
            }
        }
        rangees.sort { a, b in
            if a.rang != b.rang { return a.rang < b.rang }
            if !a.cle.egalUnites(b.cle) { return a.cle.utf16.lexicographicallyPrecedes(b.cle.utf16) }
            return a.indice < b.indice
        }
        let elements = rangees.map { $0.hilloula }
        let textes = elements.map { h -> [String] in
            var noms = [RechercheGlobale.nu(h.he)]
            if let fr = h.fr { noms.append(RechercheGlobale.nu(fr)) }
            if let en = h.en { noms.append(RechercheGlobale.nu(en)) }
            return noms
        }
        return RechercheListe(elements: elements, textes: textes)
    }

    /// La mise à nu de Halakha.kt et de YalkutYosef.kt (leurs deux `Regex`), unité par unité : le maqaf et le
    /// paseq deviennent une espace ; les voyelles et les te'amim (U+0591 à U+05C7), les guillemets droits, le
    /// guéresh et le guershayim disparaissent. Rien d'autre : ni la casse, ni les blancs, ni les balises.
    static func nuHalakha(_ t: String) -> [UInt16] {
        var sortie: [UInt16] = []
        sortie.reserveCapacity(t.utf16.count)
        for u in t.utf16 {
            switch u {
            case 0x05BE, 0x05C0: sortie.append(0x20)
            case 0x0591...0x05C7, 0x22, 0x27, 0x05F3, 0x05F4: continue
            default: sortie.append(u)
            }
        }
        return sortie
    }

    /// Le même, en texte : aucune unité ôtée n'est une moitié de paire de substitution, le texte reste entier.
    private static func nuHalakhaTexte(_ t: String) -> String {
        String(decoding: nuHalakha(t), as: UTF16.self)
    }
}

// MARK: Le tampon

/// Des textes mis à nu, bout à bout en UTF-8, chacun suivi de l'octet 0xFF, qu'aucun texte UTF-8 ne contient :
/// une trouvaille ne déborde jamais d'un texte sur le suivant. Chercher des octets UTF-8 revient à chercher des
/// unités UTF-16 (`contientUnites`) : un texte de Swift est toujours de l'Unicode valide, et les deux codages
/// n'y trouvent un motif qu'aux mêmes frontières de caractères. Un élément peut avoir plusieurs textes (le nom
/// hébreu, français et anglais d'une hilloula) : il est trouvé si l'un d'eux contient le motif.
///
/// La recherche elle-même est celle de Foundation (`Data.range(of:in:)`), compilée optimisée même quand l'app
/// ou ses tests ne le sont pas.
struct RechercheTampon: Sendable {
    private let octets: Data
    /// Le premier octet de chaque élément ; en dernier, la longueur du tampon.
    private let bornes: [Int]

    init(_ elements: [[String]]) {
        var octets: [UInt8] = []
        var bornes: [Int] = []
        bornes.reserveCapacity(elements.count + 1)
        for textes in elements {
            bornes.append(octets.count)
            for texte in textes {
                octets.append(contentsOf: texte.utf8)
                octets.append(0xFF)
            }
        }
        bornes.append(octets.count)
        self.octets = Data(octets)
        self.bornes = bornes
    }

    /// Le nombre d'éléments.
    var nombre: Int { bornes.count - 1 }

    /// Le premier élément de `debut ..< fin` dont un texte contient `motif` (de l'UTF-8 non vide) ; nil sinon.
    func premier(contenant motif: Data, de debut: Int, a fin: Int) -> Int? {
        guard debut < fin, !motif.isEmpty else { return nil }
        guard let trouve = octets.range(of: motif, in: bornes[debut]..<bornes[fin]) else { return nil }
        // Le dernier élément qui commence au plus tard à la trouvaille : celui qui la contient.
        var bas = debut
        var haut = fin - 1
        while bas < haut {
            let milieu = (bas + haut + 1) / 2
            if bornes[milieu] <= trouve.lowerBound {
                bas = milieu
            } else {
                haut = milieu - 1
            }
        }
        return bas
    }
}

/// Une source faite d'éléments à rendre tels quels (se'ifim, halakhot, hilloulot), dans l'ordre de sa recherche.
struct RechercheListe<Element: Sendable>: Sendable {
    let elements: [Element]
    private let tampon: RechercheTampon

    init(elements: [Element], textes: [[String]]) {
        self.elements = elements
        tampon = RechercheTampon(textes)
    }

    /// Les premiers éléments trouvés, `RechercheGlobale.parSorte` au plus : le `prefix(PAR_SORTE)` de Kotlin.
    func trouves(_ motif: Data, auPlus limite: Int = RechercheGlobale.parSorte) -> [Element] {
        var trouves: [Element] = []
        var depuis = 0
        while trouves.count < limite, let i = tampon.premier(contenant: motif, de: depuis, a: tampon.nombre) {
            trouves.append(elements[i])
            depuis = i + 1
        }
        return trouves
    }
}

/// Un recueil (le siddour ou les livres) : `RechercheGlobale.dansRecueil`. Chaque texte, le titre d'abord (hébreu
/// ou traduit), puis son premier bloc (hors consignes) qui contient la requête ; trente textes au plus.
struct RechercheRecueil: Sendable {

    struct Texte: Sendable {
        let id: String
        let titre: String
        let traduit: String
        let titreNu: String
        let traduitNu: String
        /// Ses blocs, parmi ceux du recueil.
        let blocs: Range<Int>
    }

    let sorte: RechercheGlobale.Sorte
    let textes: [Texte]
    /// Le texte de chaque bloc, pour l'extrait.
    private let blocs: [String]
    private let tampon: RechercheTampon

    init(_ recueil: Siddur, sorte: RechercheGlobale.Sorte, langue: String) {
        self.sorte = sorte
        var textes: [Texte] = []
        var blocs: [String] = []
        var nus: [[String]] = []
        for t in recueil.textes {
            let debut = blocs.count
            for section in t.sections {
                for bloc in section.blocs where !bloc.consigne {
                    blocs.append(bloc.texte)
                    nus.append([RechercheGlobale.nu(bloc.texte)])
                }
            }
            let titre = t.titre.he
            let traduit = t.titre.pour(langue)
            textes.append(Texte(id: t.id, titre: titre, traduit: traduit, titreNu: RechercheGlobale.nu(titre),
                                traduitNu: RechercheGlobale.nu(traduit), blocs: debut..<blocs.count))
        }
        self.textes = textes
        self.blocs = blocs
        tampon = RechercheTampon(nus)
    }

    /// `q` déjà mis à nu, `motif` ses octets UTF-8.
    func chercher(_ q: String, motif: Data) -> [RechercheGlobale.Resultat] {
        var resultats: [RechercheGlobale.Resultat] = []
        for t in textes {
            if resultats.count >= RechercheGlobale.parSorte { break }
            if t.titreNu.contientUnites(q) || t.traduitNu.contientUnites(q) {
                resultats.append(RechercheGlobale.Resultat(sorte: sorte, id: t.id, titre: t.titre,
                                                           extrait: t.traduit.egalUnites(t.titre) ? "" : t.traduit))
                continue
            }
            if let b = tampon.premier(contenant: motif, de: t.blocs.lowerBound, a: t.blocs.upperBound) {
                resultats.append(RechercheGlobale.Resultat(sorte: sorte, id: t.id, titre: t.titre,
                                                           extrait: RechercheGlobale.extrait(blocs[b], q)))
            }
        }
        return resultats
    }
}
