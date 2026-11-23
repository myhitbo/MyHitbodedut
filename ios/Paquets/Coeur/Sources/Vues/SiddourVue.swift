import Foundation
import SwiftUI
import Coeur
import Ecrans

// La liste du siddour (SiddurActivity.kt, activity_siddur.xml) : le bandeau et son choix du nusah, puis la ligne
// des marque-pages, les suggestions de l'heure, Tehilim et le Tikoun HaKlali, et les textes par groupe. La vue ne
// décide rien : SiddourModele (cible Ecrans) dit quoi montrer et où mène chaque toucher (`LectureRoute`), que
// l'app ouvre par la fermeture `ouvrir`. Les illustrations sont celles de la liste : on ne prie pas ici.

/// La liste du siddour.
public struct SiddourVue: View {
    @Bindable private var modele: SiddourModele
    private let ouvrir: @MainActor (LectureRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase
    /// La place de l'écran : les marges d'Android changent avec elle (values-w600dp, values-h640dp…).
    @State private var taille = CGSize(width: 390, height: 800)

    /// `ouvrir` : un texte (`.lecture`), Tehilim, le Tikoun, la feuille des marque-pages (`.marquesPages`).
    public init(modele: SiddourModele, ouvrir: @escaping @MainActor (LectureRoute) -> Void) {
        _modele = Bindable(modele)
        self.ouvrir = ouvrir
    }

    public var body: some View {
        VStack(spacing: 0) {
            bandeau
            ScrollView {
                liste
                    .padding(.horizontal, SiddourMesures.gouttiere(largeur: taille.width))
                    .padding(.bottom, 24)
            }
        }
        .background(Teinte(.paper))
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { nouvelle in
            taille = nouvelle
        }
        // onResume d'Android : à chaque apparition, et au retour au premier plan.
        .task { await modele.actualiser() }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active {
                Task { await modele.actualiser() }
            }
        }
        .sheet(isPresented: $modele.choixNusahOuvert) {
            SiddourChoixNusah(modele: modele)
        }
    }

    // MARK: Le bandeau

    /// Dès 640 points de haut, le bandeau prend plus de place (values-h640dp).
    private var haut: Bool {
        taille.height >= 640
    }

