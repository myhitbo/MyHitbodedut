import Foundation

// Les chaînes comme Kotlin les voit : des suites d'unités UTF-16, comparées unité par unité.
// Swift compare des caractères entiers, à l'équivalence canonique près : une lettre hébraïque et ses
// voyelles n'y font qu'un caractère, « é » y vaut « e » suivi de son accent, et `contains("מ")` ne
// trouve pas le mem de « מָה ». Les règles portées d'Android passent donc par ces fonctions partout où
// le texte peut porter des voyelles, des te'amim ou des accents. Jugées par `Tests/Vecteurs/socle.json`.

/// Recherches dans des suites d'unités UTF-16, avec les conventions de `java.lang.String`.
public enum Unites {

    /// `indexOf(motif, depuis)` : la première position de `motif` à partir de `depuis`, ou `nil`.
    /// Un motif vide est trouvé à `depuis`, ramené à la longueur du texte.
    public static func position(de motif: [UInt16], dans texte: [UInt16], depuis: Int = 0) -> Int? {
        let debut = max(0, depuis)
        if motif.isEmpty { return min(debut, texte.count) }
        if motif.count > texte.count { return nil }
        let dernier = texte.count - motif.count
        if debut > dernier { return nil }
        let premiere = motif[0]
        var i = debut
        while i <= dernier {
            if texte[i] == premiere {
                var j = 1
                while j < motif.count && texte[i + j] == motif[j] { j += 1 }
                if j == motif.count { return i }
            }
            i += 1
        }
        return nil
    }

    /// `lastIndexOf(motif)` de Kotlin : la dernière position de `motif`, ou `nil`. Kotlin cherche à partir
    /// du dernier indice : un motif vide y est trouvé, sauf dans un texte vide.
    public static func dernierePosition(de motif: [UInt16], dans texte: [UInt16]) -> Int? {
        if motif.isEmpty { return texte.isEmpty ? nil : texte.count - 1 }
        if motif.count > texte.count { return nil }
        var i = texte.count - motif.count
        while i >= 0 {
            var j = 0
            while j < motif.count && texte[i + j] == motif[j] { j += 1 }
            if j == motif.count { return i }
            i -= 1
        }
        return nil
    }

    /// Le texte de ces unités. Une moitié de paire de substitution restée seule est retirée : une chaîne
    /// de Swift ne peut pas la porter, et elle ne s'afficherait pas.
    public static func texte<S: Sequence>(_ unites: S) -> String where S.Element == UInt16 {
        let liste = Array(unites)
        var saines: [UInt16] = []
        saines.reserveCapacity(liste.count)
        var i = 0
        while i < liste.count {
            let unite = liste[i]
            if UTF16.isLeadSurrogate(unite) {
                if i + 1 < liste.count && UTF16.isTrailSurrogate(liste[i + 1]) {
                    saines.append(unite)
                    saines.append(liste[i + 1])
                    i += 1
                }
            } else if !UTF16.isTrailSurrogate(unite) {
                saines.append(unite)
            }
            i += 1
        }
        return String(decoding: saines, as: UTF16.self)
    }
}

extension String {

    // MARK: Découpes, en unités UTF-16

    /// `take(n)` de Kotlin : les `n` premières unités UTF-16.
    public func premieresUnites(_ n: Int) -> String {
        if n <= 0 { return "" }
        if n >= utf16.count { return self }
        return Unites.texte(utf16.prefix(n))
    }

    /// `drop(n)` de Kotlin : sans les `n` premières unités UTF-16.
    public func sansPremieresUnites(_ n: Int) -> String {
        if n <= 0 { return self }
        if n >= utf16.count { return "" }
        return Unites.texte(utf16.dropFirst(n))
    }

    /// `takeLast(n)` de Kotlin : les `n` dernières unités UTF-16.
    public func dernieresUnites(_ n: Int) -> String {
        if n <= 0 { return "" }
        if n >= utf16.count { return self }
        return Unites.texte(utf16.suffix(n))
    }

    /// `substring(debut, fin)` de Kotlin : les unités de `debut` inclus à `fin` exclu, bornes ramenées dans le texte.
    public func unites(_ debut: Int, _ fin: Int) -> String {
        let toutes = Array(utf16)
        let a = min(max(0, debut), toutes.count)
        let b = min(max(a, fin), toutes.count)
        return Unites.texte(toutes[a..<b])
    }

    // MARK: Recherches, unité par unité

    /// `==` de Kotlin : les mêmes unités UTF-16. Pour Swift, « é » égale « e » suivi de son accent.
    public func egalUnites(_ autre: String) -> Bool {
        utf16.elementsEqual(autre.utf16)
    }

    /// `contains` de Kotlin.
    public func contientUnites(_ motif: String) -> Bool {
        Unites.position(de: Array(motif.utf16), dans: Array(utf16)) != nil
    }

    /// `startsWith` de Kotlin.
    public func commenceParUnites(_ prefixe: String) -> Bool {
        utf16.starts(with: prefixe.utf16)
    }

