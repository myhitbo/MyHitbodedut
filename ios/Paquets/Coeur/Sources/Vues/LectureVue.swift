import Accessibility
import Foundation
import SwiftUI
import Coeur
import Ecrans

// Le lecteur des textes (SiddurLectureActivity.kt, activity_siddur_lecture.xml) : le bandeau (marque-pages,
// favori, titre, étiquettes, horaire), la bande des signets, le texte en liste paresseuse, et le bouton de
// lecture (LectureBarreVue.swift). La vue dit au modèle ce qu'elle montre (`visibles`) et suit ce qu'il demande
// (`defilement`) ; tout le reste se décide dans LectureModele (cible Ecrans).
//
// Aucune image ici, seulement des icônes : on ne prie pas devant une image (Ora'h 'Haïm 90, 23).

/// Le lecteur d'un texte du siddour ou d'un livre.
public struct LectureVue: View {
    @Bindable private var modele: LectureModele
    private let ouvrir: @MainActor (LectureRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.accessibilityReduceMotion) private var sansAnimation
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var fermer

    /// La place de la liste, que la vue fait suivre aux demandes du modèle.
    @State private var position = ScrollPosition(idType: String.self)
    /// Les lignes vues en dernier, et si la liste ne peut plus descendre : ce que la vue rapporte au modèle.
    @State private var vus: [String] = []
    @State private var enBas = false
    @State private var largeur: CGFloat = 390

    /// `ouvrir` : un renvoi du jour (`.lecture`), ouvert par la pile de navigation de l'app.
    public init(modele: LectureModele, ouvrir: @escaping @MainActor (LectureRoute) -> Void) {
        _modele = Bindable(modele)
        self.ouvrir = ouvrir
    }

    private var rendu: LectureRendu {
        LectureRendu(sombre: modele.sombre, palette: palette, schema: schema)
    }

    public var body: some View {
        VStack(spacing: 0) {
            LectureBandeau(modele: modele, bord: SiddourMesures.bord(largeur: largeur))
            if !modele.signets.isEmpty {
                LectureBandeSignets(modele: modele, rendu: rendu)
            }
            texte
        }
        .background(Teinte(.paper))
        .overlay(alignment: .bottom) {
            messages
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { nouvelle in
            largeur = nouvelle
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $modele.feuilleMarques) {
            LectureFeuilleMarquesTexte(modele: modele)
        }
        // onCreate : une seule fois (le modèle ignore les appels suivants) ; onRestart à chaque retour.
        .task { await modele.charger() }
        .onAppear { modele.revenir() }
        .onDisappear { quitter() }
        .onChange(of: phase) { _, nouvelle in
            switch nouvelle {
            case .background: quitter()
            case .active: modele.revenir()
            default: break
            }
        }
        // Le texte n'existe pas (ou plus, dans ce nusah) : Android ferme l'écran.
        .onChange(of: modele.etat) { _, etat in
            if etat == .introuvable { fermer() }
        }
    }

    /// onPause : la place est gardée.
    private func quitter() {
        let modele = self.modele
        SiddourTache.lancer { try await modele.quitter() }
    }

    // MARK: Le texte

    private var texte: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(modele.lignes) { ligne in
                    LectureLigneVue(ligne: ligne, modele: modele, rendu: rendu, ouvrir: ouvrir)
                }
            }
            .scrollTargetLayout()
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollPosition($position, anchor: .top)
        .defilementAutomatique(modele.defilementAuto, position: $position)
        .background(rendu.fond)
        .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.01) { ids in
            vus = ids
            modele.visibles(ids, enBas: enBas)
        }
        .onScrollGeometryChange(for: Bool.self, of: { geometrie in
            geometrie.contentOffset.y + geometrie.containerSize.height
                >= geometrie.contentSize.height + geometrie.contentInsets.bottom - 1
        }, action: { _, nouveau in
            enBas = nouveau
            modele.visibles(vus, enBas: nouveau)
        })
        .onScrollGeometryChange(for: Double.self, of: { Double($0.contentOffset.y) }, action: { avant, apres in
            modele.defilementVertical(apres - avant)
        })
        .onScrollPhaseChange { _, nouvelle in
            if nouvelle == .tracking || nouvelle == .interacting {
                modele.debutGlisse()
            }
        }
        .onChange(of: modele.defilement) { _, demande in
            guard let demande else { return }
            if demande.anime && !sansAnimation {
                withAnimation(.easeInOut(duration: 0.3)) {
                    position.scrollTo(id: demande.ligne, anchor: .top)
                }
            } else {
                position.scrollTo(id: demande.ligne, anchor: .top)
            }
        }
        // Un toucher rend la pastille ; deux touchers font revenir le bouton masqué (onSingleTapConfirmed,
        // onDoubleTap de ReglagesLecture).
        .onTapGesture(count: 2) {
            retrouver()
        }
        .onTapGesture(count: 1) {
            modele.toucherTexte()
        }
        .accessibilityAction(named: Text(Libelle("lecture_reglages"), traducteur: traducteur)) {
            retrouver()
        }
        // Le bouton de lecture sous le texte, jamais sur une ligne (boutonsDeLecture).
        .boutonsDeLecture(fond: rendu.fond, visibles: (modele.pastilleVisible && !modele.pastilleEffacee)
                          || modele.barreVisible || modele.defilementAuto.commandeVisible) {
            LectureBouton(modele: modele, largeur: largeur)
        }
    }

    private func retrouver() {
        let modele = self.modele
        SiddourTache.lancer { try await modele.retrouver() }
    }

    // MARK: Le bas de l'écran

    /// Le message bref et la barre qui suit le masquage, en calque au-dessus du texte (le bouton de lecture est sous
    /// le texte, `boutonsDeLecture`).
    private var messages: some View {
        VStack(spacing: 12) {
            if let message = modele.message {
                LectureMessage(message: message, modele: modele)
            }
            if modele.annonceMasque {
                LectureAnnonceMasque(modele: modele)
            }
        }
        .padding(.bottom, 16)
    }
}

