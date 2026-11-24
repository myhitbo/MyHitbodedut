import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce qu'ont en commun l'onglet Zmanim et le calendrier (VueJour.kt, activity_zmanim.xml, activity_calendrier.xml) :
// les mesures qui suivent la place de l'écran, le bandeau, la carte, le lien, les tailles de texte et la mise en
// forme des dates dans la langue de l'app. Aucune décision ici : tout ce qui est montré vient des modèles
// (ZmanimModele, CalendrierModele, ZmanimVueJour).

// MARK: Les mesures

/// Les dimensions d'Android qui suivent la place de l'écran (values-w360dp … values-w1200dp, values-h640dp).
struct ZmanimMesures: Equatable {
    var taille: CGSize = .zero

    /// values-h640dp : le bandeau s'agrandit sur un écran haut (hero_pad 22/18, hero_art 64 × 78, hero_title 24).
    var ecranHaut: Bool {
        taille.height >= 640
    }

    /// @dimen/edge : 16, 24 dès 360 de large, 48 dès 600, 120 dès 840, 320 dès 1200.
    var marge: CGFloat {
        let l = taille.width
        if l >= 1200 { return 320 }
        if l >= 840 { return 120 }
        if l >= 600 { return 48 }
        if l >= 360 { return 24 }
        return 16
    }

    /// @dimen/wide_gutter : 0 sous 600 de large, 32 dès 600, 104 dès 840, 304 dès 1200.
    var gouttiere: CGFloat {
        let l = taille.width
        if l >= 1200 { return 304 }
        if l >= 840 { return 104 }
        if l >= 600 { return 32 }
        return 0
    }
}

// MARK: Le texte

extension View {
    /// Un texte de l'interface à la taille d'Android en sp, qui suit la taille du texte du téléphone (Dynamic
    /// Type) comme le style d'iOS de même pas (Composants.swift : 17 → body, 15 → subheadline…).
    func zmanimTexte(_ taille: CGFloat, gras: Bool = false, poids: Font.Weight? = nil) -> some View {
        modifier(ZmanimTexteModificateur(taille: taille, poids: poids ?? (gras ? .bold : .regular)))
    }

    /// Un texte forcé de droite à gauche (`textDirection = RTL` d'Android) : toute la largeur, calé au début de
    /// l'hébreu, c'est-à-dire à droite, quelle que soit la langue de l'app.
    func zmanimDroiteAGauche() -> some View {
        multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct ZmanimTexteModificateur: ViewModifier {
    let poids: Font.Weight
    @ScaledMetric private var taille: CGFloat

    init(taille: CGFloat, poids: Font.Weight) {
        self.poids = poids
        _taille = ScaledMetric(wrappedValue: taille, relativeTo: ZmanimTexteModificateur.style(taille))
    }

    func body(content: Content) -> some View {
        content.font(.system(size: taille, weight: poids))
    }

    /// Le style d'iOS dont la taille suit le même pas.
    private static func style(_ taille: CGFloat) -> Font.TextStyle {
        if taille <= 11 { return .caption2 }
        if taille <= 12 { return .caption }
        if taille <= 13 { return .footnote }
        if taille <= 15 { return .subheadline }
        if taille <= 17 { return .body }
        if taille <= 20 { return .title3 }
        if taille <= 24 { return .title2 }
        return .title
    }
}

// MARK: La carte

extension View {
    /// Le fond d'une carte (VueJour.carte, bg_card) : 16 de marge intérieure, fond `card`, filet `line` de 1,
    /// coins de 20, toute la largeur.
    func zmanimFond() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Teinte(.line), lineWidth: 1)
            }
    }

    /// Les marges extérieures d'une carte : 16 sur les côtés, 12 au-dessus.
    func zmanimMarges() -> some View {
        padding(.horizontal, 16)
            .padding(.top, 12)
    }

    /// Une carte de VueJour, posée dans la colonne de l'écran.
    func zmanimCarte() -> some View {
        zmanimFond().zmanimMarges()
    }
}

