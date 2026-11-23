import Foundation
import SwiftUI
import Coeur
import Barriere
import Ecrans

/// « Voir l'écran « Je suis avec Hachem » maintenant » (SettingsActivity.previewGate, BlockerView en mode PREVIEW) :
/// la réplique du bouclier de Temps d'écran, telle que l'extension la remplira (même instantané, même règle,
/// `PlanBouclier`), visage par visage ; puis l'essai réel de deux minutes, qui pose le vrai bouclier (PORTAGE.md § 2.1.8).
/// La réplique suit la mise en page du bouclier d'iOS : l'image, le titre et le texte au centre, les deux boutons en
/// bas ; ses couleurs sont celles de view_blocker.xml dans la palette choisie. Ses boutons ne font rien : c'est un
/// aperçu (le sous-menu s'ouvre, pour qu'on voie ses entrées).
public struct ApercuBouclierVue: View {
    private let modele: ApercuBouclierModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase

    public init(modele: ApercuBouclierModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(modele.explication, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                visages
                RepliqueBouclier(contenu: modele.contenu, image: modele.image)
                carteEssai
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(Libelle("bouclier_apercu_titre"), traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task { await modele.rafraichir() }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active { Task { await modele.rafraichir() } }
        }
        .overlay(alignment: .bottom) {
            if let message = modele.message {
                AccueilMessage(texte: Text(message, traducteur: traducteur))
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .task(id: modele.message) {
            guard modele.message != nil else { return }
            if await AccueilAttente.ms(3_000) { modele.messageVu() }
        }
    }

    /// Les visages, à feuilleter.
    private var visages: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ApercuBouclierModele.faces, id: \.self) { face in
                    let choisie = modele.face == face
                    Button {
                        modele.face = face
                    } label: {
                        Text(modele.libelle(face), traducteur: traducteur)
                            .font(Font.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(choisie ? Teinte(.onBrand) : Teinte(.brand))
                            .background(choisie ? Teinte(.brand) : Teinte(.card), in: Capsule())
                            .overlay { Capsule().strokeBorder(Teinte(.brand), lineWidth: 1) }
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(choisie ? .isSelected : [])
                }
            }
        }
    }

    /// L'essai réel : le bouton, et ce qu'il fera, ou pourquoi il ne peut pas.
    private var carteEssai: some View {
        Carte {
            Button {
                Task { await modele.essayer() }
            } label: {
                Text(Libelle("bouclier_essai"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .disabled(!modele.essaiPossible)
            Text(modele.etatEssai, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 8)
        }
    }
}

/// La réplique d'un bouclier de Temps d'écran.
struct RepliqueBouclier: View {
    let contenu: ContenuBouclier
    let image: String
    @Environment(\.accessibilityReduceMotion) private var reduire

    var body: some View {
        let a = contenu.apparence
        VStack(spacing: 14) {
            Spacer(minLength: 24)
            if !image.isEmpty {
                Illustration(decorative: image, hauteur: 110)
            }
            Text(verbatim: contenu.titre)
                .font(.title3.bold())
                .foregroundStyle(Color(hexBouclier: a.titre))
                .multilineTextAlignment(.center)
            Text(verbatim: contenu.sousTitre)
                .font(.subheadline)
                .foregroundStyle(Color(hexBouclier: a.texte))
                .multilineTextAlignment(.center)
            Spacer(minLength: 24)
            Text(verbatim: contenu.principal)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(hexBouclier: a.texteBouton))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(hexBouclier: a.bouton), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityAddTraits(.isButton)
            if let secondaire = contenu.secondaire {
                if contenu.sousMenu.isEmpty {
                    Text(verbatim: secondaire)
                        .font(.body)
                        .foregroundStyle(Color(hexBouclier: a.texte))
                        .frame(minHeight: 44)
                        .accessibilityAddTraits(.isButton)
                } else {
                    Menu {
                        ForEach(contenu.sousMenu, id: \.self) { entree in
                            Button(entree) {}
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(verbatim: secondaire)
                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        .font(.body)
                        .foregroundStyle(Color(hexBouclier: a.texte))
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 480)
        .background(Color(hexBouclier: a.fond), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(reduire ? nil : .easeInOut(duration: 0.2), value: contenu)
        .accessibilityElement(children: .contain)
    }
}

extension Color {
    /// Une couleur « #RRGGBB » de l'apparence du bouclier ; le noir pour un texte mal formé.
    init(hexBouclier hex: String) {
        let rvb = ApparenceBouclier.rvb(hex) ?? (rouge: 0, vert: 0, bleu: 0)
        self.init(.sRGB, red: Double(rvb.rouge) / 255, green: Double(rvb.vert) / 255, blue: Double(rvb.bleu) / 255,
                  opacity: 1)
    }
}
