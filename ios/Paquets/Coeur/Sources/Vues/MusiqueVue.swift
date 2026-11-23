import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Coeur
import Ecrans

/// L'écran Musique (MusicActivity.kt, activity_music.xml, item_track.xml) : le bandeau, la carte des réglages
/// (la musique, le volume, la lecture aléatoire, l'ambiance), la bibliothèque, et le bouton fixe « Ajouter un
/// morceau du téléphone ». La vue ne décide rien : elle lit `MusiqueModele` (cible Ecrans) et lui passe les
/// gestes. Elle ne pousse aucun autre écran ; ses dialogues (ambiances, « Renommer ») et le sélecteur de
/// fichiers du système sont liés à l'état du modèle.
///
/// Les actions du modèle partent par `Task.immediate` : leur début (l'écriture des réglages, la fermeture d'un
/// dialogue) se fait tout de suite, dans le geste même, comme sur Android ; un interrupteur ou la barre du
/// volume ne reviennent donc jamais un instant en arrière.
public struct MusiqueVue: View {
    @Bindable private var modele: MusiqueModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phaseScene
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    /// Le sélecteur de fichiers du système (ActivityResultContracts.OpenDocument, « audio/* »).
    @State private var importeurOuvert = false
    /// Le bandeau s'efface quand on fait défiler la page, et revient en haut (BandeauDefilant.kt).
    @State private var bandeauCache = false
    @State private var hauteurBandeau: CGFloat = 0

