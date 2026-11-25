import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// Les rappels de hitbodedout (RemindersActivity.kt, activity_reminders.xml, item_reminder.xml) : le bandeau (titre,
/// résumé, illustration), la carte de l'interrupteur général, de l'avertissement des notifications refusées et du
/// trophée tout proche, puis les heures, chacune à changer d'un toucher ou à retirer, et « Ajouter une heure ». En
/// bas, l'entrée de l'écran de diagnostic des notifications en attente (propre à iOS, ROADMAP tâche 19). La vue ne
/// décide rien : elle lit `RappelsModele` (Ecrans) et appelle ses actions.
///
/// Les Réglages d'iOS s'ouvrent ici (`openNotificationSettingsURLString`) ; l'écran de diagnostic passe par
/// `ouvrir`, que l'app branche.
public struct RappelsVue: View {
    private let modele: RappelsModele
    private let aiguillage: RappelsAiguillage
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameters:
    ///   - modele: `RappelsModele(magasin:notificateur:rappels:diagnosticVisible:)`.
    ///   - ouvrir: l'écran de diagnostic (`RappelsRoute.diagnostic`) ; les Réglages d'iOS s'ouvrent sans lui.
    public init(modele: RappelsModele, ouvrir: @escaping @MainActor (RappelsRoute) -> Void) {
        self.modele = modele
        aiguillage = RappelsAiguillage(ouvrir: ouvrir)
    }

