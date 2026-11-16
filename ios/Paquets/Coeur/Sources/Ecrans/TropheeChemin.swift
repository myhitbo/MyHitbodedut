import Foundation

// L'analyseur des chemins SVG de trophees_formes.json (TropheeDessin.kt : `PathParser.createPathFromPathData`
// d'androidx). Il rend une liste de commandes absolues en Double ; la vue en fait un `Path` de SwiftUI
// (`move(to:)`, `addLine(to:)`, `addQuadCurve(to:control:)`, `addCurve(to:control1:control2:)`,
// `closeSubpath()`), sans rien calculer elle-même.
//
// Le découpage et la lecture des nombres sont ceux d'androidx (PathParser.extract) : un nombre finit à un
// blanc, à une virgule, à un « - » qui ne suit pas un exposant, ou à un second point (« .5.5 » fait deux
// nombres). Les commandes sont toutes celles du SVG, absolues et relatives : M L H V C S Q T A Z. Comme sur
// Android :
//  - après M, les paires suivantes sont des droites ;
//  - S et T reflètent le point de contrôle précédent seulement après C/S (pour S) ou Q/T (pour T), sinon
//    le point courant ;
//  - Z referme le sous-chemin, puis repose la plume à son départ (`path.moveTo`, d'où un `.deplacer`) ;
//  - un arc devient des cubiques de Bézier, au plus 45° chacune (PathParser.drawArc, arcToBezier), le
//    rayon agrandi quand les deux bouts sont trop loin pour lui.
// Là où Android se tait ou plante, l'analyseur lève : une lettre inconnue (Android l'ignore), un nombre
// illisible (NumberFormatException), un compte de nombres qui ne remplit pas la commande (Android sort du
// tableau). Un arc de rayon nul est une droite (la règle du SVG ; Android divise par zéro).

/// Un point du chemin, dans la boîte du dessin (100 de côté pour les formes, 24 pour les icônes).
public struct TropheePoint: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// Une commande du chemin, en coordonnées absolues.
public enum TropheeCommande: Sendable, Hashable {
    /// Lève la plume et la pose là : un nouveau sous-chemin.
    case deplacer(TropheePoint)
    case ligne(TropheePoint)
    /// Une courbe de Bézier quadratique.
    case quadratique(controle: TropheePoint, fin: TropheePoint)
    /// Une courbe de Bézier cubique.
    case cubique(controle1: TropheePoint, controle2: TropheePoint, fin: TropheePoint)
    /// Referme le sous-chemin courant.
    case fermer

    /// Le point où la commande laisse la plume ; nil pour `fermer`.
    public var fin: TropheePoint? {
        switch self {
        case .deplacer(let p), .ligne(let p): p
        case .quadratique(_, let p), .cubique(_, _, let p): p
        case .fermer: nil
        }
    }
}

/// Ce qui empêche de lire un chemin.
public enum TropheeCheminErreur: Error, Sendable, Hashable {
    /// Rien à lire.
    case vide
    /// Une lettre qui n'est pas une commande du SVG, ou des nombres avant toute commande.
    case commandeInconnue(String)
    /// Un nombre qui ne se lit pas.
    case nombreIllisible(String)
    /// La commande n'a pas de quoi se remplir : aucun nombre, ou un compte qui n'est pas un multiple du sien.
    case nombresIncomplets(commande: String, nombres: Int)
}

/// Les bornes d'un chemin.
public struct TropheeBoite: Sendable, Hashable {
    public var min: TropheePoint
    public var max: TropheePoint

    public init(min: TropheePoint, max: TropheePoint) {
        self.min = min
        self.max = max
    }
}

/// Un chemin lu : ses commandes, dans l'ordre.
public struct TropheeChemin: Sendable, Hashable {
    public let commandes: [TropheeCommande]

    public init(commandes: [TropheeCommande]) {
        self.commandes = commandes
    }

    /// Lit les données d'un chemin SVG (l'attribut `d`) ; lève `TropheeCheminErreur`.
    public init(_ donnees: String) throws {
        commandes = try TropheeChemin.analyser(donnees)
    }

    /// Les bornes des points où passe la plume (contrôles exclus) ; nil sans aucun point.
    public var boite: TropheeBoite? {
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        var vu = false
        for commande in commandes {
            guard let p = commande.fin else { continue }
            vu = true
            minX = Swift.min(minX, p.x)
            minY = Swift.min(minY, p.y)
            maxX = Swift.max(maxX, p.x)
            maxY = Swift.max(maxY, p.y)
        }
        return vu ? TropheeBoite(min: TropheePoint(minX, minY), max: TropheePoint(maxX, maxY)) : nil
    }