    public init(modele: MusiqueModele) {
        _modele = Bindable(modele)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !bandeauCache {
                MusiqueBandeauVue(titre: Text(modele.titre, traducteur: traducteur),
                                  resume: Text(modele.resume, traducteur: traducteur))
                    .onGeometryChange(for: CGFloat.self) { geometrie in
                        geometrie.size.height
                    } action: { hauteur in
                        hauteurBandeau = hauteur
                    }
                    .transition(.opacity)
            }
            defilement
            boutonAjout
        }
        .background(Teinte(.paper))
        .overlay(alignment: .bottom) {
            messageEphemere
        }
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importeurOuvert, allowedContentTypes: [.audio]) { resultat in
            fichierChoisi(resultat)
        }
        .sheet(isPresented: choixAmbianceOuvert) {
            MusiqueChoixAmbianceVue(modele: modele)
        }
        .alert(titreRenommage, isPresented: renommageOuvert, presenting: modele.renommage) { dialogue in
            actionsRenommage(dialogue)
        }
        .onDisappear {
            Task.immediate { @MainActor [modele] in
                await modele.quitter()
            }
        }
        .onChange(of: phaseScene) { _, phase in
            // onPause d'Android : l'app passe au second plan, l'écoute d'essai et l'aperçu d'ambiance s'arrêtent.
            if phase != .active {
                Task.immediate { @MainActor [modele] in
                    await modele.quitter()
                }
            }
        }
    }

    // MARK: Ce qui défile

    /// Tout défile sous le bandeau, la liste comprise (04/11 : sur petit écran, la liste tombait à zéro).
    private var defilement: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                carteReglages
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                Text("music_library")
                    .font(Font.body.bold())
                    .foregroundStyle(Teinte(.ink))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)
                Text("music_library_hint")
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.horizontal, 24)
                bibliotheque
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onScrollGeometryChange(for: MusiqueDefilement.self) { geometrie in
            MusiqueDefilement(geometrie)
        } action: { _, etat in
            suivreDefilement(etat)
        }
    }

    private var bibliotheque: some View {
        LazyVStack(spacing: 0) {
            ForEach(modele.lignes) { ligne in
                MusiqueLigneVue(ligne: ligne, modele: modele)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: La carte des réglages

    private var carteReglages: some View {
        Carte {
            Toggle(isOn: liaisonMusique) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("music_enable")
                        .titreCarte()
                    Text("music_enable_hint")
                        .indicationCarte()
                }
            }
            .tint(Teinte(.brand))
            MusiqueSeparateur()
            Text("music_volume")
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
                .accessibilityHidden(true)
            Slider(value: liaisonVolume, in: 0...100, step: 1)
                .tint(Teinte(.brand))
                .padding(.top, 4)
                .accessibilityLabel(Text("music_volume"))
            MusiqueSeparateur()
            Toggle(isOn: liaisonAleatoire) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("music_shuffle")
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.ink))
                    Text("music_shuffle_hint")
                        .indicationCarte()
                }
            }
            .tint(Teinte(.brand))
            MusiqueSeparateur()
            Button {
                modele.ouvrirChoixAmbiance()
            } label: {
                LigneSection(titre: Text("ambiance_title"),
                             etat: Text(modele.ambianceTitre, traducteur: traducteur))
            }
            .buttonStyle(.plain)
        }
    }

    /// L'interrupteur de la musique : la séance en cours suit (le modèle le fait).
    private var liaisonMusique: Binding<Bool> {
        Bindable(modele).musiqueLiee
    }

    /// L'interrupteur de la lecture aléatoire.
    private var liaisonAleatoire: Binding<Bool> {
        Bindable(modele).aleatoireLie
    }

    /// La barre du volume, de 0 à 100 par pas de 1 : chaque pas est enregistré (onProgressChanged).
    private var liaisonVolume: Binding<Double> {
        Bindable(modele).volumeLie
    }

    // MARK: Le bouton fixe

    /// « Ajouter un morceau du téléphone », hors du défilement : 16 de marge tout autour, 12 de remplissage.
    private var boutonAjout: some View {
        Button {
            importeurOuvert = true
        } label: {
            Text("music_add")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
        }
        .buttonStyle(.principal)
        .padding(16)
        .accessibilityIdentifier("barre-bas")
    }

    /// Le fichier choisi : copié et ajouté par le modèle ; une erreur du sélecteur se dit comme une copie
    /// refusée ; l'annulation ne rappelle pas ici.
    private func fichierChoisi(_ resultat: Result<URL, any Error>) {
        switch resultat {
        case .success(let url):
            Task.immediate { @MainActor [modele] in
                await modele.ajouter(url)
            }
        case .failure:
            modele.ajoutImpossible()
        }
    }

    // MARK: Les dialogues

    /// Le dialogue des ambiances : fermé par « Retour », par le geste qui baisse la feuille, ou par un choix.
    private var choixAmbianceOuvert: Binding<Bool> {
        Bindable(modele).choixAmbianceLie
    }

    /// Le dialogue « Renommer ». Chaque bouton ferme le dialogue par le modèle lui-même (le début de son action
    /// part tout de suite) : la fermeture que SwiftUI écrit ici n'a rien à faire, et surtout pas « Retour »,
    /// qui effacerait le dialogue avant que « Enregistrer » ne le lise.
    private var renommageOuvert: Binding<Bool> {
        Bindable(modele).renommageLie
    }

    private var titreRenommage: Text {
        if let dialogue = modele.renommage {
            return Text(dialogue.titre, traducteur: traducteur)
        }
        return Text(verbatim: "")
    }

    @ViewBuilder
    private func actionsRenommage(_ dialogue: MusiqueRenommage) -> some View {
        let indication = dialogue.indication.musiqueTexte(traducteur)
        TextField(text: $modele.texteRenommage, prompt: Text(verbatim: indication)) {
            Text(verbatim: indication)
        }
        Button {
            Task.immediate { @MainActor [modele] in
                await modele.enregistrerRenommage()
            }
        } label: {
            Text(dialogue.enregistrer, traducteur: traducteur)
        }
        if let neutre = dialogue.libelleNeutre {
            Button(role: MusiqueVue.role(dialogue.neutre)) {
                Task.immediate { @MainActor [modele] in
                    await modele.actionNeutreRenommage()
                }
            } label: {
                Text(neutre, traducteur: traducteur)
            }
        }
        Button(role: .cancel) {
            modele.annulerRenommage()
        } label: {
            Text(dialogue.retour, traducteur: traducteur)
        }
    }

    /// « Retirer » efface un fichier ajouté : un bouton destructif ; « Titre d'origine » est un bouton simple.
    private static func role(_ neutre: MusiqueRenommage.Neutre?) -> ButtonRole? {
        switch neutre {
        case .retirer?: .destructive
        case .titreOrigine?, nil: nil
        }
    }

    // MARK: Le message

    /// Le Toast d'Android (durée longue, environ 3,5 s) : un morceau illisible, un fichier non ajouté. VoiceOver
    /// le lit, comme TalkBack lit un Toast.
    @ViewBuilder
    private var messageEphemere: some View {
        if let message = modele.message {
            let texte = traducteur.texte(message)
            Text(verbatim: texte)
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(white: 0.2).opacity(0.92), in: Capsule())
                .padding(.horizontal, 24)
                .padding(.bottom, 96)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
                .task(id: message) { @MainActor [modele] in
                    UIAccessibility.post(notification: .announcement, argument: texte)
                    do {
                        try await Task.sleep(for: .milliseconds(3_500))
                        modele.effacerMessage()
                    } catch {
                        // Un autre message a pris la place, ou l'écran est parti : rien à effacer ici.
                    }
                }
        }
    }

    // MARK: Le bandeau qui s'efface

    /// BandeauDefilant.kt : effacé après un vrai défilement (plus que sa hauteur et une marge de 48), et
    /// seulement si la page le dépasse nettement ; de retour tout en haut de la page.
    private func suivreDefilement(_ defilement: MusiqueDefilement) {
        let seuil = hauteurBandeau + 48
        if !bandeauCache && defilement.decalage > seuil && defilement.etendue > seuil {
            montrerBandeau(false)
        } else if bandeauCache && defilement.decalage <= 0 {
            montrerBandeau(true)
        }
    }

    private func montrerBandeau(_ visible: Bool) {
        if reduireAnimations {
            bandeauCache = !visible
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                bandeauCache = !visible
            }
        }
    }
}

