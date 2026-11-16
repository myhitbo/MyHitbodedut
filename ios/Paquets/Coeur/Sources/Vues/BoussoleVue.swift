import Accessibility
import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La boussole de Jérusalem (BoussoleActivity.kt, activity_boussole.xml ; design C « le hassid se tourne ») :
/// le bandeau et son lieu, puis, sans lieu, l'état vide (« Où êtes-vous ? ») ; avec un lieu, la boussole, l'aide,
/// « Actualiser ma position », les deux directions et la distance, la méthode, l'affichage et la note.
///
/// La vue ne décide rien : BoussoleModele (cible Ecrans) dit l'état, la scène, les textes et les choix. Elle
/// suit le capteur tant que l'app est au premier plan (onResume, onPause d'Android), reprend la position sans
/// bruit à l'apparition et au retour, et joue le retour haptique à chaque arrivée face à Jérusalem.
///
/// Sa pile de navigation est celle de son onglet (on l'ouvre de l'écran des zmanim, ou du widget) ; elle n'ouvre
/// aucun autre écran : ses dialogues sont des feuilles, et la note mène à l'article de Chabad.org.
public struct BoussoleVue: View {
    @Bindable var modele: BoussoleModele

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var schema
    @Environment(\.paletteApp) private var palette

    /// La place de l'écran, pour les marges qui suivent la largeur et la hauteur (values-w600dp, values-h640dp…).
    @State private var taille: CGSize = .zero

    public init(modele: BoussoleModele) {
        self.modele = modele
    }

