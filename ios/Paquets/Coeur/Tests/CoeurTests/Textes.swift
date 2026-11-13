import Foundation

/// Une expression régulière d'ICU (NSRegularExpression), au plus près de java.util.regex sous
/// Kotlin : sur les unités UTF-16, avec les regards en arrière et `\p{M}`. Seul écart connu :
/// `\s` y couvre aussi les espaces d'Unicode (l'insécable comprise), ce qui élargit une recherche
/// de fautes, sans jamais la rétrécir.
struct Motif {
    private let expression: NSRegularExpression

    init(_ motif: String) throws {
        expression = try NSRegularExpression(pattern: motif)
    }

    private func tout(_ s: String) -> NSRange { NSRange(location: 0, length: s.utf16.count) }

    /// La première correspondance, ou nil.
    func trouve(_ s: String) -> String? {
        guard let m = expression.firstMatch(in: s, options: [], range: tout(s)),
              let r = Range(m.range, in: s) else { return nil }
        return String(s[r])
    }

    func present(dans s: String) -> Bool {
        expression.firstMatch(in: s, options: [], range: tout(s)) != nil
    }

    func compte(_ s: String) -> Int {
        expression.numberOfMatches(in: s, options: [], range: tout(s))
    }

    func remplace(_ s: String, par gabarit: String = "") -> String {
        expression.stringByReplacingMatches(in: s, options: [], range: tout(s), withTemplate: gabarit)
    }

    /// Le groupe `n` de chaque correspondance (0 : la correspondance entière).
    func groupes(_ s: String, _ n: Int = 0) -> [String] {
        expression.matches(in: s, options: [], range: tout(s)).compactMap { m in
            Range(m.range(at: n), in: s).map { String(s[$0]) }
        }
    }
}

extension String {
    /// `contains` de Kotlin : sur les points de code, sans équivalence canonique ni graphèmes
    /// (pour Swift, une lettre hébraïque et ses voyelles ne font qu'un caractère).
    func contient(_ motif: String) -> Bool {
        Data(utf8).range(of: Data(motif.utf8)) != nil
    }

    /// `startsWith` de Kotlin, sur les points de code.
    func commencePar(_ prefixe: String) -> Bool {
        utf8.starts(with: prefixe.utf8)
    }

    /// `Normalizer.normalize(…, Normalizer.Form.NFC)`.
    var nfc: String { precomposedStringWithCanonicalMapping }

    /// `isBlank` de Kotlin.
    var blanc: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Les seules lettres hébraïques, de א à ת.
    var lettres: String {
        String(String.UnicodeScalarView(unicodeScalars.filter { (0x05D0...0x05EA).contains($0.value) }))
    }
}
