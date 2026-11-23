import CoreText
import Foundation
import SwiftUI
import Coeur

/// Les polices des textes saints en hébreu (PoliceHebraique.kt d'Android, `ResourcesCompat.getFont`) : les sept
/// fichiers de `ios/Ressources/Polices`, copiés dans le paquet de l'app sous `Polices/`. L'interface, elle, garde
/// la police du téléphone.
public enum Polices {

    /// Les fichiers, tels que l'export les copie de `res/font` (et tels que `UIAppFonts` les nomme, sous
    /// `Polices/`). Noto Serif Hebrew a deux graisses, comme `res/font/hebreu_serif.xml` : 400 et 700.
    public static let fichiers = [
        "hebreu_serif_regular.ttf",
        "hebreu_serif_bold.ttf",
        "varela_round.ttf",
        "frank_ruhl.ttf",
        "david_libre.ttf",
        "noto_rashi.ttf",
        "miriam_libre.ttf",
    ]

    /// Les polices des accueils des versions (VueVersion.police) : Bellefair (Sérénité), Heebo (Bento), Secular One
    /// et Rubik (Pile). Heebo et Rubik sont des polices variables : leur graisse se choisit à l'usage.
    public static let fichiersVersions = [
        "bellefair.ttf",
        "heebo.ttf",
        "secular_one.ttf",
        "rubik.ttf",
    ]

    /// La famille d'une police, telle que ses fichiers la déclarent (table « name ») ; nil pour la police du
    /// téléphone, qui n'a pas de fichier (`Police.sans`).
    public static func famille(_ police: PoliceHebraique.Police) -> String? {
        switch police {
        case .serif: "Noto Serif Hebrew"
        case .sans: nil
        case .arrondie: "Varela Round"
        case .frank: "Frank Ruhl Libre"
        case .david: "David Libre"
        case .rachi: "Noto Rashi Hebrew"
        case .miriam: "Miriam Libre"
        }
    }

    /// Enregistre les polices de ce dossier pour le processus, au démarrage de l'app. Une police déjà connue
    /// (`UIAppFonts` les fait enregistrer par le système avant le premier écran) n'est pas une erreur. Rend les
    /// fichiers qui n'ont pu l'être, vide si tout va bien.
    @discardableResult
    public static func enregistrer(dossier: URL) -> [String] {
        var echecs: [String] = []
        for fichier in fichiers + fichiersVersions {
            let url = dossier.appending(path: fichier)
            var erreur: Unmanaged<CFError>? = nil
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &erreur) { continue }
            // L'erreur est lue sans être libérée : la règle de propriété de cette sortie n'est pas écrite, et
            // une erreur de trop libérée ferait tomber l'app ; au pire, quelques octets restent en mémoire.
            guard let erreur else {
                echecs.append(fichier)
                continue
            }
            let code = CFErrorGetCode(erreur.takeUnretainedValue())
            if code != CTFontManagerError.alreadyRegistered.rawValue && code != CTFontManagerError.duplicatedName.rawValue {
                echecs.append(fichier)
            }
        }
        return echecs
    }
}

extension Font {
    /// La police d'un texte saint à cette taille fixe, en points. Pour suivre la taille du texte choisie dans
    /// les réglages du téléphone (Dynamic Type), passer par `policeHebraique(_:taille:relativeA:)`.
    public static func hebreu(_ police: PoliceHebraique.Police, taille: CGFloat) -> Font {
        guard let famille = Polices.famille(police) else { return .system(size: taille) }
        return .custom(famille, fixedSize: taille)
    }
}

extension View {
    /// Pose la police d'un texte saint : `taille` est celle d'Android en sp (15, 22…), mise à l'échelle de la
    /// taille du texte du téléphone comme le style `relativeA`, ce que fait le sp d'Android.
    public func policeHebraique(_ police: PoliceHebraique.Police, taille: CGFloat, gras: Bool = false,
                                relativeA style: Font.TextStyle = .body) -> some View {
        modifier(PoliceHebraiqueModificateur(police: police, taille: taille, gras: gras, style: style))
    }
}

/// La police d'un texte saint, à une taille qui suit Dynamic Type (`@ScaledMetric`), la police du téléphone
/// comprise.
private struct PoliceHebraiqueModificateur: ViewModifier {
    let police: PoliceHebraique.Police
    let gras: Bool
    @ScaledMetric private var taille: CGFloat

    init(police: PoliceHebraique.Police, taille: CGFloat, gras: Bool, style: Font.TextStyle) {
        self.police = police
        self.gras = gras
        _taille = ScaledMetric(wrappedValue: taille, relativeTo: style)
    }

    func body(content: Content) -> some View {
        content.font(gras ? Font.hebreu(police, taille: taille).bold() : .hebreu(police, taille: taille))
    }
}
