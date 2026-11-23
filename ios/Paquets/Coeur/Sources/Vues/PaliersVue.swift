import Foundation
import SwiftUI
import Coeur
import Ecrans

/// « Trophées et paliers » (PaliersActivity.kt) : en tête, le grade, la barre vers le suivant, les trophées les plus
/// proches ; un filtre par famille ; puis une seule ligne verticale — les trophées gagnés, chacun du métal du grade
/// d'alors et daté, une bannière à chaque grade ; « Vous êtes ici » et le prochain objectif ; les suivants, en gris —
/// et les records en bas. Chaque trophée s'ouvre en fiche. La vue lit `PaliersModele` (testé sous Linux).
public struct PaliersVue: View {
    private let modele: PaliersModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.tropheeFormes) private var formes

    public init(modele: PaliersModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollViewReader { defilement in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    enTete
                    filtres
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(modele.lignes) { ligne in
                            PaliersLigneVue(ligne: ligne) { niveau in modele.ouvrirFiche(niveau) }
                                .id(ligne.id)
                        }
                    }
                    records
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .task {
                try? await modele.ouvrir()
                // L'écran s'ouvre sur « Vous êtes ici ».
                defilement.scrollTo(PaliersModele.idIci, anchor: .center)
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(PaliersModele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Bindable(modele).ficheLiee) { fiche in
            PaliersFicheVue(fiche: fiche) { modele.fermerFiche() }
                .hauteursDeFeuille([.medium])
        }
        .alert(Text(modele.feteGrade?.titre ?? Libelle("celebration_continue"), traducteur: traducteur),
               isPresented: Bindable(modele).feteGradeLiee) {
            Button {
                modele.fermerFeteGrade()
            } label: {
                Text(Libelle("celebration_continue"), traducteur: traducteur)
            }
        } message: {
            if let fete = modele.feteGrade {
                Text(fete.sous, traducteur: traducteur)
            }
        }
    }

    private var enTete: some View {
        let tete = modele.enTete
        return Carte {
            HStack(spacing: 14) {
                TropheeObjet(formes?.medaille(tete.grade))
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tete.titre, traducteur: traducteur)
                        .tailleSp(18, poids: .bold, relativeA: .headline)
                        .foregroundStyle(Teinte(.ink))
                    Text(tete.sous, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            if let barre = tete.barre {
                TropheeBarre(fraction: Double(barre), hauteur: 8, couleur: tete.couleurBarre.couleurSwiftUI, monte: true)
                    .padding(.top, 10)
            }
            if let titre = tete.prochesTitre {
                Text(titre, traducteur: traducteur)
                    .font(Font.footnote.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .padding(.top, 12)
                ForEach(tete.proches) { proche in
                    Button {
                        modele.ouvrirFiche(proche.niveau)
                    } label: {
                        HStack {
                            Text(proche.description, traducteur: traducteur)
                                .font(.subheadline)
                                .foregroundStyle(Teinte(.ink))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(proche.progres, traducteur: traducteur)
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Teinte(.muted))
                        }
                        .frame(minHeight: 40)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Le filtre par famille : une rangée de puces, un seul choix.
    private var filtres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(modele.filtres) { filtre in
                    Button {
                        modele.choisirFiltre(filtre.famille)
                    } label: {
                        Text(filtre.titre, traducteur: traducteur)
                            .font(.footnote)
                            .foregroundStyle(filtre.choisi ? Teinte(.onBrand) : Teinte(.ink))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(filtre.choisi ? Teinte(.brand) : Teinte(.card), in: Capsule())
                            .overlay { Capsule().strokeBorder(Teinte(.line), lineWidth: filtre.choisi ? 0 : 1) }
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(filtre.accessibilite, traducteur: traducteur))
                    .accessibilityAddTraits(filtre.choisi ? .isSelected : [])
                }
            }
        }
    }

    private var records: some View {
        let records = modele.records
        return Carte {
            Text(records.titre, traducteur: traducteur)
                .titreCarte()
            ForEach(Array(records.lignes.enumerated()), id: \.offset) { _, ligne in
                Text(ligne, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 6)
            }
        }
    }
}

extension PaliersModele {
    var ficheLiee: TropheeFiche? {
        get { fiche }
        set { if newValue == nil { fermerFiche() } }
    }

    var feteGradeLiee: Bool {
        get { feteGrade != nil }
        set { if !newValue { fermerFeteGrade() } }
    }
}

/// Une ligne de la ligne verticale : une bannière de grade, une étape, « Vous êtes ici », ou un mot de fin.
private struct PaliersLigneVue: View {
    let ligne: PaliersLigne
    let ouvrir: @MainActor (Trophees.Niveau) -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.tropheeFormes) private var formes

    var body: some View {
        switch ligne {
        case .banniere(let banniere):
            HStack(spacing: 10) {
                if let medaille = banniere.medaille {
                    TropheeObjet(formes?.medaille(medaille))
                        .frame(width: 28, height: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(banniere.titre, traducteur: traducteur)
                        .font(Font.subheadline.bold())
                    Text(banniere.sous, traducteur: traducteur)
                        .font(.caption)
                }
                .foregroundStyle(banniere.atteint ? Teinte(.ink) : Teinte(.muted))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Teinte(.stageSoft), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.vertical, 6)
        case .etape(let etape):
            Button {
                ouvrir(etape.niveau)
            } label: {
                HStack(spacing: 14) {
                    TropheeObjet(formes?.dessin(etape.niveau, metal: etape.metal))
                        .frame(width: CGFloat(etape.coteObjet), height: CGFloat(etape.coteObjet))
                        .opacity(etape.opaciteObjet)
                        .frame(width: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(etape.description, traducteur: traducteur)
                            .font(.subheadline)
                            .foregroundStyle(etape.gagne ? Teinte(.ink) : Teinte(.muted))
                        if let sous = etape.sous {
                            Text(sous.libelle { TropheeDate.longue($0, langue: traducteur.langue) },
                                 traducteur: traducteur)
                                .font(.caption)
                                .foregroundStyle(Teinte(.muted))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        case .ici(let ici):
            Button {
                ouvrir(ici.niveau)
            } label: {
                Carte {
                    Text(PaliersIci.titre, traducteur: traducteur)
                        .font(Font.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Teinte(.brand))
                    Text(ici.description, traducteur: traducteur)
                        .font(Font.body.bold())
                        .foregroundStyle(Teinte(.ink))
                        .padding(.top, 4)
                    TropheeBarre(fraction: Double(ici.fraction), hauteur: 8, couleur: Teinte(.brand), monte: true)
                        .padding(.top, 8)
                    Text(ici.encore, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 6)
                }
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        case .tousGagnes(let texte), .autres(let texte):
            Text(texte, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
        }
    }
}

/// La fiche d'un trophée (FicheTrophee) : l'objet, ce qu'il demande, le nom et le niveau, le jour gagné ou la
/// progression.
private struct PaliersFicheVue: View {
    let fiche: TropheeFiche
    let fermer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.tropheeFormes) private var formes

    var body: some View {
        VStack(spacing: 12) {
            TropheeObjet(formes?.dessin(fiche.niveau, metal: fiche.metal))
                .frame(width: 96, height: 96)
            Text(fiche.titre, traducteur: traducteur)
                .tailleSp(20, poids: .bold, relativeA: .title3)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.center)
            Text(verbatim: traducteur.texte(fiche.nom) + " · " + traducteur.texte(fiche.niveauCourt))
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
            switch fiche.etat {
            case .gagne(let sous, let grade):
                Text(sous.libelle { TropheeDate.longue($0, langue: traducteur.langue) }, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.brand))
                Text(grade, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
            case .aGagner(let fraction, let encore):
                TropheeBarre(fraction: Double(fraction), hauteur: 8, couleur: Teinte(.brand), monte: true)
                Text(encore, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            Spacer(minLength: 8)
            Button(action: fermer) {
                Text(TropheeFiche.bouton, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Teinte(.paper))
        .accessibilityElement(children: .contain)
    }
}
