import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'onglet Textes (le panneau `texts_scroll` de MainActivity.kt et activity_main.xml) : le titre, la recherche,
/// « Reprendre » le dernier texte lu, les favoris et la ligne des marque-pages, la carte des textes, puis « Autour
/// de la hitbodedout » (la musique et son interrupteur, les rappels). Tout se lit dans `TextesModele`.
///
/// Chaque ligne ouvre un autre écran de l'app : la vue confie sa `TextesRoute` à `ouvrir`, que le câblage de
/// l'onglet relie au modèle de l'écran (et présente `.marquesPages` en feuille, comme RepriseFavoris.listeSignets).
/// Sa pile de navigation est celle de son onglet : la vue n'en ouvre pas une seconde.
///
/// Pas d'image ni d'animation dans ce panneau (le seul retour visuel d'Android est la surbrillance au toucher) :
/// rien à adapter pour « Réduire les animations ».
public struct TextesVue: View {
    let modele: TextesModele
    private let ouvrir: @MainActor (TextesRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase
    /// La largeur de l'écran, pour les marges qui la suivent (values-w360dp, values-w600dp…).
    @State private var largeur: CGFloat = 0

    /// - Parameters:
    ///   - modele: `TextesModele(magasin:contenus:horloge:langue:signalMusique:relecture:)`.
    ///   - ouvrir: l'écran d'une ligne (recherche, Tikoun, siddour, lecteur, marque-pages, musique, rappels…).
    public init(modele: TextesModele, ouvrir: @escaping @MainActor (TextesRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titre
                recherche
                reprise
                premiereCarte
                intertitre
                secondeCarte
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TextesMesures.gouttiere(largeur))
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { nouvelle in
            largeur = nouvelle
        }
        // Le titre nomme l'écran (le retour des écrans ouverts, VoiceOver) ; le panneau le montre déjà, en grand,
        // et Android n'a pas de barre au-dessus : elle est cachée ici, les écrans poussés gardent la leur.
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .toolbar(.hidden, for: .navigationBar)
        // onResume → refresh : à chaque apparition de l'onglet, au retour d'un écran ouvert…
        .task { await modele.actualiser() }
        // … et au retour de l'app au premier plan (le jour du Tikoun, la portion de Tehilim ont pu changer).
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active {
                Task { await modele.actualiser() }
            }
        }
    }

    // MARK: L'en-tête

