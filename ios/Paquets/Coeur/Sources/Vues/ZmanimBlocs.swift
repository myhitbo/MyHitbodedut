import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les blocs de VueJour.kt, partagés par l'onglet Zmanim et le calendrier : la carte d'un jour, les horaires,
// Birkat haLevana, la hilloula et la halakha du jour, la carte d'un réglage et son dialogue. Chacun lit ce que
// le modèle lui donne (ZmanimCarteJour, ZmanimLigne, ZmanimLevana…) ; un toucher qui mène ailleurs passe par
// `ouvrir`.

// MARK: La carte du jour

/// La carte d'un jour (VueJour.carteJour) : l'illustration d'une fête ou de Chabbat, la date hébraïque, la date
/// civile, les fêtes, ce que le jour change aux prières, puis `suite` (Levana, hilloula et halakha dans le
/// calendrier ; rien dans l'onglet) et le lien de partage.
struct ZmanimCarteJourVue<Suite: View>: View {
    let carte: ZmanimCarteJour
    let police: PoliceHebraique.Police
    let partage: PartageContenu
    let suite: Suite

    @Environment(\.traducteur) private var traducteur

    init(carte: ZmanimCarteJour, police: PoliceHebraique.Police, partage: PartageContenu,
         @ViewBuilder suite: () -> Suite) {
        self.carte = carte
        self.police = police
        self.partage = partage
        self.suite = suite()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let nom = carte.illustration {
                Illustration(decorative: nom, hauteur: 150)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            Text(verbatim: carte.dateHebraique)
                .bold()
                .policeHebraique(police, taille: 26, relativeA: .title)
                .foregroundStyle(Teinte(.brand))
                .zmanimDroiteAGauche()
            Text(verbatim: ZmanimFormat.dateCivile(carte.date, langue: traducteur.langue))
                .zmanimTexte(14)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 4)
            if !carte.marques.isEmpty {
                Text(verbatim: joindre(carte.marques, ZmanimVueJour.separateurMarques))
                    .zmanimTexte(14, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.top, 8)
            }
            Text(carte.ajoutsTitre, traducteur: traducteur)
                .zmanimTexte(12, gras: true)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 12)
            ajouts
                .zmanimTexte(15)
                .foregroundStyle(Teinte(.ink))
                .padding(.top, 4)
            suite
            PartageJourLien(contenu: partage, libelle: carte.partage)
        }
        .zmanimCarte()
    }

    /// Les ajouts joints par « · », ou « Rien de particulier ».
    private var ajouts: Text {
        if let aucun = carte.aucunAjout {
            return Text(aucun, traducteur: traducteur)
        }
        return Text(verbatim: joindre(carte.ajouts, ZmanimVueJour.separateurAjouts))
    }

    private func joindre(_ libelles: [Libelle], _ separateur: String) -> String {
        libelles.map { traducteur.texte($0) }.joined(separator: separateur)
    }
}

extension ZmanimCarteJourVue where Suite == EmptyView {
    /// La carte de l'onglet Zmanim : le jour seul (Levana, hilloula et halakha viennent sous les horaires).
    init(carte: ZmanimCarteJour, police: PoliceHebraique.Police, partage: PartageContenu) {
        self.init(carte: carte, police: police, partage: partage) {
            EmptyView()
        }
    }
}

// MARK: Les horaires

/// La carte des horaires (VueJour.horaires) : une ligne par zman, 12 entre elles ; sans lieu, l'invitation et le
/// lien « Choisir le lieu ».
struct ZmanimHorairesVue: View {
    let lignes: [ZmanimLigne]
    let sansLieu: Bool
    let invitation: Libelle
    let choisirLieu: Libelle
    let montrerChoixLieu: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur

