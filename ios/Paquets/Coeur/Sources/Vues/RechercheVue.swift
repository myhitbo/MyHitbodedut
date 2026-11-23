import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La recherche dans toute l'application (RechercheActivity.kt, activity_recherche.xml) : le champ, qui a le focus à
/// l'ouverture ; les puces de la portée ; les résultats par sorte, une carte chacun. La vue ne décide rien : elle
/// lit RechercheModele (cible Ecrans).
///
/// Un résultat ouvre un autre écran de l'app (le lecteur du siddour ou d'un livre, la halakha, les hilloulot) :
/// la vue le demande par `ouvrir`, que l'app branche sur la pile de l'onglet (`RechercheRoute`). Ni barre « Aa »
/// ni échelle des lettres ici.
public struct RechercheVue: View {
    private let modele: RechercheModele
    private let ouvrir: @MainActor (RechercheRoute) -> Void
    @Environment(\.traducteur) private var traducteur
    @FocusState private var champActif: Bool

    public init(modele: RechercheModele, ouvrir: @escaping @MainActor (RechercheRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                carteDuChamp
                portees
                if let resultats = modele.resultats {
                    RechercheResultatsVue(resultats: resultats, police: modele.police, ouvrir: ouvrir)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Teinte(.paper))
        .navigationTitle(Text(Libelle("recherche_titre"), traducteur: traducteur))
        // L'index se prépare (des secondes la première fois) ; le champ s'utilise déjà.
        .task { await modele.charger() }
        // requestFocus() d'Android.
        .onAppear { champActif = true }
    }

    // MARK: Le champ

    private var carteDuChamp: some View {
        HStack(spacing: 8) {
            TextField(text: champ, prompt: Text(modele.indice, traducteur: traducteur), axis: .vertical) {
                Text(modele.indice, traducteur: traducteur)
            }
            .focused($champActif)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .foregroundStyle(Teinte(.ink))
            .frame(minHeight: 44)
            if modele.enCours {
                // Une recherche tourne (Android ne montre rien) : discret, et VoiceOver le passe.
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
        }
        .halakhaCarte()
    }

    private var champ: Binding<String> {
        Bindable(modele).texteSaisi
    }

    // MARK: La portée

    /// Les cinq puces, juste sous la carte : un seul choix, toujours un.
    private var portees: some View {
        HalakhaFlux {
            ForEach(modele.portees) { choix in
                HalakhaPuce(texte: Text(choix.libelle, traducteur: traducteur), choisie: choix.choisie) {
                    modele.choisirPortee(choix.portee)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: Les résultats

/// « Résultats : 47 » (même à zéro), puis chaque sorte sous son titre, une carte par résultat.
private struct RechercheResultatsVue: View {
    let resultats: RechercheResultats
    let police: PoliceHebraique.Police
    let ouvrir: @MainActor (RechercheRoute) -> Void
    @Environment(\.traducteur) private var traducteur

    init(resultats: RechercheResultats, police: PoliceHebraique.Police,
         ouvrir: @escaping @MainActor (RechercheRoute) -> Void) {
        self.resultats = resultats
        self.police = police
        self.ouvrir = ouvrir
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(resultats.nombre, traducteur: traducteur)
                .font(Font.subheadline.bold())
                .foregroundStyle(Teinte(.muted))
                .padding(.horizontal, 16)
                .padding(.top, 12)
            ForEach(resultats.groupes) { groupe in
                Text(groupe.titre, traducteur: traducteur)
                    .font(Font.footnote.bold())
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                ForEach(groupe.lignes) { ligne in
                    RechercheLigneVue(ligne: ligne, police: police) {
                        ouvrir(ligne.route)
                    }
                }
            }
        }
    }
}

/// Un résultat (RechercheActivity.ligne) : une carte qu'on touche en entier, son titre en police hébraïque, et
/// l'extrait sur deux lignes au plus.
private struct RechercheLigneVue: View {
    let ligne: RechercheLigne
    let police: PoliceHebraique.Police
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: ligne.titre)
                    .halakhaTexte(16, police: police, gras: true)
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let extrait = ligne.extrait {
                    Text(verbatim: extrait)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                        .lignesAuPlus(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.leading)
            .halakhaFond()
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(RechercheToucher())
        .halakhaMarges()
    }
}

/// L'effet du toucher sur une carte (Apparence.effetToucher) : elle pâlit un peu, sans sauter.
private struct RechercheToucher: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