// MARK: Le titre d'un morceau

extension MusicLibrary.Titre {
    /// Le titre à montrer : un nom donné (ou celui d'un fichier) tel quel, un titre livré dans la langue de l'app.
    func musiqueTexte(_ traducteur: Traducteur) -> String {
        switch self {
        case .nom(let nom): nom
        case .libelle(let libelle): traducteur.texte(libelle)
        }
    }
}

// MARK: Les pièces de l'écran

/// Où en est le défilement de la page : de combien elle est descendue, et de combien elle peut défiler en tout.
struct MusiqueDefilement: Equatable {
    let decalage: CGFloat
    let etendue: CGFloat

    init(_ geometrie: ScrollGeometry) {
        decalage = geometrie.contentOffset.y + geometrie.contentInsets.top
        etendue = geometrie.contentSize.height + geometrie.contentInsets.top + geometrie.contentInsets.bottom
            - geometrie.containerSize.height
    }
}

/// Le bandeau (bg_hero.xml) : un dégradé à 225° de l'accent (`brand`) vers le vert sombre (`brandDark`, dès
/// 55 %), coins bas de 20, et un filet de lumière en bas. Le titre en blanc, le résumé en menthe, comme Android.
struct MusiqueBandeauVue: View {
    let titre: Text
    let resume: Text
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            titre
                .font(Font.title2.bold())
                .foregroundStyle(Color.white)
                .accessibilityAddTraits(.isHeader)
            resume
                .font(.subheadline)
                .foregroundStyle(Teinte(.mint))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background {
            fond
        }
    }

    private var fond: some View {
        let marque = palette.couleur(.brand, schema: schema)
        let sombre = palette.couleur(.brandDark, schema: schema)
        // L'angle 225 d'Android va du coin haut droit au coin bas gauche ; le dessin ne se retourne pas en hébreu.
        let degrade = LinearGradient(stops: [
            Gradient.Stop(color: marque, location: 0),
            Gradient.Stop(color: sombre, location: 0.55),
            Gradient.Stop(color: sombre, location: 1),
        ], startPoint: UnitPoint(x: 1, y: 0), endPoint: UnitPoint(x: 0, y: 1))
        let filet = LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25), Color.white.opacity(0)],
                                   startPoint: UnitPoint(x: 0, y: 0.5), endPoint: UnitPoint(x: 1, y: 0.5))
        return UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            .fill(degrade)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(filet)
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
            .ignoresSafeArea(edges: .top)
    }
}

