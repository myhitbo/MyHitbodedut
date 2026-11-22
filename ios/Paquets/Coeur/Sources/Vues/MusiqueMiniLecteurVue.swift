import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// Le mini-lecteur de la pratique (MiniLecteur.kt) : à poser en surimpression, sur toute la hauteur de l'écran
/// de séance (`.overlay { MusiqueMiniLecteurVue(mini: mini) }`). Il ne se montre que pendant une séance ; replié,
/// un disque de 64 en bas, du côté de la fin de ligne ; déplié, une carte sombre au bas de l'écran, toujours de
/// gauche à droite, même en hébreu. Il ne capte les touchers que là où il se dessine.
///
/// La vue ne commande rien : elle lit `MusiqueMiniLecteurModele` et lui passe les gestes ; tant qu'il est
/// visible, elle le laisse relire l'état de la lecture (`suivre`, à son propre rythme).
public struct MusiqueMiniLecteurVue: View {
    private let mini: MusiqueMiniLecteurModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    @AccessibilityFocusState private var focusPanneau: Bool
    @AccessibilityFocusState private var focusDisque: Bool
    /// Le tour des deux disques, commun : sur Android, ils tournent ensemble, et s'arrêtent où ils sont.
    @State private var tour = MusiqueTour()

    /// Le noir vert du panneau (0xF2121A17 : 95 %), écrit en dur par Android.
    private static let sombre = Color(.sRGB, red: 18.0 / 255, green: 26.0 / 255, blue: 23.0 / 255, opacity: 1)

    public init(mini: MusiqueMiniLecteurModele) {
        self.mini = mini
    }

