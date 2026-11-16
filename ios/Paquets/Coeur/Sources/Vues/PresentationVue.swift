import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La présentation du premier lancement (OnboardingActivity.kt, activity_onboarding.xml et layout-land) : une page
/// à la fois, la pastille d'étape, l'illustration sur sa scène, le titre, le texte, les choix de la page, le grand
/// bouton et la rangée « Précédent » / « Passer ». La vue ne décide rien : elle lit `PresentationModele` (Ecrans)
/// et appelle ses actions.
///
/// L'app la présente en plein écran (`fullScreenCover`) ; elle se retire d'elle-même (`dismiss`) dès que le
/// modèle est `termine`. Présentée en feuille, l'app appelle `terminer()` dans son `onDismiss` (idempotent).
///
/// Changer de page ne joue aucune animation, comme sur Android (`render()` remplace le contenu).
public struct PresentationVue: View {
    private let modele: PresentationModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var fermer

    public init(modele: PresentationModele) {
        self.modele = modele
    }

    public var body: some View {
        GeometryReader { geo in
            let mesures = PresentationMesures(taille: geo.size)
            if mesures.couchee {
                couchee(mesures)
            } else {
                debout(mesures)
            }
        }
        .background(Teinte(.paper))
        .sheet(isPresented: choixHeure) {
            feuilleHeure
        }
        .onChange(of: modele.termine) { _, fini in
            if fini { fermer() }
        }
    }

    // MARK: Les deux dispositions

    /// Debout (activity_onboarding.xml) : tout dans un défilement dont le contenu remplit au moins l'écran
    /// (fillViewport) ; la scène prend la hauteur qui reste, jusqu'à sa hauteur minimale, puis le tout défile
    /// pour que les boutons du bas restent atteignables.
    private func debout(_ m: PresentationMesures) -> some View {
        ViewThatFits(in: .vertical) {
            colonneDebout(m)
            ScrollView {
                colonneDebout(m)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func colonneDebout(_ m: PresentationMesures) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            etape
            scene(m)
                .padding(.top, m.ecartImage)
            textes(m)
            choix
            suivant(m)
                .padding(.top, m.ecartSuivant)
            rangeeDuBas
        }
        .padding(.horizontal, m.bord)
        .padding(.vertical, m.margeVerticale)
    }

    /// Couchée (layout-land) : la scène sur toute la hauteur au début (à droite en hébreu), la colonne du texte
    /// à 16 pt, de poids 1 contre 1,25. Seul le haut de la colonne défile si la hauteur manque ; le grand bouton
    /// et la rangée du bas restent visibles dessous.
    private func couchee(_ m: PresentationMesures) -> some View {
        let disponible = max(m.largeur - 2 * m.bord - 16, 0)
        return HStack(spacing: 16) {
            scene(m)
                .frame(width: disponible / 2.25)
            VStack(alignment: .leading, spacing: 0) {
                ViewThatFits(in: .vertical) {
                    hautCouche(m)
                    ScrollView {
                        hautCouche(m)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                suivant(m)
                    .padding(.top, m.ecartSuivant)
                rangeeDuBas
            }
            .frame(width: disponible * 1.25 / 2.25)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, m.bord)
        .padding(.vertical, m.margeVerticale)
    }

    private func hautCouche(_ m: PresentationMesures) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            etape
            textes(m)
            choix
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Les éléments de la page

    /// La pastille d'étape, « 3 / 7 » (bg_chip_mint) : 12 sp, encre `onPlate` sur la menthe.
    private var etape: some View {
        Text(modele.etape, traducteur: traducteur)
            .font(.caption)
            .foregroundStyle(Teinte(.onPlate))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Teinte(.mint), in: Capsule())
    }

    /// La scène de l'illustration (bg_stage) : un panneau menthe aux coins de 20, 12 de marge intérieure.
    /// L'image est décorative (contentDescription null) et ne se retourne pas en hébreu.
    private func scene(_ m: PresentationMesures) -> some View {
        Illustration(decorative: modele.illustration)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .frame(minHeight: m.imageMin, idealHeight: m.imageMin, maxHeight: .infinity)
            .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Le titre (un en-tête pour VoiceOver) et le texte de la page.
    private func textes(_ m: PresentationMesures) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(modele.titre, traducteur: traducteur)
                .font(m.policeTitre)
                .foregroundStyle(Teinte(.ink))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, m.ecartTitre)
            Text(modele.corps, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.muted))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, m.ecartCorps)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    /// Les choix que porte la page : l'adresse, la durée ou le rappel (GONE ailleurs).
    @ViewBuilder
    private var choix: some View {
        if modele.montreAdresse {
            rangeeAdresses
                .padding(.top, 12)
        }
        if modele.montreDurees {
            rangeeDurees
                .padding(.top, 12)
        }
        if modele.montreRappel {
            rangeeRappel
                .padding(.top, 12)
        }
    }

