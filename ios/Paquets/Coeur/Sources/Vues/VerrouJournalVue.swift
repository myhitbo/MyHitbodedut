import Foundation
import SwiftUI
import Coeur
import Ecrans

// Le verrou du journal à l'écran (VerrouJournal.kt, JournalActivity.verrouiller, NoteDialog.show) et la ligne de la
// minuterie système. La règle est dans Ecrans (VerrouJournal.swift, MinuterieSeance.swift, testés sous Linux) ; ici,
// la couverture posée tant que le code n'est pas donné, et les deux interrupteurs des réglages.

// MARK: - La couverture

/// Ce qui couvre le journal tant que le code n'est pas donné : le fond de la page et un cadenas, rien du texte. Sur
/// Android, le contenu de l'activité devient invisible pendant que la demande du système est à l'écran.
struct VerrouCouverture: View {
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        ZStack {
            Rectangle().fill(Teinte(.paper)).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
                Text(VerrouJournal.raison, traducteur: traducteur)
                    .font(.headline)
                    .foregroundStyle(Teinte(.ink))
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct CleJournalCouvert: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Le journal derrière est couvert (parti à l'arrière-plan, le code pas encore redonné) : une note ouverte par-dessus
    /// se couvre aussi.
    var journalCouvert: Bool {
        get { self[CleJournalCouvert.self] }
        set { self[CleJournalCouvert.self] = newValue }
    }
}

/// L'écran du journal fermé à clé (JournalActivity) : couvert jusqu'au code, refermé à l'arrière-plan, le code redemandé
/// au retour ; renoncer ferme l'écran.
private struct VerrouEcranJournal: ViewModifier {
    @State private var ecran: JournalVerrouille
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var fermer

    init(verrou: VerrouJournal) {
        _ecran = State(initialValue: JournalVerrouille(verrou: verrou))
    }

    func body(content: Content) -> some View {
        content
            .environment(\.journalCouvert, !ecran.ouvert)
            .overlay {
                if !ecran.ouvert { VerrouCouverture() }
            }
            .task { await ecran.apparaitre() }
            .onChange(of: phase) { _, nouvelle in
                switch nouvelle {
                case .background: ecran.arrierePlan()
                case .active: Task { await ecran.premierPlan() }
                default: break
                }
            }
            .onChange(of: ecran.refuse) { _, refuse in
                if refuse { fermer() }
            }
    }
}

/// La fenêtre de note ouverte hors du journal sur un jour déjà écrit (NoteDialog.show) : couverte jusqu'au code ;
/// renoncer la ferme comme « Plus tard ». Ouverte depuis le journal, elle se couvre avec lui.
private struct VerrouNote: ViewModifier {
    let modele: JournalNoteModele
    let fermer: @MainActor () -> Void
    @Environment(\.journalCouvert) private var journalCouvert

    func body(content: Content) -> some View {
        content
            .overlay {
                if modele.verrouillee || journalCouvert { VerrouCouverture() }
            }
            .task {
                if !(await modele.deverrouiller()) { fermer() }
            }
    }
}

extension View {
    /// Le journal ne se montre qu'après le code du téléphone, quand le verrou est actif (VerrouJournal.actif).
    public func verrouJournal(_ verrou: VerrouJournal?) -> some View {
        modifier(VerrouEcranJournalOptionnel(verrou: verrou))
    }

    /// La note déjà écrite attend le code (JournalNoteModele.verrouillee).
    public func verrouNote(_ modele: JournalNoteModele, fermer: @escaping @MainActor () -> Void) -> some View {
        modifier(VerrouNote(modele: modele, fermer: fermer))
    }
}

/// Sans verrou (un aperçu), l'écran se montre tel quel.
private struct VerrouEcranJournalOptionnel: ViewModifier {
    let verrou: VerrouJournal?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let verrou {
            content.modifier(VerrouEcranJournal(verrou: verrou))
        } else {
            content
        }
    }
}

// MARK: - Les interrupteurs des réglages

extension ReglagesModele {
    /// L'interrupteur du verrou du journal : il montre ce qui protège vraiment ; le poser passe par le modèle (le code
    /// pour le couper, le message sans code sur le téléphone).
    var verrouJournalAllume: Bool {
        get { verrouJournal?.actif ?? false }
        set {
            let actif = newValue
            Task { await self.poserVerrouJournal(actif) }
        }
    }

    /// L'interrupteur de la minuterie système : le réglage, et l'autorisation des alarmes.
    var minuterieAllumee: Bool {
        get { minuterie?.actif ?? false }
        set {
            let actif = newValue
            Task { await self.poserMinuterie(actif) }
        }
    }
}

/// Un interrupteur des réglages, comme ceux de la vue des réglages (SettingRow) : le libellé, son indication.
private struct ReglagesBascule: View {
    let cle: String
    let indication: String
    @Binding var actif: Bool
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Toggle(isOn: $actif) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Libelle(cle), traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                Text(Libelle(indication), traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
        }
        .tint(Teinte(.brand))
        .frame(minHeight: 52)
    }
}

/// « Verrouiller le journal » (activity_settings.xml, carte des données, sous l'export) ; rien dans un aperçu.
public struct ReglagesVerrouLigne: View {
    private let modele: ReglagesModele

    public init(modele: ReglagesModele) {
        self.modele = modele
    }

    public var body: some View {
        if modele.verrouJournal != nil {
            ReglagesBascule(cle: "journal_verrou", indication: "journal_verrou_hint",
                            actif: Bindable(modele).verrouJournalAllume)
        }
    }
}

/// « Minuterie système » (propre à iOS, sous « Masquer le décompte ») ; l'autorisation relue à l'ouverture et au retour
/// des Réglages d'iOS. Rien dans un aperçu.
public struct ReglagesMinuterieLigne: View {
    private let modele: ReglagesModele
    @Environment(\.scenePhase) private var phase

    public init(modele: ReglagesModele) {
        self.modele = modele
    }

    public var body: some View {
        if let minuterie = modele.minuterie {
            ReglagesBascule(cle: "reglages_minuterie_systeme", indication: "reglages_minuterie_systeme_indication",
                            actif: Bindable(modele).minuterieAllumee)
                .task { await minuterie.rafraichir() }
                .onChange(of: phase) { _, nouvelle in
                    if nouvelle == .active { Task { await minuterie.rafraichir() } }
                }
        }
    }
}