    /// « Bibliothèque » : 24 sp gras, encre, edge_inner sur les côtés, 16 au-dessus.
    private var titre: some View {
        Text(modele.titre, traducteur: traducteur)
            .font(Font.title2.bold())
            .foregroundStyle(Teinte(.ink))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TextesMesures.bordInterieur(largeur))
            .padding(.top, 16)
            .accessibilityAddTraits(.isHeader)
    }

    /// Le bouton à contour de la recherche (Widget.Material3.Button.OutlinedButton) : toute la largeur, le texte
    /// au début (gravity start|center_vertical).
    private var recherche: some View {
        Button {
            ouvrir(modele.routeRecherche)
        } label: {
            Text(modele.recherche, traducteur: traducteur)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.secondaire)
        .padding(.horizontal, TextesMesures.bordInterieur(largeur))
        .padding(.top, 12)
    }

    // MARK: Reprendre, favoris, marque-pages

    /// Le conteneur reprise_favoris : rien tant que le modèle n'a pas de ligne.
    private var reprise: some View {
        ForEach(modele.reprise) { ligne in
            TextesLigneReprise(ligne: ligne, police: modele.police) {
                ouvrir(ligne.route)
            }
        }
    }

    // MARK: Les cartes

    /// La carte des textes (style Card) : 16 sur les côtés, 14 au-dessus.
    private var premiereCarte: some View {
        Carte {
            ForEach(modele.entrees) { entree in
                TextesLigneEntree(entree: entree, modele: modele, ouvrir: ouvrir)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    /// « Autour de la hitbodedout » : 12 sp, capitales, espacement 0,08 em, discret, 16 au-dessus.
    private var intertitre: some View {
        Text(modele.titreAutour, traducteur: traducteur)
            .font(.caption)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Teinte(.muted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TextesMesures.bordInterieur(largeur))
            .padding(.top, 16)
            .accessibilityAddTraits(.isHeader)
    }

    /// La musique et les rappels : la carte n'a que 8 au-dessus, sous l'intertitre.
    private var secondeCarte: some View {
        Carte {
            ForEach(modele.autour) { entree in
                TextesLigneEntree(entree: entree, modele: modele, ouvrir: ouvrir)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Les marges

/// Les marges qui suivent la largeur de l'écran (res/values*/dimens.xml).
enum TextesMesures {
    /// @dimen/wide_gutter, la marge de tout le panneau : 0 sous 600 de large, 32 dès 600, 104 dès 840, 304 dès 1200.
    static func gouttiere(_ largeur: CGFloat) -> CGFloat {
        if largeur >= 1200 { return 304 }
        if largeur >= 840 { return 104 }
        if largeur >= 600 { return 32 }
        return 0
    }

    /// @dimen/edge_inner, celle du titre, de la recherche et de l'intertitre, qui s'ajoute à la gouttière : 16 sous
    /// 360 de large, 24 de 360 à 599, 16 dès 600.
    static func bordInterieur(_ largeur: CGFloat) -> CGFloat {
        if largeur >= 600 { return 16 }
        if largeur >= 360 { return 24 }
        return 16
    }
}

// MARK: - Une ligne de la reprise

/// Une ligne de « Reprendre », des favoris ou des marque-pages (RepriseFavoris.ligne) : l'en-tête éventuel (12 sp,
/// capitales, couleur de marque), puis le titre suivi de « › », en 19 sp, dans la police hébraïque choisie. Seul
/// le titre se touche ; l'en-tête est un en-tête pour VoiceOver.
private struct TextesLigneReprise: View {
    let ligne: TextesRepriseLigne
    let police: PoliceHebraique.Police
    let action: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.layoutDirection) private var sens

    init(ligne: TextesRepriseLigne, police: PoliceHebraique.Police, action: @escaping @MainActor () -> Void) {
        self.ligne = ligne
        self.police = police
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entete = ligne.entete {
                Text(entete, traducteur: traducteur)
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(Teinte(.brand))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
            Button(action: action) {
                HStack(spacing: 8) {
                    // textDirection RTL, mais textAlignment VIEW_START : le texte se lit de droite à gauche, et
                    // ses lignes s'alignent au début de l'app (la fin d'un paragraphe de droite à gauche, en
                    // français ou en anglais). Le U+200F (marque droite à gauche) en tête fixe la direction du
                    // paragraphe comme textDirection RTL, même pour un titre latin (« Marque-pages · 3 », « Tehilim ») :
                    // « › » tombe alors à gauche, comme sur Android, quoi que SwiftUI déduise de layoutDirection.
                    Text(verbatim: "\u{200F}" + nom + "  ›")
                        .policeHebraique(police, taille: 19)
                        .foregroundStyle(Teinte(.ink))
                        .multilineTextAlignment(sens == .rightToLeft ? .leading : .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let icone = ligne.icone {
                        // ic_marque_priere, 18 × 18, teinte de marque, au bout de la ligne (côté fin), 8 d'écart.
                        Image(systemName: BibliothequeIcone.symbole(icone))
                            .font(.system(size: 18))
                            .foregroundStyle(Teinte(.brand))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // « › » ne se lit pas.
            .accessibilityLabel(Text(verbatim: nom))
        }
        .padding(.horizontal, 16)
        .padding(.top, ligne.entete == nil ? 4 : 14)
    }

    /// Le titre tel qu'Android l'écrit : le titre hébreu, ou le libellé ; « Marque-pages · 3 » pour la ligne des
    /// marque-pages (`nombre`).
    private var nom: String {
        let titre: String
        switch ligne.titre {
        case .hebreu(let hebreu):
            titre = hebreu
        case .libelle(let libelle):
            titre = traducteur.texte(libelle)
        }
        guard let nombre = ligne.nombre else { return titre }
        return titre + " · " + String(nombre)
    }
}

// MARK: - Une ligne des cartes

/// Une ligne de section (SectionRow) : toute la ligne ouvre son écran ; la ligne qui porte un interrupteur (la
/// musique) garde l'interrupteur à part.
private struct TextesLigneEntree: View {
    let entree: TextesEntree
    let modele: TextesModele
    let ouvrir: @MainActor (TextesRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    init(entree: TextesEntree, modele: TextesModele, ouvrir: @escaping @MainActor (TextesRoute) -> Void) {
        self.entree = entree
        self.modele = modele
        self.ouvrir = ouvrir
    }

    var body: some View {
        if entree.interrupteur != nil {
            TextesLigneInterrupteur(entree: entree, modele: modele, ouvrir: ouvrir)
        } else {
            Button {
                ouvrir(entree.route)
            } label: {
                LigneSection(titre: Text(entree.titre, traducteur: traducteur),
                             etat: entree.etat.map { Text($0, traducteur: traducteur) })
            }
            .buttonStyle(.plain)
        }
    }
}

/// La ligne de la musique (music_button) : le titre et son état, l'interrupteur (music_switch_main), le chevron.
/// Le texte et le chevron ouvrent l'écran de la musique ; l'interrupteur est un contrôle à part, que VoiceOver
/// nomme par le titre de la ligne (Android ne lui donne pas de nom).
private struct TextesLigneInterrupteur: View {
    let entree: TextesEntree
    let modele: TextesModele
    let ouvrir: @MainActor (TextesRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    init(entree: TextesEntree, modele: TextesModele, ouvrir: @escaping @MainActor (TextesRoute) -> Void) {
        self.entree = entree
        self.modele = modele
        self.ouvrir = ouvrir
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                ouvrir(entree.route)
            } label: {
                textes
            }
            .buttonStyle(.plain)
            Toggle(isOn: interrupteur) {
                Text(entree.titre, traducteur: traducteur)
            }
            .labelsHidden()
            .tint(Teinte(.brand))
            Button {
                ouvrir(entree.route)
            } label: {
                Image(systemName: "chevron.forward")
                    .font(Font.subheadline.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Le texte ouvre déjà l'écran : le chevron ne se lit pas (importantForAccessibility="no").
            .accessibilityHidden(true)
        }
        .frame(minHeight: 56)
    }

    /// Le titre (15 sp, encre) et l'état (13 sp, discret, deux lignes au plus), comme LigneSection.
    private var textes: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entree.titre, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
            if let etat = entree.etat {
                Text(etat, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Le réglage « music_enabled » : la séance en cours est prévenue par le modèle. Une écriture qui échoue ne
    /// dit rien, comme Android ; le modèle garde la position qu'il a lue.
    private var interrupteur: Binding<Bool> {
        let modele = self.modele
        return Binding(get: { @MainActor in modele.musiqueActive },
                       set: { @MainActor actif in
                           Task {
                               do {
                                   try await modele.basculerMusique(actif)
                               } catch {
                                   // Android n'affiche rien.
                               }
                           }
                       })
    }
}
