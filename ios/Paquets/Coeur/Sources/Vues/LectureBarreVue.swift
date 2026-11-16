import Foundation
import SwiftUI
import Coeur
import Ecrans

// Le bouton de lecture (ReglagesLecture.kt) : la pastille « Aa », ou la barre dépliée (A−, %, A+, lune, police,
// langues, nusah, masquer, replier), en bas au centre, par-dessus le texte. Ce qui se montre et ce que fait
// chaque toucher est dans LectureModele ; la vue pose les boutons, toujours de gauche à droite (A− à gauche).

/// La pastille ou la barre ; rien quand le bouton est masqué.
struct LectureBouton: View {
    let modele: LectureModele
    /// La largeur de l'écran : sur un écran étroit, les boutons se serrent (30 à 44 points).
    let largeur: CGFloat

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var sansAnimation

    var body: some View {
        ZStack {
            if modele.barreVisible {
                LectureBarre(modele: modele, cote: cote)
            }
            if modele.pastilleVisible {
                pastille
            }
        }
        .animation(sansAnimation ? nil : .easeOut(duration: 0.18), value: modele.pastilleEffacee)
    }

    /// `(largeur − 24 − 48 − 18 − 12) / n`, borné de 30 à 44 ; n : les boutons de taille fixe de la barre.
    private var cote: CGFloat {
        let nombre: CGFloat = modele.avecNusah ? 9 : 8
        return min(44, max(30, ((largeur - 102) / nombre).rounded(.down)))
    }

    /// « Aa » : la barre se déplie. Effacée en descendant dans le texte : transparente, un peu plus bas, et
    /// elle ne se touche plus.
    private var pastille: some View {
        Button {
            modele.deplierBarre(true)
        } label: {
            Text(verbatim: "Aa")
                .font(Font.subheadline.bold())
                .foregroundStyle(Teinte(.onBrand))
                .padding(.horizontal, 12)
                .frame(minWidth: 56, minHeight: 36)
                .background(Teinte(.brand).opacity(SiddourMesures.alpha(0xF2)),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Libelle("lecture_reglages"), traducteur: traducteur))
        .opacity(modele.pastilleEffacee ? 0 : 1)
        .offset(y: modele.pastilleEffacee ? 24 : 0)
        .allowsHitTesting(!modele.pastilleEffacee)
        .accessibilityHidden(modele.pastilleEffacee)
    }
}

/// La barre dépliée.
private struct LectureBarre: View {
    let modele: LectureModele
    let cote: CGFloat

    @Environment(\.traducteur) private var traducteur

    var body: some View {
        HStack(spacing: 0) {
            lettres
            filet
            reglages
            filet
            bouton(icone: "ic_lecture_masquer", libelle: "lecture_masquer") {
                let modele = self.modele
                SiddourTache.lancer { try await modele.masquer() }
            }
            bouton(icone: "ic_lecture_replier", libelle: "lecture_replier") {
                modele.deplierBarre(false)
            }
        }
        .foregroundStyle(Teinte(.onBrand))
        .padding(.horizontal, 4)
        .frame(height: 52)
        .background(Teinte(.brand).opacity(SiddourMesures.alpha(0xF2)),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        // A− à gauche et A+ à droite, quelle que soit la langue.
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: La taille

    private var lettres: some View {
        HStack(spacing: 0) {
            Button {
                let modele = self.modele
                SiddourTache.lancer { try await modele.changerTaille(plus: false) }
            } label: {
                Text(verbatim: "A\u{2212}")
                    .font(Font.subheadline.bold())
                    .frame(width: cote, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(nom("lecture_moins"))
            Button {
                let modele = self.modele
                SiddourTache.lancer { try await modele.tailleNormale() }
            } label: {
                Text(modele.libellePourcent, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(minWidth: 48, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(modele.descriptionPourcent, traducteur: traducteur))
            Button {
                let modele = self.modele
                SiddourTache.lancer { try await modele.changerTaille(plus: true) }
            } label: {
                Text(verbatim: "A+")
                    .font(Font.title3.bold())
                    .frame(width: cote, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(nom("lecture_plus"))
        }
        .buttonStyle(.plain)
    }

    // MARK: La nuit, la police, les langues, le nusah

    @ViewBuilder
    private var reglages: some View {
        Button {
            let modele = self.modele
            SiddourTache.lancer { try await modele.basculerNuit() }
        } label: {
            SiddourIcone("ic_lecture_lune", taille: 20)
                .frame(width: cote, height: 44)
                .background {
                    if modele.sombre {
                        Circle()
                            .fill(Teinte(.onBrand).opacity(0.25))
                            .frame(width: min(cote, 40), height: min(cote, 40))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nom("lecture_nuit"))
        .accessibilityValue(Text(modele.etatNuit, traducteur: traducteur))
        Menu {
            ForEach(modele.optionsPolice) { option in
                choix(option) {
                    let modele = self.modele
                    SiddourTache.lancer { try await modele.choisirPolice(option.valeur) }
                }
            }
        } label: {
            Text(verbatim: "\u{05D0}\u{05D1}")
                .font(.body)
                .frame(width: cote, height: 44)
                .foregroundStyle(Teinte(.onBrand))
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .accessibilityLabel(nom("lecture_police"))
        Menu {
            ForEach(modele.optionsLangues) { option in
                choix(option) {
                    let modele = self.modele
                    SiddourTache.lancer { try await modele.choisirLangues(option.valeur) }
                }
            }
        } label: {
            Text(verbatim: "\u{05D0}A")
                .font(Font.subheadline.bold())
                .frame(width: cote, height: 44)
                .foregroundStyle(Teinte(.onBrand))
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .accessibilityLabel(nom("lecture_langues"))
        if modele.avecNusah {
            Menu {
                ForEach(modele.optionsNusah) { option in
                    choix(option) {
                        let modele = self.modele
                        SiddourTache.lancer { try await modele.choisirNusah(option.valeur) }
                    }
                }
            } label: {
                SiddourIcone("ic_lecture_nusah", taille: 20)
                    .frame(width: cote, height: 44)
                    .foregroundStyle(Teinte(.onBrand))
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .accessibilityLabel(nom("siddur_choose"))
        }
    }

    /// Un choix d'un menu (PopupMenu à coche d'Android) : son nom, coché s'il est choisi.
    @ViewBuilder
    private func choix<Valeur: Sendable & Hashable>(_ option: LectureOption<Valeur>,
                               action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            if option.choisi {
                Label {
                    Text(option.nom, traducteur: traducteur)
                } icon: {
                    Image(systemName: "checkmark")
                }
            } else {
                Text(option.nom, traducteur: traducteur)
            }
        }
    }

    // MARK: Les aides

    private func bouton(icone: String, libelle: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            SiddourIcone(icone, taille: 20)
                .frame(width: cote, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nom(libelle))
    }

    /// Le filet entre deux groupes : 1 × 22, sur l'accent à 33 %.
    private var filet: some View {
        Rectangle()
            .fill(Teinte(.onBrand).opacity(SiddourMesures.alpha(0x55)))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }

    /// Le libellé de lecture d'écran d'un bouton : une clé simple du catalogue.
    private func nom(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }
}
