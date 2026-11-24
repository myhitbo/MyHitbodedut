import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Les hilloulot (HilloulotActivity.kt, activity_hilloulot.xml) : en haut la recherche ; puis le jour (flèches,
/// retour à aujourd'hui) et ses tsadikim, ou les résultats rangés par date ; en bas l'interrupteur de la carte du
/// jour, et le bouton de lecture (ReglagesLecture.installer, sans lune ni langues : la taille, la police, le
/// défilement automatique). Un nom touché déplie sa fiche. La vue ne décide rien : elle lit HilloulotModele (cible
/// Ecrans).
///
/// Le bandeau d'Android (sans image) est la barre de navigation d'iOS (PORTAGE.md § 2.3).
public struct HilloulotVue: View {
    private let modele: HilloulotModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    /// La place de la liste : « Voir ce jour » la ramène en haut, le défilement automatique la fait avancer.
    @State private var position = ScrollPosition()

    public init(modele: HilloulotModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                recherche
                liste
                    .gestesLecture(modele.barre)
                reglage
            }
            .padding(.bottom, 24)
        }
        .scrollPosition($position)
        .onChange(of: modele.retourEnHaut) {
            if reduireAnimations {
                position.scrollTo(edge: .top)
            } else {
                withAnimation {
                    position.scrollTo(edge: .top)
                }
            }
        }
        .lectureAvecBarre(modele.barre, position: $position, fond: Teinte(.paper))
        .scrollDismissesKeyboard(.interactively)
        .background(Teinte(.paper))
        .navigationTitle(texte("hilloulot_title"))
        .task { await modele.charger() }
        .modifier(HalakhaCycle(suspendre: { modele.suspendre() }, reprendre: { modele.reprendre() }))
    }

    private func texte(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }

    // MARK: La recherche

    /// Un champ seul, la loupe au début (16 / 2 / 8 / 2 de marge intérieure) ; hors de l'échelle des lettres.
    private var recherche: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(Teinte(.muted))
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            TextField(text: champ, prompt: texte("hilloulot_recherche"), axis: .vertical) {
                texte("hilloulot_recherche")
            }
            .submitLabel(.search)
            .autocorrectionDisabled()
            .foregroundStyle(Teinte(.ink))
            .frame(minHeight: 48)
        }
        .halakhaCarte(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 8))
    }

    private var champ: Binding<String> {
        Bindable(modele).rechercheSaisie
    }

    // MARK: La liste

    @ViewBuilder private var liste: some View {
        switch modele.contenu {
        case .chargement:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        case .jour(let du):
            HilloulotJourVue(du: du, modele: modele)
        case .recherche(let resultats):
            HilloulotResultatsVue(resultats: resultats, modele: modele)
        }
    }

    // MARK: Le réglage

    /// En bas : c'est un réglage, pas le contenu. Hors de l'échelle des lettres.
    private var reglage: some View {
        Toggle(isOn: interrupteur) {
            VStack(alignment: .leading, spacing: 4) {
                texte("hilloulot_afficher")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                texte("hilloulot_afficher_detail")
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
            }
        }
        .tint(Teinte(.brand))
        .halakhaCarte()
    }

    /// Une écriture qui échoue ne dit rien, comme Store.setHilloulotAffichees.
    private var interrupteur: Binding<Bool> {
        Bindable(modele).interrupteurCarteDuJour
    }
}

// MARK: Le jour

/// La carte du jour (flèches, dates, « Aujourd'hui »), l'en-tête, la carte des tsadikim, le lien de hyomi.org.il.
private struct HilloulotJourVue: View {
    let du: HilloulotDuJour
    let modele: HilloulotModele
    @Environment(\.traducteur) private var traducteur

