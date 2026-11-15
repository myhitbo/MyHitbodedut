import Foundation

// Les chaînes comme Kotlin les voit : des suites d'unités UTF-16. Sous-ensemble de `Socle/Texte.swift`
// de la demande de fusion #29, recopié à l'identique : ce dont la sauvegarde a besoin.

/// Les unités UTF-16, avec les conventions de `java.lang.String`.
public enum Unites {

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

    /// `take(n)` de Kotlin : les `n` premières unités UTF-16.
    public func premieresUnites(_ n: Int) -> String {
        if n <= 0 { return "" }
        if n >= utf16.count { return self }
        return Unites.texte(utf16.prefix(n))
    }

    /// `isBlank()` de Kotlin : vide, ou fait des seuls blancs de `Kotlin.estEspace`.
    public var estBlanc: Bool {
        utf16.allSatisfy { Kotlin.estEspace($0) }
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
}
