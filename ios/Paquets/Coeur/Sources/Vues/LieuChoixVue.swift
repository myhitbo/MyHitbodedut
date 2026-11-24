import Accessibility
import Foundation
import SwiftUI
import Coeur
import Ecrans

// Le choix du lieu des zmanim (ChoixLieu.kt) : le dialogue « Choisir le lieu » (« Ma position », puis les villes)
// et ses messages brefs (les Toast d'Android). Tout se décide dans LieuModele (Ecrans), partagé par l'onglet
// Zmanim et le calendrier : la vue présente son dialogue quand `dialogueOuvert` est vrai, et son message tant
// qu'il en a un.

/// Le dialogue « Choisir le lieu » (ChoixLieu.montrer), en feuille : « Ma position » d'abord, puis les villes
/// dans l'ordre de `villes.json`, chacune dans la langue de l'app. Un choix ferme la feuille (le modèle remet
/// `dialogueOuvert` à faux) ; la glisser vers le bas la ferme sans rien choisir, comme toucher hors d'un dialogue
/// d'Android.
public struct LieuChoixVue: View {
    let modele: LieuModele

    @Environment(\.traducteur) private var traducteur

    public init(modele: LieuModele) {
        self.modele = modele
    }

    public var body: some View {
        NavigationStack {
            List(modele.options) { option in
                Button {
                    choisir(option)
                } label: {
                    LieuLigneChoix(texte: nom(option.nom), cochee: false)
                }
                .listRowBackground(Rectangle().fill(Teinte(.card)))
            }
            .scrollContentBackground(.hidden)
            .background(Teinte(.paper))
            .navigationTitle(Text(modele.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func nom(_ nom: LieuNom) -> Text {
        switch nom {
        case .libelle(let libelle):
            Text(libelle, traducteur: traducteur)
        case .texte(let texte):
            Text(verbatim: texte)
        }
    }

    /// Une écriture des réglages qui échoue ne dit rien, comme Android (Store ne signale pas d'échec).
    private func choisir(_ option: LieuOption) {
        let modele = self.modele
        Task {
            do {
                try await modele.choisir(option)
            } catch {
            }
        }
    }
}

extension View {
    /// Pose le dialogue du choix du lieu et ses messages brefs sur un écran. `actif` : l'écran est celui qu'on
    /// voit (le premier de sa pile) ; l'onglet Zmanim et le calendrier partagent le même LieuModele, et seul
    /// l'écran du dessus le présente. Sans modèle (un aperçu), rien n'est posé.
    public func lieuChoix(_ modele: LieuModele?, actif: Bool) -> some View {
        modifier(LieuChoixModificateur(modele: modele, actif: actif))
    }
}

/// Le dialogue et le message bref du choix du lieu, liés à l'état de LieuModele.
struct LieuChoixModificateur: ViewModifier {
    let modele: LieuModele?
    let actif: Bool

    @Environment(\.traducteur) private var traducteur

    init(modele: LieuModele?, actif: Bool) {
        self.modele = modele
        self.actif = actif
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: ouvert) {
                if let modele {
                    LieuChoixVue(modele: modele)
                }
            }
            .overlay(alignment: .bottom) {
                messagePassager
            }
            .task(id: actif ? modele?.message : nil) {
                await montrerMessage()
            }
    }

    /// Le dialogue suit le modèle, sur l'écran du dessus seulement ; le fermer sans choisir remet le modèle à faux.
    private var ouvert: Binding<Bool> {
        let modele = self.modele
        let actif = self.actif
        return Binding.passerelle({ @MainActor in actif && (modele?.dialogueOuvert ?? false) },
                       { @MainActor ouvert in
                           if !ouvert { modele?.dialogueOuvert = false }
                       })
    }

    // MARK: Le message bref (Toast)

    @ViewBuilder private var messagePassager: some View {
        if actif, let modele, let message = modele.message {
            HStack(spacing: 8) {
                if modele.enCours {
                    ProgressView()
                        .tint(Teinte(.paper))
                }
                Text(message.libelle, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.paper))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Teinte(.ink).opacity(0.92), in: Capsule())
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            // Un Toast ne prend pas les touchers : ce qui est dessous reste touchable.
            .allowsHitTesting(false)
            // VoiceOver le dit par l'annonce : la bulle ne s'ajoute pas à la lecture de l'écran.
            .accessibilityHidden(true)
        }
    }

    /// Le Toast : VoiceOver le dit (TalkBack lit un Toast), puis il s'efface au bout de sa durée (LENGTH_LONG
    /// 3,5 s, LENGTH_SHORT 2 s) et le modèle l'oublie. Un autre message, ou aucun, annule l'attente.
    private func montrerMessage() async {
        guard actif, let modele, let message = modele.message else { return }
        AccessibilityNotification.Announcement(traducteur.texte(message.libelle)).post()
        do {
            try await Task.sleep(for: .seconds(message.long ? 3.5 : 2))
        } catch {
            return
        }
        modele.messageVu()
    }
}