    private var bandeau: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(modele.titre, traducteur: traducteur)
                    .font(haut ? Font.title2.bold() : Font.title3.bold())
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)
                pastilleNusah
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SiddourScene(image: modele.image, largeur: haut ? 64 : 50, hauteur: haut ? 78 : 60)
        }
        .padding(.horizontal, SiddourMesures.bord(largeur: taille.width))
        .padding(.top, haut ? 22 : 12)
        .padding(.bottom, haut ? 18 : 10)
        .background { SiddourBandeauFond() }
    }

    /// La pastille du nusah : son nom et un chevron vers le bas ; le toucher ouvre le choix.
    private var pastilleNusah: some View {
        Button {
            modele.choixNusahOuvert = true
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: modele.nusah)
                    .font(.subheadline)
                    .lignesAuPlus(1)
                Image(systemName: "chevron.down")
                    .font(Font.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.white)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(minHeight: 44)
            .background(Color.white.opacity(SiddourMesures.alpha(0x26)), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(SiddourMesures.alpha(0x59)), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: traducteur.texte(modele.descriptionNusah) + " : " + modele.nusah))
    }

    // MARK: La liste

    private var liste: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let signets = modele.signets {
                ligneSignets(signets)
            }
            ForEach(modele.suggestions) { suggestion in
                carteSuggestion(suggestion)
            }
            Text(modele.titreLivres, traducteur: traducteur)
                .font(Font.body.bold())
                .foregroundStyle(Teinte(.brand))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)
                .padding(.top, 24)
            rangeeLivres
            ForEach(modele.groupes) { groupe in
                groupeVue(groupe)
            }
            if let mentions = modele.mentions {
                Text(mentions, traducteur: traducteur)
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
        }
    }

    /// « סימניות · n › » et l'icône des prières : la feuille des marque-pages du siddour.
    private func ligneSignets(_ signets: SiddourSignets) -> some View {
        Button {
            ouvrir(signets.route)
        } label: {
            HStack(spacing: 8) {
                Text(verbatim: traducteur.texte(signets.titre) + " \u{00B7} " + String(signets.nombre) + "  \u{203A}")
                    .policeHebraique(modele.police, taille: 19)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SiddourIcone(signets.icone, taille: 18)
                    .foregroundStyle(Teinte(.brand))
            }
            .contentShape(Rectangle())
            .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    /// Une suggestion de l'heure : le personnage ou la scène, « Pour cette heure », le titre et sa traduction.
    private func carteSuggestion(_ suggestion: SiddourSuggestion) -> some View {
        Button {
            ouvrir(suggestion.route)
        } label: {
            HStack(spacing: 16) {
                SiddourScene(image: suggestion.image, largeur: 72, hauteur: 86)
                VStack(alignment: .leading, spacing: 2) {
                    Text(modele.libelleSuggestion, traducteur: traducteur)
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(0.72)
                        .foregroundStyle(Teinte(.brand))
                    Text(verbatim: suggestion.hebreu)
                        .policeHebraique(modele.police, taille: 26, relativeA: .title)
                        .foregroundStyle(Teinte(.ink))
                        .siddourHebreuAuDebut()
                    if let traduction = suggestion.traduction {
                        Text(verbatim: traduction)
                            .font(.subheadline)
                            .foregroundStyle(Teinte(.muted))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SiddourChevron()
            }
            .padding(.leading, 12)
            .padding(.top, 12)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
            .siddourCarte()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    /// Tehilim et le Tikoun HaKlali côte à côte, de même hauteur.
    private var rangeeLivres: some View {
        HStack(spacing: 8) {
            ForEach(modele.livres) { livre in
                tuileLivre(livre)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func tuileLivre(_ livre: SiddourLivre) -> some View {
        Button {
            ouvrir(livre.route)
        } label: {
            VStack(spacing: 0) {
                SiddourScene(image: livre.image, largeur: 56, hauteur: 66)
                Text(livre.hebreu, traducteur: traducteur)
                    .policeHebraique(modele.police, taille: 19)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Text(livre.traduction, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .siddourCarte()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Un groupe : son en-tête (l'hébreu, sa traduction à côté), puis la carte de ses textes.
    private func groupeVue(_ groupe: SiddourGroupe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                enTeteGroupe(groupe)
                if let traduction = groupe.traduction {
                    Text(verbatim: traduction)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            VStack(spacing: 0) {
                ForEach(Array(groupe.textes.enumerated()), id: \.element.id) { rang, texte in
                    if rang > 0 {
                        Rectangle()
                            .fill(Teinte(.line))
                            .frame(height: 1)
                    }
                    ligneTexte(texte)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .siddourCarte()
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func enTeteGroupe(_ groupe: SiddourGroupe) -> some View {
        if groupe.hebreuPolice {
            Text(verbatim: groupe.hebreu)
                .policeHebraique(modele.police, taille: 17)
                .bold()
                .foregroundStyle(Teinte(.brand))
        } else {
            Text(verbatim: groupe.hebreu)
                .font(Font.body.bold())
                .foregroundStyle(Teinte(.brand))
        }
    }

    /// Une ligne de section : le titre hébreu, sa traduction (et le nusah d'emprunt) dessous, le chevron.
    private func ligneTexte(_ texte: SiddourTexteLigne) -> some View {
        Button {
            ouvrir(texte.route)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: texte.hebreu)
                        .policeHebraique(modele.police, taille: 20)
                        .foregroundStyle(Teinte(.ink))
                        .siddourHebreuAuDebut()
                    if let detail = texte.detail {
                        Text(verbatim: detail)
                            .font(.footnote)
                            .foregroundStyle(Teinte(.muted))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SiddourChevron()
            }
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: texte.detail.map { texte.hebreu + ", " + $0 } ?? texte.hebreu))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: Le choix du nusah

/// Le dialogue du bandeau (AlertDialog à choix unique d'Android) : les trois nusah, le choisi coché.
private struct SiddourChoixNusah: View {
    let modele: SiddourModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        NavigationStack {
            List(modele.optionsNusah) { option in
                Button {
                    SiddourTache.lancer { try await modele.choisirNusah(option.valeur) }
                } label: {
                    HStack {
                        Text(option.nom, traducteur: traducteur)
                            .foregroundStyle(Teinte(.ink))
                        Spacer()
                        if option.choisi {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Teinte(.brand))
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(option.choisi ? .isSelected : [])
            }
            .navigationTitle(Text(modele.descriptionNusah, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        modele.choixNusahOuvert = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: Ce que le siddour et le lecteur partagent

/// Les mesures d'Android (dimens.xml et ses variantes de largeur) : des ressources, pas des décisions d'écran.
enum SiddourMesures {
    /// `edge` : la marge des côtés des bandeaux (16, puis 24 dès 360 de large, 48 dès 600, 120 dès 840, 320
    /// dès 1200).
    static func bord(largeur: CGFloat) -> CGFloat {
        if largeur >= 1200 { return 320 }
        if largeur >= 840 { return 120 }
        if largeur >= 600 { return 48 }
        if largeur >= 360 { return 24 }
        return 16
    }

    /// `wide_gutter` : la gouttière de la liste du siddour (0, puis 32 dès 600, 104 dès 840, 304 dès 1200).
    static func gouttiere(largeur: CGFloat) -> CGFloat {
        if largeur >= 1200 { return 304 }
        if largeur >= 840 { return 104 }
        if largeur >= 600 { return 32 }
        return 0
    }

    /// L'alpha d'une couleur d'Android (#AARRGGBB) : 0x26 → 0,15.
    static func alpha(_ octet: Int) -> Double {
        Double(octet) / 255
    }
}

/// Le fond des bandeaux (drawable/bg_hero.xml) : un dégradé à 225° de l'accent (en haut, côté illustration)
/// vers l'accent sombre (dès 55 %), les coins du bas arrondis de 20, et un filet de lumière d'un point en bas,
/// blanc à 25 % au milieu, effacé aux bouts, en retrait de 36. Le dessin d'Android ne se retourne pas en hébreu.
struct SiddourBandeauFond: View {
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let haut = palette.couleur(.brand, schema: schema)
        let bas = palette.couleur(.brandDark, schema: schema)
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            .fill(LinearGradient(stops: [
                Gradient.Stop(color: haut, location: 0),
                Gradient.Stop(color: bas, location: 0.55),
                Gradient.Stop(color: bas, location: 1),
            ], startPoint: UnitPoint(x: 1, y: 0), endPoint: UnitPoint(x: 0, y: 1)))
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25), Color.white.opacity(0)],
                               startPoint: UnitPoint(x: 0, y: 0.5), endPoint: UnitPoint(x: 1, y: 0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
            .accessibilityHidden(true)
    }
}

/// Le panneau clair d'un personnage (drawable/bg_stage.xml) : la menthe, coins de 20, 4 de marge ; l'image
/// garde ses proportions et VoiceOver la passe.
struct SiddourScene: View {
    let image: String
    let largeur: CGFloat
    let hauteur: CGFloat

    var body: some View {
        Illustration(decorative: image)
            .padding(4)
            .frame(width: largeur, height: hauteur)
            .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Le chevron des lignes (ic_chevron, autoMirrored) : 22 points, couleur de l'accent, retourné en hébreu.
struct SiddourChevron: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(Font.body.weight(.semibold))
            .foregroundStyle(Teinte(.brand))
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }
}

/// Une icône vectorielle d'Android (res/drawable/ic_*.xml) par son symbole du système le plus proche ; la teinte
/// vient de `foregroundStyle`. VoiceOver la passe : le bouton qui la porte a son libellé.
struct SiddourIcone: View {
    let nom: String
    let taille: CGFloat

    init(_ nom: String, taille: CGFloat) {
        self.nom = nom
        self.taille = taille
    }

    var body: some View {
        Image(systemName: SiddourIcone.symbole(nom))
            .resizable()
            .scaledToFit()
            .frame(width: taille, height: taille)
            .accessibilityHidden(true)
    }

    /// Le ruban en contour d'une prière, le livre ouvert d'une étude, la lune, le livre aux flèches du nusah,
    /// l'œil barré, le chevron vers le bas.
    static func symbole(_ nom: String) -> String {
        switch nom {
        case "ic_marque_priere": "bookmark"
        case "ic_marque_etude": "book"
        case "ic_lecture_lune": "moon"
        case "ic_lecture_nusah": "arrow.triangle.2.circlepath"
        case "ic_lecture_masquer": "eye.slash"
        case "ic_lecture_replier": "chevron.down"
        case "ic_chevron": "chevron.forward"
        default: "circle"
        }
    }
}

/// Lance une action du modèle qui peut échouer. Android écrit ses préférences sans échec possible : un échec
/// d'écriture ne montre rien de plus (le modèle a déjà remis l'écran d'après ce qui est en mémoire).
enum SiddourTache {
    @MainActor
    static func lancer(_ action: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                // Rien à montrer : voir plus haut.
            }
        }
    }
}

extension View {
    /// La carte des listes (drawable/bg_card.xml) : fond `card`, filet `line` d'un point, coins de 20 ; la marge
    /// intérieure est celle de chaque carte.
    func siddourCarte() -> some View {
        background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Teinte(.line), lineWidth: 1)
            }
    }

    /// Un titre hébreu (textDirection rtl, gravity start) : de droite à gauche et calé à droite, quelle que soit
    /// la langue de l'app.
    func siddourHebreuAuDebut() -> some View {
        multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
    }
}
