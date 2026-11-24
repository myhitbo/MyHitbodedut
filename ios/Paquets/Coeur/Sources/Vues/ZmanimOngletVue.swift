import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'onglet Zmanim (ZmanimActivity.kt, activity_zmanim.xml), dans l'ordre d'Android : le bandeau et la pastille du
/// lieu, la carte du jour, trois boutons (halakha, hilloulot, calendrier), deux autres (vol, boussole), les
/// horaires (ou l'invitation à choisir un lieu), puis Birkat haLevana, la hilloula et la halakha du jour chacune
/// dans sa carte, l'allumage des bougies, Ta'hanoun de fin de Tichri (en Sfard), le pied. Propre à iOS : le jour
/// précédent, le jour suivant et le retour à aujourd'hui, dans la barre.
///
/// La vue ne décide rien : ZmanimModele (cible Ecrans) dit le jour, ses blocs et les réglages. Sa pile de
/// navigation est celle de son onglet (ios/App). Le calendrier, sous-page de cet écran, est poussé ici quand
/// `calendrier` le construit ; la halakha, les hilloulot, le vol, la boussole et le texte de Birkat haLevana sont
/// d'autres écrans : `ouvrir` les reçoit.
public struct ZmanimOngletVue: View {
    let modele: ZmanimModele
    private let fabriqueCalendrier: (@MainActor () -> CalendrierModele)?
    private let ouvrir: @MainActor (ZmanimRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var scenePhase

    @State private var mesures = ZmanimMesures()
    /// L'écran est celui du dessus de sa pile : lui seul présente le choix du lieu.
    @State private var auPremierPlan = false
    /// Le dialogue de réglage ouvert (l'allumage, Ta'hanoun) ; nil sinon.
    @State private var dialogue: ZmanimDialogue?
    /// Le calendrier poussé ; nil quand on n'y est pas.
    @State private var calendrier: ZmanimCalendrierOuvert?

    /// - Parameters:
    ///   - modele: l'onglet, construit avec ses contenus, ses hilloulot, la localisation, l'autorisation et le
    ///     traducteur (sans eux, ni halakha, ni hilloula, ni choix du lieu).
    ///   - calendrier: construit le calendrier quand on le touche (CalendrierModele avec `modele.choixLieu`) ;
    ///     nil : `.calendrier` passe par `ouvrir`, comme les autres routes.
    ///   - ouvrir: les autres écrans (ZmanimRoute) : `.halakha`, `.hilloulot`, `.vol`, `.boussole`, `.siddour`,
    ///     et `.ajouterTemps` depuis le calendrier.
    public init(modele: ZmanimModele,
                calendrier: (@MainActor () -> CalendrierModele)? = nil,
                ouvrir: @escaping @MainActor (ZmanimRoute) -> Void) {
        self.modele = modele
        fabriqueCalendrier = calendrier
        self.ouvrir = ouvrir
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZmanimBandeau(titre: Text(modele.titre, traducteur: traducteur),
                          image: modele.image,
                          lieu: modele.lieuTexte.map { Text($0, traducteur: traducteur) },
                          toucherLieu: modele.montrerChoixLieu,
                          mesures: mesures)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    contenu
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, mesures.gouttiere)
                .padding(.bottom, 24)
            }
        }
        .background(Teinte(.paper))
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { taille in
            mesures.taille = taille
        }
        // Le titre nomme l'écran (le retour, VoiceOver) ; le bandeau le montre déjà : la barre ne le répète pas.
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .toolbar {
            navigationDuJour
        }
        .sheet(item: $dialogue) { dialogue in
            feuille(dialogue)
        }
        .lieuChoix(modele.choixLieu, actif: auPremierPlan)
        .navigationDestination(item: $calendrier) { ouvert in
            CalendrierVue(modele: ouvert.modele, ouvrir: ouvrir)
        }
        // À chaque apparition (onResume) : les contenus la première fois, le jour, la position sans bruit.
        .task {
            await modele.apparaitre()
        }
        .onAppear {
            auPremierPlan = true
        }
        .onDisappear {
            auPremierPlan = false
            modele.disparaitre()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if auPremierPlan {
                    Task { await modele.apparaitre() }
                }
            case .background:
                modele.disparaitre()
            default:
                break
            }
        }
    }

    // MARK: Le contenu

    @ViewBuilder private var contenu: some View {
        ZmanimCarteJourVue(carte: modele.carte, police: modele.police, partage: modele.partage)
        rangee(modele.boutons, haut: 12)
        rangee(modele.boutonsBas, haut: 8)
        ZmanimHorairesVue(lignes: modele.lignes, sansLieu: modele.sansLieu, invitation: modele.invitationLieu,
                          choisirLieu: modele.choisirLieuLibelle, montrerChoixLieu: modele.montrerChoixLieu)
        sousLesHoraires
        ZmanimCarteReglage(reglage: modele.allumageCarte) {
            dialogue = .allumage
        }
        if let tahanoun = modele.tahanounCarte {
            ZmanimCarteReglage(reglage: tahanoun) {
                dialogue = .tahanoun
            }
        }
        ZmanimPiedVue(pied: modele.pied)
    }

    /// Birkat haLevana, la hilloula et la halakha du jour (VueJour.sousHoraires), chacune dans sa carte, en tête
    /// de carte ; une carte masquée ou vide n'apparaît pas.
    @ViewBuilder private var sousLesHoraires: some View {
        if let levana = modele.levana {
            ZmanimLevanaVue(levana: levana, haut: 0, ouvrir: aller)
                .zmanimCarte()
        }
        if let hilloula = modele.hilloula {
            ZmanimHilloulaVue(hilloula: hilloula, police: modele.police, haut: 0, ouvrir: aller)
                .zmanimCarte()
        }
        if let halakha = modele.halakha {
            ZmanimHalakhaVue(halakha: halakha, police: modele.police, haut: 0, ouvrir: aller)
                .zmanimCarte()
        }
    }

    // MARK: Les boutons

    /// Une rangée de boutons de contour de même largeur, 8 entre eux, 16 sur les côtés.
    private func rangee(_ boutons: [ZmanimBouton], haut: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(boutons) { bouton in
                Button {
                    aller(bouton.route)
                } label: {
                    Text(verbatim: libelle(bouton))
                        .lineLimit(bouton.icone == nil ? 2 : 1)
                        .minimumScaleFactor(9.0 / 14.0)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ZmanimBoutonContour())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, haut)
    }

    /// « Calendrier », ou « ✈  En vol » : l'icône devant, deux espaces.
    private func libelle(_ bouton: ZmanimBouton) -> String {
        let texte = traducteur.texte(bouton.libelle)
        guard let icone = bouton.icone else { return texte }
        return icone + "  " + texte
    }

    // MARK: Le jour montré (propre à iOS)

    @ToolbarContentBuilder private var navigationDuJour: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                modele.jourPrecedent()
            } label: {
                Label {
                    Text(Libelle("jour_precedent"), traducteur: traducteur)
                } icon: {
                    Image(systemName: "chevron.backward")
                }
            }
            if !modele.estAujourdhui {
                Button {
                    modele.revenirAujourdhui()
                } label: {
                    Text(Libelle("calendrier_aujourdhui"), traducteur: traducteur)
                }
            }
            Button {
                modele.jourSuivant()
            } label: {
                Label {
                    Text(Libelle("jour_suivant"), traducteur: traducteur)
                } icon: {
                    Image(systemName: "chevron.forward")
                }
            }
        }
    }

    // MARK: Les dialogues

    @ViewBuilder private func feuille(_ dialogue: ZmanimDialogue) -> some View {
        switch dialogue {
        case .allumage:
            ZmanimFeuilleReglage(reglage: modele.allumageCarte) { option in
                choisirAllumage(option.id)
            }
        case .tahanoun:
            if let tahanoun = modele.tahanounCarte {
                ZmanimFeuilleReglage(reglage: tahanoun) { option in
                    // Les options du modèle : 0, « Dit après Isrou 'hag » ; 1, « Pas dit jusqu'à Roch 'Hodech ».
                    choisirTahanoun(sans: option.id == 1)
                }
            }
        }
    }

    // MARK: Les actions
    // Une écriture des réglages qui échoue ne dit rien, comme Android (Store ne signale pas d'échec).

    /// Une route du modèle : le calendrier est poussé ici quand on sait le construire ; le reste va à `ouvrir`.
    private func aller(_ route: ZmanimRoute) {
        if route == .calendrier, let fabriqueCalendrier {
            calendrier = ZmanimCalendrierOuvert(modele: fabriqueCalendrier())
        } else {
            ouvrir(route)
        }
    }

    private func choisirAllumage(_ minutes: Int) {
        dialogue = nil
        let modele = self.modele
        Task {
            do {
                try await modele.choisirAllumage(minutes)
            } catch {
            }
        }
    }

    private func choisirTahanoun(sans: Bool) {
        dialogue = nil
        let modele = self.modele
        Task {
            do {
                try await modele.choisirTahanounTichri(sans: sans)
            } catch {
            }
        }
    }
}

/// Un dialogue de réglage de l'onglet.
enum ZmanimDialogue: String, Identifiable {
    case allumage
    case tahanoun

    var id: String { rawValue }
}

/// Le calendrier poussé depuis l'onglet : son modèle, gardé le temps qu'il est à l'écran.
struct ZmanimCalendrierOuvert: Hashable {
    let id = UUID()
    let modele: CalendrierModele

    init(modele: CalendrierModele) {
        self.modele = modele
    }

    static func == (a: ZmanimCalendrierOuvert, b: ZmanimCalendrierOuvert) -> Bool {
        a.id == b.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Un bouton de l'onglet (ZmanimActivity.bouton, materialButtonOutlinedStyle) : le contour `line` du bouton
/// secondaire, texte medium de 14 à 9 pt à la couleur de la marque, 4 de marge sur les côtés pour que trois
/// tiennent sur une rangée, 48 de haut au moins.
struct ZmanimBoutonContour: ButtonStyle {
    init() {}

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .zmanimTexte(14, poids: .medium)
            .multilineTextAlignment(.center)
            .foregroundStyle(Teinte(.brand))
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(minHeight: 48)
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