    // MARK: La lecture

    /// Le nombre de valeurs que prend chaque commande (PathDataNode.addCommand).
    private static func pas(_ c: UInt8) -> Int? {
        switch c {
        case lettre("M"), lettre("m"), lettre("L"), lettre("l"), lettre("T"), lettre("t"): 2
        case lettre("H"), lettre("h"), lettre("V"), lettre("v"): 1
        case lettre("C"), lettre("c"): 6
        case lettre("S"), lettre("s"), lettre("Q"), lettre("q"): 4
        case lettre("A"), lettre("a"): 7
        case lettre("Z"), lettre("z"): 0
        default: nil
        }
    }

    private static func lettre(_ s: Unicode.Scalar) -> UInt8 {
        UInt8(truncatingIfNeeded: s.value)
    }

    /// Une lettre ASCII qui commence une commande (PathParser.nextStart) : toute lettre sauf l'exposant.
    private static func commenceCommande(_ c: UInt8) -> Bool {
        let estLettre = (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)
        return estLettre && c != 0x65 && c != 0x45
    }

    private static func estBlanc(_ c: UInt8) -> Bool {
        c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
    }

    /// Les segments du chemin : chaque lettre de commande et les nombres qui la suivent.
    private static func segments(_ octets: [UInt8]) throws -> [(commande: UInt8, nombres: [Double])] {
        var resultat: [(commande: UInt8, nombres: [Double])] = []
        var i = 0
        while i < octets.count {
            if estBlanc(octets[i]) || octets[i] == 0x2C {
                i += 1
                continue
            }
            let c = octets[i]
            guard commenceCommande(c), pas(c) != nil else {
                throw TropheeCheminErreur.commandeInconnue(String(decoding: [c], as: UTF8.self))
            }
            i += 1
            let debut = i
            while i < octets.count && !commenceCommande(octets[i]) { i += 1 }
            let nombres = try lireNombres(Array(octets[debut..<i]))
            resultat.append((commande: c, nombres: nombres))
        }
        return resultat
    }

    /// Les nombres d'un segment, découpés comme PathParser.extract.
    private static func lireNombres(_ o: [UInt8]) throws -> [Double] {
        var resultat: [Double] = []
        var debut = 0
        while debut < o.count {
            var i = debut
            var finSurSigneOuPoint = false
            var secondPoint = false
            var exposant = false
            while i < o.count {
                let apresExposant = exposant
                exposant = false
                var separateur = false
                let c = o[i]
                if estBlanc(c) || c == 0x2C {
                    separateur = true
                } else if c == 0x2D {
                    // Un « - » commence le nombre suivant, sauf en tête ou après un exposant.
                    if i != debut && !apresExposant {
                        separateur = true
                        finSurSigneOuPoint = true
                    }
                } else if c == 0x2E {
                    // Un second point commence le nombre suivant.
                    if secondPoint {
                        separateur = true
                        finSurSigneOuPoint = true
                    } else {
                        secondPoint = true
                    }
                } else if c == 0x65 || c == 0x45 {
                    exposant = true
                }
                if separateur { break }
                i += 1
            }
            if debut < i {
                let mot = String(decoding: o[debut..<i], as: UTF8.self)
                guard let valeur = Double(mot), valeur.isFinite else {
                    throw TropheeCheminErreur.nombreIllisible(mot)
                }
                resultat.append(valeur)
            }
            // Le « - » ou le point qui a fini ce nombre appartient au suivant.
            debut = finSurSigneOuPoint ? i : i + 1
        }
        return resultat
    }