    /// `endsWith` de Kotlin.
    public func finitParUnites(_ suffixe: String) -> Bool {
        let fin = Array(suffixe.utf16)
        let toutes = Array(utf16)
        return fin.count <= toutes.count && toutes[(toutes.count - fin.count)...].elementsEqual(fin)
    }

    /// `indexOf` de Kotlin : la position en unités UTF-16, ou `nil` (Kotlin rend −1).
    public func positionUnites(de motif: String, depuis: Int = 0) -> Int? {
        Unites.position(de: Array(motif.utf16), dans: Array(utf16), depuis: depuis)
    }

    /// `lastIndexOf` de Kotlin.
    public func dernierePositionUnites(de motif: String) -> Int? {
        Unites.dernierePosition(de: Array(motif.utf16), dans: Array(utf16))
    }

    /// `replace(ancien, nouveau)` de Kotlin : chaque occurrence, de gauche à droite, sans chevauchement.
    /// Un `ancien` vide glisse `nouveau` avant chaque unité et à la fin, comme Kotlin.
    public func remplacantUnites(_ ancien: String, par nouveau: String) -> String {
        let texte = Array(utf16)
        let motif = Array(ancien.utf16)
        let remplacement = Array(nouveau.utf16)
        guard var occurrence = Unites.position(de: motif, dans: texte) else { return self }
        let pas = max(1, motif.count)
        var sortie: [UInt16] = []
        var i = 0
        while true {
            sortie.append(contentsOf: texte[i..<occurrence])
            sortie.append(contentsOf: remplacement)
            i = occurrence + motif.count
            if occurrence >= texte.count { break }
            // `indexOf` de Java au-delà de la fin : la longueur pour un motif vide, rien sinon.
            guard let suivante = Unites.position(de: motif, dans: texte, depuis: occurrence + pas), suivante > 0 else { break }
            occurrence = suivante
        }
        sortie.append(contentsOf: texte[i...])
        return Unites.texte(sortie)
    }

    /// `substringBefore(delimiteur)` de Kotlin : ce qui précède la première occurrence, tout le texte s'il n'y en a pas.
    public func avantUnites(_ delimiteur: String) -> String {
        let texte = Array(utf16)
        guard let position = Unites.position(de: Array(delimiteur.utf16), dans: texte) else { return self }
        return Unites.texte(texte[..<position])
    }

    /// `substringAfter(delimiteur)` de Kotlin : ce qui suit la première occurrence, tout le texte s'il n'y en a pas.
    public func apresUnites(_ delimiteur: String) -> String {
        let texte = Array(utf16)
        let motif = Array(delimiteur.utf16)
        guard let position = Unites.position(de: motif, dans: texte) else { return self }
        return Unites.texte(texte[(position + motif.count)...])
    }

    // MARK: Blancs

    /// `isBlank()` de Kotlin : vide, ou fait des seuls blancs de `Kotlin.estEspace`.
    public var estBlanc: Bool {
        utf16.allSatisfy { Kotlin.estEspace($0) }
    }

    /// `lowercase()` de Kotlin (`toLowerCase(Locale.ROOT)`) : comme `lowercased()`, plus la règle du sigma
    /// final que Java applique et Swift non (« ΟΔΟΣ » → « οδος ») : Σ devient ς quand une lettre à casse le
    /// précède et qu'aucune ne le suit, les signes sans casse (accents) mis à part.
    public var minusculesJava: String {
        let scalaires = Array(unicodeScalars)
        guard scalaires.contains("\u{03A3}") else { return lowercased() }
        func casse(_ x: Unicode.Scalar) -> Bool { x.properties.isCased }
        func ignore(_ x: Unicode.Scalar) -> Bool { x.properties.isCaseIgnorable }
        var sortie = ""
        for (i, x) in scalaires.enumerated() {
            guard x == "\u{03A3}" else {
                sortie += String(x).lowercased()
                continue
            }
            var avant = i - 1
            while avant >= 0 && ignore(scalaires[avant]) { avant -= 1 }
            var apres = i + 1
            while apres < scalaires.count && ignore(scalaires[apres]) { apres += 1 }
            let final = avant >= 0 && casse(scalaires[avant]) && !(apres < scalaires.count && casse(scalaires[apres]))
            sortie += final ? "\u{03C2}" : "\u{03C3}"
        }
        return sortie
    }

    /// `trim()` de Kotlin : sans les blancs de `Kotlin.estEspace` aux deux bouts.
    public var rogne: String {
        let toutes = Array(utf16)
        var debut = 0
        var fin = toutes.count
        while debut < fin && Kotlin.estEspace(toutes[debut]) { debut += 1 }
        while fin > debut && Kotlin.estEspace(toutes[fin - 1]) { fin -= 1 }
        if debut == 0 && fin == toutes.count { return self }
        return Unites.texte(toutes[debut..<fin])
    }

    // MARK: Formes d'Unicode

    /// `Normalizer.normalize(…, Normalizer.Form.NFC)` de Java.
    public var formeNFC: String {
        precomposedStringWithCanonicalMapping
    }

    /// `Normalizer.normalize(…, Normalizer.Form.NFD)` de Java.
    public var formeNFD: String {
        decomposedStringWithCanonicalMapping
    }
}
