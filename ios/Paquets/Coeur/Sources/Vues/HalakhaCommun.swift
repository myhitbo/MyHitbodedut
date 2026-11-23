import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce que les écrans de la halakha, des hilloulot et de la recherche dessinent de la même façon (VueJour.kt
// d'Android : `carte`, `texte`, `paragraphes`, `dateCivile`, les flèches du jour, les puces d'un ChipGroup). Rien
// n'y décide : chaque pièce reçoit ses textes et ses états du modèle de l'écran.

// MARK: La taille des lettres

/// Un texte de la liste (VueJour.texte) : sa taille d'Android en sp, qui suit la taille du texte du téléphone
/// (Dynamic Type, comme le sp) puis l'échelle des écrans de lecture (ReglagesLecture.retailler) ; la police
/// hébraïque des réglages, ou celle du téléphone.
struct HalakhaTaillePolice: ViewModifier {
    private let police: PoliceHebraique.Police?
    private let gras: Bool
    private let echelle: CGFloat
    /// L'espace ajouté entre deux lignes, en part de la taille : 0,5 rend à peu près l'interligne 1,4 d'Android
    /// (`setLineSpacing(0f, 1.4f)`, qui multiplie la hauteur de ligne, elle-même d'environ 1,2 fois la taille).
    private let interligne: CGFloat
    @ScaledMetric private var taille: CGFloat

    init(taille: CGFloat, police: PoliceHebraique.Police?, gras: Bool, echelle: CGFloat, interligne: CGFloat) {
        self.police = police
        self.gras = gras
        self.echelle = echelle
        self.interligne = interligne
        _taille = ScaledMetric(wrappedValue: taille, relativeTo: HalakhaTaillePolice.style(taille))
    }

    /// Le style de texte d'iOS le plus proche de la taille d'Android (Composants.swift : 17 → body, 15 →
    /// subheadline, 13 → footnote, 12 → caption).
    private static func style(_ taille: CGFloat) -> Font.TextStyle {
        if taille >= 26 { return .title }
        if taille >= 20 { return .title3 }
        if taille >= 17 { return .body }
        if taille >= 16 { return .callout }
        if taille >= 15 { return .subheadline }
        if taille >= 13 { return .footnote }
        if taille >= 12 { return .caption }
        return .caption2
    }

    private var finale: CGFloat {
        taille * echelle
    }

    private var fonte: Font {
        let base: Font
        if let police {
            base = .hebreu(police, taille: finale)
        } else {
            base = .system(size: finale)
        }
        return gras ? base.bold() : base
    }

    func body(content: Content) -> some View {
        content
            .font(fonte)
            .lineSpacing(finale * interligne)
    }
}

extension View {
    /// `taille` en sp d'Android ; `echelle` : celle des écrans de lecture (`modele.echelle`), 1 hors de la liste.
    func halakhaTexte(_ taille: CGFloat, police: PoliceHebraique.Police? = nil, gras: Bool = false,
                      echelle: Float = 1, interligne: CGFloat = 0) -> some View {
        modifier(HalakhaTaillePolice(taille: taille, police: police, gras: gras, echelle: CGFloat(echelle),
                                     interligne: interligne))
    }
}

// MARK: La carte

/// Le fond d'une carte (VueJour.carte, bg_card) : fond `card`, filet `line` de 1, coins de 20 ; 16 de marge
/// intérieure par défaut, d'autres pour les cartes des hilloulot.
struct HalakhaFondCarte: ViewModifier {
    let interieur: EdgeInsets

    func body(content: Content) -> some View {
        content
            .padding(interieur)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Teinte(.line), lineWidth: 1)
            }
    }
}

extension View {
    /// Le fond seul, pour une carte qu'on touche en entier (la marge extérieure reste hors du bouton).
    func halakhaFond(_ interieur: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) -> some View {
        modifier(HalakhaFondCarte(interieur: interieur))
    }

