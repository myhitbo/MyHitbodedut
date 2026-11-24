import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La halakha du jour (HalakhaActivity.kt, activity_halakha.xml) : la carte des réglages (l'interrupteur de la carte
/// du jour, le livre, le champ de recherche), puis le jour et ses halakhot, ou les résultats de la recherche ; en
/// bas, le bouton de lecture (ReglagesLecture.installer, sans lune ni langues : la taille, la police, le défilement
/// automatique). La vue ne décide rien : elle lit HalakhaModele (cible Ecrans) et appelle ses actions.
///
/// Le bandeau d'Android (bg_hero, sans image : on lit) est la barre de navigation d'iOS, qui se réduit en
/// défilant (PORTAGE.md § 2.3). L'écran se pousse dans la pile de son onglet : il n'en ouvre pas une seconde.
public struct HalakhaVue: View {
    private let modele: HalakhaModele
    @Environment(\.traducteur) private var traducteur
    /// La place de la liste, que le défilement automatique fait avancer.
    @State private var position = ScrollPosition()

    public init(modele: HalakhaModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                reglages
                liste
                    .gestesLecture(modele.barre)
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollPosition($position)
        .lectureAvecBarre(modele.barre, position: $position, fond: Teinte(.paper))
        .background(Teinte(.paper))
        .navigationTitle(texte("halakha_title"))
        .task { await modele.charger() }
        .modifier(HalakhaCycle(suspendre: { modele.suspendre() }, reprendre: { modele.reprendre() }))
    }

    private func texte(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }

    // MARK: Les réglages

    /// La carte du haut. L'échelle des lettres n'y touche pas : ReglagesLecture.retailler ne prend que la liste.
    private var reglages: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: interrupteur) {
                texte("halakha_afficher")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
            }
            .tint(Teinte(.brand))
            texte("halakha_source_titre")
                .font(Font.footnote.bold())
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 8)
            HalakhaFlux {
                ForEach(modele.sources) { choix in
                    HalakhaPuce(texte: Text(choix.libelle, traducteur: traducteur), choisie: choix.choisie) {
                        choisir(choix.source)
                    }
                }
            }
            .padding(.top, 8)
            TextField(text: champ, prompt: texte("halakha_recherche"), axis: .vertical) {
                texte("halakha_recherche")
            }
            .submitLabel(.search)
            .autocorrectionDisabled()
            .foregroundStyle(Teinte(.ink))
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Teinte(.line))
                    .frame(height: 1)
            }
            .padding(.top, 8)
        }
        .halakhaCarte()
    }

    /// Le champ : chaque frappe passe au modèle, qui cherche ou revient au jour.
    private var champ: Binding<String> {
        Bindable(modele).rechercheSaisie
    }

    /// L'interrupteur, lu dans les réglages. Une écriture qui échoue ne dit rien, comme Store.setHalakhaAffichee :
    /// l'interrupteur revient alors à ce que gardent les réglages.
    private var interrupteur: Binding<Bool> {
        Bindable(modele).interrupteurCarteDuJour
    }

    private func choisir(_ source: Reglages.SourceHalakha) {
        let modele = self.modele
        Task {
            do {
                try await modele.choisirSource(source)
            } catch {
                // Android n'affiche rien : la puce reste sur le livre que gardent les réglages.
            }
        }
    }

    // MARK: La liste

    @ViewBuilder private var liste: some View {
        switch modele.contenu {
        case .chargement:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        case .jour(let du):
            HalakhaJourVue(du: du, modele: modele)
        case .recherche(let resultats):
            HalakhaResultatsVue(resultats: resultats, echelle: modele.echelle, police: modele.police)
        }
    }
}

// MARK: Le jour

/// Le jour montré : la rangée des dates entre les flèches, le Yalkut Yosef, le Ben Ish 'Haï, les notes, le lien.
private struct HalakhaJourVue: View {
    let du: HalakhaDuJour
    let modele: HalakhaModele
    @Environment(\.traducteur) private var traducteur

