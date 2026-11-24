import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// L'aide à la concentration, qui remplace « Ne pas déranger pendant la hitbodedout » (NePasDeranger.kt,
/// PORTAGE.md § 2.2.6) : pourquoi l'app ne coupe pas elle-même les notifications, les étapes pour créer dans les
/// Réglages d'iOS un mode « Hitbodedout » qui s'active quand MyHitbodedut est ouverte, le bouton qui ouvre les
/// Réglages (sur la page de l'app : le texte sous le bouton le dit), puis le filtre de l'app qui masque le décompte
/// pendant ce mode, et ce qu'il fait en ce moment. La vue lit `ConcentrationModele` (Ecrans) ; elle est poussée sur
/// la pile de l'onglet Réglages et n'en ouvre pas d'autre.
///
/// Seule ouverture du système : `UIApplication.open` de `openSettingsURLString`, comme les lignes des réglages
/// (ReglagesAiguillage) ; s'il refuse, le modèle donne le message d'Android.
public struct ConcentrationVue: View {
    private let modele: ConcentrationModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: ConcentrationModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(modele.introduction, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                carteEtapes
                ouvertureReglages
                carteFiltre
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .alert(titreMessage, isPresented: messageOuvert) {
            Button(role: .cancel) {
                modele.message = nil
            } label: {
                Text("action_ok", tableName: "ios")
            }
        }
    }

    // MARK: Les étapes

    private var carteEtapes: some View {
        Carte {
            Text(modele.titreEtapes, traducteur: traducteur)
                .titreCarte()
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(modele.etapes) { etape in
                    ConcentrationLigneEtape(etape: etape)
                }
            }
            .padding(.top, 14)
            Text(modele.resultat, traducteur: traducteur)
                .indicationCarte()
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.top, 14)
        }
    }

    // MARK: Les Réglages d'iOS

    /// Le bouton, et ce qu'il ouvre vraiment : la page de l'app dans les Réglages.
    private var ouvertureReglages: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                ouvrirReglages()
            } label: {
                Text(modele.libelleOuvrirReglages, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            Text(modele.noteOuvrirReglages, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: Le filtre

    private var carteFiltre: some View {
        Carte {
            Text(modele.titreFiltre, traducteur: traducteur)
                .titreCarte()
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            Text(modele.explicationFiltre, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.top, 8)
            Etiquette(Text(modele.etatFiltre, traducteur: traducteur))
                .padding(.top, 12)
        }
    }

    // MARK: Le message

    private var titreMessage: Text {
        Text(verbatim: modele.message.map { traducteur.texte($0) } ?? "")
    }

    private var messageOuvert: Binding<Bool> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.message != nil },
                                  { @MainActor ouvert in
                                      if !ouvert {
                                          modele.message = nil
                                      }
                                  })
    }

    /// Les Réglages d'iOS, sur la page de l'app (aucune adresse publique n'ouvre « Concentration »).
    private func ouvrirReglages() {
        let modele = self.modele
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            modele.reglagesImpossibles()
            return
        }
        UIApplication.shared.open(url, options: [:]) { acceptee in
            if !acceptee {
                modele.reglagesImpossibles()
            }
        }
    }
}

/// Une étape : son rang dans une pastille ronde à la menthe, puis ce qu'il faut faire. VoiceOver la lit d'un trait.
private struct ConcentrationLigneEtape: View {
    let etape: ConcentrationEtape
    @Environment(\.traducteur) private var traducteur
    /// La pastille des conseils (bg_tip_number), un peu plus petite : 28, qui grandit avec la taille du texte.
    @ScaledMetric(relativeTo: .subheadline) private var diametre: CGFloat = 28

    // Écrit : la propriété privée `diametre` rendrait privé l'initialiseur par membres, hors de portée de
    // ConcentrationVue.
    init(etape: ConcentrationEtape) {
        self.etape = etape
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: etape.numeroTexte)
                .font(Font.footnote.bold())
                .foregroundStyle(Teinte(.onPlate))
                .frame(width: diametre, height: diametre)
                .background(Teinte(.mint), in: Circle())
            Text(etape.texte, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }
}
