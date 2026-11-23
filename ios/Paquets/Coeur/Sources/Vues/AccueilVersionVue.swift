import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'accueil d'une version autre que Classique (VersionApp.kt, AccueilVersion.kt) : Sérénité, Bento ou Pile, selon le
/// réglage « version_app ». La racine de l'app le pose à la place des trois onglets, comme Android ouvre l'activité
/// de la version à la place de MainActivity : chaque version a ses propres entrées vers les mêmes écrans.
///
/// La vue ne décide rien : elle lit `AccueilVersionModele` (testé sous Linux) ; les écrans qu'il demande (`routes`)
/// sont ouverts par la racine. Chaque retour au premier plan relit tout (onResume) ; ce qui dépend de l'heure (le
/// prochain zman, le ciel) se relit aussi chaque minute.
public struct AccueilVersionVue: View {
    private let modele: AccueilVersionModele
    @Environment(\.accessibilityReduceMotion) private var reduire
    @Environment(\.scenePhase) private var phase

    public init(modele: AccueilVersionModele) {
        self.modele = modele
    }

    public var body: some View {
        TimelineView(.everyMinute) { _ in
            switch modele.version {
            case .serenite: SereniteVue(modele: modele)
            case .bento: BentoVue(modele: modele)
            case .pile: PileVue(modele: modele)
            case .classique: Color.clear
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            modele.reduireAnimations = reduire
            Task { await modele.apparaitre() }
        }
        .onChange(of: reduire) { _, oui in
            modele.reduireAnimations = oui
        }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active { Task { await modele.apparaitre() } }
        }
    }
}

// MARK: - Ce que partagent les trois accueils (VueVersion.kt)

/// Les couleurs des versions : fixes, choisies avec les maquettes (chaque version a son ambiance, de jour comme de
/// nuit ; les réglages Fond et Boutons valent pour Classique). En ARGB, comme Android les écrit.
enum VersionCouleur {
    static func argb(_ v: UInt32) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255,
              opacity: Double((v >> 24) & 0xFF) / 255)
    }
}

/// Les polices des versions (VueVersion.police) : Bellefair (Sérénité), Heebo (Bento), Secular One et Rubik (Pile),
/// copiées de res/font et enregistrées au lancement (`Polices.enregistrer`). Leur taille suit Dynamic Type ; une
/// police absente prend celle du téléphone.
enum VersionPolice {
    static func bellefair(_ taille: CGFloat) -> Font {
        .custom("Bellefair", size: taille, relativeTo: style(taille))
    }

    static func heebo(_ taille: CGFloat, _ graisse: Font.Weight = .regular) -> Font {
        Font.custom("Heebo", size: taille, relativeTo: style(taille)).weight(graisse)
    }

    static func secular(_ taille: CGFloat) -> Font {
        .custom("Secular One", size: taille, relativeTo: style(taille))
    }

    static func rubik(_ taille: CGFloat, _ graisse: Font.Weight = .regular) -> Font {
        Font.custom("Rubik", size: taille, relativeTo: style(taille)).weight(graisse)
    }

    // La police du téléphone à la taille d'Android en sp : `.tailleSp(sp, poids:, relativeA: style(sp))`, qui suit
    // Dynamic Type (une `Font.system(size:)` restait figée, relevée par l'audit d'accessibilité).

    /// Le style d'iOS dont la taille suit le même pas que ce sp.
    static func style(_ taille: CGFloat) -> Font.TextStyle {
        if taille <= 12 { return .caption }
        if taille <= 13 { return .footnote }
        if taille <= 15 { return .subheadline }
        if taille <= 17 { return .body }
        if taille <= 20 { return .title3 }
        if taille <= 24 { return .title2 }
        if taille <= 30 { return .title }
        return .largeTitle
    }
}

/// Les textes des versions, écrits dans la langue de l'app.
enum VersionEcrit {
    static func chaine(_ t: VersionTexte, _ traducteur: Traducteur) -> String {
        switch t {
        case .libelle(let libelle): return traducteur.texte(libelle)
        case .brut(let brut): return brut
        case .date(let jour):
            // « EEEE d MMMM », majuscule initiale (replaceFirstChar { titlecase }).
            let brut = AccueilDate.texte(jour, langue: traducteur.langue, motif: "EEEE d MMMM")
            guard let premier = brut.first else { return brut }
            return String(premier).uppercased() + brut.dropFirst()
        }
    }

    /// Des morceaux joints par « · » (listOfNotNull(…).joinToString(" · ")).
    static func ligne(_ morceaux: [VersionTexte], _ traducteur: Traducteur) -> String {
        morceaux.map { chaine($0, traducteur) }.joined(separator: " · ")
    }
}

/// Le texte hébreu d'une carte (VueVersion.hebreu) : de droite à gauche, aligné au début de sa ligne hébraïque, dans
/// la police des textes saints choisie dans les réglages.
struct VersionHebreu: View {
    let texte: String
    let taille: CGFloat
    let couleur: Color
    let police: PoliceHebraique.Police
    var lignes: Int? = nil
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        Text(verbatim: texte)
            .policeHebraique(police, taille: taille)
            .foregroundStyle(couleur)
            .lineSpacing(5)
            // Le nombre de lignes de la maquette à la taille ordinaire du texte ; tout le texte au-delà.
            .lineLimit(tailleTexte.agrandie ? nil : lignes)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

/// Un bouton en pilule, plein ou au trait (VueVersion.bouton) : 52 pt au moins, toute la largeur.
struct VersionBouton: View {
    let libelle: Text
    let fond: Color
    let encre: Color
    let police: Font
    var trait = false
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            libelle
                .font(police)
                .foregroundStyle(encre)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background {
                    if trait {
                        Capsule().strokeBorder(fond, lineWidth: 1)
                    } else {
                        Capsule().fill(fond)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(VersionPression(echelle: 0.98))
    }
}

/// Une tuile ou un bouton qui s'enfonce un peu sous le doigt (BentoActivity.tuile : 0,97 en 160 ms) ; rien ne bouge
/// avec « Réduire les animations ».
struct VersionPression: ButtonStyle {
    var echelle: CGFloat = 0.97
    @Environment(\.accessibilityReduceMotion) private var reduire

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduire ? echelle : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
