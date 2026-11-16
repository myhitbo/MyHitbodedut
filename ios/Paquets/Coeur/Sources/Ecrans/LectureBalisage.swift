import Foundation
import Coeur

// Le balisage des blocs du siddour et des livres (<b>, <small>, <br>), lu comme `Html.fromHtml(…,
// FROM_HTML_MODE_LEGACY)` le lit dans SiddurLectureActivity.kt, puis le premier mot agrandi et la ligne vide
// réduite (`premierMotAgrandi`). Le modèle rend des morceaux de style (gras, taille relative) ; la vue en fait
// son texte. Aucune autre balise ni aucune entité n'existe dans les contenus exportés (vérifié sur les 90 832
// « < » des siddourim et des livres) : une balise inconnue est ignorée, comme Tagsoup le ferait.

/// Un morceau d'un paragraphe, d'un même style.
public struct LectureSegment: Sendable, Hashable {
    public let texte: String
    public let gras: Bool
    /// La taille relative au paragraphe : 0,8 par <small> ouvert (RelativeSizeSpan(0.8f) d'Android, qui se
    /// multiplient), 1,25 pour le gras qui ouvre un paragraphe de prière, 0,3 pour la ligne vide d'une aération.
    public let taille: Double

    public init(texte: String, gras: Bool, taille: Double) {
        self.texte = texte
        self.gras = gras
        self.taille = taille
    }
}

/// Un paragraphe dans une langue : l'hébreu d'un bloc, sa traduction, ou un titre de section.
public struct LectureParagraphe: Sendable, Hashable {
    /// « he », « fr » ou « en » (LanguesTexte).
    public let langue: String
    public let segments: [LectureSegment]
    /// La taille relative de tout le paragraphe : 0,84 pour une traduction sous l'hébreu, 0,72 pour la traduction
    /// d'un titre, 1 sinon.
    public let taille: Double
    /// Dans la couleur discrète de la lecture (une traduction sous l'hébreu) ; sinon celle du texte, ou des titres.
    public let discret: Bool
    /// Dans la police hébraïque choisie (PoliceHebraique) ; faux : la police à empattements du système
    /// (`TypefaceSpan("serif")` d'une traduction).
    public let policeHebraique: Bool

    public init(langue: String, segments: [LectureSegment], taille: Double = 1, discret: Bool = false,
                policeHebraique: Bool = true) {
        self.langue = langue
        self.segments = segments
        self.taille = taille
        self.discret = discret
        self.policeHebraique = policeHebraique
    }

    /// De droite à gauche (l'hébreu), sinon de gauche à droite : chaque paragraphe prend le sens de sa langue
    /// et s'aligne sur son début (TEXT_DIRECTION_FIRST_STRONG, TEXT_ALIGNMENT_TEXT_START d'Android).
    public var droiteAGauche: Bool {
        langue == "he"
    }

    /// Le texte nu, sans les styles (pour l'accessibilité et les tests).
    public var texte: String {
        segments.map { $0.texte }.joined()
    }
}

enum LectureBalisage {

    /// Un caractère rendu, avec son style.
    private struct Signe {
        let valeur: Unicode.Scalar
        let gras: Bool
        var taille: Double
    }

    private static let espace: Unicode.Scalar = " "
    private static let saut: Unicode.Scalar = "\n"

    /// Le texte d'un bloc tel qu'Android l'affiche : `Html.fromHtml` (les blancs ' ' et '\n' réduits à une espace,
    /// aucune en tête ni après un saut de ligne), puis, si `agrandir` (un paragraphe de prière, pas une consigne),
    /// `premierMotAgrandi` : le gras qui ouvre le paragraphe un quart plus grand, et la seconde ligne d'un
    /// « \n\n » réduite à 0,3. Chaque morceau est masqué pour la police (PoliceHebraique.masque).
    static func segments(_ html: String, agrandir: Bool, police: PoliceHebraique.Police) -> [LectureSegment] {
        var signes: [Signe] = []
        // Les <b> ouverts, du plus ancien au plus récent : vrai pour celui qui s'ouvre en tête du paragraphe.
        var gras: [Bool] = []
        var petits = 0
        let scalaires = Array(html.unicodeScalars)

        func emettre(_ c: Unicode.Scalar) {
            var taille = 1.0
            for _ in 0..<petits {
                taille *= 0.8
            }
            if agrandir && gras.contains(true) {
                taille *= 1.25
            }
            signes.append(Signe(valeur: c, gras: !gras.isEmpty, taille: taille))
        }

        var i = 0
        while i < scalaires.count {
            let c = scalaires[i]
            if c == "<", let fin = fermeture(scalaires, depuis: i) {
                let (nom, fermante) = balise(scalaires, de: i + 1, a: fin)
                switch nom {
                case "b":
                    if fermante {
                        if !gras.isEmpty { gras.removeLast() }
                    } else {
                        gras.append(signes.isEmpty)
                    }
                case "small":
                    if fermante {
                        petits = max(0, petits - 1)
                    } else {
                        petits += 1
                    }
                case "br":
                    if !fermante { emettre(saut) }
                default:
                    break
                }
                i = fin + 1
                continue
            }
            if c == espace || c == saut {
                // handleCharacters d'Android : une espace seulement après autre chose qu'un blanc ou un saut.
                let precedent = signes.last?.valeur ?? saut
                if precedent != espace && precedent != saut { emettre(espace) }
            } else {
                emettre(c)
            }
            i += 1
        }

        if agrandir {
            // « \n\n » : le second saut réduit, puis la recherche reprend deux caractères plus loin.
            var k = 0
            while k + 1 < signes.count {
                if signes[k].valeur == saut && signes[k + 1].valeur == saut {
                    signes[k + 1].taille *= 0.3
                    k += 2
                } else {
                    k += 1
                }
            }
        }

        var morceaux: [LectureSegment] = []
        var courant = String.UnicodeScalarView()
        var style: (gras: Bool, taille: Double)?
        for signe in signes {
            if let style, style.gras == signe.gras, style.taille == signe.taille {
                courant.append(signe.valeur)
                continue
            }
            if let style {
                morceaux.append(LectureSegment(texte: PoliceHebraique.masque(String(courant), police: police),
                                               gras: style.gras, taille: style.taille))
            }
            courant = String.UnicodeScalarView()
            courant.append(signe.valeur)
            style = (gras: signe.gras, taille: signe.taille)
        }
        if let style {
            morceaux.append(LectureSegment(texte: PoliceHebraique.masque(String(courant), police: police),
                                           gras: style.gras, taille: style.taille))
        }
        return morceaux
    }

