import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le bravo présenté par l'écran de séance ou par l'accueil : il construit son modèle une fois (la présentation est
/// recalculée, le modèle ne doit pas l'être), puis montre `CelebrationVue`. À présenter en plein écran
/// (`fullScreenCover`) : il se retire de lui-même (`dismiss`).
public struct CelebrationPage: View {
    private let demande: CelebrationDemande
    private let fabrique: @MainActor (CelebrationDemande) -> CelebrationModele
    private let note: @MainActor (JourCivil) -> NoteModele
    @State private var modele: CelebrationModele? = nil

    /// - Parameters:
    ///   - demande: ce qui ouvre le bravo (`SeanceRoute.celebration`, ou `CelebrationDemande.prendre` à l'accueil).
    ///   - fabrique: `CelebrationModele(demande:magasin:contenus:horloge:langue:debug:)`.
    ///   - note: `NoteModele(date:magasin:)`, pour la note que propose « Continuer ».
    public init(demande: CelebrationDemande,
                fabrique: @escaping @MainActor (CelebrationDemande) -> CelebrationModele,
                note: @escaping @MainActor (JourCivil) -> NoteModele) {
        self.demande = demande
        self.fabrique = fabrique
        self.note = note
    }

    public var body: some View {
        Group {
            if let modele {
                CelebrationVue(modele: modele, note: note)
            } else {
                Rectangle()
                    .fill(Teinte(.paper))
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            if modele == nil {
                modele = fabrique(demande)
            }
        }
    }
}

/// Le bravo de fin de séance (CelebrationActivity.kt, activity_celebration.xml) : sur la scène menthe, le hassid
/// danse et des notes montent ; « Bravo ! » et les minutes ; « Continuer », puis la note de la séance ; « Partager
/// ma hitbodedout ». Après un abandon, « ’Hazak ! », le personnage qui marche, immobile, et un mot de 'hizouk.
/// Rien ne danse sous « Réduire les animations ». Tout se lit dans `CelebrationModele`.
public struct CelebrationVue: View {
    private let modele: CelebrationModele
    private let note: @MainActor (JourCivil) -> NoteModele

    @Environment(\.dismiss) private var fermer
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    @ScaledMetric(relativeTo: .title) private var tailleTitre: CGFloat = 30

    /// La place de l'écran, et celle de tout ce qui est sous la scène : la scène prend le reste.
    @State private var taille: CGSize = .zero
    @State private var hauteurBas: CGFloat = 0
    /// La note ouverte par « Continuer » ; le bravo se ferme quand elle se ferme, enregistrée ou non.
    @State private var noteOuverte: SeanceNoteOuverte? = nil
    /// Le début de la danse.
    @State private var debutDanse = Date()

    /// - Parameters:
    ///   - modele: `CelebrationModele(demande:magasin:contenus:horloge:langue:debug:)`.
    ///   - note: `NoteModele(date:magasin:)`.
    public init(modele: CelebrationModele, note: @escaping @MainActor (JourCivil) -> NoteModele) {
        self.modele = modele
        self.note = note
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                scene
                    .frame(height: hauteurScene)
                bas
                    .onGeometryChange(for: CGFloat.self) { geometrie in
                        geometrie.size.height
                    } action: { hauteur in
                        hauteurBas = hauteur
                    }
            }
            .padding(.horizontal, SeanceMesures.marge(largeur: taille.width))
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Teinte(.paper))
        .onGeometryChange(for: CGSize.self) { geometrie in
            geometrie.size
        } action: { nouvelle in
            taille = nouvelle
        }
        .task {
            await modele.charger()
        }
        .sheet(item: $noteOuverte, onDismiss: { fermer() }) { ouverte in
            NotePage(date: ouverte.date, fabrique: note)
        }
    }

    // MARK: La scène

    /// La scène prend la hauteur qui reste (layout_weight, 200 au moins) ; sous 720 points de haut, 42 % de
    /// l'écran, pour que « Bravo » et « Continuer » se voient sans défiler.
    private var hauteurScene: CGFloat {
        let hauteur = taille.height
        guard hauteur > 0 else { return 200 }
        if hauteur < CGFloat(CelebrationModele.petitEcran) {
            return hauteur * CGFloat(CelebrationModele.partScenePetitEcran)
        }
        return max(200, hauteur - 48 - hauteurBas)
    }

    private var dansant: Bool {
        modele.danse && !reduireAnimations
    }

    private var scene: some View {
        danseur
            .padding(.top, 16)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                if dansant {
                    CelebrationNotesMontantes()
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var danseur: some View {
        if dansant {
            TimelineView(.animation) { contexte in
                CelebrationDanseur(poseA: modele.poseA, poseB: modele.poseB,
                                   pas: CelebrationModele.pas(SeanceTemps.millis(contexte.date)
                                                              - SeanceTemps.millis(debutDanse)))
            }
        } else {
            CelebrationDanseur(poseA: modele.poseA, poseB: nil, pas: nil)
        }
    }

    // MARK: Sous la scène

    private var bas: some View {
        VStack(spacing: 0) {
            Text(modele.titre, traducteur: traducteur)
                .font(Font.system(size: tailleTitre, weight: .bold))
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            if let sousTitre = modele.sousTitre {
                Text(sousTitre, traducteur: traducteur)
                    .font(.callout)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            if let carte = modele.carte {
                SeanceCarteChizukVue(carte: carte, compacte: true)
                    .padding(.top, 16)
            }
            Button {
                continuer()
            } label: {
                Text(modele.libelleContinuer, traducteur: traducteur)
                    .font(Font.callout.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 24)
            partager
        }
    }

    @ViewBuilder
    private var partager: some View {
        if modele.partageVisible {
            ShareLink(item: modele.textePartage { traducteur.texte($0) },
                      subject: Text(modele.titrePartage, traducteur: traducteur)) {
                Text(modele.libellePartager, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SeanceBoutonTexte(couleur: .brand))
            .padding(.top, 4)
        }
    }

    /// « Continuer » : l'écran se ferme, ou la note de la séance s'ouvre par-dessus.
    private func continuer() {
        switch modele.continuer() {
        case .fermer:
            fermer()
        case .note(let date):
            noteOuverte = SeanceNoteOuverte(date: date)
        }
    }
}

// MARK: - La danse

/// Le danseur (celebration_dancer) : la pose A, et par-dessus la pose B qui paraît à chaque réception. Il saute,
/// plie les genoux et se balance depuis le bas au centre ; sans pas, il reste immobile, la pose A seule.
struct CelebrationDanseur: View {
    let poseA: String
    let poseB: String?
    let pas: DanseMesure.Pas?

    init(poseA: String, poseB: String?, pas: DanseMesure.Pas?) {
        self.poseA = poseA
        self.poseB = poseB
        self.pas = pas
    }

    private var hauteur: CGFloat { CGFloat(pas?.hauteur ?? 0) }
    private var flexion: CGFloat { CGFloat(pas?.flexion ?? 0) }
    private var balance: Double { Double(pas?.balance ?? 0) }
    private var visibiliteB: Double { Double(pas?.poseB ?? 0) }

    var body: some View {
        ZStack {
            Illustration(decorative: poseA)
                .opacity(1 - visibiliteB)
            if let poseB {
                Illustration(decorative: poseB)
                    .opacity(visibiliteB)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(x: 1 + 0.04 * flexion, y: 1 - 0.05 * flexion, anchor: .bottom)
        .rotationEffect(.degrees(6 * balance), anchor: .bottom)
        .offset(y: -CGFloat(CelebrationModele.saut) * hauteur)
    }
}

/// Une note ou une étoile qui monte de la scène (lancerNote) : tirée au hasard, de 18 à 25 points, partie à 18 % ou
/// 72 % de la largeur (plus 0 à 10 %) et à 55 % de la hauteur ; en 1,7 s, ralentie, elle monte de 45 % de la
/// hauteur, dérive de 15 points au plus, tourne de 20° au plus et s'efface.
struct CelebrationNoteMontante: Identifiable {
    static let duree: TimeInterval = 1.7

    let id = UUID()
    let naissance: Date
    let signe: String
    let taille: CGFloat
    let cote: CGFloat
    let derive: CGFloat
    let rotation: Double

    /// `signe` : tiré dans `CelebrationModele.signes`.
    init(naissance: Date, signe: String) {
        self.naissance = naissance
        self.signe = signe
        taille = CGFloat(18 + Int.random(in: 0..<8))
        cote = (Bool.random() ? 0.18 : 0.72) + CGFloat.random(in: 0..<0.1)
        derive = (CGFloat.random(in: 0..<1) - 0.5) * 30
        rotation = (Double.random(in: 0..<1) - 0.5) * 40
    }

    /// L'avancée de 0 à 1, ralentie (DecelerateInterpolator) ; 1 : la note a fini.
    func avancee(a date: Date) -> CGFloat {
        let t = min(max(date.timeIntervalSince(naissance) / CelebrationNoteMontante.duree, 0), 1)
        return CGFloat(1 - (1 - t) * (1 - t))
    }
}

/// Les notes qui montent, une par temps et 180 ms, tant que la scène est montrée. VoiceOver les passe ; elles ne
/// prennent aucun toucher.
struct CelebrationNotesMontantes: View {
    @State private var notes: [CelebrationNoteMontante] = []

    init() {}

    var body: some View {
        GeometryReader { geometrie in
            TimelineView(.animation) { contexte in
                ZStack(alignment: .topLeading) {
                    ForEach(notes) { note in
                        CelebrationSigne(note: note, avancee: note.avancee(a: contexte.date), scene: geometrie.size)
                    }
                }
                .frame(width: geometrie.size.width, height: geometrie.size.height, alignment: .topLeading)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            await lancer()
        }
    }

    private func lancer() async {
        while !Task.isCancelled {
            let maintenant = Date()
            notes.removeAll { maintenant.timeIntervalSince($0.naissance) > CelebrationNoteMontante.duree }
            notes.append(CelebrationNoteMontante(naissance: maintenant,
                                                 signe: CelebrationModele.signes.randomElement() ?? ""))
            do {
                try await Task.sleep(for: .milliseconds(CelebrationModele.intervalleNotes))
            } catch {
                return
            }
        }
    }
}

/// Un signe à son avancée, dans la scène : `onPlate`, qui reste lisible sur la menthe de jour comme de nuit.
private struct CelebrationSigne: View {
    let note: CelebrationNoteMontante
    let avancee: CGFloat
    let scene: CGSize

    init(note: CelebrationNoteMontante, avancee: CGFloat, scene: CGSize) {
        self.note = note
        self.avancee = avancee
        self.scene = scene
    }

    var body: some View {
        Text(verbatim: note.signe)
            .font(.system(size: note.taille))
            .foregroundStyle(Teinte(.onPlate))
            .fixedSize()
            .rotationEffect(.degrees(note.rotation * Double(avancee)))
            .opacity(Double(1 - avancee))
            .position(x: scene.width * note.cote + note.derive * avancee,
                      y: scene.height * (0.55 - 0.45 * avancee))
    }
}
