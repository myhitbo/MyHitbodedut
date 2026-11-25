import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le diagnostic des notifications en attente (propre à iOS, ROADMAP tâche 19 ; recette R3, geste 6) : une carte
/// de résumé (combien en attente sur les 64 permises, le verdict, la part de chaque catégorie, l'heure de la
/// lecture), puis une carte par notification, dans l'ordre où elles paraîtront, avec ce qu'elle a d'écart avec le
/// plan. La vue lit `RappelsDiagnosticModele` (Ecrans) ; « Actualiser » et le geste de tirer relisent.
public struct RappelsDiagnosticVue: View {
    private let modele: RappelsDiagnosticModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: RappelsDiagnosticModele) {
        self.modele = modele
    }

    public var body: some View {
        let modele = modele
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                carteResume
                if modele.charge, modele.lignes.isEmpty {
                    Text(modele.libelleVide, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.muted))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                ForEach(modele.lignes) { ligne in
                    RappelsDiagnosticLigne(ligne: ligne)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .overlay {
            if !modele.charge {
                ProgressView()
            }
        }
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { @MainActor in
                        await modele.charger()
                    }
                } label: {
                    Label {
                        Text(modele.libelleActualiser, traducteur: traducteur)
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(modele.enCours)
            }
        }
        .refreshable { [modele] in
            await modele.charger()
        }
        .task {
            await modele.charger()
        }
    }

    // MARK: Le résumé

    private var carteResume: some View {
        Carte {
            Text(modele.resume, traducteur: traducteur)
                .titreCarte()
                .multilineTextAlignment(.leading)
            if modele.charge {
                Text(modele.verdict, traducteur: traducteur)
                    .font(Font.subheadline.weight(.medium))
                    .foregroundStyle(modele.nombreDeProblemes == 0
                                     ? AnyShapeStyle(Teinte(.brand)) : AnyShapeStyle(ReglagesTeinteFixe.avertissement))
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)
            }
            if let avertissement = modele.avertissement {
                Text(avertissement, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(ReglagesTeinteFixe.avertissement)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(modele.comptes) { compte in
                    HStack {
                        Text(compte.libelleCategorie, traducteur: traducteur)
                            .foregroundStyle(Teinte(.ink))
                        Spacer(minLength: 8)
                        Text(verbatim: compte.texte)
                            .monospacedDigit()
                            .foregroundStyle(Teinte(.muted))
                    }
                    .font(.footnote)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 10)
            if !modele.lecture.isEmpty {
                Text(verbatim: modele.lecture)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 8)
            }
        }
    }
}

/// Une notification : sa catégorie et l'heure où elle paraîtra, son titre et son texte, son identifiant, puis ce
/// qu'elle a d'écart avec le plan, à la couleur `warning` quand c'est à signaler.
private struct RappelsDiagnosticLigne: View {
    let ligne: RappelsLigneDiagnostic
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            HStack(alignment: .firstTextBaseline) {
                Etiquette(Text(ligne.libelleCategorie, traducteur: traducteur))
                Spacer(minLength: 8)
                Text(verbatim: ligne.quand)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.trailing)
            }
            texte(ligne.titre)
                .font(Font.subheadline.weight(.semibold))
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .padding(.top, 8)
            texte(ligne.corps)
                .font(.footnote)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .padding(.top, 2)
            Text(verbatim: ligne.identifiant)
                .font(.caption2)
                .monospaced()
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 6)
            Text(ligne.etat, traducteur: traducteur)
                .font(Font.footnote.weight(.medium))
                .foregroundStyle(ligne.ecart.probleme
                                 ? AnyShapeStyle(ReglagesTeinteFixe.avertissement) : AnyShapeStyle(Teinte(.brand)))
                .multilineTextAlignment(.leading)
                .padding(.top, 6)
            if ligne.silenceEnfreint {
                Text("rappels_diagnostic_silence", tableName: "ios")
                    .font(Font.footnote.weight(.medium))
                    .foregroundStyle(ReglagesTeinteFixe.avertissement)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func texte(_ texte: RappelsTexte) -> Text {
        switch texte {
        case .libelle(let libelle):
            Text(libelle, traducteur: traducteur)
        case .brut(let brut):
            Text(verbatim: brut)
        }
    }
}