    public var body: some View {
        if mini.visible {
            Group {
                if mini.deplie {
                    panneau
                } else {
                    disque
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .task { @MainActor [mini] in
                await mini.suivre()
            }
            .onChange(of: mini.disqueTourne && !reduireAnimations, initial: true) { _, tourne in
                tour.suivre(tourne: tourne, a: Date())
            }
            .onChange(of: mini.deplie) { _, deplie in
                // Le focus de VoiceOver passe à ce qui vient de paraître (TYPE_VIEW_FOCUSED d'Android).
                if deplie {
                    focusPanneau = true
                } else {
                    focusDisque = true
                }
            }
        }
    }

    // MARK: Replié

    private var disque: some View {
        Button {
            mini.deplier()
        } label: {
            MusiqueDisqueVue(pochette: mini.pochette, imageParDefaut: mini.imageParDefaut, taille: 64, tour: tour)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(16)
        .accessibilityLabel(Text("lecteur_ouvrir"))
        .accessibilityFocused($focusDisque)
    }

    // MARK: Déplié

    private var panneau: some View {
        VStack(spacing: 0) {
            entete
            barre
                .padding(.top, 8)
            temps
            commandes
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MusiqueMiniLecteurVue.sombre.opacity(0.95),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .environment(\.layoutDirection, .leftToRight)
        .padding(16)
        .accessibilityElement(children: .contain)
    }

    /// Le petit disque, le titre qui défile, le bouton « replier ».
    private var entete: some View {
        HStack(spacing: 0) {
            MusiqueDisqueVue(pochette: mini.pochette, imageParDefaut: mini.imageParDefaut, taille: 48, tour: tour)
                .accessibilityHidden(true)
            MusiqueTitreDefilantVue(texte: mini.titre.musiqueTexte(traducteur))
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityFocused($focusPanneau)
            Button {
                mini.replier()
            } label: {
                MusiqueIconeLecteur(symbole: "chevron.down", couleur: Color.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("lecteur_replier"))
        }
    }

    /// La barre de position : elle suit le doigt pendant qu'il glisse, la lecture va là quand il se lève.
    private var barre: some View {
        Slider(value: liaisonPosition, in: 0...Double(mini.maximum), onEditingChanged: { [mini] enCours in
            if enCours {
                mini.commencerGlisse()
            } else {
                Task.immediate { @MainActor in
                    await mini.finirGlisse()
                }
            }
        })
        .tint(Teinte(.mint))
        .frame(height: 32)
        .accessibilityLabel(Text("lecteur_position"))
        .accessibilityValue(Text(verbatim: mini.ecoule))
    }

    private var liaisonPosition: Binding<Double> {
        Bindable(mini).positionGlissee
    }

    /// Le temps écoulé au début, la durée à la fin, en chiffres de même chasse.
    private var temps: some View {
        HStack(spacing: 8) {
            Text(verbatim: mini.ecoule)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: mini.total)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(Font.caption.monospacedDigit())
        .foregroundStyle(Color.white.opacity(0.7))
    }

    /// Aléatoire, précédent, lecture, suivant, et un vide du côté droit pour que la lecture reste au centre.
    private var commandes: some View {
        HStack(spacing: 0) {
            Button {
                Task.immediate { @MainActor [mini] in
                    await mini.basculerAleatoire()
                }
            } label: {
                MusiqueIconeLecteur(symbole: "shuffle", couleur: Color.white)
                    .opacity(mini.opaciteAleatoire)
            }
            .accessibilityLabel(Text("lecteur_aleatoire"))
            .accessibilityAddTraits(mini.aleatoire ? [.isSelected] : [])
            Spacer(minLength: 0)
            Button {
                Task.immediate { @MainActor [mini] in
                    await mini.precedent()
                }
            } label: {
                MusiqueIconeLecteur(symbole: "backward.end.fill", couleur: Color.white)
            }
            .accessibilityLabel(Text("lecteur_precedent"))
            Spacer(minLength: 0)
            Button {
                Task.immediate { @MainActor [mini] in
                    await mini.basculerLecture()
                }
            } label: {
                Image(systemName: MusiqueMiniLecteurVue.symbole(mini.iconeLecture))
                    .font(.title)
                    .foregroundStyle(MusiqueMiniLecteurVue.sombre)
                    .frame(width: 64, height: 64)
                    .background(Color.white, in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel(Text(mini.libelleLecture, traducteur: traducteur))
            Spacer(minLength: 0)
            Button {
                Task.immediate { @MainActor [mini] in
                    await mini.suivant()
                }
            } label: {
                MusiqueIconeLecteur(symbole: "forward.end.fill", couleur: Color.white)
            }
            .accessibilityLabel(Text("lecteur_suivant"))
            Spacer(minLength: 0)
            Color.clear
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
    }

    /// Les icônes d'Android (ic_lecteur_pause, ic_lecteur_lecture) en symboles du système.
    private static func symbole(_ icone: String) -> String {
        switch icone {
        case "ic_lecteur_pause": "pause.fill"
        default: "play.fill"
        }
    }
}

// MARK: Les pièces du mini-lecteur

/// Une icône du panneau dans un bouton de 48 sur 48 (les ImageButton sans fond d'Android).
struct MusiqueIconeLecteur: View {
    let symbole: String
    let couleur: Color

    var body: some View {
        Image(systemName: symbole)
            .font(.title2)
            .foregroundStyle(couleur)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }
}

/// Le tour du disque : un tour en 12 s, linéaire, qui reprend où il s'était arrêté.
struct MusiqueTour: Equatable {
    /// L'angle atteint au dernier arrêt, en degrés.
    var base: Double = 0
    /// Le moment où le disque s'est remis à tourner ; nil à l'arrêt.
    var debut: Date?

    func angle(a date: Date) -> Double {
        guard let debut else { return base }
        return base + date.timeIntervalSince(debut) / 12 * 360
    }

    mutating func suivre(tourne: Bool, a date: Date) {
        if tourne {
            if debut == nil {
                debut = date
            }
        } else if debut != nil {
            base = angle(a: date).truncatingRemainder(dividingBy: 360)
            debut = nil
        }
    }
}

/// Le disque (MiniLecteur.rond) : un rond `stageSoft` cerclé de menthe, avec la photo du morceau en plein, ou
/// à défaut le hassid à la guitare (ou sa pose féminine), ajusté ; il tourne avec `tour`.
struct MusiqueDisqueVue: View {
    let pochette: Data?
    let imageParDefaut: String
    let taille: CGFloat
    let tour: MusiqueTour

    var body: some View {
        let image = pochette.flatMap { UIImage(data: $0) }
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: tour.debut == nil)) { contexte in
            contenu(image)
                .rotationEffect(.degrees(tour.angle(a: contexte.date)))
        }
        .frame(width: taille, height: taille)
    }

    private func contenu(_ image: UIImage?) -> some View {
        ZStack {
            Circle()
                .fill(Teinte(.stageSoft))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: taille, height: taille)
                    .accessibilityHidden(true)
            } else {
                Illustration(decorative: imageParDefaut)
                    .padding(EdgeInsets(top: 4, leading: 4, bottom: 2, trailing: 4))
            }
        }
        .frame(width: taille, height: taille)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Teinte(.mint), lineWidth: 2)
        }
    }
}

/// Le titre du panneau : une ligne qui défile en boucle s'il est trop long (le marquee d'Android), immobile et
/// tronqué avec « Réduire les animations ».
struct MusiqueTitreDefilantVue: View {
    let texte: String
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    @State private var largeurTexte: CGFloat = 0
    @State private var largeurCadre: CGFloat = 0

    /// L'écart entre la fin du titre et son retour, en points.
    private let ecart: CGFloat = 48
    /// La vitesse du défilement, en points par seconde.
    private let vitesse: Double = 30

    var body: some View {
        let defile = !reduireAnimations && largeurCadre > 0 && largeurTexte > largeurCadre
        ZStack(alignment: .leading) {
            if defile {
                TimelineView(.animation) { contexte in
                    HStack(spacing: ecart) {
                        Text(verbatim: texte)
                            .lineLimit(1)
                            .fixedSize()
                        Text(verbatim: texte)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .fixedSize()
                    .offset(x: -decalage(contexte.date))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(verbatim: texte)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .onGeometryChange(for: CGFloat.self) { geometrie in
            geometrie.size.width
        } action: { largeur in
            largeurCadre = largeur
        }
        .background(alignment: .leading) {
            Text(verbatim: texte)
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .onGeometryChange(for: CGFloat.self) { geometrie in
                    geometrie.size.width
                } action: { largeur in
                    largeurTexte = largeur
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: texte))
    }

    private func decalage(_ date: Date) -> CGFloat {
        let boucle = Double(largeurTexte + ecart)
        guard boucle > 0 else { return 0 }
        let periode = boucle / vitesse
        let instant = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: periode)
        return CGFloat(instant * vitesse)
    }
}