    /// Les commandes absolues d'un chemin SVG (PathParser.PathDataNode.nodesToPath).
    public static func analyser(_ donnees: String) throws -> [TropheeCommande] {
        let lus = try segments(Array(donnees.utf8))
        guard !lus.isEmpty else { throw TropheeCheminErreur.vide }
        var sortie: [TropheeCommande] = []
        var x = 0.0
        var y = 0.0
        // Le dernier point de contrôle, pour S et T.
        var ctrlX = 0.0
        var ctrlY = 0.0
        // Le départ du sous-chemin, où Z ramène.
        var departX = 0.0
        var departY = 0.0
        // Android part de « m ».
        var precedente = lettre("m")
        for segment in lus {
            let c = segment.commande
            let v = segment.nombres
            let nom = String(decoding: [c], as: UTF8.self)
            let increment = pas(c) ?? 0
            if increment == 0 {
                // Z : les nombres qui suivraient sont ignorés, comme sur Android.
                sortie.append(.fermer)
                x = departX
                y = departY
                ctrlX = departX
                ctrlY = departY
                sortie.append(.deplacer(TropheePoint(x, y)))
                precedente = c
                continue
            }
            guard !v.isEmpty, v.count % increment == 0 else {
                throw TropheeCheminErreur.nombresIncomplets(commande: nom, nombres: v.count)
            }
            var k = 0
            while k < v.count {
                switch c {
                case lettre("m"), lettre("M"):
                    if c == lettre("m") {
                        x += v[k]
                        y += v[k + 1]
                    } else {
                        x = v[k]
                        y = v[k + 1]
                    }
                    if k > 0 {
                        sortie.append(.ligne(TropheePoint(x, y)))
                    } else {
                        sortie.append(.deplacer(TropheePoint(x, y)))
                        departX = x
                        departY = y
                    }
                case lettre("l"):
                    x += v[k]
                    y += v[k + 1]
                    sortie.append(.ligne(TropheePoint(x, y)))
                case lettre("L"):
                    x = v[k]
                    y = v[k + 1]
                    sortie.append(.ligne(TropheePoint(x, y)))
                case lettre("h"):
                    x += v[k]
                    sortie.append(.ligne(TropheePoint(x, y)))
                case lettre("H"):
                    x = v[k]
                    sortie.append(.ligne(TropheePoint(x, y)))
                case lettre("v"):
                    y += v[k]
                    sortie.append(.ligne(TropheePoint(x, y)))
                case lettre("V"):
                    y = v[k]
                    sortie.append(.ligne(TropheePoint(x, y)))
                case lettre("c"), lettre("C"):
                    let (bx, by) = c == lettre("c") ? (x, y) : (0.0, 0.0)
                    let c1 = TropheePoint(bx + v[k], by + v[k + 1])
                    let c2 = TropheePoint(bx + v[k + 2], by + v[k + 3])
                    x = bx + v[k + 4]
                    y = by + v[k + 5]
                    ctrlX = c2.x
                    ctrlY = c2.y
                    sortie.append(.cubique(controle1: c1, controle2: c2, fin: TropheePoint(x, y)))
                case lettre("s"), lettre("S"):
                    let (bx, by) = c == lettre("s") ? (x, y) : (0.0, 0.0)
                    var c1 = TropheePoint(x, y)
                    if precedente == lettre("c") || precedente == lettre("C")
                        || precedente == lettre("s") || precedente == lettre("S") {
                        c1 = TropheePoint(2 * x - ctrlX, 2 * y - ctrlY)
                    }
                    let c2 = TropheePoint(bx + v[k], by + v[k + 1])
                    x = bx + v[k + 2]
                    y = by + v[k + 3]
                    ctrlX = c2.x
                    ctrlY = c2.y
                    sortie.append(.cubique(controle1: c1, controle2: c2, fin: TropheePoint(x, y)))
                case lettre("q"), lettre("Q"):
                    let (bx, by) = c == lettre("q") ? (x, y) : (0.0, 0.0)
                    let controle = TropheePoint(bx + v[k], by + v[k + 1])
                    x = bx + v[k + 2]
                    y = by + v[k + 3]
                    ctrlX = controle.x
                    ctrlY = controle.y
                    sortie.append(.quadratique(controle: controle, fin: TropheePoint(x, y)))
                case lettre("t"), lettre("T"):
                    let (bx, by) = c == lettre("t") ? (x, y) : (0.0, 0.0)
                    var controle = TropheePoint(x, y)
                    if precedente == lettre("q") || precedente == lettre("Q")
                        || precedente == lettre("t") || precedente == lettre("T") {
                        controle = TropheePoint(2 * x - ctrlX, 2 * y - ctrlY)
                    }
                    x = bx + v[k]
                    y = by + v[k + 1]
                    ctrlX = controle.x
                    ctrlY = controle.y
                    sortie.append(.quadratique(controle: controle, fin: TropheePoint(x, y)))
                default:
                    // A ou a : le seul cas restant (`pas` a écarté les autres lettres).
                    let (bx, by) = c == lettre("a") ? (x, y) : (0.0, 0.0)
                    let finX = bx + v[k + 5]
                    let finY = by + v[k + 6]
                    arc(&sortie, x0: x, y0: y, x1: finX, y1: finY, a: v[k], b: v[k + 1], rotation: v[k + 2],
                        grand: v[k + 3] != 0, positif: v[k + 4] != 0)
                    x = finX
                    y = finY
                    ctrlX = x
                    ctrlY = y
                }
                precedente = c
                k += increment
            }
        }
        return sortie
    }

    // MARK: Les arcs (PathParser.drawArc et arcToBezier)