/// Le séparateur d'une carte (style Divider) : 1 de haut, filet `line`, 14 au-dessus et au-dessous.
struct MusiqueSeparateur: View {
    var body: some View {
        Rectangle()
            .fill(Teinte(.line))
            .frame(height: 1)
            .padding(.vertical, 14)
            .accessibilityHidden(true)
    }
}

/// Une ligne de la bibliothèque (item_track.xml) : le bouton radio, le titre et l'origine, le crayon, la
/// lecture. Toucher la ligne la choisit, un appui long ouvre « Renommer ». VoiceOver la lit d'un trait, avec
/// « sélectionné » pour le morceau des séances et deux actions nommées.
struct MusiqueLigneVue: View {
    let ligne: MusiqueLigne
    let modele: MusiqueModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        let titre = ligne.titre.musiqueTexte(traducteur)
        let origine = traducteur.texte(ligne.origine)
        HStack(spacing: 0) {
            Image(systemName: ligne.choisie ? "largecircle.fill.circle" : "circle")
                .font(.title2)
                .foregroundStyle(Teinte(ligne.choisie ? .brand : .muted))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: titre)
                    .font(.callout)
                    .foregroundStyle(Teinte(.ink))
                    .lignesAuPlus(1)
                    .truncationMode(.tail)
                Text(verbatim: origine)
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
            }
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                renommer()
            } label: {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(Teinte(.muted))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                ecouter()
            } label: {
                Image(systemName: ligne.enApercu ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(Teinte(.muted))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            choisir()
        }
        .onLongPressGesture {
            renommer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: titre + ", " + origine))
        .accessibilityAddTraits(ligne.choisie ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction {
            choisir()
        }
        .accessibilityAction {
            renommer()
        } label: {
            Text("music_rename")
        }
        .accessibilityAction {
            ecouter()
        } label: {
            Text("music_preview")
        }
    }

    private func choisir() {
        let id = ligne.id
        Task.immediate { @MainActor [modele] in
            await modele.choisir(id)
        }
    }

    private func renommer() {
        modele.ouvrirRenommage(ligne.id)
    }

    private func ecouter() {
        let id = ligne.id
        Task.immediate { @MainActor [modele] in
            await modele.basculerApercu(id)
        }
    }
}

/// Le dialogue des ambiances (setSingleChoiceItems) : les six choix, l'ambiance enregistrée cochée ; un choix
/// ferme le dialogue (le modèle le fait) ; « Retour » le ferme sans rien changer.
struct MusiqueChoixAmbianceVue: View {
    let modele: MusiqueModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        NavigationStack {
            List {
                ForEach(modele.optionsAmbiance) { option in
                    Button {
                        let choix = option.ambiance
                        Task.immediate { @MainActor [modele] in
                            await modele.choisirAmbiance(choix)
                        }
                    } label: {
                        HStack {
                            Text(option.titre, traducteur: traducteur)
                                .foregroundStyle(Teinte(.ink))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "checkmark")
                                .font(Font.body.weight(.semibold))
                                .foregroundStyle(Teinte(.brand))
                                .opacity(option.choisie ? 1 : 0)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(option.choisie ? [.isSelected] : [])
                }
            }
            .navigationTitle(Text("ambiance_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        modele.fermerChoixAmbiance()
                    } label: {
                        Text("action_back")
                    }
                }
            }
        }
        .hauteursDeFeuille([.medium, .large])
    }
}
