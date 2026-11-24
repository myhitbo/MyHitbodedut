import Foundation
import SwiftUI
import Coeur

// Les composants communs des écrans d'Android (res/values/themes.xml, dimens.xml, drawable/bg_*.xml), aux
// couleurs de la palette (Apparence.swift). Les tailles d'Android en sp deviennent des styles de texte d'iOS, qui
// suivent la taille du texte du téléphone (Dynamic Type) : 17 sp → body, 15 → subheadline, 13 → footnote,
// 12 → caption, 11 → caption2. Aucun composant ne décide de ce qu'il montre : il reçoit ses textes et ses états
// du modèle de l'écran.

// MARK: La carte

/// La carte, « l'unité de base des écrans » (style Card, drawable/bg_card.xml) : fond `card`, filet `line` de 1,
/// coins de 20, 18 de marge intérieure, toute la largeur. La marge extérieure (16 sur les côtés, 14 au-dessus
/// sur Android) revient à la pile qui pose la carte.
public struct Carte<Contenu: View>: View {
    private let contenu: Contenu

    public init(@ViewBuilder contenu: () -> Contenu) {
        self.contenu = contenu()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            contenu
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
    }
}

extension View {
    /// Le titre d'une carte (CardTitle) : 17 sp gras, encre `ink`.
    public func titreCarte() -> some View {
        font(Font.body.bold())
            .foregroundStyle(Teinte(.ink))
    }

    /// L'indication sous un titre (CardHint) : 13 sp, gris `muted`.
    public func indicationCarte() -> some View {
        font(.footnote)
            .foregroundStyle(Teinte(.muted))
    }
}

// MARK: Les boutons

/// Le bouton principal (Bouton.Plein, 04/11) : une pilule pleine à la couleur de l'accent (`brand`), texte
/// `onBrand` medium, 48 de haut au moins. `grand` : le bouton « Commencer » de l'accueil (StartButton), 60 de
/// haut et 17 sp. `.buttonStyle(.principal)`.
public struct BoutonPrincipal: ButtonStyle {
    private let grand: Bool

    public init(grand: Bool = false) {
        self.grand = grand
    }

    public func makeBody(configuration: Configuration) -> some View {
        CorpsBoutonPrincipal(configuration: configuration, grand: grand)
    }
}

/// Le bouton secondaire (Bouton.Contour) : une pilule cerclée du filet `line`, texte medium à la couleur de
/// l'accent, 48 de haut au moins. `.buttonStyle(.secondaire)`.
public struct BoutonSecondaire: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CorpsBoutonSecondaire(configuration: configuration)
    }
}

extension ButtonStyle where Self == BoutonPrincipal {
    public static var principal: BoutonPrincipal { BoutonPrincipal() }
    /// Le bouton « Commencer » de l'accueil.
    public static var principalGrand: BoutonPrincipal { BoutonPrincipal(grand: true) }
}

extension ButtonStyle where Self == BoutonSecondaire {
    public static var secondaire: BoutonSecondaire { BoutonSecondaire() }
}

/// Un bouton inactif s'efface (38 %, comme Material) ; pressé, il pâlit un peu (Android ne le fait pas sauter).
private func opaciteBouton(actif: Bool, presse: Bool) -> Double {
    guard actif else { return 0.38 }
    return presse ? 0.75 : 1
}

private struct CorpsBoutonPrincipal: View {
    let configuration: ButtonStyleConfiguration
    let grand: Bool
    @Environment(\.isEnabled) private var actif

    init(configuration: ButtonStyleConfiguration, grand: Bool) {
        self.configuration = configuration
        self.grand = grand
    }

    var body: some View {
        configuration.label
            .font(grand ? Font.body.weight(.medium) : Font.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Teinte(.onBrand))
            .padding(.horizontal, grand ? 24 : 22)
            .padding(.vertical, grand ? 14 : 10)
            .frame(minHeight: grand ? 60 : 48)
            .background(Teinte(.brand), in: Capsule())
            .contentShape(Capsule())
            .opacity(opaciteBouton(actif: actif, presse: configuration.isPressed))
    }
}