    init(du: HilloulotDuJour, modele: HilloulotModele) {
        self.du = du
        self.modele = modele
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            carteDuJour
            if let aucune = du.aucune {
                Text(aucune, traducteur: traducteur)
                    .halakhaTexte(15, echelle: modele.echelle)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            } else {
                if !du.entete.isEmpty {
                    // « 7 tsadikim ce jour · Touchez un nom pour lire sa biographie. »
                    Text(verbatim: du.entete.map { traducteur.texte($0) }.joined(separator: " · "))
                        .halakhaTexte(13, echelle: modele.echelle)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }
                if !du.lignes.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(du.lignes) { ligne in
                            HilloulotLigneVue(ligne: ligne, modele: modele)
                        }
                    }
                    .halakhaCarte(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16), haut: 6)
                }
            }
            HalakhaLienSortant(texte: traducteur.texte(du.lien.libelle), url: du.lien.url, taille: 14,
                               echelle: modele.echelle)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
    }

    private var carteDuJour: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HalakhaFleche(suivant: false, taille: 28, cadre: 52, echelle: modele.echelle,
                              libelle: Text(Libelle("jour_precedent"), traducteur: traducteur)) {
                    modele.jourPrecedent()
                }
                VStack(spacing: 0) {
                    Text(verbatim: du.dateHebraique)
                        .halakhaTexte(22, police: modele.police, gras: true, echelle: modele.echelle)
                        .foregroundStyle(Teinte(.brand))
                    Text(verbatim: HalakhaDateCivile.texte(du.jour, langue: traducteur.langue))
                        .halakhaTexte(13, echelle: modele.echelle)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                HalakhaFleche(suivant: true, taille: 28, cadre: 52, echelle: modele.echelle,
                              libelle: Text(Libelle("jour_suivant"), traducteur: traducteur)) {
                    modele.jourSuivant()
                }
            }
            if let aujourdhui = du.aujourdhui {
                Button {
                    modele.revenirAujourdhui()
                } label: {
                    Text(aujourdhui, traducteur: traducteur)
                        .halakhaTexte(14, gras: true, echelle: modele.echelle)
                        .foregroundStyle(Teinte(.brand))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .halakhaCarte(EdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 4))
    }
}

// MARK: La recherche

/// « Résultats : 12 », puis une seule carte : les dates dans l'ordre de l'année, chacune avec « Voir ce jour » et
/// ses tsadikim.
private struct HilloulotResultatsVue: View {
    let resultats: HilloulotResultats
    let modele: HilloulotModele
    @Environment(\.traducteur) private var traducteur

    init(resultats: HilloulotResultats, modele: HilloulotModele) {
        self.resultats = resultats
        self.modele = modele
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(resultats.nombre, traducteur: traducteur)
                .halakhaTexte(13, gras: true, echelle: modele.echelle)
                .foregroundStyle(Teinte(.muted))
                .padding(.horizontal, 20)
                .padding(.top, 16)
            if !resultats.groupes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(resultats.groupes.enumerated()), id: \.element.id) { paire in
                        HilloulotGroupeVue(groupe: paire.element, premier: paire.offset == 0, modele: modele)
                    }
                }
                .halakhaCarte(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16), haut: 6)
            }
        }
    }
}

/// Une date des résultats (HilloulotActivity.enteteDate), puis ses tsadikim ; un filet de 2 la sépare de la
/// précédente.
private struct HilloulotGroupeVue: View {
    let groupe: HilloulotGroupe
    let premier: Bool
    let modele: HilloulotModele
    @Environment(\.traducteur) private var traducteur

    init(groupe: HilloulotGroupe, premier: Bool, modele: HilloulotModele) {
        self.groupe = groupe
        self.premier = premier
        self.modele = modele
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !premier {
                Rectangle()
                    .fill(Teinte(.line))
                    .frame(height: 2)
                    .padding(.top, 6)
            }
            HStack(spacing: 0) {
                Text(verbatim: groupe.date)
                    .halakhaTexte(16, police: modele.police, gras: true, echelle: modele.echelle)
                    .foregroundStyle(Teinte(.brand))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    modele.voirLeJour(groupe)
                } label: {
                    Text(groupe.voir, traducteur: traducteur)
                        .halakhaTexte(13, echelle: modele.echelle)
                        .foregroundStyle(Teinte(.brand))
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            ForEach(groupe.lignes) { ligne in
                HilloulotLigneVue(ligne: ligne, modele: modele)
            }
        }
    }
}

// MARK: Un tsadik