    init(lignes: [ZmanimLigne], sansLieu: Bool, invitation: Libelle, choisirLieu: Libelle,
         montrerChoixLieu: @escaping @MainActor () -> Void) {
        self.lignes = lignes
        self.sansLieu = sansLieu
        self.invitation = invitation
        self.choisirLieu = choisirLieu
        self.montrerChoixLieu = montrerChoixLieu
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sansLieu {
                Text(invitation, traducteur: traducteur)
                    .zmanimTexte(15)
                    .foregroundStyle(Teinte(.ink))
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: montrerChoixLieu) {
                    Text(choisirLieu, traducteur: traducteur)
                        .zmanimTexte(16, gras: true)
                        .foregroundStyle(Teinte(.brand))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(lignes) { ligne in
                        LigneHoraire(libelle: Text(ligne.nom, traducteur: traducteur),
                                     heure: ligne.heureTexte,
                                     methode: ligne.methode.map { Text($0, traducteur: traducteur) },
                                     misEnAvant: ligne.misEnAvant)
                    }
                }
            }
        }
        .zmanimCarte()
    }
}

// MARK: Birkat haLevana

/// Birkat haLevana (VueJour.levana) : la lune de ce soir, l'état, la fenêtre, le motsaé Chabbat conseillé, la
/// restriction, la jauge du mois, la source et le lien vers le texte. `haut` : 0 en tête de sa carte (onglet),
/// 14 sous les ajouts (calendrier, `dp(haut)` d'Android sans l'échelle des espaces).
struct ZmanimLevanaVue: View {
    let levana: ZmanimLevana
    let haut: CGFloat
    let ouvrir: @MainActor (ZmanimRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    init(levana: ZmanimLevana, haut: CGFloat, ouvrir: @escaping @MainActor (ZmanimRoute) -> Void) {
        self.levana = levana
        self.haut = haut
        self.ouvrir = ouvrir
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZmanimLune(lune: levana.lune, sud: levana.sud)
                VStack(alignment: .leading, spacing: 0) {
                    Text(levana.titre, traducteur: traducteur)
                        .zmanimTexte(12, gras: true)
                        .foregroundStyle(Teinte(.muted))
                    Text(levana.etat, traducteur: traducteur)
                        .zmanimTexte(17, gras: true)
                        .foregroundStyle(Teinte(levana.etatMisEnAvant ? .brand : .ink))
                        .padding(.top, 4)
                    Text(levana.luneTexte, traducteur: traducteur)
                        .zmanimTexte(13)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .padding(.top, haut)
            Text(fenetre, traducteur: traducteur)
                .zmanimTexte(14)
                .foregroundStyle(Teinte(.ink))
                .padding(.top, 8)
            if let motsae = levana.motsae {
                Text(ZmanimLevana.motsae(ZmanimFormat.jourCourt(motsae, langue: traducteur.langue)),
                     traducteur: traducteur)
                    .zmanimTexte(13)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.top, 4)
            }
            if let restriction = levana.restriction {
                Text(restriction, traducteur: traducteur)
                    .zmanimTexte(13)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.top, 4)
            }
            ZmanimJaugeVue(jauge: levana.jauge)
                .padding(.top, 8)
            Text(levana.source, traducteur: traducteur)
                .zmanimTexte(11)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 4)
            ZmanimLien(Text(levana.lire, traducteur: traducteur)) {
                ouvrir(levana.route)
            }
        }
    }

    /// « Du … au … », chaque borne à l'heure du lieu dans la langue de l'app.
    private var fenetre: Libelle {
        ZmanimLevana.fenetre(debut: ZmanimFormat.borneLevana(levana.debut, langue: traducteur.langue),
                             fin: ZmanimFormat.borneLevana(levana.fin, langue: traducteur.langue))
    }
}

// MARK: La hilloula

/// La hilloula du jour (VueJour.blocHilloula) : le titre, cinq noms au plus, « et N autres › », le lien vers
/// toutes les hilloulot. `haut` : 0 en tête de sa carte, 12 dans la carte du calendrier.
struct ZmanimHilloulaVue: View {
    let hilloula: ZmanimHilloula
    let police: PoliceHebraique.Police
    let haut: CGFloat
    let ouvrir: @MainActor (ZmanimRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    init(hilloula: ZmanimHilloula, police: PoliceHebraique.Police, haut: CGFloat,
         ouvrir: @escaping @MainActor (ZmanimRoute) -> Void) {
        self.hilloula = hilloula
        self.police = police
        self.haut = haut
        self.ouvrir = ouvrir
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hilloula.titre, traducteur: traducteur)
                .zmanimTexte(12, gras: true)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, haut)
            // Interligne × 1,25 d'Android : un quart de ligne en plus, à peu près.
            Text(verbatim: hilloula.noms.joined(separator: "\n"))
                .policeHebraique(police, taille: 14, relativeA: .subheadline)
                .lineSpacing(4)
                .foregroundStyle(Teinte(.ink))
                .zmanimDroiteAGauche()
                .padding(.top, 4)
            if let autres = hilloula.autres {
                Button {
                    ouvrir(hilloula.route)
                } label: {
                    Text(verbatim: traducteur.texte(autres) + " ›")
                        .policeHebraique(police, taille: 12, relativeA: .caption)
                        .foregroundStyle(Teinte(.muted))
                        .frame(minHeight: 48)
                        .zmanimDroiteAGauche()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            ZmanimLien(Text(hilloula.tout, traducteur: traducteur)) {
                ouvrir(hilloula.route)
            }
        }
    }
}