// MARK: Le bandeau

/// Le bandeau du lecteur : les marque-pages et le favori, le titre, les étiquettes et l'horaire du jour. Il ne
/// change pas la nuit.
private struct LectureBandeau: View {
    let modele: LectureModele
    let bord: CGFloat

    @Environment(\.traducteur) private var traducteur
    @Environment(\.layoutDirection) private var sens

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Les deux boutons en fin de rangée (gravity="end"), dans le sens de la langue de l'app.
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                boutonRond(libelle: Text(Libelle("marques_titre"), traducteur: traducteur)) {
                    modele.feuilleMarques = true
                } contenu: {
                    SiddourIcone(modele.iconeMarques, taille: 24)
                        .foregroundStyle(Color.white)
                }
                boutonRond(libelle: Text(modele.descriptionFavori, traducteur: traducteur)) {
                    let modele = self.modele
                    SiddourTache.lancer { try await modele.basculerFavori() }
                } contenu: {
                    Text(verbatim: modele.symboleFavori)
                        .font(.title2)
                        .foregroundStyle(Color.white)
                }
            }
            Text(verbatim: modele.titre)
                .policeHebraique(modele.police, taille: 28, relativeA: .title)
                .bold()
                .foregroundStyle(Color.white)
                .accessibilityAddTraits(.isHeader)
                .siddourHebreuAuDebut()
            if !modele.etiquettes.isEmpty {
                etiquettes
            }
            if let horaire = modele.horaire {
                // En blanc, comme le titre : la menthe d'Android, sur le vert clair du dégradé, n'avait pas le
                // contraste que demande l'audit d'accessibilité.
                Text(verbatim: "\u{25F7} " + traducteur.texte(horaire))
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
                    // gravity="right" : à droite, en français comme en hébreu.
                    .frame(maxWidth: .infinity, alignment: sens == .rightToLeft ? .leading : .trailing)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, bord)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background { SiddourBandeauFond() }
    }

    /// Les étiquettes en pastilles, de droite à gauche ; VoiceOver lit leur phrase, pas chaque pastille.
    private var etiquettes: some View {
        // À la suite, et à la ligne quand la place manque (le texte agrandi ne se coupe plus).
        HalakhaFlux(espacement: 6, interligne: 6) {
            ForEach(Array(modele.etiquettes.enumerated()), id: \.offset) { _, etiquette in
                Text(verbatim: etiquette)
                    .font(.footnote)
                    .foregroundStyle(Color.white)
                    .lignesAuPlus(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .frame(minHeight: 28)
                    .background(Color.white.opacity(SiddourMesures.alpha(0x26)), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(SiddourMesures.alpha(0x55)), lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: modele.etiquettesDescription))
    }

    /// Un bouton rond de 48 (drawable/bg_rond_bandeau.xml) : blanc à 12 %, cerclé de blanc à 22 %.
    private func boutonRond<Contenu: View>(libelle: Text, action: @escaping @MainActor () -> Void,
                                           @ViewBuilder contenu: () -> Contenu) -> some View {
        Button(action: action) {
            contenu()
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(SiddourMesures.alpha(0x1F)), in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(SiddourMesures.alpha(0x38)), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(libelle)
    }
}

// MARK: La bande des signets

/// Les titres des sections, de droite à gauche ; le signet de la section lue est marqué et reste au milieu.
private struct LectureBandeSignets: View {
    let modele: LectureModele
    let rendu: LectureRendu

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var sansAnimation
    @State private var position = ScrollPosition(idType: Int.self)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(modele.signets) { signet in
                        bouton(signet)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollPosition($position, anchor: .center)
            // La hauteur de la bande, pas la moitié de l'écran : un défilement horizontal s'étire sinon dans la
            // colonne (vu sur les captures, ios-captures.yml).
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.layoutDirection, .rightToLeft)
            .background(rendu.fond)
            .onChange(of: modele.signetActif, initial: true) { _, actif in
                guard let actif else { return }
                if sansAnimation {
                    position.scrollTo(id: actif, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        position.scrollTo(id: actif, anchor: .center)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(Libelle("siddur_signets"), traducteur: traducteur))
            Rectangle()
                .fill(rendu.discret.opacity(SiddourMesures.alpha(0x40)))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private func bouton(_ signet: LectureSignet) -> some View {
        let actif = signet.id == modele.signetActif
        return Button {
            modele.allerAuSignet(signet.id)
        } label: {
            Text(verbatim: signet.texte)
                .policeHebraique(modele.police, taille: 13, relativeA: .footnote)
                // Le signet lu à l'encre du texte (la couleur des titres, sur sa pastille teintée, n'avait pas le
                // contraste demandé) ; la pastille le distingue.
                .foregroundStyle(actif ? rendu.texte : rendu.discret)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minHeight: 48)
                .background {
                    if actif {
                        Capsule().fill(rendu.teinte(0x26))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }
}

// MARK: Les messages

/// Le message bref (Toast) : « Marque-page posé », « … retiré » ; il s'efface seul après deux secondes.
private struct LectureMessage: View {
    let message: Libelle
    let modele: LectureModele

    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Text(message, traducteur: traducteur)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 24)
            .allowsHitTesting(false)
            .task(id: message) {
                AccessibilityNotification.Announcement(traducteur.texte(message)).post()
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled { modele.effacerMessage() }
            }
    }
}

/// La barre du bas qui suit le masquage (Snackbar LENGTH_LONG) : comment retrouver le bouton, et « Annuler ».
private struct LectureAnnonceMasque: View {
    let modele: LectureModele

    @Environment(\.traducteur) private var traducteur

    var body: some View {
        HStack(spacing: 12) {
            Text(Libelle("lecture_masque_info"), traducteur: traducteur)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                let modele = self.modele
                SiddourTache.lancer { try await modele.retrouver() }
            } label: {
                Text(Libelle("lecture_annuler_masque"), traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .task {
            AccessibilityNotification.Announcement(traducteur.texte(Libelle("lecture_masque_info"))).post()
            try? await Task.sleep(for: .seconds(2.75))
            if !Task.isCancelled { modele.finAnnonceMasque() }
        }
    }
}

// MARK: La feuille des marque-pages du texte

/// Les marque-pages de ce texte (listeMarques) : un toucher y va ; aucun, comment en poser un.
private struct LectureFeuilleMarquesTexte: View {
    let modele: LectureModele

    @Environment(\.traducteur) private var traducteur

    var body: some View {
        let marques = modele.marquesDuTexte
        NavigationStack {
            List {
                if marques.isEmpty {
                    Text(Libelle("marques_aucun"), traducteur: traducteur)
                        .foregroundStyle(Teinte(.muted))
                } else {
                    ForEach(Array(marques.enumerated()), id: \.offset) { _, marque in
                        Button {
                            modele.allerALaMarque(marque)
                        } label: {
                            Text(verbatim: "\u{1F516}  " + marque.apercu + "\u{2026}")
                                .policeHebraique(modele.police, taille: 17)
                                .foregroundStyle(Teinte(.ink))
                                .lignesAuPlus(2)
                                .siddourHebreuAuDebut()
                        }
                    }
                }
            }
            .navigationTitle(Text(Libelle("marques_titre"), traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        modele.feuilleMarques = false
                    }
                }
            }
        }
        .hauteursDeFeuille([.medium, .large])
    }
}