// MARK: Le lien

/// Le style LIEN de VueJour (`lien`) : 15 pt, gras, couleur de la marque, marges verticales de 4, 48 de haut au
/// moins, calé au début ; toute la ligne se touche.
struct ZmanimEtiquetteLien: View {
    let texte: Text

    init(texte: Text) {
        self.texte = texte
    }

    var body: some View {
        texte
            .zmanimTexte(15, gras: true)
            .foregroundStyle(Teinte(.brand))
            .multilineTextAlignment(.leading)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// Un lien de VueJour, à 4 sous ce qui le précède.
struct ZmanimLien: View {
    let texte: Text
    let action: @MainActor () -> Void

    init(_ texte: Text, action: @escaping @MainActor () -> Void) {
        self.texte = texte
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZmanimEtiquetteLien(texte: texte)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

// MARK: Le bandeau (bg_hero)

/// Le bandeau de l'onglet et du calendrier : le titre en blanc, la pastille du lieu dessous (l'onglet seul), et
/// l'illustration sur sa plaque claire ; un dégradé de la marque, les coins du bas arrondis, un filet de lumière.
struct ZmanimBandeau: View {
    let titre: Text
    let image: String
    /// « Jérusalem · Israël » ; nil : pas de pastille.
    let lieu: Text?
    let toucherLieu: @MainActor () -> Void
    let mesures: ZmanimMesures

    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init(titre: Text, image: String, lieu: Text?, toucherLieu: @escaping @MainActor () -> Void,
         mesures: ZmanimMesures) {
        self.titre = titre
        self.image = image
        self.lieu = lieu
        self.toucherLieu = toucherLieu
        self.mesures = mesures
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                titre
                    .zmanimTexte(mesures.ecranHaut ? 24 : 21, gras: true)
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let lieu {
                    pastille(lieu)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Illustration(decorative: image)
                .padding(4)
                .frame(width: mesures.ecranHaut ? 64 : 50, height: mesures.ecranHaut ? 78 : 60)
                .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, mesures.marge)
        .padding(.top, mesures.ecranHaut ? 22 : 12)
        .padding(.bottom, mesures.ecranHaut ? 18 : 10)
        .background {
            fond
        }
    }

    /// Le dégradé à 225° : la marque en haut à droite (le drawable ne se retourne pas en hébreu), le vert sombre
    /// dès 55 % ; le filet de lumière du bas, blanc à 25 % au centre, en retrait de 36.
    private var fond: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            .fill(LinearGradient(stops: [
                Gradient.Stop(color: palette.couleur(.brand, schema: schema), location: 0),
                Gradient.Stop(color: palette.couleur(.brandDark, schema: schema), location: 0.55),
                Gradient.Stop(color: palette.couleur(.brandDark, schema: schema), location: 1),
            ], startPoint: .topTrailing, endPoint: .bottomLeading))
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25), Color.white.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
    }

    /// La pastille du lieu (bg_hero_chip) : un voile blanc, son contour, le chevron qui ouvre le choix du lieu.
    private func pastille(_ lieu: Text) -> some View {
        Button(action: toucherLieu) {
            HStack(spacing: 4) {
                lieu
                    .zmanimTexte(14)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Image(systemName: "chevron.down")
                    .font(Font.caption.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 36)
            .background(Color.white.opacity(0.15), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Le pied

/// Le pied (VueJour.pied) : la méthode à valider, la source des villes ; 12 pt, atténués, 4 entre les deux.
struct ZmanimPiedVue: View {
    let pied: [Libelle]

    @Environment(\.traducteur) private var traducteur

    init(pied: [Libelle]) {
        self.pied = pied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(pied, id: \.self) { ligne in
                Text(ligne, traducteur: traducteur)
                    .zmanimTexte(12)
                    .foregroundStyle(Teinte(.muted))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: Les dates

/// Les dates mises en forme dans la langue de l'app (`DateTimeFormatter.ofPattern(motif, locale)` d'Android), au
/// calendrier grégorien. Les modèles rendent des jours et des heures civiles ; la vue les écrit.
enum ZmanimFormat {

    /// Un jour (et une heure du lieu) selon un motif d'Android : « EEEE d MMMM yyyy », « LLLL yyyy »…
    static func texte(_ jour: JourCivil, heure: Int = 12, minute: Int = 0, motif: String, langue: String) -> String {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        // Le jour et l'heure sont déjà ceux du lieu : écrits en temps universel, aucun changement d'heure ne les
        // fait glisser.
        let composantes = DateComponents(year: jour.annee, month: jour.mois, day: jour.jour, hour: heure, minute: minute)
        guard let date = calendrier.date(from: composantes) else { return jour.iso }
        let format = DateFormatter()
        format.calendar = calendrier
        format.timeZone = .gmt
        format.locale = Locale(identifier: langue)
        format.dateFormat = motif
        return format.string(from: date)
    }

    /// La date civile en toutes lettres (VueJour.dateCivile) : « lundi 2 novembre 2026 ».
    static func dateCivile(_ jour: JourCivil, langue: String) -> String {
        texte(jour, motif: "EEEE d MMMM yyyy", langue: langue)
    }

    /// Une borne de la fenêtre de Levana : « EEE d MMM, HH:mm ».
    static func borneLevana(_ instant: DateHeure, langue: String) -> String {
        texte(instant.jour, heure: instant.heure, minute: instant.minute, motif: "EEE d MMM, HH:mm", langue: langue)
    }

    /// Le motsaé Chabbat conseillé : « EEE d MMM ».
    static func jourCourt(_ jour: JourCivil, langue: String) -> String {
        texte(jour, motif: "EEE d MMM", langue: langue)
    }

    /// L'initiale en majuscule seulement (CalendrierActivity.initiale) : « Septembre – octobre 2026 ».
    static func initiale(_ s: String, langue: String) -> String {
        guard let premier = s.first else { return s }
        return String(premier).uppercased(with: Locale(identifier: langue)) + s.dropFirst()
    }

    /// Un titre de l'en-tête du calendrier.
    static func titre(_ titre: CalendrierTitre, langue: String) -> String {
        switch titre {
        case .hebreu(let texte):
            return texte
        case .moisCivil(let jour):
            return initiale(texte(jour, motif: "LLLL yyyy", langue: langue), langue: langue)
        case .plageCivile(let debut, let fin, let anneeAuDebut):
            let premier = texte(debut, motif: anneeAuDebut ? "LLLL yyyy" : "LLLL", langue: langue)
            let dernier = texte(fin, motif: "LLLL yyyy", langue: langue)
            return initiale(premier + " – " + dernier, langue: langue)
        }
    }

    /// Le 1er d'un mois civil en vue hébraïque : « 1 oct. ».
    static func premierDuMois(_ jour: JourCivil, langue: String) -> String {
        "1 " + texte(jour, motif: "LLL", langue: langue)
    }

    /// L'initiale d'un jour de la semaine, du dimanche (1) au samedi (7) : `TextStyle.NARROW`.
    static func initialeDuJour(_ jour: Int, langue: String) -> String {
        let format = DateFormatter()
        format.locale = Locale(identifier: langue)
        let symboles: [String] = format.veryShortStandaloneWeekdaySymbols ?? []
        guard jour >= 1, jour <= symboles.count else { return "" }
        return symboles[jour - 1]
    }
}

// MARK: Les dialogues à choix unique

/// Une ligne d'un dialogue à choix unique : le texte, et la coche de l'option choisie (le bouton radio d'Android),
/// que VoiceOver dit « sélectionné ».
struct LieuLigneChoix: View {
    let texte: Text
    let cochee: Bool

    init(texte: Text, cochee: Bool) {
        self.texte = texte
        self.cochee = cochee
    }

    var body: some View {
        HStack(spacing: 12) {
            texte
                .font(.body)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if cochee {
                Image(systemName: "checkmark")
                    .font(Font.body.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(cochee ? .isSelected : [])
    }
}
