import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le calendrier (CalendrierActivity.kt, activity_calendrier.xml) : le bandeau, la carte du mois (le choix de la
/// vue, l'en-tête, les initiales des jours, la grille, « Aujourd'hui »), la carte complète du jour choisi, « Ajouter
/// du temps » pour un jour passé, ses horaires, le pied.
///
/// La vue ne décide rien : CalendrierModele (cible Ecrans) dit le mois, les cases, le jour choisi et ses blocs.
/// Elle s'ouvre de l'onglet Zmanim, dans la pile de son onglet. La halakha, les hilloulot, le texte de Birkat
/// haLevana et le dialogue « Ajouter du temps » sont d'autres écrans : `ouvrir` les reçoit. Le choix du lieu est
/// celui de l'onglet (le même LieuModele).
public struct CalendrierVue: View {
    let modele: CalendrierModele
    private let ouvrir: @MainActor (ZmanimRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var scenePhase

    @State private var mesures = ZmanimMesures()
    /// L'écran est celui du dessus de sa pile : lui seul présente le choix du lieu.
    @State private var auPremierPlan = false

    /// - Parameters:
    ///   - modele: le calendrier, construit avec le `choixLieu` de l'onglet Zmanim.
    ///   - ouvrir: les autres écrans (ZmanimRoute) : `.halakha`, `.hilloulot`, `.siddour` et `.ajouterTemps`.
    public init(modele: CalendrierModele, ouvrir: @escaping @MainActor (ZmanimRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZmanimBandeau(titre: Text(modele.titre, traducteur: traducteur), image: modele.image, lieu: nil,
                          toucherLieu: {}, mesures: mesures)
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
        .lieuChoix(modele.choixLieu, actif: auPremierPlan)
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

    @ViewBuilder private var contenu: some View {
        carteMois
        ZmanimCarteJourVue(carte: modele.carte, police: modele.police, partage: modele.partage) {
            blocsDuJour
        }
        ajouterTemps
        ZmanimHorairesVue(lignes: modele.lignes, sansLieu: modele.sansLieu, invitation: modele.invitationLieu,
                          choisirLieu: modele.choisirLieuLibelle, montrerChoixLieu: modele.montrerChoixLieu)
        ZmanimPiedVue(pied: modele.pied)
    }

    // MARK: La carte du mois

    private var carteMois: some View {
        VStack(spacing: 0) {
            choixVue
            enTete
            CalendrierGrille(modele: modele)
            Button {
                modele.allerAujourdhui()
            } label: {
                Text(modele.aujourdhuiLibelle, traducteur: traducteur)
                    .zmanimTexte(15, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .zmanimCarte()
    }

    /// « Hébraïque | Grégorien » : deux pilules sur une capsule de la marque à 9 % (0x17), centrée, 8 dessous.
    private var choixVue: some View {
        HStack(spacing: 0) {
            ForEach(modele.vues) { vue in
                Button {
                    basculer(civil: vue.civil)
                } label: {
                    Text(vue.libelle, traducteur: traducteur)
                        .zmanimTexte(14, gras: vue.actif)
                        .foregroundStyle(Teinte(vue.actif ? .onBrand : .brand))
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background {
                            if vue.actif {
                                Capsule().fill(Teinte(.brand))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(vue.actif ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Teinte(.brand).opacity(0x17 / 255.0), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(modele.vueDescription, traducteur: traducteur))
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    /// « ‹ », le titre et le sous-titre au centre, « › ». Les chevrons du système se retournent d'eux-mêmes en
    /// hébreu, comme Android permute « ‹ › ».
    private var enTete: some View {
        let tete = modele.enTete
        return HStack(spacing: 0) {
            fleche(suivant: false, description: tete.precedent) {
                modele.moisPrecedent()
            }
            VStack(spacing: 0) {
                titre(tete.titre, principal: true)
                    .foregroundStyle(Teinte(.ink))
                titre(tete.sousTitre, principal: false)
                    .foregroundStyle(Teinte(.brand))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            fleche(suivant: true, description: tete.suivant) {
                modele.moisSuivant()
            }
        }
    }

    /// Un titre de l'en-tête : le principal en gras (20 pt en hébreu, 17 en civil), l'autre en 15 pt ; la police
    /// hébraïque pour un texte hébreu.
    @ViewBuilder private func titre(_ titre: CalendrierTitre, principal: Bool) -> some View {
        switch titre {
        case .hebreu(let texte):
            Text(verbatim: texte)
                .bold(principal)
                .policeHebraique(modele.police, taille: principal ? 20 : 15,
                                 relativeA: principal ? .title3 : .subheadline)
        case .moisCivil, .plageCivile:
            Text(verbatim: ZmanimFormat.titre(titre, langue: traducteur.langue))
                .zmanimTexte(principal ? 17 : 15, gras: principal)
        }
    }

    private func fleche(suivant: Bool, description: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: suivant ? "chevron.forward" : "chevron.backward")
                // Le chevron du système est plus gros que le guillemet d'Android (26 sp) à même taille.
                .zmanimTexte(20, gras: true)
                .foregroundStyle(Teinte(.brand))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(description, traducteur: traducteur))
    }

    // MARK: Le jour choisi

    /// Dans la carte du jour, après les ajouts : Levana (sa rangée à 14), la hilloula et la halakha (à 12).
    @ViewBuilder private var blocsDuJour: some View {
        if let levana = modele.levana {
            ZmanimLevanaVue(levana: levana, haut: 14, ouvrir: ouvrir)
        }
        if let hilloula = modele.hilloula {
            ZmanimHilloulaVue(hilloula: hilloula, police: modele.police, haut: 12, ouvrir: ouvrir)
        }
        if let halakha = modele.halakha {
            ZmanimHalakhaVue(halakha: halakha, police: modele.police, haut: 12, ouvrir: ouvrir)
        }
    }

    /// « Ajouter du temps fait hors du téléphone », pour un jour passé ou aujourd'hui : toute la largeur, centré.
    @ViewBuilder private var ajouterTemps: some View {
        if let libelle = modele.ajouterTemps {
            Button {
                ouvrir(modele.routeAjouterTemps)
            } label: {
                Text(libelle, traducteur: traducteur)
                    .zmanimTexte(15, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Les actions

    /// Une écriture des réglages qui échoue ne dit rien, comme Android (Store ne signale pas d'échec).
    private func basculer(civil: Bool) {
        let modele = self.modele
        Task {
            do {
                try await modele.basculer(civil: civil)
            } catch {
            }
        }
    }
}

// MARK: - La grille

/// Les initiales des jours, du dimanche au samedi, puis les semaines du mois : 7 colonnes égales, 4 entre les
/// rangées. En hébreu, la semaine va de droite à gauche, comme la rangée d'Android.
struct CalendrierGrille: View {
    let modele: CalendrierModele

    @Environment(\.traducteur) private var traducteur

    init(modele: CalendrierModele) {
        self.modele = modele
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(modele.joursDeSemaine, id: \.self) { jour in
                    Text(verbatim: ZmanimFormat.initialeDuJour(jour, langue: traducteur.langue))
                        .zmanimTexte(12)
                        .foregroundStyle(Teinte(.muted))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
                }
            }
            ForEach(modele.semaines) { semaine in
                HStack(spacing: 0) {
                    ForEach(Array(semaine.cases.enumerated()), id: \.offset) { _, jour in
                        if let jour {
                            CalendrierCaseVue(jour: jour, police: modele.police) {
                                modele.choisir(jour.date)
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

/// Une case (52 de haut, toute la largeur de sa colonne, touchable) : le quantième principal (à la couleur de la
/// marque et en gras aujourd'hui), un point sous lui un jour de fête, l'autre quantième en petit ; le fond teinté
/// un jour chômé, cerclé le jour choisi, en retrait de 2 sur les côtés, coins de 10.
struct CalendrierCaseVue: View {
    let jour: CalendrierCase
    let police: PoliceHebraique.Police
    let choisir: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur

    init(jour: CalendrierCase, police: PoliceHebraique.Police, choisir: @escaping @MainActor () -> Void) {
        self.jour = jour
        self.police = police
        self.choisir = choisir
    }

    var body: some View {
        Button(action: choisir) {
            VStack(spacing: 0) {
                quantieme(jour.haut, principal: true)
                    .foregroundStyle(Teinte(jour.aujourdhui ? .brand : .ink))
                if jour.fete {
                    Circle()
                        .fill(Teinte(.brand))
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                }
                quantieme(jour.bas, principal: false)
                    .foregroundStyle(Teinte(.muted))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
            .background {
                fond
                    .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: description))
        .accessibilityAddTraits(jour.choisie ? .isSelected : [])
    }

    /// Chabbat et Yom Tov : la marque à 10 % (0x1A) ; le jour choisi : un contour de 2 de la marque.
    private var fond: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Teinte(.brand).opacity(jour.chome ? 0x1A / 255.0 : 0))
            .overlay {
                if jour.choisie {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Teinte(.brand), lineWidth: 2)
                }
            }
    }

    /// Le quantième hébreu (police hébraïque, 17 pt en haut), civil (15 pt en haut), ou le 1er d'un mois civil ;
    /// 11 pt en bas.
    @ViewBuilder private func quantieme(_ quantieme: CalendrierQuantieme, principal: Bool) -> some View {
        let gras = principal && jour.aujourdhui
        switch quantieme {
        case .hebreu(let lettres):
            Text(verbatim: lettres)
                .bold(gras)
                .policeHebraique(police, taille: principal ? 17 : 11, relativeA: principal ? .body : .caption2)
        case .civil(let numero):
            Text(verbatim: String(numero))
                .zmanimTexte(principal ? 15 : 11, gras: gras)
        case .premierDuMois(let mois):
            Text(verbatim: ZmanimFormat.premierDuMois(mois, langue: traducteur.langue))
                .zmanimTexte(principal ? 15 : 11, gras: gras)
        }
    }

    /// Pour VoiceOver : la date ISO, la date hébraïque, puis les fêtes, joints par « · ».
    private var description: String {
        ([jour.date.iso, jour.dateHebraique] + jour.fetes.map { traducteur.texte($0) }).joined(separator: " · ")
    }
}
