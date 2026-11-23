import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les écrans du Chemin (refonte d'Android du 13/11) : le journal (JournalActivity.kt), « Mon parcours »
// (ParcoursActivity.kt) et la note d'un jour (NoteDialog.kt), que le journal ouvre et que le bravo propose. Les
// vues lisent leurs modèles d'Ecrans, testés sous Linux ; elles ne calculent rien.

// MARK: - Le journal

/// Le journal : le bandeau (titre, résumé, le mois en barres), puis une carte par journée, la plus récente en tête ;
/// toucher une journée ouvre sa note. Sans journée, le hassid qui écrit et « Commencer ». Les notes se couvrent dès
/// que la scène n'est plus active (FLAG_SECURE d'Android).
public struct JournalVue: View {
    private let modele: JournalModele
    private let commencer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase

    /// `commencer` : le bouton de l'écran vide ouvre la séance (JournalRoute.seance).
    public init(modele: JournalModele, commencer: @escaping @MainActor () -> Void) {
        self.modele = modele
        self.commencer = commencer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                bandeau
                if modele.vide {
                    vide
                } else {
                    ForEach(modele.lignes) { ligne in
                        Button {
                            modele.ouvrirNote(ligne.date)
                        } label: {
                            JournalLigneVue(ligne: ligne)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if modele.capturesMasquees && phase != .active {
                Rectangle().fill(Teinte(.paper)).ignoresSafeArea()
            }
        }
        .sheet(isPresented: Bindable(modele).noteLiee) {
            if let note = modele.note {
                JournalNoteVue(modele: note, enregistrer: {
                    do {
                        try await modele.enregistrerNote()
                    } catch {
                        // La fenêtre reste ouverte ; le changement reste en mémoire (Magasin).
                    }
                }, fermer: {
                    modele.fermerNote()
                })
            }
        }
        .onChange(of: modele.route) { _, route in
            guard route != nil else { return }
            modele.route = nil
            commencer()
        }
        .onAppear { modele.traducteur = traducteur }
    }

    private var bandeau: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(modele.resume, traducteur: traducteur)
                .font(Font.subheadline.weight(.semibold))
                .foregroundStyle(Teinte(.onBrand))
            GraphiqueMois(graphique: modele.graphique, sombre: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte(.brand), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var vide: some View {
        VStack(spacing: 14) {
            Illustration(decorative: modele.imageVide, hauteur: 130)
                .frame(maxWidth: 180)
            Text(modele.texteVide, traducteur: traducteur)
                .font(.body)
                .foregroundStyle(Teinte(.muted))
                .multilineTextAlignment(.center)
            Button {
                modele.commencer()
            } label: {
                Text(modele.boutonVide, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}

extension JournalModele {
    /// La note ouverte ; la baisser d'un geste (quand elle le permet) la ferme sans rien enregistrer.
    var noteLiee: Bool {
        get { noteOuverte }
        set { if !newValue { fermerNote() } }
    }
}

/// Une journée du journal (item_journal) : la date, la durée, la note et le journal enrichi.
private struct JournalLigneVue: View {
    let ligne: JournalLigne
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: AccueilDate.texte(ligne.date, langue: traducteur.langue))
                    .font(Font.subheadline.weight(.semibold))
                    .foregroundStyle(Teinte(.ink))
                Spacer(minLength: 8)
                Text(ligne.duree, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(Teinte(ligne.noteSeule ? .muted : .brand))
            }
            if let note = ligne.note {
                Text(verbatim: note)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Le mois en barres (JournalPlus.Graphique) : une barre par jour, à l'échelle du plus long, aujourd'hui marqué d'un
/// point. `sombre` : sur le vert d'un bandeau, les barres sont claires.
public struct GraphiqueMois: View {
    private let graphique: JournalGraphique
    private let sombre: Bool
    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    public init(graphique: JournalGraphique, sombre: Bool) {
        self.graphique = graphique
        self.sombre = sombre
    }

    public var body: some View {
        Canvas { contexte, taille in
            dessiner(contexte, taille)
        }
        .frame(height: CGFloat(JournalGraphique.hauteur + JournalGraphique.ecartPoint + 2 * JournalGraphique.rayonPoint))
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel(Text(graphique.accessibilite(moisNomme: AccueilDate.texte(graphique.mois,
            langue: traducteur.langue, motif: "MMMM yyyy")), traducteur: traducteur))
    }

    private func dessiner(_ contexte: GraphicsContext, _ taille: CGSize) {
        let barres = graphique.barres
        guard !barres.isEmpty else { return }
        let pas = taille.width / CGFloat(barres.count)
        let largeur = CGFloat(JournalGraphique.largeurBarre(largeur: Double(taille.width), nombre: barres.count))
        let base = CGFloat(JournalGraphique.hauteur)
        let couleur = sombre ? Color.white : palette.couleur(.brand, schema: schema)
        for (rang, barre) in barres.enumerated() {
            let hauteur = CGFloat(JournalGraphique.hauteurBarre(barre))
            let x = CGFloat(rang) * pas + (pas - largeur) / 2
            let rect = CGRect(x: x, y: base - hauteur, width: largeur, height: hauteur)
            let opacite = barre.faite ? 1 : JournalGraphique.opaciteVide
            contexte.fill(Path(roundedRect: rect, cornerRadius: min(largeur / 2, 2)),
                          with: .color(couleur.opacity(opacite)))
            if barre.aujourdhui {
                let r = CGFloat(JournalGraphique.rayonPoint)
                let centre = CGPoint(x: x + largeur / 2, y: base + CGFloat(JournalGraphique.ecartPoint) + r)
                contexte.fill(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r)),
                              with: .color(couleur))
            }
        }
    }
}

// MARK: - La note d'un jour

/// La note d'un jour (NoteDialog.kt) : la note libre, l'humeur avant et après, une gratitude, une chose à
/// travailler ; « Enregistrer », et « Plus tard » ou « Ne pas enregistrer » quand elle a changé. Un toucher à côté
/// ne la ferme jamais ; le geste de retour non plus, dès qu'elle a changé.
public struct JournalNoteVue: View {
    private let modele: JournalNoteModele
    private let enregistrer: @MainActor () async -> Void
    private let fermer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    public init(modele: JournalNoteModele, enregistrer: @escaping @MainActor () async -> Void,
                fermer: @escaping @MainActor () -> Void) {
        self.modele = modele
        self.enregistrer = enregistrer
        self.fermer = fermer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Illustration(decorative: modele.image, hauteur: 56)
                        .frame(width: 48, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(modele.titre, traducteur: traducteur)
                            .font(.title3.bold())
                            .foregroundStyle(Teinte(.ink))
                        Text(verbatim: AccueilDate.texte(modele.date, langue: traducteur.langue))
                            .font(.footnote)
                            .foregroundStyle(Teinte(.muted))
                    }
                }
                TextField(text: Bindable(modele).noteSaisie, axis: .vertical) {
                    Text(modele.indicationNote, traducteur: traducteur)
                }
                .lineLimit(4...10)
                .textFieldStyle(.roundedBorder)
                humeurs(Text(modele.titreAvant, traducteur: traducteur), choisie: modele.avant) { modele.toucherAvant($0) }
                humeurs(Text(modele.titreApres, traducteur: traducteur), choisie: modele.apres) { modele.toucherApres($0) }
                TextField(text: Bindable(modele).gratitudeSaisie) {
                    Text(modele.indicationGratitude, traducteur: traducteur)
                }
                .textFieldStyle(.roundedBorder)
                TextField(text: Bindable(modele).travailSaisi) {
                    Text(modele.indicationTravail, traducteur: traducteur)
                }
                .textFieldStyle(.roundedBorder)
                Button {
                    Task { await enregistrer() }
                } label: {
                    Text(modele.boutonEnregistrer, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
                Button {
                    fermer()
                } label: {
                    Text(modele.boutonRenoncer, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
            .padding(24)
        }
        .background(Teinte(.paper))
        .interactiveDismissDisabled(!modele.fermableParGeste)
        // Le verrou du journal (NoteDialog.show) : une note déjà écrite, ouverte hors du journal, attend le code.
        .verrouNote(modele, fermer: fermer)
    }

    private func humeurs(_ titre: Text, choisie: Int, toucher: @escaping @MainActor (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            titre
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
            HStack(spacing: 8) {
                ForEach(JournalNoteModele.humeurs) { humeur in
                    Button {
                        toucher(humeur.rang)
                    } label: {
                        Text(verbatim: humeur.emoji)
                            .tailleSp(30, relativeA: .title)
                            .opacity(choisie == humeur.rang || choisie == 0 ? JournalNoteModele.opaciteChoisie
                                : JournalNoteModele.opaciteAutre)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(humeur.accessibilite, traducteur: traducteur))
                    .accessibilityAddTraits(choisie == humeur.rang ? .isSelected : [])
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

extension JournalNoteModele {
    /// Le texte de la note, coupé comme Android le coupe.
    var noteSaisie: String {
        get { note }
        set { modifierNote(newValue) }
    }

    var gratitudeSaisie: String {
        get { gratitude }
        set { modifierGratitude(newValue) }
    }

    var travailSaisi: String {
        get { travail }
        set { modifierTravail(newValue) }
    }
}

// MARK: - Mon parcours

/// « Mon parcours » : le bandeau (le hassid qui loue, le titre), quatre tuiles, la moyenne, le mois en barres, les
/// sujets les plus fréquents, l'humeur moyenne avant → après quand elle a été notée.
public struct ParcoursVue: View {
    private let modele: ParcoursModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.dynamicTypeSize) private var tailleTexte

    public init(modele: ParcoursModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Illustration(decorative: modele.imageBandeau, hauteur: 60)
                        .frame(width: 50, height: 60)
                        .padding(6)
                        .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text(modele.sousTitre, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.muted))
                }
                // Deux tuiles par rangée ; une aux tailles d'accessibilité.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: tailleTexte.isAccessibilitySize ? 1 : 2),
                          spacing: 12) {
                    ForEach(modele.tuiles) { tuile in
                        ParcoursTuileVue(tuile: tuile)
                    }
                }
                if let moyenne = modele.moyenne {
                    Text(moyenne, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.muted))
                }
                mois
                sujets
                if let humeur = modele.humeur {
                    Carte {
                        Text(modele.titreHumeur, traducteur: traducteur)
                            .titreCarte()
                        Text(verbatim: humeur.texte)
                            .tailleSp(36, relativeA: .largeTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        Text(verbatim: humeur.legende.map { traducteur.texte($0) }.joined(separator: " · "))
                            .indicationCarte()
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mois: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(modele.titreMois, traducteur: traducteur)
                .font(Font.subheadline.weight(.semibold))
                .foregroundStyle(Teinte(.onBrand))
            Text(modele.texteMois, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.onBrand))
            GraphiqueMois(graphique: modele.graphique, sombre: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte(.brand), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var sujets: some View {
        Carte {
            Text(modele.titreSujets, traducteur: traducteur)
                .titreCarte()
            let liste = modele.sujets
            if liste.isEmpty {
                Text(modele.sujetsVide, traducteur: traducteur)
                    .indicationCarte()
                    .padding(.top, 6)
            } else {
                ForEach(liste) { sujet in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(sujet.nom, traducteur: traducteur)
                                .font(.subheadline)
                                .foregroundStyle(Teinte(.ink))
                            Spacer(minLength: 8)
                            Text(sujet.fois, traducteur: traducteur)
                                .font(.footnote)
                                .foregroundStyle(Teinte(.muted))
                        }
                        GeometryReader { geo in
                            Capsule()
                                .fill(Teinte(.brand))
                                .frame(width: geo.size.width * CGFloat(sujet.partDessinee), height: 8)
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 10)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Une tuile : le chiffre en grand, à la couleur de son anneau, son unité, et ce qu'il compte.
private struct ParcoursTuileVue: View {
    let tuile: ParcoursTuile
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                valeur
                    .font(Font.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(teinte)
                    .uneLigne(retrecie: 0.6)
                if let unite = tuile.unite {
                    Text(unite, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            Text(tuile.libelle, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Teinte(.line), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var valeur: Text {
        switch tuile.valeur {
        case .nombre(let n): Text(verbatim: String(n))
        case .duree(let libelle): Text(libelle, traducteur: traducteur)
        }
    }

    private var teinte: AnyShapeStyle {
        switch tuile.teinte {
        case .marque: AnyShapeStyle(Teinte(.brand))
        case .anneauSerie: AnyShapeStyle(AccueilFixe(jour: 0xB8780F, nuit: 0xE8B45C))
        case .anneauSemaine: AnyShapeStyle(AccueilFixe(jour: 0x2E7DB3, nuit: 0x6FB7E8))
        }
    }
}
