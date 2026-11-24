import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

// Les fenêtres de l'ajout de temps à un jour passé (AjoutTemps.kt, DureeSeance.choisir et saisir d'Android) :
// le jour (une alerte), « Combien de temps ? » (une liste d'actions), la durée réglable (une alerte avec un
// champ), puis le message bref « Ajouté : 30 min. ». L'écran qui les ouvre (l'accueil, le calendrier) garde le
// modèle dans un état optionnel et pose ce modificateur :
//
//     .ajoutTemps($ajout) { issue in … }
//
// où `ajout = AjoutTempsModele(magasin:horloge:systeme:date:montrer:)` au toucher d'un jour (nil, et rien ne
// s'ouvre, pour un jour à venir). Les fenêtres suivent `modele.etape` ; quand elle devient nil, `fin` reçoit
// l'issue, puis le modèle est rendu (remis à nil), après le message bref s'il y en a un.

extension View {
    /// Les fenêtres de l'ajout de temps au jour de `modele`, tant qu'il n'est pas nil.
    /// - Parameters:
    ///   - modele: le modèle ouvert ; remis à nil quand tout est fermé et le message bref montré.
    ///   - fin: l'issue (`.montrer` : l'accueil bascule la durée du jour ; `.ajoute` : l'écran se rafraîchit).
    public func ajoutTemps(_ modele: Binding<AjoutTempsModele?>,
                           fin: @escaping @MainActor (AjoutTempsIssue) -> Void = { _ in }) -> some View {
        modifier(AjoutTempsFenetres(modele: modele, fin: fin))
    }
}

/// Les trois fenêtres et le message bref. Chaque bouton appelle une action du modèle, qui change l'étape : la
/// présentation suit l'étape et ne décide rien elle-même.
public struct AjoutTempsFenetres: ViewModifier {
    @Binding private var modele: AjoutTempsModele?
    private let fin: @MainActor (AjoutTempsIssue) -> Void
    @Environment(\.traducteur) private var traducteur
    /// L'étape dont SwiftUI vient de fermer la fenêtre (un bouton touché) alors que le modèle y est encore, le
    /// temps d'une écriture : sa fenêtre ne se rouvre pas. Oubliée dès que l'étape change.
    @State private var fermeeParSwiftUI: AjoutTempsEtape? = nil

    public init(modele: Binding<AjoutTempsModele?>, fin: @escaping @MainActor (AjoutTempsIssue) -> Void) {
        _modele = modele
        self.fin = fin
    }

    public func body(content: Content) -> some View {
        content
            .alert(titreJour, isPresented: ouverte(.jour)) {
                actionsJour
            } message: {
                messageJour
            }
            .confirmationDialog(titreDurees, isPresented: ouverte(.durees), titleVisibility: .visible) {
                actionsDurees
            }
            .alert(titreSaisie, isPresented: ouverte(.saisie)) {
                actionsSaisie
            }
            .overlay(alignment: .bottom) {
                confirmation
            }
            .onChange(of: modele?.etape) { _, etape in
                fermees(etape)
            }
    }

    // MARK: L'étape

    /// La fenêtre de cette étape est ouverte. Chaque fenêtre ne se ferme que par ses boutons, qui disent tous au
    /// modèle quoi faire ; la fermeture que signale SwiftUI après un bouton ne change donc pas le modèle. Elle est
    /// seulement retenue : une durée choisie s'écrit (await) avant que l'étape change, et une liaison restée vraie
    /// ferait rouvrir la fenêtre par SwiftUI pendant ce temps.
    private func ouverte(_ etape: AjoutTempsEtape) -> Binding<Bool> {
        let modele = self.modele
        let fermee = $fermeeParSwiftUI
        return Binding(get: { @MainActor in modele?.etape == etape && fermee.wrappedValue != etape },
                       set: { @MainActor montree in
                           if !montree {
                               fermee.wrappedValue = etape
                           }
                       })
    }

