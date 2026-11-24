import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Coeur
import Ecrans

// Les pièces de l'écran Réglages (SettingsActivity.kt, activity_settings.xml, item_permission.xml, themes.xml) :
// la ligne de réglage (SettingRow), son bouton de valeur (SettingValue), la ligne à interrupteur, le séparateur,
// les couleurs fixes de colors.xml, le document de l'export, et l'aiguillage qui suit les routes du modèle.
// Aucune décision ici : tout se lit dans ReglagesModele (cible Ecrans).

// MARK: Les textes

/// Le texte d'une clé du catalogue, par le traducteur de l'app (les clés d'Android et les chaînes neuves d'iOS).
func reglagesTexte(_ cle: String, _ traducteur: Traducteur) -> Text {
    Text(Libelle(cle), traducteur: traducteur)
}

/// Le texte d'une valeur du modèle : un libellé à traduire, ou un texte tel quel (« 06:00 », « עברית »).
func reglagesTexte(_ texte: ReglagesTexte, _ traducteur: Traducteur) -> Text {
    switch texte {
    case .libelle(let libelle):
        Text(libelle, traducteur: traducteur)
    case .brut(let brut):
        Text(verbatim: brut)
    }
}

// MARK: Les couleurs fixes

/// Une couleur de colors.xml hors de la palette, de jour et de nuit (values-night/colors.xml) : « warning »
/// et « danger » ne suivent pas l'accent choisi, sur Android non plus.
struct ReglagesTeinteFixe: ShapeStyle {
    let jour: Couleur
    let nuit: Couleur

    func resolve(in environment: EnvironmentValues) -> Color {
        Color(environment.colorScheme == .dark ? nuit : jour)
    }

    /// warning : #A8561F de jour, #E8A062 de nuit.
    static let avertissement = ReglagesTeinteFixe(jour: Couleur(rouge: 0xA8, vert: 0x56, bleu: 0x1F),
                                                  nuit: Couleur(rouge: 0xE8, vert: 0xA0, bleu: 0x62))
    /// danger : #B3261E de jour, #F2B8B5 de nuit.
    static let danger = ReglagesTeinteFixe(jour: Couleur(rouge: 0xB3, vert: 0x26, bleu: 0x1E),
                                           nuit: Couleur(rouge: 0xF2, vert: 0xB8, bleu: 0xB5))
}

/// La couleur que le modèle nomme comme colors.xml : « brand », « muted » ou « warning ».
func reglagesTeinte(_ nom: String) -> AnyShapeStyle {
    switch nom {
    case "warning": AnyShapeStyle(ReglagesTeinteFixe.avertissement)
    case "muted": AnyShapeStyle(Teinte(.muted))
    default: AnyShapeStyle(Teinte(.brand))
    }
}

// MARK: Le titre d'une carte

/// Le titre d'une carte (CardTitle) et son indication (CardHint, 2 dessous) ; VoiceOver lit le titre comme un
/// en-tête.
struct ReglagesTitreCarte: View {
    @Environment(\.traducteur) private var traducteur
    private let titre: String
    private let indication: String?

