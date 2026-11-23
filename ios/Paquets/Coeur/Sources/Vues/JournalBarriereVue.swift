import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le journal de la barrière (PORTAGE.md § 2.1.8) : les cinquante derniers événements de la surveillance, du bouclier
/// et de l'app, du plus récent au plus ancien, à partager (pour la mise au point sur l'iPhone, sans Mac).
public struct JournalBarriereVue: View {
    private let modele: JournalBarriereModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: JournalBarriereModele) {
        self.modele = modele
    }

    public var body: some View {
        List {
            if let vide = modele.vide {
                Text(vide, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .listRowBackground(Teinte(.card))
            }
            ForEach(modele.lignes) { ligne in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(verbatim: ligne.quand)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Teinte(.muted))
                        .environment(\.layoutDirection, .leftToRight)
                    Text(ligne.texte, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.ink))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .listRowBackground(Teinte(.card))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !modele.lignes.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: modele.partage(traducteur)) {
                        Text(Libelle("chizuk_partager"), traducteur: traducteur)
                    }
                }
            }
        }
        .task { await modele.rafraichir() }
        .refreshable { await modele.rafraichir() }
    }
}
