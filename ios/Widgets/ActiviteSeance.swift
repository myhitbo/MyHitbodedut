import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// La Live Activity de la séance (la notification permanente de SessionService.kt, PORTAGE.md § 2.2.1), sur l'écran
/// verrouillé et dans l'île dynamique : le titre, le décompte que le système fait tourner seul (`Text(timerInterval:)`,
/// sans aucune mise à jour de l'app), la légende de l'écran de séance, et « Terminer maintenant »
/// (`ActiviteSeanceTerminer`, exécutée dans l'app).
///
/// Trois états, décidés par l'app (`SeanceActivite` d'Ecrans) : le reste d'une séance minutée, l'écoulé d'une séance
/// sans durée, rien sous « Masquer le décompte » ou le filtre de concentration. Une fin passée sans que l'app soit
/// revenue (`isStale`, la date de péremption est la fin) le dit, et le toucher rouvre l'app, qui inscrit la séance.
///
/// Le toucher ouvre l'écran de séance (`myhitbodedut://seance`, App/Liens.swift). Les textes arrivent traduits dans
/// la langue de l'app, avec son sens d'écriture.
struct ActiviteSeanceWidget: Widget {

    /// L'écran de séance de l'app.
    static let lien = URL(string: "myhitbodedut://seance")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ActiviteSeanceAttributs.self) { contexte in
            ActiviteSeanceEcranVerrouille(etat: contexte.state, echue: contexte.isStale)
                .activityBackgroundTint(ActiviteSeanceCouleurs.fond)
                .activitySystemActionForegroundColor(ActiviteSeanceCouleurs.texte)
                .widgetURL(ActiviteSeanceWidget.lien)
        } dynamicIsland: { contexte in
            let etat = contexte.state
            let echue = contexte.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActiviteSeanceSigne()
                        .font(.title2)
                        .sens(etat)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActiviteSeanceChiffre(etat: etat, echue: echue)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(ActiviteSeanceCouleurs.texte)
                        .frame(maxWidth: 120)
                        .sens(etat)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: etat.titre)
                        .font(.headline)
                        .foregroundStyle(ActiviteSeanceCouleurs.texte)
                        .lineLimit(1)
                        .sens(etat)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(verbatim: etat.phrase(echue: echue))
                            .font(.caption)
                            .foregroundStyle(ActiviteSeanceCouleurs.pale)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        ActiviteSeanceBoutonTerminer(etat: etat)
                    }
                    .sens(etat)
                }
            } compactLeading: {
                ActiviteSeanceSigne()
            } compactTrailing: {
                ActiviteSeanceChiffre(etat: etat, echue: echue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ActiviteSeanceCouleurs.menthe)
                    .frame(maxWidth: 56)
            } minimal: {
                ActiviteSeanceSigne()
            }
            .widgetURL(ActiviteSeanceWidget.lien)
            .keylineTint(ActiviteSeanceCouleurs.menthe)
        }
    }
}

/// Les couleurs fixes de la Live Activity : la marque d'Android (brand), un fond sombre lisible sur tous les écrans
/// verrouillés, la menthe de l'écran de séance.
enum ActiviteSeanceCouleurs {
    static let fond = Color(red: 0.10, green: 0.43, blue: 0.36)
    static let texte = Color.white
    static let pale = Color.white.opacity(0.78)
    static let menthe = Color(red: 0.66, green: 0.88, blue: 0.80)
}

/// L'écran verrouillé (et la bannière des iPhone sans île) : le signe, le titre et la phrase, le chiffre ; dessous,
/// « Terminer maintenant ».
struct ActiviteSeanceEcranVerrouille: View {
    let etat: ActiviteSeanceAttributs.ContentState
    let echue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ActiviteSeanceSigne()
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: etat.titre)
                        .font(.headline)
                        .foregroundStyle(ActiviteSeanceCouleurs.texte)
                        .lineLimit(1)
                    Text(verbatim: etat.phrase(echue: echue))
                        .font(.caption)
                        .foregroundStyle(ActiviteSeanceCouleurs.pale)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                ActiviteSeanceChiffre(etat: etat, echue: echue)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(ActiviteSeanceCouleurs.texte)
                    .frame(maxWidth: 140, alignment: .trailing)
            }
            ActiviteSeanceBoutonTerminer(etat: etat)
        }
        .padding(16)
        .sens(etat)
    }
}

/// Le chiffre : le décompte qui tourne seul, un œil barré sous un décompte masqué, une coche quand la fin est passée.
struct ActiviteSeanceChiffre: View {
    let etat: ActiviteSeanceAttributs.ContentState
    let echue: Bool

    var body: some View {
        if echue {
            // La phrase dit ce qui reste à faire ; le chiffre, arrêté, n'apprendrait rien.
            Image(systemName: "checkmark.circle")
                .accessibilityHidden(true)
        } else if etat.decompteVisible {
            Text(timerInterval: etat.intervalle, countsDown: etat.descend)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Image(systemName: "eye.slash")
                .accessibilityLabel(Text(verbatim: etat.legendeMontree))
        }
    }
}

/// « Terminer maintenant » : l'intention s'exécute dans l'app, sans l'ouvrir.
struct ActiviteSeanceBoutonTerminer: View {
    let etat: ActiviteSeanceAttributs.ContentState

    var body: some View {
        Button(intent: ActiviteSeanceTerminer()) {
            Text(verbatim: etat.terminer)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(ActiviteSeanceCouleurs.menthe)
    }
}

/// Le signe de la séance, dans la menthe de l'écran de séance (aucune image pendant la prière : un symbole).
struct ActiviteSeanceSigne: View {
    var body: some View {
        Image(systemName: "leaf.fill")
            .foregroundStyle(ActiviteSeanceCouleurs.menthe)
            .accessibilityHidden(true)
    }
}

private extension View {
    /// Le sens d'écriture de la langue de l'app, qui peut n'être pas celle du téléphone.
    func sens(_ etat: ActiviteSeanceAttributs.ContentState) -> some View {
        environment(\.layoutDirection, etat.droiteAGauche ? .rightToLeft : .leftToRight)
    }
}
