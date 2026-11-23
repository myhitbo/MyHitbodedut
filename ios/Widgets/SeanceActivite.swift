import ActivityKit
import Coeur
import Ecrans
import SwiftUI
import WidgetKit

// La Live Activity de la séance (tâche 17, PORTAGE.md § 2.2.1) : la notification permanente de SessionService.kt sur
// l'écran verrouillé et dans l'île dynamique. « Hitbodedout en cours », puis le temps qui reste (séance minutée), le
// temps passé (séance sans durée), ou, compteur masqué, une phrase sans chiffre (runningText) ; « Terminer maintenant »
// termine la séance sans ouvrir l'app (ACTION_FINISH). Le minuteur vit seul (`Text(timerInterval:)`, le Chronometer
// d'Android) : l'app ne la met pas à jour à chaque seconde. Le toucher ouvre l'écran de la séance.

struct SeanceActiviteWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SeanceAttributs.self) { contexte in
            SeanceEcranVerrouille(attributs: contexte.attributes, etat: contexte.state)
                .activityBackgroundTint(CouleursWidgets.nuitVerte)
                .activitySystemActionForegroundColor(CouleursWidgets.menthe)
                .widgetURL(LienApp.seance(demarrer: false).url)
        } dynamicIsland: { contexte in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.mind.and.body")
                        .font(.title2)
                        .foregroundStyle(CouleursWidgets.menthe)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SeanceCompteur(etat: contexte.state)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(CouleursWidgets.menthe)
                        .frame(maxWidth: 90)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: contexte.attributes.titre)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SeanceBoutonTerminer(libelle: contexte.attributes.terminer)
                }
            } compactLeading: {
                Image(systemName: "figure.mind.and.body")
                    .foregroundStyle(CouleursWidgets.menthe)
                    .accessibilityHidden(true)
            } compactTrailing: {
                SeanceCompteur(etat: contexte.state, court: true)
                    .monospacedDigit()
                    .foregroundStyle(CouleursWidgets.menthe)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "figure.mind.and.body")
                    .foregroundStyle(CouleursWidgets.menthe)
                    .accessibilityHidden(true)
            }
            .widgetURL(LienApp.seance(demarrer: false).url)
        }
    }
}

/// Le minuteur : vers la fin, depuis le début, ou la phrase du compteur masqué.
private struct SeanceCompteur: View {
    let etat: SeanceAttributs.ContentState
    var court = false

    var body: some View {
        if let masque = etat.texteMasque {
            if court {
                Image(systemName: "eye.slash")
                    .accessibilityLabel(Text(verbatim: masque))
            } else {
                Text(verbatim: masque)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        } else if etat.debut < etat.fin {
            Text(timerInterval: etat.debut...etat.fin, countsDown: etat.decompte)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SeanceBoutonTerminer: View {
    let libelle: String

    var body: some View {
        Button(intent: TerminerSeanceIntent()) {
            Text(verbatim: libelle)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .tint(CouleursWidgets.menthe)
    }
}

/// L'écran verrouillé : le titre, le minuteur en grand, « Terminer maintenant ».
private struct SeanceEcranVerrouille: View {
    let attributs: SeanceAttributs
    let etat: SeanceAttributs.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "figure.mind.and.body")
                    .font(.title2)
                    .foregroundStyle(CouleursWidgets.menthe)
                    .accessibilityHidden(true)
                Text(verbatim: attributs.titre)
                    .font(.headline)
                    .foregroundStyle(CouleursWidgets.fort)
                    .lineLimit(1)
                Spacer(minLength: 8)
                SeanceCompteur(etat: etat)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(CouleursWidgets.menthe)
            }
            SeanceBoutonTerminer(libelle: attributs.terminer)
        }
        .padding(16)
        .environment(\.layoutDirection, TextesWidgets.deDroiteAGauche ? .rightToLeft : .leftToRight)
    }
}