    /// Les paragraphes d'un bloc (onBindViewHolder, SiddurJour.Ligne.Bloc) : une consigne, en hébreu seul et sans
    /// aération ; une prière aérée (Aeration.aerer), puis ses traductions selon les langues de lecture.
    ///
    /// Android ajoute la traduction telle quelle, balises comprises (« <b>Dieu</b> des premiers… » s'y lirait) :
    /// ici elle est lue comme l'hébreu, sans aération ni premier mot agrandi.
    static func paragraphes(texte: String, consigne: Bool, fr: String?, en: String?, langues: LanguesTexte.Mode,
                            police: PoliceHebraique.Police) -> [LectureParagraphe] {
        if consigne {
            return [LectureParagraphe(langue: "he", segments: segments(texte, agrandir: false, police: police))]
        }
        let hebreu = LectureParagraphe(langue: "he",
                                       segments: segments(Aeration.aerer(texte), agrandir: true, police: police))
        let textes = LanguesTexte.textes(langues, texte, fr, en)
        if !textes.contains(where: { !$0.langue.egalUnites("he") }) { return [hebreu] }
        let avecHebreu = textes.contains { $0.langue.egalUnites("he") }
        var sortie: [LectureParagraphe] = []
        for partie in textes {
            if partie.langue.egalUnites("he") {
                sortie.append(hebreu)
            } else {
                sortie.append(LectureParagraphe(langue: partie.langue,
                                                segments: segments(partie.texte, agrandir: false, police: police),
                                                taille: avecHebreu ? 0.84 : 1, discret: avecHebreu,
                                                policeHebraique: false))
            }
        }
        return sortie
    }

    /// Les paragraphes d'un titre de section (SiddurJour.Ligne.Titre) : l'hébreu et/ou sa traduction, la seconde
    /// langue plus petite (0,72) ; tout dans la police hébraïque, en gras, comme la vue d'Android.
    static func titre(_ he: String, fr: String?, en: String?, langues: LanguesTexte.Mode,
                      police: PoliceHebraique.Police) -> [LectureParagraphe] {
        var sortie: [LectureParagraphe] = []
        for (rang, partie) in LanguesTexte.textes(langues, he, fr, en).enumerated() {
            let masque = PoliceHebraique.masque(partie.texte, police: police)
            sortie.append(LectureParagraphe(langue: partie.langue,
                                            segments: [LectureSegment(texte: masque, gras: true, taille: 1)],
                                            taille: rang == 0 ? 1 : 0.72))
        }
        return sortie
    }

    /// La position du « > » qui ferme la balise ouverte en `depuis` ; nil s'il n'y en a pas (le « < » est du texte).
    private static func fermeture(_ scalaires: [Unicode.Scalar], depuis: Int) -> Int? {
        var j = depuis + 1
        while j < scalaires.count {
            if scalaires[j] == ">" { return j }
            if scalaires[j] == "<" { return nil }
            j += 1
        }
        return nil
    }

    /// Le nom d'une balise, en minuscules, et si elle ferme : « b », « small », « br » (« <br/> » compris).
    private static func balise(_ scalaires: [Unicode.Scalar], de debut: Int, a fin: Int) -> (String, Bool) {
        var j = debut
        while j < fin && scalaires[j] == " " { j += 1 }
        var fermante = false
        if j < fin && scalaires[j] == "/" {
            fermante = true
            j += 1
        }
        var nom = String.UnicodeScalarView()
        while j < fin {
            let c = scalaires[j]
            if c == " " || c == "/" { break }
            nom.append(c)
            j += 1
        }
        return (String(nom).lowercased(), fermante)
    }
}
