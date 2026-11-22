import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce que partagent les vues qui montrent un trophée (l'écran des paliers, la fiche d'un trophée, la fête de
// l'accueil) : l'objet peint d'après `TropheeDessin` (TropheeDessin.kt, `draw`), la barre de progression, la
// taille des textes, la date longue. Rien n'y décide de ce qui se montre : le modèle l'a dit.

// MARK: L'objet

/// L'objet d'un trophée (coupe, écusson, médaille…) peint d'après son dessin : un carré centré de côté
/// min(largeur, hauteur), la boîte de 100 mise à l'échelle, chaque partie remplie dans l'ordre (règle non nulle,
/// comme Android), puis l'emblème (l'icône de la famille au trait, ou l'étoile du grade). L'objet ne se retourne
/// jamais en hébreu, et VoiceOver le passe toujours (`IMPORTANT_FOR_ACCESSIBILITY_NO` d'Android) : ce qu'il dit est
/// écrit à côté. Sans dessin (une forme absente du fichier), sa place reste vide.
public struct TropheeObjet: View {
    private let dessin: TropheeDessin?

    public init(_ dessin: TropheeDessin?) {
        self.dessin = dessin
    }

    public var body: some View {
        Canvas { contexte, taille in
            peindre(contexte, taille)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func peindre(_ contexte: GraphicsContext, _ taille: CGSize) {
        guard let dessin else { return }
        let cote = min(taille.width, taille.height)
        guard cote > 0 else { return }
        var c = contexte
        c.translateBy(x: (taille.width - cote) / 2, y: (taille.height - cote) / 2)
        let echelle = cote / CGFloat(TropheeFormes.boite)
        c.scaleBy(x: echelle, y: echelle)
        for partie in dessin.parties {
            c.fill(TropheeTraceur.path(partie.chemin), with: remplissage(partie.peinture))
        }
        switch dessin.embleme {
        case .trait(let chemin, let centre, let tailleIcone, let couleur):
            var t = c
            t.translateBy(x: CGFloat(centre.x - tailleIcone / 2), y: CGFloat(centre.y - tailleIcone / 2))
            let k = CGFloat(tailleIcone / TropheeFormes.boiteIcone)
            t.scaleBy(x: k, y: k)
            let epaisseur = CGFloat(dessin.epaisseurIcone(cote: Double(cote)))
            t.stroke(TropheeTraceur.path(chemin), with: .color(couleur.couleurSwiftUI),
                     style: StrokeStyle(lineWidth: epaisseur, lineCap: .round, lineJoin: .round))
        case .texte(let signe, let centre, let tailleTexte, let couleur):
            // La police par défaut, maigre, comme le `Paint` d'Android ; la hauteur des lettres centrée sur y.
            let texte = c.resolve(Text(verbatim: signe)
                .font(.system(size: CGFloat(tailleTexte)))
                .foregroundStyle(couleur.couleurSwiftUI))
            c.draw(texte, at: CGPoint(x: centre.x, y: centre.y), anchor: .center)
        }
    }

    /// La peinture d'une partie, dans la boîte de 100.
    private func remplissage(_ peinture: TropheePeinture) -> GraphicsContext.Shading {
        switch peinture {
        case .diagonale(let de, let a):
            return .linearGradient(Gradient(colors: [de.couleurSwiftUI, a.couleurSwiftUI]),
                                   startPoint: CGPoint(x: 0, y: 0),
                                   endPoint: CGPoint(x: TropheeFormes.boite, y: TropheeFormes.boite))
        case .bombee(let couleurs, let arrets, let centre, let rayon):
            var points: [Gradient.Stop] = []
            for (i, couleur) in couleurs.enumerated() where i < arrets.count {
                points.append(Gradient.Stop(color: couleur.couleurSwiftUI, location: CGFloat(arrets[i])))
            }
            return .radialGradient(Gradient(stops: points),
                                   center: CGPoint(x: centre.x, y: centre.y),
                                   startRadius: 0, endRadius: CGFloat(rayon))
        case .unie(let couleur):
            return .color(couleur.couleurSwiftUI)
        }
    }
}

extension TropheeCouleur {
    /// La couleur sRVB d'Android (`Color.argb`), son opacité comprise.
    var couleurSwiftUI: Color {
        Color(.sRGB,
              red: Double(rouge) / 255,
              green: Double(vert) / 255,
              blue: Double(bleu) / 255,
              opacity: Double(alpha) / 255)
    }
}

/// Le `Path` de SwiftUI d'un chemin lu (les commandes sont déjà absolues : rien à calculer).
enum TropheeTraceur {
    static func path(_ chemin: TropheeChemin) -> Path {
        var p = Path()
        for commande in chemin.commandes {
            switch commande {
            case .deplacer(let a):
                p.move(to: point(a))
            case .ligne(let a):
                p.addLine(to: point(a))
            case .quadratique(let controle, let fin):
                p.addQuadCurve(to: point(fin), control: point(controle))
            case .cubique(let controle1, let controle2, let fin):
                p.addCurve(to: point(fin), control1: point(controle1), control2: point(controle2))
            case .fermer:
                p.closeSubpath()
            }
        }
        return p
    }

    private static func point(_ p: TropheePoint) -> CGPoint {
        CGPoint(x: p.x, y: p.y)
    }
}

// MARK: La barre

/// La barre de progression des trophées (ProgressBar horizontale d'Android) : la couleur pleine sur un fond de la
/// même couleur à 0x30 d'opacité. `monte` : elle part de zéro et monte en 0,7 s à son apparition
/// (PaliersActivity.barre), sauf avec « Réduire les animations ». VoiceOver la passe : le texte voisin dit la
/// même chose.
struct TropheeBarre<Couleur: ShapeStyle>: View {
    let fraction: Double
    let hauteur: CGFloat
    let couleur: Couleur
    let monte: Bool

    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var montree: Double = 0

    var body: some View {
        Capsule()
            .fill(couleur.opacity(Double(0x30) / 255))
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(couleur)
                        .frame(width: geo.size.width * CGFloat(valeur))
                }
            }
            .frame(height: hauteur)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            .onAppear {
                guard monte, !reduire else { return }
                withAnimation(.easeInOut(duration: 0.7)) {
                    montree = fraction
                }
            }
    }

    /// Ce qui est montré : la valeur qui monte, ou la valeur finale.
    private var valeur: Double {
        let fin = min(max(fraction, 0), 1)
        guard monte, !reduire else { return fin }
        return min(max(montree, 0), 1)
    }
}

// MARK: Les textes

extension View {
    /// Un texte des trophées à la taille d'Android en sp (`textSize`), qui suit la taille du texte du téléphone
    /// (Dynamic Type) comme le sp ; `interlettrage` en em (`letterSpacing`).
    func tropheeTexte(_ taille: CGFloat, gras: Bool = false, interlettrage: CGFloat = 0) -> some View {
        modifier(TropheeTexteModificateur(taille: taille, gras: gras, interlettrage: interlettrage))
    }
}

private struct TropheeTexteModificateur: ViewModifier {
    let gras: Bool
    let interlettrage: CGFloat
    @ScaledMetric private var taille: CGFloat

    init(taille: CGFloat, gras: Bool, interlettrage: CGFloat) {
        self.gras = gras
        self.interlettrage = interlettrage
        _taille = ScaledMetric(wrappedValue: taille, relativeTo: TropheeTexteModificateur.style(taille))
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: taille, weight: gras ? .bold : .regular))
            .tracking(taille * interlettrage)
    }

    /// Le style d'iOS dont la taille suit le même pas (Composants.swift : 17 → body, 15 → subheadline…).
    private static func style(_ taille: CGFloat) -> Font.TextStyle {
        if taille <= 11 { return .caption2 }
        if taille <= 12 { return .caption }
        if taille <= 13 { return .footnote }
        if taille <= 15 { return .subheadline }
        if taille <= 17 { return .body }
        if taille <= 20 { return .title3 }
        if taille <= 24 { return .title2 }
        return .title
    }
}