    init(_ titre: String, indication: String? = nil) {
        self.titre = titre
        self.indication = indication
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            reglagesTexte(titre, traducteur)
                .titreCarte()
                .accessibilityAddTraits(.isHeader)
            if let indication {
                reglagesTexte(indication, traducteur)
                    .indicationCarte()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Les lignes

/// L'intitulé d'une ligne (SettingLabel, 15 ink), avec son indication dessous (SettingLabelStacked + CardHint).
struct ReglagesIntitule: View {
    private let intitule: Text
    private let indication: Text?

    init(_ intitule: Text, indication: Text? = nil) {
        self.intitule = intitule
        self.indication = indication
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            intitule
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
            if let indication {
                indication
                    .indicationCarte()
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Une ligne de réglage (SettingRow) : l'intitulé qui prend la place, et à son bout ce qui le règle (un ou deux
/// boutons de valeur). 10 au-dessus, sauf la première ligne d'une carte. Aux tailles de texte d'accessibilité,
/// la ligne passe en colonne plutôt que d'écraser l'intitulé.
struct ReglagesLigne<Fin: View>: View {
    @Environment(\.dynamicTypeSize) private var tailleTexte
    private let intitule: Text
    private let indication: Text?
    private let margeHaute: Bool
    private let fin: Fin

    init(_ intitule: Text, indication: Text? = nil, margeHaute: Bool = true, @ViewBuilder fin: () -> Fin) {
        self.intitule = intitule
        self.indication = indication
        self.margeHaute = margeHaute
        self.fin = fin()
    }

    var body: some View {
        let disposition = tailleTexte.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        disposition {
            ReglagesIntitule(intitule, indication: indication)
            fin
                .layoutPriority(1)
        }
        .padding(.top, margeHaute ? 10 : 0)
    }
}

/// Le bouton de valeur (SettingValue, bouton contour) : la valeur réglée, sur deux lignes au plus, 88 de large
/// au moins et 45 % de l'écran au plus ; le toucher ouvre la fenêtre du réglage. VoiceOver lit l'intitulé de la
/// ligne puis la valeur.
struct ReglagesBoutonValeur: View {
    private let valeur: Text
    private let intitule: Text
    private let largeurMax: CGFloat?
    private let action: @MainActor () -> Void

    init(_ valeur: Text, intitule: Text, largeurMax: CGFloat?, action: @escaping @MainActor () -> Void) {
        self.valeur = valeur
        self.intitule = intitule
        self.largeurMax = largeurMax
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            valeur
                .lineLimit(2)
                // 88 de large au moins, les 22 de marge du bouton de chaque côté compris.
                .frame(minWidth: 44)
        }
        .buttonStyle(.secondaire)
        .frame(maxWidth: largeurMax)
        .accessibilityLabel(intitule)
        .accessibilityValue(valeur)
    }
}

/// Une ligne à interrupteur : l'intitulé (et son indication) et l'interrupteur à la couleur de l'accent. Le
/// Toggle porte l'intitulé de sa ligne pour VoiceOver (audit du 16/10).
struct ReglagesLigneInterrupteur: View {
    private let intitule: Text
    private let indication: Text?
    private let margeHaute: Bool
    private let actif: Binding<Bool>

    init(_ intitule: Text, indication: Text? = nil, margeHaute: Bool = true, actif: Binding<Bool>) {
        self.intitule = intitule
        self.indication = indication
        self.margeHaute = margeHaute
        self.actif = actif
    }

    var body: some View {
        Toggle(isOn: actif) {
            ReglagesIntitule(intitule, indication: indication)
        }
        .tint(Teinte(.brand))
        .padding(.top, margeHaute ? 10 : 0)
        .accessibilityLabel(intitule)
        .accessibilityHint(indication ?? Text(verbatim: ""))
    }
}

/// Le séparateur d'une carte (Divider) : un filet `line`, 14 au-dessus et au-dessous.
struct ReglagesSeparateur: View {
    var body: some View {
        Rectangle()
            .fill(Teinte(.line))
            .frame(height: 1)
            .padding(.vertical, 14)
            .accessibilityHidden(true)
    }
}

/// Le bouton texte (TextButton) : le texte seul, à la couleur de l'accent.
struct ReglagesBoutonTexte: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.subheadline.weight(.medium))
            .foregroundStyle(Teinte(.brand))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: Le document de l'export

/// Ce que « Exporter » remet au sélecteur de fichiers du système : le JSON de la sauvegarde, tel quel.
struct ReglagesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let donnees: Data

    init(donnees: Data) {
        self.donnees = donnees
    }

    init(configuration: ReadConfiguration) throws {
        guard let lues = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        donnees = lues
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: donnees)
    }
}

// MARK: L'aiguillage des routes

/// Suit les routes que rendent les actions du modèle : les Réglages d'iOS et le navigateur s'ouvrent ici, hors de
/// l'app (safeStart d'Android : un écran qui ne s'ouvre pas le dit par le message du modèle) ; les autres écrans de
/// l'app passent par `ouvrir`, que l'app branche. Une classe liée à l'acteur principal : les liaisons des
/// interrupteurs la gardent sans rien exiger de la fermeture `ouvrir`.
@MainActor
final class ReglagesAiguillage {
    private let modele: ReglagesModele
    private let ouvrir: @MainActor (ReglagesRoute) -> Void

    init(modele: ReglagesModele, ouvrir: @escaping @MainActor (ReglagesRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    /// La route rendue par une action, s'il y en a une.
    func suivre(_ route: ReglagesRoute?) {
        guard let route else { return }
        switch route {
        case .reglagesApp:
            ouvrirAdresse(UIApplication.openSettingsURLString)
        case .reglagesNotifications:
            ouvrirAdresse(UIApplication.openNotificationSettingsURLString)
        case .navigateur(let adresse):
            ouvrirAdresse(adresse)
        case .presentation, .apercuBarriere, .choixApplications, .dedicace, .aideConcentration, .recommencer:
            ouvrir(route)
        }
    }

    /// La liaison d'un interrupteur : sa position se lit dans le modèle (un refus, comme la barrière sans accès
    /// à Temps d'écran, le laisse revenir de lui-même) ; le geste part tout de suite (`Task.immediate`), et la
    /// route rendue est suivie. Une écriture refusée ne dit rien, comme Store sur Android.
    func liaison(_ interrupteur: ReglagesInterrupteur) -> Binding<Bool> {
        let modele = self.modele
        return Binding(get: { @MainActor in
            modele.estActif(interrupteur)
        }, set: { @MainActor [self] actif in
            Task.immediate { @MainActor in
                do {
                    let route = try await modele.basculer(interrupteur, actif)
                    self.suivre(route)
                } catch {
                    // La persistance a refusé d'écrire : le changement reste en mémoire (Magasin).
                }
            }
        })
    }

    private func ouvrirAdresse(_ texte: String) {
        let modele = self.modele
        guard let url = URL(string: texte) else {
            modele.routeImpossible()
            return
        }
        UIApplication.shared.open(url, options: [:]) { acceptee in
            if !acceptee {
                modele.routeImpossible()
            }
        }
    }
}