    public var body: some View {
        VStack(spacing: 0) {
            BibliothequeBandeau(titre: Text(modele.titre, traducteur: traducteur),
                                sousTitre: Text(modele.resume, traducteur: traducteur),
                                image: modele.illustration, mesure: .liste)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    carteInterrupteurs
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    enteteHeures
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    ForEach(modele.heures) { ligne in
                        ligneHeure(ligne)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    ajouter
                        .padding(16)
                    if modele.diagnosticVisible {
                        diagnostic
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await modele.rafraichir()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task.immediate { @MainActor [modele] in
                    await modele.rafraichir()
                }
            }
        }
        .sheet(item: dialogue) { _ in
            feuilleHeure
        }
    }

    // MARK: La carte des interrupteurs

    private var carteInterrupteurs: some View {
        Carte {
            ReglagesLigneInterrupteur(Text(modele.libelleInterrupteur, traducteur: traducteur),
                                      indication: Text(modele.indicationInterrupteur, traducteur: traducteur),
                                      margeHaute: false, actif: interrupteur)
            if let avertissement = modele.avertissement {
                Button {
                    toucherAvertissement()
                } label: {
                    // CardHint à la couleur `warning` (reminders_permission).
                    Text(avertissement, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(ReglagesTeinteFixe.avertissement)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            ReglagesLigneInterrupteur(Text(modele.libelleTropheeProche, traducteur: traducteur), actif: trophee)
        }
    }

    // MARK: Les heures

    private var enteteHeures: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(modele.titreHeures, traducteur: traducteur)
                .font(Font.body.bold())
                .foregroundStyle(Teinte(.ink))
                .accessibilityAddTraits(.isHeader)
            Text(modele.indicationHeures, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
            Text(modele.indicationJours, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 2)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Une heure (item_reminder.xml) : l'heure, qu'un toucher change, et « Retirer ».
    private func ligneHeure(_ ligne: RappelsHeure) -> some View {
        let modele = modele
        let retirer = traducteur.texte(modele.libelleRetirer)
        return HStack(spacing: 8) {
            Button {
                modele.ouvrirModification(ligne.rang)
            } label: {
                Text(verbatim: ligne.texte)
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(modele.indicationHeures, traducteur: traducteur))
            Button {
                Task { @MainActor in
                    await modele.retirer(ligne.rang)
                }
            } label: {
                Text(verbatim: retirer)
                    .font(Font.subheadline.weight(.medium))
                    .foregroundStyle(Teinte(.brand))
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: retirer + " " + ligne.texte))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
    }

    private var ajouter: some View {
        let modele = modele
        return Button {
            modele.ouvrirAjout()
        } label: {
            Text(modele.libelleAjouter, traducteur: traducteur)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.principal)
    }

    private var diagnostic: some View {
        let aiguillage = aiguillage
        return Button {
            aiguillage.suivre(.diagnostic)
        } label: {
            Text(modele.libelleDiagnostic, traducteur: traducteur)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondaire)
    }

    // MARK: Le choix de l'heure

    /// Le sélecteur d'heure (TimePickerDialog d'Android), ouvert par le modèle ; le fermer d'un geste ne change rien.
    private var feuilleHeure: some View {
        let modele = modele
        return RappelsChoixHeure(
            heure: modele.heureDialogue,
            minute: modele.minuteDialogue,
            libelle: Text(modele.titreHeures, traducteur: traducteur),
            valider: { heure, minute in
                Task { @MainActor in
                    await modele.choisir(heure: heure, minute: minute)
                }
            },
            annuler: {
                modele.fermerDialogue()
            })
    }

    // MARK: Liaisons

    /// L'interrupteur général lit le réglage du modèle et l'écrit par son action ; la route rendue (les Réglages
    /// d'iOS, la question ayant déjà été posée) est suivie.
    private var interrupteur: Binding<Bool> {
        let modele = modele
        let aiguillage = aiguillage
        return Binding.passerelle(
            { @MainActor in modele.actif },
            { @MainActor actif in
                Task.immediate { @MainActor in
                    let route = await modele.basculer(actif)
                    aiguillage.suivre(route)
                }
            })
    }

    private var trophee: Binding<Bool> {
        let modele = modele
        return Binding.passerelle(
            { @MainActor in modele.tropheeProche },
            { @MainActor oui in
                Task.immediate { @MainActor in
                    await modele.basculerTropheeProche(oui)
                }
            })
    }

    /// La feuille de l'heure suit `dialogue` ; glissée vers le bas, elle se ferme sans rien choisir.
    private var dialogue: Binding<RappelsDialogue?> {
        let modele = modele
        return Binding.passerelle(
            { @MainActor in modele.dialogue },
            { @MainActor ouvert in
                if ouvert == nil { modele.fermerDialogue() }
            })
    }

    private func toucherAvertissement() {
        let modele = modele
        let aiguillage = aiguillage
        Task.immediate { @MainActor in
            let route = await modele.toucherAvertissement()
            aiguillage.suivre(route)
        }
    }
}

// MARK: L'aiguillage

/// Suit les routes de l'écran : les Réglages d'iOS s'ouvrent ici, l'écran de diagnostic passe par `ouvrir`. Une
/// classe liée à l'acteur principal, que les tâches des gestes gardent sans rien exiger de la fermeture `ouvrir`.
@MainActor
final class RappelsAiguillage {
    private let ouvrir: @MainActor (RappelsRoute) -> Void

    init(ouvrir: @escaping @MainActor (RappelsRoute) -> Void) {
        self.ouvrir = ouvrir
    }

    func suivre(_ route: RappelsRoute?) {
        guard let route else { return }
        switch route {
        case .reglagesNotifications:
            // Une adresse refusée ne dit rien : l'avertissement reste, et le geste peut se refaire.
            guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
            UIApplication.shared.open(url, options: [:]) { _ in }
        case .diagnostic:
            ouvrir(route)
        }
    }
}

// MARK: La feuille de l'heure

/// Le choix d'une heure de rappel : une roue des heures et des minutes, au format 12 ou 24 heures du téléphone, avec
/// « Annuler » et « Valider » du système. L'heure est tenue comme un instant de la journée de référence en temps
/// universel (2001-01-01 UTC), pour qu'aucun fuseau ni changement d'heure ne la décale (comme la présentation).
struct RappelsChoixHeure: View {
    private let libelle: Text
    private let valider: @MainActor (Int, Int) -> Void
    private let annuler: @MainActor () -> Void
    @State private var instant: Date

    init(heure: Int, minute: Int, libelle: Text,
         valider: @escaping @MainActor (Int, Int) -> Void,
         annuler: @escaping @MainActor () -> Void) {
        self.libelle = libelle
        self.valider = valider
        self.annuler = annuler
        _instant = State(initialValue: Date(timeIntervalSinceReferenceDate: TimeInterval(heure * 3600 + minute * 60)))
    }

    var body: some View {
        NavigationStack {
            DatePicker(selection: $instant, displayedComponents: .hourAndMinute) {
                libelle
            }
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.timeZone, .gmt)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        annuler()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        choisir()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func choisir() {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        let parties = calendrier.dateComponents([.hour, .minute], from: instant)
        valider(parties.hour ?? 0, parties.minute ?? 0)
    }
}