    /// Les marges extérieures d'une carte : 16 sur les côtés, 12 au-dessus (6 pour les cartes des hilloulot).
    func halakhaMarges(haut: CGFloat = 12) -> some View {
        padding(.horizontal, 16)
            .padding(.top, haut)
    }

    /// Une carte entière : son fond et ses marges.
    func halakhaCarte(_ interieur: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
                      haut: CGFloat = 12) -> some View {
        halakhaFond(interieur)
            .halakhaMarges(haut: haut)
    }
}

// MARK: Les puces

/// Les puces d'un ChipGroup : à la suite, et à la ligne quand la place manque. Posées de gauche à droite, que
/// SwiftUI retourne en hébreu.
struct HalakhaFlux: Layout {
    var espacement: CGFloat = 8
    var interligne: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        disposition(largeur: proposal.width, subviews: subviews).taille
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let d = disposition(largeur: bounds.width, subviews: subviews)
        for (i, vue) in subviews.enumerated() {
            vue.place(at: CGPoint(x: bounds.minX + d.positions[i].x, y: bounds.minY + d.positions[i].y),
                      proposal: ProposedViewSize(d.tailles[i]))
        }
    }

    private func disposition(largeur: CGFloat?, subviews: Subviews)
        -> (positions: [CGPoint], tailles: [CGSize], taille: CGSize) {
        let limite = largeur ?? .infinity
        var positions: [CGPoint] = []
        var tailles: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var hauteurRangee: CGFloat = 0
        var largeurMax: CGFloat = 0
        for vue in subviews {
            let t = vue.sizeThatFits(ProposedViewSize(width: limite.isFinite ? limite : nil, height: nil))
            if x > 0 && x + t.width > limite {
                x = 0
                y += hauteurRangee + interligne
                hauteurRangee = 0
            }
            positions.append(CGPoint(x: x, y: y))
            tailles.append(t)
            largeurMax = max(largeurMax, x + t.width)
            hauteurRangee = max(hauteurRangee, t.height)
            x += t.width + espacement
        }
        return (positions, tailles, CGSize(width: largeurMax, height: y + hauteurRangee))
    }
}

/// Une puce à choix unique (Chip de Material, `isCheckable`) : cochée, la menthe et la coche ; sinon le fond
/// `card`. 44 de haut, la cible d'un toucher. VoiceOver la dit choisie.
struct HalakhaPuce: View {
    let texte: Text
    let choisie: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if choisie {
                    Image(systemName: "checkmark")
                        .font(Font.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                texte
                    .font(.subheadline)
                    .lignesAuPlus(1)
            }
            .foregroundStyle(choisie ? Teinte(.onPlate) : Teinte(.ink))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(choisie ? Teinte(.mint) : Teinte(.card), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(choisie ? AccessibilityTraits.isSelected : [])
    }
}

// MARK: Le jour

/// La date civile sous la date hébraïque (VueJour.dateCivile) : « EEEE d MMMM yyyy » dans la langue de l'app,
/// sans majuscule ajoutée, comme `DateTimeFormatter.ofPattern` d'Android.
enum HalakhaDateCivile {
    static func texte(_ jour: JourCivil, langue: String) -> String {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        // Midi : aucun changement d'heure ne fait glisser le jour.
        let composantes = DateComponents(year: jour.annee, month: jour.mois, day: jour.jour, hour: 12)
        guard let date = calendrier.date(from: composantes) else { return jour.iso }
        let format = DateFormatter()
        format.calendar = calendrier
        format.timeZone = .gmt
        format.locale = Locale(identifier: langue)
        format.dateFormat = "EEEE d MMMM yyyy"
        return format.string(from: date)
    }
}

/// Une flèche du jour (HalakhaActivity.fleche) : le chevron de l'accent dans un carré qu'on touche. Les glyphes
/// « ‹ › » qu'Android permute à la main en hébreu sont ici les chevrons du système, qui se retournent d'eux-mêmes
/// (PORTAGE.md § 2.3) : le jour précédent montre « › » à droite, le suivant « ‹ » à gauche.
struct HalakhaFleche: View {
    let suivant: Bool
    /// La taille du signe sur Android (26 sp pour la halakha, 28 pour les hilloulot).
    let taille: CGFloat
    /// Le côté du carré qu'on touche (48 et 52).
    let cadre: CGFloat
    let echelle: Float
    let libelle: Text
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: suivant ? "chevron.forward" : "chevron.backward")
                // Le chevron du système est plus gros que le guillemet d'Android à même taille.
                .halakhaTexte(taille * 0.75, gras: true, echelle: echelle)
                .foregroundStyle(Teinte(.brand))
                .frame(width: cadre, height: cadre)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(libelle)
    }
}