    /// L'arc de (x0, y0) à (x1, y1), d'ellipse de rayons `a` et `b` tournée de `rotation` degrés, en cubiques.
    private static func arc(_ sortie: inout [TropheeCommande], x0: Double, y0: Double, x1: Double, y1: Double,
                            a: Double, b: Double, rotation: Double, grand: Bool, positif: Bool) {
        if a == 0 || b == 0 {
            sortie.append(.ligne(TropheePoint(x1, y1)))
            return
        }
        let theta = rotation * Double.pi / 180
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)
        // Les deux bouts dans l'espace où l'ellipse est un cercle unité.
        let x0p = (x0 * cosTheta + y0 * sinTheta) / a
        let y0p = (-x0 * sinTheta + y0 * cosTheta) / b
        let x1p = (x1 * cosTheta + y1 * sinTheta) / a
        let y1p = (-x1 * sinTheta + y1 * cosTheta) / b
        let dx = x0p - x1p
        let dy = y0p - y1p
        let xm = (x0p + x1p) / 2
        let ym = (y0p + y1p) / 2
        let dsq = dx * dx + dy * dy
        // Les deux bouts confondus : rien à tracer.
        if dsq == 0 { return }
        let disc = 1.0 / dsq - 1.0 / 4.0
        if disc < 0 {
            // Trop loin l'un de l'autre pour ce rayon : le rayon grandit juste assez.
            let ajuste = dsq.squareRoot() / 1.99999
            arc(&sortie, x0: x0, y0: y0, x1: x1, y1: y1, a: a * ajuste, b: b * ajuste, rotation: rotation,
                grand: grand, positif: positif)
            return
        }
        let s = disc.squareRoot()
        let sdx = s * dx
        let sdy = s * dy
        var cx: Double
        var cy: Double
        if grand == positif {
            cx = xm - sdy
            cy = ym + sdx
        } else {
            cx = xm + sdy
            cy = ym - sdx
        }
        let eta0 = atan2(y0p - cy, x0p - cx)
        let eta1 = atan2(y1p - cy, x1p - cx)
        var balayage = eta1 - eta0
        if positif != (balayage >= 0) {
            if balayage > 0 {
                balayage -= 2 * Double.pi
            } else {
                balayage += 2 * Double.pi
            }
        }
        cx *= a
        cy *= b
        let tcx = cx
        cx = cx * cosTheta - cy * sinTheta
        cy = tcx * sinTheta + cy * cosTheta
        enBeziers(&sortie, cx: cx, cy: cy, a: a, b: b, e1x: x0, e1y: y0, theta: theta, debut: eta0,
                  balayage: balayage)
    }

    /// L'arc d'ellipse de centre (cx, cy) en cubiques d'au plus 45° (spaceroots.org, comme Android).
    private static func enBeziers(_ sortie: inout [TropheeCommande], cx: Double, cy: Double, a: Double, b: Double,
                                  e1x: Double, e1y: Double, theta: Double, debut: Double, balayage: Double) {
        let nombre = Int((abs(balayage * 4 / Double.pi)).rounded(.up))
        guard nombre > 0 else { return }
        var eta1 = debut
        var e1x = e1x
        var e1y = e1y
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)
        var ep1x = (-a * cosTheta * sin(eta1)) - (b * sinTheta * cos(eta1))
        var ep1y = (-a * sinTheta * sin(eta1)) + (b * cosTheta * cos(eta1))
        let angle = balayage / Double(nombre)
        for _ in 0..<nombre {
            let eta2 = eta1 + angle
            let sinEta2 = sin(eta2)
            let cosEta2 = cos(eta2)
            let e2x = cx + (a * cosTheta * cosEta2) - (b * sinTheta * sinEta2)
            let e2y = cy + (a * sinTheta * cosEta2) + (b * cosTheta * sinEta2)
            let ep2x = -a * cosTheta * sinEta2 - b * sinTheta * cosEta2
            let ep2y = -a * sinTheta * sinEta2 + b * cosTheta * cosEta2
            let tanDemi = tan((eta2 - eta1) / 2)
            let alpha = sin(eta2 - eta1) * ((4 + 3 * tanDemi * tanDemi).squareRoot() - 1) / 3
            let q1 = TropheePoint(e1x + alpha * ep1x, e1y + alpha * ep1y)
            let q2 = TropheePoint(e2x - alpha * ep2x, e2y - alpha * ep2y)
            sortie.append(.cubique(controle1: q1, controle2: q2, fin: TropheePoint(e2x, e2y)))
            eta1 = eta2
            e1x = e2x
            e1y = e2y
            ep1x = ep2x
            ep1y = ep2y
        }
    }
}
