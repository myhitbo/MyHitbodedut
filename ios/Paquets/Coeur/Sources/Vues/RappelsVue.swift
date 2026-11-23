import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// Les rappels de hitbodedout (RemindersActivity.kt, activity_reminders.xml, item_reminder.xml), ouverts depuis les
/// Livres : le bandeau (titre, résumé, le personnage qui montre), la carte de l'interrupteur, l'avertissement quand
/// les notifications manquent et le trophée tout proche ; puis les heures, chacune touchable pour la changer, et
/// « Ajouter une heure ». La vue ne décide rien : elle lit `RappelsModele` (testé sous Linux).
public struct RappelsVue: View {
    @Bindable var modele: RappelsModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var ouvrirLien

    public init(modele: RappelsModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                bandeau
                carte
                VStack(alignment: .leading, spacing: 0) {
                    Text(modele.heuresTitre, traducteur: traducteur)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Teinte(.ink))
                    Text(modele.heuresAide, traducteur: traducteur)
                        .font(.system(size: 13))
                        .foregroundStyle(Teinte(.muted))
                }
                .padding(.horizontal, 8)
                ForEach(modele.heures) { heure in
                    ligne(heure)
                }
                Button {
                    modele.ouvrirAjout()
                } label: {
                    Text(modele.ajouterLibelle, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
            }
            .padding(16)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .task { await modele.apparaitre() }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active { Task { await modele.apparaitre() } }
        }
        .onChange(of: modele.routes) { _, routes in
            guard let route = routes.first else { return }
            modele.routeOuverte()
            switch route {
            case .reglagesNotifications:
                if let adresse = URL(string: UIApplication.openNotificationSettingsURLString) { ouvrirLien(adresse) }
            }
        }
        .sheet(item: $modele.dialogue) { dialogue in
            let initiale = modele.heureInitiale(dialogue)
            RappelsChoixHeure(heure: initiale.heure, minute: initiale.minute,
                              libelle: Text(modele.ajouterLibelle, traducteur: traducteur)) { heure, minute in
                Task { try? await modele.valider(heure: heure, minute: minute) }
            } annuler: {
                modele.fermerDialogue()
            }
        }
    }

    /// Le bandeau : le titre en blanc, le résumé à la menthe, le personnage sur sa scène.
    private var bandeau: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(modele.titre, traducteur: traducteur)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(modele.resume, traducteur: traducteur)
                    .font(.system(size: 14))
                    .foregroundStyle(Teinte(.mint))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Illustration(decorative: modele.image)
                .frame(width: 70, height: 88)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Teinte(.stageSoft)))
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Teinte(.brandDark)))
    }

    private var carte: some View {
        Carte {
            Toggle(isOn: $modele.actifLie) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(modele.activerTitre, traducteur: traducteur)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Teinte(.ink))
                    Text(modele.activerAide, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            .tint(Teinte(.brand))
            if modele.permissionManquante {
                Button {
                    Task { await modele.demanderNotifications() }
                } label: {
                    Text(modele.permissionTexte, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(AccueilFixe(jour: 0xA8561F, nuit: 0xE8A062))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            Toggle(isOn: $modele.tropheeLie) {
                Text(modele.tropheeLibelle, traducteur: traducteur)
                    .foregroundStyle(Teinte(.ink))
            }
            .tint(Teinte(.brand))
            .frame(minHeight: 48)
            .padding(.top, 8)
        }
    }

    /// Une heure : touchée, elle se change ; « Retirer » l'ôte.
    private func ligne(_ heure: RappelsHeure) -> some View {
        HStack(spacing: 8) {
            Button {
                modele.ouvrirChangement(heure)
            } label: {
                Text(verbatim: RappelsVue.heureTexte(heure.heure, heure.minute, langue: traducteur.langue))
                    .font(.system(size: 20))
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                Task { try? await modele.retirer(heure) }
            } label: {
                Text(modele.retirerLibelle, traducteur: traducteur)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Teinte(.brand))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Teinte(.card)))
    }

    /// Store.formatHeure : « HH:mm » si le téléphone est réglé sur 24 heures, « h:mm » et le moment de la journée
    /// sinon, dans la langue de l'app.
    static func heureTexte(_ heure: Int, _ minute: Int, langue: String) -> String {
        switch Locale.autoupdatingCurrent.hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour:
            return String(format: "%02d:%02d", heure, minute)
        default:
            var calendrier = Calendar(identifier: .gregorian)
            calendrier.locale = Locale(identifier: Traducteur.identifiantLocale(langue))
            let douze = heure % 12 == 0 ? 12 : heure % 12
            let moment = heure < 12 ? calendrier.amSymbol : calendrier.pmSymbol
            return String(format: "%d:%02d", douze, minute) + " " + moment
        }
    }
}

extension RappelsModele {
    /// L'interrupteur : son écriture passe par `basculer`, qui demande les notifications au besoin.
    var actifLie: Bool {
        get { actif }
        set {
            let oui = newValue
            Task { try? await self.basculer(oui) }
        }
    }

    var tropheeLie: Bool {
        get { trophee }
        set {
            let oui = newValue
            Task { try? await self.basculerTrophee(oui) }
        }
    }
}

/// Le choix de l'heure (TimePickerDialog) : une roue des heures et des minutes, au format du téléphone, tenue en temps
/// universel pour qu'aucun fuseau ni changement d'heure ne la décale.
private struct RappelsChoixHeure: View {
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