    /// צדיק / צדקת : deux boutons à contour, centrés, à 12 l'un de l'autre ; rien n'est coché au départ.
    private var rangeeAdresses: some View {
        HStack(spacing: 12) {
            ForEach(modele.adresses) { une in
                Button {
                    Task { try? await modele.choisirAdresse(une.adresse) }
                } label: {
                    Text(une.libelle, traducteur: traducteur)
                }
                .buttonStyle(PresentationBoutonContour(coche: une.choisie, marge: 24))
                .accessibilityAddTraits(une.choisie ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Les quatre durées, de même largeur, une seule cochée (MaterialButtonToggleGroup) : les boutons se
    /// touchent, leurs filets se confondent, et le groupe entier a la forme d'une pilule.
    private var rangeeDurees: some View {
        HStack(spacing: -1) {
            ForEach(modele.durees) { duree in
                Button {
                    Task { try? await modele.choisirDuree(duree.minutes) }
                } label: {
                    Text(duree.libelle, traducteur: traducteur)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PresentationBoutonSegment(coche: duree.choisie))
                .accessibilityAddTraits(duree.choisie ? .isSelected : [])
            }
        }
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
        }
    }

    /// L'interrupteur du rappel quotidien, et à sa suite le bouton de son heure, « à 07:00 ».
    private var rangeeRappel: some View {
        let heure = heureMiseEnForme
        return HStack(spacing: 8) {
            Toggle(isOn: rappel) {
                Text(modele.libelleRappel, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
            }
            .tint(palette.couleur(.brand, schema: schema))
            Button {
                modele.ouvrirChoixHeure()
            } label: {
                Text(modele.libelleHeureRappel(heure), traducteur: traducteur)
            }
            .buttonStyle(PresentationBoutonTexte())
            .accessibilityLabel(Text(modele.descriptionHeureRappel(heure), traducteur: traducteur))
        }
        .frame(minHeight: 48)
    }

    /// Le grand bouton, « Suivant » puis « Commencer » : toute la largeur, style plein (Bouton.Plein).
    private func suivant(_ m: PresentationMesures) -> some View {
        Button {
            Task { try? await modele.suivant() }
        } label: {
            Text(modele.libelleSuivant, traducteur: traducteur)
                .font(Font.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, m.margeSuivant)
        }
        .buttonStyle(.principal)
    }

    /// « Précédent » au début, « Passer » à la fin. Un bouton masqué garde sa place (INVISIBLE, pas GONE) et
    /// sort de VoiceOver.
    private var rangeeDuBas: some View {
        HStack(spacing: 8) {
            Button {
                modele.precedent()
            } label: {
                Text(modele.libelleRetour, traducteur: traducteur)
            }
            .buttonStyle(PresentationBoutonTexte())
            .opacity(modele.retourVisible ? 1 : 0)
            .disabled(!modele.retourVisible)
            .accessibilityHidden(!modele.retourVisible)
            Spacer(minLength: 0)
            Button {
                Task { try? await modele.passer() }
            } label: {
                Text(modele.libellePasser, traducteur: traducteur)
            }
            .buttonStyle(PresentationBoutonTexte())
            .opacity(modele.passerVisible ? 1 : 0)
            .disabled(!modele.passerVisible)
            .accessibilityHidden(!modele.passerVisible)
        }
    }

    // MARK: Le choix de l'heure

    /// Le sélecteur d'heure (TimePickerDialog d'Android), ouvert par le modèle ; le fermer d'un geste ne change
    /// rien (`fermerChoixHeure`).
    private var feuilleHeure: some View {
        let modele = modele
        return PresentationChoixHeure(
            heure: modele.heureRappelHeure,
            minute: modele.heureRappelMinute,
            libelle: Text(modele.libelleRappel, traducteur: traducteur),
            valider: { heure, minute in
                Task { try? await modele.choisirHeureRappel(heure: heure, minute: minute) }
            },
            annuler: {
                modele.fermerChoixHeure()
            })
    }

    // MARK: Liaisons et mise en forme

    /// L'interrupteur lit le réglage du modèle et l'écrit par son action.
    private var rappel: Binding<Bool> {
        let modele = modele
        return Binding(
            get: { @MainActor in modele.rappelActif },
            set: { @MainActor actif in
                Task { try? await modele.basculerRappel(actif) }
            })
    }

    /// La feuille de l'heure suit `choixHeureOuvert` ; glissée vers le bas, elle se ferme sans rien choisir.
    private var choixHeure: Binding<Bool> {
        let modele = modele
        return Binding(
            get: { @MainActor in modele.choixHeureOuvert },
            set: { @MainActor ouvert in
                if !ouvert { modele.fermerChoixHeure() }
            })
    }

    /// L'heure du rappel telle qu'Android l'écrit (OnboardingActivity.heure) : « HH:mm » si le téléphone est
    /// réglé sur 24 heures (`DateFormat.is24HourFormat`), « h:mm a » sinon, l'indication du matin ou du soir
    /// dans la langue de l'app.
    private var heureMiseEnForme: String {
        let heure = modele.heureRappelHeure
        let minute = modele.heureRappelMinute
        switch Locale.autoupdatingCurrent.hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour:
            return String(format: "%02d:%02d", heure, minute)
        default:
            var calendrier = Calendar(identifier: .gregorian)
            calendrier.locale = locale
            let douze = heure % 12 == 0 ? 12 : heure % 12
            let moment = heure < 12 ? calendrier.amSymbol : calendrier.pmSymbol
            return String(format: "%d:%02d", douze, minute) + " " + moment
        }
    }
}

// MARK: Les mesures d'Android

/// Les dimensions de la présentation selon la place (values/dimens.xml, values-w360dp à values-w1200dp,
/// values-h640dp) : la marge `edge` suit la largeur, les espacements de la page suivent la hauteur.
private struct PresentationMesures {
    let largeur: CGFloat
    /// layout-land : l'écran est plus large que haut.
    let couchee: Bool
    /// edge : 16, 24 dès 360 de large, 48 dès 600, 120 dès 840, 320 dès 1200.
    let bord: CGFloat
    /// onboarding_pad_v.
    let margeVerticale: CGFloat
    /// onboarding_art_min.
    let imageMin: CGFloat
    /// onboarding_art_gap.
    let ecartImage: CGFloat
    /// onboarding_title_gap.
    let ecartTitre: CGFloat
    /// onboarding_title_size : 19 sp, 21 dès 640 de haut.
    let policeTitre: Font
    /// onboarding_body_gap.
    let ecartCorps: CGFloat
    /// onboarding_next_gap.
    let ecartSuivant: CGFloat
    /// Ce qu'ajoute onboarding_next_pad (10, 14 dès 640 de haut) aux 10 du bouton principal.
    let margeSuivant: CGFloat

    init(taille: CGSize) {
        largeur = taille.width
        couchee = taille.width > taille.height
        let w = taille.width
        if w >= 1200 {
            bord = 320
        } else if w >= 840 {
            bord = 120
        } else if w >= 600 {
            bord = 48
        } else if w >= 360 {
            bord = 24
        } else {
            bord = 16
        }
        let haut = taille.height >= 640
        margeVerticale = haut ? 22 : 14
        imageMin = haut ? 150 : 96
        ecartImage = haut ? 18 : 12
        ecartTitre = haut ? 20 : 14
        policeTitre = haut ? Font.title2.bold() : Font.title3.bold()
        ecartCorps = haut ? 8 : 6
        ecartSuivant = haut ? 16 : 12
        margeSuivant = haut ? 4 : 0
    }
}

// MARK: Les boutons de Material

/// Le bouton à contour de Material 3 (Widget.Material3.Button.OutlinedButton, checkable) : une pilule cerclée du
/// filet `line`, texte à la couleur de l'accent ; coché, fond menthe et encre `onPlate`.
private struct PresentationBoutonContour: ButtonStyle {
    let coche: Bool
    let marge: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Teinte(coche ? .onPlate : .brand))
            .padding(.horizontal, marge)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .background {
                if coche {
                    Capsule().fill(Teinte(.mint))
                }
            }
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Un bouton du groupe des durées (MaterialButtonToggleGroup de Material 1.12) : un segment droit cerclé du
/// filet `line`, que le groupe arrondit à ses deux bouts ; coché, fond menthe et encre `onPlate`.
private struct PresentationBoutonSegment: ButtonStyle {
    let coche: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Teinte(coche ? .onPlate : .brand))
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .background {
                if coche {
                    Rectangle().fill(Teinte(.mint))
                }
            }
            .overlay {
                Rectangle().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Le bouton texte de Material 3 (Widget.Material3.Button.TextButton) : texte medium à la couleur de l'accent,
/// 48 de cible au moins.
private struct PresentationBoutonTexte: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Teinte(.brand))
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: La feuille de l'heure

/// Le choix de l'heure du rappel : une roue des heures et des minutes, au format 12 ou 24 heures du téléphone,
/// avec « Annuler » et « Valider » du système. L'heure est tenue comme un instant de la journée de référence en
/// temps universel (2001-01-01 UTC), pour qu'aucun fuseau ni changement d'heure ne la décale.
private struct PresentationChoixHeure: View {
    private let libelle: Text
    private let valider: @MainActor (Int, Int) -> Void
    private let annuler: @MainActor () -> Void
    @State private var instant: Date

    init(heure: Int, minute: Int, libelle: Text,
         valider: @escaping @MainActor (Int, Int) -> Void,
         annuler: @escaping @MainActor () -> Void) {
        self.libelle = libelle
        self.valider = valider
        self.annuler = annuler
        _instant = State(initialValue: Date(timeIntervalSinceReferenceDate: TimeInterval(heure * 3600 + minute * 60)))
    }

    var body: some View {
        NavigationStack {
            DatePicker(selection: $instant, displayedComponents: .hourAndMinute) {
                libelle
            }
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.timeZone, .gmt)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        annuler()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        choisir()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func choisir() {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        let parties = calendrier.dateComponents([.hour, .minute], from: instant)
        valider(parties.hour ?? 0, parties.minute ?? 0)
    }
}
