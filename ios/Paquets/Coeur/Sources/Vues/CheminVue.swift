import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le Chemin (refonte d'Android du 13/11, panneau chemin_scroll d'activity_main.xml) : la série, la meilleure série
/// et le temps total en tête, le mois en barres, puis les cartes du journal, de « Mon parcours » et des trophées. La
/// vue ne calcule rien : elle lit `CheminModele`, qui se teste sous Linux, et ne fait qu'appeler `ouvrir(_:)` ; la pile
/// de son onglet (ios/App) ouvre l'écran demandé.
public struct CheminVue: View {
    private let modele: CheminModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.dynamicTypeSize) private var tailleTexte

    public init(modele: CheminModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Le titre dans la page, comme celui des Livres : le grand titre de la barre de navigation changeait
                // de hauteur avec la taille du texte et déplaçait toute la page (relevé par l'audit d'accessibilité).
                Text(modele.titre, traducteur: traducteur)
                    .tailleSp(24, poids: .bold, relativeA: .title2)
                    .foregroundStyle(Teinte(.ink))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 2)
                // Sur l'iPad, deux colonnes (DeuxColonnes) : les chiffres et le mois, les cartes à côté.
                DeuxColonnes(espacement: 14) {
                    chiffres
                    // Le mois en cours, en barres (chemin_mois).
                    Carte {
                        GraphiqueMois(graphique: modele.graphique, sombre: false)
                    }
                } seconde: {
                    liens
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .toolbar(.hidden, for: .navigationBar)
    }

    /// La série, la meilleure série et le temps total.
    private var chiffres: some View {
        Carte {
            // Trois colonnes ; aux tailles d'accessibilité, trois lignes (le chiffre, puis son libellé), où les mots se
            // coupaient lettre à lettre.
            RangeeAdaptable(alignement: .top, espacement: tailleTexte.isAccessibilitySize ? 12 : 8) {
                ForEach(modele.chiffres) { chiffre in
                    let disposition = tailleTexte.isAccessibilitySize
                        ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
                        : AnyLayout(VStackLayout(spacing: 4))
                    disposition {
                        valeur(chiffre.valeur)
                            .font(Font.title2.bold())
                            .monospacedDigit()
                            .foregroundStyle(Teinte(.brand))
                            // Une ligne (CheminValeur : maxLines 1), « 18 שע׳ 30 דק׳ » rapetissé plutôt que coupé.
                            .uneLigne(retrecie: 0.5)
                        Text(chiffre.libelle, traducteur: traducteur)
                            .font(.caption)
                            .foregroundStyle(Teinte(.muted))
                            .multilineTextAlignment(tailleTexte.isAccessibilitySize ? .leading : .center)
                    }
                    .frame(maxWidth: .infinity, alignment: tailleTexte.isAccessibilitySize ? .leading : .center)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// Le journal, « Mon parcours », les trophées.
    private var liens: some View {
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
                        .lignesAuPlus(1)
                    Image(systemName: "chevron.forward")
                        .font(.footnote)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Teinte(.ink))
                .frame(minHeight: 48)
            }
            .contentShape(Rectangle())
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
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityLabel(Text(entete.reglages, traducteur: traducteur))
        }
        // Toute la ligne, de la date à la roue (nav_zmanim s'étend jusqu'à nav_settings) : sur le Jour, le ciel n'y
        // pose ni étoile ni astre (le plan du ciel, AccueilVue) ; ailleurs, rien.
        .zoneDuCiel()
    }

    private func titre(_ texte: AccueilTexte) -> Text {
        switch texte {
        case .libelle(let libelle): Text(libelle, traducteur: traducteur)
        case .brut(let brut): Text(verbatim: brut)
        }
    }
}
