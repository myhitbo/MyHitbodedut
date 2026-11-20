import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le Chemin (refonte d'Android du 13/11, panneau chemin_scroll d'activity_main.xml) : la série, la meilleure série
/// et le temps total en tête, puis les cartes du journal, de « Mon parcours » et des trophées. La vue ne calcule
/// rien : elle lit `CheminModele`, qui se teste sous Linux, et ne fait qu'appeler `ouvrir(_:)` ; la pile de son
/// onglet (ios/App) ouvre l'écran demandé. Le mois en barres viendra avec le dessin du graphique du journal.
public struct CheminVue: View {
    private let modele: CheminModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: CheminModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Carte {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(modele.chiffres) { chiffre in
                            VStack(spacing: 4) {
                                valeur(chiffre.valeur)
                                    .font(Font.title2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(Teinte(.brand))
                                Text(chiffre.libelle, traducteur: traducteur)
                                    .font(.caption)
                                    .foregroundStyle(Teinte(.muted))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                Carte {
                    Button {
                        modele.ouvrir(.journal)
                    } label: {
                        LigneSection(titre: Text(modele.libelleJournal, traducteur: traducteur),
                                     etat: Text(modele.etatJournal, traducteur: traducteur))
                    }
                    .buttonStyle(.plain)
                    Button {
                        modele.ouvrir(.parcours)
                    } label: {
                        LigneSection(titre: Text(modele.libelleParcours, traducteur: traducteur),
                                     etat: Text(modele.indicationParcours, traducteur: traducteur))
                    }
                    .buttonStyle(.plain)
                    Button {
                        modele.ouvrir(.paliers)
                    } label: {
                        LigneSection(titre: Text(modele.libelleTrophees, traducteur: traducteur),
                                     etat: Text(modele.etatTrophees, traducteur: traducteur))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
    }

    private func valeur(_ texte: AccueilTexte) -> Text {
        switch texte {
        case .libelle(let libelle): Text(libelle, traducteur: traducteur)
        case .brut(let brut): Text(verbatim: brut)
        }
    }
}

/// L'en-tête du Jour (refonte d'Android du 13/11) : à gauche, le ciel du moment et la date hébraïque, qui ouvrent les
/// zmanim ; à droite, la roue des réglages. Les deux gestes passent par le modèle (`ouvrirZmanim`, `ouvrirReglages`),
/// dont la pile de l'onglet lit les routes.
public struct EnteteJour: View {
    private let modele: AccueilModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: AccueilModele) {
        self.modele = modele
    }

    public var body: some View {
        let entete = modele.entete
        HStack(spacing: 8) {
            Button {
                modele.ouvrirZmanim()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: CielDuJour.symbole(entete.ciel))
                        .accessibilityHidden(true)
                    titre(entete.titre)
                        .font(.subheadline)
                        .lineLimit(1)
                    Image(systemName: "chevron.forward")
                        .font(.footnote)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Teinte(.ink))
                .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(entete.accessibilite, traducteur: traducteur))
            Spacer(minLength: 0)
            Button {
                modele.ouvrirReglages()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(Teinte(.ink))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(entete.reglages, traducteur: traducteur))
        }
    }

    private func titre(_ texte: AccueilTexte) -> Text {
        switch texte {
        case .libelle(let libelle): Text(libelle, traducteur: traducteur)
        case .brut(let brut): Text(verbatim: brut)
        }
    }
}