    /// Toutes les fenêtres sont fermées : l'écran qui les a ouvertes reçoit l'issue ; le modèle est rendu tout
    /// de suite, ou après le message bref.
    private func fermees(_ etape: AjoutTempsEtape?) {
        fermeeParSwiftUI = nil
        guard etape == nil, let ouvert = modele, let issue = ouvert.issue else { return }
        fin(issue)
        if ouvert.confirmation == nil {
            modele = nil
        }
    }

    // MARK: Le jour

    private var titreJour: Text {
        guard let modele else { return Text(verbatim: "") }
        return Text(verbatim: JournalDates.complete(modele.date, langue: traducteur.langue))
    }

    @ViewBuilder
    private var messageJour: some View {
        if let modele {
            Text(modele.message, traducteur: traducteur)
        }
    }

    @ViewBuilder
    private var actionsJour: some View {
        if let modele {
            Button {
                modele.ajouterTemps()
            } label: {
                Text(modele.boutonAjouter, traducteur: traducteur)
            }
            if modele.montrerDuree {
                Button {
                    modele.montrer()
                } label: {
                    Text(modele.boutonMontrer, traducteur: traducteur)
                }
            }
            Button(role: .cancel) {
                modele.retour()
            } label: {
                Text(modele.boutonRetour, traducteur: traducteur)
            }
        }
    }

    // MARK: La durée

    private var titreDurees: Text {
        guard let modele else { return Text(verbatim: "") }
        return Text(modele.titreDurees, traducteur: traducteur)
    }

    @ViewBuilder
    private var actionsDurees: some View {
        if let modele {
            ForEach(modele.durees) { duree in
                Button {
                    Task { @MainActor in
                        // Une écriture refusée arrive les fenêtres déjà fermées et le message posé (le
                        // changement reste dans le Magasin) : rien de plus à montrer.
                        try? await modele.choisir(duree)
                    }
                } label: {
                    Text(duree.libelle, traducteur: traducteur)
                }
            }
            // Android ferme la liste d'un toucher à côté ou du bouton retour ; ici, « Retour ».
            Button(role: .cancel) {
                modele.retour()
            } label: {
                Text(modele.boutonRetour, traducteur: traducteur)
            }
        }
    }

    // MARK: La durée réglable

    private var titreSaisie: Text {
        guard let modele else { return Text(verbatim: "") }
        return Text(modele.titreSaisie, traducteur: traducteur)
    }

    @ViewBuilder
    private var actionsSaisie: some View {
        if let modele {
            let indication = traducteur.texte(modele.indicationSaisie)
            TextField(text: liaisonSaisie(modele), prompt: Text(verbatim: indication)) {
                Text(verbatim: indication)
            }
            .keyboardType(.numberPad)
            Button {
                Task { @MainActor in
                    try? await modele.validerSaisie()
                }
            } label: {
                Text(modele.boutonValider, traducteur: traducteur)
            }
            Button(role: .cancel) {
                modele.retour()
            } label: {
                Text(modele.boutonRetour, traducteur: traducteur)
            }
        }
    }

    private func liaisonSaisie(_ modele: AjoutTempsModele) -> Binding<String> {
        Binding(get: { @MainActor in modele.saisie },
                set: { @MainActor texte in modele.saisie = texte })
    }

    // MARK: Le message bref

    /// « Ajouté : 30 min. » en bas de l'écran, environ 2 secondes (Toast.LENGTH_SHORT), annoncé par VoiceOver ;
    /// puis le modèle est rendu.
    @ViewBuilder
    private var confirmation: some View {
        if let ouvert = modele, let message = ouvert.confirmation {
            let texte = traducteur.texte(message)
            Text(verbatim: texte)
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(white: 0.2).opacity(0.92), in: Capsule())
                .padding(.horizontal, 24)
                .padding(.bottom, 64)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
                .task(id: message) {
                    AccessibilityNotification.Announcement(texte).post()
                    do {
                        try await Task.sleep(for: .milliseconds(2_000))
                    } catch {
                        // L'écran est parti : le message s'efface avec lui.
                    }
                    ouvert.confirmationVue()
                    if modele === ouvert {
                        modele = nil
                    }
                }
        }
    }
}