    init(du: HalakhaDuJour, modele: HalakhaModele) {
        self.du = du
        self.modele = modele
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rangee
            if let carte = du.yalkut {
                HalakhaCarteVue(carte: carte, echelle: modele.echelle, police: modele.police)
            }
            if let aucune = du.aucune {
                note(aucune, taille: 15)
            }
            if let titre = du.benIshHaiTitre {
                Text(titre, traducteur: traducteur)
                    .halakhaTexte(14, gras: true, echelle: modele.echelle)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
            ForEach(du.benIshHai) { carte in
                HalakhaCarteVue(carte: carte, echelle: modele.echelle, police: modele.police)
            }
            if let source = du.yalkutSource {
                note(source, taille: 12)
            }
            note(du.note, taille: 12)
            HalakhaLienSortant(texte: traducteur.texte(du.lien.libelle), url: du.lien.url, taille: 15,
                               echelle: modele.echelle)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
    }

    /// La date hébraïque et la date civile, entre « ‹ » et « › » ; en hébreu, la rangée se retourne. 14 au-dessus,
    /// hors de l'échelle des espacements.
    private var rangee: some View {
        HStack(spacing: 0) {
            HalakhaFleche(suivant: false, taille: 26, cadre: 48, echelle: modele.echelle,
                          libelle: Text(Libelle("jour_precedent"), traducteur: traducteur)) {
                modele.jourPrecedent()
            }
            VStack(spacing: 0) {
                Text(verbatim: du.dateHebraique)
                    .halakhaTexte(20, police: modele.police, gras: true, echelle: modele.echelle)
                    .foregroundStyle(Teinte(.brand))
                Text(verbatim: HalakhaDateCivile.texte(du.jour, langue: traducteur.langue))
                    .halakhaTexte(13, echelle: modele.echelle)
                    .foregroundStyle(Teinte(.muted))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            HalakhaFleche(suivant: true, taille: 26, cadre: 48, echelle: modele.echelle,
                          libelle: Text(Libelle("jour_suivant"), traducteur: traducteur)) {
                modele.jourSuivant()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
    }

    /// Un texte discret, centré, 12 au-dessus.
    private func note(_ libelle: Libelle, taille: CGFloat) -> some View {
        Text(libelle, traducteur: traducteur)
            .halakhaTexte(taille, echelle: modele.echelle)
            .foregroundStyle(Teinte(.muted))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }
}

// MARK: La recherche

/// « Résultats : 12 », puis les cartes ; ni rangée du jour, ni notes, ni lien.
private struct HalakhaResultatsVue: View {
    let resultats: HalakhaResultats
    let echelle: Float
    let police: PoliceHebraique.Police
    @Environment(\.traducteur) private var traducteur

    init(resultats: HalakhaResultats, echelle: Float, police: PoliceHebraique.Police) {
        self.resultats = resultats
        self.echelle = echelle
        self.police = police
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(resultats.nombre, traducteur: traducteur)
                .halakhaTexte(14, gras: true, echelle: echelle)
                .foregroundStyle(Teinte(.muted))
                .padding(.horizontal, 16)
                .padding(.top, 12)
            ForEach(resultats.cartes) { carte in
                HalakhaCarteVue(carte: carte, echelle: echelle, police: police)
            }
        }
    }
}

// MARK: Une carte

/// Une halakha (HalakhaActivity.carte) : sa source, puis son texte, tous deux en hébreu, de droite à gauche dans
/// toutes les langues, en police hébraïque ; le texte se sélectionne.
private struct HalakhaCarteVue: View {
    let carte: HalakhaCarte
    let echelle: Float
    let police: PoliceHebraique.Police

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: carte.titre)
                .halakhaTexte(13, police: police, gras: true, echelle: echelle)
                .foregroundStyle(Teinte(.brand))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
            HalakhaParagraphesVue(paragraphes: carte.paragraphes, taille: 18, police: police, echelle: echelle,
                                  interligne: 0.5)
                .textSelection(.enabled)
                .padding(.top, 8)
        }
        .halakhaCarte()
    }
}