    public var body: some View {
        VStack(spacing: 0) {
            bandeau
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    contenu
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, gouttiere)
                .padding(.bottom, 24)
            }
        }
        .background(Teinte(.paper))
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { nouvelle in
            taille = nouvelle
        }
        .overlay(alignment: .bottom) {
            messagePassager
        }
        .sheet(item: $modele.dialogue) { dialogue in
            BoussoleFeuille(modele: modele, dialogue: dialogue)
        }
        // Le titre nomme l'écran (le retour, VoiceOver) ; le bandeau le montre déjà : la barre ne le répète pas.
        .navigationTitle(t("boussole_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        // Le capteur ne tourne qu'au premier plan : la tâche s'annule en quittant l'état actif (onPause) et
        // repart au retour (onResume), ce qui recache l'avertissement et signale de nouveau l'alignement.
        .task(id: scenePhase == .active) { [actif = scenePhase == .active] in
            guard actif else { return }
            await modele.suivreCapteur()
        }
        .task(id: modele.message) {
            await montrerMessage()
        }
        .onAppear {
            Task { await reprendre() }
        }
        .onDisappear {
            Task { await modele.suspendre() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await reprendre() }
            case .background:
                Task { await modele.suspendre() }
            default:
                break
            }
        }
    }

    // MARK: Le bandeau (bg_hero)

    private var bandeau: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                t("boussole_title")
                    .font(ecranHaut ? Font.title2.bold() : Font.title3.bold())
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)
                if let pastille = modele.pastille {
                    pastilleLieu(pastille)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Illustration(decorative: modele.imageHassid)
                .padding(4)
                .frame(width: ecranHaut ? 64 : 50, height: ecranHaut ? 78 : 60)
                .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, marge)
        .padding(.top, ecranHaut ? 22 : 12)
        .padding(.bottom, ecranHaut ? 18 : 10)
        .background {
            fondBandeau
        }
    }

    /// Le dégradé de la marque, du côté de l'illustration en haut, vers le vert sombre (225°, centre à 55 %),
    /// les coins du bas arrondis, et le filet de lumière du bas.
    private var fondBandeau: some View {
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

    /// La pastille du lieu (bg_hero_chip) : un voile clair sur le bandeau ; son toucher ouvre le choix du lieu.
    private func pastilleLieu(_ pastille: BoussolePastille) -> some View {
        Button {
            Task { await modele.ouvrirChoixLieu() }
        } label: {
            textePastille(pastille)
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
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

    private func textePastille(_ pastille: BoussolePastille) -> Text {
        switch pastille {
        case .nom(let nom):
            Text(verbatim: nom)
        case .libelle(let libelle):
            Text(libelle, traducteur: traducteur)
        }
    }

    // MARK: Le contenu

    @ViewBuilder private var contenu: some View {
        switch modele.etat {
        case .sansLieu:
            etatVide
            sourceVilles
        case .sansCapteur, .attenteDuCap, .orientee:
            boussole
            sousLaBoussole
            carteDirections
            carteMethode
            carteAffichage
            carteNote
            sourceVilles
        }
    }

    /// Sans lieu (29/10) : le hassid, une question, la position en un toucher, ou une ville.
    private var etatVide: some View {
        Carte {
            VStack(spacing: 0) {
                Illustration(decorative: modele.imageHassid)
                    .padding(6)
                    .frame(width: 96, height: 116)
                    .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.top, 4)
                    .accessibilityHidden(true)
                t("boussole_vide_titre")
                    .font(Font.title3.bold())
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                t("boussole_carte_sous")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                Button {
                    Task { await utiliserMaPosition() }
                } label: {
                    t("boussole_vide_position")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
                .padding(.top, 16)
                Button {
                    Task { await modele.ouvrirChoixLieu() }
                } label: {
                    t("boussole_vide_ville")
                        .underline()
                        .font(Font.subheadline.weight(.medium))
                        .foregroundStyle(Teinte(.muted))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .boussoleMargeCarte()
    }

    /// La boussole : un carré sur le fond de scène (bg_stage), la scène du modèle dessinée dedans. VoiceOver
    /// la lit d'un trait, par la consigne que le modèle ne change qu'à l'arrivée et au départ.
    @ViewBuilder private var boussole: some View {
        if let scene = modele.scene {
            BoussoleToile(scene: scene, nord: modele.nord, cardinaux: modele.cardinaux,
                          imageHassid: modele.imageHassid)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Teinte(.mint))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityElement()
                .accessibilityLabel(Text(modele.consigneAccessible, traducteur: traducteur))
                .sensoryFeedback(.success, trigger: modele.alignements)
                .padding(.horizontal, 16)
                .padding(.top, 16)
        }
    }

    /// L'avertissement de calibrage, l'aide, et « Actualiser ma position ».
    @ViewBuilder private var sousLaBoussole: some View {
        if modele.montrerCalibrage {
            t("boussole_calibrer")
                .font(.footnote)
                .foregroundStyle(couleurAlerte)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        Text(modele.aide, traducteur: traducteur)
            .font(.footnote)
            .foregroundStyle(Teinte(.muted))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        Button {
            Task { await utiliserMaPosition() }
        } label: {
            t("boussole_actualiser_position")
        }
        .buttonStyle(.secondaire)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Les deux directions (celle que suit le hassid d'abord, en gras à la couleur de la marque), la distance et
    /// la légende.
    private var carteDirections: some View {
        Carte {
            VStack(alignment: .leading, spacing: 4) {
                if let suivie = modele.directionSuivie {
                    Text(suivie, traducteur: traducteur)
                        .font(Font.subheadline.bold())
                        .foregroundStyle(Teinte(.brand))
                }
                if let autre = modele.directionAutre {
                    Text(autre, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.ink))
                }
                if let distance = modele.distance {
                    Text(distance, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
                if let legende = modele.legende {
                    Text(legende, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .boussoleMargeCarte()
    }

    /// « Direction suivie » : toute la carte ouvre le choix de la méthode.
    private var carteMethode: some View {
        Button {
            modele.ouvrirMethode()
        } label: {
            BoussoleCarteReglage(titre: t("boussole_methode"),
                                 valeur: Text(modele.methodeChoisie, traducteur: traducteur))
        }
        .buttonStyle(.plain)
        .boussoleMargeCarte()
    }

    /// « Affichage de la boussole » : toute la carte ouvre le choix de l'affichage.
    private var carteAffichage: some View {
        Button {
            modele.ouvrirAffichage()
        } label: {
            BoussoleCarteReglage(titre: t("boussole_affichage"),
                                 valeur: Text(modele.affichageChoisi, traducteur: traducteur))
        }
        .buttonStyle(.plain)
        .boussoleMargeCarte()
    }

    /// La note sur les deux calculs, et sa source : toute la ligne mène à l'article.
    private var carteNote: some View {
        Carte {
            VStack(alignment: .leading, spacing: 4) {
                t("boussole_note_titre")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .accessibilityAddTraits(.isHeader)
                t("boussole_note")
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                lienSource
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .boussoleMargeCarte()
    }

    @ViewBuilder private var lienSource: some View {
        let source = Text(modele.source, traducteur: traducteur)
            .font(.footnote)
            .foregroundStyle(Teinte(.brand))
        if let adresse = modele.lienSource {
            Link(destination: adresse) {
                source
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
        } else {
            source
        }
    }

    /// « Villes : GeoNames (CC-BY 4.0) », sous tout le reste.
    private var sourceVilles: some View {
        t("zmanim_source_villes")
            .font(.caption)
            .foregroundStyle(Teinte(.muted))
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }

    // MARK: Le message passager (Toast)

    @ViewBuilder private var messagePassager: some View {
        if let message = modele.message {
            Text(message.libelle, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.paper))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Teinte(.ink).opacity(0.92), in: Capsule())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                // Un Toast ne prend pas les touchers : ce qui est dessous reste touchable.
                .allowsHitTesting(false)
        }
    }

    /// Le Toast : VoiceOver le dit (TalkBack lit un Toast), puis il s'efface au bout de sa durée
    /// (LENGTH_LONG 3,5 s, LENGTH_SHORT 2 s). Un autre message, ou aucun, annule l'attente.
    private func montrerMessage() async {
        guard let message = modele.message else { return }
        AccessibilityNotification.Announcement(traducteur.texte(message.libelle)).post()
        do {
            try await Task.sleep(for: .seconds(message.long ? 3.5 : 2))
        } catch {
            return
        }
        modele.effacerMessage()
    }

    // MARK: Les actions
    // Une écriture des réglages qui échoue ne dit rien, comme Android (Store ne signale pas d'échec).

    private func utiliserMaPosition() async {
        do {
            try await modele.utiliserMaPosition()
        } catch {
        }
    }

    private func reprendre() async {
        do {
            try await modele.reprendre()
        } catch {
        }
    }

    // MARK: La mise en page

    /// Une chaîne simple du catalogue, dans la langue de l'app.
    private func t(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }

    /// values-h640dp : le bandeau s'agrandit sur un écran haut.
    private var ecranHaut: Bool {
        taille.height >= 640
    }

    /// @dimen/edge : 16, 24 dès 360 de large, 48 dès 600, 120 dès 840, 320 dès 1200.
    private var marge: CGFloat {
        let l = taille.width
        if l >= 1200 { return 320 }
        if l >= 840 { return 120 }
        if l >= 600 { return 48 }
        if l >= 360 { return 24 }
        return 16
    }

    /// @dimen/wide_gutter : 0 sous 600 de large, 32 dès 600, 104 dès 840, 304 dès 1200.
    private var gouttiere: CGFloat {
        let l = taille.width
        if l >= 1200 { return 304 }
        if l >= 840 { return 104 }
        if l >= 600 { return 32 }
        return 0
    }

    /// @color/warning, qui n'est pas un jeton de la palette : #A8561F de jour, #E8A062 de nuit.
    private var couleurAlerte: Color {
        schema == .dark
            ? Color(.sRGB, red: 0xE8 / 255.0, green: 0xA0 / 255.0, blue: 0x62 / 255.0, opacity: 1)
            : Color(.sRGB, red: 0xA8 / 255.0, green: 0x56 / 255.0, blue: 0x1F / 255.0, opacity: 1)
    }
}

/// Une carte de réglage (« Direction suivie », « Affichage de la boussole ») : son titre et le choix en cours ;
/// posée comme étiquette d'un bouton, toute la carte se touche.
struct BoussoleCarteReglage: View {
    let titre: Text
    let valeur: Text

    init(titre: Text, valeur: Text) {
        self.titre = titre
        self.valeur = valeur
    }

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 4) {
                titre
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                valeur
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// Les marges d'une carte de VueJour.carte : 16 sur les côtés, 12 au-dessus.
    func boussoleMargeCarte() -> some View {
        padding(.horizontal, 16)
            .padding(.top, 12)
    }
}