/// Un nom (HilloulotActivity.ligne), écrit de droite à gauche dans toutes les langues : le nom hébreu à droite, le
/// chevron à gauche. Toute la tête se touche quand il y a de quoi déplier.
private struct HilloulotLigneVue: View {
    let ligne: HilloulotLigne
    let modele: HilloulotModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(ligne: HilloulotLigne, modele: HilloulotModele) {
        self.ligne = ligne
        self.modele = modele
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !ligne.premiere {
                Rectangle()
                    .fill(Teinte(.line))
                    .frame(height: 0.5)
            }
            tete
            if let fiche = ligne.fiche {
                HilloulotFicheVue(fiche: fiche, modele: modele)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder private var tete: some View {
        if ligne.depliable {
            Button {
                basculer()
            } label: {
                contenuTete
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: etiquette))
            .accessibilityAddTraits(.isButton)
        } else {
            contenuTete
                .accessibilityElement(children: .combine)
        }
    }

    private var contenuTete: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: ligne.nom)
                    .halakhaTexte(17, police: modele.police, gras: true, echelle: modele.echelle)
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let sous = sousTitre {
                    Text(verbatim: sous)
                        .halakhaTexte(13, echelle: modele.echelle)
                        .foregroundStyle(Teinte(.muted))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.leading)
            if ligne.depliable {
                // Vers le bas replié, vers le haut déplié.
                Image(systemName: "chevron.down")
                    .font(Font.subheadline.weight(.semibold))
                    .foregroundStyle(Teinte(.muted))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(ligne.ouverte ? 180 : 0))
                    .animation(reduireAnimations ? nil : .default, value: ligne.ouverte)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    /// La traduction et l'année du décès, jointes par « · » ; nil sans l'une ni l'autre.
    private var sousTitre: String? {
        let parties = [ligne.traduit, ligne.deces.map { traducteur.texte($0) }].compactMap { $0 }
        return parties.isEmpty ? nil : parties.joined(separator: " · ")
    }

    /// « nom, traduction, Lire la suite » (le contentDescription d'Android).
    private var etiquette: String {
        let noms = [ligne.nom, ligne.traduit].compactMap { $0 }.joined(separator: ", ")
        guard let action = ligne.action else { return noms }
        return noms + ", " + traducteur.texte(action)
    }

    private func basculer() {
        if reduireAnimations {
            modele.basculer(ligne)
        } else {
            withAnimation {
                modele.basculer(ligne)
            }
        }
    }
}

/// Ce qui se déplie sous un nom (HilloulotActivity.fiche) : la notice, les sources, chaque biographie suivie de
/// sa source, Hidabroot. 14 en bas.
private struct HilloulotFicheVue: View {
    let fiche: HilloulotFiche
    let modele: HilloulotModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(fiche: HilloulotFiche, modele: HilloulotModele) {
        self.fiche = fiche
        self.modele = modele
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let description = fiche.description {
                HalakhaParagraphesVue(paragraphes: description, taille: 14, police: modele.police,
                                      echelle: modele.echelle)
            }
            ForEach(fiche.sources) { source in
                HilloulotSourceVue(source: source, echelle: modele.echelle)
                    .padding(.top, 4)
            }
            ForEach(fiche.bios) { bio in
                HalakhaParagraphesVue(paragraphes: bio.paragraphes, taille: 14, police: modele.police,
                                      echelle: modele.echelle, lignesMax: bio.repliee ? 8 : nil)
                    .padding(.top, 12)
                if let bouton = bio.bouton {
                    Button {
                        basculer(bio)
                    } label: {
                        Text(bouton, traducteur: traducteur)
                            .halakhaTexte(13, gras: true, echelle: modele.echelle)
                            .foregroundStyle(Teinte(.brand))
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
                HilloulotSourceVue(source: bio.source, echelle: modele.echelle)
                    .padding(.top, 4)
            }
            if let hidabroot = fiche.hidabroot {
                HilloulotSourceVue(source: hidabroot, echelle: modele.echelle)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 14)
    }

    private func basculer(_ bio: HilloulotBio) {
        if reduireAnimations {
            modele.basculer(bio: bio)
        } else {
            withAnimation {
                modele.basculer(bio: bio)
            }
        }
    }
}

/// Une source (HilloulotActivity.source), discrète, au début de la ligne : avec un lien, couleur de l'accent et
/// « ↗ », le toucher ouvre la page ; sans lien, atténuée, rien ne se touche.
private struct HilloulotSourceVue: View {
    let source: HilloulotSource
    let echelle: Float
    @Environment(\.traducteur) private var traducteur

    init(source: HilloulotSource, echelle: Float) {
        self.source = source
        self.echelle = echelle
    }

    var body: some View {
        if let lien = source.lien {
            HalakhaLienSortant(texte: traducteur.texte(source.nom), url: lien, taille: 12, echelle: echelle,
                               gras: false, centre: false)
        } else {
            Text(source.nom, traducteur: traducteur)
                .halakhaTexte(12, echelle: echelle)
                .foregroundStyle(Teinte(.muted))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