// MARK: Les textes hébreux

/// Un texte en paragraphes (VueJour.paragraphes) : une demi-ligne vide entre deux. Écrit de droite à gauche, aligné
/// à droite, dans toutes les langues (TEXT_DIRECTION_RTL). `lignesMax` : une longue biographie repliée, coupée là
/// avec « … ».
struct HalakhaParagraphesVue: View {
    let paragraphes: [String]
    let taille: CGFloat
    let police: PoliceHebraique.Police
    let echelle: Float
    var interligne: CGFloat = 0
    var lignesMax: Int? = nil

    var body: some View {
        corps
            .foregroundStyle(Teinte(.ink))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder private var corps: some View {
        if let lignesMax {
            // Repliée : un seul texte, pour que les huit lignes se comptent sur toute la biographie.
            Text(verbatim: paragraphes.joined(separator: "\n"))
                .halakhaTexte(taille, police: police, echelle: echelle, interligne: interligne)
                .lineLimit(lignesMax)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: taille * CGFloat(echelle) * 0.6) {
                ForEach(paragraphes.indices, id: \.self) { i in
                    Text(verbatim: paragraphes[i])
                        .halakhaTexte(taille, police: police, echelle: echelle, interligne: interligne)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: Les liens

/// Un lien vers un site (« … ↗ », gras, couleur de l'accent, 48 de haut au moins) : le navigateur l'ouvre. Une
/// adresse illisible ne fait rien, comme le `runCatching` d'Android.
struct HalakhaLienSortant: View {
    let texte: String
    let url: String
    let taille: CGFloat
    let echelle: Float
    var gras = true
    /// Centré (le lien du jour), ou au début de la ligne (une source d'une fiche).
    var centre = true
    @Environment(\.openURL) private var ouvrirURL

    init(texte: String, url: String, taille: CGFloat, echelle: Float, gras: Bool = true, centre: Bool = true) {
        self.texte = texte
        self.url = url
        self.taille = taille
        self.echelle = echelle
        self.gras = gras
        self.centre = centre
    }

    var body: some View {
        Button {
            if let adresse = URL(string: url) {
                ouvrirURL(adresse)
            }
        } label: {
            Text(verbatim: texte + " ↗")
                .halakhaTexte(taille, gras: gras, echelle: echelle)
                .foregroundStyle(Teinte(.brand))
                .multilineTextAlignment(centre ? .center : .leading)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: centre ? .center : .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: Le cycle de vie

/// onPause et onRestart d'Android : l'écran quitte le premier plan (une autre app, un écran poussé par-dessus),
/// puis revient. Le modèle décide s'il faut passer à aujourd'hui.
struct HalakhaCycle: ViewModifier {
    let suspendre: @MainActor () -> Void
    let reprendre: @MainActor () -> Void
    @Environment(\.scenePhase) private var phase

    init(suspendre: @escaping @MainActor () -> Void, reprendre: @escaping @MainActor () -> Void) {
        self.suspendre = suspendre
        self.reprendre = reprendre
    }

    func body(content: Content) -> some View {
        content
            .onAppear { reprendre() }
            .onDisappear { suspendre() }
            .onChange(of: phase) { _, nouvelle in
                if nouvelle == .active {
                    reprendre()
                } else {
                    suspendre()
                }
            }
    }
}