private struct CorpsBoutonSecondaire: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var actif

    init(configuration: ButtonStyleConfiguration) {
        self.configuration = configuration
    }

    var body: some View {
        configuration.label
            .font(Font.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Teinte(.brand))
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
            .opacity(opaciteBouton(actif: actif, presse: configuration.isPressed))
    }
}

// MARK: Les pastilles

/// Un réglage de la prochaine séance, en pastille sous le bouton de l'accueil (StartChip, bg_start_chip.xml) :
/// le libellé en gris, la valeur à la couleur de l'accent, sur une pilule `card` cerclée de `line` ; toute la
/// pastille se touche. VoiceOver la lit d'un trait, libellé puis valeur.
public struct Pastille: View {
    private let libelle: Text
    private let valeur: Text
    private let action: @MainActor () -> Void

    public init(libelle: Text, valeur: Text, action: @escaping @MainActor () -> Void) {
        self.libelle = libelle
        self.valeur = valeur
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                libelle
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                valeur
                    .font(Font.footnote.bold())
                    .foregroundStyle(Teinte(.brand))
                    .lignesAuPlus(1)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Teinte(.card), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Une étiquette de texte sur la menthe (bg_chip_mint.xml) : l'étape d'une présentation, le genre d'une entrée
/// de la bibliothèque. 11 sp, encre `onPlate`, qui reste lisible sur la menthe de jour comme de nuit.
public struct Etiquette: View {
    private let texte: Text

    public init(_ texte: Text) {
        self.texte = texte
    }

    public var body: some View {
        texte
            // 11 points (caption2), qui suivent chaque pas de la taille du texte : caption2 reste à 11 points sous la
            // taille ordinaire, et l'audit d'accessibilité la disait suivie « en partie ».
            .tailleSp(11, relativeA: .footnote)
            .foregroundStyle(Teinte(.onPlate))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Teinte(.mint), in: Capsule())
    }
}

// MARK: Les lignes

/// Une entrée de section de l'accueil (SectionRow) : un titre, son état sur deux lignes au plus, et le chevron
/// de l'accent, qui se retourne en hébreu (ic_chevron, autoMirrored). 56 de haut au moins, toute la ligne se
/// touche : la poser comme étiquette d'un `NavigationLink` ou d'un `Button` de style `.plain`, dans une carte
/// (une `List` ajoute déjà son propre chevron).
public struct LigneSection: View {
    private let titre: Text
    private let etat: Text?

    public init(titre: Text, etat: Text? = nil) {
        self.titre = titre
        self.etat = etat
    }

    public var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                titre
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                if let etat {
                    etat
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                        .lignesAuPlus(2)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(Font.subheadline.weight(.semibold))
                .foregroundStyle(Teinte(.brand))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Une ligne d'horaire (VueJour.horaires) : le nom du zman, son heure en chiffres de même chasse, et sous eux la
/// méthode de calcul en petit. `misEnAvant` (l'allumage et la sortie de Chabbat sur Android) passe le nom et
/// l'heure à la couleur de l'accent, en gras. L'heure se lit toujours de gauche à droite, même en hébreu.
public struct LigneHoraire: View {
    private let libelle: Text
    private let heure: String
    private let methode: Text?
    private let misEnAvant: Bool

    public init(libelle: Text, heure: String, methode: Text? = nil, misEnAvant: Bool = false) {
        self.libelle = libelle
        self.heure = heure
        self.methode = methode
        self.misEnAvant = misEnAvant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                libelle
                    .font(misEnAvant ? Font.subheadline.bold() : Font.subheadline)
                    .foregroundStyle(Teinte(misEnAvant ? .brand : .ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: heure)
                    .font(Font.body.bold().monospacedDigit())
                    .foregroundStyle(Teinte(misEnAvant ? .brand : .ink))
                    .environment(\.layoutDirection, .leftToRight)
            }
            if let methode {
                methode
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