// MARK: La halakha

/// La halakha du jour (VueJour.blocHalakha) : « Halakha yomit · livre », le début en quatre lignes au plus, le
/// lien vers toute la halakha. `haut` : 0 en tête de sa carte, 12 dans la carte du calendrier.
struct ZmanimHalakhaVue: View {
    let halakha: ZmanimHalakha
    let police: PoliceHebraique.Police
    let haut: CGFloat
    let ouvrir: @MainActor (ZmanimRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    init(halakha: ZmanimHalakha, police: PoliceHebraique.Police, haut: CGFloat,
         ouvrir: @escaping @MainActor (ZmanimRoute) -> Void) {
        self.halakha = halakha
        self.police = police
        self.haut = haut
        self.ouvrir = ouvrir
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: traducteur.texte(halakha.titre) + " · " + traducteur.texte(halakha.livre))
                .zmanimTexte(12, gras: true)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, haut)
            Text(verbatim: halakha.debut)
                .policeHebraique(police, taille: 16, relativeA: .body)
                .foregroundStyle(Teinte(.ink))
                .lineLimit(4)
                .truncationMode(.tail)
                .zmanimDroiteAGauche()
                .padding(.top, 4)
            ZmanimLien(Text(halakha.tout, traducteur: traducteur)) {
                ouvrir(halakha.route)
            }
        }
    }
}

// MARK: Les réglages de l'onglet

/// Une carte de réglage touchable (l'allumage, Ta'hanoun de fin de Tichri) : le titre, la valeur, la proposition ;
/// toute la carte ouvre son dialogue.
struct ZmanimCarteReglage: View {
    let reglage: ZmanimReglage
    let action: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur

    init(reglage: ZmanimReglage, action: @escaping @MainActor () -> Void) {
        self.reglage = reglage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(reglage.titre, traducteur: traducteur)
                    .zmanimTexte(15)
                    .foregroundStyle(Teinte(.ink))
                Text(reglage.valeur, traducteur: traducteur)
                    .zmanimTexte(13)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 4)
                if let proposition = reglage.proposition {
                    Text(proposition, traducteur: traducteur)
                        .zmanimTexte(13)
                        .foregroundStyle(Teinte(.brand))
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .zmanimFond()
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .zmanimMarges()
    }
}

/// Le dialogue à choix unique d'un réglage (setSingleChoiceItems), en feuille : titré comme la carte, l'option
/// choisie cochée ; un choix ferme la feuille, la glisser vers le bas la ferme sans rien choisir.
struct ZmanimFeuilleReglage: View {
    let reglage: ZmanimReglage
    let choisir: @MainActor (ZmanimOption) -> Void

    @Environment(\.traducteur) private var traducteur

    init(reglage: ZmanimReglage, choisir: @escaping @MainActor (ZmanimOption) -> Void) {
        self.reglage = reglage
        self.choisir = choisir
    }

    var body: some View {
        NavigationStack {
            List(reglage.options) { option in
                Button {
                    choisir(option)
                } label: {
                    LieuLigneChoix(texte: Text(option.libelle, traducteur: traducteur), cochee: option.choisie)
                }
                .listRowBackground(Rectangle().fill(Teinte(.card)))
            }
            .scrollContentBackground(.hidden)
            .background(Teinte(.paper))
            .navigationTitle(Text(reglage.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