/// Le texte d'une liste de libellés, lus d'un trait par VoiceOver : joints par « , » comme les
/// `contentDescription` d'Android.
enum TropheeAccessibilite {
    static func texte(_ libelles: [Libelle], _ traducteur: Traducteur) -> Text {
        Text(verbatim: libelles.map { traducteur.texte($0) }.joined(separator: ", "))
    }
}

/// La date longue d'un gain (« 7 octobre 2026 ») : `DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)` d'Android,
/// dans la langue de l'app, au calendrier grégorien.
enum TropheeDate {
    static func longue(_ jour: JourCivil, langue: String) -> String {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        // Midi : aucun changement d'heure ne fait glisser le jour.
        let composantes = DateComponents(year: jour.annee, month: jour.mois, day: jour.jour, hour: 12)
        guard let date = calendrier.date(from: composantes) else { return jour.iso }
        let format = DateFormatter()
        format.calendar = calendrier
        format.timeZone = .gmt
        format.locale = Locale(identifier: langue)
        format.dateStyle = .long
        format.timeStyle = .none
        return format.string(from: date)
    }
}

// MARK: Le temps des animations

/// Une attente dans la suite d'une animation ; faux si la vue est partie entre-temps (la tâche est annulée).
enum TropheeAttente {
    static func ms(_ millisecondes: Int) async -> Bool {
        guard millisecondes > 0 else { return !Task.isCancelled }
        do {
            try await Task.sleep(for: .milliseconds(millisecondes))
            return true
        } catch {
            return false
        }
    }
}

/// Ouvre ou ferme sans animation : une fiche ou une fête paraît d'un coup, comme un dialogue d'Android, et non en
/// glissant du bas de l'écran.
enum TropheeTransaction {
    @MainActor
    static func sansAnimation(_ action: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, action)
    }
}

// MARK: Les formes, posées par l'app

private struct CleTropheeFormes: EnvironmentKey {
    static let defaultValue: TropheeFormes? = nil
}

extension EnvironmentValues {
    /// Les formes et les icônes de trophees_formes.json, lues une fois par l'app ; nil (un aperçu) : les objets
    /// restent vides.
    public var tropheeFormes: TropheeFormes? {
        get { self[CleTropheeFormes.self] }
        set { self[CleTropheeFormes.self] = newValue }
    }
}
